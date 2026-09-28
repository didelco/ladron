class_name TownBuilder
extends RefCounted
## The town round the museums (CityStage), far bigger than the screen, the
## camera gliding over it from one museum to the next. Not one grid: a
## river crosses it on the slant, winding in wide bends (river_at), and
## splits it into districts (District), each its own grid of streets turned
## its own way, two on either bank; between them and along the water, woods
## and grass. The far bank stands higher (RISE), up a wooded slope from
## the water; a couple of bridges (bridges) are the only ways across.
##
## Inside a district: streets with their pavements and crossings, and
## between them blocks of buildings from Kenney's city kits (CC0: City Kit
## Commercial, Suburban and Roads, in assets/models/ciudad): shops and
## offices round the museums, tall ones at the back of the high town,
## houses with gardens further out, a park now and then, street lamps at
## the corners. All at night: the kits' own colours in the violet of the
## town at night, the windows lit warm here and there, the lamps glowing
## (NIGHT_SHADER). Everything of one model goes in one MultiMesh, so the
## whole town is a few dozen draws.
##
## The plan: x across, z towards the viewer, in the town's units (TILE a
## tile, a road's width). A district's grid is in tiles: a street every
## PITCH tiles each way, BLOCK tiles of block between. The river and the
## districts are laid out along `along` (the way the river runs) and `up`
## (towards the far, high bank): s along, q up (frame()).

const KITS := "res://assets/models/ciudad/"
## A tile, in the town's units; a street every PITCH tiles, BLOCK of block.
const TILE := 1.4
const PITCH := 5
const BLOCK := 4
## How far the town goes from its middle each way (the camera never sees
## past it).
const REACH := 52.0

## The river: how wide the water, how wide and how long its bends (their
## sideways reach, and the length of one full bend along it).
const RIVER_WIDTH := 3.0
const MEANDER := 5.0
const MEANDER_LENGTH := 50.0
## The far bank: how much higher the town stands there, and how wide the
## wooded slope up to it from the water.
const RISE := 2.2
const SLOPE := 3.8
## Land kept clear of blocks: along the near bank, and either side of the
## line between two districts of one bank.
const BANK_CLEAR := 1.0
const SPLIT_CLEAR := 2.6
## The bridges, where they cross (s along the river).
const BRIDGES := [-8.0, 15.0]
## Trees in the woods: one every WOOD_STEP or so, where there is room.
const WOOD_STEP := 1.25

## The town's own colours at night: all here, to change in one place.
const PAVEMENT := Color("#443c58")
const PAVEMENT_EDGE := Color("#2f2940")
const GARDEN := Color("#34503f")
const PARK := Color("#2f4a3a")
const MEADOW := Color("#2b4436")
const PATH := Color("#6d6070")
const ROAD := Color("#48425a")
const WATER := Color("#27407a")
const WATER_GLINT := Color("#4b6fc0")
const BANK := Color("#3b3350")
const RIVERBED := Color("#1c2238")
const RAIL := Color("#8a7a9a")
const STONE := Color("#6a5f7e")
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


## One district: a grid of streets turned `angle` about its `origin`, on one
## bank (`high`: the far one, RISE up).
class District:
	var angle := 0.0
	var origin := Vector2.ZERO
	var high := false
	## the blocks built on: block -> what goes on it ("" until build)
	var blocks := {}
	## the street tiles round them: tile -> true
	var tiles := {}

	func basis() -> Basis:
		return Basis(Vector3.UP, angle)

	func height() -> float:
		return TownBuilder.RISE if high else 0.0

	## A point of the district's own plan (tiles' units) on the town's plan.
	func world(local: Vector3) -> Vector3:
		return Vector3(origin.x, height(), origin.y) + basis() * local

	## A point of the town's plan in the district's own plan.
	func local(p: Vector2) -> Vector3:
		return basis().inverse() * Vector3(p.x - origin.x, 0, p.y - origin.y)

	func centre(b: Vector2i) -> Vector3:
		return world(Vector3((b.x * PITCH + PITCH * 0.5) * TILE, 0, (b.y * PITCH + PITCH * 0.5) * TILE))

	func tile(t: int, u: int) -> Vector3:
		return world(Vector3(t * TILE, 0, u * TILE))


