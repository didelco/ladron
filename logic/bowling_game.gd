class_name BowlingGame
extends DojoGame
## «BOLOS» (bolos): you are the ball. Pins turn up in the dojo, a round at a
## time (one, or a batch), and each has its own clock: bring it down by
## ROLLING into it before it runs out, or lose. Walking into one does nothing
## (a knock needs the ball: a roll at ROLL_MIN_SPEED tiles a second or more, the
## voltereta is 7.3). A pin that goes down knocks over the pins beside it (within
## CHAIN_R of one that is falling, and so on): a strike, and it counts for
## whoever rolled. A round is done when all its pins are down; ten rounds
## won; then the hora extra.
##
## The time of a pin is base + slack * path * BOWL_K + GATE_BONUS if it is
## behind a shut door, never under MIN_TIME. LEVELS, by round:
##   n         pins in the round
##   cluster   they stand together (one in the middle, the rest round it) and
##             fall in a heap; otherwise scattered, KEEP_APART from each other
##   movers    how many of them wander, at `move` tiles a second
##   dmin dmax zones base slack gate maze   as in CatchGame
##
## Events: spawn {pins: [{pos, tile, time, gate, moving}], level}, tick {left},
## knock {by, pin, pos, dir, chain}, strike {by, count, full}, clear, level,
## alarm, lost {why: "time", pin}, won.

const BOWL_K := 0.3
const GATE_BONUS := 1.5
const MIN_TIME := 3.0
## Rolling this fast (tiles a second) or more knocks a pin; the roll itself
## is Roll.SPEED (7.3).
const ROLL_MIN_SPEED := 5.0
const KNOCK_R := 0.75
const CHAIN_R := 1.5
## The pins of a scattered round keep this far from each other (a chessboard
## distance, DojoField.AVOID).
const KEEP_APART := 3
## A pin takes this long to fall over (for the picture).
const FALL_S := 0.7
const EXTRA_SLACK_STEP := 0.02
const EXTRA_SLACK_MIN := 1.2
const EXTRA_DMAX_STEP := 0.5
const EXTRA_PINS_EVERY := 3
const MAX_PINS := 6
const LEVELS := [
	{"n": 1, "cluster": false, "movers": 0, "move": 0.0, "dmin": 4, "dmax": 8, "zones": ["tatami"], "base": 4.0, "slack": 2.4, "gate": false, "maze": false},
	{"n": 1, "cluster": false, "movers": 0, "move": 0.0, "dmin": 6, "dmax": 10, "zones": ["tatami"], "base": 3.8, "slack": 2.3, "gate": false, "maze": false},
	{"n": 2, "cluster": false, "movers": 0, "move": 0.0, "dmin": 6, "dmax": 11, "zones": ["tatami", "pasillo"], "base": 3.8, "slack": 2.2, "gate": false, "maze": false},
	{"n": 2, "cluster": false, "movers": 1, "move": 0.5, "dmin": 8, "dmax": 13, "zones": ["tatami", "pasillo", "exposicion"], "base": 3.6, "slack": 2.1, "gate": false, "maze": false},
	{"n": 2, "cluster": true, "movers": 0, "move": 0.0, "dmin": 8, "dmax": 14, "zones": ["tatami", "pasillo", "exposicion", "escondites", "patio"], "base": 3.4, "slack": 2.0, "gate": false, "maze": false},
	{"n": 3, "cluster": false, "movers": 1, "move": 0.6, "dmin": 10, "dmax": 16, "zones": [], "base": 3.4, "slack": 1.9, "gate": true, "maze": false},
	{"n": 3, "cluster": true, "movers": 0, "move": 0.0, "dmin": 10, "dmax": 18, "zones": ["pasillo"], "base": 3.2, "slack": 1.8, "gate": false, "maze": false},
	{"n": 3, "cluster": false, "movers": 2, "move": 0.8, "dmin": 12, "dmax": 20, "zones": ["laberinto"], "base": 3.0, "slack": 1.7, "gate": false, "maze": true},
	{"n": 4, "cluster": true, "movers": 0, "move": 0.0, "dmin": 12, "dmax": 22, "zones": [], "base": 3.0, "slack": 1.6, "gate": false, "maze": false},
	{"n": 4, "cluster": false, "movers": 2, "move": 1.2, "dmin": 14, "dmax": 24, "zones": ["laberinto", "pasillo"], "base": 2.8, "slack": 1.5, "gate": true, "maze": false},
]

## the pins of the round: {pos, tile, left, max, down, fell (seconds since it
## went), steps (the way it was timed by), move, path, gate, by}
var pins: Array[Dictionary] = []
var prev := Vector2i.ZERO
var shut: Array[String] = []
## the pins the whole game has brought down, and the strikes
var pins_down := 0
var strikes := 0


static func params(lv: int) -> Dictionary:
	var p: Dictionary = (LEVELS[clampi(lv, 1, LEVELS.size()) - 1] as Dictionary).duplicate(true)
	if lv > LEVELS.size():
		var k := lv - LEVELS.size()
		p.slack = maxf(EXTRA_SLACK_MIN, float(p.slack) - EXTRA_SLACK_STEP * k)
		p.dmax = float(p.dmax) + EXTRA_DMAX_STEP * k
		p.n = mini(MAX_PINS, int(p.n) + k / EXTRA_PINS_EVERY)
	p.min_time = MIN_TIME
	return p


