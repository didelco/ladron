class_name TownTerrain
extends RefCounted
## Terrain, river and rocky outcrops; the original TownBuilder algorithms.
## The context keeps the original shared state and construction order.


## s along the river and q up towards the far bank, of a point of the plan.
func frame(host: TownBuilder, p: Vector2) -> Vector2:
	return Vector2(p.dot(host.along), p.dot(host.up))


## The point of the plan at s along and q up.
func point(host: TownBuilder, s: float, q: float) -> Vector2:
	return host.along * s + host.up * q


## How far up the middle of the river is, at s along it.
func river_at(host: TownBuilder, s: float) -> float:
	return TownBuilder.MEANDER * sin(s * TAU / TownBuilder.MEANDER_LENGTH + 0.8)


## How far a point is from the middle of the river, across it: negative on
## the near bank, positive on the far one.
func across(host: TownBuilder, p: Vector2) -> float:
	var f := host.frame(p)
	var slope := TownBuilder.MEANDER * TAU / TownBuilder.MEANDER_LENGTH * cos(f.x * TAU / TownBuilder.MEANDER_LENGTH + 0.8)
	return (f.y - host.river_at(f.x)) / sqrt(1.0 + slope * slope)


## How high the ground is at a point: the river's bed below it all, level
## on the near bank, up the slope to RISE on the far one and rolling on up
## from there (_upland); the rocky outcrops' own rise on top (_crags).
func ground(host: TownBuilder, p: Vector2) -> float:
	var d := host.across(p)
	var half := TownBuilder.RIVER_WIDTH * 0.5
	if absf(d) < half + 0.3:
		return lerpf(-0.55, 0.0, smoothstep(half - 0.6, half + 0.3, absf(d)))
	if d < 0.0:
		return host._crags(p)
	return TownBuilder.RISE * smoothstep(half + 0.3, half + TownBuilder.SLOPE, d) + host._upland(p, d) + host._crags(p)


## How much higher than RISE the high bank is at p, d across from the
## river: rising towards the back, in low hills, nothing at the top of the
## slope.
func upland(host: TownBuilder, p: Vector2, d: float) -> float:
	var top := TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.SLOPE
	var fade := smoothstep(top, top + TownBuilder.UPLAND_FADE, d)
	if fade <= 0.0:
		return 0.0
	var back := TownBuilder.UPLAND_RISE * clampf((d - top) / TownBuilder.UPLAND_DEPTH, 0.0, 1.0)
	return fade * (back + TownBuilder.HILLS * (host._hills.get_noise_2dv(p) + 0.35))


## How far into a rocky outcrop a point is (the one it is furthest into):
## 0 outside, 1 at its top.
func rocky(host: TownBuilder, p: Vector2) -> float:
	var f := host.frame(p)
	var k := 0.0
	for o in TownBuilder.OUTCROPS.size():
		k = maxf(k, host._outcrop(o, f))
	return k


## The ground's rise under the outcrops.
func crags(host: TownBuilder, p: Vector2) -> float:
	var f := host.frame(p)
	var h := 0.0
	for o in TownBuilder.OUTCROPS.size():
		var k := host._outcrop(o, f)
		if k > 0.0:
			h += float(TownBuilder.OUTCROPS[o][2]) * k
	return h


## Where outcrop o's middle is on the plan.
func outcrop_at(host: TownBuilder, o: int) -> Vector2:
	var at: Vector2 = TownBuilder.OUTCROPS[o][0]
	return host.point(at.x, host.river_at(at.x) + at.y)


## How far into outcrop o a point (s along, q up: f) is: 0 outside, 1 at
## its top; its edge wavers so it is no circle.
func outcrop(host: TownBuilder, o: int, f: Vector2) -> float:
	var at: Vector2 = TownBuilder.OUTCROPS[o][0]
	var off := f - Vector2(at.x, host.river_at(at.x) + at.y)
	var r: float = TownBuilder.OUTCROPS[o][1]
	if off.length() > r * 1.4:
		return 0.0
	var a := atan2(off.y, off.x)
	var wobble := 1.0 + 0.22 * sin(a * 3.0 + 1.3 + o * 2.1) + 0.12 * sin(a * 7.0 + o)
	return smoothstep(1.0, 0.35, off.length() / (r * wobble))


