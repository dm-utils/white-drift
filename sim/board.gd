class_name DriftBoard
extends WhiteRules
## Rules of White Drift (design 2, 5.3): tilt the board, tiles slide, exact groups vanish, re-pack in tilt direction.
## State: PackedByteArray, index y * w + x, y upwards; 0 empty, 1 block, 2..4 tile.

enum Dir { R, L, D, U }

const DIR_LETTERS := "RLDU"
const GLYPHS := ".#234"
const BLOCK := 1

var w := 0
var h := 0
## setting the start resets the segment cache (blocks come from the start)
var start := PackedByteArray():
	set(value):
		start = value
		_segments = [null, null, null, null]

var _segments: Array = [null, null, null, null]
var _stamp := PackedInt32Array()
var _stamp_n := 0
var _stack := PackedInt32Array()


static func create(width: int, height: int) -> DriftBoard:
	var b := DriftBoard.new()
	b.w = width
	b.h = height
	var s := PackedByteArray()
	s.resize(width * height)
	b.start = s
	b._stamp.resize(width * height)
	b._stack.resize(width * height)
	return b


static func from_dict(d: Dictionary) -> DriftBoard:
	var n: Array = d.n
	var b := DriftBoard.create(int(n[0]), int(n[1]))
	var rows := PackedStringArray()
	for r in d.rows:
		rows.append(str(r))
	b.start = b.from_rows(rows)
	return b


func to_dict(state: PackedByteArray) -> Dictionary:
	return {"n": [w, h], "rows": Array(render(state).split("\n"))}


## Rows top first, characters ".#234".
func from_rows(rows: PackedStringArray) -> PackedByteArray:
	var s := PackedByteArray()
	s.resize(w * h)
	for row in h:
		var text := rows[row]
		for x in w:
			s[(h - 1 - row) * w + x] = maxi(GLYPHS.find(text[x]), 0)
	return s


func render(state: PackedByteArray) -> String:
	var lines := PackedStringArray()
	for row in h:
		var line := ""
		for x in w:
			line += GLYPHS[state[(h - 1 - row) * w + x]]
		lines.append(line)
	return "\n".join(lines)


## Column letter plus row digit, A1 bottom-left.
func cell_name(i: int) -> String:
	return "%s%d" % [char(65 + i % w), i / w + 1]


# --- White Kit interface -------------------------------------------------------------------------------------------

func start_state() -> Variant:
	return start


func apply(state: Variant, move: Variant) -> Variant:
	if typeof(move) != TYPE_INT or move < 0 or move > 3 or not state is PackedByteArray:
		return null
	var r := tilt(state, move)
	return null if r == state else r


func is_solved(state: Variant) -> bool:
	for c in (state as PackedByteArray):
		if c >= 2:
			return false
	return true


func move_len() -> int:
	return 1


func encode_move(move: Variant) -> String:
	return DIR_LETTERS[move]


func decode_move(token: String) -> Variant:
	if token.length() != 1:
		return null
	var i := DIR_LETTERS.find(token)
	return i if i >= 0 else null


# --- Rules ---------------------------------------------------------------------------------------------------------

## All segments for direction d, cells ordered front to back. Lines ascending, cut at blocks.
func segments(d: int) -> Array[PackedInt32Array]:
	if _segments[d] == null:
		var out: Array[PackedInt32Array] = []
		var lines := h if d < 2 else w
		var length := w if d < 2 else h
		for line in lines:
			var cur := PackedInt32Array()
			for k in length:
				var pos := k
				if d == Dir.R or d == Dir.U:
					pos = length - 1 - k # front first
				var c := line * w + pos if d < 2 else pos * w + line
				if start[c] == BLOCK:
					if not cur.is_empty():
						out.append(cur)
					cur = PackedInt32Array()
				else:
					cur.append(c)
			if not cur.is_empty():
				out.append(cur)
		_segments[d] = out
	return _segments[d]


func pack(state: PackedByteArray, d: int) -> PackedByteArray:
	var s := state.duplicate()
	_pack_in_place(s, d)
	return s


func _pack_in_place(s: PackedByteArray, d: int) -> void:
	for seg in segments(d):
		var j := 0
		var n := seg.size()
		for i in n:
			var v := s[seg[i]]
			if v >= 2:
				s[seg[j]] = v
				j += 1
		for i in range(j, n):
			s[seg[i]] = 0


## Pack, then waves of vanish and re-pack until stable.
func tilt(state: PackedByteArray, d: int) -> PackedByteArray:
	var s := state.duplicate()
	_pack_in_place(s, d)
	while _clear_exact(s):
		_pack_in_place(s, d)
	return s


