extends MinigameView
## The dojo's ESCONDITE colour code (SqueezeGame, ColourCode): a walnut board
## with a brass rim; along its top the code, a row of little gems in the
## order to make; along its bottom the balls, in cups, out of order. A gold
## arrow over the ball the cursor is on, the picked ball lifted and lit, the
## balls sliding over when two change places, and a green lamp under every
## ball sitting where the code says.

## Space between slots, the balls' size and the gems'.
const PITCH := 0.26
const BALL := 0.1
const GEM := 0.055

var _balls: Array[MeshInstance3D] = []
var _ball_lit: Array[StandardMaterial3D] = []
var _ball_dim: Array[StandardMaterial3D] = []
var _lamps: Array[MeshInstance3D] = []
var _lamp_lit: StandardMaterial3D
var _lamp_dim: StandardMaterial3D
var _arrow: Node3D


func framing() -> Dictionary:
	return {"span": 1.5, "look": 0.3, "angle": Vector3(-16, 10, 0)}


func build() -> void:
	var g := game as SqueezeGame
	var n := g.size()
	var w := n * PITCH + 0.24
	# The board: walnut, a brass rim, a brass strip for the code along the top.
	box(Vector3(w, 0.9, 0.08), WOOD, Vector3(0, 0.3, -0.06))
	box(Vector3(w + 0.06, 0.05, 0.1), GOLD, Vector3(0, 0.78, -0.06))
	box(Vector3(w + 0.06, 0.05, 0.1), GOLD, Vector3(0, -0.18, -0.06))
	box(Vector3(w - 0.16, 0.16, 0.03), GOLD.darkened(0.35), Vector3(0, 0.62, -0.02))
	_lamp_dim = MenuStage._material(INK.lightened(0.15))
	_lamp_lit = glowing(GREEN, 2.2)
	for i in n:
		var x := _x(i, n)
		# The code: a gem of each colour, in order.
		var gem := MeshInstance3D.new()
		gem.mesh = _sphere(GEM)
		gem.material_override = glowing(ColourCode.colour(g.code.target[i]), 0.9)
		gem.position = Vector3(x, 0.62, 0.02)
		add_child(gem)
		# A cup for each ball, and its lamp under it.
		var cup := cylinder(0.14, 0.11, 0.06, INK.lightened(0.08))
		cup.position = Vector3(x, 0.0, 0.0)
		var lamp := box(Vector3(0.12, 0.035, 0.03), INK, Vector3(x, -0.1, 0.0))
		lamp.material_override = _lamp_dim
		_lamps.append(lamp)
	# The balls, one of each colour, where they sit now.
	for i in n:
		var c := ColourCode.colour(i)
		var ball := MeshInstance3D.new()
		ball.mesh = _sphere(BALL)
		_ball_dim.append(MenuStage._material(c))
		_ball_lit.append(glowing(c, 1.6))
		ball.material_override = _ball_dim[i]
		ball.position = Vector3(_x(g.code.balls.find(i), n), BALL + 0.03, 0.0)
		add_child(ball)
		_balls.append(ball)
	# The cursor: a gold arrow pointing down at a ball.
	_arrow = arrow(GOLD)
	_arrow.rotation.z = PI


func pose(dt: float) -> void:
	var g := game as SqueezeGame
	var n := g.size()
	var k := minf(1.0, dt * 12.0)
	for i in n:
		var ball := g.code.balls[i]
		var picked := g.picked() == i and not g.done
		var at := Vector3(_x(i, n), BALL + 0.03 + (0.12 if picked else 0.0), 0.0)
		_balls[ball].position = _balls[ball].position.lerp(at, k)
		_balls[ball].material_override = _ball_lit[ball] if picked else _ball_dim[ball]
		_lamps[i].material_override = _lamp_lit if ball == g.code.target[i] else _lamp_dim
	# The arrow over the cursor's ball, bobbing while there is something to do.
	_arrow.visible = not g.done
	var ax := _x(g.cursor, n)
	_arrow.position = _arrow.position.lerp(Vector3(ax, 0.4 + 0.03 * sin(t * 9.0), 0.1), k)
	_arrow.scale = Vector3.ONE * (0.8 + 0.06 * sin(t * 9.0))
	# Done: the whole row glows a moment.
	scale = Vector3.ONE * (1.0 + 0.04 * good)


## Where a slot sits along the board, middled.
func _x(slot: int, n: int) -> float:
	return (slot - (n - 1) * 0.5) * PITCH


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s
