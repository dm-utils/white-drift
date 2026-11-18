# 0004 Forward generation: random start, kept only when the exact solver accepts it

Status: accepted (2026-11-18)

## Context

White Tally and White Sum build puzzles backwards from an empty board, which guarantees solvability when par search is
expensive. For a tilt game, building backwards is awkward: the position before a tilt is not unique (any arrangement
whose packing gives the current position, and from the second step on it must itself be packed towards some other
direction). Only the opposite direction gives a unique predecessor, and lines built that way alternate between two
directions, which makes dull puzzles. On the other hand the exact solver is cheap (ADR 0003).

## Decision

- The generator draws a random start: a number of blocks and of groups per level, a value 2-4 per group, `v` tiles of
  value `v` per group (so every count is a multiple of its value), all placed on shuffled cells with `WhiteRng`.
- Cheap checks (stable, enough different values, not a dead end), then the exact solver up to the band maximum with a
  state cap; the candidate is kept when par lies in the band and the greedy bot is not too good (greedy gap).
- When no candidate is accepted, the nearest solvable candidate (par below the band) is returned as a fallback, marked
  `"fallback": true` and allowed in the pool, as in White Tally. When no candidate was solvable at all, the result is
  an empty fallback that the pool tests reject, so it is never shipped.
- Specification: design 5.4.

## Alternatives considered

- **Reverse building with opposite-direction predecessors only**: always valid, but the forward solution alternates
  between two directions; the solver would usually find something shorter that uses the others, so the upper bound
  helps little. Rejected.
- **Reverse building with full predecessor enumeration** (all packed arrangements towards each other direction whose
  packing gives the position): correct and varied, but a combinatorial search per step and much harder to specify and
  test. Rejected for phase 1; it is the fallback design if the trial shows that forward generation cannot fill the hard
  band (P1).
- **Random walk from a solved-looking board**: tilts do not create tiles, so there is no natural "solved" start to
  walk from. Rejected.
- **Hand-made puzzles**: not scalable to a daily puzzle. Rejected.

## Consequences

- Every accepted puzzle has an exact par and a known number of shortest solutions; there is no separate upper bound.
- The yield (share of candidates with par in the band) is the main risk, especially for hard (par 8-11). The trial
  measures it (M2) and the design names the remedies in order: more candidates, fewer groups or more blocks, the band,
  the greedy gap.
- Generation cost per candidate is bounded by the depth limit and the state cap, so build time is predictable.
