class_name MenuStage
extends SubViewport
## A little 3D diorama for a menu card, toy-box style: a rounded island on a
## coloured backdrop, candy-plastic materials, a warm key light and a cool
## fill, a long lens at the isometric angle with a touch of tilt-shift blur.
## Still while the card waits; alive while it has the focus — thieves hop
## and sneak, guards patrol, plans pop up out of the floor.
##
## Kinds: "story" (the museum at night, a thief on the path), "generative"
## (a floor plan that keeps redrawing itself, dice rolling over it),
## "players:1" / "players:2" (on a podium), "guards:easy|medium|hard",
## "museum:small|medium|large".

const SIZE := Vector2i(420, 280)
const FOV := 22.0

# The toy palette.
const CREAM := Color("#fff4e0")
const INK := Color("#2a1b4e")
const LILAC := Color("#b9a6ff")
const LILAC_DARK := Color("#7a64e0")
const PINK := Color("#ff7fa8")
const PINK_DARK := Color("#d9557f")
const MINT := Color("#7ee0c3")
const GRASS := Color("#6fd08c")
const GRASS_NIGHT := Color("#3f9f86")
const SOIL := Color("#9a6a4a")
const GOLD := Color("#ffc53d")
const WALL := Color("#9d8cf0")
const CASE := Color("#8fe3ff")
const GUARD := Color("#e0405e")
const GUARD_DARK := Color("#8c1f3a")

## Each card's backdrop: the colour behind its island.
const BACKDROP := {
	"story": Color("#28306e"),
	"generative": Color("#9ad8ff"),
	"players": Color("#ffcf6e"),
	"guards:easy": Color("#b9f0cf"),
	"guards:medium": Color("#ffe39a"),
	"guards:hard": Color("#ff9fae"),
	"museum": Color("#d6ccff"),
}

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
var _plan_seed := 1
var _walls: Node3D
## The instanced walls and cases of the plan on show, for _rise: each
## {"mm": MultiMesh, "h": height, "cells": PackedVector3Array of (x, delay, z)}.
var _blocks: Array[Dictionary] = []


static func make(what: String) -> MenuStage:
	var s := MenuStage.new()
	var parts := what.split(":")
	s.kind = parts[0]
	s.arg = parts[1] if parts.size() > 1 else ""
	s._setup()
	return s


func _setup() -> void:
	size = SIZE
	own_world_3d = true
	msaa_3d = Viewport.MSAA_4X
	var night := kind == "story"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKDROP.get(kind + ":" + arg, BACKDROP.get(kind, CREAM))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8e9cff") if night else Color("#fff3e6")
	env.ambient_light_energy = 0.45 if night else 0.55
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
	# Warm key from the front left, casting soft shadows; a cool fill from
	# behind that rims every rounded edge.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-52, -30, 0)
	key.light_color = Color("#b8c4ff") if night else Color("#fff0d8")
	key.light_energy = 0.55 if night else 1.15
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	key.directional_shadow_max_distance = 30.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-28, 150, 0)
	fill.light_color = Color("#9ec1ff")
	fill.light_energy = 0.35
	add_child(fill)
	_root = Node3D.new()
	add_child(_root)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.rotation_degrees = Vector3(-35.264, 45, 0)
	add_child(_cam)
	match kind:
		"story": _story()
		"generative": _generative()
		"players": _players(int(arg))
		"guards": _guards(arg)
		"museum": _museum(arg)
	_pose(0.0)


## Point the camera so a span of this many units fills the card, looking at
## a spot this high, with the tilt-shift blur either side of it.
func _frame(span: float, lift: float) -> void:
	var distance := span * 0.5 / tan(deg_to_rad(FOV * 0.5))
	_cam.position = Vector3(0, lift, 0) + _cam.basis.z * distance
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
	_rounded(_root, 0.7, 1.3, 0.02, 0.2, CREAM.darkened(0.15), Vector3(0.35, 0.01, 0.75))
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


