extends Node3D
## Style sketches for the figures (scenes/bean.gd) next to the current Figure:
## a thief and a guard per style, close up in a studio light ("front"), from
## the game's camera in its night light ("top"), or every style in a row at the
## game's own distance ("lineup"). Takes a picture and quits:
##   godot --path . tests/visual/beans.tscn -- --shot=front --style=bean --out=/tmp/x.png

const THIEF := Color("#2ec4a6")
const THIEF_DARK := Color("#12705f")
const GUARD := Color("#9b2c3f")
const GUARD_DARK := Color("#5e1826")
## The game camera's offset from what it looks at (main.gd CAM_OFFSET).
const CAM_OFFSET := Vector3(0, 15.4, 6)

var _args := {"shot": "front", "style": "current", "out": "user://beans.png"}
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	var night: bool = _args.shot in ["top", "lineup"]
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0f0d14") if night else Color("#2a2838")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8e96c8") if night else Color("#c9cbe0")
	env.ambient_light_energy = 0.45 if night else 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, 30, 0)
	key.light_color = Color("#8ea2ff") if night else Color("#fff4e8")
	key.light_energy = 0.9 if night else 1.5
	key.shadow_enabled = true
	add_child(key)
	if not night:
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(-20, -140, 0)
		fill.light_color = Color("#9fb4ff")
		fill.light_energy = 0.5
		add_child(fill)
	var floor_mesh := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(40, 40)
	floor_mesh.mesh = p
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#2b2a36") if night else Color("#3b394c")
	fm.roughness = 0.6
	floor_mesh.material_override = fm
	add_child(floor_mesh)
	var cam := Camera3D.new()
	add_child(cam)

	match _args.shot:
		"front":
			_pair(_args.style, Vector3.ZERO, 0.45, -0.45)
			cam.fov = 30
			cam.position = Vector3(0, 1.6, 4.4)
			cam.look_at(Vector3(0, 0.55, 0))
		"top":
			# The thief heading right, the guard left: can you tell?
			_pair(_args.style, Vector3.ZERO, PI / 2, -PI / 2)
			# A torch pool round the guard, as in the game.
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(1.8, 1.6, 1.2)
			lamp.light_color = Color("#ffd479")
			lamp.light_energy = 0.7
			lamp.omni_range = 4.0
			add_child(lamp)
			cam.fov = 50
			cam.position = CAM_OFFSET.normalized() * 3.2 + Vector3(0, 0.4, 0)
			cam.look_at(Vector3(0, 0.4, 0))
		"ninjas":
			# The gang in the four pad colours, and a guard, turned a little.
			var gang := [[THIEF, THIEF_DARK], [Color("#e03131"), Color("#8a1c1c")], [Color("#b07cff"), Color("#5b3a99")], [Color("#4dabf7"), Color("#1c5d99")]]
			for i in 4:
				var n := _figure(_args.style, "thief", gang[i][0], gang[i][1])
				n.position = Vector3((i - 2) * 0.85, 0, 0)
				n.rotation.y = [0.35, -0.5, 2.6, -0.2][i]
			var g := _figure(_args.style, "guard", GUARD, GUARD_DARK)
			g.position = Vector3(2 * 0.85, 0, 0)
			g.rotation.y = -0.35
			cam.fov = 30
			cam.position = Vector3(0, 1.8, 7.2)
			cam.look_at(Vector3(0, 0.55, 0))
		"moods":
			# Close on the face, one guard per mood.
			var kind: String = _args.get("kind", "guard")
			var moods: Array = Bean.MOODS if kind == "guard" else Bean.NINJA_MOODS
			var gang := [[THIEF, THIEF_DARK], [Color("#e03131"), Color("#8a1c1c")], [Color("#b07cff"), Color("#5b3a99")], [Color("#4dabf7"), Color("#1c5d99")]]
			for i in moods.size():
				var c: Array = [GUARD, GUARD_DARK] if kind == "guard" else gang[i % 4]
				var b := Bean.make(_args.style, kind, c[0], c[1], moods[i])
				add_child(b)
				b.position = Vector3((i - (moods.size() - 1) / 2.0) * 0.72, 0, 0)
			cam.fov = 22
			cam.position = Vector3(0, 1.05, 7.4)
			cam.look_at(Vector3(0, 0.72, 0))
		"lineup":
			var styles: Array = _args.get("styles", "current," + ",".join(Bean.STYLES)).split(",")
			for i in styles.size():
				_pair(styles[i], Vector3((i - (styles.size() - 1) / 2.0) * 2.4, 0, 0), PI / 2, PI)
			cam.fov = 50
			cam.position = CAM_OFFSET * 0.8
			cam.look_at(Vector3.ZERO)


func _pair(style: String, at: Vector3, thief_turn: float, guard_turn: float) -> void:
	var t := _figure(style, "thief", THIEF, THIEF_DARK)
	t.position = at + Vector3(-0.5, 0, 0)
	t.rotation.y = thief_turn
	var g := _figure(style, "guard", GUARD, GUARD_DARK)
	g.position = at + Vector3(0.5, 0, 0)
	g.rotation.y = guard_turn


func _figure(style: String, kind: String, colour: Color, accent: Color) -> Node3D:
	var f: Node3D
	if style == "current":
		var fig := Figure.make(kind, colour, accent)
		add_child(fig)
		# Stand it still: one frame of state at rest.
		fig.set_state(Vector3.ZERO, PI / 2, 0.0, 0.016)
		f = fig
	else:
		f = Bean.make(style, kind, colour, accent)
		add_child(f)
	return f


func _process(_dt: float) -> void:
	_frames += 1
	if _frames == 8:
		var img := get_viewport().get_texture().get_image()
		img.save_png(_args.out)
		get_tree().quit()
