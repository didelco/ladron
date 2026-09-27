class_name LootModels
extends RefCounted
## The pieces to steal, modelled out of primitives, each with its own
## materials and a little character: the grandad's dentures with pink gums,
## the opera duck in a bow tie, the yeti's furry striped sock, the toast with
## the Barón's burnt moustache, the pickle queen's crown, the record ball
## of chewing gum, the cheese meteorite with holes and a whiff, the octopus
## wrestler's mask, the alarm clock that runs backwards, the dinosaur egg in
## its nest, a proper brilliant-cut diamond, the obsidian idol.
##
## About 0.35 units across, standing on its origin's floor (y 0 at the
## bottom, give or take), to sit in a case or turn on a stand. Everything
## glows a touch, so it reads in the dark museum.

## The shapes this builds; anything else gets the gem.
const SHAPES := ["teeth", "duck", "sock", "toast", "crown", "rock", "gum", "mask", "clock", "egg", "gem", "idol"]


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
		"gum": m._gum()
		"mask": m._mask()
		"clock": m._clock()
		"egg": m._egg()
		"idol": m._idol()
		_: m._gem()
	return root


## The thief's sack: whatever was stolen goes in it and out of sight, so it
## looks the same whatever the piece. Burlap, bulging at the bottom, its
## neck tied with a cord and a tuft sticking out, a patch sewn on the side.
## About 0.45 across, standing on its origin's floor.
static func sack() -> Node3D:
	var root := Node3D.new()
	var m := LootModels.new()
	m._root = root
	m._sack()
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


## A rubber duck mid-aria: a fat body rising to a tail, a tuft on its head,
## the beak wide open, eyes half shut with feeling, a bow tie at the throat
## and two notes floating off. It faces +X, turned three-quarters to the front.
func _duck() -> void:
	var yellow := _colour
	var orange := Color("#ff8c1a")
	var ink := Color("#1c1c24")
	var d := Node3D.new()
	d.rotation.y = -0.55
	_root.add_child(d)
	# The body: round at the chest, rising to a pointed tail at the back.
	_part(d, _sphere(0.13, 0.26), yellow, Vector3(-0.01, 0.1, 0), Vector3.ZERO, 0.3).scale = Vector3(1.25, 0.78, 1.0)
	_part(d, _sphere(0.1, 0.2), yellow, Vector3(0.06, 0.12, 0), Vector3.ZERO, 0.3)
	_part(d, _sphere(0.06, 0.12), yellow, Vector3(-0.15, 0.17, 0), Vector3(0, 0, -0.67), 0.3).scale = Vector3(1.6, 0.8, 0.7)
	for side in [-1, 1]:
		_part(d, _sphere(0.065, 0.13), yellow.darkened(0.07), Vector3(-0.04, 0.125, side * 0.1), Vector3(0, 0, -0.2), 0.3).scale = Vector3(1.4, 0.6, 0.3)
	# The neck, the head and the tuft on top.
	_part(d, _sphere(0.07, 0.14), yellow, Vector3(0.06, 0.2, 0), Vector3.ZERO, 0.3)
	var head := Vector3(0.07, 0.27, 0)
	_part(d, _sphere(0.085, 0.17), yellow, head, Vector3.ZERO, 0.3)
	for tuft in [[-0.01, 0.35, 0.028], [-0.03, 0.75, 0.022]]:
		_part(d, _cone(tuft[2], 0.07), yellow, head + Vector3(tuft[0], 0.095, 0), Vector3(0, 0, tuft[1]), 0.3).scale = Vector3(1, 1, 0.6)
	# The beak, open on a high note, and the mouth inside.
	_part(d, _sphere(0.03, 0.06), Color("#8a1c2b"), Vector3(0.135, 0.245, 0), Vector3.ZERO, 0.6)
	_part(d, _sphere(0.045, 0.09), orange, Vector3(0.155, 0.268, 0), Vector3(0, 0, 0.25), 0.35).scale = Vector3(1.5, 0.45, 1.05)
	_part(d, _sphere(0.04, 0.08), orange.darkened(0.08), Vector3(0.148, 0.222, 0), Vector3(0, 0, -0.35), 0.35).scale = Vector3(1.35, 0.4, 0.95)
	# The eyes, the lids half down: singing with feeling.
	for side in [-1, 1]:
		var dir := Vector3(0.55, 0.38, side * 0.72).normalized()
		_part(d, _sphere(0.024, 0.048), Color.WHITE, head + dir * 0.07, Vector3.ZERO, 0.2)
		_part(d, _sphere(0.012, 0.024), ink, head + dir * 0.089, Vector3.ZERO, 0.1)
		_part(d, _sphere(0.004, 0.008), Color.WHITE, head + dir * 0.098 + Vector3(0, 0.005, 0), Vector3.ZERO, 0.1, 1.0)
		_part(d, _sphere(0.027, 0.054), yellow.darkened(0.05), head + dir * 0.071 + Vector3(0, 0.013, 0), Vector3.ZERO, 0.3)
	# The bow tie: two wings pointing in to the knot.
	for side in [-1, 1]:
		_part(d, _cone(0.035, 0.06), ink, Vector3(0.14, 0.195, side * 0.032), Vector3(-side * PI / 2, 0, 0), 0.6).scale = Vector3(0.4, 1, 1)
	_part(d, _sphere(0.014, 0.028), ink, Vector3(0.145, 0.195, 0), Vector3.ZERO, 0.6)
	# Two notes floating off the beak.
	for note in [[Vector3(0.22, 0.34, 0.04), 1.0], [Vector3(0.27, 0.41, -0.03), 0.75]]:
		var at: Vector3 = note[0]
		var k: float = note[1]
		var gold := Color("#ffe8a3")
		_part(d, _sphere(0.017 * k, 0.026 * k), gold, at, Vector3(0, 0, 0.4), 0.3, 0.9).scale = Vector3(1.3, 1, 0.6)
		_part(d, _box(Vector3(0.005, 0.065, 0.005) * k), gold, at + Vector3(0.017, 0.032, 0) * k, Vector3.ZERO, 0.3, 0.9)
		_part(d, _box(Vector3(0.025, 0.006, 0.005) * k), gold, at + Vector3(0.028, 0.058, 0) * k, Vector3(0, 0, -0.5), 0.3, 0.9)


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


