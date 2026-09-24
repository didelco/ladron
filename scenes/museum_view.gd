class_name MuseumView
extends Node3D
## The museum as drawn: floor, walls, the collection in its cases, paintings
## and the emergency lighting. Built once per round from Museum; nothing here
## changes while the round runs. Port of the web version's Floor, Walls,
## Exhibits, Paintings and EmergencyLights.

const WALL_HEIGHT := 1.15
## The shell is only a little taller than the partitions, and only where the
## void is not to the south: the camera never turns, so a wall with the void
## south of it is always between it and the player.
const OUTER_HEIGHT := 1.45
const CAP_H := 0.07
const TRIM_H := 0.025
const SKIRT_H := 0.12
const CASE_HEIGHT := 0.82
const MAX_EMERGENCY := 10

const C := {
	"night": Color("#0f0d14"),
	"floor": Color("#2b2834"),
	"floor_line": Color("#474357"),
	"gold": Color("#f0c46a"),
	"gold_dim": Color("#9a7a3c"),
	"wall_top": Color("#544a5e"),
	"bone": Color("#e8ddc0"),
	"bone_dark": Color("#b9a883"),
	"mineral": Color("#7ad6ff"),
	"mineral_warm": Color("#ff8ab5"),
	"fern": Color("#4f9e5e"),
	"stone": Color("#5a5560"),
	"crimson": Color("#9b2c3f"),
	"wall_side": Color("#211d29"),
	"wall_cap": Color("#6f6479"),
	"ink": Color("#08070c"),
	"case_dark": Color("#232634"),
	"glass": Color("#a8d8e8"),
	"emergency": Color("#4ade80"),
}


func build() -> void:
	_floor()
	_walls()
	_exhibits()
	_paintings()
	_emergency_lights()


static func to_world(x: float, y: float, height := 0.0) -> Vector3:
	return Vector3(x - Museum.w / 2.0, height, y - Museum.h / 2.0)


static func toon(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


# --- Floor -------------------------------------------------------------------

## The marble floor: a shader does the slabs, veins, joints and the contact
## shadow (floor.gdshader). All it needs from here is the plan, one texel a
## tile: how solid each tile is, and whether it is outside the building.
func _floor() -> void:
	var w := Museum.w
	var h := Museum.h
	var img := Image.create(w, h, false, Image.FORMAT_RG8)
	for y in h:
		for x in w:
			var t := Museum.grid[y * w + x]
			var solid := 1.0 if t == Tiles.WALL else (0.6 if t == Tiles.COVER else 0.0)
			img.set_pixel(x, y, Color(solid, 1.0 if Museum.is_outside(x, y) else 0.0, 0))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var veins := NoiseTexture2D.new()
	veins.noise = noise
	veins.seamless = true
	veins.width = 256
	veins.height = 256
	var m := ShaderMaterial.new()
	m.shader = preload("res://scenes/floor.gdshader")
	m.set_shader_parameter("plan", ImageTexture.create_from_image(img))
	m.set_shader_parameter("veins", veins)
	m.set_shader_parameter("size", Vector2(w, h))
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, h)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = m
	add_child(node)


# --- Walls -------------------------------------------------------------------

## Every wall block, its moulded cap with a gold line under it, and a skirting
## board. The cap is lit only along the edge of a wall mass: a thick block of
## wall is a roof seen from above, and lit all over it was the biggest,
## brightest thing on screen.
func _walls() -> void:
	var inner: Array[Vector2i] = []
	var outer: Array[Vector2i] = []
	for y in Museum.h:
		for x in Museum.w:
			if Museum.grid[y * Museum.w + x] != Tiles.WALL or Museum.is_outside(x, y):
				continue
			var edge := false
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1)]:
				if Museum.is_outside(x + d.x, y + d.y):
					edge = true
			(outer if edge else inner).append(Vector2i(x, y))
	for set_and_h in [[inner, WALL_HEIGHT], [outer, OUTER_HEIGHT]]:
		var cells: Array[Vector2i] = set_and_h[0]
		var wh: float = set_and_h[1]
		_instances(_box(Vector3(1, wh, 1)), cells, wh / 2, toon(C.wall_side), 0.22)
		_instances(_box(Vector3(1.04, CAP_H, 1.04)), cells, wh + CAP_H / 2, toon(C.wall_cap), 0.14, true)
		_instances(_box(Vector3(1.02, TRIM_H, 1.02)), cells, wh - TRIM_H * 1.5, toon(C.gold_dim))
		_instances(_box(Vector3(1.03, SKIRT_H, 1.03)), cells, SKIRT_H / 2, toon(C.ink))
		# A dado rail at waist height: the line every gallery wall has.
		_instances(_box(Vector3(1.015, 0.035, 1.015)), cells, 0.5, toon(C.gold_dim))


