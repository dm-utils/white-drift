# White Drift - design

Status: phase 1 (look and feel) designed, not built. Later phases are designed in outline and marked **[later]**;
they are not built in phase 1.
This document describes the game as it must be built. Decisions with their trade-offs are in `docs/adr/`; terms are
defined in `docs/glossary.md`; code and test rules are in `docs/conventions.md`.

White Drift is built on the shared base White Kit (`dm-utils/white-kit`, installed as a git submodule at
`res://addons/white_kit/`, design in that repository's `docs/design.md`). Phase 1a pins kit `v0.2.0`; phase 1b pins
`v0.3.0`, which adds the tile view base class with board-swipe input, the safe area, the maximum content width and the
screenshot tools (kit design section 14). Section 7 lists exactly what White Drift uses from the kit.

## 1. Purpose and phases

White Drift is a puzzle game for players aged 10 and up and adults, intended to become a daily puzzle. The board holds
tiles marked 2, 3 and 4 and a few fixed blocks. A swipe tilts the whole board: every tile slides in that direction
until it stops against the edge, a block or another tile. A group of equal tiles vanishes when its size equals its
number (White Tally's rule). The player clears the board in as few tilts as possible. No new tiles ever appear.

### 1.1 Phase 1: look and feel

Phase 1 tests how the game looks and feels. It answers:

1. Can a new player predict where tiles end after a tilt, and apply the size rule, after a 30-second explanation?
2. With only four moves, does the game ask for planning ("which order of tilts?"), or do players just swipe until it
   works?
3. Are there "aha" moments: a block that holds one tile back, a group that only forms when the board tilts the other
   way first, a chain in the tilt direction?
4. Are the tilt, the stop against blocks, vanishing and chains easy to read and pleasant to watch, on a phone and on a
   PC?

In scope:

- Playable puzzles in three levels (easy, medium, hard) from a precomputed pool of 40 sets (6.3), not tied to dates.
- Free choice: level tabs, Next, Undo, Restart.
- Controls for touch, mouse and keyboard (10.4).
- Animations of tilt, vanish and chain (10.2).
- Readability of tiles, groups and blocks (10.1); a calm, flat, dark look in the series style.
- Tilts and par shown simply (3.1, `FINAL_ONLY`); no strict scoring.
- Dutch and English.
- Web version on GitHub Pages at https://play.whitedrift.steefbeest.nl, usable in portrait on a phone and on a desktop.
- The rules engine, generator and exact solver needed to fill the pool (section 5), with a trial (5.7).

Out of scope for phase 1 (designed below where marked **[later]**): binding puzzles to dates, the first day and puzzle
numbers, the share line, daily counting (every tilt counts), saved daily progress, the full trial, accounts,
leaderboards, a server, art, sound, Android/Windows builds, a puzzle archive, a "no longer solvable" notice.

### 1.2 Later phases

See section 12. Phase 2 turns the pool into a daily puzzle with puzzle numbers, a share line and `EVERY_MOVE`
counting; the kit's `_count_mode(is_practice)` already separates day and practice, with one record format.

## 2. Rules

### 2.1 Board and coordinates

- A rectangular board of `w x h` cells, seen from above. `w` is 2 to 8, `h` is 2 to 9 (generated boards are larger;
  small sizes occur in tests and examples).
- Coordinates as White Tally and the kit tile view: `x` to the right (`0 .. w-1`), `y` **upwards** (`0 .. h-1`),
  `(0, 0)` bottom-left, cell index `i = y * w + x`. Direction `U` is towards the top of the screen.
- Cell names: column letter plus row digit, `A1` bottom-left (examples and tests; moves do not name cells).
- Each cell is empty, holds one **tile**, or is a **block**.

### 2.2 Tiles and blocks

- A tile has a value: 2, 3 or 4. Tiles never change value and are never created.
- A block is a fixed cell: it never moves, never vanishes, is not a tile and belongs to no group.
- Two cells are neighbours when they share an edge. Diagonals are not neighbours.

### 2.3 Groups

As White Tally (its ADR 0001): a **group** is a maximal set of tiles with the same value connected through neighbours.
A group is **exact** when its size equals its value, **overfull** when larger, **short** when smaller. Only exact
groups vanish; an overfull group does not vanish and neither does any part of it. Blocks and empty cells separate
groups.

### 2.4 Lines, segments and packing

- For a direction `d`, a **line** is a row (for `R` and `L`) or a column (for `U` and `D`).
- Blocks cut each line into **segments**: maximal runs of non-block cells. A segment is ordered from its **front** (the
  end in direction `d`) to its back.
- **Pack** a board towards `d`: in every segment, the tiles keep their order and move to the front, with no empty cell
  between them or before them. Formally, for segment cells `c_0 .. c_{n-1}` from the front and tiles `t_0 .. t_{k-1}`
  in that order: cell `c_j` gets `t_j` for `j < k` and is empty for `j >= k`.
- Tiles never pass each other, never pass a block and never leave their line.

### 2.5 Moves: tilt

A move is a **tilt** in one of the four directions `R`, `L`, `D`, `U`.

1. `P = pack(state, d)`. When `P` equals the state (no tile can move), the tilt is **ignored**: not counted, not
   recorded, no undo step (`WhiteRules.apply` returns `null`). The board view nudges the board.
2. Otherwise resolve `P` (2.6). The tilt counts as one move.

After any effective tilt the board is packed towards `d` and stable, so the same tilt again is always ignored: from the
second move on, at most three tilts can change the board. After the board is empty (solved), every tilt is ignored
(kit attempt).

### 2.6 Resolution: vanish and re-pack in the tilt direction

1. **Find** all exact groups on the packed board.
2. If there are none, resolution ends.
3. **Vanish**: remove all exact groups at the same time (one **wave**).
4. **Re-pack** towards the same direction `d` (the board is still tilted), then go to step 1.

Notes:

- Groups are maximal, so exact groups never share a tile; the wave is unique.
- A **chain** is a resolution with more than one wave: tiles that slid on after a wave form a new exact group.
- Resolution always ends: every wave removes at least two tiles.
- A board after resolution is **stable** (no exact group) and packed towards `d`. Every start position is stable but
  need not be packed: the start is the only position where tiles can float anywhere.
- Why the same direction: the board stays tilted until the next swipe, so tiles keep drifting; see ADR 0001.

### 2.7 Goal and invariants

- The puzzle is solved when no tile is left (blocks remain).
- A wave removes exactly `v` tiles of value `v` per exact group, so for every value `v` the number of tiles of value
  `v` modulo `v` never changes. A board can only be cleared if every value occurs a multiple of its own number of
  times; the generator guarantees this. It is necessary, not sufficient.
- Blocks never change. No tiles are ever added.

### 2.8 Examples

Examples are drawn with the top row first, row numbers on the left and column letters on top; `.` is empty, `#` a
block. `DriftBoard.render()` produces the same rows without labels and spaces (for example `.#2.`). Every example
below is also a regression test.

**Example 1 - a tilt forms a pair; no gravity.** Board `4 x 3`, tilt `L`.

```
start              packed left           after wave 1
   A B C D            A B C D               A B C D
3  . . . .         3  . . . .            3  . . . .
2  . 3 . .         2  3 . . .            2  3 . . .
1  2 . . 2         1  2 2 . .            1  . . . .
```

Both 2s of row 1 slide left and touch: an exact pair. It vanishes. The 3 stays at `A2`: tiles move only in the tilt
direction, nothing falls.

**Example 2 - a block holds a tile; overfull does not vanish.** Board `5 x 2`, tilt `D`.

```
start              after the tilt
   A B C D E          A B C D E
2  . . 2 . 2       2  . . . . .
1  2 # . 2 .       1  2 # 2 2 2
```

`C2` and `E2` drop to row 1. The three 2s at `C1`, `D1`, `E1` form an overfull group: nothing vanishes. The block at
`B1` keeps `A1` apart from them.

**Example 3 - ignored tilts.** The result of Example 2. Tilt `D` again: everything is already packed down, ignored.
Tilt `L`: row 1 is cut by the block into `A1` and `C1..E1`, both already packed left; row 2 is empty: ignored. Tilt `R`:
likewise ignored. Only `U` changes this board.

**Example 4 - chain in the tilt direction.** Board `4 x 3`, tilt `L`.

```
start             packed left        wave 1, re-pack     wave 2
   A B C D           A B C D            A B C D            A B C D
3  3 . . .        3  3 . . .         3  3 . . .         3  . . . .
2  . 2 . 3        2  2 3 . .         2  3 . . .         2  . . . .
1  2 . 3 .        1  2 3 . .         1  3 . . .         1  . . . .
```

After packing, the 2s at `A1`, `A2` are an exact pair (the 3s at `B1`, `B2` are a short pair). Wave 1 removes the 2s;
the board is still tilted left, so the 3s slide on to `A1` and `A2` and join `A3`: three 3s, exact. Wave 2 clears the
board. Tilt `R` also clears this board in one tilt, without a chain: it packs the three 3s into column `D` and the two
2s into column `C`, and both groups vanish in one wave. The puzzle has par 1 and two shortest solutions.

**Example 5 - a complete puzzle (par 2).** Board `4 x 3`.

```
   A B C D
3  2 . . .
2  . . 3 .
1  3 . 2 3
```

Solution `D R`:

```
after D            after R (packed)    wave 1, re-pack     wave 2
   A B C D            A B C D             A B C D             A B C D
3  . . . .         3  . . . .          3  . . . .          3  . . . .
2  2 . 3 .         2  . . 2 3          2  . . . 3          2  . . . .
1  3 . 2 3         1  . 3 2 3          1  . . 3 3          1  . . . .
```

`D` drops the 2 from `A3` onto the 3 at `A1`; nothing vanishes. `R` packs row 2 to `2 3` at `C2`, `D2` and row 1 to
`3 2 3` at `B1`..`D1`: the 2s at `C2`, `C1` are an exact pair. After they vanish the board is still tilted right: the 3
at `B1` slides to `C1` and joins `D1` and `D2`: three 3s, a chain that clears the board. None of the four single tilts
from the start makes anything vanish, so par is 2. `U R` is the only other shortest solution (after `U`, the tilt `R`
makes the 3s at `C2`, `C3`, `D3` exact and the remaining 2s meet at `D2`, `D3`), so the puzzle has two shortest
solutions.

**Example 6 - no tilt changes anything.** Board `3 x 2`.

```
   A B C
2  2 # .
1  # 2 #
```

Every tile is boxed in by blocks and edges in all four directions: every tilt is ignored. A dead end (2.9).

### 2.9 Dead ends

- A position is a **dead end** when tiles are left and all four tilts are ignored. The message line shows the dead-end
  text (10.5); undo and restart stay available.
- Positions that can still change but can no longer be cleared are not reported in phase 1. **[later]** Because the
  reachable positions of a Drift board are few (at most three moves per position), the game can check on the device
  whether the current position can still be cleared (breadth-first search with a state cap) and say so.

### 2.10 How White Drift differs from White Tally and White Shift

| | White Tally | White Shift | White Drift |
|---|---|---|---|
| Move | swap or slide one tile | swipe: pieces glide until they hit something | tilt: all tiles slide until they hit something |
| Moves per position | 30 to 80 | at most 4 | at most 3 (4 at the start) |
| What vanishes | exact groups | nothing (one stone must exit) | exact groups (Tally's rule) |
| After a vanish | gravity down | - | re-pack in the tilt direction |
| Fixed obstacles | none | pins, walls | blocks |
| Solver | bounded search | exact BFS | exact BFS |

White Drift combines Shift's global gliding move with Tally's size rule. The whole board moves at once, so the puzzle
is about order: which tilt first, so that the right tiles meet and the wrong ones do not.

## 3. Counting, undo, restart and par

### 3.1 Phase 1: simple counting

- Every puzzle is played as a kit practice attempt (`FINAL_ONLY`): the counter shows the tilts from the start to the
  current position; undo lowers it, restart sets it to 0. Par is shown next to it; when solved the message line shows
  count, par and clock.
- Undo and restart are unlimited, possible only with history and before solving. Nothing is strict in phase 1.

### 3.2 [later] Daily counting

`EVERY_MOVE` for daily puzzles (every tilt counts, including undone ones), `FINAL_ONLY` for practice, through the kit
hook `_count_mode(is_practice)`; one record format. With only three choices per position, `EVERY_MOVE` matters more
than in White Tally: trying tilts and undoing them costs.

### 3.3 Par

- Par is the exact minimum number of tilts, from a complete breadth-first search (5.5, ADR 0003). Every shipped
  puzzle has `exact: true`; a candidate whose search hits its cap is rejected, never shipped with a bound.
- The number of different shortest solutions (`solutions`) is stored with the puzzle (as White Shift does) and
  measured in the trial.

## 4. Levels

Each level has its own generator parameters (`DriftGenerator.LEVELS`). The values are **starting values**; the
developer adjusts them in the trial (5.7) within the stated ranges and records the outcome in 5.9.

| Parameter | Easy (0) | Medium (1) | Hard (2) | Allowed range |
|---|---|---|---|---|
| Board `w x h` | 5x5 | 6x6 | 6x6 | 5x5, 6x6, 6x7, 7x7 |
| Blocks | 1-2 | 2-3 | 3-4 | 0-8 |
| Groups (each `v` tiles of value `v`) | 3 | 4 | 4-5 | 2-7 |
| Different values present (at least) | 2 | 3 | 3 | 2-3 |
| Greedy gap (5.6) | none | 1 | 2 | none-3 |
| Par band | 3-4 | 5-7 | 8-11 | bands may share at most their end value |
| Candidates tried | 600 | 1500 | 3000 | up to 8000 |
| Search state cap (per candidate) | 50 000 | 100 000 | 200 000 | up to 1 000 000 |

- Tiles per board: the sum of the group values (easy 6-12, medium 8-16, hard 8-20).
- The par bands are wider apart than White Tally's because a tilt is a coarser move and par is exact: hard puzzles need
  a real plan of eight or more tilts.

## 5. Rules engine, generator and solver

All code in this section lives in `sim/`, is pure (no nodes, no floats, no time, no `user://`) and is shared by the
game, the build tools and the tests. It is written for White Drift; patterns are borrowed from White Tally (state as
`PackedByteArray`, flood fill with a stamp, traced step) and White Shift (breadth-first solver with solution count).

### 5.1 State

- A state is a `PackedByteArray` of length `w * h`, index `i = y * w + x`; value `0` empty, `1` block, `2`-`4` tile.
- Blocks are part of the state (they never change), so a state alone describes the board; board size and start belong
  to the `DriftBoard` instance.
- States are used directly as `Dictionary` keys.

### 5.2 Moves in code

- Move code = direction: `R = 0`, `L = 1`, `D = 2`, `U = 3` (the series' codes).
- Move token: one letter `R`, `L`, `D` or `U` (`move_len() == 1`), as White Shift.

### 5.3 `DriftBoard` (`sim/board.gd`)

```
class_name DriftBoard extends WhiteRules
enum Dir { R, L, D, U }
const DIR_LETTERS := "RLDU"
const GLYPHS := ".#234"          # the index of a glyph is its cell value
const BLOCK := 1
var w: int
var h: int
var start: PackedByteArray

static func create(w: int, h: int) -> DriftBoard
static func from_dict(d: Dictionary) -> DriftBoard              # {"n": [w, h], "rows": [...]}
func to_dict(state: PackedByteArray) -> Dictionary
func from_rows(rows: PackedStringArray) -> PackedByteArray      # rows top first, chars ".#234"
func render(state: PackedByteArray) -> String
func cell_name(i: int) -> String

# White Kit interface
func start_state() -> Variant
func apply(state: Variant, move: Variant) -> Variant            # null unless move is an int 0..3 and tilt changes the state
func is_solved(state: Variant) -> bool                          # no value >= 2
func move_len() -> int                                          # 1
func encode_move(move: Variant) -> String                       # "R", "L", "D" or "U"
func decode_move(token: String) -> Variant                      # index in DIR_LETTERS, null otherwise

# Rules
func segments(d: int) -> Array[PackedInt32Array]    # all segments for direction d, cells ordered front to back; cached per board and direction
func pack(state, d: int) -> PackedByteArray
func tilt(state, d: int) -> PackedByteArray         # pack + waves of vanish and re-pack (fast)
func tilt_reference(state, d: int) -> PackedByteArray
func tilt_traced(state, d: int) -> Dictionary       # result plus animation steps
func groups(state) -> Array[PackedInt32Array]
func exact_groups(state) -> Array[PackedInt32Array]
func is_stable(state) -> bool                       # no exact group
func is_packed(state, d: int) -> bool               # pack(state, d) == state
func legal_moves(state) -> PackedInt32Array         # directions whose tilt changes the state, ascending
func is_dead_end(state) -> bool                     # tiles left and legal_moves empty
func count_tiles(state) -> int
```

- `segments(d)`: for `R` the lines are rows and the front is the right end (cells ordered `x` descending); `L` rows,
  left end (`x` ascending); `U` columns, top (`y` descending); `D` columns, bottom (`y` ascending). Lines in ascending
  row or column order; each line cut at blocks; segments without cells are skipped. The cache is filled on first use
  from `start` (blocks never move).
- `pack(state, d)`: per segment, copy the tile values in front-to-back order to the first cells, clear the rest.
- `tilt(state, d)` (fast): `p = pack(state, d)`; loop: exact groups by flood fill over tile cells (stamp array, as
  White Tally's `_flood`, whole components); none: return `p`; else clear them and `p = pack(p, d)`.
- `tilt_reference(state, d)` (independent algorithm): repeat passes over all cells; in each pass every tile whose
  neighbour in direction `d` is on the board and empty moves one cell; stop when a pass moves nothing. Then find exact
  groups with a separate breadth-first component search, clear them, and repeat the passes. Must equal `tilt()` for
  every state and direction (tested on random states).
- `apply(state, move)`: `null` when `move` is not an int in 0..3; `r = tilt(state, move)`; `null` when `r == state`,
  else `r`. Never modifies its argument.
- `tilt_traced(state, d)` returns `{"state": result, "steps": [...]}`: first `{"kind": "tilt", "moves": [[from, to],
  ...]}` with every tile that moved during the pack (omitted when none moved, but then the tilt is ignored), then per
  wave `{"kind": "vanish", "cells": [...]}` (sorted) followed by `{"kind": "tilt", "moves": [...]}` for the re-pack
  (omitted when nothing moved). Its `state` equals `tilt()`.
- Random stable states for tests: put random tiles (values 2-4) and blocks into random cells with a seeded
  `WhiteRng`, then clear exact groups until stable (without packing).

There is no `DriftAttempt` class: the game uses `WhiteAttempt` directly with a `DriftBoard` as rules.

### 5.4 Generator: random start, exact filter (`DriftGenerator`, `sim/generator.gd`)

Forward generation (ADR 0004): draw a random start with the right tile counts, then let the exact solver decide.

```
static func generate(seed_value: int, level: int) -> Dictionary
static func generate_with(seed_value: int, cfg: Dictionary) -> Dictionary
# returns {"board": DriftBoard (start set), "par": int, "exact": true, "solutions": int,
#          "path": PackedInt32Array, "states": int, "tried": int, "fallback": bool}
static func to_json(result: Dictionary) -> Dictionary   # the puzzle object of 6.3
```

**Input.** A 64-bit seed (6.1) and a level. `WhiteRng.new(seed_value)`; only `range_int` and `shuffle`.

**Candidate.** For `t = 0 .. candidates - 1` (the PRNG stream continues):

1. `B = range_int(blocks)`, `G = range_int(groups)`; for each of the `G` groups a value `range_int(2, 4)`.
2. The tile list: for each group value `v`, `v` copies of `v`, groups in draw order. `T` = its length. When
   `T + B > w * h`, the candidate is rejected (it still counts as tried).
3. `cells` = `[0 .. w*h - 1]`, `rng.shuffle(cells)`. The first `B` cells become blocks. `rng.shuffle(tile list)`; the
   next `T` cells get the tiles in that order.
4. Cheap checks: the start is stable; at least the level's number of different values; not a dead end.
5. `DriftSolver.solve(board, start, band maximum, state cap)`. Rejected when no solution is found within the band
   maximum or the search hits the cap.
6. Par in the band.
7. Greedy gap: `DriftSolver.greedy(board, start, 3 * band maximum)` does not solve in fewer than `par + gap` tilts (a
   greedy failure passes); level "none" skips this.
8. Accepted: return the puzzle.

**Fallback.** Every candidate with a solution found in step 5 is a fallback candidate, ranked by distance of par to
the band (only below the band is possible), then fewer `solutions`, then fewer tiles; the best one is returned with
`fallback = true` when no candidate is accepted. When no candidate had any solution, the result has `par = 0`, an empty
path and `fallback = true`; the build tool prints `FALLBACK` and the pool tests fail, so such a set is never shipped.

### 5.5 Solver (`DriftSolver`, `sim/solver.gd`)

Exact breadth-first search, as White Shift's solver (ADR 0003).

```
static func solve(board: DriftBoard, state: PackedByteArray, max_depth: int, max_states: int) -> Dictionary
# {"par": int (-1 = none), "exact": bool, "solutions": int, "path": PackedInt32Array, "states": int, "capped": bool}
static func greedy(board: DriftBoard, state: PackedByteArray, max_moves: int) -> Dictionary
# {"solved": bool, "moves": int, "path": PackedInt32Array}
```

`solve`:

1. When `state` is already solved: par 0. `dist = {state: 0}`, `ways = {state: 1}`, `parent = {}`,
   `frontier = [state]`, depth 0.
2. While the frontier is not empty and `depth < max_depth` and no goal was found: for each state `s` in frontier order,
   for each direction `d` in `0 .. 3`: `t = tilt(s, d)`; skip when `t == s`. When `t` is solved: add `ways[s]` to the
   goal count (capped at `2^40`) and, for the first goal only, remember `[s, d]` as its parent. Otherwise, when `t` is
   new: `dist[t] = depth + 1`, `ways[t] = ways[s]`, `parent[t] = [s, d]`, append to the next frontier; when
   `dist[t] == depth + 1`: add `ways[s]` to `ways[t]` (capped). After each expanded state, when no goal has been found
   in this depth and `dist.size() > max_states`: stop with `capped = true`, `par = -1`.
3. A goal found at depth `k`: the depth is finished (to count every shortest line) and the search stops: `par = k`,
   `exact = true`, `solutions` = the goal count, `path` = the first goal's parent chain. No goal within `max_depth`:
   `par = -1`, `exact = false`, `capped = false`.
4. `states = dist.size()`.

Deterministic: frontier order and direction order fix the path. All limits are counts.

`greedy`: plays the tilt that removes the most tiles (ties: lowest direction code); stops when solved, when no tilt
removes anything, or after `max_moves`.

Why exact par is cheap here: at most three effective tilts per position after the first, so even without merging
equal positions depth 11 has at most `4 * 3^10`, about 236 000, nodes; positions repeat often, so the real number is
far lower. The state cap guards the worst case; the trial measures `states` (M2).

### 5.6 Filters

Summarised from 5.4, in order: tile and block counts fit; start stable; enough different values; not a dead end; a
solution within the band maximum without hitting the cap; par in the band; greedy gap. **[later]** A limit on
`solutions` for the hard level if the trial shows that many hard puzzles have dozens of shortest lines.

### 5.7 Phase 1 trial

Before UI work the developer builds `DriftBoard`, `DriftSolver` and `DriftGenerator` with their tests, then
`tools/measure.gd`, and runs the trial.

- M1 throughput: `tilt()` calls per second on random stable 6x6 boards with 4 blocks and 12-16 tiles; search states
  per second.
- M2 per level, 50 seeds (`WhiteSeed.fnv1a64("white-drift-trial|<n>|<level>")`, `n = 0 .. 49`): candidates tried,
  share of candidates with any solution within the band maximum, fallback count, tiles and blocks at start, par,
  `solutions` (median, max), `states` (median, max), greedy solved share, build time per puzzle (median, max).

Done when, for every level:

| Check | Requirement | If not met |
|---|---|---|
| P1 | At least 40 of 50 seeds give a non-fallback puzzle. | More candidates (up to 8000); then fewer groups or more blocks; then the band; then the greedy gap. |
| P2 | Median par strictly increases easy < medium < hard. | Shift bands or group counts. |
| P3 | Building the pool (6.3, 40 sets) takes at most 2 hours wall-clock on a desktop with up to 8 parallel processes. | Lower candidates or the state cap. |
| P4 | Reported, not a gate: `solutions` per level and the greedy solved share. | Input for the architect (hard-level filter, phase 2). |

Every accepted puzzle is exact by construction. Adjust only within the ranges of section 4; otherwise stop and report
to the project lead.

### 5.8 [later] Full trial for the daily puzzle

200 seeds per level and M3 (60 days = 180 puzzles): P1 as at least 90% non-fallback; P2 plus median hard >= p75
medium; M3 at most 2 hours; a decision on a `solutions` limit for hard.

### 5.9 Trial results

To be filled in by the developer after the phase 1 trial: settings used, M1, the M2 table per level, P1-P4, findings.

## 6. Precomputed puzzles

### 6.1 Seeds

- Game id `white-drift`. Pool seed `WhiteSeed.practice("white-drift", i, level)`.
- **[later]** Daily seed `WhiteSeed.daily("white-drift", date, level)`.

### 6.2 Why precomputed

Generation needs many candidates with a search each; on a phone browser that takes too long. Puzzles are built ahead
of time and shipped (ADR 0006).

### 6.3 Files and format

- Phase 1: `data/practice.json`: `{"<i>": [easy, medium, hard]}`, 40 sets. **[later]** `data/daily.json`.
- Loaded with `WhitePuzzleStore.new("res://data/daily.json", "res://data/practice.json", convert)`; `convert` gives
  `{"board": DriftBoard.from_dict(raw.board), "par", "exact", "solutions", "path"}` (path as `PackedInt32Array`).
- Puzzle object (Example 5):

```json
{
  "board": {"n": [4, 3], "rows": ["2...", "..3.", "3.23"]},
  "par": 2,
  "exact": true,
  "solutions": 2,
  "path": "DR"
}
```

| Field | Meaning |
|---|---|
| `board.n` | `[w, h]` |
| `board.rows` | `h` strings of `w` characters `.#234`, top row first |
| `par` | Exact minimum number of tilts |
| `exact` | Always `true` for a shipped puzzle |
| `solutions` | Number of different shortest tilt sequences |
| `path` | One shortest solution, one letter per tilt (the first one found in direction order) |
| `fallback` | Present and `true` only for a fallback puzzle |

For Example 5 the solver must report `solutions` 2 (`DR` and `UR`) and path `DR` (found first: `D` is expanded before
`U`); the example test checks both.

### 6.4 Build tools

- `tools/build_puzzles.gd` extends `WhitePrecompute`: `_game_id()` `"white-drift"`; `_generate` returns
  `DriftGenerator.to_json(DriftGenerator.generate(seed_value, level))`; `_summary` prints
  ` par <list> solutions <list>` and ` FALLBACK` when any puzzle has `fallback`.
- Parallel build and merge as White Sum (8 processes of 5 sets, `--merge` into one file, verify, copy to `data/`;
  conventions, Puzzle data).
- `tools/verify_puzzles.gd`: re-solves every puzzle with its level's cap and checks `par`, `solutions`, `exact` and
  that `path` clears the board; exit 1 on any mismatch.
- `tools/measure.gd`: the trial (5.7), `-- --seeds=50 [--level=N]`.

### 6.5 Game constants

`sim/game.gd`, `class_name DriftGame`: `GAME_ID := "white-drift"`, `DAILY`, `PRACTICE`, `store()` with the converter
of 6.3. **[later]** `FIRST_DAY`.

### 6.6 Known trade-off

Puzzles and solutions are readable in the public repository; acceptable until a server provides daily puzzles.

## 7. White Kit usage

| # | Need | Kit part | How White Drift uses it |
|---|---|---|---|
| K1 | Dutch day, puzzle number | `WhiteDaily` | **[later]** |
| K2 | PRNG and seed hash | `WhiteRng`, `WhiteSeed` | Generator, tests, trial. |
| K3 | Puzzle loading | `WhitePuzzleStore` | `DriftGame.store()`. |
| K4 | Rules, attempt, record, count modes | `WhiteRules`, `WhiteAttempt` | `DriftBoard extends WhiteRules`, `move_len() == 1`; `FINAL_ONLY` in phase 1. |
| K5 | Saved progress | `WhiteProgress` | Phase 1: language only. |
| K6 | Clock, share line | `WhiteFormat` | Phase 1: clock. |
| K7 | Texts | `WhiteText` | `DriftStrings.TEXT` (10.6). |
| K8 | Screen | `WhiteDayScreen` | `ui/main.gd` (10.3). |
| K9 | Board view | `WhiteTileView` (kit 0.3.0) | `DriftBoardView extends WhiteTileView`, `BOARD_SWIPES`, blocks as static cells. |
| K10 | Safe area, maximum width | kit 0.3.0 | true and 720. |
| K11 | Tests, precompute, CI, screenshots | kit | As White Sum. |

No kit changes are requested beyond kit 0.3.0 as designed.

## 8. Attempt and record

`WhiteAttempt` with `DriftBoard` as rules. Record per kit grammar: one letter per tilt (`R`, `L`, `D`, `U`), `z` undo,
`r` restart. Example on Example 5: `LzDR` = tilt left, undo, tilt down, tilt right; solved; `FINAL_ONLY` count 2,
`EVERY_MOVE` count 3. Ignored tilts are never written.

## 9. Saved progress

Phase 1: language only. **[later]** Daily progress through `WhiteDayScreen`.

## 10. User interface

Godot 4.7.2, GL Compatibility, portrait 720x1280 design size (stretch `canvas_items`, aspect `expand`). All drawing in
code.

### 10.1 Look

Abstract, flat, dark and calm (ADR 0005).

| Element | Presentation |
|---|---|
| Board | `WhiteTileView` defaults (`#232933`, grid `#2C333F`). |
| Tile | Flat rounded square (radius 18%, gap 8%), colour by value as White Tally: 2 `#4C7FD6`, 3 `#E3943A`, 4 `#3FA58A`. |
| Marks | `v` round dots evenly spaced on a small ring around the tile centre, starting at the top: 2 = top and bottom, 3 = a triangle pointing up, 4 = a diamond (top, right, bottom, left). Ring radius 20% of the cell, dot diameter 15%, colour `#1C1F24` at 85% opacity. Not dice layouts (dice put 2 and 3 on the diagonal and 4 in the corners), and no numerals. |
| Joins | As White Tally: neighbouring tiles of the same value joined by a bar in the tile colour, 40% of the cell wide, drawn in `_draw_links`; diagonal contact shows no join. |
| Block | A recessed square: fill `#151920`, 2 px border `#3A4250`, same radius and gap as a tile; clearly not a tile. |
| Ignored tilt | The whole board nudges 6 px towards the swipe and back in 150 ms (kit `nudge`). |

Look-alike risk (ADR 0005): no numerals or powers of two on sliding tiles, no merging, no score counter in the board;
no sparkles, particles, flashes, screen shake, combo texts or pop-ups. A vanish is a quiet fade.

All values are members or constants at the top of `ui/board_view.gd`.

### 10.2 Animation

| Trace step (`tilt_traced`) | View step |
|---|---|
| `tilt` `moves` | `{"kind": "move", "moves": moves, "speed": 16.0}` (all tiles together, constant speed as White Shift and White Tally's falls) |
| `vanish` `cells` | `{"kind": "vanish", "cells": cells}` (180 ms fade and shrink, 60 ms pause) |

- `DriftBoardView.to_view_steps(steps)` (static, tested) does the mapping.
- `update_attempt(a)`: when the record ends with a tilt letter and history is not empty, animate
  `to_view_steps(board.tilt_traced(a.history.back(), code).steps)` with `before = a.history.back()`; after undo or
  restart, `show_values(a.state)`. A new swipe during an animation finishes it first (kit).

### 10.3 Screen (`ui/main.gd extends WhiteDayScreen`)

As White Sum 10.3 (practice-only, Best route, dead-end notice, maximum width 720, safe area), with:

| Hook | White Drift |
|---|---|
| `_game_id()` | `DriftGame.GAME_ID` |
| `_game_title()` | `"WHITE DRIFT"` |
| `_texts()` | `DriftStrings.TEXT` |
| `_load_practice(index)`, `_practice_count()` | `DriftGame.store()` |
| `_new_attempt(puzzle, mode)` | `WhiteAttempt.new(puzzle.board, mode)` |
| `_make_view()` | a `DriftBoardView`; `move_chosen` to `_on_move`, `finished` to a refresh |
| `_key_move(event)` | `view.key_move(event)` (arrows and WASD tilt) |
| `_play_message(a)` | dead-end notice (2.9), empty while the view is busy |
| `_on_debug_extra()` | `--best` plays the stored path |

All other hooks as White Sum.

### 10.4 Input

`DriftBoardView extends WhiteTileView` with `input_mode = BOARD_SWIPES`: a swipe anywhere on the view (on or off the
board) tilts; arrows and WASD tilt; taps do nothing. `_resolve_board_swipe(dir)` returns `dir` when
`board.tilt(shown(), dir) != shown()`, else -1 (the kit nudges). `_is_tile(v)` is `v >= 2`; blocks are static cells.

### 10.5 Messages

| When | Message line |
|---|---|
| No tilt made yet | `hint` |
| Solved | `solved` with count, par and clock, plus `perfect` when count equals par |
| Not solved, dead end | `dead_end` |
| Otherwise | empty |

### 10.6 Texts (`ui/strings.gd`, `class_name DriftStrings`)

| Key | Dutch | English |
|---|---|---|
| `count` | Kantelingen: %d | Tilts: %d |
| `count_final` | Kantelingen in oplossing: %d | Tilts in solution: %d |
| `solved` | Leeg in %d kantelingen (par %d) · %s | Cleared in %d tilts (par %d) · %s |
| `perfect` | Precies par! | Exactly par! |
| `hint` | Veeg om het bord te kantelen: alle stenen schuiven mee. Een groep gelijke stenen verdwijnt als hij precies zo groot is als zijn getal. | Swipe to tilt the board: all tiles slide along. A group of equal tiles vanishes when its size equals its number. |
| `dead_end` | Geen kanteling verandert nog iets. Neem terug of begin opnieuw. | No tilt changes anything. Undo or restart. |
| `best_route` | Beste route | Best route |
| `share_line` | White Drift #%d · %s kantelingen (par %s) | White Drift #%d · %s tilts (par %s) |

### 10.7 [later] Share line

`White Drift #12 · 4/7/10 tilts (par 3/6/9)`, unsolved levels as `-`; no moves, no time.

## 11. Build and deployment

As White Sum section 11, with the play version at https://play.whitedrift.steefbeest.nl and this `tools/shots.txt`:

```
easy 720x1280 --practice --level=0
medium 720x1280 --practice --level=1 --lang=en
hard 720x1280 --practice --level=2
tilted 720x1280 --practice --level=1 --keys=D
solved 720x1280 --practice --level=0 --best
phone-safe-area 720x1280 --practice --level=1 --safe=40,80,40,60
small 360x640 --practice --level=1
desktop 1280x720 --practice --level=1
wide 1900x1000 --practice --level=2
```

On a puzzle where `D` happens to be ignored, the `tilted` shot shows the start; that is acceptable for a look check.

## 12. Roadmap

| Phase | Content |
|---|---|
| 1 | Look and feel: rules, generator, exact solver, precomputed pool in three levels, controls, animations, readability, NL/EN, play version. |
| 2 | Daily puzzle: three puzzles per Dutch day, numbers, share line, `EVERY_MOVE`, saved daily progress, full trial. |
| 3 | Tuning from play tests: levels, bands, `solutions` limit, par visibility, "no longer solvable" notice (2.9). |
| 4 | Version 1 finish: look, sound, statistics, Android. |
| 5 | st33f-engine: server puzzles, results, leaderboards, friends, accounts (owner approval for players aged 10-15). |
| 6 | Competitions; player feedback triage. |

## 13. Acceptance criteria

### 13.1 Phase 1

Rules (`DriftBoard`)
- Examples 1-6 in 2.8 give exactly the shown boards (`render()`); Example 4 through `tilt_traced()` with `L` yields
  exactly two `vanish` steps, with `R` exactly one; Example 5's paths `DR` and `UR` clear the board.
- Example 3: from the result of Example 2, `apply` returns null for `D`, `L` and `R`, and a state for `U`.
- After any effective tilt `d`, the result is packed towards `d` (`is_packed`) and stable, and tilting `d` again is
  ignored (checked on 10 000 random (state, direction) pairs).
- For 10 000 random (stable state, direction) pairs: `tilt()` equals `tilt_reference()` and `tilt_traced().state`;
  `apply()` does not modify its argument; blocks are unchanged; the tile count never grows; for every value `v`,
  `count(v) mod v` is unchanged.
- `segments`: on Example 2's board, direction `L`, row 1 has the segments `[A1]` and `[C1, D1, E1]` (front first),
  row 2 one segment of five cells.
- `is_dead_end` is true for Example 6 and false for the starts of Examples 1, 2, 4 and 5.
- Tokens: `encode_move` gives `R`, `L`, `D`, `U` for 0..3; `decode_move` inverts it and returns null for `r`, `X`, `""`
  and `RR`.
- `from_dict(to_dict(state))` round-trips; equal `PackedByteArray`s hit the same `Dictionary` entry.
- An independent oracle in the tests (no code shared with `DriftBoard`) agrees with `tilt()` on 300 random boards for
  all four directions.

Solver and generator
- Example 5: `solve` gives par 2, `exact` true, `solutions` 2, path `DR`. Example 4: par 1, `solutions` 2, path `R`
  (`R` is tried before `L`). With `max_depth = 1` on Example 5: par -1, not capped; with `max_states = 1`: capped, par
  -1.
- On 30 small random boards (`w, h <= 4`, at most 8 tiles) the solver's par and `solutions` equal a plain enumeration
  of all tilt sequences up to length 6 that skips ignored tilts (test helper).
- `generate(seed, level)` twice gives identical rows, par, solutions and path; every generated start is stable, value
  counts are multiples, `path` clears the board in exactly `par` tilts, par lies in the band unless `fallback`.
- No file in `sim/` uses `RandomNumberGenerator`, `randi(`, `randf(`, `randomize(` or `next_float`.
- Trial checks P1-P3 met and P1-P4 recorded in 5.9.

Pool
- Every puzzle in `data/practice.json` converts; start stable; value counts multiples; par in band unless `fallback`;
  `exact` true; `path` clears the board in exactly `par` tilts; 40 sets of three. `verify_puzzles.gd` confirms par and
  `solutions`.

Attempt and record
- Record `LzDR` on Example 5: solved, count 2 in `FINAL_ONLY`, 3 in `EVERY_MOVE`; ignored tilts change neither count
  nor record; `apply_record` reproduces state, record, `moves_made` and `count()`.

UI and deployment
- Opens directly on a pool set; tabs, Next, Undo, Restart as White Sum.
- A swipe anywhere on the view tilts; arrows and WASD tilt; an ignored tilt nudges the board and changes nothing; taps
  do nothing.
- `to_view_steps` maps `tilt` and `vanish` as in 10.2; a chain shows tilt, vanish, tilt, vanish in order; a swipe
  during an animation snaps it to its end.
- Blocks never move in any animation and are clearly distinct from tiles; groups are joined; diagonal contact shows no
  join; the three values are distinguishable in greyscale by their dot count.
- No numerals on tiles, no particles, flashes, screen shake or pop-ups.
- Counter `count_final`, par, solved message with count, par and clock; dead-end message on Example 6.
- Dutch and English complete; language survives a reload.
- Centred column at most 720 wide on 1280x720 and 1900x1000; full width on 720x1280 and 360x640.
- CI on `develop` green; https://play.whitedrift.steefbeest.nl loads and plays on a phone and on a PC.

### 13.2 [later] Phase 2

- `EVERY_MOVE`: undo and restart never lower the count; daily file complete; reload keeps a partly played day; share
  line `White Drift #<n> · a/b/c tilts (par p/q/r)`.

## 14. Developer work

### 14.1 Phase 1a: rules, solver, generator, tools, pool (kit `v0.2.0`)

Does not wait for kit 0.3.0.

1. Repository setup as White Sum 14.1 step 1 (project, kit `v0.2.0`, export preset, test runner, CI test steps). The
   README is already written; keep it current.
2. `sim/board.gd` (5.3) with the examples of 2.8, the independent oracle and the `tilt`/`tilt_reference` agreement
   test.
3. `sim/solver.gd` (5.5) with its tests, `sim/generator.gd` (5.4), `sim/game.gd` (6.5).
4. `tools/measure.gd`; M1, then the trial; record 5.9.
5. `tools/build_puzzles.gd`, `tools/verify_puzzles.gd`; build the pool in parallel, verify, commit
   `data/practice.json`; pool tests.

Done when: tests green in CI, P1-P3 met, P4 reported, pool verified.

### 14.2 Phase 1b: screen, board view, play version (kit `v0.3.0`)

1. Pin `v0.3.0`; kit threshold from its template.
2. `ui/strings.gd`, `ui/board_view.gd` (`DriftBoardView extends WhiteTileView`, `BOARD_SWIPES`, drawing hooks for
   tiles, ring dots, joins and blocks, `_resolve_board_swipe`, `show_attempt`, `update_attempt`, `to_view_steps`),
   `ui/main.gd`, `ui/main.tscn`, Best route, dead-end notice.
3. UI tests: open, tabs, Next, undo/restart, counter texts, swipes and keys on Examples 1-5, nudge on an ignored tilt,
   `to_view_steps`, max width.
4. `tools/shots.txt` and the full CI template; Pages on `develop`.

Done when: 13.1 is met.

## 15. Open points

- Look-and-feel test: do ring dots read as "this many" quickly enough, or do players want numerals despite the
  look-alike risk? Is 16 cells/s right for a whole-board tilt?
- Trial: is the forward generator's yield for the hard band enough (P1)? If not, the first remedies are in 5.7; a
  reverse-building generator is the fallback design (ADR 0004).
- Hard level: a limit on `solutions` (few shortest lines) once the trial shows the distribution.
- Later: the "no longer solvable" notice (2.9) and whether it should be shown at all in the daily puzzle.
