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
## Whatever looks like a place to hide is one: every big piece and every
## suit of armour standing in the museum, and every piece of furniture. What
## keeps it from being too easy is how few of them there are, far apart from
## one another: the generator stands only so many big pieces to hide in
## (MapGen), the props only so many suits of armour (Props.place), and each
## night adds furniture, and empty pedestals to pose on (Plinths), up to the
## museum's share (places, spread). A saved map keeps what it stood by hand.
## Getting in takes a moment of wriggling (Minigame "squeeze", start), two to
## five seconds out in the open — once the nights have minigames
## (Heist.minigames); before that, the action key gets you in at once.
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
## How many places to hide in and pedestals to pose on a museum has between
## them: one for this many open tiles, and never fewer than MIN (if there is
## room); every PLINTH_EVERY-th of them a pedestal.
const PER_TILES := 120
const MIN := 3
const PLINTH_EVERY := 3
## Of the places to hide in, about this share are big pieces (MapGen); of
## the rest, up to half are suits of armour (Props.place), and furniture
## fills what is left (spread).
const BIG_SHARE := 0.4
## None closer than this to another, in tiles, middle to middle: running
## from one to the next is a risk of its own.
const APART := 9.0
## How tight a squeeze each is: that many more wriggles to get in
## (SqueezeGame); the roomy ones take none.
const TIGHT := {"box": 1, "egg": 1, "chest": 1, "shell": 1, "armour": 1, "legionary": 1}

## The pieces of furniture standing tonight: tile -> kind (PIECES).
static var pieces := Placed.furniture


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


## How many places to hide in and pedestals to pose on a museum with this
## many open tiles has: its share (PER_TILES), never fewer than MIN.
static func places(open: int) -> int:
	return maxi(MIN, open / PER_TILES)


## How many of them are pedestals: every PLINTH_EVERY-th, from the second.
static func plinths_of(open: int) -> int:
	return (places(open) + 1) / PLINTH_EVERY


## How many are places to hide in.
static func hideouts_of(open: int) -> int:
	return places(open) - plinths_of(open)


## How many big pieces to hide in the generator stands, at most (MapGen).
static func big_of(open: int) -> int:
	return roundi(hideouts_of(open) * BIG_SHARE)


## How many suits of armour the props stand, at most (Props.place), with
## this many big pieces to hide in standing already.
static func suits_of(open: int, big: int) -> int:
	return ceili(maxi(0, hideouts_of(open) - big) / 2.0)


## Where every place to hide in and every pedestal is now: their middles.
static func taken() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for s in all():
		out.append(s.middle())
	for t in Plinths.list:
		out.append(Vector2(t) + Vector2(0.5, 0.5))
	return out


## Whether this point is far enough (APART) from all of these.
static func far_from(at: Vector2, others: Array[Vector2]) -> bool:
	return others.all(func(o: Vector2) -> bool: return o.distance_to(at) >= APART)


## Fill tonight's share (places) with empty pedestals to pose on (if
## plinths) and furniture to hide in, of its gallery's theme, each on a case
## of its own (if furniture): next to the big pieces and suits of armour
## already standing and what a saved map stood by hand (Plinths.list,
## pieces), and none within APART of any of them. Never on the job's case
## nor one in avoid, never on a big piece, always with floor beside it to
## get in from.
static func spread(seed: int, avoid: Array[Vector2i], plinths: bool, furniture: bool) -> void:
	var rand := Mulberry32.new(seed ^ 0x6b43a9b5)
	var open := Museum.open_tiles.size()
	var want_plinths := maxi(0, plinths_of(open) - Plinths.list.size()) if plinths else 0
	var want_furniture := maxi(0, hideouts_of(open) - all().size()) if furniture else 0
	var cases: Array[Vector2i] = []
	for t in Museum.cover_tiles:
		if t in avoid or Plinths.is_plinth(t) or pieces.has(t) or not Museum.big_piece_at(t).is_empty():
			continue
		if not _floor_beside(t).is_empty():
			cases.append(t)
	var others := taken()
	# A pedestal every so often, in among the furniture.
	var n := 0
	while want_plinths + want_furniture > 0:
		var plinth := want_furniture == 0 or (want_plinths > 0 and n % PLINTH_EVERY == 1)
		n += 1
		if plinth:
			want_plinths -= 1
		else:
			want_furniture -= 1
		var free := cases.filter(func(c: Vector2i) -> bool: return far_from(Vector2(c) + Vector2(0.5, 0.5), others))
		if free.is_empty():
			break
		var t: Vector2i = free[rand.below(free.size())]
		others.append(Vector2(t) + Vector2(0.5, 0.5))
		if plinth:
			Plinths.list.append(t)
		else:
			var room := Museum.room_at(t.x + 0.5, t.y + 0.5)
			var kinds := kinds_for(room.theme if room else Museum.only_theme)
			pieces[t] = kinds[rand.below(kinds.size())]


