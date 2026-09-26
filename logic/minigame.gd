class_name Minigame
extends RefCounted
## A job done with the hands, in a little box by the thief (MinigameBox), as
## in Among Us: the world goes on meanwhile, so the longer it takes, the
## longer you stand there to be seen. These are the action kind: they cannot
## be failed, only done slowly — a miss costs a moment, never the job.
##
##   "lockpick" (the case): a dial on the lock, a needle going round it and
##     a green sector on its rim; press the action key as the needle crosses
##     the green to set a pin, one pin after another, the green somewhere
##     else each time. A miss slips the pick, and it settles again.
##   "wires" (the alarm panel): a row of wires, three to six by the level;
##     over the next one to cut, an arrow shows which way to pull the
##     cutters: press that direction. The wrong way sparks, and the hands
##     jump off it a moment.
##   "steady" (the case, on some nights instead of the pick): a suction cup
##     on the glass drifts about on its own; the directions push it back.
##     Kept inside the ring for `need` seconds in a row, the glass is cut;
##     out of the ring, the count starts again.
##
## And one of the enduring kind, which can be failed:
##   "balance" (posing as a statue on a pedestal, Plinths): on one foot,
##     the thief sways and tips; left and right keep it up. Over it goes
##     past the point of no return: it falls off, and that is a noise. It
##     never ends by itself: it lasts while the pose does, a little harder
##     by the second (very slowly: nobody stands on one foot for ever), and
##     on top of that harder the closer the guards come (and a little with
##     the lights on: pressure, 0..1).
##     Short taps steady it: held down, a key pushes harder and harder, and
##     over it goes the other way. Leaning far (WOBBLE), it sweats and
##     wobbles, and a guard looking sees it is no statue.
##
## Each comes in three levels (level: 0 easy .. 2 hard, level_now()): more
## wires, a smaller ring for the cup and a stronger drift, a balance that
## tips sooner and tires a little faster.
##
## Frightened hands shake (tremble, 0..1, from how alarmed the guards are):
## the pick jitters and the sweet spot narrows, the cutters take longer to
## steady on the next wire. Driven by a few keys or a pad: the directions,
## the action key, and the roll key (B) to let go; for the pick, which needs
## no directions, a direction steps away too.

## Seconds for the needle to go once round the dial.
const PIN_PERIOD := 1.0
## Half the width of the green sector, as a share of the way round, steady;
## at full tremble it is SHAKE_NARROW narrower.
const PIN_BAND := 0.1
const SHAKE_NARROW := 0.4
## How far the needle jitters at full tremble, as a share of the way round.
const SHAKE_JITTER := 0.04
## A miss: the pick slips off, and the hands answer again after this long.
const SLIP_S := 0.45
## Each near miss on the same pin loosens it: its sweet spot this much wider
## (a share of PIN_BAND), so whoever keeps at it always gets there.
const GIVE := 0.45
## The wrong way on a wire: a spark, and the hands off it this long.
const SPARK_S := 0.6
## At full tremble, how long the cutters take to steady on the next wire.
const STEADY_S := 0.3
## How many wires a panel has, by level.
const WIRES_LEVEL := [3, 4, 6]
## Directions, as the wires show them: up, right, down, left.
const DIRS := ["up", "right", "down", "left"]

## The suction cup: its radius (the easy ring's is 1), how hard it drifts,
## how hard the keys push it and how quickly it slows.
const CUP := 0.26
const DRIFT := 2.4
## By level (easy, medium, hard): the ring's size and the drift's strength.
const RING_LEVEL := [1.0, 0.84, 0.7]
const DRIFT_LEVEL := [0.8, 1.0, 1.15]
const PUSH := 4.2
const DAMP := 2.6
## How often the drift changes its mind, in seconds.
const GUST_S := 0.45

## On one foot: how fast a lean grows by itself (more under pressure), how
## hard left and right push back, how quickly the sway slows, and the
## nudges that come from nowhere.
const TOPPLE := 2.2
const LEAN_DAMP := 1.6
## Left and right: a tap gives a little kick; held, the push grows
## exponentially with how long (doubling every HOLD_DOUBLE seconds, up to
## PUSH_MAX), so a long press throws it over the other way.
const TAP_KICK := 0.35
const PUSH_BASE := 2.0
const HOLD_DOUBLE := 0.18
const PUSH_MAX := 30.0
const NUDGE := 0.9
const NUDGE_S := 0.7
## By level: how quickly it tips over, and how much harder it gets with
## every second on one foot (a share of what it was at the start: 0.015 is
## 1.9 times as hard after a minute).
const TOPPLE_LEVEL := [0.8, 1.0, 1.2]
const TIRE_LEVEL := [0.01, 0.015, 0.02]
## At full pressure (the guards on top of it), how much harder it tips and
## how much harder the nudges come, as a share of what they are when calm.
const PRESSURE_TOPPLE := 1.2
const PRESSURE_NUDGE := 1.5
## Leaning this far it falls off (the lean is in the figure's units: 1 is
## Figure.MAX_LEAN radians over).
const FALL := 1.6
## Leaning this far, the statue wobbles for all to see: a big drop of
## sweat, and to a guard looking it is no statue (wobbling()).
const WOBBLE := 0.6

