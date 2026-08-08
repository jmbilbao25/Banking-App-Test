import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/txn_csv.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../state/providers.dart';
import '../../state/txn_filter.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import '../widgets/transaction_list.dart';

/// Rows requested per page. Requirement 15.10 asks for the next 20, so this is
/// the figure the criterion names rather than a tunable.
const int txnPageSize = 20;

/// What the ledger has loaded so far, and what it is doing about the rest.
///
/// [rows] is the raw reverse chronological list as returned by the repository,
/// before the active filter is applied. Filtering happens over this loaded set
/// in the presentation layer, so requirements 15.5 to 15.8 keep working while
/// only part of the ledger is in memory.
@immutable
class TxnPageState {
  const TxnPageState({
    this.rows = const <Txn>[],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  final List<Txn> rows;

  /// False once a short page has proved the end has been reached. There is no
  /// total count by design, so a page shorter than [txnPageSize] is the signal.
  final bool hasMore;

  /// True while one page request is in flight. Guards against a second request
  /// for the same offset, which would append the same rows twice.
  final bool isLoadingMore;

  /// Set when a page request failed. The rows already loaded stay on screen and
  /// the failure is offered as an inline retry at the end of the list.
  final String? loadMoreError;

  TxnPageState copyWith({
    List<Txn>? rows,
    bool? hasMore,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) => TxnPageState(
    rows: rows ?? this.rows,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    loadMoreError: clearLoadMoreError
        ? null
        : (loadMoreError ?? this.loadMoreError),
  );
}

/// Pages the full ledger through [TransactionRepository.fetchTransactionPage].
///
/// The first page resolves through the async value, so the existing skeleton and
/// failure rendering of requirement 3 covers the initial load. Every later page
/// is folded into the loaded data instead, because tearing a populated list back
/// down to its skeleton to append 20 rows would read as the screen flashing.
class TxnPagingController extends AsyncNotifier<TxnPageState> {
  @override
  Future<TxnPageState> build() async {
    final page = await ref
        .watch(transactionRepositoryProvider)
        .fetchTransactionPage(offset: 0, limit: txnPageSize);
    return TxnPageState(rows: page, hasMore: page.length == txnPageSize);
  }

  /// Requests the next [txnPageSize] rows and appends them.
  ///
  /// A no op while a request is in flight, once the end has been reached, or
  /// while a previous failure is waiting on its retry, so scrolling at the end
  /// of the list cannot queue several requests for the same offset.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null) return;
    if (current.isLoadingMore || !current.hasMore) return;
    if (current.loadMoreError != null) return;
    await _fetchNext(current);
  }

  /// Retries the page that failed, from the same offset.
  Future<void> retryLoadMore() async {
    final current = state.value;
    if (current == null || current.isLoadingMore) return;
    await _fetchNext(current);
  }

  Future<void> _fetchNext(TxnPageState current) async {
    final offset = current.rows.length;
    state = AsyncData(
      current.copyWith(isLoadingMore: true, clearLoadMoreError: true),
    );

    try {
      final page = await ref
          .read(transactionRepositoryProvider)
          .fetchTransactionPage(offset: offset, limit: txnPageSize);

      // Identity guard. A repeated page, whatever its cause, must not put the
      // same transaction on screen twice.
      final seen = <String>{for (final row in current.rows) row.id};
      final appended = <Txn>[
        ...current.rows,
        ...page.where((row) => seen.add(row.id)),
      ];

      state = AsyncData(
        TxnPageState(rows: appended, hasMore: page.length == txnPageSize),
      );
    } on RepositoryFailure catch (error) {
      state = AsyncData(
        current.copyWith(isLoadingMore: false, loadMoreError: error.message),
      );
    } catch (_) {
      state = AsyncData(
        current.copyWith(
          isLoadingMore: false,
          loadMoreError: 'We could not load more transactions.',
        ),
      );
    }
  }
}

/// The paged ledger. Declared here so the screen owns it; lift it into
/// `providers.dart` alongside the other transaction reads at integration.
final txnPagingProvider =
    AsyncNotifierProvider<TxnPagingController, TxnPageState>(
      TxnPagingController.new,
      retry: noAutomaticRetry,
    );

/// The seam requirement 15.11 writes through. The default reports where the
/// file would land and performs no IO, so no build and no test depends on a
/// platform path. Bind the device backed writer over this at composition time.
final txnExportWriterProvider = Provider<TxnExportWriter>(
  (ref) => stubTxnExportWriter,
);

/// Full ledger with search, filters, removable filter chips, paging, and export.
class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(txnFilterProvider).query,
  );

