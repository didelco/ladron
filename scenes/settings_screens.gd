class_name SettingsScreens
extends RefCounted
## The settings screens (sound, screen, pads, the loudspeaker, the IA panel), and what
## is kept of them: read at the start (load_all), applied as each line moves (step) and saved. The values themselves (sound_on, fullscreen, ...) live in Game, which
## the rest of the game reads them from.

var host: Game

## where the settings screen goes back to: "title" or "paused"
var settings_from := "title"

## the settings page on show: "" for the main one, or "sound", "screen", "pads" (the controls) or "options"
var settings_page := ""


func _init(game: Game) -> void:
	host = game


## The settings: SONIDO, PANTALLA, CONTROLES and OPCIONES (loudspeaker, IA panel). Opens from
## the title and from the pause. Each line is a setting (Hud._stepper): accept
## or a click moves it on, ← and → move it down and up; each change is saved.
func show(from: String, page := "") -> void:
	if from == "title":
		host.hud.backdrop(Hud.SPOTS.settings)
	host.podium.drop()
	settings_from = from
	settings_page = page
	host.phase = "settings"
	var keys: Array = {
		"": [],
		"sound": ["sound", "music", "music_volume", "effects_volume"],
		"screen": ["fullscreen", "window", "ui_scale", "quality", "render_scale", "vsync"],
		"pads": ["rumble", "rumble_strength", "deadzone"],
		"options": ["megaphone", "ia"],
	}[page]
	var rows: Array = []
	if page == "":
		rows.append({"text": Text.t("SETTINGS_SOUND_PAGE"), "call": show.bind(from, "sound")})
		rows.append({"text": Text.t("SETTINGS_SCREEN_PAGE"), "call": show.bind(from, "screen")})
		rows.append({"text": Text.t("SETTINGS_CONTROLS_PAGE"), "call": show.bind(from, "pads")})
		rows.append({"text": Text.t("SETTINGS_OPTIONS_PAGE"), "call": show.bind(from, "options")})
	for k in keys:
		rows.append({"text": text_of(k), "step": step.bind(k), "help": Text.t("SETTINGS_HELP_" + k.to_upper())})
	rows.append({"text": Text.t("MENU_BACK"), "call": back, "colour": Hud.C.dim})
	var title := Text.t({"": "MENU_SETTINGS", "sound": "SETTINGS_SOUND_TITLE", "screen": "SETTINGS_SCREEN_TITLE", "pads": "SETTINGS_CONTROLS_TITLE", "options": "SETTINGS_OPTIONS_TITLE"}[page])
	var items: Array = [{"title": title, "size": 48}]
	if page != "":
		items.append({"text": Text.t("SETTINGS_ADJUST_HELP"), "size": 15, "wrap": true, "width": 570, "colour": Hud.C.text})
	items.append({"buttons": rows})
	match page:
		"sound":
			items.append({"text": Text.t("SETTINGS_SOUND_HELP"), "size": 16, "colour": Hud.C.dim})
		"pads":
			var pads := Input.get_connected_joypads()
			var names: Array = pads.map(func(d): return Pads.describe(d))
			items.append({"text": (Text.t("SETTINGS_PADS_LIST") % " · ".join(names)) if not pads.is_empty() else Text.t("SETTINGS_NO_PADS"), "size": 16, "colour": Hud.C.gold})
			items.append(controls_table())
			items.append({"text": Text.t("CONTROLS_MORE"), "size": 15, "colour": Hud.C.dim})
	host.hud.show_menu(items, "settings:" + page)


## What does what, for the controls page: an action a row, and its key for
## each keyboard half and its pad button across. A row's text is its cells
## split by "|"; one with a single key for both keyboards (M, P, N) spans them.
func controls_table() -> Dictionary:
	var rows: Array = [
		["", Text.t("CONTROLS_P1"), Text.t("CONTROLS_P2"), Text.t("CONTROLS_PAD")],
		["", Text.t("CONTROLS_P1_WHERE"), Text.t("CONTROLS_P2_WHERE"), Text.t("CONTROLS_PAD_WHERE")],
	]
	# The main action first, then the way out, then the rest. P2's keys by
	# what they say on this keyboard ({slash}: "-" on a Spanish one).
	for key in ["CONTROLS_MOVE", "CONTROLS_PUSH", "CONTROLS_ROLL", "CONTROLS_CROUCH", "CONTROLS_SLOW", "CONTROLS_SMOKE", "CONTROLS_MAP", "CONTROLS_PAUSE", "CONTROLS_MUTE"]:
		var line := Text.t(key).replace("{slash}", Hands.key_label(KEY_SLASH)).replace("{period}", Hands.key_label(KEY_PERIOD)).replace("{comma}", Hands.key_label(KEY_COMMA))
		var cells: Array = Array(line.split("|"))
		if cells.size() == 3:
			cells[1] = {"text": cells[1], "span": 2}
		rows.append(cells)
	return {"table": rows, "widths": [200, 170, 170, 240], "heads": 2}


