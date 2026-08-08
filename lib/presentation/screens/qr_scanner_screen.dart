import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/providers.dart';
import '../../state/split_bills_controller.dart';
import '../widgets/camera_permission.dart';
import '../widgets/money_text.dart';

// ---------------------------------------------------------------------------
// QR Scanner Screen
// ---------------------------------------------------------------------------

/// Full camera QR scanner for split-bill payments.
///
/// Uses [mobile_scanner] for a real camera feed on Android and iOS.
/// Handles runtime camera-permission request, torch toggle, and app-lifecycle
/// pause/resume so the scanner never stays active when the app is backgrounded.
/// The overlay UI (corner brackets, status text, torch button) adapts to the
/// current light/dark theme while the camera preview always renders on a dark
/// background for maximum contrast.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({this.initialPayload, super.key});

  /// When non-null the scanner skips the camera and immediately processes
  /// this payload (used by the "Simulate Pay" button in detail screen).
  final String? initialPayload;

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _scanner;

  bool _torchOn = false;
  bool _processed = false; // guard: only handle the first valid scan
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanner = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    // If the caller passed a pre-built payload, skip camera entirely.
    if (widget.initialPayload != null && widget.initialPayload!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handlePayload(widget.initialPayload!);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause the scanner when the app goes to background; resume when it returns.
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _scanner.stop();
      case AppLifecycleState.resumed:
        if (!_processed) _scanner.start();
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Payload handling
  // -------------------------------------------------------------------------

  void _onDetect(BarcodeCapture capture) {
    if (_processed) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    _processed = true;
    _scanner.stop();
    _handlePayload(raw);
  }

  void _handlePayload(String rawPayload) {
    try {
      final data = jsonDecode(rawPayload) as Map<String, dynamic>;
      if (data['type'] == 'split_bill_payment') {
        _showPaymentConfirmation(
          billId: data['billId'] as String,
          participantId: data['participantId'] as String,
          participantName: data['participantName'] as String,
          billTitle: data['billTitle'] as String,
          amount: (data['amount'] as num).toDouble(),
        );
        return;
      }
      if (data['type'] == 'split_bill_join') {
        _showJoinConfirmation(
          billId: data['billId'] as String,
          billTitle: data['billTitle'] as String,
          totalAmount: (data['totalAmount'] as num).toDouble(),
          category: data['category'] as String? ?? '',
        );
        return;
      }
    } catch (_) {
      // not JSON – fall through
    }
    _showError('Unrecognised QR code. Please scan a FrostBank split-bill QR.');
    // Allow another scan attempt.
    _processed = false;
    _scanner.start();
  }

  void _showJoinConfirmation({
    required String billId,
    required String billTitle,
    required double totalAmount,
    required String category,
  }) {
    if (!mounted) return;
    final nameController = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final tokens = context.tokens;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.surfaceRaised,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Join Split Bill',
                  style: AppType.titleMedium.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '"$billTitle"',
                  style: AppType.bodyMedium
                      .copyWith(color: tokens.textSecondary),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Your name',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(sheetCtx).pop();
                          _processed = false;
                          _scanner.start();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) return;
                          Navigator.of(sheetCtx).pop();
                          await ref
                              .read(splitBillsProvider.notifier)
                              .joinBill(
                                billId: billId,
                                participantName: name,
                              );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Joined "$billTitle" as $name!',
                                ),
                                backgroundColor: Colors.green.shade700,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.group_add_rounded),
                        label: const Text('Join Bill'),
                        style: FilledButton.styleFrom(
                          backgroundColor: context.tokens.interactivePrimary,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _showPaymentConfirmation({
    required String billId,
    required String participantId,
    required String participantName,
    required String billTitle,
    required double amount,
  }) {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentConfirmationSheet(
        billId: billId,
        participantId: participantId,
        participantName: participantName,
        billTitle: billTitle,
        amount: amount,
        onSuccess: () {
          if (mounted) Navigator.of(context).pop(); // close sheet
          if (mounted) Navigator.of(context).pop(); // close scanner
        },
        onCancel: () {
          // Let the user scan again.
          _processed = false;
          _scanner.start();
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Torch toggle
  // -------------------------------------------------------------------------

  Future<void> _toggleTorch() async {
    await _scanner.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final isDark = tokens.isDark;

    // Overlay chrome colours – adapted for light/dark.
    final overlayBg = isDark
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.45);
    // Both branches of the previous ternary were the same literal, which was the
    // accent token spelled by hand. The viewport is dark in either theme, so the
    // bracket reads from the dark token set.
    final bracketColor = AppTokens.dark.accent;
    final labelBg = Colors.black.withValues(alpha: 0.65);

    return Scaffold(
      // Camera view always on a dark background for contrast.
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Scan QR to Pay'),
        actions: [
          // Torch / flash button
          IconButton(
            tooltip: _torchOn ? 'Flash off' : 'Flash on',
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _torchOn
                    ? Icons.flash_on_rounded
                    : Icons.flash_off_rounded,
                key: ValueKey(_torchOn),
                color: _torchOn ? Colors.amber : Colors.white,
              ),
            ),
            onPressed: _toggleTorch,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _permissionDenied
          ? CameraPermissionDeniedView(
              onRetry: () => setState(() => _permissionDenied = false),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // ── Real camera feed ──────────────────────────────────────
                MobileScanner(
                  controller: _scanner,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) {
                    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _permissionDenied = true);
                      });
                    }
                    return _CameraErrorView(error: error);
                  },
                ),

                // ── Dark vignette overlay (4 semi-transparent panels) ─────
                _ScannerOverlay(
                  overlayColor: overlayBg,
                  bracketColor: bracketColor,
                  frameSize: 260,
                ),

                // ── Hint label below the frame ────────────────────────────
                Positioned(
                  bottom: MediaQuery.of(context).size.height * 0.28,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: labelBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Align the QR code inside the frame',
                        style: AppType.bodySmall.copyWith(color: Colors.white),
                      ),
                    ),
                  ),
                ),

                // ── Torch status chip ─────────────────────────────────────
                if (_torchOn)
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 60,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flash_on_rounded,
                                size: 14, color: Colors.black),
                            SizedBox(width: 4),
                            Text(
                              'Flash on',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scanner overlay – dark vignette + animated corner brackets
// ---------------------------------------------------------------------------

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({
    required this.overlayColor,
    required this.bracketColor,
    required this.frameSize,
  });

  final Color overlayColor;
  final Color bracketColor;
  final double frameSize;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final frameL = (screenW - frameSize) / 2;
    final frameT = (screenH - frameSize) / 2 - 40;

    return Stack(
      children: [
        // Top panel
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: frameT,
          child: ColoredBox(color: overlayColor),
        ),
        // Bottom panel
        Positioned(
          top: frameT + frameSize,
          left: 0,
          right: 0,
          bottom: 0,
          child: ColoredBox(color: overlayColor),
        ),
        // Left panel
        Positioned(
          top: frameT,
          left: 0,
          width: frameL,
          height: frameSize,
          child: ColoredBox(color: overlayColor),
        ),
        // Right panel
        Positioned(
          top: frameT,
          left: frameL + frameSize,
          right: 0,
          height: frameSize,
          child: ColoredBox(color: overlayColor),
        ),
        // Corner brackets
        Positioned(
          top: frameT,
          left: frameL,
          child: _CornerBrackets(
            size: frameSize,
            color: bracketColor,
            strokeWidth: 3.5,
            bracketLength: 28,
            borderRadius: 8,
          ),
        ),
      ],
    );
  }
}

