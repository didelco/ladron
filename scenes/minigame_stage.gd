class_name MinigameStage
extends SubViewport
## The little 3D scene a minigame (Minigame) is played on, in the menus' toy
## style (MenuStage): soft plastic in the night museum's colours, a warm lamp
## and a cool moon, no words. Drawn with a clear background into the box
## beside the thief (MinigameBox).
##
##   lockpick: a brass lock seen from the front with a dial round its
##     keyhole: a ring of marks, the green sector lit among them, a steel
##     needle going round; the pins in a row on top, popping up green as
##     they set.
##   wires: a walnut panel with brass trim and a wire per step; the cut
##     ones hang apart, and over the next one a glowing arrow points the
##     way to pull.
##   steady: the alarm panel's glass in a brass frame, a ring drawn on it (smaller
##     the harder the level) and a flat rubber suction cup drifting about,
##     its rim glowing green while it is in and red out;
##     a row of lamps along the top lights up as the seconds go by.
##   balance: the thief itself, in its colours and its statue pose on its
##     pedestal, swaying as it sways in the museum.

const SIZE := Vector2i(220, 170)
const FOV := 24.0

const CREAM := MenuStage.CREAM
const INK := MenuStage.INK
const GOLD := MenuStage.GOLD
const WOOD := MenuStage.WOOD
const STEEL := Color("#b8bcc8")
const GREEN := Color("#4ade80")
const RED := Color("#ff3d6e")
const WIRE_COLOURS := [Color("#e8594f"), Color("#4dabf7"), Color("#ffd43b"), Color("#5cc98a"), Color("#c77dff"), Color("#e8d6b4")]

## The dial: how many marks round it, and how far out they sit.
const MARKS := 48
const DIAL := 0.4

var game: Minigame
var _root: Node3D
var _cam: Camera3D
var _kind := ""
var _steps := 0
# The lock.
var _marks: Array[MeshInstance3D] = []
var _mark_dim: StandardMaterial3D
var _mark_lit: StandardMaterial3D
var _needle: Node3D
var _needle_mat: StandardMaterial3D
var _pins: Array[MeshInstance3D] = []
var _pin_lit: StandardMaterial3D
var _pin_dim: StandardMaterial3D
# The glass.
var _ring: Node3D
var _cup: Node3D
var _cup_mat: StandardMaterial3D
var _lamps: Array[MeshInstance3D] = []
var _lamp_dim: StandardMaterial3D
# The statue.
var _statue: Figure
var _colour := Color("#2ec4a6")
# The panel.
var _wires: Array[Node3D] = []
var _arrow: Node3D
var _spark: OmniLight3D
## 0..1 flashes, fading: a success, a miss
var _good := 0.0
var _bad := 0.0
var _t := 0.0


func _init() -> void:
	size = SIZE
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a5a9a")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The menus' lighting: a warm lamp front left with soft shadows, a cool
	# moon rimming the edges from behind.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color("#ffc98a")
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_color = Color("#8f9cff")
	fill.light_energy = 0.5
	add_child(fill)
	_spark = OmniLight3D.new()
	_spark.light_color = RED
	_spark.omni_range = 1.4
	_spark.light_energy = 0.0
	add_child(_spark)
	_cam = Camera3D.new()
	_cam.fov = FOV
	add_child(_cam)


## The ring's radius on the glass: the game's ring is 1.
const RING := 0.4


## Play this game (or none: the scene goes still and stops drawing); the
## thief's colour dresses the statue.
func show_game(g: Minigame, colour := Color("#2ec4a6")) -> void:
	if g and g.kind == "balance" and colour != _colour:
		_colour = colour
		_kind = ""
	game = g
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if g else SubViewport.UPDATE_DISABLED
	if g == null:
		return
	if g.kind != _kind or g.steps != _steps or _root == null:
		_build(g.kind, g.steps)
	for e in g.events:
		if e in ["pin", "snip", "done"]:
			_good = 1.0
		elif e in ["slip", "spark"]:
			_bad = 1.0


