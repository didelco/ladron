class_name NatureDecoration
extends RefCounted
## Decoración exterior del museo de naturaleza: jardín, plantas y cubierta.
## Recibe el edificio para conservar su malla compartida y LA MISMA instancia
## RNG para mantener el orden aleatorio. Los recursos comunes se cachean aquí.

var host: MuseumBuilding
static var _n_prims := {}
static var _n_plant_meshes := {}
static var _n_look: StandardMaterial3D

func _init(building: MuseumBuilding) -> void:
	host = building


## A balcony's planter along its edge, full: trees where it stands far out
## (they reach up past the floor over it, which stands in; not with
## `trees` off), bushes and flowers where it is near; a vine over its edge
## here and there. `low`: only flowers, no vine (under the crown, or next
## to a room).
func planter(face: Transform3D, u: float, y: float, bay: float, out: float, rng: RandomNumberGenerator, trees: bool, low: bool) -> void:
	var h := MuseumBuilding.N_PLANTER.x
	var mid := out - MuseumBuilding.N_PLANTER.y * 0.5
	host._n_part(Vector3(bay - 0.03, h, MuseumBuilding.N_PLANTER.y), MuseumBuilding.N_PLANTER_COLOUR, Vector3(u, y + h * 0.5, mid), face)
	var far: bool = trees and out >= MuseumBuilding.N_OUT[0]
	var n := maxi(2, roundi(bay / 0.28))
	for j in n:
		var at := Vector3(u - bay * 0.5 + (j + 0.5) * bay / n + rng.randf_range(-0.04, 0.04), y + h, mid)
		var kind := "bloom"
		var size := rng.randf_range(0.22, 0.3)
		if not low:
			var roll := rng.randf()
			if far and roll < 0.62:
				kind = ["tree", "tree", "pine", "birch", "autumn"][rng.randi() % 5]
				size = rng.randf_range(0.65, 0.95)
			else:
				kind = "bush" if roll < 0.8 else "bloom"
				size = rng.randf_range(0.26, 0.4)
		plant(kind, face * at, size, rng)
	if not low and rng.randf() < 0.6:
		plant("vine", face * Vector3(u + rng.randf_range(-bay * 0.35, bay * 0.35), y + h, out + 0.02), rng.randf_range(0.4, 0.7), rng)


## A room's hole in a balcony: lined with wood (the sides, its ceiling), a
## mossy floor, empty (its lit back and floor are the room's own); a bit
## of planter each side of it with a bush on it.
func niche(face: Transform3D, u: float, y: float, bay: float, out: float, hole: Vector2, rng: RandomNumberGenerator) -> void:
	var tall := MuseumBuilding.N_FLOOR - MuseumBuilding.N_SLAB
	for sx: int in [-1, 1]:
		host._n_part(Vector3(0.04, tall, out), MuseumBuilding.N_WOOD, Vector3(u + sx * (hole.x * 0.5 + 0.02), y + tall * 0.5, out * 0.5), face)
	host._n_part(Vector3(hole.x + 0.08, 0.02, out), MuseumBuilding.N_WOOD, Vector3(u, y + tall - 0.01, out * 0.5), face)
	host._n_part(Vector3(hole.x, 0.02, out - 0.02), MuseumBuilding.N_MOSS, Vector3(u, y + 0.01, out * 0.5), face)
	var side := (bay - hole.x) * 0.5 - 0.06
	if side < 0.05:
		return
	var h := MuseumBuilding.N_PLANTER.x
	for sx: int in [-1, 1]:
		var cu := u + sx * (bay * 0.5 - side * 0.5 - 0.015)
		host._n_part(Vector3(side, h, MuseumBuilding.N_PLANTER.y), MuseumBuilding.N_PLANTER_COLOUR, Vector3(cu, y + h * 0.5, out - MuseumBuilding.N_PLANTER.y * 0.5), face)
		plant("bloom" if sx > 0 else "bush", face * Vector3(cu, y + h, out - MuseumBuilding.N_PLANTER.y * 0.5), rng.randf_range(0.24, 0.3), rng)


