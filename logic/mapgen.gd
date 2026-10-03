class_name MapGen
extends RefCounted
## Museum generator.
##
## First the building: a footprint of any size, and not only a rectangle — an
## L, a T, a U, a cross, or a block with bites taken out of it.
##
## Then the plan, packed like a real museum and with no corridor running
## round the edge: the whole inside is split by binary space partition,
## wall to wall, and the pieces become galleries of every size — the odd big
## hall, long narrow rooms, small cabinets — side by side with a single wall
## between. Now and then a split leaves a short passage instead of a wall,
## one or two tiles wide and never longer than a room: the only corridors
## there are. Doors go through the walls: first enough to reach everything,
## then more until every gallery and passage has at least two, on different
## sides where it can, then a few extra so there is always another way
## round. A gallery with one way in is a trap, not a hiding place.
##
## Then the disorder: galleries opened into each other along part or all of
## a wall (L-shaped halls, suites of rooms), a few crooked shortcuts through
## the walls, columns, shelving, partitions and islands inside. After all of
## it, the guarantees are re-established: everything reachable, no dead ends.
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
## Every shape keeps its arms at least this wide, so a gallery always fits.
const MIN_ARM := 9
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAGONALS: Array[Vector2i] = [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
## The pieces that take more than one tile, in tiles across and along (the
## table is BigPieces.SIZES, data only).
const BIG := BigPieces.SIZES

var w: int
var h: int
var grid: PackedInt32Array
## inside the outer wall: the only tiles that may ever be carved
var interior: PackedByteArray
## floor right against the outer wall: where you can come in from outside
var ring: PackedByteArray
## 1 where there is no building at all
var outside: PackedByteArray
## galleries as Rect2i
var rooms: Array[Rect2i] = []
var spawn: Vector2i
## the big pieces, each on a block of COVER: {"kind": ..., "rect": Rect2i}
var big: Array[Dictionary] = []
var _rand: Mulberry32
## the one theme the museum shows ("" any): which big pieces it may have
var theme := ""


## Build a museum. Read the result from grid, rooms, spawn, outside and ring.
## only: a museum of one theme (Museum.only_theme) gets only the big
## pieces of that theme, if it has any; "" all of them.
static func generate(seed: int, width: int, height: int, shape: String, only := "") -> MapGen:
	var g := MapGen.new()
	g.theme = only
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

	ring = PackedByteArray()
	ring.resize(w * h)

	# Start solid and carve.
	grid = PackedInt32Array()
	grid.resize(w * h)
	grid.fill(Tiles.WALL)

	_carve_galleries()
	_open_doors()
	_shortcuts()
	_furnish_rooms()
	_scatter_cover()
	_link_everything()
	_clear_dead_ends()
	_keep_galleries()
	_clear_wall_crumbs()
	_unpinch_cases()

	# The way in: floor against the outer wall.
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if grid[y * w + x] != Tiles.FLOOR:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if interior[(y + dy) * w + x + dx] == 0:
						ring[y * w + x] = 1

	_big_pieces(seed)

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
	# Pieces the outline runs through are first cut along the outline, so
	# every piece is either inside the building or out of it: no slivers.
	var mixed := _outline_cut(r)
	if mixed.size() == 1 and mixed[0] == Rect2i():
		return []
	if mixed.size() == 2:
		var parts: Array[Rect2i] = []
		parts.append_array(_split(mixed[0], depth))
		parts.append_array(_split(mixed[1], depth))
		return parts
	var can_h := r.size.y >= MIN_LEAF * 2
	var can_v := r.size.x >= MIN_LEAF * 2
	if depth > 8 or (not can_h and not can_v):
		return [r]
	# Now and then a piece is left whole: the big halls that break the grid.
	var area := r.size.x * r.size.y
	if depth >= 2 and area <= 140 and _rand.next() < 0.25:
		return [r]

	# Cut across the long side, mostly: long thin galleries read as corridors
	# of rooms, not as a grid. Square pieces go either way.
	var horizontal: bool
	if can_h and not can_v:
		horizontal = true
	elif can_v and not can_h:
		horizontal = false
	elif r.size.y > r.size.x * 1.3:
		horizontal = _rand.next() < 0.85
	elif r.size.x > r.size.y * 1.3:
		horizontal = _rand.next() < 0.15
	else:
		horizontal = _rand.next() < 0.5
	var side := r.size.y if horizontal else r.size.x
	# Anywhere in the allowed range, skewed off the middle half the time.
	var t := _rand.next()
	if _rand.next() < 0.5:
		t = t * t if _rand.next() < 0.5 else 1.0 - (1.0 - t) * (1.0 - t)
	var cut := MIN_LEAF + int(floor(t * (side - MIN_LEAF * 2 + 1)))
	var out: Array[Rect2i] = []
	# Sometimes a short passage between the halves instead of a wall: only
	# where the cut is short, so corridors never run the length of the building.
	var across := r.size.x if horizontal else r.size.y
	var pw := 2 + _rand.below(2)
	if across <= 14 and side >= MIN_LEAF * 2 + pw and _rand.next() < 0.3:
		cut = MIN_LEAF + int(floor(_rand.next() * (side - MIN_LEAF * 2 - pw + 1)))
		if horizontal:
			out.append_array(_split(Rect2i(r.position.x, r.position.y, r.size.x, cut), depth + 1))
			_halls.append(Rect2i(r.position.x, r.position.y + cut, r.size.x, pw))
			out.append_array(_split(Rect2i(r.position.x, r.position.y + cut + pw, r.size.x, r.size.y - cut - pw), depth + 1))
		else:
			out.append_array(_split(Rect2i(r.position.x, r.position.y, cut, r.size.y), depth + 1))
			_halls.append(Rect2i(r.position.x + cut, r.position.y, pw, r.size.y))
			out.append_array(_split(Rect2i(r.position.x + cut + pw, r.position.y, r.size.x - cut - pw, r.size.y), depth + 1))
		return out
	if horizontal:
		out.append_array(_split(Rect2i(r.position.x, r.position.y, r.size.x, cut), depth + 1))
		out.append_array(_split(Rect2i(r.position.x, r.position.y + cut, r.size.x, r.size.y - cut), depth + 1))
	else:
		out.append_array(_split(Rect2i(r.position.x, r.position.y, cut, r.size.y), depth + 1))
		out.append_array(_split(Rect2i(r.position.x + cut, r.position.y, r.size.x - cut, r.size.y), depth + 1))
	return out


## A piece with no inside at all: [Rect2i()]. A piece the outline runs
## through: the two halves of a cut along it. Otherwise nothing.
func _outline_cut(r: Rect2i) -> Array[Rect2i]:
	var inside := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			inside += interior[y * w + x]
	if inside == 0:
		return [Rect2i()]
	if inside == r.size.x * r.size.y:
		return []
	var cuts: Array = []
	for c in range(1, r.size.y):
		for x in range(r.position.x, r.end.x):
			if interior[(r.position.y + c - 1) * w + x] != interior[(r.position.y + c) * w + x]:
				cuts.append([true, c])
				break
	for c in range(1, r.size.x):
		for y in range(r.position.y, r.end.y):
			if interior[y * w + r.position.x + c - 1] != interior[y * w + r.position.x + c]:
				cuts.append([false, c])
				break
	var pick: Array = cuts[int(floor(_rand.next() * cuts.size()))]
	var c: int = pick[1]
	if pick[0]:
		return [Rect2i(r.position.x, r.position.y, r.size.x, c), Rect2i(r.position.x, r.position.y + c, r.size.x, r.size.y - c)]
	return [Rect2i(r.position.x, r.position.y, c, r.size.y), Rect2i(r.position.x + c, r.position.y, r.size.x - c, r.size.y)]


## Is there inside on the far side of this piece's right (or bottom) edge?
## Only then does it keep that edge as a wall to share.
func _needs_wall(leaf: Rect2i, right: bool) -> bool:
	if right:
		if leaf.end.x >= w:
			return false
		for y in range(leaf.position.y, leaf.end.y):
			if interior[y * w + leaf.end.x] == 1:
				return true
		return false
	if leaf.end.y >= h:
		return false
	for x in range(leaf.position.x, leaf.end.x):
		if interior[leaf.end.y * w + x] == 1:
			return true
	return false


## Which place (gallery or passage) each tile belongs to, -1 for none.
var _room_of := PackedInt32Array()
## passages left by the split, before they are carved
var _halls: Array[Rect2i] = []
## every place carved, and whether it is a passage rather than a gallery
var _places: Array[Rect2i] = []
var _is_hall: Array[bool] = []


## Split the inside and turn every piece into a gallery or a passage. Each
## keeps its right and bottom edge as the wall it shares with the next one,
## except at the edge, where the outer wall already is.
func _carve_galleries() -> void:
	_room_of = PackedInt32Array()
	_room_of.resize(w * h)
	_room_of.fill(-1)
	var x0 := w
	var y0 := h
	var x1 := 0
	var y1 := 0
	for y in h:
		for x in w:
			if interior[y * w + x] == 1:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x + 1)
				y1 = maxi(y1, y + 1)
	if x1 <= x0:
		return
	_halls.clear()
	var leaves := _split(Rect2i(x0, y0, x1 - x0, y1 - y0), 0)
	var all: Array = []
	for leaf in leaves:
		all.append([leaf, false])
	for hall in _halls:
		all.append([hall, true])
	for item in all:
		var leaf: Rect2i = item[0]
		var rw := leaf.size.x - (1 if _needs_wall(leaf, true) else 0)
		var rh := leaf.size.y - (1 if _needs_wall(leaf, false) else 0)
		var room := Rect2i(leaf.position, Vector2i(rw, rh))
		var carved: Array[Vector2i] = []
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				if interior[y * w + x] == 1:
					carved.append(Vector2i(x, y))
		# Where the outline bites into a piece, a sliver is not a place.
		if carved.size() < (3 if item[1] else 6):
			continue
		for t in carved:
			grid[t.y * w + t.x] = Tiles.FLOOR
			_room_of[t.y * w + t.x] = _places.size()
		_places.append(room)
		_is_hall.append(item[1])
	rooms = _places


