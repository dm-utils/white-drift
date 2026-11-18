extends RefCounted
## Solver and generator (design 5.4, 5.5, 13.1): examples, plain enumeration, determinism, filters.

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	_examples()
	_enumeration()
	_greedy()
	_generator()
	_no_native_random()


func _examples() -> void:
	var b := preload("res://tests/rules_tests.gd").mk(["2...", "..3.", "3.23"])
	var r := DriftSolver.solve(b, b.start, 10, 10000)
	_check.call(r.par == 2 and r.exact and r.solutions == 2 and not r.capped, "example 5: par 2, exact, two solutions")
	_check.call(r.path == PackedInt32Array([DriftBoard.Dir.D, DriftBoard.Dir.R]), "example 5: first path is D R")
	var r1 := DriftSolver.solve(b, b.start, 1, 10000)
	_check.call(r1.par == -1 and not r1.capped and not r1.exact, "example 5 with max_depth 1: none, not capped")
	var r2 := DriftSolver.solve(b, b.start, 10, 1)
	_check.call(r2.par == -1 and r2.capped, "example 5 with max_states 1: capped")
	var b4 := preload("res://tests/rules_tests.gd").mk(["3...", ".2.3", "2.3."])
	var r4 := DriftSolver.solve(b4, b4.start, 10, 10000)
	_check.call(r4.par == 1 and r4.solutions == 2 and r4.path == PackedInt32Array([DriftBoard.Dir.R]),
			"example 4: par 1, two solutions, R found before L")
	var b6 := preload("res://tests/rules_tests.gd").mk(["2#.", "#2#"])
	var r6 := DriftSolver.solve(b6, b6.start, 10, 10000)
	_check.call(r6.par == -1 and not r6.capped and r6.states == 1, "example 6: no solution, one state")
	var done := preload("res://tests/rules_tests.gd").mk(["#.", ".#"])
	_check.call(DriftSolver.solve(done, done.start, 5, 10).par == 0, "a cleared board has par 0")


# plain enumeration of all tilt sequences without ignored tilts: [shortest length or -1, number of shortest ones]
func _enumerate(b: DriftBoard, s: PackedByteArray, depth: int, limit: int) -> Array:
	if b.is_solved(s):
		return [depth, 1]
	if depth == limit:
		return [-1, 0]
	var best := -1
	var count := 0
	for d in 4:
		var t: Variant = b.apply(s, d)
		if t == null:
			continue
		var sub := _enumerate(b, t, depth + 1, limit)
		if sub[0] < 0:
			continue
		if best < 0 or sub[0] < best:
			best = sub[0]
			count = sub[1]
		elif sub[0] == best:
			count += sub[1]
	return [best, count]


func _enumeration() -> void:
	var rng := WhiteRng.new(77)
	var same := true
	var solvable := 0
	var multi := 0
	var rules := preload("res://tests/rules_tests.gd")
	for i in 30:
		var w := rng.range_int(3, 4)
		var h := rng.range_int(3, 4)
		var b := DriftBoard.create(w, h)
		var s := PackedByteArray()
		s.resize(w * h)
		var cells: Array = range(w * h)
		rng.shuffle(cells)
		var k := 0
		for j in rng.range_int(0, 2):
			s[cells[k]] = DriftBoard.BLOCK
			k += 1
		# groups of equal values: 2 + 2, 3, 2 + 3 ... at most 8 tiles
		var values: Array = []
		for j in rng.range_int(1, 3):
			var v := rng.range_int(2, 3)
			if k + values.size() + v > w * h:
				continue
			for m in v:
				values.append(v)
		rng.shuffle(values)
		for v in values:
			s[cells[k]] = v
			k += 1
		while true:
			var ex := b.exact_groups(s)
			if ex.is_empty():
				break
			for g in ex:
				for c in g:
					s[c] = 0
		b.start = s
		var plain := _enumerate(b, s, 0, 6)
		var r := DriftSolver.solve(b, s, 6, 1000000)
		var want_par: int = plain[0]
		var want_sol: int = plain[1]
		if r.par != want_par or r.solutions != want_sol:
			same = false
			print("solver differs on %s: par %d/%d solutions %d/%d" % [b.render(s), r.par, want_par, r.solutions, want_sol])
		solvable += 1 if want_par > 0 else 0
		multi += 1 if want_sol > 1 else 0
	_check.call(same, "solver par and solutions equal plain enumeration on 30 small random boards")
	_check.call(solvable >= 6, "enumeration boards include solvable ones (%d)" % solvable)
	_check.call(multi >= 1, "enumeration boards include one with several shortest solutions (%d)" % multi)
	_check.call(rules != null, "rules helper loads")