func text_of(key: String) -> String:
	var yes := func(on: bool) -> String: return Text.t("SETTINGS_YES") if on else Text.t("SETTINGS_NO")
	match key:
		"sound": return Text.t("SETTINGS_SOUND") % yes.call(host.sound_on)
		"music": return Text.t("SETTINGS_MUSIC") % yes.call(host.music_on)
		"music_volume": return Text.t("SETTINGS_MUSIC_VOLUME") % volume_bar(host.music_volume)
		"effects_volume": return Text.t("SETTINGS_EFFECTS_VOLUME") % volume_bar(host.effects_volume)
		"fullscreen": return Text.t("SETTINGS_FULLSCREEN") % yes.call(host.fullscreen)
		"vsync": return Text.t("SETTINGS_VSYNC") % yes.call(host.vsync)
		"window":
			var w := Settings.window_size(host.window)
			return Text.t("SETTINGS_WINDOW_AUTO" if host.window < 0 else "SETTINGS_WINDOW") % [w.x, w.y]
		"ui_scale": return Text.t("SETTINGS_UI_SCALE") % host.ui_scale
		"quality": return Text.t("SETTINGS_QUALITY") % Text.t("SETTINGS_QUALITY_LOW" if Quality.is_low() else "SETTINGS_QUALITY_HIGH")
		"render_scale": return Text.t("SETTINGS_RENDER_SCALE") % Quality.scale
		"ia": return Text.t("SETTINGS_IA") % yes.call(host.show_ia)
		"megaphone": return Text.t("SETTINGS_MEGAPHONE") % Text.t("SETTINGS_MEGAPHONE_" + host.megaphone_mode.to_upper())
		"rumble": return Text.t("SETTINGS_RUMBLE") % yes.call(host.rumble)
		"rumble_strength": return Text.t("SETTINGS_RUMBLE_STRENGTH") % volume_bar(host.rumble_strength)
		"deadzone": return Text.t("SETTINGS_DEADZONE") % host.deadzone
	return key


## |||||····· 50%: a bar a step, in glyphs the arcade font has (it has no
## blocks, and the fallback's come out as hairlines).
func volume_bar(percent: int) -> String:
	var on: int = percent / Settings.VOLUME_STEP
	return "%s%s %d%%" % ["|".repeat(on), "·".repeat(100 / Settings.VOLUME_STEP - on), percent]


## One setting changed from its button: a yes/no flips whichever way; a
## volume goes down or up a step with ← and → (stopping at the ends), and up
## with accept (E, A), round from 100 back to 0. Applied, saved, and the button's
## new text returned.
func step(dir: int, key: String) -> String:
	match key:
		"sound": set_sound(not host.sound_on)
		"music": toggle_music()
		"ia": toggle_ia()
		"megaphone":
			# Both, notice only, voice only, off, round again.
			var modes := Settings.MEGAPHONE_MODES
			set_megaphone_mode(modes[posmod(modes.find(host.megaphone_mode) + (1 if dir >= 0 else -1), modes.size())])
		"fullscreen", "vsync":
			host.set(key, not host.get(key))
			Settings.apply_display(host.fullscreen, host.vsync, host.window, key == "fullscreen")
		"window":
			# Auto, then each size that fits, round again.
			var count := Settings.fitting_sizes().size()
			host.window = posmod(host.window + 1 + (1 if dir >= 0 else -1), count + 1) - 1
			Settings.apply_display(host.fullscreen, host.vsync, host.window)
		"ui_scale":
			host.ui_scale = Settings.UI_SCALE_MIN if dir == 0 and host.ui_scale >= Settings.UI_SCALE_MAX else clampi(host.ui_scale + (10 if dir >= 0 else -10), Settings.UI_SCALE_MIN, Settings.UI_SCALE_MAX)
			apply_ui_scale()
		"quality", "render_scale":
			step_quality(key)
		"rumble":
			host.rumble = not host.rumble
			# Feel it straight away.
			if key == "rumble" and host.rumble:
				host.hands.rumble(0.4, 0.4, 0.2)
		"rumble_strength":
			host.rumble_strength = 0 if dir == 0 and host.rumble_strength >= 100 else Settings.volume(host.rumble_strength + (Settings.VOLUME_STEP if dir >= 0 else -Settings.VOLUME_STEP))
			host.hands.rumble(0.4, 0.4, 0.2)
		"deadzone":
			host.deadzone = 20 if dir == 0 and host.deadzone >= 80 else clampi(host.deadzone + (10 if dir >= 0 else -10), 20, 80)
		"music_volume", "effects_volume":
			var v: int = host.get(key)
			if dir == 0:
				v = 0 if v >= 100 else v + Settings.VOLUME_STEP
			else:
				v = Settings.volume(v + dir * Settings.VOLUME_STEP)
			host.set(key, v)
			host.sfx.set_volumes(host.music_volume / 100.0, host.effects_volume / 100.0)
	save()
	return text_of(key)