var root: Node3D
## what each model is made of, and where each copy of it goes:
## path -> {"mesh", "inner": Transform3D, "at": [Transform3D], "own": [Color]}
var _batches := {}
var _materials := {}
var _rng := RandomNumberGenerator.new()
## the way the river runs and the way up to the far bank, on the plan
var along := Vector2(1, 0)
var up := Vector2(0, -1)
## where the districts of each bank meet (s along the river)
var split_low := 0.0
var split_high := 6.0
var districts: Array[District] = []
## the blocks taken by something else (the museums, the hideout), built as
## bare pavement: Vector3i(district, x, y) -> true
var skip := {}
## the museums' lots on the plan: round them, shops
var museums: Array[Vector2] = []
## the bridges: [low end, high end] on the plan, at their heights
var bridges: Array = []
## the streets as a graph, for the way between two places (route): node ->
## Vector3 where, and node -> {node: length}
var _nodes := {}
var _links := {}
## the roads laid outside the districts (to the bridges, between
## districts): [from, to], kept clear of trees
var _roads: Array = []


func _init(parent: Node3D) -> void:
	root = parent
	_rng.seed = 7


## A block's size inside its streets, in the town's units.
static func block_size() -> float:
	return BLOCK * TILE


# --- The lie of the land ------------------------------------------------------------

## s along the river and q up towards the far bank, of a point of the plan.
func frame(p: Vector2) -> Vector2:
	return Vector2(p.dot(along), p.dot(up))


## The point of the plan at s along and q up.
func point(s: float, q: float) -> Vector2:
	return along * s + up * q


## How far up the middle of the river is, at s along it.
func river_at(s: float) -> float:
	return MEANDER * sin(s * TAU / MEANDER_LENGTH + 0.8)


## How far a point is from the middle of the river, across it: negative on
## the near bank, positive on the far one.
func across(p: Vector2) -> float:
	var f := frame(p)
	var slope := MEANDER * TAU / MEANDER_LENGTH * cos(f.x * TAU / MEANDER_LENGTH + 0.8)
	return (f.y - river_at(f.x)) / sqrt(1.0 + slope * slope)


## How high the ground is at a point: the river's bed below it all, level
## on the near bank, up the slope to RISE on the far one.
func ground(p: Vector2) -> float:
	var d := across(p)
	var half := RIVER_WIDTH * 0.5
	if absf(d) < half + 0.3:
		return lerpf(-0.55, 0.0, smoothstep(half - 0.6, half + 0.3, absf(d)))
	if d < 0.0:
		return 0.0
	return RISE * smoothstep(half + 0.3, half + SLOPE, d)


## The way the river runs at s along it, and the way across it (towards
## the far bank).
func _tangent(s: float) -> Vector2:
	var slope := MEANDER * TAU / MEANDER_LENGTH * cos(s * TAU / MEANDER_LENGTH + 0.8)
	return (along + up * slope).normalized()


func _across_dir(s: float) -> Vector2:
	var slope := MEANDER * TAU / MEANDER_LENGTH * cos(s * TAU / MEANDER_LENGTH + 0.8)
	return (up - along * slope).normalized()


## The district a point belongs to, or -1: on a bank clear of the water and
## the slope, and clear of the line between the two districts of its bank.
func district_of(p: Vector2) -> int:
	if absf(p.x) > REACH or absf(p.y) > REACH:
		return -1
	var d := across(p)
	var s := frame(p).x
	var half := RIVER_WIDTH * 0.5
	if d < 0.0:
		if d > -(half + BANK_CLEAR) or absf(s - split_low) < SPLIT_CLEAR:
			return -1
		return 0 if s < split_low else 1
	if d < half + SLOPE + 0.3 or absf(s - split_high) < SPLIT_CLEAR:
		return -1
	return 2 if s < split_high else 3


# --- Laying it out ------------------------------------------------------------------

