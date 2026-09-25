class_name Guard
extends RefCounted
## A night attendant: where it is, what it knows and what it is doing.
## Moved in place by Sim.step_guard.

## The last place it saw, heard or was told about a thief.
class Memory:
	var x: float
	var y: float
	## seen, noise or called
	var kind: String
	## ms timestamp
	var at: float
	## the area it points at has since been looked over and was empty
	var cleared := false
	## heading of the thief when spotted, if it was moving
	var has_heading := false
	var vx := 0.0
	var vy := 0.0

	func copy() -> Memory:
		var m := Memory.new()
		m.x = x
		m.y = y
		m.kind = kind
		m.at = at
		m.cleared = cleared
		m.has_heading = has_heading
		m.vx = vx
		m.vy = vy
		return m

var id: String
var name: String
var x: float
var y: float
## facing angle in radians
var dir := PI
var path: Array[Vector2i] = []
var target: Vector2i
## index into the round (Museum.watchpoints)
var stop := 0
## seconds left standing still, sweeping the view
var sweep := 0.0
## a post it keeps to while nothing is up (Sim.assign_posts), or (-1, -1),
## and which way it looks from there
var post := Vector2i(-1, -1)
var post_dir := 0.0
## spot being checked while combing the area around a clue, or (-1, -1)
var search_spot := Vector2i(-1, -1)
## seconds spent standing at one junction, so nobody takes root there
var watching := 0.0
var decision: Decision = null
var memory: Memory = null
var sees_player := false
## when it last shouted (ms)
var shouted_at := -INF
## on edge: walks faster, looks further, listens harder (suspicion 2 and up)
var alert := false
## INF once it is sure there is someone about: it never calms below alert
var calm_in := 0.0
## how many times something has put it on alert
var alarms := 0
## How much it suspects, shown over its head: 0 nothing, 1 noticed
## something odd (!), 2 on alert, not sure what is wrong (!!), 3 going for
## you (!!!). It climbs with what it sees and hears and wears off a step at
## a time (Sim.step_guard).
var suspicion := 0
## when it last had reason for its current level (ms): what it calms down by
var suspicion_at := 0.0
## when it last saw each tile (y * w + x), 0 for never: see Watch
var seen_at := PackedFloat64Array()
## the situation the current plan was made for
var planned_for := ""
## "", "lights" or "warn": something it went off to do instead of its round
var errand := ""
## the room (lights) or the guard id (warn) the errand is about
var errand_room := -1
var errand_partner := ""
