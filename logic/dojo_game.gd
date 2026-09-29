class_name DojoGame
extends DojoTrial
## What the dojo's games (PILLA EL CALCETÍN, EQUILIBRIO, BOLOS, AGUANTA ESCONDIDO)
## share on top of any trial (DojoTrial): rounds each harder than the last, lost at
## the first failure. It is played at one of three difficulties (DojoTrials.TIERS:
## easy, medium, hard), each a stretch of the ten levels: it begins at the first
## level of the stretch and is won by doing the last. Nothing here is won for the
## story: no guards, no stars, no progress but the best level kept for each stretch
## and size of band (DojoTrials.record).
##
## The flow, on top of the trial's:
##   playing  a level, until it is done or lost
##   between  BETWEEN_S seconds before the next level
## `level` is the level being played (or, once lost, failed; once won, the last
## one done); `got` the levels done, out of `goal`.
##
## Events besides the trial's: {"e": "level", level, got}, {"e": "clear", level,
## got}, {"e": "alarm", by, seconds}; and "lost" and "won" carry `level` and `got`.

const BETWEEN_S := 1.0
## A scarecrow that sees a thief takes this long off the clock, and the dojo
## goes red for ALERT_RED_S; the same scarecrow does not do it again for
## ALARM_COOLDOWN_S.
const ALARM_S := 2.0
const ALERT_RED_S := 3.0
const ALARM_COOLDOWN_S := 3.0

var level := 0
var got := 0
## the stretch of levels played (DojoTrials.TIERS): first and last level
var first := 1
var last := 10
## how many levels the stretch has
var goal := 10
## red alarm left, in seconds (the dojo's lights)
var alert_left := 0.0
## who did what: id -> how many (things caught, pins knocked, ...)
var credits := {}

var _between_left := 0.0
var _cool := {}


func _setup() -> void:
	first = int(DojoTrials.TIERS[tier].from)
	last = int(DojoTrials.TIERS[tier].to)
	goal = last - first + 1


func start() -> void:
	level = first
	got = 0
	alert_left = 0.0
	credits = {}
	_cool = {}
	super.start()
	_events.back().merge({"level": level})


func _tick_common(dt: float) -> void:
	alert_left = maxf(0.0, alert_left - dt)
	for k in _cool.keys():
		_cool[k] = maxf(0.0, float(_cool[k]) - dt)


func _begin_play() -> void:
	super._begin_play()
	_begin_level()


func _other(dt: float) -> void:
	if state == "between":
		_between_left -= dt
		if _between_left <= 0.0:
			state = "playing"
			_tick_key = -1
			_begin_level()


func record_kind() -> String:
	return "level"


## The level reached (the one being played, failed or, once won, the last done).
func score() -> float:
	return float(level)


func progress_text() -> String:
	return Text.t("HIDEOUT_TRIAL_LEVEL_COUNT") % [level, got, goal]


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


func lost_title() -> String:
	return Text.t("HIDEOUT_GAME_LOST_" + id.to_upper())


func view() -> Dictionary:
	var v := super.view()
	v.merge({"level": level, "got": got, "goal": goal, "reached": level, "alert": clampf(alert_left / ALERT_RED_S, 0.0, 1.0),
		"mvp": mvp(), "mvp_name": mvp_name()}, true)
	return v


# --- For each game to say ---------------------------------------------------------------------

## Set up the level being begun (`level`).
func _begin_level() -> void:
	pass


## Take seconds off what the level has left (alarm).
func _penalize(_seconds: float) -> void:
	pass


# --- For them to use ---------------------------------------------------------------------------

func _credit(who: int, n := 1) -> void:
	credits[who] = int(credits.get(who, 0)) + n


## The level is done: on to the next (after BETWEEN_S), or, the stretch's last, won.
func _clear_level() -> void:
	got += 1
	_emit({"e": "clear", "level": level, "got": got})
	if level >= last:
		state = "won"
		_emit({"e": "won", "level": level, "got": got, "score": score()})
		return
	level += 1
	state = "between"
	_between_left = BETWEEN_S
	_emit({"e": "level", "level": level, "got": got})


## The game is lost; `more` is what the event "lost" carries besides its own
## (who, which pin).
func _lose(why: String, more := {}) -> void:
	var m := {"level": level, "got": got}
	m.merge(more)
	super._lose(why, m)


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
