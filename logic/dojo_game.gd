class_name DojoGame
extends RefCounted
## What the dojo's games (DojoGames) share: a game of rounds each harder than
## the last, lost at the first failure. It is played at one of three
## difficulties (DojoGames.TIERS: easy, medium, hard), each a stretch of the ten
## levels: it begins at the first level of the stretch and is won by doing the
## last. Nothing here is won for the story: no guards, no stars, no progress
## but the best level kept for each stretch and size of band (DojoGames.record).
##
## The flow:
##   idle     not begun (start() begins)
##   ready    "¿LISTOS?", READY_S seconds
##   playing  a level, until it is done or lost
##   between  BETWEEN_S seconds before the next level
##   won      the last level of the stretch done
##   lost     failed; the level reached is `level`, and `got` were done
## `level` is the level being played (or, once lost, failed; once won, the last
## one done); `got` the levels done, out of `goal`. abort() leaves the game from
## wherever.
##
## Pure logic, no nodes. The host (Main, in the house) calls step(dt, bodies)
## every frame with the band's bodies and plays what comes back:
##   {id: int (whoever it is), pos: Vector2 (tiles), rolling: bool, hidden: bool
##    (in a hideout; for "pedestal", up on a pedestal), speed: float (tiles/s),
##    out: bool (down, caught, out of play)}, and, for the games that use them,
##   hold: bool (the action key held, "aguanta"), posing: bool (up on a
##   pedestal, "pedestal"; defaults to `hidden`), fell: bool and lean: float
##   (the pedestal game's: the Minigame "balance" keeps the pose, this only
##   counts the time).
## The events are dictionaries with "e" for what happened, each game's own, and
## these of all: {"e": "ready"}, {"e": "level", level, got}, {"e": "alarm", by,
## seconds}, {"e": "lost", level, got, why}, {"e": "won", level, got},
## {"e": "abort"}.

const READY_S := 2.0
const BETWEEN_S := 1.0
## A scarecrow that sees a thief takes this long off the clock, and the dojo
## goes red for ALERT_RED_S; the same scarecrow does not do it again for
## ALARM_COOLDOWN_S.
const ALARM_S := 2.0
const ALERT_RED_S := 3.0
const ALARM_COOLDOWN_S := 3.0

var id := ""
var players := 1
var state := "idle"
var level := 0
var got := 0
## the stretch of levels played (DojoGames.TIERS): its index, first and last level
var tier := 0
var first := 1
var last := 10
## how many levels the stretch has
var goal := 10
var field: DojoField
var seed_value := 0
var rng: Mulberry32
## where the game starts (the first thing is placed from here): the tile of its
## start point, and the thief that started it (-1: whoever)
var start_tile := Vector2i.ZERO
var starter := -1
## The rule of sight: Callable(scarecrow: Dictionary, pos: Vector2, hidden: bool)
## -> bool. Invalid: the field's own (DojoField.sees). The host gives Practice's.
var seen := Callable()
## the band's names by body id, for the MVP
var names: Array[String] = []
## the best level kept for this size of band before playing, and whether this
## game beat it (DojoGames.settle sets both)
var best := 0
var new_record := false
## seconds of play, and the why of the loss
var time := 0.0
var lost_why := ""
## red alarm left, in seconds (the dojo's lights), and the last one's total
var alert_left := 0.0
## who did what: id -> how many (things caught, pins knocked, ...)
var credits := {}

var _events: Array[Dictionary] = []
var _ready_left := 0.0
var _between_left := 0.0
var _tick_key := -1
var _cool := {}


func setup(players_: int, seed_: int, field_: DojoField, start_: Vector2i, tier_ := 0) -> void:
	players = clampi(players_, 1, 4)
	seed_value = seed_
	rng = Mulberry32.new(seed_)
	field = field_
	start_tile = start_
	tier = clampi(tier_, 0, DojoGames.TIERS.size() - 1)
	first = int(DojoGames.TIERS[tier].from)
	last = int(DojoGames.TIERS[tier].to)
	goal = last - first + 1


