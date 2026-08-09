# The gauntlet prompt

Written with `gauntlet-loop`, from the brief: *more assets, icons and animations,
consistent; polish the card frost animation so it is clean, neat and creative; move
the freeze control below the cards so the animation is visible; good performance;
design and UX led.*

## The bar

Two halves, because taste alone cannot be argued with and a number alone cannot be
looked at.

- **Taste half.** `Reference Images/image.png`, the Conceptzilla iOS banking
  reference this repository already treats as its visual gate, plus the card face as
  currently shipped. Named, on disk, fetchable, and comparable side by side against
  a render of the same screen.
- **Measurable half.** `FrameTiming.rasterDuration` p95 while the freeze animation
  runs, measured in profile mode; frost draw calls per frame counted from the
  painter; `flutter analyze` at zero; `flutter test` green; 18 goldens regenerated
  deliberately.

## The prompt

> Polish the freeze animation on the FrostBank card face and move its control
> directly under the card carousel so the whole run is visible when tapped. Wire
> `pendingCardId`, which is threaded through three files and supplied by nobody, so
> the face answers the tap before the write returns. Keep the card's shipped look,
> the token set, and Req 2.6's single repeating animation. Drive the painter with
> `CustomPainter(repaint:)` so ticks skip build and layout, reuse its `Path` and
> `Paint` objects, and do not raise the frost draw-call count above the seven it
> costs today. Add icons from the existing `_rounded` Material family only.
> Then: render the screen, put it beside `Reference Images/image.png` with the
> labels stripped, and hand both to a fresh critic that has not seen this prompt.
> Fix the single biggest gap it names. Repeat until the critic picks ours.

## Exit condition

The critic picks our render over the bar in a blind comparison, and p95
`rasterDuration` during the freeze run is under the 8 ms latency budget the Flutter
docs give for a 60 Hz interactive surface.
