extends Node3D
## The game: screens, the loop, and drawing the world each frame.
##
## Two modes. The story: ten fixed nights, easy to hard, with a tale (Story).
## The generative: a new museum every time, at the difficulty and size you
## pick. Either with one thief or two; with two, the job takes both (Heist).
##
## Screens: title (pick the mode) → the mode's menu (the story: players, the
## town's map, a museum and its night; the generative: difficulty, size and
## players) → [prologue] → loot (the piece and its story) → mission
## (the plan, a map) → countdown → playing ⇄ paused → caught, or escaped with the piece (next level). No
## clock: a round lasts as long as it takes. The loop is the web version's Game.tsx tick: thieves and their
## noise, the job and its alarm, guards, the yell, the warning, keeping apart,
## lights, thinking (Laya through BrainClient, or the fallback rules),
## hidden, caught.

## the guards think this often
const THINK_EVERY_MS := 1100.0
## The words on screen are keys into Text (locale/texts.csv).
const SIZE_NAMES := {"small": "MENU_SIZE_SMALL", "medium": "MENU_SIZE_MEDIUM", "large": "MENU_SIZE_LARGE"}
const DIFFICULTY_NAMES := {"easy": "MENU_DIFFICULTY_EASY", "medium": "MENU_DIFFICULTY_MEDIUM", "hard": "MENU_DIFFICULTY_HARD"}
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
## A fixed handful of room lights, handed to the lit rooms nearest the camera.
const ROOM_LIGHT_POOL := 4
const CONE_RAYS := 40
## The floor cone's dim throw, as a share of its bright pool.
const CONE_DIM := 0.4
## How soft the cone's edges are: between the two bands and at the far rim
## (metres), and at the sides (share of the cone's width on each side).
const CONE_BAND_FEATHER := 0.7
const CONE_RIM_FEATHER := 1.8
const CONE_SIDE_FEATHER := 0.2
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

## "story", "generative" or "challenge"
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
## the seats taken so far on the player-select screen, and for which mode
var joining: Array[String] = []
var join_for := "story"
## when the last seat was taken (ms): one press may arrive twice — a pad
## that shows up as two devices, or one that also sends a key — and must
## not take both seats
var joined_at := -INF
## the map is out: the thieves stand still to read it, the guards do not
var map_open := false
var level := 1
var thieves: Array[Thief] = []
var guards: Array[Guard] = []
var phase := "title"
var stride := [0.0, 0.0, 0.0, 0.0]
## the push key held last frame, per thief: one push per press
var push_held := [false, false, false, false]
## how many seats the player-select screen is filling
var join_count := 2
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
## over each guard's head: its suspicion, and what was last drawn there
var suspicion_marks: Array[Sprite3D] = []
var suspicion_keys: Array[String] = []
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
## each alarm panel's lamp and its glow (two for a gang of four)
var panel_mats: Array[StandardMaterial3D] = []
var panel_glows: Array[OmniLight3D] = []
## the piece turning on its own stand, on the loot screen
var preview: SubViewport
var preview_cam: Camera3D
## the assets screen: which tab, and which item of it
var assets_tab := "loot"
var assets_index := 0
var preview_pivot: Node3D
## the page of the prologue and of the briefing before a night on screen
var prologue_page := 0
var brief_page := 0
var preview_spot: OmniLight3D


func _ready() -> void:
	# The words first: everything below builds some.
	Text.setup()
	# The dust in the air (Fx.dust_field) is the torches' alone: every other
	# light, however or wherever it is made, passes through it unseen.
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is Light3D and not n.has_meta(Fx.LIGHTS_DUST):
			(n as Light3D).light_cull_mask &= ~Fx.DUST_LAYER)
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
				"map": _show_story_map()
				"museum": _show_museum(Story.museum_of(story_pick))
				"generative": _show_generative_menu()
				"challenges": _show_challenge_menu()
				"editor": _show_editor(MapFile.generated(4242, "small"))
				"settings": _show_settings("title")
				"pads": _show_settings("title", "pads")
				"input": _show_join("generative")
				"end":
					phase = "caught"
					_show_end()
	# --intro: the piece, then the countdown, for checking the way in.
	# --challenge: the first of the saved maps instead.
	if "--intro" in OS.get_cmdline_user_args():
		var which := "generative" if "--gen" in OS.get_cmdline_user_args() else "story"
		if "--challenge" in OS.get_cmdline_user_args() and not MapFile.list().is_empty():
			challenge_map = MapFile.list()[0]
			which = "challenge"
		_start(which, 2 if "--two" in OS.get_cmdline_user_args() else 1)
		get_tree().create_timer(1.5).timeout.connect(_start_countdown)
	if "--autostart" in OS.get_cmdline_user_args():
		if "--two" in OS.get_cmdline_user_args():
			players = 2
			_new_round(1)
		_show_brief(_brief_pages().size() - 1)
		get_tree().create_timer(2.0).timeout.connect(_start_playing)
		# --map: and take the map out a moment later.
		if "--map" in OS.get_cmdline_user_args():
			get_tree().create_timer(3.0).timeout.connect(_toggle_map)


# --- Screens -----------------------------------------------------------------------

func _show_title() -> void:
	phase = "title"
	testing = null
	_drop_preview()
	hud.show_menu([
		{"title": Text.t("MENU_TITLE"), "size": 64},
		{"cards": [
			{"title": Text.t("MENU_STORY"), "text": Text.t("MENU_STORY_TEXT"), "stage": MenuStage.make("story"), "call": _show_story_menu, "colour": Hud.C.safe},
			{"title": Text.t("MENU_GENERATIVE"), "text": Text.t("MENU_GENERATIVE_TEXT"), "stage": MenuStage.make("generative"), "call": _show_generative_menu, "colour": Hud.C.gold},
			{"title": Text.t("MENU_CHALLENGE"), "text": Text.t("MENU_CHALLENGE_TEXT"), "stage": MenuStage.make("museum:large"), "call": _show_challenge_menu, "colour": Hud.C.green},
		], "width": 250},
		{"gap": 18},
		{"buttons": [{"text": Text.t("MENU_SETTINGS"), "call": _show_settings.bind("title"), "colour": Hud.C.dim}], "small": true},
		{"gap": 10},
		{"buttons": [{"text": Text.t("MENU_QUIT"), "call": _quit, "colour": Hud.C.dim}], "small": true},
	])


# --- Challenges ------------------------------------------------------------------------

## The challenges: museums made by hand (MapFile), the game's own and the
## player's. The map picked, the page of the list on show, a delete waiting
## for its second press, and the editor while it is open.
const CHALLENGES_A_PAGE := 8
var challenge_map: MapFile
var challenge_page := 0
var challenge_delete := false
var editor: MapEditor


## The maps, a card each — the plan, the name, what kind of night — and a
## new one, which opens the editor.
func _show_challenge_menu() -> void:
	phase = "menu"
	challenge_delete = false
	_drop_preview()
	var maps := MapFile.list()
	var pages := maxi(1, ceili(maps.size() / float(CHALLENGES_A_PAGE)))
	challenge_page = clampi(challenge_page, 0, pages - 1)
	var items: Array = [
		{"title": Text.t("CHALLENGE_TITLE"), "size": 40},
		{"text": Text.t("CHALLENGE_TEXT"), "colour": Hud.C.dim},
	]
	var shown := maps.slice(challenge_page * CHALLENGES_A_PAGE, (challenge_page + 1) * CHALLENGES_A_PAGE)
	if shown.is_empty():
		items.append({"text": Text.t("CHALLENGE_EMPTY")})
	for i in range(0, shown.size(), 4):
		var cards: Array = []
		for m in shown.slice(i, i + 4):
			cards.append({"title": m.name.to_upper(), "text": _challenge_info(m), "picture": MapEditor.picture(m), "call": _show_challenge_map.bind(m),
				"colour": Hud.C.gold if m.built_in else Hud.C.green, "title_size": 10})
		items.append({"cards": cards, "width": 210})
	var small := MapFile.blank(Museum.SIZES.small.w, Museum.SIZES.small.h)
	var row: Array = [{"text": Text.t("CHALLENGE_NEW"), "call": _show_editor.bind(small), "colour": Hud.C.green}]
	if pages > 1:
		items.append({"text": Text.t("CHALLENGE_PAGE") % [challenge_page + 1, pages], "colour": Hud.C.dim, "size": 16})
		row.push_front({"text": Text.t("MENU_PREVIOUS"), "call": _page_challenges.bind(-1), "colour": Hud.C.dim})
		row.append({"text": Text.t("MENU_NEXT"), "call": _page_challenges.bind(1), "colour": Hud.C.dim})
	items.append({"buttons": row, "row": true, "small": true, "focus": 1 if pages > 1 else 0})
	items.append({"buttons": [{"text": Text.t("MENU_BACK"), "call": _show_title, "colour": Hud.C.dim}], "small": true})
	hud.show_menu(items)


func _page_challenges(dir: int) -> void:
	var pages := maxi(1, ceili(MapFile.list().size() / float(CHALLENGES_A_PAGE)))
	challenge_page = posmod(challenge_page + dir, pages)
	_show_challenge_menu()


