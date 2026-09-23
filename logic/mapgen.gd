class_name MapGen
extends RefCounted
## Museum generator: a line-by-line port of the web version's mapgen.ts.
##
## First the building: a footprint of any size, and not only a rectangle — an
## L, a T, a U, a cross, or a block with bites taken out of it. Everything
## after is carved inside that footprint and nowhere else. Then the floor
## plan: split by binary space partition, each leaf gets a gallery, a block of
## shelving or open floor, and corridors join them back up. A circulation
## corridor runs just inside the outer wall, whatever its shape.
##
## Same seed, same museum as the web: every call to the PRNG happens in the
## same order as there. tests/test_mapgen.gd holds it to that.
##
## The grid is flat — index y * w + x — because packed arrays nested inside an
## Array are copied on write in GDScript, and grid[y][x] = v would change a
## copy.

const SHAPES: Array[String] = ["rect", "L", "T", "U", "cross", "notched"]
const MIN_LEAF := 6
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

	var leaves := _split(Rect2i(1, 1, w - 2, h - 2), 0)
	for leaf in leaves:
		var room := _carve_room(leaf)
		if room.size.x > 0:
			rooms.append(room)

	# Join rooms in sequence, plus one extra link, so there is always a way
	# round rather than a single spine everyone has to share.
	for i in range(1, rooms.size()):
		_corridor(_centre(rooms[i - 1]), _centre(rooms[i]))
	if rooms.size() > 2:
		_corridor(_centre(rooms[0]), _centre(rooms[rooms.size() - 1]))

	for i in w * h:
		if ring[i] == 1:
			grid[i] = Tiles.FLOOR
	for room in rooms:
		_door_to_ring(room)

	_connect()
	_furnish_rooms()
	_scatter_cover()
	_clear_blocked_furniture()

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


func _centre(r: Rect2i) -> Vector2i:
	return Vector2i(int(floor(r.position.x + r.size.x / 2.0)), int(floor(r.position.y + r.size.y / 2.0)))


## Inside the outer wall, and not on the corridor that runs along it.
func _buildable(x: int, y: int) -> bool:
	return x > 0 and y > 0 and x < w - 1 and y < h - 1 and interior[y * w + x] == 1 and ring[y * w + x] == 0


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h and interior[y * w + x] == 1


## A gallery inside a leaf, with a one-tile margin. Its floor must be inside
## the building and off the corridor along the outer wall; its walls may be
## that corridor. Smaller rooms are tried before the leaf is given up on.
## Returns an empty Rect2i when nothing fits.
func _carve_room(leaf: Rect2i) -> Rect2i:
	var max_w := leaf.size.x - 2
	var max_h := leaf.size.y - 2
	if max_w < 3 or max_h < 3:
		return Rect2i()

	for attempt in 8:
		# Start at nearly the whole leaf, then shrink towards the minimum.
		var shrink := attempt / 7.0
		var rw := maxi(3, _js_round(max_w - int(floor(_rand.next() * 2)) - (max_w - 3) * shrink))
		var rh := maxi(3, _js_round(max_h - int(floor(_rand.next() * 2)) - (max_h - 3) * shrink))
		var x := leaf.position.x + 1 + int(floor(_rand.next() * (max_w - rw + 1)))
		var y := leaf.position.y + 1 + int(floor(_rand.next() * (max_h - rh + 1)))

		var fits := true
		for j in range(y - 1, y + rh + 1):
			for i in range(x - 1, x + rw + 1):
				if not fits:
					break
				var wall := j == y - 1 or j == y + rh or i == x - 1 or i == x + rw
				if (not _inside(i, j)) if wall else (not _buildable(i, j)):
					fits = false
		if not fits:
			continue

		for j in range(y, y + rh):
			for i in range(x, x + rw):
				_put(i, j, Tiles.FLOOR)
		return Rect2i(x, y, rw, rh)
	return Rect2i()


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


