class_name Game
extends Node3D
## The game: screens, the loop, and drawing the world each frame.
##
## Two modes. The story: twenty fixed nights, easy to hard, with a tale (Story).
## The generative: a new museum every time, at the difficulty and size you
## pick. Either with one thief or two; with two, the job takes both (Heist).
##
## Screens: title (pick the mode; the story asks first how many thieves, in
## the sticker carousel) → the mode's menu (the story: the town's map, a
## museum and its night; the generative: difficulty, size, theme and how
## many thieves) → [prologue] → loot (the piece and its story) → mission
## (the plan, a map) → countdown → playing ⇄ paused → caught, or escaped with the piece (next level). No
## clock: a round lasts as long as it takes. The loop is the web version's Game.tsx tick: thieves and their
## noise, the job and its alarm, guards, the yell, the warning, keeping apart,
## lights, thinking (Laya through BrainClient, or the fallback rules),
## hidden, caught (NightLoop).
##
## This script is the hub: the state that everything reads (mode, phase, thieves, guards,
## the settings' values), the screens that lead to a night, the rounds' layout and the
## frame's order. The rest is in controllers it owns (the vars just below), each one a
## class in scenes/ that holds a reference back to Game and has a short public face:
## LaunchArgs, HouseRun, PreviewStand, SettingsScreens, NightEnv, Scenery, CameraRig,
## Hands, MegaphoneRun, NightLoop, ChallengeScreens, BriefScreens.

## the guards think this often
const THINK_EVERY_MS := 1100.0
## The words on screen are keys into Text (locale/texts.csv).
const SIZE_NAMES := {"small": "MENU_SIZE_SMALL", "medium": "MENU_SIZE_MEDIUM", "large": "MENU_SIZE_LARGE"}
const DIFFICULTY_NAMES := {"easy": "MENU_DIFFICULTY_EASY", "medium": "MENU_DIFFICULTY_MEDIUM", "hard": "MENU_DIFFICULTY_HARD"}
## "" is any theme, mixed (Museum.only_theme's own "any" value).
const THEME_NAMES := {"": "MENU_THEME_RANDOM", "antiguo": "MENU_THEME_ANCIENT", "edad_media": "MENU_THEME_MEDIEVAL",
	"prehistoria": "MENU_THEME_PREHISTORY", "naturaleza": "MENU_THEME_NATURE", "moderna": "MENU_THEME_MODERN"}
const THEME_CHOICE_NAMES := {"": "AL AZAR", "antiguo": "ANTIGUO", "edad_media": "MEDIEVAL",
	"prehistoria": "PREHISTORIA", "naturaleza": "NATURALEZA", "moderna": "MODERNA"}
## What a guard yells on spotting you.
const SHOUTS := ["HUD_SHOUT_1", "HUD_SHOUT_2", "HUD_SHOUT_3"]

const COLOURS := {
	"night": Color("#0f0d14"),
	"thief": Color("#2ec4a6"),
	"thief_dark": Color("#12705f"),
	"thief2": Color("#f0a13a"),
	"thief2_dark": Color("#8a5410"),
	"thief3": Color("#b07cff"),
	"thief3_dark": Color("#5b3a99"),
	"thief4": Color("#4dabf7"),
	"thief4_dark": Color("#1c5d99"),
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

## The parts of the game that have a controller of their own, each with a narrow
## way in (see the README, scenes/).
var launch := LaunchArgs.new(self)
var house := HouseRun.new(self)
var podium := PreviewStand.new(self)
var options := SettingsScreens.new(self)
var nightenv := NightEnv.new(self)
var scenery := Scenery.new(self)
var rig := CameraRig.new(self)
var hands := Hands.new(self)
var loudspeaker := MegaphoneRun.new(self)
var loop := NightLoop.new(self)
var challenges := ChallengeScreens.new(self)
var briefing := BriefScreens.new(self)
## Atraco Sorpresa's plan, moving the cursor over its items with the left
## stick (edge-triggered, like Hub._stick_side/_stick_vertical): which way
## it was pushed last, so a held stick does not repeat every frame.
var _plan_stick_x := 0.0
var _plan_stick_y := 0.0
## La casa como punto de partida (sustituye el menú de tarjetas) y la pausa
## real vista con su misma pinta; ver scenes/hub.gd.
var hub := Hub.new(self)

## "story", "generative" or "challenge"
var mode := "story"
## the story night picked on its menu
var story_pick := 1
var size := "small"
## the generative mode's museum theme (Themes), "" for any theme mixed
var theme := ""
## the seed the museum on screen was laid out with, generative only — with
## size and theme, MuseumCode.encode turns it into the plan's shareable code.
var last_map_seed := 0
## a seed typed in as a code (MuseumCode.decode), waiting for _new_round's
## generative "else" to use once instead of a random one; -1 once spent.
var pending_seed := -1
## one thief or two on the same keyboard
var players := 1
var sound_on := true
var music_on := true
var show_ia := false
var dev_mode := false
var dev_overlay := DevOverlay.new()
## the museum's loudspeaker (Megaphone) and how it is switched on: one of
## Settings.MEGAPHONE_MODES ("both", "text", "sound", "off")
var megaphone_mode := "both"
## the loudspeaker's voice (MegaVoice)
var mega_voice: MegaVoice
## one of Settings.SCREEN_MODES ("window", "fullscreen", "borderless")
var screen_mode := "window"
var vsync := true
## frames per second, 0 for unlimited (one of Settings.FPS_LIMITS)
var fps_limit := 0
## percent, 0..100 in steps of ten
var music_volume := 100
var effects_volume := 100
## the window's size (Settings.WINDOW_SIZES index, -1 auto) and the UI's
var window := -1
var ui_scale := 100
var rumble := true
var rumble_strength := 100
var deadzone := 50
## Who plays with what: one entry per thief — "any" (on your own: the whole
## keyboard and every pad), "kb_left" (WASD side), "kb_right" (arrows side)
## or "pad:N". Picked on the player-select screen, Mario Kart style.
var seats: Array[String] = ["any"]
## the map is out: the thieves stand still to read it, the guards do not
var map_open := false
var level := 1
## who was caught first, and by which guard (its name), for the police file;
## -1 and "" while nobody is
var caught_thief := -1
var caught_by := ""
## how many police files this session has opened: each gets the next number
var files_opened := 0
## an end shown to look at it (--menu=escaped): it unlocks nothing
var just_looking := false
var thieves: Array[Thief] = []
var guards: Array[Guard] = []
var phase := "title"
var stride := [0.0, 0.0, 0.0, 0.0]
## the push key held last frame, per thief: one push per press
var push_held := [false, false, false, false]
## the same for the smoke bomb key: one bomb per press
var smoke_held := [false, false, false, false]
## at a minigame as the frame began, per thief: a press that ends one is
## not also an action on the room
var busy := [false, false, false, false]
var last_think := 0.0
var last_spread := 0.0
var think_tick := 0
var log_lines: Array[String] = []

var brain: BrainClient
var sfx: Sfx
var hud: Hud
var world: Node3D
var camera: Camera3D
var props_view: PropsView
var ear: AudioListener3D


func _ready() -> void:
	# The words first: everything below builds some.
	Text.setup()
	# The dust in the air (Fx.dust_field) is the torches' alone: every other
	# light, however or wherever it is made, passes through it unseen.
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Light3D and not n.has_meta(Fx.LIGHTS_DUST):
			(n as Light3D).light_cull_mask &= ~Fx.DUST_LAYER)
	# The map: View (Back, Select) on any pad, as most games have it; Y is
	# kept for something to use (M on the keyboard, by hand).
	if not InputMap.has_action("map"):
		InputMap.add_action("map")
		var e := InputEventJoypadButton.new()
		e.button_index = JOY_BUTTON_BACK
		e.device = -1
		InputMap.action_add_event("map", e)
	# The pause stops the tree (and the physics with it), but not the game
	# itself: its keys, the menus and the music go on. The world only moves
	# in _tick, which the pause does not run.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Devices that are not really pads, ignored before anything sees them
	# (Pads, PadFilter); and pads that drop out and come back (_pad_changed).
	get_tree().root.add_child.call_deferred(PadFilter.new())
	for d in Input.get_connected_joypads():
		hands.pad_guids[d] = Input.get_joy_guid(d)
	Input.joy_connection_changed.connect(hands.pad_changed)
	brain = BrainClient.new()
	add_child(brain)
	brain.decided.connect(_on_decided)
	brain.failed.connect(_on_brain_failed)
	sfx = Sfx.new()
	add_child(sfx)
	mega_voice = MegaVoice.new(sfx)
	add_child(mega_voice)
	hud = Hud.new()
	add_child(hud)
	add_child(hub)
	add_child(dev_overlay)
	hud.ui_sound.connect(func(kind: String) -> void: sfx.ui(kind, 0.6))
	options.load_all()
	nightenv.build()
	# La guarida detrás del hub, en vez de un museo: es donde se empieza
	# ahora, no solo un fondo para que no sea un vacío negro.
	mode = Practice.MODE
	players = 1
	seats = ["any"]
	_new_round(1)
	# The cover first, when the game is simply opened; the hub under it.
	if OS.get_cmdline_user_args().is_empty() and TitleScreen.available():
		_show_cover()
	else:
		hub.show_start()
	launch.apply()


