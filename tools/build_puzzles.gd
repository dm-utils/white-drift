extends WhitePrecompute
## Precomputes puzzles so a phone never has to search.
##   godot --headless --path . -s res://tools/build_puzzles.gd -- --practice=40 [--start=0] --out=build/practice.json
## Practice seed: "white-drift-practice|<i>|<level>". Output {"<i>": [easy, medium, hard]}, puzzle format design 6.3.


func _game_id() -> String:
	return DriftGame.GAME_ID


func _generate(seed_value: int, level: int) -> Dictionary:
	return DriftGenerator.to_json(DriftGenerator.generate(seed_value, level))


func _summary(puzzles: Array) -> String:
	var par := []
	var solutions := []
	var fb := false
	for p in puzzles:
		par.append(p.par)
		solutions.append(p.solutions)
		fb = fb or p.has("fallback")
	return " par %s solutions %s%s" % [par, solutions, " FALLBACK" if fb else ""]
