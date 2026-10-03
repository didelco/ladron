class_name Quality
extends RefCounted
## Graphics quality, for machines that struggle: "high" is the look the game
## was made with, "low" trades the costly effects (screen-space reflections and
## light bounce, volumetric fog, ambient occlusion, long shadows, smoke
## particles, MSAA 4x) for frames.
##
## What is set lives here (static), so every 3D viewport built later starts
## right (setup_viewport); apply_tree() re-does the ones already there.

const LEVELS := ["high", "low"]

static var level := "high"


static func is_low() -> bool:
	return level == "low"


## Whether the game is running under the Compatibility (OpenGL 3.3) renderer,
## where volumetric fog, SSAO, SSIL, SSR and depth of field do not exist —
## Quality.apply_environment/apply_light turn them off regardless of `level`,
## whether the player picked "Alta" or not, so nothing warns or misbehaves.
static func is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


## A level as saved, or "high" for anything else.
static func valid_level(v: Variant) -> String:
	return v if v is String and v in LEVELS else LEVELS[0]


static func set_state(new_level: String) -> void:
	level = valid_level(new_level)


## MSAA for the 3D viewports: 4x, or 2x in low.
static func msaa() -> Viewport.MSAA:
	return Viewport.MSAA_2X if is_low() else Viewport.MSAA_4X


## MSAA on a 3D viewport (menus, city, HUD portraits...).
static func setup_viewport(vp: Viewport) -> void:
	vp.msaa_3d = msaa()


## The night's environment: the costly effects on in high, off in low, and
## always off in Compatibility (none of the four exist there — Forward+ only).
static func apply_environment(env: Environment) -> void:
	var on := not is_low() and not is_compatibility()
	env.volumetric_fog_enabled = on
	env.ssao_enabled = on
	env.ssil_enabled = on
	env.ssr_enabled = on


## The moon's shadows: two splits out to 35 m in high, one to 20 in low.
static func apply_light(light: DirectionalLight3D) -> void:
	if is_low():
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		light.directional_shadow_max_distance = 20.0
	else:
		light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		light.directional_shadow_max_distance = 35.0


## The smoke bomb's particles (the cloud itself, what hides you, is the game's).
static func smoke_particles() -> bool:
	return not is_low()


## Pixels the main window's 3D render is allowed, before the scale below
## kicks in: ~1440p (2560×1440). Measured (performance agent): on a 5K
## screen the render goes to the physical pixel count with no cap at all —
## 16× a 1280×720 design — and every light/shadow/postprocess is paid per
## pixel, so FPS falls from 93 to 13 with several guards chasing. The game's
## look (flat colour, no high-frequency detail) hides a softer 3D image
## well, so trading resolution for frames here costs nothing visible beyond
## a little less crispness — the HUD (2D, untouched by this) stays sharp.
## 1440p is high enough that normal/laptop screens (the vast majority) never
## hit it and render native; only 1440p+/4K/5K screens, where the problem
## was measured, are scaled down.
const RENDER_TARGET_PIXELS := 2560 * 1440
## Never scaled below this: much softer and the flat-colour look starts to
## smear rather than just lose crispness.
const RENDER_SCALE_MIN := 0.5


## The main window's 3D resolution, capped to RENDER_TARGET_PIXELS: native
## (scale 1.0) under the cap, otherwise the scale that brings the actual
## pixel count down to it (area scales with the square of the linear
## factor, hence the sqrt). Godot's own bilinear upscale (not FSR: this
## project runs the Compatibility renderer, where FSR's support is not
## certain) draws the smaller image back up to the window's real size.
## Only the main window: SubViewports (menus, portraits) are setup_viewport's.
static func apply_render_scale(viewport: Viewport) -> void:
	var size: Vector2i = viewport.size
	var actual_pixels: int = size.x * size.y
	var scale := 1.0
	if actual_pixels > RENDER_TARGET_PIXELS:
		scale = maxf(RENDER_SCALE_MIN, sqrt(float(RENDER_TARGET_PIXELS) / float(actual_pixels)))
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = scale


## MSAA on every 3D viewport below the main window (not the window's own
## MSAA, which is off).
static func apply_tree(tree: SceneTree) -> void:
	_walk(tree.root)


static func _walk(node: Node) -> void:
	for c in node.get_children():
		if c is SubViewport:
			setup_viewport(c)
		_walk(c)