# --- Screens -----------------------------------------------------------------------

## The title screen: the cover, and on any key the menu.
## The menu is built under it at once, so the cover fades away onto it,
## never onto the museum behind; the cover keeps the keys while it is up.
func _show_cover() -> void:
	hub.show_start()
	var cover := TitleScreen.new()
	cover.started.connect(func() -> void: sfx.ui("ok"))
	add_child(cover)


## All title returns use the sticker Hub; optional mode selection opens players.
func _show_title(pick := "", choose := true) -> void:
	get_tree().paused = false
	_close_map()
	_close_tour()
	house.trial_end()
	challenges.testing = null
	dojo_from_title = true
	podium.drop()
	if mode != Practice.MODE or den_view == null:
		mode = Practice.MODE
		_new_round(1)
	hub.show_start(pick)
	if choose and pick in ["story", "dojo"]:
		hub._ask_players(pick)


func _pick_players(which: String) -> void:
	hub._ask_players(which)


func _players_picked(which: String, n: int) -> void:
	players = n
	if which == "story":
		_story_players(n)
	elif which == "dojo":
		_dojo_start(n)
	else:
		_show_generative_menu()


# --- Challenges ------------------------------------------------------------------------


## Out of a game to where it was started from: the editor, if it was a try.
func _leave_game(to: Callable) -> void:
	mega_voice.stop()
	house.trial_end()
	if challenges.testing:
		challenges.back_to_editor()
	else:
		to.call()


## The words on that way out.
func _leave_text() -> String:
	if mode == Practice.MODE:
		return Text.t("MENU_DOJO_LEAVE" if dojo_from_title else "PRACTICE_LEAVE")
	return Text.t("EDITOR_BACK_TO_EDITOR" if challenges.testing else "MENU_TO_MENU")


## Out of the game, from the title.
func _quit() -> void:
	options.save()
	mega_voice.stop(true)
	house.trial_end()
	if quit_hook.is_valid():
		quit_hook.call()
	else:
		get_tree().quit()


## What closes the application; a test puts its own here, so as not to quit.
var quit_hook := Callable()
## The pause is asking "¿SALIR DEL JUEGO?" (SÍ / NO) instead of showing its buttons.
var quit_asking := false


## The story with n thieves (picked in the player selector): a gang first
## says which controls are whose (_show_join); then on to the town
## (_story_gang). Each gang has its own way through the nights (Story.unlocked).
func _story_players(n: int) -> void:
	if n >= 2:
		hands.show_join("story", n)
		return
	seats = ["any"]
	pads_lost.clear()
	_story_gang(1)


## The gang is ready: on to the town, where it last got to; the first
## time, the tale before it.
func _story_gang(n: int) -> void:
	players = n
	mode = "story"
	story_pick = Story.unlocked(n)
	if story_pick == 1:
		briefing.show_prologue()
	else:
		_show_city()


# --- The way in to a heist: the town, a museum, its plan (Tour) -----------------------

## The way in, while it is up: the town in 3D and all that follows (Tour);
## and whether it all moves at once (the tests).
var tour: Tour
var tour_hurry := false


## The town, in 3D (Tour): museum m picked, or the one story_pick is in.
## fresh: a museum just opened by a big job, to show it opening.
func _show_city(m := -1, fresh := -1) -> void:
	_open_tour().open_city(players, m if m >= 0 else Tour.next_stop(players), fresh)


## Inside heist n's museum, its room picked: back from a heist.
func _show_museum_tour(n: int) -> void:
	story_pick = clampi(n, 1, Story.unlocked(players))
	_open_tour().open_museum(players, story_pick)


## A new way in over whatever is on screen: the menus fade, the game behind
## stops being drawn while the town covers it.
func _open_tour() -> Tour:
	_close_tour()
	mode = "story"
	phase = "tour"
	podium.drop()
	hud.hide_panel()
	tour = Tour.new()
	tour.stage.hurry = tour_hurry
	add_child(tour)
	tour.left.connect(func() -> void:
		_close_tour()
		_show_title("story"))
	tour.room_chosen.connect(_tour_room)
	tour.go.connect(_tour_go)
	tour.told.connect(_remember_told)
	tour.sound.connect(func(kind: String) -> void: sfx.ui(kind, 0.6))
	get_viewport().disable_3d = true
	return tour


func _close_tour() -> void:
	get_viewport().disable_3d = false
	if tour:
		tour.queue_free()
		tour = null


## A room picked in the museum: heist n laid out, and its plan out of the
## room (Tour.show_plan).
func _tour_room(n: int) -> void:
	story_pick = n
	mode = "story"
	pads_lost.clear()
	_new_round(n)
	tour.show_plan(_plan_data())


## The same house and trials reached from the title, with the band's own
## story unlocks and records. The origin only chooses the way back.
var dojo_from_title := false


func _dojo_title() -> void:
	_show_title("dojo", false)


func _dojo_start(n: int, picked := false) -> void:
	if n >= 2 and not picked:
		hands.show_join("dojo", n)
		return
	mode = Practice.MODE
	players = n
	dojo_from_title = true
	if n == 1:
		seats = ["any"]
	pads_lost.clear()
	get_viewport().disable_3d = false
	_new_round(1)
	# Walking in at the lounge would flash its own room name first
	# (home_tick); the hideout's name takes that moment instead.
	house.home_room = "salon"
	_start_countdown()
	hud.room_name(Text.t("HIDEOUT_NAME"))


## What the tour needs to tell the plan of the heist laid out: its picture,
## the beats told over it and the marks to look round (PlanBeats), the job
## sheet, what getting the piece out takes, the goals for its stars, and
## whether it has been told before.
func _plan_data() -> Dictionary:
	podium.build()
	var beats := PlanBeats.build(level, players, guards)
	return {
		"n": level,
		"image": Hud.plan_map(guards, _thief_colours().slice(0, thieves.size()), true),
		"tile_px": float(clampi(int(Hud.MAP_WIDTH / Museum.w), 8, 32)),
		"beats": beats,
		"marks": PlanBeats.marks(beats, guards),
		"takes": Briefing.takes(),
		"sheet": {"name": Heist.first_upper(Heist.loot.name), "blurb": Heist.loot.blurb,
			"story": Heist.loot.get("story", ""), "photo": podium.preview.get_texture()},
		"goals": StarSlots.goals(level, players),
		"told": _told(level),
	}


## Heist n's plan told already: done before, or told this time round or on
## an earlier day (kept with the progress, "tour", "told_<gang>").
func _told(n: int) -> bool:
	if retell:
		return false
	if n < Story.unlocked(players) or told_now.has([n, players]):
		return true
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	return int(cfg.get_value("tour", "told_%d" % players, 0)) >= n


var told_now := {}
## every plan told as if new (the docs' pictures)
var retell := false