## Doors from a room out to open floor, on some sides, only where the walk
## out stays inside the building and gets somewhere in a few steps.
func _door_to_ring(room: Rect2i) -> void:
	var rx := room.position.x
	var ry := room.position.y
	var rw := room.size.x
	var rh := room.size.y
	# Built one after another, in this order, as in the web version: each
	# entry draws its random offset in turn.
	var sides: Array[Array] = []
	sides.append([rx + _rand.below(rw), ry - 1, 0, -1])
	sides.append([rx + _rand.below(rw), ry + rh, 0, 1])
	sides.append([rx - 1, ry + _rand.below(rh), -1, 0])
	sides.append([rx + rw, ry + _rand.below(rh), 1, 0])
	var chosen: Array[Array] = []
	for s in sides:
		if _rand.next() < 0.5:
			chosen.append(s)
	if chosen.is_empty():
		chosen.append(sides[0])

	for s in chosen:
		var walk: Array[Vector2i] = []
		var x: int = s[0]
		var y: int = s[1]
		var reached := false
		for step in 8:
			if x < 0 or y < 0 or x >= w or y >= h or interior[y * w + x] == 0:
				break
			walk.append(Vector2i(x, y))
			if ring[y * w + x] == 1 or (step > 0 and at(x, y) == Tiles.FLOOR):
				reached = true
				break
			x += s[2]
			y += s[3]
		if reached:
			for t in walk:
				_put(t.x, t.y, Tiles.FLOOR)


## L-shaped corridor between two points, inside the building.
func _corridor(a: Vector2i, b: Vector2i) -> void:
	var horizontal_first := _rand.next() < 0.5
	if horizontal_first:
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			_dig(x, a.y)
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			_dig(b.x, y)
	else:
		for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
			_dig(a.x, y)
		for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
			_dig(x, b.y)


func _dig(x: int, y: int) -> void:
	if interior[y * w + x] == 1:
		_put(x, y, Tiles.FLOOR)


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


## Clear any furniture that stranded part of the map.
func _clear_blocked_furniture() -> void:
	for pass_n in 12 + (w * h) / 150:
		var start := _first_tile(true)
		if start.x < 0:
			return
		var seen := _flood(start, true)
		var stranded: Array[Vector2i] = []
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if at(x, y) == Tiles.FLOOR and seen[y * w + x] == 0:
					stranded.append(Vector2i(x, y))
		if stranded.is_empty():
			return
		var opened := false
		for s in stranded:
			for d in DIRS:
				var f := s + d
				if f.x < 0 or f.y < 0 or f.x >= w or f.y >= h or at(f.x, f.y) != Tiles.COVER:
					continue
				_put(f.x, f.y, Tiles.FLOOR)
				opened = true
				break
			if opened:
				break
		if not opened:
			return


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


## Carve back until everything is reachable, inside the building.
func _connect() -> void:
	for attempt in 80 + (w * h) / 20:
		var start := _first_tile(false)
		if start.x < 0:
			return
		var seen := _flood(start, false)
		var stranded: Array[Vector2i] = []
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				if at(x, y) != Tiles.WALL and seen[y * w + x] == 0:
					stranded.append(Vector2i(x, y))
		if stranded.is_empty():
			return

		var s := stranded[int(floor(_rand.next() * stranded.size()))]
		var opened := false
		for d in DIRS:
			var b := s + d * 2
			if b.x < 1 or b.y < 1 or b.x > w - 2 or b.y > h - 2:
				continue
			var m := s + d
			if at(m.x, m.y) == Tiles.WALL and interior[m.y * w + m.x] == 1 and seen[b.y * w + b.x] == 1:
				_put(m.x, m.y, Tiles.FLOOR)
				opened = true
				break
		if not opened:
			for d in DIRS:
				var m := s + d
				if interior[m.y * w + m.x] == 1:
					_put(m.x, m.y, Tiles.FLOOR)


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
