import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_bank_app/core/design/theme.dart';
import 'package:mobile_bank_app/core/format/txn_csv.dart';
import 'package:mobile_bank_app/data/mock_data_source.dart';
import 'package:mobile_bank_app/domain/models.dart';
import 'package:mobile_bank_app/domain/repositories.dart';
import 'package:mobile_bank_app/presentation/screens/transaction_history_screen.dart';
import 'package:mobile_bank_app/presentation/widgets/states.dart';
import 'package:mobile_bank_app/presentation/widgets/transaction_list.dart';
import 'package:mobile_bank_app/state/providers.dart';

/// The seeded world, clock pinned so the ledger is identical on every run.
MockDataSource _source() =>
    MockDataSource(now: DateTime(2026, 8, 5))
      ..latencyOverride = (() => Duration.zero);

/// Wraps the real mock repository and records every page request, so the tests
/// can assert on offsets, on concurrency, and on failure of one page only.
class _SpyTransactionRepository implements TransactionRepository {
  _SpyTransactionRepository(this._source);

  final MockDataSource _source;

  /// Every page request, in order.
  final List<({int offset, int limit})> pageCalls =
      <({int offset, int limit})>[];

  /// When set, the next request parks until this completes, which is how the
  /// concurrency guard is observed.
  Completer<void>? gate;

  /// When true, the next request fails and then clears itself.
  bool failNextPage = false;

  int callsAtOffset(int offset) =>
      pageCalls.where((call) => call.offset == offset).length;

  @override
  Future<List<Txn>> fetchTransactionPage({
    String? accountId,
    required int offset,
    required int limit,
  }) async {
    pageCalls.add((offset: offset, limit: limit));
    final parked = gate;
    if (parked != null) await parked.future;
    if (failNextPage) {
      failNextPage = false;
      throw const RepositoryFailure('We could not load more transactions.');
    }
    return _source.transactionPage(
      accountId: accountId,
      offset: offset,
      limit: limit,
    );
  }

  @override
  Future<List<Txn>> fetchTransactions({String? accountId}) =>
      _source.transactions(accountId: accountId);

  @override
  Future<Txn> fetchTransaction(String id) => _source.transaction(id);
}

/// Records what the screen handed to the export seam, and can fail on demand.
class _SpyExportWriter {
  String? filename;
  String? contents;
  int calls = 0;
  bool fail = false;

  Future<String> write(String name, String body) async {
    calls++;
    filename = name;
    contents = body;
    if (fail) throw const RepositoryFailure('Storage is full.');
    return 'Downloads/$name';
  }
}

Widget _harness(
  MockDataSource source, {
  TransactionRepository? repository,
  TxnExportWriter? writer,
}) => ProviderScope(
  retry: noAutomaticRetry,
  overrides: [
    mockDataSourceProvider.overrideWithValue(source),
    if (repository != null)
      transactionRepositoryProvider.overrideWithValue(repository),
    if (writer != null) txnExportWriterProvider.overrideWithValue(writer),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const TransactionHistoryScreen(),
  ),
);

/// The screen's own container, so a test can drive the shared filter state
/// without going through the sheet.
ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(TransactionHistoryScreen)),
    );

/// Scrolls to the end of the loaded list, which is what requirement 15.10
/// describes as the trigger for the next page.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await tester.drag(find.byType(ListView), const Offset(0, -4000));
  await tester.pumpAndSettle();
}

int _rowCount(WidgetTester tester) =>
    tester.widgetList(find.byType(TransactionRow)).length;

/// One row, for the encoder tests. Every field is supplied so the quoting rules
/// can be exercised on real user data positions.
Txn _txn({
  String id = 'txn_001',
  String merchant = 'Ludlow Coffee House',
  String category = 'Dining',
  String reference = 'REF001',
  String? note,
  double amount = 6.85,
  TxnDirection direction = TxnDirection.outflow,
}) => Txn(
  id: id,
  accountId: 'acc_wallet',
  merchant: merchant,
  category: category,
  amount: amount,
  currencyCode: 'USD',
  direction: direction,
  type: TxnType.cardPurchase,
  status: TxnStatus.completed,
  date: DateTime(2026, 8, 5, 8, 12),
  reference: reference,
  note: note,
);

