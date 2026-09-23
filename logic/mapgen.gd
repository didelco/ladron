class_name MapGen
extends RefCounted
## Museum generator.
##
## First the building: a footprint of any size, and not only a rectangle — an
## L, a T, a U, a cross, or a block with bites taken out of it. A circulation
## corridor runs just inside the outer wall, whatever its shape.
##
## Then the galleries, packed like a real museum: the space inside the
## corridor is split by binary space partition and every piece becomes a
## gallery, next to its neighbours with a single wall between — no leftover
## blocks of solid wall that read as sealed rooms. Doors go through those
## walls: first enough to reach every gallery (from the corridor too), then
## more until every gallery has at least two, on different sides where it
## can, then a few extra so there is always another way round. A gallery with
## one way in is a trap, not a hiding place.
##
## (The web version carved rooms with margins and joined them with
## corridors; it left dead-end stubs, solid blocks and one-door rooms. This
## is the Godot port's own generator from here on.)
##
## The grid is flat — index y * w + x — because packed arrays nested inside an
## Array are copied on write in GDScript, and grid[y][x] = v would change a
## copy.

const SHAPES: Array[String] = ["rect", "L", "T", "U", "cross", "notched"]
## Smallest piece a split may leave: a 4x4 gallery and its wall.
const MIN_LEAF := 5
## Every shape keeps its arms at least this wide, so a gallery and the
## corridor round it always fit.
const MIN_ARM := 9
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var w: int
var h: int
var grid: PackedInt32Array
## inside the outer wall: the only tiles that may ever be carved
var interior: PackedByteArray
## the circulation corridor along the outer wall
var ring: PackedByteArray
## 1 where there is no building at all
var outside: PackedByteArray
## galleries as Rect2i
var rooms: Array[Rect2i] = []
var spawn: Vector2i
var _rand: Mulberry32


## Build a museum. Read the result from grid, rooms, spawn, outside and ring.
static func generate(seed: int, width: int, height: int, shape: String) -> MapGen:
	var g := MapGen.new()
	g._build(seed, width, height, shape)
	return g


func at(x: int, y: int) -> int:
	return grid[y * w + x]


func _put(x: int, y: int, v: int) -> void:
	grid[y * w + x] = v


func _build(seed: int, width: int, height: int, shape: String) -> void:
	w = width
	h = height
	_rand = Mulberry32.new(seed)
	var footprint := _build_footprint(shape)

	# Inside the outer wall: footprint tiles whose whole neighbourhood is
	# footprint too. What is left of the footprint is the outer wall itself.
	interior = PackedByteArray()
	interior.resize(w * h)
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var all := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if footprint[(y + dy) * w + x + dx] == 0:
						all = false
			if all:
				interior[y * w + x] = 1

	# The circulation corridor: the band of interior right against the wall.
	ring = PackedByteArray()
	ring.resize(w * h)
	for y in h:
		for x in w:
			if interior[y * w + x] == 0:
				continue
			var edge := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if interior[(y + dy) * w + x + dx] == 0:
						edge = true
			if edge:
				ring[y * w + x] = 1

	# Start solid and carve.
	grid = PackedInt32Array()
	grid.resize(w * h)
	grid.fill(Tiles.WALL)

	for i in w * h:
		if ring[i] == 1:
			grid[i] = Tiles.FLOOR

	_carve_galleries()
	_open_doors()
	_furnish_rooms()
	_scatter_cover()
	_link_everything()
	_clear_dead_ends()

	outside = PackedByteArray()
	outside.resize(w * h)
	for i in w * h:
		if footprint[i] == 0:
			outside[i] = 1
	spawn = _pick_spawn()


# --- Footprint -------------------------------------------------------------

