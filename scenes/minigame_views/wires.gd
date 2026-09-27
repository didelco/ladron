extends MinigameView
## The wires (WiresGame): a walnut panel with brass trim and a wire per
## step; the cut ones hang apart, and over the next one a glowing arrow
## points the way to pull. The wrong way sparks.

const WIRE_COLOURS := [Color("#e8594f"), Color("#4dabf7"), Color("#ffd43b"), Color("#5cc98a"), Color("#c77dff"), Color("#e8d6b4")]

var _wires: Array[Node3D] = []
var _arrow: Node3D
var _spark: OmniLight3D


func build() -> void:
	var steps := game.steps
	# The panel: walnut, a brass trim round it, a dark face behind the wires.
	box(Vector3(1.62, 1.12, 0.1), GOLD, Vector3(0, 0, -0.08))
	box(Vector3(1.5, 1.0, 0.1), WOOD, Vector3(0, 0, -0.04))
	box(Vector3(1.36, 0.86, 0.04), INK, Vector3(0, 0, 0.02))
	for i in steps:
		var x := (i - (steps - 1) * 0.5) * (1.1 / maxf(1, steps - 1))
		var c: Color = WIRE_COLOURS[i % WIRE_COLOURS.size()]
		# A brass terminal top and bottom, and the wire between them in two
		# halves, so a cut one can hang apart.
		for y in [0.36, -0.36]:
			var term := cylinder(0.05, 0.05, 0.06, GOLD)
			term.rotation_degrees.x = 90
			term.position = Vector3(x, y, 0.08)
		var wire := Node3D.new()
		wire.position = Vector3(x, 0, 0.1)
		add_child(wire)
		for half in [1, -1]:
			var seg := MeshInstance3D.new()
			seg.mesh = cylinder_mesh(0.03, 0.36)
			seg.material_override = MenuStage._material(c)
			seg.position = Vector3(0, half * 0.18, 0)
			wire.add_child(seg)
		_wires.append(wire)
	_arrow = arrow(GOLD)
	_spark = OmniLight3D.new()
	_spark.light_color = RED
	_spark.omni_range = 1.4
	_spark.light_energy = 0.0
	add_child(_spark)


func pose(_dt: float) -> void:
	var g := game as WiresGame
	for i in _wires.size():
		var cut := i < g.step
		var w := _wires[i]
		# Cut: the halves pull apart and hang a little askew.
		var top := w.get_child(0) as Node3D
		var bottom := w.get_child(1) as Node3D
		top.position.y = 0.18 + (0.07 if cut else 0.0)
		bottom.position.y = -0.18 - (0.07 if cut else 0.0)
		top.rotation_degrees.z = 12.0 if cut else 0.0
		bottom.rotation_degrees.z = -9.0 if cut else 0.0
	var way := g.way()
	_arrow.visible = way >= 0
	if way >= 0:
		var x := _wires[g.step].position.x
		# Up is 0, then clockwise: right, down, left.
		var angle := -way * PI * 0.5
		var dir := Vector2(sin(-angle), cos(angle))
		var bob := 0.04 * sin(t * 9.0)
		_arrow.position = Vector3(x + dir.x * bob, dir.y * bob, 0.26)
		_arrow.rotation = Vector3(0, 0, angle)
	# The wrong wire: sparks.
	_spark.light_energy = 3.0 * bad
	if g.step < _wires.size():
		_spark.position = Vector3(_wires[g.step].position.x, 0, 0.5)