func _remember_told(n: int) -> void:
	told_now[[n, players]] = true
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	var key := "told_%d" % players
	if int(cfg.get_value("tour", key, 0)) < n:
		cfg.set_value("tour", key, n)
		cfg.save(Story.save)


## ¡A ROBAR! on the plan: the tour fades into the game and the count begins.
func _tour_go(_n: int) -> void:
	get_viewport().disable_3d = false
	var t := tour
	tour = null
	t.fade_out()
	# The "3" once the plan has gone, not under it.
	_start_countdown(Hud.FADE_S)


## Generative settings use the shared sticker carousel.
## on restores focus to the setting just changed.
func _show_generative_menu(on := "") -> void:
	var choices: Array = [
		{"id": "difficulty", "label": Text.t(DIFFICULTY_NAMES[Sim.difficulty]), "sticker": {"easy": "dificultad-facil.png", "medium": "dificultad-media.png", "hard": "dificultad-dificil.png"}[Sim.difficulty], "description": Text.t("MENU_HELP_DIFFICULTY"), "call": _pick_setting.bind("difficulty")},
		{"id": "size", "label": Text.t(SIZE_NAMES[size]), "sticker": {"small": "mapa-pequeno.png", "medium": "mapa-mediano.png", "large": "mapa-grande.png"}[size], "description": Text.t("MENU_HELP_SIZE"), "call": _pick_setting.bind("size")},
		{"id": "theme", "label": Text.t(THEME_NAMES[theme]), "picture": _theme_picture(theme), "description": Text.t("MENU_HELP_THEME"), "call": _pick_setting.bind("theme")},
		{"id": "players", "label": "%dP" % players, "sticker": "jugadores-coop.png", "description": Text.t("MENU_HELP_PLAYERS"), "call": _pick_generative_players},
		{"id": "code", "label": Text.t("MENU_CODE_CARD"), "sticker": "ganzua.png", "description": Text.t("MENU_HELP_CODE"), "call": _show_code_entry},
		{"id": "start", "label": Text.t("MENU_START"), "sticker": "aceptar.png", "call": _start.bind("generative", players)},
		{"id": "back", "label": Text.t("MENU_BACK"), "sticker": "volver.png", "call": _show_title.bind("generative", false)},
	]
	var selected := 5
	for i in choices.size():
		if choices[i].id == on:
			selected = i
	hub.show_screen(Text.t("MENU_GENERATIVE_TITLE"), choices, "generative", "generative", _show_title.bind("generative", false), selected)


func _pick_setting(which: String) -> void:
	var names: Dictionary = {"difficulty": DIFFICULTY_NAMES, "size": SIZE_NAMES, "theme": THEME_NAMES}[which]
	var current: String = Sim.difficulty if which == "difficulty" else (size if which == "size" else theme)
	var choices: Array = []
	var selected := 0
	for key: String in names:
		var option := {"id": key, "label": Text.t(names[key]), "call": _set_setting.bind(which, key)}
		if which == "theme":
			option.picture = _theme_picture(key)
		elif which == "difficulty":
			option.sticker = {"easy": "dificultad-facil.png", "medium": "dificultad-media.png", "hard": "dificultad-dificil.png"}[key]
		else:
			option.sticker = {"small": "mapa-pequeno.png", "medium": "mapa-mediano.png", "large": "mapa-grande.png"}[key]
		if key == current:
			selected = choices.size()
		choices.append(option)
	choices.append({"id": "back", "label": Text.t("MENU_BACK"), "sticker": "volver.png", "call": _show_generative_menu.bind(which)})
	hub.show_screen(Text.t({"difficulty": "MENU_HOW_HARD", "size": "MENU_HOW_BIG", "theme": "MENU_HOW_THEME"}[which]), choices, "generative_choice", "pick", _show_generative_menu.bind(which), selected)


static var _theme_pictures := {}


static func _theme_picture(key: String) -> Texture2D:
	if _theme_pictures.has(key):
		return _theme_pictures[key]
	if key != "":
		_theme_pictures[key] = load("res://assets/ui/temas/%s.png" % key)
	else:
		var collage := Image.create(512, 342, false, Image.FORMAT_RGBA8)
		collage.fill(Color.TRANSPARENT)
		var positions := [Vector2i(18, 48), Vector2i(182, 48), Vector2i(346, 48), Vector2i(100, 184), Vector2i(264, 184)]
		var i := 0
		for theme_key: String in THEME_NAMES:
			if theme_key == "":
				continue
			var icon := _theme_picture(theme_key).get_image()
			if icon.is_compressed():
				icon.decompress()
			icon.resize(148, 99, Image.INTERPOLATE_LANCZOS)
			collage.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), positions[i])
			i += 1
		_theme_pictures[key] = ImageTexture.create_from_image(collage)
	return _theme_pictures[key]


## Save the selected setting and return with focus on its category.
func _set_setting(which: String, k: String) -> void:
	match which:
		"difficulty":
			Sim.difficulty = k
		"size":
			size = k
		_:
			theme = k
	options.save()
	_show_generative_menu(which)


## Player count uses the shared selector and returns to Generative.
func _pick_generative_players() -> void:
	var choices: Array = []
	for n in range(1, 5):
		choices.append({"id": "p%d" % n, "label": "%dP" % n, "res": "res://assets/ui/ninjas_%d.png" % n, "call": _generative_players_picked.bind(n)})
	choices.append({"id": "back", "label": Text.t("MENU_BACK"), "sticker": "volver.png", "call": _show_generative_menu.bind("players")})
	hub.show_screen(Text.t("MENU_HOW_MANY"), choices, "generative_players", "pick", _show_generative_menu.bind("players"), players - 1)


func _generative_players_picked(n: int) -> void:
	players = n
	_show_generative_menu("players")


## Another museum's code, typed in (MuseumCode.decode) instead of a random
## one: a plain text field, keyboard only — the sticker carousel doesn't do
## free text, so this one screen leaves it for Hud.show_menu's own panel.
## warning: the last code tried, if it did not decode, under the field.
func _show_code_entry(warning := "") -> void:
	phase = "generative_code"
	hub.visible = false
	hud.show_menu([
		{"title": Text.t("MENU_CODE_TITLE"), "size": 36},
		{"text": Text.t("MENU_CODE_HELP"), "colour": Hud.C.dim, "wrap": true, "width": 420},
		{"field": {"id": "code_field", "hint": "AAAA", "max_length": MuseumCode.CODE_DIGITS, "width": 180, "call": _submit_code}},
		{"text": warning, "id": "code_warning", "colour": Hud.C.alert},
		{"buttons": [
			{"text": Text.t("MENU_BACK"), "call": _show_generative_menu.bind("code"), "colour": Hud.C.dim},
			{"text": Text.t("MENU_CODE_GO"), "call": func() -> void: _submit_code(hud.field_text("code_field"))},
		], "row": true},
	], "generative_code")


## A typed code applied: size and theme swap in like _set_setting, and the
## seed waits in pending_seed for the next generative round (_new_round's
## "else") to pick up instead of a random one. Back to Generative with it
## already set, rather than a separate confirmation screen.
func _submit_code(code: String) -> void:
	var found := MuseumCode.decode(code)
	if found.is_empty():
		_show_code_entry(Text.t("MENU_CODE_BAD"))
		return
	size = found.size
	theme = found.theme
	pending_seed = found.seed
	options.save()
	_show_generative_menu("start")


## The plan's code, for the player to paste or read aloud elsewhere.
func copy_museum_code(code: String) -> void:
	DisplayServer.clipboard_set(code)
	hud.set_text("code_status", Text.t("BRIEF_CODE_COPIED"), Hud.C.green)


func _start(which: String, n: int, picked := false) -> void:
	# A gang: first, each one says which controls are theirs.
	if n >= 2 and not picked:
		hands.show_join(which, n)
		return
	mode = which
	players = n
	if n == 1:
		seats = ["any"]
	pads_lost.clear()
	if mode == "story":
		_new_round(story_pick)
	else:
		_new_round(1)
	briefing.show(0)


