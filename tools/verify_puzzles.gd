extends SceneTree
## Re-solves every puzzle of a file with its level's cap; exit 1 on any mismatch (design 6.4).
##   godot --headless --path . -s res://tools/verify_puzzles.gd -- [--file=res://data/practice.json]


func _init() -> void:
	var path := "res://data/practice.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			path = a.get_slice("=", 1)
	var json := JSON.new()
	if not FileAccess.file_exists(path) or json.parse(FileAccess.get_file_as_string(path)) != OK \
			or not json.data is Dictionary:
		printerr("cannot read " + path)
		quit(1)
		return
	var bad := 0
	var total := 0
	var fallbacks := 0
	var data: Dictionary = json.data
	var keys := data.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(a) < int(b) if str(a).is_valid_int() else str(a) < str(b))
	for key in keys:
		var set: Array = data[key]
		for level in set.size():
			total += 1
			var why := _problem(DriftGame.convert(set[level]), level)
			if bool(set[level].get("fallback", false)):
				fallbacks += 1
			if not why.is_empty():
				bad += 1
				print("MISMATCH %s level %d: %s" % [key, level, why])
	print("verified %d puzzles, %d fallback, %d mismatches" % [total, fallbacks, bad])
	quit(1 if bad > 0 else 0)


func _problem(p: Dictionary, level: int) -> String:
	var b: DriftBoard = p.board
	var cfg: Dictionary = DriftGenerator.LEVELS[level]
	var r := DriftSolver.solve(b, b.start, maxi(p.par, cfg.band[1]), cfg.cap)
	if not p.exact or r.par != p.par or not r.exact:
		return "par %d (stored %d) exact %s" % [r.par, p.par, r.exact]
	if r.solutions != p.solutions:
		return "solutions %d (stored %d)" % [r.solutions, p.solutions]
	var s := b.start
	for m in p.path:
		var n: Variant = b.apply(s, m)
		if n == null:
			return "path has an ignored tilt"
		s = n
	if not b.is_solved(s) or p.path.size() != p.par:
		return "path does not clear the board in par tilts"
	return ""
