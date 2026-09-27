class_name Hideouts
extends RefCounted
## Places to hide in. Next to one, the action key gets you in; any direction
## gets you out, onto the free floor that way.
##
##   the big pieces (Museum.big_pieces) you fit inside: the sarcophagus, the
##     Trojan horse, the mammoth (under its coat), the hollow log and the
##     little car on its stand;
##   pieces of furniture on a case tile of their own (pieces), one theme
##     each: a retro fridge and a cardboard box (modern), a legionary's
##     armour (ancient), a confessional and a chest (middle ages), a giant
##     dinosaur egg (prehistory), a giant tortoise shell (nature);
##   a suit of armour still standing (Props): you step inside it.
##
## Inside, you make no sound and no guard sees you. Same deal as the statue
## (Plinths): it only works unseen. Get in in front of a guard and it
## remembers (Guard.knows) and comes straight for you, and once beside it
## pulls you out; a guard that did not see you walks right past. A suit of
## armour knocked over with you inside it tips you out onto the floor.

## Closer than this to one (to its edge) to get in.
const REACH := 1.0
## A guard this close to a blown hideout pulls you out.
const GRAB := 1.2
## The big pieces you fit inside (keys of MapGen.BIG).
const BIG := ["sarcophagus", "trojan_horse", "mammoth", "log", "car"]
## The pieces of furniture you hide in: their model (MuseumView.asset) and
## the theme whose galleries they stand in (Themes).
const PIECES := {
	"fridge": {"model": "temas/moderna/nevera", "theme": "moderna"},
	"box": {"model": "temas/moderna/caja", "theme": "moderna"},
	"legionary": {"model": "temas/antiguo/legionario", "theme": "antiguo"},
	"confessional": {"model": "temas/edad_media/confesionario", "theme": "edad_media"},
	"chest": {"model": "temas/edad_media/baul", "theme": "edad_media"},
	"egg": {"model": "temas/prehistoria/huevo", "theme": "prehistoria"},
	"shell": {"model": "temas/naturaleza/caparazon", "theme": "naturaleza"},
}
## One piece of furniture to hide in for this many open tiles, and never
## fewer than MIN (if there is room).
const PER_TILES := 70
const MIN := 2

## The pieces of furniture standing tonight: tile -> kind (PIECES).
static var pieces := {}


class Spot:
	var kind: String
	## what it covers, in tiles: the piece's tiles, or the suit's one point
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


## What a kind is called on screen: "el sarcófago", "la nevera".
static func name_of(kind: String) -> String:
	return Text.t("PROP_ARMOUR" if kind == "armour" else "HIDE_" + kind.to_upper())


## Stand a few pieces of furniture to hide in on the museum's cases, each of
## its gallery's theme (a corridor's, any): never the job's case nor one in
## avoid, never a big piece, each with floor beside it to get in from, and
## spread out about the museum.
static func place(seed: int, avoid: Array[Vector2i]) -> void:
	pieces.clear()
	var rand := Mulberry32.new(seed ^ 0x6b43a9b5)
	var spots: Array[Vector2i] = []
	for t in Museum.cover_tiles:
		if t in avoid or Plinths.is_plinth(t) or not Museum.big_piece_at(t).is_empty():
			continue
		if _floor_beside(t).is_empty():
			continue
		spots.append(t)
	var wanted := maxi(MIN, Museum.open_tiles.size() / PER_TILES)
	var tries := 0
	while pieces.size() < wanted and tries < 400 and not spots.is_empty():
		tries += 1
		var t: Vector2i = spots[rand.below(spots.size())]
		if pieces.keys().any(func(o): return absi(o.x - t.x) + absi(o.y - t.y) < 5):
			continue
		var room := Museum.room_at(t.x + 0.5, t.y + 0.5)
		var kinds := kinds_for(room.theme if room else "")
		pieces[t] = kinds[rand.below(kinds.size())]
		spots.erase(t)


## Where a saved map stood them by hand (MapFile's exhibits): tile -> kind.
static func put(by_hand: Dictionary) -> void:
	pieces.clear()
	for t in by_hand:
		if PIECES.has(by_hand[t]) and Museum.is_cover(t.x + 0.5, t.y + 0.5) and Museum.big_piece_at(t).is_empty():
			pieces[t] = by_hand[t]


## The pieces of furniture of a theme ("" for any).
static func kinds_for(theme: String) -> Array:
	var out: Array = []
	for k in PIECES:
		if theme == "" or PIECES[k].theme == theme:
			out.append(k)
	return out if not out.is_empty() else PIECES.keys()


## The free floor tiles next to one, to get in from or out to.
static func _floor_beside(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in Museum.DIRS:
		if Museum.tile_at(t.x + d.x + 0.5, t.y + d.y + 0.5) == Tiles.FLOOR:
			out.append(t + d)
	return out


## Every hideout in the museum right now: the big pieces you fit in, the
## pieces of furniture, and the suits of armour still on their feet.
static func all() -> Array[Spot]:
	var out: Array[Spot] = []
	for b in Museum.big_pieces:
		if not b.kind in BIG:
			continue
		var r: Rect2i = b.rect
		var s := Spot.new()
		s.kind = b.kind
		s.area = Rect2(r)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				s.tiles.append(Vector2i(x, y))
		out.append(s)
	for t in pieces:
		var s := Spot.new()
		s.kind = pieces[t]
		s.area = Rect2(Vector2(t), Vector2.ONE)
		s.tiles.append(t)
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
