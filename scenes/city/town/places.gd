class_name TownPlaces
extends RefCounted
## Loose houses, riverside walk, sports ground, shopping mall and park.
## The context keeps the original shared state and construction order.


## Houses and chalets out among the trees, each on a garden of its own and
## turned its own way (a little off the way the river runs): on flat land,
## clear of the districts, the roads, the rocks and the water; some with a
## lit pool; windows lit, a pool of light at the door.
func loose_houses(host: TownBuilder) -> void:
	var letters := "abcdefghijklmnopqrstu"
	var y := -TownBuilder.REACH
	while y < TownBuilder.REACH:
		var x := -TownBuilder.REACH
		while x < TownBuilder.REACH:
			var p := Vector2(x, y) + Vector2(host._rng.randf_range(-1, 1), host._rng.randf_range(-1, 1)) * TownBuilder.HOUSE_STEP * 0.35
			x += TownBuilder.HOUSE_STEP
			if host._rng.randf() > TownBuilder.HOUSE_SHARE:
				continue
			if host.seen.is_valid() and not host.seen.call(Vector3(p.x, host.ground(p), p.y), TownBuilder.TILE * 3.0):
				continue
			var d := host.across(p)
			if d > -(TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.WALK_OFF + TownBuilder.WALK_WIDTH + 0.8) and d < TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.SLOPE + 0.4:
				continue
			if host._rocky(p) > 0.0 or host._in_sports(p) or host._built(p, 1.8) or host._on_road(p) or host._near_taken(p, 1.2):
				continue
			var turn := atan2(host.along.x, host.along.y) + host._rng.randf_range(-0.6, 0.6) + (PI if host._rng.randf() < 0.5 else 0.0)
			var basis := Basis(Vector3.UP, turn)
			var chalet := host._rng.randf() < 0.45
			var lot := 2.9 if chalet else 2.3
			# Its garden level, at the highest ground under it, on a plinth
			# down to the lowest.
			var h := -INF
			var low := INF
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2.ZERO]:
				var w := basis * Vector3(c.x * lot * 0.5, 0, c.y * lot * 0.5)
				var g := host.ground(p + Vector2(w.x, w.z))
				h = maxf(h, g)
				low = minf(low, g)
			var at := Vector3(p.x, h, p.y)
			if h - low > 0.04:
				var drop := h - low + 0.2
				host._box(Vector3(lot, drop, lot), TownBuilder.TERRACE_WALL, at + Vector3(0, -drop * 0.5, 0), basis)
			host._box(Vector3(lot, 0.05, lot), TownBuilder.GARDEN, at + Vector3(0, 0.02, 0), basis)
			var path := "suburbios/building-type-%s.glb" % letters[host._rng.randi() % letters.length()]
			host._add(path, at + basis * Vector3(0, 0.05, -0.2), turn, host._fit(path, lot * (0.62 if chalet else 0.72)), host._own(1.0))
			host._pool(at + basis * Vector3(0, 0, 0.9), 1.4, TownBuilder.GLOW_HOUSE)
			if chalet and host._rng.randf() < TownBuilder.POOL_SHARE / 0.45:
				var water := basis * Vector3(0.75, 0.06, 0.95) + at
				host._box(Vector3(0.8, 0.04, 0.5), TownBuilder.POOL_WATER, water, basis, true, host._glow(TownBuilder.POOL_WATER, 1.4))
				host._pool(water, 1.5, TownBuilder.GLOW_POOL)
			if host._rng.randf() < 0.7:
				host._tree(at + basis * Vector3(-lot * 0.4, 0, lot * 0.35))
			host._take(p, lot * 0.75)
		y += TownBuilder.HOUSE_STEP


## The riverside walk: a paved path along the near bank, following the
## bends, with a lamp and a bench every so often; not where something is
## built on the bank (a museum by the water) nor across a bridge's foot.
func walk(host: TownBuilder) -> void:
	var s := -TownBuilder.REACH * 1.4
	var step := 0.9
	var next_lamp := 0.0
	var prev := Vector3.INF
	while s < TownBuilder.REACH * 1.4:
		var dir := host._across_dir(s)
		var mid := host.point(s, host.river_at(s)) - dir * (TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.WALK_OFF)
		s += step
		if absf(mid.x) > TownBuilder.REACH + 4.0 or absf(mid.y) > TownBuilder.REACH + 4.0 or host._built(mid, 0.2) or host._near_bridge(mid, 1.6):
			prev = Vector3.INF
			continue
		var here := Vector3(mid.x, 0.03, mid.y)
		if prev != Vector3.INF:
			host._beam(prev, here, TownBuilder.WALK_WIDTH, 0.04, TownBuilder.PATH)
		prev = here
		next_lamp -= step
		if next_lamp <= 0.0:
			next_lamp = TownBuilder.WALK_LAMP
			var side := Vector3(-dir.x, 0, -dir.y) * (TownBuilder.WALK_WIDTH * 0.5 + 0.25)
			host._lamp(here + side, atan2(dir.x, dir.y))
			# A bench facing the water, between two lamps.
			var bench := here + side - Vector3(host._tangent(s).x, 0, host._tangent(s).y) * TownBuilder.WALK_LAMP * 0.5
			host._box(Vector3(0.5, 0.12, 0.16), Color("#6b4a3a"), bench + Vector3(0, 0.08, 0), Basis(Vector3.UP, atan2(dir.x, dir.y)))


