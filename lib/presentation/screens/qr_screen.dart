import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/format/money.dart';
import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../../state/providers.dart';
import '../widgets/app_lock_confirm.dart';
import '../widgets/brand.dart';
import '../widgets/camera_permission.dart';
import '../widgets/money_form.dart';
import '../widgets/money_text.dart';
import '../widgets/qr_painter.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'transaction_history_screen.dart' show txnPagingProvider;

/// QR payments.
///
/// Two surfaces behind one brand region: a code that asks to be paid, and a
/// camera that pays one. The previous version built both out of literals, with
/// twelve hex colours, a corporate blue that appears nowhere in the brand sheet,
/// grey shade fills, five different radii and an `isDark` branch on almost every
/// line. It also debited a flat hundred regardless of what was scanned, and
/// never told the customer who they were paying.
///
/// This rebuild carries the same vocabulary as Transfer and Deposit:
/// [MoneyFormScaffold] for the brand region and the content sheet, [SheetField]
/// and [AmountField] for input, [AccountSelectField] for the account, and
/// [MoneyReviewRow] plus [MoneyOutcomeSheet] for the confirmation and the
/// receipt. Requirement 17.7 still gates the debit behind App_Lock, and
/// requirement 17.5 still hands the viewport to [CameraPermissionDeniedView]
/// when the camera has been refused.

/// A payment request resolved from a scanned or a typed code.
///
/// Requirement 17.6 asks for a merchant and an amount on screen before anything
/// is debited, so a code that cannot produce both cannot be paid.
@immutable
class QRPaymentRequest {
  const QRPaymentRequest({
    required this.code,
    required this.merchant,
    required this.amount,
  });

  final String code;
  final String merchant;

  /// Base currency figure, the same unit the repository debits in.
  final double amount;
}

/// Where the pay surface is: at the viewport, typing a code, or reviewing one.
enum _PayStage { scanning, entering, review }

class QRScreen extends ConsumerStatefulWidget {
  const QRScreen({super.key});

  /// Requirement 17.8, stated once so the widget test asserts the copy the
  /// screen actually renders rather than a second copy of it.
  static const String unrecognisedCodeMessage =
      'We do not recognise that payment code. Please check it and try again.';

  /// Mock data: the merchant directory this build resolves payment codes
  /// against. A terminal prints one of these codes, the customer scans it or
  /// types it, and the merchant and the amount come back for confirmation.
  static const Map<String, ({String merchant, double amount})>
  paymentCodeDirectory = {
    '204815': (merchant: 'Solene Bakery', amount: 18.40),
    '118342': (merchant: 'Halden Transit Authority', amount: 3.25),
    '552907': (merchant: 'Lumen Mobile', amount: 55.00),
    '731064': (merchant: 'Ludlow Coffee House', amount: 6.85),
  };

  /// Length of a printed payment code.
  static const int codeLength = 6;

  /// Resolves a scanned payload or a typed code against the directory.
  ///
  /// Returns null when nothing resolves, which is what requirement 17.8 turns
  /// into a message and a resumed scan.
  static QRPaymentRequest? resolveCode(String raw) {
    var text = raw.trim();
    const scheme = 'frostbank://pay?code=';
    if (text.toLowerCase().startsWith(scheme)) {
      text = text.substring(scheme.length);
    }
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != codeLength) return null;
    final entry = paymentCodeDirectory[digits];
    if (entry == null) return null;
    return QRPaymentRequest(
      code: digits,
      merchant: entry.merchant,
      amount: entry.amount,
    );
  }

  @override
  ConsumerState<QRScreen> createState() => _QRScreenState();
}

