class_name MenuStage
extends SubViewport
## A little 3D scene for a menu card, seen in axonometric: an orthographic
## camera at the isometric angle, on a slab of museum floor. Still while the
## card waits; alive while it has the focus — thieves creep, guards patrol,
## plans build themselves.
##
## Kinds: "story" (the museum at night, a thief on the steps), "generative"
## (a floor plan that keeps redrawing itself), "players:1" / "players:2",
## "guards:easy|medium|hard", "museum:small|medium|large".

const SIZE := Vector2i(360, 240)
const FLOOR := Color("#2b2834")
const FLOOR_EDGE := Color("#1b1822")
const WALL := Color("#6f6479")
const WALL_SIDE := Color("#3a3346")
const STONE := Color("#5a4fa0")
const STONE_LIT := Color("#7d72c4")
const GOLD := Color("#ffe066")

var kind := ""
var arg := ""
## animating: the card has the focus
var active := false
var _t := 0.0
var _root: Node3D
var _figures: Array[Figure] = []
var _extra: Array[Node3D] = []
var _plan_seed := 1
var _walls: Node3D


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
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#8a86b8")
	env.environment.ambient_light_energy = 0.55
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	_root = Node3D.new()
	add_child(_root)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	# True isometric: 35.26 degrees down, 45 round.
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = cam.basis.z * 20.0 + Vector3(0, 0.45, 0)
	cam.size = 3.4
	add_child(cam)
	match kind:
		"story": _story()
		"generative": _generative(cam)
		"players": _players(int(arg))
		"guards": _guards(arg)
		"museum": _museum(arg, cam)
	# Close in on the figures: they are what those cards are about.
	if kind == "players":
		_frame(cam, 2.3, 0.5)
	elif kind == "guards":
		_frame(cam, 2.7, 0.45)
	_pose(0.0)


func _frame(cam: Camera3D, span: float, lift: float) -> void:
	cam.size = span
	cam.position = cam.basis.z * 20.0 + Vector3(0, lift, 0)


func _process(dt: float) -> void:
	if not active:
		return
	_t += dt
	_animate(dt)


# --- Scenes -----------------------------------------------------------------------

## A slab of museum floor: the stage everything stands on.
func _slab(w: float, d: float) -> void:
	_box(_root, Vector3(w, 0.16, d), FLOOR, Vector3(0, -0.08, 0))
	_box(_root, Vector3(w + 0.06, 0.06, d + 0.06), FLOOR_EDGE, Vector3(0, -0.19, 0))