## A map's line on its card: its size, difficulty and guards, or that it
## cannot be played yet.
func _challenge_info(m: MapFile) -> String:
	if not m.check().is_empty():
		return Text.t("CHALLENGE_UNPLAYABLE")
	return Text.t("CHALLENGE_INFO") % [Heist.first_upper(Text.t(SIZE_NAMES[m.size_name()]).to_lower()),
		Text.t(DIFFICULTY_NAMES[m.difficulty]).to_lower(), m.guards_tonight()]


## One map: its plan, then play it with one to four thieves, edit it, or
## (the player's own) delete it.
func _show_challenge_map(m: MapFile) -> void:
	phase = "challenge"
	challenge_map = m
	var items: Array = [
		{"title": m.name.to_upper(), "size": 36, "colour": Hud.C.gold if m.built_in else Hud.C.green},
		{"text": Text.t("CHALLENGE_BUILT_IN" if m.built_in else "CHALLENGE_MINE") + " · " + _challenge_info(m), "colour": Hud.C.dim, "size": 17},
		{"picture": MapEditor.picture(m, 8), "height": 260},
	]
	if m.check().is_empty():
		items.append({"cards": [
			{"title": Text.t("MENU_PLAY_1"), "stage": MenuStage.make("players:1"), "call": _start.bind("challenge", 1), "colour": COLOURS.thief, "title_size": 12},
			{"title": Text.t("MENU_PLAY_2"), "stage": MenuStage.make("players:2"), "call": _start.bind("challenge", 2), "colour": COLOURS.thief2, "title_size": 12},
			{"title": Text.t("MENU_PLAY_3"), "stage": MenuStage.make("players:3"), "call": _start.bind("challenge", 3), "colour": COLOURS.thief3, "title_size": 12},
			{"title": Text.t("MENU_PLAY_4"), "stage": MenuStage.make("players:4"), "call": _start.bind("challenge", 4), "colour": COLOURS.thief4, "title_size": 12},
		], "width": 140})
	var row: Array = [{"text": Text.t("CHALLENGE_EDIT"), "call": _show_editor.bind(m), "colour": Hud.C.gold}]
	if not m.built_in:
		row.append({"text": Text.t("CHALLENGE_DELETE_SURE" if challenge_delete else "CHALLENGE_DELETE"), "call": _delete_challenge.bind(m), "colour": Hud.C.alert})
	row.append({"text": Text.t("MENU_BACK"), "call": _show_challenge_menu, "colour": Hud.C.dim})
	items.append({"buttons": row, "row": true, "small": true})
	hud.show_menu(items)


## Twice to delete: the first press only asks.
func _delete_challenge(m: MapFile) -> void:
	if not challenge_delete:
		challenge_delete = true
		_show_challenge_map(m)
		return
	MapFile.remove(m)
	_show_challenge_menu()


## The map editor (MapEditor), over everything; back to the challenges when
## it closes.
func _show_editor(m: MapFile) -> void:
	phase = "editor"
	challenge_delete = false
	_drop_preview()
	hud.hide_panel()
	hud.visible = false
	editor = MapEditor.new()
	add_child(editor)
	editor.ui_sound.connect(func(kind: String) -> void: sfx.ui(kind, 0.6))
	editor.closed.connect(func() -> void:
		_drop_editor()
		_show_challenge_menu())
	editor.preview.connect(_editor_preview)
	editor.play.connect(func(map: MapFile) -> void:
		testing = map.copy()
		testing_dirty = editor.dirty
		_drop_editor()
		challenge_map = map
		_start("challenge", 1))
	editor.open(m)


## A map tried from the editor (PROBAR): every way out of the game goes
## back to editing it, not to the menus. And whether it had changes unsaved.
var testing: MapFile
var testing_dirty := false


func _back_to_editor() -> void:
	get_tree().paused = false
	var m := testing
	testing = null
	_show_editor(m)
	editor.dirty = testing_dirty


## Out of a game to where it was started from: the editor, if it was a try.
func _leave_game(to: Callable) -> void:
	if testing:
		_back_to_editor()
	else:
		to.call()


## The words on that way out.
func _leave_text() -> String:
	return Text.t("EDITOR_BACK_TO_EDITOR" if testing else "MENU_TO_MENU")


func _drop_editor() -> void:
	hud.visible = true
	editor.queue_free()
	editor = null


## The map being edited, built in the game's world behind the editor, for
## its camera to fly round.
func _editor_preview(m: MapFile) -> void:
	mode = "challenge"
	challenge_map = m
	players = 1
	seats = ["any"]
	_new_round(1)
	editor.start_preview(world)


## Out of the game, from the title.
func _quit() -> void:
	_save_settings()
	get_tree().quit()


## The story, first: how many thieves. Each gang has its own way through
## the nights (Story.unlocked), shown on its card. A gang then says which
## controls are whose (_show_join), and on to the town (_show_story_map).
func _show_story_menu() -> void:
	phase = "story_players"
	var cards: Array = []
	for n in range(1, 5):
		cards.append({"title": Text.t("MENU_PLAYERS_%d" % n),
			"text": Text.t("MENU_PLAYERS_%d_TEXT" % n) + "\n" + Text.t("STORY_REACHED") % [Story.unlocked(n), Story.count()],
			"stage": MenuStage.make("players:%d" % n), "call": _story_players.bind(n), "colour": _thief_colours()[n - 1], "focus": n == players})
	hud.show_menu([
		{"title": Text.t("MENU_STORY_TITLE"), "size": 44},
		{"text": Text.t("MENU_STORY_TAGLINE"), "colour": Hud.C.gold, "size": 17},
		{"cards": cards, "width": 150},
		{"buttons": [{"text": Text.t("MENU_BACK"), "call": _show_title, "colour": Hud.C.dim}], "row": true},
	])


func _story_players(n: int) -> void:
	if n >= 2:
		_show_join("story", n)
		return
	seats = ["any"]
	_story_gang(1)


## The gang is ready: on to the town, where it last got to.
func _story_gang(n: int) -> void:
	players = n
	story_pick = Story.unlocked(n)
	_show_story_map()


## The town: the museums on their streets, the ones this gang has reached
## open. Landing on one says what it is and how far into it you are;
## pressing it goes in (_show_museum).
func _show_story_map() -> void:
	phase = "story_map"
	var reached := Story.unlocked(players)
	story_pick = clampi(story_pick, 1, reached)
	var here := Story.museum_of(story_pick)
	var stops: Array = []
	for m in Story.MUSEUMS.size():
		stops.append({"n": m + 1, "colour": Color(Story.MUSEUMS[m].colour), "locked": Story.nights_in(m)[0] > reached, "selected": m == here,
			"look": Story.MUSEUMS[m].palette, "call": _pick_museum.bind(m), "open": _show_museum.bind(m)})
	hud.show_menu([
		{"title": Text.t("STORY_MAP_TITLE"), "size": 44},
		{"text": Text.t("STORY_GANG_%d" % players), "colour": _thief_colours()[players - 1], "size": 15},
		{"nights": stops, "style": "city", "height": 330},
		{"text": "", "size": 18, "id": "museum"},
		{"text": "", "size": 15, "id": "museum_text", "colour": Hud.C.dim},
		{"buttons": [{"text": Text.t("MENU_BACK"), "call": _show_story_menu, "colour": Hud.C.dim}], "row": true},
	])
	_pick_museum(here)


## Landing on a museum in the town: its name, how many of its nights are
## done, and what it is.
func _pick_museum(m: int) -> void:
	var museum := Story.museum(m)
	var nights := Story.nights_in(m)
	var done := nights.filter(func(n: int) -> bool: return n < Story.unlocked(players)).size()
	hud.set_text("museum", Text.t("STORY_MUSEUM_LINE") % [museum.name.to_upper(), done, nights.size()], Color(museum.colour))
	hud.set_text("museum_text", museum.text, Hud.C.dim)


## Inside a museum, in its own colours: its nights as rooms (any reached so
## far can be picked), the piece of the one picked turning under a light.
## Pressing a room, or ROBAR, plays it.
func _show_museum(m: int) -> void:
	phase = "museum"
	var reached := Story.unlocked(players)
	var nights := Story.nights_in(m)
	if Story.museum_of(story_pick) != m:
		story_pick = mini(nights[-1], reached)
	var loot: Dictionary = Story.level(story_pick).loot
	_build_preview(loot)
	var stops: Array = []
	for n in nights:
		stops.append({"n": n, "colour": Color(Story.level(n).loot.colour), "locked": n > reached, "selected": n == story_pick,
			"call": _pick_night.bind(n), "open": _play_night})
	var museum := Story.museum(m)
	hud.show_menu([
		{"title": museum.name.to_upper(), "colour": Color(museum.colour).lightened(0.2), "size": 40},
		{"text": museum.text, "colour": Hud.C.dim, "size": 15},
		{"nights": stops, "style": "museum", "palette": museum.palette, "width": 720, "height": 170},
		{"picture": preview.get_texture(), "smooth": true, "height": 110},
		{"text": Text.t("MENU_NIGHT_PIECE") % [story_pick, loot.name.to_upper()], "colour": Color(loot.colour), "size": 17, "id": "night"},
		{"buttons": [
			{"text": Text.t("MENU_BACK"), "call": _show_story_map, "colour": Hud.C.dim},
			{"text": Text.t("STORY_PLAY"), "call": _play_night, "colour": Hud.C.safe},
		], "row": true},
	])


