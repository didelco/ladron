class_name TownBuilder
extends RefCounted
## The town round the museums (CityStage), wide enough to fill the screen
## whatever it is looking at: a grid of streets with their pavements and
## crossings, and between them blocks of buildings from Kenney's city kits
## (CC0: City Kit Commercial, Suburban and Roads, in assets/models/ciudad):
## shops and offices in the middle, tall ones in the very middle, houses
## with gardens further out, a park or two, a river down one street with
## its bridges, street lamps at the corners and trees. All at night: the
## kits' own colours in the violet of the town at night, the windows lit
## warm here and there, the lamps glowing (NIGHT_SHADER).
##
## Everything of one model goes in one MultiMesh, so the whole town is a
## few dozen draws.
##
## The plan is in tiles, a road's width each: x across, z towards the
## viewer; a street every PITCH tiles each way, BLOCK tiles of block
## between. The town hangs off `root`, in its units (TILE a tile).

const KITS := "res://assets/models/ciudad/"
## A tile, in the town's units; a street every PITCH tiles; how far the
## town goes from its middle each way, in blocks.
const TILE := 1.4
const PITCH := 5
const BLOCK := 4
const REACH := 5

## The town's own colours at night: all here, to change in one place.
const PAVEMENT := Color("#443c58")
const PAVEMENT_EDGE := Color("#2f2940")
const GARDEN := Color("#34503f")
const PARK := Color("#2f4a3a")
const PATH := Color("#6d6070")
const WATER := Color("#27407a")
const WATER_GLINT := Color("#4b6fc0")
const BANK := Color("#3b3350")
const RAIL := Color("#8a7a9a")
const FAR := Color("#1f1a2e")
const LAMP := Color("#ffd479")
## The kits' faces, lit by the town at night: how much of the day's colour
## is left, the windows lit (one in LIT_SHARE), the lamps' glow.
const NIGHT := Color("#b9b0e0")
const WINDOW_LIT := Color("#ffc86a")
const LIT_SHARE := 0.55
## Walls and roofs a little different house to house, picked by each
## building's own number.
const WALLS := [Color("#f3e6ff"), Color("#ffe7d6"), Color("#e2f0ff"), Color("#f5f0e0"), Color("#ffd9e4")]
const ROOFS := [Color("#7a4a6e"), Color("#4f5f8a"), Color("#8a4f4a"), Color("#4a6e62"), Color("#6a4a8a")]

const NIGHT_SHADER := """
shader_type spatial;
uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform vec3 night : source_color = vec3(0.73, 0.69, 0.88);
uniform vec3 window_lit : source_color = vec3(1.0, 0.78, 0.42);
uniform float lit_share = 0.55;
uniform float windows = 1.0;
uniform float lamps = 0.0;
uniform vec3 walls[5];
uniform vec3 roofs[5];
varying vec3 world;
varying vec4 own;
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	own = INSTANCE_CUSTOM;
}
void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	int k = int(own.r * 4.99);
	// Glass: the kits' blues. Lit or not, window by window.
	float glass = windows * step(0.28, c.b - c.r) * step(c.r, c.g);
	float on = step(hash(floor(world * 2.2) + own.g * 17.0), lit_share);
	// White walls take the house's own tint; green roofs its roof.
	float white = step(0.86, min(c.r, min(c.g, c.b)));
	float green = step(0.12, c.g - c.r) * step(c.b, c.g) * (1.0 - glass);
	c = mix(c, walls[k], white * 0.85);
	c = mix(c, roofs[k] * (0.7 + c.g * 0.5), green * own.b);
	// The lamps' warm heads.
	float bulb = lamps * step(0.9, c.r) * step(0.6, c.g) * step(c.b, 0.45);
	vec3 base = c * night;
	ALBEDO = mix(base, mix(vec3(0.12, 0.13, 0.25), window_lit, on), glass);
	EMISSION = window_lit * glass * on * 1.6 + window_lit * bulb * 3.0;
	ROUGHNESS = 0.6;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
"""

