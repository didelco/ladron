class_name CatchGame
extends DojoGame
## «PILLA EL CALCETÍN» (atrapa): a golden sock turns up somewhere in the dojo
## with a ring that empties; anyone of the band that gets within CATCH_R of it
## (not hiding) takes it, and the next turns up somewhere else. The clock runs
## out: lost. Ten taken: won, and on into the hora extra if you like.
##
## The time of each is base + slack * path * SLACK_K, path being the steps on
## foot from where the last one was (plus GATE_BONUS if a shut door stands in
## between, WATCH_BONUS if it can only be got by crossing a scarecrow's cone),
## never under the level's min_time. Each level asks more (LEVELS):
##   dmin, dmax  how far from the last one, in steps on foot
##   zones       where it may turn up (empty: anywhere)
##   base, slack the time
##   move        tiles a second it wanders at (0: still)
##   gate        behind a shut door, which does not open by itself
##   watch       WATCHED: the sock turns up in a scarecrow's cone or behind it
##               (its shortest way crosses one); watch_n how many different ones
##               (2 from level 9); a thief seen in a cone costs ALARM_S seconds
##               and reddens the dojo, once for each scarecrow (ALARM_COOLDOWN_S)
##   maze        the way at least 1.6 times the straight line
##   ring        the ring is shown (without: only the tick)
##   min_time    the least it gets
## With no scarecrows in the field a watched level asks for a door instead, or
## the maze if there is none.
##
## Events: spawn {pos, tile, level, time, gate, watch, forced, moving, ring},
## tick {left}, catch {by, pos, level, got, left}, clear, level, alarm {by},
## lost {why: "time"}, won.

const SLACK_K := 0.24
const GATE_BONUS := 1.5
const WATCH_BONUS := 1.5
const CATCH_R := 0.8
const EXTRA_SLACK_STEP := 0.02
const EXTRA_SLACK_MIN := 1.0
const EXTRA_DMAX_STEP := 0.5
const EXTRA_MIN_TIME := 4.0
const LEVELS := [
	{"dmin": 5, "dmax": 8, "zones": ["tatami"], "base": 3.0, "slack": 2.2, "move": 0.0, "gate": false, "watch": false, "watch_n": 0, "maze": false, "ring": true, "min_time": 0.0},
	{"dmin": 6, "dmax": 10, "zones": ["tatami"], "base": 2.8, "slack": 2.0, "move": 0.0, "gate": false, "watch": false, "watch_n": 0, "maze": false, "ring": true, "min_time": 0.0},
	{"dmin": 8, "dmax": 13, "zones": ["tatami", "pasillo"], "base": 2.6, "slack": 1.8, "move": 0.0, "gate": false, "watch": false, "watch_n": 0, "maze": false, "ring": true, "min_time": 0.0},
	{"dmin": 10, "dmax": 16, "zones": ["tatami", "pasillo", "exposicion"], "base": 2.4, "slack": 1.65, "move": 0.0, "gate": false, "watch": false, "watch_n": 0, "maze": false, "ring": true, "min_time": 0.0},
	{"dmin": 12, "dmax": 18, "zones": ["tatami", "pasillo", "exposicion", "escondites", "patio"], "base": 2.2, "slack": 1.5, "move": 0.8, "gate": false, "watch": false, "watch_n": 0, "maze": false, "ring": true, "min_time": 0.0},
	{"dmin": 12, "dmax": 20, "zones": [], "base": 2.0, "slack": 1.45, "move": 0.0, "gate": true, "watch": false, "watch_n": 0, "maze": false, "ring": true, "min_time": 0.0},
	{"dmin": 14, "dmax": 22, "zones": ["pasillo"], "base": 1.9, "slack": 1.4, "move": 0.0, "gate": false, "watch": true, "watch_n": 1, "maze": false, "ring": true, "min_time": 0.0},
	{"dmin": 14, "dmax": 24, "zones": ["laberinto"], "base": 1.8, "slack": 1.3, "move": 0.0, "gate": false, "watch": true, "watch_n": 1, "maze": true, "ring": true, "min_time": 0.0},
	{"dmin": 16, "dmax": 26, "zones": [], "base": 1.6, "slack": 1.25, "move": 1.4, "gate": false, "watch": true, "watch_n": 2, "maze": false, "ring": false, "min_time": 0.0},
	{"dmin": 16, "dmax": 24, "zones": ["laberinto", "pasillo"], "base": 1.4, "slack": 1.15, "move": 1.8, "gate": true, "watch": true, "watch_n": 2, "maze": false, "ring": false, "min_time": 4.5},
]

## the sock: {pos: Vector2, tile, left, max, ring, move, gate, watch, forced,
## path: Array[Vector2i] it is walking, zone}
var obj := {}
## where the last one was (the next is placed from here)
var prev := Vector2i.ZERO
## the scarecrows the last levels used (the next ones prefer others)
var used: Array[String] = []
var last_spawn := {}
## the doors this level asks the host to shut (ids)
var shut: Array[String] = []