func _play_night() -> void:
	_start("story", players, true)


## Moving along the path picks the night: the piece and its name change in
## place, the menu stays as it is.
func _pick_night(n: int) -> void:
	if n == story_pick or preview == null:
		return
	story_pick = n
	var loot: Dictionary = Story.level(n).loot
	_preview_piece(loot)
	hud.set_text("night", Text.t("MENU_NIGHT_PIECE") % [n, loot.name.to_upper()], Color(loot.colour))


## The generative mode: difficulty and museum size as cards, then play with
## one thief, two or three.
func _show_generative_menu() -> void:
	phase = "menu"
	var levels: Array = []
	for k in ["easy", "medium", "hard"]:
		levels.append({"title": Text.t(DIFFICULTY_NAMES[k]), "stage": MenuStage.make("guards:" + k), "call": _pick_difficulty.bind(k),
			"colour": {"easy": Hud.C.green, "medium": Hud.C.gold, "hard": Hud.C.alert}[k], "selected": Sim.difficulty == k, "focus": Sim.difficulty == k, "title_size": 12})
	var sizes: Array = []
	for k in ["small", "medium", "large"]:
		sizes.append({"title": Text.t(SIZE_NAMES[k]), "stage": MenuStage.make("museum:" + k), "call": _pick_size.bind(k),
			"colour": Hud.C.safe, "selected": size == k, "title_size": 12})
	hud.show_menu([
		{"title": Text.t("MENU_GENERATIVE_TITLE"), "size": 40},
		{"cards": levels, "width": 140},
		{"cards": sizes, "width": 140},
		{"cards": [
			{"title": Text.t("MENU_PLAY_1"), "stage": MenuStage.make("players:1"), "call": _start.bind("generative", 1), "colour": COLOURS.thief, "title_size": 12},
			{"title": Text.t("MENU_PLAY_2"), "stage": MenuStage.make("players:2"), "call": _start.bind("generative", 2), "colour": COLOURS.thief2, "title_size": 12},
			{"title": Text.t("MENU_PLAY_3"), "stage": MenuStage.make("players:3"), "call": _start.bind("generative", 3), "colour": COLOURS.thief3, "title_size": 12},
			{"title": Text.t("MENU_PLAY_4"), "stage": MenuStage.make("players:4"), "call": _start.bind("generative", 4), "colour": COLOURS.thief4, "title_size": 12},
		], "width": 140},
		{"buttons": [{"text": Text.t("MENU_BACK"), "call": _show_title, "colour": Hud.C.dim}], "row": true},
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
	# A gang: first, each one says which controls are theirs.
	if n >= 2 and not picked:
		_show_join(which, n)
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
	_show_brief(0)


## The keys on each side of a shared keyboard: pressing any of them on the
## player-select screen takes that side.
const KB_LEFT := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_C, KEY_E, KEY_Q, KEY_SPACE, KEY_SHIFT, KEY_TAB]
const KB_RIGHT := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_ENTER, KEY_KP_ENTER, KEY_MINUS, KEY_SLASH, KEY_PERIOD, KEY_COMMA]
## The middle of the keyboard, for a third thief: IJKL, U and O.
const KB_MID := [KEY_I, KEY_J, KEY_K, KEY_L, KEY_U, KEY_O]
## The number pad, for a fourth: 8 4 5 6, 0 and +.
const KB_PAD := [KEY_KP_8, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_0, KEY_KP_ADD]


## Player select, like Mario Kart 64: a seat a thief, each taken by whoever
## presses a button on their pad or a key on their part of the keyboard.
## P1 is always teal, P2 orange and P3 purple; the first to press is P1.
func _show_join(which: String, count := 2) -> void:
	phase = "join"
	join_for = which
	join_count = count
	joining.clear()
	joined_at = -INF
	_draw_join()


func _draw_join() -> void:
	var cards: Array = []
	for i in join_count:
		var seat: String = joining[i] if i < joining.size() else ""
		cards.append({"title": Text.t("JOIN_PLAYER") % (i + 1), "text": _seat_label(seat) if seat != "" else Text.t("JOIN_PRESS"),
			"stage": MenuStage.make("seat:%d" % (i + 1)), "colour": _thief_colours()[i],
			"selected": seat != "", "static": true, "animate": seat != "", "dim": seat == "", "title_size": 12})
	hud.show_menu([
		{"title": Text.t("JOIN_TITLE"), "size": 40},
		{"cards": cards, "width": 200},
		{"text": Text.t("JOIN_HOW"), "size": 16},
		{"text": Text.t("JOIN_READY") if joining.size() == join_count else Text.t("JOIN_UNDO"), "size": 16, "colour": Hud.C.gold if joining.size() == join_count else Hud.C.dim},
	])


func _seat_label(seat: String) -> String:
	match seat:
		"kb_left": return Text.t("SEAT_KB_LEFT")
		"kb_right": return Text.t("SEAT_KB_RIGHT")
		"kb_pad": return Text.t("SEAT_KB_PAD")
		"kb_mid": return Text.t("SEAT_KB_MID")
		"any": return Text.t("SEAT_ANY")
	var pad := int(seat.substr(4))
	return Text.t("SEAT_PAD") % [pad + 1, Input.get_joy_name(pad).left(18)]


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
		elif join_count >= 3 and (event.physical_keycode in KB_MID or event.keycode in KB_MID):
			seat = "kb_mid"
		elif join_count >= 4 and (event.physical_keycode in KB_PAD or event.keycode in KB_PAD):
			seat = "kb_pad"
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_B:
			_unjoin()
			return
		seat = "pad:%d" % event.device
	if seat == "" or seat in joining or joining.size() >= join_count:
		return
	var now := Time.get_ticks_msec()
	if now - joined_at < 450:
		return
	joined_at = now
	joining.append(seat)
	sfx.ui("ok")
	_rumble_pad(seat, 0.3, 0.15)
	_draw_join()
	if joining.size() == join_count:
		get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if phase == "join" and joining.size() == join_count:
				seats.assign(joining)
				if join_for == "story":
					# The story's gang goes on to the town, to pick a night.
					_story_gang(join_count)
				else:
					_start(join_for, join_count, true))


func _unjoin() -> void:
	sfx.ui("back")
	if joining.is_empty():
		if join_for == "story":
			_show_story_menu()
		elif join_for == "challenge":
			_show_challenge_map(challenge_map)
		else:
			_show_generative_menu()
		return
	joining.pop_back()
	_draw_join()


## The tale, a paragraph a page, whole at once: turn back, go on, or skip
## the lot and go straight to the night.
func _show_prologue(page := 0) -> void:
	phase = "prologue"
	prologue_page = page
	var pages := Story.prologue()
	var last := page == pages.size() - 1
	hud.show_menu([
		{"title": Text.t("PROLOGUE_TITLE"), "size": 44},
		{"stage": MenuStage.make("story"), "height": 220},
		{"text": pages[page], "size": 19, "wrap": true},
		{"text": _dots(page, pages.size()), "colour": Hud.C.dim, "size": 14},
		{"buttons": [
			{"text": Text.t("MENU_BACK") if page == 0 else Text.t("MENU_PREV"), "call": _prologue_back, "colour": Hud.C.dim},
			{"text": Text.t("PROLOGUE_GO") if last else Text.t("MENU_NEXT"), "call": _show_brief.bind(0) if last else _show_prologue.bind(page + 1)},
		], "row": true, "focus": 1},
		{"buttons": [{"text": Text.t("MENU_SKIP"), "call": _skip_story, "colour": Hud.C.dim}], "small": true},
	])


## Straight to the night: past the tale and the briefing, into the countdown.
func _skip_story() -> void:
	_start_countdown()


func _prologue_back() -> void:
	if prologue_page > 0:
		_show_prologue(prologue_page - 1)
	else:
		_show_museum(Story.museum_of(story_pick))


## ● ○ ○ : where you are in a run of pages.
func _dots(at: int, count: int) -> String:
	var out: Array[String] = []
	for i in count:
		out.append("●" if i == at else "○")
	return " ".join(out)


