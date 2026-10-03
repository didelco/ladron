class_name TownVegetation
extends RefCounted
## Trees, plant meshes, woods and hedgerows; no separate RNG or caches.
## The context keeps the original shared state and construction order.


## A tree at `at`: in town (a garden, a yard, a park) mostly the kit's, now
## and then a birch, an oak or a flowering bush; out in the wild, whatever
## grows there (_kind_at).
func tree(host: TownBuilder, at: Vector3, wild := false) -> void:
	var kind := host._kind_at(Vector2(at.x, at.z)) if wild else host._pick({"kit": 6.0, "oak": 1.5, "birch": 1.0, "autumn": 0.4, "bloom": 0.8})
	if kind == "kit":
		var path := "suburbios/tree-large.glb" if host._rng.randf() < 0.6 else "suburbios/tree-small.glb"
		host._add(path, at, host._rng.randf() * TAU, TownBuilder.TILE * host._rng.randf_range(1.5, 2.1), host._own(0.0))
	else:
		host._plant(kind, at)


## What grows at p out in the wild, by the lie of the land and its patches:
## pines up the slope and in their stands, poplars by the water, birch
## groves and autumn copses, oaks and the kit's trees everywhere else,
## a bush now and then.
func kind_at(host: TownBuilder, p: Vector2) -> String:
	var d := host.across(p)
	var conifer := host._conifers.get_noise_2dv(p) * 0.5 + 0.5
	var grove := host._groves.get_noise_2dv(p)
	var on_slope := d > TownBuilder.RIVER_WIDTH * 0.5 and d < TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.SLOPE + 1.0
	return host._pick({
		"kit": 1.5,
		"oak": 2.2 * (1.0 - conifer),
		"pine": 4.0 * conifer * conifer + (2.5 if on_slope else 0.0),
		"birch": 4.0 * maxf(0.0, grove - 0.1),
		"autumn": 4.0 * maxf(0.0, -grove - 0.25),
		"poplar": 3.0 if absf(d) < TownBuilder.RIVER_WIDTH * 0.5 + 3.0 else 0.15,
		"bush": 0.7,
	})


