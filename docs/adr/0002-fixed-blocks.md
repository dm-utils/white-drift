# 0002 Fixed blocks as the only obstacle

Status: accepted (2026-11-18)

## Context

With four tilts and no obstacles, every row behaves like every other row: a tilt to the left lines up every row at the
left edge, and the reachable positions of a board are few and similar. Puzzles would be short, and a player could solve
them by trying. The owner suggested fixed blocks or pins for depth.

## Decision

- A board has a few **blocks**: fixed cells that never move, never vanish and are not tiles. They cut rows and columns
  into segments; tiles stop against them.
- Block counts per level are generator parameters (easy 1-2, medium 2-3, hard 3-4, range 0-8; design section 4).
- Blocks are stored in the state (value 1) and in the puzzle rows (`#`), and drawn as recessed squares, clearly
  different from tiles.

## Alternatives considered

- **No obstacles**: shallow, see context. Rejected.
- **Pins on cell edges or walls between cells** (as White Shift's walls): finer control, but harder to read on a phone
  and to draw at small sizes, and the state would need edge data. Rejected for phase 1.
- **One-way cells or holes that swallow tiles**: more rules to explain; holes would remove tiles without the size rule.
  Rejected.
- **Movable heavy blocks** (pushed by tiles): larger state space and harder to predict. Rejected.
- **Tiles that never move (anchored tiles) instead of blocks**: they would take part in groups and vanish, which mixes
  two roles. Rejected; a block has one role.

## Consequences

- Each tilt treats different segments differently, so the order of tilts matters: a block can hold one tile back while
  the rest moves on (design Example 2).
- Blocks can box a tile in for good (Example 6); the generator rejects dead-end starts, and the trial measures how often
  candidates are unsolvable.
- The tile view treats blocks as static cells (kit `WhiteTileView`, `_is_tile` hook).