## The sports ground on the near bank: a football pitch, a basketball court
## and a tennis court, each on its own ground with its white lines and a
## fence, under floodlights (pools of cool light); not in a row, each a
## little off and turned its own way.
func sports(host: TownBuilder) -> void:
	var s := (TownBuilder.SPORTS.x + TownBuilder.SPORTS.y) * 0.5
	var dir := host._tangent(s)
	var across_dir := host._across_dir(s)
	var back := -(TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.WALK_OFF + TownBuilder.WALK_WIDTH + 1.0)
	var base := host.point(s, host.river_at(s)) + across_dir * back
	# Pitch, court, court: along the bank, the pitch nearest the water; where
	# each is, how big, its colour, and how far it is turned.
	var fields := [
		[Vector2(-0.4, -2.7), Vector2(7.0, 4.4), TownBuilder.PITCH_GRASS, "pitch", 0.1],
		[Vector2(-2.7, -7.6), Vector2(3.2, 2.2), TownBuilder.COURT, "basket", -0.3],
		[Vector2(2.6, -7.0), Vector2(3.4, 1.9), TownBuilder.TENNIS, "tennis", 0.22],
	]
	for f in fields:
		var off: Vector2 = f[0] + Vector2(host._rng.randf_range(-0.3, 0.3), host._rng.randf_range(-0.25, 0.25))
		var size: Vector2 = f[1]
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.y) + float(f[4]) + host._rng.randf_range(-0.06, 0.06))
		var c2: Vector2 = base + dir * off.x + across_dir * off.y
		var c := Vector3(c2.x, 0.0, c2.y)
		# The ground and its lines: the edge, the halfway line, a circle.
		host._box(Vector3(size.y + 0.4, 0.05, size.x + 0.4), TownBuilder.PATH.darkened(0.3), c + Vector3(0, 0.02, 0), basis)
		host._box(Vector3(size.y, 0.06, size.x), f[2], c + Vector3(0, 0.03, 0), basis)
		for sgn in [-1, 1]:
			host._box(Vector3(0.05, 0.07, size.x), TownBuilder.LINE, c + basis * Vector3(sgn * size.y * 0.5, 0.035, 0), basis)
			host._box(Vector3(size.y, 0.07, 0.05), TownBuilder.LINE, c + basis * Vector3(0, 0.035, sgn * size.x * 0.5), basis)
		host._box(Vector3(size.y, 0.07, 0.05), TownBuilder.LINE, c + Vector3(0, 0.035, 0), basis)
		if f[3] == "pitch":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.55
			torus.outer_radius = 0.6
			ring.mesh = torus
			ring.scale = Vector3(1, 0.1, 1)
			ring.material_override = MenuStage._material(TownBuilder.LINE)
			ring.position = c + Vector3(0, 0.07, 0)
			host.root.add_child(ring)
			for sgn in [-1, 1]:
				host._box(Vector3(0.9, 0.35, 0.06), TownBuilder.LINE, c + basis * Vector3(0, 0.2, sgn * size.x * 0.5), basis)
		else:
			# A low fence round the court.
			for sgn in [-1, 1]:
				host._box(Vector3(0.03, 0.4, size.x + 0.4), TownBuilder.RAIL, c + basis * Vector3(sgn * (size.y * 0.5 + 0.2), 0.2, 0), basis)
				host._box(Vector3(size.y + 0.4, 0.4, 0.03), TownBuilder.RAIL, c + basis * Vector3(0, 0.2, sgn * (size.x * 0.5 + 0.2)), basis)
		# Floodlights at the corners, and their light.
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var post := c + basis * Vector3(sx * (size.y * 0.5 + 0.35), 0, sz * (size.x * 0.5 + 0.35))
				host._box(Vector3(0.06, 1.6, 0.06), TownBuilder.RAIL, post + Vector3(0, 0.8, 0))
				host._box(Vector3(0.22, 0.1, 0.1), TownBuilder.LINE, post + Vector3(0, 1.62, 0), basis, true, host._glow(Color(0.9, 0.95, 1.0), 2.5))
		host._pool(c, maxf(size.x, size.y) * 0.75, TownBuilder.GLOW_FLOOD)
		var span := maxf(size.x, size.y) * 0.6 + 0.6
		host._take(c2, span)


