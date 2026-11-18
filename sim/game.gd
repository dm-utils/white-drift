class_name DriftGame
extends RefCounted
## Game constants and the puzzle store.

const GAME_ID := "white-drift"
const DAILY := "res://data/daily.json"
const PRACTICE := "res://data/practice.json"

static var _store: WhitePuzzleStore


## Raw puzzle object (design 6.3) to {"board", "par", "exact", "solutions", "path", "fallback"}.
static func convert(raw: Dictionary) -> Dictionary:
	var board := DriftBoard.from_dict(raw.board)
	return {"board": board, "par": int(raw.par), "exact": bool(raw.exact), "solutions": int(raw.solutions),
			"path": decode_path(board, str(raw.path)), "fallback": bool(raw.get("fallback", false))}


static func decode_path(board: DriftBoard, text: String) -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in text.length():
		var m: Variant = board.decode_move(text[i])
		if m == null:
			return PackedInt32Array()
		out.append(m)
	return out


static func store() -> WhitePuzzleStore:
	if _store == null:
		_store = WhitePuzzleStore.new(DAILY, PRACTICE, convert)
	return _store
