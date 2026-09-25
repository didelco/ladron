extends Node3D
## The game: screens, the loop, and drawing the world each frame.
##
## Two modes. The story: ten fixed nights, easy to hard, with a tale (Story).
## The generative: a new museum every time, at the difficulty and size you
## pick. Either with one thief or two; with two, the job takes both (Heist).
##
## Screens: title (pick the mode) → the mode's menu (players, and the night or
## the difficulty) → [prologue] → loot (the piece and its story) → mission
## (the plan, a map) → countdown → playing ⇄ paused → caught, or escaped with the piece (next level). No
## clock: a round lasts as long as it takes. The loop is the web version's Game.tsx tick: thieves and their
## noise, the job and its alarm, guards, the yell, the warning, keeping apart,
## lights, thinking (Laya through BrainClient, or the fallback rules),
## hidden, caught.

## the guards think this often
const THINK_EVERY_MS := 1100.0
const SIZE_NAMES := {"small": "CHICO", "medium": "MEDIANO", "large": "GRANDE"}
const DIFFICULTY_NAMES := {"easy": "FÁCIL", "medium": "MEDIA", "hard": "DIFÍCIL"}
## What a guard yells on spotting you.
const SHOUTS := ["¡ALTO!", "¡QUIETO!", "¡PARA!"]

const COLOURS := {
	"night": Color("#0f0d14"),
	"thief": Color("#2ec4a6"),
	"thief_dark": Color("#12705f"),
	"thief2": Color("#f0a13a"),
	"thief2_dark": Color("#8a5410"),
	"guard": Color("#9b2c3f"),
	"guard_dark": Color("#5e1826"),
	"ink": Color("#08070c"),
	"alert": Color("#ff3d6e"),
	"cone": Color("#ffd479"),
	"cone_alert": Color("#ffa94d"),
	"lit": Color("#eef3ff"),
	"switch_off": Color("#f87171"),
	"switch_on": Color("#4ade80"),
	"safe": Color("#22d3ee"),
}

## Physical keys the game reads, by the names Sim.SCHEMES uses.
const KEYS := {
	KEY_W: "w", KEY_A: "a", KEY_S: "s", KEY_D: "d",
	KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right",
	KEY_C: "c", KEY_SHIFT: "shift", KEY_MINUS: "minus", KEY_SLASH: "slash",
	KEY_E: "e", KEY_PERIOD: "period",
}
## A fixed handful of room lights, handed to the lit rooms nearest the camera.
const ROOM_LIGHT_POOL := 4
const CONE_RAYS := 40
## Air thin enough not to veil the plan from 16 m up; the lights make up for it
## by scattering several times their share into it, so the beams still show.
const FOG_DENSITY := 0.012
const TORCH_FOG := 12.0
const ROOM_FOG := 4.0
## The torch is the hero light: a crisp near-white beam that owns the dark,
## brighter when its guard is on the hunt. Its colour is warmer than the moon
## and cooler than the lamps, so it never reads as either.
const TORCH_COLOUR := Color("#fff1d8")
const TORCH_ENERGY := 9.0
const TORCH_ENERGY_ALERT := 13.0
## Lit rooms glow warm, like a hotel lobby with the chandeliers on.
const ROOM_LIGHT_COLOUR := Color("#ffc47e")
const ROOM_LIGHT_ENERGY := 1.4
## How much the flat wash over a lit room adds: the room must read as lit at
## a glance, but through the tonemapper a strong wash burns it to cream.
const ROOM_WASH := 0.07
## The night, graded: deep blue-violet shadows and a cold moon, so the warm
## practical lights and the torches are the only warm things on screen.
const AMBIENT_COLOUR := Color("#6256aa")
const AMBIENT_ENERGY := 0.6
const MOON_COLOUR := Color("#8ea2ff")
const MOON_ENERGY := 0.4
const BACKGROUND := Color("#0a0918")

## "story" or "generative"
var mode := "story"
## the story night picked on its menu
var story_pick := 1
var size := "small"
## one thief or two on the same keyboard
var players := 1
var sound_on := true
var music_on := true
var show_ia := false
var fullscreen := false
var vsync := true
## percent, 0..100 in steps of ten
var music_volume := 100
var effects_volume := 100
## where the settings screen goes back to: "title" or "paused"
var settings_from := "title"
## the settings page on show: "" for the main one, or "sound", "screen", "pads"
var settings_page := ""
var rumble := true
var rumble_strength := 100
var deadzone := 50
## Who plays with what: one entry per thief — "any" (on your own: the whole
## keyboard and every pad), "kb_left" (WASD side), "kb_right" (arrows side)
## or "pad:N". Picked on the player-select screen, Mario Kart style.
var seats: Array[String] = ["any"]
## the seats taken so far on the player-select screen, and for which mode
var joining: Array[String] = []
var join_for := "story"
## the map is out: the thieves stand still to read it, the guards do not
var map_open := false
var level := 1
var thieves: Array[Thief] = []
var guards: Array[Guard] = []
var phase := "title"
var stride := [0.0, 0.0]
## the push key held last frame, per thief: one push per press
var push_held := [false, false]
var last_think := 0.0
var last_spread := 0.0
var think_tick := 0
var log_lines: Array[String] = []

var brain: BrainClient
var sfx: Sfx
var hud: Hud
var world: Node3D
var camera: Camera3D
var thief_nodes: Array[Figure] = []
var guard_nodes: Array[Figure] = []
var torches: Array[SpotLight3D] = []
var room_lights: Array[OmniLight3D] = []
var cones: Array[MeshInstance3D] = []
var switch_marks: Array[MeshInstance3D] = []
var lit_washes: Array[MeshInstance3D] = []
var loot_node: Node3D
## the spotlight straight down on the piece's case, museum style
var loot_spot: SpotLight3D
var props_view: PropsView
var ear: AudioListener3D
## each guard's position last frame and the distance walked since its last step
var guard_steps: Array = []
## the alarm panel, two thieves only: its lamp and glow, red till held
var panel_mat: StandardMaterial3D
var panel_glow: OmniLight3D
## the piece turning on its own stand, on the loot screen
var preview: SubViewport
var preview_pivot: Node3D
var preview_spot: OmniLight3D


func _ready() -> void:
	# The map: Y or Select/Back on any pad (M on the keyboard, by hand).
	if not InputMap.has_action("map"):
		InputMap.add_action("map")
		for button in [JOY_BUTTON_Y, JOY_BUTTON_BACK]:
			var e := InputEventJoypadButton.new()
			e.button_index = button
			e.device = -1
			InputMap.action_add_event("map", e)
	# The pause stops the tree (and the physics with it), but not the game
	# itself: its keys, the menus and the music go on. The world only moves
	# in _tick, which the pause does not run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	brain = BrainClient.new()
	add_child(brain)
	brain.decided.connect(_on_decided)
	brain.failed.connect(_on_brain_failed)
	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	hud.ui_sound.connect(func(kind: String) -> void: sfx.ui(kind, 0.6))
	_load_settings()
	_build_environment()
	# A museum behind the title screen, so it is not a black void.
	_new_round(1)
	_show_title()
	# For recording and testing: `godot -- --autostart` skips the title, shows
	# the mission for two seconds and starts the round; add --two for two thieves.
	# --menu=story|generative|settings: open a menu straight away, to look at it.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):
			match arg.substr(7):
				"story": _show_story_menu()
				"generative": _show_generative_menu()
				"settings": _show_settings("title")
				"pads": _show_settings("title", "pads")
				"input": _show_join("generative")
				"end":
					phase = "caught"
					_show_end()
	# --intro: the piece, then the countdown, for checking the way in.
	if "--intro" in OS.get_cmdline_user_args():
		_start("generative" if "--gen" in OS.get_cmdline_user_args() else "story", 2 if "--two" in OS.get_cmdline_user_args() else 1)
		get_tree().create_timer(1.5).timeout.connect(_start_countdown)
	if "--autostart" in OS.get_cmdline_user_args():
		if "--two" in OS.get_cmdline_user_args():
			players = 2
			_new_round(1)
		_show_mission()
		get_tree().create_timer(2.0).timeout.connect(_start_playing)
		# --map: and take the map out a moment later.
		if "--map" in OS.get_cmdline_user_args():
			get_tree().create_timer(3.0).timeout.connect(_toggle_map)


# --- Screens -----------------------------------------------------------------------

func _show_title() -> void:
	phase = "title"
	_drop_preview()
	hud.show_menu([
		{"title": "¡APAGA LA LUZ\nQUE TE PILLO!", "size": 64},
		{"cards": [
			{"title": "HISTORIA", "text": "Diez noches de aventura", "stage": MenuStage.make("story"), "call": _show_story_menu, "colour": Hud.C.safe},
			{"title": "GENERATIVO", "text": "Un museo nuevo cada vez", "stage": MenuStage.make("generative"), "call": _show_generative_menu, "colour": Hud.C.gold},
		], "width": 250},
		{"gap": 18},
		{"buttons": [{"text": "SETTINGS", "call": _show_settings.bind("title"), "colour": Hud.C.dim}], "small": true},
		{"gap": 10},
		{"buttons": [{"text": "SALIR", "call": _quit, "colour": Hud.C.dim}], "small": true},
	])


