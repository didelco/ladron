class_name MenuStage
extends SubViewport
## Dioramas compartidos del prólogo y las lecciones de Historia.
## Los dioramas de tarjetas del menú antiguo viven en archive/menus-antiguos-2026-10-01.
## Los materiales y primitivas siguen compartidos por el mundo y los minijuegos.

const SIZE := Vector2i(420, 280)
const FOV := 22.0

# The night museum's palette.
const CREAM := Color("#e8d6b4")
const INK := Color("#1c1210")
const LILAC := Color("#7a6496")
const LILAC_DARK := Color("#3f2e52")
const PINK := Color("#7a2e44")
const PINK_DARK := Color("#551e30")
const MINT := Color("#4f8a7a")
const GRASS := Color("#3d6b52")
const GRASS_NIGHT := Color("#2c4f45")
const SOIL := Color("#4a2f22")
const GOLD := Color("#d8ac5c")
const WALL := Color("#8a7299")
const CASE := Color("#8fc4d6")
const GUARD := Color("#b8324c")
const GUARD_DARK := Color("#6e1a2c")
const WOOD := Color("#5a3a26")
const VELVET := Color("#5c1f33")

## Each card's backdrop: the dark behind its island.
const BACKDROP := {"story": Color("#15112a"), "lesson": Color("#1a1422")}

## One candy material per colour, shared by every stage: the menus build a
## dozen stages, each of dozens of pieces.
static var _materials := {}

var kind := ""
var arg := ""
## animating: the card has the focus
var active := false:
	set(on):
		if on and not active:
			_t = 0.0
		active = on
var _t := 0.0
var _root: Node3D
var _cam: Camera3D
var _figures: Array[Figure] = []
var _extra: Array[Node3D] = []
var _walls: Node3D
## The instanced walls and cases of the plan on show, for _rise: each
## {"mm": MultiMesh, "h": height, "cells": PackedVector3Array of (x, delay, z)}.
var _blocks: Array[Dictionary] = []


static func make(what: String) -> MenuStage:
	var parts := what.split(":")
	assert(parts[0] in ["story", "lesson"], "Los dioramas de menú están archivados; los menús activos usan Hub.")
	# The nights' lessons each have a scene of their own (LessonStage).
	var s: MenuStage = LessonStage.new() if parts[0] == "lesson" else MenuStage.new()
	s.kind = parts[0]
	s.arg = parts[1] if parts.size() > 1 else ""
	s._setup()
	return s


func _setup() -> void:
	size = SIZE
	own_world_3d = true
	Quality.setup_viewport(self)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKDROP.get(kind + ":" + arg, BACKDROP.get(kind, CREAM))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a5a9a")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# A warm lamp from the front left, casting soft shadows; cool moonlight
	# from behind that rims every rounded edge; and a pool of lamplight on
	# the island itself.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -30, 0)
	key.light_color = Color("#ffc98a")
	key.light_energy = 0.75
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	key.directional_shadow_max_distance = 30.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 150, 0)
	fill.light_color = Color("#8f9cff")
	fill.light_energy = 0.45
	add_child(fill)
	var pool := OmniLight3D.new()
	pool.position = Vector3(0.3, 1.8, 0.6)
	pool.light_color = Color("#ffb45a")
	pool.light_energy = 1.4
	pool.omni_range = 4.5
	add_child(pool)
	_root = Node3D.new()
	add_child(_root)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.rotation_degrees = Vector3(-35.264, 45, 0)
	add_child(_cam)
	_build()
	_pose(0.0)


## The scene of this kind, on its island.
func _build() -> void:
	if kind == "story":
		_story()


func _frame(span: float, lift: float) -> void:
	var distance := span * 0.5 / tan(deg_to_rad(FOV * 0.5))
	_cam.position = Vector3(0, lift, 0) + _cam.basis.z * distance
	# Depth of field only exists in Forward+/Mobile; in Compatibility the
	# card just stays sharp edge to edge instead of warning every frame.
	if Quality.is_compatibility():
		return
	var dof := CameraAttributesPractical.new()
	dof.dof_blur_far_enabled = true
	dof.dof_blur_far_distance = distance + span * 0.45
	dof.dof_blur_far_transition = span * 0.5
	dof.dof_blur_near_enabled = true
	dof.dof_blur_near_distance = distance - span * 0.45
	dof.dof_blur_near_transition = span * 0.35
	dof.dof_blur_amount = 0.08
	_cam.attributes = dof


func _process(dt: float) -> void:
	if not active:
		return
	_t += dt
	_animate(dt)


# --- Scenes -----------------------------------------------------------------------

