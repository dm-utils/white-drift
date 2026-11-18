class_name DriftSolver
extends RefCounted
## Exact breadth-first search (design 5.5, ADR 0003): fewest tilts, number of shortest sequences, one of them.

const WAYS_CAP := 1 << 40


## {"par": -1 when none, "exact", "solutions", "path": PackedInt32Array, "states", "capped"}
static func solve(board: DriftBoard, state: PackedByteArray, max_depth: int, max_states: int) -> Dictionary:
	if board.is_solved(state):
		return {"par": 0, "exact": true, "solutions": 1, "path": PackedInt32Array(), "states": 1, "capped": false}
	var dist := {state: 0}
	var ways := {state: 1}
	var parent := {}
	var frontier: Array[PackedByteArray] = [state]
	var depth := 0
	var goal_ways := 0
	var goal_parent: Array = []
	var capped := false
	while not frontier.is_empty() and depth < max_depth and goal_parent.is_empty() and not capped:
		var next: Array[PackedByteArray] = []
		for s in frontier:
			var n_ways: int = ways[s]
			for d in 4:
				var t := board.tilt(s, d)
				if t == s:
					continue
				if board.is_solved(t):
					goal_ways = mini(goal_ways + n_ways, WAYS_CAP)
					if goal_parent.is_empty():
						goal_parent = [s, d]
				elif not dist.has(t):
					dist[t] = depth + 1
					ways[t] = n_ways
					parent[t] = [s, d]
					next.append(t)
				elif dist[t] == depth + 1:
					ways[t] = mini(ways[t] + n_ways, WAYS_CAP)
			if goal_parent.is_empty() and dist.size() > max_states:
				capped = true
				break
		frontier = next
		depth += 1
	if goal_parent.is_empty():
		return {"par": -1, "exact": false, "solutions": 0, "path": PackedInt32Array(), "states": dist.size(),
				"capped": capped}
	var path := PackedInt32Array([goal_parent[1]])
	var cur: PackedByteArray = goal_parent[0]
	while parent.has(cur):
		var p: Array = parent[cur]
		path.insert(0, p[1])
		cur = p[0]
	return {"par": path.size(), "exact": true, "solutions": goal_ways, "path": path, "states": dist.size(),
			"capped": false}


## Plays the tilt that removes most tiles (ties: lowest code) until solved, stuck or max_moves.
static func greedy(board: DriftBoard, state: PackedByteArray, max_moves: int) -> Dictionary:
	var s := state
	var path := PackedInt32Array()
	while not board.is_solved(s) and path.size() < max_moves:
		var tiles := board.count_tiles(s)
		var best_d := -1
		var best_t := s
		var best_gain := 0
		for d in 4:
			var t := board.tilt(s, d)
			var gain := tiles - board.count_tiles(t)
			if gain > best_gain:
				best_gain = gain
				best_d = d
				best_t = t
		if best_d < 0:
			break
		path.append(best_d)
		s = best_t
	return {"solved": board.is_solved(s), "moves": path.size(), "path": path}
