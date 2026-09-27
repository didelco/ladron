class_name Hideouts
extends RefCounted
## Places to hide in: a sarcophagus (lid aside, in you get) and a suit of
## armour still standing (you step inside it). Next to one, the action key
## gets you in; any direction gets you out, onto the free floor that way.
##
## Inside, you make no sound and no guard sees you. Same deal as the statue
## (Plinths): it only works unseen. Get in in front of a guard and it
## remembers (Guard.knows) and comes straight for you, and once beside it
## pulls you out; a guard that did not see you walks right past. A suit of armour knocked over with
## you inside it tips you out onto the floor.

## Closer than this to one (to the edge of its bier, for a sarcophagus) to
## get in.
const REACH := 1.0
## A guard this close to a blown hideout pulls you out.
const GRAB := 1.2
## The kinds you hide in, and what they are called (keys into Text).
const NAMES := {"sarcophagus": "HIDE_SARCOPHAGUS", "armour": "PROP_ARMOUR"}


class Spot:
	var kind: String
	## what it covers, in tiles: the bier's tiles, or the suit's one point
	var area: Rect2
	var tiles: Array[Vector2i] = []
	## the suit of armour's Props.Prop, or null
	var prop: Props.Prop = null

	## Where the thief is while inside: its middle.
	func middle() -> Vector2:
		return area.get_center()

	## How far a point is from it: from its edge, 0 inside.
	func dist_to(x: float, y: float) -> float:
		var c := Vector2(clampf(x, area.position.x, area.end.x), clampf(y, area.position.y, area.end.y))
		return c.distance_to(Vector2(x, y))

	func same(o: Spot) -> bool:
		return o != null and o.kind == kind and o.area == area


## What a kind is called on screen: "el sarcófago".
static func name_of(kind: String) -> String:
	return Text.t(NAMES[kind])


## Every hideout in the museum right now: the sarcophagi, and the suits of
## armour still on their feet.
static func all() -> Array[Spot]:
	var out: Array[Spot] = []
	for b in Museum.big_pieces:
		if b.kind != "sarcophagus":
			continue
		var r: Rect2i = b.rect
		var s := Spot.new()
		s.kind = "sarcophagus"
		s.area = Rect2(r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				s.tiles.append(Vector2i(x, y))
		out.append(s)
	for p in Props.list:
		if p.kind != "armour" or p.fallen:
			continue
		var s := Spot.new()
		s.kind = "armour"
		s.area = Rect2(p.x, p.y, 0, 0)
		s.tiles.append(p.tile)
		s.prop = p
		out.append(s)
	return out


## The hideout within reach of this thief, nearest first, or null: never
## one another thief is already in.
static func within_reach(p: Thief, thieves: Array[Thief]) -> Spot:
	if p.out or p.posing or p.hiding or p.rolling or p.dizzy > 0.0:
		return null
	var best: Spot = null
	var best_d := REACH
	for s in all():
		if thieves.any(func(o): return o.hiding and s.same(o.hideout)):
			continue
		var d := s.dist_to(p.x, p.y)
		if d <= best_d:
			best_d = d
			best = s
	return best


## In, and not a sound. Seen doing it, it fools nobody.
static func get_in(p: Thief, s: Spot, guards: Array[Guard]) -> void:
	var saw := Sim.witnesses(guards, p)
	p.hide_blown = not saw.is_empty()
	p.hiding = true
	p.hideout = s
	p.hide_entry = Vector2(p.x, p.y)
	var m := s.middle()
	p.x = m.x
	p.y = m.y
	p.crouched = false
	p.posture = 0.0
	p.speed = 0.0
	p.moving = false
	p.sprinting = false
	p.slow = false
	for g in saw:
		Sim.learn(g, p)


## Out onto the floor the way (dx, dy) points, if it is free: true if it got
## out. On a diagonal, whichever of its two ways is free; of the free tiles
## that way, the one nearest where it got in.
static func get_out(p: Thief, dx: int, dy: int) -> bool:
	var ways: Array[Vector2i] = []
	if dx != 0:
		ways.append(Vector2i(dx, 0))
	if dy != 0:
		ways.append(Vector2i(0, dy))
	for d in ways:
		var best := Vector2i(-1, -1)
		var best_d := INF
		for t in p.hideout.tiles:
			var n: Vector2i = t + d
			if n in p.hideout.tiles or Museum.tile_at(n.x + 0.5, n.y + 0.5) != Tiles.FLOOR:
				continue
			var dd := Vector2(n.x + 0.5, n.y + 0.5).distance_to(p.hide_entry)
			if dd < best_d:
				best_d = dd
				best = n
		if best.x < 0:
			continue
		leave(p, best, atan2(d.y, d.x))
		return true
	return false


## Out whichever way is free: the suit it was in went over.
static func tip_out(p: Thief) -> void:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if get_out(p, d.x, d.y):
			return
	var t := p.hideout.tiles[0]
	leave(p, t, p.dir)


static func leave(p: Thief, t: Vector2i, dir: float) -> void:
	p.hiding = false
	p.hide_blown = false
	p.hideout = null
	p.x = t.x + 0.5
	p.y = t.y + 0.5
	p.dir = dir


## Within reach of a guard that knows it is there.
static func grabbed(p: Thief, g: Guard) -> bool:
	return g.knows == p.id and p.hideout.dist_to(g.x, g.y) < GRAB