var root: Node3D
## what each model is made of, and where each copy of it goes:
## path -> {"mesh", "inner": Transform3D, "at": [Transform3D], "own": [Color]}
var _batches := {}
var _materials := {}
var _rng := RandomNumberGenerator.new()
## the blocks taken by something else (the museums, the hideout): not built on
var skip := {}
## the museums' blocks: round them the town keeps low
var museums: Array = []
## the street down which the river runs, in tiles across (x)
var river_x := PITCH
## what happens on each block, "", "park", "tall", "shops" or "houses"
var _kind := {}


func _init(parent: Node3D) -> void:
	root = parent
	_rng.seed = 7


## A block's middle on the town's plan, in the town's units.
static func block_centre(b: Vector2i) -> Vector3:
	return Vector3((b.x * PITCH + PITCH * 0.5) * TILE, 0, (b.y * PITCH + PITCH * 0.5) * TILE)


## A block's size inside its streets, in the town's units.
static func block_size() -> float:
	return BLOCK * TILE


## The whole town: its streets, its blocks, its river and its lamps.
func build() -> void:
	_far_ground()
	_streets()
	for bx in range(-REACH, REACH):
		for bz in range(-REACH, REACH):
			var b := Vector2i(bx, bz)
			if skip.has(b):
				_pavement(b, PAVEMENT)
				continue
			_block(b)
	_river()
	_flush()


# --- The plan ---------------------------------------------------------------------

## A dark plane far under everything, should the camera see past the edge.
func _far_ground() -> void:
	var span := REACH * PITCH * TILE * 2.0 + 60.0
	_box(root, Vector3(span, 0.1, span), FAR, Vector3(0, -0.08, 0))


## The streets: a road tile on every street tile, crossings where two meet
## (with a zebra crossing on each side), the river's street a river.
func _streets() -> void:
	var lo := -REACH * PITCH
	var hi := REACH * PITCH
	for t in range(lo, hi + 1):
		for u in range(lo, hi + 1):
			var along_x := posmod(u, PITCH) == 0
			var along_z := posmod(t, PITCH) == 0
			if not along_x and not along_z:
				continue
			if t == river_x:
				continue
			var at := Vector3(t * TILE, 0, u * TILE)
			if along_x and along_z:
				_add("calles/road-crossroad.glb", at, 0.0)
			elif along_x:
				var near := posmod(t, PITCH) in [1, PITCH - 1]
				_add("calles/road-crossing.glb" if near else "calles/road-straight.glb", at, PI / 2)
			else:
				var near := posmod(u, PITCH) in [1, PITCH - 1]
				_add("calles/road-crossing.glb" if near else "calles/road-straight.glb", at, 0.0)


## A block's pavement: a slab a step up from the street.
func _pavement(b: Vector2i, colour: Color) -> void:
	var c := block_centre(b)
	var s := block_size()
	_box(root, Vector3(s + 0.02, 0.08, s + 0.02), PAVEMENT_EDGE, c + Vector3(0, 0.03, 0))
	_box(root, Vector3(s - 0.1, 0.08, s - 0.1), colour, c + Vector3(0, 0.05, 0))


## What goes on block b: at the back, the tall buildings of the middle of
## town, their lights on the skyline; round the museums, shops; further
## out, houses; now and then a park. Lamps at its corners.
func _block(b: Vector2i) -> void:
	var near := false
	for m in museums:
		if maxi(absi(m.x - b.x), absi(m.y - b.y)) <= 1:
			near = true
	var kind := "houses"
	if b.y <= -3 and absi(b.x) <= 3:
		kind = "tall"
	elif near and posmod(b.x + b.y, 2) == 0:
		kind = "shops"
	if posmod(b.x * 7 + b.y * 13, 9) == 0:
		kind = "park"
	_kind[b] = kind
	match kind:
		"park": _park(b)
		"houses": _houses(b)
		_: _shops(b, kind == "tall")
	_corner_lamps(b)


