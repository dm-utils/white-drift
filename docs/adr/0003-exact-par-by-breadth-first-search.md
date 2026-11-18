# 0003 Exact par by breadth-first search, with the number of shortest solutions

Status: accepted (2026-11-18)

## Context

White Tally's trial showed that exact par is expensive with many moves per position (hard par was bounded for every
seed). White Drift has at most three effective moves per position after the first (ADR 0001), like White Shift, whose
breadth-first solver gives exact par and counts the shortest solutions cheaply. The owner wants par to be as exact as
possible.

## Decision

- `DriftSolver.solve` is a breadth-first search over positions (deduplicated by state), directions in the fixed order
  `R, L, D, U`, limited by a maximum depth (the band maximum) and a cap on stored positions. It returns par, `exact`,
  the number of shortest solutions and the first shortest path found.
- Only puzzles with a complete search are shipped: `exact` is always `true`. A candidate whose search hits the cap is
  rejected by the generator, never shipped with a bound.
- The number of shortest solutions is stored with every puzzle and measured in the trial; a limit for the hard level
  may follow (design 5.6, 15).

## Alternatives considered

- **White Tally's iterative deepening search**: works, but breadth-first search is simpler here, gives the solution
  count for free and needs no beam fallback. Rejected.
- **Bounded par allowed for hard** (as White Tally phase 1): unnecessary when the search is this cheap; an exact par
  keeps "exactly par" meaningful. Rejected.
- **A* with a heuristic**: there is no useful admissible estimate (one tilt can clear the board through a chain), and
  BFS is already fast enough. Rejected.
- **Solve on the device instead of precomputing**: feasible for one puzzle, but generation needs hundreds of searches
  per accepted puzzle. Rejected for generation; a device-side search is kept in mind for the later "no longer
  solvable" notice (design 2.9).

## Consequences

- Every shipped puzzle has an exact par; the share line can compare players fairly.
- The state cap and the depth limit bound the cost per candidate; the trial measures `states` per candidate and the
  wall-clock time of the pool build (P3).
- The stored `solutions` gives the trial a measure of how forgiving a puzzle is.