## A real pause: the tree stops, knocked-over props hang in mid-air, until
## SEGUIR (or Esc, or P) or the way out to the title.
func _pause() -> void:
	house.trial_end()
	_close_map()
	quit_asking = false
	phase = "paused"
	get_tree().paused = true
	hub.show_pause()


func _ask_leave() -> void:
	if mode == Practice.MODE and not challenges.testing:
		_quit_to_title()
		return
	_confirm_quit(Text.t("MENU_LEAVE_EDITOR_ASK" if challenges.testing else "MENU_LEAVE_ASK"), _quit_to_title, "paused_leave")


## SALIR DEL JUEGO, from the pause: back (Esc, B, P, Start) is NO.
func _ask_quit() -> void:
	_confirm_quit(Text.t("MENU_QUIT_ASK"), _quit, "paused_quit")


func _confirm_quit(title: String, yes: Callable, screen: String) -> void:
	quit_asking = true
	var choices: Array = [
		{"id": "yes", "label": Text.t("SETTINGS_YES"), "sticker": "aceptar.png", "description": Text.t("MENU_QUIT_ASK_TEXT"), "call": yes},
		{"id": "no", "label": Text.t("SETTINGS_NO"), "sticker": "cancelar.png", "call": _pause},
	]
	hub.show_screen(title, choices, "confirm", "paused", _pause, 1)


func _quit_to_title() -> void:
	get_tree().paused = false
	hud.cctv(false)
	_leave_game(_way_out())


## Over the pause's monitor: the camera of the room the first thief is in,
## "CAM 3 · LA SALA DE LOS HUESOS" (a corridor, just the corridor).
func _camera_caption() -> String:
	var where := Text.t("ZONE_MUSEUM")
	var cam := 1
	if not thieves.is_empty():
		var z := Museum.zone_at(thieves[0].x, thieves[0].y)
		if z:
			cam = z.id + 1
			where = z.label if z.room >= 0 else Text.t("ZONE_CORRIDOR")
	return Text.t("HUD_CCTV_CAM") % [cam, where.to_upper()]


## Under it: the museum, by name when it has one.
func _cctv_museum() -> String:
	if mode == Practice.MODE:
		return Text.t("HIDEOUT_NAME").to_upper()
	if mode == "story":
		return String(Story.museum(Story.museum_of(level)).name).to_upper()
	if mode == "challenge" and challenges.challenge_map and challenges.challenge_map.name != "":
		return challenges.challenge_map.name.to_upper()
	return Text.t("HUD_CCTV_MUSEUM")


## How many headlines the paper picks from (END_HEAD_n), and the longest
## piece's name that fits in one ("¡%s VUELVE A CASA!").
const END_HEADS := 5
const END_HEAD_NAME := 26


## The end of a night. Got away with the piece: the town paper's front page
## (_front_page), the buttons under it. Caught: the police file
## (_police_file), the buttons beside it. The way on (again, or the next)
## with the focus, and the way out, as always.
func _show_end() -> void:
	var colour: Color = Hud.C.alert
	var next := Text.t("END_AGAIN")
	var go := _again
	var boss := false
	if phase == "escaped":
		colour = Hud.C.safe
		next = Text.t("END_NEXT_NIGHT" if mode == "story" else "END_NEXT_HEIST")
		# A museum's big job done: the museum is, and the town shows the next.
		if mode == "story" and Story.is_boss(level) and level < Story.count():
			boss = true
			next = Text.t("END_NEXT_MUSEUM")
			if not challenges.testing:
				go = _leave_game.bind(_show_city.bind(Story.museum_of(level + 1), Story.museum_of(level + 1)))
		if mode == "story" and not challenges.testing:
			# The stars this go won, kept with the best (not when only looking).
			HeistStats.rate(level, players, true, not just_looking)
			if not just_looking:
				Story.unlock(level + 1, players)
				# The go's time, against the band's own best for this heist
				# (the stand's ficha, den_view, shows it by band).
				Story.record_time(level, players, HeistStats.time)
			story_pick = mini(level + 1, Story.count())
			if level >= Story.count():
				_show_ending()
				return
	var ways: Array = [
		{"buttons": [{"text": next, "call": go, "colour": colour}], "big": true},
		{"buttons": [{"text": Text.t("EDITOR_BACK_TO_EDITOR") if challenges.testing else Text.t("END_TO_MENU"), "call": _leave_game.bind(_way_out()), "colour": Hud.C.dim}], "small": true},
	]
	if phase == "escaped":
		hud.show_menu([{"newspaper": _front_page(boss)}] + ways)
	else:
		# The file runs off the bottom of the screen: the buttons beside it.
		hud.show_menu([{"columns": [{"items": [{"mugshot": _police_file()}]}, {"items": ways, "middle": true}], "separation": 48}])


## Out of a night's end, its button or back: to the mode's menu.
func _way_out() -> Callable:
	if mode == Practice.MODE and dojo_from_title:
		return _dojo_title
	return {"story": _show_city, "challenge": challenges.show_menu,
		Practice.MODE: _show_city.bind(CityStage.HIDEOUT), "generative": _show_generative_menu}.get(mode, _show_title)


## Which headline the paper picks: the same heist, the same page.
func _end_pick() -> int:
	return absi(hash(String(Heist.loot.get("name", "")))) % 997 + level


## The town paper the morning after: its name, a big headline, the piece's
## photo and, beside it, the night in a few big figures. After a museum's
## big job (boss), the museum is the news.
func _front_page(boss: bool) -> Dictionary:
	podium.build()
	# Wide, for the page: the same piece, with more room either side.
	podium.preview.size = Vector2i(int(300 * EndPages.PAPER_PHOTO.x / EndPages.PAPER_PHOTO.y), 300)
	var name := String(Heist.loot.get("name", ""))
	var headline := Text.t("END_HEAD_%d" % (_end_pick() % END_HEADS + 1))
	if "%s" in headline:
		headline = headline % name.to_upper() if name.length() <= END_HEAD_NAME else Text.t("END_HEAD_1")
	# Not seen once: half the time, that is the news.
	if HeistStats.count("seen") == 0 and _end_pick() % 2 == 0:
		headline = Text.t("END_HEAD_UNSEEN")
	if boss:
		headline = Text.t("END_HEAD_MUSEUM") % Story.museum_in(Story.museum_of(level)).to_upper()
	var page := {
		"name": Text.t("END_PAPER_NAME"),
		"headline": headline,
		"photo": podium.preview.get_texture(),
		"figures": _figures(),
	}
	# In the story, the stars this go won (HeistStats.rate), the new ones
	# stamped in red.
	if HeistStats.stars != 0:
		page.stars = HeistStats.star_row()
		page.star_names = [Text.t("END_STAR_TAKEN"), Text.t("END_STAR_UNSEEN"), Text.t("END_STAR_FAST")]
	return page


## The night in figures, for the paper: [number, what] each (HeistStats).
func _figures() -> Array:
	var out: Array = []
	for h in HeistStats.highlights():
		var k: String = h[0]
		var n: int = h[1]
		if k == "time":
			out.append([HeistStats.clock(n), Text.t("END_STAT_TIME")])
		elif k == "seen":
			# Seen by a guard: you, or the lot of you.
			out.append([str(n), Text.t("END_STAT_SEEN_MANY" if thieves.size() > 1 else "END_STAT_SEEN_ONE")])
		else:
			out.append([str(n), Text.t("END_STAT_%s_%s" % [k.to_upper(), "ONE" if n == 1 else "MANY"])])
	return out