## The districts and which of their blocks are built on: every block whose
## whole square (streets and all) falls in its district. Angles: each its own.
func plan(angles: Array, origins: Array[Vector2]) -> void:
	districts.clear()
	for i in 4:
		var d := District.new()
		d.angle = deg_to_rad(float(angles[i]))
		d.origin = origins[i]
		d.high = i >= 2
		districts.append(d)
		var r := int(REACH * 2.0 / (PITCH * TILE)) + 2
		for bx in range(-r, r):
			for bz in range(-r, r):
				var b := Vector2i(bx, bz)
				var inside := true
				for c in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0.5)]:
					var w := d.world(Vector3((b.x + c.x) * PITCH * TILE, 0, (b.y + c.y) * PITCH * TILE))
					if district_of(Vector2(w.x, w.z)) != i:
						inside = false
						break
				if inside:
					d.blocks[b] = ""
		for b in d.blocks:
			_ring_of(d, b)


## The street tiles round block b.
func _ring_of(d: District, b: Vector2i) -> void:
	for k in PITCH + 1:
		for tu in [Vector2i(b.x * PITCH + k, b.y * PITCH), Vector2i(b.x * PITCH + k, (b.y + 1) * PITCH),
				Vector2i(b.x * PITCH, b.y * PITCH + k), Vector2i((b.x + 1) * PITCH, b.y * PITCH + k)]:
			d.tiles[tu] = true


## The district a point is on, by its bank and its side of the line between
## the two of that bank, however close to the water or that line.
func bank_of(p: Vector2) -> int:
	var s := frame(p).x
	if across(p) < 0.0:
		return 0 if s < split_low else 1
	return 2 if s < split_high else 3


## The block of district i under a point, built on from now on (and kept
## for whoever asked, as skip) even if it reaches a little into the clear
## land by the water or between districts: a museum by the river.
func claim(i: int, p: Vector2) -> Vector2i:
	var d := districts[i]
	var l := d.local(p)
	var b := Vector2i(floori(l.x / (PITCH * TILE)), floori(l.z / (PITCH * TILE)))
	if not d.blocks.has(b):
		d.blocks[b] = ""
		_ring_of(d, b)
	skip[Vector3i(i, b.x, b.y)] = true
	return b


## The whole town: the ground and the river, the districts, the bridges and
## the roads to them, and the woods in between.
func build() -> void:
	_terrain()
	_water()
	for i in districts.size():
		_district(i)
	_bridges()
	_join_districts()
	_woods()
	_flush()


# --- The ground and the water --------------------------------------------------------

## The ground as one mesh, following ground(): grass everywhere, darker
## meadow here and there, the river's banks and bed.
func _terrain() -> void:
	var step := 0.8
	var n := int((REACH + 8.0) * 2.0 / step)
	var lo := -(REACH + 8.0)
	var heights := PackedFloat32Array()
	var colours := PackedColorArray()
	heights.resize((n + 1) * (n + 1))
	colours.resize((n + 1) * (n + 1))
	var half := RIVER_WIDTH * 0.5
	for j in n + 1:
		for i in n + 1:
			var p := Vector2(lo + i * step, lo + j * step)
			var k := j * (n + 1) + i
			heights[k] = ground(p)
			var d := absf(across(p))
			var c := PARK.lerp(MEADOW, 0.5 + 0.5 * sin(p.x * 0.31 + sin(p.y * 0.23) * 2.0))
			if d < half + 0.4:
				c = RIVERBED.lerp(BANK, smoothstep(half - 0.5, half + 0.4, d))
			colours[k] = c
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var quad := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for v in quad:
				var k: int = v.y * (n + 1) + v.x
				st.set_color(colours[k])
				st.add_vertex(Vector3(lo + v.x * step, heights[k], lo + v.y * step))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	mi.material_override = m
	root.add_child(mi)


## The water: a sheet over the river's bed, and the moon on it in strips
## along the bends.
func _water() -> void:
	var span := (REACH + 8.0) * 2.0
	var sheet := _box(root, Vector3(span, 0.02, span), WATER, Vector3(0, -0.22, 0))
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var s := -REACH * 1.5
	while s < REACH * 1.5:
		s += _rng.randf_range(0.8, 2.2)
		var at := point(s, river_at(s) + _rng.randf_range(-0.9, 0.9))
		if absf(at.x) > REACH + 6.0 or absf(at.y) > REACH + 6.0:
			continue
		var dir := _tangent(s)
		var glint := _box(root, Vector3(0.05, 0.02, _rng.randf_range(0.3, 0.9)), WATER_GLINT, Vector3(at.x, -0.2, at.y), Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP))
		glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- The districts ------------------------------------------------------------------

