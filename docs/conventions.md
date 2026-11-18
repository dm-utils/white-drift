# Conventions

How code, tests, data and branches are handled in this repository. The design is in `docs/design.md`. These
conventions follow White Tally's and White Sum's; differences are marked.

## Engine and layout

- Godot 4.7.2, GDScript only, pinned in `project.godot` and CI. Use the same version on every machine.
- Renderer: GL Compatibility. Web export single-threaded.
- White Kit is a git submodule at `addons/white_kit`, pinned to a tagged release (CI checks the pin): `v0.2.0` in phase
  1a, `v0.3.0` from phase 1b. Clone with `--recurse-submodules`, or run `git submodule update --init` after a plain
  clone. Never edit files under `addons/white_kit` here; kit changes are requested from the kit and arrive by updating
  the pin:

```bash
git -C addons/white_kit fetch --tags
addons/white_kit/tools/shots.sh before-after . tools/shots.txt v<old> v<new>   # from phase 1b
git -C addons/white_kit checkout v<new>
git add addons/white_kit
# run the tests, then commit: chore: update White Kit to v<new>
```

| Folder | Content |
|---|---|
| `sim/` | Rules (`DriftBoard`), solver (`DriftSolver`), generator (`DriftGenerator`), game constants and puzzle store (`DriftGame`). No scenes, no nodes, no UI. |
| `ui/` | Main screen (`main.gd`, extends `WhiteDayScreen`), board view (`board_view.gd`, extends `WhiteTileView`), texts (`strings.gd`). Depends on `sim/` and the kit, never the other way round. |
| `tools/` | Headless scripts: `build_puzzles.gd` (extends `WhitePrecompute`), `verify_puzzles.gd`, `measure.gd`; the screenshot scenario file `shots.txt`. |
| `data/` | Precomputed puzzles: the pool `practice.json` (phase 1); `daily.json` from phase 2. |
| `tests/` | Headless test runner (extends `WhiteTestRunner`) and tests. |
| `addons/white_kit/` | White Kit (submodule). |
| `build/` | Local output (exports, generated puzzle files, screenshots). Ignored by git. |

There is no `LICENSE` file: all rights reserved.

## GDScript style

- Godot style guide: tabs, `snake_case` functions and variables, `PascalCase` classes and enums, `UPPER_CASE`
  constants. Lines within 120 characters.
- Static typing everywhere; kit interface methods keep the kit's `Variant` signatures.
- Internal members and functions start with `_` (kit hooks too).
- Global classes have the prefix `Drift` (`DriftBoard`, `DriftSolver`, `DriftGenerator`, `DriftGame`,
  `DriftBoardView`, `DriftStrings`). Kit classes have the prefix `White`; do not declare `White*` names here.
- `sim/` code must not use scenes, nodes, input, rendering, time or `user://`. It may use `JSON` and `FileAccess` on
  `res://`, and kit `core/` classes.
- Hot paths (tilt, solver, generator) work on `PackedByteArray` states and integer direction codes; segments are
  cached per board and direction.
- Every rule change keeps `DriftBoard.tilt()` and `DriftBoard.tilt_reference()` in agreement; the two use different
  algorithms on purpose (segment packing versus one-cell passes).
- Documentation comments use `##`; ordinary comments `#`. Comments and identifiers in English.
- Player-facing texts live in `ui/strings.gd` (`DriftStrings.TEXT`, Dutch and English), registered through the kit.
- Look-and-feel values (colours, sizes, timings) are set at the top of `ui/board_view.gd`.
- No credentials, keys or personal data in the repository.

## Coordinates and notation

- `x` to the right, `y` upwards, `(0, 0)` bottom-left, cell index `y * w + x` (as the kit tile view).
- Direction codes `R=0, L=1, D=2, U=3`; `U` is towards the top of the screen. Move tokens are the single letters.
- Board text (`render()`, `board.rows`) lists the top row first; characters `.#234` (`#` is a block).
- The board view converts to screen coordinates; nothing else uses screen orientation.

## Determinism

- The generator gives the same puzzle for the same seed on every machine: only `WhiteRng` (`range_int`, `shuffle`);
  never `RandomNumberGenerator`, `randi`, `randf`, `randomize` or `WhiteRng.next_float` in `sim/`.
- No floats in rules, solver or generator.
- Search limits are counts (depth, states, candidates), never time. The solver's frontier and direction order are
  fixed, so `path` is reproducible.
- Seeds: `WhiteSeed.practice("white-drift", i, level)` for the pool; trial seeds
  `WhiteSeed.fnv1a64("white-drift-trial|<n>|<level>")`; [later] `WhiteSeed.daily("white-drift", date, level)`.
- In phase 1 the pool may be rebuilt freely; from phase 2 published days are never regenerated.

## Tests

- Run headless; import first after a fresh clone or a new `class_name`:

```bash
godot --headless --path . --import
timeout 300 godot --headless --path . res://addons/white_kit/tests/run_kit_tests.tscn
timeout 300 godot --headless --path . res://tests/run_tests.tscn -- --min-checks=<N>
```

- `tests/run_tests.gd` extends `WhiteTestRunner`; CI's `MIN_CHECKS` equals the current check count; raise it when
  tests are added.
- `what` in `check(ok, what)` describes the expected behaviour in plain words.
- Rule tests build boards with `DriftBoard.from_rows()` and compare with `render()`. Every example in design 2.8 is a
  test. The independent oracle shares no code with `DriftBoard`.
- Solver tests compare with a plain enumeration of tilt sequences on small boards.
- Every shipped puzzle in `data/` is re-checked by the tests (converts, stable, path clears the board in par tilts,
  par in band, `exact` true). Full re-solving is done with `tools/verify_puzzles.gd`, not in CI.
- UI is checked with the kit's debug screenshot mode and `tools/shots.txt`; screenshots are not committed.

## Puzzle data

- Measure the generator before and after changing it:

```bash
godot --headless --path . -s res://tools/measure.gd -- --seeds=50
```

- Phase 1: build the pool, merge, verify, then copy to `data/`. The whole pool takes seconds; when building in parallel
  on a shared machine use at most 3 Godot processes:

```bash
G="godot --headless --path . -s res://tools/build_puzzles.gd --"
$G --practice=14 --start=0 --out=build/p0.json &
$G --practice=13 --start=14 --out=build/p1.json &
$G --practice=13 --start=27 --out=build/p2.json &
wait
for k in 0 1 2; do $G --merge=build/p$k.json --into=build/practice.json; done
godot --headless --path . -s res://tools/verify_puzzles.gd -- --file=build/practice.json
```

- [later] Daily puzzles: build ahead, verify, then `--merge` into `data/daily.json`; keep at least 14 days ahead.
- Run the tests and the verify tool before committing data.

## Git and CI

- `develop` is the working branch; every push to `develop` runs CI and (from phase 1b) publishes the play version at
  https://play.whitedrift.steefbeest.nl. `main` is protected and updated through pull requests only.
- `.github/workflows/ci.yml` comes from the kit template (`addons/white_kit/templates/ci.yml`).
- Branch names: `feature/<description>`, `fix/<description>`, `chore/<description>`.
- Commit messages in English, imperative, short subject line.
- CI must be green before merging to `main`. Do not commit build output.
