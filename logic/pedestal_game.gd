class_name PedestalGame
extends DojoGame
## «EQUILIBRIO» (pedestal): hold the statue's pose on a pedestal (Plinths) for
## so many seconds. Each round, longer and shakier: the lean tips faster, gets
## nudged out of nowhere, and the wind comes. Fall off and it is lost; the
## level is the rounds held. (Named PedestalGame because BalanceGame is already
## the minigame of the same pose on one foot, logic/minigames/balance.gd.)
##
## The band: ONE holds a round, the first of them to get up on the lit pedestal
## (the one within NEAR of the lit pedestal, `posing`); the rest cheer. If
## they step down before the time, or fall, it is lost; if nobody gets up in
## CLIMB_S it is too ("late"). With several pedestals (set_pedestals) each round
## lights one, not the last one's.
##
## The lean is the game's own little simulation (each holder's, `push` -1..1
## the input): lean'' = topple * lean - DAMP * lean' + nudges + wind + PUSH_GAIN *
## push; over FALL either way it falls. To have the minigame "balance" keep it
## instead, a body carries `fell` (and `lean`): then this only counts time and
## levels. Its difficulty for that comes from params(): `game_level` (0/1/2, as
## the game's own) and `pressure` (0..1, as Plinths.pressure).
##
## Events: spawn {tile, pos, level, hold}, up {by}, nudge {by, dir}, wobble {by},
## tick {left}, fall {by}, clear, level, alarm, lost {why: "fall"|"down"|"late"}, won.

const FALL := 1.6
const WOBBLE := 0.6
const DAMP := 0.4
const PUSH_GAIN := 7.0
const NEAR := 1.0
const CLIMB_S := 15.0
const START_LEAN := 0.1
const WIND_HZ := 0.35
const EXTRA_HOLD := 3.0
const EXTRA_TOPPLE := 0.1
const TOPPLE_MAX := 4.0
const EXTRA_NUDGE := 0.1
const NUDGE_MAX := 2.2
const EXTRA_NUDGE_S := 0.03
const NUDGE_S_MIN := 0.4
const EXTRA_WIND := 0.1
const WIND_MAX := 2.4
## hold: seconds to hold; topple: how fast the lean grows by itself; nudge: the
## jolt of a push out of nowhere, every nudge_s seconds or so; wind: an
## acceleration swaying it either way
const LEVELS := [
	{"hold": 4.0, "topple": 1.6, "nudge": 0.30, "nudge_s": 1.6, "wind": 0.0},
	{"hold": 5.0, "topple": 1.8, "nudge": 0.40, "nudge_s": 1.4, "wind": 0.0},
	{"hold": 6.0, "topple": 2.0, "nudge": 0.50, "nudge_s": 1.3, "wind": 0.3},
	{"hold": 8.0, "topple": 2.2, "nudge": 0.60, "nudge_s": 1.2, "wind": 0.5},
	{"hold": 10.0, "topple": 2.4, "nudge": 0.75, "nudge_s": 1.1, "wind": 0.7},
	{"hold": 12.0, "topple": 2.6, "nudge": 0.90, "nudge_s": 1.0, "wind": 0.9},
	{"hold": 15.0, "topple": 2.8, "nudge": 1.05, "nudge_s": 0.9, "wind": 1.1},
	{"hold": 18.0, "topple": 3.0, "nudge": 1.20, "nudge_s": 0.8, "wind": 1.3},
	{"hold": 22.0, "topple": 3.2, "nudge": 1.35, "nudge_s": 0.7, "wind": 1.5},
	{"hold": 26.0, "topple": 3.4, "nudge": 1.50, "nudge_s": 0.6, "wind": 1.7},
]

var pedestals: Array[Vector2i] = []
## the lit pedestal
var lit := Vector2i.ZERO
## "climb" until somebody is up; then "hold"
var phase := "climb"
var holder := -1
var hold_left := 0.0
var climb_left := 0.0
## the holder's lean and how fast it leans
var lean := 0.0
var lean_v := 0.0
var _nudge_t := 0.0
var _wobbling := false
var _wind_t := 0.0
var _last_pedestal := Vector2i(-999, -999)


static func params(lv: int) -> Dictionary:
	var p := level_row(LEVELS, lv)
	if lv > LEVELS.size():
		var k := lv - LEVELS.size()
		p.hold = float(p.hold) + EXTRA_HOLD * k
		p.topple = minf(TOPPLE_MAX, float(p.topple) + EXTRA_TOPPLE * k)
		p.nudge = minf(NUDGE_MAX, float(p.nudge) + EXTRA_NUDGE * k)
		p.nudge_s = maxf(NUDGE_S_MIN, float(p.nudge_s) - EXTRA_NUDGE_S * k)
		p.wind = minf(WIND_MAX, float(p.wind) + EXTRA_WIND * k)
	p.game_level = 0 if lv <= 3 else (1 if lv <= 7 else 2)
	p.pressure = clampf((lv - 1) / 10.0, 0.0, 1.0)
	return p


