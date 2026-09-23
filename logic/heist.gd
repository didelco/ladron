class_name Heist
extends RefCounted
## The job: every level there is one thing to take and one door to leave by.
## Port of the web version's heist.ts.
##
## The piece sits in a case deep in the museum; you take it by standing in
## front of it, still, for as long as the lock takes — step away and you start
## again — and forcing it sets its alarm off. The way out is a service door in
## the outer wall, far from the piece and never where you came in, so the job
## is always a crossing and never a there-and-back.

const LOOT := [
	{"name": "el Ojo de Medianoche", "blurb": "Un zafiro del tamaño de un puño.", "verb": "FORZANDO LA VITRINA", "seconds": 3.0, "colour": "#5b8cff", "shape": "gem"},
	{"name": "el huevo de oviraptor", "blurb": "Fósil de setenta millones de años.", "verb": "SOLTANDO EL HUEVO", "seconds": 4.0, "colour": "#e8c89a", "shape": "egg"},
	{"name": "la corona de la reina Urraca", "blurb": "Oro batido y granates.", "verb": "DESATORNILLANDO", "seconds": 4.5, "colour": "#f0c46a", "shape": "crown"},
	{"name": "el meteorito de Tolva", "blurb": "Hierro caído del cielo en 1911.", "verb": "ENGAÑANDO EL SENSOR", "seconds": 5.0, "colour": "#9aa3b5", "shape": "rock"},
	{"name": "la máscara de jade", "blurb": "Funeraria, doscientas teselas verdes.", "verb": "CORTANDO EL SELLO", "seconds": 5.5, "colour": "#3ddc84", "shape": "mask"},
	{"name": "el ídolo de obsidiana", "blurb": "La pieza estrella del museo.", "verb": "ABRIENDO LA CERRADURA", "seconds": 6.0, "colour": "#b07cff", "shape": "idol"},
]

## Close enough to the case to work on it: one tile off, body against the glass.
const REACH := 1.12
## Facing roughly at it.
const FACING := 1.3
## Near enough to pick up a piece dropped on the floor.
const PICK_UP := 0.7
## Near enough to the door to be through it.
const DOOR := 0.8
## The case's alarm rings this often while someone is forcing it.
const ALARM_EVERY_MS := 900.0

# The job for the current level.
static var level := 1
static var loot: Dictionary = LOOT[0]
## the case tile
static var at := Vector2i.ZERO
static var start := Vector2i.ONE
## floor tile in front of the door, and from it to the wall the door is in
static var exit := Vector2i.ONE
static var exit_face := Vector2i(-1, 0)
## start -> piece -> door, tile by tile, for the map on the mission screen
static var route: Array[Vector2i] = []
## the plan in three lines: [title, text]
static var plan: Array = []

# The take, frame by frame.
## 0..1 of the lock worked through; back to 0 the moment nobody is at it
static var progress := 0.0
## who is at the case, who has the piece ("" for nobody)
static var by := ""
static var carrier := ""
## where it lies on the floor after its carrier was caught, or INF
static var dropped := Vector2.INF
static var taken := false
static var _last_alarm := 0.0


## The piece for a level (1-based): past the list it loops, a second slower each lap.
static func loot_for(n: int) -> Dictionary:
	var l: Dictionary = LOOT[(n - 1) % LOOT.size()].duplicate()
	l.seconds += (n - 1) / LOOT.size()
	return l


## Lay the job out on the museum just generated. The piece: a case in a
## gallery, among the furthest from the entrance. The door: on the outer
## wall, far from the piece and not beside the entrance. Both at random among
## the good candidates, so two museums that look alike do not play alike.
static func plan_job(n: int) -> void:
	level = n
	loot = loot_for(n)
	start = Museum.spawn
	progress = 0.0
	by = ""
	carrier = ""
	dropped = Vector2.INF
	taken = false
	_last_alarm = 0.0
	var from_start := _distances(start)
	var reach := func(t: Vector2i) -> int: return from_start[t.y * Museum.w + t.x]

	var cases: Array = []
	for t in Museum.cover_tiles:
		var stands := _stand_tiles(t).filter(func(s): return reach.call(s) >= 0)
		if stands.is_empty():
			continue
		var d := 1 << 30
		for s in stands:
			d = mini(d, reach.call(s))
		# A gallery piece is worth more than one in a corridor: count it further.
		cases.append([t, d * (1.0 if Museum.room_at(t.x + 0.5, t.y + 0.5) else 0.6)])
	cases.sort_custom(func(a, b): return a[1] > b[1])
	var top := cases.slice(0, maxi(1, ceili(cases.size() / 4.0)))
	at = top[randi() % top.size()][0] if not top.is_empty() else Vector2i.ONE

	# The tile you will stand on: the nearest to the entrance.
	var stand := start
	var best := 1 << 30
	for s in _stand_tiles(at):
		var d: int = reach.call(s)
		if d >= 0 and d < best:
			best = d
			stand = s
	var from_loot := _distances(stand)

	# Doors: a floor tile against the outer wall, whatever the building's shape.
	var doors: Array = []
	for t in Museum.open_tiles:
		if Museum.grid[t.y * Museum.w + t.x] != Tiles.FLOOR:
			continue
		var dl := from_loot[t.y * Museum.w + t.x]
		var ds := from_start[t.y * Museum.w + t.x]
		if dl < 0 or ds < 0:
			continue
		# Not the way in: out the same door is not a plan, it is a retreat.
		if ds < 7:
			continue
		for d in Museum.DIRS:
			var wall := t + d
			if Museum.tile_at(wall.x + 0.5, wall.y + 0.5) != Tiles.WALL:
				continue
			if not Museum.is_outside(wall.x + d.x, wall.y + d.y):
				continue
			doors.append([t, d, dl + ds * 0.5])
	doors.sort_custom(func(a, b): return a[2] > b[2])
	var good := doors.slice(0, maxi(1, ceili(doors.size() / 5.0)))
	if good.is_empty():
		exit = start
		exit_face = Vector2i(-1, 0)
	else:
		var door: Array = good[randi() % good.size()]
		exit = door[0]
		exit_face = door[1]

	route = _walk(start, stand)
	var out := _walk(stand, exit)
	out.remove_at(0)
	route.append_array(out)
	plan = [
		["Entrada", first_upper(Museum.zone_label(start.x + 0.5, start.y + 0.5))],
		["Pieza", first_upper(Museum.zone_label(at.x + 0.5, at.y + 0.5))],
		["Salida", "Puerta del muro %s, en %s" % [_side(exit_face), Museum.zone_label(exit.x + 0.5, exit.y + 0.5)]],
	]


