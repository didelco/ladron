extends MinigameView
## Getting into a hideout (SqueezeGame): the thief, in its colours, in a
## walnut chest with a brass rim, curling up a little more with each
## wriggle until it is under the rim, swaying to the side it wriggled; an arrow
## each side, the one for the next wriggle lit gold once the body has
## settled. Stuck, the chest shudders; in, the lid comes down.

## How far it sways each way (in Figure.set_lean's units, short of the
## sweat); it sinks by curling up, feet on the chest's floor.
const SWAY := 0.45
## The thief's size in the chest (the figure is life size: too big for it).
const FIGURE := 0.6

var _thief: Figure
var _arrows: Array[Node3D] = []
var _lit: StandardMaterial3D
var _dim: StandardMaterial3D
var _lid: Node3D
var _chest: Node3D
var _lean := 0.0


func framing() -> Dictionary:
	return {"span": 1.5, "look": 0.45, "angle": Vector3(-18, 12, 0)}


func build() -> void:
	# The chest: walnut walls round an open top, a brass rim, dark inside.
	_chest = Node3D.new()
	add_child(_chest)
	var parts := [
		[Vector3(1.0, 0.06, 0.7), WOOD, Vector3(0, 0.03, 0)],
		[Vector3(1.0, 0.56, 0.06), WOOD, Vector3(0, 0.31, -0.32)],
		[Vector3(0.06, 0.56, 0.7), WOOD, Vector3(-0.47, 0.31, 0)],
		[Vector3(0.06, 0.56, 0.7), WOOD, Vector3(0.47, 0.31, 0)],
		[Vector3(1.0, 0.56, 0.06), WOOD, Vector3(0, 0.31, 0.32)],
		[Vector3(1.06, 0.05, 0.08), GOLD, Vector3(0, 0.6, 0.33)],
		[Vector3(1.06, 0.05, 0.08), GOLD, Vector3(0, 0.6, -0.33)],
		[Vector3(0.08, 0.05, 0.7), GOLD, Vector3(-0.49, 0.6, 0)],
		[Vector3(0.08, 0.05, 0.7), GOLD, Vector3(0.49, 0.6, 0)],
	]
	for p in parts:
		var b := box(p[0], p[1], p[2])
		remove_child(b)
		_chest.add_child(b)
	_thief = Figure.make("thief", colour, colour.darkened(0.5))
	_thief.set_rim(0.2)
	_thief.scale = Vector3.ONE * FIGURE
	# Seen faintly through the chest's front, as the museum shows a figure
	# behind something.
	_thief.set_ghost(colour, 0.45)
	add_child(_thief)
	# The lid, hinged along the back, standing open until the thief is in.
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.62, -0.35)
	_lid.rotation.x = -1.9
	add_child(_lid)
	var lid := box(Vector3(1.06, 0.06, 0.74), WOOD.lightened(0.08), Vector3(0, 0.03, 0.37))
	remove_child(lid)
	_lid.add_child(lid)
	# An arrow each side, pointing out: left and right.
	_lit = glowing(GOLD, 2.5)
	_dim = MenuStage._material(GOLD.darkened(0.55))
	for s in [-1, 1]:
		var a := arrow(GOLD)
		a.position = Vector3(s * 0.78, 0.5, 0.2)
		a.rotation.z = -s * PI * 0.5
		_arrows.append(a)


func pose(dt: float) -> void:
	var g := game as SqueezeGame
	var p := g.progress()
	# Each wriggle sways it to that side, easing back towards upright.
	var want := 0.0
	if g.step > 0 and not g.done:
		want = SWAY if g.side == SqueezeGame.LEFT else -SWAY
	_lean = lerpf(_lean, want * (1.0 - clampf(g.settle / SqueezeGame.SETTLE_S, 0.0, 1.0) * 0.3), minf(1.0, dt * 10.0))
	_thief.set_state(Vector3(0, 0.06, 0), PI / 2, p, dt)
	_thief.set_lean(_lean)
	# Stuck: the chest shudders.
	_chest.position.x = 0.02 * bad * sin(t * 60.0)
	# The lid: open, then down once it is done.
	var shut := -1.9 if not g.done else 0.0
	_lid.rotation.x = lerpf(_lid.rotation.x, shut, minf(1.0, dt * 12.0))
	# The arrows: the next side lit once the body has settled.
	for i in _arrows.size():
		var dir := SqueezeGame.LEFT if i == 0 else SqueezeGame.RIGHT
		var on := g.ready() and (g.side < 0 or g.side == dir)
		_arrows[i].visible = not g.done
		for m in _arrows[i].get_children():
			(m as MeshInstance3D).material_override = _lit if on else _dim
		_arrows[i].scale = Vector3.ONE * (1.0 + (0.12 * sin(t * 9.0) if on else 0.0))
