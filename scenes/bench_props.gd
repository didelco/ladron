class_name BenchProps
extends RefCounted
## The things of the dojo's tests, one kind for each (the `via` of its row of
## DojoTrials.TABLE says which), composed from primitives (or the house's models) in
## the house's toon colours: an empty glass case (GANZÚA), a hideout (ESCONDITE), an
## alarm box on the wall with its wires hanging (CABLES) and another with a glass
## and a suction cup (PULSO). None holds a sock (that is PILLA EL CALCETÍN's).
## Each has a lamp: red while it waits, green once it is done, and something that
## moves where it has one (the glass, the lever, the cup). Wall ones are built with
## the wall face at the node's origin and their +z out of the wall.

const LAMP_OFF := Color("#8a2323")
const LAMP_ON := Color("#4cf07a")
const STEEL := Color("#5c6370")
const WIRE_COLOURS := [Color("#e04b4b"), Color("#4b8fe0"), Color("#f0c53a"), Color("#4bc46a"), Color("#e08a2b"), Color("#b06ae0")]


## Build the `object` (a `via` of Practice.VIAS) of difficulty `level` under `parent`;
## `piece` is the furniture of a hideout (Hideouts.PIECES).
## Returns {lamp: MeshInstance3D, move: Node3D or null, shut: Vector3, done: Vector3,
## rot: bool}: `move` goes from `shut` to `done` (a rotation if `rot`, a position if
## not) as the case is done.
static func build(view: MuseumView, object: String, parent: Node3D, level: int, piece := "") -> Dictionary:
	match object:
		"vitrine":
			return _vitrine(view, parent)
		"hideout":
			return _hideout(view, parent, piece)
		"alarm_wires":
			return _alarm_wires(view, parent, level)
	return _alarm_glass(view, parent, level)


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
	c.radial_segments = 16
	return c


static func _result(lamp: MeshInstance3D, move: Node3D = null, shut := Vector3.ZERO, done := Vector3.ZERO, rot := false) -> Dictionary:
	return {"lamp": lamp, "move": move, "shut": shut, "done": done, "rot": rot}


## Lit or not: the lamp's colour.
static func light(part: Dictionary, on: bool) -> void:
	((part.lamp as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = LAMP_ON if on else LAMP_OFF


## GANZÚA: an empty glass case on its base; the glass comes up (a bell lifted).
static func _vitrine(view: MuseumView, parent: Node3D) -> Dictionary:
	view._base(parent)
	view._vitrine(parent, null)
	var glass := parent.get_child(parent.get_child_count() - 1) as Node3D
	var lamp := _lamp(parent, _ball(0.06), Vector3(0.34, 0.22, 0.4))
	return _result(lamp, glass, Vector3.ZERO, Vector3(0, 0.75, 0))


## ESCONDITE: a piece of furniture to hide in (Hideouts.PIECES: a fridge, a box, a
## chest, tighter each), with a lamp on its top. It is not one to hide in: it is
## for wriggling into, as in a heist.
static func _hideout(view: MuseumView, parent: Node3D, kind: String) -> Dictionary:
	var model := MuseumView.asset(Hideouts.PIECES[kind].model)
	parent.add_child(model)
	var top := view._bounds(model, Transform3D.IDENTITY)
	var lamp := _lamp(parent, _ball(0.07), Vector3(0, top.end.y + 0.14, 0))
	return _result(lamp)


## The alarm box of a heist (Scenery.build_panel): grey, with a big lamp.
static func _alarm_box(view: MuseumView, parent: Node3D, size: Vector3) -> MeshInstance3D:
	view._mesh(parent, MuseumView._box(size), STEEL, Vector3(0, 1.0, size.z / 2.0))
	return _lamp(parent, _ball(0.1), Vector3(0, 1.0 + size.y / 2.0 - 0.12, size.z + 0.02))


## CABLES: the alarm box with its wires hanging under it (3 to 6 by the level, as
## the game has them) and the red lever, that goes down when it is done.
static func _alarm_wires(view: MuseumView, parent: Node3D, level: int) -> Dictionary:
	var lamp := _alarm_box(view, parent, Vector3(0.5, 0.6, 0.14))
	var n: int = WiresGame.WIRES_LEVEL[level]
	for i in n:
		var x := (i - (n - 1) / 2.0) * 0.07
		view._mesh(parent, MuseumView._box(Vector3(0.03, 0.3, 0.03)), WIRE_COLOURS[i], Vector3(x, 0.55, 0.1), true)
	var lever := view._pivot(parent, Vector3(0.14, 0.95, 0.17))
	view._mesh(lever, MuseumView._box(Vector3(0.06, 0.2, 0.06)), Color("#e03131"), Vector3(0, -0.06, 0), true)
	return _result(lamp, lever, Vector3(0, 0, 0.7), Vector3(0, 0, -0.7), true)


## PULSO: the alarm box with a pane of glass on it, the ring to keep the suction
## cup in (smaller the harder, as the game has it) and the cup; it comes off when
## it is done.
static func _alarm_glass(view: MuseumView, parent: Node3D, level: int) -> Dictionary:
	var lamp := _alarm_box(view, parent, Vector3(0.6, 0.76, 0.14))
	var glass := MeshInstance3D.new()
	glass.mesh = MuseumView._box(Vector3(0.44, 0.34, 0.02))
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.6, 0.85, 1.0, 0.55)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.material_override = gm
	glass.position = Vector3(0, 0.9, 0.15)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glass)
	var ring := TorusMesh.new()
	var r: float = 0.15 * SteadyGame.RING_LEVEL[level]
	ring.inner_radius = r - 0.012
	ring.outer_radius = r
	var rm := view._mesh(parent, ring, Color("#2a1810"), Vector3(0, 0.9, 0.17), true)
	rm.rotation.x = PI / 2
	var cup := view._pivot(parent, Vector3(0, 0.9, 0.18))
	var disc := view._mesh(cup, _cyl(0.06, 0.03), Color("#d8352f"), Vector3.ZERO, true)
	disc.rotation.x = PI / 2
	return _result(lamp, cup, Vector3(0, 0.9, 0.18), Vector3(0, 0.9, 0.34))