## A floor plan on a sheet of paper, popping up wall by wall, a pair of dice
## tumbling over it; every so often it redraws itself.
func _generative() -> void:
	_frame(4.0, 0.35)
	_island(3.6, 2.8, CREAM, Color("#6aa8ff"))
	_walls = Node3D.new()
	_root.add_child(_walls)
	_build_plan(20260924)
	for i in 2:
		var die := _die()
		die.position = Vector3(0.9 - i * 0.55, 0.9 + i * 0.2, -0.6 + i * 0.5)
		die.rotation = Vector3(0.4 + i, 0.7 * i, 0.3)
		_root.add_child(die)
		_extra.append(die)


func _build_plan(seed: int) -> void:
	for c in _walls.get_children():
		c.queue_free()
	var plan := MapGen.generate(seed, 21, 15, "rect")
	_plan_blocks(plan, 3.2 / plan.w, 0.3, 0.16)


## One thief or two on a podium, under confetti colours.
func _players(n: int) -> void:
	_frame(2.5, 0.85)
	var tiers := [[1.25, 0.26, PINK], [1.05, 0.18, CREAM], [0.9, 0.08, GOLD]]
	var y := 0.0
	for tier in tiers:
		var c := CylinderMesh.new()
		c.top_radius = tier[0]
		c.bottom_radius = tier[0]
		c.height = tier[1]
		c.radial_segments = 48
		_mesh(_root, c, tier[2], Vector3(0, y + tier[1] / 2.0, 0))
		y += tier[1]
	var ring := TorusMesh.new()
	ring.inner_radius = 1.02
	ring.outer_radius = 1.1
	ring.ring_segments = 48
	_mesh(_root, ring, GOLD, Vector3(0, 0.27, 0))
	# Confetti stars stuck round the rim.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 16:
		var a := i * TAU / 16
		var bit := _box(_root, Vector3(0.08, 0.02, 0.08), [PINK, MINT, LILAC, GOLD][i % 4], Vector3(cos(a) * 1.15, 0.53, sin(a) * 1.15))
		bit.rotation.y = rng.randf() * TAU
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 3.2, 0.3)
	spot.rotation_degrees = Vector3(-84, 0, 0)
	spot.spot_angle = 24
	spot.light_energy = 2.5
	spot.light_color = Color("#fff1c8")
	spot.shadow_enabled = true
	_root.add_child(spot)
	_figure("thief", Color("#2ec4a6"), Color("#12705f"), 1.0)
	if n == 2:
		_figure("thief", Color("#f0a13a"), Color("#8a5410"), 1.0)


## The guards of a difficulty: one dozing by a bench, two on their rounds
## between cases, three running with a red beacon spinning.
func _guards(level: String) -> void:
	_frame(3.1, 0.55)
	_island(3.3, 2.5, CREAM.darkened(0.04), LILAC_DARK)
	# A couple of glass cases to guard.
	for c in [Vector3(-0.9, 0, -0.7), Vector3(0.95, 0, -0.55)]:
		_rounded(_root, 0.46, 0.46, 0.3, 0.08, LILAC, c + Vector3(0, 0.15, 0))
		var glass := _rounded(_root, 0.4, 0.4, 0.3, 0.06, Color(CASE, 0.5), c + Vector3(0, 0.45, 0))
		var gm := _material(CASE).duplicate() as StandardMaterial3D
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_color = Color(CASE, 0.45)
		for part in glass.get_children():
			(part as MeshInstance3D).material_override = gm
		var gem := SphereMesh.new()
		gem.radius = 0.09
		gem.height = 0.18
		gem.radial_segments = 6
		gem.rings = 3
		_glow(_mesh(_root, gem, PINK, c + Vector3(0, 0.42, 0)), PINK, 0.5)
	var n: int = {"easy": 1, "medium": 2, "hard": 3}[level]
	if level == "easy":
		# A bench to nod off by.
		_rounded(_root, 0.9, 0.3, 0.06, 0.05, Color("#c98a5a"), Vector3(0.25, 0.32, 0.55))
		for side in [-1, 1]:
			_box(_root, Vector3(0.06, 0.3, 0.26), Color("#8a5a3c"), Vector3(0.25 + side * 0.36, 0.15, 0.55))
	for i in n:
		var g := _figure("guard", GUARD, GUARD_DARK, 1.0)
		var torch := SpotLight3D.new()
		torch.position = Vector3(0, 1.0, 0.3)
		torch.rotation = Vector3(-0.45, PI, 0)
		torch.spot_angle = 26
		torch.spot_range = 3.0
		torch.light_energy = 3.0
		torch.light_color = Color("#ff4060") if level == "hard" else Color("#ffe7a8")
		g.add_child(torch)
	if level == "easy":
		for k in 3:
			var z := _word("Z", Color("#6b5fb8"), 0.006)
			_extra.append(z)
	elif level == "hard":
		# A beacon on a post, spinning red.
		var post := CylinderMesh.new()
		post.top_radius = 0.05
		post.bottom_radius = 0.06
		post.height = 0.9
		_mesh(_root, post, INK, Vector3(-1.25, 0.45, 0.6))
		var lamp := SphereMesh.new()
		lamp.radius = 0.13
		lamp.height = 0.2
		_glow(_mesh(_root, lamp, Color("#ff3048"), Vector3(-1.25, 0.95, 0.6)), Color("#ff3048"), 2.5)
		var beam := SpotLight3D.new()
		beam.position = Vector3(-1.25, 0.95, 0.6)
		beam.spot_angle = 30
		beam.spot_range = 4.0
		beam.light_energy = 4.0
		beam.light_color = Color("#ff3048")
		_root.add_child(beam)
		_extra.append(beam)
		_extra.append(_word("!", Color("#ff3048"), 0.008))


