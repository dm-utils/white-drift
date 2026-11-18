class_name DriftGenerator
extends RefCounted
## Forward generation (design 5.4, ADR 0004): random start with the right tile counts, kept when the exact solver
## and the filters accept it. Only WhiteRng, no floats.

## blocks, groups: [min, max]; values: least number of different values; gap 0 = no greedy filter
const LEVELS := [
	{"w": 5, "h": 5, "blocks": [1, 2], "groups": [3, 3], "values": 2, "gap": 0, "band": [3, 4],
			"candidates": 600, "cap": 50000},
	{"w": 6, "h": 6, "blocks": [2, 3], "groups": [4, 4], "values": 3, "gap": 1, "band": [5, 7],
			"candidates": 1500, "cap": 100000},
	{"w": 6, "h": 6, "blocks": [3, 4], "groups": [4, 5], "values": 3, "gap": 2, "band": [8, 11],
			"candidates": 3000, "cap": 200000},
]


static func generate(seed_value: int, level: int) -> Dictionary:
	return generate_with(seed_value, LEVELS[level])


static func generate_with(seed_value: int, cfg: Dictionary) -> Dictionary:
	var rng := WhiteRng.new(seed_value)
	var w: int = cfg.w
	var h: int = cfg.h
	var band: Array = cfg.band
	var best: Dictionary = {}
	var best_key: Array = []
	var tried := 0
	for t in int(cfg.candidates):
		tried += 1
		var nb := rng.range_int(cfg.blocks[0], cfg.blocks[1])
		var ng := rng.range_int(cfg.groups[0], cfg.groups[1])
		var tiles: Array = []
		for g in ng:
			var v := rng.range_int(2, 4)
			for k in v:
				tiles.append(v)
		if tiles.size() + nb > w * h:
			continue
		var cells: Array = range(w * h)
		rng.shuffle(cells)
		rng.shuffle(tiles)
		var board := DriftBoard.create(w, h)
		var s := PackedByteArray()
		s.resize(w * h)
		for k in nb:
			s[cells[k]] = DriftBoard.BLOCK
		for k in tiles.size():
			s[cells[nb + k]] = tiles[k]
		board.start = s
		if not board.is_stable(s) or _kinds(tiles) < int(cfg.values) or board.is_dead_end(s):
			continue
		var r := DriftSolver.solve(board, s, band[1], cfg.cap)
		if r.par < 0:
			continue
		var accepted: bool = r.par >= band[0]
		if accepted and int(cfg.gap) > 0:
			var gr := DriftSolver.greedy(board, s, 3 * band[1])
			if gr.solved and gr.moves < r.par + int(cfg.gap):
				accepted = false
		var result := _result(board, r, false, tried)
		if accepted:
			return result
		var key := [maxi(band[0] - r.par, 0), r.solutions, tiles.size()]
		if best.is_empty() or _less(key, best_key):
			best = result
			best_key = key
	if best.is_empty():
		var board := DriftBoard.create(w, h)
		return {"board": board, "par": 0, "exact": false, "solutions": 0, "path": PackedInt32Array(), "states": 0,
				"tried": tried, "fallback": true}
	best.fallback = true
	best.tried = tried
	return best


static func _result(board: DriftBoard, r: Dictionary, fallback: bool, tried: int) -> Dictionary:
	return {"board": board, "par": r.par, "exact": true, "solutions": r.solutions, "path": r.path,
			"states": r.states, "tried": tried, "fallback": fallback}


static func _kinds(tiles: Array) -> int:
	var seen := {}
	for v in tiles:
		seen[v] = true
	return seen.size()


static func _less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


## Puzzle object of design 6.3.
static func to_json(result: Dictionary) -> Dictionary:
	var b: DriftBoard = result.board
	var letters := ""
	for m in result.path:
		letters += DriftBoard.DIR_LETTERS[m]
	var out := {"board": b.to_dict(b.start), "par": result.par, "exact": result.exact,
			"solutions": result.solutions, "path": letters}
	if result.fallback:
		out.fallback = true
	return out