  /// Drives the end of list detection of requirement 15.10.
  final ScrollController _scroll = ScrollController();

  /// Distance from the end at which the next page is requested, so the rows
  /// arrive before the user meets the bottom.
  static const double _loadMoreThreshold = 240;

  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - _loadMoreThreshold) return;
    ref.read(txnPagingProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final filter = ref.watch(txnFilterProvider);
    final paging = ref.watch(txnPagingProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];

    // The filter is applied over what has been paged in, so every criterion
    // from the chips to the Empty_State reads against the rows on screen.
    final rows = paging.whenData(
      (page) => filter.apply(page.rows),
    );
    final loaded = paging.value;
    final filteredRows = rows.value ?? const <Txn>[];

    // Keep the field in step when another screen hands a query over.
    ref.listen(txnFilterProvider, (_, next) {
      if (next.query != _search.text) _search.text = next.query;
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          IconButton(
            onPressed: paging.hasValue && !_isExporting
                ? () => _export(filteredRows)
                : null,
            tooltip: 'Export CSV',
            icon: const Icon(Icons.download_rounded),
          ),
          IconButton(
            onPressed: () => _openFilters(context),
            tooltip: 'Filter transactions',
            icon: const Icon(Icons.filter_list_rounded),
          ),
          const SizedBox(width: Space.x2),
        ],
      ),
      body: ResponsiveShell(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.x5, 0, Space.x5, Space.x3),
              child: TextField(
                controller: _search,
                onChanged: (value) =>
                    ref.read(txnFilterProvider.notifier).setQuery(value),
                textInputAction: TextInputAction.search,
                style: AppType.bodyMedium.copyWith(color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search merchant or reference',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: filter.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            ref.read(txnFilterProvider.notifier).setQuery('');
                          },
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.all(AppRadius.pill),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.all(AppRadius.pill),
                    borderSide: BorderSide(color: tokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.all(AppRadius.pill),
                    borderSide: BorderSide(color: tokens.accent, width: 2),
                  ),
                ),
              ),
            ),
            if (!filter.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.x5,
                  0,
                  Space.x5,
                  Space.x2,
                ),
                child: _ActiveFilters(filter: filter, accounts: accounts),
              ),
            Expanded(
              child: RefreshIndicator(
                color: tokens.accent,
                onRefresh: () async {
                  ref.invalidate(txnPagingProvider);
                  await ref.read(txnPagingProvider.future);
                },
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(
                    Space.x5,
                    Space.x2,
                    Space.x5,
                    Space.x16 + Space.x8,
                  ),
                  children: [
                    AsyncSection<List<Txn>>(
                      value: rows,
                      onRetry: () => ref.invalidate(txnPagingProvider),
                      skeleton: const SkeletonRows(count: 7),
                      isEmpty: (data) => data.isEmpty,
                      empty: EmptyStateView(
                        heading: 'Nothing matches those filters',
                        message:
                            'Clear the filters to see every transaction again.',
                        actionLabel: 'Clear filters',
                        icon: Icons.filter_alt_off_rounded,
                        onAction: () {
                          _search.clear();
                          ref.read(txnFilterProvider.notifier).clear();
                        },
                      ),
                      builder: (data) => GroupedTransactions(
                        rows: data,
                        onSelect: (txn) => context.push('/txn/${txn.id}'),
                      ),
                    ),
                    if (loaded != null) _ListEnd(page: loaded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Requirement 15.11. Encodes the filtered rows, hands them to the writer
  /// seam, and reports the outcome including the count and the destination.
  Future<void> _export(List<Txn> rows) async {
    if (_isExporting) return;
    final messenger = ScaffoldMessenger.of(context);
    final writer = ref.read(txnExportWriterProvider);
    setState(() => _isExporting = true);

    String? destination;
    String? failure;
    try {
      destination = await writer(txnCsvFilename(), encodeTxnCsv(rows));
    } on RepositoryFailure catch (error) {
      failure = error.message;
    } catch (_) {
      failure = 'We could not save the file.';
    }

    if (!mounted) return;
    setState(() => _isExporting = false);

    final label = rows.length == 1 ? 'row' : 'rows';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          destination != null
              ? 'Exported ${rows.length} $label to $destination'
              : 'Export failed. $failure',
        ),
      ),
    );
  }

  void _openFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const _FilterSheet(),
    );
  }
}

/// The tail of the list: a bounded progress indicator while a page is in
/// flight, an inline retry when one failed, and an explicit control so a filter
/// that shortens the list past the fold can still reach further pages.
class _ListEnd extends ConsumerWidget {
  const _ListEnd({required this.page});

