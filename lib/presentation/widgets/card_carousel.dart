import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design/motion.dart';
import '../../core/design/tokens.dart';
import '../../domain/models.dart';
import 'card_face.dart';
import 'pressable.dart';

/// Swipeable deck of card faces.
///
/// The swipe drives a real rotation rather than a slide: the outgoing card turns
/// away from the finger while the incoming one turns to face the holder, so the
/// gesture reads as handling a stack of physical cards. Position, tilt, scale,
/// elevation, and the specular highlight are all continuous functions of the
/// page offset, which means the deck tracks the finger and never snaps.
///
/// Under reduced motion the rotation and the tilt drop out and the deck falls
/// back to a plain cross fade.
class CardCarousel extends StatefulWidget {
  const CardCarousel({
    required this.cards,
    required this.onPageChanged,
    this.onCardTap,
    this.initialIndex = 0,
    this.showDots = true,
    this.pendingCardId,
    this.revealedCardId,
    this.dotColor,
    this.dotTrackColor,
    super.key,
  });

  final List<BankCard> cards;

  /// Fires as soon as the deck crosses the halfway point toward a new card, so
  /// content below the deck keeps up with the finger.
  final ValueChanged<int> onPageChanged;

  /// Tapping the card in front. Tapping a neighbour brings it to the front
  /// instead, which is handled here.
  final ValueChanged<BankCard>? onCardTap;

  final int initialIndex;
  final bool showDots;

  /// The card with a freeze or a thaw in flight, if any. Its face acknowledges
  /// the tap while the write is out, so the wait is not dead time.
  final String? pendingCardId;

  /// The card currently turned over to show its details, if any.
  ///
  /// Set by the screen, and only after App_Lock has confirmed, so the deck cannot
  /// decide to show a number on its own. Requirement 13.8 puts a clock on the
  /// reveal, and when that clock runs out this goes back to null and the card
  /// turns back by itself.
  final String? revealedCardId;

  final Color? dotColor;
  final Color? dotTrackColor;

  /// Share of the available width given to one page slot.
  ///
  /// Deliberately well under one: the neighbours have to stay on screen for the
  /// turn to be worth anything. At 0.76 the cards either side were clipped
  /// almost immediately and the rotation happened out of sight.
  static const double viewportFraction = 0.68;

  static const double _gutter = Space.x3 + 2;
  static const double _maxCardWidth = 248;

  /// Room the deck needs for a given available width, shadow included.
  static double heightFor(double availableWidth) =>
      CardFace.heightFor(cardWidthFor(availableWidth)) + Space.x8;

  static double cardWidthFor(double availableWidth) {
    final slot = availableWidth * viewportFraction;
    return (slot - _gutter * 2).clamp(140.0, _maxCardWidth);
  }

  @override
  State<CardCarousel> createState() => _CardCarouselState();
}

class _CardCarouselState extends State<CardCarousel> {
  late final PageController _controller;
  late final ValueNotifier<double> _page;
  late int _settled;

  @override
  void initState() {
    super.initState();
    _settled = widget.initialIndex;
    _page = ValueNotifier<double>(widget.initialIndex.toDouble());
    _controller = PageController(
      initialPage: widget.initialIndex,
      viewportFraction: CardCarousel.viewportFraction,
    )..addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    _page.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    if (!position.hasPixels || !position.haveDimensions) return;
    final value = _controller.page;
    if (value == null) return;

    _page.value = value;

    final settled = value.round().clamp(0, widget.cards.length - 1);
    if (settled == _settled) return;
    _settled = settled;
    // Feedback: crossing to a new card is confirmed in the hand, the way a
    // physical detent would.
    HapticFeedback.selectionClick();
    widget.onPageChanged(settled);
  }

