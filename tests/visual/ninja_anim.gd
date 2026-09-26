extends Node3D
## The rigged ninja (assets/models/ninja.glb) playing each of its animations
## side by side. Takes a picture and quits:
##   godot --path . tests/visual/ninja_anim.tscn -- --out=/tmp/x.png --t=0.3

var _args := {"out": "user://ninja_anim.png", "t": "0.25"}
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#2a2838")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#c9cbe0")
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 30, 0)
	key.light_energy = 1.4
	key.shadow_enabled = true
	add_child(key)
	var scene: PackedScene = load("res://assets/models/ninja.glb")
	var names := ["reposo", "andar", "correr", "gatear"]
	for i in names.size():
		var n := scene.instantiate()
		add_child(n)
		n.position = Vector3((i - 1.5) * 1.1, 0, 0)
		n.rotation.y = 0.6
		var player: AnimationPlayer = n.find_child("AnimationPlayer", true, false)
		print("anims: ", player.get_animation_list())
		player.play(names[i])
		player.seek(float(_args.t) * player.current_animation_length, true)
		player.pause()
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 35
	cam.position = Vector3(0, 1.6, 5.4)
	cam.look_at(Vector3(0, 0.45, 0))


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 8:
		get_viewport().get_texture().get_image().save_png(_args.out)
		get_tree().quit()