## A museum just built: no furniture until the night stands it.
static func reset() -> void:
	pieces.clear()


## Where a saved map stood them by hand (MapFile's exhibits): tile -> kind.
static func put(by_hand: Dictionary) -> void:
	pieces.clear()
	for t in by_hand:
		# Only with floor beside it: a way in, and somewhere for its door to face.
		if PIECES.has(by_hand[t]) and Museum.is_cover(t.x + 0.5, t.y + 0.5) and Museum.big_piece_at(t).is_empty() \
				and not _floor_beside(t).is_empty():
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
## one another thief is already in, or wriggling into. `allow` (optional, takes
## the Spot, answers a bool) narrows down which ones count.
static func within_reach(p: Thief, thieves: Array[Thief], allow := Callable()) -> Spot:
	if p.out or p.posing or p.hiding or p.rolling or p.dizzy > 0.0:
		return null
	var best: Spot = null
	var best_d := REACH
	for s in all():
		if allow.is_valid() and not allow.call(s):
			continue
		if thieves.any(func(o): return o != p and ((o.hiding and s.same(o.hideout)) or s.same(o.hide_target))):
			continue
		var d := s.dist_to(p.x, p.y)
		if d <= best_d:
			best_d = d
			best = s
	return best


## Start wriggling into one (Minigame "squeeze"): it stops where it is,
## hands and all, out in the open until it is in.
static func start(p: Thief, s: Spot, input: Dictionary) -> void:
	p.game = Minigame.make("squeeze", "hideout", TIGHT.get(s.kind, 0), input)
	p.hide_target = s
	p.hide_seen.clear()
	p.moving = false
	p.speed = 0.0
	p.sprinting = false


## One frame of wriggling in, done or not: the guards that see it at it
## remember. Returns "in" once it is in (seen at any point, it fools none of
## them), "lost" if the hideout is gone meanwhile (another thief got in
## first, the suit went over), else "".
static func squeeze(p: Thief, guards: Array[Guard], thieves: Array[Thief], done: bool) -> String:
	var s := p.hide_target
	if s == null or p.out:
		p.hide_target = null
		return "lost"
	if thieves.any(func(o): return o != p and o.hiding and s.same(o.hideout)) or (s.prop and s.prop.fallen):
		p.hide_target = null
		return "lost"
	for g in Sim.witnesses(guards, p):
		if not g in p.hide_seen:
			p.hide_seen.append(g)
	if not done:
		return ""
	get_in(p, s, guards, p.hide_seen)
	p.hide_target = null
	p.hide_seen.clear()
	return "in"


## In, and not a sound. Seen doing it (now, or by those in seen while it
## wriggled in), it fools nobody.
static func get_in(p: Thief, s: Spot, guards: Array[Guard], seen: Array[Guard] = []) -> void:
	var saw := Sim.witnesses(guards, p)
	for g in seen:
		if not g in saw:
			saw.append(g)
	p.hide_blown = not saw.is_empty()
	p.hiding = true
	p.hide_settling = true
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
	p.hide_settling = false
	p.hideout = null
	p.x = t.x + 0.5
	p.y = t.y + 0.5
	p.dir = dir


## Within reach of a guard that knows it is there.
static func grabbed(p: Thief, g: Guard) -> bool:
	return g.knows == p.id and p.hideout.dist_to(g.x, g.y) < GRAB
