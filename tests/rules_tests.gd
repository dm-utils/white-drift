extends RefCounted
## Rules of design 2: the examples, packing, fast vs reference, traces, invariants, notation, attempt and record.

const R := DriftBoard.Dir.R
const L := DriftBoard.Dir.L
const D := DriftBoard.Dir.D
const U := DriftBoard.Dir.U

var _check: Callable


func run(check: Callable, _node: Node) -> void:
	_check = check
	_examples()
	_segments()
	_random_agreement()
	_traced()
	_invariants()
	_notation()
	_attempt()


static func mk(rows: Array) -> DriftBoard:
	var b := DriftBoard.create(str(rows[0]).length(), rows.size())
	b.start = b.from_rows(PackedStringArray(rows))
	return b


## Random stable state: random tiles and blocks in random cells, then exact groups cleared (not packed).
static func random_state(b: DriftBoard, rng: WhiteRng, blocks: int, tiles: int) -> PackedByteArray:
	var cells: Array = range(b.w * b.h)
	rng.shuffle(cells)
	var s := PackedByteArray()
	s.resize(b.w * b.h)
	for k in blocks:
		s[cells[k]] = DriftBoard.BLOCK
	for k in mini(tiles, b.w * b.h - blocks):
		s[cells[blocks + k]] = rng.range_int(2, 4)
	while true:
		var ex := b.exact_groups(s)
		if ex.is_empty():
			break
		for g in ex:
			for c in g:
				s[c] = 0
	return s


## Board of the given size whose blocks come from a random state, plus that state.
static func random_board(rng: WhiteRng, w: int, h: int, blocks: int, tiles: int) -> DriftBoard:
	var b := DriftBoard.create(w, h)
	b.start = random_state(b, rng, blocks, tiles)
	return b


func _tilt(b: DriftBoard, s: PackedByteArray, d: int) -> String:
	return b.render(b.tilt(s, d))


func _examples() -> void:
	var b := mk(["....", ".3..", "2..2"])
	_check.call(b.is_stable(b.start), "example 1 start is stable")
	_check.call(b.render(b.pack(b.start, L)) == "....\n3...\n22..", "example 1: packed left, the 2s touch")
	_check.call(_tilt(b, b.start, L) == "....\n3...\n....", "example 1: the pair vanishes, the 3 stays (no gravity)")
	b = mk(["..2.2", "2#.2."])
	_check.call(_tilt(b, b.start, D) == ".....\n2#222", "example 2: block holds a tile, overfull group stays")
	var s := b.tilt(b.start, D)
	_check.call(b.apply(s, D) == null, "example 3: tilt D again is ignored")
	_check.call(b.apply(s, L) == null, "example 3: tilt L is ignored")
	_check.call(b.apply(s, R) == null, "example 3: tilt R is ignored")
	_check.call(b.apply(s, U) != null, "example 3: tilt U changes the board")
	b = mk(["3...", ".2.3", "2.3."])
	_check.call(_tilt(b, b.start, L) == "....\n....\n....", "example 4: tilt L clears the board in a chain")
	_check.call(b.render(b.pack(b.start, L)) == "3...\n23..\n23..", "example 4: packed left")
	_check.call(_tilt(b, b.start, R) == "....\n....\n....", "example 4: tilt R clears the board without a chain")
	b = mk(["2...", "..3.", "3.23"])
	_check.call(b.render(b.tilt(b.start, D)) == "....\n2.3.\n3.23", "example 5: D drops the 2 onto the 3")
	s = b.tilt(b.start, D)
	_check.call(b.render(b.pack(s, R)) == "....\n..23\n.323", "example 5: R packs both rows")
	_check.call(b.is_solved(b.tilt(s, R)), "example 5: R then clears the board through a chain")
	for path in ["DR", "UR"]:
		var t := b.start
		for ch in path:
			t = b.tilt(t, b.decode_move(ch))
		_check.call(b.is_solved(t), "example 5: path %s clears the board" % path)
	for d in 4:
		_check.call(b.tilt(b.start, d) != b.start and not b.is_solved(b.tilt(b.start, d)),
				"example 5: no single tilt %s clears it" % DriftBoard.DIR_LETTERS[d])
	b = mk(["2#.", "#2#"])
	_check.call(b.is_dead_end(b.start), "example 6: dead end")
	_check.call(b.legal_moves(b.start).is_empty(), "example 6: no tilt changes anything")
	for rows in [["....", ".3..", "2..2"], ["..2.2", "2#.2."], ["3...", ".2.3", "2.3."], ["2...", "..3.", "3.23"]]:
		var e := mk(rows)
		_check.call(not e.is_dead_end(e.start), "no dead end at the start of %s" % str(rows))
	b = mk(["..2.2", "2#.2."])
	_check.call(b.legal_moves(b.tilt(b.start, D)) == PackedInt32Array([U]), "example 3: only U is legal after D")