static func time_for(lv: int, path: int, gate := false) -> float:
	var p := params(lv)
	var t := float(p.base) + float(p.slack) * path * BOWL_K
	if gate:
		t += GATE_BONUS
	return maxf(t, MIN_TIME)


func _init() -> void:
	id = "bolos"


func _reset() -> void:
	pins = []
	prev = start_tile
	shut = []
	pins_down = 0
	strikes = 0


func _begin_level() -> void:
	var p := params(level)
	pins = []
	shut = []
	var opts := {}
	if p.gate:
		opts.gate = true
	if p.maze:
		opts.maze = true
	var first := field.pick(prev, p.zones, p.dmin, p.dmax, opts, rng)
	if first.is_empty():
		first = {"tile": prev, "gate": "", "path": 0}
	var tiles: Array[Dictionary] = [first]
	var n: int = p.n
	if p.cluster:
		var ortho: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].filter(func(d): return field.has_floor(first.tile + d))
		var diag: Array = [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)].filter(func(d): return field.has_floor(first.tile + d))
		_shuffle(ortho)
		_shuffle(diag)
		for d in ortho + diag:
			if tiles.size() >= n:
				break
			tiles.append({"tile": first.tile + d, "gate": first.gate, "path": int(first.path)})
	else:
		while tiles.size() < n:
			var avoid: Array = tiles.map(func(c): return c.tile)
			var o := opts.duplicate()
			o.avoid = avoid
			var c := field.pick(prev, p.zones, p.dmin, p.dmax, o, rng)
			if c.is_empty():
				break
			tiles.append(c)
	var movers_left: int = p.movers
	for i in tiles.size():
		var c: Dictionary = tiles[i]
		var mover: bool = not p.cluster and i >= tiles.size() - movers_left
		var closes: bool = p.gate and String(c.gate) != ""
		if closes and not shut.has(String(c.gate)):
			shut.append(String(c.gate))
		var secs := time_for(level, int(c.path), closes)
		pins.append({"pos": DojoField.center(c.tile), "tile": c.tile, "left": secs, "max": secs, "down": false, "fell": 0.0,
			"steps": int(c.path), "move": float(p.move) if mover else 0.0, "path": [] as Array[Vector2i], "gate": String(c.gate) if closes else "", "by": -1})
	var list: Array[Dictionary] = []
	for q in pins:
		list.append({"pos": q.pos, "tile": q.tile, "time": q.max, "gate": q.gate, "moving": q.move > 0.0})
	_emit({"e": "spawn", "pins": list, "level": level})


func _play(dt: float, bodies: Array[Dictionary]) -> void:
	for q in pins:
		if q.down:
			q.fell = float(q.fell) + dt
		elif q.move > 0.0:
			_wander(q, dt, shut)
	# The ball.
	for b in _live(bodies):
		if not b.get("rolling", false) or float(b.get("speed", 0.0)) < ROLL_MIN_SPEED:
			continue
		var hit := 0
		var total := 0
		for i in pins.size():
			var q := pins[i]
			if q.down or (b.pos as Vector2).distance_to(q.pos) >= KNOCK_R:
				continue
			hit += 1
			total += _knock(i, int(b.id), b.pos, false)
		if hit > 0:
			var chained := total - hit
			if chained > 0:
				strikes += 1
				var every := pins.all(func(q): return q.down)
				_emit({"e": "strike", "by": int(b.id), "count": total, "full": every and pins.size() > 1})
	if pins.all(func(q): return q.down):
		_clear_level()
		return
	var least := INF
	for q in pins:
		if q.down:
			continue
		q.left = float(q.left) - dt
		least = minf(least, q.left)
		if q.left <= 0.0:
			q.left = 0.0
			_lose("time")
			_events[_events.size() - 1]["pin"] = pins.find(q)
			return
	if least < INF:
		_tick(least)


## Down goes a pin, and the pins beside it. How many fell.
func _knock(i: int, by: int, from: Vector2, chain: bool) -> int:
	var q := pins[i]
	if q.down:
		return 0
	q.down = true
	q.by = by
	q.fell = 0.0
	pins_down += 1
	_credit(by)
	var dir := ((q.pos as Vector2) - from).normalized() if (q.pos as Vector2) != from else Vector2.RIGHT
	_emit({"e": "knock", "by": by, "pin": i, "pos": q.pos, "dir": dir, "chain": chain, "level": level})
	var n := 1
	for j in pins.size():
		if not pins[j].down and (pins[j].pos as Vector2).distance_to(q.pos) <= CHAIN_R:
			n += _knock(j, by, q.pos, true)
	return n


func _penalize(seconds: float) -> void:
	for q in pins:
		if not q.down:
			q.left = maxf(0.05, float(q.left) - seconds)


func _view() -> Dictionary:
	var objects: Array[Dictionary] = []
	var least := 0.0
	var top := 0.0
	var first := true
	for q in pins:
		objects.append({"kind": "pin", "pos": q.pos, "ring": 0.0 if q.down else float(q.left) / float(q.max), "down": q.down,
			"fell": minf(1.0, float(q.fell) / FALL_S), "gate": q.gate, "moving": q.move > 0.0})
		if not q.down and (first or q.left < least):
			least = q.left
			top = q.max
			first = false
	return {"objects": objects, "timer": {"left": least, "max": top, "kind": "limit"}, "gates_closed": shut.duplicate(),
		"scarecrows": [], "headline": "level", "pins_left": pins.filter(func(q): return not q.down).size()}