## The Pickle Queen's crown: an ermine rim, a gold band set with rubies and
## sapphires, diamond points with a pearl and a warty pickle on each, and red
## velvet under two gold arches, a gold orb and one more pickle on top.
func _crown() -> void:
	var gold := Color("#e8b54a")
	var pickle := _colour
	var ermine := Color("#f6f1e7")
	# The ermine: a fat white roll, black tail tips round it.
	_part(_root, _torus(0.12, 0.175), ermine, Vector3(0, 0.03, 0), Vector3.ZERO, 0.95, 0.15).scale = Vector3(1, 1.1, 1)
	for k in 10:
		var a := k * TAU / 10 + 0.3
		_part(_root, _capsule(0.007, 0.024), Color("#1c1c24"), Vector3(sin(a), 0, cos(a)) * 0.175 + Vector3(0, 0.035, 0), Vector3.ZERO, 0.8)
	# The band, a twisted rope along each edge, and the velvet inside.
	_part(_root, _cylinder(0.14, 0.14, 0.08), gold, Vector3(0, 0.09, 0), Vector3.ZERO, 0.3, 0.1, 0.4)
	for y in [0.052, 0.128]:
		_part(_root, _torus(0.134, 0.152), gold.darkened(0.12), Vector3(0, y, 0), Vector3.ZERO, 0.3, 0.1, 0.4).scale = Vector3(1, 0.7, 1)
	_part(_root, _sphere(0.132, 0.2), Color("#8e1b3a"), Vector3(0, 0.13, 0), Vector3.ZERO, 1.0, 0.12)
	# Two arches over the velvet, and on top an orb with the biggest pickle.
	for turn in [0.0, PI / 2]:
		var arch := _part(_root, _torus(0.128, 0.142), gold, Vector3(0, 0.13, 0), Vector3(PI / 2, turn, 0), 0.3, 0.1, 0.4)
		arch.scale = Vector3(1, 1, 0.7)
	_part(_root, _sphere(0.026, 0.052), gold, Vector3(0, 0.275, 0), Vector3.ZERO, 0.25, 0.15, 0.45)
	_pickle(_root, Vector3(0, 0.33, 0), Vector3(0, 0, 0.15), 1.1, pickle)
	# Round the band, each at its own angle, facing out: the points and the gems.
	for k in 5:
		var p := Node3D.new()
		p.rotation.y = k * TAU / 5
		_root.add_child(p)
		_part(p, _box(Vector3(0.075, 0.075, 0.014)), gold, Vector3(0, 0.14, 0.14), Vector3(0, 0, PI / 4), 0.3, 0.1, 0.4)
		_part(p, _sphere(0.014, 0.028), Color("#fbf6ea"), Vector3(0, 0.196, 0.14), Vector3.ZERO, 0.15, 0.3)
		_pickle(p, Vector3(0, 0.245, 0.145), Vector3(0.25, 0, 0), 1.0, pickle)
		var q := Node3D.new()
		q.rotation.y = (k + 0.5) * TAU / 5
		_root.add_child(q)
		_part(q, _box(Vector3(0.042, 0.042, 0.012)), gold, Vector3(0, 0.13, 0.14), Vector3(0, 0, PI / 4), 0.3, 0.1, 0.4)
		_part(q, _sphere(0.01, 0.02), Color("#fbf6ea"), Vector3(0, 0.163, 0.14), Vector3.ZERO, 0.15, 0.3)
		for g in [[p, Color("#c2185b")], [q, Color("#2f6fd6")]]:
			_part(g[0], _cylinder(0.024, 0.024, 0.01), gold.darkened(0.1), Vector3(0, 0.09, 0.141), Vector3(PI / 2, 0, 0), 0.3, 0.1, 0.4)
			_part(g[0], _facets(0.018), g[1], Vector3(0, 0.09, 0.148), Vector3(PI / 2, 0, 0), 0.08, 0.5, 0.2).scale = Vector3(1, 0.6, 1)