## The police file: always the same sheet and photo, only the number
## changing, the crime (what was taken, or nearly, and who did the catching
## in one field), the notes. A gang
## caught is the same file: the stamp says how many.
func _police_file() -> Dictionary:
	files_opened += 1
	var n := maxi(1, thieves.size())
	var many := "_MANY" if n > 1 else "_ONE"
	var name := String(Heist.loot.get("name", ""))
	# The jokes change file to file (FILE_JOKES of each), the same for the
	# same file number and night.
	var rand := RandomNumberGenerator.new()
	rand.seed = hash([files_opened, level, name])
	var pick := func(key: String) -> String:
		return Text.t("%s_%d" % [key, rand.randi_range(1, FILE_JOKES[key])])
	# One field, the crime and who caught it in a few words: two draws.
	var crime: String = pick.call("END_FILE_CRIME_ALMOST" if Heist.taken else "END_FILE_CRIME_TRY") % name
	var guard: String = pick.call("END_FILE_BY_GUARD") % caught_by if caught_by != "" else Text.t("END_FILE_BY_NOBODY")
	return {
		"photo": load(EndPages.MUGSHOT_PHOTO),
		"number": Text.t("END_FILE_NUMBER") % files_opened,
		"letterhead": Text.t("END_FILE_LETTERHEAD"),
		"stamp": Text.t("END_FILE_STAMP_MANY") % n if n > 1 else Text.t("END_FILE_STAMP_ONE"),
		"rows": [[Text.t("END_FILE_CRIME"), "%s %s" % [crime, Text.t("END_FILE_BY" + many) % guard]]],
		"notes": [Text.t("END_FILE_NOTES"), pick.call("END_FILE_NOTE_MANY" if n > 1 else "END_FILE_NOTE")],
		"prints": Text.t("END_FILE_PRINTS"),
	}


## How many versions of each joke on the police file there are in Text
## (END_FILE_<KEY>_1 .. _N).
const FILE_JOKES := {"END_FILE_CRIME_TRY": 3, "END_FILE_CRIME_ALMOST": 2,
	"END_FILE_BY_GUARD": 4, "END_FILE_NOTE": 6, "END_FILE_NOTE_MANY": 3}


func _show_ending() -> void:
	phase = "ending"
	sfx.ui("escaped")
	hud.show_menu([
		{"title": Text.t("ENDING_TITLE"), "colour": Hud.C.safe, "size": 48},
		{"text": Story.ending(), "size": 18, "wrap": true},
		{"buttons": [{"text": Text.t("MENU_TO_MENU"), "call": _show_title}]},
	])


## Again, or the next: in the story, back to the museum with the next room
## picked, or the same one again, its plan coming straight back out (told
## already, so straight to looking round it); elsewhere, the plan.
func _again() -> void:
	if mode == "story" and not challenges.testing:
		var caught := phase != "escaped"
		var n := mini(level + 1, Story.count()) if not caught else level
		_show_museum_tour(n)
		if caught:
			get_tree().create_timer(0.7).timeout.connect(func() -> void:
				if tour and tour.state == "museum":
					tour.act("accept"))
		return
	_new_round(level + 1 if phase == "escaped" else level)
	briefing.show(0)


## Where back (Escape, Backspace or B: MenuKeys) goes somewhere, and so
## sounds.
const BACK_PHASES := ["menu", "pick", "generative", "generative_code", "challenge", "prologue", "ending", "brief", "paused", "settings", "caught", "escaped"]


func _unhandled_input(event: InputEvent) -> void:
	if phase == "tour" and tour:
		tour.input(event)
		return
	if phase == "join":
		hands.join_input(event)
		return
	# The night just over, frozen: nothing counts until its page is up.
	if phase == "over":
		return
	# A game of the dojo on: Tab leaves it, and at its end the panel takes the keys.
	if house.trial != null and phase == "playing" and house.trial_input(event):
		get_viewport().set_input_as_handled()
		return
	var key: Key = event.keycode if event is InputEventKey and event.pressed and not event.echo else KEY_NONE
	if key == KEY_N:
		options.set_sound(not sound_on)
		if phase == "settings":
			options.show(options.settings_from, options.settings_page)
		return
	# Selectors also accept number keys as shortcuts to the first four choices.
	if phase == "pick" and key in [KEY_A, KEY_D]:
		hub._select(hub.cursor + (-1 if key == KEY_A else 1))
		return
	if phase == "pick" and key >= KEY_1 and key <= KEY_4:
		if hub.visible and key - KEY_1 < hub.active.size():
			hub._pick(hub.active[key - KEY_1].id)
		return
	var intent := _intent(event)
	match intent:
		"pause":
			_pause()
		"map":
			_toggle_map()
		"skip":
			if phase == "prologue":
				_show_city()
			else:
				briefing.skip_story()
		"back":
			if phase in BACK_PHASES:
				sfx.ui("back")
				_back()
		"accept":
			# The focused button takes E, the full stop and A by itself
			# (ui_accept, as they are let go): pressed here, it would go twice.
			# This is Start, which stands for them, or no button to take them.
			var focus := get_viewport().gui_get_focus_owner()
			if focus is Button and focus.is_visible_in_tree():
				if hud.menu_open() and not event.is_action("ui_accept"):
					(focus as Button).pressed.emit()
			elif phase == "pick":
				if hub.visible:
					hub._pick(hub.active[hub.cursor].id)
		"prev", "next":
			var step := -1 if intent == "prev" else 1
			if phase == "brief":
				var to := briefing.brief_page + step
				if to >= 0 and to < briefing.pages().size():
					briefing.show(to)


## What a press does on the screen that is up: MenuKeys says what it means
## (accept, back...), this where it goes. Playing, Escape, P or Start pause
## and M or View show the map; Space, Enter, B, E, the full stop and A are the
## thieves' (a roll, the action), never a menu's. On the pause, back, P or
## Start go back to the game. Start skips the tale and the briefing, and
## elsewhere stands for accept. LB and RB (and Q, back) flick between the
## briefing's tabs and the assets. "" is nothing.
func _intent(event: InputEvent) -> String:
	var what := MenuKeys.of(event)
	var key: Key = event.keycode if event is InputEventKey and event.pressed and not event.echo else KEY_NONE
	var start := what == "skip" and event is InputEventJoypadButton
	match phase:
		"playing":
			if key in [KEY_ESCAPE, KEY_P] or start:
				return "pause"
			if key == KEY_M or what == "map":
				return "map"
			return ""
		"paused":
			if key == KEY_P or start:
				return "back"
		"prologue", "brief":
			if start:
				return "skip"
	if start:
		return "accept"
	if phase == "brief":
		if key == KEY_Q:
			return "prev"
		if what in ["prev", "next"]:
			return what
	if what in ["accept", "back"]:
		return what
	return ""


## Back, screen by screen: the same as its VOLVER (or its way out).
func _back() -> void:
	match phase:
		"menu": _show_title()
		"pick": hub._pick("back")
		"generative": _show_title("generative")
		"generative_code": _show_generative_menu("code")
		"challenge": challenges.show_menu()
		"prologue": briefing.prologue_back()
		"ending": _show_title()
		"brief": briefing.back()
		"paused":
			if quit_asking:
				_pause()
			else:
				_start_playing()
		"settings": options.back()
		"caught", "escaped": _leave_game(_way_out())


## 3, 2, 1, GO! over the museum, everyone frozen in place until it is over.
## wait: from a menu, the count waits for it to fade away (Hud.FADE_S), the
## camera already coming in on the gang.
func _start_countdown(wait := 0.0) -> void:
	# At home there is no count: the band is there and can move, the camera
	# coming in on it while the town fades away.
	if mode == Practice.MODE:
		podium.drop()
		_start_playing()
		if wait > 0.0:
			rig.intro_camera(wait)
		return
	phase = "countdown"
	podium.drop()
	hud.hide_panel()
	hud.countdown(_count_beep, _start_playing, wait)
	rig.intro_camera(wait + Hud.COUNT_S * Hud.COUNT.size())


func _count_beep(i: int) -> void:
	sfx.ui("go" if i == 3 else "tick")


func _start_playing() -> void:
	phase = "playing"
	hub.visible = false
	get_tree().paused = false
	# Space and Enter can accept SEGUIR on the pause: one still held from there is
	# not a roll until it is let go (Sim.step_thief rolls on the press).
	for t in thieves:
		t.roll_key = true
	podium.drop()
	hud.hide_panel()


# --- Rounds --------------------------------------------------------------------------

