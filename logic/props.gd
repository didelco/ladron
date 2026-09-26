class_name Props
extends RefCounted
## Things standing about the galleries that go over if you walk into them: a
## waste-paper bin (and its papers), a bust on a slim pedestal, an
## information panel on its stand, a suit of armour (that falls to pieces).
##
## They never block the way: you can walk right through where they stand,
## and that is the trouble — touching one while moving knocks it over, with
## a crash every guard in earshot hears. And once down it stays down: a guard
## who later sees it lying there knows something is wrong, raises the alarm
## a notch and goes to look.
##
## Which is also the trick: push one over on purpose (Props.push) and the
## guards come running to it — away from where you are going.

const KINDS := ["bin", "bust", "panel", "armour"]
## How the kinds are shared out: mostly bins, the odd suit of armour.
const WEIGHTS := [0.4, 0.25, 0.2, 0.15]
## What a guard calls it when it sees it on the floor: keys into Text
## (name_of has the words).
const NAMES := {"bin": "PROP_BIN", "bust": "PROP_BUST", "panel": "PROP_PANEL", "armour": "PROP_ARMOUR"}
## Closer than this to one, moving, and over it goes.
const TOUCH := 0.45
## Close enough to push one over on purpose.
const REACH := 1.1


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


## What a kind is called on screen: "la papelera".
static func name_of(kind: String) -> String:
	return Text.t(NAMES[kind])


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
		# Out in the open, in the middle of a gallery: right in the way.
		if faces.is_empty():
			var clear := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if Museum.tile_at(t.x + dx + 0.5, t.y + dy + 0.5) != Tiles.FLOOR:
						clear = false
			if clear and Museum.room_at(t.x + 0.5, t.y + 0.5) != null:
				spots.append([t, Vector2i.ZERO])
			continue
		if faces.size() != 1:
			continue
		# Never with the wall between it and the camera (to the south): it
		# would stand behind it, out of sight.
		if faces[0] == Vector2i(0, 1):
			continue
		# Nor right beside a gap in its own wall.
		var along := Vector2i(faces[0].y, faces[0].x)
		if not (wall.call(faces[0] + along) and wall.call(faces[0] - along)):
			continue
		spots.append([t, faces[0]])
	var wanted := maxi(3, Museum.open_tiles.size() / 40)
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
		p.kind = KINDS[-1]
		for k in KINDS.size():
			roll -= WEIGHTS[k]
			if roll < 0.0:
				p.kind = KINDS[k]
				break
		p.tile = t
		p.face = s[1] if s[1] != Vector2i.ZERO else Vector2i(0, -1)
		var pull := 0.22 if s[1] != Vector2i.ZERO else 0.0
		p.x = t.x + 0.5 + p.face.x * pull
		p.y = t.y + 0.5 + p.face.y * pull
		list.append(p)


## Stand one by hand, where a saved map says (MapFile): against a wall of
## its tile if it has one (never the south one, the camera's side).
static func put(kind: String, t: Vector2i) -> void:
	var p := Prop.new()
	p.id = list.size()
	p.kind = kind
	p.tile = t
	var face := Vector2i.ZERO
	for d in Museum.DIRS:
		if d != Vector2i(0, 1) and Museum.tile_at(t.x + d.x + 0.5, t.y + d.y + 0.5) == Tiles.WALL:
			face = d
			break
	p.face = face if face != Vector2i.ZERO else Vector2i(0, -1)
	var pull := 0.22 if face != Vector2i.ZERO else 0.0
	p.x = t.x + 0.5 + p.face.x * pull
	p.y = t.y + 0.5 + p.face.y * pull
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


## The standing one within reach of this thief, nearest first, or null.
static func within_reach(t: Thief) -> Prop:
	var best: Prop = null
	var best_d := REACH
	for p in list:
		if p.fallen or t.out:
			continue
		var d := Museum.dist(t.x, t.y, p.x, p.y)
		if d <= best_d:
			best_d = d
			best = p
	return best


## Push it over on purpose: away from the thief, with the same crash.
static func push(p: Prop, t: Thief, now: float, noises: Array[SoundEvent]) -> void:
	if p.fallen:
		return
	p.fallen = true
	p.fallen_at = now
	p.fall_dir = atan2(p.y - t.y, p.x - t.x)
	knocked.append(p)
	# A shove sends it over properly: louder than a nudge.
	noises.append(SoundEvent.make(p.x, p.y, p.kind, crash_loudness(p.kind, 0.6)))


## How much of the museum each kind fills at full tilt: the bust is heavy
## stone, the bin rings out, the panel is mostly a slap, and a suit of armour
## coming apart on the marble is the loudest thing in the building.
const CARRY := {"bin": 0.9, "bust": 1.0, "panel": 0.8, "armour": 1.1}


## How loud it is going over: never quiet — a nudge is already its kind's
## base loudness — and the harder it goes, the further it carries, up to a
## crash a calm guard hears from the far end of the building.
static func crash_loudness(kind: String, strength: float) -> float:
	var whole := Vector2(Museum.w, Museum.h).length() / Hearing.HEARING_CALM
	return lerpf(float(Hearing.LOUDNESS[kind]), whole * float(CARRY[kind]), clampf(strength, 0.0, 1.0))


## Loud enough to be heard all over the museum.
static func heard_everywhere(loudness: float) -> bool:
	return loudness >= 0.6 * Vector2(Museum.w, Museum.h).length() / Hearing.HEARING_CALM


## A fallen one this guard sees for the first time, if any.
static func spotted_by(g: Guard) -> Prop:
	for p in list:
		if not p.fallen or p.noticed.has(g.id):
			continue
		if Sim.in_view(g, p.x, p.y):
			p.noticed[g.id] = true
			return p
	return null