func _segments() -> void:
	var b := mk(["..2.2", "2#.2."])
	var segs := b.segments(L)
	_check.call(segs.size() == 3, "L: row 1 has two segments, row 2 one")
	_check.call(segs[0] == PackedInt32Array([0]) and segs[1] == PackedInt32Array([2, 3, 4]),
			"L: row 1 segments are [A1] and [C1, D1, E1], front first")
	_check.call(segs[2] == PackedInt32Array([5, 6, 7, 8, 9]), "L: row 2 is one segment of five cells")
	_check.call(b.segments(R)[0] == PackedInt32Array([4, 3, 2]), "R: front is the right end")
	_check.call(b.segments(D)[0] == PackedInt32Array([0, 5]), "D: column A from the bottom")
	_check.call(b.segments(U)[0] == PackedInt32Array([5, 0]), "U: column A from the top")
	_check.call(b.segments(D).size() == 5, "D: five columns, the block only shortens column B")
	_check.call(b.cell_name(0) == "A1" and b.cell_name(9) == "E2", "cell names, A1 bottom-left")


func _random_agreement() -> void:
	var rng := WhiteRng.new(101)
	var agree := true
	var immutable := true
	var shrinks := true
	var mods := true
	var blocks_kept := true
	var packed := true
	var stable := true
	var again := true
	var n_eff := 0
	for i in 10000:
		var b := random_board(rng, rng.range_int(3, 7), rng.range_int(3, 7), rng.range_int(0, 4), rng.range_int(4, 14))
		var s := b.start
		var d := rng.range_int(0, 3)
		var keep := s.duplicate()
		var t := b.tilt(s, d)
		agree = agree and t == b.tilt_reference(s, d) and t == b.tilt_traced(s, d).state
		immutable = immutable and s == keep
		shrinks = shrinks and b.count_tiles(t) <= b.count_tiles(s)
		for v in [2, 3, 4]:
			mods = mods and _count(t, v) % v == _count(s, v) % v
		for c in s.size():
			if s[c] == DriftBoard.BLOCK:
				blocks_kept = blocks_kept and t[c] == DriftBoard.BLOCK
			elif t[c] == DriftBoard.BLOCK:
				blocks_kept = false
		var applied: Variant = b.apply(s, d)
		immutable = immutable and s == keep
		if applied != null:
			n_eff += 1
			packed = packed and b.is_packed(applied, d)
			stable = stable and b.is_stable(applied)
			again = again and b.apply(applied, d) == null
	_check.call(agree, "tilt equals tilt_reference and tilt_traced on 10000 random pairs")
	_check.call(n_eff > 3000, "enough effective tilts among the random pairs (%d)" % n_eff)
	_check.call(immutable, "tilt and apply never modify their argument")
	_check.call(shrinks and mods and blocks_kept, "tile count never grows, count mod value constant, blocks fixed")
	_check.call(packed and stable and again, "after an effective tilt: packed, stable, same tilt ignored")


func _count(s: PackedByteArray, v: int) -> int:
	var n := 0
	for c in s:
		n += 1 if c == v else 0
	return n