## The museum, the gang, the guards, the job and the props for a round,
## from one seed (the same seed, the same night). Returns what the night's
## guard post watches (Sim.assign_posts).
func _lay_out(n: int, map_seed: int) -> int:
	seed(map_seed)
	Sim.gang = players
	if saved_map:
		# A saved map: the way in, the piece, the door and the guards where
		# its maker put them. A story night keeps its museum's colours and
		# theme unless the map chose its own colours.
		Museum.only_theme = String(Sim.custom.get("theme", ""))
		saved_map.apply()
		var own := saved_map.palette()
		if mode == "challenge" or not own.is_empty():
			MuseumView.palette = own
		MuseumView.exhibits = saved_map.exhibits.duplicate()
		Props.list.clear()
	elif mode == "story":
		var night := Story.level(n)
		Sim.new_map(map_seed, night.size, -1, night.shape)
	else:
		Sim.new_map(map_seed, size)
	thieves = [Sim.new_thief("p1")]
	for k in range(2, players + 1):
		thieves.append(Sim.new_thief("p%d" % k))
	guards = Sim.new_guards(Sim.guard_count(Museum.size_name))
	if saved_map:
		Sim.place_guards(guards, saved_map.guards)
	var piece: Dictionary = {}
	if mode == "story":
		piece = Story.level(n).loot
	elif mode == "challenge":
		piece = challenges.challenge_map.loot_piece()
	elif mode == Practice.MODE:
		piece = saved_map.loot_piece()
	Heist.plan_job(level, piece, players, saved_map.job() if saved_map else {})
	_place_things(map_seed)
	return Sim.assign_posts(guards)


## What stands about once the job is planned: the props to knock over, the pedestals
## to pose on, the furniture to hide in, what stands on every other case, the arcades.
func _place_things(map_seed: int) -> void:
	# Things to knock over: never on the tiles the job needs clear.
	var stand := Heist.route[0]
	for t in Heist.route:
		if Museum.dist(t.x + 0.5, t.y + 0.5, Heist.at.x + 0.5, Heist.at.y + 0.5) < 1.1:
			stand = t
			break
	# Empty pedestals to pose on and furniture to hide in: first where a
	# saved map stood them by hand; then the props (a suit of armour is a
	# place to hide too, Props.place keeps it away from the rest); then a few
	# more picked for tonight up to the museum's share, far apart
	# (Hideouts.spread) — never on the piece's case, nor one a saved map
	# filled by hand; a sort a map stood by hand gets none added.
	var by_hand: Array[Vector2i] = []
	var hide_by_hand := {}
	for t in MuseumView.exhibits:
		if t == Heist.at:
			continue
		if MuseumView.exhibits[t] == "plinth":
			by_hand.append(t)
		elif Hideouts.PIECES.has(MuseumView.exhibits[t]):
			hide_by_hand[t] = MuseumView.exhibits[t]
	Plinths.list.clear()
	Hideouts.pieces.clear()
	if saved_map:
		Plinths.put(by_hand)
		Hideouts.put(hide_by_hand)
	# A saved map may stand its own props, by hand.
	if saved_map and not saved_map.props.is_empty():
		saved_map.put_props()
	elif Sim.feature("props"):
		Props.place(map_seed, [Heist.exit, Heist.panel, Heist.panel2, stand, Heist.start])
	else:
		Props.list.clear()
	var keep: Array[Vector2i] = [Heist.at]
	for t in MuseumView.exhibits:
		keep.append(t)
	Hideouts.spread(map_seed, keep, Sim.feature("plinths") and Plinths.list.is_empty(),
		Sim.feature("hideouts") and Hideouts.pieces.is_empty())
	# What stands on every other case tonight, now that the rest is placed:
	# decided once (Collection), for the view and the arcade machines alike.
	Collection.lay_out()
	Arcades.find()
	if mode == Practice.MODE:
		Arcades.find_home()


## The map the round is laid out from (_lay_out): the challenge's, or a
## story night's touched up by hand; null for a museum built from its seed.
var saved_map: MapFile


## The seed a story night builds its museum from (for this many thieves): a
## night that posts a guard for its lesson takes the first of its museums
## where the lesson cannot be dodged.
func _story_seed(n: int) -> int:
	var base := Story.seed_for(n, players)
	if Story.level(n).get("post", "") != "":
		for k in Story.LESSON_TRIES:
			if _lay_out(n, base + k * Story.SEED_STEP) > 0:
				return base + k * Story.SEED_STEP
	return base


func _new_round(n: int) -> void:
	_close_map()
	if mode == "story":
		n = clampi(n, 1, Story.count())
	level = n
	# Each story museum in its own colours; the rest by their seed.
	MuseumView.palette = {}
	MuseumView.exhibits = {}
	saved_map = null
	if mode == "story":
		MuseumView.palette = Story.palette(n)
		Sim.custom = Story.tuning(n)
		# Touched up by hand: that museum, as it was saved.
		saved_map = challenges.night_map(n)
		_lay_out(n, saved_map.seed if saved_map else _story_seed(n))
	elif mode == "challenge":
		Sim.custom = challenges.challenge_map.tuning()
		saved_map = challenges.challenge_map
		_lay_out(n, challenges.challenge_map.seed + n)
	elif mode == Practice.MODE:
		Sim.custom = Practice.tuning()
		saved_map = Practice.map(players)
		_lay_out(n, saved_map.seed)
	else:
		Sim.custom = {"theme": theme} if theme != "" else {}
		last_map_seed = pending_seed if pending_seed >= 0 else randi() % (MuseumCode.MAX_SEED + 1)
		pending_seed = -1
		_lay_out(n, last_map_seed)
	stride = [0.0, 0.0, 0.0, 0.0]
	HeistStats.reset()
	caught_thief = -1
	caught_by = ""
	push_held = [false, false, false, false]
	smoke_held = [false, false, false, false]
	Smoke.reset(thieves)
	loop.guard_steps.clear()
	loop.prop_noises.clear()
	last_think = 0.0
	think_tick = 0
	log_lines.clear()
	Sim.thoughts.clear()
	Sim.light_events.clear()
	scenery.build()
	rig.snap()
	loudspeaker.start(n)
	hud.set_gang(_thief_colours().slice(0, thieves.size()), _thief_darks().slice(0, thieves.size()), Heist.loot)
	hud.set_home(mode == Practice.MODE)
	house.home_room = ""
	house.home_leaving = false
	# In the house: the doors as at the start (all shut, the lounge in sight).
	house.home_sight(true)


## The house as drawn (null out of it): the doors and the dark rooms are its.
var den_view: DenView
## The museum as drawn, in a challenge or a story night (null in the band's
## house): for a challenge's own doors (Museum.doors), to draw them opening
## and shutting (MuseumView.set_map_door).
var museum_view: MuseumView


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT and not event.echo:
		hands.mod_down[[event.keycode, event.location]] = event.pressed
	# On your own either the keyboard or a pad may be in your hands: the
	# hints show whichever was touched last.
	if event is InputEventKey and event.pressed:
		hands.last_pad = false
	elif ((event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)) and Pads.real(event.device):
		hands.last_pad = true
		hands.last_pad_device = event.device
		if event is InputEventJoypadButton and not pads_lost.is_empty():
			hands.reclaim_pad(event.device)
	# Tab skips the tale and the briefing: taken here, before the menu's
	# buttons take it to move the focus along and it never gets that far.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and phase in ["prologue", "brief"]:
		get_viewport().set_input_as_handled()
		if phase == "prologue":
			_show_city()
		else:
			briefing.skip_story()
	if phase == "brief" and briefing.plan_nav_active():
		_plan_nav_input(event)


func reset_plan_nav() -> void:
	_plan_stick_x = 0.0
	_plan_stick_y = 0.0


