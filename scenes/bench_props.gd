class_name BenchProps
extends RefCounted
## The things of the dojo's bench, one kind for each test (Practice.BENCH_OBJECTS is
## the table that says which), composed from primitives in the house's toon colours:
## a marked tile on the floor, an empty glass case, a press, an alarm box on the
## wall and a window pane with a suction cup. None holds a sock (that is
## PILLA EL CALCETÍN's). Each has a lamp: red while it waits, green once it is
## done, and something that moves (the lid, the plunger, the cup) where it has one.
## They face south (+z), where the camera is.

const LAMP_OFF := Color("#8a2323")
const LAMP_ON := Color("#4cf07a")
const STEEL := Color("#59616b")
const STEEL_LIGHT := Color("#8a929c")
const GOLD := Color("#e0b030")


## Build the `object` (Practice.BENCH_OBJECTS) under `parent` (a node at the middle of its tile,
## on the floor). Returns {lamp: MeshInstance3D, move: Node3D or null, shut: Vector3,
## done: Vector3, rot: bool}: `move` goes from `shut` to `done` (a rotation if
## `rot`, a position if not) as the case is done.
static func build(view: MuseumView, object: String, parent: Node3D) -> Dictionary:
	match object:
		"tile":
			return _tile(view, parent)
		"vitrine":
			return _vitrine(view, parent)
		"press":
			return _press(view, parent)
		"alarm":
			return _alarm(view, parent)
	return _window(view, parent)