func _cap_shade(t: Vector2i) -> float:
	for d in Museum.DIRS:
		var x := t.x + d.x
		var y := t.y + d.y
		if x >= 0 and y >= 0 and x < Museum.w and y < Museum.h and Museum.grid[y * Museum.w + x] != Tiles.WALL:
			return 1.0
	return 0.45


# --- The collection ------------------------------------------------------------

## What stands on each piece of cover: a glass case of butterflies, minerals or
## a fossil, a skull or a statue on a plinth, a fern diorama — and one bear,
## in the roomiest gallery. Which piece a tile gets comes from a hash of its
## coordinates, so a gallery looks the same every time. All waist-high: the
## rules hide someone on all fours behind any of them. The job's own case is
## an empty vitrine: the piece itself is drawn by the game, glowing.
func _exhibits() -> void:
	var bear := Vector2i(-1, -1)
	var best_room := 12
	for t in Museum.cover_tiles:
		if t == Heist.at:
			continue
		var room := 0
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if Museum.tile_at(t.x + dx + 0.5, t.y + dy + 0.5) == Tiles.FLOOR:
					room += 1
		if room > best_room:
			best_room = room
			bear = t
	var i := 0
	for t in Museum.cover_tiles:
		var piece := Node3D.new()
		piece.position = to_world(t.x + 0.5, t.y + 0.5)
		add_child(piece)
		_base(piece)
		var yaw := _hash01(t.x, t.y, 3) * TAU
		var kind := int(_hash01(t.x, t.y) * 12)
		if t == Heist.at:
			_vitrine(piece, null)
		elif t == bear:
			var p := _pivot(piece, Vector3.ZERO, yaw)
			_plinth(p, 0.3, 0.98)
			_specimen(p, "res://assets/models/bear.glb", 0.3, 0.62, 0.92, C.bone)
		elif kind == 0:
			_vitrine(piece, _butterflies(t.x + t.y))
		elif kind == 1:
			_vitrine(piece, _minerals(t.x + t.y))
		elif kind == 2:
			_vitrine(piece, _ammonite() if i % 2 == 0 else _rock())
		elif kind == 3:
			var p := _pivot(piece, Vector3.ZERO, yaw)
			_plinth(p, 0.5, 0.64)
			_specimen(p, "res://assets/models/statue-%s.glb" % ("a" if i % 2 == 0 else "b"), 0.5, 0.88, 0.8, C.bone_dark)
		elif kind == 4:
			_plinth(piece, CASE_HEIGHT - 0.16, 0.64)
			_skull(piece, yaw)
		elif kind == 5:
			_diorama(piece, t.x + t.y)
		elif kind == 6:
			var p := _pivot(piece, Vector3.ZERO, yaw)
			_plinth(p, 0.42, 0.6)
			_amphora(p, 0.42, t.x * 7 + t.y)
		elif kind == 7:
			_globe(_pivot(piece, Vector3.ZERO, yaw))
		elif kind == 8:
			_armour(_pivot(piece, Vector3.ZERO, round(yaw / (PI / 2)) * PI / 2))
		elif kind == 9:
			_totem(_pivot(piece, Vector3.ZERO, round(yaw / (PI / 2)) * PI / 2), t.x + t.y * 3)
		elif kind == 10:
			_dinosaur(_pivot(piece, Vector3.ZERO, yaw))
		else:
			_vitrine(piece, _sarcophagus())
		i += 1


## The slab under every exhibit: there is always something visible where the
## collision is, even if a model fails to load.
func _base(parent: Node3D) -> void:
	_mesh(parent, _box(Vector3(0.9, 0.16, 0.9)), C.case_dark, Vector3(0, 0.08, 0))


func _plinth(parent: Node3D, h: float, w: float) -> void:
	_mesh(parent, _box(Vector3(w, h, w)), C.wall_top, Vector3(0, h / 2, 0))
	# A brass band round the top, and a label on the front.
	_mesh(parent, _box(Vector3(w + 0.02, 0.03, w + 0.02)), C.gold_dim, Vector3(0, h - 0.04, 0))
	_mesh(parent, _box(Vector3(0.18, 0.06, 0.01)), C.bone, Vector3(0, h * 0.6, w / 2 + 0.006))


