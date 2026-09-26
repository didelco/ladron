extends Node3D
## The dust in a guard's torch: a dark floor, the game's camera, and a torch
## sweeping back and forth over the dust of a small museum (its walls left
## out). The motes stay put in the air: the beam lights some and leaves
## others as it passes, and finds the same ones coming back.
##   godot tests/visual/dust.tscn

var torch := SpotLight3D.new()
var t := 0.0


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0f0d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6256aa")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.tonemap_white = 6.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color("#c4c8ec")
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_length = 25.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	floor.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("#3a2f3f")
	floor.material_override = fm
	add_child(floor)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 15.4, 6)
	cam.look_at(Vector3.ZERO)
	Sim.new_map(1)
	Fx.dust_field(self)
	var guard := Node3D.new()
	add_child(guard)
	torch.set_meta(Fx.LIGHTS_DUST, true)
	torch.light_color = Color("#fff1d8")
	torch.light_energy = 9.0
	torch.spot_attenuation = 1.0
	torch.spot_angle_attenuation = 0.5
	torch.spot_angle = rad_to_deg(PI / 4.2) * 1.1
	torch.spot_range = 8.0
	torch.shadow_enabled = true
	torch.light_volumetric_fog_energy = 12.0
	torch.position = Vector3(0, 1.15, 0.3)
	torch.rotation = Vector3(-0.35, PI, 0)
	guard.add_child(torch)
	# A room's ceiling light too, off to one side: it must leave the dust dark.
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ffc98a")
	lamp.light_energy = 2.0
	lamp.omni_range = 5.0
	lamp.position = Vector3(-8, 3.5, 0)
	lamp.light_cull_mask &= ~Fx.DUST_LAYER
	add_child(lamp)


func _process(dt: float) -> void:
	t += dt
	# Swing from one side to the other and back, like a guard turning round.
	(torch.get_parent() as Node3D).rotation.y = sin(t * 0.8) * 1.4
