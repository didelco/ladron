extends MinigameView
## The pick (LockpickGame): a brass lock seen from the front with a dial
## round its keyhole: a ring of marks, the green sector lit among them, a
## steel needle going round; the pins in a row on top, popping up green as
## they set.

## How many marks round the dial, and how far out they sit.
const MARKS := 48
const DIAL := 0.4

var _marks: Array[MeshInstance3D] = []
var _mark_dim: StandardMaterial3D
var _mark_lit: StandardMaterial3D
var _needle: Node3D
var _needle_mat: StandardMaterial3D
var _pins: Array[MeshInstance3D] = []
var _pin_lit: StandardMaterial3D
var _pin_dim: StandardMaterial3D


func framing() -> Dictionary:
	return {"span": 1.6, "look": 0.08, "angle": Vector3(-12, 14, 0)}


func build() -> void:
	var steps := game.steps
	# The lock, brass, its face to the camera, on a walnut collar.
	var collar := cylinder(0.62, 0.62, 0.3, WOOD)
	collar.rotation_degrees.x = 90
	collar.position.z = -0.12
	var body := cylinder(0.54, 0.54, 0.34, GOLD)
	body.rotation_degrees.x = 90
	# The keyhole in the middle: a dark round and its slot.
	var hole := cylinder(0.07, 0.07, 0.04, INK)
	hole.rotation_degrees.x = 90
	hole.position = Vector3(0, 0.03, 0.17)
	box(Vector3(0.05, 0.14, 0.04), INK, Vector3(0, -0.05, 0.17))
	# The dial: a ring of marks round the keyhole; the green ones are where
	# the pin sets.
	_mark_dim = MenuStage._material(GOLD.darkened(0.45))
	_mark_lit = glowing(GREEN, 2.2)
	for i in MARKS:
		var a := float(i) / MARKS * TAU
		var mark := box(Vector3(0.045, 0.1, 0.03), GOLD, Vector3(sin(a) * DIAL, cos(a) * DIAL, 0.18))
		mark.rotation.z = -a
		_marks.append(mark)
	# The pins, a row along the top, brass until set.
	_pin_dim = MenuStage._material(GOLD.darkened(0.25))
	_pin_lit = glowing(GREEN, 1.8)
	for i in steps:
		var x := (i - (steps - 1) * 0.5) * 0.17
		var pin := cylinder(0.05, 0.05, 0.16, GOLD)
		pin.position = Vector3(x, 0.66, 0.0)
		_pins.append(pin)
	# The needle: steel, from the keyhole out to the marks, turning about
	# the middle.
	_needle = Node3D.new()
	_needle.position.z = 0.21
	add_child(_needle)
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
	hub.mesh = cylinder_mesh(0.045, 0.04)
	hub.material_override = MenuStage._material(MenuStage.VELVET)
	hub.rotation_degrees.x = 90
	_needle.add_child(hub)


func pose(_dt: float) -> void:
	var g := game as LockpickGame
	# The green sector: the marks within the band of the spot.
	var band := g.band()
	for i in _marks.size():
		var d := absf(float(i) / MARKS - g.spot)
		var lit := minf(d, 1.0 - d) <= band and not g.done
		_marks[i].material_override = _mark_lit if lit else _mark_dim
	# The needle goes round clockwise from the top, red when it slips.
	_needle.rotation.z = -g.tip() * TAU
	_needle_mat.albedo_color = STEEL.lerp(RED, clampf(g.lock / LockpickGame.SLIP_S, 0.0, 1.0))
	for i in _pins.size():
		var set_ := i < g.step
		_pins[i].material_override = _pin_lit if set_ else _pin_dim
		# Set pins stand up; the one being worked quivers.
		var lift := 0.08 if set_ else 0.0
		if i == g.step and not g.done:
			lift = 0.015 * sin(t * 30.0)
		_pins[i].position.y = 0.66 + lift
	scale = Vector3.ONE * (1.0 + 0.04 * good)