## On clear land, as near the museums as there is room for: the mall, then
## the big park.
func places(host: TownBuilder) -> void:
	var at := host._clear_spot(TownBuilder.MALL_REACH)
	if at != Vector2.INF:
		host._mall(at)
		host._take(at, TownBuilder.MALL_REACH)
	# The park a little smaller if that is all there is room for.
	var r := TownBuilder.BIG_PARK_REACH
	while r >= TownBuilder.BIG_PARK_REACH * 0.7:
		at = host._clear_spot(r)
		if at != Vector2.INF:
			host._big_park(at, r)
			host._take(at, r)
			break
		r -= 0.5


## The clear round of land r across nearest a museum (Vector2.INF if none).
func clear_spot(host: TownBuilder, r: float) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	var y := -TownBuilder.REACH
	while y < TownBuilder.REACH:
		var x := -TownBuilder.REACH
		while x < TownBuilder.REACH:
			var p := Vector2(x, y)
			x += 2.0
			var dd := INF
			for m in host.museums:
				dd = minf(dd, m.distance_to(p))
			if dd < best_d and host._clear(p, r):
				best_d = dd
				best = p
		y += 2.0
	return best


## Land round p, r across, that can be seen, flat and all on one bank, with
## nothing on it: no block, road, walk, rock, pitch or loose house.
func clear(host: TownBuilder, p: Vector2, r: float) -> bool:
	if host.seen.is_valid() and not host.seen.call(Vector3(p.x, host.ground(p), p.y), 0.0):
		return false
	var bank := signf(host.across(p))
	var g0 := host.ground(p)
	for k in 9:
		var q := p if k == 8 else p + Vector2.from_angle(k * TAU / 8.0) * r
		var d := host.across(q)
		var flat := d < -(TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.WALK_OFF + TownBuilder.WALK_WIDTH + 0.6) or d > TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.SLOPE + 0.6
		if not flat or signf(d) != bank or absf(q.x) > TownBuilder.REACH or absf(q.y) > TownBuilder.REACH:
			return false
		if host._rocky(q) > 0.0 or host._in_sports(q) or host._built(q, 0.6) or host._on_road(q) or host._near_taken(q):
			return false
		if absf(host.ground(q) - g0) > 0.25:
			return false
	return true


## The crossing of the streets of p's bank nearest p, and its key.
func nearest_node(host: TownBuilder, p: Vector2) -> Array:
	var high := host.across(p) > 0.0
	var best := Vector3i(-2, 0, 0)
	var best_d := INF
	for k in host._nodes:
		if k.x < 0 or host.districts[k.x].high != high:
			continue
		var n: Vector3 = host._nodes[k]
		var dd := Vector2(n.x, n.z).distance_to(p)
		if dd < best_d:
			best_d = dd
			best = k
	return [best, host._nodes.get(best, Vector3(p.x, 0, p.y))]