## One of the keys, each as likely as its weight.
func pick(host: TownBuilder, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := host._rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return String(weights.keys()[0])


## A plant of a kind made here, standing at `at`: its own size, width, turn
## and tint (autumn's leaves anything from gold to red).
func plant(host: TownBuilder, kind: String, at: Vector3) -> void:
	var sizes := {"pine": Vector2(1.7, 2.8), "oak": Vector2(1.3, 2.0), "birch": Vector2(1.4, 2.2), "poplar": Vector2(2.0, 3.0),
		"autumn": Vector2(1.3, 2.0), "bush": Vector2(0.5, 0.9), "bloom": Vector2(0.5, 0.8)}
	var span: Vector2 = sizes[kind]
	var size := host._rng.randf_range(span.x, span.y)
	if not host._shown(at, size, kind):
		return
	var wide := size * host._rng.randf_range(0.85, 1.15)
	var basis := Basis(Vector3.UP, host._rng.randf() * TAU).scaled(Vector3(wide, size, wide))
	var v := host._rng.randf_range(0.85, 1.12)
	var tint := Color(v * host._rng.randf_range(0.95, 1.05), v, v * host._rng.randf_range(0.95, 1.05))
	if kind == "autumn":
		var hues := [Color(1, 1, 1), Color(1.15, 1.1, 0.6), Color(1.05, 0.72, 0.7)]
		tint *= hues[host._rng.randi() % hues.size()] as Color
	if not host._plants.has(kind):
		host._plants[kind] = []
	(host._plants[kind] as Array).append([Transform3D(basis, at), tint])


## A hedge from a to b, `tall` high, on the ground between them.
func hedge(host: TownBuilder, a: Vector3, b: Vector3, tall := 0.34) -> void:
	var run := Vector3(b.x - a.x, 0, b.z - a.z)
	if run.length() < 0.05:
		return
	var mid := (a + b) * 0.5
	if not host._shown(mid, run.length() * 0.5 + 0.3, "hedge"):
		return
	var basis := Basis.looking_at(run.normalized(), Vector3.UP) * Basis.from_scale(Vector3(host._rng.randf_range(0.9, 1.1), tall * host._rng.randf_range(0.85, 1.15), run.length() + 0.06))
	var v := host._rng.randf_range(0.88, 1.1)
	if not host._plants.has("hedge"):
		host._plants["hedge"] = []
	(host._plants["hedge"] as Array).append([Transform3D(basis, mid), Color(v, v, v)])


## Every plant made here as one MultiMesh a kind, each in its own tint.
func flush_plants(host: TownBuilder) -> void:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.rim_enabled = true
	m.rim = 0.3
	for kind in host._plants:
		var list: Array = host._plants[kind]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = host._plant_mesh(String(kind))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		if kind in ["bush", "bloom"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.root.add_child(mmi)
	host._plants.clear()


## A kind of plant, a metre or so high (a hedge a metre long), low and
## flat-faced like the kits': a trunk and a crown of cones or balls.
func plant_mesh(host: TownBuilder, kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"pine":
			host._shape(st, host._cone(0.05, 0.075, 0.16), Vector3(0, 0.08, 0), TownBuilder.TRUNK.darkened(0.1))
			host._shape(st, host._cone(0.055, 0.07, 0.22), Vector3(0, 0.24, 0), TownBuilder.TRUNK)
			for k in 4:
				host._shape(st, host._cone(0.0, 0.32 - k * 0.07, 0.34), Vector3(0, 0.38 + k * 0.165, 0), TownBuilder.PINE_GREEN.lightened(k * 0.05))
		"oak", "autumn":
			var leaves := TownBuilder.OAK_GREEN if kind == "oak" else TownBuilder.AUTUMN_LEAVES
			host._shape(st, host._cone(0.05, 0.07, 0.45), Vector3(0, 0.22, 0), TownBuilder.TRUNK)
			host._shape(st, host._ball(0.3), Vector3(0, 0.62, 0), leaves)
			host._shape(st, host._ball(0.24), Vector3(0.17, 0.78, 0.07), leaves.lightened(0.08))
			host._shape(st, host._ball(0.22), Vector3(-0.15, 0.74, -0.11), leaves.darkened(0.08))
			host._shape(st, host._ball(0.16), Vector3(0.02, 0.9, -0.12), leaves.lightened(0.14))
			host._shape(st, host._ball(0.14), Vector3(-0.2, 0.58, 0.16), leaves.darkened(0.04))
		"birch":
			host._shape(st, host._cone(0.03, 0.04, 0.8), Vector3(0, 0.4, 0), TownBuilder.BIRCH_BARK)
			host._shape(st, host._ball(0.19), Vector3(0, 0.68, 0), TownBuilder.BIRCH_GREEN, Vector3(1, 1.3, 1))
			host._shape(st, host._ball(0.14), Vector3(0.12, 0.86, 0.05), TownBuilder.BIRCH_GREEN.lightened(0.08), Vector3(1, 1.2, 1))
			host._shape(st, host._ball(0.12), Vector3(-0.11, 0.8, -0.08), TownBuilder.BIRCH_GREEN.darkened(0.06), Vector3(1, 1.2, 1))
		"poplar":
			host._shape(st, host._cone(0.04, 0.05, 0.3), Vector3(0, 0.15, 0), TownBuilder.TRUNK)
			host._shape(st, host._ball(0.15), Vector3(0, 0.44, 0), TownBuilder.POPLAR_GREEN.darkened(0.04), Vector3(1, 1.4, 1))
			host._shape(st, host._ball(0.165), Vector3(0, 0.68, 0), TownBuilder.POPLAR_GREEN, Vector3(1, 1.5, 1))
			host._shape(st, host._ball(0.13), Vector3(0, 0.92, 0), TownBuilder.POPLAR_GREEN.lightened(0.08), Vector3(1, 1.3, 1))
		"bush", "bloom":
			host._shape(st, host._ball(0.46), Vector3(0, 0.24, 0), TownBuilder.BUSH_GREEN, Vector3(1, 0.66, 1))
			host._shape(st, host._ball(0.3), Vector3(0.27, 0.2, 0.1), TownBuilder.BUSH_GREEN.lightened(0.07), Vector3(1, 0.72, 1))
			host._shape(st, host._ball(0.24), Vector3(-0.22, 0.16, -0.16), TownBuilder.BUSH_GREEN.darkened(0.05), Vector3(1, 0.7, 1))
			if kind == "bloom":
				for k in 6:
					var a := k * TAU / 6.0 + 0.4
					host._shape(st, host._ball(0.09), Vector3(cos(a) * 0.36, 0.34 + 0.08 * sin(a * 3.0), sin(a) * 0.36), TownBuilder.BLOSSOM)
		"hedge":
			# A base block, clipped square, with a row of smaller lobes along
			# the top so it reads as trimmed foliage, not a smooth slab.
			host._shape(st, BoxMesh.new(), Vector3(0, 0.36, 0), TownBuilder.HEDGE_GREEN, Vector3(0.34, 0.72, 1.0))
			for k in 5:
				var z := -0.42 + k * 0.21
				var h := 0.1 if k % 2 == 0 else 0.06
				host._shape(st, host._ball(0.18), Vector3(0, 0.72 + h, z), TownBuilder.HEDGE_GREEN.lightened(0.05 + 0.03 * (k % 2)), Vector3(1.0, 0.62, 1.15))
	st.generate_normals()
	return st.commit()


## A primitive's triangles into st, each corner its own (flat faces),
## stretched and moved, in one colour.
func shape(host: TownBuilder, st: SurfaceTool, mesh: PrimitiveMesh, at: Vector3, colour: Color, stretch := Vector3.ONE) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(colour)
	for i in index:
		st.add_vertex(verts[i] * stretch + at)


func cone(host: TownBuilder, top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 6
	c.rings = 0
	return c


func ball(host: TownBuilder, r: float) -> SphereMesh:
	var b := SphereMesh.new()
	b.radius = r
	b.height = r * 2.0
	b.radial_segments = 6
	b.rings = 3
	return b


## Trees wherever there is land and nothing built: along the river, up the
## slope, between the districts and out past them. Thicker on the slope,
## a lone one here and there in the fields, bushes under them; each what
## grows there (_kind_at).
func woods(host: TownBuilder) -> void:
	var y := -(TownBuilder.REACH + 6.0)
	while y < TownBuilder.REACH + 6.0:
		var x := -(TownBuilder.REACH + 6.0)
		while x < TownBuilder.REACH + 6.0:
			var p := Vector2(x + host._rng.randf_range(-0.5, 0.5) * TownBuilder.WOOD_STEP, y + host._rng.randf_range(-0.5, 0.5) * TownBuilder.WOOD_STEP)
			x += TownBuilder.WOOD_STEP
			if host.seen.is_valid() and not host.seen.call(Vector3(p.x, host.ground(p), p.y), TownBuilder.TILE * 2.0):
				continue
			var d := host.across(p)
			if absf(d) < TownBuilder.RIVER_WIDTH * 0.5 + 0.5:
				continue
			var on_slope := d > 0.0 and d < TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.SLOPE
			var share := 0.85 if on_slope else 0.55
			if host._farmland(p):
				share = 0.05
			if host._rng.randf() > share:
				continue
			if host._built(p) or host._on_road(p) or host._near_taken(p) or host._rocky(p) > 0.55 or host._on_walk(p):
				continue
			var at := Vector3(p.x, host.ground(p) - 0.02, p.y)
			if host._rng.randf() < 0.15:
				host._plant("bush", at)
			else:
				host._tree(at, true)
		y += TownBuilder.WOOD_STEP


## Out of town, where the fields are (_fields): open land clear of the
## water and the slope, the rocks, the pitches and the districts.
func farmland(host: TownBuilder, p: Vector2) -> bool:
	if host._fields.get_noise_2dv(p) < -0.05:
		return false
	var d := host.across(p)
	if d > -(TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.WALK_OFF + TownBuilder.WALK_WIDTH + 1.5) and d < TownBuilder.RIVER_WIDTH * 0.5 + TownBuilder.SLOPE + 0.5:
		return false
	return host._rocky(p) == 0.0 and not host._in_sports(p) and not host._built(p, 1.0)


## Hedges round the fields: lines along the river's bends and across them,
## FIELD or so apart, a gap for a gate now and then, a tree in them here
## and there; not over a road nor into a house's garden.
func hedgerows(host: TownBuilder) -> void:
	for across_lines in [false, true]:
		var line := -TownBuilder.REACH * 1.2 + host._rng.randf() * TownBuilder.FIELD
		while line < TownBuilder.REACH * 1.2:
			var t := -TownBuilder.REACH * 1.2
			var prev := Vector3.INF
			while t < TownBuilder.REACH * 1.2:
				var f := Vector2(line, t) if across_lines else Vector2(t, line)
				var p := host.point(f.x, host.river_at(f.x) + f.y)
				t += TownBuilder.HEDGE_STEP
				var ok := absf(p.x) < TownBuilder.REACH and absf(p.y) < TownBuilder.REACH and host._rng.randf() > 0.015
				if ok and host.seen.is_valid():
					ok = host.seen.call(Vector3(p.x, 0, p.y), 1.0)
				if not ok or not host._farmland(p) or host._on_road(p) or host._near_taken(p, 0.3):
					prev = Vector3.INF
					continue
				var here := Vector3(p.x, host.ground(p), p.y)
				if prev != Vector3.INF:
					host._hedge(prev, here)
				prev = here
				if host._rng.randf() < 0.07:
					host._tree(here, true)
			line += TownBuilder.FIELD * host._rng.randf_range(0.75, 1.3)


