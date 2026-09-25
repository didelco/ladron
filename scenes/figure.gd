class_name Figure
extends Node3D
## A figure: thief or attendant, built from the same skeleton. Port of the web
## version's Figure.
##
## Everything serves one question the player asks sixty times a second from a
## camera pitched almost straight down: which way is that one facing? Hence
## the wide shoulder line, the peak of a cap, the pale eyes in a dark mask and
## the hood's tail pointing back. Proportions lean chibi: the head is what the
## camera sees most of.
##
## Limbs pivot at hip and shoulder (no knees), the body leans into speed and
## breathes when still, and a thief gets down on all fours and up again in
## stages, from key poses. This node is all the rest of the game knows of a
## character: set_state() each frame. A rigged model can replace it later.
##
## Drawing: toon shading, an ink outline from an inflated inside-out copy of
## each part (the material's next pass), and Godot's stencil x-ray: where
## something covers the figure it shows through as a flat silhouette in its
## state colour — but never over itself, so an arm across the chest does not.

const SKIN := Color("#e2c6a2")
const SKIN_SHADE := Color("#b98d6a")
const TROUSER := Color("#242a38")
const BOOT := Color("#14171e")
const SOLE := Color("#cfd3dc")
const EYE := Color("#f6f3ff")
const GOLD := Color("#f0c46a")
const MINERAL := Color("#7ad6ff")
const CONE := Color("#ffd479")
const INK := Color("#08070c")

const NECK := 0.84
const HIP := 0.4
const TORSO := 0.42
const CRAWL_STRIDE := 0.35
## How far out the ink outline sits from each part, in metres.
const INK_GROW := 0.012
## Rim light on every shaded part: how strong, and how much of the part's own
## colour it takes (0 white, 1 fully tinted).
const RIM := 1.0
const RIM_TINT := 0.2

## Getting down on all fours, and back up, as key poses: down is squat with
## hands out, tip forward and plant, knees down and settle; up is push off and
## rock back, lift the hands and straighten, stand up out of the squat.
## Columns: torso pivot height, forward pitch, legs' angle (+ is back) and
## length, arms' angle in the world (0 hangs straight down), head nod.
const GET_DOWN := [
	{"at": 0.0, "hips": 0.42, "pitch": 0.0, "leg": 0.0, "leg_len": 1.0, "arm": 0.0, "head": 0.0},
	{"at": 0.3, "hips": 0.3, "pitch": 0.35, "leg": -0.18, "leg_len": 0.76, "arm": -0.95, "head": -0.1},
	{"at": 0.6, "hips": 0.3, "pitch": 1.12, "leg": 0.15, "leg_len": 0.72, "arm": -0.4, "head": -0.35},
	{"at": 0.85, "hips": 0.245, "pitch": 1.42, "leg": 0.8, "leg_len": 0.7, "arm": 0.04, "head": -0.22},
	{"at": 1.0, "hips": 0.26, "pitch": 1.35, "leg": 0.75, "leg_len": 0.7, "arm": 0.0, "head": -0.15},
]
const GET_UP := [
	{"at": 0.0, "hips": 0.26, "pitch": 1.35, "leg": 0.75, "leg_len": 0.7, "arm": 0.0, "head": -0.15},
	{"at": 0.3, "hips": 0.28, "pitch": 1.3, "leg": 0.05, "leg_len": 0.74, "arm": 0.12, "head": -0.2},
	{"at": 0.58, "hips": 0.32, "pitch": 0.6, "leg": -0.15, "leg_len": 0.76, "arm": 0.2, "head": -0.05},
	{"at": 0.82, "hips": 0.37, "pitch": 0.15, "leg": -0.08, "leg_len": 0.88, "arm": 0.06, "head": 0.0},
	{"at": 1.0, "hips": 0.42, "pitch": 0.0, "leg": 0.0, "leg_len": 1.0, "arm": 0.0, "head": 0.0},
]

var guard := false
var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _ghost_colour := Color.WHITE
var _materials := {}

var _phase := 0.0
var _last_pos := Vector3.INF
var _speed := 0.0
var _posture := 0.0
var _rising := false
var _clock := 0.0


