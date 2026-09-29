class_name NightEnv
extends RefCounted
## The night the museums are in: the Environment (cold blue ambient, ACES, glow, thin fog, contact
## shadows, the polished floor's reflections), the moon, the camera and the ears, and the
## warm soft mood of the band's house (DenView.mood). What Quality turns off in Baja is
## turned off through Quality.apply_environment and Quality.apply_light.

## Air thin enough not to veil the plan from 16 m up; the lights make up for it
## by scattering several times their share into it, so the beams still show.
const FOG_DENSITY := 0.012

## The night, graded: deep blue-violet shadows and a cold moon, so the warm
## practical lights and the torches are the only warm things on screen.
const AMBIENT_COLOUR := Color("#6256aa")
const AMBIENT_ENERGY := 0.6
const MOON_COLOUR := Color("#8ea2ff")
const MOON_ENERGY := 0.4
const BACKGROUND := Color("#0a0918")
const FOG_LENGTH := 25.0

var host: Game

## The "moon" light, and whether the world is in the band's house's mood
## (warm and soft, DenView.mood) instead of the museums' night.
var moon: DirectionalLight3D
var mood_home := false

## the Environment, for the fog to reach as far as the camera pulls back
var world_env: Environment


func _init(game: Game) -> void:
	host = game


## The environment, the moon, the camera and the ears, added to the game.
func build() -> void:
	world_env = _environment()
	var we := WorldEnvironment.new()
	we.environment = world_env
	host.add_child(we)
	_moonlight()
	host.camera = Camera3D.new()
	host.camera.fov = 50
	host.add_child(host.camera)
	# The ears are the thief's, not the camera's (high above): a guard's
	# steps grow as it comes near you, from the side it comes from.
	host.ear = AudioListener3D.new()
	host.add_child(host.ear)
	host.ear.make_current()


## The look of the night: colour, tonemapping, glow, fog and the screen-space effects.
func _environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = BACKGROUND
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The building is shut: what you see by is the torches, the room lights
	# once switched on, the lamps, and this blue night. Blue, not grey: a
	# haunted hotel, not a power cut.
	env.ambient_light_color = AMBIENT_COLOUR
	env.ambient_light_energy = AMBIENT_ENERGY
	# Filmic curve: a torch hotspot rolls off to white instead of clipping, and
	# the lamps keep their colour at full blast. Exposure up to make up for the
	# darker toe, then a push of saturation and contrast for the cartoon look.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.25
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.08
	# Bloom only on what is really bright (lamps, the lit exit, the piece, the
	# floor under a torch): a halo round each, the dark left dark.
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(5, 0.5)
	# A little dust in the air, so a torch is a beam you can see coming and a lit
	# room glows. Thin and unlit by the ambient, or the whole plan turns to milk.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = FOG_DENSITY
	env.volumetric_fog_albedo = Color("#c4c8ec")
	env.volumetric_fog_ambient_inject = 0.0
	# The camera is ~17 m from the floor: no need to spend froxels any further
	# (further when it pulls back to keep a gang in, _follow_camera).
	env.volumetric_fog_length = FOG_LENGTH
	env.volumetric_fog_anisotropy = 0.3
	# Contact shadows where cases and figures meet the floor and walls meet
	# corners; SSIL lets a lit room or a torch pool spill a little colour round.
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.ssil_enabled = true
	env.ssil_radius = 3.0
	# The polished floor mirrors the lamps and the lit exit (floor.gdshader
	# keeps it glossy); a short march is plenty from straight above.
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.1
	env.ssr_fade_out = 2.0
	Quality.apply_environment(env)
	return env


## Moonlight through the high windows: cold and faint, from one side. It
## shades the tops of walls and cases apart from their faces, and draws the
## rim round the figures in the dark (Figure's materials).
func _moonlight() -> void:
	moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.light_color = MOON_COLOUR
	moon.light_energy = MOON_ENERGY
	moon.light_volumetric_fog_energy = 0.0
	# Its shadows lay the walls and cases down on the floor in blue, which is
	# most of what gives the plan depth from above. The camera is never far
	# from the floor, so two splits over a short distance are plenty.
	moon.shadow_enabled = true
	moon.shadow_opacity = 0.85
	moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	Quality.apply_light(moon)
	host.add_child(moon)


## The house or the museums' night: the Environment and the moon changed only
## when the round moves from one to the other.
func set_mood(home: bool) -> void:
	if world_env == null or home == mood_home:
		return
	mood_home = home
	if home:
		DenView.mood(world_env, moon)
		return
	world_env.background_color = BACKGROUND
	world_env.ambient_light_color = AMBIENT_COLOUR
	world_env.ambient_light_energy = AMBIENT_ENERGY
	world_env.tonemap_exposure = 1.25
	world_env.tonemap_white = 6.0
	world_env.adjustment_saturation = 1.12
	world_env.adjustment_contrast = 1.08
	world_env.glow_intensity = 0.7
	world_env.glow_hdr_threshold = 1.0
	world_env.volumetric_fog_density = FOG_DENSITY
	world_env.volumetric_fog_albedo = Color("#c4c8ec")
	world_env.ssr_enabled = true
	world_env.ssil_enabled = true
	moon.light_color = MOON_COLOUR
	moon.light_energy = MOON_ENERGY
	moon.shadow_opacity = 0.85