## Atraco Sorpresa's plan, the one page it has: WASD/flechas (or the D-pad
## or the stick) step plan_cursor over plan_targets() instead of moving the
## focus along "Volver"/"¡EMPEZAR!" below (taken here, before those buttons
## get the arrows — same as KEY_TAB above); the action key starts the night
## right away and back leaves, both the same as their buttons, so the row
## stays a plain, mouse-only alternative and never a second way through the
## same choice. MenuKeys.of still says what E, Space, Escape... mean, as
## everywhere else.
func _plan_nav_input(event: InputEvent) -> void:
	# The hints row under the row below (BriefScreens.show) follows
	# whichever hand just moved, same as hands.last_pad above.
	hud.set_hints_pad(hands.last_pad)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W, KEY_LEFT, KEY_A:
				get_viewport().set_input_as_handled()
				briefing.plan_select(-1)
				return
			KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
				get_viewport().set_input_as_handled()
				briefing.plan_select(1)
				return
	elif event is InputEventJoypadButton and event.pressed and Pads.real(event.device):
		match event.button_index:
			JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT:
				get_viewport().set_input_as_handled()
				briefing.plan_select(-1)
				return
			JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT:
				get_viewport().set_input_as_handled()
				briefing.plan_select(1)
				return
	elif event is InputEventJoypadMotion and Pads.real(event.device):
		var side := signf(event.axis_value) if absf(event.axis_value) > 0.6 else 0.0
		if event.axis == JOY_AXIS_LEFT_X:
			if side != 0.0 and side != _plan_stick_x:
				briefing.plan_select(int(side))
			_plan_stick_x = side
		elif event.axis == JOY_AXIS_LEFT_Y:
			if side != 0.0 and side != _plan_stick_y:
				briefing.plan_select(int(side))
			_plan_stick_y = side
		else:
			return
		get_viewport().set_input_as_handled()
		return
	var what := MenuKeys.of(event)
	if what == "accept":
		get_viewport().set_input_as_handled()
		sfx.ui("ok")
		_start_countdown(Hud.FADE_S)
	elif what == "back":
		get_viewport().set_input_as_handled()
		sfx.ui("back")
		briefing.back()


## Seats whose pad dropped out: seat index -> the guid of the pad it had.
var pads_lost := {}


# --- The loop ------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if podium.preview_pivot:
		podium.preview_pivot.rotate_y(dt * 0.9)
	_music_mood()
	if props_view and not thieves.is_empty():
		var at: Array[Vector3] = []
		for t in thieves:
			# Nothing tips over while a test is on in the house: the bodies stay away.
			at.append(_to_world(t.x, t.y) if not t.out and not t.hiding and not (mode == Practice.MODE and house.trial_active()) else Vector3(0, -50, 0))
		props_view.move_thieves(at)
	if phase == "playing":
		loop.tick(dt)
	_draw_frame(dt)


## The music follows the guards: creeping while they are calm, a pulse
## once any is on alert, all of it while one can see you. Softer in menus.
func _music_mood() -> void:
	var tension := 0.0
	var in_game := phase in ["playing", "countdown", "paused", "over"]
	if in_game:
		for g in guards:
			if g.sees_player:
				tension = 1.0
			elif g.alert:
				tension = maxf(tension, 0.55)
	sfx.mood(tension, 0.8 if in_game else 0.5)
	# The band's house has music of its own, and the museums' fades out.
	sfx.home(mode == Practice.MODE and phase in ["playing", "countdown", "paused"])


## The keys a thief's minigame reads this frame: its directions, action key
## and roll key (Minigame.input_from).
func _game_input(i: int, keys: Dictionary) -> Dictionary:
	var scheme: String = "solo" if thieves.size() == 1 else ["wasd", "arrows", "ijkl", "numpad"][i]
	var action: bool = keys.has(["e", "period", "o", "kpadd"][i]) or (thieves.size() == 1 and keys.has("period"))
	return Minigame.input_from(keys, Sim.SCHEMES[scheme], action)


## Each thief's minigame box, beside it on screen.
var game_boxes: Array[MinigameBox] = []


func _draw_game_boxes() -> void:
	while game_boxes.size() < thieves.size():
		var box := MinigameBox.new()
		hud.add_child(box)
		game_boxes.append(box)
	for i in game_boxes.size():
		var p: Thief = thieves[i] if i < thieves.size() else null
		var g: Minigame = p.game if p and phase in ["playing", "paused"] else null
		var head := camera.unproject_position(_to_world(p.x, p.y, 1.6)) if g else Vector2.ZERO
		var controls := hands.controls(i)
		controls.glyphs = {"action": hands.glyph(i, "action"), "cancel": hands.glyph(i, "roll"), "move": hands.glyph(i, "move")}
		controls.glyphs.lr = controls.glyphs.move if controls.glyphs.move.kind == "stick" else hands.glyph(i, "lr")
		controls.glyphs.ud = controls.glyphs.move if controls.glyphs.move.kind == "stick" else hands.glyph(i, "ud")
		game_boxes[i].follow(g, head, _thief_colours()[i], controls)


## How a thief's figure stands: curled in a roll, dizzy, posing as a statue.
func _pose_of(p: Thief) -> String:
	return "statue" if p.posing else Roll.pose(p)


# --- Prompts: what each thief can do, over its head ------------------------------

## Each thief's bubble of what it can do now (Prompt).
var prompts: Array[Prompt] = []
## what each thief held last frame, to see a press begin
var seat_before: Array = []
## the inputs by their place in _seat_input's answer
const INPUT_AT := {"move": [0, 1, 2, 3], "crouch": [4], "action": [5], "roll": [6]}


func _draw_prompts(dt: float) -> void:
	while prompts.size() < thieves.size():
		var p := Prompt.new()
		hud.add_child(p)
		prompts.append(p)
	for i in prompts.size():
		var p: Thief = thieves[i] if i < thieves.size() else null
		var rows := _prompt_rows(i) if p else []
		var head := camera.unproject_position(_to_world(p.x, p.y, 1.9)) if p else Vector2.ZERO
		prompts[i].show_rows(rows, head, _thief_colours()[i], dt)
		# A press on this thief's controls sinks the glyph for it.
		if i < hands.seat_now.size():
			var was: Array = seat_before[i] if i < seat_before.size() else []
			for input in INPUT_AT:
				for k in INPUT_AT[input]:
					if hands.seat_now[i][k] and not (k < was.size() and was[k]):
						prompts[i].press(input)
	seat_before = hands.seat_now.duplicate(true)


## What the action key would do for thief t where it stands, the first of
## these there is (the bubble says the same, _prompt_rows): a minigame at
## the case or the alarm panel ("job"), a pedestal ("plinth"), a hideout
## ("hide"), an arcade machine ("arcade"), a room's switch ("switch"), a
## prop to push over ("push"). In the band's house, a door next to one
## ("door": open it, or shut it if no one is in its way) comes before all but
## the job; a challenge's own door ("map_door", Museum.doors) the same, in a
## museum. While a trial is on in the house (HouseRun.trial_active) only what
## the trial itself needs is offered. {do, at}, or empty for nothing.
func _action_for(t: Thief) -> Dictionary:
	# A trial on in the house: only what it needs (HouseRun.trial_action).
	if mode == Practice.MODE and house.trial_active():
		return house.trial_action(t)
	var job := Heist.game_for(t)
	if not job.is_empty():
		return {"do": "job", "at": job}
	if mode == Practice.MODE:
		var door := Den.door_near(Vector2i(int(floor(t.x)), int(floor(t.y))))
		if door != "" and Den.can_toggle(door, house.band_points(), players):
			return {"do": "door", "at": door}
		# The start point of a trial next to it (the games, the bench's tests, the circuit).
		if house.trial_lock <= 0.0:
			var start := Practice.start_at(Vector2(t.x, t.y), players)
			if not start.is_empty():
				return {"do": "trial", "id": start.id, "tier": start.tier}
	elif not Museum.doors.is_empty():
		var map_door := Museum.door_near(Vector2i(int(floor(t.x)), int(floor(t.y))))
		if map_door != MapFile.NONE and Museum.can_toggle_door(map_door, house.band_points()):
			return {"do": "map_door", "at": map_door}
	var plinth = Plinths.within_reach(t, thieves)
	if plinth != null:
		return {"do": "plinth", "at": plinth}
	var spot := Hideouts.within_reach(t, thieves)
	if spot:
		return {"do": "hide", "at": spot}
	var arcade := Arcades.within_reach(t, thieves)
	if arcade.x >= 0:
		return {"do": "arcade", "at": arcade}
	var room := Sim.switch_within_reach(t)
	if room:
		return {"do": "switch", "at": room}
	var prop := Props.within_reach(t)
	if prop:
		return {"do": "push", "at": prop}
	return {}


