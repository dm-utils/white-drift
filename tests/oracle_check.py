"""Independent oracle for White Drift: rules, pool and par, no code shared with the game.

Run: python3 -I tests/oracle_check.py [--brute]
Tilt = per-line sort with blocks as walls, groups by union-find. Exit 1 on any failure.
"""
import json
import os
import sys
from collections import deque

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DIRS = "RLDU"
FAILS = []
CHECKS = 0


def check(ok, what):
    global CHECKS
    CHECKS += 1
    if not ok:
        FAILS.append(what)
        print("FAIL:", what)


# board = tuple of rows (top first), chars ".#234"; cell (r, c), r=0 top
def parse(rows):
    return tuple(tuple(r) for r in rows)


def render(b):
    return ["".join(r) for r in b]


def lines(b, d):
    """Yield lists of (r, c) per segment, front first."""
    h, w = len(b), len(b[0])
    if d in "RL":
        raw = [[(r, c) for c in (range(w - 1, -1, -1) if d == "R" else range(w))] for r in range(h)]
    else:
        raw = [[(r, c) for r in (range(h) if d == "U" else range(h - 1, -1, -1))] for c in range(w)]
    for line in raw:
        seg = []
        for p in line:
            if b[p[0]][p[1]] == "#":
                if seg:
                    yield seg
                seg = []
            else:
                seg.append(p)
        if seg:
            yield seg


def pack(b, d):
    g = [list(r) for r in b]
    for seg in lines(b, d):
        tiles = [b[r][c] for r, c in seg if b[r][c] != "."]
        for i, (r, c) in enumerate(seg):
            g[r][c] = tiles[i] if i < len(tiles) else "."
    return tuple(tuple(r) for r in g)


def exact_groups(b):
    h, w = len(b), len(b[0])
    seen = set()
    out = []
    for r in range(h):
        for c in range(w):
            v = b[r][c]
            if v in "234" and (r, c) not in seen:
                comp = [(r, c)]
                seen.add((r, c))
                i = 0
                while i < len(comp):
                    y, x = comp[i]
                    i += 1
                    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        ny, nx = y + dy, x + dx
                        if 0 <= ny < h and 0 <= nx < w and b[ny][nx] == v and (ny, nx) not in seen:
                            seen.add((ny, nx))
                            comp.append((ny, nx))
                if len(comp) == int(v):
                    out.append(comp)
    return out


def tilt(b, d):
    """Returns (result, waves) ; result == b when ignored."""
    p = pack(b, d)
    if p == b:
        return b, 0
    waves = 0
    while True:
        gs = exact_groups(p)
        if not gs:
            return p, waves
        waves += 1
        g = [list(r) for r in p]
        for grp in gs:
            for r, c in grp:
                g[r][c] = "."
        p = pack(tuple(tuple(r) for r in g), d)


def solved(b):
    return not any(ch in "234" for r in b for ch in r)


def bfs(b, max_depth=14):
    """Returns (par, ways, states). ways counts shortest effective tilt sequences."""
    dist = {b: 0}
    ways = {b: 1}
    frontier = [b]
    depth = 0
    goal = 0
    if solved(b):
        return 0, 1, 1
    while frontier and not goal and depth < max_depth:
        nxt = []
        for s in frontier:
            for d in DIRS:
                t, _ = tilt(s, d)
                if t == s:
                    continue
                if solved(t):
                    goal += ways[s]
                elif t not in dist:
                    dist[t] = depth + 1
                    ways[t] = ways[s]
                    nxt.append(t)
                elif dist[t] == depth + 1:
                    ways[t] += ways[s]
        depth += 1
        frontier = nxt
    return (depth if goal else -1), goal, len(dist)


def brute(b, par):
    """Count effective sequences of exactly par tilts that end solved, none solved earlier (plain DFS)."""
    cnt = 0

    def rec(s, k):
        nonlocal cnt
        for d in DIRS:
            t, _ = tilt(s, d)
            if t == s:
                continue
            if solved(t):
                if k + 1 == par:
                    cnt += 1
                continue
            if k + 1 < par:
                rec(t, k + 1)

    rec(b, 0)
    return cnt


