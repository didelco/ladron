class_name BalanceGame
extends Minigame
## Posing as a statue on a pedestal (Plinths): on one foot, the thief sways
## and tips; left and right keep it up. Over it goes past the point of no
## return: it falls off, and that is a noise ("fail"). It never ends by
## itself: it lasts while the pose does, a little harder by the second (very
## slowly: nobody stands on one foot for ever), and on top of that harder the
## closer the guards come (and a little with the lights on: pressure, 0..1).
## Short taps steady it: held down, a key pushes harder and harder, and over
## it goes the other way. Leaning far (WOBBLE), it sweats and wobbles, and a
## guard looking sees it is no statue. Harder levels tip sooner and tire a
## little faster.

## How fast a lean grows by itself (more under pressure), how quickly the
## sway slows, and the nudges that come from nowhere.
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

## The lean (negative over to the left, positive to the right, and over it
## goes past FALL either way) and how fast it is leaning.
var lean := 0.0
var lean_v := 0.0
var _nudge := 0.0
## how long the key pushing it has been held, in seconds, and which way
var _hold := 0.0
var _hold_dir := 0


func _setup(_steps: int) -> void:
	# A little off true from the start: it needs minding at once.
	lean = _rng.randf_range(-0.12, 0.12)


## On one foot and leaning far over: statues do not wobble.
func wobbling() -> bool:
	return not done and absf(lean) >= WOBBLE


## How tired the leg is, as a factor on the tipping and the nudges: 1 at
## the start, growing very slowly by the second.
func tired() -> float:
	return 1.0 + t * TIRE_LEVEL[level]


func _play(input: Dictionary, _press: Dictionary, dt: float) -> String:
	_nudge -= dt
	if _nudge <= 0.0:
		_nudge = NUDGE_S * _rng.randf_range(0.5, 1.5)
		# A nudge: a jolt to the sway, bigger under pressure.
		lean_v += _rng.randf_range(-1.0, 1.0) * NUDGE * (1.0 + PRESSURE_NUDGE * pressure) * tired()
	# The push: a kick on the tap, then harder the longer it is held.
	var dir := int(push_of(input).x)
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