## A little pickle standing up: green, a touch bent, covered in warts.
func _pickle(parent: Node3D, at: Vector3, rot: Vector3, size: float, green: Color) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation = rot
	parent.add_child(holder)
	_part(holder, _capsule(0.02 * size, 0.075 * size), green, Vector3.ZERO, Vector3(0, 0, 0.12), 0.55, 0.2)
	for k in 5:
		var a := k * 2.4
		var y := lerpf(-0.022, 0.022, k / 4.0) * size
		_part(holder, _sphere(0.0045 * size, 0.009 * size), green.lightened(0.15), Vector3(cos(a) * 0.019 * size - y * 0.12, y, sin(a) * 0.019 * size), Vector3.ZERO, 0.6, 0.2)


## The record-breaking ball of chewing gum: every neighbour pressed a piece
## on for their birthday, so it is lumpy with wads of every colour (mostly
## strawberry), strings hanging off, a bubble half blown out of one side. It
## sits in a gold trophy cup on a wooden base with a plaque.
func _gum() -> void:
	var pink := _colour
	var gold := Color("#e8b54a")
	var wood := Color("#5a3a22")
	_part(_root, _cylinder(0.085, 0.1, 0.03), wood, Vector3(0, 0.015, 0), Vector3.ZERO, 0.5, 0.1)
	_part(_root, _box(Vector3(0.08, 0.018, 0.004)), gold, Vector3(0, 0.015, 0.093), Vector3(-0.59, 0, 0), 0.3, 0.3, 0.4)
	_part(_root, _cylinder(0.03, 0.045, 0.04), gold, Vector3(0, 0.05, 0), Vector3.ZERO, 0.3, 0.1, 0.4)
	_part(_root, _cylinder(0.08, 0.03, 0.04), gold, Vector3(0, 0.088, 0), Vector3.ZERO, 0.3, 0.1, 0.4)
	var c := Vector3(0, 0.21, 0)
	_part(_root, _sphere(0.12, 0.24), pink.darkened(0.1), c, Vector3.ZERO, 0.85)
	# The wads, spread evenly round the ball, each pressed flat against it.
	var shades := [pink, pink, pink, pink.lightened(0.18), pink.lightened(0.1), pink.darkened(0.1), pink.darkened(0.2),
		Color("#ffc2d4"), Color("#e64980"), Color("#8ce0bd"), Color("#a5d8ff")]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var n := 70
	for k in n:
		var y := 1.0 - 2.0 * (k + 0.5) / n
		var a := k * 2.39996
		var dir := Vector3(cos(a) * sqrt(1.0 - y * y), y, sin(a) * sqrt(1.0 - y * y))
		if dir.y < -0.75:
			continue
		var r := rng.randf_range(0.026, 0.04)
		var wad := _part(_root, _sphere(r, r * 0.8), shades[rng.randi() % shades.size()], c + dir * (0.118 + rng.randf() * 0.008), Vector3.ZERO, 0.85)
		wad.quaternion = Quaternion(Vector3.UP, dir) * Quaternion(Vector3.UP, rng.randf() * TAU)
		wad.scale = Vector3(rng.randf_range(1.0, 1.5), 1.0, rng.randf_range(0.7, 1.0))
	# Strings of gum hanging off, a drop at the end of each.
	for s in [[Vector3(0.1, 0.19, 0.07), 0.07], [Vector3(-0.11, 0.2, 0.05), 0.05], [Vector3(0.03, 0.17, 0.12), 0.06]]:
		var at: Vector3 = s[0]
		var h: float = s[1]
		_part(_root, _capsule(0.0035, h), pink.lightened(0.1), at - Vector3(0, h * 0.5, 0), Vector3.ZERO, 0.6)
		_part(_root, _sphere(0.007, 0.016), pink.lightened(0.1), at - Vector3(0, h, 0), Vector3.ZERO, 0.6)
	# The bubble, half blown.
	var out := Vector3(0.75, 0.35, 0.55).normalized()
	_part(_root, _sphere(0.02, 0.04), pink.darkened(0.1), c + out * 0.13, Vector3.ZERO, 0.4)
	_part(_root, _sphere(0.065, 0.13), Color(pink.lightened(0.25), 0.6), c + out * 0.19, Vector3.ZERO, 0.1, 0.4)
	_part(_root, _sphere(0.01, 0.02), Color.WHITE, c + out * 0.19 + Vector3(-0.025, 0.035, 0.03), Vector3.ZERO, 0.1, 1.2)


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