func _greedy() -> void:
	var b := preload("res://tests/rules_tests.gd").mk(["3...", ".2.3", "2.3."])
	var g := DriftSolver.greedy(b, b.start, 10)
	_check.call(g.solved and g.moves == 1 and g.path == PackedInt32Array([DriftBoard.Dir.R]),
			"greedy on example 4 clears in one tilt, R before L on a tie")
	var b6 := preload("res://tests/rules_tests.gd").mk(["2#.", "#2#"])
	var g6 := DriftSolver.greedy(b6, b6.start, 10)
	_check.call(not g6.solved and g6.moves == 0, "greedy stops when no tilt removes a tile")
	var b5 := preload("res://tests/rules_tests.gd").mk(["2...", "..3.", "3.23"])
	_check.call(not DriftSolver.greedy(b5, b5.start, 10).solved, "greedy cannot solve example 5 (no tilt removes tiles at first)")


func _generator() -> void:
	var a := DriftGenerator.generate(12345, 0)
	var b := DriftGenerator.generate(12345, 0)
	var ab: DriftBoard = a.board
	var bb: DriftBoard = b.board
	_check.call(ab.render(ab.start) == bb.render(bb.start) and a.par == b.par and a.solutions == b.solutions
			and a.path == b.path, "generate twice with one seed gives the same puzzle")
	var all_ok := true
	var in_band := true
	var kinds_ok := true
	for level in 2:
		for n in 3:
			var r := DriftGenerator.generate(WhiteSeed.fnv1a64("white-drift-test|%d|%d" % [n, level]), level)
			var board: DriftBoard = r.board
			var s := board.start
			var band: Array = DriftGenerator.LEVELS[level].band
			all_ok = all_ok and board.is_stable(s) and not board.is_dead_end(s)
			for v in [2, 3, 4]:
				var count := 0
				for c in s:
					count += 1 if c == v else 0
				all_ok = all_ok and count % v == 0
			var t := s
			for m in r.path:
				var nx: Variant = board.apply(t, m)
				if nx == null:
					all_ok = false
					break
				t = nx
			all_ok = all_ok and board.is_solved(t) and r.path.size() == r.par and r.exact
			in_band = in_band and (r.fallback or (r.par >= band[0] and r.par <= band[1]))
			var kinds := {}
			for c in s:
				if c >= 2:
					kinds[c] = true
			kinds_ok = kinds_ok and (r.fallback or kinds.size() >= DriftGenerator.LEVELS[level].values)
	_check.call(all_ok, "generated puzzles: stable, balanced, no dead end, path clears the board in par tilts")
	_check.call(in_band, "generated par lies in the band unless fallback")
	_check.call(kinds_ok, "generated puzzles have enough different values")
	var cfg: Dictionary = DriftGenerator.LEVELS[0].duplicate()
	cfg.candidates = 1
	cfg.band = [60, 70]
	var fb := DriftGenerator.generate_with(1, cfg)
	_check.call(fb.fallback, "an unreachable band gives a fallback")
	var js := DriftGenerator.to_json(DriftGenerator.generate(12345, 0))
	_check.call(js.has("board") and js.exact and js.path.length() == js.par and not js.has("fallback"),
			"to_json gives the puzzle object")
	var conv := DriftGame.convert(JSON.parse_string(JSON.stringify(js)))
	_check.call(conv.par == a.par and conv.path == a.path and conv.board.start == ab.start,
			"a puzzle object converts back through DriftGame.convert")


func _no_native_random() -> void:
	var bad := false
	var dir := DirAccess.open("res://sim")
	for f in dir.get_files():
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string("res://sim/" + f)
			for token in ["RandomNumberGenerator", "randi(", "randf(", "randomize(", "next_float", "randi_range("]:
				if text.contains(token):
					bad = true
					print("sim/%s uses %s" % [f, token])
	_check.call(not bad, "no file in sim/ uses native randomness")
