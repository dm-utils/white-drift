extends RefCounted
## UI logic that needs no real screen: dots, view steps, swipes and keys, animation, texts and the main screen in
## practice mode (design 10, 13.1 UI).

const R := DriftBoard.Dir.R
const L := DriftBoard.Dir.L
const D := DriftBoard.Dir.D
const U := DriftBoard.Dir.U

var _check: Callable
var _node: Node
var _codes: Array = []
var _made: Array = []


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_dots()
	_view_steps()
	_resolve()
	_swipes()
	_keys()
	_animation()
	_blocks_and_joins()
	_texts()
	await _screen()
	for v in _made:
		v.free()


func _mk(rows: Array) -> DriftBoard:
	return preload("res://tests/rules_tests.gd").mk(rows)


## [view, attempt, board] on a 720x720 view; emitted move codes go to _codes.
func _view(rows: Array) -> Array:
	var b := _mk(rows)
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var v := DriftBoardView.new()
	v.size = Vector2(720, 720)
	v.show_attempt(a)
	_codes = []
	_made.append(v)
	v.move_chosen.connect(func(c: int) -> void: _codes.append(c))
	return [v, a, b]


func _drain(v: DriftBoardView) -> int:
	var frames := 0
	while v.busy() and frames < 400:
		v._process(0.05)
		frames += 1
	return frames


func _kinds(steps: Array) -> String:
	var out := ""
	for s in steps:
		out += "m" if s.kind == "move" else "v"
	return out


func _dots() -> void:
	var ring := DriftBoardView.RING_RADIUS
	var on_ring := true
	for v in [2, 3, 4]:
		for p in DriftBoardView.dot_offsets(v):
			on_ring = on_ring and is_equal_approx(p.length(), ring)
	_check.call(on_ring, "dots sit on a ring around the tile centre")
	var d2 := DriftBoardView.dot_offsets(2)
	var d3 := DriftBoardView.dot_offsets(3)
	var d4 := DriftBoardView.dot_offsets(4)
	_check.call(d2.size() == 2 and d3.size() == 3 and d4.size() == 4, "a tile shows as many dots as its value")
	_check.call(is_zero_approx(d2[0].x) and is_zero_approx(d2[1].x) and d2[0].y < 0.0 and d2[1].y > 0.0,
			"two dots: top and bottom")
	_check.call(is_zero_approx(d3[0].x) and d3[0].y < 0.0 and d3[1].y > 0.0 and d3[2].y > 0.0
			and is_equal_approx(d3[1].x, -d3[2].x), "three dots: a triangle pointing up")
	var diamond := true
	for p in d4:
		diamond = diamond and (is_zero_approx(p.x) or is_zero_approx(p.y))
	_check.call(diamond and is_equal_approx(d4[1].x, ring) and is_equal_approx(d4[3].x, -ring),
			"four dots: top, right, bottom, left")
	_check.call(DriftBoardView.dot_offsets(1).is_empty() and DriftBoardView.dot_offsets(0).is_empty(),
			"blocks and empty cells have no dots")
	# no dice layouts: dice put two dots on a diagonal and four in the corners
	var dice := false
	for p in d4:
		dice = dice or (absf(p.x) > 0.01 and absf(p.y) > 0.01)
	for p in d2:
		dice = dice or (absf(p.x) > 0.01 and absf(p.y) > 0.01)
	_check.call(not dice, "no dice layout for two and four")