func _traced() -> void:
	var b := mk(["3...", ".2.3", "2.3."])
	var tl := b.tilt_traced(b.start, L)
	var kinds: Array = tl.steps.map(func(st: Dictionary) -> String: return st.kind)
	_check.call(kinds == ["tilt", "vanish", "tilt", "vanish"], "example 4 L: tilt, vanish, tilt, vanish (got %s)" % [kinds])
	_check.call(tl.steps.filter(func(st: Dictionary) -> bool: return st.kind == "vanish").size() == 2,
			"example 4 L: exactly two vanish steps")
	_check.call(b.is_solved(tl.state), "example 4 L: traced result is empty")
	var tr := b.tilt_traced(b.start, R)
	_check.call(tr.steps.filter(func(st: Dictionary) -> bool: return st.kind == "vanish").size() == 1,
			"example 4 R: exactly one vanish step")
	_check.call(tl.steps[1].cells == [0, 4], "example 4 L: first wave removes the 2s (A1, A2)")
	var b1 := mk(["....", ".3..", "2..2"])
	var t1 := b1.tilt_traced(b1.start, L)
	_check.call(t1.steps[0].moves.size() == 2 and t1.steps[1].cells == [0, 1], "example 1 traced: two moves, then the pair")
	var moved := {}
	for m in t1.steps[0].moves:
		moved[m[0]] = m[1]
	_check.call(moved == {3: 1, 5: 4}, "example 1 traced: moves are [from, to] cell indices")
	var b2 := mk(["..2.2", "2#.2."])
	_check.call(b2.tilt_traced(b2.start, D).steps.size() == 1, "overfull group: a single tilt step, no vanish")


func _invariants() -> void:
	var rng := WhiteRng.new(5)
	var ok := true
	for i in 200:
		var b := random_board(rng, 5, 5, 2, 8)
		for d in 4:
			var tr := b.tilt_traced(b.start, d)
			# replaying the steps by hand gives the same state
			var s := b.start.duplicate()
			for st in tr.steps:
				if st.kind == "tilt":
					var vals := {}
					for m in st.moves:
						vals[m[1]] = s[m[0]]
						s[m[0]] = 0
					for c in vals:
						s[c] = vals[c]
				else:
					for c in st.cells:
						s[c] = 0
			ok = ok and s == tr.state
	_check.call(ok, "replaying the trace steps gives the traced result")
	var b := mk(["2.", ".2"])
	_check.call(b.apply(b.start, 7) == null and b.apply(b.start, "R") == null and b.apply(b.start, -1) == null,
			"apply rejects moves that are not 0..3")
	_check.call(b.is_solved(mk(["#.", ".#"]).start), "a board of blocks only is solved")


func _notation() -> void:
	var b := mk(["..2.2", "2#.2."])
	for d in 4:
		_check.call(b.encode_move(d) == "RLDU"[d] and b.decode_move("RLDU"[d]) == d, "token round trip %d" % d)
	_check.call(b.decode_move("r") == null and b.decode_move("X") == null and b.decode_move("") == null
			and b.decode_move("RR") == null, "decode_move rejects junk")
	_check.call(b.move_len() == 1, "move_len is 1")
	var back := DriftBoard.from_dict(b.to_dict(b.start))
	_check.call(back.start == b.start and back.w == 5 and back.h == 2, "from_dict(to_dict) round-trips")
	var from_json := DriftBoard.from_dict(JSON.parse_string(JSON.stringify(b.to_dict(b.start))))
	_check.call(from_json.start == b.start, "from_dict accepts parsed JSON (floats)")
	var dict := {PackedByteArray([2, 3]): 1}
	_check.call(dict.has(PackedByteArray([2, 3])), "equal byte arrays hit the same dictionary entry")
	_check.call(b.render(b.start) == "..2.2\n2#.2.", "render lists the top row first")


func _attempt() -> void:
	var b := mk(["2...", "..3.", "3.23"])
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	a.apply_record("LzDR")
	_check.call(a.solved(), "record LzDR solves example 5")
	_check.call(a.count() == 2 and a.record == "LzDR" and a.moves_made == 3, "FINAL_ONLY counts 2, record kept")
	var e := WhiteAttempt.new(b, WhiteAttempt.CountMode.EVERY_MOVE)
	e.apply_record("LzDR")
	_check.call(e.count() == 3, "EVERY_MOVE counts 3")
	var f := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	f.apply_record("LzDDR")
	_check.call(f.record == "LzDR" and f.count() == 2, "an ignored tilt changes neither record nor count")
	_check.call(f.state == a.state and f.moves_made == a.moves_made, "apply_record reproduces state and moves_made")
