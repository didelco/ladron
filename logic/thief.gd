class_name Thief
extends RefCounted
## A thief on the floor. Moved in place by Sim.step_thief.

## which keys drive this one: "p1" or "p2"
var id := "p1"
var x := 0.0
var y := 0.0
## facing angle in radians, kept from the last direction walked
var dir := 0.0
var moving := false
## no guard can see it right now (filled in by the game loop)
var hidden := false
## tiles per second: builds up while a direction is held
var speed := 0.0
## fast enough to be loud
var sprinting := false
## the slow key held, standing: walking heel to toe, quietly (Sim.SLOW_SPEED)
var slow := false
## pressed against something: a bump fires once, not every frame
var blocked := false
## caught: still drawn, no longer playing
var out := false
## out through the door with the job done, not caught: gone, and safe
var safe := false
## 0 standing, 1 on all fours; eases over Sim.CROUCH_SECONDS
var posture := 0.0
## which way the posture is heading: the crouch key toggles it
var crouched := false
## crouch key held last frame, so holding it toggles once
var crouch_key := false
## curled in a ball and rolling (Roll): no steering, no stopping
var rolling := false
## tiles of the roll still to go
var roll_left := 0.0
## seconds left down after a roll, before getting up (Roll.SETTLE_SECONDS,
## or Roll.DIZZY_SECONDS after a crash)
var dizzy := 0.0
## crashed at the end of the roll: lying on its back seeing stars
var stars := false
## roll key held last frame: one roll per press
var roll_key := false
## up on an empty pedestal, still as a statue (Plinths): which one
var posing := false
var perch := Vector2i(-1, -1)
## a guard saw it climb up (or wobble): that guard knows (Guard.knows)
var pose_blown := false
## inside something (Hideouts): the sarcophagus or a suit of armour
var hiding := false
## which one (Hideouts.Spot), and where it stood before getting in
var hideout: Hideouts.Spot = null
var hide_entry := Vector2.ZERO
## a guard saw it get in: that guard knows (Guard.knows)
var hide_blown := false
## wriggling into one (Minigame "squeeze"): which, and the guards that have
## seen it at it so far
var hide_target: Hideouts.Spot = null
var hide_seen: Array[Guard] = []
## at a job with the hands (Minigame): the lock or the alarm's glass, or
## the balance on a pedestal; it
## stands where it is until done or it lets go
var game: Minigame = null
## playing pong on an arcade machine (Arcades): its tile
var arcade := Vector2i(-1, -1)
