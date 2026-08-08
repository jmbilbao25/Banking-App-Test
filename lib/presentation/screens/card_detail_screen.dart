import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/card_carousel.dart';
import '../widgets/card_face.dart';
import '../widgets/money_text.dart';
import '../widgets/motion_effects.dart';
import '../widgets/pressable.dart';
import '../widgets/states.dart';
import '../widgets/surfaces.dart';
import 'new_card_sheet.dart';

/// Card detail. The deck at the top, the balance of whichever card faces the
/// holder, and that card's details below with PIN authentication security.
class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({required this.cardId, super.key});

  final String cardId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  int? _index;
  bool _revealed = false;

  Future<void> _copy(BankCard card) async {
    await Clipboard.setData(
      ClipboardData(text: card.number.replaceAll(' ', '')),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Card number copied'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<bool> _promptPinVerification(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController(text: '');
    final tokens = context.tokens;
    final verified = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Icon(Icons.lock_rounded, color: tokens.accent, size: 20),
            const SizedBox(width: Space.x2),
            Expanded(
              child: Text(
                title,
                style: AppType.titleMedium.copyWith(color: tokens.textPrimary),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: AppType.bodySmall.copyWith(color: tokens.textSecondary),
            ),
            const SizedBox(height: Space.x4),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              autofocus: true,
              textAlign: TextAlign.center,
              style: AppType.numericHero.copyWith(
                fontSize: 24,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '••••••',
                counterText: '',
                filled: true,
                fillColor: tokens.interactiveSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(color: tokens.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: tokens.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () {
              // Checked against the stored digest. The previous literal
              // comparison accepted a known PIN on every card in the build.
              if (ref.read(pinVaultProvider).verify(controller.text.trim())) {
                Navigator.of(ctx).pop(true);
              } else {
                HapticFeedback.vibrate();
              }
            },
            style: FilledButton.styleFrom(backgroundColor: tokens.accent),
            child: const Text('Verify PIN'),
          ),
        ],
      ),
    );
    controller.dispose();
    return verified ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId.isEmpty ? 'Cards' : 'Card Details'),
        actions: [
          IconButton(
            onPressed: () async {
              if (_revealed) {
                setState(() => _revealed = false);
              } else {
                final ok = await _promptPinVerification(
                  context,
                  title: 'Security Verification',
                  message: 'Enter your 6-digit PIN to reveal full card details.',
                );
                if (ok && mounted) {
                  setState(() => _revealed = true);
                }
              }
            },
            tooltip: _revealed ? 'Hide card details' : 'Reveal card details (PIN required)',
            icon: Icon(
              _revealed
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
            ),
          ),
          const SizedBox(width: Space.x1),
        ],
      ),
      body: ResponsiveShell(
        child: AsyncSection<List<BankCard>>(
          value: cards,
          onRetry: () => ref.invalidate(cardsProvider),
          skeleton: const _DetailSkeleton(),
          isEmpty: (rows) => rows.isEmpty,
          empty: EmptyStateView(
            heading: 'No cards yet',
            message: 'Add a card to see its details here.',
            actionLabel: 'Add card',
            icon: Icons.credit_card_rounded,
            onAction: () => showNewCardSheet(context),
          ),
          builder: (rows) {
            final startIndex = rows.indexWhere(
              (card) => card.id == widget.cardId,
            );
            final initial = startIndex < 0 ? 0 : startIndex;
            final activeIndex = (_index ?? initial).clamp(0, rows.length - 1);
            final card = rows[activeIndex];

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                0,
                Space.x2,
                0,
                Space.x16 + Space.x16,
              ),
              children: [
                FadeSlideIn(
                  duration: Motion.long,
                  offset: const Offset(0, 28),
                  scaleFrom: 0.9,
                  child: CardCarousel(
                    cards: rows,
                    initialIndex: initial,
                    onPageChanged: (value) => setState(() {
                      _index = value;
                      // A new card in front never inherits the previous card's
                      // revealed digits.
                      _revealed = false;
                    }),
                  ),
                ),
                const SizedBox(height: Space.x6),
                CardValueSwap(
                  child: Column(
                    key: ValueKey(card.id),
                    children: [
                      MoneyText(
                        card.balance,
                        style: AppType.numericHero.copyWith(fontSize: 36),
                        currencyCode: card.currencyCode,
                        label: '${card.label} balance',
                      ),
                      const SizedBox(height: Space.x1),
                      Text(
                        '${card.label} \u2022 ${card.kind.label}',
                        style: AppType.bodySmall.copyWith(
                          color: context.tokens.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.x6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const FadeSlideIn(
                        index: 1,
                        child: SectionHeader(title: 'Card info'),
                      ),
                      FadeSlideIn(
                        index: 2,
                        child: DetailRow(
                          label: 'Card number',
                          value: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: _RevealedNumber(
                              card: card,
                              revealed: _revealed,
                            ),
                          ),
                          trailing: IconButton(
                            onPressed: () => _copy(card),
                            tooltip: 'Copy card number',
                            icon: const Icon(Icons.copy_rounded, size: 18),
                          ),
                        ),
                      ),
                      FadeSlideIn(
                        index: 3,
                        child: DetailRow(
                          label: 'CVC',
                          value: NumericText(
                            _revealed ? card.cvc : '\u2022\u2022\u2022',
                            style: AppType.numericMedium,
                            label: _revealed ? 'CVC ${card.cvc}' : 'CVC hidden',
                          ),
                        ),
                      ),
                      FadeSlideIn(
                        index: 4,
                        child: DetailRow(
                          label: 'Expiry date',
                          value: NumericText(
                            card.expiry,
                            style: AppType.numericMedium,
                            label: 'Expires ${card.expiry}',
                          ),
                        ),
                      ),
                      FadeSlideIn(
                        index: 5,
                        child: DetailRow(
                          label: 'Card holder',
                          value: Text(card.holderName),
                        ),
                      ),
                      FadeSlideIn(
                        index: 6,
                        child: DetailRow(
                          label: 'Status',
                          value: Align(
                            alignment: Alignment.centerLeft,
                            child: StatusPill(
                              label: card.status.label,
                              color: card.status == CardStatus.frozen
                                  ? context.tokens.info
                                  : context.tokens.success,
                            ),
                          ),
                          trailing: Pressable(
                            onTap: () async {
                              final okPin = await _promptPinVerification(
                                context,
                                title: 'Security PIN Required',
                                message:
                                    'Enter your 6-digit PIN to confirm card state update.',
                              );
                              if (!okPin || !context.mounted) return;

                              final controller = ref.read(
                                cardsControllerProvider.notifier,
                              );
                              await controller.toggleFreeze(card.id);
                              if (!context.mounted) return;

                              final state = ref.read(cardsControllerProvider);
                              final message = switch (state) {
                                CardSuccess(:final card) =>
                                  card.status == CardStatus.frozen
                                      ? '${card.label} is now frozen.'
                                      : '${card.label} is now active.',
                                CardError(:final message) => message,
                                _ => 'Something went wrong.',
                              };
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(message),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Space.x3,
                                vertical: Space.x1 + 2,
                              ),
                              decoration: BoxDecoration(
                                color: context.tokens.interactiveSecondary,
                                borderRadius: AppRadius.all(AppRadius.pill),
                                border: Border.all(color: context.tokens.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    card.status == CardStatus.frozen
                                        ? Icons.lock_open_rounded
                                        : Icons.ac_unit_rounded,
                                    size: 14,
                                    color: context.tokens.accent,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    card.status == CardStatus.frozen
                                        ? 'Unfreeze'
                                        : 'Freeze',
                                    style: AppType.labelSmall.copyWith(
                                      color: context.tokens.accent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RevealedNumber extends StatelessWidget {
  const _RevealedNumber({required this.card, required this.revealed});

  final BankCard card;
  final bool revealed;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.resolve(context, Motion.short),
        switchInCurve: Motion.standard,
        switchOutCurve: Motion.standard,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previousChildren, ?currentChild],
        ),
        child: NumericText(
          revealed ? card.number : card.maskedNumber,
          key: ValueKey(revealed),
          style: AppType.numericMedium,
          label: revealed
              ? 'Card number ${card.number}'
              : 'Card number ending ${card.last4}',
        ),
      );
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(
                height: CardCarousel.heightFor(constraints.maxWidth),
                child: Center(
                  child: CardFaceSkeleton(
                    width: CardCarousel.cardWidthFor(constraints.maxWidth),
                  ),
                ),
              ),
              const SizedBox(height: Space.x2),
              const SkeletonBlock(width: 60, height: 7, radius: AppRadius.pill),
              const SizedBox(height: Space.x6),
              const SkeletonBlock(width: 190, height: 34),
              const SizedBox(height: Space.x6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: Space.x5),
                child: SkeletonRows(count: 4),
              ),
            ],
          ),
        ),
      );
}