static func make(kind: String, colour: Color, accent: Color) -> Figure:
	var f := Figure.new()
	f.guard = kind == "guard"
	f._build(colour, accent)
	return f


## Colour of the silhouette seen through whatever covers the figure, and how
## strongly (0..1: darker is fainter).
func set_ghost(colour: Color, strength: float) -> void:
	var c := colour * strength
	c.a = 1.0
	if c.is_equal_approx(_ghost_colour):
		return
	_ghost_colour = c
	for m in _materials.values():
		if (m as StandardMaterial3D).stencil_mode == BaseMaterial3D.STENCIL_MODE_XRAY:
			m.stencil_color = c


## Place and pose the figure for this frame. dir is the grid heading (radians
## from +x); posture 0 standing, 1 on all fours.
func set_state(pos: Vector3, dir: float, posture: float, dt: float) -> void:
	position = pos
	rotation.y = -dir + PI / 2
	# The stride turns over with distance walked: 5.5 rad per tile, faster
	# (shorter steps) on all fours.
	if _last_pos != Vector3.INF:
		_phase += Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() * (5.5 + posture * 6.0)
	_last_pos = pos
	_animate(posture, dt)


# --- Building -------------------------------------------------------------------

func _build(colour: Color, accent: Color) -> void:
	_ghost_colour = colour * 0.75
	_ghost_colour.a = 1.0

	_body = Node3D.new()
	add_child(_body)

	# Legs: hip-pivoted, trouser, boot and a pale sole as one limb.
	for side in [-1, 1]:
		var leg := _pivot(_body, Vector3(side * 0.1, HIP, 0))
		_legs.append(leg)
		_part(leg, _capsule(0.07, 0.2), TROUSER, Vector3(0, -0.19, 0))
		_part(leg, _sphere(0.085), BOOT, Vector3(0, -0.36, 0.03), Vector3(1, 0.8, 1.35))
		_part(leg, _box(0.13, 0.025, 0.22), SOLE, Vector3(0, -0.395, 0.035), Vector3.ONE, Vector3.ZERO, true)

	_torso = _pivot(_body, Vector3(0, TORSO, 0))
	var t := _pivot(_torso, Vector3(0, -TORSO, 0))
	# Hips and the coat that tells the two sides apart.
	_part(t, _sphere(0.16), TROUSER, Vector3(0, 0.43, 0), Vector3(1, 1, 0.8))
	_part(t, _capsule(0.19, 0.16), colour, Vector3(0, 0.6, 0), Vector3(1, 1, 0.78))
	# Belt, with a buckle.
	_part(t, _cylinder(0.19, 0.19, 0.06), BOOT, Vector3(0, 0.49, 0), Vector3(1, 1, 0.8))
	_part(t, _box(0.07, 0.05, 0.02), GOLD, Vector3(0, 0.49, 0.155), Vector3.ONE, Vector3.ZERO, true)

	if guard:
		# Tunic front: placket, brass buttons, a dark tie under the collar.
		_part(t, _box(0.035, 0.22, 0.012), accent, Vector3(0, 0.6, 0.148), Vector3.ONE, Vector3.ZERO, true)
		for y in [0.66, 0.59, 0.53]:
			_part(t, _sphere(0.017), GOLD, Vector3(0.035, y, 0.15), Vector3.ONE, Vector3.ZERO, true)
		_part(t, _box(0.05, 0.1, 0.02), BOOT, Vector3(0, 0.7, 0.14), Vector3.ONE, Vector3(0.25, 0, 0), true)
		# Chest badge, and the radio on the belt with its aerial.
		_part(t, _cylinder(0.03, 0.03, 0.012, 6), GOLD, Vector3(-0.09, 0.66, 0.135), Vector3.ONE, Vector3(PI / 2, -0.3, 0), true)
		_part(t, _box(0.06, 0.1, 0.07), BOOT, Vector3(-0.17, 0.5, -0.03))
		_part(t, _cylinder(0.008, 0.008, 0.08, 4), BOOT, Vector3(-0.17, 0.58, -0.05), Vector3.ONE, Vector3.ZERO, true)
	else:
		# Harness: two narrow straps over a dark jumper.
		for side in [-1, 1]:
			_part(t, _box(0.055, 0.27, 0.035), accent, Vector3(side * 0.08, 0.61, 0.135), Vector3.ONE, Vector3(0, 0, side * 0.14), true)
		# The swag bag slung behind, with the loot showing at the mouth.
		_part(t, _sphere(0.15), accent, Vector3(0, 0.6, -0.19), Vector3(1.05, 1.1, 0.75))
		_part(t, _torus(0.055, 0.018), BOOT, Vector3(0, 0.74, -0.2))
		_part(t, _cylinder(0.04, 0.04, 0.012), GOLD, Vector3(0.02, 0.78, -0.21), Vector3.ONE, Vector3(0.4, 0.3, 0), true)
		_part(t, _gem(0.03), MINERAL, Vector3(-0.03, 0.775, -0.18), Vector3.ONE, Vector3.ZERO, true, true)

	# The shoulder line: the strongest direction cue from overhead.
	_part(t, _capsule(0.1, 0.3), accent, Vector3(0, 0.72, 0), Vector3(0.42, 1, 0.62), Vector3(0, 0, PI / 2))
	if guard:
		for side in [-1, 1]:
			_part(t, _box(0.09, 0.02, 0.1), GOLD, Vector3(side * 0.2, 0.765, 0), Vector3.ONE, Vector3.ZERO, true)

	# Arms, shoulder-pivoted, with a hand each. Thieves wear dark gloves.
	for side in [-1, 1]:
		var arm := _pivot(t, Vector3(side * 0.25, 0.72, 0))
		_arms.append(arm)
		_part(arm, _capsule(0.055, 0.15), colour, Vector3(0, -0.12, 0))
		_part(arm, _cylinder(0.058, 0.058, 0.03), accent, Vector3(0, -0.2, 0), Vector3.ONE, Vector3.ZERO, true)
		_part(arm, _sphere(0.06), SKIN if guard else BOOT, Vector3(0, -0.25, 0))
		# The torch in the attendant's right hand, its lens lit.
		if guard and side > 0:
			var torch := _pivot(arm, Vector3(0, -0.26, 0.06))
			torch.rotation.x = PI / 2 + 0.55
			_part(torch, _cylinder(0.032, 0.032, 0.16), BOOT, Vector3(0, 0.02, 0))
			_part(torch, _cylinder(0.05, 0.036, 0.06), GOLD, Vector3(0, 0.12, 0))
			_part(torch, _cylinder(0.042, 0.042, 0.01), CONE, Vector3(0, 0.152, 0), Vector3.ONE, Vector3.ZERO, true, true)

	_part(t, _cylinder(0.065, 0.075, 0.07), SKIN_SHADE if guard else accent, Vector3(0, 0.8, 0))

	# Head: its own pivot at the neck.
	_head = _pivot(_body, Vector3(0, NECK, 0))
	_part(_head, _sphere(0.165), SKIN, Vector3(0, 0.12, 0.01), Vector3(1, 1.02, 1))
	# Eyes: two bright dots say "this way" from above.
	for side in [-1, 1]:
		var eye := _pivot(_head, Vector3(side * 0.058, 0.13, 0.158 if guard else 0.196))
		_part(eye, _sphere(0.028), EYE, Vector3.ZERO, Vector3(1, 1.2, 0.6), Vector3.ZERO, true)
		_part(eye, _sphere(0.015), BOOT, Vector3(0, -0.002, 0.014), Vector3.ONE, Vector3.ZERO, true)
	_part(_head, _sphere(0.022), SKIN_SHADE, Vector3(0, 0.09, 0.165), Vector3.ONE, Vector3.ZERO, true)

	if guard:
		# Moustache, ears, and a peaked cap whose peak points where it looks.
		_part(_head, _capsule(0.022, 0.07), Color("#3a2a22"), Vector3(0, 0.06, 0.155), Vector3(1, 0.45, 0.5), Vector3(0, 0, PI / 2), true)
		for side in [-1, 1]:
			_part(_head, _sphere(0.04), SKIN, Vector3(side * 0.16, 0.11, 0), Vector3(0.5, 1, 0.8))
		_part(_head, _cylinder(0.17, 0.175, 0.08), accent, Vector3(0, 0.235, 0))
		_part(_head, _cylinder(0.177, 0.177, 0.02), BOOT, Vector3(0, 0.205, 0), Vector3.ONE, Vector3.ZERO, true)
		_part(_head, _cylinder(0.2, 0.18, 0.12), accent, Vector3(0, 0.3, -0.01), Vector3(1, 0.3, 1))
		_part(_head, _cylinder(0.13, 0.13, 0.025), BOOT, Vector3(0, 0.2, 0.1), Vector3(1, 1, 0.55), Vector3(-0.3, 0, 0))
		_part(_head, _box(0.06, 0.05, 0.02), GOLD, Vector3(0, 0.25, 0.172), Vector3.ONE, Vector3.ZERO, true)
	else:
		# Hood round the back of the head, with a tail pointing back.
		_part(_head, _hemisphere(0.18), accent, Vector3(0, 0.13, -0.035), Vector3(1.08, 1.06, 1.08))
		_part(_head, _sphere(0.165), accent, Vector3(0, 0.1, -0.07))
		_part(_head, _cylinder(0.0, 0.07, 0.16), accent, Vector3(0, 0.19, -0.2), Vector3.ONE, Vector3(-1.9, 0, 0))
		# Mask across the eyes, and a scarf over the chin.
		_part(_head, _sphere(0.165), BOOT, Vector3(0, 0.13, 0.105), Vector3(1, 0.34, 0.62))
		_part(_head, _sphere(0.16), colour, Vector3(0, 0.02, 0.03), Vector3(1, 0.55, 1))
		_part(_head, _box(0.06, 0.16, 0.025), colour, Vector3(0.06, -0.04, -0.15), Vector3.ONE, Vector3(0.5, 0, 0.2))


