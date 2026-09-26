extends Node3D
## Close-up of the figures, for eyeballing the models and their animations at
## the game's speeds: a thief walking, running and crawling, and a guard
## walking and running, each on its own lane, back and forth. Run it from the
## editor, or record it:
##   godot --write-movie out.png --fixed-fps 30 --quit-after 240 tests/visual/figures.tscn

## [kind, colour, [[speed m/s, posture, seconds], ...]]
const LANES := [
	["thief", Color("#2ec4a6"), [[1.5, 0.0, 2.0], [0.0, 0.0, 1.0], [4.8, 0.0, 1.5]]],
	["thief", Color("#f0a13a"), [[0.0, 1.0, 1.0], [0.8, 1.0, 3.0], [0.0, 0.0, 1.5]]],
	["guard", Color("#9b2c3f"), [[1.2, 0.0, 2.5], [0.0, 0.0, 1.0], [3.4, 0.0, 1.5]]],
]

var _figs: Array[Figure] = []
var _x: Array[float] = []
var _dir: Array[float] = []
var _posture: Array[float] = []
var t := 0.0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0f0d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8e96c8")
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 35, 0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	add_child(key)
	var floor_mesh := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(20, 10)
	floor_mesh.mesh = p
	floor_mesh.material_override = MuseumView.toon(Color("#2b2a36"))
	add_child(floor_mesh)
	for i in LANES.size():
		var lane: Array = LANES[i]
		var f := Figure.make(lane[0], lane[1], lane[1].darkened(0.5))
		add_child(f)
		_figs.append(f)
		_x.append(-3.0)
		_dir.append(0.0)
		_posture.append(0.0)
		f.set_ghost(lane[1], 0.75)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 4.2, 5.6)
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(0, 0.3, 0))


func _process(dt: float) -> void:
	t += dt
	for i in LANES.size():
		var steps: Array = LANES[i][2]
		var total := 0.0
		for s in steps:
			total += s[2]
		var u := fmod(t, total)
		var step: Array = steps[0]
		for s in steps:
			if u < s[2]:
				step = s
				break
			u -= s[2]
		# Turn round at the ends of the lane.
		if _x[i] > 3.0:
			_dir[i] = PI
		elif _x[i] < -3.0:
			_dir[i] = 0.0
		_x[i] += cos(_dir[i]) * float(step[0]) * dt
		# Posture eases like the sim's: 1.5 s to get down or up.
		_posture[i] = move_toward(_posture[i], step[1], dt / 1.5)
		_figs[i].set_state(Vector3(_x[i], 0, (i - 1) * 1.4), _dir[i], _posture[i], dt)