func _build(kind: String, steps: int) -> void:
	if _root:
		_root.queue_free()
	_root = Node3D.new()
	add_child(_root)
	_kind = kind
	_steps = steps
	_pins.clear()
	_marks.clear()
	_wires.clear()
	_lamps.clear()
	_statue = null
	# A little above and to the side, as the menus look at things, but
	# nearly face on: the job must read at a glance.
	_cam.rotation_degrees = Vector3(-12, 14, 0)
	# How much of the scene, top to bottom, fills the box.
	var span: float = {"lockpick": 1.6, "steady": 1.35, "balance": 1.95}.get(kind, 1.3)
	var look: float = {"lockpick": 0.08, "balance": 0.9}.get(kind, 0.0)
	if kind == "balance":
		# Straight on: the sway reads left and right.
		_cam.rotation_degrees = Vector3(-8, 0, 0)
	_cam.position = Vector3(0, look, 0) + _cam.basis.z * (span * 0.5 / tan(deg_to_rad(FOV * 0.5)))
	match kind:
		"lockpick": _build_lock(steps)
		"steady": _build_glass(steps)
		"balance": _build_statue()
		_: _build_panel(steps)


func _build_lock(steps: int) -> void:
	# The lock, brass, its face to the camera, on a walnut collar.
	var collar := _cylinder(0.62, 0.62, 0.3, WOOD)
	collar.rotation_degrees.x = 90
	collar.position.z = -0.12
	var body := _cylinder(0.54, 0.54, 0.34, GOLD)
	body.rotation_degrees.x = 90
	# The keyhole in the middle: a dark round and its slot.
	var hole := _cylinder(0.07, 0.07, 0.04, INK)
	hole.rotation_degrees.x = 90
	hole.position = Vector3(0, 0.03, 0.17)
	_box(Vector3(0.05, 0.14, 0.04), INK, Vector3(0, -0.05, 0.17))
	# The dial: a ring of marks round the keyhole; the green ones are where
	# the pin sets.
	_mark_dim = MenuStage._material(GOLD.darkened(0.45))
	_mark_lit = _glowing(GREEN, 2.2)
	for i in MARKS:
		var a := float(i) / MARKS * TAU
		var mark := _box(Vector3(0.045, 0.1, 0.03), GOLD, Vector3(sin(a) * DIAL, cos(a) * DIAL, 0.18))
		mark.rotation.z = -a
		_marks.append(mark)
	# The pins, a row along the top, brass until set.
	_pin_dim = MenuStage._material(GOLD.darkened(0.25))
	_pin_lit = _glowing(GREEN, 1.8)
	for i in steps:
		var x := (i - (steps - 1) * 0.5) * 0.17
		var pin := _cylinder(0.05, 0.05, 0.16, GOLD)
		pin.position = Vector3(x, 0.66, 0.0)
		_pins.append(pin)
	# The needle: steel, from the keyhole out to the marks, turning about
	# the middle.
	_needle = Node3D.new()
	_needle.position.z = 0.21
	_root.add_child(_needle)
	_needle_mat = MenuStage._material(STEEL).duplicate()
	var arm := MeshInstance3D.new()
	arm.mesh = MuseumView._box(Vector3(0.04, DIAL - 0.02, 0.03))
	arm.material_override = _needle_mat
	arm.position.y = (DIAL - 0.02) * 0.5
	_needle.add_child(arm)
	var point := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.05
	cone.height = 0.09
	cone.radial_segments = 3
	point.mesh = cone
	point.material_override = _needle_mat
	point.position.y = DIAL - 0.02
	point.scale = Vector3(1, 1, 0.5)
	_needle.add_child(point)
	var hub := MeshInstance3D.new()
	hub.mesh = _cylinder_mesh(0.045, 0.04)
	hub.material_override = MenuStage._material(MenuStage.VELVET)
	hub.rotation_degrees.x = 90
	_needle.add_child(hub)


