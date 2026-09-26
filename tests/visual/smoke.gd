extends Node3D
## The smoke bomb (SmokeFx) going off in a dark gallery, a ninja in the
## middle of it and a guard's torch sweeping through, from the game's camera
## ("game") or closer ("close"). Record it:
##   godot --path . --write-movie out.png --fixed-fps 30 --quit-after 270 tests/visual/smoke.tscn -- --view=close

var _t := 0.0
var _torch: SpotLight3D
var _guard: Figure
var _ninja: Figure
var _fired := false


func _ready() -> void:
	var view := "close"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view="):
			view = a.substr(7)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0f0d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#5a5f86")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color("#c4c8ec")
	env.volumetric_fog_length = 30.0
	env.volumetric_fog_anisotropy = 0.3
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.light_color = Color("#8ea2ff")
	moon.light_energy = 0.45
	moon.shadow_enabled = true
	add_child(moon)
	# A floor, a wall behind, a few cases.
	var floor_mesh := MeshInstance3D.new()
	var p := PlaneMesh.new()
	p.size = Vector2(16, 12)
	floor_mesh.mesh = p
	floor_mesh.material_override = MuseumView.toon(Color("#3a2c30"))
	add_child(floor_mesh)
	for spec in [[Vector3(0, 0.6, -3.5), Vector3(12, 1.2, 0.5)], [Vector3(-2.2, 0.41, -1.0), Vector3(0.8, 0.82, 0.8)], [Vector3(2.4, 0.41, 0.8), Vector3(0.8, 0.82, 0.8)], [Vector3(-3.2, 0.41, 1.8), Vector3(0.8, 0.82, 0.8)]]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = spec[1]
		b.mesh = bm
		b.position = spec[0]
		b.material_override = MuseumView.toon(Color("#4a3a52"))
		add_child(b)
	_ninja = Figure.make("thief", Color("#e2262f"), Color("#8a1c1c"))
	add_child(_ninja)
	_ninja.set_state(Vector3(0, 0, 0), PI / 2, 0.0, 0.016)
	_guard = Figure.make("guard", Color("#9b2c3f"), Color("#5e1826"))
	add_child(_guard)
	_torch = SpotLight3D.new()
	_torch.light_color = Color("#ffe3a0")
	_torch.light_energy = 6.0
	_torch.spot_range = 9.0
	_torch.spot_angle = 22.0
	_torch.shadow_enabled = true
	_torch.light_volumetric_fog_energy = 3.0
	add_child(_torch)
	var cam := Camera3D.new()
	add_child(cam)
	if view == "game":
		cam.fov = 50
		cam.look_at_from_position(Vector3(0, 15.4, 6) * 0.72, Vector3.ZERO)
	else:
		cam.fov = 40
		cam.look_at_from_position(Vector3(3.2, 4.2, 6.5), Vector3(0, 0.6, 0))


func _process(dt: float) -> void:
	_t += dt
	# The guard walks in from the right, the torch sweeping the room.
	var gx := lerpf(5.5, 3.4, clampf(_t / 3.0, 0.0, 1.0))
	var sweep := sin(_t * 0.9) * 0.5
	_guard.set_state(Vector3(gx, 0, -0.6), PI + sweep, 0.0, dt)
	var at := Vector3(gx, 1.15, -0.6)
	_torch.position = at
	_torch.look_at(at + Vector3(-cos(sweep), -0.28, -sin(sweep)).normalized())
	_ninja.set_state(Vector3(0, 0, 0), PI / 2, 0.0, dt)
	if _t > 0.6 and not _fired:
		_fired = true
		SmokeFx.burst(self, Vector3(0, 0, 0), 2.5, 6.0)
