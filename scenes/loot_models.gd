class_name LootModels
extends RefCounted
## The pieces to steal, modelled out of primitives, each with its own
## materials and a little character: the grandad's dentures with pink gums,
## the opera duck in a bow tie, the yeti's furry striped sock, the toast with
## the Barón's burnt moustache, the pickle queen's crown, the cheese
## meteorite with holes and a whiff, the octopus wrestler's mask, the alarm
## clock that runs backwards, the dinosaur egg in its nest, a proper
## brilliant-cut diamond, the obsidian idol.
##
## About 0.35 units across, standing on its origin's floor (y 0 at the
## bottom, give or take), to sit in a case or turn on a stand. Everything
## glows a touch, so it reads in the dark museum.

## The shapes this builds; anything else gets the gem.
const SHAPES := ["teeth", "duck", "sock", "toast", "crown", "rock", "mask", "clock", "egg", "gem", "idol"]


static func build(shape: String, colour: Color) -> Node3D:
	var root := Node3D.new()
	var m := LootModels.new()
	m._root = root
	m._colour = colour
	match shape:
		"teeth": m._teeth()
		"duck": m._duck()
		"sock": m._sock()
		"toast": m._toast()
		"crown": m._crown()
		"rock": m._cheese_rock()
		"mask": m._mask()
		"clock": m._clock()
		"egg": m._egg()
		"idol": m._idol()
		_: m._gem()
	return root


var _root: Node3D
var _colour: Color
var _materials := {}


# --- The pieces --------------------------------------------------------------------

## Porcelain dentures, a little open, glowing faintly in the dark.
func _teeth() -> void:
	var gum := Color("#e2637a")
	for jaw in [1, -1]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0.1, -0.06)
		pivot.rotation.x = -0.28 * jaw
		_root.add_child(pivot)
		var y: float = 0.035 * jaw
		# A horseshoe of gum, then a tooth on it every few degrees.
		for k in 9:
			var a := lerpf(-1.25, 1.25, k / 8.0)
			var at := Vector3(sin(a) * 0.12, y, cos(a) * 0.12)
			_part(pivot, _capsule(0.03, 0.07), gum, at, Vector3(PI / 2, a, 0), 0.4)
			var tooth := _capsule(0.018 if absf(a) > 0.6 else 0.022, 0.05)
			_part(pivot, tooth, Color("#fbf8ef"), at + Vector3(0, -0.028 * jaw, 0) + Vector3(sin(a), 0, cos(a)) * 0.012, Vector3.ZERO, 0.15, 0.3)
		_part(pivot, _box(Vector3(0.2, 0.012, 0.16)), gum.darkened(0.15), Vector3(0, y + 0.01 * jaw, 0.04), Vector3.ZERO, 0.5)


## A yellow rubber duck with an opera singer's bow tie and a proud chest.
func _duck() -> void:
	var yellow := _colour
	_part(_root, _sphere(0.14, 0.2), yellow, Vector3(0, 0.11, 0), Vector3.ZERO, 0.35).scale = Vector3(1.15, 1.0, 1.0)
	_part(_root, _sphere(0.05, 0.08), yellow, Vector3(-0.14, 0.16, 0), Vector3(0, 0, 0.6), 0.35)
	_part(_root, _sphere(0.09, 0.18), yellow, Vector3(0.07, 0.26, 0), Vector3.ZERO, 0.35)
	# A wide flat beak, two lips.
	for lip in [0.0, -0.022]:
		_part(_root, _sphere(0.05, 0.03), Color("#ff8c1a"), Vector3(0.155, 0.245 + lip, 0), Vector3(0, 0, -0.15), 0.4).scale = Vector3(1.4, 1, 1.2)
	for side in [-1, 1]:
		_part(_root, _sphere(0.022, 0.04), Color.WHITE, Vector3(0.13, 0.29, side * 0.045), Vector3.ZERO, 0.2)
		_part(_root, _sphere(0.012, 0.024), Color("#111"), Vector3(0.148, 0.292, side * 0.048), Vector3.ZERO, 0.1)
		_part(_root, _sphere(0.06, 0.05), yellow.darkened(0.08), Vector3(-0.01, 0.13, side * 0.12), Vector3.ZERO, 0.35).scale = Vector3(1.3, 0.8, 0.5)
	# The bow tie.
	for side in [-1, 1]:
		var wing := _part(_root, _cone(0.035, 0.06), Color("#1c1c24"), Vector3(0.1, 0.19, side * 0.035), Vector3(PI / 2 * side, 0, 0), 0.6)
		wing.scale = Vector3(1, 1, 0.5)
	_part(_root, _sphere(0.016, 0.03), Color("#1c1c24"), Vector3(0.11, 0.19, 0), Vector3.ZERO, 0.6)


