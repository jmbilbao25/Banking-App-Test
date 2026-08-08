import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../state/split_bills_controller.dart';
import '../widgets/brand.dart';
import '../widgets/money_text.dart';
import '../widgets/qr_painter.dart';
import '../widgets/surfaces.dart';
import 'qr_scanner_screen.dart';

// ---------------------------------------------------------------------------
// Split Bill QR Screen
// ---------------------------------------------------------------------------

/// Displays a real, scannable QR code for a participant's payment share.
///
/// Two tabs:
///   • "Pay" — participant scans this to pay their share.
///   • "Join" — any new user scans this to join the bill as a participant.
class SplitBillQrScreen extends ConsumerStatefulWidget {
  const SplitBillQrScreen({
    required this.billId,
    required this.participantId,
    super.key,
  });

  final String billId;
  final String participantId;

  @override
  ConsumerState<SplitBillQrScreen> createState() => _SplitBillQrScreenState();
}

class _SplitBillQrScreenState extends ConsumerState<SplitBillQrScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final bills = ref.watch(splitBillsProvider);

    final billMatch = bills.where((b) => b.id == widget.billId);
    if (billMatch.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment QR')),
        body: const Center(child: Text('Bill not found.')),
      );
    }

    final bill = billMatch.first;
    final pMatch = bill.participants.where((p) => p.id == widget.participantId);
    if (pMatch.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Payment QR')),
        body: const Center(child: Text('Participant not found.')),
      );
    }

    final participant = pMatch.first;
    final payPayload = participant.generateQrPayload(bill.id, bill.title);
    final joinPayload = bill.joinQrPayload;

    return Scaffold(
      backgroundColor: tokens.background,
      appBar: AppBar(
        backgroundColor: tokens.background,
        title: const Text('QR Codes'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.payment_rounded), text: 'Payment QR'),
            Tab(icon: Icon(Icons.group_add_rounded), text: 'Join QR'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── Payment QR ──────────────────────────────────────────────────
          _PaymentQrTab(
            bill: bill,
            participant: participant,
            payload: payPayload,
          ),
          // ── Join QR ─────────────────────────────────────────────────────
          _JoinQrTab(
            bill: bill,
            payload: joinPayload,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Payment QR tab
// ---------------------------------------------------------------------------

class _PaymentQrTab extends ConsumerWidget {
  const _PaymentQrTab({
    required this.bill,
    required this.participant,
    required this.payload,
  });

  final dynamic bill;
  final dynamic participant;
  final String payload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;

    return ResponsiveShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.x5,
          Space.x4,
          Space.x5,
          Space.x16,
        ),
        children: [
          // ── Header gradient card ─────────────────────────────────────────
          FrostBackdrop(
            borderRadius: AppRadius.all(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: Column(
                children: [
                  Text(
                    'Payment Request',
                    style: AppType.labelMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    participant.name,
                    style: AppType.headlineMedium.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    bill.title,
                    style: AppType.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.x4),
                  MoneyText(
                    participant.shareAmount,
                    style: AppType.numericHero,
                    color: Colors.white,
                    label: 'Payment amount',
                  ),
                  const SizedBox(height: Space.x6),

                  // ── Real scannable QR ────────────────────────────────────
                  QrCodeWidget(
                    data: payload,
                    size: 220,
                    // White bg always — needed for scanner contrast.
                    backgroundColor: Colors.white,
                    // The QR card is white in both themes, so its control reads the
                    // light token set rather than the active one.
                    foregroundColor: AppTokens.light.textPrimary,
                  ),

                  const SizedBox(height: Space.x6),
                  _InfoNote(
                    text:
                        'Scan this QR code with the FrostBank app to pay '
                        "${participant.name}'s share of ${bill.title}.",
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.x5),

          // ── Copy payload ─────────────────────────────────────────────────
          _CopyButton(
            label: 'Copy Payment Payload',
            value: payload,
          ),
          const SizedBox(height: Space.x3),

          // ── Scan & Pay ───────────────────────────────────────────────────
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => QrScannerScreen(initialPayload: payload),
              ),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan and pay'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: Space.x4),
              backgroundColor: tokens.interactivePrimary,
              foregroundColor: Colors.white,
              elevation: 4,
              textStyle: AppType.labelLarge.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: Space.x3),
          OutlinedButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else if (context.canPop()) {
                context.pop();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.textPrimary,
              side: BorderSide(color: tokens.border),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Join QR tab
// ---------------------------------------------------------------------------

class _JoinQrTab extends StatelessWidget {
  const _JoinQrTab({required this.bill, required this.payload});

  final dynamic bill;
  final String payload;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ResponsiveShell(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          Space.x5,
          Space.x4,
          Space.x5,
          Space.x16,
        ),
        children: [
          // ── Header gradient card ─────────────────────────────────────────
          FrostBackdrop(
            borderRadius: AppRadius.all(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(Space.x6),
              child: Column(
                children: [
                  Text(
                    'Join This Bill',
                    style: AppType.labelMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                  ),
                  const SizedBox(height: Space.x1),
                  Text(
                    bill.title,
                    style: AppType.headlineMedium.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    '${bill.totalCount} participant${bill.totalCount == 1 ? '' : 's'} · '
                    '${bill.category}',
                    style: AppType.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.76),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: Space.x2),
                  MoneyText(
                    bill.totalAmount,
                    style: AppType.numericHero,
                    color: Colors.white,
                    label: 'Total bill amount',
                  ),
                  const SizedBox(height: Space.x6),

                  // ── Real scannable join QR ────────────────────────────────
                  QrCodeWidget(
                    data: payload,
                    size: 220,
                    backgroundColor: Colors.white,
                    // The QR card is white in both themes, so its control reads the
                    // light token set rather than the active one.
                    foregroundColor: AppTokens.light.textPrimary,
                  ),

                  const SizedBox(height: Space.x6),
                  _InfoNote(
                    icon: Icons.group_add_rounded,
                    text:
                        'Share this QR code so others can scan it and '
                        'join "${bill.title}" as a participant.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.x5),

          _CopyButton(
            label: 'Copy Join Payload',
            value: payload,
          ),
          const SizedBox(height: Space.x3),

          OutlinedButton(
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else if (context.canPop()) {
                context.pop();
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: tokens.textPrimary,
              side: BorderSide(color: tokens.border),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _InfoNote extends StatelessWidget {
  const _InfoNote({
    required this.text,
    this.icon = Icons.info_outline_rounded,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.x3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: AppRadius.all(AppRadius.md),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: Space.x3),
          Expanded(
            child: Text(
              text,
              style: AppType.bodySmall.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.label, required this.value});
  final String label;
  final String value;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return OutlinedButton.icon(
      onPressed: _copy,
      icon: Icon(_copied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
      label: Text(_copied ? 'Copied!' : widget.label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _copied ? tokens.success : tokens.interactivePrimary,
        side: BorderSide(
          color: _copied ? tokens.success : tokens.border,
        ),
      ),
    );
  }
}