## "lockpick" or "wires"
var kind := ""
## what it is on: "case", "panel" or "panel2" (Heist)
var what := ""
## 0 easy, 1 medium, 2 hard
var level := 1
## how many pins or wires, and how many done
var steps := 1
var step := 0
## seconds spent at it
var t := 0.0
## seconds until the hands answer again, after a miss
var lock := 0.0
## 0..1: how much the hands shake (set every frame by whoever runs it)
var tremble := 0.0
## held off by someone else's part (the panel not yet cut, a second lock
## with nobody at it): the box shows why and nothing answers
var blocked := ""
var done := false
## what happened this frame, for the sounds: "pin", "slip", "snip", "spark",
## "done"
var events: Array[String] = []

# The dial: where the needle is (0..1 of the way round, from the top,
# clockwise), the middle of the green sector, and how many times it has
# slipped on this pin.
var sweep := 0.0
var spot := 0.5
var misses := 0
# The wires: the way to pull each one (an index into DIRS).
var ways: Array[int] = []
# The suction cup: where it is (the ring has radius 1), how it moves, the
# drift pushing it, and how long it has been in the ring without a break
# out of the `need` seconds it takes.
var cup := Vector2.ZERO
var cup_v := Vector2.ZERO
var drift := Vector2.ZERO
var _drift_to := Vector2.ZERO
var _gust_in := 0.0
var held := 0.0
var need := 2.0
# On one foot: the lean (negative over to the left, positive to the right,
# and over it goes past FALL either way), how fast it is leaning, and the pressure.
var lean := 0.0
var lean_v := 0.0
var pressure := 0.0
var _nudge := 0.0
## how long the key pushing it has been held, in seconds, and which way
var _hold := 0.0
var _hold_dir := 0

var _rng := RandomNumberGenerator.new()
## the keys as they were last frame, so only presses count
var _was := {}


## A new one, primed with the keys as they are now: whatever is already held
## (the action key that opened it, a direction still down) is not a press.
static func make(kind_: String, what_: String, steps_: int, input: Dictionary, seed_: int = 0, level_ := -1) -> Minigame:
	var g := Minigame.new()
	g.kind = kind_
	g.what = what_
	g.level = level_now() if level_ < 0 else clampi(level_, 0, 2)
	g.steps = maxi(1, steps_)
	g._rng.seed = seed_ if seed_ != 0 else randi()
	g._was = input.duplicate()
	match kind_:
		"lockpick":
			g._new_pin()
		"wires":
			# As many as the level says, each its own way to pull.
			g.steps = WIRES_LEVEL[g.level]
			for i in g.steps:
				g.ways.append(g._rng.randi() % DIRS.size())
		"steady":
			# steps are the lamps that light as the seconds go by.
			g.need = maxf(1.0, steps_ * 0.5)
		"balance":
			# A little off true from the start: it needs minding at once.
			g.lean = g._rng.randf_range(-0.12, 0.12)
	return g


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
## night's difficulty already in it) has: two for the easiest, six at most.
static func pins_for(seconds: float) -> int:
	return clampi(roundi(seconds * 1.2), 2, 6)


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
	if kind == "steady":
		return clampf(held / need, 0.0, 1.0)
	return float(step) / steps


## The ring's radius at this level (the easy one's is 1).
func ring() -> float:
	return RING_LEVEL[level]


## The cup is inside the ring, all of it.
func inside() -> bool:
	return cup.length() <= ring() - CUP


## The needle, 0..1 of the way round the dial from the top, clockwise,
## with the shake on top.
func tip() -> float:
	var jitter := SHAKE_JITTER * tremble * sin(t * 31.0) * sin(t * 17.0 + 1.0)
	return fposmod(sweep + jitter, 1.0)


## How far the needle is from the middle of the green, the short way round.
func off() -> float:
	var d := absf(tip() - spot)
	return minf(d, 1.0 - d)


## Half the width of the sweet spot now: narrower the more the hands shake,
## wider the more times the pick has slipped on this pin.
func band() -> float:
	return PIN_BAND * (1.0 - SHAKE_NARROW * tremble + GIVE * misses)


## The next wire's way, or -1 while the cutters steady (or it is all done).
func way() -> int:
	if done or step >= ways.size() or lock > 0.0:
		return -1
	return ways[step]