def examples():
    # design 2.8 examples, own transcription
    b = parse(["....", ".3..", "2..2"])
    check(render(pack(b, "L")) == ["....", "3...", "22.."], "ex1 packed")
    check(render(tilt(b, "L")[0]) == ["....", "3...", "...."], "ex1 result")
    b = parse(["..2.2", "2#.2."])
    r, _ = tilt(b, "D")
    check(render(r) == [".....", "2#222"], "ex2 overfull stays")
    for d in "DLR":
        check(tilt(r, d)[0] == r, "ex3 ignored " + d)
    check(tilt(r, "U")[0] != r, "ex3 U effective")
    b = parse(["3...", ".2.3", "2.3."])
    r, w = tilt(b, "L")
    check(solved(r) and w == 2, "ex4 L chain two waves")
    r, w = tilt(b, "R")
    check(solved(r) and w == 1, "ex4 R one wave")
    check(bfs(b)[:2] == (1, 2), "ex4 par1 sol2")
    b = parse(["2...", "..3.", "3.23"])
    check(bfs(b)[:2] == (2, 2), "ex5 par2 sol2")
    r, _ = tilt(b, "D")
    check(render(r) == ["....", "2.3.", "3.23"], "ex5 D")
    b = parse(["2#.", "#2#"])
    check(all(tilt(b, d)[0] == b for d in DIRS), "ex6 dead end")
    # own cases
    # tilt per segment: block splits row, tiles stop at the block
    b = parse(["2.#.2"])
    check(render(tilt(b, "R")[0]) == [".2#.2"], "segment R left part stops at block")
    check(render(tilt(b, "L")[0]) == ["2.#2."], "segment L right part stops at block")
    # block between equal tiles keeps them apart, no group
    b = parse(["2#2"])
    check(all(tilt(b, d)[0] == b for d in DIRS), "block separates pair")
    # diagonal is no neighbour
    b = parse(["2.", ".2"])
    r, _ = tilt(b, "L")
    check(solved(r), "diag tiles slide to form pair then vanish")
    # overfull: 3 twos in line never vanish (a pair part of three)
    b = parse(["222."])
    check(tilt(b, "R")[0] == parse([".222"]), "overfull no vanish")
    # group 3 of 3
    b = parse(["3.3.3"])
    check(solved(tilt(b, "L")[0]), "three 3s vanish")
    # four 4s as 2x2 block
    b = parse(["4.4", "4.4"])
    check(solved(tilt(b, "L")[0]), "four 4s square vanish")
    # chain: after vanish remaining slide same direction and form group
    b = parse(["3.2.2.3.3"])
    # pack L: 3 2 2 3 3 -> pair 2 vanishes -> 3 3 3 slide -> exact -> empty
    r, w = tilt(b, "L")
    check(solved(r) and w == 2, "chain in tilt direction")
    # chain must NOT go through other direction: column version
    b = parse(["3", ".", "2", "2", "3", "3"])
    check(solved(tilt(b, "U")[0]), "chain vertical U")
    # ignored tilt: already packed
    b = parse(["23.."])
    check(tilt(b, "L")[0] == b, "packed ignored")
    # re-pack uses same direction: tile left of vanished pair moves right on R
    b = parse(["3.22.3.3"])
    r, w = tilt(b, "R")
    check(solved(r), "chain R")
    # no gravity: loose tile in other axis stays
    b = parse(["..", "3."])
    check(tilt(b, "R")[0] == parse(["..", ".3"]), "no gravity")


def invariants_random():
    import random
    rnd = random.Random(7)
    for _ in range(3000):
        h, w = rnd.randint(2, 6), rnd.randint(2, 6)
        g = [["."] * w for _ in range(h)]
        for r in range(h):
            for c in range(w):
                x = rnd.random()
                g[r][c] = "#" if x < 0.12 else rnd.choice("234") if x < 0.6 else "."
        b = tuple(tuple(r) for r in g)
        # make stable
        while True:
            gs = exact_groups(b)
            if not gs:
                break
            g = [list(r) for r in b]
            for grp in gs:
                for r, c in grp:
                    g[r][c] = "."
            b = tuple(tuple(r) for r in g)
        for d in DIRS:
            t, _ = tilt(b, d)
            before = sum(ch in "234" for r in b for ch in r)
            after = sum(ch in "234" for r in t for ch in r)
            check(after <= before, "tiles never grow")
            for v in "234":
                cb = sum(ch == v for r in b for ch in r)
                ca = sum(ch == v for r in t for ch in r)
                if (cb - ca) % int(v) != 0:
                    check(False, "mod invariant")
                    break
            if any((b[r][c] == "#") != (t[r][c] == "#") for r in range(h) for c in range(w)):
                check(False, "blocks moved")
            if t != b:
                check(pack(t, d) == t and not exact_groups(t), "packed and stable after tilt")
                check(tilt(t, d)[0] == t, "same tilt twice ignored")
    check(True, "random done")


