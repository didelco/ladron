extends MinigameView
## The suction cup (SteadyGame): the glass in a brass frame, a ring drawn on
## it (smaller the harder the level) and a flat rubber suction cup drifting
## about, its rim glowing green while it is in and red out; a row of lamps
## along the top lights up as the seconds go by.

## The ring's radius on the glass: the game's ring is 1.
const RING := 0.4

var _ring: Node3D
## the ring's glow: cream, or orange and red as the alarm counts the slips
## (Minigame.hook_colour)
var _ring_mat: StandardMaterial3D
var _cup: Node3D
var _cup_mat: StandardMaterial3D
var _lamps: Array[MeshInstance3D] = []
var _lamp_dim: StandardMaterial3D
var _lamp_lit: StandardMaterial3D


func framing() -> Dictionary:
	return {"span": 1.35, "look": 0.0, "angle": Vector3(-12, 14, 0)}


func build() -> void:
	var steps := game.steps
	# The pane in a brass frame, the case's pale blue, see-through.
	box(Vector3(1.62, 1.12, 0.06), GOLD, Vector3(0, 0, -0.08))
	# Dark behind, so the glass reads as glass: a sheen, not a board.
	box(Vector3(1.5, 1.0, 0.02), INK, Vector3(0, 0, -0.035))
	var pane := box(Vector3(1.5, 1.0, 0.04), Color("#bfe6f5", 0.22), Vector3(0, 0, 0.0))
	pane.material_override = glowing(Color("#bfe6f5", 0.22), 0.25)
	pane.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A streak of light across it.
	var streak := box(Vector3(0.08, 1.1, 0.01), Color(1, 1, 1, 0.12), Vector3(-0.45, 0, 0.02))
	streak.rotation_degrees.z = -30
	streak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The ring scored on the glass, sized to the level each frame.
	_ring = Node3D.new()
	_ring.position.z = 0.03
	add_child(_ring)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING - 0.012
	torus.outer_radius = RING + 0.012
	torus.rings = 48
	ring.mesh = torus
	_ring_mat = glowing(CREAM, 0.8)
	ring.material_override = _ring_mat
	ring.rotation_degrees.x = 90
	_ring.add_child(ring)
	# The suction cup: a flat disc of pale rubber on the glass, its rim
	# lit green or red, a little brass handle to hold it by.
	_cup = Node3D.new()
	add_child(_cup)
	var r := SteadyGame.CUP * RING
	var disc := MeshInstance3D.new()
	disc.mesh = cylinder_mesh(r, 0.025)
	disc.material_override = MenuStage._material(Color(CREAM, 0.55))
	disc.rotation_degrees.x = 90
	_cup.add_child(disc)
	_cup_mat = glowing(GREEN, 1.6)
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
	stem.mesh = cylinder_mesh(0.018, 0.08)
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
	_lamp_lit = glowing(GREEN, 1.8)
	for i in steps:
		var lamp := MeshInstance3D.new()
		var b := SphereMesh.new()
		b.radius = 0.04
		b.height = 0.08
		lamp.mesh = b
		lamp.position = Vector3((i - (steps - 1) * 0.5) * 0.13, 0.52, 0.02)
		add_child(lamp)
		_lamps.append(lamp)


func pose(_dt: float) -> void:
	var g := game as SteadyGame
	_ring.scale = Vector3.ONE * g.ring()
	# The ring: cream while the lamp being lit is clean, orange after a slip,
	# red (blinking) after two — the alarm has gone off.
	var hook := g.hook_colour()
	var ring_c: Color = CREAM if hook == 0 else HOOK_COLOURS[hook]
	if hook == 2 and fmod(t, 0.4) < 0.15:
		ring_c = INK
	_ring_mat.albedo_color = ring_c
	_ring_mat.emission = ring_c
	_ring_mat.emission_energy_multiplier = 0.8 if hook == 0 else 2.0
	_cup.position = Vector3(g.cup.x * RING, -g.cup.y * RING, 0.04)
	var c := GREEN if g.inside() else RED
	_cup_mat.albedo_color = c
	_cup_mat.emission = c
	for i in _lamps.size():
		_lamps[i].material_override = _lamp_lit if i < g.step else _lamp_dim
