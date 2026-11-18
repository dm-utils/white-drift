extends RefCounted
## Second-opinion UI and pool-play checks written against design 10 and 13.1, not against the game's own tests.

const R := DriftBoard.Dir.R
const L := DriftBoard.Dir.L
const D := DriftBoard.Dir.D
const U := DriftBoard.Dir.U

var _check: Callable
var _node: Node
var _codes: Array = []


func run(check: Callable, node: Node) -> void:
	_check = check
	_node = node
	_thresholds()
	_play_pool()
	_safe_area_and_width()
	_mid_animation()
	await _screen()


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


func _view(rows: Array) -> Array:
	var b := DriftBoard.create(rows[0].length(), rows.size())
	b.start = b.from_rows(PackedStringArray(rows))
	var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
	var v := DriftBoardView.new()
	v.size = Vector2(720, 720)
	v.show_attempt(a)
	_codes = []
	v.move_chosen.connect(func(c: int) -> void: _codes.append(c))
	return [v, a, b]


func _thresholds() -> void:
	var r := _view(["2...", "..3.", "3.23"])
	var v: DriftBoardView = r[0]
	var cell: float = WhiteTileView.layout(v.size, 4, 3, v.fit).cell
	var p := Vector2(300, 300)
	# release-only: 23 px is a tap, 24 px a swipe (kit swipe_min_px)
	v._gui_input(_mouse(true, p))
	v._gui_input(_mouse(false, p + Vector2(23, 0)))
	_check.call(_codes.is_empty(), "a 23 px drag on release is a tap and does nothing")
	v._gui_input(_mouse(true, p))
	v._gui_input(_mouse(false, p + Vector2(24, 0)))
	_check.call(_codes == [R], "a 24 px drag on release tilts")
	_codes.clear()
	# all four directions, screen up is U
	var want := {Vector2(-60, 0): L, Vector2(0, 60): D, Vector2(0, -60): U, Vector2(60, 5): R, Vector2(5, -60): U}
	for d: Vector2 in want:
		_codes.clear()
		v._gui_input(_mouse(true, p))
		v._gui_input(_mouse(false, p + d))
		_check.call(_codes == [want[d]], "swipe %s gives direction %d" % [d, want[d]])
	# diagonal: larger axis wins
	_codes.clear()
	v._gui_input(_mouse(true, p))
	v._gui_input(_mouse(false, p + Vector2(40, -50)))
	_check.call(_codes == [U], "a mostly vertical diagonal swipe goes up")
	# during drag: 0.4 cell fires, 0.39 does not
	_codes.clear()
	v._gui_input(_mouse(true, p))
	v._gui_input(_motion(p + Vector2(cell * 0.39, 0)))
	_check.call(_codes.is_empty(), "0.39 cell during the drag does not fire")
	v._gui_input(_motion(p + Vector2(cell * 0.41, 0)))
	_check.call(_codes == [R], "0.41 cell during the drag fires")
	v._gui_input(_motion(p + Vector2(cell * 3, 0)))
	v._gui_input(_mouse(false, p + Vector2(cell * 3, 0)))
	_check.call(_codes.size() == 1, "a long drag fires only once")
	# right mouse button and touch-less motion do nothing
	_codes.clear()
	var e := _mouse(true, p)
	e.button_index = MOUSE_BUTTON_RIGHT
	v._gui_input(e)
	v._gui_input(_motion(p + Vector2(200, 0)))
	_check.call(_codes.is_empty(), "the right button does not start a swipe")
	v.free()


func _pool() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/practice.json"))