class _QRScreenState extends ConsumerState<QRScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// The camera lives on the second tab, so the first frame of this screen
  /// never brings a camera session up. Selecting it starts the scanner and
  /// leaving it stops the scanner again.
  static const int _payTabIndex = 1;

  /// A QR symbol has to hold printed contrast to stay machine readable, so the
  /// plate and the modules resolve from the light token set in both themes, for
  /// the same reason the viewport resolves from the dark one.
  static const AppTokens _codeTokens = AppTokens.light;

  /// Tall enough that [CameraPermissionDeniedView] fits inside it, because that
  /// view replaces the preview in place rather than taking the whole screen.
  static const double _viewportHeight = Space.x16 * 6;
  static const double _frameSide = Space.x16 * 2.5;
  static const double _codeSize = Space.x16 * 3.5;

  late final TabController _tabController;

  /// Started and stopped from here rather than by the preview widget, because
  /// this screen already owns the lifecycle: the pay tab starts it, leaving the
  /// tab stops it, backgrounding stops it, and `dispose` releases it. Leaving
  /// `autoStart` on would add a second, uncoordinated start inside the preview's
  /// `initState`, and the two would race.
  final MobileScannerController _scannerController = MobileScannerController(
    autoStart: false,
  );

  final _receiveAmount = TextEditingController();
  final _typedCode = TextEditingController();

  int _tabIndex = 0;
  _PayStage _stage = _PayStage.scanning;
  QRPaymentRequest? _pending;

  String? _receiveAccountId;
  String? _sourceAccountId;

  String? _codeError;
  String? _payError;
  bool _submitting = false;
  bool _torchOn = false;

  /// Requirement 17.5: the viewport is replaced by an explanation and a control
  /// that opens the operating system settings when permission is refused.
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChange);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _receiveAmount.dispose();
    _typedCode.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Scanner lifecycle
  // ---------------------------------------------------------------------------

  void _handleTabChange() {
    final index = _tabController.index;
    if (index == _tabIndex) return;
    _tabIndex = index;
    if (index == _payTabIndex) {
      if (_stage == _PayStage.scanning) _startScanner();
    } else {
      _stopScanner();
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera never stays live while the application is in the background.
    switch (state) {
      case AppLifecycleState.resumed:
        if (_tabIndex == _payTabIndex && _stage == _PayStage.scanning) {
          _startScanner();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _stopScanner();
    }
  }

  /// Starting and stopping are best effort. A device with no camera reports
  /// through the scanner's own error builder, so a throw here is not a failure
  /// the customer needs to be told about twice.
  Future<void> _startScanner() async {
    try {
      await _scannerController.start();
    } on Object {
      return;
    }
  }

  Future<void> _stopScanner() async {
    try {
      await _scannerController.stop();
    } on Object {
      return;
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
    } on Object {
      if (!mounted) return;
      _showNotice('The torch is not available right now.');
      return;
    }
    if (!mounted) return;
    setState(() => _torchOn = !_torchOn);
  }

  // ---------------------------------------------------------------------------
  // Code handling
  // ---------------------------------------------------------------------------

  void _handleDetection(BarcodeCapture capture) {
    if (_stage != _PayStage.scanning) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;

    _stopScanner();
    final request = QRScreen.resolveCode(raw);
    if (request == null) {
      // Requirement 17.8: say so, then carry on scanning.
      _showNotice(QRScreen.unrecognisedCodeMessage);
      _resumeScanning();
      return;
    }
    // Requirement 17.6: the resolved merchant and amount are shown for
    // confirmation. Nothing has been debited at this point.
    setState(() {
      _pending = request;
      _stage = _PayStage.review;
      _payError = null;
    });
  }

  void _openManualEntry() {
    _stopScanner();
    setState(() {
      _stage = _PayStage.entering;
      _codeError = null;
    });
  }

  void _resolveTypedCode() {
    final request = QRScreen.resolveCode(_typedCode.text);
    if (request == null) {
      // The typed path keeps the field so the code can be corrected, where the
      // scanned path resumes the camera instead.
      setState(() => _codeError = QRScreen.unrecognisedCodeMessage);
      return;
    }
    setState(() {
      _pending = request;
      _stage = _PayStage.review;
      _codeError = null;
      _payError = null;
    });
  }

  void _resumeScanning() {
    setState(() {
      _stage = _PayStage.scanning;
      _pending = null;
      _codeError = null;
      _payError = null;
      _submitting = false;
    });
    if (_tabIndex == _payTabIndex) _startScanner();
  }

  /// Plain language only. A raw exception never reaches the customer.
  void _showNotice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // The debit
  // ---------------------------------------------------------------------------

  Future<void> _pay(Account source) async {
    if (_submitting) return;
    final request = _pending;
    if (request == null) return;

    final preferences = ref.read(preferencesProvider);
    final shown = Money.format(
      Money.convert(request.amount, toCurrency: preferences.currencyCode),
      currencyCode: preferences.currencyCode,
    );

    if (source.availableBalance < request.amount) {
      setState(
        () => _payError =
            'That is more than the available balance in ${source.name}.',
      );
      return;
    }

    // Requirement 17.7: App_Lock confirms the customer before any balance is
    // reduced. A refusal leaves the account untouched and resumes scanning.
    final confirmed = await confirmWithAppLock(
      context,
      ref,
      reason: 'Confirm paying $shown to ${request.merchant}.',
    );
    if (!mounted) return;
    if (!confirmed) {
      _resumeScanning();
      return;
    }

    setState(() {
      _submitting = true;
      _payError = null;
    });

    try {
      await ref.read(accountRepositoryProvider).transfer(
        fromAccountId: source.id,
        recipient: request.merchant,
        amount: request.amount,
        note: 'QR payment',
      );

      ref.invalidate(accountsProvider);
      ref.invalidate(accountProvider(source.id));
      ref.invalidate(transactionsProvider);
      ref.invalidate(txnPagingProvider);
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _pending = null;
        _stage = _PayStage.scanning;
        _typedCode.clear();
      });

      await MoneyOutcomeSheet.show(
        context,
        succeeded: true,
        heading: 'Payment sent',
        detail: 'You paid ${request.merchant} $shown from ${source.name}.',
        reference: request.code,
      );
      if (!mounted) return;
      Navigator.of(context).maybePop();
    } on RepositoryFailure catch (failure) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // The repository writes in plain language, and nothing left the account.
      _showNotice('${failure.message} No money left ${source.name}.');
      _resumeScanning();
    } on Object {
      if (!mounted) return;
      setState(() => _submitting = false);
      _showNotice(
        'That payment did not go through. No money left ${source.name}.',
      );
      _resumeScanning();
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  bool get _onPayTab => _tabIndex == _payTabIndex;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final rows = accounts.hasValue ? accounts.requireValue : const <Account>[];
    final headerAccount = rows.isEmpty
        ? null
        : (_onPayTab ? _resolveSource(rows) : _resolveReceiver(rows));

    return MoneyFormScaffold(
      title: 'QR payments',
      subtitle: _subtitle,
      header: headerAccount == null
          ? null
          : AccountContextCard(account: headerAccount),
      children: [
        _TabSelector(controller: _tabController),
        const SizedBox(height: Space.x6),
        AsyncSection<List<Account>>(
          value: accounts,
          onRetry: () => ref.invalidate(accountsProvider),
          skeleton: const _QRSkeleton(),
          isEmpty: (data) => data.isEmpty,
          empty: EmptyStateView(
            icon: Icons.account_balance_rounded,
            heading: 'No account to use',
            message: 'Open an account before you send or receive a payment.',
            actionLabel: 'Go back',
            onAction: () => Navigator.of(context).maybePop(),
          ),
          builder: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _onPayTab
                ? _payTab(data, _resolveSource(data))
                : _generateTab(data, _resolveReceiver(data)),
          ),
        ),
      ],
    );
  }

  String get _subtitle {
    if (!_onPayTab) return 'Set an amount and show this code to be paid.';
    return switch (_stage) {
      _PayStage.scanning => 'Point the camera at a merchant payment code.',
      _PayStage.entering => 'Type the code printed on the merchant terminal.',
      _PayStage.review => 'Check the merchant and the amount before you pay.',
    };
  }

  Account _resolveReceiver(List<Account> rows) {
    _receiveAccountId ??= rows.first.id;
    return rows.firstWhere(
      (account) => account.id == _receiveAccountId,
      orElse: () => rows.first,
    );
  }

  Account _resolveSource(List<Account> rows) {
    _sourceAccountId ??= rows.first.id;
    return rows.firstWhere(
      (account) => account.id == _sourceAccountId,
      orElse: () => rows.first,
    );
  }

  // ---------------------------------------------------------------------------
  // Generate tab
  // ---------------------------------------------------------------------------

  double get _requestedAmount =>
      double.tryParse(_receiveAmount.text.trim()) ?? 0;

  /// The payload the code carries. Empty until an amount has been entered, so
  /// the surface never renders a code that asks for nothing.
  String _payload(Account receiver) {
    final amount = _requestedAmount;
    if (amount <= 0) return '';
    final code = ref.read(preferencesProvider).currencyCode;
    return 'frostbank://pay?to=${receiver.shortCode}'
        '&amount=${amount.toStringAsFixed(2)}&currency=$code';
  }

  List<Widget> _generateTab(List<Account> rows, Account receiver) {
    final tokens = context.tokens;
    final currency = ref.watch(preferencesProvider).currencyCode;
    final payload = _payload(receiver);

    return [
      const SheetFieldLabel('Amount to receive'),
      AmountField(
        controller: _receiveAmount,
        helperText: 'The payer sees this amount when they scan.',
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: Space.x5),
      const SheetFieldLabel('Paid into'),
      AccountSelectField(
        accounts: rows,
        selectedId: receiver.id,
        onChanged: (id) => setState(() => _receiveAccountId = id),
      ),
      const SizedBox(height: Space.x6),
      if (payload.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Space.x6),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: AppRadius.all(AppRadius.lg),
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            children: [
              Icon(
                Icons.qr_code_2_rounded,
                size: Space.x10,
                color: tokens.textSecondary,
              ),
              const SizedBox(height: Space.x3),
              Text(
                'Enter an amount to build your code.',
                textAlign: TextAlign.center,
                style: AppType.bodyMedium.copyWith(color: tokens.textSecondary),
              ),
            ],
          ),
        )
      else ...[
        Center(
          child: QrCodeWidget(
            data: payload,
            size: _codeSize,
            foregroundColor: _codeTokens.textPrimary,
            backgroundColor: _codeTokens.surfaceRaised,
          ),
        ),
        const SizedBox(height: Space.x6),
        MoneyReviewRow(
          label: 'Requested',
          emphasised: true,
          value: MoneyText(
            _requestedAmount,
            currencyCode: currency,
            style: AppType.numericLarge,
            maskable: false,
            label: 'Requested amount',
          ),
        ),
        MoneyReviewRow(
          label: 'Paid into',
          value: Text(
            receiver.name,
            style: AppType.bodyMedium.copyWith(color: tokens.textPrimary),
          ),
        ),
        const SoftDivider(inset: 0),
        const SizedBox(height: Space.x3),
        const SheetFieldLabel('Code payload'),
        NumericText(
          payload,
          style: AppType.numericSmall,
          color: tokens.textSecondary,
          label: 'Payment code payload',
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // Pay tab
  // ---------------------------------------------------------------------------

  List<Widget> _payTab(List<Account> rows, Account source) => switch (_stage) {
    _PayStage.scanning => _scanStage(),
    _PayStage.entering => _entryStage(),
    _PayStage.review => _reviewStage(rows, source),
  };

  List<Widget> _scanStage() {
    final tokens = context.tokens;
    return [
      _Viewport(
        permissionDenied: _permissionDenied,
        onPermissionRetry: () => setState(() => _permissionDenied = false),
        onPermissionDenied: () {
          if (mounted) setState(() => _permissionDenied = true);
        },
        controller: _scannerController,
        onDetect: _handleDetection,
        torchOn: _torchOn,
        onToggleTorch: _toggleTorch,
      ),
      const SizedBox(height: Space.x4),
      Text(
        'Hold the code inside the frame. It is read automatically.',
        style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
      ),
      const SizedBox(height: Space.x4),
      // Requirement 17.4, third control: a code can be paid without a camera.
      SizedBox(
        width: double.infinity,
        height: Layout.minTapTarget,
        child: TextButton.icon(
          onPressed: _openManualEntry,
          icon: const Icon(Icons.keyboard_rounded, size: 18),
          label: const Text('Enter code'),
        ),
      ),
    ];
  }

  List<Widget> _entryStage() {
    final tokens = context.tokens;
    return [
      const SheetFieldLabel('Payment code'),
      SheetField(
        controller: _typedCode,
        numeric: true,
        hint: '000000',
        maxLength: QRScreen.codeLength,
        errorText: _codeError,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _resolveTypedCode(),
        onChanged: (_) {
          if (_codeError != null) setState(() => _codeError = null);
        },
      ),
      const SizedBox(height: Space.x3),
      Text(
        'The merchant terminal shows a six digit code beside the total.',
        style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
      ),
      const SizedBox(height: Space.x6),
      PrimaryAction(
        label: 'Find merchant',
        icon: Icons.search_rounded,
        onPressed: _resolveTypedCode,
      ),
      const SizedBox(height: Space.x2),
      SizedBox(
        width: double.infinity,
        height: Layout.minTapTarget,
        child: TextButton(
          onPressed: _resumeScanning,
          child: const Text('Use camera'),
        ),
      ),
    ];
  }

  /// Requirement 17.6: merchant, amount and source, all before the debit.
  List<Widget> _reviewStage(List<Account> rows, Account source) {
    final tokens = context.tokens;
    final request = _pending!;
    final currency = ref.watch(preferencesProvider).currencyCode;

    return [
      Semantics(
        header: true,
        child: Text(
          'Confirm payment',
          style: AppType.titleLarge.copyWith(color: tokens.textPrimary),
        ),
      ),
      const SizedBox(height: Space.x4),
      MoneyReviewRow(
        label: 'Merchant',
        value: Flexible(
          child: Text(
            request.merchant,
            textAlign: TextAlign.right,
            style: AppType.titleSmall.copyWith(color: tokens.textPrimary),
          ),
        ),
      ),
      MoneyReviewRow(
        label: 'Payment code',
        value: NumericText(
          request.code,
          style: AppType.numericSmall,
          color: tokens.textSecondary,
          label: 'Payment code ${request.code}',
        ),
      ),
      const SizedBox(height: Space.x2),
      const SoftDivider(inset: 0),
      MoneyReviewRow(
        label: 'Total to debit',
        emphasised: true,
        value: MoneyText(
          request.amount,
          currencyCode: currency,
          style: AppType.numericLarge,
          maskable: false,
          label: 'Total to debit',
        ),
      ),
      const SizedBox(height: Space.x4),
      const SheetFieldLabel('Pay from'),
      AccountSelectField(
        accounts: rows,
        selectedId: source.id,
        onChanged: (id) => setState(() {
          _sourceAccountId = id;
          _payError = null;
        }),
      ),
      if (_payError != null) ...[
        const SizedBox(height: Space.x4),
        InlineFormError(_payError!),
      ],
      const SizedBox(height: Space.x6),
      PrimaryAction(
        label: 'Pay now',
        busy: _submitting,
        icon: Icons.lock_rounded,
        onPressed: () => _pay(source),
      ),
      const SizedBox(height: Space.x2),
      SizedBox(
        width: double.infinity,
        height: Layout.minTapTarget,
        child: TextButton(
          onPressed: _submitting ? null : _resumeScanning,
          child: const Text('Cancel'),
        ),
      ),
    ];
  }
}

/// The two tabs, in the content sheet rather than under an app bar, so the
/// brand region above stays the same one every money screen uses.
class _TabSelector extends StatelessWidget {
  const _TabSelector({required this.controller});

  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return SizedBox(
      width: double.infinity,
      child: TabBar(
        controller: controller,
        labelColor: tokens.accent,
        unselectedLabelColor: tokens.textSecondary,
        indicatorColor: tokens.accent,
        dividerColor: tokens.border,
        labelStyle: AppType.labelLarge,
        unselectedLabelStyle: AppType.labelLarge,
        // Requirement 4.2: the tab itself is a full height target.
        tabs: const [
          Tab(height: Layout.minTapTarget, text: 'My code'),
          Tab(height: Layout.minTapTarget, text: 'Scan to pay'),
        ],
      ),
    );
  }
}