## The square round the tower: white stone slabs (a little lighter or darker
## each, with grey joints between them) out to a kerb all round, none
## under the tower.
func square(rng: RandomNumberGenerator) -> void:
	var lot := MuseumBuilding.N_LOT * 2.0
	host._n_part(Vector3(lot, MuseumBuilding.N_PAVE - 0.01, lot), MuseumBuilding.N_JOINTS, Vector3(0, (MuseumBuilding.N_PAVE - 0.01) * 0.5, 0))
	var n := roundi(lot / MuseumBuilding.N_SLAB_SIZE)
	var step := lot / n
	for i in n:
		for j in n:
			var at := Vector3(-MuseumBuilding.N_LOT + (i + 0.5) * step, MuseumBuilding.N_PAVE - 0.01, -MuseumBuilding.N_LOT + (j + 0.5) * step)
			if absf(at.x) < MuseumBuilding.N_W * 0.5 - step * 0.5 and at.z < -step * 0.5 and at.z > -MuseumBuilding.N_D + step * 0.5:
				continue
			var tint := MuseumBuilding.N_PAVING.darkened(rng.randf_range(0.0, 0.05))
			host._n_part(Vector3(step - MuseumBuilding.N_JOINT, 0.02, step - MuseumBuilding.N_JOINT), tint, at)
	for k in 4:
		var turn := Transform3D(Basis(Vector3.UP, k * PI * 0.5), Vector3.ZERO)
		var h := MuseumBuilding.N_PAVE + MuseumBuilding.N_KERB.y
		host._n_part(Vector3(lot, h, MuseumBuilding.N_KERB.x), MuseumBuilding.N_KERB_COLOUR, Vector3(0, h * 0.5, MuseumBuilding.N_LOT - MuseumBuilding.N_KERB.x * 0.5), turn)


## A raised bed on the square, its foot's middle at `at`: a pale stone box
## (across, along) with grass on top.
func raised_bed(at: Vector3, s: Vector2) -> void:
	host._n_part(Vector3(s.x, 0.13, s.y), MuseumBuilding.N_PLANTER_COLOUR, at + Vector3(0, 0.065, 0))
	host._n_part(Vector3(s.x - 0.06, 0.02, s.y - 0.06), MuseumBuilding.N_GRASS, at + Vector3(0, 0.135, 0))


## The roof: a meadow with bushes and a little tree or two, solar panels
## tilted to the sky, a giant snail, a little wind turbine at the back.
func roof(roof_y: float, rng: RandomNumberGenerator) -> void:
	host._n_part(Vector3(MuseumBuilding.N_W - 0.1, 0.05, MuseumBuilding.N_D - 0.1), MuseumBuilding.N_GRASS, Vector3(0, roof_y + 0.025, -MuseumBuilding.N_D * 0.5))
	for j in 3:
		for i in 2:
			var at := Vector3(-0.95 + i * 0.6, roof_y + 0.2, -1.1 - j * 0.3)
			host._n_shape("box", MuseumBuilding.N_SOLAR, at, Vector3(0.56, 0.03, 0.3), Transform3D.IDENTITY, Basis(Vector3.RIGHT, -0.5))
			host._n_part(Vector3(0.03, 0.18, 0.03), MuseumBuilding.N_MULLION, at - Vector3(0, 0.1, 0))
	for j in 5:
		plant("bush" if j % 2 == 0 else "bloom", Vector3(rng.randf_range(0.1, 0.9), roof_y + 0.05, rng.randf_range(-1.8, -1.2)), rng.randf_range(0.3, 0.42), rng)
	plant("tree", Vector3(-0.6, roof_y + 0.05, -0.5), 0.8, rng)
	# A giant snail on its way along the front edge.
	snail(Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.8), Vector3(0.5, roof_y + 0.05, -0.7)))
	# The wind turbine: a mast, its head, and the rotor facing the camera.
	var base := Vector3(0.85, roof_y + 0.05, -1.65)
	var mast := 1.0
	host._n_shape("trunk", MuseumBuilding.N_WHITE, base + Vector3(0, mast * 0.5, 0), Vector3(0.08, mast, 0.08))
	var turn := Basis(Vector3.UP, PI * 0.25)
	host._n_shape("box", MuseumBuilding.N_WHITE, base + Vector3(0, mast, 0), Vector3(0.1, 0.1, 0.26), Transform3D.IDENTITY, turn)
	var rotor := MuseumBuilding.NRotor.new()
	rotor.transform = Transform3D(turn, base + Vector3(0, mast, 0) + turn * Vector3(0, 0, 0.16))
	rotor.speed = 1.6 if host.open else 0.0
	host.add_child(rotor)
	var blades := MuseumBuilding.NMesh.new()
	blades.add(primitive_triangles("ball"), MuseumBuilding._n_xf(Vector3.ZERO, Vector3(0.08, 0.08, 0.1)), host._shade(host._colour))
	for k in 3:
		var a := Basis(Vector3.BACK, k * TAU / 3.0)
		blades.add(primitive_triangles("box"), Transform3D(a, Vector3.ZERO) * MuseumBuilding._n_xf(Vector3(0, 0.32, 0), Vector3(0.06, 0.6, 0.015)), host._shade(MuseumBuilding.N_WHITE))
	var bm := MeshInstance3D.new()
	bm.mesh = blades.commit()
	bm.material_override = material()
	rotor.add_child(bm)