## Out of the game, from the title.
func _quit() -> void:
	_save_settings()
	get_tree().quit()


## The story: the path of nights (any reached so far can be picked), the
## piece of the night picked turning under a light, and one thief or two.
func _show_story_menu() -> void:
	phase = "menu"
	story_pick = clampi(story_pick, 1, Story.unlocked())
	var nights: Array = []
	for n in range(1, Story.count() + 1):
		nights.append({"n": n, "colour": Color(Story.level(n).loot.colour), "locked": n > Story.unlocked(), "selected": n == story_pick, "call": _pick_night.bind(n)})
	var loot: Dictionary = Story.level(story_pick).loot
	_build_preview(loot)
	hud.show_menu([
		{"title": "MODO HISTORIA", "size": 44},
		{"text": "La Banda del Calcetín contra el Barón Von Bostezo", "colour": Hud.C.gold, "size": 17},
		{"nights": nights},
		{"picture": preview.get_texture(), "smooth": true, "height": 110},
		{"text": "NOCHE %d · %s" % [story_pick, loot.name.to_upper()], "colour": Color(loot.colour), "size": 17, "id": "night"},
		{"cards": [
			{"title": "1 LADRÓN", "text": "Tú solo contra el museo", "stage": MenuStage.make("players:1"), "call": _start.bind("story", 1), "colour": COLOURS.thief},
			{"title": "2 LADRONES", "text": "Uno sujeta la alarma, otro abre", "stage": MenuStage.make("players:2"), "call": _start.bind("story", 2), "colour": COLOURS.thief2},
		], "width": 150},
		{"buttons": [{"text": "< VOLVER", "call": _show_title, "colour": Hud.C.dim}], "row": true},
	])


## Moving along the path picks the night: the piece and its name change in
## place, the menu stays as it is.
func _pick_night(n: int) -> void:
	if n == story_pick or preview == null:
		return
	story_pick = n
	var loot: Dictionary = Story.level(n).loot
	_preview_piece(loot)
	hud.set_text("night", "NOCHE %d · %s" % [n, loot.name.to_upper()], Color(loot.colour))


## The generative mode: difficulty and museum size as cards, then play with
## one thief or two.
func _show_generative_menu() -> void:
	phase = "menu"
	var levels: Array = []
	for k in ["easy", "medium", "hard"]:
		levels.append({"title": DIFFICULTY_NAMES[k], "stage": MenuStage.make("guards:" + k), "call": _pick_difficulty.bind(k),
			"colour": {"easy": Hud.C.green, "medium": Hud.C.gold, "hard": Hud.C.alert}[k], "selected": Sim.difficulty == k, "focus": Sim.difficulty == k, "title_size": 12})
	var sizes: Array = []
	for k in ["small", "medium", "large"]:
		sizes.append({"title": SIZE_NAMES[k], "stage": MenuStage.make("museum:" + k), "call": _pick_size.bind(k),
			"colour": Hud.C.safe, "selected": size == k, "title_size": 12})
	hud.show_menu([
		{"title": "MODO GENERATIVO", "size": 40},
		{"cards": levels, "width": 140},
		{"cards": sizes, "width": 140},
		{"cards": [
			{"title": "▶ 1 LADRÓN", "stage": MenuStage.make("players:1"), "call": _start.bind("generative", 1), "colour": COLOURS.thief, "title_size": 12},
			{"title": "▶ 2 LADRONES", "stage": MenuStage.make("players:2"), "call": _start.bind("generative", 2), "colour": COLOURS.thief2, "title_size": 12},
		], "width": 140},
		{"buttons": [{"text": "< VOLVER", "call": _show_title, "colour": Hud.C.dim}], "row": true},
	])


func _pick_difficulty(k: String) -> void:
	Sim.difficulty = k
	_save_settings()
	_show_generative_menu()


func _pick_size(k: String) -> void:
	size = k
	_save_settings()
	_show_generative_menu()


func _start(which: String, n: int, picked := false) -> void:
	# Two thieves: first, each one says which controls are theirs.
	if n == 2 and not picked:
		_show_join(which)
		return
	mode = which
	players = n
	if n == 1:
		seats = ["any"]
	if mode == "story":
		_new_round(story_pick)
		if story_pick == 1:
			_show_prologue()
			return
	else:
		_new_round(1)
	_show_loot()


## The keys on each side of a shared keyboard: pressing any of them on the
## player-select screen takes that side.
const KB_LEFT := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_C, KEY_E, KEY_Q, KEY_SPACE, KEY_SHIFT, KEY_TAB]
const KB_RIGHT := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_MINUS, KEY_SLASH, KEY_PERIOD, KEY_COMMA]


## Player select, like Mario Kart 64: two seats, each taken by whoever
## presses a button on their pad or a key on their side of the keyboard.
## P1 is always teal and P2 always orange; the first to press is P1.
func _show_join(which: String) -> void:
	phase = "join"
	join_for = which
	joining.clear()
	_draw_join()


func _draw_join() -> void:
	var cards: Array = []
	for i in 2:
		var seat: String = joining[i] if i < joining.size() else ""
		cards.append({"title": "JUGADOR %d" % (i + 1), "text": _seat_label(seat) if seat != "" else "Pulsa un botón",
			"stage": MenuStage.make("seat:%d" % (i + 1)), "colour": COLOURS.thief if i == 0 else COLOURS.thief2,
			"selected": seat != "", "static": true, "animate": seat != "", "dim": seat == "", "title_size": 12})
	hud.show_menu([
		{"title": "¿QUIÉN JUEGA?", "size": 40},
		{"cards": cards, "width": 200},
		{"text": "Cada uno pulsa un botón de su mando, o una tecla de su lado del teclado (WASD o flechas)", "size": 16},
		{"text": "¡LISTOS!" if joining.size() == 2 else "Esc o B: quitar al último · volver", "size": 16, "colour": Hud.C.gold if joining.size() == 2 else Hud.C.dim},
	])


func _seat_label(seat: String) -> String:
	match seat:
		"kb_left": return "Teclado · WASD"
		"kb_right": return "Teclado · flechas"
		"any": return "Teclado y mandos"
	var pad := int(seat.substr(4))
	return "Mando %d · %s" % [pad + 1, Input.get_joy_name(pad).left(18)]


## A press on the player-select screen: it takes a seat, or (Esc, B) frees
## the last one — or goes back when none is taken.
func _join_input(event: InputEvent) -> void:
	var seat := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_unjoin()
			return
		if event.physical_keycode in KB_LEFT or event.keycode in KB_LEFT:
			seat = "kb_left"
		elif event.physical_keycode in KB_RIGHT or event.keycode in KB_RIGHT:
			seat = "kb_right"
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			_unjoin()
			return
		seat = "pad:%d" % event.device
	if seat == "" or seat in joining or joining.size() >= 2:
		return
	joining.append(seat)
	sfx.ui("ok")
	_rumble_pad(seat, 0.3, 0.15)
	_draw_join()
	if joining.size() == 2:
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if phase == "join" and joining.size() == 2:
				seats.assign(joining)
				_start(join_for, 2, true))


func _unjoin() -> void:
	sfx.ui("back")
	if joining.is_empty():
		if join_for == "story":
			_show_story_menu()
		else:
			_show_generative_menu()
		return
	joining.pop_back()
	_draw_join()


func _show_prologue() -> void:
	phase = "prologue"
	hud.show_menu([
		{"title": "HABÍA UNA VEZ...", "size": 44},
		{"text": Story.PROLOGUE, "size": 18, "wrap": true},
		{"buttons": [{"text": "▶ ¡VAMOS!", "call": _show_loot}]},
	])


## Sound and music, their volumes, the screen and the IA panel. Opens from
## the title and from the pause. Each line is a setting (Hud._stepper): Enter
## or a click moves it on, ← and → move it down and up; each change is saved.
func _show_settings(from: String, page := "") -> void:
	settings_from = from
	settings_page = page
	phase = "settings"
	var keys: Array = {
		"": ["ia"],
		"sound": ["sound", "music", "music_volume", "effects_volume"],
		"screen": ["fullscreen", "vsync"],
		"pads": ["rumble", "rumble_strength", "deadzone"],
	}[page]
	var rows: Array = []
	if page == "":
		rows.append({"text": "SONIDO >", "call": _show_settings.bind(from, "sound")})
		rows.append({"text": "PANTALLA >", "call": _show_settings.bind(from, "screen")})
		rows.append({"text": "CONTROLES >", "call": _show_settings.bind(from, "pads")})
	for k in keys:
		rows.append({"text": _setting_text(k), "step": _step_setting.bind(k)})
	rows.append({"text": "< VOLVER", "call": _settings_back, "colour": Hud.C.dim})
	var title: String = {"": "SETTINGS", "sound": "SONIDO", "screen": "PANTALLA", "pads": "CONTROLES"}[page]
	var items: Array = [{"title": title, "size": 48}, {"buttons": rows}]
	match page:
		"sound":
			items.append({"text": "← y → para bajar y subir el volumen · N silencia todo", "size": 16, "colour": Hud.C.dim})
		"pads":
			var pads := Input.get_connected_joypads()
			var names: Array = pads.map(func(d): return "%d: %s" % [d + 1, Input.get_joy_name(d)])
			items.append({"text": ("Mandos: " + " · ".join(names)) if not pads.is_empty() else "No hay mandos conectados", "size": 16, "colour": Hud.C.gold})
			items.append({"text": "Teclado: P1 WASD y C (a gatas) · P2 flechas y - o /", "size": 16})
			items.append({"text": "Mando: stick o cruceta, A o B a gatas, Start pausa", "size": 16})
	hud.show_menu(items)