## Glass case on a dark base, with brass posts and rim and a label, and
## whatever it holds sitting on the base.
func _vitrine(parent: Node3D, contents: Node3D) -> void:
	_mesh(parent, _box(Vector3(0.86, 0.4, 0.86)), C.case_dark, Vector3(0, 0.2, 0))
	_mesh(parent, _box(Vector3(0.2, 0.08, 0.01)), C.bone, Vector3(0, 0.24, 0.434))
	if contents:
		contents.position = Vector3(0, 0.42, 0)
		parent.add_child(contents)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_mesh(parent, _box(Vector3(0.035, 0.43, 0.035)), C.gold_dim, Vector3(sx * 0.39, 0.615, sz * 0.39))
	for side in [Vector3(0, 0, 0.39), Vector3(0, 0, -0.39)]:
		_mesh(parent, _box(Vector3(0.815, 0.03, 0.035)), C.gold, Vector3(0, CASE_HEIGHT, 0) + side)
	for side in [Vector3(0.39, 0, 0), Vector3(-0.39, 0, 0)]:
		_mesh(parent, _box(Vector3(0.035, 0.03, 0.815)), C.gold, Vector3(0, CASE_HEIGHT, 0) + side)
	# A strip of warm light under the rim, for the piece to glow in.
	var lamp := _mesh(parent, _box(Vector3(0.7, 0.015, 0.05)), Color("#ffe8b0"), Vector3(0, CASE_HEIGHT - 0.03, -0.35), true)
	var lm := toon(Color("#ffe8b0"))
	lm.emission_enabled = true
	lm.emission = Color("#ffd98a")
	lm.emission_energy_multiplier = 1.5
	lamp.material_override = lm
	var glass := MeshInstance3D.new()
	glass.mesh = _box(Vector3(0.78, 0.42, 0.78))
	var gm := toon(Color(C.glass, 0.28))
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override = gm
	glass.position = Vector3(0, 0.61, 0)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(glass)


## Pinned butterflies: little bright wings on a card.
func _butterflies(seed: int) -> Node3D:
	var g := Node3D.new()
	_mesh(g, _box(Vector3(0.6, 0.02, 0.6)), C.bone, Vector3(0, 0.01, 0))
	for i in 5:
		var a := _hash01(i, seed) * TAU
		var r := 0.08 + _hash01(i, seed, 4) * 0.14
		var colour: Color = [C.mineral_warm, C.gold, C.mineral, Color("#ff9f1c"), Color("#b07cff")][i]
		for side in [-1, 1]:
			var wing := _mesh(g, _box(Vector3(0.07, 0.008, 0.09)), colour, Vector3(cos(a) * r + side * 0.035, 0.03, sin(a) * r), true)
			wing.rotation.y = a
		_mesh(g, _box(Vector3(0.012, 0.012, 0.08)), C.ink, Vector3(cos(a) * r, 0.035, sin(a) * r), true).rotation.y = a
	return g


## A cluster of crystals catching the light.
func _minerals(seed: int) -> Node3D:
	var g := Node3D.new()
	for i in 4:
		var a := _hash01(i, seed, 2) * TAU
		var r := 0.06 + i * 0.05
		var s := SphereMesh.new()
		s.radius = 0.07 + i * 0.02
		s.height = s.radius * 3.2
		s.radial_segments = 4
		s.rings = 2
		var c := _mesh(g, s, C.mineral_warm if i == 1 else C.mineral, Vector3(cos(a) * r, s.height / 2, sin(a) * r), true)
		c.rotation = Vector3(0.25 * (i - 1.5), a, 0.2)
	return g


## An ammonite: a coiled fossil lying flat.
func _ammonite() -> Node3D:
	var g := Node3D.new()
	for ring in [[0.16, 0.07, C.bone_dark], [0.09, 0.05, C.bone], [0.035, 0.03, C.bone_dark]]:
		var t := TorusMesh.new()
		t.inner_radius = ring[0] - ring[1]
		t.outer_radius = ring[0] + ring[1]
		_mesh(g, t, ring[2], Vector3(0, 0.07, 0))
	return g


## A lump of meteorite: dark, faceted, pitted.
func _rock() -> Node3D:
	var g := Node3D.new()
	var s := SphereMesh.new()
	s.radius = 0.17
	s.height = 0.26
	s.radial_segments = 7
	s.rings = 4
	_mesh(g, s, C.stone, Vector3(0, 0.12, 0))
	return g


