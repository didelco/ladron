class_name SmokeFx
extends Node3D
## A smoke bomb going off: a cloud that hides whoever is in it.
##
## Built in layers, so it reads from the camera up high and still looks like
## smoke close to: the pop (a flash of light, a ring of dust racing out over
## the floor, a spray of sparks); the body, a volume of the game's own
## volumetric fog (a FogVolume), so the torches light it from inside and a
## beam through it glows; round it, big soft puffs that billow out, swell,
## turn and thin away; along the floor, a lower, wider layer that rolls out
## and lingers after the rest has gone.
##
##   SmokeFx.burst(world, MuseumView.to_world(x, y), 2.5, 6.0)
##
## radius: how far the cloud reaches (tiles); seconds: how long it hides.

## The smoke's colours: pale and a little warm where it is thick, cool grey
## where it thins, as ash smoke goes.
const LIGHT := Color("#e8e4dc")
const MID := Color("#a9a8b0")
const DARK := Color("#6d6c78")

var radius := 2.5
var seconds := 6.0
var _age := 0.0
var _fog: FogVolume
var _fog_mat: FogMaterial
var _flash: OmniLight3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _parts: Array[GPUParticles3D] = []

static var _puff_tex: Texture2D
static var _density: NoiseTexture3D


static func burst(parent: Node, at: Vector3, radius := 2.5, seconds := 6.0) -> SmokeFx:
	var fx := SmokeFx.new()
	fx.radius = radius
	fx.seconds = seconds
	fx.position = at
	parent.add_child(fx)
	return fx


func _ready() -> void:
	_build_flash()
	_build_ring()
	_build_sparks()
	_build_fog()
	_build_puffs()
	_build_floor_layer()


func _process(dt: float) -> void:
	_age += dt
	var life := seconds + 3.5
	# The pop: bright for a blink, gone in a quarter second.
	if _flash:
		_flash.light_energy = maxf(0.0, 9.0 * (1.0 - _age / 0.25))
		if _age > 0.3:
			_flash.queue_free()
			_flash = null
	# The dust ring races out and fades.
	if _ring:
		var k := clampf(_age / 0.55, 0.0, 1.0)
		var ease := 1.0 - pow(1.0 - k, 3.0)
		_ring.scale = Vector3.ONE * lerpf(0.2, radius * 1.25, ease)
		_ring_mat.albedo_color.a = 0.6 * (1.0 - k * k)
		if k >= 1.0:
			_ring.queue_free()
			_ring = null
	# The fog body: swells out fast, holds thick, then thins out and lifts.
	var grow := 1.0 - pow(1.0 - clampf(_age / 0.9, 0.0, 1.0), 3.0)
	# It hides for `seconds`; then it thins out over three more, in wisps.
	var fade := clampf((seconds + 2.0 - _age) / 3.0, 0.0, 1.0)
	_fog.size = Vector3(radius * 2.1, radius * 1.1, radius * 2.1) * lerpf(0.35, 1.0, grow) * lerpf(1.2, 1.0, fade)
	_fog.position.y = radius * 0.4 + (1.0 - fade) * 0.6
	_fog_mat.density = 2.2 * grow * fade * fade
	# The noise in it drifts and churns.
	_fog_mat.density_texture = _density
	(_fog_mat as FogMaterial).height_falloff = 0.6
	_fog.rotation.y += dt * 0.12
	# The puffs stop coming once it is time to thin out.
	if _age > seconds - 0.6:
		for p in _parts:
			p.emitting = false
	if _age > life + 3.0:
		queue_free()


## Is a point (world, flat) inside the cloud while it still hides?
func hides(at: Vector3) -> bool:
	if _age > seconds:
		return false
	var d := Vector2(at.x - global_position.x, at.z - global_position.z).length()
	var grow := 1.0 - pow(1.0 - clampf(_age / 0.9, 0.0, 1.0), 3.0)
	return d < radius * lerpf(0.35, 1.0, grow)


# --- The layers ----------------------------------------------------------------------

func _build_flash() -> void:
	_flash = OmniLight3D.new()
	_flash.light_color = Color("#ffd9a0")
	_flash.omni_range = radius * 3.0
	_flash.light_energy = 9.0
	_flash.light_volumetric_fog_energy = 4.0
	_flash.position.y = 0.4
	add_child(_flash)