func _setting_text(key: String) -> String:
	var yes := func(on: bool) -> String: return "SÍ" if on else "NO"
	match key:
		"sound": return "SONIDO: %s  (N)" % yes.call(sound_on)
		"music": return "MÚSICA: %s" % yes.call(music_on)
		"music_volume": return "VOL. MÚSICA %s" % _volume_bar(music_volume)
		"effects_volume": return "VOL. EFECTOS %s" % _volume_bar(effects_volume)
		"fullscreen": return "PANTALLA COMPLETA: %s" % yes.call(fullscreen)
		"vsync": return "V-SYNC: %s" % yes.call(vsync)
		"ia": return "PANEL IA: %s" % yes.call(show_ia)
		"rumble": return "VIBRACIÓN: %s" % yes.call(rumble)
		"rumble_strength": return "FUERZA %s" % _volume_bar(rumble_strength)
		"deadzone": return "ZONA MUERTA STICK: %d%%" % deadzone
	return key


## |||||····· 50%: a bar a step, in glyphs the arcade font has (it has no
## blocks, and the fallback's come out as hairlines).
func _volume_bar(percent: int) -> String:
	var on: int = percent / Settings.VOLUME_STEP
	return "%s%s %d%%" % ["|".repeat(on), "·".repeat(100 / Settings.VOLUME_STEP - on), percent]


## One setting changed from its button: a yes/no flips whichever way; a
## volume goes down or up a step with ← and → (stopping at the ends), and up
## with Enter, round from 100 back to 0. Applied, saved, and the button's
## new text returned.
func _step_setting(dir: int, key: String) -> String:
	match key:
		"sound": _set_sound(not sound_on)
		"music": _toggle_music()
		"ia": _toggle_ia()
		"fullscreen", "vsync":
			set(key, not get(key))
			Settings.apply_display(fullscreen, vsync)
		"rumble":
			rumble = not rumble
			# Feel it straight away.
			if key == "rumble" and rumble:
				_rumble(0.4, 0.4, 0.2)
		"rumble_strength":
			rumble_strength = 0 if dir == 0 and rumble_strength >= 100 else Settings.volume(rumble_strength + (Settings.VOLUME_STEP if dir >= 0 else -Settings.VOLUME_STEP))
			_rumble(0.4, 0.4, 0.2)
		"deadzone":
			deadzone = 20 if dir == 0 and deadzone >= 80 else clampi(deadzone + (10 if dir >= 0 else -10), 20, 80)
		"music_volume", "effects_volume":
			var v: int = get(key)
			if dir == 0:
				v = 0 if v >= 100 else v + Settings.VOLUME_STEP
			else:
				v = Settings.volume(v + dir * Settings.VOLUME_STEP)
			set(key, v)
			sfx.set_volumes(music_volume / 100.0, effects_volume / 100.0)
	_save_settings()
	return _setting_text(key)


func _set_sound(on: bool) -> void:
	sound_on = on
	AudioServer.set_bus_mute(0, not on)
	_save_settings()


func _toggle_music() -> void:
	music_on = not music_on
	sfx.set_music(music_on)


func _toggle_ia() -> void:
	show_ia = not show_ia


## What was saved last time, applied: sound, music and volumes, the screen,
## and the generative mode's last difficulty and size.
func _load_settings() -> void:
	var s := Settings.read()
	sound_on = s.sound
	music_on = s.music
	show_ia = s.ia
	Sim.difficulty = s.difficulty
	size = s.size
	fullscreen = s.fullscreen
	vsync = s.vsync
	music_volume = s.music_volume
	effects_volume = s.effects_volume
	rumble = s.rumble
	rumble_strength = s.rumble_strength
	deadzone = s.deadzone

	AudioServer.set_bus_mute(0, not sound_on)
	sfx.set_music(music_on)
	sfx.set_volumes(music_volume / 100.0, effects_volume / 100.0)
	Settings.apply_display(fullscreen, vsync)


func _save_settings() -> void:
	Settings.write({
		"sound": sound_on, "music": music_on, "ia": show_ia,
		"difficulty": Sim.difficulty, "size": size,
		"fullscreen": fullscreen, "vsync": vsync,
		"music_volume": music_volume, "effects_volume": effects_volume,
		"rumble": rumble, "rumble_strength": rumble_strength,
		"deadzone": deadzone,
	})


func _settings_back() -> void:
	if settings_page != "":
		_show_settings(settings_from)
	elif settings_from == "paused":
		_pause()
	else:
		_show_title()


## A real pause: the tree stops, knocked-over props hang in mid-air, until
## SEGUIR (or Esc, or P) or the way out to the title.
func _pause() -> void:
	_close_map()
	phase = "paused"
	get_tree().paused = true
	hud.show_menu([
		{"title": "PAUSA", "size": 56},
		{"buttons": [
			{"text": "▶ SEGUIR", "call": _start_playing},
			{"text": "SETTINGS", "call": _show_settings.bind("paused")},
			{"text": "< MENÚ", "call": _quit_to_title},
		]},
	])


func _quit_to_title() -> void:
	get_tree().paused = false
	_show_title()


## First the piece: turning under a light, its name, and the story of why
## someone wants it.
func _show_loot() -> void:
	phase = "loot"
	_build_preview()
	hud.show_menu([
		{"title": ("NOCHE %d DE %d" % [level, Story.count()]) if mode == "story" else ("NIVEL %02d" % level), "size": 40},
		{"text": "ESTA NOCHE HAY QUE RECUPERAR" if mode == "story" else "ESTA NOCHE VAS A ROBAR", "size": 16, "colour": Hud.C.dim},
		{"picture": preview.get_texture(), "smooth": true, "height": 250},
		{"title": Heist.loot.name.to_upper(), "size": 30, "colour": Color(Heist.loot.colour)},
		{"text": Heist.loot.blurb, "colour": Hud.C.gold},
		{"text": Heist.loot.story, "size": 17, "wrap": true},
		{"buttons": [{"text": "▶ VER EL PLAN", "call": _show_mission}]},
	])


func _build_preview(loot: Dictionary = Heist.loot) -> void:
	_drop_preview()
	preview = SubViewport.new()
	preview.size = Vector2i(480, 300)
	preview.own_world_3d = true
	preview.transparent_bg = true
	preview.msaa_3d = Viewport.MSAA_4X
	add_child(preview)
	# Axonometric, like every picture in the menus.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = cam.basis.z * 10.0 + Vector3(0, 0.08, 0)
	cam.size = 0.62
	preview.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	preview.add_child(sun)
	preview_spot = OmniLight3D.new()
	preview_spot.position = Vector3(0, 0.8, 0.4)
	preview_spot.light_energy = 1.5
	preview.add_child(preview_spot)
	# A velvet stand under it.
	var stand := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.25
	c.height = 0.08
	stand.mesh = c
	stand.material_override = MenuStage._material(MenuStage.VELVET)
	stand.position = Vector3(0, -0.12, 0)
	preview.add_child(stand)
	preview_pivot = Node3D.new()
	preview_pivot.position = Vector3(0, 0.1, 0)
	preview.add_child(preview_pivot)
	_preview_piece(loot)


## Swap the piece on the stand, keeping the stand, the camera and the picture.
func _preview_piece(loot: Dictionary) -> void:
	for c in preview_pivot.get_children():
		c.queue_free()
	preview_spot.light_color = Color(loot.colour)
	var piece := LootModels.build(loot.shape, Color(loot.colour))
	piece.position.y = -0.1
	preview_pivot.add_child(piece)


func _drop_preview() -> void:
	if preview:
		preview.queue_free()
		preview = null
		preview_pivot = null
		preview_spot = null


func _show_mission() -> void:
	phase = "mission"
	# Little text: the piece, the map, and on the first level one line on how.
	# The map already says where you come in, where the piece is and the door.
	var lines := [Heist.first_upper(Heist.loot.name)]
	if Heist.team:
		lines.append("Uno sujeta el cuadro de la alarma (naranja) mientras el otro abre la vitrina")
	if level == 1:
		lines.append("Quieto %s junto a la pieza · la alarma atrae guardias · sal por la puerta verde" % _seconds(Heist.loot.seconds))
	if level <= 2:
		lines.append("Papeleras, bustos y paneles: tíralos con E (X en el mando) y los guardias irán a ver el ruido")
	var items: Array = [{"title": "EL PLAN", "size": 52}]
	for l in lines:
		items.append({"text": l})
	items.append({"map": Hud.plan_map(guards), "height": 400})
	items.append({"buttons": [{"text": "▶ EMPEZAR", "call": _start_countdown}]})
	hud.show_menu(items)