/// Draws the four corner L-shaped brackets of the scan frame.
class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets({
    required this.size,
    required this.color,
    required this.strokeWidth,
    required this.bracketLength,
    required this.borderRadius,
  });

  final double size;
  final Color color;
  final double strokeWidth;
  final double bracketLength;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _BracketPainter(
          color: color,
          strokeWidth: strokeWidth,
          bracketLength: bracketLength,
          radius: borderRadius,
        ),
      ),
    );
  }
}

class _BracketPainter extends CustomPainter {
  _BracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.bracketLength,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double bracketLength;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bl = bracketLength;
    final r = radius;
    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, bl + r)
        ..lineTo(0, r)
        ..arcToPoint(Offset(r, 0), radius: Radius.circular(r))
        ..lineTo(bl + r, 0),
      paint,
    );
    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - bl - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: Radius.circular(r))
        ..lineTo(w, bl + r),
      paint,
    );
    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - bl - r)
        ..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h), radius: Radius.circular(r))
        ..lineTo(bl + r, h),
      paint,
    );
    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - bl - r, h)
        ..lineTo(w - r, h)
        ..arcToPoint(Offset(w, h - r), radius: Radius.circular(r))
        ..lineTo(w, h - bl - r),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _BracketPainter old) =>
      old.color != color || old.strokeWidth != strokeWidth;
}