## What thief i can do where it stands, one row each (Prompt): the action
## key for what it would do (_action_for), why it waits, or how the job goes.
func _prompt_rows(i: int) -> Array:
	var p := thieves[i]
	if phase != "playing" or p.out or p.game or map_open:
		return []
	var row := func(input: String, verb: String) -> Dictionary:
		return {"input": input, "glyph": hands.glyph(i, input), "verb": verb}
	# At the case: how the job goes, or why it will not give.
	if Heist.by == p.id and not Heist.taken:
		if Heist.waiting:
			var two: bool = Heist.panel2.x >= 0
			if Heist.minigames():
				return [{"verb": Text.t("HUD_JOB_WAIT_CUTS" if two else "HUD_JOB_WAIT_CUT")}]
			return [{"verb": Text.t("HUD_JOB_WAIT_PANELS" if two else "HUD_JOB_WAIT_PANEL")}]
		if Heist.short_hand:
			return [{"verb": Text.t("HUD_JOB_TWO_LOCKS")}]
		return [{"verb": Heist.loot.verb, "progress": Heist.progress}]
	# Al cogerla ya no se nombra la pieza, solo adónde ir.
	if Heist.carrier == p.id:
		return [{"verb": Text.t("HUD_JOB_CARRYING")}]
	if p.posing:
		return [row.call("move", Text.t("HUD_PLINTH_DOWN"))]
	if p.hiding:
		return [row.call("move", Text.t("HUD_HIDE_OUT"))]
	# A trial on says how to leave it in its own HUD (TrialView), the same for all.
	if house.trial != null:
		return []
	var act := _action_for(p)
	match act.get("do", ""):
		"trial": return [row.call("action", DojoTrials.start_label(act.id, act.tier))]
		"job": return [row.call("action", Text.t({"lockpick": "HUD_GAME_PICK_HINT", "steady": "HUD_GAME_STEADY_HINT"}.get(act.at.kind, "HUD_GAME_WIRES_HINT")))]
		"plinth": return [row.call("action", Text.t("HUD_PLINTH_HINT"))]
		"hide": return [row.call("action", Text.t("HUD_HIDE_HINT"))]
		"arcade": return [row.call("action", Text.t("HIDEOUT_ARCADE_PLAY" if mode == Practice.MODE else "HUD_ARCADE_HINT"))]
		"switch": return [row.call("action", Text.t("HUD_SWITCH_HINT"))]
		"push": return [row.call("action", Text.t("HUD_PUSH_HINT"))]
		"door": return [row.call("action", Text.t("HIDEOUT_DOOR_CLOSE" if Den.is_open(act.at) else "HIDEOUT_DOOR_OPEN"))]
		"map_door": return [row.call("action", Text.t("HIDEOUT_DOOR_CLOSE" if Museum.is_door_open(act.at) else "HIDEOUT_DOOR_OPEN"))]
	return []


## Out comes the map, or away it goes.
func _toggle_map() -> void:
	map_open = not map_open
	if map_open:
		hud.show_map(_live_map(), _thief_colours().slice(0, thieves.size()))
		sfx.ui("pick")
	else:
		hud.hide_map()


## The map as drawn now. In the house it knows the house: which rooms are
## dark (unexplored) and that there is no piece to mark.
func _live_map() -> Image:
	Hud.home_map = mode == Practice.MODE
	Hud.dark_rooms.clear()
	if Hud.home_map and den_view != null and is_instance_valid(den_view):
		for id in Den.ORDER:
			if not den_view.shows(id):
				Hud.dark_rooms.append(id)
	return Hud.live_map(thieves, _thief_colours())


func _close_map() -> void:
	map_open = false
	hud.hide_map()


func _thief_darks() -> Array:
	return [COLOURS.thief_dark, COLOURS.thief2_dark, COLOURS.thief3_dark, COLOURS.thief4_dark]


func _thief_colours() -> Array:
	return [COLOURS.thief, COLOURS.thief2, COLOURS.thief3, COLOURS.thief4]


func _on_decided(decisions: Dictionary, _ms: int) -> void:
	if phase != "playing":
		return
	for g in guards:
		if g.sees_player or not decisions.has(g.id):
			continue
		Sim.apply_decision(g, decisions[g.id])


func _on_brain_failed(reason: String) -> void:
	_log(Text.t("LOG_BRAIN_FAILED") % reason)


func _log(line: String) -> void:
	log_lines.push_front(line)
	log_lines = log_lines.slice(0, 8)


# --- Building the world --------------------------------------------------------

func _to_world(x: float, y: float, height: float = 0.0) -> Vector3:
	return MuseumView.to_world(x, y, height)


## Each piece its own shape: a cut gem, an egg, a crown with points, a jade
# --- Drawing -------------------------------------------------------------------------

func _draw_frame(dt: float) -> void:
	if camera and hud:
		_draw_game_boxes()
		_draw_prompts(dt)
	scenery.draw_figures(dt)
	scenery.draw_room_lights()
	scenery.draw_loot()
	rig.follow(dt)
	_draw_hud(dt)


func _draw_hud(dt: float) -> void:
	if thieves.is_empty():
		return
	# The gang as they are: standing or down, carrying, seen, out.
	var states: Array = []
	for p in thieves:
		states.append({"posture": p.posture, "speed": p.speed if p.moving else 0.0, "carrying": Heist.carrier == p.id,
			"seen": not p.hidden, "out": p.out, "safe": p.safe, "pose": _pose_of(p), "smoke": Smoke.count(p)})
	hud.update_gang(states, dt)
	var alarm := 0
	for g in guards:
		alarm = maxi(alarm, g.suspicion)
	# The kunai at the edge of the screen, pointing from whoever is nearest
	# straight at the objective: the piece, or the door once someone has it.
	var goal := Heist.objective()
	var ref := thieves[0]
	for p in thieves:
		if not p.out and (ref.out or Museum.dist(p.x, p.y, goal.x, goal.y) < Museum.dist(ref.x, ref.y, goal.x, goal.y)):
			ref = p
	var way := {}
	if phase == "playing" and Sim.feature("case") and not ref.out and Museum.dist(ref.x, ref.y, goal.x, goal.y) > 1.5:
		var from := camera.unproject_position(_to_world(ref.x, ref.y))
		var to := camera.unproject_position(_to_world(goal.x, goal.y, 1.0))
		way = {"from": from, "goal": to}
	var job := {
		"dropped": Heist.dropped != Vector2.INF,
		"name": Heist.loot.name,
		"panel": Heist.panels_held() and not Heist.taken,
	}
	# What happened lately, in words (bottom left): only with the AI panel on,
	# beside the guards' thinking.
	var told: Array[String] = []
	if show_ia:
		told = log_lines
	if mode == Practice.MODE and house.home_room == "salon":
		told = [Text.t("HIDEOUT_HINT")]
	if not hud.menu_open():
		hud.update_play(told, job, way, COLOURS.switch_on if Heist.carrier != "" else Color(Heist.loot.colour), alarm)
	var cards: Array = []
	for g in guards:
		var card := {"name": g.name, "title": Text.t("MIND_SEEN") if g.sees_player else (g.decision.label if g.decision else Text.t("MIND_THINKING")), "colour": COLOURS.alert if g.sees_player else Hud.C.text}
		if g.decision and not g.sees_player:
			var opts: Array = []
			for k in g.decision.probabilities:
				opts.append([g.decision.labels.get(k, k), g.decision.probabilities[k]])
			opts.sort_custom(func(a, b): return a[1] > b[1])
			card.options = opts
			card.note = Text.t("MIND_NOTE") % [roundi(g.decision.aggression * 100), Mind.look_label(g.decision.look), Text.t("MIND_TORN") if g.decision.torn else ""]
		cards.append(card)
	hud.set_ia(show_ia and phase == "playing", cards)