func _show_end() -> void:
	var title := "TE HAN PILLADO"
	var colour: Color = Hud.C.alert
	var line := "%s %s." % [Heist.first_upper(Heist.loot.name), "vuelve a su vitrina" if Heist.taken else "sigue en su sitio"]
	var next := "▶ OTRA VEZ"
	if phase == "escaped":
		title = "¡GOLPE PERFECTO!"
		colour = Hud.C.safe
		line = "%s vuelve a casa." % Heist.first_upper(Heist.loot.name) if mode == "story" else "Nivel %d superado: %s ya es tuyo." % [level, Heist.loot.name]
		next = "▶ SIGUIENTE NOCHE" if mode == "story" else "▶ SIGUIENTE GOLPE"
		if mode == "story":
			Story.unlock(level + 1)
			story_pick = mini(level + 1, Story.count())
			if level >= Story.count():
				_show_ending()
				return
	var picture: Dictionary = {"stage": MenuStage.make("guards:hard"), "height": 140}
	if phase == "escaped":
		_build_preview()
		picture = {"picture": preview.get_texture(), "smooth": true, "height": 140}
	hud.show_menu([
		{"title": title, "colour": colour, "size": 52},
		picture,
		{"text": line},
		{"buttons": [{"text": next, "call": _again, "colour": colour}], "big": true},
		{"buttons": [{"text": "< VOLVER AL MENÚ", "call": _show_title, "colour": Hud.C.dim}], "small": true},
	])


func _show_ending() -> void:
	phase = "ending"
	sfx.ui("escaped")
	hud.show_menu([
		{"title": "¡OPERACIÓN\nDEVOLVERLO TODO!", "colour": Hud.C.safe, "size": 48},
		{"text": Story.ENDING, "size": 18, "wrap": true},
		{"buttons": [{"text": "< MENÚ", "call": _show_title}]},
	])


func _again() -> void:
	_new_round(level + 1 if phase == "escaped" else level)
	_show_loot()


func _seconds(s: float) -> String:
	return ("%d segundos" % int(s)) if is_equal_approx(s, round(s)) else ("%s segundos" % str(s).replace(".", ","))


func _unhandled_input(event: InputEvent) -> void:
	if phase == "join":
		_join_input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and phase not in ["playing", "countdown"]:
		sfx.ui("back")
	var key := _pad_as_key(event)
	if key == KEY_NONE:
		if not (event is InputEventKey and event.pressed and not event.echo):
			return
		key = event.keycode
	# Menus are buttons (mouse, arrows and Enter); these are the shortcuts.
	if key == KEY_M and phase == "playing":
		_toggle_map()
		return
	if key == KEY_N:
		_set_sound(not sound_on)
		if phase == "settings":
			_show_settings(settings_from, settings_page)
		return
	match phase:
		"menu":
			if key == KEY_ESCAPE:
				_show_title()
		"input":
			if key == KEY_ESCAPE:
				if settings_from == "story":
					_show_story_menu()
				else:
					_show_generative_menu()
		"prologue":
			if key == KEY_SPACE:
				_show_loot()
			elif key == KEY_ESCAPE:
				_show_title()
		"ending":
			if key == KEY_ESCAPE or key == KEY_SPACE:
				_show_title()
		"loot":
			if key == KEY_SPACE:
				_show_mission()
			elif key == KEY_ESCAPE:
				_show_title()
		"mission":
			if key == KEY_SPACE:
				_start_countdown()
			elif key == KEY_ESCAPE:
				_show_title()
		"playing":
			if key == KEY_ESCAPE or key == KEY_P:
				_pause()
		"paused":
			if key == KEY_ESCAPE or key == KEY_P:
				_start_playing()
		"settings":
			if key == KEY_ESCAPE:
				_settings_back()
		"caught", "escaped":
			if key == KEY_SPACE:
				_again()
			elif key == KEY_ESCAPE:
				_show_title()


## A pad button as the key it stands for, so the shortcuts above are written
## once. Start pauses and resumes (P) and elsewhere moves on (Space); B backs
## out (Escape), except while playing, where it crouches. A is ui_accept and
## presses the focused button by itself.
func _pad_as_key(event: InputEvent) -> Key:
	if not (event is InputEventJoypadButton and event.pressed):
		return KEY_NONE
	if event.is_action("pause"):
		return KEY_P if phase in ["playing", "paused"] else KEY_SPACE
	if event.is_action("map"):
		return KEY_M if phase == "playing" else KEY_NONE
	if event.is_action("ui_cancel") and phase != "playing":
		return KEY_ESCAPE
	return KEY_NONE


## 3, 2, 1, GO! over the museum, everyone frozen in place until it is over.
func _start_countdown() -> void:
	phase = "countdown"
	_drop_preview()
	hud.hide_panel()
	hud.countdown(_count_beep, _start_playing)


func _count_beep(i: int) -> void:
	sfx.ui("go" if i == 3 else "tick")


func _start_playing() -> void:
	phase = "playing"
	get_tree().paused = false
	_drop_preview()
	hud.hide_panel()


# --- Rounds --------------------------------------------------------------------------

func _new_round(n: int) -> void:
	_close_map()
	if mode == "story":
		n = clampi(n, 1, Story.count())
	level = n
	if mode == "story":
		var night := Story.level(n)
		Sim.custom = Story.tuning(n)
		Sim.new_map(Story.seed_for(n), night.size, -1, night.shape)
	else:
		Sim.custom = {}
		Sim.new_map(randi() % 1000000000, size)
	thieves = [Sim.new_thief("p1")]
	if players == 2:
		thieves.append(Sim.new_thief("p2"))
	guards = Sim.new_guards(Sim.guard_count(Museum.size_name))
	Heist.plan_job(level, Story.level(n).loot if mode == "story" else {}, players == 2)
	# Things to knock over: never on the tiles the job needs clear.
	var stand := Heist.route[0]
	for t in Heist.route:
		if Museum.dist(t.x + 0.5, t.y + 0.5, Heist.at.x + 0.5, Heist.at.y + 0.5) < 1.1:
			stand = t
			break
	Props.place(Story.seed_for(n) if mode == "story" else randi(), [Heist.exit, Heist.panel, stand, Heist.start])
	stride = [0.0, 0.0]
	push_held = [false, false]
	guard_steps.clear()
	prop_noises.clear()
	last_think = 0.0
	think_tick = 0
	log_lines.clear()
	Sim.thoughts.clear()
	Sim.light_events.clear()
	_build_world()
	_snap_camera()


## The physics frame _pressed_keys last ran on: a gap means play (re)started.
var pad_frame := -1
## Pad crouch actions held over from a menu, ignored until released.
var pad_stale := {}


func _pressed_keys() -> Dictionary:
	var keys := {}
	# A and B also press and back out of menus: one still held from there when
	# the play starts (or resumes) is not a crouch until it is let go.
	var resumed := Engine.get_physics_frames() != pad_frame + 1
	pad_frame = Engine.get_physics_frames()
	# Each thief's controls, as the key names Sim reads for that thief.
	var names := [["w", "s", "a", "d", "c", "e"], ["up", "down", "left", "right", "minus", "period"]]
	for i in mini(seats.size(), thieves.size()):
		var got := _seat_input(seats[i], resumed)
		for k in 6:
			if got[k]:
				keys[names[i][k]] = true
	return keys


## One seat's controls this frame: [up, down, left, right, crouch, push].
func _seat_input(seat: String, resumed: bool) -> Array:
	var out := [false, false, false, false, false, false]
	if seat == "any" or seat == "kb_left":
		for pair in [[0, KEY_W], [1, KEY_S], [2, KEY_A], [3, KEY_D], [4, KEY_C], [4, KEY_SHIFT], [5, KEY_E]]:
			if Input.is_physical_key_pressed(pair[1]):
				out[pair[0]] = true
	if seat == "any" or seat == "kb_right":
		for pair in [[0, KEY_UP], [1, KEY_DOWN], [2, KEY_LEFT], [3, KEY_RIGHT], [4, KEY_MINUS], [4, KEY_SLASH], [5, KEY_PERIOD]]:
			if Input.is_physical_key_pressed(pair[1]):
				out[pair[0]] = true
	var pads: Array = Input.get_connected_joypads() if seat == "any" else ([int(seat.substr(4))] if seat.begins_with("pad:") else [])
	var dz := deadzone / 100.0
	for pad in pads:
		var x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		out[0] = out[0] or y < -dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)
		out[1] = out[1] or y > dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)
		out[2] = out[2] or x < -dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)
		out[3] = out[3] or x > dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)
		var stale_key := "pad:%d" % pad
		var crouch := Input.is_joy_button_pressed(pad, JOY_BUTTON_A) or Input.is_joy_button_pressed(pad, JOY_BUTTON_B)
		if crouch and resumed:
			pad_stale[stale_key] = true
		elif not crouch:
			pad_stale.erase(stale_key)
		out[4] = out[4] or (crouch and not pad_stale.has(stale_key))
		out[5] = out[5] or Input.is_joy_button_pressed(pad, JOY_BUTTON_X)
	return out