## A giant ladybird on the lawn, at `at` (its head along +z): a red shell
## with black spots and a black line down it, a black head with two
## antennae and six little legs.
func ladybird(at: Transform3D) -> void:
	host._n_shape("half", MuseumBuilding.N_LADYBIRD, Vector3(0, 0.12, 0), Vector3(0.8, 0.62, 1.0), at)
	host._n_part(Vector3(0.025, 0.02, 1.0), MuseumBuilding.N_BLACK, Vector3(0, 0.44, -0.02), at)
	host._n_shape("ball", MuseumBuilding.N_BLACK, Vector3(0, 0.22, 0.5), Vector3(0.42, 0.34, 0.34), at)
	for sx: int in [-1, 1]:
		host._n_shape("ball", Color.WHITE, Vector3(sx * 0.1, 0.3, 0.64), Vector3(0.1, 0.1, 0.06), at)
		host._n_shape("ball", MuseumBuilding.N_BLACK, Vector3(sx * 0.1, 0.3, 0.67), Vector3(0.05, 0.05, 0.03), at)
		host._n_shape("cyl", MuseumBuilding.N_BLACK, Vector3(sx * 0.14, 0.5, 0.6), Vector3(0.02, 0.36, 0.02), at, Basis(Vector3.BACK, -sx * 0.45) * Basis(Vector3.RIGHT, 0.4))
		host._n_shape("ball", MuseumBuilding.N_BLACK, Vector3(sx * 0.22, 0.66, 0.66), Vector3(0.07, 0.07, 0.07), at)
		for j in 3:
			host._n_shape("cyl", MuseumBuilding.N_BLACK, Vector3(sx * 0.4, 0.07, -0.25 + j * 0.25), Vector3(0.03, 0.2, 0.03), at, Basis(Vector3.BACK, sx * 1.1))
	# The spots: on the shell's curve, three a side.
	var spots: Array[Vector2] = [Vector2(0.17, 0.25), Vector2(0.24, -0.08), Vector2(0.14, -0.33)]
	for sx: int in [-1, 1]:
		for p in spots:
			var x := sx * p.x
			var z := p.y
			var r := Vector2(x / 0.4, z / 0.5)
			var h := sqrt(maxf(0.0, 1.0 - r.length_squared()))
			var n := Vector3(x / 0.16, h / 0.31, z / 0.25).normalized()
			var spot := Basis.looking_at(n) * Basis(Vector3.RIGHT, PI * 0.5)
			host._n_shape("cyl", MuseumBuilding.N_BLACK, Vector3(x, 0.12 + h * 0.31, z) + n * 0.005, Vector3(0.12, 0.02, 0.12), at, spot)


