extends SceneTree
## Phase 1 trial (design 5.7).
##   godot --headless --path . -s res://tools/measure.gd -- [--seeds=50] [--level=N] [--from=0] [--skip-m1]
##       [--cfg=<json merged into the level config>] [--verbose]
## M1: tilt() and search throughput. M2: per level over the trial seeds; checks P1 and, with all levels, P2 and P3.

const NAMES := ["easy", "medium", "hard"]


func _init() -> void:
	var seeds := 50
	var only := -1
	var first := 0
	var m1 := true
	var verbose := false
	var override := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.get_slice("=", 1))
		elif a.begins_with("--level="):
			only = int(a.get_slice("=", 1))
		elif a.begins_with("--from="):
			first = int(a.get_slice("=", 1))
		elif a.begins_with("--cfg="):
			override = JSON.parse_string(a.substr(6))
		elif a == "--skip-m1":
			m1 = false
		elif a == "--verbose":
			verbose = true
	if m1:
		_m1()
	var medians := []
	var total_s := 0.0
	var ok := true
	for level in 3:
		if only >= 0 and level != only:
			continue
		var r := _m2(level, seeds, first, override, verbose)
		medians.append(r.par_median)
		total_s += r.total_s
		ok = ok and r.ok
	if only < 0:
		var inc: bool = medians[0] < medians[1] and medians[1] < medians[2]
		print("P2 median par strictly increasing %s (%s)" % ["ok" if inc else "FAIL", medians])
		print("P3 estimate for 40 sets on one process: %.0f s (%.1f min) from %.0f s per %d seeds x 3 levels" % [
			total_s * 40.0 / seeds, total_s * 40.0 / seeds / 60.0, total_s, seeds])
		ok = ok and inc
	print("trial " + ("ok" if ok else "FAILED"))
	quit(0 if ok else 1)


func _m1() -> void:
	var rules := preload("res://tests/rules_tests.gd")
	var rng := WhiteRng.new(7)
	var boards: Array = []
	var states: Array = []
	while states.size() < 200:
		var b := DriftBoard.create(6, 6)
		var s := rules.random_state(b, rng, 4, rng.range_int(12, 16))
		b.start = s
		# blocks are in the start, so the board must be built from the state that holds them
		boards.append(b)
		states.append(s)
	var n := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < 3000000:
		for i in states.size():
			for d in 4:
				boards[i].tilt(states[i], d)
				n += 1
	print("M1 tilt(): %.0f per second (6x6, 4 blocks, 12-16 tiles)" % (n / ((Time.get_ticks_usec() - t0) / 1e6)))
	var r := DriftGenerator.generate(WhiteSeed.fnv1a64("white-drift-trial|0|2"), 2)
	var pb: DriftBoard = r.board
	var t1 := Time.get_ticks_usec()
	var total := 0
	for k in 20:
		var sol := DriftSolver.solve(pb, pb.start, 11, 1000000)
		total += sol.states
	var dt := (Time.get_ticks_usec() - t1) / 1e6
	print("M1 search: %.0f states per second (%d states per solve of a hard puzzle)" % [total / dt, total / 20])


func _m2(level: int, seeds: int, first: int, override: Dictionary, verbose: bool) -> Dictionary:
	var cfg: Dictionary = DriftGenerator.LEVELS[level].duplicate()
	cfg.merge(override, true)
	var pars := PackedInt32Array()
	var sols := PackedInt32Array()
	var states := PackedInt32Array()
	var tiles := PackedInt32Array()
	var blocks := PackedInt32Array()
	var tried := PackedInt32Array()
	var times := PackedFloat64Array()
	var fallback := 0
	var greedy_solved := 0
	var solvable_total := 0
	var tried_total := 0
	var capped_total := 0
	var total := 0.0
	for n in range(first, first + seeds):
		var t0 := Time.get_ticks_usec()
		var r := DriftGenerator.generate_with(WhiteSeed.fnv1a64("white-drift-trial|%d|%d" % [n, level]), cfg)
		var dt := (Time.get_ticks_usec() - t0) / 1e6
		total += dt
		times.append(dt)
		var b: DriftBoard = r.board
		var nt := b.count_tiles(b.start)
		var nbl := b.start.count(DriftBoard.BLOCK)
		pars.append(r.par)
		sols.append(r.solutions)
		states.append(r.states)
		tiles.append(nt)
		blocks.append(nbl)
		tried.append(r.tried)
		fallback += 1 if r.fallback else 0
		tried_total += r.tried
		solvable_total += r.solvable
		capped_total += r.capped
		if r.par > 0:
			greedy_solved += 1 if DriftSolver.greedy(b, b.start, 3 * cfg.band[1]).solved else 0
		if verbose:
			print("  %s seed %d: par %d solutions %d states %d tried %d fallback %s tiles %d blocks %d %.1f s" % [
				NAMES[level], n, r.par, r.solutions, r.states, r.tried, r.fallback, nt, nbl, dt])
	var nonfb := seeds - fallback
	var need := ceili(seeds * 0.8)
	print("M2 %-6s %dx%d  non-fallback %d/%d  tried med %d max %d  solvable %.1f%% capped %.1f%%  tiles med %d blocks med %d" % [
		NAMES[level], cfg.w, cfg.h, nonfb, seeds, _median_i(tried), Array(tried).max(),
		100.0 * solvable_total / maxi(tried_total, 1), 100.0 * capped_total / maxi(tried_total, 1),
		_median_i(tiles), _median_i(blocks)])
	print("   par med %d (%s)  solutions med %d max %d  states med %d max %d  greedy solved %d/%d  build s med %.1f max %.1f total %.0f" % [
		_median_i(pars), _spread(pars), _median_i(sols), Array(sols).max(), _median_i(states), Array(states).max(),
		greedy_solved, seeds, _median_f(times), Array(times).max(), total])
	print("P1 %s: %d of %d non-fallback (need %d)" % [NAMES[level], nonfb, seeds, need])
	return {"ok": nonfb >= need, "par_median": _median_i(pars), "total_s": total}


func _spread(a: PackedInt32Array) -> String:
	var d := {}
	for v in a:
		d[v] = d.get(v, 0) + 1
	var keys := d.keys()
	keys.sort()
	return " ".join(keys.map(func(k: int) -> String: return "%d:%d" % [k, d[k]]))


func _median_i(a: PackedInt32Array) -> int:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]


func _median_f(a: PackedFloat64Array) -> float:
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]