func _play_pool() -> void:
	var pool := _pool()
	var all_ok := true
	var after_ok := true
	var rec_ok := true
	for k in pool:
		for p in pool[k]:
			var b := DriftBoard.from_dict(p.board)
			var a := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
			var path: String = p.path
			for ch in path:
				all_ok = all_ok and a.play(b.decode_move(ch))
			all_ok = all_ok and a.solved() and a.count() == int(p.par) and b.is_solved(a.state)
			# solved: every tilt is ignored
			for d in 4:
				after_ok = after_ok and not a.play(d)
			rec_ok = rec_ok and a.record == path
			# replay from record
			var a2 := WhiteAttempt.new(b, WhiteAttempt.CountMode.FINAL_ONLY)
			a2.apply_record(a.record)
			rec_ok = rec_ok and a2.state == a.state and a2.count() == a.count()
	_check.call(all_ok, "all 120 stored paths solve in exactly par tilts through WhiteAttempt")
	_check.call(after_ok, "after solving, every tilt is ignored")
	_check.call(rec_ok, "the record equals the path and replays to the same state")


func _safe_area_and_width() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_node.add_child(m)
	m._debug["safe"] = "40,80,40,60"
	var ins := m._insets_for(Vector2(720, 1280))
	_check.call(int(ins.left) == WhiteTheme.MARGIN + 40 and int(ins.right) == WhiteTheme.MARGIN + 40
			and int(ins.top) == WhiteTheme.MARGIN + 80 and int(ins.bottom) == WhiteTheme.MARGIN + 60,
			"the safe area insets are added to the margins")
	m._debug["safe"] = ""
	var widths_ok := true
	var centred := true
	for vp in [Vector2(1280, 720), Vector2(1900, 1000), Vector2(2560, 1440), Vector2(721, 1280), Vector2(720, 1280),
			Vector2(719, 1280), Vector2(360, 640), Vector2(1000, 1000)]:
		var i := m._insets_for(vp)
		var col: float = vp.x - int(i.left) - int(i.right)
		widths_ok = widths_ok and (col <= 720.0 or vp.x - 2.0 * WhiteTheme.MARGIN <= 720.0 + 1.0)
		centred = centred and absi(int(i.left) - int(i.right)) <= 1
	_check.call(widths_ok, "content column never exceeds 720 px")
	_check.call(centred, "content column is centred")
	var w1 := m._insets_for(Vector2(1280, 720))
	_check.call(1280 - int(w1.left) - int(w1.right) == 720 + 0 or 1280 - int(w1.left) - int(w1.right) == 719 + 1,
			"1280x720 gets exactly a 720 column")
	# safe-area maths
	var s := WhiteSafeArea.from_rects(Rect2(0, 100, 1000, 900), Vector2(1000, 1000), Vector2(500, 500))
	_check.call(is_equal_approx(s.top, 50.0) and s.left == 0.0 and s.bottom == 0.0, "safe rect is scaled to the viewport")
	var neg := WhiteSafeArea.from_rects(Rect2(-50, -50, 1200, 1200), Vector2(1000, 1000), Vector2(1000, 1000))
	_check.call(neg.left == 0.0 and neg.top == 0.0 and neg.right == 0.0 and neg.bottom == 0.0,
			"a safe rect larger than the window gives no negative insets")
	var junk := WhiteSafeArea.parse("x,,5")
	_check.call(junk.left == 0.0 and junk.top == 0.0 and junk.right == 5.0 and junk.bottom == 0.0, "junk override parses to zeros")
	var zero := WhiteSafeArea.from_rects(Rect2(), Vector2(1000, 1000), Vector2(1000, 1000))
	_check.call(zero.left == 0.0 and zero.bottom == 0.0, "an empty safe rect gives zero insets")
	m.queue_free()


func _mid_animation() -> void:
	var r := _view([".....", "2#.2."])
	var v: DriftBoardView = r[0]
	var a: WhiteAttempt = r[1]
	a.play(U)
	v.update_attempt(a)
	_check.call(v.busy(), "a tilt that moves tiles starts an animation")
	# a key during the animation finishes it first and then judges against the end state
	var key := InputEventKey.new()
	key.keycode = KEY_UP
	key.pressed = true
	var c: Variant = v.key_move(key)
	_check.call(c == null and not v.busy(), "a second tilt during the animation snaps it and is judged on the end state")
	_check.call(v.shown() == a.state, "the shown state equals the attempt state after snapping")
	v.free()