func _district(i: int) -> void:
	var d := districts[i]
	_streets(d)
	for b in d.blocks:
		if skip.has(Vector3i(i, b.x, b.y)):
			_pavement(d, b, PAVEMENT)
			continue
		_block(d, b)
	# The streets as a graph: a node at every crossing, linked along each
	# street to the next.
	for tu in d.tiles:
		if posmod(tu.x, PITCH) != 0 or posmod(tu.y, PITCH) != 0:
			continue
		var at := d.tile(tu.x, tu.y)
		_node(Vector3i(i, tu.x, tu.y), at)
		for step in [Vector2i(PITCH, 0), Vector2i(0, PITCH)]:
			var to: Vector2i = tu + step
			var ok := true
			for k in range(1, PITCH + 1):
				if not d.tiles.has(tu + step / PITCH * k):
					ok = false
					break
			if ok:
				_node(Vector3i(i, to.x, to.y), d.tile(to.x, to.y))
				_link(Vector3i(i, tu.x, tu.y), Vector3i(i, to.x, to.y))


## The streets of a district: a road tile on every street tile, crossings
## where two meet (with a zebra crossing on each side).
func _streets(d: District) -> void:
	for tu in d.tiles:
		var t: int = tu.x
		var u: int = tu.y
		var along_x := posmod(u, PITCH) == 0
		var along_z := posmod(t, PITCH) == 0
		var at := d.tile(t, u) + Vector3(0, 0.005, 0)
		if along_x and along_z:
			_add("calles/road-crossroad.glb", at, d.angle)
		elif along_x:
			var near := posmod(t, PITCH) in [1, PITCH - 1]
			_add("calles/road-crossing.glb" if near else "calles/road-straight.glb", at, d.angle + PI / 2)
		else:
			var near := posmod(u, PITCH) in [1, PITCH - 1]
			_add("calles/road-crossing.glb" if near else "calles/road-straight.glb", at, d.angle)


## A block's pavement: a slab a step up from the street.
func _pavement(d: District, b: Vector2i, colour: Color) -> void:
	var c := d.centre(b)
	var s := block_size()
	_box(root, Vector3(s + 0.02, 0.08, s + 0.02), PAVEMENT_EDGE, c + Vector3(0, 0.03, 0), d.basis())
	_box(root, Vector3(s - 0.1, 0.08, s - 0.1), colour, c + Vector3(0, 0.05, 0), d.basis())


## What goes on block b: at the back of the high town, the tall buildings,
## their lights on the skyline; round the museums, shops; further out,
## houses; now and then a park. Lamps at its corners.
func _block(d: District, b: Vector2i) -> void:
	var c := d.centre(b)
	var near := museums.any(func(m: Vector2) -> bool: return m.distance_to(Vector2(c.x, c.z)) < 12.0)
	var kind := "houses"
	if d.high and frame(Vector2(c.x, c.z)).y - river_at(frame(Vector2(c.x, c.z)).x) > 26.0 and posmod(b.x + b.y * 3, 3) != 0:
		kind = "tall"
	elif near and posmod(b.x + b.y, 2) == 0:
		kind = "shops"
	if posmod(b.x * 7 + b.y * 13, 9) == 0:
		kind = "park"
	d.blocks[b] = kind
	match kind:
		"park": _park(d, b)
		"houses": _houses(d, b)
		_: _shops(d, b, kind == "tall")
	_corner_lamps(d, b)


## A block of shops and offices: a building on every lot round its edge,
## each facing its street, a yard with trees in the middle.
func _shops(d: District, b: Vector2i, tall: bool) -> void:
	_pavement(d, b, PAVEMENT)
	var c := d.centre(b)
	var names := ["a", "b", "c", "d", "f", "g", "h"]
	var big := ["i", "l", "m", "skyscraper-a", "skyscraper-b", "skyscraper-c", "skyscraper-d", "skyscraper-e"]
	for i in BLOCK:
		for j in BLOCK:
			var edge := i == 0 or j == 0 or i == BLOCK - 1 or j == BLOCK - 1
			var at := c + d.basis() * Vector3((i - (BLOCK - 1) * 0.5) * TILE, 0.09, (j - (BLOCK - 1) * 0.5) * TILE)
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
			_add(path, at, d.angle + turn, k, _own(0.0))