## Sound and music, their volumes, the screen and the IA panel. Opens from
## the title and from the pause. Each line is a setting (Hud._stepper): Enter
## or a click moves it on, ← and → move it down and up; each change is saved.
func _show_settings(from: String, page := "") -> void:
	_drop_preview()
	settings_from = from
	settings_page = page
	phase = "settings"
	var keys: Array = {
		"": ["ia"],
		"sound": ["sound", "music", "music_volume", "effects_volume"],
		"screen": ["fullscreen", "window", "ui_scale", "vsync"],
		"pads": ["rumble", "rumble_strength", "deadzone"],
	}[page]
	var rows: Array = []
	if page == "":
		rows.append({"text": Text.t("SETTINGS_SOUND_PAGE"), "call": _show_settings.bind(from, "sound")})
		rows.append({"text": Text.t("SETTINGS_SCREEN_PAGE"), "call": _show_settings.bind(from, "screen")})
		rows.append({"text": Text.t("SETTINGS_PADS_PAGE"), "call": _show_settings.bind(from, "pads")})
		rows.append({"text": Text.t("SETTINGS_ASSETS_PAGE"), "call": _show_assets.bind("loot", 0)})
	for k in keys:
		rows.append({"text": _setting_text(k), "step": _step_setting.bind(k)})
	rows.append({"text": Text.t("MENU_BACK"), "call": _settings_back, "colour": Hud.C.dim})
	var title := Text.t({"": "SETTINGS_TITLE", "sound": "SETTINGS_SOUND_TITLE", "screen": "SETTINGS_SCREEN_TITLE", "pads": "SETTINGS_PADS_TITLE"}[page])
	var items: Array = [{"title": title, "size": 48}, {"buttons": rows}]
	match page:
		"sound":
			items.append({"text": Text.t("SETTINGS_SOUND_HELP"), "size": 16, "colour": Hud.C.dim})
		"pads":
			var pads := Input.get_connected_joypads()
			var names: Array = pads.map(func(d): return "%d: %s" % [d + 1, Input.get_joy_name(d)])
			items.append({"text": (Text.t("SETTINGS_PADS_LIST") % " · ".join(names)) if not pads.is_empty() else Text.t("SETTINGS_NO_PADS"), "size": 16, "colour": Hud.C.gold})
			items.append({"text": Text.t("SETTINGS_KEYS_HELP"), "size": 16})
			items.append({"text": Text.t("SETTINGS_PAD_HELP"), "size": 16})
	hud.show_menu(items)


func _setting_text(key: String) -> String:
	var yes := func(on: bool) -> String: return Text.t("SETTINGS_YES") if on else Text.t("SETTINGS_NO")
	match key:
		"sound": return Text.t("SETTINGS_SOUND") % yes.call(sound_on)
		"music": return Text.t("SETTINGS_MUSIC") % yes.call(music_on)
		"music_volume": return Text.t("SETTINGS_MUSIC_VOLUME") % _volume_bar(music_volume)
		"effects_volume": return Text.t("SETTINGS_EFFECTS_VOLUME") % _volume_bar(effects_volume)
		"fullscreen": return Text.t("SETTINGS_FULLSCREEN") % yes.call(fullscreen)
		"vsync": return Text.t("SETTINGS_VSYNC") % yes.call(vsync)
		"window":
			var w := Settings.window_size(window)
			return Text.t("SETTINGS_WINDOW_AUTO" if window < 0 else "SETTINGS_WINDOW") % [w.x, w.y]
		"ui_scale": return Text.t("SETTINGS_UI_SCALE") % ui_scale
		"ia": return Text.t("SETTINGS_IA") % yes.call(show_ia)
		"rumble": return Text.t("SETTINGS_RUMBLE") % yes.call(rumble)
		"rumble_strength": return Text.t("SETTINGS_RUMBLE_STRENGTH") % _volume_bar(rumble_strength)
		"deadzone": return Text.t("SETTINGS_DEADZONE") % deadzone
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
			Settings.apply_display(fullscreen, vsync, window, key == "fullscreen")
		"window":
			# Auto, then each size that fits, round again.
			var count := Settings.fitting_sizes().size()
			window = posmod(window + 1 + (1 if dir >= 0 else -1), count + 1) - 1
			Settings.apply_display(fullscreen, vsync, window)
		"ui_scale":
			ui_scale = Settings.UI_SCALE_MIN if dir == 0 and ui_scale >= Settings.UI_SCALE_MAX else clampi(ui_scale + (10 if dir >= 0 else -10), Settings.UI_SCALE_MIN, Settings.UI_SCALE_MAX)
			_apply_ui_scale()
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
	window = s.window
	ui_scale = s.ui_scale
	music_volume = s.music_volume
	effects_volume = s.effects_volume
	rumble = s.rumble
	rumble_strength = s.rumble_strength
	deadzone = s.deadzone

	AudioServer.set_bus_mute(0, not sound_on)
	sfx.set_music(music_on)
	sfx.set_volumes(music_volume / 100.0, effects_volume / 100.0)
	Settings.apply_display(fullscreen, vsync, window)
	_apply_ui_scale()


## Menus and HUD drawn bigger or smaller, whatever the window's size: the
## 2D is laid out for 1280×720 and scaled to the window, times this.
func _apply_ui_scale() -> void:
	get_window().content_scale_factor = ui_scale / 100.0


func _save_settings() -> void:
	Settings.write({
		"sound": sound_on, "music": music_on, "ia": show_ia,
		"difficulty": Sim.difficulty, "size": size,
		"fullscreen": fullscreen, "vsync": vsync, "window": window, "ui_scale": ui_scale,
		"music_volume": music_volume, "effects_volume": effects_volume,
		"rumble": rumble, "rumble_strength": rumble_strength,
		"deadzone": deadzone,
	})


## Everything the game is made of, to look at: the pieces, the characters,
## the things that fall over, the sounds and the map's marks. Opens from the
## settings; a tab a page, ← → (or the buttons) along the pieces and props.
const ASSET_TABS := {"loot": "ASSETS_TAB_LOOT", "people": "ASSETS_TAB_PEOPLE", "props": "ASSETS_TAB_PROPS", "sounds": "ASSETS_TAB_SOUNDS", "map": "ASSETS_TAB_MAP"}


func _asset_loot() -> Array:
	var out: Array = []
	var names := {}
	for n in range(1, Story.count() + 1):
		out.append(Story.level(n).loot)
		names[Story.level(n).loot.name] = true
	# And one of each shape the generative heists make up (LootGen).
	for l in LootGen.samples():
		if not names.has(l.name):
			out.append(l)
	return out


func _show_assets(tab: String, index: int) -> void:
	phase = "assets"
	assets_tab = tab
	var tabs: Array = []
	for k in ASSET_TABS:
		tabs.append({"text": Text.t(ASSET_TABS[k]), "call": _show_assets.bind(k, 0), "colour": Hud.C.gold if k == tab else Hud.C.dim, "selected": k == tab})
	var items: Array = [{"title": Text.t("ASSETS_TITLE"), "size": 44}, {"buttons": tabs, "row": true, "small": true, "width": 190, "focus": ASSET_TABS.keys().find(tab)}, {"gap": 8}]
	var count := 0
	match tab:
		"loot":
			var list := _asset_loot()
			count = list.size()
			index = posmod(index, count)
			var loot: Dictionary = list[index]
			_build_preview(loot)
			items.append({"picture": preview.get_texture(), "smooth": true, "height": 260})
			items.append({"title": loot.name.to_upper(), "size": 26, "colour": Color(loot.colour)})
			items.append({"text": "%s · %s" % [loot.blurb, loot.shape], "colour": Hud.C.gold})
		"props":
			var kinds: Array = Props.KINDS
			count = kinds.size()
			index = posmod(index, count)
			_build_preview()
			_preview_node(PropsView.model(kinds[index]), Color("#b8a888"), 2.0, 0.6)
			items.append({"picture": preview.get_texture(), "smooth": true, "height": 260})
			items.append({"title": Props.name_of(kinds[index]).to_upper(), "size": 26})
			items.append({"text": Text.t("ASSETS_FALL_METAL" if kinds[index] in ["bin", "armour"] else "ASSETS_FALL_DRY"), "colour": Hud.C.gold})
		"people":
			_drop_preview()
			var cards: Array = []
			for c in [["players:1", "ASSETS_PEOPLE_THIEF"], ["players:2", "ASSETS_PEOPLE_TWO"], ["guards:easy", "ASSETS_PEOPLE_SLEEPY"], ["guards:hard", "ASSETS_PEOPLE_THREE"]]:
				cards.append({"title": Text.t(c[1]), "stage": MenuStage.make(c[0]), "static": true, "animate": true})
			items.append({"cards": cards.slice(0, 2), "width": 300})
			items.append({"cards": cards.slice(2), "width": 300})
		"sounds":
			_drop_preview()
			# One sound at a time, like the pieces: its name and a button to hear it.
			var names: Array = sfx.sound_names()
			count = names.size()
			index = posmod(index, count)
			items.append({"gap": 60})
			items.append({"title": names[index].to_upper(), "size": 40})
			items.append({"gap": 30})
			items.append({"buttons": [{"text": Text.t("ASSETS_LISTEN"), "call": sfx.ui.bind(names[index], 1.0)}], "big": true, "focus": 0})
			items.append({"gap": 40})
		"map":
			_drop_preview()
			items.append({"text": Text.t("ASSETS_MAP_TEXT"), "colour": Hud.C.dim})
			items.append({"legend": ["thief", "gem", "exit", "guard"], "thieves": _thief_colours(), "loot": Color("#74c0fc")})
			items.append({"legend": ["prop", "route", "panel"]})
			items.append({"text": Text.t("ASSETS_MAP_MARKS"), "colour": Hud.C.gold})
	assets_index = index
	if count > 1:
		items.append({"text": "%d / %d" % [index + 1, count], "colour": Hud.C.dim, "size": 14})
		items.append({"buttons": [
			{"text": Text.t("MENU_PREVIOUS"), "call": _show_assets.bind(tab, index - 1), "colour": Hud.C.dim},
			{"text": Text.t("MENU_NEXT"), "call": _show_assets.bind(tab, index + 1)},
		# On the sounds, Enter plays the one on screen; elsewhere it moves on.
		], "row": true, "focus": -1 if tab == "sounds" else 1})
	items.append({"buttons": [{"text": Text.t("MENU_BACK"), "call": _show_settings.bind(settings_from), "colour": Hud.C.dim}], "small": true})
	hud.show_menu(items)