/// The camera frame, its scrim, and the torch control.
///
/// Requirement 17.4 asks for all three. Every colour resolves from the dark
/// token set, because a preview needs a dark surround whichever theme is on.
class _Viewport extends StatelessWidget {
  const _Viewport({
    required this.permissionDenied,
    required this.onPermissionRetry,
    required this.onPermissionDenied,
    required this.controller,
    required this.onDetect,
    required this.torchOn,
    required this.onToggleTorch,
  });

  final bool permissionDenied;
  final VoidCallback onPermissionRetry;
  final VoidCallback onPermissionDenied;
  final MobileScannerController controller;
  final void Function(BarcodeCapture capture) onDetect;
  final bool torchOn;
  final VoidCallback onToggleTorch;

  static const AppTokens _tokens = AppTokens.dark;

  /// The shared denial view sits inside the frame rather than taking the whole
  /// screen, so at a larger text scale its content can exceed the frame. It
  /// scrolls instead of clipping, and still fills the frame when it fits, which
  /// is what requirement 4.3 asks of every region that holds text.
  static Widget _denied(VoidCallback onRetry) => SingleChildScrollView(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: _QRScreenState._viewportHeight,
      ),
      child: CameraPermissionDeniedView(onRetry: onRetry),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final scrim = _tokens.background.withValues(alpha: 0.55);

