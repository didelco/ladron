class_name ScreenFx
extends CanvasLayer
## The finish over the museum, like a lens: the corners sinking into the
## night's blue, a fine film grain, and a hair of colour fringe towards the
## edges. And the red flash round the edges when a guard spots you (flash).
##
## Drawn over the 3D and under the HUD and every screen (they are layer 1 and
## up), so words and menus stay crisp. A 2D shader over a copy of the screen:
## the same in Baja and in Compatibility, and it costs next to nothing.
## Gentle on purpose: in a stealth game reading the light is the game, so the
## middle of the screen, where the gang is, is never touched.

## Under the HUD (layer 1), over the 3D.
const LAYER := -1

## How much the corners darken (0 none, 1 all the way to VIGNETTE_TINT), and
## the colour they sink into: the night's blue-violet, not grey.
const VIGNETTE := 0.42
const VIGNETTE_TINT := Color("#4a4470")

## The grain: up to this much of full brightness either way, a new pattern
## 24 times a second, like film.
const GRAIN := 0.035

## The colour fringe at the very corners, as a share of the screen; none in
## the middle.
const ABERRATION := 0.0018

## The flash: how strong at its peak, and how long it takes to come and go (s).
const FLASH_PEAK := 0.16
const FLASH_IN := 0.05
const FLASH_OUT := 0.2

var _look: ColorRect
var _flash: TextureRect
var _flash_tween: Tween


func _init() -> void:
	layer = LAYER
	_look = ColorRect.new()
	_look.set_anchors_preset(Control.PRESET_FULL_RECT)
	_look.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _lens_shader()
	m.set_shader_parameter("vignette", VIGNETTE)
	m.set_shader_parameter("vignette_tint", VIGNETTE_TINT)
	m.set_shader_parameter("grain", GRAIN)
	m.set_shader_parameter("aberration", ABERRATION)
	_look.material = m
	add_child(_look)
	# The flash: white, tinted by self_modulate, faded by modulate. Stronger
	# at the edges than in the middle, where the gang is.
	_flash = TextureRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_flash.texture = _edge_glow()
	_flash.modulate.a = 0.0
	_flash.visible = false
	add_child(_flash)


## The screen goes `colour` round the edges for a blink: in quickly, out
## softly. A guard's first yell (NightLoop._first_yell) flashes it red.
func flash(colour: Color = Game.COLOURS.alert, strength := 1.0) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash.self_modulate = colour
	_flash.modulate.a = 0.0
	_flash.visible = true
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "modulate:a", FLASH_PEAK * strength, FLASH_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, FLASH_OUT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_flash_tween.tween_callback(func() -> void: _flash.visible = false)


## White, a little see-through in the middle and solid at the edges (stretched
## to the screen, so an ellipse).
static func _edge_glow() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.4))
	g.set_color(1, Color(1, 1, 1, 1.0))
	g.add_point(0.55, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t


## Vignette, fringe and grain, over what the 3D drew.
static func _lens_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen : hint_screen_texture, filter_linear, repeat_disable;
uniform float vignette = 0.42;
uniform vec3 vignette_tint : source_color = vec3(0.29, 0.27, 0.44);
uniform float grain = 0.035;
uniform float aberration = 0.0018;

// A hash without sin(), so it does not band on some GPUs.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_mid = uv - 0.5;
	// How far out, 0 in the middle and 1 in the corners, whatever the
	// screen's shape.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	float r = length(from_mid * vec2(aspect, 1.0)) / length(vec2(aspect, 1.0) * 0.5);
	// Red out a hair, blue in a hair: only towards the corners.
	vec2 off = from_mid * r * r * aberration * 2.0;
	vec3 col = vec3(
		texture(screen, uv + off).r,
		texture(screen, uv).g,
		texture(screen, uv - off).b);
	// The corners sink into the night, the middle half untouched.
	float v = smoothstep(0.5, 1.15, r);
	col *= mix(vec3(1.0), vignette_tint, v * vignette);
	// Grain at 24 frames a second, the same few dozen patterns round again
	// (so the numbers never grow big enough to lose precision).
	float frame = mod(floor(TIME * 24.0), 61.0);
	col += (hash(FRAGCOORD.xy + frame * vec2(37.0, 17.0)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
"""
	return sh