## At the end, only the galleries are rooms: passages are corridor floor.
func _keep_galleries() -> void:
	var remap := PackedInt32Array()
	var kept: Array[Rect2i] = []
	for i in _places.size():
		remap.append(-1 if _is_hall[i] else kept.size())
		if not _is_hall[i]:
			kept.append(_places[i])
	for i in w * h:
		if _room_of[i] >= 0:
			_room_of[i] = remap[_room_of[i]]
	rooms = kept


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
	# Open plan: some neighbours are opened into each other along a stretch
	# of their wall, and the corridor breaks into some galleries the same
	# way — L-shaped spaces, alcoves, a ragged edge instead of a frame.
	for key in keys:
		var p: Array = pairs[key]
		if p[0] < 0 or p[1] < 0 or _is_hall[p[0]] or _is_hall[p[1]]:
			continue
		if (p[2] as Array).size() < 3 or _rand.next() >= 0.28:
			continue
		var cands: Array = p[2]
		var n := cands.size()
		# Part of the wall, or all of it: two galleries become one hall.
		var run := n if _rand.next() < 0.35 else maxi(2, int(n * (0.3 + _rand.next() * 0.5)))
		var from := int(floor(_rand.next() * (n - run + 1)))
		for k in range(from, from + run):
			var t: Vector2i = cands[k][0]
			grid[t.y * w + t.x] = Tiles.FLOOR
		opened[key] = true
		for room in [p[0], p[1]]:
			if room >= 0:
				doors[room] = doors.get(room, 0) + 2
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


