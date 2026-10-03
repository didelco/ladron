class_name Roll
extends RefCounted
## Rolling: tucked into a ball, the thief shoots DISTANCE tiles the way it
## faces — most of a gallery — far faster than it can run, and as low as on
## all fours (the guards see it no better than crawling, and it makes no
## footfalls). There is no steering a ball: once off, it goes where it was
## pointed, all the way.
##
## The catch is the landing. A clean roll ends on all fours, catching its
## breath for SETTLE_SECONDS, then it gets up (the last RISE_SECONDS of Sim's
## usual getting up): a little longer on the floor than a crawler. Rolled
## into a wall or a case, it stops dead there with a crash the whole museum
## hears (roll_bump) and lies flat on its back, ninja stars going round its
## head, for DIZZY_SECONDS before getting up: stood up as far as the guards'
## eyes go (Sim.view_posture), with them coming. Whoever carries the piece
## cannot roll at all.
##
## Sim.step_thief drives it: the roll key starts one, on the press.

const DISTANCE := 8.0
## Tiles per second (about 7.3): a third past a run (Sim.TOP_SPEED, 5.4), the
## fastest a thief ever goes, yet slow enough to see the ball tumble rather
## than jump, and to stop at a wall cleanly a frame at a time.
const SPEED := DISTANCE / 1.1
const SECONDS := DISTANCE / SPEED
## A clean roll: on all fours, before getting up even starts.
const SETTLE_SECONDS := 0.8
## Into a wall or a case: stunned, ninja stars going round the head, before
## getting up. Stood up and in full view all that while (Sim.view_posture):
## the price of a crash.
const DIZZY_SECONDS := 2.0
## Then getting up: quicker than from all fours (Sim.CROUCH_SECONDS), but
## the whole spell on the floor is longer (1.8 s clean, 3.0 s after a crash).
const RISE_SECONDS := 1.0


## Carrying the loot sack (Heist.carrier): too bulky to roll.
static func carrying(p: Thief) -> bool:
	return Heist.carrier == p.id


## Can it roll now? On its feet or on all fours, not already rolling or
## down after one, still playing, and not carrying the piece. Getting up (after a roll too) is all you do
## while you do it, as in Sim.step_thief: no rolling out of it.
static func can_start(p: Thief) -> bool:
	return free_to_roll(p) and refusal(p) == ""


## Why a thief fit to roll (free_to_roll) still may not: "sack" (carrying the
## piece) or "tired" (not enough wind, Energy.ROLL_COST), or "" if it may.
static func refusal(p: Thief) -> String:
	if carrying(p):
		return "sack"
	return "" if Energy.can_roll(p) else "tired"


## Everything but the sack and the wind: fit to roll if it could.
static func free_to_roll(p: Thief) -> bool:
	var rising := not p.crouched and p.posture > 0.0
	return not (p.out or p.safe or p.rolling or p.dizzy > 0.0 or rising)


## How to draw it (Figure.set_state): "roll", "dizzy" (on its back, with
## stars) or "" (a clean roll settles on all fours, drawn as a crawl).
static func pose(p: Thief) -> String:
	return "roll" if p.rolling else ("dizzy" if p.dizzy > 0.0 and p.stars else "")


## Off it goes, the way it faces: down low straight away, and down it stays
## until it gets up again (crouched keeps it low and quiet meanwhile).
static func start(p: Thief) -> bool:
	if not can_start(p):
		return false
	Energy.pay_roll(p)
	p.rolling = true
	p.roll_left = DISTANCE
	p.crouched = true
	p.posture = 1.0
	p.speed = SPEED
	p.sprinting = false
	p.blocked = false
	return true


## One frame of rolling or of being down after it. Returns "crash" when the ball hits a
## wall or a case (stopped dead there), "done" when it runs out of roll,
## "up" when the dizziness is over and it starts getting up, "" otherwise.
## move is Sim.move_with_collision and crouch_seconds Sim.CROUCH_SECONDS, given
## by the caller (Sim.step_thief), so that Roll does not need Sim.
static func step(p: Thief, dt: float, move: Callable, crouch_seconds: float) -> String:
	if p.rolling:
		var want := minf(SPEED * dt, p.roll_left)
		var dx := cos(p.dir)
		var dy := sin(p.dir)
		var moved: Array = move.call(p.x, p.y, dx * want, dy * want)
		var nx: float = moved[0]
		var ny: float = moved[1]
		# Slid along a door jamb it goes on; blocked head-on it stops dead.
		var forward := (nx - p.x) * dx + (ny - p.y) * dy
		p.x = nx
		p.y = ny
		p.roll_left -= want
		p.moving = true
		if forward < want * 0.6:
			_land(p, true)
			return "crash"
		if p.roll_left <= 0.0:
			_land(p, false)
			return "done"
		return ""
	if p.dizzy > 0.0:
		p.dizzy = maxf(0.0, p.dizzy - dt)
		if p.dizzy == 0.0:
			p.stars = false
			# Up it gets, the ordinary way (Sim eases the posture back),
			# from far enough down to take RISE_SECONDS.
			p.crouched = false
			p.posture = minf(1.0, RISE_SECONDS / crouch_seconds)
			return "up"
	return ""


## Stopped: on all fours for a moment, or, crashed, flat out and dizzy.
static func _land(p: Thief, crashed: bool) -> void:
	p.rolling = false
	p.roll_left = 0.0
	p.stars = crashed
	p.dizzy = DIZZY_SECONDS if crashed else SETTLE_SECONDS
	p.speed = 0.0
	p.moving = false