## The mall: a long low hall with a glass front and a taller wing, its sign
## lit on the roof; before it a big car park, bays in rows, cars in half of
## them, lamps over the aisles, bushes round it; a road from its gate to
## the nearest street. Facing that street.
func mall(host: TownBuilder, c: Vector2) -> void:
	var near: Array = host._nearest_node(c)
	var goal: Vector3 = near[1]
	var fwd := (Vector2(goal.x, goal.z) - c).normalized()
	var basis := Basis(Vector3.UP, atan2(fwd.x, fwd.y))
	var o := Vector3(c.x, host.ground(c), c.y)
	# The car park: a kerb, the tarmac, three rows of fourteen bays.
	host._box(Vector3(9.4, 0.06, 5.9), TownBuilder.PAVEMENT_EDGE, o + basis * Vector3(0, 0.03, 1.9), basis)
	host._box(Vector3(9.0, 0.06, 5.5), TownBuilder.ROAD, o + basis * Vector3(0, 0.05, 1.9), basis)
	for row in [[0.1, 1], [2.2, -1], [3.1, 1]]:
		var z: float = row[0]
		var x := -4.2
		while x < 4.3:
			host._box(Vector3(0.03, 0.02, 0.85), TownBuilder.LINE, o + basis * Vector3(x, 0.085, z), basis)
			if x < 4.0 and host._rng.randf() < 0.55:
				host._car(o + basis * Vector3(x + 0.3, 0.08, z), basis * Basis(Vector3.UP, (0.0 if int(row[1]) > 0 else PI) + host._rng.randf_range(-0.06, 0.06)))
			x += 0.6
	# Lamps over the aisles.
	for z in [1.15, 4.1]:
		for x in [-3.0, 0.0, 3.0]:
			host._lamp(o + basis * Vector3(x, 0.08, z), atan2(fwd.x, fwd.y))
	# The hall and its wing, the roof, the glass front and the way in, the signs.
	host._box(Vector3(6.8, 1.2, 2.8), TownBuilder.MALL_WALL, o + basis * Vector3(0.8, 0.6, -2.6), basis)
	host._box(Vector3(7.0, 0.08, 3.0), TownBuilder.MALL_ROOF, o + basis * Vector3(0.8, 1.24, -2.6), basis)
	host._box(Vector3(2.4, 1.7, 3.2), TownBuilder.MALL_WING, o + basis * Vector3(-3.8, 0.85, -2.5), basis)
	host._box(Vector3(2.6, 0.08, 3.4), TownBuilder.MALL_ROOF, o + basis * Vector3(-3.8, 1.74, -2.5), basis)
	host._box(Vector3(5.6, 0.5, 0.04), TownBuilder.WINDOW_LIT, o + basis * Vector3(1.0, 0.45, -1.19), basis, false, host._glow(TownBuilder.WINDOW_LIT, 1.1))
	host._box(Vector3(2.0, 0.08, 0.8), TownBuilder.MALL_SIGN, o + basis * Vector3(1.0, 0.82, -0.85), basis)
	host._box(Vector3(3.0, 0.42, 0.1), TownBuilder.MALL_SIGN, o + basis * Vector3(1.0, 1.55, -1.25), basis, false, host._glow(TownBuilder.MALL_SIGN, 2.6))
	host._box(Vector3(1.3, 0.36, 0.1), TownBuilder.MALL_SIGN, o + basis * Vector3(-3.8, 1.45, -0.88), basis, false, host._glow(TownBuilder.MALL_SIGN, 2.2))
	for k in 4:
		host._box(Vector3(0.5, 0.25, 0.4), TownBuilder.RAIL, o + basis * Vector3(-1.6 + k * 1.2, 1.4, -3.3 + (k % 2) * 0.6), basis)
	host._pool(o + basis * Vector3(1.0, 0, -0.6), 2.2, TownBuilder.GLOW_HOUSE)
	# Bushes and trees round the car park.
	for sx in [-1, 1]:
		for z in [-0.4, 0.7, 1.8, 2.9, 4.0]:
			host._plant("bush" if host._rng.randf() < 0.6 else "bloom", o + basis * Vector3(sx * 4.8, 0.02, z + host._rng.randf_range(-0.2, 0.2)))
		host._tree(o + basis * Vector3(sx * 4.8, 0.02, 4.8))
	# The road from the gate.
	var gate := o + basis * Vector3(0, 0.02, 4.9)
	host._node(Vector3i(-3, 0, 0), gate)
	host._road_to_nearest(Vector3i(-3, 0, 0), gate, host.across(c) > 0.0)


## A parked car: its body in one of the cars' colours, a dark cabin on it.
func car(host: TownBuilder, at: Vector3, basis: Basis) -> void:
	host._box(Vector3(0.32, 0.13, 0.62), TownBuilder.CARS[host._rng.randi() % TownBuilder.CARS.size()], at + Vector3(0, 0.09, 0), basis)
	host._box(Vector3(0.27, 0.11, 0.32), TownBuilder.CAR_GLASS, at + basis * Vector3(0, 0.2, -0.04), basis)