## Graphics quality flips; the 3D render scale goes to the next on offer.
func step_quality(key: String) -> void:
	if key == "quality":
		Quality.set_state("high" if Quality.is_low() else "low", Quality.scale)
	else:
		Quality.set_state(Quality.level, Quality.next_scale(Quality.scale))
	apply_quality()


## Quality and render scale, applied to the night and to every 3D viewport.
func apply_quality() -> void:
	if host.nightenv.world_env:
		Quality.apply_environment(host.nightenv.world_env)
	if host.nightenv.moon:
		Quality.apply_light(host.nightenv.moon)
	Quality.apply_tree(host.get_tree())


func set_sound(on: bool) -> void:
	host.sound_on = on
	AudioServer.set_bus_mute(0, not on)
	save()


func toggle_music() -> void:
	host.music_on = not host.music_on
	host.sfx.set_music(host.music_on)


## The loudspeaker's mode changed, in the settings or while playing (from the
## pause): the notice on screen goes away without a notice mode, the voice is
## cut off without a voice mode.
func set_megaphone_mode(m: String) -> void:
	host.megaphone_mode = m
	if not Settings.megaphone_text(m):
		host.hud.megaphone("")
	if not Settings.megaphone_sound(m):
		host.mega_voice.stop()


func toggle_ia() -> void:
	host.show_ia = not host.show_ia


## What was saved last time, applied: sound, music and volumes, the screen,
## and the generative mode's last difficulty and size.
func load_all() -> void:
	var s := Settings.read()
	host.sound_on = s.sound
	host.music_on = s.music
	host.show_ia = s.ia
	host.megaphone_mode = s.megaphone_mode
	Sim.difficulty = s.difficulty
	host.size = s.size
	host.theme = s.theme
	host.fullscreen = s.fullscreen
	host.vsync = s.vsync
	host.window = s.window
	host.ui_scale = s.ui_scale
	Quality.set_state(s.quality, s.render_scale)
	host.music_volume = s.music_volume
	host.effects_volume = s.effects_volume
	host.rumble = s.rumble
	host.rumble_strength = s.rumble_strength
	host.deadzone = s.deadzone

	AudioServer.set_bus_mute(0, not host.sound_on)
	host.sfx.set_music(host.music_on)
	host.sfx.set_volumes(host.music_volume / 100.0, host.effects_volume / 100.0)
	Settings.apply_display(host.fullscreen, host.vsync, host.window)
	apply_ui_scale()
	Quality.apply_tree(host.get_tree())


## Menus and HUD drawn bigger or smaller, whatever the window's size: the
## 2D is laid out for 1280×720 and scaled to the window, times this.
func apply_ui_scale() -> void:
	host.get_window().content_scale_factor = host.ui_scale / 100.0


func save() -> void:
	Settings.write({
		"sound": host.sound_on, "music": host.music_on, "ia": host.show_ia, "megaphone_mode": host.megaphone_mode,
		"difficulty": Sim.difficulty, "size": host.size, "theme": host.theme,
		"fullscreen": host.fullscreen, "vsync": host.vsync, "window": host.window, "ui_scale": host.ui_scale,
		"quality": Quality.level, "render_scale": Quality.scale,
		"music_volume": host.music_volume, "effects_volume": host.effects_volume,
		"rumble": host.rumble, "rumble_strength": host.rumble_strength,
		"deadzone": host.deadzone,
	})


func back() -> void:
	if settings_page != "":
		show(settings_from)
	elif settings_from == "paused":
		host._pause()
	else:
		host._show_title()
