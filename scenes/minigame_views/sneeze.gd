extends MinigameView
## The sneeze (SneezeGame): in the dark of the hideout, a lane of dust
## running to a big nose; the bar glows across it in the thief's colours,
## and fluffs of dust drift along it. Three pips over the lane light up red
## with each press out of time, and the nose reddens and twitches as the
## sneeze comes.

const LANE := 0.5
const DARK := Color("#141020")
const DUST := Color("#f3e3cf")
const NOSE := Color("#e9a27c")
## As many fluffs as there can be on the lane at once.
const FLUFFS := 6

var _bar: MeshInstance3D
var _bar_mat: StandardMaterial3D
var _fluffs: Array[MeshInstance3D] = []
var _nose: Node3D
var _nose_mat: StandardMaterial3D
var _pips: Array[MeshInstance3D] = []
var _pip_dim: StandardMaterial3D
var _pip_lit: StandardMaterial3D


func framing() -> Dictionary:
	return {"span": 1.25, "look": 0.04, "angle": Vector3(-8, 10, 0)}


func build() -> void:
	# The dark inside, and the lane along it.
	box(Vector3(1.6, 0.9, 0.06), DARK, Vector3(0.08, 0.04, -0.1))
	box(Vector3(2.0 * LANE + 0.1, 0.14, 0.03), Color("#3a2f4e"), Vector3(0, 0, -0.04))
	_bar_mat = glowing(colour, 0.9)
	_bar = box(Vector3(0.1, 0.2, 0.02), colour, Vector3(SneezeGame.BAR_X * LANE, 0, -0.01))
	_bar.material_override = _bar_mat
	for i in FLUFFS:
		var f := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.045
		s.height = 0.09
		f.mesh = s
		f.material_override = glowing(DUST, 0.5)
		add_child(f)
		_fluffs.append(f)
	# The nose, at the end of the lane: a big round tip and two nostrils.
	_nose = Node3D.new()
	_nose.position = Vector3(LANE + 0.1, 0, 0.02)
	add_child(_nose)
	_nose_mat = MenuStage._material(NOSE).duplicate() as StandardMaterial3D
	var tip := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.13
	ball.height = 0.26
	tip.mesh = ball
	tip.material_override = _nose_mat
	_nose.add_child(tip)
	for y in [0.05, -0.05]:
		var hole := MeshInstance3D.new()
		var h := SphereMesh.new()
		h.radius = 0.028
		h.height = 0.056
		hole.mesh = h
		hole.material_override = MenuStage._material(INK)
		hole.position = Vector3(-0.1, y, 0.04)
		_nose.add_child(hole)
	# The misses, over the lane.
	_pip_dim = MenuStage._material(INK.lightened(0.2))
	_pip_lit = glowing(RED, 2.0)
	for i in SneezeGame.MISSES:
		var pip := box(Vector3(0.06, 0.06, 0.02), INK, Vector3((i - 1) * 0.1, 0.33, 0.0))
		_pips.append(pip)


func pose(_dt: float) -> void:
	var g := game as SneezeGame
	_bar.scale.x = g.bar() * 2.0 * LANE / 0.1
	_bar_mat.emission_energy_multiplier = 0.9 + 2.0 * good
	for i in _fluffs.size():
		var f := _fluffs[i]
		f.visible = i < g.tickles.size()
		if f.visible:
			var x: float = g.tickles[i]
			f.position = Vector3(x * LANE, 0.015 * sin(t * 7.0 + i * 2.1), 0.03)
			f.rotation.z = t * 3.0 + i
	for i in _pips.size():
		_pips[i].material_override = _pip_lit if i < g.misses else _pip_dim
	# The nose reddens with each miss and twitches as a fluff comes close.
	var close := 0.0
	if not g.tickles.is_empty():
		close = clampf(1.0 - absf(g.tickles[0] - SneezeGame.BAR_X - g.bar()) / 0.5, 0.0, 1.0)
	var worry := clampf(float(g.misses) / SneezeGame.MISSES + bad * 0.5, 0.0, 1.0)
	_nose_mat.albedo_color = NOSE.lerp(RED, worry * 0.7)
	_nose.scale = Vector3.ONE * (1.0 + 0.06 * close * sin(t * 40.0) + 0.05 * worry)