## The big park, r round: a round lawn with a hedge round it, a fountain in the
## middle ringed by a path with benches and lamps, winding paths out to the
## edge, a kiosk, flower beds, and trees of every kind round it all.
func big_park(host: TownBuilder, c: Vector2, r: float) -> void:
	var o := Vector3(c.x, host.ground(c), c.y)
	host._disc(o + Vector3(0, 0.03, 0), r, 0.06, TownBuilder.PARK)
	var paths: Array = []
	# The ring round the fountain.
	for k in 16:
		var a := k * TAU / 16.0
		var b := (k + 1) * TAU / 16.0
		paths.append([o + Vector3(cos(a), 0, sin(a)) * 2.0, o + Vector3(cos(b), 0, sin(b)) * 2.0])
	# Winding ways out, and where they leave the park.
	var exits: Array[float] = []
	var first := host._rng.randf() * TAU
	for k in 4:
		var a := first + k * TAU / 4.0 + host._rng.randf_range(-0.3, 0.3)
		exits.append(a)
		var bend := host._rng.randf_range(-0.5, 0.5)
		var prev := o + Vector3(cos(a), 0, sin(a)) * 2.0
		for j in range(1, 6):
			var t := j / 5.0
			var aa := a + bend * sin(t * PI)
			var here := o + Vector3(cos(aa), 0, sin(aa)) * lerpf(2.0, r - 0.1, t)
			paths.append([prev, here])
			prev = here
	for seg in paths:
		host._beam((seg[0] as Vector3) + Vector3(0, 0.07, 0), (seg[1] as Vector3) + Vector3(0, 0.07, 0), 0.5, 0.04, TownBuilder.PATH)
	# The fountain: a stone basin, its water lit, a column and a bowl.
	host._disc(o + Vector3(0, 0.14, 0), 1.0, 0.24, TownBuilder.STONE)
	host._disc(o + Vector3(0, 0.27, 0), 0.88, 0.04, TownBuilder.POOL_WATER, host._glow(TownBuilder.POOL_WATER, 0.9))
	host._disc(o + Vector3(0, 0.55, 0), 0.12, 0.6, TownBuilder.STONE)
	host._disc(o + Vector3(0, 0.86, 0), 0.4, 0.08, TownBuilder.STONE)
	host._disc(o + Vector3(0, 0.91, 0), 0.34, 0.03, TownBuilder.POOL_WATER, host._glow(TownBuilder.POOL_WATER, 1.4))
	host._pool(o, 2.4, TownBuilder.GLOW_POOL)
	# Benches facing it and lamps between them.
	for k in 6:
		var a := k * TAU / 6.0 + TAU / 12.0
		var at := o + Vector3(cos(a), 0, sin(a)) * 2.55
		host._box(Vector3(0.5, 0.12, 0.16), Color("#6b4a3a"), at + Vector3(0, 0.12, 0), Basis(Vector3.UP, -a + PI / 2))
		var lamp_a := a + TAU / 12.0
		host._lamp(o + Vector3(cos(lamp_a) * 2.6, 0.06, sin(lamp_a) * 2.6), -lamp_a + PI / 2)
	# A kiosk by the ring, its roof pink.
	var ka := first + TAU / 8.0
	var kiosk := o + Vector3(cos(ka), 0, sin(ka)) * 3.4
	host._box(Vector3(0.7, 0.5, 0.7), TownBuilder.MALL_WALL, kiosk + Vector3(0, 0.3, 0), Basis(Vector3.UP, ka))
	host._box(Vector3(0.95, 0.1, 0.95), TownBuilder.MALL_SIGN, kiosk + Vector3(0, 0.6, 0), Basis(Vector3.UP, ka))
	host._pool(kiosk, 1.2, TownBuilder.GLOW_HOUSE)
	# The hedge round it, open where the paths leave.
	for k in 40:
		var a := k * TAU / 40.0
		var b := (k + 1) * TAU / 40.0
		var gap := false
		for e in exits:
			if absf(angle_difference(e, (a + b) * 0.5)) < 0.22:
				gap = true
		if not gap:
			host._hedge(o + Vector3(cos(a), 0.06, sin(a)) * (r - 0.15), o + Vector3(cos(b), 0.06, sin(b)) * (r - 0.15), 0.3)
	# Flower beds and trees, clear of the paths and the kiosk.
	for k in 90:
		var a := host._rng.randf() * TAU
		var d := sqrt(host._rng.randf_range(0.1, 1.0)) * (r - 0.6)
		var at := o + Vector3(cos(a) * d, 0.06, sin(a) * d)
		if d < 1.3 or at.distance_to(kiosk) < 0.9 or host._near_path(at, paths, 0.45):
			continue
		if d < 3.0:
			host._plant("bloom" if host._rng.randf() < 0.7 else "bush", at)
		elif host._rng.randf() < 0.75:
			host._tree(at, host._rng.randf() < 0.6)


func near_path(host: TownBuilder, at: Vector3, paths: Array, r: float) -> bool:
	var p := Vector2(at.x, at.z)
	for seg in paths:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		if Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(p) < r:
			return true
	return false


## A round slab, r across and h high, its middle at `at`.
func disc(host: TownBuilder, at: Vector3, r: float, h: float, colour: Color, material: Material = null) -> void:
	if not host._shown(at, r, "disc"):
		return
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	c.rings = 0
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = material if material else MenuStage._material(colour)
	mi.position = at
	host.root.add_child(mi)