func _build_footprint(shape: String) -> PackedByteArray:
	var m := PackedByteArray()
	m.resize(w * h)
	_fill(m, 0, 0, w, h, 1)
	var narrow := w < MIN_ARM * 2 + 1 or h < MIN_ARM * 2 + 1
	if shape == "rect" or narrow:
		return m

	if shape == "L":
		# Bite one corner out.
		var bw := w - _part(w, 0.4, 0.6)
		var bh := h - _part(h, 0.4, 0.6)
		var right := _rand.next() < 0.5
		var bottom := _rand.next() < 0.5
		_fill(m, w - bw if right else 0, h - bh if bottom else 0, w if right else bw, h if bottom else bh, 0)
	elif shape == "T":
		# A full-width bar along one side, a stem down the middle of the rest.
		var bar := _part(h, 0.4, 0.5)
		var stem := _part(w, 0.35, 0.5)
		var sx := (w - stem) / 2
		if _rand.next() < 0.5:
			_fill(m, 0, bar, sx, h, 0)
			_fill(m, sx + stem, bar, w, h, 0)
		else:
			_fill(m, 0, 0, sx, h - bar, 0)
			_fill(m, sx + stem, 0, w, h - bar, 0)
	elif shape == "U":
		# A courtyard notch cut into one side.
		var nw := mini(w - MIN_ARM * 2, _part(w, 0.3, 0.4))
		var nh := h - _part(h, 0.4, 0.55)
		var nx := (w - nw) / 2
		if _rand.next() < 0.5:
			_fill(m, nx, 0, nx + nw, nh, 0)
		else:
			_fill(m, nx, h - nh, nx + nw, h, 0)
	elif shape == "cross":
		# Two bars crossing: all four corners go.
		var bw := _part(w, 0.35, 0.5)
		var bh := _part(h, 0.4, 0.55)
		var x0 := (w - bw) / 2
		var y0 := (h - bh) / 2
		_fill(m, 0, 0, x0, y0, 0)
		_fill(m, x0 + bw, 0, w, y0, 0)
		_fill(m, 0, y0 + bh, x0, h, 0)
		_fill(m, x0 + bw, y0 + bh, w, h, 0)
	else:
		# Notched: a few bites out of the corners.
		var bites := 1 + _rand.below(3)
		for i in bites:
			var bw := 4 + int(floor(_rand.next() * maxi(1, w / 4 - 3)))
			var bh := 3 + int(floor(_rand.next() * maxi(1, h / 4 - 2)))
			var spot := _rand.below(4)
			var x := w - bw if spot % 2 == 1 else 0
			var y := 0 if spot < 2 else h - bh
			_fill(m, x, y, x + bw, y + bh, 0)
	return m


func _fill(m: PackedByteArray, x0: int, y0: int, x1: int, y1: int, v: int) -> void:
	for y in range(maxi(0, y0), mini(h, y1)):
		for x in range(maxi(0, x0), mini(w, x1)):
			m[y * w + x] = v


## A span between MIN_ARM and a share of the side, never leaving less than
## MIN_ARM of the side on its own.
func _part(side: int, lo: float, hi: float) -> int:
	var a := maxi(MIN_ARM, int(floor(side * lo)))
	var b := mini(side - MIN_ARM, int(floor(side * hi)))
	return a if b <= a else a + int(floor(_rand.next() * (b - a + 1)))


# --- Floor plan ------------------------------------------------------------

## Recursive binary split, stopping when a half would get too cramped.
func _split(r: Rect2i, depth: int) -> Array[Rect2i]:
	var can_h := r.size.y >= MIN_LEAF * 2
	var can_v := r.size.x >= MIN_LEAF * 2
	if depth > 8 or (not can_h and not can_v):
		return [r]

	var horizontal := can_h and (not can_v or _rand.next() < 0.5)
	var out: Array[Rect2i] = []
	if horizontal:
		var cut := MIN_LEAF + int(floor(_rand.next() * (r.size.y - MIN_LEAF * 2 + 1)))
		out.append_array(_split(Rect2i(r.position.x, r.position.y, r.size.x, cut), depth + 1))
		out.append_array(_split(Rect2i(r.position.x, r.position.y + cut, r.size.x, r.size.y - cut), depth + 1))
	else:
		var cut := MIN_LEAF + int(floor(_rand.next() * (r.size.x - MIN_LEAF * 2 + 1)))
		out.append_array(_split(Rect2i(r.position.x, r.position.y, cut, r.size.y), depth + 1))
		out.append_array(_split(Rect2i(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y), depth + 1))
	return out


## Which gallery each tile belongs to, -1 for none.
var _room_of := PackedInt32Array()


## The space the galleries fill: inside the building, off the corridor, and
## one tile back from it — that tile is the wall between corridor and rooms.
func _gallery_space() -> PackedByteArray:
	var space := PackedByteArray()
	space.resize(w * h)
	for y in h:
		for x in w:
			if interior[y * w + x] == 0 or ring[y * w + x] == 1:
				continue
			var by_ring := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if ring[(y + dy) * w + x + dx] == 1:
						by_ring = true
			if not by_ring:
				space[y * w + x] = 1
	return space