func _screen() -> void:
	var scene: PackedScene = load("res://ui/main.tscn")
	var m: WhiteDayScreen = scene.instantiate()
	_node.add_child(m)
	await _node.get_tree().process_frame
	# undo at start and restart at start change nothing
	var a0: WhiteAttempt = m.attempts[0]
	m._on_undo()
	m._on_restart()
	_check.call(a0.record == "" and a0.count() == 0, "undo and restart before any move change nothing")
	# a tilt, restart, restart again: record has one r only
	var p: Dictionary = m.puzzles[0]
	m._on_move(p.path[0])
	m._on_restart()
	var rec := a0.record
	m._on_restart()
	_check.call(a0.record == rec, "a second restart is a no-op")
	# undo until empty
	m._on_move(p.path[0])
	m._on_move(p.path[1])
	m._on_undo()
	m._on_undo()
	m._on_undo()
	_check.call(a0.count() == 0 and a0.state == (p.board as DriftBoard).start, "undo goes back to the start and stops")
	# counter semantics: FINAL_ONLY, undo lowers
	m._on_move(p.path[0])
	m._on_move(p.path[1])
	_check.call(m.counter.text == WhiteText.t("count_final") % 2, "counter shows tilts in the current solution")
	m._on_undo()
	_check.call(m.counter.text == WhiteText.t("count_final") % 1, "counter drops after undo")
	m._on_restart()
	# dead end through the screen: R vanishes the 2s of column C and leaves A3 boxed in by two blocks
	var dead := DriftBoard.create(3, 3)
	dead.start = dead.from_rows(PackedStringArray(["2#.", "#2.", "2.."]))
	m.puzzles[0] = {"board": dead, "par": 9, "exact": true, "solutions": 1, "path": PackedInt32Array()}
	m.attempts[0] = WhiteAttempt.new(dead, WhiteAttempt.CountMode.FINAL_ONLY)
	m._pick_level(1)
	m._pick_level(0)
	_check.call(m.message.text == WhiteText.t("hint") and not dead.is_dead_end(dead.start), "the hint shows on the new board")
	m._on_move(R)
	_check.call(m.view.busy() and m.message.text == "", "no dead-end notice while the animation runs")
	var guard := 0
	while m.view.busy() and guard < 400:
		m.view._process(0.05)
		guard += 1
	m._refresh()
	_check.call(dead.is_dead_end(m.attempts[0].state) and m.message.text == WhiteText.t("dead_end"),
			"the dead-end message is shown after the animation")
	m._on_move(L)
	_check.call(m.attempts[0].count() == 1, "tilts in a dead end are ignored")
	m._on_undo()
	m._refresh()
	_check.call(m.message.text != WhiteText.t("dead_end"), "undo from a dead end removes the dead-end message")
	# language persists across a reload
	var before := WhiteText.lang
	m._toggle_lang()
	var toggled := WhiteText.lang
	m.queue_free()
	WhiteText.lang = "nl"
	var m2: WhiteDayScreen = scene.instantiate()
	_node.add_child(m2)
	await _node.get_tree().process_frame
	_check.call(toggled != before and WhiteText.lang == toggled, "the language survives a reload")
	m2._toggle_lang()
	_check.call(WhiteText.lang == before, "toggling twice returns to the first language")
	# texts: hint is the same in both and fully translated
	for lang in ["nl", "en"]:
		WhiteText.lang = lang
		for key in ["count", "count_final", "solved", "perfect", "hint", "dead_end", "best_route", "share_line"]:
			_check.call(WhiteText.t(key) != key and WhiteText.t(key) != "", "%s text %s exists" % [lang, key])
		_check.call(WhiteText.t("levels").size() == 3, "%s has three level names" % lang)
	WhiteText.lang = before
	m2.queue_free()