## The yeti's sock: long, furry at the cuff, red and white stripes, a patch
## on the toe. Stands on its heel.
func _sock() -> void:
	var wool := Color("#f1ece2")
	var red := Color("#c9303c")
	_part(_root, _cylinder(0.075, 0.07, 0.3), wool, Vector3(0, 0.23, 0), Vector3.ZERO, 0.9)
	for k in 3:
		_part(_root, _cylinder(0.077, 0.077, 0.035), red, Vector3(0, 0.14 + k * 0.08, 0), Vector3.ZERO, 0.9)
	_part(_root, _sphere(0.08, 0.16), wool, Vector3(0, 0.07, 0), Vector3.ZERO, 0.9)
	_part(_root, _capsule(0.075, 0.26), wool, Vector3(0.1, 0.07, 0), Vector3(0, 0, PI / 2), 0.9)
	_part(_root, _sphere(0.078, 0.12), red, Vector3(0.21, 0.07, 0), Vector3.ZERO, 0.9)
	# Tufts of yeti fur round the cuff.
	for k in 12:
		var a := k * TAU / 12
		var tuft := _part(_root, _cone(0.022, 0.06), Color("#dfe6ef"), Vector3(cos(a) * 0.075, 0.39, sin(a) * 0.075), Vector3(sin(a) * 0.5, 0, -cos(a) * 0.5), 1.0)
		tuft.rotation = Vector3(sin(a) * 0.6, 0, -cos(a) * 0.6)


## A slice of toast with a pat of butter, and the Barón's face burnt into it:
## two eyes and a curled moustache.
func _toast() -> void:
	var crust := Color("#9a5b24")
	var crumb := _colour.lightened(0.25)
	var slice := Node3D.new()
	slice.position = Vector3(0, 0.17, 0)
	_root.add_child(slice)
	# The loaf's outline: a square with a rounded top, crust round the edge.
	_part(slice, _box(Vector3(0.3, 0.22, 0.045)), crust, Vector3(0, -0.03, 0), Vector3.ZERO, 0.8)
	for side in [-1, 1]:
		_part(slice, _cylinder(0.09, 0.09, 0.045), crust, Vector3(side * 0.07, 0.08, 0), Vector3(PI / 2, 0, 0), 0.8)
	_part(slice, _box(Vector3(0.26, 0.19, 0.05)), crumb, Vector3(0, -0.03, 0.001), Vector3.ZERO, 0.9)
	for side in [-1, 1]:
		_part(slice, _cylinder(0.075, 0.075, 0.05), crumb, Vector3(side * 0.07, 0.08, 0.001), Vector3(PI / 2, 0, 0), 0.9)
	var burn := Color("#4a2410")
	for side in [-1, 1]:
		_part(slice, _sphere(0.018, 0.012), burn, Vector3(side * 0.05, 0.05, 0.027), Vector3.ZERO, 1.0)
		var curl := TorusMesh.new()
		curl.inner_radius = 0.018
		curl.outer_radius = 0.03
		_part(slice, curl, burn, Vector3(side * 0.045, -0.02, 0.027), Vector3(PI / 2, 0, 0), 1.0).scale = Vector3(1.2, 1, 0.3)
	_part(slice, _box(Vector3(0.06, 0.035, 0.03)), Color("#ffe27a"), Vector3(0.07, -0.08, 0.035), Vector3(0, 0, 0.2), 0.3)
	# A stand behind, like a plate rack.
	_part(_root, _box(Vector3(0.2, 0.02, 0.12)), Color("#d8ac5c"), Vector3(0, 0.01, 0), Vector3.ZERO, 0.35, 0.1, 0.35)