## On the sports ground: along its stretch of the near bank, back from the
## water.
func in_sports(host: TownBuilder, p: Vector2) -> bool:
	var s := host.frame(p).x
	var d := host.across(p)
	return s > TownBuilder.SPORTS.x and s < TownBuilder.SPORTS.y and d < -TownBuilder.RIVER_WIDTH * 0.5 and d > -TownBuilder.SPORTS_DEPTH


## The way the river runs at s along it, and the way across it (towards
## the far bank).
func tangent(host: TownBuilder, s: float) -> Vector2:
	var slope := TownBuilder.MEANDER * TAU / TownBuilder.MEANDER_LENGTH * cos(s * TAU / TownBuilder.MEANDER_LENGTH + 0.8)
	return (host.along + host.up * slope).normalized()


func across_dir(host: TownBuilder, s: float) -> Vector2:
	var slope := TownBuilder.MEANDER * TAU / TownBuilder.MEANDER_LENGTH * cos(s * TAU / TownBuilder.MEANDER_LENGTH + 0.8)
	return (host.up - host.along * slope).normalized()


## The ground as one mesh, following ground(): grass everywhere, darker
## meadow here and there, the river's banks and bed.
func terrain(host: TownBuilder) -> void:
	var step := 0.8
	var n := int((TownBuilder.REACH + 8.0) * 2.0 / step)
	var lo := -(TownBuilder.REACH + 8.0)
	var heights := PackedFloat32Array()
	var colours := PackedColorArray()
	heights.resize((n + 1) * (n + 1))
	colours.resize((n + 1) * (n + 1))
	# Only the squares ever seen, looked at in patches of TERRAIN_PATCH a side;
	# the ground worked out only at their corners.
	var patches := ceili(float(n) / TownBuilder.TERRAIN_PATCH)
	var kept := PackedByteArray()
	kept.resize(patches * patches)
	var needed := PackedByteArray()
	needed.resize((n + 1) * (n + 1))
	for pj in patches:
		for pi in patches:
			var mid := Vector3(lo + (pi + 0.5) * TownBuilder.TERRAIN_PATCH * step, 0.0, lo + (pj + 0.5) * TownBuilder.TERRAIN_PATCH * step)
			mid.y = host.ground(Vector2(mid.x, mid.z))
			if not host._shown(mid, TownBuilder.TERRAIN_PATCH * step * 0.71 + TownBuilder.RISE * 0.5, "ground"):
				continue
			kept[pj * patches + pi] = 1
			for j in range(pj * TownBuilder.TERRAIN_PATCH, mini((pj + 1) * TownBuilder.TERRAIN_PATCH, n) + 1):
				for i in range(pi * TownBuilder.TERRAIN_PATCH, mini((pi + 1) * TownBuilder.TERRAIN_PATCH, n) + 1):
					needed[j * (n + 1) + i] = 1
	var half := TownBuilder.RIVER_WIDTH * 0.5
	for j in n + 1:
		for i in n + 1:
			var k := j * (n + 1) + i
			if not needed[k]:
				continue
			var p := Vector2(lo + i * step, lo + j * step)
			heights[k] = host.ground(p)
			var d := absf(host.across(p))
			var c := TownBuilder.PARK.lerp(TownBuilder.MEADOW, 0.5 + 0.5 * sin(p.x * 0.31 + sin(p.y * 0.23) * 2.0))
			if d < half + 0.4:
				c = TownBuilder.RIVERBED.lerp(TownBuilder.BANK, smoothstep(half - 0.5, half + 0.4, d))
			colours[k] = c
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			if not kept[(j / TownBuilder.TERRAIN_PATCH) * patches + i / TownBuilder.TERRAIN_PATCH]:
				continue
			var quad := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for v in quad:
				var k: int = v.y * (n + 1) + v.x
				st.set_color(colours[k])
				st.add_vertex(Vector3(lo + v.x * step, heights[k], lo + v.y * step))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	mi.material_override = m
	host.root.add_child(mi)


