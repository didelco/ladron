extends MinigameView
## Getting into a hideout (SqueezeGame): the thief, in its colours, in a
## walnut chest with a brass rim, curling up as it sinks after each shove
## until it is under the rim; a gold arrow over it, lit when a shove would
## count, and a red bar across the front while someone looks (a shove then
## sinks slowly). In, the lid comes down.

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
var _eye: MeshInstance3D


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
	# One arrow, pointing down into the chest (the shove), and a red bar
	# across the front while a guard looks (or the lantern is on it).
	_lit = glowing(GOLD, 2.5)
	_dim = MenuStage._material(GOLD.darkened(0.55))
	var a := arrow(GOLD)
	a.position = Vector3(0, 1.05, 0.2)
	a.rotation.z = PI
	_arrows.append(a)
	_eye = box(Vector3(1.2, 0.05, 0.05), RED, Vector3(0, 0.66, 0.4))
	_eye.material_override = glowing(RED, 3.0)


func pose(dt: float) -> void:
	var g := game as SqueezeGame
	# It sinks by curling up as it goes; each shove leans it to a side.
	_lean = lerpf(_lean, (0.0 if g.done or g.sink <= 0.0 else SWAY * (1.0 if g.step % 2 == 0 else -1.0)), minf(1.0, dt * 10.0))
	_thief.set_state(Vector3(0, 0.06, 0), PI / 2, g.progress(), dt)
	_thief.set_lean(_lean)
	# Stuck under the lantern: the chest shudders.
	_chest.position.x = 0.02 * bad * sin(t * 60.0) + (0.012 * sin(t * 40.0) if g.sink > 0.0 and g.slow else 0.0)
	# The lid: open, then down once it is done.
	var shut := -1.9 if not g.done else 0.0
	_lid.rotation.x = lerpf(_lid.rotation.x, shut, minf(1.0, dt * 12.0))
	# The arrow: lit when the shove would count, dim while it sinks.
	var on := g.ready()
	_arrows[0].visible = not g.done
	for m in _arrows[0].get_children():
		(m as MeshInstance3D).material_override = _lit if on else _dim
	_arrows[0].scale = Vector3.ONE * (1.0 + (0.12 * sin(t * 9.0) if on else 0.0))
	_arrows[0].position.y = 1.05 + (0.05 * sin(t * 9.0) if on else 0.0)
	# The red bar: someone looks.
	_eye.visible = g.lit() and not g.done
