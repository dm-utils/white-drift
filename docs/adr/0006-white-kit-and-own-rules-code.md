# 0006 White Kit for the shell, own rules code, precomputed puzzles

Status: accepted (2026-11-18)

## Context

White Kit provides the screen, attempt and record, puzzle store, precompute tool, test runner and CI template; kit
0.3.0 (kit ADR 0007) adds a tile view base class with a board-swipe input mode, safe area, maximum content width and
screenshot tools. The kit decided not to share rules, solvers or generators. White Drift's move (tilt) and solver (BFS)
differ from White Tally's; its group rule is the same.

## Decision

- White Drift pins White Kit `v0.2.0` during phase 1a (rules, solver, generator, pool) and `v0.3.0` from phase 1b.
- `sim/` is written for White Drift (design 5). Patterns are taken from White Tally (packed byte states, flood fill with
  a stamp, traced step, an independent reference implementation for tests) and White Shift (breadth-first solver with
  solution count); no files are copied.
- The board view extends `WhiteTileView` in `BOARD_SWIPES` mode with blocks as static cells; the screen extends
  `WhiteDayScreen` in practice-only mode.
- Puzzles are precomputed with `WhitePrecompute` and shipped in `data/practice.json`.
- Records use one letter per tilt (`move_len() == 1`); phase 1 counts `FINAL_ONLY`, the daily puzzle later
  `EVERY_MOVE`.

## Alternatives considered

- **Copy White Tally's `sim/` and adapt it** (as White Sum does): the move, resolution, solver and generator all
  differ; only the group flood fill would survive, and the copy would bring code that does not apply. Rejected.
- **Copy White Shift's view for swipe input**: the kit's `BOARD_SWIPES` mode covers it, together with tile animation
  that White Shift's view lacks. Rejected.
- **Wait for kit 0.3.0 before starting**: delays the rules and the trial, which carry the main risk (generator yield).
  Rejected.
- **Generate on the device**: hundreds of searches per accepted puzzle. Rejected.

## Consequences

- Phase 1a can start at once, in parallel with the kit 0.3.0 work and with White Sum; phase 1b waits for `v0.3.0`.
- The group rule exists in two implementations (Tally, Drift). Both are covered by independent oracle tests, so a
  divergence would show up as a failing test in the game that has it.
- Puzzles and solutions are readable in the public repository; acceptable until a server provides daily puzzles.