## "el pasillo" -> "El pasillo". GDScript's capitalize() does every word.
static func first_upper(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


static func _side(face: Vector2i) -> String:
	match face:
		Vector2i(-1, 0): return "oeste"
		Vector2i(1, 0): return "este"
		Vector2i(0, -1): return "norte"
		_: return "sur"


## Walking distance from a tile to every floor tile; -1 unreachable.
static func _distances(from: Vector2i) -> PackedInt32Array:
	var w := Museum.w
	var d := PackedInt32Array()
	d.resize(w * Museum.h)
	d.fill(-1)
	d[from.y * w + from.x] = 0
	var queue := PackedInt32Array([from.y * w + from.x])
	var q := 0
	while q < queue.size():
		var cur := queue[q]
		q += 1
		for dd in Museum.DIRS:
			var nx := cur % w + dd.x
			var ny := cur / w + dd.y
			if nx < 0 or ny < 0 or nx >= w or ny >= Museum.h or Museum.grid[ny * w + nx] != Tiles.FLOOR:
				continue
			var k := ny * w + nx
			if d[k] >= 0:
				continue
			d[k] = d[cur] + 1
			queue.append(k)
	return d


## Shortest walk between two floor tiles, both ends included.
static func _walk(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var d := _distances(to)
	var out: Array[Vector2i] = [from]
	var c := from
	if d[c.y * Museum.w + c.x] < 0:
		return out
	while d[c.y * Museum.w + c.x] > 0:
		for dd in Museum.DIRS:
			var n := c + dd
			if n.x < 0 or n.y < 0 or n.x >= Museum.w or n.y >= Museum.h:
				continue
			var v := d[n.y * Museum.w + n.x]
			if v >= 0 and v == d[c.y * Museum.w + c.x] - 1:
				c = n
				break
		out.append(c)
	return out


## The floor tiles beside a case: where you stand to take what is in it.
static func _stand_tiles(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in Museum.DIRS:
		var n := t + d
		if Museum.tile_at(n.x + 0.5, n.y + 0.5) == Tiles.FLOOR:
			out.append(n)
	return out


## Standing at the case, still, facing it?
static func at_case(p: Thief) -> bool:
	if p.out or p.moving or p.speed > 0.2:
		return false
	var cx := at.x + 0.5
	var cy := at.y + 0.5
	if Museum.dist(p.x, p.y, cx, cy) > REACH:
		return false
	return absf(wrapf(atan2(cy - p.y, cx - p.x) - p.dir, -PI, PI)) < FACING


static func at_door(p: Thief) -> bool:
	return Museum.dist(p.x, p.y, exit.x + 0.5, exit.y + 0.5) < DOOR


## One frame of the job: working the lock (and its alarm), carrying, dropping,
## picking up, leaving. Returns "", "stolen", "dropped", "picked" or "out";
## an alarm going off this frame is appended to noises.
static func step(thieves: Array[Thief], dt: float, now: float, noises: Array[SoundEvent]) -> String:
	if not taken:
		var worker: Thief = null
		for p in thieves:
			if at_case(p):
				worker = p
				break
		if worker == null:
			progress = 0.0
			by = ""
			_last_alarm = 0.0
			return ""
		# Forcing the case sets its alarm off, and a guard hears it like any
		# other sound: the job is a race against whoever is in earshot.
		if now - _last_alarm > ALARM_EVERY_MS:
			_last_alarm = now
			noises.append(SoundEvent.make(at.x + 0.5, at.y + 0.5, "alarm"))
		# Swapping who is at it is stepping away.
		progress = (progress if worker.id == by else 0.0) + dt / float(loot.seconds)
		by = worker.id
		if progress >= 1.0:
			progress = 1.0
			by = ""
			carrier = worker.id
			taken = true
			return "stolen"
		return ""
	if carrier != "":
		var c: Thief = null
		for p in thieves:
			if p.id == carrier:
				c = p
		if c == null or c.out:
			carrier = ""
			dropped = Vector2(c.x, c.y) if c else Vector2.INF
			return "dropped"
		return "out" if at_door(c) else ""
	if dropped != Vector2.INF:
		for p in thieves:
			if not p.out and Museum.dist(p.x, p.y, dropped.x, dropped.y) < PICK_UP:
				carrier = p.id
				dropped = Vector2.INF
				return "picked"
	return ""


## Where the piece is right now, for the arrow at the edge of the screen.
static func objective() -> Vector2:
	if carrier != "":
		return Vector2(exit.x + 0.5, exit.y + 0.5)
	if dropped != Vector2.INF:
		return dropped
	return Vector2(at.x + 0.5, at.y + 0.5)
