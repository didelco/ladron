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