## A museum of this size, on its own island, to the same scale as the others.
func _museum(which: String) -> void:
	_frame(4.3, 0.0)
	var dims: Dictionary = Museum.SIZES[which]
	var plan := MapGen.generate(777, dims.w, dims.h, "rect")
	var k := 0.075
	_island(plan.w * k + 0.36, plan.h * k + 0.36, CREAM, LILAC_DARK)
	_walls = Node3D.new()
	_root.add_child(_walls)
	_plan_blocks(plan, k, 0.2, 0.09)


# --- Animation --------------------------------------------------------------------

## The resting pose: what the card shows while it waits.
func _pose(dt: float) -> void:
	match kind:
		"story":
			_figures[0].set_state(Vector3(-0.35, 0, 1.0), PI / 4, 0.0, dt)
		"players":
			for i in _figures.size():
				var x := 0.0 if _figures.size() == 1 else (i - 0.5) * 0.75
				_figures[i].set_state(Vector3(x, 0.52, -x * 0.3), PI / 4, 0.0, dt)
		"guards":
			var n := _figures.size()
			for i in n:
				var x := (i - (n - 1) / 2.0) * 0.8
				_figures[i].set_state(Vector3(x, 0, 0.35 + absf(x) * 0.1), PI / 4, 0.0, dt)
			_place_labels(0.0)


func _animate(dt: float) -> void:
	match kind:
		"story":
			# Tiptoeing along the path and back, ducking down half the way.
			var u := sin(_t * 0.9)
			var dir := 0.0 if cos(_t * 0.9) > 0 else PI
			var f := _figures[0]
			f.set_state(Vector3(u * 1.1 - 0.2, 0, 1.0), dir, 1.0 if u > 0.25 else 0.0, dt)
			if u <= 0.25:
				_hop(f, _t * 9.0, 0.06)
			for k in 2:
				var glass: StandardMaterial3D = _extra[k].get_meta("material")
				glass.emission_energy_multiplier = 1.4 + 1.0 * absf(sin(_t * (5.0 + k * 2.0)) * sin(_t * 1.7))
		"generative":
			if int(_t / 2.0) != int((_t - dt) / 2.0):
				_plan_seed += 1
				_build_plan(20260924 + _plan_seed * 97)
			_rise(fmod(_t, 2.0))
			for i in 2:
				var die: Node3D = _extra[i]
				die.rotation += Vector3(1.3, 0.9, 0.6) * dt * (1.0 + i * 0.4)
				die.position.y = 0.9 + i * 0.2 + sin(_t * 3.0 + i) * 0.08
		"museum":
			_rise(_t * 0.8)
			_root.rotation.y = sin(_t * 0.8) * 0.35
		"players":
			# Hopping for joy, one after the other, turning to show off.
			for i in _figures.size():
				var x := 0.0 if _figures.size() == 1 else (i - 0.5) * 0.75
				var f := _figures[i]
				f.set_state(Vector3(x, 0.52, -x * 0.3), PI / 4 + sin(_t * 2.0 + i) * 0.6, 0.0, dt)
				_hop(f, _t * 6.0 + i * PI * 0.5, 0.25)
		"guards":
			var n := _figures.size()
			var speed: float = {"easy": 0.0, "medium": 1.0, "hard": 2.4}[arg]
			for i in n:
				var f := _figures[i]
				if arg == "easy":
					# Dozing on its feet: a slow sway, and a start now and then.
					f.set_state(Vector3(0, 0, 0.35), PI / 4 + sin(_t * 0.8) * 0.2, 0.0, dt)
					if fmod(_t, 4.0) > 3.7:
						_hop(f, (fmod(_t, 4.0) - 3.7) / 0.3 * PI, 0.12)
					continue
				var a := _t * speed + i * TAU / n
				var pos := Vector3(cos(a) * 0.85, 0, 0.1 + sin(a) * 0.7)
				var heading := Vector2(-sin(a) * 0.85, cos(a) * 0.7)
				f.set_state(pos, atan2(heading.y, heading.x), 0.0, dt)
				_hop(f, _t * (8.0 if arg == "hard" else 5.0) + i, 0.1 if arg == "hard" else 0.04)
			_place_labels(_t)


