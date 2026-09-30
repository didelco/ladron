class_name DojoTrial
extends RefCounted
## What every trial of the dojo shares (DojoTrials is the list of them): the four
## games (DojoGame: PILLA EL CALCETÍN, EQUILIBRIO, BOLOS, AGUANTA ESCONDIDO), the
## four tests of the bench (BenchTrial: GANZÚA, ESCONDITE, CABLES, PULSO) and the
## stealth CIRCUITO (CircuitTrial). One life cycle, one HUD, one end, one record:
##
##   idle     not begun (start() begins)
##   ready    "¿LISTOS?", READY_S seconds
##   playing  the trial itself (each kind its own `_play`)
##   (between a game's levels, DojoGame)
##   won      passed
##   lost     failed (`lost_why` says why)
## abort() leaves it from wherever, and nothing is kept. At the end the host
## (HouseRun) has DojoTrials.settle keep the record and opens the panel (TrialView,
## whose choices are TrialMenu's): SEGUIR (the next difficulty), OTRA VEZ, SALIR.
##
## A trial is played at one of three difficulties (DojoTrials.TIERS: easy, medium,
## hard), by a band of `players` thieves, and keeps ONE record for each (difficulty,
## band size): the best `score()` of the kind `record_kind()` says, "level" (more
## is better: the games) or "time" (less is better: the tests and the circuit).
##
## Pure logic, no nodes. The host calls step(dt, bodies) every frame with the
## band's bodies and plays what comes back:
##   {id: int (whoever it is), pos: Vector2 (tiles), rolling: bool, hidden: bool
##    (in a hideout; for "pedestal", up on a pedestal), speed: float (tiles/s),
##    out: bool (down, caught, out of play)}, and, for the trials that use them,
##   hold: bool (the action key held, "aguanta"), posing: bool, fell: bool and lean:
##   float (the pedestal's), game: the minigame a thief has in hand (the bench's).
## The events are dictionaries with "e" for what happened, each trial's own, and
## these of all: {"e": "ready"}, {"e": "lost", why, score}, {"e": "won", score},
## {"e": "abort"}.
##
## To make a new one: a script extending this (or DojoGame, for one of rounds) with
## `_play` and `_view`, and a row of DojoTrials.TABLE (README, «Cómo añadir una
## prueba al dojo»). Nothing else needs to know it exists.

const READY_S := 2.0

var id := ""
var players := 1
var state := "idle"
## 0 easy, 1 medium, 2 hard (DojoTrials.TIERS)
var tier := 0
var field: DojoField
var seed_value := 0
var rng: Mulberry32
## where the trial starts (the tile of its start point), and the thief that began
## it (an index of thieves, -1: whoever)
var start_tile := Vector2i.ZERO
var starter := -1
## The rule of sight: Callable(scarecrow: Dictionary, pos: Vector2, hidden: bool)
## -> bool. Invalid: the field's own (DojoField.sees). The host gives Practice's.
var seen := Callable()
## the band's names by body id
var names: Array[String] = []
## the best mark kept for this difficulty and size of band before playing (0: none),
## and whether this run beat it (DojoTrials.settle sets both)
var best := 0.0
var new_record := false
## seconds of play (the clock of the trial)
var time := 0.0
var lost_why := ""

var _events: Array[Dictionary] = []
var _ready_left := 0.0
var _tick_key := -1


func setup(players_: int, seed_: int, field_: DojoField, start_: Vector2i, tier_ := 0) -> void:
	players = clampi(players_, 1, 4)
	seed_value = seed_
	rng = Mulberry32.new(seed_)
	field = field_
	start_tile = start_
	tier = clampi(tier_, 0, DojoTrials.TIERS.size() - 1)
	_setup()


## Begin (or begin again): "¿LISTOS?", then it.
func start() -> void:
	rng = Mulberry32.new(seed_value)
	state = "ready"
	time = 0.0
	lost_why = ""
	new_record = false
	_tick_key = -1
	_ready_left = READY_S
	_reset()
	_emit({"e": "ready"})


## Leave the trial, from wherever, with nothing kept.
func abort() -> void:
	if state == "idle":
		return
	state = "idle"
	_emit({"e": "abort"})
	_reset()


## Whether the trial is on (something to draw, the host to step).
func active() -> bool:
	return state != "idle"


func finished() -> bool:
	return state == "won" or state == "lost"


## Whether it was passed.
func won() -> bool:
	return state == "won"


## One frame. Returns the events of it (and of what was done since the last).
func step(dt: float, bodies: Array[Dictionary]) -> Array[Dictionary]:
	_tick_common(dt)
	match state:
		"ready":
			_ready_left -= dt
			if _ready_left <= 0.0:
				_begin_play()
		"playing":
			time += dt
			_play(dt, bodies)
		_:
			_other(dt)
	var out := _events
	_events = []
	return out