## The blast wave: a soft ring of dust racing out over the floor.
func _build_ring() -> void:
	_ring = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(2.0, 2.0)
	_ring.mesh = q
	_ring.scale = Vector3.ONE * 0.2
	_ring.position.y = 0.04
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(LIGHT, 0.55)
	_ring_mat.albedo_texture = _soft_ring()
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)


static var _ring_tex: Texture2D


## A blurred ring, broken up by noise so it reads as dust, not a hoop.
static func _soft_ring() -> Texture2D:
	if _ring_tex:
		return _ring_tex
	var size := 256
	var n := FastNoiseLite.new()
	n.frequency = 0.06
	n.fractal_octaves = 3
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var band := exp(-pow((r - 0.8) / 0.12, 2.0)) + 0.35 * exp(-pow((r - 0.55) / 0.25, 2.0))
			var lump := n.get_noise_2d(x, y) * 0.5 + 0.5
			img.set_pixel(x, y, Color(1, 1, 1, clampf(band * (0.35 + lump), 0.0, 1.0)))
	img.generate_mipmaps()
	_ring_tex = ImageTexture.create_from_image(img)
	return _ring_tex


## A spray of hot sparks out of the pop, falling, gone in half a second.
func _build_sparks() -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.7
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 80.0
	m.initial_velocity_min = 3.0
	m.initial_velocity_max = 6.5
	m.gravity = Vector3(0, -9.0, 0)
	m.damping_min = 2.0
	m.damping_max = 4.0
	m.scale_min = 0.5
	m.scale_max = 1.0
	var fade := Gradient.new()
	fade.set_color(0, Color("#fff2c0"))
	fade.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	m.color_ramp = ramp
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	q.material = mat
	p.draw_pass_1 = q
	p.position.y = 0.3
	p.emitting = true
	add_child(p)


## The body of the cloud: the game's volumetric fog, thick, in a squashed
## ball, with a churning noise so it is never a smooth blob.
func _build_fog() -> void:
	_fog = FogVolume.new()
	_fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
	_fog_mat = FogMaterial.new()
	_fog_mat.albedo = LIGHT
	_fog_mat.emission = Color(0.06, 0.06, 0.07)
	_fog_mat.edge_fade = 0.6
	_fog_mat.density = 0.0
	if _density == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.fractal_type = FastNoiseLite.FRACTAL_FBM
		n.fractal_octaves = 4
		n.frequency = 0.045
		_density = NoiseTexture3D.new()
		_density.width = 64
		_density.height = 64
		_density.depth = 64
		_density.seamless = true
		_density.noise = n
	_fog_mat.density_texture = _density
	_fog.material = _fog_mat
	_fog.size = Vector3.ONE * 0.1
	add_child(_fog)


## The puffs: big soft billows that burst out, slow down, swell and turn,
## lit by whatever light is about, and thin away. A burst out of the pop,
## then a slow boil that keeps the cloud full until it is time to go.
func _build_puffs() -> void:
	# The burst: out fast, braked hard, so it piles up at the cloud's edge.
	_parts.append(_puffs(60, 2.6, 0.95, 0.4, radius * 1.1, radius * 1.9, radius * 2.6, radius * 3.4, 1.9, 0.6))
	# The boil: slow puffs inside the cloud, rolling over each other.
	_parts.append(_puffs(36, 3.0, 0.0, radius * 0.55, radius * 0.1, radius * 0.4, 0.6, 1.0, 1.7, 0.75))