## A mounted skull, facing the gallery: the eye sockets read from above.
func _skull(parent: Node3D, yaw: float) -> void:
	var g := _pivot(parent, Vector3(0, CASE_HEIGHT - 0.06, 0), yaw)
	var cranium := SphereMesh.new()
	cranium.radius = 0.15
	cranium.height = 0.26
	_mesh(g, cranium, C.bone, Vector3(0, 0.12, 0))
	_mesh(g, _box(Vector3(0.16, 0.1, 0.16)), C.bone, Vector3(0, 0.06, 0.13))
	for dx in [-0.06, 0.06]:
		var eye := SphereMesh.new()
		eye.radius = 0.035
		eye.height = 0.07
		_mesh(g, eye, C.ink, Vector3(dx, 0.14, 0.12), true)
	# Teeth: a pale row along the jaw.
	_mesh(g, _box(Vector3(0.12, 0.025, 0.02)), Color.WHITE, Vector3(0, 0.02, 0.21), true)


## A habitat diorama: ferns and a stone in a planter, no glass.
func _diorama(parent: Node3D, seed: int) -> void:
	_mesh(parent, _box(Vector3(0.86, 0.4, 0.86)), C.case_dark, Vector3(0, 0.2, 0))
	_mesh(parent, _box(Vector3(0.8, 0.04, 0.8)), Color("#3b2f24"), Vector3(0, 0.42, 0))
	for i in 6:
		var a := _hash01(i, seed, 5) * TAU
		var r := _hash01(i, seed, 9) * 0.25
		var h := 0.2 + _hash01(i, seed, 11) * 0.3
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = h
		cone.radial_segments = 5
		var f := _mesh(parent, cone, C.fern.lightened(_hash01(i, seed, 2) * 0.2), Vector3(cos(a) * r, 0.44 + h / 2, sin(a) * r))
		f.rotation = Vector3(0, a, _hash01(i, seed, 13) * 0.4 - 0.2)
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.12
	s.radial_segments = 6
	s.rings = 3
	_mesh(parent, s, C.stone, Vector3(0.2, 0.46, -0.15))


## A Greek amphora: a turned body, neck and lip, two handles and a painted
## band of black figures round its belly.
func _amphora(parent: Node3D, on: float, seed: int) -> void:
	var clay := Color("#c8733c")
	var black := Color("#241a14")
	var body := SphereMesh.new()
	body.radius = 0.17
	body.height = 0.36
	_mesh(parent, body, clay, Vector3(0, on + 0.2, 0))
	var band := CylinderMesh.new()
	band.top_radius = 0.172
	band.bottom_radius = 0.172
	band.height = 0.07
	_mesh(parent, band, black, Vector3(0, on + 0.22, 0))
	for k in 5:
		var a := k * TAU / 5 + _hash01(seed, k) * 0.3
		_mesh(parent, _box(Vector3(0.03, 0.05, 0.01)), clay.lightened(0.2), Vector3(cos(a) * 0.175, on + 0.22, sin(a) * 0.175), true).rotation.y = -a + PI / 2
	var neck := CylinderMesh.new()
	neck.top_radius = 0.07
	neck.bottom_radius = 0.06
	neck.height = 0.12
	_mesh(parent, neck, clay, Vector3(0, on + 0.42, 0))
	var lip := TorusMesh.new()
	lip.inner_radius = 0.05
	lip.outer_radius = 0.085
	_mesh(parent, lip, black, Vector3(0, on + 0.48, 0))
	var foot := CylinderMesh.new()
	foot.top_radius = 0.06
	foot.bottom_radius = 0.1
	foot.height = 0.05
	_mesh(parent, foot, black, Vector3(0, on + 0.025, 0))
	for side in [-1, 1]:
		var handle := TorusMesh.new()
		handle.inner_radius = 0.045
		handle.outer_radius = 0.065
		var h := _mesh(parent, handle, clay, Vector3(side * 0.12, on + 0.38, 0))
		h.rotation.x = PI / 2


