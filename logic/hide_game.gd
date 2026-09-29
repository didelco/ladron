class_name HideGame
extends DojoGame
## «AGUANTA ESCONDIDO» (aguanta): get into a hideout (Hideouts: armour, crate,
## locker) and stay hidden for so many seconds while a scarecrow's lantern
## sweeps the place, and, in the higher rounds, hold in the sneeze as well.
##
## A round has two parts. First the band gets in: in `enter` seconds the band
## must be hidden (else "late"). Then it holds `hold` seconds. Lost if:
##   "seen"    the lantern sees a thief who is not hidden (in either part);
##   "left"    a thief that was hidden comes out (LEAVE_GRACE_S of leeway for
##             a frame's glitch);
##   "sneeze"  the sneeze bar of a hidden thief fills up (ACHOO!);
##   "late"    not all in, in time.
##
## WHO must hide, with several thieves (decided): as many as there are open
## hideouts this round (`spots`, fewer the higher the level), up to the whole
## band: need = min(alive thieves, spots). Those that are hidden when the
## count is reached are "in" and must stay; the rest, if any, must keep out of
## the lantern (they are lost if it sees them: the rule is the same, whoever it
## is). With no hideouts given (set_hideouts), any hidden body counts and
## `spots` is the count.
##
## The lantern: a scarecrow with a lantern (`lantern`, a DojoField scarecrow
## dictionary) whose facing swings: lantern_angle = lantern_center + amp *
## sin(phase), phase advancing `sweep` radians a second. The host puts
## lantern_angle on its scarecrow every frame and answers `seen` (or the field's
## rule) for it.
##
## The sneeze: from level 5 the bar of each hidden thief rises `rise` a second
## and jumps `burst` every 2 to 4 seconds; each PRESS of `hold` (a body's key,
## the action) takes TAP off it: keep tapping. It never ends while you stay in.
##
## Events: spawn {level, hold, enter, hides: [tiles], spots}, in {n, need}, tick
## {left}, tickle {by, bar} (the bar over WARN), sneeze {by} (ACHOO), clear, level,
## alarm, lost {why, by}, won.

const LEAVE_GRACE_S := 0.3
const TAP := 0.2
const WARN := 0.7
const NEAR_HIDE := 1.3
const BURST_MIN_S := 2.0
const BURST_MAX_S := 4.0
const EXTRA_HOLD := 3.0
const EXTRA_SWEEP := 0.1
const SWEEP_MAX := 3.6
const EXTRA_RISE := 0.03
const RISE_MAX := 0.6
const ENTER_MIN := 3.0
const LEVELS := [
	{"hold": 5.0, "sweep": 0.8, "amp": 0.9, "spots": 4, "rise": 0.0, "burst": 0.0, "enter": 8.0},
	{"hold": 7.0, "sweep": 1.0, "amp": 0.9, "spots": 4, "rise": 0.0, "burst": 0.0, "enter": 8.0},
	{"hold": 9.0, "sweep": 1.2, "amp": 1.0, "spots": 4, "rise": 0.0, "burst": 0.0, "enter": 7.0},
	{"hold": 12.0, "sweep": 1.4, "amp": 1.0, "spots": 3, "rise": 0.0, "burst": 0.0, "enter": 7.0},
	{"hold": 15.0, "sweep": 1.6, "amp": 1.1, "spots": 3, "rise": 0.10, "burst": 0.08, "enter": 6.0},
	{"hold": 18.0, "sweep": 1.8, "amp": 1.1, "spots": 3, "rise": 0.14, "burst": 0.10, "enter": 6.0},
	{"hold": 21.0, "sweep": 2.0, "amp": 1.2, "spots": 2, "rise": 0.18, "burst": 0.12, "enter": 5.0},
	{"hold": 24.0, "sweep": 2.2, "amp": 1.2, "spots": 2, "rise": 0.22, "burst": 0.14, "enter": 5.0},
	{"hold": 27.0, "sweep": 2.4, "amp": 1.2, "spots": 1, "rise": 0.28, "burst": 0.16, "enter": 4.0},
	{"hold": 30.0, "sweep": 2.6, "amp": 1.3, "spots": 1, "rise": 0.34, "burst": 0.18, "enter": 4.0},
]

