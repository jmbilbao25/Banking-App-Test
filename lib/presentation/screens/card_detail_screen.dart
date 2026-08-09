import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../widgets/app_lock_confirm.dart';
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

  /// The card whose freeze or thaw is in flight.
  ///
  /// This is the input `CardFace.pending` was written for and never received.
  /// `pendingCardId` was declared on the carousel, threaded down to the face, and
  /// supplied by nobody, so `_FrostDriveState._nucleation` was unreachable and the
  /// face sat still between the tap and the repository answering. The frost only
  /// started once `cardsProvider` was invalidated and the status came back
  /// changed, which is the wrong moment: the acknowledgment belongs on the frame
  /// the finger lifts.
  String? _pendingCardId;

  /// Requirement 13.8 holds the full number on screen for 10 seconds and then
  /// returns to the masked rendering, so a revealed card cannot be left visible.
  static const _revealWindow = Duration(seconds: 10);
  Timer? _remaskTimer;

  @override
  void dispose() {
    _remaskTimer?.cancel();
    super.dispose();
  }

  /// The one path into a freeze or a thaw.
  ///
  /// Same shape as [_toggleReveal] and for the same reason: one place asks
  /// App_Lock, so a second entry point cannot forget to. The pending id is set
  /// before the await and cleared in a finally, so a failed write leaves the face
  /// where it started rather than stuck part frozen.
  Future<void> _toggleFreeze(BankCard card) async {
    if (_pendingCardId != null) return;

    final okPin = await confirmWithAppLock(
      context,
      ref,
      reason: 'Confirm changing the state of this card.',
    );
    if (!okPin || !mounted) return;

    setState(() => _pendingCardId = card.id);
    try {
      await ref.read(cardsControllerProvider.notifier).toggleFreeze(card.id);
    } finally {
      if (mounted) setState(() => _pendingCardId = null);
    }
    if (!mounted) return;

    final state = ref.read(cardsControllerProvider);
    final message = switch (state) {
      CardSuccess(:final card) => card.status == CardStatus.frozen
          ? '${card.label} is now frozen.'
          : '${card.label} is now active.',
      CardError(:final message) => message,
      _ => 'Something went wrong.',
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  /// The one path in and out of the revealed state.
  ///
  /// Both the control in the app bar and a tap on the card itself come through
  /// here, so there is exactly one place App_Lock is asked and exactly one place
  /// the reveal clock is started. An earlier version had the gate inlined in the
  /// app bar, which is the kind of thing that ends up with a second entry point
  /// that forgot to ask.
  Future<void> _toggleReveal() async {
    if (_revealed) {
      _mask();
      return;
    }
    final ok = await confirmWithAppLock(
      context,
      ref,
      reason: 'Confirm to reveal your full card number.',
    );
    if (ok && mounted) _reveal();
  }

  void _reveal() {
    _remaskTimer?.cancel();
    setState(() => _revealed = true);
    _remaskTimer = Timer(_revealWindow, () {
      if (mounted) setState(() => _revealed = false);
    });
  }

  void _mask() {
    _remaskTimer?.cancel();
    setState(() => _revealed = false);
  }

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

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(cardsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.cardId.isEmpty ? 'Cards' : 'Card Details'),
        actions: [
          IconButton(
            onPressed: _toggleReveal,
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
                    // The face answers the tap on the frame the finger lifts,
                    // rather than waiting for the write to come back.
                    pendingCardId: _pendingCardId,
                    // Turned over only while the reveal is live, so the clock in
                    // requirement 13.8 turns the card back on its own.
                    revealedCardId: _revealed ? card.id : null,
                    // Tapping the card in front is the same request the control
                    // in the app bar makes, and it goes through the same gate.
                    // The card is the obvious thing to touch when you want what
                    // is on the card, but it must not become a way around
                    // App_Lock.
                    onCardTap: (_) => _toggleReveal(),
                    onPageChanged: (value) {
                      // A new card in front never inherits the previous card's
                      // revealed digits, and the remask timer is cancelled so it
                      // cannot fire against the wrong card.
                      _remaskTimer?.cancel();
                      setState(() {
                        _index = value;
                        _revealed = false;
                      });
                    },
                  ),
                ),
                const SizedBox(height: Space.x5),
                // Directly under the deck, and that is the whole point of its
                // position. It used to be the trailing control of the Status row,
                // roughly 800 logical pixels down, which meant reaching it
                // scrolled the card off the top of the screen: a 740 millisecond
                // freeze played in full on a face nobody could see. It is also
                // now in the thumb zone rather than at the far end of a scroll.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.x5),
                  child: _FreezeControl(
                    card: card,
                    working: _pendingCardId == card.id,
                    onPressed: () => _toggleFreeze(card),
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
                          // No control here any more. The action lives under the
                          // deck where the animation it triggers is visible, and
                          // two buttons for one intent is worse than a walk.
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


/// Freeze and unfreeze, directly under the deck.
///
/// Full width rather than a pill in a row, because it is the primary action on
/// this screen and it now has to look like one. Its whole state is on its face:
/// what it will do, what it is doing, and what the card currently is.
///
/// The label is the action, never the state, so the button never reads as a
/// status badge you could mistake for a control. The card behind it carries the
/// state, twice: the frost itself, and the word FROZEN on the face for anyone who
/// cannot use the frost to tell.
class _FreezeControl extends StatelessWidget {
  const _FreezeControl({
    required this.card,
    required this.working,
    required this.onPressed,
  });

  final BankCard card;

  /// A write is in flight. The control holds its position and says so rather than
  /// disappearing or letting a second tap through.
  final bool working;

  final VoidCallback onPressed;

  bool get _frozen => card.status == CardStatus.frozen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    final label = working
        ? (_frozen ? 'Unfreezing card' : 'Freezing card')
        : (_frozen ? 'Unfreeze card' : 'Freeze card');

    return Semantics(
      button: true,
      enabled: !working,
      label: label,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: working ? null : onPressed,
          borderRadius: AppRadius.pill,
          haptic: false,
          child: SizedBox(
            // Above the 48 floor both platforms ask for, and the same height as
            // the primary action on every task screen.
            height: Layout.minTapTarget + Space.x1,
            width: double.infinity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: AppRadius.all(AppRadius.pill),
                // Frozen reads cold and recessed, active reads warm and raised,
                // so the button's own surface says which way the card currently
                // sits before the label is read.
                color: _frozen
                    ? tokens.info.withValues(alpha: 0.12)
                    : tokens.interactiveSecondary,
                border: Border.all(
                  color: _frozen
                      ? tokens.info.withValues(alpha: 0.45)
                      : tokens.border,
                ),
              ),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // State transition: the glyph swaps on the same band as the
                    // frost it triggers, so the control and the card read as one
                    // event rather than two.
                    AnimatedSwitcher(
                      duration: Motion.resolve(context, Motion.short),
                      switchInCurve: Motion.standard,
                      switchOutCurve: Motion.standard,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: working
                          ? SizedBox.square(
                              key: const ValueKey('working'),
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _frozen
                                    ? tokens.info
                                    : tokens.interactivePrimary,
                              ),
                            )
                          : Icon(
                              _frozen
                                  ? Icons.lock_open_rounded
                                  : Icons.ac_unit_rounded,
                              key: ValueKey(_frozen),
                              size: 18,
                              color: _frozen
                                  ? tokens.info
                                  : tokens.interactivePrimary,
                            ),
                    ),
                    const SizedBox(width: Space.x2),
                    Text(
                      label,
                      style: AppType.labelLarge.copyWith(
                        color: _frozen
                            ? tokens.info
                            : tokens.interactivePrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