func _puffs(amount: int, life: float, explode: float, spread_r: float, v_min: float, v_max: float, d_min: float, d_max: float, big: float, lift: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.explosiveness = explode
	p.randomness = 0.5
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-radius * 2, -1, -radius * 2), Vector3(radius * 4, radius * 3, radius * 4))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = maxf(0.3, spread_r)
	m.direction = Vector3(0, 0.25, 0)
	m.spread = 180.0
	m.flatness = 0.35
	m.initial_velocity_min = v_min
	m.initial_velocity_max = v_max
	m.damping_min = d_min
	m.damping_max = d_max
	m.gravity = Vector3(0, 0.12, 0)
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -30.0
	m.angular_velocity_max = 30.0
	m.scale_min = 0.8
	m.scale_max = 1.3
	m.turbulence_enabled = true
	m.turbulence_noise_strength = 0.8
	m.turbulence_noise_scale = 3.0
	m.turbulence_influence_min = 0.03
	m.turbulence_influence_max = 0.08
	# Swells as it slows: small and dense out of the pop, big and thin later.
	var size := Curve.new()
	size.add_point(Vector2(0.0, 0.3))
	size.add_point(Vector2(0.3, 0.85))
	size.add_point(Vector2(1.0, 1.3))
	var size_tex := CurveTexture.new()
	size_tex.curve = size
	m.scale_curve = size_tex
	# Fades in at once, holds, thins out; paler at first, greyer as it goes.
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
	g.colors = PackedColorArray([Color(LIGHT, 0.0), Color(LIGHT, lift), Color(MID, lift * 0.8), Color(DARK, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	m.color_ramp = ramp
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2.ONE * big * (radius / 2.5)
	q.material = _puff_material()
	p.draw_pass_1 = q
	p.position.y = 0.55
	p.emitting = true
	add_child(p)
	return p


## Along the floor: a wide, low layer that rolls out past the rest and
## hangs about once the cloud above has thinned.
func _build_floor_layer() -> void:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 4.5
	p.explosiveness = 0.7
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-radius * 2, -1, -radius * 2), Vector3(radius * 4, 2, radius * 4))
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	m.emission_ring_axis = Vector3(0, 1, 0)
	m.emission_ring_radius = 0.3
	m.emission_ring_inner_radius = 0.1
	m.emission_ring_height = 0.05
	m.direction = Vector3(1, 0, 0)
	m.spread = 180.0
	m.flatness = 1.0
	m.initial_velocity_min = radius * 1.4
	m.initial_velocity_max = radius * 2.0
	m.damping_min = radius * 1.7
	m.damping_max = radius * 2.3
	m.gravity = Vector3.ZERO
	m.angle_min = -180.0
	m.angle_max = 180.0
	m.angular_velocity_min = -20.0
	m.angular_velocity_max = 20.0
	var size := Curve.new()
	size.add_point(Vector2(0.0, 0.4))
	size.add_point(Vector2(1.0, 1.6))
	var size_tex := CurveTexture.new()
	size_tex.curve = size
	m.scale_curve = size_tex
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.1, 0.6, 1.0])
	g.colors = PackedColorArray([Color(LIGHT, 0.0), Color(LIGHT, 0.6), Color(MID, 0.5), Color(DARK, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = g
	m.color_ramp = ramp
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.9, 1.9) * (radius / 2.5)
	q.material = _puff_material()
	p.draw_pass_1 = q
	p.position.y = 0.2
	p.emitting = true
	add_child(p)
	_parts.append(p)


## Soft, lit, billboarded smoke: the texture's own lumps, the vertex colour
## for its fade, fading where it meets the floor and the walls instead of
## cutting a hard line through them.
func _puff_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _puff()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	# Light through it from behind, as smoke does.
	mat.backlight_enabled = true
	mat.backlight = Color(0.55, 0.55, 0.6)
	mat.proximity_fade_enabled = true
	mat.proximity_fade_distance = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = false
	return mat


## A lumpy soft ball of smoke: fractal noise, fading to nothing towards the
## edge, a little denser low on one side (as if lit from above).
static func _puff() -> Texture2D:
	if _puff_tex:
		return _puff_tex
	var size := 128
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = 5
	n.frequency = 0.035
	n.seed = 7
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			var r := sqrt(u * u + v * v)
			var lump := n.get_noise_2d(x, y) * 0.5 + 0.5
			# A soft disc whose edge the noise bites into.
			var edge := 1.0 - smoothstep(0.35, 1.0, r + (0.5 - lump) * 0.45)
			var a := clampf(edge * (0.55 + lump * 0.7), 0.0, 1.0)
			var shade := lerpf(0.78, 1.0, clampf(0.5 - v * 0.5 + lump * 0.3, 0.0, 1.0))
			img.set_pixel(x, y, Color(shade, shade, shade, a))
	img.generate_mipmaps()
	_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


static func _soft_dot() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var r := Vector2(x - 15.5, y - 15.5).length() / 16.0
			var a := clampf(1.0 - r, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)