## Split the gallery space and turn every piece into a gallery. Each keeps
## its right and bottom edge as the wall it shares with the next one, except
## at the edge of the space, where the wall to the corridor already is.
func _carve_galleries() -> void:
	var space := _gallery_space()
	_room_of = PackedInt32Array()
	_room_of.resize(w * h)
	_room_of.fill(-1)
	var x0 := w
	var y0 := h
	var x1 := 0
	var y1 := 0
	for y in h:
		for x in w:
			if space[y * w + x] == 1:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x + 1)
				y1 = maxi(y1, y + 1)
	if x1 <= x0:
		return
	for leaf in _split(Rect2i(x0, y0, x1 - x0, y1 - y0), 0):
		var rw := leaf.size.x - (0 if leaf.end.x >= x1 else 1)
		var rh := leaf.size.y - (0 if leaf.end.y >= y1 else 1)
		var room := Rect2i(leaf.position, Vector2i(rw, rh))
		var carved: Array[Vector2i] = []
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				if space[y * w + x] == 1:
					carved.append(Vector2i(x, y))
		# Where the outline bites into a piece, a sliver is not a gallery.
		if carved.size() < 6:
			continue
		for t in carved:
			grid[t.y * w + t.x] = Tiles.FLOOR
			_room_of[t.y * w + t.x] = rooms.size()
		rooms.append(room)


## Doors through the walls between galleries, and between a gallery and the
## corridor. Every wall tile with open floor straight across it is a
## candidate, grouped by which two places it joins (the corridor counts as
## one place). First a spanning tree, so everything is reachable; then more
## until every gallery has two doors, on a side it has no door on yet; then
## a few extra, so the building has loops.
func _open_doors() -> void:
	var RING := -2
	var place := func(x: int, y: int) -> int:
		if x < 0 or y < 0 or x >= w or y >= h or grid[y * w + x] != Tiles.FLOOR:
			return -1
		if ring[y * w + x] == 1:
			return RING
		return _room_of[y * w + x]
	# pair key -> [a, b, [[tile, side_of_a, side_of_b], ...]]
	var pairs := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if grid[y * w + x] != Tiles.WALL or interior[y * w + x] == 0:
				continue
			for axis in [Vector2i(1, 0), Vector2i(0, 1)]:
				var a: int = place.call(x - axis.x, y - axis.y)
				var b: int = place.call(x + axis.x, y + axis.y)
				if a == -1 or b == -1 or a == b:
					continue
				var lo := mini(a, b)
				var hi := maxi(a, b)
				var key := "%d:%d" % [lo, hi]
				if not pairs.has(key):
					pairs[key] = [lo, hi, []]
				# The side of the wall each gallery sees the door on.
				var side_a: Vector2i = axis if a == lo else -axis
				pairs[key][2].append([Vector2i(x, y), side_a, -side_a])

	var keys := pairs.keys()
	keys.sort()
	for i in range(keys.size() - 1, 0, -1):
		var j := int(floor(_rand.next() * (i + 1)))
		var tmp = keys[i]
		keys[i] = keys[j]
		keys[j] = tmp

	var parent := {}
	var find := func(n: int, f: Callable) -> int:
		if not parent.has(n) or parent[n] == n:
			parent[n] = n
			return n
		parent[n] = f.call(parent[n], f)
		return parent[n]
	var doors := {}     # gallery -> number of doors
	var sides := {}     # gallery -> {side: true}
	var opened := {}    # pair key -> true
	var open := func(key: String) -> void:
		var p: Array = pairs[key]
		var cands: Array = p[2]
		# Not in a corner: a door in the middle third of the wall where it can.
		var c: Array = cands[int(floor(_rand.next() * cands.size()))]
		if cands.size() >= 3:
			c = cands[cands.size() / 3 + int(floor(_rand.next() * maxi(1, cands.size() / 3)))]
		var t: Vector2i = c[0]
		grid[t.y * w + t.x] = Tiles.FLOOR
		opened[key] = true
		for k in [[p[0], c[1]], [p[1], c[2]]]:
			if k[0] >= 0:
				doors[k[0]] = doors.get(k[0], 0) + 1
				if not sides.has(k[0]):
					sides[k[0]] = {}
				sides[k[0]][k[1]] = true

	# Everything reachable, the corridor included.
	for key in keys:
		var p: Array = pairs[key]
		var ra: int = find.call(p[0], find)
		var rb: int = find.call(p[1], find)
		if ra != rb:
			parent[ra] = rb
			open.call(key)
	# Two doors each, on a new side if there is one.
	for pass_n in 2:
		for key in keys:
			if opened.has(key):
				continue
			var p: Array = pairs[key]
			for end in [[p[0], 1], [p[1], 2]]:
				var room: int = end[0]
				if room < 0 or doors.get(room, 0) >= 2:
					continue
				var side: Vector2i = (pairs[key][2] as Array)[0][end[1]]
				if pass_n == 0 and sides.get(room, {}).has(side):
					continue
				open.call(key)
				break
	# And a few more, so there is more than one way round.
	for key in keys:
		if not opened.has(key) and _rand.next() < 0.2:
			open.call(key)
	# A gallery with a single neighbour gets its second door in that wall.
	for key in keys:
		var p: Array = pairs[key]
		for room in [p[0], p[1]]:
			if room >= 0 and doors.get(room, 0) < 2 and (p[2] as Array).size() >= 3:
				var cands: Array = p[2]
				for c in [cands[0], cands[cands.size() - 1]]:
					var t: Vector2i = c[0]
					if grid[t.y * w + t.x] == Tiles.WALL and doors.get(room, 0) < 2:
						grid[t.y * w + t.x] = Tiles.FLOOR
						doors[room] = doors.get(room, 0) + 1