## Put any model on the preview's stand, lit in this colour, framed to span.
func _preview_node(node: Node3D, light: Color, span: float, lift: float) -> void:
	for c in preview_pivot.get_children():
		c.queue_free()
	preview_spot.light_color = light
	preview_cam.size = span
	preview_cam.position = preview_cam.basis.z * 10.0 + Vector3(0, lift, 0)
	node.position.y = -0.1
	preview_pivot.add_child(node)


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
		{"title": Text.t("MENU_PAUSE"), "size": 56},
		{"buttons": [
			{"text": Text.t("MENU_RESUME"), "call": _start_playing},
			{"text": Text.t("MENU_SETTINGS"), "call": _show_settings.bind("paused")},
			{"text": _leave_text(), "call": _quit_to_title},
		]},
	])


func _quit_to_title() -> void:
	get_tree().paused = false
	_leave_game(_show_title)


## Before a night: a briefing of a page or two you can move between freely —
## what is new tonight (if anything is), and the plan: the map, the piece
## and its story, and tips for the night — tabs along the top, back and
## next along the bottom.
func _brief_pages() -> Array:
	var pages := []
	if mode == "story" and not Story.news(level, players).is_empty():
		pages.append("news")
	pages.append("plan")
	return pages


func _show_brief(page: int) -> void:
	var pages := _brief_pages()
	page = clampi(page, 0, pages.size() - 1)
	brief_page = page
	phase = "brief"
	var names := {"news": Text.t("BRIEF_TAB_NEWS"), "plan": Text.t("BRIEF_TAB_PLAN")}
	var tabs: Array = []
	for i in pages.size():
		tabs.append({"text": names[pages[i]], "call": _show_brief.bind(i), "colour": Hud.C.gold if i == page else Hud.C.dim, "selected": i == page})
	# Tabs only when there is more than one page.
	var items: Array = [{"buttons": tabs, "row": true, "small": true}, {"gap": 6}] if pages.size() > 1 else []
	match pages[page]:
		"news": items.append_array(_news_items())
		"plan": items.append_array(_plan_items())
	var last := page == pages.size() - 1
	items.append({"buttons": [
		{"text": Text.t("MENU_PREV") if page > 0 else Text.t("MENU_BACK"), "call": _brief_back, "colour": Hud.C.dim},
		{"text": Text.t("BRIEF_START") if last else Text.t("BRIEF_NEXT_TAB") % names[pages[page + 1]], "call": _start_countdown if last else _show_brief.bind(page + 1)},
	], "row": true, "focus": 1})
	if not last:
		items.append({"buttons": [{"text": Text.t("MENU_SKIP"), "call": _skip_story, "colour": Hud.C.dim}], "small": true})
	hud.show_menu(items)


func _brief_back() -> void:
	if brief_page > 0:
		_show_brief(brief_page - 1)
	elif mode == "story" and level == 1:
		_show_prologue(Story.prologue().size() - 1)
	elif mode == "story":
		_show_museum(Story.museum_of(level))
	elif mode == "challenge":
		_leave_game(_show_challenge_map.bind(challenge_map))
	else:
		_show_generative_menu()


## What changes tonight, a card for each, on the diorama that shows it.
func _news_items() -> Array:
	var cards: Array = []
	for n in Story.news(level, players):
		cards.append({"title": n.title, "text": n.text, "stage": MenuStage.make(n.stage), "static": true, "animate": true, "colour": Hud.C.gold})
	return [
		{"title": Text.t("BRIEF_NEWS_TITLE"), "size": 44},
		{"text": Text.t("BRIEF_NEWS_TEXT"), "colour": Hud.C.dim},
		{"cards": cards, "width": 330 if cards.size() < 3 else 290},
	]


## The plan: the map on the left; on the right, the piece (turning under a
## light, its name and how long it takes), its story when it has one, and
## tips worked out from the night (Briefing).
func _plan_items() -> Array:
	var colours := _thief_colours().slice(0, thieves.size())
	var keys := ["thief", "gem", "exit", "guard", "prop", "route"]
	if Heist.team:
		keys.append("panel")
	var legend_loot := Color(Heist.loot.colour)
	var left: Array = [
		{"map": Hud.plan_map(guards, colours), "height": 390},
		{"legend": keys.slice(0, 3), "thieves": colours, "loot": legend_loot},
		{"legend": keys.slice(3), "thieves": colours, "loot": legend_loot},
	]
	# Rebuilt each time: the last round's piece may still be on the stand.
	_build_preview()
	var piece: Array = [
		{"text": _brief_heading(), "size": 15, "colour": Hud.C.dim, "align": "left"},
		{"text": Heist.first_upper(Heist.loot.name), "size": 26, "colour": Color(Heist.loot.colour), "wrap": true, "width": 330, "align": "left"},
		{"text": Heist.loot.blurb, "size": 17, "colour": Hud.C.gold, "wrap": true, "width": 330, "align": "left"},
		{"text": Text.t("BRIEF_TAKES") % _seconds(Heist.loot.seconds), "size": 15, "colour": Hud.C.dim, "wrap": true, "width": 330, "align": "left"},
	]
	var right: Array = [{"columns": [
		{"items": [{"picture": preview.get_texture(), "smooth": true, "height": 120}], "middle": true},
		{"items": piece, "separation": 4, "middle": true},
	], "separation": 12}]
	var story: String = Heist.loot.get("story", "")
	if story.strip_edges() != "":
		right.append({"text": story, "size": 17, "wrap": true, "width": 540, "align": "left"})
	right.append({"gap": 4})
	right.append({"title": Text.t("BRIEF_TIPS_TITLE"), "size": 24, "align": "left"})
	for tip in Briefing.tips(guards):
		right.append({"text": "• " + tip, "size": 17, "wrap": true, "width": 540, "align": "left"})
	return [{"columns": [
		{"items": left, "separation": 6, "middle": true},
		{"items": right, "width": 540, "separation": 8, "middle": true},
	], "separation": 36}]


## Over the piece: which night, or which level and how hard, or which map.
func _brief_heading() -> String:
	match mode:
		"story":
			return Text.t("BRIEF_NIGHT_OF") % [level, Story.count()]
		"challenge":
			if challenge_map and challenge_map.name != "":
				return challenge_map.name.to_upper()
	if mode == "generative":
		return Text.t("BRIEF_DIFFICULTY") % [Text.t("BRIEF_LEVEL") % level, Text.t(DIFFICULTY_NAMES[Sim.difficulty])]
	return Text.t("BRIEF_LEVEL") % level


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
	preview_cam = cam
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


func _show_end() -> void:
	var title := Text.t("END_CAUGHT")
	var colour: Color = Hud.C.alert
	var line := Text.t("END_BACK_IN_CASE" if Heist.taken else "END_STILL_THERE") % Heist.first_upper(Heist.loot.name)
	var next := Text.t("END_AGAIN")
	if phase == "escaped":
		title = Text.t("END_PERFECT")
		colour = Hud.C.safe
		line = Text.t("END_HOME") % Heist.first_upper(Heist.loot.name) if mode == "story" else Text.t("END_LEVEL_DONE") % [level, Heist.loot.name]
		next = Text.t("END_NEXT_NIGHT" if mode == "story" else "END_NEXT_HEIST")
		if mode == "story":
			Story.unlock(level + 1, players)
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
		{"buttons": [{"text": Text.t("EDITOR_BACK_TO_EDITOR") if testing else Text.t("END_TO_MENU"), "call": _leave_game.bind({"story": _show_story_map, "challenge": _show_challenge_menu}.get(mode, _show_title)), "colour": Hud.C.dim}], "small": true},
	])


func _show_ending() -> void:
	phase = "ending"
	sfx.ui("escaped")
	hud.show_menu([
		{"title": Text.t("ENDING_TITLE"), "colour": Hud.C.safe, "size": 48},
		{"text": Story.ending(), "size": 18, "wrap": true},
		{"buttons": [{"text": Text.t("MENU_TO_MENU"), "call": _show_title}]},
	])


func _again() -> void:
	_new_round(level + 1 if phase == "escaped" else level)
	_show_brief(0)