func _sack() -> void:
	var burlap := Color("#a8804f")
	var cord := Color("#5a3a22")
	# The bulk, full and heavy at the bottom.
	_part(_root, _sphere(0.22, 0.4), burlap, Vector3(0, 0.2, 0), Vector3.ZERO, 0.95, 0.08).scale = Vector3(1.0, 1.0, 0.85)
	# Tapering to the neck, tied, and the tuft over the knot.
	_part(_root, _cylinder(0.06, 0.15, 0.14), burlap, Vector3(0, 0.42, 0), Vector3.ZERO, 0.95, 0.08)
	_part(_root, _torus(0.05, 0.08), cord, Vector3(0, 0.47, 0), Vector3.ZERO, 0.9, 0.05)
	_part(_root, _cylinder(0.1, 0.05, 0.08), burlap.lightened(0.08), Vector3(0, 0.53, 0), Vector3.ZERO, 0.95, 0.08)
	# A patch sewn on the side facing out, and a dollar sign on it.
	_part(_root, _box(Vector3(0.12, 0.12, 0.02)), burlap.darkened(0.25), Vector3(0.0, 0.2, 0.18), Vector3(0, 0, 0.15), 0.95, 0.06)
	_part(_root, _box(Vector3(0.018, 0.1, 0.012)), Color("#f4ecd8"), Vector3(0.0, 0.2, 0.195), Vector3.ZERO, 0.8, 0.4)
	_part(_root, _torus(0.02, 0.035), Color("#f4ecd8"), Vector3(0.0, 0.2, 0.195), Vector3(PI / 2, 0, 0), 0.8, 0.4).scale = Vector3(1, 1, 1.4)


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


## A cut stone: a sphere with few sides, so it catches the light in facets.
func _facets(r: float) -> SphereMesh:
	var s := _sphere(r, r * 2.0)
	s.radial_segments = 8
	s.rings = 4
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