var hideouts: Array[Vector2i] = []
## the hideouts open this round
var open_hides: Array[Vector2i] = []
## the lantern's scarecrow (a DojoField one) and where its swing is centred (radians)
var lantern := {"id": "linterna", "tile": Vector2i.ZERO, "facing": PI / 2.0, "range": 5.5, "angle": 0.42}
var lantern_center := PI / 2.0
var lantern_angle := PI / 2.0
var phase := "enter"
var enter_left := 0.0
var hold_left := 0.0
var need := 1
## ids of the thieves in (hidden when the hold began) and their sneeze bars
var inside: Array[int] = []
var bars := {}
var spots := 1
var _sweep_t := 0.0
var _burst_t := 0.0
var _out_for := {}
var _pressed := {}
var _warned := {}


static func params(lv: int) -> Dictionary:
	var p := level_row(LEVELS, lv)
	if lv > LEVELS.size():
		var k := lv - LEVELS.size()
		p.hold = float(p.hold) + EXTRA_HOLD * k
		p.sweep = minf(SWEEP_MAX, float(p.sweep) + EXTRA_SWEEP * k)
		p.rise = minf(RISE_MAX, float(p.rise) + EXTRA_RISE * k)
		p.enter = maxf(ENTER_MIN, float(p.enter) - 0.25 * k)
	return p


func _init() -> void:
	id = "aguanta"


## The dojo's hideouts (tiles), where a round may open some.
func set_hideouts(list: Array) -> void:
	hideouts.assign(list)


## Set the lantern: its post (tile) and the centre of its swing.
func set_lantern(tile: Vector2i, center_angle: float) -> void:
	lantern.tile = tile
	lantern_center = center_angle
	lantern_angle = center_angle
	lantern.facing = center_angle


func _reset() -> void:
	phase = "enter"
	inside = []
	bars = {}
	open_hides = []
	_sweep_t = 0.0
	lantern_angle = lantern_center
	lantern.facing = lantern_angle


func _begin_level() -> void:
	var p := params(level)
	phase = "enter"
	enter_left = float(p.enter)
	hold_left = float(p.hold)
	inside = []
	bars = {}
	_out_for = {}
	_pressed = {}
	_warned = {}
	_burst_t = BURST_MIN_S + rng.next() * (BURST_MAX_S - BURST_MIN_S)
	open_hides = []
	spots = int(p.spots)
	if not hideouts.is_empty():
		var pool: Array = hideouts.duplicate()
		_shuffle(pool)
		spots = mini(spots, pool.size())
		for i in spots:
			open_hides.append(pool[i])
	need = 1
	_emit({"e": "spawn", "level": level, "hold": hold_left, "enter": enter_left, "hides": open_hides.duplicate(), "spots": spots})


## Whether a body is hidden in a hideout that counts (an open one, when they are known).
func _counts(b: Dictionary) -> bool:
	if not b.get("hidden", false):
		return false
	if open_hides.is_empty():
		return true
	for t in open_hides:
		if (b.pos as Vector2).distance_to(DojoField.center(t)) <= NEAR_HIDE:
			return true
	return false


func _play(dt: float, bodies: Array[Dictionary]) -> void:
	var p := params(level)
	var alive := _live(bodies)
	if not _sweep(dt, p, alive):
		return
	need = mini(alive.size(), spots)
	if phase == "enter" and not _enter(dt, alive):
		return
	if not _stay_in(dt, bodies):
		return
	if float(p.rise) > 0.0 and not _sneeze(dt, p, bodies):
		return
	hold_left -= dt
	if hold_left <= 0.0:
		hold_left = 0.0
		for k in inside:
			_credit(k)
		_clear_level()
		return
	_tick(hold_left)


