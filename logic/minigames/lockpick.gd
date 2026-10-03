class_name LockpickGame
extends Minigame
## The case: a dial on the lock, a needle going round it and a green sector
## on its rim; press the action key as the needle crosses the green to set a
## pin, one pin after another, the green somewhere else each time. A miss
## slips the pick, and it settles again. Shaking hands make the needle
## jitter and the green narrower. With the case's alarm on (Minigame.alarm)
## each pin is a hook: one miss turns it orange, two red, and red sets the
## alarm off; the next pin is green again. Picked clean, it never rings.

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

## Where the needle is (0..1 of the way round, from the top, clockwise), the
## middle of the green sector, and how many times it has slipped on this pin.
var sweep := 0.0
var spot := 0.5
var misses := 0


func _setup(_steps: int) -> void:
	_new_pin()


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


func _play(_input: Dictionary, press: Dictionary, dt: float) -> String:
	# The needle keeps going round, even while the pick settles.
	sweep = fmod(sweep + dt / PIN_PERIOD, 1.0)
	if press.has("action") and lock <= 0.0:
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
			# Any miss counts towards the alarm, a wild one too.
			_missed_hook()
	return "done" if step >= steps else ""


## The next pin: the green somewhere else round the dial, never just ahead
## of the needle (it must come round to it).
func _new_pin() -> void:
	misses = 0
	_next_hook()
	spot = fposmod(sweep + _rng.randf_range(0.3, 0.85), 1.0)