## Begin (or begin again, from the stretch's first level): "¿LISTOS?", then it.
func start() -> void:
	rng = Mulberry32.new(seed_value)
	state = "ready"
	level = first
	got = 0
	time = 0.0
	lost_why = ""
	new_record = false
	alert_left = 0.0
	credits = {}
	_cool = {}
	_tick_key = -1
	_ready_left = READY_S
	_reset()
	_emit({"e": "ready", "level": level})


## Leave the game, from wherever, with nothing kept.
func abort() -> void:
	if state == "idle":
		return
	state = "idle"
	_emit({"e": "abort", "level": level, "got": got})
	_reset()


## Whether the game is on (something to draw, the host to step).
func active() -> bool:
	return state != "idle"


func finished() -> bool:
	return state == "won" or state == "lost"


## A scarecrow saw somebody, or the host says so: this much off the clock (the
## game's own way, _penalize) and the dojo red. Only while playing.
func alarm(seconds := ALARM_S, by := "") -> bool:
	if state != "playing":
		return false
	alert_left = ALERT_RED_S
	_penalize(seconds)
	_emit({"e": "alarm", "by": by, "seconds": seconds, "red": ALERT_RED_S})
	return true


## The band's member with most to their name, or -1 for none (or a lone thief).
func mvp() -> int:
	if players < 2:
		return -1
	var best_id := -1
	var most := 0
	var ids := credits.keys()
	ids.sort()
	for k in ids:
		if int(credits[k]) > most:
			most = int(credits[k])
			best_id = int(k)
	return best_id


func mvp_name() -> String:
	var m := mvp()
	if m >= 0 and m < names.size():
		return names[m]
	return ""


## One frame. Returns the events of it (and of what was done since the last).
func step(dt: float, bodies: Array[Dictionary]) -> Array[Dictionary]:
	alert_left = maxf(0.0, alert_left - dt)
	for k in _cool.keys():
		_cool[k] = maxf(0.0, float(_cool[k]) - dt)
	match state:
		"ready":
			_ready_left -= dt
			if _ready_left <= 0.0:
				state = "playing"
				_tick_key = -1
				_begin_level()
		"playing":
			time += dt
			_play(dt, bodies)
		"between":
			_between_left -= dt
			if _between_left <= 0.0:
				state = "playing"
				_tick_key = -1
				_begin_level()
	var out := _events
	_events = []
	return out


## What the host draws: the same for every game, plus what each adds (`objects`
## to draw, `timer`, ...).
func view() -> Dictionary:
	var v := {"id": id, "state": state, "level": level, "got": got, "goal": goal, "tier": tier,
		"best": best, "players": players, "new_record": new_record, "reached": level,
		"alert": clampf(alert_left / ALERT_RED_S, 0.0, 1.0), "time": time,
		"ready": maxf(0.0, _ready_left), "mvp": mvp(), "mvp_name": mvp_name(), "why": lost_why,
		"names": names}
	v.merge(_view(), true)
	return v


# --- For each game to say ---------------------------------------------------------------------

## Forget the round (start, abort).
func _reset() -> void:
	pass


## Set up the level being begun (`level`).
func _begin_level() -> void:
	pass


## A frame of play.
func _play(_dt: float, _bodies: Array[Dictionary]) -> void:
	pass


## Take seconds off what the level has left (alarm).
func _penalize(_seconds: float) -> void:
	pass


func _view() -> Dictionary:
	return {}


# --- For them to use ---------------------------------------------------------------------------

func _emit(e: Dictionary) -> void:
	_events.append(e)


func _credit(who: int, n := 1) -> void:
	credits[who] = int(credits.get(who, 0)) + n