## The lantern swings; whoever it sees out of a hideout loses the game.
## False if it did.
func _sweep(dt: float, p: Dictionary, alive: Array[Dictionary]) -> bool:
	_sweep_t += dt * float(p.sweep)
	lantern_angle = lantern_center + float(p.amp) * sin(_sweep_t)
	lantern.facing = lantern_angle
	for b in alive:
		if not b.get("hidden", false) and sees(lantern, b.pos, false):
			_lose("seen", {"by": int(b.id)})
			return false
	return true


## Getting in: once `need` of them are hidden the hold begins (true); until
## then the time to get in runs down, and out, "late". False while still in the
## enter part.
func _enter(dt: float, alive: Array[Dictionary]) -> bool:
	var in_ids: Array[int] = []
	for b in alive:
		if _counts(b):
			in_ids.append(int(b.id))
	if need > 0 and in_ids.size() >= need:
		phase = "hold"
		inside = in_ids
		for k in inside:
			bars[k] = 0.0
			_out_for[k] = 0.0
		_emit({"e": "in", "n": in_ids.size(), "need": need})
		return true
	enter_left -= dt
	if enter_left <= 0.0:
		enter_left = 0.0
		_lose("late")
	else:
		_tick(enter_left)
	return false


## Holding: a thief that was in and is out (or out of play) for LEAVE_GRACE_S
## loses the game. False if one did.
func _stay_in(dt: float, bodies: Array[Dictionary]) -> bool:
	for b in bodies:
		var k := int(b.id)
		if not inside.has(k):
			continue
		if b.get("out", false) or not _counts(b):
			_out_for[k] = float(_out_for.get(k, 0.0)) + dt
			if _out_for[k] >= LEAVE_GRACE_S:
				_lose("left", {"by": k})
				return false
		else:
			_out_for[k] = 0.0
	return true


## The sneeze bars rise, jump now and then, and drop TAP for each press of the
## key; a full one sneezes and loses. False if one did.
func _sneeze(dt: float, p: Dictionary, bodies: Array[Dictionary]) -> bool:
	_burst_t -= dt
	var burst := 0.0
	if _burst_t <= 0.0:
		_burst_t = BURST_MIN_S + rng.next() * (BURST_MAX_S - BURST_MIN_S)
		burst = float(p.burst)
	for b in bodies:
		var k := int(b.id)
		if not inside.has(k):
			continue
		var held: bool = b.get("hold", false)
		if held and not _pressed.get(k, false):
			bars[k] = maxf(0.0, float(bars[k]) - TAP)
		_pressed[k] = held
		bars[k] = float(bars[k]) + float(p.rise) * dt + burst
		if bars[k] >= WARN and not _warned.get(k, false):
			_warned[k] = true
			_emit({"e": "tickle", "by": k, "bar": bars[k]})
		elif bars[k] < WARN:
			_warned[k] = false
		if bars[k] >= 1.0:
			_emit({"e": "sneeze", "by": k})
			_lose("sneeze", {"by": k})
			return false
	return true


func _penalize(seconds: float) -> void:
	if phase == "hold":
		hold_left += seconds
	else:
		enter_left = maxf(0.05, enter_left - seconds)


func _view() -> Dictionary:
	var p := params(level)
	var objects: Array[Dictionary] = []
	for t in open_hides:
		objects.append({"kind": "hideout", "pos": DojoField.center(t), "ring": -1.0})
	var timer_left := hold_left if phase == "hold" else enter_left
	var timer_max: float = float(p.hold) if phase == "hold" else float(p.enter)
	return {"objects": objects, "timer": {"left": timer_left, "max": timer_max, "kind": "hold" if phase == "hold" else "limit"},
		"phase": phase, "lantern": {"pos": DojoField.torch_of(lantern), "angle": lantern_angle, "range": lantern.range, "cone": lantern.angle},
		"bars": bars.duplicate()}
