class_name Energy
extends RefCounted
## A thief's wind. Running is faster than any guard on the chase, so it costs:
## flat out it drains ENERGY (0 to 1, Thief.energy); down to TIRED_BELOW the
## top speed is the run of old (Sim.TOP_SPEED), under that it falls away
## smoothly to EXHAUSTED_SPEED, which a guard hot on its heels (about 4.3
## tiles a second, Sim.pace_of) outpaces. So one guard can be left behind,
## but not a string of them. A roll takes a good part of the bar at once
## (ROLL_COST) and cannot be done without that much.
##
## Whenever it is not being spent (not running, not rolling: walking, crawling,
## standing, hiding, in a minigame, stunned) the bar fills, and the emptier it
## is the slower: REGEN_K * energy + REGEN_MIN a second, the minimum so that
## it is never 0 and an empty bar does fill.
##
## Not every night tires you (Sim.tiring): not the first museum, not on easy,
## not at home. Then none of this applies.

## Per second of running above Sim.RUN_THRESHOLD. About 7 s from full to
## where tiredness starts, 10 s to the floor of the run.
const RUN_DRAIN := 0.09
## Above this, the whole of the run; below it, less and less of it.
const TIRED_BELOW := 0.4
## What the run comes down to with nothing left: a jog (a creep up to
## Sim.RUN_THRESHOLD is not running, so it costs nothing more).
const EXHAUSTED_SPEED := 3.2
## A roll's price, out of 1 (a third), and what it takes to start one.
const ROLL_COST := 0.34
## Filling up: REGEN_K * energy + REGEN_MIN a second. From empty it takes
## ~3 s to get anywhere, ~10 s to be full; from half, ~2.4 s to be full.
const REGEN_K := 0.25
const REGEN_MIN := 0.025
## How long the bar flashes at the key of a roll it cannot pay for.
const REFUSED_FLASH := 0.7


## Does this night tire the thieves at all?
static func active() -> bool:
	return Sim.tiring()


## The fastest it can run now: the full TOP_SPEED with wind to spare, less as
## it runs out (continuous, down to EXHAUSTED_SPEED).
static func top_speed(p: Thief) -> float:
	if not active():
		return Sim.TOP_SPEED
	return lerpf(EXHAUSTED_SPEED, Sim.TOP_SPEED, clampf(p.energy / TIRED_BELOW, 0.0, 1.0))


## Tired enough for the bar to show it (and turn red).
static func tired(p: Thief) -> bool:
	return active() and p.energy < TIRED_BELOW


## Enough to roll? (Always, on a night that does not tire.)
static func can_roll(p: Thief) -> bool:
	return not active() or p.energy >= ROLL_COST


## What a roll costs, as it starts.
static func pay_roll(p: Thief) -> void:
	if active():
		p.energy = maxf(0.0, p.energy - ROLL_COST)


## How fast the bar fills at this level.
static func regen_rate(energy: float) -> float:
	return REGEN_K * energy + REGEN_MIN


## One frame after the thief's move (Sim.step_thief): running drains,
## everything else but a roll in the air fills. Counts down the flash of a
## refused roll.
static func tick(p: Thief, dt: float) -> void:
	p.energy_flash = maxf(0.0, p.energy_flash - dt)
	if not active():
		p.energy = 1.0
		return
	if p.rolling:
		return
	if p.sprinting and p.moving:
		p.energy = maxf(0.0, p.energy - RUN_DRAIN * dt)
	else:
		p.energy = minf(1.0, p.energy + regen_rate(p.energy) * dt)