## A block of shops and offices: a building on every lot round its edge,
## each facing its street, a yard with trees in the middle.
func _shops(b: Vector2i, tall: bool) -> void:
	_pavement(b, PAVEMENT)
	var c := block_centre(b)
	var names := ["a", "b", "c", "d", "f", "g", "h"]
	var big := ["i", "l", "m", "skyscraper-a", "skyscraper-b", "skyscraper-c", "skyscraper-d", "skyscraper-e"]
	for i in BLOCK:
		for j in BLOCK:
			var edge := i == 0 or j == 0 or i == BLOCK - 1 or j == BLOCK - 1
			var at := c + Vector3((i - (BLOCK - 1) * 0.5) * TILE, 0.09, (j - (BLOCK - 1) * 0.5) * TILE)
			if not edge:
				if _rng.randf() < 0.7:
					_tree(at + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)))
				continue
			# Facing the street it is on: +z the front, -z the back, then the sides.
			var turn := 0.0
			if j == BLOCK - 1:
				turn = 0.0
			elif j == 0:
				turn = PI
			elif i == 0:
				turn = -PI / 2
			else:
				turn = PI / 2
			# Not every lot built on: a gap here and there for air and trees.
			var corner := (i == 0 or i == BLOCK - 1) and (j == 0 or j == BLOCK - 1)
			if not corner and not tall and _rng.randf() < 0.3:
				_tree(at)
				continue
			var name: String = names[_rng.randi() % names.size()]
			if tall and _rng.randf() < 0.55:
				name = big[_rng.randi() % big.size()]
			var path := "comercial/building-%s.glb" % name
			var k := _fit(path, TILE * 0.98)
			_add(path, at, turn, k, _own(0.0))


## A block of houses: four, one a corner, each on its garden facing its
## street, with a tree or two and a hedge.
func _houses(b: Vector2i) -> void:
	_pavement(b, PAVEMENT)
	var c := block_centre(b)
	var s := block_size()
	_box(root, Vector3(s - 0.5, 0.06, s - 0.5), GARDEN, c + Vector3(0, 0.1, 0))
	var letters := "abcdefghijklmnopqrstu"
	for qx in [-1, 1]:
		for qz in [-1, 1]:
			var at := c + Vector3(qx * s * 0.25, 0.12, qz * s * 0.25)
			var turn := 0.0 if qz > 0 else PI
			var path := "suburbios/building-type-%s.glb" % letters[_rng.randi() % letters.length()]
			_add(path, at, turn, _fit(path, s * 0.36), _own(1.0))
			_tree(at + Vector3(qx * s * 0.2, 0, -qz * s * 0.16))
			if _rng.randf() < 0.5:
				_tree(at + Vector3(-qx * s * 0.18, 0, -qz * s * 0.18))


## A park: grass, a path across it, trees all round.
func _park(b: Vector2i) -> void:
	_pavement(b, PAVEMENT)
	var c := block_centre(b)
	var s := block_size()
	_box(root, Vector3(s - 0.4, 0.06, s - 0.4), PARK, c + Vector3(0, 0.1, 0))
	_box(root, Vector3(s - 0.4, 0.07, 0.35), PATH, c + Vector3(0, 0.105, 0))
	_box(root, Vector3(0.35, 0.07, s - 0.4), PATH, c + Vector3(0, 0.105, 0))
	for k in 14:
		var at := c + Vector3(_rng.randf_range(-s * 0.42, s * 0.42), 0.13, _rng.randf_range(-s * 0.42, s * 0.42))
		if absf(at.x - c.x) < 0.4 or absf(at.z - c.z) < 0.4:
			continue
		_tree(at)


## A street lamp at each corner of block b, turned over the street.
func _corner_lamps(b: Vector2i) -> void:
	var c := block_centre(b)
	var h := block_size() * 0.5 - 0.12
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var at := c + Vector3(sx * h, 0.09, sz * h)
			_add("calles/light-square.glb", at, atan2(float(sx), float(sz)) + PI, TILE * 1.1, _own(0.0))


func _tree(at: Vector3) -> void:
	var path := "suburbios/tree-large.glb" if _rng.randf() < 0.6 else "suburbios/tree-small.glb"
	_add(path, at, _rng.randf() * TAU, TILE * _rng.randf_range(1.5, 2.1), _own(0.0))


