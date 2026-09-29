class_name CircuitTrial
extends DojoTrial
## «CIRCUITO» (circuit): the dojo's stealth bay, walls, crates and scarecrows in a
## guard's coat that sweep their torch to and fro (Practice.scarecrows: the rows of
## DojoTrials.TABLE with `scarecrows`). The trial: from the ring you began at to the
## goal at the far end without a torch finding you, before the clock runs out.
## The scarecrows are there whether or not a trial is on (to practise the sneaking,
## with the dojo going red if one sees you); in a trial being seen is failing
## (lost "seen"). The difficulties (a row of the table) sweep them faster
## (`speed`) and give less time (`limit`). Kept: the time of the pass.
##
## The host gives it the guards (Practice.scarecrows), the clock of their sweep (the
## same one that moves them on the screen, HouseRun.scarecrow_time) and, in a test with no
## plan loaded, a `los`; the bodies carry `low` (see Practice.scarecrow_sees).
##
## Events besides the trial's: {"e": "seen", by}.

const GOAL_R := 0.8

var guards: Array = []
## Callable() -> float: the seconds of the sweep
var clock := Callable()
## optional line-of-sight check for Practice.scarecrow_sees
var los := Callable()

var _goal := Vector2i.ZERO
var _limit := 60.0
var _speed := 1.0


func _setup() -> void:
	var row := DojoTrials.info(id)
	_goal = row.goal
	_limit = float((row.limit as Array)[tier])
	_speed = float((row.speed as Array)[tier])


## How much faster the scarecrows sweep at this difficulty (1: as in the free practice).
func speed() -> float:
	return _speed


func record_kind() -> String:
	return "time"


func score() -> float:
	return time


func progress_text() -> String:
	return Text.t("HIDEOUT_TRIAL_METERS") % _to_goal()


func _to_goal() -> int:
	return int(round(_at.distance_to(DojoField.center(_goal)))) if _at != Vector2.INF else 0


var _at := Vector2.INF


func _play(_dt: float, bodies: Array[Dictionary]) -> void:
	var me := {}
	for b in bodies:
		if int(b.id) == starter:
			me = b
	if me.is_empty() or me.get("out", false):
		_lose("seen")
		return
	_at = me.pos
	if (me.pos as Vector2).distance_to(DojoField.center(_goal)) <= GOAL_R:
		_win()
		return
	var t: float = float(clock.call()) if clock.is_valid() else time * _speed
	for b in _live(bodies):
		for g in guards:
			if Practice.scarecrow_sees(g, b.pos, b.get("hidden", false), b.get("low", false), los, t):
				_emit({"e": "seen", "by": String(g.id)})
				_lose("seen", {"by": int(b.id)})
				return
	if time >= _limit:
		_lose("time")
		return
	_tick(_limit - time)


func _view() -> Dictionary:
	return {"objects": [{"kind": "goal", "pos": DojoField.center(_goal), "ring": -1.0}],
		"timer": {"left": maxf(0.0, _limit - time), "max": _limit, "kind": "limit"}}