## A few passages cut through the walls from one gallery to another far off:
## straight across, then straight along (an L), so each wall they cross gets
## one clean opening instead of a staircase of bites.
func _shortcuts() -> void:
	if rooms.size() < 3:
		return
	for k in rooms.size() / 9:
		var a: Rect2i = rooms[int(floor(_rand.next() * rooms.size()))]
		var b: Rect2i = rooms[int(floor(_rand.next() * rooms.size()))]
		var p := Vector2i(a.position.x + int(floor(_rand.next() * a.size.x)), a.position.y + int(floor(_rand.next() * a.size.y)))
		var q := Vector2i(b.position.x + int(floor(_rand.next() * b.size.x)), b.position.y + int(floor(_rand.next() * b.size.y)))
		if absi(p.x - q.x) + absi(p.y - q.y) < 8:
			continue
		var steps := 0
		var x_first := _rand.next() < 0.5
		while p != q and steps < 200:
			steps += 1
			var d := Vector2i(signi(q.x - p.x), signi(q.y - p.y))
			var along_x := d.y == 0 or (d.x != 0 and x_first)
			var step := Vector2i(d.x, 0) if along_x else Vector2i(0, d.y)
			var n := p + step
			if n.x < 1 or n.y < 1 or n.x >= w - 1 or n.y >= h - 1 or interior[n.y * w + n.x] == 0:
				continue
			p = n
			if grid[p.y * w + p.x] == Tiles.WALL:
				grid[p.y * w + p.x] = Tiles.FLOOR