## The museum at night: a pastel temple on a grassy island, lamp posts and
## trees, the moon and stars, a thief sneaking along the path.
func _story() -> void:
	_frame(3.9, 0.55)
	_island(3.6, 2.8, GRASS_NIGHT, SOIL)
	# The path to the door.
	_rounded(_root, 0.7, 1.3, 0.02, 0.2, Color("#6d5a4a"), Vector3(0.35, 0.01, 0.75))
	var front := Node3D.new()
	front.position = Vector3(0.35, 0, -0.45)
	_root.add_child(front)
	for s in 3:
		_rounded(front, 2.1 - s * 0.14, 0.62 - s * 0.1, 0.08, 0.06, CREAM.darkened(0.05 * s), Vector3(0, 0.04 + s * 0.08, 0.5 - s * 0.05))
	_rounded(front, 1.9, 0.7, 0.9, 0.08, LILAC, Vector3(0, 0.69, -0.05))
	for k in 5:
		var col := CylinderMesh.new()
		col.top_radius = 0.075
		col.bottom_radius = 0.085
		col.height = 0.9
		col.radial_segments = 16
		_mesh(front, col, CREAM, Vector3(-0.76 + k * 0.38, 0.69, 0.36))
	_rounded(front, 2.05, 0.82, 0.12, 0.06, PINK, Vector3(0, 1.2, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(2.05, 0.42, 0.82)
	_mesh(front, roof, PINK_DARK, Vector3(0, 1.47, 0))
	var door := _rounded(front, 0.32, 0.04, 0.5, 0.12, GOLD, Vector3(0, 0.49, 0.31))
	_glow(door, GOLD, 0.6)
	for side in [-1, 1]:
		var window := _rounded(front, 0.2, 0.03, 0.26, 0.08, Color("#ffe8a0"), Vector3(side * 0.57, 0.8, 0.31))
		_glow(window, Color("#ffd27a"), 2.0)
		_extra.append(window)
	# Two round trees and a lamp post, for scale and warmth.
	for t in [[-1.35, -0.3, 0.32], [1.45, 0.55, 0.26]]:
		_tree(Vector3(t[0], 0, t[1]), t[2])
	_lamp(Vector3(-0.55, 0, 0.95))
	var moon := SphereMesh.new()
	moon.radius = 0.26
	moon.height = 0.52
	_glow(_mesh(_root, moon, Color("#fff1c2"), Vector3(-1.4, 2.0, -1.3)), Color("#fff1c2"), 1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 14:
		var star := SphereMesh.new()
		star.radius = 0.025
		star.height = 0.05
		var s := _mesh(_root, star, Color.WHITE, Vector3(rng.randf_range(-2.2, 1.6), rng.randf_range(1.6, 2.6), rng.randf_range(-2.0, -0.6)))
		_glow(s, Color.WHITE, 2.5)
	var thief := _figure("thief", Color("#2ec4a6"), Color("#12705f"), 0.7)
	_extra.append(thief)


## A training mat, the sock to catch, and a wooden lookout to sneak past.
## This is a diorama only: it never borrows the live house or its progress.
func _pose(dt: float) -> void:
	if kind == "story":
		_figures[0].set_state(Vector3(-0.35, 0, 1.0), PI / 4, 0.0, dt)


func _animate(dt: float) -> void:
	if kind != "story":
		return
	var u := sin(_t * 0.9)
	var dir := 0.0 if cos(_t * 0.9) > 0 else PI
	var f := _figures[0]
	f.set_state(Vector3(u * 1.1 - 0.2, 0, 1.0), dir, 1.0 if u > 0.25 else 0.0, dt)
	if u <= 0.25:
		_hop(f, _t * 9.0, 0.06)
	for k in 2:
		var glass: StandardMaterial3D = _extra[k].get_meta("material")
		glass.emission_energy_multiplier = 1.4 + 1.0 * absf(sin(_t * (5.0 + k * 2.0)) * sin(_t * 1.7))


## Up in the air and back, squashing as it lands: a Figure's bounce.
func _hop(f: Figure, phase: float, height: float) -> void:
	var s := absf(sin(phase))
	f.position.y += s * height
	var base: float = f.get_meta("scale", 1.0)
	var squash := 0.14 * pow(1.0 - s, 8.0) if height > 0.05 else 0.0
	f.scale = Vector3(base * (1.0 + squash), base * (1.0 - squash), base * (1.0 + squash))


## The Zs float up from the sleeper; the ! hops over the runners and the
## beacon spins.
func _rise(t: float) -> void:
	for block in _blocks:
		var mm: MultiMesh = block.mm
		var h: float = block.h
		var cells: PackedVector3Array = block.cells
		for i in cells.size():
			var c := cells[i]
			var u := clampf((t - c.y) / 0.3, 0.0, 1.0)
			var s := maxf(0.01, _back_out(u))
			mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(1, s, 1)), Vector3(c.x, h * s / 2, c.z)))


static func _back_out(u: float) -> float:
	var c1 := 1.9
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)


# --- Pieces -----------------------------------------------------------------------