  void _handleTap(int index, BankCard card) {
    if (index != _page.value.round()) {
      _controller.animateToPage(
        index,
        duration: Motion.resolve(context, Motion.medium),
        curve: Motion.emphasized,
      );
      return;
    }
    widget.onCardTap?.call(card);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final cardWidth = CardCarousel.cardWidthFor(width);
      final cardHeight = CardFace.heightFor(cardWidth);
      final reduced = Motion.isReduced(context);

      return Column(
        children: [
          SizedBox(
            height: cardHeight + Space.x8,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.cards.length,
              // Turned cards and their shadows reach past their page slot.
              clipBehavior: Clip.none,
              padEnds: true,
              itemBuilder: (context, index) {
                final card = widget.cards[index];
                return Center(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _page,
                    builder: (context, page, child) => _TurnedCard(
                      delta: page - index,
                      reduced: reduced,
                      child: child!,
                    ),
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: Pressable(
                        onTap: () => _handleTap(index, card),
                        borderRadius: AppRadius.lg,
                        semanticLabel:
                            '${card.label}, ${card.kind.label} '
                            '${card.network.label} ending ${card.last4}, '
                            '${card.status.label}',
                        child: _SheenCard(
                          page: _page,
                          index: index,
                          card: card,
                          pending: card.id == widget.pendingCardId,
                          revealed: card.id == widget.revealedCardId,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.showDots && widget.cards.length > 1) ...[
            const SizedBox(height: Space.x2),
            ValueListenableBuilder<double>(
              valueListenable: _page,
              builder: (context, page, _) => CardPageDots(
                count: widget.cards.length,
                page: page,
                color: widget.dotColor,
                trackColor: widget.dotTrackColor,
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// Applies the turn. Kept separate from the face so the face only repaints when
/// its own sheen changes.
class _TurnedCard extends StatelessWidget {
  const _TurnedCard({
    required this.delta,
    required this.reduced,
    required this.child,
  });

  /// Signed distance from the front of the deck, in pages.
  final double delta;
  final bool reduced;
  final Widget child;

  /// Turn at one page out. Enough to read as a flip, short of the edge on which
  /// the face would foreshorten into a sliver.
  static const double _turn = 0.92;

  @override
  Widget build(BuildContext context) {
    final d = delta.clamp(-1.6, 1.6);
    final distance = d.abs();
    final fade = (1 - distance * 0.42).clamp(0.16, 1.0);

    if (reduced) return Opacity(opacity: fade, child: child);

    final transform = Matrix4.identity()
      // Perspective, so the turn has a near edge and a far edge.
      ..setEntry(3, 2, 0.0013)
      ..rotateY(d * _turn)
      // A little roll, so the card falls away rather than pivoting on a rail.
      ..rotateZ(d * 0.05);

    final shrink = 1 - (distance * 0.09).clamp(0.0, 0.2);
    transform.scaleByDouble(shrink, shrink, 1, 1);

    return Opacity(
      opacity: fade,
      child: Transform.translate(
        // Pulls the leaving card back over the deck, so the stack keeps depth.
        offset: Offset(d * 22, distance * 10),
        child: Transform(
          alignment: Alignment.center,
          transform: transform,
          filterQuality: FilterQuality.medium,
          child: child,
        ),
      ),
    );
  }
}

/// Feeds the page offset into the face, so light travels across the card as it
/// turns. Split out so the repaint stays inside the painter.
class _SheenCard extends StatelessWidget {
  const _SheenCard({
    required this.page,
    required this.index,
    required this.card,
    required this.pending,
    required this.revealed,
  });

  final ValueNotifier<double> page;
  final int index;
  final BankCard card;
  final bool pending;
  final bool revealed;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: page,
    builder: (context, value, _) {
      final delta = (value - index).clamp(-1.0, 1.0);
      final lift = (1 - delta.abs() * 0.6).clamp(0.25, 1.0);
      return FlipCard(
        showBack: revealed,
        front: CardFace(
          card: card,
          sheen: Motion.amount(context, delta),
          lift: lift,
          pending: pending,
        ),
        back: CardBackFace(card: card, lift: lift),
      );
    },
  );
}