## What the host draws: the same for every trial (`title`, `hud` rows, `timer`,
## the `result` at the end), plus what each adds (`objects` to draw, ...).
func view() -> Dictionary:
	var v := {"id": id, "state": state, "tier": tier, "players": players, "title": title(),
		"best": best, "new_record": new_record, "time": time, "ready": maxf(0.0, _ready_left),
		"why": lost_why, "names": names, "hud": hud_rows(), "kind": record_kind(),
		"timer": {}, "result": result() if finished() else {}}
	v.merge(_view(), true)
	return v


## The name of the trial and its difficulty, the top line of the HUD and of the panel:
## "PILLA EL CALCETÍN  MEDIO".
func title() -> String:
	return "%s  %s" % [Text.t(String(DojoTrials.info(id).get("name", ""))), Text.t(DojoTrials.TIERS[tier].text)]


## The lines under the title in the HUD, the same place and style for every trial:
## how far it is ("NIVEL 4  1/3", "PINES 2/4") and the best mark for this difficulty.
func hud_rows() -> Array[String]:
	var rows: Array[String] = []
	var line := progress_text()
	if line != "":
		rows.append(line)
	rows.append(best_text())
	return rows


## The best mark kept for this difficulty and size of band, in words ("MEJOR NIVEL 5",
## "MEJOR 12.3 s", "MEJOR --").
func best_text() -> String:
	if best <= 0.0:
		return Text.t("HIDEOUT_TRIAL_BEST_NONE")
	return Text.t("HIDEOUT_TRIAL_BEST") % score_text(best)


## The result of a trial that has ended, for the panel: {won, title, line (the why or
## the congratulation), score_line, best_line, new_record, mvp, has_next, tier}.
func result() -> Dictionary:
	var is_won := state == "won"
	var mvp_name := mvp_name()
	return {"won": is_won, "tier": tier, "id": id,
		"title": Text.t("HIDEOUT_TRIAL_WON") if is_won else lost_title(),
		"line": Text.t("HIDEOUT_TRIAL_WON_LINE") if is_won else Text.t("HIDEOUT_TRIAL_WHY_" + lost_why.to_upper()),
		"score_line": Text.t("HIDEOUT_TRIAL_SCORE") % score_text(score()),
		"best_line": Text.t("HIDEOUT_TRIAL_BEST_TIER") % [Text.t(DojoTrials.TIERS[tier].text), band_text(), best_text()] if best > 0.0 else "",
		"new_record": new_record, "mvp": Text.t("HIDEOUT_GAME_MVP") % mvp_name if mvp_name != "" else "",
		"has_next": is_won and tier < DojoTrials.TIERS.size() - 1}


## "1 LADRÓN", "3 LADRONES".
func band_text() -> String:
	return Text.t("HIDEOUT_TRIAL_BAND_ONE" if players == 1 else "HIDEOUT_TRIAL_BAND_MANY") % players


# --- For each trial to say ---------------------------------------------------------------------

## What it keeps a record of: "level" (more is better) or "time" (less is better).
func record_kind() -> String:
	return "level"


## The mark of this run, in the record's units (level reached, seconds).
func score() -> float:
	return 0.0


## A mark in words ("nivel 5", "12.3 s").
func score_text(value: float) -> String:
	if record_kind() == "time":
		return "%.1f s" % value
	return Text.t("HIDEOUT_TRIAL_LEVEL") % int(value)


## How far it is, in words ("" for nothing to say).
func progress_text() -> String:
	return ""


## The title of the panel when it is lost.
func lost_title() -> String:
	return Text.t("HIDEOUT_TRIAL_LOST")


## The band's member with most to their name, or "" (games only).
func mvp_name() -> String:
	return ""


## Configure (setup): what each trial takes from its difficulty.
func _setup() -> void:
	pass


## Forget the round (start, abort).
func _reset() -> void:
	pass


## The playing part begins.
func _begin_play() -> void:
	state = "playing"
	_tick_key = -1


## A frame of play.
func _play(_dt: float, _bodies: Array[Dictionary]) -> void:
	pass


## A frame of any other state (a game's `between`).
func _other(_dt: float) -> void:
	pass


## What every frame does first (timers that run in any state).
func _tick_common(_dt: float) -> void:
	pass


## What each trial adds to the view.
func _view() -> Dictionary:
	return {}


# --- For them to use ---------------------------------------------------------------------------

func _emit(e: Dictionary) -> void:
	_events.append(e)


func _live(bodies: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in bodies:
		if not b.get("out", false):
			out.append(b)
	return out


## The trial is passed.
func _win() -> void:
	if state == "won":
		return
	state = "won"
	_emit({"e": "won", "score": score()})


## The trial is failed; `more` is what the event "lost" carries besides its own
## (who, which pin).
func _lose(why: String, more := {}) -> void:
	if state == "lost":
		return
	state = "lost"
	lost_why = why
	var e := {"e": "lost", "why": why, "score": score()}
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