func _build_glass(steps: int) -> void:
	# The pane in a brass frame, the case's pale blue, see-through.
	_box(Vector3(1.62, 1.12, 0.06), GOLD, Vector3(0, 0, -0.08))
	# Dark behind, so the glass reads as glass: a sheen, not a board.
	_box(Vector3(1.5, 1.0, 0.02), INK, Vector3(0, 0, -0.035))
	var pane := _box(Vector3(1.5, 1.0, 0.04), Color("#bfe6f5", 0.22), Vector3(0, 0, 0.0))
	pane.material_override = _glowing(Color("#bfe6f5", 0.22), 0.25)
	pane.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A streak of light across it.
	var streak := _box(Vector3(0.08, 1.1, 0.01), Color(1, 1, 1, 0.12), Vector3(-0.45, 0, 0.02))
	streak.rotation_degrees.z = -30
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The ring scored on the glass, sized to the level each frame.
	_ring = Node3D.new()
	_ring.position.z = 0.03
	_root.add_child(_ring)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING - 0.012
	torus.outer_radius = RING + 0.012
	torus.rings = 48
	ring.mesh = torus
	ring.material_override = _glowing(CREAM, 0.8)
	ring.rotation_degrees.x = 90
	_ring.add_child(ring)
	# The suction cup: a flat disc of pale rubber on the glass, its rim
	# lit green or red, a little brass handle to hold it by.
	_cup = Node3D.new()
	_root.add_child(_cup)
	var r := Minigame.CUP * RING
	var disc := MeshInstance3D.new()
	disc.mesh = _cylinder_mesh(r, 0.025)
	disc.material_override = MenuStage._material(Color(CREAM, 0.55))
	disc.rotation_degrees.x = 90
	_cup.add_child(disc)
	_cup_mat = _glowing(GREEN, 1.6)
	var rim := MeshInstance3D.new()
	var lip := TorusMesh.new()
	lip.inner_radius = r - 0.018
	lip.outer_radius = r + 0.004
	lip.rings = 32
	rim.mesh = lip
	rim.material_override = _cup_mat
	rim.rotation_degrees.x = 90
	rim.position.z = 0.015
	_cup.add_child(rim)
	var stem := MeshInstance3D.new()
	stem.mesh = _cylinder_mesh(0.018, 0.08)
	stem.material_override = MenuStage._material(GOLD)
	stem.rotation_degrees.x = 90
	stem.position.z = 0.05
	_cup.add_child(stem)
	var knob := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.035
	ball.height = 0.07
	knob.mesh = ball
	knob.material_override = MenuStage._material(GOLD)
	knob.position.z = 0.1
	_cup.add_child(knob)
	# The lamps along the top of the frame.
	_lamp_dim = MenuStage._material(WOOD)
	for i in steps:
		var lamp := MeshInstance3D.new()
		var b := SphereMesh.new()
		b.radius = 0.04
		b.height = 0.08
		lamp.mesh = b
		lamp.position = Vector3((i - (steps - 1) * 0.5) * 0.13, 0.52, 0.02)
		_root.add_child(lamp)
		_lamps.append(lamp)
	_pin_lit = _glowing(GREEN, 1.8)


func _build_statue() -> void:
	# The pedestal: a low stone block on a walnut base.
	_box(Vector3(0.62, 0.08, 0.42), WOOD, Vector3(0, 0.04, 0))
	_box(Vector3(0.5, 0.3, 0.34), CREAM, Vector3(0, 0.23, 0))
	_statue = Figure.make("thief", _colour, _colour.darkened(0.5))
	_statue.set_rim(0.2)
	_root.add_child(_statue)


func _build_panel(steps: int) -> void:
	# The panel: walnut, a brass trim round it, a dark face behind the wires.
	_box(Vector3(1.62, 1.12, 0.1), GOLD, Vector3(0, 0, -0.08))
	_box(Vector3(1.5, 1.0, 0.1), WOOD, Vector3(0, 0, -0.04))
	_box(Vector3(1.36, 0.86, 0.04), INK, Vector3(0, 0, 0.02))
	for i in steps:
		var x := (i - (steps - 1) * 0.5) * (1.1 / maxf(1, steps - 1))
		var colour: Color = WIRE_COLOURS[i % WIRE_COLOURS.size()]
		# A brass terminal top and bottom, and the wire between them in two
		# halves, so a cut one can hang apart.
		for y in [0.36, -0.36]:
			var t := _cylinder(0.05, 0.05, 0.06, GOLD)
			t.rotation_degrees.x = 90
			t.position = Vector3(x, y, 0.08)
		var wire := Node3D.new()
		wire.position = Vector3(x, 0, 0.1)
		_root.add_child(wire)
		for half in [1, -1]:
			var seg := MeshInstance3D.new()
			seg.mesh = _cylinder_mesh(0.03, 0.36)
			seg.material_override = MenuStage._material(colour)
			seg.position = Vector3(0, half * 0.18, 0)
			wire.add_child(seg)
		_wires.append(wire)
	# The arrow: a shaft and a head, glowing gold, in the panel's plane.
	_arrow = Node3D.new()
	_root.add_child(_arrow)
	var glow := _glowing(GOLD, 2.5)
	var shaft := MeshInstance3D.new()
	shaft.mesh = MuseumView._box(Vector3(0.07, 0.2, 0.05))
	shaft.material_override = glow
	shaft.position = Vector3(0, -0.06, 0)
	_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.12
	cone.height = 0.16
	cone.radial_segments = 3
	head.mesh = cone
	head.material_override = glow
	head.position = Vector3(0, 0.1, 0)
	head.scale = Vector3(1, 1, 0.4)
	_arrow.add_child(head)