## A globe on a wooden stand in a brass meridian: blue seas, green lands.
func _globe(parent: Node3D) -> void:
	var wood := Color("#6b4a2e")
	for k in 3:
		var a := k * TAU / 3
		var leg := _mesh(parent, _box(Vector3(0.05, 0.45, 0.05)), wood, Vector3(cos(a) * 0.18, 0.22, sin(a) * 0.18))
		leg.rotation = Vector3(sin(a) * 0.25, 0, -cos(a) * 0.25)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.3
	ring.outer_radius = 0.34
	_mesh(parent, ring, wood, Vector3(0, 0.45, 0))
	var sea := SphereMesh.new()
	sea.radius = 0.28
	sea.height = 0.56
	_mesh(parent, sea, Color("#2f6f9f"), Vector3(0, 0.72, 0))
	for k in 6:
		var a := _hash01(k, 3) * TAU
		var b := (_hash01(k, 5) - 0.5) * 1.8
		var land := SphereMesh.new()
		land.radius = 0.09 + _hash01(k, 7) * 0.06
		land.height = land.radius * 0.8
		var at := Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b)) * 0.25
		var m := _mesh(parent, land, Color("#5aa050"), Vector3(0, 0.72, 0) + at, true)
		m.basis = Basis.looking_at(at.normalized(), Vector3.UP if absf(b) < 1.2 else Vector3.RIGHT)
	var meridian := TorusMesh.new()
	meridian.inner_radius = 0.31
	meridian.outer_radius = 0.33
	var mer := _mesh(parent, meridian, C.gold, Vector3(0, 0.72, 0), true)
	mer.rotation = Vector3(PI / 2, 0, 0.4)


## A suit of armour on a low stand, visor down, holding a lance.
func _armour(parent: Node3D) -> void:
	var steel := Color("#a9b2c3")
	var dark := Color("#5c6370")
	_mesh(parent, _box(Vector3(0.6, 0.08, 0.5)), C.case_dark, Vector3(0, 0.04, 0))
	for side in [-1, 1]:
		_mesh(parent, _box(Vector3(0.1, 0.36, 0.12)), steel, Vector3(side * 0.08, 0.26, 0))
		_mesh(parent, _box(Vector3(0.12, 0.05, 0.18)), dark, Vector3(side * 0.08, 0.1, 0.03))
		var shoulder := SphereMesh.new()
		shoulder.radius = 0.08
		shoulder.height = 0.12
		_mesh(parent, shoulder, steel, Vector3(side * 0.17, 0.78, 0))
		_mesh(parent, _box(Vector3(0.07, 0.3, 0.08)), steel, Vector3(side * 0.2, 0.6, 0.02))
	_mesh(parent, _box(Vector3(0.28, 0.14, 0.18)), dark, Vector3(0, 0.49, 0))
	_mesh(parent, _box(Vector3(0.3, 0.26, 0.2)), steel, Vector3(0, 0.68, 0))
	_mesh(parent, _box(Vector3(0.04, 0.2, 0.01)), dark, Vector3(0, 0.68, 0.1), true)
	var helm := CylinderMesh.new()
	helm.top_radius = 0.09
	helm.bottom_radius = 0.1
	helm.height = 0.18
	_mesh(parent, helm, steel, Vector3(0, 0.92, 0))
	_mesh(parent, _box(Vector3(0.14, 0.015, 0.01)), C.ink, Vector3(0, 0.94, 0.1), true)
	var plume := SphereMesh.new()
	plume.radius = 0.05
	plume.height = 0.14
	_mesh(parent, plume, C.crimson, Vector3(0, 1.05, -0.03))
	var lance := _mesh(parent, _box(Vector3(0.03, 1.1, 0.03)), Color("#6b4a2e"), Vector3(0.28, 0.6, 0.05))
	lance.rotation.z = -0.08
	var tip := CylinderMesh.new()
	tip.top_radius = 0.0
	tip.bottom_radius = 0.04
	tip.height = 0.12
	_mesh(parent, tip, steel, Vector3(0.325, 1.2, 0.05))