## A waterfall off one of the terraces, down the tower's side, into a
## small pond at its foot: a bright sheet down the wall, a couple of
## ripples where it lands. Dimmer while the museum is still shut.
func waterfall(rng: RandomNumberGenerator) -> void:
	# A rocky outcrop standing free in the square, clear of the tower's own
	# planted terraces (which would hide it): water falling its face into a
	# pond, real particles for the fall and the splash where it lands.
	var at := Vector3(-1.15, 0.0, 2.5)
	var rock := Color("#7d7468")
	var h := 1.3
	for i in 4:
		var s := 1.0 - i * 0.16
		host._box(Vector3(0.5 * s, h / 4.0, 0.4 * s), host._shade(rock.lightened(i * 0.03)), at + Vector3(0.05 * i, MuseumBuilding.N_PAVE + h * (i + 0.5) / 4.0, -0.05 * i))
	var tint := MuseumBuilding.N_WATER if host.open else MuseumBuilding.N_WATER.darkened(0.3)
	var energy := 1.2 if host.open else 0.35
	var pond := at + Vector3(0.32, 0.0, 0.05)
	host._box(Vector3(0.9, 0.05, 0.75), MuseumBuilding.N_POND_EDGE, pond + Vector3(0, MuseumBuilding.N_PAVE + 0.005, 0))
	host._glow(Vector3(0.72, 0.02, 0.58), tint, pond + Vector3(0, MuseumBuilding.N_PAVE + 0.03, 0), energy * 0.8)
	if not host.open:
		return
	var drop_mesh := host._ball(0.03)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = tint.lightened(0.3)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_mesh.material = fm
	# The fall: droplets sheeting down the rock face.
	var fall := GPUParticles3D.new()
	fall.position = at + Vector3(0.15, MuseumBuilding.N_PAVE + h, -0.1)
	host.add_child(fall)
	fall.amount = 40
	fall.lifetime = 0.9
	fall.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 4.0
	pm.gravity = Vector3(0, -2.6, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.4
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.16, 0.02, 0.05)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	fall.process_material = pm
	fall.draw_pass_1 = drop_mesh
	# The splash where it lands: a quick burst of droplets bouncing up.
	var splash := GPUParticles3D.new()
	splash.position = pond + Vector3(0, MuseumBuilding.N_PAVE + 0.04, 0)
	host.add_child(splash)
	splash.amount = 16
	splash.lifetime = 0.5
	splash.local_coords = true
	var sm := ParticleProcessMaterial.new()
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 45.0
	sm.gravity = Vector3(0, -3.0, 0)
	sm.initial_velocity_min = 0.3
	sm.initial_velocity_max = 0.6
	sm.scale_min = 0.3
	sm.scale_max = 0.6
	sm.color_ramp = fade_tex
	splash.process_material = sm
	splash.draw_pass_1 = drop_mesh


## A giant snail, at `at` (its head along +z): a long soft body,
## a big spiral shell on its back, two stalks with its eyes on top.
func snail(at: Transform3D) -> void:
	host._n_shape("ball", MuseumBuilding.N_SNAIL, Vector3(0, 0.1, 0.05), Vector3(0.32, 0.2, 1.1), at)
	host._n_shape("ball", MuseumBuilding.N_SNAIL, Vector3(0, 0.22, 0.48), Vector3(0.24, 0.26, 0.26), at)
	host._n_shape("ball", MuseumBuilding.N_SHELL, Vector3(0, 0.44, -0.12), Vector3(0.36, 0.62, 0.62), at)
	host._n_shape("ring", MuseumBuilding.N_SHELL_DARK, Vector3(0, 0.44, -0.12), Vector3(0.62, 0.5, 0.62), at, Basis(Vector3.BACK, PI * 0.5))
	host._n_shape("ring", MuseumBuilding.N_SHELL_DARK, Vector3(0.02, 0.46, -0.1), Vector3(0.36, 0.5, 0.36), at, Basis(Vector3.BACK, PI * 0.5))
	host._n_shape("ball", MuseumBuilding.N_SHELL_DARK, Vector3(0.05, 0.47, -0.08), Vector3(0.12, 0.14, 0.14), at)
	for sx: int in [-1, 1]:
		host._n_shape("cyl", MuseumBuilding.N_SNAIL, Vector3(sx * 0.06, 0.42, 0.56), Vector3(0.03, 0.3, 0.03), at, Basis(Vector3.BACK, -sx * 0.3))
		host._n_shape("ball", Color.WHITE, Vector3(sx * 0.1, 0.57, 0.57), Vector3(0.09, 0.09, 0.09), at)
		host._n_shape("ball", MuseumBuilding.N_BLACK, Vector3(sx * 0.1, 0.57, 0.61), Vector3(0.045, 0.045, 0.03), at)