## A block of houses: four, one a corner, each on its garden facing its
## street, with a tree or two and a hedge.
func _houses(d: District, b: Vector2i) -> void:
	_pavement(d, b, PAVEMENT)
	var c := d.centre(b)
	var s := block_size()
	_box(root, Vector3(s - 0.5, 0.06, s - 0.5), GARDEN, c + Vector3(0, 0.1, 0), d.basis())
	var letters := "abcdefghijklmnopqrstu"
	for qx in [-1, 1]:
		for qz in [-1, 1]:
			var at := c + d.basis() * Vector3(qx * s * 0.25, 0.12, qz * s * 0.25)
			var turn := 0.0 if qz > 0 else PI
			var path := "suburbios/building-type-%s.glb" % letters[_rng.randi() % letters.length()]
			_add(path, at, d.angle + turn, _fit(path, s * 0.36), _own(1.0))
			_tree(at + d.basis() * Vector3(qx * s * 0.2, 0, -qz * s * 0.16))
			if _rng.randf() < 0.5:
				_tree(at + d.basis() * Vector3(-qx * s * 0.18, 0, -qz * s * 0.18))


## A park: grass, a path across it, trees all round.
func _park(d: District, b: Vector2i) -> void:
	_pavement(d, b, PAVEMENT)
	var c := d.centre(b)
	var s := block_size()
	_box(root, Vector3(s - 0.4, 0.06, s - 0.4), PARK, c + Vector3(0, 0.1, 0), d.basis())
	_box(root, Vector3(s - 0.4, 0.07, 0.35), PATH, c + Vector3(0, 0.105, 0), d.basis())
	_box(root, Vector3(0.35, 0.07, s - 0.4), PATH, c + Vector3(0, 0.105, 0), d.basis())
	for k in 14:
		var off := Vector3(_rng.randf_range(-s * 0.42, s * 0.42), 0.13, _rng.randf_range(-s * 0.42, s * 0.42))
		if absf(off.x) < 0.4 or absf(off.z) < 0.4:
			continue
		_tree(c + d.basis() * off)


## A street lamp at each corner of block b, turned over the street.
func _corner_lamps(d: District, b: Vector2i) -> void:
	var c := d.centre(b)
	var h := block_size() * 0.5 - 0.12
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var at := c + d.basis() * Vector3(sx * h, 0.09, sz * h)
			_add("calles/light-square.glb", at, d.angle + atan2(float(sx), float(sz)) + PI, TILE * 1.1, _own(0.0))


func _tree(at: Vector3) -> void:
	var path := "suburbios/tree-large.glb" if _rng.randf() < 0.6 else "suburbios/tree-small.glb"
	_add(path, at, _rng.randf() * TAU, TILE * _rng.randf_range(1.5, 2.1), _own(0.0))


# --- Crossing and joining ------------------------------------------------------------

## The bridges: from the near bank, over the water and up the slope to the
## high town, a stone deck on piers with a rail each side, lamps at the
## ends; a road on to the nearest crossing of each bank.
func _bridges() -> void:
	bridges.clear()
	for s in BRIDGES:
		var mid := point(s, river_at(s))
		var dir := _across_dir(s)
		var half := RIVER_WIDTH * 0.5
		var low2 := mid - dir * (half + 0.9)
		var high2 := mid + dir * (half + SLOPE + 0.4)
		var low := Vector3(low2.x, 0.0, low2.y)
		var high := Vector3(high2.x, RISE, high2.y)
		bridges.append([low, high])
		var deck := low + Vector3(0, 0.12, 0)
		var top := high + Vector3(0, 0.12, 0)
		_beam(root, deck, top, TILE * 1.05, 0.14, STONE)
		_beam(root, deck + Vector3(0, 0.02, 0), top + Vector3(0, 0.02, 0), TILE * 0.8, 0.14, ROAD)
		var side := Vector3(-dir.y, 0, dir.x) * TILE * 0.5
		for sgn in [-1, 1]:
			_beam(root, deck + side * sgn + Vector3(0, 0.2, 0), top + side * sgn + Vector3(0, 0.2, 0), 0.07, 0.1, RAIL)
			for e in [deck, top]:
				_add("calles/light-square.glb", e + side * sgn * 1.15 - Vector3(0, 0.1, 0), atan2(dir.x, dir.y), TILE * 1.1, _own(0.0))
		# Piers in the water.
		for k in [0.3, 0.55]:
			var at := deck.lerp(top, k)
			_box(root, Vector3(TILE * 0.9, at.y + 0.3, 0.35), STONE.darkened(0.25), Vector3(at.x, (at.y - 0.3) * 0.5 - 0.15, at.z), Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP))
		var low_id := Vector3i(-1, bridges.size(), 0)
		var high_id := Vector3i(-1, bridges.size(), 1)
		_node(low_id, deck)
		_node(high_id, top)
		_link(low_id, high_id)
		_road_to_nearest(low_id, deck, false)
		_road_to_nearest(high_id, top, true)


