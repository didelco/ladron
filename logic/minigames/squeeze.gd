class_name SqueezeGame
extends Minigame
## Getting into a hideout (Hideouts): its colour code (ColourCode). The code
## is shown in order; the same colours sit under it in a row, out of order;
## the directions move a cursor along the row, the action key picks the ball
## under it, and the action key on another ball changes the two of place.
## The row reading as the code, the thief is in. It cannot be failed, only
## done slowly, and all that time you are out there to be seen.
##
## By level (what the ESCONDITE tests of the dojo teach): three balls, one
## swap away; four balls, two swaps away; five balls, three swaps away
## (ColourCode.BALLS_LEVEL, SWAPS_LEVEL); a tight piece (steps_, 1:
## Hideouts.TIGHT) is dealt one swap further. The same puzzle in a heist
## (what "hideout") and at the dojo's bench (what "bench"): only who runs
## it and what it shows round it change.
##
## steps counts the balls, step the ones sitting where the code says.

## The code: the thing itself.
var code: ColourCode
## The slot the cursor is on.
var cursor := 0
## A guard sees the thief: set every frame by whoever runs it (the box shows
## it; it changes nothing of the puzzle).
var watched := false
## How tight the fit is (Hideouts.TIGHT): 0 or 1.
var tight := 0


func _setup(steps_: int) -> void:
	tight = clampi(steps_, 0, 1)
	code = ColourCode.make(ColourCode.balls_for(level), ColourCode.swaps_for(level, tight), _rng)
	steps = code.balls.size()
	step = code.matched()


## How many balls the row has.
func size() -> int:
	return code.balls.size()


## The slot picked for a swap, or -1.
func picked() -> int:
	return code.picked


func progress() -> float:
	return float(code.matched()) / maxi(1, steps)


func _play(_input: Dictionary, press: Dictionary, _dt: float) -> String:
	if press.has("left"):
		cursor = posmod(cursor - 1, size())
	if press.has("right"):
		cursor = posmod(cursor + 1, size())
	if press.has("action"):
		var was := code.picked
		if code.pick(cursor):
			events.append("pin")
		elif code.picked >= 0:
			events.append("pin")
		elif was >= 0:
			events.append("slip")
	step = code.matched()
	return "done" if code.solved() else ""
