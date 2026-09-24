class_name Props
extends RefCounted
## Things standing about the galleries that go over if you walk into them: a
## waste-paper bin (and its papers), a bust on a slim pedestal, an
## information panel on its stand.
##
## They never block the way: you can walk right through where they stand,
## and that is the trouble — touching one while moving knocks it over, with
## a crash every guard in earshot hears. And once down it stays down: a guard
## who later sees it lying there knows something is wrong, raises the alarm
## a notch and goes to look.

const KINDS := ["bin", "bust", "panel"]
## How the kinds are shared out: mostly bins.
const WEIGHTS := [0.45, 0.3, 0.25]
## What a guard calls it when it sees it on the floor.
const NAMES := {"bin": "la papelera", "bust": "el busto", "panel": "el panel"}
## Closer than this to one, moving, and over it goes.
const TOUCH := 0.42


class Prop:
	var id: int
	var kind: String
	var tile: Vector2i
	## where it stands: the tile's centre, pulled a little towards its wall
	var x: float
	var y: float
	## from its tile towards the wall it stands against
	var face: Vector2i
	var fallen := false
	## which way it went over, in radians, and when (ms)
	var fall_dir := 0.0
	var fallen_at := 0.0
	## the guards that have already seen it lying there
	var noticed := {}


static var list: Array[Prop] = []
## knocked over this frame, for the view and the sound
static var knocked: Array[Prop] = []


## Stand a few about the museum: against a wall, off the doorways, away from
## where you come in and from the spots the job needs clear.
static func place(seed: int, avoid: Array[Vector2i]) -> void:
	list.clear()
	knocked.clear()
	var rand := Mulberry32.new(seed ^ 0x2c1b3c6d)
	var spots: Array = []
	for t in Museum.open_tiles:
		if Museum.grid[t.y * Museum.w + t.x] != Tiles.FLOOR:
			continue
		if avoid.any(func(a): return absi(a.x - t.x) + absi(a.y - t.y) <= 1):
			continue
		if Museum.dist(t.x, t.y, Museum.spawn.x, Museum.spawn.y) < 3.0:
			continue
		# Not in a doorway or a one-wide passage: walls on opposite sides.
		var wall := func(d: Vector2i) -> bool: return Museum.tile_at(t.x + d.x + 0.5, t.y + d.y + 0.5) == Tiles.WALL
		if (wall.call(Vector2i(1, 0)) and wall.call(Vector2i(-1, 0))) or (wall.call(Vector2i(0, 1)) and wall.call(Vector2i(0, -1))):
			continue
		var faces: Array[Vector2i] = []
		for d in Museum.DIRS:
			if wall.call(d):
				faces.append(d)
		if faces.size() != 1:
			continue
		# Nor right beside a gap in its own wall.
		var along := Vector2i(faces[0].y, faces[0].x)
		if not (wall.call(faces[0] + along) and wall.call(faces[0] - along)):
			continue
		spots.append([t, faces[0]])
	var wanted := maxi(2, Museum.open_tiles.size() / 55)
	var taken := {}
	var tries := 0
	while list.size() < wanted and tries < 400 and not spots.is_empty():
		tries += 1
		var s: Array = spots[rand.below(spots.size())]
		var t: Vector2i = s[0]
		# Spread out: none within three tiles of another.
		if taken.keys().any(func(o): return absi(o.x - t.x) + absi(o.y - t.y) < 4):
			continue
		taken[t] = true
		var p := Prop.new()
		p.id = list.size()
		var roll := rand.next()
		p.kind = KINDS[0] if roll < WEIGHTS[0] else (KINDS[1] if roll < WEIGHTS[0] + WEIGHTS[1] else KINDS[2])
		p.tile = t
		p.face = s[1]
		p.x = t.x + 0.5 + p.face.x * 0.22
		p.y = t.y + 0.5 + p.face.y * 0.22
		list.append(p)


## One frame: anyone moving into one knocks it over. Its crash goes into
## noises; what fell is left in knocked for whoever draws it.
static func step(thieves: Array[Thief], now: float, noises: Array[SoundEvent]) -> void:
	knocked.clear()
	for p in list:
		if p.fallen:
			continue
		for t in thieves:
			if t.out or t.speed < 0.3:
				continue
			if Museum.dist(t.x, t.y, p.x, p.y) > TOUCH:
				continue
			p.fallen = true
			p.fallen_at = now
			# Over the way you were going.
			p.fall_dir = t.dir
			knocked.append(p)
			noises.append(SoundEvent.make(p.x, p.y, p.kind))
			break


## A fallen one this guard sees for the first time, if any.
static func spotted_by(g: Guard) -> Prop:
	for p in list:
		if not p.fallen or p.noticed.has(g.id):
			continue
		if Sim.in_view(g, p.x, p.y):
			p.noticed[g.id] = true
			return p
	return null