## Shakes the pads: every one, or with `at` only the pad of the thief nearest
## to it (pad 0 is P1, pad 1 is P2). On your own any pad may be the one in
## your hands, so all of them shake.
func _rumble(weak: float, strong: float, secs: float, at := Vector2.INF) -> void:
	var who := -1
	if thieves.size() == 2 and at != Vector2.INF:
		who = 0 if Museum.dist(thieves[0].x, thieves[0].y, at.x, at.y) <= Museum.dist(thieves[1].x, thieves[1].y, at.x, at.y) else 1
	for i in seats.size():
		if who < 0 or i == who:
			_rumble_pad(seats[i], weak, secs, strong)


## Shake one seat's pad (every pad for "any"; keyboards do not shake).
func _rumble_pad(seat: String, weak: float, secs: float, strong := -1.0) -> void:
	if not rumble or rumble_strength == 0:
		return
	if strong < 0.0:
		strong = weak
	var k := rumble_strength / 100.0
	var pads: Array = Input.get_connected_joypads() if seat == "any" else ([int(seat.substr(4))] if seat.begins_with("pad:") else [])
	for pad in pads:
		Input.start_joy_vibration(pad, weak * k, strong * k, secs)


# --- The loop ------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if preview_pivot:
		preview_pivot.rotate_y(dt * 0.9)
	_music_mood()
	if props_view and not thieves.is_empty():
		var at: Array[Vector3] = []
		for t in thieves:
			at.append(_to_world(t.x, t.y) if not t.out else Vector3(0, -50, 0))
		props_view.move_thieves(at)
	if phase == "playing":
		_tick(dt)
	_draw_frame(dt)


## The music follows the guards: creeping while they are calm, a pulse
## once any is on alert, all of it while one can see you. Softer in menus.
func _music_mood() -> void:
	var tension := 0.0
	var in_game := phase in ["playing", "countdown", "paused"]
	if in_game:
		for g in guards:
			if g.sees_player:
				tension = 1.0
			elif g.alert:
				tension = maxf(tension, 0.55)
	sfx.mood(tension, 0.8 if in_game else 0.5)


## Noises the physics made since the last frame, for the next tick.
var prop_noises: Array[SoundEvent] = []


## A prop leaned past falling in the physics: if nobody pushed it on
## purpose, it was walked into — the crash, the rumble, the log.
func _on_prop_tipped(id: int, dir: float, at: Vector2, strength: float) -> void:
	var p: Props.Prop = Props.list[id]
	p.x = at.x
	p.y = at.y
	if p.fallen:
		return
	p.fallen = true
	p.fall_dir = dir
	p.fallen_at = Sim.now_ms()
	var loud := Props.crash_loudness(p.kind, strength)
	prop_noises.append(SoundEvent.make(p.x, p.y, p.kind, loud))
	_prop_fell(p, strength)


## The crash of one going over, whoever did it.
func _prop_fell(p: Props.Prop, strength := 0.6) -> void:
	sfx.at(p.kind, _to_world(p.x, p.y), 0.45 + 0.55 * strength, 4.0 + 6.0 * strength)
	_rumble(0.3 + 0.5 * strength, 0.4 * strength, 0.15 + 0.2 * strength, Vector2(p.x, p.y))
	_shake((0.45 if p.kind == "bust" else 0.25) * (0.6 + 0.8 * strength))
	var loud := Props.crash_loudness(p.kind, strength)
	_log(("¡Menudo estruendo! %s se ha oído en todo el museo" % Heist.first_upper(Props.NAMES[p.kind])) if loud >= 20.0 else "¡Has tirado %s!" % Props.NAMES[p.kind])


## Something already down, sent rolling or rustling by a thief's feet: a
## smaller noise, but a noise — the tin bin clatters, paper whispers.
func _on_prop_kicked(kind: String, at: Vector2, strength: float) -> void:
	var loud: float = {"bin": 7.5, "bust": 6.0, "panel": 5.0, "paper": 2.5}.get(kind, 4.0) * (0.5 + 0.5 * strength)
	prop_noises.append(SoundEvent.make(at.x, at.y, "kick", loud))
	if kind == "paper":
		sfx.at("whisper", _to_world(at.x, at.y), 0.5 + 0.5 * strength)
	else:
		sfx.at("bin" if kind == "bin" else "bump", _to_world(at.x, at.y), 0.35 + 0.4 * strength)


## "E: TIRAR LA PAPELERA" when a thief has something within reach.
func _push_hint() -> String:
	if phase != "playing":
		return ""
	for i in thieves.size():
		var p := Props.within_reach(thieves[i])
		if p:
			var key := "E" if i == 0 else "."
			return "%s / X: TIRAR %s" % [key, (Props.NAMES[p.kind] as String).to_upper()]
	return ""


## Each guard's boots, a step every stride: heard from where they are, so
## louder the nearer (the listener rides on the thief), harder when on alert.
func _guard_footsteps() -> void:
	if guard_steps.size() != guards.size():
		guard_steps = guards.map(func(g): return [Vector2(g.x, g.y), 0.0])
	for i in guards.size():
		var g := guards[i]
		var here := Vector2(g.x, g.y)
		var entry: Array = guard_steps[i]
		entry[1] += here.distance_to(entry[0])
		entry[0] = here
		var stride := 0.62 if g.alert else 0.55
		if entry[1] >= stride:
			entry[1] = 0.0
			sfx.at("boot", _to_world(g.x, g.y), 1.0 if g.alert else 0.75, 2.2)


## Out comes the map, or away it goes.
func _toggle_map() -> void:
	map_open = not map_open
	if map_open:
		hud.show_map(Hud.live_map(thieves, _thief_colours()))
		sfx.ui("pick")
	else:
		hud.hide_map()


func _close_map() -> void:
	map_open = false
	hud.hide_map()


func _thief_colours() -> Array:
	return [COLOURS.thief, COLOURS.thief2]


