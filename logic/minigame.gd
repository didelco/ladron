class_name Minigame
extends RefCounted
## A job done with the hands, in a little box by the thief (MinigameBox), as
## in Among Us: the world goes on meanwhile, so the longer it takes, the
## longer you stand there to be seen.
##
## This is what they all share: the keys (only presses count, and what was
## already held when it opened is not a press), the time, the level, how
## much the hands shake, being held off by someone else's part, and letting
## go with the roll key (B) — only that one, so a brush of the stick never
## throws a job away. Each kind is a script of its own in logic/minigames/,
## named as the kind, with its look in scenes/minigame_views/ (MinigameView):
##
##   of the action kind, which cannot be failed, only done slowly:
##     "lockpick" (LockpickGame), "wires" (WiresGame), "steady" (SteadyGame),
##     "squeeze" (SqueezeGame: the dojo bench's colour code, ColourCode);
##   of the enduring kind, which can be failed:
##     "balance" (BalanceGame: posing as a statue on one foot),
##     "sneeze" (SneezeGame: holding in a sneeze while hiding, which never
##     ends while you stay in);
##   and one just for fun, which never ends: "arcade" (ArcadeGame: pong on
##     the arcade machine, Arcades).
##
## A new one: logic/minigames/<kind>.gd extending this (its _setup and
## _play, and progress if it is not counted in steps),
## scenes/minigame_views/<kind>.gd extending MinigameView, a line
## GAME_HOW_<KIND> in locale/texts.csv, and whoever starts it calls
## Minigame.make("<kind>", …). Nothing else needs to know it exists.
##
## Each comes in three levels (level: 0 easy .. 2 hard, level_now()), and
## frightened hands shake (tremble, 0..1, from how alarmed the guards are).

const SCRIPTS := "res://logic/minigames/%s.gd"
## Directions, as the games name them: up, right, down, left.
const DIRS := ["up", "right", "down", "left"]

## the kind: the name of its script in logic/minigames/
var kind := ""
## what it is on: "case", "panel", "panel2" (Heist), "plinth", "hideout"
var what := ""
## 0 easy, 1 medium, 2 hard
var level := 1
## how many pins, wires, lamps or shoves, and how many done
var steps := 1
var step := 0
## seconds spent at it
var t := 0.0
## seconds until the hands answer again, after a miss
var lock := 0.0
## 0..1: how much the hands shake (set every frame by whoever runs it)
var tremble := 0.0
## 0..1: how close the guards are (set every frame by whoever runs it)
var pressure := 0.0
## held off by someone else's part (the panel not yet cut, a second lock
## with nobody at it): the box shows why and nothing answers
var blocked := ""
var done := false
## what happened this frame, for the sounds and the box: "pin", "slip",
## "snip", "spark", "fall", "done"
var events: Array[String] = []

var _rng := RandomNumberGenerator.new()
## the keys as they were last frame, so only presses count
var _was := {}


## A new one, primed with the keys as they are now: whatever is already held
## (the action key that opened it, a direction still down) is not a press.
static func make(kind_: String, what_: String, steps_: int, input: Dictionary, seed_: int = 0, level_ := -1) -> Minigame:
	var g: Minigame = load(SCRIPTS % kind_).new()
	g.kind = kind_
	g.what = what_
	g.level = level_now() if level_ < 0 else clampi(level_, 0, 2)
	g.steps = maxi(1, steps_)
	g._rng.seed = seed_ if seed_ != 0 else randi()
	g._was = input.duplicate()
	g._setup(steps_)
	return g


## There is a minigame of this kind.
static func exists(kind_: String) -> bool:
	return ResourceLoader.exists(SCRIPTS % kind_)


## The seconds the cup must stay in the ring on a lock of this many seconds
## (Heist.loot.seconds), as lamps of half a second each: 2 s to 4 s.
static func lamps_for(seconds: float) -> int:
	return clampi(roundi(seconds * 1.3), 4, 8)


## Tonight's level: the story's night says (Story.tuning's "game_level"),
## else the difficulty picked.
static func level_now() -> int:
	if Sim.custom.has("game_level"):
		return int(Sim.custom.game_level)
	return {"easy": 0, "medium": 1, "hard": 2}.get(Sim.difficulty, 1)


## How many pins a lock of this many seconds (Heist.loot.seconds, the
## night's difficulty already in it) has: one for the first ones, four at
## most. On the story's nights, 3 s and 3.5 s (the pick's first nights)
## are one pin, 4 s two, 5 s three, 6 s and up four.
static func pins_for(seconds: float) -> int:
	return clampi(roundi(seconds - 2.5), 1, 4)


## How much a thief's hands shake with the guards this alarmed (the most
## alarmed one's suspicion, 0..3): steady while nobody suspects a thing.
static func tremble_for(suspicion: int) -> float:
	return [0.0, 0.2, 0.55, 1.0][clampi(suspicion, 0, 3)]


## The keys a minigame reads, from the frame's keys and the thief's scheme
## (Sim.SCHEMES): the four directions, the action key and the roll key.
static func input_from(keys: Dictionary, pad: Dictionary, action: bool) -> Dictionary:
	var held := func(names: Array) -> bool:
		return names.any(func(n): return keys.has(n))
	return {"up": held.call(pad.up), "down": held.call(pad.down), "left": held.call(pad.left),
		"right": held.call(pad.right), "action": action, "cancel": held.call(pad.roll)}


## 0..1 of it done.
func progress() -> float:
	return float(step) / steps


## The key into Text of the line on how to play it, under the box.
func how() -> String:
	return "GAME_HOW_" + kind.to_upper()


## The roll key lets go of it (it does, but for the sneeze: that one is
## left by getting out of the hideout).
func can_let_go() -> bool:
	return true


## The key into Text of the line on how to let go of it, under the box.
func let_go() -> String:
	return "GAME_LET_GO"


## It gives the thief away to a guard looking (Sim.can_see): a statue
## wobbling on one foot.
func wobbling() -> bool:
	return false


## One frame. Returns "quit" when the thief lets go (the roll key), "done"
## the frame it is finished, "fail" the frame it is failed, else "".
func tick(input: Dictionary, dt: float) -> String:
	events.clear()
	var press := {}
	for k in input:
		if input[k] and not _was.get(k, false):
			press[k] = true
	_was = input.duplicate()
	if press.has("cancel") and can_let_go():
		return "quit"
	if done or blocked != "":
		return ""
	t += dt
	lock = maxf(0.0, lock - dt)
	var out := _play(input, press, dt)
	if out == "done":
		done = true
		step = steps
		events.append("done")
	return out


# --- For each kind to fill in --------------------------------------------------

## Set up a new one; steps_ is what whoever started it asked for (steps is
## already that, at least 1).
func _setup(_steps: int) -> void:
	pass


## One frame of play, while it is not done nor held off: input is the keys
## held, press the ones that went down this frame. Returns "done" when it
## is finished, "fail" when it is failed, else "".
func _play(_input: Dictionary, _press: Dictionary, _dt: float) -> String:
	return ""


# --- Helpers ------------------------------------------------------------------

## The direction that went down this frame (an index into DIRS), or -1.
static func pressed_dir(press: Dictionary) -> int:
	var dir := -1
	for i in DIRS.size():
		if press.has(DIRS[i]):
			dir = i
	return dir


## The keys held, as a push: right and down are positive.
static func push_of(input: Dictionary) -> Vector2:
	return Vector2(float(input.get("right", false)) - float(input.get("left", false)),
		float(input.get("down", false)) - float(input.get("up", false)))
