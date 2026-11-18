# White Drift

A daily puzzle game in the White series. Tiles marked 2, 3 and 4 and a few fixed blocks sit on a board. A swipe tilts
the whole board: every tile slides until it stops against the edge, a block or another tile. A group of equal tiles
vanishes when its size equals its number. Clear the board in as few tilts as possible.

Status: phases 1a and 1b built (rules, solver, generator, 40 practice sets, screen and play version). No daily puzzle yet.

- Play version: https://play.whitedrift.steefbeest.nl
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

Debug screenshots of the scenarios in `tools/shots.txt` (needs xvfb):

```bash
addons/white_kit/tools/shots.sh run . tools/shots.txt build/shots
```

All rights reserved.