func _tick(dt: float) -> void:
	var now := Sim.now_ms()
	# Reading the map, nobody moves (the pads are still read, to keep their
	# held-button bookkeeping); every few frames it is redrawn.
	var keys := _pressed_keys()
	if map_open:
		# The controls lean the map instead of moving anyone.
		var push := Vector2.ZERO
		for pair in [["a", "d", "w", "s"], ["left", "right", "up", "down"]]:
			push += Vector2(float(keys.has(pair[1])) - float(keys.has(pair[0])), float(keys.has(pair[3])) - float(keys.has(pair[2])))
		hud.push_map(push)
		keys = {}
		if Engine.get_physics_frames() % 6 == 0:
			hud.update_map(Hud.live_map(thieves, _thief_colours()))
	var noises: Array[SoundEvent] = []
	for i in thieves.size():
		var p := thieves[i]
		var px := p.x
		var py := p.y
		# On your own both pads drive you; with two, each pad is its own.
		var scheme := "solo" if thieves.size() == 1 else ("wasd" if i == 0 else "arrows")
		var step := Sim.step_thief(p, keys, dt, scheme)
		var noise := Hearing.thief_noise(px, py, p, step.entered_cover, step.bumped, Sim.TOP_SPEED)
		# Footsteps land once per stride; a bump is its own event.
		stride[i] += Museum.dist(px, py, p.x, p.y)
		if noise and (noise.kind == "walk" or noise.kind == "sprint"):
			if stride[i] < 0.45 + p.speed / Sim.TOP_SPEED * 0.5:
				noise = null
			else:
				stride[i] = 0.0
		if noise and not p.out:
			noises.append(noise)
			var what := "step" if noise.kind in ["walk", "sprint", "rustle"] else ("shelf" if noise.kind == "shelf" else "bump")
			# A step as loud as you are fast, softer on all fours.
			var vol := clampf(p.speed / Sim.TOP_SPEED, 0.12, 1.0) * (1.0 - 0.5 * p.posture) if what == "step" else clampf(noise.loudness / 9.0, 0.15, 1.0)
			sfx.at(what, _to_world(p.x, p.y), vol, 3.0 if what == "step" else 6.0)

	# Walking into things: over they go, with a crash.
	# Things knocked over: the physics decides (PropsView pushes them with
	# the thieves' bodies and tells us what fell or got kicked about), and
	# what it heard since last frame joins this frame's noises.
	Props.knocked.clear()
	noises.append_array(prop_noises)
	prop_noises.clear()
	# On purpose: E (P2: . ), or X on the pad, next to one — over it goes,
	# and the guards come to see.
	for i in thieves.size():
		var t := thieves[i]
		var pressed: bool = keys.has("e") or (thieves.size() == 1 and keys.has("period")) if i == 0 else keys.has("period")
		if pressed and not push_held[i]:
			var target := Props.within_reach(t)
			if target:
				Props.push(target, t, now, noises)
		push_held[i] = pressed
	for p in Props.knocked:
		props_view.shove(p)
		_prop_fell(p)

	# The job: working the case (and its alarm), carrying, dropping, the door.
	var before_alarms := noises.size()
	var took := Heist.step(thieves, dt, now, noises)
	if noises.size() > before_alarms:
		if Heist.progress < 0.1:
			_log("¡Salta la alarma de la vitrina!")
		sfx.at("alarm", _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5), 0.8)
	match took:
		"stolen":
			sfx.ui("stolen")
			Fx.sparkle(world, _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05), Color(Heist.loot.colour))
			_punch_in()
			_log("Tienes %s: ahora, a la salida" % Heist.loot.name)
		"dropped":
			_log("%s ha caído al suelo" % Heist.first_upper(Heist.loot.name))
		"picked":
			sfx.ui("pick")

	Sim.tick_lights(dt)
	var saw_before := {}
	for g in guards:
		saw_before[g.id] = g.sees_player
	for g in guards:
		Sim.step_guard(g, thieves, noises, now, dt)
	_guard_footsteps()
	for s in Sim.call_for_backup(saw_before, guards, now):
		sfx.at("shout", _to_world(s.x, s.y), 1.0 if s.first else 0.5)
		if s.first:
			sfx.ui("sting", 0.7)
			_rumble(0.4, 0.8, 0.4)
			_shake(0.6)
			var heard_by: Array = s.heard_by
			var heard: String = ("%s lo ha oído y viene" % " y ".join(heard_by)) if not heard_by.is_empty() else "nadie más lo ha oído"
			var ear := thieves[0]
			var angle := atan2(s.y - ear.y, s.x - ear.x)
			var d := Museum.dist(ear.x, ear.y, s.x, s.y)
			hud.shout(SHOUTS[randi() % SHOUTS.size()], "%s grita %s · %s" % [s.from, "a lo lejos" if d > 9 else "cerca", heard], angle)
			_log("%s: ¡Alto! — %s" % [s.from, heard])
	for w in Sim.warn_partners(guards, now):
		sfx.at("whisper", _to_world(w.x, w.y), 0.6)
		_log("%s avisa a %s en voz baja" % [w.from, w.to])
	for t in Sim.thoughts:
		_log("%s: %s" % [t.by, t.text])
	Sim.thoughts.clear()
	for e in Sim.light_events:
		var label := "la sala"
		for z in Museum.zones:
			if z.room == e.room:
				label = z.label
		var r: Museum.Room = Museum.rooms[e.room]
		sfx.at("lights", _to_world(r.switch_at.x + 0.5, r.switch_at.y + 0.5), 0.8)
		_log("%s enciende las luces de %s" % [e.by, label])
	Sim.light_events.clear()

	if now - last_spread > 500:
		last_spread = now
		Sim.keep_apart(guards)
	# Thinking. Only guards with a decision to make are asked, and everyone
	# every third time; without the brain, the fallback rules decide.
	if now - last_think > THINK_EVERY_MS:
		last_think = now
		think_tick += 1
		var everyone := think_tick % 3 == 0
		var asking: Array[Guard] = guards.filter(func(g): return not g.sees_player and (everyone or Sim.needs_plan(g)))
		if not brain.ask(asking, guards, now) and not brain.busy:
			for g in asking:
				if Sim.needs_plan(g):
					var others: Array[Guard] = guards.filter(func(o): return o != g)
					Sim.apply_decision(g, Mind.fallback(g, others, now))

	for p in thieves:
		p.hidden = Sim.is_hidden(guards, p)
		if Sim.caught(guards, p):
			p.out = true
			p.speed = 0
			sfx.ui("caught")
	# No clock: take as long as you like. Out of the door with the piece wins;
	# everyone caught loses.
	if took == "out":
		phase = "escaped"
		_close_map()
		sfx.ui("escaped")
		_show_end()
	elif thieves.all(func(p): return p.out):
		phase = "caught"
		_close_map()
		_show_end()


func _on_decided(decisions: Dictionary, _ms: int) -> void:
	if phase != "playing":
		return
	for g in guards:
		if g.sees_player or not decisions.has(g.id):
			continue
		var before := g.decision.label if g.decision else ""
		Sim.apply_decision(g, decisions[g.id])
		# Log what it actually does: a committed guard keeps its plan.
		if g.decision.label != before:
			var p: float = g.decision.probabilities.get(g.decision.option, 0.0)
			_log("%s: %s · %d%%%s" % [g.name, g.decision.label, roundi(p * 100), " (duda)" if g.decision.torn else ""])


func _on_brain_failed(reason: String) -> void:
	_log("IA: reglas de reserva (%s)" % reason)


func _log(line: String) -> void:
	log_lines.push_front(line)
	log_lines = log_lines.slice(0, 8)


# --- Building the world --------------------------------------------------------

func _to_world(x: float, y: float, height: float = 0.0) -> Vector3:
	return MuseumView.to_world(x, y, height)


func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _build_environment() -> void:
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
	# The camera is ~17 m from the floor: no need to spend froxels any further.
	env.volumetric_fog_length = 25.0
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
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# Moonlight through the high windows: cold and faint, from one side. It
	# shades the tops of walls and cases apart from their faces, and draws the
	# rim round the figures in the dark (Figure's materials).
	var moon := DirectionalLight3D.new()
	# The moon lights the room, not the dust in the air (Fx.Dust): motes only
	# show where a torch or a lamp catches them.
	moon.light_cull_mask = 0xFFFFF & ~Fx.DUST_LAYER
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
	moon.directional_shadow_max_distance = 35.0
	add_child(moon)
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	# The ears are the thief's, not the camera's (high above): a guard's
	# steps grow as it comes near you, from the side it comes from.
	ear = AudioListener3D.new()
	add_child(ear)
	ear.make_current()


func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	thief_nodes.clear()
	guard_nodes.clear()
	torches.clear()
	room_lights.clear()
	cones.clear()
	switch_marks.clear()
	lit_washes.clear()

	# Floor, walls, cases and emergency lights: built once, never touched again.
	var view := MuseumView.new()
	view.build()
	world.add_child(view)
	props_view = PropsView.new()
	world.add_child(props_view)
	props_view.build()
	props_view.set_thieves(thieves.size())
	props_view.tipped.connect(_on_prop_tipped)
	props_view.kicked.connect(_on_prop_kicked)

	# Switches, and the white wash that fills a lit room.
	for r in Museum.rooms:
		switch_marks.append(_switch(r))
		var wash := MeshInstance3D.new()
		var p := PlaneMesh.new()
		p.size = Vector2(r.rect.size.x, r.rect.size.y)
		wash.mesh = p
		var wm := _flat(Color(ROOM_LIGHT_COLOUR, ROOM_WASH))
		wm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		wash.material_override = wm
		wash.position = _to_world(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0, 0.02)
		wash.visible = false
		world.add_child(wash)
		lit_washes.append(wash)

	_build_job()

	for i in thieves.size():
		# Second pad, second colour: two teal figures would be one figure.
		var f := Figure.make("thief", COLOURS.thief if i == 0 else COLOURS.thief2, COLOURS.thief_dark if i == 0 else COLOURS.thief2_dark)
		world.add_child(f)
		thief_nodes.append(f)
	for i in ROOM_LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = ROOM_LIGHT_COLOUR
		l.light_energy = 0.0
		l.omni_attenuation = 0.8
		l.light_specular = 0.6
		l.light_volumetric_fog_energy = ROOM_FOG
		world.add_child(l)
		Fx.dust_in(l)
		room_lights.append(l)
	for g in guards:
		var f := Figure.make("guard", COLOURS.guard, COLOURS.guard_dark)
		world.add_child(f)
		guard_nodes.append(f)
		# A torch, not a bulb: narrow cone, soft edge, pointed where it looks.
		# Bright hotspot, a quick falloff to the rim, and crisp shadows so the
		# cases and figures it sweeps throw long ones across the floor.
		var torch := SpotLight3D.new()
		torch.light_color = TORCH_COLOUR
		torch.spot_attenuation = 0.7
		torch.spot_angle_attenuation = 0.9
		torch.light_specular = 1.0
		torch.shadow_enabled = true
		torch.shadow_bias = 0.04
		torch.shadow_normal_bias = 0.8
		torch.shadow_blur = 0.6
		torch.light_volumetric_fog_energy = TORCH_FOG
		f.add_child(torch)
		# Just ahead of the cap's peak (inside it, the shadowed head swallows the
		# beam), and turned round: a spot shines down its -Z, a figure faces +Z.
		torch.position = Vector3(0, 1.15, 0.3)
		torch.rotation = Vector3(-0.35, PI, 0)
		Fx.dust_in(torch)
		torches.append(torch)
		var cone := MeshInstance3D.new()
		cone.mesh = ImmediateMesh.new()
		var cm := _flat(Color(COLOURS.cone, 0.12))
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cone.material_override = cm
		world.add_child(cone)
		cones.append(cone)