## One frame. Returns "quit" when the thief lets go (the roll key; for the
## pick, a direction too), "done" the frame it is finished, "fail" the frame
## it falls (balance), else "".
func tick(input: Dictionary, dt: float) -> String:
	events.clear()
	var pressed := func(k: String) -> bool:
		return input.get(k, false) and not _was.get(k, false)
	var quit: bool = pressed.call("cancel")
	if kind == "lockpick":
		for d in DIRS:
			quit = quit or pressed.call(d)
	var act: bool = pressed.call("action")
	var dir := -1
	for i in DIRS.size():
		if pressed.call(DIRS[i]):
			dir = i
	_was = input.duplicate()
	if quit:
		return "quit"
	if done or blocked != "":
		return ""
	t += dt
	lock = maxf(0.0, lock - dt)
	if kind == "steady":
		return _tick_steady(input, dt)
	if kind == "balance":
		return _tick_balance(input, dt)
	if kind == "lockpick":
		# The needle keeps going round, even while the pick settles.
		sweep = fmod(sweep + dt / PIN_PERIOD, 1.0)
		if act and lock <= 0.0:
			if off() <= band():
				step += 1
				events.append("pin")
				if step < steps:
					_new_pin()
			else:
				lock = SLIP_S
				# Only a near miss loosens the pin: mashing the key does not.
				if off() <= band() * 3.0:
					misses += 1
				events.append("slip")
	elif dir >= 0 and lock <= 0.0:
		if dir == ways[step]:
			step += 1
			events.append("snip")
			lock = STEADY_S * tremble
		else:
			lock = SPARK_S
			events.append("spark")
	if step >= steps:
		done = true
		events.append("done")
		return "done"
	return ""


## The keys held, as a push: right and down are positive.
static func _push(input: Dictionary) -> Vector2:
	return Vector2(float(input.get("right", false)) - float(input.get("left", false)),
		float(input.get("down", false)) - float(input.get("up", false)))


func _tick_steady(input: Dictionary, dt: float) -> String:
	# The drift wanders: a new heading every so often, eased into; shaking
	# hands make it wilder.
	_gust_in -= dt
	if _gust_in <= 0.0:
		_gust_in = GUST_S * _rng.randf_range(0.6, 1.4)
		_drift_to = Vector2.from_angle(_rng.randf() * TAU) * DRIFT * DRIFT_LEVEL[level] * _rng.randf_range(0.5, 1.0) * (1.0 + 0.7 * tremble)
	drift = drift.lerp(_drift_to, minf(1.0, dt * 4.0))
	cup_v += (drift + _push(input) * PUSH) * dt
	cup_v -= cup_v * minf(1.0, DAMP * dt)
	cup += cup_v * dt
	# It can stray a little past the ring, not off the glass.
	if cup.length() > 1.4:
		cup = cup.normalized() * 1.4
		cup_v = Vector2.ZERO
	var was_in := held > 0.0
	if inside():
		held += dt
		var lamps := int(held / need * steps)
		if lamps > step:
			events.append("pin")
		step = mini(lamps, steps)
	else:
		held = 0.0
		step = 0
		if was_in:
			events.append("slip")
	if held >= need:
		done = true
		step = steps
		events.append("done")
		return "done"
	return ""


func _tick_balance(input: Dictionary, dt: float) -> String:
	_nudge -= dt
	if _nudge <= 0.0:
		_nudge = NUDGE_S * _rng.randf_range(0.5, 1.5)
		# A nudge: a jolt to the sway, bigger under pressure.
		lean_v += _rng.randf_range(-1.0, 1.0) * NUDGE * (1.0 + PRESSURE_NUDGE * pressure) * tired()
	# The push: a kick on the tap, then harder the longer it is held.
	var dir := int(_push(input).x)
	if dir != _hold_dir:
		_hold = 0.0
		_hold_dir = dir
		lean_v += dir * TAP_KICK
	elif dir != 0:
		_hold += dt
	var push := dir * minf(PUSH_BASE * pow(2.0, _hold / HOLD_DOUBLE), PUSH_MAX)
	var accel: float = lean * TOPPLE * TOPPLE_LEVEL[level] * (1.0 + PRESSURE_TOPPLE * pressure) * tired() + push
	lean_v += accel * dt
	lean_v -= lean_v * minf(1.0, LEAN_DAMP * dt)
	lean += lean_v * dt
	if absf(lean) >= FALL:
		lean = signf(lean) * FALL
		events.append("fall")
		return "fail"
	return ""


## On one foot and leaning far over: statues do not wobble, so a guard
## looking now sees through the pose (Sim.can_see).
func wobbling() -> bool:
	return kind == "balance" and not done and absf(lean) >= WOBBLE


## How tired the leg is, as a factor on the tipping and the nudges: 1 at
## the start, growing very slowly by the second.
func tired() -> float:
	return 1.0 + t * TIRE_LEVEL[level]


## The next pin: the green somewhere else round the dial, never just ahead
## of the needle (it must come round to it).
func _new_pin() -> void:
	misses = 0
	spot = fposmod(sweep + _rng.randf_range(0.3, 0.85), 1.0)