## Guarantee: every bit of floor can be walked to from the corridor. Any
## pocket left cut off — behind a thick wall in a corner of the outline, or
## boxed in by cases — is joined to the rest by the shortest way through,
## preferring to move a case over cutting a wall. Repeats until nothing is
## left out, so there are no closed spaces, whatever the dice did.
func _link_everything() -> void:
	var start := Vector2i(-1, -1)
	for i in w * h:
		if grid[i] == Tiles.FLOOR:
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
## get cornered, not a place to go. Passages are trimmed back to their
## doors the same way; galleries are left alone.
func _clear_dead_ends() -> void:
	var changed := true
	while changed:
		changed = false
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				if grid[i] != Tiles.FLOOR or (_room_of[i] >= 0 and not _is_hall[_room_of[i]]):
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
	for i in _places.size():
		if _is_hall[i]:
			continue
		var room := _places[i]
		var rx := room.position.x
		var ry := room.position.y
		var rw := room.size.x
		var rh := room.size.y
		if rw < 5 or rh < 5:
			continue
		var roll := _rand.next()
		if roll < 0.25:
			continue  # left open
		if roll < 0.5:
			# Shelving: runs of shelf with gaps, at uneven spacing, never
			# touching the walls so the edge of the room stays walkable.
			var vertical := rw > rh if _rand.next() < 0.7 else _rand.next() < 0.5
			var across := rw if vertical else rh
			var along := rh if vertical else rw
			var line := 2
			while line < across - 2:
				var a := 1 + _rand.below(2)
				var b := along - 2 - _rand.below(2)
				# The gap leaves at least two tiles of shelf on each side: a
				# shelf tile standing alone is drawn as a column (MapFile.exempt_walls).
				var gap := a + 2 + _rand.below(b - a - 3) if b - a >= 4 else -1
				if b - a < 1:
					line += 2 + _rand.below(2)
					continue
				for k in range(a, b + 1):
					if k == gap:
						continue
					if vertical:
						_furnish_wall(rx + line, ry + k)
					else:
						_furnish_wall(rx + k, ry + line)
				line += 2 + _rand.below(2)
		elif roll < 0.7 and _colonnade(room):
			pass
		elif roll < 0.85:
			# A partition jutting in from one wall, making a nook.
			var side := _rand.below(4)
			var len := 2 + _rand.below(maxi(1, mini(rw, rh) - 3))
			var tiles: Array[Vector2i] = []
			if side < 2:
				var x := rx + 2 + _rand.below(maxi(1, rw - 4))
				for k in len:
					tiles.append(Vector2i(x, ry + k if side == 0 else ry + rh - 1 - k))
			else:
				var y := ry + 2 + _rand.below(maxi(1, rh - 4))
				for k in len:
					tiles.append(Vector2i(rx + k if side == 2 else rx + rw - 1 - k, y))
			# Never across a doorway.
			if tiles.all(func(t): return not _by_door(t, room)):
				for t in tiles:
					_furnish_wall(t.x, t.y)
		else:
			# An island in the middle of the floor, off-centre.
			var cx := rx + 1 + _rand.below(maxi(1, rw - 3))
			var cy := ry + 1 + _rand.below(maxi(1, rh - 3))
			var bw := 1 + _rand.below(2)
			var bh := 1 + _rand.below(2)
			# Never a single tile: on its own it would be drawn as a column.
			if bw == 1 and bh == 1:
				bh = 2
			for y in range(cy, mini(cy + bh, ry + rh - 1)):
				for x in range(cx, mini(cx + bw, rx + rw - 1)):
					_furnish_wall(x, y)


