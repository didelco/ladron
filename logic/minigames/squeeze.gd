class_name SqueezeGame
extends Minigame
## Getting into a hideout (Hideouts): one shove with the action key and the
## thief sinks in. Short, and the risk is the guard, not the keys: a shove
## made while a guard looks (watched) gets stuck and sinks slowly, so it pays
## to pick the moment the light has passed. It cannot be failed, only done
## slowly, and all that time you are out there to be seen.
##
## By level (what the ESCONDITE tests of the dojo teach):
##   easy   one shove, and in. Nobody looks.
##   medium one shove, but a lantern sweeps the place: shove between sweeps.
##   hard   two shoves (half in, then all the way), with the lantern's gaps
##          shorter. Pick both moments.
## In a heist the lantern is the real guards (watched, set every frame by
## whoever runs it); in the dojo, where there are none, a lantern of its own
## goes round (LANTERN_S and LIT_LEVEL), so the same lesson is there.
##
## steps_ is how tight the fit is: 1 for a little longer to sink
## (Hideouts.TIGHT).

## Shoves it takes to get in, by level.
const SHOVES_LEVEL := [1, 1, 2]
## Seconds sinking after a shove, by level (two shoves on the hard one, each
## half the way), and this much more for a tight fit, per shove.
const SINK_LEVEL := [0.7, 0.8, 0.5]
const TIGHT_SINK := 0.2
## Shaking hands sink this much longer at full tremble.
const SHAKE_SINK := 0.15
## Shoved while watched: it sinks this many times slower.
const WATCHED_SLOW := 2.0
## The dojo's lantern: seconds for a round, and the share of it that lights
## the place, by level (none on the easy one).
const LANTERN_S := 2.2
const LIT_LEVEL := [0.0, 0.35, 0.4]

## Seconds left of the sink after the last shove, and how long it is in all.
var sink := 0.0
var sink_total := 0.0
## A guard sees the thief: set every frame by whoever runs it, but for the
## dojo, where the game's own lantern says (tick).
var watched := false
## The last shove was made in view (for the box).
var slow := false
## How tight the fit is (Hideouts.TIGHT): 0 or 1.
var tight := 0


func _setup(steps_: int) -> void:
	steps = SHOVES_LEVEL[level]
	tight = clampi(steps_, 0, 1)



## The shove would count now.
func ready() -> bool:
	return sink <= 0.0 and not done


## The lantern is on the place: the dojo's own, or the guards' looking.
func lit() -> bool:
	return watched


## Where the dojo's lantern is, 0..1 of its round: the place is lit for the
## first LIT_LEVEL of it.
func lantern_phase() -> float:
	return fposmod(t / LANTERN_S, 1.0)


func progress() -> float:
	var part := 0.0
	if sink > 0.0 and sink_total > 0.0:
		part = 1.0 - sink / sink_total
	return clampf((step + part) / steps, 0.0, 1.0)


func _play(_input: Dictionary, press: Dictionary, dt: float) -> String:
	if what == "bench":
		watched = LIT_LEVEL[level] > 0.0 and lantern_phase() < LIT_LEVEL[level]
	if sink > 0.0:
		sink = maxf(0.0, sink - dt)
		if sink <= 0.0:
			step += 1
			return "done" if step >= steps else ""
		return ""
	if not press.has("action"):
		return ""
	slow = watched
	sink_total = (SINK_LEVEL[level] + TIGHT_SINK * tight + SHAKE_SINK * tremble) * (WATCHED_SLOW if watched else 1.0)
	sink = sink_total
	events.append("slip" if watched else "pin")
	return ""