func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


## One piece. detail parts (eyes, buttons, badges) get no outline — a ring of
## ink round a bead is just a bigger black bead — and no ghost; glow parts
## ignore the lighting.
func _part(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, scale_by := Vector3.ONE, rot := Vector3.ZERO, detail := false, glow := false) -> void:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	m.scale = scale_by
	m.rotation = rot
	m.material_override = _material(colour, detail, glow)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if detail else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(m)


func _material(colour: Color, detail: bool, glow: bool) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [colour.to_html(), detail, glow]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		# Light either hits a surface or it does not: drawn, not rendered.
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		# A rim of whatever light is about (the moon, a torch, a lamp) round
		# the silhouette, tinted by the body colour: the figures pop off the
		# dark floor the way cartoon characters do.
		m.rim_enabled = true
		m.rim = RIM
		m.rim_tint = RIM_TINT
	if not detail:
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = INK
		ink.cull_mode = BaseMaterial3D.CULL_FRONT
		ink.grow = true
		ink.grow_amount = INK_GROW
		m.next_pass = ink
	# Every part is in on the x-ray, details included: a part left out counts
	# as something covering the figure, and the silhouette colour showed
	# through the eyes and the buttons.
	m.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
	m.stencil_color = _ghost_colour
	_materials[key] = m
	return m