## The museum at night: steps, columns, a pediment, one lit window, the moon
## behind and a thief on the steps.
func _story() -> void:
	_slab(3.2, 2.4)
	var front := Node3D.new()
	front.position = Vector3(0.2, 0, -0.5)
	_root.add_child(front)
	for s in 3:
		_box(front, Vector3(2.2 - s * 0.16, 0.08, 0.5 - s * 0.1), STONE.darkened(0.1 * s), Vector3(0, 0.04 + s * 0.08, 0.55 - s * 0.05))
	_box(front, Vector3(2.0, 1.0, 0.7), STONE, Vector3(0, 0.74, -0.05))
	for k in 5:
		var col := CylinderMesh.new()
		col.top_radius = 0.07
		col.bottom_radius = 0.08
		col.height = 1.0
		_mesh(front, col, STONE_LIT, Vector3(-0.8 + k * 0.4, 0.74, 0.34))
	_box(front, Vector3(2.1, 0.12, 0.8), STONE_LIT, Vector3(0, 1.3, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(2.1, 0.45, 0.8)
	_mesh(front, roof, STONE_LIT, Vector3(0, 1.585, 0))
	var window := _box(front, Vector3(0.22, 0.34, 0.02), GOLD, Vector3(0.2, 0.75, 0.31))
	_glow(window, GOLD, 1.5)
	_extra.append(window)
	var moon := SphereMesh.new()
	moon.radius = 0.28
	moon.height = 0.56
	var m := _mesh(_root, moon, Color("#f4ecc8"), Vector3(-1.3, 2.1, -1.2))
	_glow(m, Color("#f4ecc8"), 0.8)
	var thief := _figure("thief", Color("#2ec4a6"), Color("#12705f"))
	thief.scale = Vector3.ONE * 0.75
	_extra.append(thief)


## A floor plan extruded into walls: redrawn every so often while it has the
## focus, the walls growing up out of the floor.
func _generative(cam: Camera3D) -> void:
	_slab(3.3, 2.5)
	cam.size = 3.6
	_walls = Node3D.new()
	_root.add_child(_walls)
	_build_plan(20260924)


func _build_plan(seed: int) -> void:
	for c in _walls.get_children():
		c.queue_free()
	var plan := MapGen.generate(seed, 21, 15, "rect")
	var k := 3.1 / plan.w
	for y in plan.h:
		for x in plan.w:
			var t := plan.at(x, y)
			if t == Tiles.FLOOR:
				continue
			var h := 0.28 if t == Tiles.WALL else 0.14
			var colour := WALL if t == Tiles.WALL else Color("#a8d8e8")
			var b := _box(_walls, Vector3(k, h, k), colour, Vector3((x - plan.w / 2.0 + 0.5) * k, h / 2, (y - plan.h / 2.0 + 0.5) * k))
			b.set_meta("h", h)
			b.set_meta("delay", (x + y) * 0.02)


## One thief or two on a round spotlight.
func _players(n: int) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.15
	disc.height = 0.12
	_mesh(_root, disc, FLOOR, Vector3(0, -0.06, 0))
	var light := CylinderMesh.new()
	light.top_radius = 0.85
	light.bottom_radius = 0.85
	light.height = 0.01
	var l := _mesh(_root, light, Color("#fff1b8"), Vector3(0, 0.005, 0))
	_glow(l, Color("#fff1b8"), 0.35)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, 3, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.spot_angle = 22
	spot.light_energy = 3.0
	spot.light_color = Color("#fff1b8")
	_root.add_child(spot)
	_figure("thief", Color("#2ec4a6"), Color("#12705f"))
	if n == 2:
		_figure("thief", Color("#f0a13a"), Color("#8a5410"))


## The guards of a difficulty: one dozing, two on their rounds, three
## running with their torches red.
func _guards(level: String) -> void:
	_slab(3.2, 2.4)
	var n: int = {"easy": 1, "medium": 2, "hard": 3}[level]
	for i in n:
		var g := _figure("guard", Color("#9b2c3f"), Color("#5e1826"))
		var torch := SpotLight3D.new()
		torch.position = Vector3(0, 0.9, 0.2)
		torch.rotation_degrees = Vector3(-25, 0, 0)
		torch.spot_angle = 28
		torch.spot_range = 3.0
		torch.light_energy = 4.0
		torch.light_color = Color("#ff3d6e") if level == "hard" else Color("#ffd479")
		g.add_child(torch)
	if level == "easy":
		for k in 3:
			var z := Label3D.new()
			z.text = "Z"
			z.font = Hud.ARCADE
			z.font_size = 48
			z.pixel_size = 0.006
			z.modulate = Color("#9aa0c8")
			z.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_root.add_child(z)
			_extra.append(z)
	elif level == "hard":
		var bang := Label3D.new()
		bang.text = "!"
		bang.font = Hud.ARCADE
		bang.font_size = 64
		bang.pixel_size = 0.008
		bang.modulate = Color("#ff3d6e")
		bang.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_root.add_child(bang)
		_extra.append(bang)


## A museum of this size, to the same scale as the others.
func _museum(which: String, cam: Camera3D) -> void:
	var dims: Dictionary = Museum.SIZES[which]
	var plan := MapGen.generate(777, dims.w, dims.h, "rect")
	var k := 0.075
	cam.size = 3.8
	_walls = Node3D.new()
	_root.add_child(_walls)
	_box(_walls, Vector3(plan.w * k, 0.08, plan.h * k), FLOOR, Vector3(0, -0.04, 0))
	for y in plan.h:
		for x in plan.w:
			var t := plan.at(x, y)
			if t == Tiles.FLOOR:
				continue
			var h := 0.16 if t == Tiles.WALL else 0.07
			_box(_walls, Vector3(k, h, k), WALL if t == Tiles.WALL else Color("#a8d8e8"), Vector3((x - plan.w / 2.0 + 0.5) * k, h / 2, (y - plan.h / 2.0 + 0.5) * k))


# --- Animation --------------------------------------------------------------------

## The resting pose: what the card shows while it waits.
func _pose(dt: float) -> void:
	match kind:
		"story":
			_figures[0].set_state(Vector3(-0.9, 0, 0.6), -PI / 4, 0.0, dt)
		"players":
			for i in _figures.size():
				var x := 0.0 if _figures.size() == 1 else (i - 0.5) * 0.7
				_figures[i].set_state(Vector3(x, 0, 0), PI / 4, 0.0, dt)
		"guards":
			for i in _figures.size():
				var x := (i - (_figures.size() - 1) / 2.0) * 0.8
				_figures[i].set_state(Vector3(x, 0, x * 0.3), PI / 4, 0.0, dt)
			_place_labels(0.0)


func _animate(dt: float) -> void:
	match kind:
		"story":
			# Tiptoeing along the steps and back, on all fours half the way.
			var u := sin(_t * 0.9)
			var x := u * 1.0 - 0.2
			var dir := 0.0 if cos(_t * 0.9) > 0 else PI
			_figures[0].set_state(Vector3(x, 0, 0.6), dir, 1.0 if u > 0.2 else 0.0, dt)
			var window: MeshInstance3D = _extra[0]
			(window.material_override as StandardMaterial3D).emission_energy_multiplier = 1.0 + 0.8 * absf(sin(_t * 7.0) * sin(_t * 2.3))
		"generative":
			if int(_t / 1.6) != int((_t - dt) / 1.6):
				_plan_seed += 1
				_build_plan(20260924 + _plan_seed * 97)
			_rise(fmod(_t, 1.6))
			_root.rotation.y = sin(_t * 0.5) * 0.25
		"museum":
			_root.rotation.y = sin(_t * 0.8) * 0.4
		"players":
			# Round the spotlight, one after the other.
			for i in _figures.size():
				var a := _t * 1.4 + i * PI
				var pos := Vector3(cos(a), 0, sin(a)) * 0.55
				var heading := Vector2(-sin(a), cos(a))
				_figures[i].set_state(pos, atan2(heading.y, heading.x), 0.0, dt)
		"guards":
			var n := _figures.size()
			var speed: float = {"easy": 0.0, "medium": 0.9, "hard": 2.2}[arg]
			for i in n:
				if arg == "easy":
					# Dozing on its feet: a slow sway.
					_figures[i].set_state(Vector3(0, 0, 0), PI / 4 + sin(_t * 0.8) * 0.15, 0.0, dt)
					continue
				var a := _t * speed + i * TAU / n
				var r := 0.75
				var pos := Vector3(cos(a) * r, 0, sin(a) * r * 0.8)
				var heading := Vector2(-sin(a), cos(a) * 0.8)
				_figures[i].set_state(pos, atan2(heading.y, heading.x), 0.0, dt)
			_place_labels(_t)


## The Zs float up from the sleeper; the ! hops over the runners.
func _place_labels(t: float) -> void:
	for k in _extra.size():
		var l := _extra[k] as Label3D
		if l == null:
			continue
		if arg == "easy":
			var u := fmod(t * 0.5 + k / 3.0, 1.0)
			l.position = Vector3(0.25 + u * 0.4, 1.1 + u * 0.8, 0)
			l.modulate.a = 1.0 - u
			l.scale = Vector3.ONE * (0.6 + u * 0.8)
		else:
			l.position = Vector3(0, 1.6 + absf(sin(t * 6.0)) * 0.15, 0)


## Walls grow up out of the floor, one diagonal after another.
func _rise(t: float) -> void:
	for b in _walls.get_children():
		if not b.has_meta("h"):
			continue
		var h: float = b.get_meta("h")
		var u := clampf((t - float(b.get_meta("delay"))) / 0.25, 0.0, 1.0)
		var s := maxf(0.01, u)
		(b as Node3D).scale.y = s
		(b as Node3D).position.y = h * s / 2


# --- Pieces -----------------------------------------------------------------------

func _figure(what: String, colour: Color, accent: Color) -> Figure:
	var f := Figure.make(what, colour, accent)
	_root.add_child(f)
	_figures.append(f)
	return f


func _box(parent: Node3D, s: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	return _mesh(parent, MuseumView._box(s), colour, at)


func _mesh(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MuseumView.toon(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


func _glow(mi: MeshInstance3D, colour: Color, energy: float) -> void:
	var m := mi.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