func _live(bodies: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in bodies:
		if not b.get("out", false):
			out.append(b)
	return out


## The level's turn comes: play it.
func _begin_play() -> void:
	state = "playing"
	_tick_key = -1
	_begin_level()


## The level is done: on to the next (after BETWEEN_S), or, the stretch's last, won.
func _clear_level() -> void:
	got += 1
	_emit({"e": "clear", "level": level, "got": got})
	if level >= last:
		state = "won"
		_emit({"e": "won", "level": level, "got": got})
		return
	level += 1
	state = "between"
	_between_left = BETWEEN_S
	_emit({"e": "level", "level": level, "got": got})


## The game is lost; `more` is what the event "lost" carries besides its own
## (who, which pin).
func _lose(why: String, more := {}) -> void:
	if state == "lost":
		return
	state = "lost"
	lost_why = why
	var e := {"e": "lost", "level": level, "got": got, "why": why}
	e.merge(more)
	_emit(e)


## A beat for a clock: an event every second with `left` <= 5, and every half
## second with <= 2, once for each (never twice for the same beat).
func _tick(left: float) -> void:
	var step_s := 0.5 if left <= 2.0 else (1.0 if left <= 5.0 else 0.0)
	if step_s == 0.0:
		_tick_key = -1
		return
	var key := int(ceil(left / step_s)) + (1000 if step_s == 0.5 else 0)
	if key != _tick_key:
		_tick_key = key
		_emit({"e": "tick", "left": left})


## Ask whether a scarecrow sees a body, by the rule the host gave or the field's.
func sees(sc: Dictionary, pos: Vector2, hidden: bool) -> bool:
	if seen.is_valid():
		return bool(seen.call(sc, pos, hidden))
	if field != null:
		return field.sees(sc, pos, hidden)
	return false


## Scarecrows seeing somebody: one alarm for each, then not again for
## ALARM_COOLDOWN_S, and never a loss. `list` are scarecrow dictionaries.
func _watch(list: Array, bodies: Array[Dictionary]) -> void:
	for sc in list:
		if float(_cool.get(sc.id, 0.0)) > 0.0:
			continue
		for b in _live(bodies):
			if sees(sc, b.pos, b.get("hidden", false)):
				_cool[sc.id] = ALARM_COOLDOWN_S
				alarm(ALARM_S, String(sc.id))
				break


## The row of a game's LEVELS for level `lv` (the last one past the end), to
## be worked on: a copy.
static func level_row(levels: Array, lv: int) -> Dictionary:
	return (levels[clampi(lv, 1, levels.size()) - 1] as Dictionary).duplicate(true)


func _shuffle(list: Array) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rng.below(i + 1)
		var t = list[i]
		list[i] = list[j]
		list[j] = t


## How far a wandering thing goes at a time, in steps.
const WANDER_MIN := 3
const WANDER_MAX := 6


## Something that wanders (a sock, a pin): {pos, tile, path, move (tiles a
## second)}. On to a place a few steps off, over floor, keeping to the side
## of the shut doors (ids) it is on.
func _wander(e: Dictionary, dt: float, shut_ids: Array = []) -> void:
	var way: Array[Vector2i] = e.path
	if way.is_empty():
		var near := field.candidates(e.tile, [], WANDER_MIN, WANDER_MAX, {"shut": shut_ids})
		if near.is_empty():
			return
		var to: Vector2i = near[rng.below(near.size())].tile
		way = field.path(e.tile, to, shut_ids)
		e.path = way
	var step_len: float = e.move * dt
	while step_len > 0.0 and not way.is_empty():
		var goal_pos := DojoField.center(way[0])
		var gap: float = (e.pos as Vector2).distance_to(goal_pos)
		if gap <= step_len:
			e.pos = goal_pos
			e.tile = way[0]
			way.remove_at(0)
			step_len -= gap
		else:
			e.pos = (e.pos as Vector2).move_toward(goal_pos, step_len)
			step_len = 0.0
	e.path = way
