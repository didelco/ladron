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
	# the window's size: an index into WINDOW_SIZES, or -1 for the biggest
	# that fits the screen
	"window": -1,
	# how big menus and HUD are, percent, in steps of 10
	"ui_scale": 100,
	# percent, in steps of VOLUME_STEP
	"music_volume": 100,
	"effects_volume": 100,
	# gamepads
	"rumble": true,
	"rumble_strength": 100,
	# percent of the stick's travel ignored round the centre
	"deadzone": 50,
	# pad 1 plays P1 and pad 0 plays P2
	"swap_pads": false,
	# two players: "keys" (both on the keyboard), "mixed" (keyboard and a pad),
	# "pads" (a pad each)
	"input_mode": "keys",
}
const VOLUME_STEP := 10
## Window sizes on offer (16:9); only those that fit the screen are used.
const WINDOW_SIZES := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3200, 1800), Vector2i(3840, 2160)]
const UI_SCALE_MIN := 70
const UI_SCALE_MAX := 150
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
	if not out.input_mode in ["keys", "mixed", "pads"]:
		out.input_mode = DEFAULTS.input_mode
	if not out.size in ["small", "medium", "large"]:
		out.size = DEFAULTS.size
	for k in ["music_volume", "effects_volume", "rumble_strength"]:
		out[k] = volume(out[k])
	out.deadzone = clampi(snappedi(out.deadzone, VOLUME_STEP), 20, 80)
	out.window = clampi(out.window, -1, WINDOW_SIZES.size() - 1)
	out.ui_scale = clampi(snappedi(out.ui_scale, 10), UI_SCALE_MIN, UI_SCALE_MAX)
	return out


static func write(values: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in DEFAULTS:
		cfg.set_value(SECTION, k, values.get(k, DEFAULTS[k]))
	cfg.save(path)


## A volume as the menu offers it: 0 to 100 in steps of ten.
static func volume(percent: int) -> int:
	return clampi(snappedi(percent, VOLUME_STEP), 0, 100)


## The pads as set: how far the stick must go before it counts, and which
## pad plays which thief. Rewrites the p1_*/p2_* actions' joypad events.
## With the keyboard and one pad ("mixed"), the first pad is P2's and P1 has
## none (a device number no pad has).
static func apply_pads(deadzone: int, swap: bool, input_mode := "pads") -> void:
	for player in ["p1", "p2"]:
		var device := (0 if player == "p1" else 1) if not swap else (1 if player == "p1" else 0)
		if input_mode == "mixed":
			device = 0 if player == "p2" else 15
		for dir in ["up", "down", "left", "right", "crouch", "push"]:
			var action := "%s_%s" % [player, dir]
			if not InputMap.has_action(action):
				continue
			InputMap.action_set_deadzone(action, deadzone / 100.0)
			for e in InputMap.action_get_events(action):
				if e is InputEventJoypadButton or e is InputEventJoypadMotion:
					var moved: InputEvent = e.duplicate()
					moved.device = device
					InputMap.action_erase_event(action, e)
					InputMap.action_add_event(action, moved)


## The window sizes that fit this screen (always at least the smallest).
static func fitting_sizes() -> Array:
	if DisplayServer.get_name() == "headless":
		return [WINDOW_SIZES[0]]
	var room := DisplayServer.screen_get_usable_rect().size
	var out: Array = WINDOW_SIZES.filter(func(w): return w.x <= room.x and w.y <= room.y)
	return out if not out.is_empty() else [WINDOW_SIZES[0]]


## The size a window setting stands for: -1 is the biggest that fits.
static func window_size(index: int) -> Vector2i:
	var fits := fitting_sizes()
	return fits[-1] if index < 0 else fits[mini(index, fits.size() - 1)]


## Full screen or a window, and v-sync. Only touches the mode when it has to
## change; with resize, a window is set to the chosen size and centred.
## Nothing to do without a window.
static func apply_display(fullscreen: bool, vsync: bool, window := -1, resize := true) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_full := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen != is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if resize and not fullscreen:
		var size := window_size(window)
		var room := DisplayServer.screen_get_usable_rect()
		DisplayServer.window_set_size(size)
		DisplayServer.window_set_position(room.position + (room.size - size) / 2)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