## Guarantee: every bit of floor can be walked to from the corridor. Any
## pocket left cut off — behind a thick wall in a corner of the outline, or
## boxed in by cases — is joined to the rest by the shortest way through,
## preferring to move a case over cutting a wall. Repeats until nothing is
## left out, so there are no closed spaces, whatever the dice did.
func _link_everything() -> void:
	var start := Vector2i(-1, -1)
	for i in w * h:
		if ring[i] == 1 and grid[i] == Tiles.FLOOR:
			start = Vector2i(i % w, i / w)
			break
	if start.x < 0:
		return
	for attempt in 200:
		var reached := _flood(start, true)
		var lost := Vector2i(-1, -1)
		for i in w * h:
			if grid[i] == Tiles.FLOOR and reached[i] == 0:
				lost = Vector2i(i % w, i / w)
				break
		if lost.x < 0:
			return
		# Cheapest way from the lost pocket to reached floor: floor is free,
		# a case costs 1, a wall 3; only inside the building.
		var cost := PackedInt32Array()
		cost.resize(w * h)
		cost.fill(1 << 30)
		var prev := PackedInt32Array()
		prev.resize(w * h)
		prev.fill(-1)
		var lost_zone := _flood(lost, true)
		var frontier: Array[int] = []
		for i in w * h:
			if lost_zone[i] == 1:
				cost[i] = 0
				frontier.append(i)
		var goal := -1
		while not frontier.is_empty():
			# Small grids: pick the cheapest by scanning.
			var bi := 0
			for k in range(1, frontier.size()):
				if cost[frontier[k]] < cost[frontier[bi]]:
					bi = k
			var cur: int = frontier[bi]
			frontier.remove_at(bi)
			if reached[cur] == 1:
				goal = cur
				break
			for d in DIRS:
				var nx := cur % w + d.x
				var ny := cur / w + d.y
				if nx < 1 or ny < 1 or nx >= w - 1 or ny >= h - 1 or interior[ny * w + nx] == 0:
					continue
				var k := ny * w + nx
				var step := 0 if grid[k] == Tiles.FLOOR else (1 if grid[k] == Tiles.COVER else 3)
				if cost[cur] + step < cost[k]:
					cost[k] = cost[cur] + step
					prev[k] = cur
					if not frontier.has(k):
						frontier.append(k)
		if goal < 0:
			return
		var c := goal
		while c >= 0 and cost[c] > 0:
			grid[c] = Tiles.FLOOR
			c = prev[c]


## Corridor ends that lead nowhere get filled back in: a stub is a place to
## get cornered, not a place to go. Galleries and the circulation corridor
## are left alone.
func _clear_dead_ends() -> void:
	var changed := true
	while changed:
		changed = false
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				if grid[i] != Tiles.FLOOR or ring[i] == 1 or _room_of[i] >= 0:
					continue
				var open := 0
				for d in DIRS:
					if grid[(y + d.y) * w + x + d.x] != Tiles.WALL:
						open += 1
				if open <= 1:
					grid[i] = Tiles.WALL
					changed = true