void main() {
  group('Requirement 15.10, paging the Transaction_History_Screen', () {
    testWidgets(
      '15.10 the first load requests one page of 20 and renders 20 rows, not '
      'the whole seeded ledger of 44',
      (tester) async {
        final spy = _SpyTransactionRepository(_source());
        await tester.pumpWidget(_harness(_source(), repository: spy));
        await tester.pumpAndSettle();

        expect(spy.pageCalls, [(offset: 0, limit: 20)]);
        expect(_rowCount(tester), 20);
      },
    );

    testWidgets(
      '15.10 scrolling to the end of the loaded list requests the next 20 and '
      'appends them, so the visible count grows',
      (tester) async {
        final spy = _SpyTransactionRepository(_source());
        await tester.pumpWidget(_harness(_source(), repository: spy));
        await tester.pumpAndSettle();

        expect(_rowCount(tester), 20);

        await _scrollToEnd(tester);

        expect(spy.callsAtOffset(20), 1);
        expect(spy.pageCalls.last, (offset: 20, limit: 20));
        expect(_rowCount(tester), 40);
      },
    );

    testWidgets(
      '15.10 reaching the true end stops requesting, and no transaction is '
      'rendered twice',
      (tester) async {
        final spy = _SpyTransactionRepository(_source());
        await tester.pumpWidget(_harness(_source(), repository: spy));
        await tester.pumpAndSettle();

        // Three pages cover the seeded 44 rows: 20, 20, then a short 4.
        for (var attempt = 0; attempt < 4; attempt++) {
          await _scrollToEnd(tester);
        }

        expect(_rowCount(tester), 44);
        expect(spy.pageCalls, [
          (offset: 0, limit: 20),
          (offset: 20, limit: 20),
          (offset: 40, limit: 20),
        ]);

        // A short page proved the end, so further scrolling asks for nothing.
        await _scrollToEnd(tester);
        expect(spy.pageCalls.length, 3);
        expect(find.text('End of activity'), findsOneWidget);
        expect(find.text('Load more'), findsNothing);

        final ids = tester
            .widgetList<TransactionRow>(find.byType(TransactionRow))
            .map((row) => row.txn.id)
            .toList();
        expect(ids.toSet().length, ids.length);
      },
    );

    test(
      '15.10 two concurrent page requests are never issued for the same offset',
      () async {
        final spy = _SpyTransactionRepository(_source());
        final container = ProviderContainer(
          overrides: [
            transactionRepositoryProvider.overrideWithValue(spy),
          ],
        );
        addTearDown(container.dispose);

        await container.read(txnPagingProvider.future);
        expect(container.read(txnPagingProvider).value!.rows.length, 20);

        final gate = Completer<void>();
        spy.gate = gate;
        final controller = container.read(txnPagingProvider.notifier);

        final first = controller.loadMore();
        // The second call arrives while the first is in flight and must be a
        // no op rather than a second request for offset 20.
        await controller.loadMore();
        await controller.loadMore();

        expect(spy.callsAtOffset(20), 1);
        expect(container.read(txnPagingProvider).value!.isLoadingMore, isTrue);

        spy.gate = null;
        gate.complete();
        await first;

        expect(spy.callsAtOffset(20), 1);
        expect(container.read(txnPagingProvider).value!.rows.length, 40);
      },
    );

    testWidgets(
      '15.10 a failed page renders an inline retry at the end of the list '
      'without dropping the rows already loaded',
      (tester) async {
        final spy = _SpyTransactionRepository(_source());
        await tester.pumpWidget(_harness(_source(), repository: spy));
        await tester.pumpAndSettle();

        // A filter shortens the list, so the end of list control is on screen
        // and the failure can be driven without a long scroll.
        _containerOf(tester).read(txnFilterProvider.notifier).setQuery('ludlow');
        await tester.pumpAndSettle();
        expect(_rowCount(tester), 3);

        spy.failNextPage = true;
        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();

        // The failure is inline at the end, and the loaded rows survived it.
        expect(find.byType(ErrorStateView), findsOneWidget);
        expect(
          find.text('We could not load more transactions.'),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        expect(_rowCount(tester), 3);

        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(find.byType(ErrorStateView), findsNothing);
        expect(spy.callsAtOffset(20), 2);
        // Two further Ludlow rows sit in the second page.
        expect(_rowCount(tester), 5);
      },
    );

    testWidgets(
      '15.10 a page in flight renders a bounded progress indicator at the end '
      'of the list',
      (tester) async {
        final spy = _SpyTransactionRepository(_source());
        await tester.pumpWidget(_harness(_source(), repository: spy));
        await tester.pumpAndSettle();

        _containerOf(tester).read(txnFilterProvider.notifier).setQuery('ludlow');
        await tester.pumpAndSettle();

        final gate = Completer<void>();
        spy.gate = gate;
        await tester.tap(find.text('Load more'));
        await tester.pump();

        final indicator = find.byType(CircularProgressIndicator);
        expect(indicator, findsOneWidget);
        expect(tester.getSize(indicator), const Size(24, 24));
        expect(find.text('Load more'), findsNothing);

        spy.gate = null;
        gate.complete();
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });

  group('Requirement 15.11, exporting the filtered result', () {
    testWidgets(
      '15.11 the screen renders an export control that writes the filtered '
      'rows and displays the result',
      (tester) async {
        final writer = _SpyExportWriter();
        await tester.pumpWidget(_harness(_source(), writer: writer.write));
        await tester.pumpAndSettle();

        // Icon only control, so requirement 4.1 needs a label on it. The label
        // doubles as the finder here.
        final control = find.byTooltip('Export CSV');
        expect(control, findsOneWidget);

        // Requirement 4.2. The icon box is Material's 40 by 40, expanded by the
        // button to a 48 by 48 gesture target.
        final target = find.ancestor(of: control, matching: find.byType(IconButton));
        expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(target).height, greaterThanOrEqualTo(48));

        _containerOf(tester).read(txnFilterProvider.notifier).setQuery('ludlow');
        await tester.pumpAndSettle();
        expect(_rowCount(tester), 3);

        await tester.tap(control);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 750));

        expect(writer.calls, 1);
        expect(writer.filename, endsWith('.csv'));

        // The filtered rows were written, not the whole loaded page.
        final lines = writer.contents!.trim().split(txnCsvLineEnding);
        expect(lines.length, 4);
        expect(lines.first, startsWith('Date,Merchant'));
        expect(
          lines.skip(1).where((line) => line.contains('Ludlow')).length,
          3,
        );
        expect(writer.contents, isNot(contains('Verdant Grocers')));

        // Requirement 15.11 second half: the outcome, with count and target.
        expect(
          find.text('Exported 3 rows to Downloads/${writer.filename}'),
          findsOneWidget,
        );
      },
    );

    testWidgets('15.11 a failing writer displays a failure message', (
      tester,
    ) async {
      final writer = _SpyExportWriter()..fail = true;
      await tester.pumpWidget(_harness(_source(), writer: writer.write));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));

      expect(writer.calls, 1);
      expect(find.text('Export failed. Storage is full.'), findsOneWidget);
      expect(find.textContaining('Exported'), findsNothing);
    });
  });

  group('Requirement 15.11, encodeTxnCsv', () {
    test('15.11 emits a header row naming every column', () {
      final csv = encodeTxnCsv(<Txn>[]);

      expect(csv, 'Date,Merchant,Category,Type,Status,Direction,Amount,'
          'Currency,Reference,Note$txnCsvLineEnding');
    });

    test('15.11 quotes a merchant that carries a comma', () {
      final csv = encodeTxnCsv([_txn(merchant: 'Verdant Grocers, Halden')]);

      expect(csv, contains('"Verdant Grocers, Halden"'));
      expect(csv.trim().split(txnCsvLineEnding).length, 2);
    });

    test('15.11 quotes a merchant that carries a double quote, doubling it', () {
      final csv = encodeTxnCsv([_txn(merchant: 'The "Blue" Door')]);

      expect(csv, contains('"The ""Blue"" Door"'));
    });

    test('15.11 quotes a note that carries a newline', () {
      final csv = encodeTxnCsv([_txn(note: 'Split with Ana\nPaid back Friday')]);

      expect(csv, contains('"Split with Ana\nPaid back Friday"'));
      // The embedded newline stays inside one quoted field, so the document is
      // still a header row plus one record.
      expect(csv.split(txnCsvLineEnding).where((l) => l.isNotEmpty).length, 2);
    });

    test('15.11 leaves an ordinary field unquoted', () {
      expect(encodeTxnCsvField('Ludlow Coffee House'), 'Ludlow Coffee House');
      expect(encodeTxnCsvField(''), '');
    });

    test('15.11 writes the signed amount and the direction of each row', () {
      final csv = encodeTxnCsv([
        _txn(amount: 6.85),
        _txn(
          id: 'txn_002',
          amount: 240,
          direction: TxnDirection.inflow,
        ),
      ]);

      expect(csv, contains('-6.85,USD'));
      expect(csv, contains('Outflow'));
      expect(csv, contains('240.00,USD'));
      expect(csv, contains('Inflow'));
    });
  });

  group('Requirements 15.5 to 15.8, filtering still holds under paging', () {
    testWidgets(
      '15.5 and 15.6 applied filters render as removable chips, and removing '
      'one keeps the rest',
      (tester) async {
        await tester.pumpWidget(_harness(_source()));
        await tester.pumpAndSettle();

        final filter = _containerOf(tester).read(txnFilterProvider.notifier)
          ..toggleType(TxnType.deposit)
          ..toggleType(TxnType.qrPayment);
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Remove filter Deposit'), findsOneWidget);
        expect(
          find.bySemanticsLabel('Remove filter QR payment'),
          findsOneWidget,
        );

        await tester.tap(find.bySemanticsLabel('Remove filter Deposit'));
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('Remove filter Deposit'), findsNothing);
        expect(
          find.bySemanticsLabel('Remove filter QR payment'),
          findsOneWidget,
        );
        expect(
          _containerOf(tester).read(txnFilterProvider).types,
          {TxnType.qrPayment},
        );

        filter.clear();
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Remove filter QR payment'), findsNothing);
      },
    );

    testWidgets(
      '15.8 a filter matching nothing in the loaded pages renders the '
      'Empty_State, and its action clears the filter',
      (tester) async {
        await tester.pumpWidget(_harness(_source()));
        await tester.pumpAndSettle();

        _containerOf(
          tester,
        ).read(txnFilterProvider.notifier).setQuery('zznotamerchant');
        await tester.pumpAndSettle();

        expect(find.byType(EmptyStateView), findsOneWidget);
        expect(find.text('Nothing matches those filters'), findsOneWidget);
        expect(_rowCount(tester), 0);
        // The filter matched nothing in the pages loaded so far, so the control
        // that reaches further pages stays available under the Empty_State.
        expect(find.text('Load more'), findsOneWidget);

        await tester.tap(find.text('Clear filters'));
        await tester.pumpAndSettle();

        expect(find.byType(EmptyStateView), findsNothing);
        expect(_containerOf(tester).read(txnFilterProvider).isEmpty, isTrue);
        // The loaded page is intact, so clearing the filter costs no refetch.
        expect(_rowCount(tester), 20);
      },
    );

    testWidgets(
      '15.7 search stays case insensitive over the paged rows, and paging on '
      'keeps the filter applied',
      (tester) async {
        final spy = _SpyTransactionRepository(_source());
        await tester.pumpWidget(_harness(_source(), repository: spy));
        await tester.pumpAndSettle();

        _containerOf(tester).read(txnFilterProvider.notifier).setQuery('LUDLOW');
        await tester.pumpAndSettle();
        expect(_rowCount(tester), 3);

        await tester.tap(find.text('Load more'));
        await tester.pumpAndSettle();

        expect(spy.callsAtOffset(20), 1);
        // Still filtered, now over 40 loaded rows.
        expect(_rowCount(tester), 5);
      },
    );
  });
}