func _view_steps() -> void:
	var b4 := _mk(["3...", ".2.3", "2.3."])
	var tl := b4.tilt_traced(b4.start, L)
	var vs := DriftBoardView.to_view_steps(tl.steps)
	_check.call(_kinds(vs) == "mvmv", "a chain shows tilt, vanish, tilt, vanish in order")
	_check.call(vs[0].kind == "move" and vs[0].speed == DriftBoardView.MOVE_SPEED and vs[0].moves == tl.steps[0].moves,
			"a tilt step becomes a move step at constant speed with the same moves")
	_check.call(vs[1].kind == "vanish" and vs[1].cells == tl.steps[1].cells, "a vanish step keeps its cells")
	var tr := b4.tilt_traced(b4.start, R)
	_check.call(_kinds(DriftBoardView.to_view_steps(tr.steps)) == "mv", "the same board tilted right: tilt and one vanish")
	var b5 := _mk(["2...", "..3.", "3.23"])
	var s1 := b5.tilt_traced(b5.start, D)
	_check.call(_kinds(DriftBoardView.to_view_steps(s1.steps)) == "m", "a tilt without a vanish is one move step")
	_check.call(DriftBoardView.to_view_steps([]).is_empty(), "no steps, no view steps")


func _resolve() -> void:
	var r := _view(["..2.2", "2#.2."])
	var v: DriftBoardView = r[0]
	var a: WhiteAttempt = r[1]
	var b: DriftBoard = r[2]
	_check.call(v._resolve_board_swipe(D) == D, "a tilt that moves tiles is chosen")
	a.play(D)
	v.update_attempt(a)
	_drain(v)
	_check.call(b.render(v.shown()) == ".....\n2#222", "the view shows the tilted board")
	_check.call(v._resolve_board_swipe(D) == -1 and v._resolve_board_swipe(L) == -1 and v._resolve_board_swipe(R) == -1,
			"design example 3: D, L and R are ignored")
	_check.call(v._resolve_board_swipe(U) == U, "design example 3: U changes the board")
	var empty := DriftBoardView.new()
	_made.append(empty)
	_check.call(empty._resolve_board_swipe(U) == -1, "no board, no tilt")


