class_name SteadyGame
extends Minigame
## The alarm panel's glass (or the case's, on some nights instead of the
## pick): a suction cup on it drifts about on its own; the directions push
## it back. Kept inside the ring for `need` seconds in a row, the glass is
## cut; out of the ring, the count starts again. Harder levels have a
## smaller ring and a stronger drift; shaking hands make the drift wilder.

## The cup's radius (the easy ring's is 1), how hard it drifts, how hard the
## keys push it and how quickly it slows.
const CUP := 0.26
const DRIFT := 2.4
## By level (easy, medium, hard): the ring's size and the drift's strength.
const RING_LEVEL := [1.0, 0.84, 0.7]
const DRIFT_LEVEL := [0.8, 1.0, 1.15]
const PUSH := 4.2
const DAMP := 2.6
## How often the drift changes its mind, in seconds.
const GUST_S := 0.45

## Where the cup is (the ring has radius 1), how it moves, the drift pushing
## it, and how long it has been in the ring without a break out of the
## `need` seconds it takes.
var cup := Vector2.ZERO
var cup_v := Vector2.ZERO
var drift := Vector2.ZERO
var _drift_to := Vector2.ZERO
var _gust_in := 0.0
var held := 0.0
var need := 2.0


func _setup(steps_: int) -> void:
	# steps are the lamps that light as the seconds go by.
	need = maxf(1.0, steps_ * 0.5)


func progress() -> float:
	return clampf(held / need, 0.0, 1.0)


## The ring's radius at this level (the easy one's is 1).
func ring() -> float:
	return RING_LEVEL[level]


## The cup is inside the ring, all of it.
func inside() -> bool:
	return cup.length() <= ring() - CUP


func _play(input: Dictionary, _press: Dictionary, dt: float) -> String:
	# The drift wanders: a new heading every so often, eased into; shaking
	# hands make it wilder.
	_gust_in -= dt
	if _gust_in <= 0.0:
		_gust_in = GUST_S * _rng.randf_range(0.6, 1.4)
		_drift_to = Vector2.from_angle(_rng.randf() * TAU) * DRIFT * DRIFT_LEVEL[level] * _rng.randf_range(0.5, 1.0) * (1.0 + 0.7 * tremble)
	drift = drift.lerp(_drift_to, minf(1.0, dt * 4.0))
	cup_v += (drift + push_of(input) * PUSH) * dt
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
	return "done" if held >= need else ""
