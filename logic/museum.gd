class_name Museum
extends RefCounted
## The live museum: port of the web version's map.ts.
##
## Static state, like the module it comes from: the simulation, the guards'
## minds and the scene all read the one museum being played. regenerate()
## builds a new one; everything else here answers questions about it — what
## is at a tile, what a guard can see, how a sound carries, the way from here
## to there.

## How big a museum is, and how many attendants it takes to watch it.
const SIZES := {
	"small": {"w": 23, "h": 17, "guards": 2},
	"medium": {"w": 35, "h": 25, "guards": 3},
	"large": {"w": 49, "h": 35, "guards": 5},
}

## The galleries of the collection, in English for Laya and Spanish for the HUD.
const GALLERIES := [
	["the Egyptian gallery", "la sala egipcia"],
	["the mineral hall", "la sala de minerales"],
	["the fossil gallery", "la galería de fósiles"],
	["the butterfly room", "la sala de mariposas"],
	["the portrait gallery", "la galería de retratos"],
	["the map room", "la sala de mapas"],
	["the sculpture court", "el patio de esculturas"],
	["the armoury", "la armería"],
	["the clock room", "la sala de relojes"],
	["the ceramics gallery", "la sala de cerámica"],
	["the meteorite room", "la sala de meteoritos"],
	["the bird gallery", "la sala de aves"],
	["the coin cabinet", "el gabinete de monedas"],
	["the textile gallery", "la sala de tejidos"],
	["the ship model room", "la sala de maquetas navales"],
	["the Roman gallery", "la sala romana"],
	["the tapestry hall", "la sala de tapices"],
	["the prints room", "el gabinete de grabados"],
	["the instrument gallery", "la sala de instrumentos"],
	["the whale hall", "la sala de la ballena"],
	["the jewel room", "la sala de joyas"],
	["the insect gallery", "la sala de insectos"],
	["the Viking gallery", "la sala vikinga"],
	["the globe room", "la sala de globos terráqueos"],
]

## Longest stretch of corridor that still counts as one place.
const STRETCH := 12
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


## A gallery with a ceiling light and the switch that turns it on. switch_at
## is the floor tile you stand on to reach it; face points at the wall.
class Room:
	var id: int
	var rect: Rect2i
	var switch_at: Vector2i
	var face: Vector2i


## A place guards think and talk in: a gallery by its own name, or a stretch
## of corridor named after the gallery it runs past. Names are unique.
class Zone:
	var id: int
	var name: String
	var label: String
	var tiles: Array[Vector2i] = []
	## the room this zone is, or -1
	var room: int = -1


static var w := 23
static var h := 17
static var shape := "rect"
## "small", "medium" or "large"
static var size_name := "small"
static var grid := PackedInt32Array()
static var outside := PackedByteArray()
static var ring := PackedByteArray()
static var open_tiles: Array[Vector2i] = []
static var cover_tiles: Array[Vector2i] = []
## the guards' round
static var watchpoints: Array[Vector2i] = []
static var rooms: Array[Room] = []
static var zones: Array[Zone] = []
## milliseconds each room's lights stay on for; 0 is dark
static var lights_left: Array[float] = []
static var spawn := Vector2i(1, 1)
## bumped on every regenerate, so views can rebuild what they cached
static var version := 0
static var _room_index := PackedInt32Array()

## Distance with 64-bit floats. Vector2 is 32-bit in Godot: close calls — a
## stretch exactly as far east of a room as south of it — came out the other
## way from the web version, which does everything in doubles.
static func dist(ax: float, ay: float, bx: float, by: float) -> float:
	return sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay))

static var _zone_index := PackedInt32Array()


## Build a new museum: its size and outline, then everything in it. An empty
## outline picks one at random, from the seed.
static func regenerate(seed: int, size: String = "small", outline: String = "") -> void:
	var dims: Dictionary = SIZES[size]
	var rand := Mulberry32.new(seed ^ 0x5bd1e995)
	shape = outline if outline != "" else MapGen.SHAPES[rand.below(MapGen.SHAPES.size())]
	size_name = size
	w = dims.w
	h = dims.h

	var made := MapGen.generate(seed, w, h, shape)
	grid = made.grid
	outside = made.outside
	ring = made.ring
	spawn = made.spawn

	open_tiles.clear()
	cover_tiles.clear()
	for y in h:
		for x in w:
			var t := grid[y * w + x]
			if t == Tiles.COVER:
				cover_tiles.append(Vector2i(x, y))
			elif t != Tiles.WALL:
				open_tiles.append(Vector2i(x, y))

	watchpoints = _build_round()

	rooms.clear()
	_room_index = PackedInt32Array()
	_room_index.resize(w * h)
	_room_index.fill(-1)
	for r in made.rooms:
		var sw := _place_switch(r)
		if sw.is_empty():
			continue
		var room := Room.new()
		room.id = rooms.size()
		room.rect = r
		room.switch_at = sw.at
		room.face = sw.face
		rooms.append(room)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_room_index[y * w + x] = room.id
	lights_left.clear()
	for r in rooms:
		lights_left.append(0.0)

	_build_zones(rand)
	version += 1