## The Pickle Queen's crown: a gold band with five points, each tipped with a
## little green pickle, and gems round the band.
func _crown() -> void:
	var gold := Color("#e8b54a")
	_part(_root, _cylinder(0.15, 0.14, 0.09), gold, Vector3(0, 0.045, 0), Vector3.ZERO, 0.3, 0.1, 0.35)
	_part(_root, _torus(0.14, 0.16), gold.darkened(0.15), Vector3(0, 0.005, 0), Vector3.ZERO, 0.3, 0.1, 0.35)
	for k in 5:
		var a := k * TAU / 5
		var at := Vector3(cos(a) * 0.145, 0.13, sin(a) * 0.145)
		_part(_root, _cone(0.035, 0.1), gold, at, Vector3.ZERO, 0.3, 0.1, 0.35)
		var pickle := _part(_root, _capsule(0.022, 0.07), _colour, at + Vector3(0, 0.07, 0), Vector3(0, 0, 0.3), 0.5)
		pickle.scale = Vector3(1, 1, 0.9)
		var gem := _part(_root, _sphere(0.02, 0.03), Color("#c2185b") if k % 2 == 0 else Color("#2f6fd6"), Vector3(cos(a + 0.63) * 0.152, 0.05, sin(a + 0.63) * 0.152), Vector3.ZERO, 0.1, 0.4)
		gem.scale = Vector3(1, 1, 0.6)


## A lump of meteorite that is mostly cheese: yellow, lumpy, full of holes,
## a green whiff rising off it.
func _cheese_rock() -> void:
	var cheese := _colour
	var lumps := [[Vector3(0, 0.12, 0), 0.14], [Vector3(0.08, 0.1, 0.05), 0.1], [Vector3(-0.07, 0.14, -0.04), 0.1], [Vector3(0.02, 0.2, -0.03), 0.09]]
	for l in lumps:
		_part(_root, _sphere(l[1], l[1] * 1.8), cheese, l[0], Vector3(0.3, 0.2, 0.1), 0.6).scale = Vector3(1.1, 0.9, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	for k in 9:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		_part(_root, _sphere(0.025, 0.03), cheese.darkened(0.45), Vector3(0, 0.13, 0) + d * 0.145, Vector3.ZERO, 0.9)
	for k in 3:
		var whiff := _part(_root, _torus(0.02, 0.03), Color("#8fd16a", 0.8), Vector3(-0.05 + k * 0.05, 0.3 + k * 0.05, 0), Vector3(PI / 2, 0, 0), 0.5, 0.6)
		whiff.scale = Vector3(1, 1, 0.5)


## A lucha libre mask for an octopus: the head, big eye holes rimmed in
## gold, a flame across the brow, and tentacles curling out below.
func _mask() -> void:
	var purple := _colour
	var head := _part(_root, _sphere(0.14, 0.3), purple, Vector3(0, 0.21, 0), Vector3.ZERO, 0.35)
	head.scale = Vector3(1, 1.1, 0.95)
	for side in [-1, 1]:
		var rim := _part(_root, _sphere(0.045, 0.06), Color("#ffd166"), Vector3(side * 0.055, 0.24, 0.115), Vector3(0, 0, side * 0.4), 0.3, 0.2)
		rim.scale = Vector3(1.3, 1, 0.5)
		_part(_root, _sphere(0.034, 0.05), Color("#111"), Vector3(side * 0.055, 0.24, 0.128), Vector3(0, 0, side * 0.4), 0.2).scale = Vector3(1.3, 1, 0.4)
	_part(_root, _box(Vector3(0.05, 0.1, 0.02)), Color("#ffd166"), Vector3(0, 0.31, 0.125), Vector3(0.3, 0, 0), 0.3, 0.2)
	_part(_root, _box(Vector3(0.05, 0.012, 0.02)), Color("#111"), Vector3(0, 0.16, 0.13), Vector3.ZERO, 0.3)
	for k in 8:
		var a := k * TAU / 8
		var t := _part(_root, _capsule(0.02, 0.12), purple.lightened(0.1), Vector3(cos(a) * 0.09, 0.07, sin(a) * 0.09), Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9), 0.35)
		t.rotation = Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9)