func _process(dt: float) -> void:
	if game == null or _root == null:
		return
	_t += dt
	_good = maxf(0.0, _good - dt * 3.0)
	_bad = maxf(0.0, _bad - dt * 3.0)
	# Shaking hands shake the view.
	_cam.h_offset = 0.012 * game.tremble * sin(_t * 47.0)
	_cam.v_offset = 0.012 * game.tremble * sin(_t * 39.0 + 1.0)
	match _kind:
		"lockpick": _pose_lock()
		"steady": _pose_glass()
		"balance": _pose_statue(dt)
		_: _pose_panel()


func _pose_lock() -> void:
	# The green sector: the marks within the band of the spot.
	var band := game.band()
	for i in _marks.size():
		var d := absf(float(i) / MARKS - game.spot)
		var lit := minf(d, 1.0 - d) <= band and not game.done
		_marks[i].material_override = _mark_lit if lit else _mark_dim
	# The needle goes round clockwise from the top, red when it slips.
	_needle.rotation.z = -game.tip() * TAU
	_needle_mat.albedo_color = STEEL.lerp(RED, clampf(game.lock / Minigame.SLIP_S, 0.0, 1.0))
	for i in _pins.size():
		var set_ := i < game.step
		_pins[i].material_override = _pin_lit if set_ else _pin_dim
		# Set pins stand up; the one being worked quivers.
		var lift := 0.08 if set_ else 0.0
		if i == game.step and not game.done:
			lift = 0.015 * sin(_t * 30.0)
		_pins[i].position.y = 0.66 + lift
	_root.scale = Vector3.ONE * (1.0 + 0.04 * _good)


func _pose_glass() -> void:
	_ring.scale = Vector3.ONE * game.ring()
	_cup.position = Vector3(game.cup.x * RING, -game.cup.y * RING, 0.04)
	var c := GREEN if game.inside() else RED
	_cup_mat.albedo_color = c
	_cup_mat.emission = c
	for i in _lamps.size():
		_lamps[i].material_override = _pin_lit if i < game.step else _lamp_dim


func _pose_statue(dt: float) -> void:
	# Facing the camera, as it does on the museum's pedestals.
	_statue.set_state(Vector3(0, 0.38, 0), PI / 2, 0.0, dt, "statue")
	_statue.set_lean(game.lean)


func _pose_panel() -> void:
	for i in _wires.size():
		var cut := i < game.step
		var w := _wires[i]
		# Cut: the halves pull apart and hang a little askew.
		var top := w.get_child(0) as Node3D
		var bottom := w.get_child(1) as Node3D
		top.position.y = 0.18 + (0.07 if cut else 0.0)
		bottom.position.y = -0.18 - (0.07 if cut else 0.0)
		top.rotation_degrees.z = 12.0 if cut else 0.0
		bottom.rotation_degrees.z = -9.0 if cut else 0.0
	var way := game.way()
	_arrow.visible = way >= 0
	if way >= 0:
		var x := _wires[game.step].position.x
		# Up is 0, then clockwise: right, down, left.
		var angle := -way * PI * 0.5
		var dir := Vector2(sin(-angle), cos(angle))
		var bob := 0.04 * sin(_t * 9.0)
		_arrow.position = Vector3(x + dir.x * bob, dir.y * bob, 0.26)
		_arrow.rotation = Vector3(0, 0, angle)
	# The wrong wire: sparks.
	_spark.light_energy = 3.0 * _bad
	if game.step < _wires.size():
		_spark.position = Vector3(_wires[game.step].position.x, 0, 0.5)


func _box(s: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = s
	mi.mesh = mesh
	mi.material_override = MenuStage._material(colour)
	mi.position = at
	_root.add_child(mi)
	return mi


func _cylinder(top: float, bottom: float, h: float, colour: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 24
	mi.mesh = c
	mi.material_override = MenuStage._material(colour)
	_root.add_child(mi)
	return mi


static func _cylinder_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return c


static func _glowing(colour: Color, energy: float) -> StandardMaterial3D:
	var m := MenuStage._material(colour).duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	return m