## The water: a sheet over the river's bed, and the moon on it in strips
## along the bends.
func water(host: TownBuilder) -> void:
	var span := (TownBuilder.REACH + 8.0) * 2.0
	host._box(Vector3(span, 0.02, span), TownBuilder.WATER, Vector3(0, -0.22, 0), Basis.IDENTITY, false)
	var s := -TownBuilder.REACH * 1.5
	while s < TownBuilder.REACH * 1.5:
		s += host._rng.randf_range(0.8, 2.2)
		var at := host.point(s, host.river_at(s) + host._rng.randf_range(-0.9, 0.9))
		if absf(at.x) > TownBuilder.REACH + 6.0 or absf(at.y) > TownBuilder.REACH + 6.0:
			continue
		var dir := host._tangent(s)
		host._box(Vector3(0.05, 0.02, host._rng.randf_range(0.3, 0.9)), TownBuilder.WATER_GLINT, Vector3(at.x, -0.2, at.y), Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP), false)


## Rocks on each outcrop (OUTCROPS), never in rows: a few heaps spread over
## it (a Poisson spread, the most near its top), each a great rock or a crag
## in the middle and smaller ones leaning in round it, and strays down its
## sides, every one kept its own room from the rest (ROCK_SPACING). Each
## stone one of ROCK_KINDS rough shapes, never the same as a neighbour's,
## stretched its own way and tipped over on all three axes, sat into the
## ground so no edge floats: one MultiMesh a shape, for all the outcrops.
func rocks(host: TownBuilder) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var at: Array = []
	for k in TownBuilder.ROCK_KINDS:
		at.append([])
	# every rock laid: Vector4(x, z, its reach, its shape)
	var laid: Array[Vector4] = []
	for o in TownBuilder.OUTCROPS.size():
		var c := host._outcrop_at(o)
		var r: float = TownBuilder.OUTCROPS[o][1]
		var count: int = TownBuilder.OUTCROPS[o][3]
		var big: float = TownBuilder.OUTCROPS[o][4]
		var crag: float = TownBuilder.OUTCROPS[o][5]
		# The heaps' middles: darts thrown at the outcrop, the nearer its top
		# the likelier, none too near another.
		var want := clampi(count / TownBuilder.ROCK_HEAP, 1, 12)
		var gap := r * 1.3 / sqrt(float(want))
		var heaps: Array[Vector2] = []
		var tries := 0
		while heaps.size() < want and tries < want * 60:
			tries += 1
			var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
			if rng.randf() > pow(host._rocky(p), 1.5) or heaps.any(func(h: Vector2) -> bool: return h.distance_to(p) < gap):
				continue
			heaps.append(p)
		var placed := 0
		# A great one in the middle of each heap, then smaller ones round it.
		for h in heaps:
			var k := host._rocky(h)
			var core := lerpf(1.0, big, k) * rng.randf_range(0.85, 1.25)
			var reach := host._lay_rock(rng, h, core, crag * 1.5, laid, at)
			if reach <= 0.0:
				continue
			placed += 1
			var ring := rng.randi_range(6, 11)
			var heaped := 0
			for j in ring * 4:
				if heaped >= ring or placed >= count:
					break
				var size := core * rng.randf_range(0.35, 0.8)
				var p := h + Vector2.from_angle(rng.randf() * TAU) * (reach + size * 0.5) * rng.randf_range(0.45, 1.3)
				if host._lay_rock(rng, p, size, crag * 0.5, laid, at) > 0.0:
					placed += 1
					heaped += 1
		# Strays: whatever is left, smaller, anywhere on it.
		tries = 0
		while placed < count and tries < count * 30:
			tries += 1
			var p := c + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 1.25
			var k := host._rocky(p)
			var size := lerpf(0.3, big * 0.35, k) * rng.randf_range(0.5, 1.2)
			if host._lay_rock(rng, p, size, crag * 0.3, laid, at) > 0.0:
				placed += 1
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	m.rim_enabled = true
	m.rim = 0.3
	for i in at.size():
		if (at[i] as Array).is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = host._rock_mesh(i + 1)
		mm.instance_count = at[i].size()
		for j in at[i].size():
			mm.set_instance_transform(j, at[i][j][0])
			mm.set_instance_color(j, at[i][j][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		host.root.add_child(mmi)


## One rock `size` across at p, if there is room for it (on its outcrop,
## clear of what is built and of every rock laid: ROCK_SPACING); a crag
## standing up one in `crag`. Its reach round p, or 0 if not laid.
func lay_rock(host: TownBuilder, rng: RandomNumberGenerator, p: Vector2, size: float, crag: float, laid: Array[Vector4], at: Array) -> float:
	var k := host._rocky(p)
	if k <= 0.05 or host._built(p) or host._on_road(p) or host._near_bridge(p, TownBuilder.TILE * 2.0) or absf(host.across(p)) < TownBuilder.RIVER_WIDTH * 0.5 + 0.6:
		return 0.0
	# Squat boulders, slabs and, now and then, a crag, each its own stretch.
	var dims := Vector3(rng.randf_range(0.7, 1.6), rng.randf_range(0.5, 0.9), rng.randf_range(0.6, 1.3)) * size
	var tip := 0.3
	if rng.randf() < crag:
		dims = Vector3(rng.randf_range(0.6, 1.0), rng.randf_range(1.3, 1.9 + 0.8 * k), rng.randf_range(0.5, 0.9)) * size * 0.8
		tip = 0.25
	var reach := maxf(dims.x, dims.z) * 0.5
	var near: Array[int] = []
	for q in laid:
		var dd := Vector2(q.x, q.y).distance_to(p)
		if dd < (q.z + reach) * TownBuilder.ROCK_SPACING:
			return 0.0
		if dd < (q.z + reach) * 1.8:
			near.append(int(q.w))
	# A shape none of its neighbours has.
	var kinds: Array[int] = []
	for i in TownBuilder.ROCK_KINDS:
		if not i in near:
			kinds.append(i)
	var kind: int = kinds[rng.randi() % kinds.size()] if not kinds.is_empty() else rng.randi() % TownBuilder.ROCK_KINDS
	var tx := rng.randf_range(-tip, tip)
	var tz := rng.randf_range(-tip, tip)
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, tx) * Basis(Vector3.BACK, tz) * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(dims)
	# Sat down on the lowest ground under it, and in as far as it is tipped.
	var low := host.ground(p)
	for e in 6:
		low = minf(low, host.ground(p + Vector2.from_angle(e * TAU / 6.0) * reach * 0.8))
	var sink := sin(maxf(absf(tx), absf(tz))) * reach * 0.5
	var rock := [Transform3D(basis, Vector3(p.x, low + dims.y * 0.12 - sink, p.y)), TownBuilder.ROCK.lerp(TownBuilder.ROCK_LIGHT, rng.randf())]
	laid.append(Vector4(p.x, p.y, reach, kind))
	host._take(p, reach * 1.1)
	if host._shown(rock[0].origin, maxf(reach, dims.y) * 1.5, "rock"):
		(at[kind] as Array).append(rock)
	return reach


## A rough stone of its own (seed): a ball of few faces, more or fewer by
## its seed, each corner pushed in or out, its foot cut flat; one in four a
## slab, its top cut flat too.
func rock_mesh(host: TownBuilder, seed: int) -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 5 + seed % 3
	ball.rings = 3 + (seed / 3) % 2
	var arrays := ball.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var spread := 0.45 + 0.1 * (seed % 4)
	var top := 0.4 if seed % 4 == 0 else 1.0
	# The same push for the same corner, seams and all.
	var push := func(v: Vector3) -> Vector3:
		var h := sin(roundf(v.x * 40.0) * 12.9898 + roundf(v.y * 40.0) * 78.233 + roundf(v.z * 40.0) * 37.719 + seed * 4.1) * 43758.5453
		return v * (1.0 - spread * 0.5 + spread * (h - floorf(h)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in index:
		var v: Vector3 = push.call(verts[i])
		st.add_vertex(Vector3(v.x, clampf(v.y, -0.3, top), v.z))
	st.generate_normals()
	return st.commit()