## Up in the air and back, squashing as it lands: a Figure's bounce.
func _hop(f: Figure, phase: float, height: float) -> void:
	var s := absf(sin(phase))
	f.position.y += s * height
	var base: float = f.get_meta("scale", 1.0)
	var squash := 0.14 * pow(1.0 - s, 8.0) if height > 0.05 else 0.0
	f.scale = Vector3(base * (1.0 + squash), base * (1.0 - squash), base * (1.0 + squash))


## The Zs float up from the sleeper; the ! hops over the runners and the
## beacon spins.
func _place_labels(t: float) -> void:
	var z := 0
	for node in _extra:
		if node is SpotLight3D:
			node.rotation = Vector3(-0.35, t * 5.0, 0)
		elif node is Label3D:
			var l := node as Label3D
			if arg == "easy":
				var u := fmod(t * 0.5 + z / 3.0, 1.0)
				l.position = Vector3(0.25 + u * 0.4, 1.15 + u * 0.8, 0.35)
				l.modulate.a = 1.0 - u
				l.scale = Vector3.ONE * (0.6 + u * 0.8)
				z += 1
			else:
				l.position = Vector3(0, 1.7 + absf(sin(t * 6.0)) * 0.18, 0.1)


## Walls pop up out of the floor one diagonal after another, overshooting a
## little like a jelly; INF stands them all at full height.
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
func _die() -> Node3D:
	var g := Node3D.new()
	var s := 0.34
	var body := _rounded(g, s, s, s, 0.07, CREAM, Vector3.ZERO)
	body.position = Vector3.ZERO
	var faces := [[Vector3(0, 0, 1), 1], [Vector3(0, 0, -1), 6], [Vector3(1, 0, 0), 3], [Vector3(-1, 0, 0), 4], [Vector3(0, 1, 0), 2], [Vector3(0, -1, 0), 5]]
	var spots := {1: [Vector2.ZERO], 2: [Vector2(-1, -1), Vector2(1, 1)], 3: [Vector2(-1, -1), Vector2.ZERO, Vector2(1, 1)],
		4: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)],
		5: [Vector2(-1, -1), Vector2(1, -1), Vector2.ZERO, Vector2(-1, 1), Vector2(1, 1)],
		6: [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]}
	for f in faces:
		var n: Vector3 = f[0]
		var u := Vector3(n.y, n.z, n.x) if n.x == 0 else Vector3(0, 1, 0)
		var v := n.cross(u)
		for p in spots[f[1]]:
			var pip := SphereMesh.new()
			pip.radius = 0.03
			pip.height = 0.03
			_mesh(g, pip, PINK_DARK, n * (s * 0.5) + u * p.x * 0.08 + v * p.y * 0.08)
	return g


## A floating word over the scene, in the menu's font.
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
		m.roughness = 0.42
		m.rim_enabled = true
		m.rim = 0.35
		m.rim_tint = 0.5
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
