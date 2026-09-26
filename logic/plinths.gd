class_name Plinths
extends RefCounted
## Low empty pedestals, knee-high, waiting for a sculpture that never came:
## climb on one (the action key, next to it) and strike a ninja pose, and to
## a guard you are just another piece of the collection. Any direction steps
## you down again, onto the free floor that way.
##
## Each stands on a case tile (Tiles.COVER), so it blocks the way like any
## other piece of furniture; a guard never walks into the statue. The trick
## only works unseen: climb up in front of a guard and it knows what it saw
## (Thief.pose_blown) until it loses sight of you — and a guard right beside
## a statue it knows is you takes you down off it.

## Closer than this to one's middle to climb up.
const REACH := 1.2
## How high the top is (m): the thief stands this much off the floor.
const HEIGHT := 0.3
## A guard this close to a blown statue gets hold of it.
const GRAB := 1.3
## Seconds on the floor after falling off one (Minigame "balance").
const FALL_DOWN_S := 1.2
## One for this many open tiles, and never fewer than MIN (if there is room).
const PER_TILES := 90
const MIN := 2

static var list: Array[Vector2i] = []


## Pick a few of the museum's cases to be empty pedestals instead: never the
## job's own, never a big piece, each with floor beside it to climb from and
## spread out about the museum.
static func place(seed: int, avoid: Array[Vector2i]) -> void:
	list.clear()
	var rand := Mulberry32.new(seed ^ 0x51ed270b)
	var spots: Array[Vector2i] = []
	for t in Museum.cover_tiles:
		if t in avoid or not Museum.big_piece_at(t).is_empty():
			continue
		if _floor_beside(t).is_empty():
			continue
		spots.append(t)
	var wanted := maxi(MIN, Museum.open_tiles.size() / PER_TILES)
	var tries := 0
	while list.size() < wanted and tries < 400 and not spots.is_empty():
		tries += 1
		var t: Vector2i = spots[rand.below(spots.size())]
		if list.any(func(o): return absi(o.x - t.x) + absi(o.y - t.y) < 5):
			continue
		list.append(t)
		spots.erase(t)


## Where a saved map stood them by hand (MapFile's exhibits, "plinth").
static func put(tiles: Array[Vector2i]) -> void:
	list.clear()
	for t in tiles:
		if Museum.is_cover(t.x + 0.5, t.y + 0.5) and Museum.big_piece_at(t).is_empty():
			list.append(t)


static func is_plinth(t: Vector2i) -> bool:
	return t in list


## The free floor tiles next to one, to climb up from or step down to.
static func _floor_beside(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in Museum.DIRS:
		if Museum.tile_at(t.x + d.x + 0.5, t.y + d.y + 0.5) == Tiles.FLOOR:
			out.append(t + d)
	return out


## The empty pedestal within reach of this thief, nearest first, or null
## (as a Variant: a Vector2i, or null).
static func within_reach(p: Thief, thieves: Array[Thief]) -> Variant:
	if p.out or p.posing or p.rolling or p.dizzy > 0.0:
		return null
	var best: Variant = null
	var best_d := REACH
	for t in list:
		if thieves.any(func(o): return o.posing and o.perch == t):
			continue
		var d := Museum.dist(p.x, p.y, t.x + 0.5, t.y + 0.5)
		if d <= best_d:
			best_d = d
			best = t
	return best


## Up on it and still as stone. Seen doing it, the pose fools nobody.
static func climb(p: Thief, t: Vector2i, guards: Array[Guard]) -> void:
	p.pose_blown = not Sim.is_hidden(guards, p)
	p.posing = true
	p.perch = t
	# Facing the room's south side, the camera's: a statue shows its front.
	p.dir = PI / 2
	p.x = t.x + 0.5
	p.y = t.y + 0.5
	p.crouched = false
	p.posture = 0.0
	p.speed = 0.0
	p.moving = false
	p.sprinting = false
	p.slow = false


## How hard it is to keep the pose on one foot (Minigame "balance"), 0..1:
## the gallery's lights on, a guard close by.
static func pressure(p: Thief, guards: Array[Guard]) -> float:
	var out := 0.5 if Museum.is_lit(p.x, p.y) else 0.0
	for g in guards:
		out += clampf(1.0 - Museum.dist(g.x, g.y, p.x, p.y) / 8.0, 0.0, 1.0) * 0.8
	return clampf(out, 0.0, 1.0)


## Down onto whichever side is free, the way it leans first (lean < 0 is
## the camera's left, west).
static func get_down(p: Thief, lean := 0.0) -> bool:
	var first := -1 if lean < 0.0 else 1
	for d in [Vector2i(first, 0), Vector2i(-first, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if step_down(p, d.x, d.y):
			return true
	return false


## Lost its balance: off the pedestal the way it leaned, with a thud the
## guards hear, and a moment on the floor getting up.
static func fall(p: Thief, lean: float, noises: Array[SoundEvent]) -> void:
	get_down(p, lean)
	p.dizzy = FALL_DOWN_S
	p.posture = 1.0
	noises.append(SoundEvent.make(p.x, p.y, "tumble"))


## Down onto the floor the way (dx, dy) points, if it is free: true if it
## stepped down. On a diagonal, whichever of its two ways is free.
static func step_down(p: Thief, dx: int, dy: int) -> bool:
	var ways: Array[Vector2i] = []
	if dx != 0:
		ways.append(Vector2i(dx, 0))
	if dy != 0:
		ways.append(Vector2i(0, dy))
	for d in ways:
		var n := p.perch + d
		if Museum.tile_at(n.x + 0.5, n.y + 0.5) != Tiles.FLOOR:
			continue
		p.posing = false
		p.pose_blown = false
		p.x = n.x + 0.5
		p.y = n.y + 0.5
		p.dir = atan2(d.y, d.x)
		p.perch = Vector2i(-1, -1)
		return true
	return false