func _mouse(pressed: bool, p: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = p
	return e


func _motion(p: Vector2) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = p
	return e


func _swipes() -> void:
	var r := _view(["2...", "..3.", "3.23"])
	var v: DriftBoardView = r[0]
	_check.call(v.input_mode == WhiteTileView.InputMode.BOARD_SWIPES, "the view is in board-swipe mode")
	var lay := WhiteTileView.layout(v.size, 4, 3, v.fit)
	var cell: float = lay.cell
	var corner := Vector2(3, 3) # outside the board
	v._gui_input(_mouse(true, corner))
	v._gui_input(_motion(corner + Vector2(cell * 0.2, 0)))
	_check.call(_codes.is_empty(), "a short drag does not fire yet")
	v._gui_input(_motion(corner + Vector2(cell * 0.45, 2)))
	_check.call(_codes == [R], "a swipe that starts off the board tilts right")
	v._gui_input(_mouse(false, corner + Vector2(cell, 0)))
	_check.call(_codes.size() == 1, "one gesture fires once")
	_codes.clear()
	var on: Vector2 = lay.origin + Vector2(cell * 1.5, cell * 1.5) # an empty cell
	v._gui_input(_mouse(true, on))
	v._gui_input(_mouse(false, on + Vector2(0, 30)))
	_check.call(_codes == [D], "a release-only swipe of 30 px counts, also from an empty cell")
	_codes.clear()
	v._gui_input(_mouse(true, on))
	v._gui_input(_mouse(false, on + Vector2(2, 2)))
	_check.call(_codes.is_empty() and v.selected() == -1, "a tap does nothing")
	# ignored tilt: nudge, no code
	var r2 := _view([".....", "2#222"])
	var v2: DriftBoardView = r2[0]
	var lay2 := WhiteTileView.layout(v2.size, 5, 2, v2.fit)
	var p2 := Vector2(3, 3)
	v2._gui_input(_mouse(true, p2))
	v2._gui_input(_motion(p2 + Vector2(0, float(lay2.cell) * 0.6)))
	_check.call(_codes.is_empty() and v2._nudge_dir == D, "an ignored swipe nudges the board and emits nothing")
	v2.input_enabled = false
	v2._nudge_dir = -1
	v2._gui_input(_mouse(true, p2))
	v2._gui_input(_motion(p2 + Vector2(0, 100)))
	_check.call(_codes.is_empty() and v2._nudge_dir == -1, "no input while the view is locked")


func _key(code: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _keys() -> void:
	var r := _view(["2...", "..3.", "3.23"])
	var v: DriftBoardView = r[0]
	_check.call(v.key_move(_key(KEY_RIGHT)) == R and v.key_move(_key(KEY_LEFT)) == L, "arrows tilt")
	_check.call(v.key_move(_key(KEY_DOWN)) == D and v.key_move(_key(KEY_UP)) == U, "up and down arrows tilt")
	_check.call(v.key_move(_key(KEY_D)) == R and v.key_move(_key(KEY_A)) == L and v.key_move(_key(KEY_S)) == D
			and v.key_move(_key(KEY_W)) == U, "WASD tilt")
	_check.call(v.key_move(_key(KEY_SPACE)) == null and v.key_move(_key(KEY_ENTER)) == null
			and v.key_move(_key(KEY_ESCAPE)) == null and v.key_move(_key(KEY_X)) == null, "other keys do nothing")
	_check.call(not v.cursor_visible() and v.selected() == -1, "no cursor and no selection in board-swipe mode")
	var r2 := _view([".....", "2#222"])
	var v2: DriftBoardView = r2[0]
	_check.call(v2.key_move(_key(KEY_DOWN)) == null and v2._nudge_dir == D, "an ignored key nudges and returns nothing")
	v2.input_enabled = false
	_check.call(v2.key_move(_key(KEY_UP)) == null, "no keys while the view is locked")


func _animation() -> void:
	# chain (design example 4): move, vanish, move, vanish
	var r := _view(["3...", ".2.3", "2.3."])
	var v: DriftBoardView = r[0]
	var a: WhiteAttempt = r[1]
	a.play(L)
	v.update_attempt(a)
	var kinds: Array = []
	for p in v._phases:
		kinds.append(p.kind)
	_check.call(v.busy() and kinds == ["move", "vanish", "move", "vanish"], "a chain animates move, vanish, move, vanish")
	_check.call(v.shown() == a.state and a.solved(), "shown() is the end state at once")
	_drain(v)
	_check.call(not v.busy() and v.shown() == a.state, "the animation ends on the attempt's state")
	# slide length decides the duration
	var r2 := _view(["2...", "....", "...."])
	var v2: DriftBoardView = r2[0]
	var a2: WhiteAttempt = r2[1]
	a2.play(R)
	v2.update_attempt(a2)
	_check.call(is_equal_approx(float(v2._phases[0].dur), 3.0 / DriftBoardView.MOVE_SPEED),
			"a slide of three cells takes three cells at the tilt speed")
	# a new swipe during an animation snaps it to its end
	var snapped: Variant = v2.key_move(_key(KEY_DOWN))
	_check.call(snapped == D and not v2.busy(), "a swipe during an animation finishes it first")
	# undo and restart show the state at once
	var r3 := _view(["2...", "..3.", "3.23"])
	var v3: DriftBoardView = r3[0]
	var a3: WhiteAttempt = r3[1]
	a3.play(D)
	v3.update_attempt(a3)
	a3.play(L)
	v3.update_attempt(a3)
	_drain(v3)
	_check.call(v3.shown() == a3.state, "two tilts in a row end on the attempt's state")
	a3.undo()
	v3.update_attempt(a3)
	_check.call(not v3.busy() and v3.shown() == a3.state, "undo shows the earlier state without animation")
	a3.play(L)
	v3.update_attempt(a3)
	a3.restart()
	v3.update_attempt(a3)
	_check.call(not v3.busy() and v3.shown() == (r3[2] as DriftBoard).start and v3.shown() == a3.state, "restart shows the start at once")
	# a board change (new level) resets the view
	var r4 := _view(["22", "22"])
	var v4: DriftBoardView = r4[0]
	_check.call(v4.has_board() and v4.grid_w == 2 and v4.grid_h == 2, "show_attempt sets the board size")
	v4.clear()
	_check.call(not v4.has_board(), "clear removes the board")


func _blocks_and_joins() -> void:
	var r := _view([".....", "2#.2."])
	var v: DriftBoardView = r[0]
	var a: WhiteAttempt = r[1]
	_check.call(not v._is_tile(DriftBoard.BLOCK) and v._is_tile(2) and v._is_tile(4) and not v._is_tile(0),
			"blocks are static cells, values 2 to 4 are tiles")
	var before := v.shown()
	a.play(R)
	v.update_attempt(a)
	var mid_ok := true
	for step in 4:
		v._process(0.02)
		mid_ok = mid_ok and v._state[1] == DriftBoard.BLOCK
	_drain(v)
	_check.call(mid_ok and v.shown()[1] == DriftBoard.BLOCK and before[1] == DriftBoard.BLOCK,
			"a block never moves during an animation")
	_check.call(DriftBoardView.joined(Vector2(0, 0), Vector2(1, 0)) and DriftBoardView.joined(Vector2(2, 1), Vector2(2, 2)),
			"tiles in neighbouring cells are joined")
	_check.call(not DriftBoardView.joined(Vector2(0, 0), Vector2(1, 1)) and not DriftBoardView.joined(Vector2(0, 0), Vector2(2, 0)),
			"diagonal contact and a gap show no join")
	_check.call(DriftBoardView.joined(Vector2(0.99, 0), Vector2(2.0, 0)) and not DriftBoardView.joined(Vector2(0.5, 0), Vector2(1.6, 0)),
			"tiles in motion join only when they touch")


func _texts() -> void:
	var nl: Dictionary = DriftStrings.TEXT.nl
	var en: Dictionary = DriftStrings.TEXT.en
	_check.call(nl.keys() == en.keys(), "Dutch and English define the same keys")
	var all := true
	for key in ["count", "count_final", "solved", "perfect", "hint", "dead_end", "best_route", "share_line"]:
		all = all and nl.has(key)
	_check.call(all, "all keys of design 10.6 are present")
	var fmt_ok := true
	for lang in ["nl", "en"]:
		var t: Dictionary = DriftStrings.TEXT[lang]
		fmt_ok = fmt_ok and str(t.count_final) % 3 != "" and str(t.solved) % [3, 2, "0:10"] != ""
		fmt_ok = fmt_ok and str(t.share_line) % [1, "3", "2"] != ""
	_check.call(fmt_ok, "format texts take their arguments")


func _screen() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_node.add_child(m)
	await _node.get_tree().process_frame
	_check.call(m.practice and not m.mode_btn.visible, "the screen opens on a practice set without a mode button")
	_check.call(m.puzzles.size() == 3 and m.tabs.size() == 3, "three levels on the tabs")
	_check.call(m.counter.text == WhiteText.t("count_final") % 0 and m.par_label.text != "", "counter and par are shown")
	_check.call(m.message.text == WhiteText.t("hint"), "the hint shows before the first move")
	_check.call(m.undo_btn.disabled and m.restart_btn.disabled, "undo and restart wait for a move")
	_check.call(m.view is DriftBoardView and (m.view as DriftBoardView).board == m.puzzles[0].board, "the view shows level 0")
	var p: Dictionary = m.puzzles[0]
	m._on_move(p.path[0])
	_check.call(m.counter.text == WhiteText.t("count_final") % 1 and not m.undo_btn.disabled, "a tilt raises the counter")
	m._on_undo()
	_check.call(m.counter.text == WhiteText.t("count_final") % 0 and m.undo_btn.disabled, "undo lowers the counter")
	m._on_move(p.path[0])
	m._on_restart()
	_check.call(m.attempts[0].history.is_empty() and m.attempts[0].record.ends_with("r"), "restart goes back to the start")
	_check.call(m.counter.text == WhiteText.t("count_final") % 0, "restart sets the counter to 0")
	# ignored tilt: no count, no record
	var a0: WhiteAttempt = m.attempts[0]
	var ignored := -1
	for d in 4:
		if (p.board as DriftBoard).apply(a0.state, d) == null:
			ignored = d
	if ignored >= 0:
		var rec := a0.record
		m._on_move(ignored)
		_check.call(a0.record == rec and a0.count() == 0, "an ignored tilt changes neither record nor counter")
	for code in p.path:
		m._on_move(code)
	var a: WhiteAttempt = m.attempts[0]
	_check.call(a.solved() and a.count() == int(p.par), "playing the stored path solves level 0 in par tilts")
	_check.call(m.next_btn.visible and m.best_btn.visible and not m.undo_btn.visible and not m.restart_btn.visible,
			"solved: Next and Best route, no Undo or Restart")
	_check.call(m.message.text.contains(str(p.par)) and m.message.text.contains(WhiteText.t("perfect")),
			"the solved message shows count and par, and Exactly par")
	_check.call(m.tabs[0].text.ends_with(" · %d" % int(p.par)), "the solved level shows its count on the tab")
	m._show_best()
	_check.call(m._replaying and not m.view.input_enabled and m.view.shown() == (p.board as DriftBoard).start,
			"Best route replays from the start with the input locked")
	m._on_move(p.path[0])
	_check.call(m.view.shown() == (p.board as DriftBoard).start, "moves are ignored while the best route plays")
	m._next()
	_check.call(m.level == 1 and not m.attempts[1].solved(), "Next goes to the next level")
	await _node.get_tree().create_timer(0.8).timeout
	_check.call(m.view.input_enabled and not m._replaying, "leaving the level stops the best route and unlocks the input")
	m._pick_level(2)
	_check.call(m.level == 2 and (m.view as DriftBoardView).board == m.puzzles[2].board, "a tab opens its level")
	var before: int = m.practice_index
	m.attempts[2].apply_record("")
	for code in m.puzzles[2].path:
		m._on_move(code)
	m._next()
	_check.call(m.practice_index == (before + 1) % m._practice_count() and m.level == 0,
			"Next after hard goes to the next set, easy")
	# dead end (design example 6), only after a tilt was made
	var dead := _mk(["2#.", "#2#"])
	var da := WhiteAttempt.new(dead, WhiteAttempt.CountMode.FINAL_ONLY)
	m.view.show_attempt(da)
	_check.call(m._play_message(da) == "", "no dead-end notice before a tilt")
	da.moves_made = 1
	_check.call(m._play_message(da) == WhiteText.t("dead_end"), "dead-end notice when no tilt changes anything")
	# width: centred column of at most 720 on a wide window, full width on a phone
	var wide := m._insets_for(Vector2(2276, 1280))
	_check.call(2276 - int(wide.left) - int(wide.right) == 720, "a wide window gets a 720 px column")
	var wide2 := m._insets_for(Vector2(1900, 1000))
	_check.call(1900 - int(wide2.left) - int(wide2.right) <= 720, "a 1900 px window gets at most a 720 px column")
	var phone := m._insets_for(Vector2(720, 1280))
	_check.call(int(phone.left) == WhiteTheme.MARGIN and int(phone.right) == WhiteTheme.MARGIN, "a phone uses the full width")
	var small := m._insets_for(Vector2(360, 640))
	_check.call(int(small.left) == WhiteTheme.MARGIN and int(small.right) == WhiteTheme.MARGIN, "a small phone uses the full width")
	_check.call(m._max_content_width() == 720 and m._use_safe_area() and m._practice_only(), "screen hooks as designed")
	# language
	WhiteText.lang = "en"
	m._refresh()
	var en_counter := m.counter.text
	WhiteText.lang = "nl"
	m._refresh()
	_check.call(en_counter.begins_with("Tilts") and m.counter.text.begins_with("Kantelingen"), "the counter follows the language")
	m.queue_free()
