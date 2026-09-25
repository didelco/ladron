class_name Fx
extends RefCounted
## Particles, all GPUParticles3D built here: dust hanging in the lights, the
## puff when something is knocked over, the sparkle when the piece comes out
## of its case. Counts stay low: the camera is high above, and a handful of
## specks reads better than a cloud.
##
## One-shot bursts free themselves once done; the dust lives on its light and
## goes with it.

## A soft round speck, white: tinted per use through vertex colour.
static var _soft: GradientTexture2D


# --- Dust in the lights -------------------------------------------------------------

## Dust motes drifting in a light: inside the beam of a guard's torch, or
## under a room's ceiling light. Only there while the light is on.
static func dust_in(light: Light3D) -> void:
	light.add_child(Dust.new())


## Motes hanging in a light. They sit where the light shines (local to it, so
## a torch carries its beam of dust along), and fade out when it goes off.
class Dust extends GPUParticles3D:
	var _process_mat := ParticleProcessMaterial.new()
	var _look := Fx.speck_material(false)
	var _shape := Vector2.ZERO
	var _tint := Color.BLACK

	func _init() -> void:
		amount = 28
		lifetime = 5.0
		preprocess = 5.0
		local_coords = true
		# Big enough to cover a whole beam: the default box is two metres wide.
		visibility_aabb = AABB(Vector3(-6, -4, -12), Vector3(12, 6, 13))
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := _process_mat
		m.gravity = Vector3.ZERO
		m.direction = Vector3.UP
		m.spread = 180.0
		m.initial_velocity_min = 0.02
		m.initial_velocity_max = 0.08
		# A slow swirl, so they drift rather than slide in straight lines.
		m.turbulence_enabled = true
		m.turbulence_noise_strength = 0.4
		m.turbulence_noise_scale = 3.0
		m.turbulence_noise_speed_random = 0.1
		m.turbulence_influence_min = 0.02
		m.turbulence_influence_max = 0.05
		m.scale_min = 0.05
		m.scale_max = 0.09
		# In, hang, out: a mote never pops.
		m.color_ramp = Fx.fade(Color(1, 1, 1, 0.0), Color(1, 1, 1, 1.0), 0.3)
		process_material = m
		draw_pass_1 = Fx.quad(_look)

	func _process(_dt: float) -> void:
		var light := get_parent() as Light3D
		if light == null:
			return
		emitting = light.light_energy > 0.0
		if not emitting:
			return
		if light.light_color != _tint:
			_tint = light.light_color
			_look.albedo_color = Color(_tint, 0.3)
		if light is SpotLight3D:
			var spot := light as SpotLight3D
			var shape := Vector2(spot.spot_angle, spot.spot_range)
			if shape != _shape:
				_shape = shape
				_fill_cone(spot)
		elif _shape == Vector2.ZERO:
			# A ceiling light: a slab of air in the middle of the room.
			_shape = Vector2.ONE
			amount = 36
			_process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			_process_mat.emission_box_extents = Vector3(3.0, 0.8, 2.5)
			position = Vector3(0, -1.5, 0)

	## Points scattered through the torch's cone, down to the floor: the beam
	## is narrow and tilted, and a box would put motes outside it.
	func _fill_cone(spot: SpotLight3D) -> void:
		var tan_half := tan(deg_to_rad(spot.spot_angle)) * 0.8
		var pts := PackedVector3Array()
		var tries := 0
		while pts.size() < 64 and tries < 2000:
			tries += 1
			# Farther out the cone is wider: weight the depth that way.
			var d := spot.spot_range * sqrt(randf_range(0.02, 1.0)) * 0.8
			var r := d * tan_half * sqrt(randf())
			var a := randf() * TAU
			var p := Vector3(cos(a) * r, sin(a) * r, -d)
			# Keep to the air: above the floor, below the ceiling of the view.
			var y := (spot.transform * p).y
			if y > 0.08 and y < 1.8:
				pts.append(p)
		if pts.is_empty():
			return
		var img := Image.create(pts.size(), 1, false, Image.FORMAT_RGBF)
		for i in pts.size():
			img.set_pixel(i, 0, Color(pts[i].x, pts[i].y, pts[i].z))
		_process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
		_process_mat.emission_point_texture = ImageTexture.create_from_image(img)
		_process_mat.emission_point_count = pts.size()


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