## A totem pole: stacked painted heads, eyes and beaks, wings at the top.
func _totem(parent: Node3D, seed: int) -> void:
	var paints := [Color("#b5462f"), Color("#2f6f9f"), Color("#3d7a4a"), Color("#d9a441")]
	var wood := Color("#7a5234")
	var y := 0.0
	for k in 3:
		var h := 0.3
		var drum := CylinderMesh.new()
		drum.top_radius = 0.15
		drum.bottom_radius = 0.16
		drum.height = h
		drum.radial_segments = 10
		_mesh(parent, drum, wood, Vector3(0, y + h / 2, 0))
		var paint: Color = paints[int(_hash01(seed, k) * 4) % 4]
		for side in [-1, 1]:
			var eye := SphereMesh.new()
			eye.radius = 0.04
			eye.height = 0.05
			_mesh(parent, eye, Color.WHITE, Vector3(side * 0.06, y + h * 0.65, 0.14), true)
			_mesh(parent, _box(Vector3(0.025, 0.025, 0.02)), C.ink, Vector3(side * 0.06, y + h * 0.65, 0.17), true)
			_mesh(parent, _box(Vector3(0.07, 0.02, 0.02)), paint, Vector3(side * 0.06, y + h * 0.85, 0.15), true)
		var beak := CylinderMesh.new()
		beak.top_radius = 0.0
		beak.bottom_radius = 0.04
		beak.height = 0.1 if k % 2 == 0 else 0.05
		var b := _mesh(parent, beak, paint, Vector3(0, y + h * 0.4, 0.18))
		b.rotation.x = PI / 2
		y += h
	for side in [-1, 1]:
		var wing := _mesh(parent, _box(Vector3(0.3, 0.1, 0.04)), paints[0], Vector3(side * 0.24, y - 0.08, 0))
		wing.rotation.z = side * 0.35


## A little dinosaur skeleton on a low platform: skull, spine, ribs, tail.
func _dinosaur(parent: Node3D) -> void:
	_mesh(parent, _box(Vector3(0.86, 0.1, 0.5)), C.case_dark, Vector3(0, 0.05, 0))
	for side in [-1, 1]:
		for leg in [-0.18, 0.14]:
			_mesh(parent, _box(Vector3(0.03, 0.34, 0.03)), C.bone_dark, Vector3(leg, 0.27, side * 0.07))
	# Spine: a curve of vertebrae from the tail tip to the neck.
	var n := 14
	for i in n:
		var t := float(i) / (n - 1)
		var x := lerpf(-0.42, 0.3, t)
		var y := 0.45 + sin(t * PI) * 0.12 + (0.15 * t * t if t > 0.8 else 0.0)
		var v := SphereMesh.new()
		v.radius = 0.028 + sin(t * PI) * 0.02
		v.height = v.radius * 2.0
		_mesh(parent, v, C.bone, Vector3(x, y, 0))
		if t > 0.3 and t < 0.75:
			var rib := TorusMesh.new()
			rib.inner_radius = 0.07
			rib.outer_radius = 0.085
			var r := _mesh(parent, rib, C.bone, Vector3(x, y - 0.07, 0), true)
			r.rotation.z = PI / 2
	var skull := _mesh(parent, _box(Vector3(0.16, 0.08, 0.08)), C.bone, Vector3(0.38, 0.66, 0))
	skull.rotation.z = -0.3
	_mesh(parent, _box(Vector3(0.1, 0.02, 0.06)), C.bone_dark, Vector3(0.4, 0.61, 0), true).rotation.z = -0.3
	var eye := SphereMesh.new()
	eye.radius = 0.018
	eye.height = 0.03
	_mesh(parent, eye, C.ink, Vector3(0.36, 0.68, 0.042), true)


## A mummy's case lying in a vitrine: gold, a painted face, blue stripes.
func _sarcophagus() -> Node3D:
	var g := Node3D.new()
	var gold := Color("#d9a441")
	var body := CapsuleMesh.new()
	body.radius = 0.13
	body.height = 0.62
	var b := _mesh(g, body, gold, Vector3(0, 0.1, 0))
	b.rotation.x = PI / 2
	b.scale = Vector3(1, 1, 0.6)
	for k in 4:
		var stripe := _mesh(g, _box(Vector3(0.24, 0.02, 0.025)), Color("#2f4f9f"), Vector3(0, 0.17, -0.12 + k * 0.08), true)
		stripe.rotation.x = 0
	_mesh(g, _box(Vector3(0.14, 0.02, 0.12)), Color("#e0b07a"), Vector3(0, 0.18, 0.2), true)
	for side in [-1, 1]:
		_mesh(g, _box(Vector3(0.03, 0.01, 0.015)), C.ink, Vector3(side * 0.035, 0.19, 0.22), true)
	_mesh(g, _box(Vector3(0.2, 0.03, 0.05)), Color("#2f4f9f"), Vector3(0, 0.17, 0.27), true)
	return g