# clears every exact group in place; false when there was none
func _clear_exact(s: PackedByteArray) -> bool:
	_stamp_n += 1
	var stamp := _stamp_n
	var found := false
	var n := w * h
	for i in n:
		var v := s[i]
		if v < 2 or _stamp[i] == stamp:
			continue
		# whole component, stack holds the component cells
		_stack[0] = i
		var top := 1
		_stamp[i] = stamp
		var size := 0
		var members := 0
		while members < top:
			var c := _stack[members]
			members += 1
			size += 1
			var x := c % w
			if x > 0 and s[c - 1] == v and _stamp[c - 1] != stamp:
				_stamp[c - 1] = stamp
				_stack[top] = c - 1
				top += 1
			if x < w - 1 and s[c + 1] == v and _stamp[c + 1] != stamp:
				_stamp[c + 1] = stamp
				_stack[top] = c + 1
				top += 1
			if c >= w and s[c - w] == v and _stamp[c - w] != stamp:
				_stamp[c - w] = stamp
				_stack[top] = c - w
				top += 1
			if c < n - w and s[c + w] == v and _stamp[c + w] != stamp:
				_stamp[c + w] = stamp
				_stack[top] = c + w
				top += 1
		if size == v:
			found = true
			for k in size:
				s[_stack[k]] = 0
	return found


## Independent algorithm: one-cell passes instead of segment packing, own component search.
func tilt_reference(state: PackedByteArray, d: int) -> PackedByteArray:
	var s := state.duplicate()
	var dx: int = [1, -1, 0, 0][d]
	var dy: int = [0, 0, -1, 1][d]
	while true:
		_slide_passes(s, dx, dy)
		var gone := _reference_groups(s)
		if gone.is_empty():
			return s
		for c in gone:
			s[c] = 0
	return s


func _slide_passes(s: PackedByteArray, dx: int, dy: int) -> void:
	var moved := true
	while moved:
		moved = false
		var snap := s.duplicate()
		for c in w * h:
			if snap[c] < 2:
				continue
			var nx := c % w + dx
			var ny := c / w + dy
			if nx < 0 or nx >= w or ny < 0 or ny >= h:
				continue
			var t := ny * w + nx
			if snap[t] == 0:
				s[t] = snap[c]
				s[c] = 0
				moved = true


func _reference_groups(s: PackedByteArray) -> Array[int]:
	var gone: Array[int] = []
	var seen := {}
	for c in w * h:
		if s[c] < 2 or seen.has(c):
			continue
		var comp: Array[int] = [c]
		seen[c] = true
		var queue: Array[int] = [c]
		while not queue.is_empty():
			var cur: int = queue.pop_back()
			for nb in _neighbours(cur):
				if s[nb] == s[c] and not seen.has(nb):
					seen[nb] = true
					comp.append(nb)
					queue.append(nb)
		if comp.size() == s[c]:
			gone.append_array(comp)
	return gone


func _neighbours(c: int) -> Array[int]:
	var out: Array[int] = []
	var x := c % w
	var y := c / w
	if x > 0:
		out.append(c - 1)
	if x < w - 1:
		out.append(c + 1)
	if y > 0:
		out.append(c - w)
	if y < h - 1:
		out.append(c + w)
	return out


## {"state": result, "steps": [{"kind": "tilt", "moves": [[from, to]]}, {"kind": "vanish", "cells": [...]}, ...]}
func tilt_traced(state: PackedByteArray, d: int) -> Dictionary:
	var s := state.duplicate()
	var steps: Array = []
	var moves := _pack_traced(s, d)
	if not moves.is_empty():
		steps.append({"kind": "tilt", "moves": moves})
	while true:
		var before := s.duplicate()
		if not _clear_exact(s):
			break
		var cells: Array = []
		for i in s.size():
			if before[i] >= 2 and s[i] == 0:
				cells.append(i)
		steps.append({"kind": "vanish", "cells": cells})
		moves = _pack_traced(s, d)
		if not moves.is_empty():
			steps.append({"kind": "tilt", "moves": moves})
	return {"state": s, "steps": steps}


func _pack_traced(s: PackedByteArray, d: int) -> Array:
	var moves: Array = []
	for seg in segments(d):
		var j := 0
		var n := seg.size()
		for i in n:
			var v := s[seg[i]]
			if v >= 2:
				if i != j:
					moves.append([seg[i], seg[j]])
					s[seg[j]] = v
					s[seg[i]] = 0
				j += 1
	return moves


func groups(state: PackedByteArray) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	var seen := {}
	for c in w * h:
		if state[c] < 2 or seen.has(c):
			continue
		var comp := PackedInt32Array([c])
		seen[c] = true
		var i := 0
		while i < comp.size():
			for nb in _neighbours(comp[i]):
				if state[nb] == state[c] and not seen.has(nb):
					seen[nb] = true
					comp.append(nb)
			i += 1
		out.append(comp)
	return out


func exact_groups(state: PackedByteArray) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for g in groups(state):
		if g.size() == state[g[0]]:
			out.append(g)
	return out


func is_stable(state: PackedByteArray) -> bool:
	return exact_groups(state).is_empty()


func is_packed(state: PackedByteArray, d: int) -> bool:
	return pack(state, d) == state


## Directions whose tilt changes the state, ascending.
func legal_moves(state: PackedByteArray) -> PackedInt32Array:
	var out := PackedInt32Array()
	for d in 4:
		if tilt(state, d) != state:
			out.append(d)
	return out


func is_dead_end(state: PackedByteArray) -> bool:
	return not is_solved(state) and legal_moves(state).is_empty()


func count_tiles(state: PackedByteArray) -> int:
	var n := 0
	for c in state:
		if c >= 2:
			n += 1
	return n
