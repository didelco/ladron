class_name DevOverlay
extends CanvasLayer
## Diagnostics visible over gameplay and menus, including while paused.
var _fps: Label
## the night's own line under the FPS: mode, siren, intruder, theft (DevInfo)
var _night: Label
var _elapsed := 0.0
var _night_elapsed := 0.0


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
	_night = Label.new()
	_night.position = Vector2(12, 36)
	_night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_night.add_theme_font_size_override("font_size", 16)
	_night.add_theme_color_override("font_color", Hud.CREAM)
	_night.add_theme_color_override("font_outline_color", Hud.INK)
	_night.add_theme_constant_override("outline_size", 6)
	add_child(_night)
	set_enabled(false)


func set_enabled(on: bool) -> void:
	visible = on
	set_process(on)
	_elapsed = 0.0
	_night_elapsed = 0.0
	_night.text = ""
	if on:
		_update_fps()
		_update_night()


func _update_fps() -> void:
	_fps.text = "FPS: %d" % Engine.get_frames_per_second()


## The state of the night, only while a night is on (guards in play).
func _update_night() -> void:
	var host := get_parent() as Game
	if host == null or host.guards.is_empty() or not host.phase in ["playing", "paused", "countdown"]:
		_night.text = ""
		return
	_night.text = DevInfo.night_text(host.guards)


func _process(dt: float) -> void:
	_night_elapsed += dt
	if _night_elapsed >= 0.1:
		_night_elapsed = 0.0
		_update_night()
	_elapsed += dt
	if _elapsed >= 0.25:
		_elapsed = 0.0
		_update_fps()