    return ClipRRect(
      borderRadius: AppRadius.all(AppRadius.lg),
      child: SizedBox(
        height: _QRScreenState._viewportHeight,
        width: double.infinity,
        child: ColoredBox(
          color: _tokens.background,
          child: permissionDenied
              // Requirement 17.5.
              ? _denied(onPermissionRetry)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: controller,
                      onDetect: onDetect,
                      errorBuilder: (context, error) {
                        if (error.errorCode ==
                            MobileScannerErrorCode.permissionDenied) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onPermissionDenied();
                          });
                        }
                        return _denied(onPermissionRetry);
                      },
                    ),
                    IgnorePointer(child: _ScanScrim(scrim: scrim)),
                    Positioned(
                      top: Space.x3,
                      right: Space.x3,
                      // Requirement 4.1: an icon only control is named, and the
                      // name states the state the torch is in right now.
                      // Requirement 4.2: the control is a 48 pixel target.
                      child: GlassIconButton(
                        icon: torchOn
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        label: torchOn ? 'Torch on' : 'Torch off',
                        onTap: onToggleTorch,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _ScanScrim extends StatelessWidget {
  const _ScanScrim({required this.scrim});

  final Color scrim;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: ColoredBox(color: scrim)),
      SizedBox(
        height: _QRScreenState._frameSide,
        child: Row(
          children: [
            Expanded(child: ColoredBox(color: scrim)),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: _Viewport._tokens.accent,
                  width: 2,
                ),
                borderRadius: AppRadius.all(AppRadius.md),
              ),
              child: const SizedBox.square(
                dimension: _QRScreenState._frameSide,
              ),
            ),
            Expanded(child: ColoredBox(color: scrim)),
          ],
        ),
      ),
      Expanded(child: ColoredBox(color: scrim)),
    ],
  );
}

/// Shape matched to the generate tab: two label and field pairs, then the code
/// plate, per requirement 3.1.
class _QRSkeleton extends StatelessWidget {
  const _QRSkeleton();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var field = 0; field < 2; field++) ...[
        const SkeletonBlock(width: 96, height: 12),
        const SizedBox(height: Space.x2),
        const SkeletonBlock(height: 56, radius: AppRadius.md),
        const SizedBox(height: Space.x5),
      ],
      const Center(
        child: SkeletonBlock(
          width: _QRScreenState._codeSize,
          height: _QRScreenState._codeSize,
          radius: AppRadius.lg,
        ),
      ),
    ],
  );
}
