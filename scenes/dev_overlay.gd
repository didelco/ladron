class_name DevOverlay
extends CanvasLayer
## Diagnostics visible over gameplay and menus, including while paused.
var _fps: Label
var _elapsed := 0.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fps = Label.new()
	_fps.position = Vector2(12, 10)
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.add_theme_font_size_override("font_size", 18)
	_fps.add_theme_color_override("font_color", Hud.CREAM)
	_fps.add_theme_color_override("font_outline_color", Hud.INK)
	_fps.add_theme_constant_override("outline_size", 6)
	add_child(_fps)
	set_enabled(false)


func set_enabled(on: bool) -> void:
	visible = on
	set_process(on)
	_elapsed = 0.0
	if on:
		_update_fps()


func _update_fps() -> void:
	_fps.text = "FPS: %d" % Engine.get_frames_per_second()


func _process(dt: float) -> void:
	_elapsed += dt
	if _elapsed >= 0.25:
		_elapsed = 0.0
		_update_fps()
