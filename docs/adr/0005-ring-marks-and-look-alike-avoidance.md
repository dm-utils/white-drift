# 0005 Tiles with ring dots and value colours; avoid the look of number-merging tilt games

Status: accepted (2026-11-18)

## Context

The look must be flat, abstract, dark and calm like the rest of the series and readable on a phone. Square tiles that
slide across a grid when the player swipes are strongly associated with well-known number-merging games, especially
when the tiles show the numbers 2 and 4. White Drift must be an original game and must not look like one. White Tally
shows values as pips on the diagonal, which its test said read as dice faces. White Drift uses White Tally's group rule,
so tiles of equal value belong together and colour per value helps.

## Decision

- Tile colour per value as White Tally (2 blue, 3 orange, 4 teal), and link bars between neighbouring tiles of the same
  value, so a group reads as one shape.
- The value is shown as that many dots on a small ring around the tile centre: 2 as a vertical pair, 3 as a triangle,
  4 as a diamond. No numerals on tiles.
- Blocks are recessed dark squares. Nothing merges, nothing grows, no score in the board.
- A vanish is a quiet fade; an ignored tilt nudges the board slightly. No particles, flashes, screen shake or pop-ups.

## Alternatives considered

- **Numerals on the tiles**: the clearest value signal, but numbered sliding squares invite the comparison with
  number-merging games, which this game must avoid. Rejected for phase 1; the look-and-feel test checks whether the
  dots are read fast enough (design 15).
- **White Tally's diagonal pips**: consistent with Tally, but read as dice faces (White Tally test finding). Rejected.
- **Tally marks or bars**: readable, but suggest counting strokes and resemble White Tally's name more than its look;
  bars also clash with the link bars. Rejected.
- **Shapes per value** (circle, triangle, square): the number would have to be learned per shape. Rejected.

## Consequences

- Readability of the dots is an acceptance criterion (distinguishable in greyscale by count) and an open question for
  the look-and-feel test.
- The board view uses the kit's body, face and link hooks; the marks and colours are tunable values in
  `ui/board_view.gd`.