def pool(brute_all):
    data = json.load(open(os.path.join(ROOT, "data", "practice.json")))
    check(len(data) == 40, "40 sets")
    check(sorted(map(int, data.keys())) == list(range(40)), "keys 0..39")
    bands = [(3, 4), (5, 7), (8, 11)]
    wh = [(5, 5), (6, 6), (6, 6)]
    seen = {}
    pars = {0: [], 1: [], 2: []}
    tot = 0
    for k in sorted(data, key=int):
        sets = data[k]
        check(len(sets) == 3, f"set {k} has 3")
        sp = []
        for lv, p in enumerate(sets):
            tag = f"set {k} lv {lv}"
            rows = p["board"]["rows"]
            w, h = p["board"]["n"]
            check(len(rows) == h and all(len(r) == w for r in rows), tag + " dims")
            check(all(ch in ".#234" for r in rows for ch in r), tag + " chars")
            check((w, h) == wh[lv], tag + f" size {w}x{h}")
            b = parse(rows)
            check(not exact_groups(b), tag + " start stable")
            for v in "234":
                n = sum(ch == v for r in rows for ch in r)
                check(n % int(v) == 0, tag + f" count {v}")
            check(len({ch for r in rows for ch in r if ch in "234"}) >= (2 if lv == 0 else 3), tag + " values")
            check(p["exact"] is True and "fallback" not in p, tag + " exact")
            # path legal and clears in par tilts
            s = b
            legal = True
            for i, ch in enumerate(p["path"]):
                t, _ = tilt(s, ch)
                if t == s:
                    legal = False
                s = t
                if i < len(p["path"]) - 1 and solved(s):
                    legal = False
            check(legal, tag + " path all effective")
            check(solved(s) and len(p["path"]) == p["par"], tag + " path clears in par")
            par, ways, states = bfs(b, 14)
            tot += 1
            check(par == p["par"], tag + f" par {p['par']} vs mine {par}")
            check(ways == p["solutions"], tag + f" solutions {p['solutions']} vs mine {ways}")
            check(bands[lv][0] <= par <= bands[lv][1], tag + f" band par {par}")
            if brute_all or lv < 2:
                bc = brute(b, par)
                check(bc == ways, tag + f" brute {bc} vs bfs {ways}")
                # no shorter solution by brute
                if par > 1:
                    check(all(brute(b, q) == 0 for q in range(1, par)), tag + " nothing shorter")
            key = rows_key = tuple(rows)
            check(key not in seen, tag + f" duplicate of {seen.get(key)}")
            seen[key] = tag
            # also duplicates under symmetry
            sp.append(par)
            pars[lv].append(par)
        check(sp[0] < sp[1] < sp[2], f"set {k} ascending {sp}")
    import statistics
    for lv in range(3):
        print("level", lv, "par median", statistics.median(pars[lv]), "range", min(pars[lv]), max(pars[lv]))
    check(statistics.median(pars[0]) < statistics.median(pars[1]) < statistics.median(pars[2]), "median ascending")
    # symmetry dupes: any two boards equal after mirror/rotate
    def variants(rows):
        g = [list(r) for r in rows]
        out = []
        for _ in range(2):
            for _ in range(4):
                g = [list(x) for x in zip(*g[::-1])]
                out.append(tuple("".join(r) for r in g))
            g = [r[::-1] for r in g]
        return out
    canon = {}
    for k in data:
        for lv, p in enumerate(data[k]):
            c = min(variants(p["board"]["rows"]))
            if c in canon:
                print("NOTE symmetric duplicate:", k, lv, "with", canon[c])
            canon[c] = (k, lv)
    print("pool puzzles checked:", tot)


if __name__ == "__main__":
    examples()
    invariants_random()
    pool("--brute" in sys.argv)
    print("checks:", CHECKS, "fails:", len(FAILS))
    sys.exit(1 if FAILS else 0)
