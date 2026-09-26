class_name Fx
extends RefCounted
## Particles: dust hanging in the air (a MultiMesh, seen where a light falls)
## and, as GPUParticles3D, the puff when something is knocked over and the
## sparkle when the piece comes out of its case. Counts stay low: the camera is high above, and a handful of
## specks reads better than a cloud.
##
## One-shot bursts free themselves once done; the dust lives with the world.

## A soft round speck, white: tinted per use through vertex colour.
static var _soft: GradientTexture2D


# --- Dust in the air ---------------------------------------------------------------

## The visual layer dust lives on. Only the torches reach it: a light made
## with this meta keeps it in its cull mask, every other one drops it.
const DUST_LAYER := 1 << 10
const LIGHTS_DUST := &"lights_dust"

## Motes per square metre of floor, between ankle and head height.
const DUST_PER_M2 := 2.6


## Dust hanging in the air all over the museum, and staying there. It shows
## only where a torch shines on it: a torch sweeping past picks out the motes
## in its beam and leaves them in the dark again behind it, and coming back
## finds the same ones. Nothing is born or dies; the air is just lit.
static func dust_field(parent: Node3D) -> void:
	var spots: Array[Vector3] = []
	for y in Museum.h:
		for x in Museum.w:
			if Museum.is_wall(x + 0.5, y + 0.5):
				continue
			var n := int(DUST_PER_M2) + (1 if randf() < fmod(DUST_PER_M2, 1.0) else 0)
			for i in n:
				spots.append(MuseumView.to_world(x + randf(), y + randf(), randf_range(0.1, 1.8)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = QuadMesh.new()
	mm.instance_count = spots.size()
	for i in spots.size():
		mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
		# Where it is in its slow sway, and how big it is.
		mm.set_instance_custom_data(i, Color(randf(), randf(), randf(), randf_range(0.05, 0.09)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.layers = DUST_LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var look := ShaderMaterial.new()
	look.shader = _dust_shader()
	node.material_override = look
	parent.add_child(node)


## A soft speck facing the camera, lit by the light that reaches it however
## it faces it: from straight above a quad looks up, and a torch held at
## waist height shines across it, so the usual shading would leave it black.
static func _dust_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, ambient_light_disabled, specular_disabled;

// White, whatever the torch's own colour.
uniform vec3 tint : source_color = vec3(1.0);
uniform float strength = 1.0;

void vertex() {
	// A barely-there sway, a few centimetres, so the air is not frozen.
	vec3 phase = INSTANCE_CUSTOM.xyz * 6.2832;
	vec3 sway = 0.04 * vec3(sin(TIME * 0.31 + phase.x), sin(TIME * 0.23 + phase.y), sin(TIME * 0.27 + phase.z));
	float size = INSTANCE_CUSTOM.w;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * size,
		INV_VIEW_MATRIX[1] * size,
		INV_VIEW_MATRIX[2] * size,
		MODEL_MATRIX[3] + vec4(sway, 0.0));
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = tint;
	// A solid little core with a short soft edge, not a faint smudge.
	ALPHA = (1.0 - smoothstep(0.35, 1.0, r)) * strength;
}

void light() {
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION / PI;
}
"""
	return sh


# --- Bursts -------------------------------------------------------------------------

## Dust thrown up where a prop hits the floor. The bust smashes: a bigger
## cloud, and a few white chips skittering out.
static func puff(parent: Node3D, at: Vector3, smash := false) -> void:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.25 if smash else 0.18
	m.direction = Vector3.UP
	m.spread = 80.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 1.6 if smash else 1.1
	m.gravity = Vector3(0, -0.4, 0)
	m.damping_min = 1.5
	m.damping_max = 2.5
	m.angle_min = 0.0
	m.angle_max = 360.0
	m.scale_min = 0.4 if smash else 0.3
	m.scale_max = 0.7 if smash else 0.5
	# The cloud swells as it settles.
	m.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.4)])
	m.color_ramp = fade(Color("#9c9180", 0.0), Color("#9c9180", 0.45), 0.1)
	_burst(parent, at + Vector3(0, 0.15, 0), 22 if smash else 14, 1.4, 0.85, m, speck_material(true))
	if not smash:
		return
	# Chips of marble: real little boxes, bouncing on the floor.
	var c := ParticleProcessMaterial.new()
	c.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 0.1
	c.direction = Vector3.UP
	c.spread = 70.0
	c.initial_velocity_min = 1.2
	c.initial_velocity_max = 2.4
	c.gravity = Vector3(0, -9.8, 0)
	c.angular_velocity_min = -400.0
	c.angular_velocity_max = 400.0
	c.scale_min = 0.6
	c.scale_max = 1.3
	c.particle_flag_rotate_y = true
	c.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
	c.collision_friction = 0.6
	c.collision_bounce = 0.3
	c.color_ramp = fade(Color("#d8d2c4", 0.0), Color("#d8d2c4"), 0.02, 0.8)
	var chip := BoxMesh.new()
	chip.size = Vector3(0.04, 0.03, 0.05)
	var look := StandardMaterial3D.new()
	look.vertex_color_use_as_albedo = true
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Unshaded: in the dark the chips would be lost, and they are marble.
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chip.material = look
	var chips := _burst(parent, at + Vector3(0, 0.3, 0), 9, 1.6, 1.0, c, null, chip)
	# The floor, for them to land on.
	var ground := GPUParticlesCollisionBox3D.new()
	ground.size = Vector3(4, 0.2, 4)
	ground.position = Vector3(0, -0.4, 0)
	chips.add_child(ground)


## A burst of glitter in the piece's colour: it is out of its case.
static func sparkle(parent: Node3D, at: Vector3, colour: Color) -> void:
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.15
	m.direction = Vector3.UP
	m.spread = 100.0
	m.initial_velocity_min = 1.2
	m.initial_velocity_max = 2.6
	m.gravity = Vector3(0, -1.5, 0)
	m.damping_min = 1.5
	m.damping_max = 2.5
	m.scale_min = 0.08
	m.scale_max = 0.16
	m.scale_curve = _curve([Vector2(0, 1), Vector2(0.7, 0.8), Vector2(1, 0)])
	# White-hot at first, settling into the piece's colour.
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(colour, 0.0))
	g.add_point(0.2, Color(colour.lightened(0.15), 1.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	m.color_ramp = ramp
	var look := speck_material(false)
	look.albedo_color = Color(1.4, 1.4, 1.4)
	_burst(parent, at, 30, 1.3, 0.9, m, look)


# --- Pieces -------------------------------------------------------------------------

## A one-shot emitter at a world position, gone once its last particle is.
static func _burst(parent: Node3D, at: Vector3, count: int, life: float, burst: float, m: ParticleProcessMaterial, look: Material, mesh: Mesh = null) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = count
	p.lifetime = life
	p.explosiveness = burst
	p.one_shot = true
	p.process_material = m
	p.draw_pass_1 = mesh if mesh else quad(look)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = at
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	# restart(), not emitting = true: a new emitter already counts as
	# emitting, and would never get round to saying it has finished.
	p.restart()
	return p


## The speck: a soft round quad facing the camera, coloured by the particle.
## Glowing specks add light; dust is drawn over what is behind it.
static func speck_material(mixed: bool) -> StandardMaterial3D:
	if _soft == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft = GradientTexture2D.new()
		_soft.gradient = g
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 32
		_soft.height = 32
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	# Without this the particle's own size is dropped: every speck a metre wide.
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if mixed else BaseMaterial3D.BLEND_MODE_ADD
	return m


static func quad(look: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.material = look
	return q


## A colour ramp that fades in, holds and fades out; hold_end is where the
## fading out starts.
static func fade(clear: Color, full: Color, fade_in: float, hold_end := 0.6) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, clear)
	g.set_color(1, Color(full, 0.0))
	g.add_point(fade_in, full)
	g.add_point(hold_end, full)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(points: Array[Vector2]) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 2.0
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t
