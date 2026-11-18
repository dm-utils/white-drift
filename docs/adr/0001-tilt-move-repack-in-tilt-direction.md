# 0001 The move is a tilt; after a vanish the tiles keep drifting in the tilt direction

Status: accepted (2026-11-18)

## Context

The owner's idea: a swipe tilts the whole board in one of four directions; all loose tiles slide until they hit the
edge, a tile or a fixed obstacle; then groups vanish by White Tally's size rule; chains until stable. Open: what
happens after a vanish (do tiles move again, and which way), and when a tilt counts. The rule must be deterministic,
predictable for a player, and leave enough depth with only four moves.

## Decision

- A tilt packs every segment (part of a row or column between blocks and edges) towards the tilt direction, keeping the
  order of the tiles. A tilt that moves no tile is ignored (not counted, not recorded).
- After packing, all exact groups vanish together; then the board is packed again **in the same direction**, and this
  repeats until no exact group is left (chain).
- The player's rule: "Swipe to tilt the board: all tiles slide along. A group of equal tiles vanishes when its size
  equals its number."

## Alternatives considered

- **No movement after a vanish** (holes stay until the next tilt): simpler, but tiles then hang in mid-board next to
  holes while the board is still tilted, which looks wrong and is harder to predict ("why did that tile not slide?").
  It also removes chains. Rejected.
- **Gravity down after a vanish, whatever the tilt** (as White Tally): mixes two forces; after a tilt to the right the
  tiles would suddenly fall down. Confusing. Rejected.
- **Re-pack in the opposite direction or alternate**: no physical meaning. Rejected.
- **A tilt that counts even when nothing moves**: a wasted move would cost a point in the daily puzzle without any
  effect on the board, and the undo history would hold equal states. Rejected; ignored tilts follow the kit rule for
  rejected moves.
- **Tiles slide one cell per tilt** instead of all the way: more moves per solution and many more positions; loses the
  "everything rushes to the wall" character that makes a tilt readable. Rejected.

## Consequences

- After every effective tilt the board is packed towards that direction, so repeating the same tilt is always ignored:
  at most three useful moves per position (four at the start). Solutions are sequences of direction changes.
- The start is the only position whose tiles may float anywhere; the generator uses that freedom (ADR 0004).
- Resolution is unique and cheap: packing is linear per segment, groups are a flood fill.
- The small branching factor makes exact par by breadth-first search cheap (ADR 0003), but also means depth must come
  from blocks and tile counts, not from move variety (ADR 0002, par bands in design section 4).