// ---------------------------------------------------------------------------
// Error / permission views
// ---------------------------------------------------------------------------

class _CameraErrorView extends StatelessWidget {
  const _CameraErrorView({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                'Camera unavailable',
                style: AppType.titleMedium.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                error.errorDetails?.message ?? error.errorCode.name,
                style: AppType.bodySmall.copyWith(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The permission denied view now lives in
// lib/presentation/widgets/camera_permission.dart, shared with the QR payment
// screen, and carries the settings control requirement 17.5 asks for.

// ---------------------------------------------------------------------------
// Payment confirmation bottom sheet
// ---------------------------------------------------------------------------

class _PaymentConfirmationSheet extends ConsumerStatefulWidget {
  const _PaymentConfirmationSheet({
    required this.billId,
    required this.participantId,
    required this.participantName,
    required this.billTitle,
    required this.amount,
    required this.onSuccess,
    required this.onCancel,
  });

  final String billId;
  final String participantId;
  final String participantName;
  final String billTitle;
  final double amount;
  final VoidCallback onSuccess;
  final VoidCallback onCancel;

  @override
  ConsumerState<_PaymentConfirmationSheet> createState() =>
      _PaymentConfirmationSheetState();
}

class _PaymentConfirmationSheetState
    extends ConsumerState<_PaymentConfirmationSheet> {
  String? _selectedAccountId;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final accountsAsync = ref.watch(accountsProvider);
    final currency = ref.watch(preferencesProvider).activeCurrency;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: tokens.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.interactiveSecondary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.qr_code_rounded,
                  color: tokens.interactivePrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm QR Payment',
                      style: AppType.titleMedium.copyWith(
                        color: tokens.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      widget.billTitle,
                      style: AppType.bodySmall.copyWith(
                        color: tokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Amount row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Paying for',
                      style: AppType.labelSmall.copyWith(
                          color: tokens.textSecondary),
                    ),
                    Text(
                      widget.participantName,
                      style: AppType.titleSmall.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                MoneyText(
                  widget.amount,
                  style: AppType.numericMedium,
                  color: tokens.textPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account selector
          Text(
            'Pay from account',
            style: AppType.labelMedium.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: 8),
          accountsAsync.when(
            data: (accounts) => DropdownButtonFormField<String>(
              initialValue: _selectedAccountId ?? accounts.firstOrNull?.id,
              decoration: InputDecoration(
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: accounts
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text(
                        '${a.name}  (${currency.symbol}${a.availableBalance.toStringAsFixed(2)})',
                        style: AppType.bodyMedium.copyWith(
                            color: tokens.textPrimary),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedAccountId = v),
            ),
            loading: () => const LinearProgressIndicator(),
            error: (_, stack) => Text(
              'Could not load accounts',
              style: AppType.bodySmall.copyWith(color: tokens.error),
            ),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          widget.onCancel();
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.textPrimary,
                    side: BorderSide(color: tokens.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isProcessing ? null : _confirm,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isProcessing ? 'Processing…' : 'Confirm Payment'),
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.interactivePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);

    final accountsAsync = ref.read(accountsProvider);
    final accountId =
        _selectedAccountId ?? accountsAsync.value?.firstOrNull?.id;
    final currency = ref.read(preferencesProvider).activeCurrency;

    final success = await ref.read(splitBillsProvider.notifier).confirmPayment(
          billId: widget.billId,
          participantId: widget.participantId,
          payingAccountId: accountId,
          currencyCode: currency.code,
        );

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment of ${ref.read(preferencesProvider).activeCurrency.symbol}'
            '${widget.amount.toStringAsFixed(2)} confirmed!',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green.shade700,
        ),
      );
      widget.onSuccess();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment failed. Please try again.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
      widget.onCancel();
    }
  }
}