## A downloaded model, fitted to a height and a footprint and sat on its
## plinth: models arrive at whatever scale their author left them in, so the
## bounding box decides. tint repaints it: a museum piece is stone or bone.
func _specimen(parent: Node3D, path: String, on: float, height: float, footprint: float, tint: Color) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	var holder := Node3D.new()
	holder.add_child(model)
	parent.add_child(holder)
	var box := _bounds(model, Transform3D.IDENTITY)
	if box.size.y <= 0:
		return
	var k := minf(height / box.size.y, footprint / maxf(maxf(box.size.x, box.size.z), 1e-6))
	holder.scale = Vector3.ONE * k
	var centre := box.get_center()
	holder.position = Vector3(-centre.x * k, on - box.position.y * k, -centre.z * k)
	var paint := toon(tint)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = paint


## Merged bounds of every mesh under a node, in that node's space.
static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var here := xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D:
		var b: AABB = here * (node as MeshInstance3D).get_aabb()
		box = b
		first = false
	for c in node.get_children():
		var cb := _bounds(c, here)
		if cb.size == Vector3.ZERO:
			continue
		box = cb if first else box.merge(cb)
		first = false
	return box


# --- Paintings -----------------------------------------------------------------

## Canvases on the wall faces the camera can see (facing south), each painted
## procedurally: a moonlit landscape, a dark portrait or a block abstract.
func _paintings() -> void:
	var most := 6 + Museum.w * Museum.h / 120
	var hung := 0
	for y in range(1, Museum.h - 1):
		for x in range(1, Museum.w - 1):
			if hung >= most:
				return
			if Museum.grid[y * Museum.w + x] != Tiles.WALL or Museum.is_outside(x, y):
				continue
			if Museum.grid[(y + 1) * Museum.w + x] != Tiles.FLOOR or _hash01(x, y, 23) < 0.72:
				continue
			var frame := Node3D.new()
			frame.position = to_world(x + 0.5, y + 1.0, 0.0)
			add_child(frame)
			_painting(frame, x * 31 + y * 7)
			hung += 1


func _painting(parent: Node3D, seed: int) -> void:
	var fw := 0.7
	var fh := 0.5
	var cy := 0.8
	_mesh(parent, _box(Vector3(fw + 0.05, fh + 0.05, 0.03)), C.ink, Vector3(0, cy, 0.015))
	_mesh(parent, _box(Vector3(fw, fh, 0.05)), C.gold_dim, Vector3(0, cy, 0.03))
	var canvas := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(fw - 0.1, fh - 0.1)
	canvas.mesh = q
	var m := StandardMaterial3D.new()
	# Unlit and a little dim: most hang where no light reaches, and a lit
	# canvas in the dark was a black rectangle.
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _canvas(seed)
	m.albedo_color = Color(0.62, 0.6, 0.58)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	canvas.material_override = m
	canvas.position = Vector3(0, cy, 0.056)
	parent.add_child(canvas)
	_mesh(parent, _box(Vector3(0.16, 0.05, 0.012)), C.bone, Vector3(0, cy - fh / 2 - 0.08, 0.01))