## An old twin-bell alarm clock, its hands going the wrong way: a curved
## arrow on the face says so.
func _clock() -> void:
	var body := _colour
	var face := Node3D.new()
	face.position = Vector3(0, 0.17, 0)
	_root.add_child(face)
	_part(face, _cylinder(0.14, 0.14, 0.08), body, Vector3.ZERO, Vector3(PI / 2, 0, 0), 0.35, 0.1, 0.3)
	_part(face, _cylinder(0.12, 0.12, 0.01), Color("#f8f4e8"), Vector3(0, 0, 0.041), Vector3(PI / 2, 0, 0), 0.4)
	_part(face, _torus(0.12, 0.14), Color("#e8b54a"), Vector3(0, 0, 0.041), Vector3(PI / 2, 0, 0), 0.3, 0.1, 0.35)
	for k in 12:
		var a := k * TAU / 12
		_part(face, _box(Vector3(0.008, 0.02 if k % 3 == 0 else 0.012, 0.004)), Color("#222"), Vector3(sin(a) * 0.1, cos(a) * 0.1, 0.048), Vector3(0, 0, -a), 0.5)
	for hand in [[0.07, 2.4, 0.01], [0.05, 0.9, 0.012]]:
		var a: float = hand[1]
		_part(face, _box(Vector3(hand[2], hand[0], 0.005)), Color("#222"), Vector3(sin(a) * hand[0] * 0.5, cos(a) * hand[0] * 0.5, 0.05), Vector3(0, 0, -a), 0.5)
	# The arrow round the face, anticlockwise.
	var arrow := _torus(0.075, 0.085)
	_part(face, arrow, Color("#c9303c"), Vector3(0, 0, 0.049), Vector3(PI / 2, 0, 0), 0.4).scale = Vector3(1, 1, 0.2)
	_part(face, _cone(0.018, 0.03), Color("#c9303c"), Vector3(-0.08, 0.0, 0.05), Vector3(0, 0, 0), 0.4)
	for side in [-1, 1]:
		_part(_root, _sphere(0.05, 0.05), Color("#e8b54a"), Vector3(side * 0.09, 0.31, 0), Vector3(0, 0, side * 0.5), 0.3, 0.1, 0.35)
		_part(_root, _capsule(0.012, 0.08), Color("#333"), Vector3(side * 0.09, 0.03, 0), Vector3(0, 0, side * 0.4), 0.5)
	_part(_root, _box(Vector3(0.02, 0.05, 0.02)), Color("#e8b54a"), Vector3(0, 0.32, 0), Vector3.ZERO, 0.35, 0.1, 0.35)