static func _lamp(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var l := MeshInstance3D.new()
	l.mesh = mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = LAMP_OFF
	l.material_override = m
	l.position = at
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(l)
	return l


static func _ball(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 12
	s.rings = 6
	return s


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 14
	return c


static func _result(lamp: MeshInstance3D, move: Node3D = null, shut := Vector3.ZERO, done := Vector3.ZERO, rot := false) -> Dictionary:
	return {"lamp": lamp, "move": move, "shut": shut, "done": done, "rot": rot}


## Lit or not: the lamp's colour.
static func light(part: Dictionary, on: bool) -> void:
	((part.lamp as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = LAMP_ON if on else LAMP_OFF


## QUIETO: a yellow tile with a dark border and two footprints on it, and a strip
## of light across its front edge.
static func _tile(view: MuseumView, parent: Node3D) -> Dictionary:
	view._mesh(parent, MuseumView._box(Vector3(0.92, 0.03, 0.92)), Color("#2a2418"), Vector3(0, 0.015, 0), true)
	view._mesh(parent, MuseumView._box(Vector3(0.8, 0.04, 0.8)), Color("#e8b62c"), Vector3(0, 0.02, 0), true)
	for sx in [-0.15, 0.15]:
		view._mesh(parent, MuseumView._box(Vector3(0.16, 0.05, 0.3)), Color("#3a2c14"), Vector3(sx, 0.025, -0.02), true)
		view._mesh(parent, MuseumView._box(Vector3(0.12, 0.05, 0.1)), Color("#3a2c14"), Vector3(sx, 0.025, 0.22), true)
	var strip := _lamp(parent, MuseumView._box(Vector3(0.7, 0.05, 0.07)), Vector3(0, 0.05, 0.36))
	return _result(strip)


## GANZÚA: an empty glass case on its base; the glass comes up (a bell lifted).
static func _vitrine(view: MuseumView, parent: Node3D) -> Dictionary:
	view._base(parent)
	view._vitrine(parent, null)
	var glass := parent.get_child(parent.get_child_count() - 1) as Node3D
	var lamp := _lamp(parent, _ball(0.06), Vector3(0.34, 0.22, 0.4))
	return _result(lamp, glass, Vector3.ZERO, Vector3(0, 0.75, 0))


## APRETAR: a press on an anvil: two posts, a crossbeam and the plunger that comes down.
static func _press(view: MuseumView, parent: Node3D) -> Dictionary:
	view._mesh(parent, MuseumView._box(Vector3(0.84, 0.12, 0.62)), STEEL, Vector3(0, 0.06, 0))
	view._mesh(parent, MuseumView._box(Vector3(0.44, 0.14, 0.34)), Color("#2f353c"), Vector3(0, 0.19, 0.02))
	for sx in [-0.34, 0.34]:
		view._mesh(parent, MuseumView._box(Vector3(0.09, 0.78, 0.09)), STEEL_LIGHT, Vector3(sx, 0.5, -0.2))
	view._mesh(parent, MuseumView._box(Vector3(0.78, 0.12, 0.16)), STEEL, Vector3(0, 0.86, -0.2))
	var plunger := view._pivot(parent, Vector3(0, 0.0, 0.02))
	view._mesh(plunger, _cyl(0.07, 0.36), STEEL_LIGHT, Vector3(0, 0.66, -0.06))
	view._mesh(plunger, MuseumView._box(Vector3(0.4, 0.06, 0.32)), Color("#c9553a"), Vector3(0, 0.46, 0.0))
	# A wheel on the beam to turn, for looks.
	var wheel := view._mesh(parent, TorusMesh.new(), Color("#c9553a"), Vector3(0.0, 0.86, -0.06), true)
	(wheel.mesh as TorusMesh).inner_radius = 0.05
	(wheel.mesh as TorusMesh).outer_radius = 0.08
	wheel.rotation.x = PI / 2
	var lamp := _lamp(parent, _ball(0.06), Vector3(0.34, 0.97, -0.2))
	return _result(lamp, plunger, Vector3.ZERO, Vector3(0, -0.14, 0))


## CABLES: an alarm box on the wall, as in a heist (Scenery.build_panel): grey,
## a big lamp and a red lever, that goes down when it is done. The node is on the
## wall face, its +z out of the wall.
static func _alarm(view: MuseumView, parent: Node3D) -> Dictionary:
	view._mesh(parent, MuseumView._box(Vector3(0.5, 0.6, 0.14)), Color("#5c6370"), Vector3(0, 1.0, 0.07))
	view._mesh(parent, MuseumView._box(Vector3(0.4, 0.05, 0.02)), Color("#2a2f36"), Vector3(0, 0.82, 0.15), true)
	var lamp := _lamp(parent, _ball(0.1), Vector3(0, 1.12, 0.16))
	var lever := view._pivot(parent, Vector3(0.14, 1.0, 0.17))
	view._mesh(lever, MuseumView._box(Vector3(0.06, 0.2, 0.06)), Color("#e03131"), Vector3(0, -0.06, 0), true)
	return _result(lamp, lever, Vector3(0, 0, 0.7), Vector3(0, 0, -0.7), true)


## PULSO: a pane of glass in a frame on a foot, with the suction cup stuck to it,
## that comes off (forward) when it is done.
static func _window(view: MuseumView, parent: Node3D) -> Dictionary:
	view._mesh(parent, MuseumView._box(Vector3(0.84, 0.08, 0.36)), STEEL, Vector3(0, 0.04, 0))
	view._mesh(parent, MuseumView._box(Vector3(0.08, 0.96, 0.08)), Color("#7a4a26"), Vector3(-0.38, 0.56, 0))
	view._mesh(parent, MuseumView._box(Vector3(0.08, 0.96, 0.08)), Color("#7a4a26"), Vector3(0.38, 0.56, 0))
	view._mesh(parent, MuseumView._box(Vector3(0.84, 0.08, 0.08)), Color("#7a4a26"), Vector3(0, 1.04, 0))
	view._mesh(parent, MuseumView._box(Vector3(0.84, 0.08, 0.08)), Color("#7a4a26"), Vector3(0, 0.12, 0))
	var glass := MeshInstance3D.new()
	glass.mesh = MuseumView._box(Vector3(0.68, 0.86, 0.02))
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.6, 0.85, 1.0, 0.4)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = gm
	glass.position = Vector3(0, 0.58, 0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glass)
	var cup := view._pivot(parent, Vector3(0, 0.6, 0.02))
	var disc := view._mesh(cup, _cyl(0.13, 0.05), Color("#d8352f"), Vector3(0, 0, 0.02))
	disc.rotation.x = PI / 2
	var stem := view._mesh(cup, _cyl(0.03, 0.12), Color("#d8352f"), Vector3(0, 0, 0.1))
	stem.rotation.x = PI / 2
	var lamp := _lamp(parent, _ball(0.06), Vector3(0.38, 1.14, 0))
	return _result(lamp, cup, Vector3(0, 0.6, 0.02), Vector3(0, 0.6, 0.18))