## A light switch as mounted: a panel with a lever on the wall face, a conduit
## up to a junction box on the wall's cap, and the box's lamp — red while the
## room is dark, green once someone has thrown it. The lamp is what reads from
## the camera; it is what gets returned, to be recoloured.
func _switch(r: Museum.Room) -> MeshInstance3D:
	var s := r.switch_at
	var root := Node3D.new()
	root.position = _to_world(s.x + 0.5 + r.face.x * 0.5, s.y + 0.5 + r.face.y * 0.5)
	root.rotation.y = atan2(-r.face.x, -r.face.y)
	world.add_child(root)
	var part := func(size: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		m.material_override = MuseumView.toon(colour)
		m.position = at
		root.add_child(m)
		return m
	part.call(Vector3(0.24, 0.32, 0.04), COLOURS.ink, Vector3(0, 0.8, 0.02))
	part.call(Vector3(0.2, 0.28, 0.05), Color("#e8ddc0"), Vector3(0, 0.8, 0.04))
	part.call(Vector3(0.05, 0.12, 0.05), COLOURS.ink, Vector3(0, 0.82, 0.08)).rotation.x = 0.5
	part.call(Vector3(0.05, 0.3, 0.04), Color("#5a5560"), Vector3(0, 1.05, 0.03))
	part.call(Vector3(0.28, 0.1, 0.28), Color("#5a5560"), Vector3(0, MuseumView.WALL_HEIGHT + MuseumView.CAP_H + 0.05, -0.18))
	var lamp := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.07
	c.height = 0.05
	lamp.mesh = c
	lamp.material_override = _flat(COLOURS.switch_off)
	lamp.position = Vector3(0, MuseumView.WALL_HEIGHT + MuseumView.CAP_H + 0.12, -0.18)
	root.add_child(lamp)
	return lamp


## The piece, glowing over its case, and the door out: a frame in the outer
## wall with a green door, a light over it and SALIDA above.
func _build_job() -> void:
	var colour := Color(Heist.loot.colour)
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 1.4
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	loot_node = LootModels.build(Heist.loot.shape, colour)
	world.add_child(loot_node)
	# The star of the collection gets a spotlight from the ceiling: a cone of
	# warm white straight down on its case, its beam showing in the dust.
	loot_spot = SpotLight3D.new()
	loot_spot.position = _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 4.2)
	loot_spot.rotation = Vector3(-PI / 2, 0, 0)
	loot_spot.light_color = Color("#fff0d6")
	loot_spot.light_energy = 9.0
	loot_spot.spot_range = 6.0
	loot_spot.spot_angle = 14.0
	loot_spot.spot_angle_attenuation = 0.6
	loot_spot.shadow_enabled = true
	loot_spot.light_volumetric_fog_energy = 6.0
	world.add_child(loot_spot)
	var glow := OmniLight3D.new()
	glow.light_color = colour
	glow.light_energy = 1.2
	glow.omni_range = 2.5
	loot_node.add_child(glow)

	var door := Node3D.new()
	door.position = _to_world(Heist.exit.x + 0.5 + Heist.exit_face.x * 0.5, Heist.exit.y + 0.5 + Heist.exit_face.y * 0.5)
	door.rotation.y = atan2(-Heist.exit_face.x, -Heist.exit_face.y)
	world.add_child(door)
	var box := func(size: Vector3, mat: Material, at: Vector3) -> void:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.material_override = mat
		mi.position = at
		door.add_child(mi)
	var frame := MuseumView.toon(Color("#1b1622"))
	box.call(Vector3(0.1, 1.3, 0.12), frame, Vector3(-0.42, 0.65, 0.04))
	box.call(Vector3(0.1, 1.3, 0.12), frame, Vector3(0.42, 0.65, 0.04))
	box.call(Vector3(0.94, 0.1, 0.12), frame, Vector3(0, 1.3, 0.04))
	var panel := StandardMaterial3D.new()
	panel.albedo_color = COLOURS.switch_on.darkened(0.3)
	panel.emission_enabled = true
	panel.emission = COLOURS.switch_on
	panel.emission_energy_multiplier = 0.6
	box.call(Vector3(0.74, 1.2, 0.04), panel, Vector3(0, 0.6, 0.02))
	box.call(Vector3(0.06, 0.06, 0.05), MuseumView.toon(Color("#f0c46a")), Vector3(0.26, 0.6, 0.06))
	var sign := Label3D.new()
	sign.text = "SALIDA"
	sign.font = Hud.ARCADE
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.modulate = COLOURS.switch_on
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.75, 0.1)
	door.add_child(sign)
	panel_mat = null
	panel_glow = null
	if Heist.team:
		_build_panel()
	var exit_light := OmniLight3D.new()
	exit_light.light_color = COLOURS.switch_on
	exit_light.light_energy = 1.5
	exit_light.omni_range = 3.0
	exit_light.position = Vector3(0, 1.5, 0.5)
	door.add_child(exit_light)


## The alarm panel: a grey box on the wall with a big lamp, orange while it
## waits, green while someone holds it.
func _build_panel() -> void:
	var node := Node3D.new()
	node.position = _to_world(Heist.panel.x + 0.5 + Heist.panel_face.x * 0.5, Heist.panel.y + 0.5 + Heist.panel_face.y * 0.5)
	node.rotation.y = atan2(-Heist.panel_face.x, -Heist.panel_face.y)
	world.add_child(node)
	var box := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.6, 0.14)
	box.mesh = b
	box.material_override = MuseumView.toon(Color("#5c6370"))
	box.position = Vector3(0, 1.0, 0.07)
	node.add_child(box)
	panel_mat = StandardMaterial3D.new()
	panel_mat.emission_enabled = true
	panel_mat.emission_energy_multiplier = 2.0
	var lamp := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.2
	lamp.mesh = s
	lamp.material_override = panel_mat
	lamp.position = Vector3(0, 1.1, 0.16)
	node.add_child(lamp)
	var lever := MeshInstance3D.new()
	var l := BoxMesh.new()
	l.size = Vector3(0.06, 0.2, 0.06)
	lever.mesh = l
	lever.material_override = MuseumView.toon(Color("#e03131"))
	lever.position = Vector3(0.14, 0.88, 0.17)
	node.add_child(lever)
	panel_glow = OmniLight3D.new()
	panel_glow.light_energy = 1.2
	panel_glow.omni_range = 2.5
	panel_glow.position = Vector3(0, 1.1, 0.5)
	node.add_child(panel_glow)
	var sign := Label3D.new()
	sign.text = "ALARMA"
	sign.font = Hud.ARCADE
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.modulate = Color("#ff922b")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.55, 0.1)
	node.add_child(sign)


func _draw_panel() -> void:
	if panel_mat == null:
		return
	var held := Heist.panel_by != ""
	var t := Time.get_ticks_msec() / 1000.0
	var c := COLOURS.switch_on if held else Color("#ff922b")
	panel_mat.albedo_color = c
	panel_mat.emission = c
	panel_glow.light_color = c
	# Blinks while someone waits at the case for it.
	panel_glow.light_energy = 1.2 if held or not Heist.waiting else (0.4 + 1.2 * absf(sin(t * 6.0)))


## Each piece its own shape: a cut gem, an egg, a crown with points, a jade
# --- Drawing -------------------------------------------------------------------------

func _draw_frame(dt: float) -> void:
	# The ears between the thieves still in, facing the way the camera does
	# (so left on screen is left in the ear).
	if ear and camera:
		var at := Vector3.ZERO
		var n := 0
		for t in thieves:
			if not t.out:
				at += _to_world(t.x, t.y, 1.2)
				n += 1
		ear.global_transform = Transform3D(camera.global_basis, at / n if n > 0 else camera.global_position)
	for i in thieves.size():
		var p := thieves[i]
		var f := thief_nodes[i]
		f.set_state(_to_world(p.x, p.y), p.dir, p.posture, dt)
		f.scale = Vector3.ONE * (0.75 if p.out else 1.0)
		# Seen through the cases: your colour while nobody sees you, the
		# alarm red the moment one does, all but gone once you are out.
		if p.out:
			f.set_ghost(COLOURS.ink, 0.35)
		elif p.hidden:
			f.set_ghost(COLOURS.thief if i == 0 else COLOURS.thief2, 0.75)
		else:
			f.set_ghost(COLOURS.alert, 1.0)
	for i in guards.size():
		var g := guards[i]
		var f := guard_nodes[i]
		f.set_state(_to_world(g.x, g.y), g.dir, 0.0, dt)
		f.set_ghost(COLOURS.alert if g.sees_player else COLOURS.guard, 0.75)
		var view := Sim.view_of(g)
		var torch := torches[i]
		torch.light_color = COLOURS.alert if g.sees_player else TORCH_COLOUR
		torch.spot_angle = rad_to_deg(view.half) * 0.85
		torch.spot_range = view.range + 1.0
		# Under the ceiling lights a torch is pointless, and switched off.
		torch.light_energy = 0.0 if Museum.is_lit(g.x, g.y) else (TORCH_ENERGY_ALERT if g.alert else TORCH_ENERGY)
		_draw_cone(g, cones[i])
	_draw_room_lights()
	_draw_loot()
	_follow_camera(dt)
	_draw_hud()