  final TxnPageState page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    if (page.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: Space.x5),
        child: Center(
          // Feedback: an indeterminate spinner marks one page request in
          // flight, bounded so it never grows into the list.
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final failure = page.loadMoreError;
    if (failure != null) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.x4),
        child: ErrorStateView(
          message: failure,
          onRetry: () => ref.read(txnPagingProvider.notifier).retryLoadMore(),
        ),
      );
    }

    if (page.hasMore) {
      return Padding(
        padding: const EdgeInsets.only(top: Space.x4),
        child: Center(
          child: TextButton(
            onPressed: () => ref.read(txnPagingProvider.notifier).loadMore(),
            child: const Text('Load more'),
          ),
        ),
      );
    }

    if (page.rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: Space.x5),
      child: Center(
        child: Text(
          'End of activity',
          style: AppType.labelMedium.copyWith(color: tokens.textSecondary),
        ),
      ),
    );
  }
}

class _ActiveFilters extends ConsumerWidget {
  const _ActiveFilters({required this.filter, required this.accounts});

  final TxnFilter filter;
  final List<Account> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(txnFilterProvider.notifier);
    final account = accounts
        .where((item) => item.id == filter.accountId)
        .firstOrNull;

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: Space.x2,
        runSpacing: Space.x2,
        children: [
          for (final type in filter.types)
            _RemovableChip(
              label: type.label,
              onRemove: () => controller.removeType(type),
            ),
          if (filter.range != TxnDateRange.anyTime)
            _RemovableChip(
              label: filter.range.label,
              onRemove: () => controller.setRange(TxnDateRange.anyTime),
            ),
          if (account != null)
            _RemovableChip(
              label: account.name,
              onRemove: () => controller.setAccount(null),
            ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Pressable(
      onTap: onRemove,
      semanticLabel: 'Remove filter $label',
      borderRadius: AppRadius.pill,
      minSize: 36,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x3,
          vertical: Space.x2,
        ),
        decoration: BoxDecoration(
          color: tokens.interactiveSecondary,
          borderRadius: AppRadius.all(AppRadius.pill),
          border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppType.labelMedium.copyWith(
                color: tokens.interactivePrimary,
              ),
            ),
            const SizedBox(width: Space.x1),
            Icon(
              Icons.close_rounded,
              size: 16,
              color: tokens.interactivePrimary,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final filter = ref.watch(txnFilterProvider);
    final controller = ref.read(txnFilterProvider.notifier);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x5, 0, Space.x5, Space.x5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Filter transactions',
              style: AppType.headlineMedium.copyWith(color: tokens.textPrimary),
            ),
            const SizedBox(height: Space.x5),
            _FilterGroupLabel('Type'),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final type in TxnType.values)
                  _ChoiceChipTile(
                    label: type.label,
                    selected: filter.types.contains(type),
                    onTap: () => controller.toggleType(type),
                  ),
              ],
            ),
            const SizedBox(height: Space.x5),
            _FilterGroupLabel('Date range'),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final range in TxnDateRange.values)
                  _ChoiceChipTile(
                    label: range.label,
                    selected: filter.range == range,
                    onTap: () => controller.setRange(range),
                  ),
              ],
            ),
            const SizedBox(height: Space.x5),
            _FilterGroupLabel('Account'),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                _ChoiceChipTile(
                  label: 'All accounts',
                  selected: filter.accountId == null,
                  onTap: () => controller.setAccount(null),
                ),
                for (final account in accounts)
                  _ChoiceChipTile(
                    label: account.name,
                    selected: filter.accountId == account.id,
                    onTap: () => controller.setAccount(account.id),
                  ),
              ],
            ),
            const SizedBox(height: Space.x6),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.clear,
                    child: const Text('Clear all'),
                  ),
                ),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Show results'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterGroupLabel extends StatelessWidget {
  const _FilterGroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.x3),
    child: Text(
      text,
      style: AppType.labelLarge.copyWith(color: context.tokens.textSecondary),
    ),
  );
}

class _ChoiceChipTile extends StatelessWidget {
  const _ChoiceChipTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Pressable(
      onTap: onTap,
      semanticLabel: '$label${selected ? ', selected' : ''}',
      borderRadius: AppRadius.pill,
      minSize: 40,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x3,
        ),
        decoration: BoxDecoration(
          color: selected ? tokens.interactiveSecondary : tokens.surface,
          borderRadius: AppRadius.all(AppRadius.pill),
          border: Border.all(
            color: selected ? tokens.accent : tokens.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: AppType.labelMedium.copyWith(
            color: selected ? tokens.interactivePrimary : tokens.textPrimary,
          ),
        ),
      ),
    );
  }
}