## A big speckled dinosaur egg in a nest of twigs.
func _egg() -> void:
	var shell := _colour
	for k in 14:
		var a := k * TAU / 14
		_part(_root, _capsule(0.012, 0.14), Color("#7a5234").lerp(Color("#a8844f"), (k % 3) / 3.0), Vector3(cos(a) * 0.1, 0.03, sin(a) * 0.1), Vector3(PI / 2, -a + 0.4, 0.3), 1.0)
	_part(_root, _sphere(0.1, 0.28), shell, Vector3(0, 0.16, 0), Vector3.ZERO, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 12:
		var d := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)).normalized()
		_part(_root, _sphere(0.018, 0.012), shell.darkened(0.4), Vector3(0, 0.16, 0) + Vector3(d.x * 0.1, d.y * 0.14, d.z * 0.1), Vector3.ZERO, 0.6)


## A brilliant-cut diamond: a flat table, a faceted crown, a deep pavilion.
func _gem() -> void:
	var stone := _colour
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(stone, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.2
	mat.roughness = 0.05
	mat.emission_enabled = true
	mat.emission = stone
	mat.emission_energy_multiplier = 0.7
	mat.rim_enabled = true
	mat.rim = 0.8
	var crown := _cylinder(0.09, 0.16, 0.07)
	crown.radial_segments = 8
	var pavilion := _cylinder(0.16, 0.0, 0.17)
	pavilion.radial_segments = 8
	for pair in [[crown, Vector3(0, 0.215, 0)], [pavilion, Vector3(0, 0.095, 0)]]:
		var mi := MeshInstance3D.new()
		mi.mesh = pair[0]
		mi.position = pair[1]
		mi.material_override = mat
		_root.add_child(mi)
	# A glint on the table.
	_part(_root, _sphere(0.02, 0.02), Color.WHITE, Vector3(0.03, 0.252, 0.02), Vector3.ZERO, 0.1, 2.0)


## The obsidian idol: a squat seated figure, a big head with a headdress,
## gold eyes.
func _idol() -> void:
	var stone := _colour.darkened(0.3)
	_part(_root, _box(Vector3(0.2, 0.05, 0.16)), stone.darkened(0.3), Vector3(0, 0.025, 0), Vector3.ZERO, 0.2)
	_part(_root, _capsule(0.08, 0.2), stone, Vector3(0, 0.14, 0), Vector3.ZERO, 0.15).scale = Vector3(1.1, 1, 0.9)
	_part(_root, _box(Vector3(0.17, 0.14, 0.14)), stone, Vector3(0, 0.29, 0), Vector3.ZERO, 0.15)
	for side in [-1, 1]:
		_part(_root, _box(Vector3(0.04, 0.02, 0.01)), Color("#e8b54a"), Vector3(side * 0.04, 0.3, 0.072), Vector3.ZERO, 0.3, 1.2, 0.35)
		_part(_root, _capsule(0.022, 0.1), stone, Vector3(side * 0.08, 0.13, 0.04), Vector3(0.9, 0, side * 0.2), 0.15)
	_part(_root, _box(Vector3(0.06, 0.012, 0.01)), Color("#e8b54a"), Vector3(0, 0.255, 0.072), Vector3.ZERO, 0.3, 0.6, 0.35)
	for k in 5:
		_part(_root, _cone(0.025, 0.08), _colour, Vector3(-0.07 + k * 0.035, 0.39, 0), Vector3.ZERO, 0.2, 0.5)


# --- Parts -------------------------------------------------------------------------

## A piece of the model: one mesh, one colour, a faint glow of its own so it
## reads in the dark.
func _part(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, rot := Vector3.ZERO, rough := 0.5, glow := 0.12, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation = rot
	var key := "%s|%s|%s|%s" % [colour.to_html(), rough, glow, metal]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = rough
		m.metallic = metal
		if colour.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = colour
			m.emission_energy_multiplier = glow
		m.rim_enabled = true
		m.rim = 0.3
		_materials[key] = m
	mi.material_override = _materials[key]
	parent.add_child(mi)
	return mi


func _sphere(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = 24
	s.rings = 12
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 6
	return c


func _cylinder(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 24
	return c


func _cone(r: float, h: float) -> CylinderMesh:
	return _cylinder(0.0, r, h)


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return t