# three.js sizes: a capsule's length is its straight part, Godot's height is all of it.
func _capsule(r: float, length: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = length + 2 * r
	c.radial_segments = 12
	c.rings = 4
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = 2 * r
	s.radial_segments = 16
	s.rings = 10
	return s


func _hemisphere(r: float) -> SphereMesh:
	var s := _sphere(r)
	s.is_hemisphere = true
	s.height = r
	return s


func _gem(r: float) -> SphereMesh:
	var s := _sphere(r)
	s.radial_segments = 4
	s.rings = 2
	return s


func _cylinder(top: float, bottom: float, h: float, segments := 14) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _torus(r: float, tube: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = 12
	t.ring_segments = 6
	return t


# --- Animating ---------------------------------------------------------------------

func _animate(u: float, dt: float) -> void:
	_clock += dt
	# How fast the stride is turning over, smoothed: drives the lean and fades
	# the breathing in and out. ~24 rad/s of phase is a flat-out sprint.
	var raw := 0.0
	if dt > 0:
		raw = absf(_phase - get_meta("last_phase", _phase)) / dt
	set_meta("last_phase", _phase)
	_speed += (minf(raw / 24.0, 1.0) - _speed) * minf(dt * 8, 1.0)
	var run := _speed
	var idle := 1.0 - minf(run * 3, 1.0)

	# Which way the posture is moving picks the move: getting up is not
	# getting down played backwards.
	if u > _posture + 1e-4:
		_rising = false
	elif u < _posture - 1e-4:
		_rising = true
	_posture = u
	var pose := _sample(GET_UP, 1.0 - u) if _rising else _sample(GET_DOWN, u)
	var c := minf(1.0, u * 4)
	var down := 0.0 if u < 0.9 else (u - 0.9) / 0.1
	var pitch: float = pose.pitch
	var hips: float = pose.hips

	var swing := sin(_phase)
	var stride := 0.35 + run * 0.35
	# Crawling is a trot: left hand with right knee.
	var crawl := CRAWL_STRIDE * swing * down
	for i in 2:
		var sgn := -1.0 if i == 0 else 1.0
		var upright := sgn * swing * stride
		_legs[i].rotation.x = upright * (1 - c) + (pose.leg + sgn * crawl) * c
		_legs[i].position.y = HIP + (hips - TORSO)
		_legs[i].scale.y = pose.leg_len
	# Arms counter the legs; the torch arm holds its beam steady.
	var arm := 0.28 + run * 0.4
	var up_l := swing * arm
	_arms[0].rotation.x = up_l * (1 - c) + (pose.arm - pitch - crawl) * c
	_arms[0].rotation.z = (-0.08 - run * 0.1) * (1 - c) - c * 0.05
	var up_r := (-0.55 + swing * 0.08) if guard else -swing * arm
	_arms[1].rotation.x = up_r * (1 - c) + (pose.arm - pitch + crawl) * c
	_arms[1].rotation.z = (0.08 + run * 0.1) * (1 - c) + c * 0.05

	var breath := sin(_clock * 2.1) * idle
	# Bob twice per stride; lean into the run (not on all fours).
	_body.position.y = absf(swing) * (0.035 if guard else 0.025) * (0.4 + run) * (1 - c * 0.6)
	_body.rotation.x = run * (0.12 if guard else 0.22) * (1 - c)
	_torso.position.y = hips
	_torso.rotation = Vector3(pitch, swing * 0.07 * run * (1 - c), crawl * 0.25 * c)
	_torso.scale = Vector3(1 + breath * 0.012, 1 + breath * 0.02, 1 + breath * 0.012)
	# The head rides on the end of the pitched torso and stays level.
	var neck := NECK - TORSO
	_head.rotation.x = -run * (0.1 if guard else 0.18) * (1 - c) + breath * 0.02 + pose.head
	_head.position.y = hips + neck * cos(pitch) + breath * 0.006 + (1 - cos(pitch)) * 0.05
	_head.position.z = neck * sin(pitch)


## A pose partway through a move: Catmull-Rom through the keys, so the body
## flows through each pose instead of stopping on it.
static func _sample(keys: Array, u: float) -> Dictionary:
	var t := clampf(u, 0.0, 1.0)
	var i := 0
	while i < keys.size() - 2 and t > keys[i + 1].at:
		i += 1
	var a: Dictionary = keys[maxi(0, i - 1)]
	var b: Dictionary = keys[i]
	var c: Dictionary = keys[i + 1]
	var d: Dictionary = keys[mini(keys.size() - 1, i + 2)]
	var span: float = c.at - b.at
	var k: float = (t - b.at) / (span if span != 0 else 1.0)
	var k2 := k * k
	var k3 := k2 * k
	var out := {"at": t}
	for key in ["hips", "pitch", "leg", "leg_len", "arm", "head"]:
		var p0: float = a[key]
		var p1: float = b[key]
		var p2: float = c[key]
		var p3: float = d[key]
		out[key] = 0.5 * (2 * p1 + (-p0 + p2) * k + (2 * p0 - 5 * p1 + 4 * p2 - p3) * k2 + (-p0 + 3 * p1 - 3 * p2 + p3) * k3)
	return out