# --- Questions about tiles ---------------------------------------------------

static func tile_at(x: float, y: float) -> int:
	var cx := int(floor(x))
	var cy := int(floor(y))
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return Tiles.WALL
	return grid[cy * w + cx]


static func is_wall(x: float, y: float) -> bool:
	return tile_at(x, y) == Tiles.WALL


static func is_cover(x: float, y: float) -> bool:
	return tile_at(x, y) == Tiles.COVER


## You cannot walk through furniture, only around it.
static func blocks_move(x: float, y: float) -> bool:
	return tile_at(x, y) != Tiles.FLOOR


## Nor see past it, if you are down behind it.
static func blocks_sight(x: float, y: float) -> bool:
	return tile_at(x, y) != Tiles.FLOOR


static func is_outside(x: int, y: int) -> bool:
	return x < 0 or y < 0 or x >= w or y >= h or outside[y * w + x] == 1


static func is_ring(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and ring[y * w + x] == 1


static func room_at(x: float, y: float) -> Room:
	var cx := int(floor(x))
	var cy := int(floor(y))
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return null
	var i := _room_index[cy * w + cx]
	return null if i < 0 else rooms[i]


static func zone_at(x: float, y: float) -> Zone:
	var cx := int(floor(x))
	var cy := int(floor(y))
	if cx < 0 or cy < 0 or cx >= w or cy >= h:
		return null
	var i := _zone_index[cy * w + cx]
	return null if i < 0 else zones[i]


## Is the ceiling light on over this point?
static func is_lit(x: float, y: float) -> bool:
	var r := room_at(x, y)
	return r != null and lights_left[r.id] > 0


## The place a point is in, by name; off the floor, the nearest one.
static func zone_name(x: float, y: float) -> String:
	var z := _nearest_zone(x, y)
	return z.name if z else "the museum"


static func zone_label(x: float, y: float) -> String:
	var z := _nearest_zone(x, y)
	return z.label if z else "el museo"


static func _nearest_zone(x: float, y: float) -> Zone:
	var here := zone_at(x, y)
	if here:
		return here
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var z := zone_at(x + dx, y + dy)
				if z:
					return z
	return null


## How much corridor a tile can see: free tiles in a straight line each way.
static func openness(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h or grid[y * w + x] == Tiles.WALL:
		return 0
	var total := 0
	for d in DIRS:
		for i in range(1, maxi(w, h)):
			var nx := x + d.x * i
			var ny := y + d.y * i
			if nx < 0 or ny < 0 or nx >= w or ny >= h or grid[ny * w + nx] != Tiles.FLOOR:
				break
			total += 1
	return total


## The walkable tile nearest a point.
static func nearest_open(x: float, y: float) -> Vector2i:
	var best := open_tiles[0]
	var best_d := INF
	for t in open_tiles:
		var d := dist(t.x + 0.5, t.y + 0.5, x, y)
		if d < best_d:
			best_d = d
			best = t
	return best


# --- Paths, sight and sound --------------------------------------------------

## Breadth-first path between two tiles: the tiles to walk, target last.
static func bfs_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var start := from.y * w + from.x
	var goal := to.y * w + to.x
	var path: Array[Vector2i] = []
	if start == goal or goal < 0 or goal >= w * h:
		return path
	var prev := PackedInt32Array()
	prev.resize(w * h)
	prev.fill(-1)
	prev[start] = start
	var queue := PackedInt32Array([start])
	var head := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		if cur == goal:
			break
		var cx := cur % w
		var cy := cur / w
		for d in DIRS:
			var nx := cx + d.x
			var ny := cy + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			# Walkable means FLOOR: furniture is as solid as a wall to a walker.
			var k := ny * w + nx
			if grid[k] != Tiles.FLOOR or prev[k] != -1:
				continue
			prev[k] = cur
			queue.append(k)
	if prev[goal] == -1:
		return path
	var cur := goal
	while cur != start:
		path.append(Vector2i(cur % w, cur / w))
		cur = prev[cur]
	path.reverse()
	return path


## Walk a ray across the grid until it hits a wall (or, unless over_cover, a
## case). Returns the distance travelled, capped at max_dist.
static func cast_ray(x: float, y: float, angle: float, max_dist: float, over_cover := false) -> float:
	var dx := cos(angle)
	var dy := sin(angle)
	var cx := int(floor(x))
	var cy := int(floor(y))
	var step_x := 1 if dx > 0 else -1
	var step_y := 1 if dy > 0 else -1
	var t_delta_x := INF if dx == 0 else absf(1.0 / dx)
	var t_delta_y := INF if dy == 0 else absf(1.0 / dy)
	var t_max_x := INF if dx == 0 else ((cx + 1 - x) if dx > 0 else (x - cx)) * t_delta_x
	var t_max_y := INF if dy == 0 else ((cy + 1 - y) if dy > 0 else (y - cy)) * t_delta_y
	var travelled := 0.0
	while travelled < max_dist:
		if t_max_x < t_max_y:
			travelled = t_max_x
			t_max_x += t_delta_x
			cx += step_x
		else:
			travelled = t_max_y
			t_max_y += t_delta_y
			cy += step_y
		if cx < 0 or cy < 0 or cx >= w or cy >= h:
			return minf(travelled, max_dist)
		var t := grid[cy * w + cx]
		if t == Tiles.WALL or (not over_cover and t == Tiles.COVER):
			return minf(travelled, max_dist)
	return max_dist


## How much a straight line is muffled: a wall costs more than furniture.
static func muffle_between(ax: float, ay: float, bx: float, by: float) -> float:
	var steps := int(ceil(dist(ax, ay, bx, by) * 3))
	var cost := 0.0
	var inside := false
	for i in range(1, steps):
		var t := float(i) / steps
		var tile := tile_at(ax + (bx - ax) * t, ay + (by - ay) * t)
		if tile != Tiles.FLOOR:
			if not inside:
				cost += 1.0 if tile == Tiles.WALL else 0.45
			inside = true
		else:
			inside = false
	return cost


## Line of sight: walls always block it; the waist-high cases only block it
## for someone crouched behind them (over_cover = false).
static func has_line_of_sight(ax: float, ay: float, bx: float, by: float, over_cover := false) -> bool:
	var steps := int(ceil(dist(ax, ay, bx, by) * 4))
	for i in range(1, steps):
		var t := float(i) / steps
		var x := ax + (bx - ax) * t
		var y := ay + (by - ay) * t
		if is_wall(x, y) if over_cover else blocks_sight(x, y):
			return false
	return true


# --- Building the plan's extras ----------------------------------------------

## The guards' round: the tiles that watch the most corridor, spread out,
## ordered nearest-neighbour so walking the list reads as a patrol.
static func _build_round() -> Array[Vector2i]:
	var ranked: Array = []
	for i in open_tiles.size():
		var t := open_tiles[i]
		ranked.append([t, openness(t.x, t.y), i])
	# Stable, like the web's sort: ties keep the order of the plan.
	ranked.sort_custom(func(a, b): return a[1] > b[1] or (a[1] == b[1] and a[2] < b[2]))

	var picked: Array[Vector2i] = []
	var wanted := maxi(10, int(floor(open_tiles.size() / 40.0 + 0.5)))
	for entry in ranked:
		if picked.size() >= wanted:
			break
		var t: Vector2i = entry[0]
		var ok := true
		for p in picked:
			if dist(p.x, p.y, t.x, t.y) < 4:
				ok = false
				break
		if ok:
			picked.append(t)
	if picked.is_empty():
		return [open_tiles[0]]

	var route: Array[Vector2i] = [picked[0]]
	var left := picked.slice(1)
	while not left.is_empty():
		var c := route[route.size() - 1]
		var best := 0
		for i in range(1, left.size()):
			if dist(left[i].x, left[i].y, c.x, c.y) < dist(left[best].x, left[best].y, c.x, c.y):
				best = i
		route.append(left[best])
		left.remove_at(best)
	return route


## Where a room's switch goes: on its own wall, beside a doorway.
static func _place_switch(r: Rect2i) -> Dictionary:
	var spots: Array = []
	var doors: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if grid[y * w + x] != Tiles.FLOOR:
				continue
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var n: Vector2i = Vector2i(x, y) + d
				if r.has_point(n):
					continue
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				var t := grid[n.y * w + n.x]
				if t == Tiles.WALL:
					spots.append({"at": Vector2i(x, y), "face": d, "i": spots.size()})
				elif t == Tiles.FLOOR:
					doors.append(Vector2i(x, y))
	if spots.is_empty():
		return {}
	var to_door := func(at: Vector2i) -> int:
		if doors.is_empty():
			return 0
		var m := 1 << 30
		for d in doors:
			m = mini(m, absi(d.x - at.x) + absi(d.y - at.y))
		return 99 if m == 0 else m
	# Right beside the door, not in it; ties keep their order.
	spots.sort_custom(func(a, b):
		var da: int = to_door.call(a.at)
		var db: int = to_door.call(b.at)
		return da < db or (da == db and a.i < b.i))
	return spots[0]


## Split the museum into named places: each gallery whole, the corridors into
## stretches of up to STRETCH tiles, each named after the gallery it runs past.
static func _build_zones(rand: Mulberry32) -> void:
	zones.clear()
	_zone_index = PackedInt32Array()
	_zone_index.resize(w * h)
	_zone_index.fill(-1)

	var names := GALLERIES.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := int(floor(rand.next() * (i + 1)))
		var tmp = names[i]
		names[i] = names[j]
		names[j] = tmp
	for r in rooms:
		var pair: Array = names[r.id % names.size()]
		var n := r.id / names.size()
		var z := Zone.new()
		z.id = zones.size()
		z.name = (pair[0] as String).replace("the ", "the second ") if n > 0 else pair[0]
		z.label = "%s (%d)" % [pair[1], n + 1] if n > 0 else pair[1]
		z.room = r.id
		zones.append(z)
	var room_zone := {}
	for z in zones:
		room_zone[z.room] = z.id

	var corridor: Array[Vector2i] = []
	for t in open_tiles:
		var r := room_at(t.x + 0.5, t.y + 0.5)
		if r:
			var id: int = room_zone[r.id]
			zones[id].tiles.append(t)
			_zone_index[t.y * w + t.x] = id
		else:
			corridor.append(t)

	# Grow corridor stretches outwards from whatever is left.
	var is_corridor := PackedByteArray()
	is_corridor.resize(w * h)
	for t in corridor:
		is_corridor[t.y * w + t.x] = 1
	var base := zones.size()
	var stretches: Array = []
	for s in corridor:
		if _zone_index[s.y * w + s.x] >= 0:
			continue
		var id := base + stretches.size()
		var tiles: Array[Vector2i] = [s]
		_zone_index[s.y * w + s.x] = id
		var i := 0
		while i < tiles.size() and tiles.size() < STRETCH:
			var c := tiles[i]
			for d in DIRS:
				if tiles.size() >= STRETCH:
					break
				var n := c + d
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				if is_corridor[n.y * w + n.x] == 0 or _zone_index[n.y * w + n.x] >= 0:
					continue
				_zone_index[n.y * w + n.x] = id
				tiles.append(n)
			i += 1
		stretches.append(tiles)

	# Scraps of a tile or two are a doorway: they join the place next door.
	for tiles in stretches:
		if tiles.size() > 2:
			continue
		for t in tiles:
			var near := -1
			for d in DIRS:
				var n: Vector2i = t + d
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					continue
				var z := _zone_index[n.y * w + n.x]
				if z >= 0 and (z < base or (stretches[z - base] as Array).size() > 2):
					near = z
					break
			_zone_index[t.y * w + t.x] = near
			if near >= 0 and near < base:
				zones[near].tiles.append(t)
			elif near >= 0:
				(stretches[near - base] as Array).append(t)
		tiles.clear()

	# Name each stretch after the gallery it runs past, by which side of it.
	var used := {}
	for tiles in stretches:
		if tiles.is_empty():
			continue
		var id := zones.size()
		var cx := 0.0
		var cy := 0.0
		for t in tiles:
			cx += t.x
			cy += t.y
		cx = cx / tiles.size() + 0.5
		cy = cy / tiles.size() + 0.5
		var best: Zone = null
		var best_d := INF
		for z in zones:
			if z.room < 0:
				continue
			var rr := rooms[z.room].rect
			var d := dist(rr.position.x + rr.size.x / 2.0, rr.position.y + rr.size.y / 2.0, cx, cy)
			if d < best_d:
				best_d = d
				best = z
		var zname := "the corridor"
		var label := "el pasillo"
		if best:
			var rr := rooms[best.room].rect
			var ox := cx - (rr.position.x + rr.size.x / 2.0)
			var oy := cy - (rr.position.y + rr.size.y / 2.0)
			var dirs: Array
			if absf(ox) > absf(oy):
				dirs = ["east", "al este"] if ox > 0 else ["west", "al oeste"]
			else:
				dirs = ["south", "al sur"] if oy > 0 else ["north", "al norte"]
			zname = "the corridor %s of %s" % [dirs[0], best.name]
			# "de el patio" is "del patio" in Spanish.
			var of := ("del " + best.label.substr(3)) if best.label.begins_with("el ") else ("de " + best.label)
			label = "el pasillo %s %s" % [dirs[1], of]
		var n: int = used.get(zname, 0) + 1
		used[zname] = n
		if n > 1:
			zname += " (stretch %d)" % n
			label += " (tramo %d)" % n
		var z := Zone.new()
		z.id = id
		z.name = zname
		z.label = label
		for t in tiles:
			z.tiles.append(t)
			_zone_index[t.y * w + t.x] = id
		zones.append(z)