## The level's numbers; past the tenth, the hora extra's.
static func params(lv: int) -> Dictionary:
	var p: Dictionary = (LEVELS[clampi(lv, 1, LEVELS.size()) - 1] as Dictionary).duplicate(true)
	if lv > LEVELS.size():
		var n := lv - LEVELS.size()
		p.slack = maxf(EXTRA_SLACK_MIN, float(p.slack) - EXTRA_SLACK_STEP * n)
		p.dmax = float(p.dmax) + EXTRA_DMAX_STEP * n
		p.min_time = EXTRA_MIN_TIME
	return p


## The time a sock gets for a way of `path` steps.
static func time_for(lv: int, path: int, gate := false, forced := false) -> float:
	var p := params(lv)
	var t := float(p.base) + float(p.slack) * path * SLACK_K
	if gate:
		t += GATE_BONUS
	if forced:
		t += WATCH_BONUS
	return maxf(t, float(p.min_time))


func _init() -> void:
	id = "atrapa"


func _reset() -> void:
	obj = {}
	prev = start_tile
	used = []
	shut = []
	last_spawn = {}


func _begin_level() -> void:
	var p := params(level)
	var opts := {}
	var watch: bool = p.watch and field != null and not field.scarecrows.is_empty()
	var gate: bool = p.gate
	var maze: bool = p.maze
	if p.watch and not watch:
		# No scarecrows: a door instead, or the maze if there is none.
		if field != null and not field.gates.is_empty():
			gate = true
		else:
			maze = true
	if gate:
		opts.gate = true
	if maze:
		opts.maze = true
	if watch:
		opts.watched = true
		opts.watched_min = int(p.watch_n)
		if not used.is_empty():
			opts.prefer_not = used.duplicate()
	var c := field.pick(prev, p.zones, p.dmin, p.dmax, opts, rng)
	if c.is_empty():
		c = {"tile": prev, "zone": "", "gate": "", "path": 0, "time_path": 0, "watchers": [], "cross": [], "forced": false}
	var tile: Vector2i = c.tile
	var closes: bool = gate and String(c.gate) != ""
	shut = []
	if closes:
		shut.append(String(c.gate))
	var forced: bool = watch and bool(c.forced)
	var secs := time_for(level, int(c.time_path) if watch else int(c.path), closes, forced)
	used = []
	if watch:
		for sid in c.cross:
			used.append(sid)
	obj = {"pos": DojoField.center(tile), "tile": tile, "left": secs, "max": secs, "ring": p.ring, "move": float(p.move),
		"gate": String(c.gate) if closes else "", "watch": watch, "forced": forced, "zone": c.zone,
		"path": [] as Array[Vector2i], "cross": c.cross, "relaxed": c.get("relaxed", 0)}
	last_spawn = c
	_emit({"e": "spawn", "pos": obj.pos, "tile": tile, "level": level, "time": secs, "gate": obj.gate,
		"watch": watch, "forced": forced, "cross": c.cross, "moving": float(p.move) > 0.0, "ring": p.ring})


func _play(dt: float, bodies: Array[Dictionary]) -> void:
	if obj.is_empty():
		return
	var p := params(level)
	if obj.move > 0.0:
		_wander(obj, dt, shut)
	# Taken?
	for b in _live(bodies):
		if b.get("hidden", false):
			continue
		if (b.pos as Vector2).distance_to(obj.pos) < CATCH_R:
			var at: Vector2 = obj.pos
			prev = obj.tile
			_credit(int(b.id))
			_emit({"e": "catch", "by": int(b.id), "pos": at, "level": level, "got": got + 1, "left": obj.left})
			obj = {}
			_clear_level()
			return
	if p.watch and field != null and not field.scarecrows.is_empty():
		_watch(field.scarecrows, bodies)
	obj.left = float(obj.left) - dt
	if obj.left <= 0.0:
		obj.left = 0.0
		_lose("time")
		return
	_tick(obj.left)


func _penalize(seconds: float) -> void:
	if not obj.is_empty():
		obj.left = maxf(0.05, float(obj.left) - seconds)


func _view() -> Dictionary:
	var objects: Array[Dictionary] = []
	if not obj.is_empty():
		objects.append({"kind": "sock", "pos": obj.pos, "ring": (float(obj.left) / float(obj.max)) if obj.ring else -1.0,
			"gate": obj.gate, "moving": obj.move > 0.0, "watch": obj.watch})
	return {"objects": objects, "timer": {"left": float(obj.get("left", 0.0)), "max": float(obj.get("max", 0.0)), "kind": "limit"},
		"gates_closed": shut.duplicate(), "scarecrows": field.scarecrows if field != null else [],
		"headline": "level"}