## A plant of a kind (_n_plant_mesh) standing at `at`, `size` tall: its own
## width, turn and tint (shut, darker).
func plant(kind: String, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var wide := size * rng.randf_range(0.85, 1.2)
	var turn := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, size, wide))
	var v := rng.randf_range(0.85, 1.12)
	var tint := host._shade(Color(v * rng.randf_range(0.95, 1.05), v, v * rng.randf_range(0.95, 1.05)))
	if not host._n_plants.has(kind):
		host._n_plants[kind] = []
	(host._n_plants[kind] as Array).append([Transform3D(turn, at), tint])


func flush_plants() -> void:
	for kind: String in host._n_plants:
		var list: Array = host._n_plants[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = plant_mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material()
		if kind in ["bush", "bloom", "vine"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		host.add_child(mmi)
	host._n_plants = {}


## A kind of plant, about a unit tall, low-poly with flat faces like the
## town's (TownBuilder's colours): a tree, a pine, a birch, an autumn tree,
## a bush, a bush in flower, or a vine hanging down from its top.
static func plant_mesh(kind: String) -> ArrayMesh:
	if _n_plant_meshes.has(kind):
		return _n_plant_meshes[kind]
	var st := MuseumBuilding.NMesh.new()
	var leaf := primitive_triangles("leaf")
	# Each leaf cluster turned a little of its own about the trunk, not all
	# stacked square on the same axis: reads as a crown grown this way, not
	# parts glued on.
	var rot := func(a: float) -> Basis: return Basis(Vector3.UP, a)
	match kind:
		"tree", "autumn":
			var leaves := (TownBuilder.OAK_GREEN if kind == "tree" else TownBuilder.AUTUMN_LEAVES).lightened(MuseumBuilding.N_LEAF_LIGHT)
			st.add(primitive_triangles("trunk"), MuseumBuilding._n_xf(Vector3(0, 0.22, 0), Vector3(0.12, 0.45, 0.12)), TownBuilder.TRUNK)
			st.add(leaf, MuseumBuilding._n_xf(Vector3(0, 0.6, 0), Vector3.ONE * 0.62, rot.call(0.3)), leaves)
			st.add(leaf, MuseumBuilding._n_xf(Vector3(0.19, 0.78, 0.06), Vector3.ONE * 0.46, rot.call(1.1)), leaves.lightened(0.08))
			st.add(leaf, MuseumBuilding._n_xf(Vector3(-0.16, 0.74, -0.11), Vector3.ONE * 0.42, rot.call(-0.8)), leaves.darkened(0.08))
			st.add(leaf, MuseumBuilding._n_xf(Vector3(0.02, 0.9, -0.13), Vector3.ONE * 0.3, rot.call(2.0)), leaves.lightened(0.14))
			st.add(leaf, MuseumBuilding._n_xf(Vector3(-0.22, 0.56, 0.17), Vector3.ONE * 0.28, rot.call(-1.7)), leaves.darkened(0.04))
		"pine":
			st.add(primitive_triangles("trunk"), MuseumBuilding._n_xf(Vector3(0, 0.15, 0), Vector3(0.14, 0.3, 0.14)), TownBuilder.TRUNK)
			for k in 4:
				st.add(primitive_triangles("cone"), MuseumBuilding._n_xf(Vector3(0, 0.36 + k * 0.165, 0), Vector3(0.62 - k * 0.13, 0.36, 0.62 - k * 0.13), rot.call(k * 0.5)), TownBuilder.PINE_GREEN.lightened(MuseumBuilding.N_LEAF_LIGHT + k * 0.05))
		"birch":
			st.add(primitive_triangles("trunk"), MuseumBuilding._n_xf(Vector3(0, 0.4, 0), Vector3(0.07, 0.8, 0.07)), TownBuilder.BIRCH_BARK)
			st.add(leaf, MuseumBuilding._n_xf(Vector3(0, 0.68, 0), Vector3(0.38, 0.58, 0.38), rot.call(0.6)), TownBuilder.BIRCH_GREEN.lightened(MuseumBuilding.N_LEAF_LIGHT))
			st.add(leaf, MuseumBuilding._n_xf(Vector3(0.13, 0.85, 0.05), Vector3(0.28, 0.42, 0.28), rot.call(-1.3)), TownBuilder.BIRCH_GREEN.lightened(MuseumBuilding.N_LEAF_LIGHT + 0.08))
			st.add(leaf, MuseumBuilding._n_xf(Vector3(-0.12, 0.78, -0.08), Vector3(0.24, 0.36, 0.24), rot.call(2.3)), TownBuilder.BIRCH_GREEN.darkened(0.06))
		"bush", "bloom":
			st.add(leaf, MuseumBuilding._n_xf(Vector3(0, 0.3, 0), Vector3(0.94, 0.66, 0.94), rot.call(0.4)), TownBuilder.BUSH_GREEN.lightened(MuseumBuilding.N_LEAF_LIGHT + 0.08))
			st.add(leaf, MuseumBuilding._n_xf(Vector3(0.29, 0.26, 0.1), Vector3(0.6, 0.46, 0.6), rot.call(-1.5)), TownBuilder.BUSH_GREEN.lightened(MuseumBuilding.N_LEAF_LIGHT + 0.16))
			st.add(leaf, MuseumBuilding._n_xf(Vector3(-0.24, 0.2, -0.15), Vector3(0.5, 0.4, 0.5), rot.call(1.9)), TownBuilder.BUSH_GREEN.darkened(0.04))
			if kind == "bloom":
				for k in 7:
					var a := k * TAU / 7.0 + 0.4
					st.add(leaf, MuseumBuilding._n_xf(Vector3(cos(a) * 0.36, 0.42 + 0.1 * sin(a * 3.0), sin(a) * 0.36), Vector3.ONE * 0.2), MuseumBuilding.N_FLOWERS[k % MuseumBuilding.N_FLOWERS.size()])
		"vine":
			for k in 4:
				st.add(leaf, MuseumBuilding._n_xf(Vector3(0.06 * sin(k * 2.1), -0.12 - k * 0.22, 0.03 * k), Vector3(0.36, 0.34, 0.26) * (1.0 - k * 0.15)), TownBuilder.POPLAR_GREEN.lightened(MuseumBuilding.N_LEAF_LIGHT + 0.05 + k * 0.03))
	var mesh := st.commit()
	_n_plant_meshes[kind] = mesh
	return mesh


## A primitive's triangles, a unit across (and tall): a box, a ball (and a
## rougher one for leaves), a half ball, a cylinder, a cone, a tapered
## trunk, a ring.
static func primitive_triangles(kind: String) -> PackedVector3Array:
	if _n_prims.has(kind):
		return _n_prims[kind]
	var mesh: PrimitiveMesh
	match kind:
		"box":
			mesh = BoxMesh.new()
		"ball", "leaf", "half":
			var b := SphereMesh.new()
			b.radius = 0.5
			b.height = 1.0
			b.radial_segments = 9 if kind == "leaf" else 12
			b.rings = 4 if kind == "leaf" else 6
			if kind == "half":
				b.height = 0.5
				b.is_hemisphere = true
			mesh = b
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.38
			t.outer_radius = 0.5
			t.rings = 16
			t.ring_segments = 6
			mesh = t
		_:
			var c := CylinderMesh.new()
			c.bottom_radius = 0.5
			c.top_radius = 0.0 if kind == "cone" else (0.35 if kind == "trunk" else 0.5)
			c.height = 1.0
			c.radial_segments = 6 if kind == "cone" else 8
			c.rings = 0
			mesh = c
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tris := PackedVector3Array()
	for i in index:
		tris.append(verts[i])
	_n_prims[kind] = tris
	return tris


## The look of all that is baked: its own colours, lit like the rest.
static func material() -> StandardMaterial3D:
	if _n_look == null:
		_n_look = StandardMaterial3D.new()
		_n_look.vertex_color_use_as_albedo = true
		_n_look.vertex_color_is_srgb = true
		_n_look.roughness = 0.6
		_n_look.rim_enabled = true
		_n_look.rim = 0.3
		_n_look.rim_tint = 0.6
	return _n_look
