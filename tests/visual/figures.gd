extends Node3D
## Close-up of the figures, for eyeballing the models and their animations:
## a thief walking, getting down, crawling and getting up, and a guard walking.
## Run it from the editor, or record it:
##   godot --write-movie out.png --fixed-fps 30 --quit-after 240 tests/visual/figures.tscn

var thief: Figure
var guard: Figure
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
	add_child(key)
	thief = Figure.make("thief", Color("#2ec4a6"), Color("#12705f"))
	add_child(thief)
	guard = Figure.make("guard", Color("#9b2c3f"), Color("#5e1826"))
	add_child(guard)
	# A case in front of the thief's path, to show the x-ray silhouette.
	var case_box := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.8, 0.8, 0.8)
	case_box.mesh = b
	case_box.position = Vector3(-0.6, 0.4, 1.2)
	add_child(case_box)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 2.6, 3.6)
	cam.fov = 40
	add_child(cam)
	cam.look_at(Vector3(0, 0.5, 0))


func _process(dt: float) -> void:
	t += dt
	# Thief: walk 2 s, get down 1.5 s, crawl 2 s, get up 1.5 s, then again.
	var cycle := fmod(t, 7.0)
	var posture := 0.0
	var moving := true
	if cycle >= 2.0 and cycle < 3.5:
		posture = (cycle - 2.0) / 1.5
		moving = false
	elif cycle >= 3.5 and cycle < 5.5:
		posture = 1.0
	elif cycle >= 5.5:
		posture = 1.0 - (cycle - 5.5) / 1.5
		moving = false
	var speed := (0.8 if posture > 0 else 2.0) if moving else 0.0
	var x := -1.2 + fmod(t * 0.3, 1.2)
	thief.set_state(Vector3(x, 0, 0.3 + (t * speed * 0.05)), 0.0, posture, dt)
	thief.position = Vector3(-0.6, 0, 0.3)
	thief.set_meta("last_phase", thief.get_meta("last_phase", 0.0))
	guard.set_state(Vector3(0.7 + sin(t) * 0.001, 0, t * 1.4), PI / 2, 0.0, dt)
	guard.position = Vector3(0.7, 0, 0.0)
	guard.rotation.y = 0.6
	thief.rotation.y = -0.4
	thief.set_ghost(Color("#2ec4a6"), 0.75)