func _seconds(s: float) -> String:
	return Text.t("BRIEF_SECONDS") % (str(int(s)) if is_equal_approx(s, round(s)) else str(s).replace(".", Text.t("BRIEF_DECIMAL_POINT")))


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
		"story_players":
			if key == KEY_ESCAPE:
				_show_title()
		"challenge":
			if key == KEY_ESCAPE:
				_show_challenge_menu()
		"story_map":
			if key == KEY_ESCAPE:
				_show_story_menu()
		"museum":
			if key == KEY_ESCAPE:
				_show_story_map()
		"input":
			if key == KEY_ESCAPE:
				if settings_from == "story":
					_show_story_menu()
				else:
					_show_generative_menu()
		"prologue", "brief" when key == KEY_TAB:
			_skip_story()
		"prologue":
			if key == KEY_SPACE:
				var pages := Story.prologue().size()
				if prologue_page < pages - 1:
					_show_prologue(prologue_page + 1)
				else:
					_show_brief(0)
			elif key == KEY_ESCAPE:
				_prologue_back()
		"ending":
			if key == KEY_ESCAPE or key == KEY_SPACE:
				_show_title()
		"brief":
			# Space goes on a page (the last one starts), Escape goes back one;
			# Q and E, or the shoulder keys' letters, flick between the tabs.
			if key == KEY_SPACE:
				if brief_page < _brief_pages().size() - 1:
					_show_brief(brief_page + 1)
				else:
					_start_countdown()
			elif key == KEY_ESCAPE:
				_brief_back()
			elif key == KEY_Q and brief_page > 0:
				_show_brief(brief_page - 1)
			elif key == KEY_E and brief_page < _brief_pages().size() - 1:
				_show_brief(brief_page + 1)
		"playing":
			if key == KEY_ESCAPE or key == KEY_P:
				_pause()
		"paused":
			if key == KEY_ESCAPE or key == KEY_P:
				_start_playing()
		"settings":
			if key == KEY_ESCAPE:
				_settings_back()
		"assets":
			if key == KEY_ESCAPE:
				_show_settings(settings_from)
			elif key == KEY_Q or key == KEY_E:
				_show_assets(assets_tab, assets_index + (1 if key == KEY_E else -1))
		"caught", "escaped":
			if key == KEY_SPACE:
				_again()
			elif key == KEY_ESCAPE:
				_leave_game(_show_title)


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

## The museum, the gang, the guards, the job and the props for a round,
## from one seed (the same seed, the same night). Returns what the night's
## guard post watches (Sim.assign_posts).
func _lay_out(n: int, map_seed: int) -> int:
	seed(map_seed)
	Sim.gang = players
	if mode == "story":
		var night := Story.level(n)
		Sim.new_map(map_seed, night.size, -1, night.shape)
	elif mode == "challenge":
		# A saved map: the way in, the piece, the door and the guards where
		# its maker put them.
		challenge_map.apply()
		MuseumView.palette = challenge_map.palette()
		MuseumView.exhibits = challenge_map.exhibits.duplicate()
		Props.list.clear()
	else:
		Sim.new_map(map_seed, size)
	thieves = [Sim.new_thief("p1")]
	for k in range(2, players + 1):
		thieves.append(Sim.new_thief("p%d" % k))
	guards = Sim.new_guards(Sim.guard_count(Museum.size_name))
	if mode == "challenge":
		Sim.place_guards(guards, challenge_map.guards)
	var piece: Dictionary = Story.level(n).loot if mode == "story" else (challenge_map.loot_piece() if mode == "challenge" else {})
	Heist.plan_job(level, piece, players, challenge_map.job() if mode == "challenge" else {})
	# Things to knock over: never on the tiles the job needs clear.
	var stand := Heist.route[0]
	for t in Heist.route:
		if Museum.dist(t.x + 0.5, t.y + 0.5, Heist.at.x + 0.5, Heist.at.y + 0.5) < 1.1:
			stand = t
			break
	# A saved map may stand its own, by hand.
	if mode == "challenge" and not challenge_map.props.is_empty():
		challenge_map.put_props()
	elif Sim.feature("props"):
		Props.place(map_seed, [Heist.exit, Heist.panel, Heist.panel2, stand, Heist.start])
	else:
		Props.list.clear()
	return Sim.assign_posts(guards)


func _new_round(n: int) -> void:
	_close_map()
	if mode == "story":
		n = clampi(n, 1, Story.count())
	level = n
	# Each story museum in its own colours; the rest by their seed.
	MuseumView.palette = {}
	MuseumView.exhibits = {}
	if mode == "story":
		var night := Story.level(n)
		MuseumView.palette = Story.palette(n)
		Sim.custom = Story.tuning(n)
		var base := Story.seed_for(n, players)
		# A night that posts a guard for its lesson is built around it: the
		# first of its museums where the lesson cannot be dodged.
		var pick := base
		if night.get("post", "") != "":
			for k in Story.LESSON_TRIES:
				if _lay_out(n, base + k * Story.SEED_STEP) > 0:
					pick = base + k * Story.SEED_STEP
					break
		_lay_out(n, pick)
	elif mode == "challenge":
		Sim.custom = challenge_map.tuning()
		_lay_out(n, challenge_map.seed + n)
	else:
		Sim.custom = {}
		_lay_out(n, randi() % 1000000000)
	stride = [0.0, 0.0, 0.0, 0.0]
	push_held = [false, false, false, false]
	guard_steps.clear()
	prop_noises.clear()
	last_think = 0.0
	think_tick = 0
	log_lines.clear()
	Sim.thoughts.clear()
	Sim.light_events.clear()
	_build_world()
	_snap_camera()
	hud.set_gang(_thief_colours().slice(0, thieves.size()), _thief_darks().slice(0, thieves.size()), Heist.loot)


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
	var names := [["w", "s", "a", "d", "c", "e"], ["up", "down", "left", "right", "minus", "period"], ["i", "k", "j", "l", "u", "o"], ["kp8", "kp5", "kp4", "kp6", "kp0", "kpadd"]]
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
	if seat == "kb_mid":
		for pair in [[0, KEY_I], [1, KEY_K], [2, KEY_J], [3, KEY_L], [4, KEY_U], [5, KEY_O]]:
			if Input.is_physical_key_pressed(pair[1]):
				out[pair[0]] = true
	if seat == "kb_pad":
		for pair in [[0, KEY_KP_8], [1, KEY_KP_5], [2, KEY_KP_4], [3, KEY_KP_6], [4, KEY_KP_0], [5, KEY_KP_ADD]]:
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
	if thieves.size() >= 2 and at != Vector2.INF:
		var best := INF
		for i in thieves.size():
			var d := Museum.dist(thieves[i].x, thieves[i].y, at.x, at.y)
			if d < best:
				best = d
				who = i
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
	prop_noises.append(SoundEvent.make(p.x, p.y, p.kind, Props.crash_loudness(p.kind, strength)))
	_prop_fell(p, strength)


## The crash of one going over, whoever did it.
func _prop_fell(p: Props.Prop, strength := 0.6) -> void:
	var loud := Props.crash_loudness(p.kind, strength)
	sfx.noise(p.kind, _to_world(p.x, p.y), loud)
	_rumble(0.3 + 0.5 * strength, 0.4 * strength, 0.15 + 0.2 * strength, Vector2(p.x, p.y))
	_shake((0.45 if p.kind in ["bust", "armour"] else 0.25) * (0.6 + 0.8 * strength))
	_log((Text.t("LOG_CRASH_EVERYWHERE") % Heist.first_upper(Props.name_of(p.kind))) if Props.heard_everywhere(loud) else Text.t("LOG_KNOCKED") % Props.name_of(p.kind))


## Something already down, sent rolling or rustling by a thief's feet: a
## smaller noise, but a noise — the tin bin clatters, paper whispers.
func _on_prop_kicked(kind: String, at: Vector2, strength: float) -> void:
	var loud: float = {"bin": 7.5, "bust": 6.0, "panel": 5.0, "armour": 7.0, "paper": 2.5}.get(kind, 4.0) * (0.5 + 0.5 * strength)
	prop_noises.append(SoundEvent.make(at.x, at.y, "kick", loud))
	# The tin and the steel ring, the rubble and the board knock dry, the
	# paper whispers.
	var sound: String = {"bin": "kick_metal", "armour": "kick_metal", "paper": "whisper"}.get(kind, "kick_dry")
	sfx.noise(sound, _to_world(at.x, at.y), loud)


## "E: TIRAR LA PAPELERA" when a thief has something within reach.
func _push_hint() -> String:
	if phase != "playing":
		return ""
	for i in thieves.size():
		var p := Props.within_reach(thieves[i])
		if p:
			var key := "E" if i == 0 else "."
			return Text.t("HUD_PUSH_HINT") % [key, Props.name_of(p.kind).to_upper()]
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
		hud.show_map(Hud.live_map(thieves, _thief_colours()), _thief_colours().slice(0, thieves.size()))
		sfx.ui("pick")
	else:
		hud.hide_map()


func _close_map() -> void:
	map_open = false
	hud.hide_map()


func _thief_darks() -> Array:
	return [COLOURS.thief_dark, COLOURS.thief2_dark, COLOURS.thief3_dark, COLOURS.thief4_dark]