static func _canvas(seed: int) -> ImageTexture:
	var w := 48
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var r := func(k: int) -> float: return _hash01(seed, k, 71)
	var kind := int(r.call(1) * 3)
	if kind == 0:
		# Landscape: sky, a moon or low sun, hills in three planes.
		var dusk: bool = r.call(2) > 0.5
		var top := Color("#2a1f4d") if dusk else Color("#274b6e")
		var bottom := Color("#e07a5f") if dusk else Color("#a8d8e8")
		for yy in h:
			img.fill_rect(Rect2i(0, yy, w, 1), top.lerp(bottom, float(yy) / h))
		var sx := int(8 + r.call(3) * 30)
		var sy := int(8 + r.call(4) * 6)
		for yy in range(-3, 4):
			for xx in range(-3, 4):
				if xx * xx + yy * yy <= 9:
					img.set_pixel(clampi(sx + xx, 0, w - 1), clampi(sy + yy, 0, h - 1), Color("#ffd479") if dusk else Color("#fff4d0"))
		for plane in 3:
			var col: Color = [Color("#4a5d4f"), Color("#2f4a3a"), Color("#1b2c24")][plane]
			for xx in w:
				var top_y := int(20 + plane * 4 + sin(xx * 0.16 + r.call(5 + plane) * 6) * (4 - plane))
				img.fill_rect(Rect2i(xx, top_y, 1, h - top_y), col)
	elif kind == 1:
		# Portrait: a sitter in the dark, lit from one side.
		img.fill(Color("#1d120c"))
		img.fill_rect(Rect2i(8, 4, 32, 28), Color("#3a2618"))
		var coat := Color("#2a1a3a") if r.call(2) > 0.5 else Color("#3a1c1c")
		img.fill_rect(Rect2i(12, 26, 24, 10), coat)
		img.fill_rect(Rect2i(19, 10, 10, 14), Color("#d9b48f"))
		img.fill_rect(Rect2i(25, 10, 4, 14), Color("#a8805f"))
		img.fill_rect(Rect2i(18, 7, 12, 5), Color("#1a120c"))
	else:
		# Abstract: blocks of colour on cream, with black lines.
		img.fill(Color("#e8ddc0"))
		var cols := [Color("#9b2c3f"), Color("#7ad6ff"), Color("#f0c46a"), Color("#1b2433")]
		for j in 4:
			img.fill_rect(Rect2i(int(r.call(10 + j) * 34), int(r.call(20 + j) * 24), 8 + int(r.call(30 + j) * 14), 6 + int(r.call(40 + j) * 12)), cols[(j + int(r.call(2) * 4)) % 4])
		for j in 3:
			var at := 6 + int(r.call(60 + j) * 36)
			if r.call(50 + j) > 0.5:
				img.fill_rect(Rect2i(clampi(at, 0, w - 2), 0, 2, h), Color("#141018"))
			else:
				img.fill_rect(Rect2i(0, clampi(at * h / w, 0, h - 2), w, 2), Color("#141018"))
	return ImageTexture.create_from_image(img)


# --- Emergency lights ------------------------------------------------------------

## A few green fittings along the corridor inside the outer wall: enough to
## find your way by, nowhere near enough to search by.
func _emergency_lights() -> void:
	var spots: Array[Vector2i] = []
	for y in range(1, Museum.h - 1):
		for x in range(1, Museum.w - 1):
			if Museum.is_ring(x, y) and Museum.grid[y * Museum.w + x] == Tiles.FLOOR and (x * 3 + y * 5) % 11 == 0:
				spots.append(Vector2i(x, y))
	var every := maxi(1, ceili(spots.size() / float(MAX_EMERGENCY)))
	var fitting := StandardMaterial3D.new()
	fitting.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fitting.albedo_color = C.emergency
	for i in range(0, spots.size(), every):
		var s := spots[i]
		var light := OmniLight3D.new()
		light.light_color = C.emergency
		light.light_energy = 0.8
		light.omni_range = 5.0
		light.position = to_world(s.x + 0.5, s.y + 0.5, 2.1)
		add_child(light)
		var box := MeshInstance3D.new()
		box.mesh = _box(Vector3(0.34, 0.12, 0.1))
		box.material_override = fitting
		box.position = light.position
		add_child(box)


# --- Helpers ---------------------------------------------------------------------

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## One instanced mesh over a set of tiles. tint gives each its own shade of
## the colour, so a run of wall reads as panels; cap darkens the middle of
## big wall masses.
func _instances(mesh: Mesh, tiles: Array[Vector2i], height: float, mat: StandardMaterial3D, tint := 0.0, cap := false, offset := Vector3.ZERO) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = tint > 0 or cap
	mm.mesh = mesh
	mm.instance_count = tiles.size()
	if mm.use_colors:
		mat.vertex_color_use_as_albedo = true
	for i in tiles.size():
		var t := tiles[i]
		mm.set_instance_transform(i, Transform3D(Basis(), to_world(t.x + 0.5, t.y + 0.5, height) + offset))
		if mm.use_colors:
			var k := 1.0 - tint / 2.0 + _hash01(t.x, t.y) * tint
			if cap:
				k *= _cap_shade(t)
			mm.set_instance_color(i, Color(k, k, k))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	add_child(node)


## Deterministic 0..1 from a tile, so the plan looks the same every frame.
static func _hash01(x: int, y: int, salt := 41) -> float:
	return fposmod(absf(sin(x * 31.7 + y * 17.3 + salt * 7.13)), 1.0)


## One toon-shaded piece; detail pieces cast no shadow.
func _mesh(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, detail := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _toon_cached(colour)
	m.position = at
	if detail:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


var _mats := {}


func _toon_cached(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not _mats.has(key):
		_mats[key] = toon(colour)
	return _mats[key]


func _pivot(parent: Node3D, at: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = yaw
	parent.add_child(n)
	return n
