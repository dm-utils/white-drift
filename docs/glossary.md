# Glossary

Terms used in the code, the design (`docs/design.md`) and the ADRs. Code names in brackets. Terms shared by the whole
series (attempt, record, count mode, progress file, seed text, tile view, nudge, ...) are defined in White Kit's
glossary (`addons/white_kit/docs/glossary.md`); they are repeated here only where White Drift adds something. Terms
marked [later] belong to phases after phase 1.

| Term | Meaning |
|---|---|
| Attempt (`WhiteAttempt`) | One player's go at one puzzle, from White Kit, with a `DriftBoard` as rules. |
| Best route | The stored solution (`path`), shown as an animation after solving. |
| Block | A fixed cell: never moves, never vanishes, not a tile, part of no group. Cuts lines into segments. Shown as a recessed square. |
| Board (`DriftBoard`) | Board size, start position (tiles and blocks) and the rules (tilt, pack, vanish); implements `WhiteRules`. |
| Chain | A resolution with more than one wave: tiles that slid on after a wave form a new exact group. |
| Count | The number shown: tilts on the current line in phase 1 (`FINAL_ONLY`); [later] every tilt for daily puzzles. |
| Daily set | [later] The three puzzles of one Dutch calendar day. |
| Dead end | Tiles are left and all four tilts are ignored. Reported on the message line. |
| Exact group | A group whose size equals its value. Vanishes. |
| Exact par | Par proven minimal by a complete breadth-first search; every shipped Drift puzzle has it. |
| Fallback | The generator's nearest candidate when none fits the level; marked `"fallback": true`. |
| Forward generation | The generator method: draw a random start with valid tile counts, then keep it only when the exact solver finds a par in the band. |
| Front | The end of a segment in the tilt direction; packing moves tiles there. |
| Game id | `white-drift`; first part of the seed texts. |
| Greedy (`DriftSolver.greedy`) | A bot that always plays the tilt removing the most tiles and gives up when none removes anything. |
| Greedy gap | Filter: the greedy bot must not solve the puzzle in fewer than par plus this number of tilts. |
| Group | A maximal set of neighbouring tiles with the same value (blocks and empty cells separate groups). |
| Ignored tilt | A tilt that moves no tile. Not counted, not recorded; the board nudges. |
| Level | Easy (0), medium (1) or hard (2); each has its own board size, blocks, groups and par band. |
| Line | A row (for tilts `R`, `L`) or a column (for `U`, `D`). |
| Look and feel | Phase 1: playable pool puzzles to test controls, animations, readability and the tilt rule; no date binding or strict scoring. |
| Marks | The value of a tile shown as that many dots on a small ring (2 vertical, 3 triangle, 4 diamond). |
| Move | A tilt. |
| Move code | The direction as an integer: `R=0, L=1, D=2, U=3`. |
| Move token | One upper-case letter per tilt: `R`, `L`, `D`, `U`. |
| Overfull group | A group larger than its value. Does not vanish. |
| Pack | Move every tile of every segment to the segment's front, keeping their order. |
| Packed | A board on which packing towards a direction changes nothing. Every position after a tilt is packed towards that tilt. |
| Par | The exact minimum number of tilts. |
| Par band | The range of par a generated puzzle must fall in for its level. |
| Pool | The precomputed puzzles of phase 1: 40 sets of three levels in `data/practice.json`. |
| Re-pack | Packing again in the same direction after a wave, because the board is still tilted. |
| Record | Kit action string: tilt letters, `z` undo, `r` restart, e.g. `LzDR`. |
| Resolution | What follows a tilt: pack, then waves of vanishing exact groups with re-packing in between, until stable. |
| Segment | A maximal run of non-block cells in a line; tiles never leave their segment during a tilt. |
| Share line | [later] One line with the day's counts and pars, e.g. `White Drift #12 · 4/7/10 tilts (par 3/6/9)`. |
| Short group | A group smaller than its value. Does not vanish. |
| Solutions (`solutions`) | The number of different shortest tilt sequences of a puzzle, counted by the solver. |
| Solver (`DriftSolver`) | Breadth-first search over all positions reachable by tilts; gives exact par, the number of shortest solutions and one path. |
| Stable | Without exact groups. Every start and every position after a tilt is stable. |
| State | `PackedByteArray` of `w * h` cells: 0 empty, 1 block, 2-4 tile; index `y * w + x` with `y` upwards. |
| State cap | The maximum number of positions the solver may store per candidate; a candidate that hits it is rejected. |
| Tile | A square with value 2, 3 or 4, shown in the value's colour with that many dots. |
| Tilt | The move: all tiles slide in one direction until they stop against the edge, a block or another tile. |
| Trial | The measurement run (`tools/measure.gd`): phase 1 checks P1-P4. |
| View step | Kit step for the board view (`move` or `vanish`); `DriftBoardView.to_view_steps` converts the traced tilt. |
| Wave | One round of removing all exact groups at the same time. |
| White Kit | The shared base of the White puzzle games, a submodule at `addons/white_kit`. |
