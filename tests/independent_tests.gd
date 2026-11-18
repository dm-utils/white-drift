extends RefCounted
## Independent oracle: works on rendered rows as plain strings, shares no code with DriftBoard.

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	var rng := WhiteRng.new(2024)
	var rules := preload("res://tests/rules_tests.gd")
	var agree := true
	for i in 300:
		var b := rules.random_board(rng, rng.range_int(3, 7), rng.range_int(3, 7), rng.range_int(0, 4), rng.range_int(4, 14))
		for d in 4:
			var want := oracle(b.render(b.start), "RLDU"[d])
			if b.render(b.tilt(b.start, d)) != want:
				agree = false
				print("oracle differs (%s):\n%s\n--\n%s" % ["RLDU"[d], b.render(b.start), want])
	_check.call(agree, "an independent string oracle agrees with tilt() on 300 random boards in all four directions")
	_check.call(oracle("....\n.3..\n2..2", "L") == "....\n3...\n....", "oracle on example 1")
	_check.call(oracle("..2.2\n2#.2.", "D") == ".....\n2#222", "oracle on example 2")


## Tilt a board given as text rows (top first); returns text rows.
static func oracle(text: String, dir: String) -> String:
	var rows: Array = Array(text.split("\n"))
	var cols := (rows[0] as String).length()
	var grid: Array = []
	for r in rows:
		grid.append(Array((r as String).split("")))
	# rotate so that the tilt is always "towards the start of each text line"
	var lines: Array = []
	match dir:
		"L":
			lines = grid
		"R":
			for row in grid:
				var rev := (row as Array).duplicate()
				rev.reverse()
				lines.append(rev)
		"U":
			for c in cols:
				var line := []
				for r in grid.size():
					line.append(grid[r][c])
				lines.append(line)
		"D":
			for c in cols:
				var line := []
				for r in range(grid.size() - 1, -1, -1):
					line.append(grid[r][c])
				lines.append(line)
	var changed := true
	var cells := lines
	while changed:
		cells = cells.map(_squash)
		var board := _untransform(cells, dir, rows.size(), cols)
		var gone := _exact(board)
		changed = not gone.is_empty()
		for key in gone:
			var rc: PackedStringArray = key.split(",")
			board[int(rc[0])][int(rc[1])] = "."
		cells = _transform(board, dir)
	var out := _untransform(cells, dir, rows.size(), cols)
	return "\n".join(out.map(func(r: Array) -> String: return "".join(r)))


# one line: stable partition of each block-free chunk, tiles first
static func _squash(line: Array) -> Array:
	var joined := "".join(line)
	var parts := joined.split("#")
	var out: Array = []
	for p in parts:
		var tiles := (p as String).replace(".", "")
		out.append(tiles + ".".repeat(p.length() - tiles.length()))
	return Array("#".join(out).split(""))


static func _transform(board: Array, dir: String) -> Array:
	var rows := board.size()
	var cols := (board[0] as Array).size()
	var lines: Array = []
	match dir:
		"L":
			for r in board:
				lines.append(r.duplicate())
		"R":
			for r in board:
				var rev := (r as Array).duplicate()
				rev.reverse()
				lines.append(rev)
		"U":
			for c in cols:
				var line := []
				for r in rows:
					line.append(board[r][c])
				lines.append(line)
		"D":
			for c in cols:
				var line := []
				for r in range(rows - 1, -1, -1):
					line.append(board[r][c])
				lines.append(line)
	return lines


static func _untransform(lines: Array, dir: String, rows: int, cols: int) -> Array:
	var board: Array = []
	for r in rows:
		var row := []
		row.resize(cols)
		board.append(row)
	for i in lines.size():
		var line: Array = lines[i]
		for k in line.size():
			match dir:
				"L":
					board[i][k] = line[k]
				"R":
					board[i][cols - 1 - k] = line[k]
				"U":
					board[k][i] = line[k]
				"D":
					board[rows - 1 - k][i] = line[k]
	return board


# keys "r,c" of all tiles in groups whose size equals their digit, by recursive search
static func _exact(board: Array) -> Array:
	var seen := {}
	var gone: Array = []
	for r in board.size():
		for c in (board[r] as Array).size():
			var ch: String = board[r][c]
			if not ch.is_valid_int() or seen.has("%d,%d" % [r, c]):
				continue
			var members: Array = []
			_fill(board, r, c, ch, seen, members)
			if members.size() == int(ch):
				gone.append_array(members)
	return gone


static func _fill(board: Array, r: int, c: int, ch: String, seen: Dictionary, members: Array) -> void:
	if r < 0 or c < 0 or r >= board.size() or c >= (board[0] as Array).size():
		return
	var key := "%d,%d" % [r, c]
	if seen.has(key) or board[r][c] != ch:
		return
	seen[key] = true
	members.append(key)
	_fill(board, r + 1, c, ch, seen, members)
	_fill(board, r - 1, c, ch, seen, members)
	_fill(board, r, c + 1, ch, seen, members)
	_fill(board, r, c - 1, ch, seen, members)