func _init() -> void:
	id = "pedestal"


## The pedestals of the dojo (tiles), where a round may be lit.
func set_pedestals(list: Array) -> void:
	pedestals.assign(list)


func _reset() -> void:
	phase = "climb"
	holder = -1
	lean = 0.0
	lean_v = 0.0
	_wobbling = false
	_last_pedestal = Vector2i(-999, -999)


func _begin_level() -> void:
	var p := params(level)
	phase = "climb"
	holder = -1
	hold_left = float(p.hold)
	climb_left = CLIMB_S
	lean = 0.0
	lean_v = 0.0
	_wobbling = false
	_wind_t = 0.0
	_nudge_t = float(p.nudge_s)
	if pedestals.is_empty():
		lit = field.pick(start_tile, [], 2, 9999, {}, rng).get("tile", start_tile) if field != null else start_tile
	else:
		var pool: Array[Vector2i] = pedestals.filter(func(t): return t != _last_pedestal)
		if pool.is_empty():
			pool = pedestals.duplicate()
		lit = pool[rng.below(pool.size())]
	_last_pedestal = lit
	_emit({"e": "spawn", "tile": lit, "pos": DojoField.center(lit), "level": level, "hold": hold_left})


func _play(dt: float, bodies: Array[Dictionary]) -> void:
	if phase == "climb" and not _climb(dt, bodies):
		return
	_hold(dt, bodies)


## Waiting for somebody to get up on the lit pedestal. True once one has (the
## round goes on as a hold in this same frame).
func _climb(dt: float, bodies: Array[Dictionary]) -> bool:
	var mid := DojoField.center(lit)
	for b in _live(bodies):
		if _posing(b) and (b.pos as Vector2).distance_to(mid) <= NEAR:
			phase = "hold"
			holder = int(b.id)
			lean = START_LEAN * (1.0 if rng.next() < 0.5 else -1.0) * (1.0 + rng.next())
			lean_v = 0.0
			_emit({"e": "up", "by": holder})
			return true
	climb_left -= dt
	if climb_left <= 0.0:
		_lose("late")
	return false


## Up on a pedestal (or, when the host does not say, hidden).
func _posing(b: Dictionary) -> bool:
	return b.get("posing", b.get("hidden", false))


## The holder keeps the pose: down or fallen loses, and the time out wins.
func _hold(dt: float, bodies: Array[Dictionary]) -> void:
	var me := {}
	for b in bodies:
		if int(b.id) == holder:
			me = b
	if me.is_empty() or me.get("out", false) or not _posing(me):
		if not me.is_empty() and me.get("fell", false):
			_fall()
		else:
			_lose("down")
		return
	if me.has("fell"):
		lean = float(me.get("lean", lean))
		if me.fell:
			_fall()
			return
	else:
		_sway(dt, float(me.get("push", 0.0)))
		if absf(lean) >= FALL:
			_fall()
			return
	var wob := absf(lean) >= WOBBLE
	if wob and not _wobbling:
		_emit({"e": "wobble", "by": holder})
	_wobbling = wob
	hold_left -= dt
	if hold_left <= 0.0:
		hold_left = 0.0
		_credit(holder)
		holder = -1
		_clear_level()
		return
	_tick(hold_left)


func _fall() -> void:
	_emit({"e": "fall", "by": holder})
	_lose("fall")


func _sway(dt: float, push: float) -> void:
	var p := params(level)
	_wind_t += dt
	_nudge_t -= dt
	if _nudge_t <= 0.0:
		_nudge_t = float(p.nudge_s) * (0.5 + rng.next())
		var jolt := (rng.next() * 2.0 - 1.0) * float(p.nudge)
		lean_v += jolt
		_emit({"e": "nudge", "by": holder, "dir": signf(jolt)})
	var wind := float(p.wind) * sin(_wind_t * TAU * WIND_HZ)
	var acc := float(p.topple) * lean - DAMP * lean_v + wind + PUSH_GAIN * clampf(push, -1.0, 1.0)
	lean_v += acc * dt
	lean += lean_v * dt


func _penalize(seconds: float) -> void:
	# Here a slip of the clock is a longer hold.
	hold_left += seconds


func _view() -> Dictionary:
	var p := params(level)
	var objects: Array[Dictionary] = [{"kind": "pedestal", "pos": DojoField.center(lit), "ring": -1.0}]
	return {"objects": objects, "timer": {"left": hold_left if phase == "hold" else float(p.hold), "max": float(p.hold), "kind": "hold"},
		"lean": lean, "fall": FALL, "phase": phase}