## Columns are structure, not exhibits, so they keep a builder's rhythm: a
## tile of floor between a column and any wall, three tiles from one column
## to the next along a row, rows a regular grid, never a column skipped.
const COLUMN_MARGIN := 1
const COLUMN_STEP := 3
## Rows of columns across a gallery: two (a nave between two aisles) up to
## this width; wider than that, three when a middle row lands dead centre.
const COLUMN_THREE_ROWS_FROM := 12


## Rows of columns down the long axis of a gallery, every row the same
## rhythm and the rows on one grid. Nothing at all if a full, regular grid
## does not fit (a lone column reads as one more exhibit): the long side
## needs 6 tiles for two columns, the short side 5 for one row down the
## middle. Returns whether anything was placed.
func _colonnade(room: Rect2i) -> bool:
	var vertical := room.size.y > room.size.x
	var along := room.size.y if vertical else room.size.x
	var across := room.size.x if vertical else room.size.y
	var line := _rhythm(along, COLUMN_STEP, 2)
	var rows := _row_offsets(across)
	if line.is_empty() or rows.is_empty():
		return false
	var tiles: Array[Vector2i] = []
	for r in rows:
		for k in line:
			tiles.append(room.position + (Vector2i(r, k) if vertical else Vector2i(k, r)))
	# Where the outline bites into the room some of its rect is still wall:
	# a column there, or against it, breaks the margin, and a grid with one
	# missing is no grid — so the room goes without.
	for t in tiles:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if at(t.x + dx, t.y + dy) != Tiles.FLOOR:
					return false
	for t in tiles:
		_furnish_wall(t.x, t.y)
	return true


## Offsets along a side of `len` tiles for as many columns as fit at `step`
## with COLUMN_MARGIN free at both ends, centred so the two margins come out
## as equal as they can; empty with fewer than `at_least`.
static func _rhythm(len: int, step: int, at_least: int) -> Array[int]:
	var span := len - 2 * COLUMN_MARGIN - 1
	if span < 0:
		return []
	var n := span / step + 1
	if n < at_least:
		return []
	var start := COLUMN_MARGIN + (span - (n - 1) * step) / 2
	var out: Array[int] = []
	for i in n:
		out.append(start + i * step)
	return out


## Where the rows go across a gallery `len` tiles wide: one down the middle
## of a 5-wide room; from 6 up, one along each wall (COLUMN_MARGIN in), and
## a third in the middle only in a wide room where the middle is a tile.
static func _row_offsets(len: int) -> Array[int]:
	if len < 2 * COLUMN_MARGIN + 3:
		return []
	var first := COLUMN_MARGIN
	var last := len - 1 - COLUMN_MARGIN
	var out: Array[int] = []
	if last - first < COLUMN_STEP:
		if len % 2 == 1:
			out.append(len / 2)
	elif len >= COLUMN_THREE_ROWS_FROM and (first + last) % 2 == 0 and (last - first) / 2 >= COLUMN_STEP:
		out.assign([first, (first + last) / 2, last])
	else:
		out.assign([first, last])
	return out


## Wall a gallery is furnished with (shelving, columns, a partition, an
## island): meant to stand on its own, so never cleared as a crumb.
var _furniture := {}


