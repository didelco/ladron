class_name SneezeGame
extends Minigame
## Hiding (Hideouts): after a while in there, dust tickles the nose. Tickles
## come along a lane, left to right, on a steady beat, towards the nose;
## press the action key as each one crosses the bar to hold the sneeze in.
## Let one through, or miss too often (MISSES), and out it comes: ACHOO! —
## out of the hideout, and every guard near hears it. It never ends while
## you stay in: the longer you stay and the more alarmed the guards, the
## narrower the bar and the quicker the beat. Easier than the pick: the bar
## starts wide. You leave it by leaving the hideout (any direction), not by
## letting go: that would be hiding for ever.
##
## The lane: x from -1 (where the tickles come from) to 1 (the nose).

## Seconds in the hideout, calm, before the tickling starts, and how long
## the sneeze leaves the thief stunned on the floor.
const CALM_S := 5.0
const STUN_S := 0.8
## Where the bar is along the lane, and half its width: at first, at its
## narrowest (after SHRINK_S in there), and at full tremble this much less.
const BAR_X := 0.45
const BAR := 0.2
const NARROWEST := 0.07
const SHRINK_S := 60.0
const SHAKE_NARROW := 0.35
## How far the bar is by level (0 easy .. 2 hard), as a share of BAR.
const BAR_LEVEL := [1.15, 1.0, 0.85]
## Seconds between tickles, at first and at the quickest (after SHRINK_S).
const BEAT := 1.3
const QUICKEST := 0.75
## How fast a tickle comes along, in lanes a second (one lane is 2).
const SPEED := 1.1
## Too many presses out of time: a sneeze. Each run of CALM_HITS held in a
## row forgives one.
const MISSES := 3
const CALM_HITS := 5
## A miss: the hands answer again after this long.
const SLIP_S := 0.25

## where each tickle on the lane is
var tickles: Array[float] = []
## presses out of time, and tickles held since the last one
var misses := 0
var held := 0
## seconds until the next tickle sets off
var next := 0.6


## Nothing to finish: there is no progress to show.
func progress() -> float:
	return 0.0


## Letting go does nothing: you get out of the hideout to stop.
func can_let_go() -> bool:
	return false


func let_go() -> String:
	return "GAME_LET_GO_SNEEZE"


## How far on it is, 0 at first .. 1 from SHRINK_S on.
func worn() -> float:
	return clampf(t / SHRINK_S, 0.0, 1.0)


## Half the width of the bar now.
func bar() -> float:
	var wide: float = lerpf(BAR, NARROWEST, worn()) * BAR_LEVEL[level]
	return maxf(NARROWEST * 0.7, wide * (1.0 - SHAKE_NARROW * tremble))


## Seconds between tickles now.
func beat() -> float:
	return lerpf(BEAT, QUICKEST, worn())


func _play(_input: Dictionary, press: Dictionary, dt: float) -> String:
	next -= dt
	if next <= 0.0:
		tickles.append(-1.0)
		next += beat()
	for i in tickles.size():
		tickles[i] += SPEED * dt
	# One past the bar: it reaches the nose.
	if not tickles.is_empty() and tickles[0] > BAR_X + bar():
		tickles.pop_front()
		return "fail"
	if press.has("action") and lock <= 0.0:
		if not tickles.is_empty() and absf(tickles[0] - BAR_X) <= bar():
			tickles.pop_front()
			events.append("pin")
			held += 1
			if held >= CALM_HITS and misses > 0:
				misses -= 1
				held = 0
		else:
			misses += 1
			held = 0
			lock = SLIP_S
			events.append("slip")
			if misses >= MISSES:
				return "fail"
	return ""