## Each two districts of a bank joined by a road across the woods between
## them: from the closest two of their crossings.
func _join_districts() -> void:
	for pair in [[0, 1], [2, 3]]:
		var best := []
		var best_d := INF
		for a in _nodes:
			if a.x != pair[0]:
				continue
			for b in _nodes:
				if b.x != pair[1]:
					continue
				var dd: float = (_nodes[a] as Vector3).distance_to(_nodes[b])
				if dd < best_d:
					best_d = dd
					best = [a, b]
		if not best.is_empty():
			_road(best[0], best[1])


## A road from a place (a bridge's end) to the nearest crossing of the
## districts of its bank.
func _road_to_nearest(from: Vector3i, at: Vector3, high: bool) -> void:
	var best := Vector3i(-2, 0, 0)
	var best_d := INF
	for k in _nodes:
		if k.x < 0 or districts[k.x].high != high:
			continue
		var dd: float = (_nodes[k] as Vector3).distance_to(at)
		if dd < best_d:
			best_d = dd
			best = k
	if best.x >= 0:
		_road(from, best)


## A road laid over the ground between two nodes: tarmac on a kerb, lamps
## along it now and then, and a link in the graph.
func _road(a: Vector3i, b: Vector3i) -> void:
	var from: Vector3 = _nodes[a]
	var to: Vector3 = _nodes[b]
	_roads.append([Vector2(from.x, from.z), Vector2(to.x, to.z)])
	var lift := Vector3(0, 0.01, 0)
	_beam(root, from + lift, to + lift, TILE * 1.0, 0.05, PAVEMENT_EDGE)
	_beam(root, from + lift + Vector3(0, 0.01, 0), to + lift + Vector3(0, 0.01, 0), TILE * 0.8, 0.05, ROAD)
	var length := from.distance_to(to)
	var dir := (to - from).normalized()
	var side := Vector3(-dir.z, 0, dir.x) * TILE * 0.62
	var k := 3.0
	while k < length - 2.0:
		var at := from + dir * k
		_add("calles/light-square.glb", at + side, atan2(side.x, side.z) + PI, TILE * 1.1, _own(0.0))
		k += 5.0
	_link(a, b)


# --- The woods ----------------------------------------------------------------------

## Trees wherever there is land and nothing built: along the river, up the
## slope, between the districts and out past them. Thicker on the slope.
func _woods() -> void:
	var y := -(REACH + 6.0)
	while y < REACH + 6.0:
		var x := -(REACH + 6.0)
		while x < REACH + 6.0:
			var p := Vector2(x + _rng.randf_range(-0.5, 0.5) * WOOD_STEP, y + _rng.randf_range(-0.5, 0.5) * WOOD_STEP)
			x += WOOD_STEP
			var d := across(p)
			if absf(d) < RIVER_WIDTH * 0.5 + 0.5:
				continue
			var on_slope := d > 0.0 and d < RIVER_WIDTH * 0.5 + SLOPE
			if _rng.randf() > (0.85 if on_slope else 0.55):
				continue
			if _built(p) or _on_road(p):
				continue
			_tree(Vector3(p.x, ground(p) - 0.02, p.y))
		y += WOOD_STEP


## Something built there: a district's blocks or streets.
func _built(p: Vector2) -> bool:
	for d in districts:
		var l := d.local(p)
		var tx := l.x / TILE
		var tz := l.z / TILE
		for ox in [-0.8, 0.8]:
			for oz in [-0.8, 0.8]:
				var b := Vector2i(floori((tx + ox) / PITCH), floori((tz + oz) / PITCH))
				if d.blocks.has(b):
					return true
	return false


