class_name Hearing
extends RefCounted
## Sound: how loud things are, and what a guard makes of them. Port of the web
## version's sound.ts.

## How far a noise carries, in tiles, before walls are taken into account.
## Standing still makes none: staying put is the whole point of hiding.
## Things falling over: they carry through walls better (see heard_at).
const CRASHES := ["bin", "bust", "panel", "armour", "roll_bump", "tumble"]

## How far each kind of noise carries, in tiles (a table of data, kept in
## SoundEvent so that it does not need Hearing to make a sound).
const LOUDNESS := SoundEvent.LOUDNESS

## Walking slowly on purpose (Sim.SLOW_SPEED) you place your feet: a step
## carries this share of what the same speed would. Quiet, never silent.
const SLOW_HUSH := 0.5

## A wall between you and a guard eats this much of a noise's reach.
const WALL_DAMPING := 2.6
## How far a noise carries to a guard, relative to its nominal reach.
const HEARING_CALM := 0.75
const HEARING_ALERT := 1.25


## Reach of a footstep at a given speed: creeping is nearly silent.
static func step_loudness(speed: float, top_speed: float) -> float:
	var t := clampf(speed / top_speed, 0.0, 1.0)
	return 2.6 + t * t * 7.4


## How far a collision carries: a case rattles far louder than a wall thuds,
## and both scale with the square of the speed you hit them at.
static func crash_loudness(speed: float, top_speed: float, shelf: bool) -> float:
	var t := clampf(speed / top_speed, 0.0, 1.0)
	return float(LOUDNESS["shelf" if shelf else "bump"]) * (0.15 + 0.85 * t * t)


## What the guard's state does to how far it hears: HEARING_ALERT on alert,
## HEARING_CALM otherwise (heard_at and the dev overlay read it from here).
static func state_factor(g: Guard) -> float:
	return HEARING_ALERT if g.alert else HEARING_CALM


## Where a guard thinks a noise came from, or null if it does not reach. Faint
## noises are mislocated: the guard goes roughly the right way. ear is the
## night's hearing dial (Sim.tuning("hearing")), given by the caller.
static func heard_at(g: Guard, noise: SoundEvent, ear: float) -> Variant:
	var d := Museum.dist(g.x, g.y, noise.x, noise.y)
	# A guard on alert is listening for you; a calm one is half asleep.
	# A crash (something knocked over) is a deep, carrying sound: walls take
	# half as much off it as off footsteps.
	var damping := WALL_DAMPING * (0.5 if noise.kind in CRASHES else 1.0)
	var reach := noise.loudness * state_factor(g) * ear \
		- damping * Museum.muffle_between(g.x, g.y, noise.x, noise.y)
	if reach <= 0 or d > reach:
		return null
	# 0 at the guard's feet, 1 at the edge of hearing.
	var faintness := d / reach
	var spread := faintness * faintness * 3.5
	var angle := randf() * TAU
	return Vector2(noise.x + cos(angle) * spread, noise.y + sin(angle) * spread)


## The noise a thief made this frame, if any. prev_x/prev_y is where it stood
## before the step.
static func thief_noise(prev_x: float, prev_y: float, after: Thief, entered_cover: bool, bumped: String, top_speed: float) -> SoundEvent:
	# A ball into a wall is a thump, low as it is.
	if bumped == "roll":
		return SoundEvent.make(after.x, after.y, "roll_bump")
	# On all fours you place every step: no footfalls, no knocks, nothing;
	# a roll is as quiet, and so is lying down after it.
	if after.crouched or after.rolling or after.dizzy > 0.0:
		return null
	# Running into something is loud even though it moved you nowhere.
	if bumped != "":
		return SoundEvent.make(after.x, after.y, "shelf" if bumped == "shelf" else "bump", crash_loudness(after.speed, top_speed, bumped == "shelf"))
	if Museum.dist(prev_x, prev_y, after.x, after.y) <= 0.001:
		return null
	if entered_cover and after.sprinting:
		return SoundEvent.make(after.x, after.y, "rustle")
	# Loudness follows the actual speed, so winding up is audibly riskier.
	var loud := step_loudness(after.speed, top_speed) * (SLOW_HUSH if after.slow else 1.0)
	return SoundEvent.make(after.x, after.y, "sprint" if after.sprinting else "walk", loud)