func _furnish_wall(x: int, y: int) -> void:
	_put(x, y, Tiles.WALL)
	_furniture[Vector2i(x, y)] = true


## Bits of wall left standing on their own — one or two tiles, off the outer
## wall and not furniture — where doors, openings and passages were cut round
## them: they read as rubble on the plan, so they go.
func _clear_wall_crumbs() -> void:
	var seen := {}
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var t := Vector2i(x, y)
			if at(x, y) != Tiles.WALL or interior[y * w + x] == 0 or seen.has(t):
				continue
			# The bit of wall this tile is part of, as far as three tiles.
			var bit: Array[Vector2i] = [t]
			seen[t] = true
			var k := 0
			var outer := false
			while k < bit.size() and bit.size() <= 3:
				var c := bit[k]
				k += 1
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := Vector2i(c.x + dx, c.y + dy)
						if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or interior[n.y * w + n.x] == 0:
							outer = true
				for d in DIRS:
					var n := c + d
					if n.x < 1 or n.y < 1 or n.x >= w - 1 or n.y >= h - 1 or interior[n.y * w + n.x] == 0:
						continue
					if at(n.x, n.y) == Tiles.WALL and not seen.has(n):
						seen[n] = true
						bit.append(n)
			# One tile with no wall on any side is never the outer wall nor
			# furniture worth the name, whatever touches its corners: it would
			# be drawn as a column, and a column stands clear of walls — so
			# with wall at a corner it is a leftover (a partition's stump, a
			# filled-in dead end) and goes.
			var lone := bit.size() == 1 and DIRS.all(func(d): return at(t.x + d.x, t.y + d.y) != Tiles.WALL)
			var cornered := lone and DIAGONALS.any(func(d): return at(t.x + d.x, t.y + d.y) == Tiles.WALL)
			if (outer or bit.size() > 2 or bit.any(func(b): return _furniture.has(b))) and not cornered:
				continue
			# Only if the floor it leaves has two ways out: a crumb touching the
			# floor at one side or just at a corner would become a stub.
			if not bit.all(func(b): return _open_sides(b, bit) >= 2):
				continue
			for b in bit:
				_put(b.x, b.y, Tiles.FLOOR)


## Sides of t with floor to walk on (a case is no way out), counting the
## rest of `bit` as cleared.
func _open_sides(t: Vector2i, bit: Array[Vector2i]) -> int:
	var n := 0
	for d in DIRS:
		if at(t.x + d.x, t.y + d.y) == Tiles.FLOOR or bit.has(t + d):
			n += 1
	return n