func _thief_colours() -> Array:
	return [COLOURS.thief, COLOURS.thief2, COLOURS.thief3, COLOURS.thief4]


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
		var scheme: String = "solo" if thieves.size() == 1 else ["wasd", "arrows", "ijkl", "numpad"][i]
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
			# As loud as the guards hear it.
			sfx.noise(what, _to_world(p.x, p.y), noise.loudness)

	# Walking into things: over they go, with a crash.
	# Things knocked over: the physics decides (PropsView pushes them with
	# the thieves' bodies and tells us what fell or got kicked about), and
	# what it heard since last frame joins this frame's noises.
	Props.knocked.clear()
	noises.append_array(prop_noises)
	prop_noises.clear()
	# On purpose: E (P2: . , P3: O), or X on the pad, next to one — over it goes,
	# and the guards come to see.
	for i in thieves.size():
		var t := thieves[i]
		var pressed: bool = keys.has(["e", "period", "o", "kpadd"][i]) or (thieves.size() == 1 and keys.has("period"))
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
			_log(Text.t("LOG_CASE_ALARM"))
		sfx.at("alarm", _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5), 0.8)
	match took:
		"stolen":
			sfx.ui("stolen")
			Fx.sparkle(world, _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05), Color(Heist.loot.colour))
			_punch_in()
			_log(Text.t("LOG_GOT_IT_TEAM" if thieves.size() > 1 else "LOG_GOT_IT") % Heist.loot.name)
		"dropped":
			_log(Text.t("LOG_DROPPED") % Heist.first_upper(Heist.loot.name))
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
			var heard: String = (Text.t("LOG_HEARD_BY") % Text.t("LOG_AND").join(heard_by)) if not heard_by.is_empty() else Text.t("LOG_NOBODY_HEARD")
			var ear := thieves[0]
			var angle := atan2(s.y - ear.y, s.x - ear.x)
			var d := Museum.dist(ear.x, ear.y, s.x, s.y)
			hud.shout(Text.t(SHOUTS[randi() % SHOUTS.size()]), Text.t("HUD_SHOUT_FAR" if d > 9 else "HUD_SHOUT_NEAR") % [s.from, heard], angle)
			_log(Text.t("LOG_SHOUT") % [s.from, heard])
	for w in Sim.warn_partners(guards, now):
		sfx.at("whisper", _to_world(w.x, w.y), 0.6)
		_log(Text.t("LOG_WARN") % [w.from, w.to])
	for t in Sim.thoughts:
		_log("%s: %s" % [t.by, t.text])
	Sim.thoughts.clear()
	for e in Sim.light_events:
		var label := Text.t("LOG_THE_ROOM_OF")
		for z in Museum.zones:
			if z.room == e.room:
				label = z.label_of
		var r: Museum.Room = Museum.rooms[e.room]
		sfx.at("lights", _to_world(r.switch_at.x + 0.5, r.switch_at.y + 0.5), 0.8)
		_log(Text.t("LOG_LIGHTS") % [e.by, label])
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
	# Once the piece is taken, whoever reaches the door slips out and is
	# safe: out of sight, out of reach, waiting for the rest.
	if Heist.taken:
		for p in thieves:
			if not p.out and Heist.at_door(p):
				p.out = true
				p.safe = true
				p.speed = 0
				if thieves.size() > 1 and not thieves.all(func(o): return o.safe):
					_log(Text.t("LOG_OUT_WAITING") % ("P%d" % (thieves.find(p) + 1)))
	# No clock: take as long as you like. The whole gang out of the door
	# with the piece wins; one of you caught ends the night.
	if thieves.any(func(p): return p.out and not p.safe):
		phase = "caught"
		_close_map()
		_show_end()
	elif thieves.all(func(p): return p.safe):
		phase = "escaped"
		_close_map()
		sfx.ui("escaped")
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
			_log(Text.t("LOG_DECISION") % [g.name, g.decision.label, roundi(p * 100), Text.t("LOG_TORN") if g.decision.torn else ""])


func _on_brain_failed(reason: String) -> void:
	_log(Text.t("LOG_BRAIN_FAILED") % reason)


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
	suspicion_marks.clear()
	suspicion_keys.clear()
	switch_marks.clear()
	lit_washes.clear()

	# Floor, walls, cases and emergency lights: built once, never touched again.
	var view := MuseumView.new()
	view.build()
	world.add_child(view)
	Fx.dust_field(world)
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
		var f := Figure.make("thief", _thief_colours()[i], _thief_darks()[i])
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
		room_lights.append(l)
	for g in guards:
		var f := Figure.make("guard", COLOURS.guard, COLOURS.guard_dark)
		world.add_child(f)
		guard_nodes.append(f)
		# Over its head: how much it suspects (!, !!, !!!) and a bar for how
		# long until it calms down a step. Seen through walls, always.
		var mark := Sprite3D.new()
		mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		mark.no_depth_test = true
		mark.shaded = false
		mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mark.pixel_size = 0.05
		mark.render_priority = 10
		mark.position = Vector3(0, 2.9, 0)
		mark.visible = false
		f.add_child(mark)
		suspicion_marks.append(mark)
		suspicion_keys.append("")
		# A torch, not a bulb: narrow cone, soft edge, pointed where it looks.
		# Bright hotspot, a quick falloff to the rim, and crisp shadows so the
		# cases and figures it sweeps throw long ones across the floor.
		var torch := SpotLight3D.new()
		torch.set_meta(Fx.LIGHTS_DUST, true)
		torch.light_color = TORCH_COLOUR
		# Falls off with distance quicker than a bulb, so the pool near the
		# guard is bright and the throw beyond it dim; and a low angle exponent
		# for a wide penumbra instead of a hard rim.
		torch.spot_attenuation = 1.0
		torch.spot_angle_attenuation = 0.5
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
		torches.append(torch)
		var cone := MeshInstance3D.new()
		cone.mesh = ImmediateMesh.new()
		# White: the colour and the fades ride on the vertices.
		var cm := _flat(Color(1, 1, 1, 0.99))
		cm.vertex_color_use_as_albedo = true
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
	loot_spot.light_energy = 14.0
	loot_spot.spot_range = 6.0
	loot_spot.spot_angle = 17.0
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
	sign.text = Text.t("HUD_SIGN_EXIT")
	sign.font = Hud.ARCADE
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.modulate = COLOURS.switch_on
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.75, 0.1)
	door.add_child(sign)
	panel_mats.clear()
	panel_glows.clear()
	if Heist.team:
		_build_panel(Heist.panel, Heist.panel_face)
	if Heist.team and Heist.panel2.x >= 0:
		_build_panel(Heist.panel2, Heist.panel2_face)
	var exit_light := OmniLight3D.new()
	exit_light.light_color = COLOURS.switch_on
	exit_light.light_energy = 1.5
	exit_light.omni_range = 3.0
	exit_light.position = Vector3(0, 1.5, 0.5)
	door.add_child(exit_light)


## The alarm panel: a grey box on the wall with a big lamp, orange while it
## waits, green while someone holds it.
func _build_panel(at: Vector2i, face: Vector2i) -> void:
	var node := Node3D.new()
	node.position = _to_world(at.x + 0.5 + face.x * 0.5, at.y + 0.5 + face.y * 0.5)
	node.rotation.y = atan2(-face.x, -face.y)
	world.add_child(node)
	var box := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.6, 0.14)
	box.mesh = b
	box.material_override = MuseumView.toon(Color("#5c6370"))
	box.position = Vector3(0, 1.0, 0.07)
	node.add_child(box)
	var panel_mat := StandardMaterial3D.new()
	panel_mat.emission_enabled = true
	panel_mat.emission_energy_multiplier = 2.0
	panel_mats.append(panel_mat)
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
	var panel_glow := OmniLight3D.new()
	panel_glows.append(panel_glow)
	panel_glow.light_energy = 1.2
	panel_glow.omni_range = 2.5
	panel_glow.position = Vector3(0, 1.1, 0.5)
	node.add_child(panel_glow)
	var sign := Label3D.new()
	sign.text = Text.t("HUD_SIGN_ALARM")
	sign.font = Hud.ARCADE
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.modulate = Color("#ff922b")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.55, 0.1)
	node.add_child(sign)


func _draw_panel() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in panel_mats.size():
		var held := (Heist.panel_by if i == 0 else Heist.panel2_by) != ""
		var c := COLOURS.switch_on if held else Color("#ff922b")
		panel_mats[i].albedo_color = c
		panel_mats[i].emission = c
		panel_glows[i].light_color = c
		# Blinks while someone waits at the case for it.
		panel_glows[i].light_energy = 1.2 if held or not Heist.waiting else (0.4 + 1.2 * absf(sin(t * 6.0)))


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
		# Gone out of the door: not in the museum any more.
		f.visible = not p.safe
		f.scale = Vector3.ONE * (0.75 if p.out else 1.0)
		# Seen through the cases: your colour while nobody sees you, the
		# alarm red the moment one does, all but gone once you are out.
		if p.out:
			f.set_ghost(COLOURS.ink, 0.35)
		elif p.hidden:
			f.set_ghost(_thief_colours()[i], 0.75)
		else:
			f.set_ghost(COLOURS.alert, 1.0)
	for i in guards.size():
		var g := guards[i]
		var f := guard_nodes[i]
		f.set_state(_to_world(g.x, g.y), g.dir, 0.0, dt)
		f.set_ghost(COLOURS.alert if g.sees_player else COLOURS.guard, 0.75)
		_draw_suspicion(i, g)
		var view := Sim.view_of(g)
		var torch := torches[i]
		torch.light_color = COLOURS.alert if g.sees_player else TORCH_COLOUR
		# A touch wider than the cone: the soft rim spends the edge fading out.
		torch.spot_angle = rad_to_deg(view.half) * 1.1
		torch.spot_range = view.range + 1.0
		# Under the ceiling lights a torch is pointless, and switched off.
		# A harder night hands them stronger torches.
		var power := Sim.torch_power()
		torch.light_energy = 0.0 if Museum.is_lit(g.x, g.y) else (TORCH_ENERGY_ALERT if g.alert else TORCH_ENERGY) * power * power
		_draw_cone(g, cones[i])
	_draw_room_lights()
	_draw_loot()
	_follow_camera(dt)
	_draw_hud(dt)


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
		loot_spot.light_energy = move_toward(loot_spot.light_energy, 0.0 if Heist.taken else 14.0, 0.2)
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


