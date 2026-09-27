class_name SqueezeGame
extends Minigame
## Getting into a hideout (Hideouts): the thief wriggles in, left, right,
## left, right, sinking a little deeper with each wriggle. Each one counts
## only once the body has settled from the last (SETTLE_S): mashing gets you
## nowhere faster, and a wriggle too soon, or to the same side twice, gets
## you stuck a moment. It cannot be failed, only done slowly: from about two
## seconds calm and loose to about five in a tight fit with the guards
## alarmed — and all that time you are out there to be seen.
##
## steps_ is how tight the fit is: 1 for one more wriggle (Hideouts.TIGHT).

## Wriggles it takes to get in, by level, before the fit.
const WRIGGLES_LEVEL := [7, 8, 9]
## After a wriggle, the body settles this long before the next one counts,
## and at full tremble this much longer.
const SETTLE_S := 0.32
const SHAKE_SETTLE := 0.06
## Too soon, or the same side twice: stuck this long.
const STUCK_S := 0.35
## Left and right, as DIRS has them.
const LEFT := 3
const RIGHT := 1

## The side the next wriggle must go (LEFT or RIGHT), or -1 for either (the
## first), and the seconds until the body has settled.
var side := -1
var settle := 0.0


func _setup(steps_: int) -> void:
	steps = WRIGGLES_LEVEL[level] + clampi(steps_, 0, 1)


## The next wriggle would count now.
func ready() -> bool:
	return settle <= 0.0 and lock <= 0.0 and not done


func _play(_input: Dictionary, press: Dictionary, dt: float) -> String:
	settle = maxf(0.0, settle - dt)
	var dir := pressed_dir(press)
	if dir != LEFT and dir != RIGHT:
		return ""
	if lock > 0.0:
		return ""
	if settle > 0.0 or (side >= 0 and dir != side):
		lock = STUCK_S
		events.append("slip")
		return ""
	step += 1
	events.append("pin")
	side = LEFT if dir == RIGHT else RIGHT
	settle = SETTLE_S + SHAKE_SETTLE * tremble
	return "done" if step >= steps else ""
