class_name DriftBoardView
extends WhiteTileView
## Board view of White Drift (design 10): tiles with ring dots, joins, recessed blocks. A swipe or arrow key tilts
## the whole board. Look and feel values are the constants and members below.

const TILE_COLORS := {2: Color("4C7FD6"), 3: Color("E3943A"), 4: Color("3FA58A")}
const MARK_COLOR := Color(0.110, 0.122, 0.141, 0.85)
const BLOCK_FILL := Color("151920")
const BLOCK_BORDER := Color("3A4250")
const BLOCK_BORDER_PX := 2
const RING_RADIUS := 0.26 ## in cells
const RING_PX := 2.0 ## width of the faint ring line the dots sit on
const RING_ALPHA := 0.3 ## ring line opacity relative to the dots
const DOT_DIAMETER := 0.17 ## in cells
const JOIN_WIDTH := 0.4 ## join bar, in cells
const MOVE_SPEED := 16.0 ## cells per second
## Dot angles in degrees, 0 = right, 90 = down on screen; first dot at the top.
const DOT_ANGLES := {
	2: [270.0, 90.0],
	3: [270.0, 30.0, 150.0],
	4: [270.0, 0.0, 90.0, 180.0],
}

var board: DriftBoard

var _block_box := StyleBoxFlat.new()


func _init() -> void:
	input_mode = InputMode.BOARD_SWIPES
	_block_box.bg_color = BLOCK_FILL
	_block_box.border_color = BLOCK_BORDER
	_block_box.set_border_width_all(BLOCK_BORDER_PX)


# --- hooks -------------------------------------------------------------------------------------------------------

func _is_tile(value: int) -> bool:
	return value >= 2


func _resolve_board_swipe(dir: int) -> int:
	if board == null:
		return -1
	var s := shown()
	return dir if board.tilt(s, dir) != s else -1


func _draw_static(rect: Rect2, _value: int) -> void:
	_block_box.set_corner_radius_all(int(cell_px * tile_radius))
	draw_style_box(_block_box, rect)


func _draw_tile_body(rect: Rect2, value: int, alpha: float) -> void:
	var col: Color = TILE_COLORS[value]
	col.a = alpha
	_box.bg_color = col
	_box.set_corner_radius_all(int(cell_px * tile_radius))
	draw_style_box(_box, rect)


func _draw_links(tiles: Array) -> void:
	for ai in tiles.size():
		for bi in range(ai + 1, tiles.size()):
			var a: Dictionary = tiles[ai]
			var b: Dictionary = tiles[bi]
			if a.value != b.value:
				continue
			var d: Vector2 = b.pos - a.pos
			var horizontal := absf(absf(d.x) - 1.0) < 0.02 and absf(d.y) < 0.02
			var vertical := absf(absf(d.y) - 1.0) < 0.02 and absf(d.x) < 0.02
			if not (horizontal or vertical):
				continue
			var col: Color = TILE_COLORS[a.value]
			col.a = minf(a.alpha, b.alpha)
			var thick: float = a.cell * JOIN_WIDTH * minf(a.scale, b.scale)
			var ca: Vector2 = a.center
			var cb: Vector2 = b.center
			draw_rect(Rect2(ca.min(cb) - Vector2(thick, thick) / 2.0, (ca - cb).abs() + Vector2(thick, thick)), col)


func _draw_tile_face(rect: Rect2, value: int, alpha: float, scale_f: float) -> void:
	var col := MARK_COLOR
	col.a *= alpha
	var c := rect.get_center()
	var ring := col
	ring.a *= RING_ALPHA
	draw_arc(c, cell_px * RING_RADIUS * scale_f, 0.0, TAU, 40, ring, RING_PX, true)
	for p in dot_offsets(value):
		draw_circle(c + (p as Vector2) * cell_px * scale_f, cell_px * DOT_DIAMETER / 2.0 * scale_f, col)


# --- pure helpers (tested) ---------------------------------------------------------------------------------------

## Dot centres relative to the tile centre, in cells (screen orientation, y down).
static func dot_offsets(value: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for deg in DOT_ANGLES.get(value, []):
		out.append(Vector2.from_angle(deg_to_rad(deg)) * RING_RADIUS)
	return out


## View steps for the steps of DriftBoard.tilt_traced (design 10.2).
static func to_view_steps(steps: Array) -> Array:
	var out: Array = []
	for s in steps:
		if s.kind == "tilt":
			out.append({"kind": "move", "moves": s.moves, "speed": MOVE_SPEED})
		elif s.kind == "vanish":
			out.append({"kind": "vanish", "cells": s.cells})
	return out


# --- state -------------------------------------------------------------------------------------------------------

## Shows the attempt's state at once (new board, no animation).
func show_attempt(a: WhiteAttempt) -> void:
	board = a.rules as DriftBoard
	show_cells(board.w, board.h, a.state)


## After a tilt: animates it; after undo or restart: shows the state at once.
func update_attempt(a: WhiteAttempt) -> void:
	finish_animation()
	var rec := a.record
	var code: Variant = board.decode_move(rec.right(1)) if not rec.is_empty() and not a.history.is_empty() else null
	if code == null:
		show_values(a.state)
		return
	play_tilt(a.history.back(), code)


## Animates a tilt from state `before` (also used by Best route).
func play_tilt(before: PackedByteArray, dir: int) -> void:
	animate(to_view_steps(board.tilt_traced(before, dir).steps), before)
