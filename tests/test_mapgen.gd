extends SceneTree
## The museum generator, checked for what makes a museum playable, over
## hundreds of museums of every size and shape:
##   - the PRNG is still bit-exact with the web version (the seeds mean the
##     same thing);
##   - every bit of floor is reachable, and there is no floor outside;
##   - every gallery has at least two ways in (no one-door traps);
##   - no dead-end corridor stubs;
##   - no big blocks of solid wall inside the building (no sealed "rooms");
##   - every walkable tile belongs to a named place, and names are unique.
##   godot --headless --script tests/test_mapgen.gd

var failures: Array[String] = []


func _init() -> void:
	_check_rng()
	var stats := {}
	var n := 0
	for size in ["small", "medium", "large"]:
		for shape in MapGen.SHAPES:
			for k in 17:
				var seed := 1000 + n * 7919
				n += 1
				Museum.regenerate(seed, size, shape)
				_check_museum("%s/%s/%d" % [size, shape, seed])
				var key := "%s/%s" % [size, shape]
				if not stats.has(key):
					stats[key] = [0, 0, 0]
				stats[key][0] += 1
				stats[key][1] += Museum.rooms.size()
				stats[key][2] += _doors_min()
	print("%d museos" % n)
	for key in stats:
		var s: Array = stats[key]
		print("  %-16s salas %4.1f" % [key, float(s[1]) / s[0]])
	if failures.is_empty():
		print("OK: museos bien formados")
		quit(0)
	else:
		for f in failures.slice(0, 20):
			printerr(f)
		printerr("%d fallos" % failures.size())
		quit(1)


func _check_rng() -> void:
	for case in JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rng.json")):
		var r := Mulberry32.new(int(case.seed))
		for v in case.values:
			# Godot's JSON reader can lose the last bit of a double, so not ==.
			if absf(r.next() - float(v)) > 1e-12:
				failures.append("rng %d distinto de la web" % int(case.seed))
				break


func _check_museum(tag: String) -> void:
	var w := Museum.w
	var h := Museum.h
	# Reachable floor, nothing outside.
	var floor := 0
	for y in h:
		for x in w:
			var t := Museum.grid[y * w + x]
			if t == Tiles.FLOOR:
				floor += 1
				if Museum.is_outside(x, y):
					failures.append("%s: suelo fuera del edificio" % tag)
					return
	var seen := {}
	var queue: Array[Vector2i] = [Museum.spawn]
	seen[Museum.spawn] = true
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in Museum.DIRS:
			var nb := c + d
			if Museum.tile_at(nb.x + 0.5, nb.y + 0.5) == Tiles.FLOOR and not seen.has(nb):
				seen[nb] = true
				queue.append(nb)
	if seen.size() != floor:
		failures.append("%s: %d casillas de suelo inalcanzables" % [tag, floor - seen.size()])
	# Two ways into every gallery.
	var doors := _doors_min()
	if doors < 2:
		failures.append("%s: una sala con %d puertas" % [tag, doors])
	# No stubs: a corridor tile (not gallery, not against the outer wall) with one way out.
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			if Museum.grid[y * w + x] != Tiles.FLOOR or Museum.is_ring(x, y) or Museum.room_at(x + 0.5, y + 0.5):
				continue
			var open := 0
			for d in Museum.DIRS:
				if Museum.tile_at(x + d.x + 0.5, y + d.y + 0.5) != Tiles.WALL:
					open += 1
			if open <= 1:
				failures.append("%s: pasillo sin salida en (%d, %d)" % [tag, x, y])
				return
	# No sealed blocks: no 4x4 of solid wall inside the building.
	for y in range(1, h - 4):
		for x in range(1, w - 4):
			var solid := true
			for dy in 4:
				for dx in 4:
					if Museum.grid[(y + dy) * w + x + dx] != Tiles.WALL or Museum.is_outside(x + dx, y + dy):
						solid = false
			if solid:
				failures.append("%s: bloque macizo en (%d, %d)" % [tag, x, y])
				return
	# No case between two walls, left and right or above and below.
	for t in Museum.cover_tiles:
		var wall := func(dx: int, dy: int) -> bool: return Museum.grid[(t.y + dy) * w + t.x + dx] == Tiles.WALL
		if (wall.call(0, -1) and wall.call(0, 1)) or (wall.call(-1, 0) and wall.call(1, 0)):
			failures.append("%s: vitrina entre dos paredes en (%d, %d)" % [tag, t.x, t.y])
			return
	# Columns are structure: no wall within a tile of one (a case may stand
	# by it), and the ones in a gallery a full regular grid (same step
	# along, same step across, nothing skipped), three or more apart.
	var by_room := {}
	for t in Museum.columns:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if Museum.grid[(t.y + dy) * w + t.x + dx] == Tiles.WALL and not (dx == 0 and dy == 0):
					failures.append("%s: columna pegada a un muro en (%d, %d)" % [tag, t.x, t.y])
					return
		var room := Museum.room_at(t.x + 0.5, t.y + 0.5)
		if room == null:
			failures.append("%s: columna fuera de una sala en (%d, %d)" % [tag, t.x, t.y])
			return
		if not by_room.has(room.id):
			by_room[room.id] = []
		by_room[room.id].append(t)
	for id in by_room:
		var cols: Array = by_room[id]
		var xs := {}
		var ys := {}
		for t in cols:
			xs[t.x] = true
			ys[t.y] = true
		if cols.size() != xs.size() * ys.size() or cols.size() < 2:
			failures.append("%s: columnas sin retícula completa en la sala %d" % [tag, id])
			return
		for axis in [xs.keys(), ys.keys()]:
			var ks: Array = axis
			ks.sort()
			for i in range(1, ks.size()):
				if ks[i] - ks[i - 1] < 3 or (i > 1 and ks[i] - ks[i - 1] != ks[1] - ks[0]):
					failures.append("%s: columnas sin ritmo en la sala %d" % [tag, id])
					return
	# Names.
	var names := {}
	for z in Museum.zones:
		if names.has(z.name):
			failures.append("%s: nombre repetido %s" % [tag, z.name])
		names[z.name] = true


## The fewest ways into any gallery: floor tiles just outside its rect that
## lead in through its wall.
func _doors_min() -> int:
	var fewest := 99
	for r in Museum.rooms:
		var rect := r.rect
		var n := 0
		for y in range(rect.position.y - 1, rect.end.y + 1):
			for x in range(rect.position.x - 1, rect.end.x + 1):
				if rect.has_point(Vector2i(x, y)):
					continue
				if Museum.tile_at(x + 0.5, y + 0.5) != Tiles.FLOOR:
					continue
				# A door: floor in the wall ring with room floor right inside.
				for d in Museum.DIRS:
					var inside := Vector2i(x, y) + d
					if rect.has_point(inside) and Museum.tile_at(inside.x + 0.5, inside.y + 0.5) == Tiles.FLOOR:
						n += 1
						break
		fewest = mini(fewest, n)
	return fewest