## The walls and cases of a plan, k a side, as one instanced mesh each
## rather than a node per tile: the large museum has hundreds of them.
func _plan_blocks(plan: MapGen, k: float, wall_h: float, case_h: float) -> void:
	_blocks.clear()
	for wall in [true, false]:
		var h := wall_h if wall else case_h
		var cells := PackedVector3Array()
		for y in plan.h:
			for x in plan.w:
				var t := plan.at(x, y)
				if t != Tiles.FLOOR and (t == Tiles.WALL) == wall:
					cells.append(Vector3((x - plan.w / 2.0 + 0.5) * k, (x + y) * 0.02, (y - plan.h / 2.0 + 0.5) * k))
		if cells.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = MuseumView._box(Vector3(k * 0.96, h, k * 0.96))
		mm.instance_count = cells.size()
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _material(WALL if wall else CASE)
		_walls.add_child(mmi)
		_blocks.append({"mm": mm, "h": h, "cells": cells})
	_rise(INF)


## The ground every scene stands on: a rounded slab, grass or paper on top
## of a thick coloured side, its top at y = 0.
func _island(w: float, d: float, top: Color, side: Color) -> void:
	_rounded(_root, w, d, 0.34, 0.32, side, Vector3(0, -0.21, 0))
	_rounded(_root, w - 0.06, d - 0.06, 0.08, 0.29, top, Vector3(0, -0.04, 0))


## A box with rounded vertical edges: two crossed boxes and a cylinder at
## each corner. Returns the node holding the pieces.
func _rounded(parent: Node3D, w: float, d: float, h: float, r: float, colour: Color, at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = at
	parent.add_child(g)
	r = minf(r, minf(w, d) * 0.5)
	_box(g, Vector3(w - 2.0 * r, h, d), colour, Vector3.ZERO)
	_box(g, Vector3(w, h, d - 2.0 * r), colour, Vector3.ZERO)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var c := CylinderMesh.new()
			c.top_radius = r
			c.bottom_radius = r
			c.height = h
			c.radial_segments = 16
			c.rings = 1
			_mesh(g, c, colour, Vector3(sx * (w * 0.5 - r), 0, sz * (d * 0.5 - r)))
	return g


func _tree(at: Vector3, r: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.04
	trunk.bottom_radius = 0.06
	trunk.height = 0.35
	_mesh(_root, trunk, SOIL, at + Vector3(0, 0.17, 0))
	for k in 3:
		var ball := SphereMesh.new()
		ball.radius = r * (1.0 - k * 0.25)
		ball.height = ball.radius * 2.0
		_mesh(_root, ball, GRASS.darkened(0.1 * k), at + Vector3(0, 0.35 + r * 0.7 + k * r * 0.55, 0))


## A lamp post with a warm globe, lighting the path.
func _lamp(at: Vector3) -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.025
	post.bottom_radius = 0.04
	post.height = 0.7
	_mesh(_root, post, INK, at + Vector3(0, 0.35, 0))
	var globe := SphereMesh.new()
	globe.radius = 0.08
	globe.height = 0.16
	_glow(_mesh(_root, globe, Color("#ffd27a"), at + Vector3(0, 0.75, 0)), Color("#ffb347"), 3.0)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 0.75, 0)
	light.light_color = Color("#ffb45a")
	light.light_energy = 1.6
	light.omni_range = 1.6
	_root.add_child(light)


## A die: a rounded cream cube with pink pips.
func _word(text: String, colour: Color, pixel: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = Hud.ARCADE
	l.font_size = 56
	l.pixel_size = pixel
	l.modulate = colour
	l.outline_size = 10
	l.outline_modulate = CREAM
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_root.add_child(l)
	return l


func _figure(what: String, colour: Color, accent: Color, scale_by: float) -> Figure:
	var f := Figure.make(what, colour, accent)
	f.set_meta("scale", scale_by)
	f.scale = Vector3.ONE * scale_by
	# The rim the game gives figures against its dark rooms washes them out
	# under the dioramas' daylight: toned down here.
	f.set_rim(0.2)
	_root.add_child(f)
	_figures.append(f)
	return f


func _box(parent: Node3D, s: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	return _mesh(parent, MuseumView._box(s), colour, at)


func _mesh(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _material(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


## Candy plastic: soft, a little glossy, with a rim of light round the edges.
static func _material(colour: Color) -> StandardMaterial3D:
	if not _materials.has(colour):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 0.55
		m.rim_enabled = true
		m.rim = 0.3
		m.rim_tint = 0.6
		if colour.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[colour] = m
	return _materials[colour]


## A glowing piece gets a material of its own: the shared one must not
## glow everywhere, and the lit windows flicker their own.
func _glow(node: Node3D, colour: Color, energy: float) -> void:
	var targets: Array = [node] if node is MeshInstance3D else node.get_children()
	var m := (_material(colour).duplicate()) as StandardMaterial3D
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	for t in targets:
		(t as MeshInstance3D).material_override = m
	if node is Node3D and not (node is MeshInstance3D):
		node.set_meta("material", m)