func _on_road(p: Vector2) -> bool:
	for r in _roads:
		if Geometry2D.get_closest_point_to_segment(p, r[0], r[1]).distance_to(p) < TILE * 1.1:
			return true
	for b in bridges:
		var a := Vector2(b[0].x, b[0].z)
		var c := Vector2(b[1].x, b[1].z)
		if Geometry2D.get_closest_point_to_segment(p, a, c).distance_to(p) < TILE * 1.2:
			return true
	return false


# --- The way between two places ----------------------------------------------------

func _node(k: Vector3i, at: Vector3) -> void:
	_nodes[k] = at
	if not _links.has(k):
		_links[k] = {}


func _link(a: Vector3i, b: Vector3i) -> void:
	var dd: float = (_nodes[a] as Vector3).distance_to(_nodes[b])
	_links[a][b] = dd
	_links[b][a] = dd


## The crossing of district i's streets nearest the front of block b (the
## street on its near side), and where that front is.
func door(i: int, b: Vector2i) -> Array:
	var d := districts[i]
	var front := d.world(Vector3((b.x * PITCH + PITCH * 0.5) * TILE, 0, (b.y + 1) * PITCH * TILE))
	var best := Vector3i(i, b.x * PITCH, (b.y + 1) * PITCH)
	var other := Vector3i(i, (b.x + 1) * PITCH, (b.y + 1) * PITCH)
	return [front, best, other]


## The way along the streets (and over a bridge, if it must) from the front
## of one block to the front of another: the points to go through.
func route(from: Array, to: Array) -> Array[Vector3]:
	var a: Array = door(from[0], from[1])
	var b: Array = door(to[0], to[1])
	var starts := [a[1], a[2]].filter(func(k): return _nodes.has(k))
	var goals := [b[1], b[2]].filter(func(k): return _nodes.has(k))
	var out: Array[Vector3] = [a[0]]
	if starts.is_empty() or goals.is_empty():
		out.append(b[0])
		return out
	# Dijkstra, small enough to do by hand.
	var dist := {}
	var prev := {}
	var open := []
	for k in starts:
		dist[k] = (a[0] as Vector3).distance_to(_nodes[k])
		open.append(k)
	var reached = null
	while not open.is_empty():
		var best_i := 0
		for j in open.size():
			if dist[open[j]] < dist[open[best_i]]:
				best_i = j
		var k = open[best_i]
		open.remove_at(best_i)
		if k in goals:
			reached = k
			break
		for n in _links[k]:
			var nd: float = dist[k] + _links[k][n]
			if nd < dist.get(n, INF):
				dist[n] = nd
				prev[n] = k
				if not n in open:
					open.append(n)
	if reached == null:
		out.append(b[0])
		return out
	var path: Array[Vector3] = []
	var k = reached
	while k != null:
		path.push_front(_nodes[k])
		k = prev.get(k, null)
	out.append_array(path)
	out.append(b[0])
	return out


# --- Making -----------------------------------------------------------------------

## A building's own look: its wall and roof tints (a number each), whether
## its roof takes the tint (1 for houses), its windows' own luck.
func _own(roof: float) -> Color:
	return Color(_rng.randf(), _rng.randf(), roof, 1.0)


## How much to scale a model for it to be `across` wide at most.
func _fit(path: String, wide: float) -> float:
	var batch := _batch(path)
	var size: Vector3 = batch.size
	return wide / maxf(size.x, size.z)


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


func _box(parent: Node3D, s: Vector3, colour: Color, at: Vector3, turn := Basis.IDENTITY) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = s
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = MenuStage._material(colour)
	mi.transform = Transform3D(turn, at)
	parent.add_child(mi)
	return mi


## A box from a to b (their middles), w wide and h thick, tilted with the
## slope between them.
func _beam(parent: Node3D, a: Vector3, b: Vector3, w: float, h: float, colour: Color) -> MeshInstance3D:
	var along := b - a
	var basis := Basis.looking_at(along.normalized(), Vector3.UP)
	return _box(parent, Vector3(w, h, along.length()), colour, (a + b) * 0.5, basis)
