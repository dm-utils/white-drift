# White Drift

A daily puzzle game in the White series. Tiles marked 2, 3 and 4 and a few fixed blocks sit on a board. A swipe tilts
the whole board: every tile slides until it stops against the edge, a block or another tile. A group of equal tiles
vanishes when its size equals its number. Clear the board in as few tilts as possible.

Status: phase 1a built (rules, solver, generator, 40 practice sets); the screen follows in phase 1b. No daily puzzle yet.

- Play version (from phase 1b): https://play.whitedrift.steefbeest.nl
- Design: `docs/design.md`, decisions in `docs/adr/`, terms in `docs/glossary.md`, rules for code and data in
  `docs/conventions.md`.

## Development

Godot 4.7.2. The shared base White Kit is a git submodule at `addons/white_kit`; clone with submodules:

```bash
git clone --recurse-submodules https://github.com/dm-utils/white-drift.git
# or, after a plain clone:
git submodule update --init
```

Run the tests headless:

```bash
godot --headless --path . --import
godot --headless --path . res://tests/run_tests.tscn
```

All rights reserved.