## Math.round: halves go up, towards +infinity.
static func _js_round(v: float) -> int:
	return int(floor(v + 0.5))


## What is inside a gallery: open, rows of shelving, or an island of cases.
func _furnish_rooms() -> void:
	for room in rooms:
		var roll := _rand.next()
		if roll < 0.35 or room.size.x < 5 or room.size.y < 5:
			continue  # left open
		var rx := room.position.x
		var ry := room.position.y
		if roll < 0.7:
			# Shelving: rows with a gap, never touching the walls.
			var vertical := _rand.next() < 0.5
			if vertical:
				var x := rx + 2
				while x < rx + room.size.x - 2:
					var from := ry + 1 + _rand.below(2)
					var to := ry + room.size.y - 2 - _rand.below(2)
					for y in range(from, to + 1):
						_put(x, y, Tiles.WALL)
					x += 2
			else:
				var y := ry + 2
				while y < ry + room.size.y - 2:
					var from := rx + 1 + _rand.below(2)
					var to := rx + room.size.x - 2 - _rand.below(2)
					for x in range(from, to + 1):
						_put(x, y, Tiles.WALL)
					y += 2
		else:
			# An island in the middle of the floor.
			var cx := int(floor(rx + room.size.x / 2.0))
			var cy := int(floor(ry + room.size.y / 2.0))
			var bw := 1 + _rand.below(2)
			var bh := 1 + _rand.below(2)
			for y in range(cy - bh + 1, cy + 1):
				for x in range(cx - bw + 1, cx + 1):
					_put(x, y, Tiles.WALL)


## Cases to duck behind, mostly against walls and in corners.
func _scatter_cover() -> void:
	var candidates: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if at(x, y) != Tiles.FLOOR:
				continue
			# Keep the circulation corridor clear.
			if ring[y * w + x] == 1:
				continue
			var walls := 0
			for d in DIRS:
				if at(x + d.x, y + d.y) == Tiles.WALL:
					walls += 1
			# Never plug a corridor: walls on opposite sides mean the only way through.
			var pinch := (at(x, y - 1) == Tiles.WALL and at(x, y + 1) == Tiles.WALL) \
				or (at(x - 1, y) == Tiles.WALL and at(x + 1, y) == Tiles.WALL)
			if pinch or walls > 2:
				continue
			# Not in front of a door: a case there turns the door into a wall.
			var at_door := false
			for d in DIRS:
				var nx := x + d.x
				var ny := y + d.y
				if at(nx, ny) == Tiles.FLOOR and ((at(nx, ny - 1) == Tiles.WALL and at(nx, ny + 1) == Tiles.WALL) or (at(nx - 1, ny) == Tiles.WALL and at(nx + 1, ny) == Tiles.WALL)):
					at_door = true
			if at_door:
				continue
			candidates.append(Vector2i(x, y))

	var wanted := _js_round(candidates.size() * 0.14)
	var placed := 0
	var i := candidates.size() - 1
	while i > 0 and placed < wanted:
		var j := int(floor(_rand.next() * (i + 1)))
		var tmp := candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
		var c := candidates[i]
		i -= 1
		if at(c.x, c.y) != Tiles.FLOOR:
			continue
		_put(c.x, c.y, Tiles.COVER)
		placed += 1


## First tile, scanning rows, that is floor (floor_only) or anything but wall.
func _first_tile(floor_only: bool) -> Vector2i:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var t := at(x, y)
			if (t == Tiles.FLOOR) if floor_only else (t != Tiles.WALL):
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## Flood fill over floor (floor_only) or anything but wall. 1 = reached.
func _flood(from: Vector2i, floor_only: bool) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen[from.y * w + from.x] = 1
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in DIRS:
			var n := c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
				continue
			var t := at(n.x, n.y)
			if not ((t == Tiles.FLOOR) if floor_only else (t != Tiles.WALL)):
				continue
			if seen[n.y * w + n.x] == 1:
				continue
			seen[n.y * w + n.x] = 1
			queue.append(n)
	return seen


## Drop the player on the corridor along the outer wall.
func _pick_spawn() -> Vector2i:
	var best: Array[Vector2i] = []
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if at(x, y) == Tiles.FLOOR and ring[y * w + x] == 1:
				best.append(Vector2i(x, y))
	if best.is_empty():
		var f := _first_tile(true)
		return f if f.x >= 0 else Vector2i(1, 1)
	return best[int(floor(_rand.next() * best.size()))]