## Is this tile of the room just inside an opening in its wall?
func _by_door(t: Vector2i, room: Rect2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = t + d
		if not room.has_point(n) and grid[n.y * w + n.x] != Tiles.WALL:
			return true
	return false


## A case never stands between two walls (left and right, or above and
## below). _scatter_cover keeps to that, but the steps after it put walls
## down too: once the plan is done the cases are looked at again, and one
## caught between two walls goes (floor never shuts a way).
func _unpinch_cases() -> void:
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if at(x, y) == Tiles.COVER and pinched(x, y):
				_put(x, y, Tiles.FLOOR)


## Walls on two opposite sides of the tile: above and below, or left and right.
func pinched(x: int, y: int) -> bool:
	return (at(x, y - 1) == Tiles.WALL and at(x, y + 1) == Tiles.WALL) \
		or (at(x - 1, y) == Tiles.WALL and at(x + 1, y) == Tiles.WALL)


## Cases the way a museum sets them out, one plan to a gallery: along its
## walls at even steps, in rows down its length, an island in its middle, or
## a few here and there. Each plan is centred on the room, so a gallery reads
## as laid out rather than strewn; a case goes only where one may (_case_spot).
func _scatter_cover() -> void:
	for i in _places.size():
		if _is_hall[i]:
			continue
		var r := _places[i]
		var roll := _rand.next()
		var spots: Array[Vector2i]
		if roll < 0.35:
			spots = _cases_along_walls(r)
		elif roll < 0.6:
			spots = _cases_in_rows(r)
		elif roll < 0.8:
			spots = _cases_island(r)
		else:
			spots = _cases_here_and_there(r, i)
		for t in spots:
			if _case_spot(t.x, t.y, i):
				_put(t.x, t.y, Tiles.COVER)


## Against the walls, every CASE_STEP tiles, the same from both ends; never
## in a corner.
const CASE_STEP := 3


func _cases_along_walls(r: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in _even_steps(r.position.x + 1, r.end.x - 2, CASE_STEP):
		out.append(Vector2i(x, r.position.y))
		out.append(Vector2i(x, r.end.y - 1))
	for y in _even_steps(r.position.y + 1, r.end.y - 2, CASE_STEP):
		out.append(Vector2i(r.position.x, y))
		out.append(Vector2i(r.end.x - 1, y))
	return out


## One row down the middle of the room's length, or two in a wide room, a
## case every other tile, with a way round every row.
func _cases_in_rows(r: Rect2i) -> Array[Vector2i]:
	var along_x := r.size.x >= r.size.y
	var across := r.size.y if along_x else r.size.x
	var length := r.size.x if along_x else r.size.y
	if across < 5 or length < 5:
		return _cases_along_walls(r)
	var lines: Array[int] = []
	if across < 8:
		lines.append(across / 2)
	else:
		lines.append_array([across / 3, across - 1 - across / 3])
	var out: Array[Vector2i] = []
	for l in lines:
		for k in _even_steps(2, length - 3, 2):
			out.append(r.position + (Vector2i(k, l) if along_x else Vector2i(l, k)))
	return out


## A block of cases in the middle of the room: two by two, or longer in a
## long room, a single one in a small room.
func _cases_island(r: Rect2i) -> Array[Vector2i]:
	var bw := 1 if r.size.x < 6 else (3 if r.size.x >= 9 and r.size.x > r.size.y else 2)
	var bh := 1 if r.size.y < 6 else (3 if r.size.y >= 9 and r.size.y > r.size.x else 2)
	var x0 := r.position.x + (r.size.x - bw) / 2
	var y0 := r.position.y + (r.size.y - bh) / 2
	var out: Array[Vector2i] = []
	for y in range(y0, y0 + bh):
		for x in range(x0, x0 + bw):
			out.append(Vector2i(x, y))
	return out


## A few cases where they fall, as the generator always did: about one spot
## in seven of those a case may take.
func _cases_here_and_there(r: Rect2i, room: int) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if _case_spot(x, y, room):
				spots.append(Vector2i(x, y))
	for i in range(spots.size() - 1, 0, -1):
		var j := int(floor(_rand.next() * (i + 1)))
		var tmp := spots[i]
		spots[i] = spots[j]
		spots[j] = tmp
	return spots.slice(0, _js_round(spots.size() * 0.14))


## From a to b, every `step`, centred between them: the same gap at both ends.
static func _even_steps(a: int, b: int, step: int) -> Array[int]:
	var out: Array[int] = []
	if b < a:
		return out
	var n := (b - a) / step + 1
	var first := a + ((b - a) - (n - 1) * step) / 2
	for k in n:
		out.append(first + k * step)
	return out


## Whether a case may stand here, in gallery `room`: on its floor, off the
## corridor along the outer wall, not just inside a doorway nor in front of
## one, not between two walls, with no more than two walls round it.
func _case_spot(x: int, y: int, room: int) -> bool:
	if x < 1 or y < 1 or x >= w - 1 or y >= h - 1 or at(x, y) != Tiles.FLOOR:
		return false
	if ring[y * w + x] == 1 or _room_of[y * w + x] != room or _is_hall[room]:
		return false
	if _by_door(Vector2i(x, y), _places[room]):
		return false
	var walls := 0
	for d in DIRS:
		if at(x + d.x, y + d.y) == Tiles.WALL:
			walls += 1
	# Never plug a corridor: walls on opposite sides mean the only way through.
	if pinched(x, y) or walls > 2:
		return false
	# Not in front of a door: a case there turns the door into a wall.
	for d in DIRS:
		var nx := x + d.x
		var ny := y + d.y
		if at(nx, ny) == Tiles.FLOOR and ((at(nx, ny - 1) == Tiles.WALL and at(nx, ny + 1) == Tiles.WALL) or (at(nx - 1, ny) == Tiles.WALL and at(nx + 1, ny) == Tiles.WALL)):
			return false
	return true


## The big pieces, each standing on a block of case tiles in a gallery with
## floor all round it (a free tile on every side, so no way is ever shut):
## the dinosaur and the bear, to look at, and a few to hide in (Hideouts.BIG).
## Every one of those is a hideout, so there are only as many as the
## museum's share gives (Hideouts.big_of), far apart (Hideouts.APART): each
## kind once, and then a second of one that is not unique (Themes.UNIQUE) if
## there is still room in the share. They draw from a generator of their
## own, so the rest of the museum is the same as without them; one to a
## gallery, and a piece that finds no room is left out.
func _big_pieces(seed: int) -> void:
	big.clear()
	var rand := Mulberry32.new(seed ^ 0x3c6ef372)
	# A museum of one theme: only its own (the middle ages have none).
	var fits := func(kind: String) -> bool: return theme == "" or Themes.for_big(kind) in [theme, ""]
	var order: Array[int] = []
	for i in rooms.size():
		order.append(i)
	_shuffle(order, rand)
	for kind in ["dinosaur", "bear"]:
		if fits.call(kind):
			_stand_big(kind, order, rand, [] as Array[Vector2])
	var kinds: Array = Hideouts.BIG.filter(fits)
	_shuffle(kinds, rand)
	for k in kinds.duplicate():
		if not Themes.is_unique(k):
			kinds.append(k)
	var open := 0
	for v in grid:
		if v == Tiles.FLOOR:
			open += 1
	var middles: Array[Vector2] = []
	for kind in kinds:
		var size: Vector2i = BIG[kind]
		# Counted once it stands, so the share is the museum's as it ends up.
		if middles.size() >= Hideouts.big_of(open - size.x * size.y):
			continue
		var r := _stand_big(kind, order, rand, middles)
		if r.size != Vector2i.ZERO:
			middles.append(Rect2(r).get_center())
			open -= size.x * size.y


## Stand one big piece in the first gallery (of order) with room for it, at
## least Hideouts.APART from every point in apart; that gallery takes no
## other. Its tiles, or an empty rect if none had room.
func _stand_big(kind: String, order: Array[int], rand: Mulberry32, apart: Array[Vector2]) -> Rect2i:
	var size: Vector2i = BIG[kind]
	for i in order:
		var room := rooms[i]
		var spots: Array[Rect2i] = []
		for s in [size, Vector2i(size.y, size.x)]:
			for y in range(room.position.y, room.end.y):
				for x in range(room.position.x, room.end.x):
					var r := Rect2i(x, y, s.x, s.y)
					if _room_all_floor(r.grow(1), i) and Hideouts.far_from(Rect2(r).get_center(), apart):
						spots.append(r)
		if spots.is_empty():
			continue
		var r := spots[rand.below(spots.size())]
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_put(x, y, Tiles.COVER)
		big.append({"kind": kind, "rect": r})
		order.erase(i)
		return r
	return Rect2i()


static func _shuffle(list: Array, rand: Mulberry32) -> void:
	for i in range(list.size() - 1, 0, -1):
		var j := rand.below(i + 1)
		var tmp = list[i]
		list[i] = list[j]
		list[j] = tmp


## Every tile of r is plain floor of room i, off the corridor along the
## outer wall.
func _room_all_floor(r: Rect2i, i: int) -> bool:
	if r.position.x < 1 or r.position.y < 1 or r.end.x > w - 1 or r.end.y > h - 1:
		return false
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var k := y * w + x
			if grid[k] != Tiles.FLOOR or _room_of[k] != i or ring[k] == 1:
				return false
	return true


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