## The river down its street: water between two stone banks, a little
## lower than the street; a bridge with rails where each street crosses.
func _river() -> void:
	var x := river_x * TILE
	var span := REACH * PITCH * TILE * 2.0 + 4.0
	_box(root, Vector3(TILE, 0.1, span), WATER, Vector3(x, -0.06, 0))
	for s in [-1, 1]:
		_box(root, Vector3(0.12, 0.16, span), BANK, Vector3(x + s * TILE * 0.5, 0.0, 0))
	# The moon on the water, in strips.
	for k in 40:
		var z := _rng.randf_range(-span * 0.5, span * 0.5)
		var glint := _box(root, Vector3(_rng.randf_range(0.2, 0.7), 0.02, 0.05), WATER_GLINT, Vector3(x + _rng.randf_range(-0.4, 0.4), 0.0, z))
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for u in range(-REACH, REACH + 1):
		var z := u * PITCH * TILE
		_add("calles/road-straight.glb", Vector3(x, 0.06, z), 0.0)
		_box(root, Vector3(TILE * 1.2, 0.08, TILE), BANK, Vector3(x, 0.0, z))
		for s in [-1, 1]:
			_box(root, Vector3(TILE * 1.1, 0.14, 0.06), RAIL, Vector3(x, 0.15, z + s * TILE * 0.47))


# --- Making -----------------------------------------------------------------------

## A building's own look: its wall and roof tints (a number each), whether
## its roof takes the tint (1 for houses), its windows' own luck.
func _own(roof: float) -> Color:
	return Color(_rng.randf(), _rng.randf(), roof, 1.0)


## How much to scale a model for it to be `across` wide at most.
func _fit(path: String, across: float) -> float:
	var batch := _batch(path)
	var size: Vector3 = batch.size
	return across / maxf(size.x, size.z)


## One more of model `path`: at, turned (about y) and scaled.
func _add(path: String, at: Vector3, turn: float, k := TILE, own := Color(0, 0, 0, 1)) -> void:
	var batch := _batch(path)
	var xf := Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * k), at)
	(batch.at as Array).append(xf * (batch.inner as Transform3D))
	(batch.own as Array).append(own)


func _batch(path: String) -> Dictionary:
	if not _batches.has(path):
		var scene: Node = (load(KITS + path) as PackedScene).instantiate()
		var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		var inner := Transform3D.IDENTITY
		var n: Node = mi
		while n != scene:
			inner = (n as Node3D).transform * inner
			n = n.get_parent()
		var aabb := inner * mi.get_aabb()
		_batches[path] = {"mesh": mi.mesh, "inner": inner, "size": aabb.size, "at": [], "own": []}
		scene.free()
	return _batches[path]


## Every model's copies as one MultiMesh, in the night's colours.
func _flush() -> void:
	for path in _batches:
		var batch: Dictionary = _batches[path]
		var at: Array = batch.at
		if at.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = batch.mesh
		mm.instance_count = at.size()
		for i in at.size():
			mm.set_instance_transform(i, at[i])
			mm.set_instance_custom_data(i, batch.own[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _night(String(path).get_slice("/", 0))
		if String(path).begins_with("calles/road"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)


## A kit's night material: its colour map, its windows lit (the buildings),
## its lamps glowing (the streets).
func _night(kit: String) -> ShaderMaterial:
	if not _materials.has(kit):
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = NIGHT_SHADER
		m.set_shader_parameter("colormap", load(KITS + kit + "/Textures/colormap.png"))
		m.set_shader_parameter("night", Vector3(NIGHT.r, NIGHT.g, NIGHT.b))
		m.set_shader_parameter("window_lit", Vector3(WINDOW_LIT.r, WINDOW_LIT.g, WINDOW_LIT.b))
		m.set_shader_parameter("lit_share", LIT_SHARE)
		m.set_shader_parameter("windows", 0.0 if kit == "calles" else 1.0)
		m.set_shader_parameter("lamps", 1.0 if kit == "calles" else 0.0)
		m.set_shader_parameter("walls", PackedVector3Array(WALLS.map(func(c): return Vector3(c.r, c.g, c.b))))
		m.set_shader_parameter("roofs", PackedVector3Array(ROOFS.map(func(c): return Vector3(c.r, c.g, c.b))))
		_materials[kit] = m
	return _materials[kit]


func _box(parent: Node3D, s: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = s
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = MenuStage._material(colour)
	mi.position = at
	parent.add_child(mi)
	return mi
