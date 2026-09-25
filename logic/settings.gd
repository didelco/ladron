class_name Settings
extends RefCounted
## The player's preferences, kept between sessions in a file of their own:
## the story's progress lives apart (Story.SAVE), so a bad settings file never
## costs anyone their nights.
##
## A plain dictionary in and out, with a default for every key: a file from
## an older version, or hand-edited, just falls back where it does not fit.

const DEFAULTS := {
	"sound": true,
	"music": true,
	"ia": false,
	"difficulty": "medium",
	"size": "small",
	"fullscreen": false,
	"vsync": true,
	# percent, in steps of VOLUME_STEP
	"music_volume": 100,
	"effects_volume": 100,
}
const VOLUME_STEP := 10
const SECTION := "settings"

## Where they are kept. Tests and recordings point it somewhere else (set it,
## or `godot -- --settings=<file>`), so as never to touch the player's own.
static var path := _default_path()


static func _default_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--settings="):
			return arg.substr(11)
	return "user://settings.cfg"


## The saved settings, or the defaults for whatever is missing or wrong.
static func read() -> Dictionary:
	var out := DEFAULTS.duplicate()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return out
	for k in DEFAULTS:
		var v: Variant = cfg.get_value(SECTION, k, DEFAULTS[k])
		if typeof(v) == typeof(DEFAULTS[k]):
			out[k] = v
	if not out.difficulty in ["easy", "medium", "hard"]:
		out.difficulty = DEFAULTS.difficulty
	if not out.size in ["small", "medium", "large"]:
		out.size = DEFAULTS.size
	for k in ["music_volume", "effects_volume"]:
		out[k] = volume(out[k])
	return out


static func write(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in DEFAULTS:
		cfg.set_value(SECTION, k, values.get(k, DEFAULTS[k]))
	cfg.save(path)


## A volume as the menu offers it: 0 to 100 in steps of ten.
static func volume(percent: int) -> int:
	return clampi(snappedi(percent, VOLUME_STEP), 0, 100)


## Full screen or a window, and v-sync. Only touches the window when it has
## to change, so a maximised window stays maximised; nothing to do without one.
static func apply_display(fullscreen: bool, vsync: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
