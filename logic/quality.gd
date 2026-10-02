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


## MSAA on every 3D viewport below the main window (not the window's own
## MSAA, which is off).
static func apply_tree(tree: SceneTree) -> void:
	_walk(tree.root)


static func _walk(node: Node) -> void:
	for c in node.get_children():
		if c is SubViewport:
			setup_viewport(c)
		_walk(c)