func _draw_room_lights() -> void:
	var lit: Array = []
	for r in Museum.rooms:
		var on := Museum.lights_left[r.id] > 0
		switch_marks[r.id].material_override.albedo_color = COLOURS.switch_on if on else COLOURS.switch_off
		lit_washes[r.id].visible = on
		if on:
			var c := _to_world(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0, 2.6)
			lit.append([c, c.distance_to(camera.position), Vector2(r.rect.size).length()])
	lit.sort_custom(func(a, b): return a[1] < b[1])
	for i in room_lights.size():
		var l := room_lights[i]
		if i < lit.size():
			l.position = lit[i][0]
			l.omni_range = lit[i][2] / 2.0 + 3.0
			l.light_energy = ROOM_LIGHT_ENERGY
		else:
			l.light_energy = 0.0


## The piece: turning over its case, on the thief's back, or on the floor.
func _draw_loot() -> void:
	# Once the piece is gone the spotlight has nothing to show: it dims.
	if loot_spot:
		loot_spot.light_energy = move_toward(loot_spot.light_energy, 0.0 if Heist.taken else 9.0, 0.15)
	_draw_panel()
	var t := Time.get_ticks_msec() / 1000.0
	if Heist.carrier != "":
		var c: Thief = thieves[0]
		for p in thieves:
			if p.id == Heist.carrier:
				c = p
		loot_node.position = _to_world(c.x - cos(c.dir) * 0.2, c.y - sin(c.dir) * 0.2, 1.05 - c.posture * 0.5)
	elif Heist.dropped != Vector2.INF:
		loot_node.position = _to_world(Heist.dropped.x, Heist.dropped.y, 0.2)
	else:
		loot_node.position = _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05 + sin(t * 2.0) * 0.05)
	loot_node.rotation.y = t * 1.2


## The view cone, rebuilt from rays every frame so it stops at the walls.
func _draw_cone(g: Guard, node: MeshInstance3D) -> void:
	var im: ImmediateMesh = node.mesh
	im.clear_surfaces()
	var view := Sim.view_of(g)
	var origin := _to_world(g.x, g.y, 0.03)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := Vector3.ZERO
	for i in CONE_RAYS:
		var a: float = g.dir - view.half + 2.0 * view.half * i / (CONE_RAYS - 1)
		# Painted over the cases: this is where someone standing is seen.
		var far := Museum.cast_ray(g.x, g.y, a, Sim.LIT_RANGE, true)
		var ex: float = g.x + cos(a) * view.range
		var ey: float = g.y + sin(a) * view.range
		var d: float = far if far > view.range and Museum.is_lit(ex, ey) else minf(far, view.range)
		var pnt := _to_world(g.x + cos(a) * d, g.y + sin(a) * d, 0.03)
		if i > 0:
			im.surface_add_vertex(origin)
			im.surface_add_vertex(prev)
			im.surface_add_vertex(pnt)
		prev = pnt
	im.surface_end()
	var m: StandardMaterial3D = node.material_override
	var colour: Color = COLOURS.alert if g.sees_player else (COLOURS.cone_alert if g.alert else COLOURS.cone)
	# Faint: the torch's beam in the fog does most of the showing, this just
	# marks the edge of what the guard sees.
	m.albedo_color = Color(colour, 0.16 if g.sees_player else (0.09 if g.alert else 0.045))


## Where the camera sits over what it looks at: high up and a little behind.
const CAM_OFFSET := Vector3(0, 15.4, 6)
## The shake at full trauma: how far the view slides (in metres at the
## camera) and how far it rolls (radians).
const SHAKE_MOVE := 0.45
const SHAKE_ROLL := 0.025
## How much of the trauma wears off each second.
const SHAKE_DECAY := 1.2

## where the camera is headed, followed smoothly; the shake and the punch are
## put on top of it every frame, so they never pile up in the follow
var cam_rest := Vector3.ZERO
## 0..1: how shaken the camera is. It is squared for the shake, so small
## knocks barely move it and big ones hit hard, and it decays by itself.
var trauma := 0.0
## 0..1: how far the camera has swooped in towards the thief (the steal)
var punch := 0.0
var punch_tween: Tween


func _camera_target() -> Vector3:
	var live := thieves.filter(func(p): return not p.out)
	var watched: Array = live if not live.is_empty() else thieves
	var mx := 0.0
	var my := 0.0
	for p in watched:
		mx += p.x
		my += p.y
	mx /= watched.size()
	my /= watched.size()
	# Keep the frame inside the building.
	return _to_world(clampf(mx, 7, Museum.w - 7), clampf(my, 5.5, Museum.h - 5.5), 0.6)


func _snap_camera() -> void:
	var t := _camera_target()
	cam_rest = t + CAM_OFFSET
	trauma = 0.0
	punch = 0.0
	if punch_tween:
		punch_tween.kill()
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.position = cam_rest
	camera.look_at(t)


func _follow_camera(dt: float) -> void:
	var t := _camera_target()
	var k := 1.0 - pow(0.0015, dt)
	cam_rest = cam_rest.lerp(t + CAM_OFFSET, k)
	var focus := cam_rest - CAM_OFFSET
	camera.position = focus + CAM_OFFSET * (1.0 - 0.22 * punch)
	camera.look_at(focus)
	# The shake slides the picture rather than moving the camera, so the
	# lights nearest the camera do not flicker from room to room.
	trauma = maxf(trauma - SHAKE_DECAY * dt, 0.0)
	var s := trauma * trauma
	var time := Time.get_ticks_msec() / 1000.0
	camera.h_offset = SHAKE_MOVE * s * (sin(time * 47.0) + 0.5 * sin(time * 83.0 + 1.3)) / 1.5
	camera.v_offset = SHAKE_MOVE * s * (sin(time * 53.0 + 2.1) + 0.5 * sin(time * 71.0 + 0.4)) / 1.5
	camera.rotate_object_local(Vector3.BACK, SHAKE_ROLL * s * sin(time * 37.0 + 0.7))


## A jolt of the camera: 0.6 for a guard's first yell, less for a crash.
func _shake(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## The piece is yours: the camera swoops in on the thief and eases back out.
func _punch_in() -> void:
	if punch_tween:
		punch_tween.kill()
	punch_tween = create_tween()
	punch_tween.tween_property(self, "punch", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	punch_tween.tween_property(self, "punch", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw_hud() -> void:
	if thieves.is_empty():
		return
	var ia := "IA: Laya %d ms" % brain.last_ms if brain.status == "laya" else "IA: reglas"
	var parts := PackedStringArray()
	for i in thieves.size():
		var p := thieves[i]
		var stance := "DE PIE"
		if p.crouched:
			stance = "A GATAS" if p.posture >= 1.0 else "BAJANDO"
		elif p.posture > 0:
			stance = "SUBIENDO"
		var state := "PILLADO" if p.out else ("A CUBIERTO" if p.hidden else "A LA VISTA")
		parts.append(("P%d " % (i + 1) if thieves.size() == 2 else "") + "%s · %s" % [state, stance])
	parts.append(ia)
	var any_seen := thieves.any(func(p): return not p.out and not p.hidden)
	# The arrow at the screen edge, from whoever is nearest: to the piece, or
	# to the door once someone has it.
	var goal := Heist.objective()
	var ref := thieves[0]
	for p in thieves:
		if not p.out and (ref.out or Museum.dist(p.x, p.y, goal.x, goal.y) < Museum.dist(ref.x, ref.y, goal.x, goal.y)):
			ref = p
	var d := Museum.dist(ref.x, ref.y, goal.x, goal.y)
	var angle := atan2(goal.y - ref.y, goal.x - ref.x) if d > 6 and phase == "playing" else NAN
	var job := {
		"working": Heist.by != "",
		"progress": Heist.progress,
		"verb": Heist.loot.verb,
		"carrying": Heist.carrier != "",
		"dropped": Heist.dropped != Vector2.INF,
		"name": Heist.loot.name,
		"waiting": Heist.waiting,
		"panel": Heist.panel_by != "" and not Heist.taken,
		"hint": _push_hint(),
	}
	if not hud.menu_open():
		hud.update_play("   ".join(parts), COLOURS.alert if any_seen else COLOURS.safe, log_lines, job, angle, COLOURS.switch_on if Heist.carrier != "" else Color(Heist.loot.colour))
	var cards: Array = []
	for g in guards:
		var card := {"name": g.name, "title": "Te ha visto" if g.sees_player else (g.decision.label if g.decision else "pensando…"), "colour": COLOURS.alert if g.sees_player else Hud.C.text}
		if g.decision and not g.sees_player:
			var opts: Array = []
			for k in g.decision.probabilities:
				opts.append([g.decision.labels.get(k, k), g.decision.probabilities[k]])
			opts.sort_custom(func(a, b): return a[1] > b[1])
			card.options = opts
			card.note = "ritmo %d%% · %s%s" % [roundi(g.decision.aggression * 100), Mind.LOOK_LABEL[g.decision.look], " · duda" if g.decision.torn else ""]
		cards.append(card)
	hud.set_ia(show_ia and phase == "playing", cards)
