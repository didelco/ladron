class_name BenchTrial
extends DojoTrial
## The tests of the dojo's bench (GANZÚA, ESCONDITE, CABLES, PULSO): the same
## Minigame as in a heist (logic/minigames/), at the difficulty of the start point
## the thief began it at, but run as any other trial: "¿LISTOS?", the clock, a
## panel at the end (passed or failed, the time and the best time for that
## difficulty and size of band) and SEGUIR / OTRA VEZ / SALIR.
##
## One attempt for each difficulty (the difficulties are the levels: more pins,
## more wires, a smaller ring, a tighter hideout, see DojoTrials.TABLE), so what it
## keeps is the time of the pass. The minigames cannot be failed, only done slowly,
## so a test is failed by the clock: `limit` seconds (a row of the table) from the
## moment it begins. The thief lets go of it like of any trial, with Tab (or with
## the minigame's own way, B: that leaves without a panel too).
##
## The minigame is the thief's (Thief.game, ticked by the night as in a heist): the
## host makes it (minigame()) at the start, held off (`blocked`) through the
## "¿LISTOS?", frees it on the event "go" and gives it back in the body's `game`;
## this only watches it: done is won, gone is left, and the clock runs out.
##
## Events besides the trial's: {"e": "go"} (the minigame is free) and {"e": "left"}
## (the thief let go of the minigame).

var _limit := 30.0
var _kind := ""
var _steps := 1
var _progress := 0.0


func _setup() -> void:
	var row := DojoTrials.info(id)
	_kind = String(row.get("minigame", ""))
	_limit = float((row.limit as Array)[tier])
	_steps = steps_for(id, tier)


## How many steps a test asks of its minigame at a difficulty (the pins, the
## wriggles the tightness of the piece adds, the lamps).
static func steps_for(trial_id: String, tier_: int) -> int:
	var row := DojoTrials.info(trial_id)
	if row.has("pieces"):
		return int(Hideouts.TIGHT.get((row.pieces as Array)[tier_], 0))
	return int((row.steps as Array)[tier_])


## The minigame of this test for a thief whose keys are `input`, held off until "go".
func minigame(input: Dictionary) -> Minigame:
	var g := Minigame.make(_kind, "bench", _steps, input, 0, tier)
	g.blocked = "ready"
	return g


func record_kind() -> String:
	return "time"


func score() -> float:
	return time


func progress_text() -> String:
	return "%d%%" % int(round(_progress * 100.0))


func _reset() -> void:
	_progress = 0.0


func _begin_play() -> void:
	super._begin_play()
	_emit({"e": "go"})


func _play(_dt: float, bodies: Array[Dictionary]) -> void:
	var g: Minigame = null
	for b in bodies:
		if int(b.id) == starter:
			g = b.get("game")
	if g == null or g.kind != _kind:
		# Let go of it (the minigame's own key): the trial ends there, kept as nothing.
		_emit({"e": "left"})
		abort()
		return
	_progress = g.progress()
	if g.done:
		_progress = 1.0
		_win()
		return
	if time >= _limit:
		_lose("time")
		return
	_tick(_limit - time)


func _view() -> Dictionary:
	return {"objects": [{"kind": "station", "pos": DojoField.center(start_tile), "ring": -1.0}],
		"timer": {"left": maxf(0.0, _limit - time), "max": _limit, "kind": "limit"}, "progress": _progress}