## The colour of each level of suspicion: a hunch, alert, after you.
const SUSPICION_COLOURS := [Color.TRANSPARENT, Color("#ffd43b"), Color("#ff922b"), Color("#ff3048")]
## The bar under the marks, in this many steps: redrawn only on a change.
const SUSPICION_STEPS := 24


## What a guard's head says: nothing when it suspects nothing; else its
## marks and, under them, how much is left before it calms down a step —
## full and still for a guard that is sure, or giving chase.
func _draw_suspicion(i: int, g: Guard) -> void:
	var mark := suspicion_marks[i]
	if g.suspicion <= 0:
		mark.visible = false
		suspicion_keys[i] = ""
		return
	var now := Sim.now_ms()
	var left := 1.0
	if g.suspicion == 1:
		left = 1.0 - (now - g.suspicion_at) / (Sim.tuning("calm_after") * 1000.0)
	elif g.suspicion == 2 and g.calm_in != INF:
		left = 1.0 - (now - g.suspicion_at) / Sim.ALERT_HOLD_MS
	var step := clampi(ceili(clampf(left, 0.0, 1.0) * SUSPICION_STEPS), 0, SUSPICION_STEPS)
	var key := "%d:%d" % [g.suspicion, step]
	if key == suspicion_keys[i]:
		return
	var rose := suspicion_keys[i] == "" or int(suspicion_keys[i].get_slice(":", 0)) < g.suspicion
	suspicion_keys[i] = key
	mark.texture = ImageTexture.create_from_image(_suspicion_image(g.suspicion, float(step) / SUSPICION_STEPS))
	mark.visible = true
	# Going up a level: a pop, so you notice.
	if rose:
		mark.scale = Vector3.ONE * 1.8
		create_tween().tween_property(mark, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The marks (as many as the level) over a bar filled to `fill`, in pixels
## with a dark outline so they read on floor, wall or torch light alike.
static func _suspicion_image(level: int, fill: float) -> Image:
	var w := 34
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color("#1c1210")
	var colour: Color = SUSPICION_COLOURS[level]
	# "!": a 3-wide stroke over a dot, 5 apart.
	var x0 := w / 2 - (level * 5 - 2) / 2
	for k in level:
		var x := x0 + k * 5
		img.fill_rect(Rect2i(x - 1, 0, 5, 9), ink)
		img.fill_rect(Rect2i(x - 1, 10, 5, 5), ink)
		img.fill_rect(Rect2i(x, 1, 3, 7), colour)
		img.fill_rect(Rect2i(x, 11, 3, 3), colour)
	# The bar: how long before it calms down a step.
	img.fill_rect(Rect2i(1, 16, w - 2, 5), ink)
	img.fill_rect(Rect2i(2, 17, w - 4, 3), Color("#3a2a30"))
	img.fill_rect(Rect2i(2, 17, int(round((w - 4) * fill)), 3), colour)
	return img


## The view cone, rebuilt from rays every frame so it stops at the walls.
## Two bands, like the torch: the bright pool that sees you however low you
## are, and the dim throw beyond it that only catches you standing. Every
## edge is feathered — between the bands, at the far rim and at the sides —
## so it reads as light on the floor, not a cut-out.
func _draw_cone(g: Guard, node: MeshInstance3D) -> void:
	var im: ImmediateMesh = node.mesh
	im.clear_surfaces()
	var view := Sim.view_of(g)
	var colour: Color = COLOURS.alert if g.sees_player else (COLOURS.cone_alert if g.alert else COLOURS.cone)
	# Faint: the torch's beam in the fog does most of the showing, this just
	# marks what the guard sees.
	var bright: float = (0.2 if g.sees_player else (0.13 if g.alert else 0.09)) * clampf(Sim.torch_power(), 0.7, 1.4)
	var dim := bright * CONE_DIM
	var near: float = view.near
	var reach: float = view.range
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev: Array = []
	for i in CONE_RAYS:
		var t := float(i) / (CONE_RAYS - 1)
		var a: float = g.dir - view.half + 2.0 * view.half * t
		# Soft sides: the light thins out towards the edge of the beam.
		var side := smoothstep(0.0, CONE_SIDE_FEATHER, t) * smoothstep(1.0, 1.0 - CONE_SIDE_FEATHER, t)
		# Painted over the cases: this is where someone standing is seen.
		var far := Museum.cast_ray(g.x, g.y, a, Sim.LIT_RANGE, true)
		var ex: float = g.x + cos(a) * reach
		var ey: float = g.y + sin(a) * reach
		var lit_beyond: bool = far > reach and Museum.is_lit(ex, ey)
		var d: float = far if lit_beyond else minf(far, reach)
		# (distance, alpha) from the guard out: bright pool, blend, dim throw,
		# and a fade to nothing at the rim unless a lit room carries it on.
		var rings := [
			[0.0, bright],
			[near - CONE_BAND_FEATHER, bright],
			[near + CONE_BAND_FEATHER, dim],
			[reach - CONE_RIM_FEATHER, dim],
			[d if lit_beyond else reach, dim if lit_beyond else 0.0],
		]
		var ray: Array = []
		for r in rings:
			var at := clampf(r[0], 0.0, d)
			ray.append([_to_world(g.x + cos(a) * at, g.y + sin(a) * at, 0.03), Color(colour, r[1] * side)])
		if i > 0:
			for k in ray.size() - 1:
				_cone_tri(im, prev[k], prev[k + 1], ray[k])
				_cone_tri(im, ray[k], prev[k + 1], ray[k + 1])
		prev = ray
	im.surface_end()


func _cone_tri(im: ImmediateMesh, a: Array, b: Array, c: Array) -> void:
	for v in [a, b, c]:
		im.surface_set_color(v[1])
		im.surface_add_vertex(v[0])


## Where the camera sits over what it looks at: high up and a little behind.
const CAM_OFFSET := Vector3(0, 15.4, 6)
## How far (m) the thief can wander from the middle before the camera moves.
const CAM_SLACK := 0.9
## Roughly how long (s) the camera takes to catch up: higher is lazier.
const CAM_SMOOTH := 0.55
## The shake at full trauma: how far the view slides (in metres at the
## camera) and how far it rolls (radians).
const SHAKE_MOVE := 0.45
const SHAKE_ROLL := 0.025
## How much of the trauma wears off each second.
const SHAKE_DECAY := 1.2

## where the camera is headed, followed smoothly; the shake and the punch are
## put on top of it every frame, so they never pile up in the follow
var cam_rest := Vector3.ZERO
## how fast cam_rest is moving: the follow is a spring, so it winds up when
## you set off and runs on a little, easing to a stop, when you halt
var cam_vel := Vector3.ZERO
## the point the spring pulls towards: it only moves once the thief strays
## past CAM_SLACK from it, so small moves do not drag the whole picture
var cam_goal := Vector3.ZERO
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
	cam_goal = t
	cam_vel = Vector3.ZERO
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
	# A loose leash: inside CAM_SLACK the thief moves about the frame and the
	# camera stays put; past it, the goal is dragged along.
	var off := Vector3(t.x - cam_goal.x, 0.0, t.z - cam_goal.z)
	if off.length() > CAM_SLACK:
		cam_goal += off - off.normalized() * CAM_SLACK
	cam_goal.y = t.y
	# A critically damped spring towards it (the SmoothDamp step): it starts
	# slowly, catches up, and settles without overshooting.
	var omega := 2.0 / CAM_SMOOTH
	var x := omega * dt
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cam_rest - (cam_goal + CAM_OFFSET)
	var temp := (cam_vel + omega * change) * dt
	cam_vel = (cam_vel - omega * temp) * decay
	cam_rest = cam_goal + CAM_OFFSET + (change + temp) * decay
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


func _draw_hud(dt: float) -> void:
	if thieves.is_empty():
		return
	# The gang as they are: standing or down, carrying, seen, out.
	var states: Array = []
	for p in thieves:
		states.append({"posture": p.posture, "speed": p.speed if p.moving else 0.0, "carrying": Heist.carrier == p.id,
			"seen": not p.hidden, "out": p.out, "safe": p.safe})
	hud.update_gang(states, dt)
	var alarm := 0
	for g in guards:
		alarm = maxi(alarm, g.suspicion)
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
		"short_hand": Heist.short_hand,
		"panel": Heist.panels_held() and not Heist.taken,
		"panels": 2 if Heist.panel2.x >= 0 else 1,
		"hint": _push_hint(),
	}
	if not hud.menu_open():
		hud.update_play(log_lines, job, angle, COLOURS.switch_on if Heist.carrier != "" else Color(Heist.loot.colour), alarm)
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
