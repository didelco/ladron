extends Node3D
## The game: screens, the loop, and drawing the world each frame.
##
## Two modes. The story: twenty fixed nights, easy to hard, with a tale (Story).
## The generative: a new museum every time, at the difficulty and size you
## pick. Either with one thief or two; with two, the job takes both (Heist).
##
## Screens: title (pick the mode; for the story and the generative, how many
## thieves in a bubble out of its card) → the mode's menu (the story: the
## town's map, a museum and its night; the generative: difficulty and size)
## → [prologue] → loot (the piece and its story) → mission
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
## the museum's loudspeaker (Megaphone) and how it is switched on: one of
## Settings.MEGAPHONE_MODES ("both", "text", "sound", "off")
var megaphone_mode := "both"
var mega: Megaphone
## the loudspeaker's voice (MegaVoice)
var mega_voice: MegaVoice
var mega_still := 0.0
var mega_suspicion := 0
var mega_exit_said := false
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
## Once stolen the piece goes in this sack: on the carrier's back, or on the
## floor where it was dropped.
var sack_node: Node3D
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
		pad_guids[d] = Input.get_joy_guid(d)
	Input.joy_connection_changed.connect(_pad_changed)
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
	hud.ui_sound.connect(func(kind: String) -> void: sfx.ui(kind, 0.6))
	_load_settings()
	_build_environment()
	# A museum behind the title screen, so it is not a black void.
	_new_round(1)
	# The cover first, when the game is simply opened; the menu under it.
	if OS.get_cmdline_user_args().is_empty() and TitleScreen.available():
		_show_cover()
	else:
		_show_title()
	# For recording and testing: `godot -- --autostart` skips the title, shows
	# the mission for two seconds and starts the round; add --two for two thieves.
	# --menu=story|generative|settings: open a menu straight away, to look at it.
	# --pick=N first: the story's heist N picked (map and museum open on its).
	# --save=PATH: the progress kept there instead (Story.save), for
	# looking at the screens without touching the player's own; and with it
	# --reached=N: as far as heist N there.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			Story.save = arg.substr(7)
		if arg.begins_with("--gang="):
			players = clampi(int(arg.substr(7)), 1, 4)
		elif arg == "--two":
			players = 2
	for arg in OS.get_cmdline_user_args():
		# Never in the player's own progress.
		if arg.begins_with("--reached=") and Story.save != Story.SAVE:
			Story.unlock(clampi(int(arg.substr(10)), 1, Story.count()), players)
	story_pick = Story.unlocked(players)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pick="):
			story_pick = clampi(int(arg.substr(7)), 1, Story.count())
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):
			match arg.substr(7):
				"story": _show_title("story")
				# The way in (Tour): the town, or inside the museum of --pick=N
				# with that room picked.
				# (--opened=M: as just after the big job before museum M).
				"map", "city":
					var fresh := -1
					for a in OS.get_cmdline_user_args():
						if a.begins_with("--opened="):
							fresh = clampi(int(a.substr(9)) - 1, 0, Story.MUSEUMS.size() - 1)
					_show_city(fresh, fresh)
				"museum": _show_museum_tour(story_pick)
				# The hideout's practice room, straight in (--gang=N, --two).
				"practica":
					mode = Practice.MODE
					pads_lost.clear()
					_new_round(1)
					_start_countdown(0.0)
				"generative": _show_generative_menu()
				"challenges": _show_challenge_menu()
				"editor": _show_editor(MapFile.generated(4242, "small"))
				"settings": _show_settings("title")
				"pads": _show_settings("title", "pads")
				"input": _show_join("generative")
				# The ends of a night and the pause, to look at them: --pick=N
				# for the story's heist, --gen for the generative, --two or
				# --gang=N for more thieves.
				"end", "caught", "escaped":
					_look_at_end("escaped" if arg == "--menu=escaped" else "caught")
				"paused":
					_look_at_pause()
	# --plan=N: heist N's plan out of its room, told from the start (with
	# --explore, as if told before: straight to looking round it).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			var n := clampi(int(arg.substr(7)), 1, Story.count())
			if Story.save != Story.SAVE:
				Story.unlock(n, players)
			n = mini(n, Story.unlocked(players))
			if "--explore" in OS.get_cmdline_user_args():
				told_now[[n, players]] = true
			_show_museum_tour(n)
			_tour_room(n)
	# --acts=right,accept,...: presses for the way in, one every 1.2 s, to
	# record it going (Tour.act: left, right, up, down, accept, back, skip).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--acts="):
			var acts := arg.substr(7).split(",")
			for i in acts.size():
				get_tree().create_timer(1.2 * (i + 1)).timeout.connect(func() -> void:
					if tour:
						tour.act(acts[i]))
	# --brief=N:P: the story's night N, briefing page P (0-based), to look at it
	# (--gen: the generative's level N instead).
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--brief="):
			var bits := arg.substr(8).split(":")
			mode = "generative" if "--gen" in OS.get_cmdline_user_args() else "story"
			_new_round(int(bits[0]))
			_show_brief(int(bits[1]) if bits.size() > 1 else 0)
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
		# --smoke: and a smoke bomb goes off at P1's feet a moment in.
		if "--smoke" in OS.get_cmdline_user_args():
			get_tree().create_timer(3.5).timeout.connect(func() -> void:
				Smoke.drop(thieves[0], Sim.now_ms(), prop_noises))
		# --map: and take the map out a moment later.
		if "--map" in OS.get_cmdline_user_args():
			get_tree().create_timer(3.0).timeout.connect(_toggle_map)
		# --hide: and P1 starts a few steps from a place to hide in.
		if "--hide" in OS.get_cmdline_user_args():
			get_tree().create_timer(2.1).timeout.connect(_near_hideout.bind(0))


## A night's end straight away (--menu=caught, --menu=escaped), for looking
## at it: the heist --pick=N (the story), or --gen's first; saves nothing.
func _look_at_end(how: String) -> void:
	just_looking = true
	var args := OS.get_cmdline_user_args()
	if "--gen" in args:
		mode = "generative"
	players = 2 if "--two" in args else 1
	for arg in args:
		if arg.begins_with("--gang="):
			players = clampi(int(arg.substr(7)), 1, 4)
	_new_round(story_pick if mode == "story" else 1)
	# Over the museum, as after a night: the wall, not the title's picture;
	# and some figures for the paper, as after a night.
	hud.backdrop(null)
	HeistStats.time = 102.0
	HeistStats.add("hides", 2)
	HeistStats.add("smoke")
	if how == "caught":
		caught_thief = 0
		caught_by = guards[0].name if not guards.is_empty() else ""
	phase = how
	_show_end()


## The pause a moment into the night (--menu=paused), for looking at it;
## --lost: as if the first thief's pad had dropped out.
func _look_at_pause() -> void:
	var args := OS.get_cmdline_user_args()
	if "--gen" in args:
		mode = "generative"
	if "--two" in args:
		players = 2
	_new_round(story_pick if mode == "story" else 1)
	_show_brief(_brief_pages().size() - 1)
	get_tree().create_timer(1.0).timeout.connect(_start_playing)
	get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if "--lost" in args:
			pads_lost[0] = ""
		_pause())


## For trying hiding out (--hide): thief i a few steps from a hideout,
## facing it, on the free floor it is got into from. Returns the way from
## the hideout to where it stands, or (0, 0) if there is none.
func _near_hideout(i: int) -> Vector2i:
	var p := thieves[i]
	for s in Hideouts.all():
		for t in s.tiles:
			for d in Museum.DIRS:
				var n: Vector2i = t + d
				if n in s.tiles or Museum.tile_at(n.x + 0.5, n.y + 0.5) != Tiles.FLOOR:
					continue
				var far := n
				for k in 3:
					var m: Vector2i = far + d
					if Museum.tile_at(m.x + 0.5, m.y + 0.5) != Tiles.FLOOR:
						break
					far = m
				p.x = far.x + 0.5
				p.y = far.y + 0.5
				p.dir = atan2(-d.y, -d.x)
				return d
	return Vector2i.ZERO


# --- Screens -----------------------------------------------------------------------

## The title screen: the cover, and on any key the menu.
## The menu is built under it at once, so the cover fades away onto it,
## never onto the museum behind; the cover keeps the keys while it is up.
func _show_cover() -> void:
	_show_title()
	var cover := TitleScreen.new()
	cover.started.connect(func() -> void: sfx.ui("ok"))
	add_child(cover)


## The modes as cards. The story and the generative ask how many thieves
## first, in a bubble out of their card (_pick_players); pick: that bubble
## up again, coming back to it from what it led to.
func _show_title(pick := "") -> void:
	hud.backdrop(Hud.SPOTS.title)
	phase = "title"
	testing = null
	_drop_preview()
	var on := pick if pick != "" else "story"
	hud.show_menu([
		{"cards": [
			{"title": Text.t("MENU_GENERATIVE"), "text": Text.t("MENU_GENERATIVE_TEXT"), "stage": MenuStage.make("generative"), "call": _pick_players.bind("generative"), "colour": Hud.C.gold, "id": "generative", "focus": on == "generative"},
			{"title": Text.t("MENU_STORY"), "text": Text.t("MENU_STORY_TEXT"), "stage": MenuStage.make("story"), "call": _pick_players.bind("story"), "colour": Hud.C.safe, "id": "story", "focus": on == "story"},
			{"title": Text.t("MENU_CHALLENGE"), "text": Text.t("MENU_CHALLENGE_TEXT"), "stage": MenuStage.make("museum:large"), "call": _show_challenge_menu, "colour": Hud.C.green},
		], "width": 270, "arrows": true},
		{"gap": 40},
		{"buttons": [
			{"text": Text.t("MENU_SETTINGS"), "glyph": "settings", "call": _show_settings.bind("title"), "colour": Hud.C.dim},
			{"text": Text.t("MENU_QUIT"), "glyph": "quit", "call": _quit, "colour": Hud.C.dim},
		], "row": true, "small": true, "width": 260},
	], "title")
	hud.show_version()
	if pick != "":
		_pick_players(pick)


## How many thieves, for the story or the generative: a bubble out of the
## mode's card on the title, over the title as it is (Hud.pop_bubble), one
## to four, each a sticker of that many ninja heads in their colours
## (assets/ui/ninjas_N.png, tools/ninja_stickers.py) and just "1P"… under
## it, starting on the gang last played. Picking goes straight on
## (_players_picked); back (MenuKeys) or a click off it closes it, back to the card.
func _pick_players(which: String) -> void:
	phase = "pick"
	var choices: Array = []
	for n in range(1, 5):
		choices.append({"title": "%dP" % n, "icon": load("res://assets/ui/ninjas_%d.png" % n),
			"colour": _thief_colours()[n - 1], "call": _players_picked.bind(which, n)})
	hud.pop_bubble(which, Text.t("MENU_HOW_MANY"), choices, players - 1, func() -> void: phase = "title")


## n thieves picked in the bubble: the story's gang says which controls are
## whose (_show_join) and goes on to the town; the generative on to its menu.
## Kept in players either way, for the bubble to open on it coming back.
func _players_picked(which: String, n: int) -> void:
	players = n
	if which == "story":
		_story_players(n)
	else:
		_show_generative_menu()


# --- Challenges ------------------------------------------------------------------------

## The challenges: museums made by hand (MapFile), the game's own and the
## player's — and the story's nights, to touch up. The map picked, the line
## the list is on, a delete waiting for its second press, the editor while it
## is open, and the nights' museums as they build them (_night_as_map).
var challenge_map: MapFile
var challenge_at := ""
var challenge_delete := false
var editor: MapEditor
var _night_maps := {}


## The maps as a list of names — the story's nights, then the challenges — and
## beside it the one the list is on: its plan and what kind of night it is.
## Pressing a line opens it; a new map opens the editor.
func _show_challenge_menu() -> void:
	hud.backdrop(Hud.SPOTS.challenge)
	phase = "menu"
	challenge_delete = false
	_drop_preview()
	var lines: Array = [{"head": Text.t("MENU_STORY")}]
	for n in range(1, Story.count() + 1):
		var edited := MapFile.for_night(n) != null
		lines.append({"text": _night_name(n) + (" *" if edited else ""), "colour": Hud.C.green if edited else Hud.C.text,
			"call": _land_night.bind(n), "open": _show_night_map.bind(n), "selected": challenge_at == "night:%d" % n})
	lines.append({"head": Text.t("CHALLENGE_MAPS_HEAD")})
	var maps := MapFile.list()
	if maps.is_empty():
		lines.append({"head": Text.t("CHALLENGE_EMPTY")})
	for m in maps:
		lines.append({"text": m.name.to_upper(), "colour": Hud.C.gold if m.built_in else Hud.C.green,
			"call": _land_map.bind(m), "open": _show_challenge_map.bind(m), "selected": challenge_at == "map:" + m.path})
	# The plan's room: as big as the biggest museum's, so none jumps about.
	var room := MapEditor.picture(MapFile.blank(Museum.SIZES.large.w, Museum.SIZES.large.h), 8)
	var small := MapFile.blank(Museum.SIZES.small.w, Museum.SIZES.small.h)
	hud.show_menu([
		{"title": Text.t("MENU_CHALLENGE"), "size": 40},
		{"text": Text.t("CHALLENGE_TEXT"), "colour": Hud.C.dim},
		{"columns": [
			{"items": [{"list": lines, "width": 380, "height": 450}]},
			{"items": [
				{"text": "", "id": "pick_name", "size": 24},
				{"text": "", "id": "pick_info", "size": 16, "colour": Hud.C.dim},
				{"picture": room, "id": "pick_plan", "height": 330},
				{"text": Text.t("CHALLENGE_HINT"), "size": 14, "colour": Hud.C.dim},
			], "width": 560},
		], "separation": 30},
		{"buttons": [
			{"text": Text.t("CHALLENGE_NEW"), "call": _show_editor.bind(small), "colour": Hud.C.green},
			{"text": Text.t("MENU_BACK"), "call": _show_title, "colour": Hud.C.dim},
		], "row": true, "small": true},
	])


## The list lands on a story night: its museum, beside it.
func _land_night(n: int) -> void:
	challenge_at = "night:%d" % n
	var m := _night_as_map(n)
	hud.set_text("pick_name", _night_name(n), Hud.C.safe)
	hud.set_text("pick_info", _night_info(n, m), Hud.C.dim)
	hud.set_picture("pick_plan", MapEditor.picture(m, 8))


## The list lands on a challenge: its plan, beside it.
func _land_map(m: MapFile) -> void:
	challenge_at = "map:" + m.path
	hud.set_text("pick_name", m.name.to_upper(), Hud.C.gold if m.built_in else Hud.C.green)
	hud.set_text("pick_info", Text.t("CHALLENGE_BUILT_IN" if m.built_in else "CHALLENGE_MINE") + " · " + _challenge_info(m), Hud.C.dim)
	hud.set_picture("pick_plan", MapEditor.picture(m, 8))


## A night's name in the list: its number and its piece.
func _night_name(n: int) -> String:
	return Text.t("MENU_NIGHT_PIECE") % [n, String(Story.level(n).loot.name).to_upper()]


## Under a night's name: its museum, whether it has been touched up, its guards.
func _night_info(n: int, m: MapFile) -> String:
	var edited := MapFile.for_night(n) != null
	var guards := m.guards.size()
	return "%s · %s · %s" % [Story.museum(Story.museum_of(n)).name, Text.t("CHALLENGE_NIGHT_EDITED" if edited else "CHALLENGE_NIGHT_BUILT"),
		Text.t("TIP_GUARDS_ONE") if guards == 1 else Text.t("TIP_GUARDS_MANY") % guards]


## A story night's museum as a map: the one saved for it, or the one the
## night builds (for one thief, the way it plays), kept for the next time.
func _night_as_map(n: int) -> MapFile:
	var saved := MapFile.for_night(n)
	if saved:
		saved.name = _night_name(n)
		return saved
	if not _night_maps.has(n):
		var was := [mode, players, level, saved_map]
		mode = "story"
		players = 1
		level = n
		saved_map = null
		MuseumView.palette = Story.palette(n)
		MuseumView.exhibits = {}
		Sim.custom = Story.tuning(n)
		var seed_ := _story_seed(n)
		_lay_out(n, seed_)
		var at: Array[Vector2i] = []
		for g in guards:
			at.append(Vector2i(floori(g.x), floori(g.y)))
		var m := MapFile.from_museum(n, seed_, at)
		m.name = _night_name(n)
		_night_maps[n] = m
		mode = was[0]
		players = was[1]
		level = was[2]
		saved_map = was[3]
	return (_night_maps[n] as MapFile).copy()


## One story night: its plan, then edit it or, touched up, put it back as the
## night builds it.
func _show_night_map(n: int) -> void:
	hud.backdrop(Hud.SPOTS.challenge)
	phase = "challenge"
	challenge_at = "night:%d" % n
	var m := _night_as_map(n)
	var edited := MapFile.for_night(n) != null
	var row: Array = [{"text": Text.t("CHALLENGE_EDIT"), "call": _show_editor.bind(m), "colour": Hud.C.gold}]
	if edited:
		row.append({"text": Text.t("CHALLENGE_RESTORE_SURE" if challenge_delete else "CHALLENGE_RESTORE"), "call": _restore_night.bind(n), "colour": Hud.C.alert})
	row.append({"text": Text.t("MENU_BACK"), "call": _show_challenge_menu, "colour": Hud.C.dim})
	hud.show_menu([
		{"title": _night_name(n), "size": 36, "colour": Hud.C.safe},
		{"text": _night_info(n, m), "colour": Hud.C.dim, "size": 17},
		{"picture": MapEditor.picture(m, 8), "height": 300},
		{"text": Text.t("CHALLENGE_NIGHT_TEXT"), "colour": Hud.C.dim, "size": 14, "wrap": true, "width": 640},
		{"buttons": row, "row": true, "small": true},
	], "night:%d" % n)


## Twice to put a night back as it builds itself: the first press only asks.
func _restore_night(n: int) -> void:
	if not challenge_delete:
		challenge_delete = true
		_show_night_map(n)
		return
	var saved := MapFile.for_night(n)
	if saved:
		MapFile.remove(saved)
	challenge_delete = false
	_show_night_map(n)


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
	hud.backdrop(Hud.SPOTS.challenge)
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
	hud.show_menu(items, "map:" + m.path)


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
	editor = MapEditor.new()
	add_child(editor)
	# It fades in over the menus (never over the game behind them), which go
	# once it covers them.
	var coming := editor
	Hud.fade_layer(editor, 1.0).tween_callback(func() -> void:
		if editor == coming:
			hud.put_away())
	editor.ui_sound.connect(func(kind: String) -> void: sfx.ui(kind, 0.6))
	editor.closed.connect(func() -> void:
		_drop_editor()
		_show_challenge_menu())
	editor.preview.connect(_editor_preview)
	editor.play.connect(func(map: MapFile) -> void:
		testing = map.copy()
		testing_dirty = editor.dirty
		_drop_editor()
		if map.night > 0:
			story_test = map
			story_pick = map.night
			_start("story", 1)
			return
		challenge_map = map
		_start("challenge", 1))
	editor.open(m)


## A map tried from the editor (PROBAR): every way out of the game goes
## back to editing it, not to the menus. And whether it had changes unsaved.
var testing: MapFile
var testing_dirty := false
## A story night's museum being tried or looked round from the editor: the
## night plays it instead of the one saved for it.
var story_test: MapFile


func _back_to_editor() -> void:
	get_tree().paused = false
	var m := testing
	testing = null
	story_test = null
	_show_editor(m)
	editor.dirty = testing_dirty


## Out of a game to where it was started from: the editor, if it was a try.
func _leave_game(to: Callable) -> void:
	mega_voice.stop()
	_dojo_end()
	if testing:
		_back_to_editor()
	else:
		to.call()


## The words on that way out.
func _leave_text() -> String:
	if mode == Practice.MODE:
		return Text.t("PRACTICE_LEAVE")
	return Text.t("EDITOR_BACK_TO_EDITOR" if testing else "MENU_TO_MENU")


## The editor goes: the menus straight back up behind it, whole, and it
## fades away over them, deaf to every key and click as it does.
func _drop_editor() -> void:
	hud.visible = true
	hud.cover_now()
	var old := editor
	editor = null
	old.set_process_input(false)
	old.set_process_unhandled_input(false)
	for c in old.get_children():
		c.propagate_call("set", ["mouse_filter", Control.MOUSE_FILTER_IGNORE])
		c.propagate_call("set", ["focus_mode", Control.FOCUS_NONE])
	Hud.fade_layer(old, 0.0).tween_callback(old.queue_free)


## The map being edited, built in the game's world behind the editor, for
## its camera to fly round.
func _editor_preview(m: MapFile) -> void:
	players = 1
	seats = ["any"]
	pads_lost.clear()
	if m.night > 0:
		mode = "story"
		story_test = m
		_new_round(m.night)
		story_test = null
	else:
		mode = "challenge"
		challenge_map = m
		_new_round(1)
	editor.start_preview(world)


## Out of the game, from the title.
func _quit() -> void:
	_save_settings()
	get_tree().quit()


## The story with n thieves (picked in the title's bubble): a gang first
## says which controls are whose (_show_join); then on to the town
## (_story_gang). Each gang has its own way through the nights (Story.unlocked).
func _story_players(n: int) -> void:
	if n >= 2:
		_show_join("story", n)
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
		_show_prologue()
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
	_open_tour().open_city(players, m if m >= 0 else Story.museum_of(story_pick), fresh)


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
	_drop_preview()
	hud.hide_panel()
	tour = Tour.new()
	tour.stage.hurry = tour_hurry
	add_child(tour)
	tour.left.connect(func() -> void:
		_close_tour()
		_show_title("story"))
	tour.room_chosen.connect(_tour_room)
	tour.go.connect(_tour_go)
	tour.practice.connect(_tour_practice)
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


## The hideout picked in the town: the practice room, straight in. No plan,
## no briefing; the town fades into the room and the count begins.
func _tour_practice() -> void:
	mode = Practice.MODE
	pads_lost.clear()
	_new_round(1)
	_tour_go(0)


## What the tour needs to tell the plan of the heist laid out: its picture,
## the beats told over it and the marks to look round (PlanBeats), the job
## sheet, what getting the piece out takes, the goals for its stars, and
## whether it has been told before.
func _plan_data() -> Dictionary:
	_build_preview()
	var beats := PlanBeats.build(level, players, guards)
	return {
		"n": level,
		"image": Hud.plan_map(guards, _thief_colours().slice(0, thieves.size())),
		"tile_px": float(clampi(int(Hud.MAP_WIDTH / Museum.w), 8, 32)),
		"beats": beats,
		"marks": PlanBeats.marks(beats, guards),
		"takes": Briefing.takes(),
		"sheet": {"name": Heist.first_upper(Heist.loot.name), "blurb": Heist.loot.blurb,
			"story": Heist.loot.get("story", ""), "photo": preview.get_texture()},
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


## The generative mode's settings: two big cards, the difficulty and the
## museum's size, each showing the one in force (its diorama and its name),
## framed like every other menu's; pressing one pops a bubble of its three
## out of it (_pick_setting), like the title's how many thieves. Under them,
## EMPEZAR, with the focus, plays with the thieves picked in the title's
## bubble (_pick_players); back goes to that bubble, to change how many.
## on: the card to come back to ("difficulty" or "size"), just set in its
## bubble; "" starts on EMPEZAR.
func _show_generative_menu(on := "") -> void:
	hud.backdrop(Hud.SPOTS.generative)
	phase = "generative"
	hud.show_menu([
		{"title": Text.t("MENU_GENERATIVE_TITLE"), "size": 40},
		{"cards": [
			{"title": Text.t("MENU_DIFFICULTY"), "text": Text.t(DIFFICULTY_NAMES[Sim.difficulty]), "stage": MenuStage.make("guards:" + Sim.difficulty),
				"call": _pick_setting.bind("difficulty"), "id": "difficulty", "focus": on == "difficulty"},
			{"title": Text.t("MENU_SIZE"), "text": Text.t(SIZE_NAMES[size]), "stage": MenuStage.make("museum:" + size),
				"call": _pick_setting.bind("size"), "id": "size", "focus": on == "size"},
		], "width": 270},
		{"gap": 24},
		{"buttons": [
			{"text": Text.t("MENU_START"), "call": _start.bind("generative", players)},
			{"text": Text.t("MENU_BACK"), "call": _show_title.bind("generative"), "colour": Hud.C.dim},
		], "row": true, "focus": 0 if on == "" else -1},
	], "generative")


## The difficulty or the size, in a bubble out of its card (Hud.pop_bubble):
## its three, each on its own diorama (still), starting on the one in force.
## Picking keeps it (_set_setting); back (MenuKeys) or a click off it closes it,
## back to the card, as it was.
func _pick_setting(which: String) -> void:
	phase = "pick"
	var hard := which == "difficulty"
	var names: Dictionary = DIFFICULTY_NAMES if hard else SIZE_NAMES
	var colours := {"easy": Hud.C.green, "medium": Hud.C.gold, "hard": Hud.C.alert}
	var choices: Array = []
	for k: String in names:
		choices.append({"title": Text.t(names[k]), "stage": MenuStage.make(("guards:" if hard else "museum:") + k),
			"colour": colours[k] if hard else Hud.C.safe, "call": _set_setting.bind(which, k)})
	var now := names.keys().find(Sim.difficulty if hard else size)
	hud.pop_bubble(which, Text.t("MENU_HOW_HARD" if hard else "MENU_HOW_BIG"), choices, now,
		func() -> void: phase = "generative")


## A difficulty or a size picked in its bubble: kept in the settings, and
## the menu again, its card showing it and with the focus.
func _set_setting(which: String, k: String) -> void:
	if which == "difficulty":
		Sim.difficulty = k
	else:
		size = k
	_save_settings()
	_show_generative_menu(which)


func _start(which: String, n: int, picked := false) -> void:
	# A gang: first, each one says which controls are theirs.
	if n >= 2 and not picked:
		_show_join(which, n)
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
	_show_brief(0)


## The keys on each side of a shared keyboard: pressing any of them on the
## player-select screen takes that side (Shift by which of the two it is).
## Not its B (Space, Enter: KB_BACK): as on a pad, that one gives it up.
## One keyboard seats two at most; a third and fourth thief join with a pad.
## KEY_SLASH is where the key is, not what it says: the one right of the
## full stop ("/" on a US keyboard, "-" on a Spanish one).
const KB_LEFT := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_C, KEY_E, KEY_Q, KEY_F, KEY_TAB]
const KB_RIGHT := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SLASH, KEY_PERIOD, KEY_COMMA]
const KB_BACK := {KEY_SPACE: "kb_left", KEY_ENTER: "kb_right", KEY_KP_ENTER: "kb_right"}


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
	], "join")


func _seat_label(seat: String) -> String:
	match seat:
		"kb_left": return Text.t("SEAT_KB_LEFT")
		"kb_right": return Text.t("SEAT_KB_RIGHT")
		"any": return Text.t("SEAT_ANY")
	var pad := int(seat.substr(4))
	return Text.t("SEAT_PAD") % [pad + 1, Input.get_joy_name(pad).left(18)]


## A press on the player-select screen: it takes a seat; Esc frees the last
## one, B (Space, Enter on the keyboard) its own — or goes back when none is
## taken.
func _join_input(event: InputEvent) -> void:
	var seat := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_unjoin()
			return
		if KB_BACK.has(event.keycode):
			_leave_seat(KB_BACK[event.keycode])
			return
		if event.keycode == KEY_SHIFT:
			seat = "kb_right" if event.location == KEY_LOCATION_RIGHT else "kb_left"
		elif event.physical_keycode in KB_LEFT or event.keycode in KB_LEFT:
			seat = "kb_left"
		elif event.physical_keycode in KB_RIGHT or event.keycode in KB_RIGHT:
			seat = "kb_right"
	elif event is InputEventJoypadButton and event.pressed:
		if not Pads.real(event.device):
			return
		if event.button_index == JOY_BUTTON_B:
			_leave_seat("pad:%d" % event.device)
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
				pads_lost.clear()
				if join_for == "story":
					# The story's gang goes on to the town, to pick a night.
					_story_gang(join_count)
				else:
					_start(join_for, join_count, true))


## B takes its own thief off (a pad's, or a keyboard side's), or with nobody
## in, goes back: never somebody else's seat.
func _leave_seat(mine: String) -> void:
	if mine in joining:
		sfx.ui("back")
		joining.erase(mine)
		_draw_join()
	elif joining.is_empty():
		_unjoin()


func _unjoin() -> void:
	sfx.ui("back")
	if joining.is_empty():
		if join_for == "story":
			_show_title("story")
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
			{"text": Text.t("MENU_NEXT"), "call": _show_city if last else _show_prologue.bind(page + 1)},
		], "row": true, "focus": 1},
		{"buttons": [{"text": Text.t("MENU_SKIP"), "call": _show_city, "colour": Hud.C.dim}], "small": true},
	], "prologue:%d" % page)


## Straight to the night: past the tale and the briefing, into the countdown.
func _skip_story() -> void:
	_start_countdown(Hud.FADE_S)


func _prologue_back() -> void:
	if prologue_page > 0:
		_show_prologue(prologue_page - 1)
	else:
		_show_title("story")


## ● ○ ○ : where you are in a run of pages.
func _dots(at: int, count: int) -> String:
	var out: Array[String] = []
	for i in count:
		out.append("●" if i == at else "○")
	return " ".join(out)


## Sound and music, their volumes, the screen and the IA panel. Opens from
## the title and from the pause. Each line is a setting (Hud._stepper): accept
## or a click moves it on, ← and → move it down and up; each change is saved.
func _show_settings(from: String, page := "") -> void:
	if from == "title":
		hud.backdrop(Hud.SPOTS.settings)
	_drop_preview()
	settings_from = from
	settings_page = page
	phase = "settings"
	var keys: Array = {
		"": ["megaphone", "ia"],
		"sound": ["sound", "music", "music_volume", "effects_volume"],
		"screen": ["fullscreen", "window", "ui_scale", "quality", "render_scale", "vsync"],
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
	var title := Text.t({"": "MENU_SETTINGS", "sound": "SETTINGS_SOUND_TITLE", "screen": "SETTINGS_SCREEN_TITLE", "pads": "SETTINGS_PADS_TITLE"}[page])
	var items: Array = [{"title": title, "size": 48}, {"buttons": rows}]
	match page:
		"sound":
			items.append({"text": Text.t("SETTINGS_SOUND_HELP"), "size": 16, "colour": Hud.C.dim})
		"pads":
			var pads := Input.get_connected_joypads()
			var names: Array = pads.map(func(d): return Pads.describe(d))
			items.append({"text": (Text.t("SETTINGS_PADS_LIST") % " · ".join(names)) if not pads.is_empty() else Text.t("SETTINGS_NO_PADS"), "size": 16, "colour": Hud.C.gold})
			items.append(_controls_table())
			items.append({"text": Text.t("CONTROLS_MORE"), "size": 15, "colour": Hud.C.dim})
	hud.show_menu(items, "settings:" + page)


## What does what, for the controls page: an action a row, and its key for
## each keyboard half and its pad button across. A row's text is its cells
## split by "|"; one with a single key for both keyboards (M, P, N) spans them.
func _controls_table() -> Dictionary:
	var rows: Array = [
		["", Text.t("CONTROLS_P1"), Text.t("CONTROLS_P2"), Text.t("CONTROLS_PAD")],
		["", Text.t("CONTROLS_P1_WHERE"), Text.t("CONTROLS_P2_WHERE"), Text.t("CONTROLS_PAD_WHERE")],
	]
	# The main action first, then the way out, then the rest. P2's keys by
	# what they say on this keyboard ({slash}: "-" on a Spanish one).
	for key in ["CONTROLS_MOVE", "CONTROLS_PUSH", "CONTROLS_ROLL", "CONTROLS_CROUCH", "CONTROLS_SLOW", "CONTROLS_MAP", "CONTROLS_PAUSE", "CONTROLS_MUTE"]:
		var line := Text.t(key).replace("{slash}", _key_label(KEY_SLASH)).replace("{period}", _key_label(KEY_PERIOD))
		var cells: Array = Array(line.split("|"))
		if cells.size() == 3:
			cells[1] = {"text": cells[1], "span": 2}
		rows.append(cells)
	return {"table": rows, "widths": [200, 170, 170, 240], "heads": 2}


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
		"quality": return Text.t("SETTINGS_QUALITY") % Text.t("SETTINGS_QUALITY_LOW" if Quality.is_low() else "SETTINGS_QUALITY_HIGH")
		"render_scale": return Text.t("SETTINGS_RENDER_SCALE") % Quality.scale
		"ia": return Text.t("SETTINGS_IA") % yes.call(show_ia)
		"megaphone": return Text.t("SETTINGS_MEGAPHONE") % Text.t("SETTINGS_MEGAPHONE_" + megaphone_mode.to_upper())
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
## with accept (E, A), round from 100 back to 0. Applied, saved, and the button's
## new text returned.
func _step_setting(dir: int, key: String) -> String:
	match key:
		"sound": _set_sound(not sound_on)
		"music": _toggle_music()
		"ia": _toggle_ia()
		"megaphone":
			# Both, notice only, voice only, off, round again.
			var modes := Settings.MEGAPHONE_MODES
			_set_megaphone_mode(modes[posmod(modes.find(megaphone_mode) + (1 if dir >= 0 else -1), modes.size())])
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
		"quality", "render_scale":
			_step_quality(key)
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


## Graphics quality flips; the 3D render scale goes to the next on offer.
func _step_quality(key: String) -> void:
	if key == "quality":
		Quality.set_state("high" if Quality.is_low() else "low", Quality.scale)
	else:
		Quality.set_state(Quality.level, Quality.next_scale(Quality.scale))
	_apply_quality()


## Quality and render scale, applied to the night and to every 3D viewport.
func _apply_quality() -> void:
	if world_env:
		Quality.apply_environment(world_env)
	if moon_light:
		Quality.apply_light(moon_light)
	Quality.apply_tree(get_tree())


func _set_sound(on: bool) -> void:
	sound_on = on
	AudioServer.set_bus_mute(0, not on)
	_save_settings()


func _toggle_music() -> void:
	music_on = not music_on
	sfx.set_music(music_on)


## The loudspeaker's mode changed, in the settings or while playing (from the
## pause): the notice on screen goes away without a notice mode, the voice is
## cut off without a voice mode.
func _set_megaphone_mode(m: String) -> void:
	megaphone_mode = m
	if not Settings.megaphone_text(m):
		hud.megaphone("")
	if not Settings.megaphone_sound(m):
		mega_voice.stop()


func _toggle_ia() -> void:
	show_ia = not show_ia


## What was saved last time, applied: sound, music and volumes, the screen,
## and the generative mode's last difficulty and size.
func _load_settings() -> void:
	var s := Settings.read()
	sound_on = s.sound
	music_on = s.music
	show_ia = s.ia
	megaphone_mode = s.megaphone_mode
	Sim.difficulty = s.difficulty
	size = s.size
	fullscreen = s.fullscreen
	vsync = s.vsync
	window = s.window
	ui_scale = s.ui_scale
	Quality.set_state(s.quality, s.render_scale)
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
	Quality.apply_tree(get_tree())


## Menus and HUD drawn bigger or smaller, whatever the window's size: the
## 2D is laid out for 1280×720 and scaled to the window, times this.
func _apply_ui_scale() -> void:
	get_window().content_scale_factor = ui_scale / 100.0


func _save_settings() -> void:
	Settings.write({
		"sound": sound_on, "music": music_on, "ia": show_ia, "megaphone_mode": megaphone_mode,
		"difficulty": Sim.difficulty, "size": size,
		"fullscreen": fullscreen, "vsync": vsync, "window": window, "ui_scale": ui_scale,
		"quality": Quality.level, "render_scale": Quality.scale,
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
	if settings_from != "paused":
		hud.backdrop(Hud.SPOTS.settings)
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
		# On the sounds, accept plays the one on screen; elsewhere it moves on.
		], "row": true, "focus": -1 if tab == "sounds" else 1})
	items.append({"buttons": [{"text": Text.t("MENU_BACK"), "call": _show_settings.bind(settings_from), "colour": Hud.C.dim}], "small": true})
	hud.show_menu(items, "assets:" + tab)


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
	_dojo_end()
	_close_map()
	phase = "paused"
	get_tree().paused = true
	var lost: Array = []
	for i in pads_lost:
		lost.append({"text": Text.t("PAD_LOST") % (i + 1), "size": 18, "colour": Hud.C.alert})
	if not lost.is_empty():
		lost.append({"text": Text.t("PAD_LOST_HOW"), "size": 15, "colour": Hud.C.dim})
	hud.cctv(true, _camera_caption(), _cctv_museum(), HeistStats.time)
	hud.show_menu([
		{"title": Text.t("MENU_PAUSE"), "size": 56}] + lost + [
		{"buttons": [
			{"text": Text.t("MENU_RESUME"), "call": _start_playing},
			{"text": Text.t("MENU_SETTINGS"), "call": _show_settings.bind("paused")},
			{"text": _leave_text(), "call": _quit_to_title},
		]},
	], "paused")


func _quit_to_title() -> void:
	get_tree().paused = false
	hud.cctv(false)
	_leave_game(_way_out() if mode == Practice.MODE else _show_title)


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
	if mode == "challenge" and challenge_map and challenge_map.name != "":
		return challenge_map.name.to_upper()
	return Text.t("HUD_CCTV_MUSEUM")


## Before a night, the same in every mode: the piece's tale if it has one,
## what is new tonight if anything is (only the story teaches), and the plan:
## the map and the rules for the night (Briefing).
func _brief_pages() -> Array:
	var pages := []
	if String(Heist.loot.get("story", "")).strip_edges() != "":
		pages.append("story")
	if mode == "story" and not Story.news(level, players).is_empty():
		pages.append("news")
	pages.append("plan")
	return pages


func _show_brief(page: int) -> void:
	var pages := _brief_pages()
	page = clampi(page, 0, pages.size() - 1)
	brief_page = page
	phase = "brief"
	# In the story, the museum's own picture behind its heists' screens.
	if mode == "story":
		hud.backdrop(Hud.MUSEUM_FOCUS, "museum_%d" % (Story.museum_of(level) + 1))
	var names := {"story": Text.t("BRIEF_TAB_STORY"), "news": Text.t("BRIEF_TAB_NEWS"), "plan": Text.t("BRIEF_TAB_PLAN")}
	var items: Array = []
	match pages[page]:
		"story": items.append_array(_story_items())
		"news": items.append_array(_news_items())
		"plan": items.append_array(_plan_items())
	var last := page == pages.size() - 1
	# Along the bottom: back on the left, the next page by name in the middle,
	# and straight to the night on the right (on the last page, the middle
	# one starts it).
	var row: Array = [
		{"text": Text.t("MENU_BACK"), "call": _brief_back, "colour": Hud.C.dim},
		{"text": Text.t("BRIEF_START") if last else Text.t("BRIEF_NEXT_TAB") % names[pages[page + 1]], "call": _start_countdown.bind(Hud.FADE_S) if last else _show_brief.bind(page + 1)},
	]
	if not last:
		row.append({"text": Text.t("BRIEF_SKIP"), "call": _skip_story, "colour": Hud.C.dim})
	items.append({"buttons": row, "row": true, "focus": 1})
	hud.show_menu(items, "brief:%d" % page)


func _brief_back() -> void:
	if brief_page > 0:
		_show_brief(brief_page - 1)
	elif mode == "story" and level == 1:
		_show_prologue(Story.prologue().size() - 1)
	elif mode == "story":
		_show_museum_tour(level)
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


## The story's first page: the gang's job sheet, on paper over the museum's
## picture (EndPages.piece_card) — the piece turning in a polaroid, which
## job this is, its name, what it is like and its tale.
func _story_items() -> Array:
	# Rebuilt each time: the last round's piece may still be on the stand.
	_build_preview()
	return [
		{"card": {"name": Heist.first_upper(Heist.loot.name), "blurb": Heist.loot.blurb,
			"story": Heist.loot.get("story", ""), "photo": preview.get_texture()}},
		{"gap": 16},
	]


## The plan: the map on the left; on the right, the piece (turning under a
## light, its name and how long it takes) and the rules for the night
## worked out from it (Briefing).
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
		{"text": Heist.first_upper(Heist.loot.name), "size": 26, "colour": Color(Heist.loot.colour), "wrap": true, "width": 330, "align": "left"},
		{"text": Briefing.takes(), "size": 15, "colour": Hud.C.dim, "wrap": true, "width": 330, "align": "left"},
	]
	var right: Array = [{"columns": [
		{"items": [{"picture": preview.get_texture(), "smooth": true, "height": 120}], "middle": true},
		{"items": piece, "separation": 4, "middle": true},
	], "separation": 12}]
	right.append({"gap": 4})
	right.append({"title": Text.t("BRIEF_TIPS_TITLE"), "size": 24, "align": "left"})
	for tip in Briefing.tips(guards, level if mode == "story" else 0):
		right.append({"text": "• " + tip, "size": 17, "wrap": true, "width": 540, "align": "left"})
	return [{"columns": [
		{"items": left, "separation": 6, "middle": true},
		{"items": right, "width": 540, "separation": 8, "middle": true},
	], "separation": 36}]


func _build_preview(loot: Dictionary = Heist.loot) -> void:
	_drop_preview()
	preview = SubViewport.new()
	preview.size = Vector2i(480, 300)
	preview.own_world_3d = true
	preview.transparent_bg = true
	Quality.setup_viewport(preview)
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
		# Gone once the menu showing it has faded out, not before.
		var old := preview
		get_tree().create_timer(Hud.FADE_S + Hud.SWAP_S).timeout.connect(old.queue_free)
		preview = null
		preview_pivot = null
		preview_spot = null


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
			if not testing:
				go = _leave_game.bind(_show_city.bind(Story.museum_of(level + 1), Story.museum_of(level + 1)))
		if mode == "story" and not testing:
			# The stars this go won, kept with the best (not when only looking).
			HeistStats.rate(level, players, true, not just_looking)
			if not just_looking:
				Story.unlock(level + 1, players)
			story_pick = mini(level + 1, Story.count())
			if level >= Story.count():
				_show_ending()
				return
	var ways: Array = [
		{"buttons": [{"text": next, "call": go, "colour": colour}], "big": true},
		{"buttons": [{"text": Text.t("EDITOR_BACK_TO_EDITOR") if testing else Text.t("END_TO_MENU"), "call": _leave_game.bind(_way_out()), "colour": Hud.C.dim}], "small": true},
	]
	if phase == "escaped":
		hud.show_menu([{"newspaper": _front_page(boss)}] + ways)
	else:
		# The file runs off the bottom of the screen: the buttons beside it.
		hud.show_menu([{"columns": [{"items": [{"mugshot": _police_file()}]}, {"items": ways, "middle": true}], "separation": 48}])


## Out of a night's end, its button or back: to the mode's menu.
func _way_out() -> Callable:
	return {"story": _show_city, "challenge": _show_challenge_menu,
		Practice.MODE: _show_city.bind(CityStage.HIDEOUT)}.get(mode, _show_title)


## Which headline the paper picks: the same heist, the same page.
func _end_pick() -> int:
	return absi(hash(String(Heist.loot.get("name", "")))) % 997 + level


## The town paper the morning after: its name, a big headline, the piece's
## photo and, beside it, the night in a few big figures. After a museum's
## big job (boss), the museum is the news.
func _front_page(boss: bool) -> Dictionary:
	_build_preview()
	# Wide, for the page: the same piece, with more room either side.
	preview.size = Vector2i(int(300 * EndPages.PAPER_PHOTO.x / EndPages.PAPER_PHOTO.y), 300)
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
		"photo": preview.get_texture(),
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
	if mode == "story" and not testing:
		var caught := phase != "escaped"
		var n := mini(level + 1, Story.count()) if not caught else level
		_show_museum_tour(n)
		if caught:
			get_tree().create_timer(0.7).timeout.connect(func() -> void:
				if tour and tour.state == "museum":
					tour.act("accept"))
		return
	_new_round(level + 1 if phase == "escaped" else level)
	_show_brief(0)


## Where back (Escape, Space, Enter or B: MenuKeys) goes somewhere, and so
## sounds.
const BACK_PHASES := ["menu", "pick", "generative", "challenge", "prologue", "ending", "brief", "paused", "settings", "assets", "caught", "escaped"]


func _unhandled_input(event: InputEvent) -> void:
	if phase == "tour" and tour:
		tour.input(event)
		return
	if phase == "join":
		_join_input(event)
		return
	# The night just over, frozen: nothing counts until its page is up.
	if phase == "over":
		return
	# A game of the dojo on: Tab leaves it, and at its end the panel takes the keys.
	if _dojo_game != null and phase == "playing" and _dojo_input(event):
		get_viewport().set_input_as_handled()
		return
	var key: Key = event.keycode if event is InputEventKey and event.pressed and not event.echo else KEY_NONE
	if key == KEY_N:
		_set_sound(not sound_on)
		if phase == "settings":
			_show_settings(settings_from, settings_page)
		return
	# A bubble (how many thieves, the generative's difficulty or size): its
	# own keys for the left-hand player (A and D along it) and 1 to 4
	# straight to one (past its last, nothing); the arrows move by themselves.
	if phase == "pick" and key in [KEY_A, KEY_D]:
		hud.bubble_move(-1 if key == KEY_A else 1)
		return
	if phase == "pick" and key >= KEY_1 and key <= KEY_4:
		hud.bubble_pick(key - KEY_1)
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
				_skip_story()
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
				hud.bubble_pick(hud.bubble_focus())
		"prev", "next":
			var step := -1 if intent == "prev" else 1
			if phase == "brief":
				var to := brief_page + step
				if to >= 0 and to < _brief_pages().size():
					_show_brief(to)
			else:
				_show_assets(assets_tab, assets_index + step)


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
	if phase in ["brief", "assets"]:
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
		"pick": hud.close_bubble(true)
		"generative": _show_title("generative")
		"challenge": _show_challenge_menu()
		"prologue": _prologue_back()
		"ending": _show_title()
		"brief": _brief_back()
		"paused": _start_playing()
		"settings": _settings_back()
		"assets": _show_settings(settings_from)
		"caught", "escaped": _leave_game(_way_out())


## 3, 2, 1, GO! over the museum, everyone frozen in place until it is over.
## wait: from a menu, the count waits for it to fade away (Hud.FADE_S), the
## camera already coming in on the gang.
func _start_countdown(wait := 0.0) -> void:
	# At home there is no count: the band is there and can move, the camera
	# coming in on it while the town fades away.
	if mode == Practice.MODE:
		_drop_preview()
		_start_playing()
		if wait > 0.0:
			_intro_camera(wait)
		return
	phase = "countdown"
	_drop_preview()
	hud.hide_panel()
	hud.countdown(_count_beep, _start_playing, wait)
	_intro_camera(wait + Hud.COUNT_S * Hud.COUNT.size())


func _count_beep(i: int) -> void:
	sfx.ui("go" if i == 3 else "tick")


func _start_playing() -> void:
	phase = "playing"
	get_tree().paused = false
	# Space and Enter go back out of the pause: one still held from there is
	# not a roll until it is let go (Sim.step_thief rolls on the press).
	for t in thieves:
		t.roll_key = true
	_drop_preview()
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
		piece = challenge_map.loot_piece()
	elif mode == Practice.MODE:
		piece = saved_map.loot_piece()
	Heist.plan_job(level, piece, players, saved_map.job() if saved_map else {})
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
	return Sim.assign_posts(guards)


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


## A story night's museum as touched up by hand, if it has been (the one
## being tried from the editor first); else null.
func _night_map(n: int) -> MapFile:
	if story_test and story_test.night == n:
		return story_test
	return MapFile.for_night(n)


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
		saved_map = _night_map(n)
		_lay_out(n, saved_map.seed if saved_map else _story_seed(n))
	elif mode == "challenge":
		Sim.custom = challenge_map.tuning()
		saved_map = challenge_map
		_lay_out(n, challenge_map.seed + n)
	elif mode == Practice.MODE:
		Sim.custom = Practice.tuning()
		saved_map = Practice.map(players)
		_lay_out(n, saved_map.seed)
	else:
		Sim.custom = {}
		_lay_out(n, randi() % 1000000000)
	stride = [0.0, 0.0, 0.0, 0.0]
	HeistStats.reset()
	caught_thief = -1
	caught_by = ""
	push_held = [false, false, false, false]
	smoke_held = [false, false, false, false]
	Smoke.reset(thieves)
	guard_steps.clear()
	prop_noises.clear()
	last_think = 0.0
	think_tick = 0
	log_lines.clear()
	Sim.thoughts.clear()
	Sim.light_events.clear()
	_build_world()
	_snap_camera()
	_start_megaphone(n)
	hud.set_gang(_thief_colours().slice(0, thieves.size()), _thief_darks().slice(0, thieves.size()), Heist.loot)
	hud.set_home(mode == Practice.MODE)
	home_room = ""
	home_leaving = false
	# In the house: the doors as at the start (all shut, the lounge in sight).
	_home_sight(true)


## In the band's house: the room the first thief is in (to say its name as
## one walks in) and whether the way out has been taken.
var home_room := ""
var home_leaving := false
## The house as drawn (null out of it): the doors and the dark rooms are its.
var den_view: DenView


## In the house: the rooms in sight (Den.visible_rooms: those with one of the
## band in, and those seen through the doors that are open) drawn and the
## rest dark, and what stands in the dark hidden: the dojo's things that
## fall (Props), the dummies and the sealed case's sock. snap: no fading
## (as a round begins). Nothing to do out of the house.
func _home_sight(snap := false) -> void:
	if mode != Practice.MODE or den_view == null or not is_instance_valid(den_view):
		return
	var rooms: Array[String] = []
	for p in thieves:
		if not p.out:
			rooms.append_array(Den.rooms_at(p.x, p.y))
	if not rooms.is_empty():
		den_view.set_visible_rooms(Den.visible_rooms(Den.open_doors(), rooms), snap)
	if props_view != null and is_instance_valid(props_view):
		props_view.show_where(den_view.shows_at)
	for d in mannequins:
		d.visible = den_view.shows_at(d.position.x + Museum.w / 2.0, d.position.z + Museum.h / 2.0)


## The scarecrows look for the band (Practice.scarecrow_sees, the guards' rule
## with their own numbers): one sees a thief and the whole dojo goes red with
## a siren for a few seconds (DenView.set_alert), then not again for a moment.
## Only the dojo: nobody is caught, nothing is counted, no megaphone speaks.
func _scarecrow_tick(dt: float) -> void:
	if scarecrow_list.is_empty() or den_view == null or not is_instance_valid(den_view):
		return
	var seen := false
	for p in thieves:
		if p.out:
			continue
		for sc in scarecrow_list:
			if Practice.scarecrow_sees(sc, Vector2(p.x, p.y), p.hiding or p.posing, p.posture < Sim.DOWN):
				seen = true
	var was: bool = scarecrow_alert.active
	scarecrow_alert = Practice.alert_step(scarecrow_alert, dt, seen)
	if scarecrow_alert.active != was:
		den_view.set_alert(scarecrow_alert.active)
		if scarecrow_alert.active and den_view.shows("dojo"):
			var r := Den.rect("dojo")
			sfx.at("siren", _to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0, 1.0), 0.5, 14.0)


## The bench of practice cases (Practice.bench_*): a lectern turns to the next
## test or level; a case is opened by the test picked, standing still or with
## the same minigame as in a heist; the panel is cut with the suction cup. All
## of it a game and nothing else: no stars, no progress, no noise, no megaphone.
func _bench_act(t: Thief, i: int, what: Dictionary, keys: Dictionary) -> void:
	var input := _game_input(i, keys)
	match what.what:
		"kind":
			Practice.bench_cycle_kind(bench, players)
			sfx.ui("nav")
		"level":
			Practice.bench_cycle_level(bench)
			sfx.ui("nav")
		"need_panel":
			sfx.ui("back")
		"panel":
			t.game = Minigame.make("steady", "bench", 4 + int(bench.level) * 2, input, 0, int(bench.level))
			bench_target[t.id] = what
			t.moving = false
			t.speed = 0.0
			t.sprinting = false
		_:
			var game := Practice.bench_game(bench.kind, int(bench.level), input)
			var c: Vector2i = Practice.bench_cases(players)[what.i].at
			t.dir = atan2(c.y + 0.5 - t.y, c.x + 0.5 - t.x)
			if game == null:
				bench_hold[t.id] = {"i": what.i, "t": 0.0}
			else:
				t.game = game
				bench_target[t.id] = what
				t.moving = false
				t.speed = 0.0
				t.sprinting = false
	if den_view != null and is_instance_valid(den_view):
		den_view.set_bench(bench)


func _bench_open(c: int) -> void:
	Practice.bench_open(bench, c)
	sfx.ui("stolen")
	var at: Vector2i = Practice.bench_cases(players)[c].at
	Fx.sparkle(world, _to_world(at.x + 0.5, at.y + 0.5, 1.05), Color("#e2262f"))


func _bench_tick(dt: float) -> void:
	var before := bench.duplicate(true)
	Practice.bench_step(bench, dt)
	for p in thieves:
		if bench_hold.has(p.id):
			var h: Dictionary = bench_hold[p.id]
			var still: bool = not p.out and not p.moving and p.speed < 0.2 and Practice.bench_case_at(Vector2(p.x, p.y), players) == int(h.i) and bench.cases[h.i].state == "closed"
			h.t = Practice.bench_hold_step(float(h.t), still, dt)
			if not still:
				bench_hold.erase(p.id)
			elif h.t >= Practice.BENCH_HOLD_S:
				bench_hold.erase(p.id)
				_bench_open(int(h.i))
		if bench_target.has(p.id):
			if p.game == null:
				bench_target.erase(p.id)
			elif p.game.what == "bench" and p.game.done:
				var what: Dictionary = bench_target[p.id]
				bench_target.erase(p.id)
				p.game = null
				if what.what == "panel":
					bench.panel_off = true
					sfx.ui("ok")
				else:
					_bench_open(int(what.i))
	if bench != before and den_view != null and is_instance_valid(den_view):
		den_view.set_bench(bench)


# --- The dojo's games -----------------------------------------------------------------------
## The sign posts of the house (Practice.ITEMS with `game`) start the dojo's games
## (DojoGames): a game on the band's own field, stepped here with the band's
## bodies, seen by DojoGamesView. Nothing in it counts for the story: only the
## best level of each size of band is kept (DojoGames.settle, section [dojo]).
## Tab or the pause leave a game; at its end the panel takes the keys.
var _dojo_game: DojoGame
var _dojo_view: DojoGamesView
## the lantern's scarecrow of AGUANTA ESCONDIDO (a guard's coat on its cross)
var _dojo_lantern: Figure
## thief index -> fell off the pedestal this frame (the balance minigame's word)
var _dojo_fell := {}
## seconds after leaving a game in which no sign post starts another
var _dojo_lock := 0.0


## Begin a game (its sign post's id) for the band, from where the first thief stands.
func _dojo_start(id: String) -> void:
	if _dojo_view == null or not is_instance_valid(_dojo_view) or thieves.is_empty() or _dojo_game != null:
		return
	var field := DojoField.from_den(saved_map if saved_map != null else Practice.map(players))
	field.set_scarecrows(Practice.scarecrows(players))
	var start := DojoField.tile_of(Vector2(thieves[0].x, thieves[0].y))
	var game := DojoGames.make(id, players, randi(), field, start)
	if game == null:
		return
	# Sight is the scarecrows' own (Practice), not the field's.
	game.seen = func(sc: Dictionary, pos: Vector2, hidden: bool) -> bool:
		return Practice.scarecrow_sees({"at": sc.tile, "dir": sc.facing}, pos, hidden)
	for i in thieves.size():
		game.names.append(Text.t("JOIN_PLAYER") % (i + 1))
	if game is PedestalGame:
		(game as PedestalGame).set_pedestals(Practice.plinth_tiles(players))
	elif game is HideGame:
		(game as HideGame).set_hideouts(Practice.hide_tiles(players))
		(game as HideGame).set_lantern(Practice.LANTERN_AT, Practice.LANTERN_DIR)
		_dojo_lantern_show(true, Practice.LANTERN_DIR)
	_dojo_game = game
	_dojo_fell.clear()
	game.start()
	sfx.ui("go")


## The lantern's scarecrow, up or down, looking where `angle` says.
func _dojo_lantern_show(on: bool, angle: float) -> void:
	if den_view != null and is_instance_valid(den_view):
		den_view.set_lantern(on, angle)
	if on and _dojo_lantern == null:
		_dojo_lantern = Figure.make("guard", COLOURS.guard, COLOURS.guard_dark)
		world.add_child(_dojo_lantern)
	if _dojo_lantern != null:
		_dojo_lantern.visible = on
		var at := Practice.LANTERN_AT
		_dojo_lantern.set_state(_to_world(at.x + 0.5, at.y + 0.5), angle, 0.0, 0.0)


## Leave the game, from wherever, with nothing kept; the view and the lantern go.
func _dojo_end() -> void:
	if _dojo_game == null:
		return
	_dojo_game.abort()
	_dojo_game = null
	if _dojo_view != null and is_instance_valid(_dojo_view):
		_dojo_view.show_view({})
	_dojo_lantern_show(false, 0.0)
	_dojo_lock = 0.5


## Keys for a game on: Tab leaves it; at its end accept picks (again, on, out),
## back leaves, and the arrows move along the panel. True if taken.
func _dojo_input(event: InputEvent) -> bool:
	if _dojo_view == null or not is_instance_valid(_dojo_view):
		return false
	if not _dojo_game.finished():
		if event is InputEventKey and MenuKeys.of(event) == "skip":
			sfx.ui("back")
			_dojo_end()
			return true
		return false
	var what := MenuKeys.of(event)
	if what == "accept":
		match _dojo_view.accept():
			"again":
				_dojo_fell.clear()
				_dojo_game.start()
				sfx.ui("go")
			"go_on":
				_dojo_game.continue_extra()
				sfx.ui("go")
			_:
				sfx.ui("back")
				_dojo_end()
		return true
	if what == "back":
		sfx.ui("back")
		_dojo_end()
		return true
	for a in ["ui_up", "ui_left", "ui_down", "ui_right"]:
		if event.is_action_pressed(a, false):
			sfx.ui("nav", 0.6)
			_dojo_view.move(-1 if a in ["ui_up", "ui_left"] else 1)
			return true
	return false


## A frame of the game on: the band's bodies in, its events out (sounds, the
## red of the alarm, the records), the picture and the doors it shuts.
func _dojo_tick(dt: float, keys: Dictionary) -> void:
	var bodies: Array[Dictionary] = []
	for i in thieves.size():
		var p := thieves[i]
		var input := _game_input(i, keys)
		bodies.append({"id": i, "pos": Vector2(p.x, p.y), "rolling": p.rolling, "speed": p.speed, "out": p.out,
			"hidden": p.hiding or p.posing, "posing": p.posing, "push": float(input.right) - float(input.left),
			"hold": input.action, "fell": _dojo_fell.get(i, false),
			"lean": (p.game as BalanceGame).lean if p.game is BalanceGame else 0.0})
	_dojo_fell.clear()
	var was_finished := _dojo_game.finished()
	var events := _dojo_game.step(dt, bodies)
	if DojoGames.settle(_dojo_game, events) or (_dojo_game.finished() and not was_finished):
		if den_view != null and is_instance_valid(den_view):
			den_view.refresh_signs()
	for e in events:
		if e.e == "alarm" and den_view != null and is_instance_valid(den_view):
			var was: bool = scarecrow_alert.active
			scarecrow_alert = Practice.alert_step(scarecrow_alert, 0.0, true)
			if scarecrow_alert.active and not was:
				den_view.set_alert(true)
	var view := _dojo_game.view()
	for id in view.get("gates_closed", []):
		if not Den.door(String(id)).is_empty() and Den.is_open(String(id)):
			Den.set_open(String(id), false)
			Den.apply_doors()
			if den_view != null and is_instance_valid(den_view):
				den_view.set_door(String(id), false)
	if _dojo_game is HideGame:
		_dojo_lantern_show(true, (_dojo_game as HideGame).lantern_angle)
	if _dojo_view != null and is_instance_valid(_dojo_view):
		_dojo_view.react(events, sfx, world)
		_dojo_view.show_view(view)


## Whether something at a spot of the plan (tiles) is drawn: everywhere but
## in one of the house's dark rooms.
func _home_shows(x: float, y: float) -> bool:
	return mode != Practice.MODE or den_view == null or not is_instance_valid(den_view) or den_view.shows_at(x, y)


## Where the band stands, in tiles, for what needs to know who is in the way.
func _band_points() -> Array:
	var out: Array = []
	for p in thieves:
		if not p.out:
			out.append(Vector2(p.x, p.y))
	return out


## The house's own goings-on each tick (true: the band has left). Crossing the
## front door with any of the band takes them all out, the way the pause does
## (the town is one screen); walking into a room names it; the bombs are
## never short.
func _home_tick() -> bool:
	if home_leaving or thieves.is_empty():
		return home_leaving
	for p in thieves:
		if not p.out and Den.at_door(p.x, p.y):
			home_leaving = true
			_quit_to_title()
			return true
	var room := Den.room_at(thieves[0].x, thieves[0].y)
	if room != "" and room != home_room:
		home_room = room
		hud.room_name(Text.t("HIDEOUT_ROOM_" + room.to_upper()))
	for p in thieves:
		Smoke.left[p.id] = Smoke.PER_THIEF
	_home_sight()
	return false


## The physics frame _pressed_keys last ran on: a gap means play (re)started.
var pad_frame := -1
## Crouch, action and roll keys and buttons held over from a menu, ignored
## until released (_fresh).
var pad_stale := {}
## each thief's controls as last read (_seat_input), for the prompts to see
## a press as it happens
var seat_now: Array = []


func _pressed_keys() -> Dictionary:
	var keys := {}
	# A, B, E, Space and Enter also press and back out of menus: one still held
	# from there when the play starts (or resumes) does nothing until let go.
	var resumed := Engine.get_physics_frames() != pad_frame + 1
	pad_frame = Engine.get_physics_frames()
	# Each thief's controls, as the key names Sim reads for that thief. P3's
	# and P4's are only names now: they play with a pad, never those keys.
	var names := [["w", "s", "a", "d", "c", "e", "space", "lalt", "f"], ["up", "down", "left", "right", "minus", "period", "enter", "ralt", "comma"], ["i", "k", "j", "l", "u", "o", "y", "h", "n"], ["kp8", "kp5", "kp4", "kp6", "kp0", "kpadd", "kpmul", "kpsub", "kpdot"]]
	seat_now.resize(mini(seats.size(), thieves.size()))
	for i in mini(seats.size(), thieves.size()):
		var got := _seat_input(seats[i], resumed)
		seat_now[i] = got
		for k in 9:
			if got[k]:
				keys[names[i][k]] = true
	return keys


## Which Shift keys are down, by key and KeyLocation. Polling cannot
## tell the left one (P1's) from the right one (P2's), so their key events
## keep this up to date.
var mod_down := {}


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_SHIFT and not event.echo:
		mod_down[[event.keycode, event.location]] = event.pressed
	# On your own either the keyboard or a pad may be in your hands: the
	# hints show whichever was touched last.
	if event is InputEventKey and event.pressed:
		last_pad = false
	elif ((event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)) and Pads.real(event.device):
		last_pad = true
		last_pad_device = event.device
		if event is InputEventJoypadButton and not pads_lost.is_empty():
			_reclaim_pad(event.device)
	# Tab skips the tale and the briefing: taken here, before the menu's
	# buttons take it to move the focus along and it never gets that far.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB and phase in ["prologue", "brief"]:
		get_viewport().set_input_as_handled()
		if phase == "prologue":
			_show_city()
		else:
			_skip_story()


## The last thing touched was a pad (for the hints of a thief on "any"),
## and which one.
var last_pad := false
var last_pad_device := 0


## The names of a thief's controls, for the hints: the directions ("move"),
## left and right ("lr"), up and down ("ud"), the action key and the one to
## let go ("cancel") — its keyboard side's keys, or its pad's.
func _controls(i: int) -> Dictionary:
	var seat: String = seats[i] if i < seats.size() else "any"
	var pad := seat.begins_with("pad:") or (seat == "any" and last_pad)
	if pad:
		return {"move": Text.t("KEY_STICK"), "lr": "◀ ▶", "ud": "▲ ▼", "action": "A", "cancel": "B"}
	if seat == "kb_right":
		return {"move": "← ↑ → ↓", "lr": "← →", "ud": "↑ ↓", "action": _key_label(KEY_PERIOD), "cancel": Text.t("KEY_ENTER")}
	return {"move": "WASD", "lr": "A D", "ud": "W S", "action": "E", "cancel": Text.t("KEY_SPACE")}


## What the key in that place says on this keyboard: "-" for KEY_SLASH on a
## Spanish one, "/" on a US one.
static func _key_label(physical: Key) -> String:
	var label := physical
	if DisplayServer.get_name() != "headless":
		label = DisplayServer.keyboard_get_label_from_physical(physical)
	# A printable key is its character; the rest go by name.
	if label > 32 and label < KEY_SPECIAL:
		return char(label).to_upper()
	return OS.get_keycode_string(label)


## Is this side's Shift held? A key event that never said which
## side counts for both; and with none down at all (let go in another
## window), none is.
func _mod_held(key: Key, side: KeyLocation) -> bool:
	if not Input.is_physical_key_pressed(key):
		for k in mod_down.keys():
			if k[0] == key:
				mod_down.erase(k)
		return false
	return mod_down.get([key, side], false) or mod_down.get([key, KEY_LOCATION_UNSPECIFIED], false)


## Is this key or button down, and not still held over from a menu (E and
## A accept there; Space, Enter and B back out)? One held when the play starts or
## resumes counts once it has been let go.
func _fresh(id: String, held: bool, resumed: bool) -> bool:
	if held and resumed:
		pad_stale[id] = true
	elif not held:
		pad_stale.erase(id)
	return held and not pad_stale.has(id)


## One seat's controls this frame: [up, down, left, right, crouch, push, roll,
## slow, smoke], the way most PC games have them. P1: WASD, E the action,
## Space the roll, C to crouch, left Shift held to walk slowly, F a smoke
## bomb. P2 the same round the arrows: the full stop, Enter, the key after
## the full stop (KEY_SLASH), right Shift and the comma. No Ctrl: on a Mac,
## Ctrl and Space change the keyboard's language and Ctrl and an arrow the
## desktop.
func _seat_input(seat: String, resumed: bool) -> Array:
	var out := [false, false, false, false, false, false, false, false, false]
	if seat == "any" or seat == "kb_left":
		for pair in [[0, KEY_W], [1, KEY_S], [2, KEY_A], [3, KEY_D], [4, KEY_C], [5, KEY_E], [6, KEY_SPACE], [8, KEY_F]]:
			var held := Input.is_physical_key_pressed(pair[1])
			if held if pair[0] < 4 else _fresh("key:%d" % pair[1], held, resumed):
				out[pair[0]] = true
		out[7] = _mod_held(KEY_SHIFT, KEY_LOCATION_LEFT)
	if seat == "any" or seat == "kb_right":
		for pair in [[0, KEY_UP], [1, KEY_DOWN], [2, KEY_LEFT], [3, KEY_RIGHT], [4, KEY_SLASH], [5, KEY_PERIOD], [6, KEY_ENTER], [6, KEY_KP_ENTER], [8, KEY_COMMA]]:
			var held := Input.is_physical_key_pressed(pair[1])
			if held if pair[0] < 4 else _fresh("key:%d" % pair[1], held, resumed):
				out[pair[0]] = true
		out[7] = out[7] or _mod_held(KEY_SHIFT, KEY_LOCATION_RIGHT)
	var pads: Array = Pads.connected() if seat == "any" else ([int(seat.substr(4))] if seat.begins_with("pad:") else [])
	var dz := deadzone / 100.0
	for pad in pads:
		var x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		out[0] = out[0] or y < -dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)
		out[1] = out[1] or y > dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)
		out[2] = out[2] or x < -dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)
		out[3] = out[3] or x > dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)
		# As most pads have it: A (south) the action, as it accepts in the
		# menus; B (east) the roll, the way out, as it backs out of them; X
		# (west) or a click of the left stick crouches; Y (north) throws a smoke
		# bomb. Each is ignored while still held over from a menu.
		for pair in [[5, JOY_BUTTON_A], [6, JOY_BUTTON_B], [4, JOY_BUTTON_X], [4, JOY_BUTTON_LEFT_STICK], [8, JOY_BUTTON_Y]]:
			if _fresh("pad:%d:%d" % [pad, pair[1]], Input.is_joy_button_pressed(pad, pair[1]), resumed):
				out[pair[0]] = true
		# LB held walks slowly; so does the stick past the dead zone but short
		# of halfway from there to the rim (the cross has no half measures).
		var tilt := Vector2(x, y).length()
		var nudged := (absf(x) > dz or absf(y) > dz) and tilt < dz + (1.0 - dz) * 0.5
		out[7] = out[7] or Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER) or nudged
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
	var pads: Array = Pads.connected() if seat == "any" else ([int(seat.substr(4))] if seat.begins_with("pad:") else [])
	for pad in pads:
		Input.start_joy_vibration(pad, weak * k, strong * k, secs)


## Each pad's guid while plugged in (device -> guid): once it is gone the
## system no longer says, and a lost seat waits for that pad by it.
var pad_guids := {}
## Seats whose pad dropped out: seat index -> the guid of the pad it had.
var pads_lost := {}


## A pad plugged in or out. Out: the thief it was has no hands (its seat is
## "lost") and a game in play pauses. In: if it is the pad a thief lost,
## back it goes to that thief.
func _pad_changed(device: int, connected: bool) -> void:
	if connected:
		pad_guids[device] = Input.get_joy_guid(device)
		var i := Pads.owner_back(pads_lost, pad_guids[device])
		if i >= 0 and Pads.real(device) and not ("pad:%d" % device) in seats:
			_give_pad(i, device)
		return
	var seat := "pad:%d" % device
	if phase == "join" and seat in joining:
		joining.erase(seat)
		_draw_join()
	for i in seats.size():
		if seats[i] == seat:
			seats[i] = "lost"
			pads_lost[i] = pad_guids.get(device, "")
	pad_guids.erase(device)
	if not pads_lost.is_empty():
		if phase == "playing":
			_pause()
		elif phase == "paused":
			_pause()


## A press on a pad while a thief has none: if the pad is nobody's, it is
## the first such thief's now.
func _reclaim_pad(device: int) -> void:
	if ("pad:%d" % device) in seats:
		return
	var first := -1
	for i in pads_lost:
		if first < 0 or i < first:
			first = i
	_give_pad(first, device)


func _give_pad(i: int, device: int) -> void:
	seats[i] = "pad:%d" % device
	pads_lost.erase(i)
	sfx.ui("ok")
	_rumble_pad(seats[i], 0.3, 0.15)
	_log(Text.t("LOG_PAD_BACK") % (i + 1))
	if phase == "paused":
		_pause()


# --- The loop ------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if preview_pivot:
		preview_pivot.rotate_y(dt * 0.9)
	_music_mood()
	if props_view and not thieves.is_empty():
		var at: Array[Vector3] = []
		for t in thieves:
			at.append(_to_world(t.x, t.y) if not t.out and not t.hiding else Vector3(0, -50, 0))
		props_view.move_thieves(at)
	if phase == "playing":
		_tick(dt)
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
	if phase == "playing":
		HeistStats.add("knocked")
	var loud := Props.crash_loudness(p.kind, strength)
	sfx.noise(p.kind, _to_world(p.x, p.y), loud)
	_rumble(0.3 + 0.5 * strength, 0.4 * strength, 0.15 + 0.2 * strength, Vector2(p.x, p.y))
	_shake((0.45 if p.kind in ["bust", "armour"] else 0.25) * (0.6 + 0.8 * strength))
	_log((Text.t("LOG_CRASH_EVERYWHERE") % Heist.first_upper(Props.name_of(p.kind))) if Props.heard_everywhere(loud) else Text.t("LOG_KNOCKED") % Props.name_of(p.kind))
	_mega("knocked")
	if phase == "playing":
		_act("knock_" + p.kind)


## Something already down, sent rolling or rustling by a thief's feet: a
## smaller noise, but a noise — the tin bin clatters, paper whispers.
func _on_prop_kicked(kind: String, at: Vector2, strength: float) -> void:
	var loud: float = {"bin": 7.5, "bust": 6.0, "panel": 5.0, "armour": 7.0, "paper": 2.5}.get(kind, 4.0) * (0.5 + 0.5 * strength)
	prop_noises.append(SoundEvent.make(at.x, at.y, "kick", loud))
	# The tin and the steel ring, the rubble and the board knock dry, the
	# paper whispers.
	var sound: String = {"bin": "kick_metal", "armour": "kick_metal", "paper": "whisper"}.get(kind, "kick_dry")
	sfx.noise(sound, _to_world(at.x, at.y), loud)


## The keys a thief's minigame reads this frame: its directions, action key
## and roll key (Minigame.input_from).
func _game_input(i: int, keys: Dictionary) -> Dictionary:
	var scheme: String = "solo" if thieves.size() == 1 else ["wasd", "arrows", "ijkl", "numpad"][i]
	var action: bool = keys.has(["e", "period", "o", "kpadd"][i]) or (thieves.size() == 1 and keys.has("period"))
	return Minigame.input_from(keys, Sim.SCHEMES[scheme], action)


## The little sounds of a job in hand, heard close by (the guards do not:
## picking a lock is silent, the case's alarm aside).
func _game_sounds(p: Thief) -> void:
	var at := _to_world(p.x, p.y, 1.0)
	for e in p.game.events:
		match e:
			"pin": sfx.at("pin", at, 0.7, 2.0)
			"slip": sfx.at("slip", at, 0.6, 2.0)
			"snip": sfx.at("snip", at, 0.7, 2.0)
			"spark": sfx.at("spark", at, 0.6, 2.0)
			# The arcade machine's pong (ArcadeGame): its bleeps.
			"bounce": sfx.at("pong_hit", at, 0.35, 2.0)
			"wall": sfx.at("pong_wall", at, 0.25, 2.0)
			"score": sfx.at("pong_score", at, 0.35, 2.0)
			"miss": sfx.at("pong_miss", at, 0.35, 2.0)
			"done": _rumble(0.3, 0.2, 0.12, Vector2(p.x, p.y))


## In a hideout, with the minigames on, a sneeze comes on after a while
## (SneezeGame): it is held in until the thief gets out, whichever way.
func _sneeze_coming(p: Thief, i: int, keys: Dictionary, dt: float) -> void:
	# In a game of the dojo the sneeze is the game's own (HideGame).
	if _dojo_game != null:
		if p.game is SneezeGame:
			p.game = null
		p.hidden_for = 0.0
		return
	if not p.hiding:
		p.hidden_for = 0.0
		if p.game is SneezeGame:
			p.game = null
		return
	p.hidden_for += dt
	if p.game == null and Heist.minigames() and p.hidden_for >= SneezeGame.CALM_S:
		p.game = Minigame.make("sneeze", "hideout", 1, _game_input(i, keys))


## ACHOO! Out of the hideout, stunned a moment, and heard all round.
func _sneeze(p: Thief, noises: Array[SoundEvent]) -> void:
	HeistStats.add("sneezes")
	p.game = null
	Hideouts.tip_out(p)
	p.dizzy = SneezeGame.STUN_S
	noises.append(SoundEvent.make(p.x, p.y, "sneeze"))
	sfx.noise("sneeze", _to_world(p.x, p.y, 1.0), Hearing.LOUDNESS["sneeze"])
	_rumble(0.5, 0.7, 0.25, Vector2(p.x, p.y))
	_shake(0.25)
	_log(Text.t("LOG_SNEEZE"))
	_mega("sneeze")
	_act("sneeze", thieves.find(p))


## A frame of a thief wriggling into a hideout (Hideouts.squeeze): in once
## it is done, or let go if the hideout went meanwhile.
func _squeeze(p: Thief, done: bool) -> void:
	var spot := p.hide_target
	match Hideouts.squeeze(p, guards, thieves, done):
		"in":
			p.game = null
			_hid(p, spot)
		"lost":
			p.game = null


## In: the lid's thud, and whether anyone saw it.
func _hid(p: Thief, spot: Hideouts.Spot) -> void:
	HeistStats.add("hides")
	sfx.at("roll", _to_world(p.x, p.y), 0.3, 2.0)
	_log(Text.t("LOG_HIDE_BLOWN") if p.hide_blown else Text.t("LOG_HIDE_IN") % Hideouts.name_of(spot.kind))
	_mega("hide")
	_act("hide_seen" if p.hide_blown else ("hide_armour" if spot.kind == "armour" else "hide_other"), thieves.find(p))


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
		var controls := _controls(i)
		controls.glyphs = {"action": _glyph(i, "action"), "cancel": _glyph(i, "roll"), "move": _glyph(i, "move")}
		controls.glyphs.lr = controls.glyphs.move if controls.glyphs.move.kind == "stick" else _glyph(i, "lr")
		controls.glyphs.ud = controls.glyphs.move if controls.glyphs.move.kind == "stick" else _glyph(i, "ud")
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
		if i < seat_now.size():
			var was: Array = seat_before[i] if i < seat_before.size() else []
			for input in INPUT_AT:
				for k in INPUT_AT[input]:
					if seat_now[i][k] and not (k < was.size() and was[k]):
						prompts[i].press(input)
	seat_before = seat_now.duplicate(true)


## What the action key would do for thief t where it stands, the first of
## these there is (the bubble says the same, _prompt_rows): a minigame at
## the case or the alarm panel ("job"), a pedestal ("plinth"), a hideout
## ("hide"), an arcade machine ("arcade"), a room's switch ("switch"), a
## prop to push over ("push"). In the band's house, a door next to one
## ("door": open it, or shut it if no one is in its way) comes before all but
## the job. {do, at}, or empty for nothing.
func _action_for(t: Thief) -> Dictionary:
	var job := Heist.game_for(t)
	if not job.is_empty():
		return {"do": "job", "at": job}
	if mode == Practice.MODE:
		var door := Den.door_near(Vector2i(int(floor(t.x)), int(floor(t.y))))
		if door != "" and Den.can_toggle(door, _band_points()):
			return {"do": "door", "at": door}
		var bench_act := Practice.bench_action(Vector2(t.x, t.y), bench, players)
		if not bench_act.is_empty():
			return {"do": "bench", "at": bench_act}
		if _dojo_game == null and _dojo_lock <= 0.0:
			var sign_game := Practice.game_at(Vector2(t.x, t.y), players)
			if sign_game != "":
				return {"do": "game", "id": sign_game}
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
		return {"input": input, "glyph": _glyph(i, input), "verb": verb}
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
	if Heist.carrier == p.id:
		return [{"verb": Text.t("HUD_JOB_CARRYING") % String(Heist.loot.name).to_upper()}]
	if p.posing:
		return [row.call("move", Text.t("HUD_PLINTH_DOWN"))]
	if p.hiding:
		return [row.call("move", Text.t("HUD_HIDE_OUT"))]
	if bench_hold.has(p.id):
		return [{"verb": Text.t("HIDEOUT_BENCH_HOLD"), "progress": float(bench_hold[p.id].t) / Practice.BENCH_HOLD_S}]
	if _dojo_game != null:
		return [] if _dojo_game.finished() else [{"verb": Text.t("HIDEOUT_GAME_LEAVE_KEY")}]
	var act := _action_for(p)
	match act.get("do", ""):
		"game": return [row.call("action", "%s: %s" % [Text.t("HIDEOUT_GAME_START"), Text.t(DojoGames.info(act.id).name_key)])]
		"bench":
			match act.at.what:
				"need_panel": return [{"verb": Text.t("HIDEOUT_BENCH_NEED_PANEL")}]
				"panel": return [row.call("action", Text.t("HIDEOUT_BENCH_PANEL"))]
				"kind": return [row.call("action", Text.t("HIDEOUT_BENCH_CHANGE_KIND"))]
				"level": return [row.call("action", Text.t("HIDEOUT_BENCH_CHANGE_LEVEL"))]
				_: return [row.call("action", Text.t("HIDEOUT_BENCH_OPEN"))]
		"job": return [row.call("action", Text.t({"lockpick": "HUD_GAME_PICK_HINT", "steady": "HUD_GAME_STEADY_HINT"}.get(act.at.kind, "HUD_GAME_WIRES_HINT")))]
		"plinth": return [row.call("action", Text.t("HUD_PLINTH_HINT"))]
		"hide": return [row.call("action", Text.t("HUD_HIDE_HINT") % Hideouts.name_of(act.at.kind).to_upper())]
		"arcade": return [row.call("action", Text.t("HIDEOUT_ARCADE_PLAY" if mode == Practice.MODE else "HUD_ARCADE_HINT"))]
		"switch": return [row.call("action", Text.t("HUD_SWITCH_HINT"))]
		"push": return [row.call("action", Text.t("HUD_PUSH_HINT") % Props.name_of(act.at.kind).to_upper())]
		"door": return [row.call("action", Text.t("HIDEOUT_DOOR_CLOSE" if Den.is_open(act.at) else "HIDEOUT_DOOR_OPEN"))]
	return []


## The glyph (Glyph spec) for one of thief i's inputs, on whatever it plays
## with: its keyboard half, or its pad drawn as that pad's maker draws it.
func _glyph(i: int, input: String) -> Dictionary:
	var seat: String = seats[i] if i < seats.size() else "any"
	var pad := seat.begins_with("pad:") or (seat == "any" and last_pad)
	if pad:
		if input == "move":
			return {"kind": "stick"}
		var device := int(seat.substr(4)) if seat.begins_with("pad:") else last_pad_device
		var place: String = {"action": "south", "crouch": "west", "roll": "east"}.get(input, "south")
		return {"kind": "pad", "pos": place, "family": _pad_family(device)}
	# The four to move, where the hand finds them; left-right and up-down,
	# the same four with the other two dimmed.
	var four = "arrows" if seat == "kb_right" else ["W", "A", "S", "D"]
	match input:
		"move": return {"kind": "keys4", "labels": four}
		"lr": return {"kind": "keys4", "labels": four, "lit": [false, true, false, true]}
		"ud": return {"kind": "keys4", "labels": four, "lit": [true, false, true, false]}
	var keys := _controls(i)
	var label: String = {"move": keys.move, "action": keys.action, "roll": keys.cancel,
		"crouch": _key_label(KEY_SLASH) if seat == "kb_right" else "C"}.get(input, "?")
	return {"kind": "key", "label": label}


## Whose pad it is, by its name: PlayStation and Nintendo draw their buttons
## their own way; anything else, the Xbox way (as most pads do).
static func _pad_family(device: int) -> String:
	var name := Input.get_joy_name(device).to_lower()
	for mark in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if name.contains(mark):
			return "ps"
	for mark in ["nintendo", "switch", "joy-con", "pro controller"]:
		if name.contains(mark):
			return "nintendo"
	return "xbox"


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


func _tick(dt: float) -> void:
	HeistStats.time += dt
	if mode == Practice.MODE:
		_dojo_lock = maxf(0.0, _dojo_lock - dt)
		_scarecrow_tick(dt)
		_bench_tick(dt)
	if mode == Practice.MODE and _home_tick():
		return
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
			hud.update_map(_live_map())
	var noises: Array[SoundEvent] = []
	# Hands at a lock or a panel (Minigame) shake as the guards grow alarmed.
	var suspicion := 0
	for g in guards:
		suspicion = maxi(suspicion, g.suspicion)
	for i in thieves.size():
		var p := thieves[i]
		var px := p.x
		var py := p.y
		# On your own both pads drive you; with two, each pad is its own.
		var scheme: String = "solo" if thieves.size() == 1 else ["wasd", "arrows", "ijkl", "numpad"][i]
		_sneeze_coming(p, i, keys, dt)
		busy[i] = p.game != null
		if p.game:
			p.game.tremble = Minigame.tremble_for(suspicion)
			p.game.pressure = Plinths.pressure(p, guards)
			var lean: float = (p.game as BalanceGame).lean if p.game is BalanceGame else 0.0
			var played := p.game.tick(_game_input(i, keys), dt)
			match played:
				"quit":
					# Off the pedestal as well, if that is where it was.
					if p.game.kind == "balance":
						Plinths.get_down(p, lean)
					p.hide_target = null
					p.arcade = Vector2i(-1, -1)
					p.game = null
					# The roll key let go of it: it is not a roll as well.
					p.roll_key = true
				"fail" when p.game.kind == "sneeze":
					_sneeze(p, noises)
				"fail":
					# Lost its balance: down it comes, and the guards hear it.
					_dojo_fell[i] = true
					Plinths.fall(p, (p.game as BalanceGame).lean, noises)
					p.game = null
					sfx.noise("roll_bump", _to_world(p.x, p.y), Hearing.LOUDNESS["tumble"])
					_rumble(0.5, 0.7, 0.25, Vector2(p.x, p.y))
					_shake(0.3)
					_log(Text.t("LOG_PLINTH_FELL"))
					_mega("dizzy")
					_act("plinth_fall", i)
				_:
					_game_sounds(p)
					if p.game.kind == "squeeze":
						_squeeze(p, played == "done")
		var step := Sim.step_thief(p, keys, dt, scheme)
		_sneeze_coming(p, i, keys, 0.0)
		var noise := Hearing.thief_noise(px, py, p, step.entered_cover, step.bumped, Sim.TOP_SPEED)
		# Footsteps land once per stride; a bump is its own event.
		stride[i] += Museum.dist(px, py, p.x, p.y)
		if noise and (noise.kind == "walk" or noise.kind == "sprint"):
			if stride[i] < 0.45 + p.speed / Sim.TOP_SPEED * 0.5:
				noise = null
			else:
				stride[i] = 0.0
		# Off in a ball: a rush over the floor (the guards hear nothing of it).
		if step.roll == "start":
			HeistStats.add("rolls")
			_act("roll", i)
			sfx.at("roll", _to_world(p.x, p.y), 0.7, 3.0)
		# Rolled into a wall: the thump, a puff of plaster, and it hurts.
		if step.bumped == "roll":
			HeistStats.add("bumps")
			Fx.puff(world, _to_world(p.x + cos(p.dir) * Sim.BODY, p.y + sin(p.dir) * Sim.BODY), false)
			_rumble(0.6, 0.9, 0.3, Vector2(p.x, p.y))
			var case := Museum.is_cover(p.x + cos(p.dir) * (Sim.BODY + 0.1), p.y + sin(p.dir) * (Sim.BODY + 0.1))
			_log(Text.t("LOG_ROLL_CASE" if case else "LOG_ROLL_WALL"))
			_act("roll_case" if case else "roll_wall", i)
		if noise and not p.out:
			noises.append(noise)
			var what := "step" if noise.kind in ["walk", "sprint", "rustle"] else (noise.kind if noise.kind in ["shelf", "roll_bump"] else "bump")
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
	# and the guards come to see. At a room's switch the same key flips it.
	for i in thieves.size():
		var t := thieves[i]
		var pressed: bool = keys.has(["e", "period", "o", "kpadd"][i]) or (thieves.size() == 1 and keys.has("period"))
		# Not from inside a hideout, and not the press that just ended a
		# minigame (the sneeze let out, the balance lost): that one was the game's.
		var act := _action_for(t) if pressed and not push_held[i] and not t.game and not busy[i] and not t.hiding else {}
		match act.get("do", ""):
			"job":
				Heist.start_game(t, act.at, _game_input(i, keys))
				if act.at.what == "case":
					_act("case", i)
				sfx.at("pick", _to_world(t.x, t.y), 0.5, 2.0)
			"plinth":
				Plinths.climb(t, act.at, guards)
				_act("plinth", i)
				# With minigames the pose is held on one foot (Minigame "balance").
				if Heist.minigames():
					t.game = Minigame.make("balance", "plinth", 1, _game_input(i, keys))
				sfx.at("roll", _to_world(t.x, t.y), 0.4, 2.0)
				_log(Text.t("LOG_PLINTH_BLOWN" if t.pose_blown else "LOG_PLINTH_UP"))
			"hide":
				# In with a moment's wriggling (Minigame "squeeze", _squeeze);
				# before the nights have minigames, in at once.
				if Heist.minigames():
					Hideouts.start(t, act.at, _game_input(i, keys))
				else:
					Hideouts.get_in(t, act.at, guards)
					_hid(t, act.at)
			"arcade":
				# A game of pong, facing the screen: nothing to win (ArcadeGame).
				var arcade: Vector2i = act.at
				t.game = Minigame.make("arcade", "arcade", 1, _game_input(i, keys))
				t.arcade = arcade
				_act("arcade", i)
				t.dir = atan2(arcade.y + 0.5 - t.y, arcade.x + 0.5 - t.x)
				sfx.at("pong_score", _to_world(t.x, t.y, 1.0), 0.4, 2.0)
				_log(Text.t("LOG_ARCADE"))
			"bench":
				_bench_act(t, i, act.at, keys)
			"game":
				_dojo_start(String(act.id))
			"switch":
				Sim.flip_switch(act.at, t, guards, now, noises)
			"push":
				Props.push(act.at, t, now, noises)
			"door":
				# Open or shut (it was checked no one is in the way): the plan
				# follows, the leaves slide, and what is seen is worked out again.
				if Den.toggle_door(act.at, _band_points()):
					if den_view != null and is_instance_valid(den_view):
						den_view.set_door(act.at, Den.is_open(act.at))
					sfx.at("door", _to_world(t.x, t.y, 0.5), 0.6, 4.0)
					_home_sight()
		push_held[i] = pressed
	for p in Props.knocked:
		props_view.shove(p)
		_prop_fell(p)
	# A suit of armour gone over with someone inside: out they tumble.
	for t in thieves:
		if t.hiding and t.hideout.prop and t.hideout.prop.fallen:
			Hideouts.tip_out(t)
			t.dizzy = Plinths.FALL_DOWN_S
			t.posture = 1.0
			_log(Text.t("LOG_HIDE_TIPPED"))
	# Smoke bombs: F (P2 the comma), or Y on the pad, at your feet.
	for i in thieves.size():
		var pressed: bool = keys.has(["f", "comma", "n", "kpdot"][i])
		if pressed and not smoke_held[i]:
			if Smoke.drop(thieves[i], now, noises) == null and not thieves[i].out:
				sfx.ui("back", 0.5)
				_act("smoke_empty", i)
		smoke_held[i] = pressed
	Smoke.step(now)
	for c in Smoke.fresh:
		HeistStats.add("smoke")
		SmokeFx.burst(world, _to_world(c.x, c.y), Smoke.RADIUS * 1.15, Smoke.SECONDS)
		sfx.at("smoke", _to_world(c.x, c.y, 0.5), 0.9, 6.0)
		_rumble(0.3, 0.5, 0.3, Vector2(c.x, c.y))
		_log(Text.t("LOG_SMOKE"))
		_mega("smoke")
		var by := thieves.find_custom(func(t): return t.id == c.by)
		_act("smoke_last" if by >= 0 and Smoke.count(thieves[by]) == 0 else "smoke", by)
	Smoke.clear_fresh()
	if _dojo_game != null:
		_dojo_tick(dt, keys)

	# The job: working the case (and its alarm), carrying, dropping, the door.
	var before_alarms := noises.size()
	var cut_before := [Heist.panel_off, Heist.panel2_off]
	var took := Heist.step(thieves, dt, now, noises)
	if [Heist.panel_off, Heist.panel2_off] != cut_before:
		sfx.ui("ok")
		_log(Text.t("LOG_PANEL_CUT"))
		_mega("panel")
		_act("panel")
	if noises.size() > before_alarms:
		if Heist.progress < 0.1:
			_log(Text.t("LOG_CASE_ALARM"))
			_mega("alarm")
		sfx.at("alarm", _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5), 0.8)
	match took:
		"stolen":
			sfx.ui("stolen")
			Fx.sparkle(world, _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05), Color(Heist.loot.colour))
			_punch_in()
			_log(Text.t("LOG_GOT_IT_TEAM" if thieves.size() > 1 else "LOG_GOT_IT") % Heist.loot.name)
			_mega("stolen")
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
			HeistStats.add("seen")
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
			_mega("seen")
	for w in Sim.warn_partners(guards, now):
		sfx.at("whisper", _to_world(w.x, w.y), 0.6)
		_log(Text.t("LOG_WARN") % [w.from, w.to])
	# What the guards think stays off the screen.
	Sim.thoughts.clear()
	for e in Sim.light_events:
		var label := Text.t("LOG_THE_ROOM_OF")
		for z in Museum.zones:
			if z.room == e.room:
				label = z.label_of
		var r: Museum.Room = Museum.rooms[e.room]
		sfx.at("lights", _to_world(r.switch_at.x + 0.5, r.switch_at.y + 0.5), 0.8)
		if e.thief:
			HeistStats.add("lights")
			_act("switch")
			_log(Text.t("LOG_YOU_LIGHTS_ON" if e.on else "LOG_YOU_LIGHTS_OFF") % label)
			_mega("lights_on" if e.on else "lights_off")
		else:
			_log(Text.t("LOG_LIGHTS") % [e.by, label])
			_mega("lights_on" if e.on else "lights_off")
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
		# Seen wobbling on one foot: whoever sees it knows, and comes for it.
		if p.posing and not p.hidden and p.game and p.game.wobbling():
			p.pose_blown = true
			for g in Sim.witnesses(guards, p):
				Sim.learn(g, p)
		if Sim.caught(guards, p):
			p.out = true
			p.speed = 0
			sfx.ui("caught")
			if caught_thief < 0:
				caught_thief = thieves.find(p)
				caught_by = _nearest_guard(p)
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
					_mega("waiting")
	_megaphone_tick(dt)
	# No clock: take as long as you like. The whole gang out of the door
	# with the piece wins; one of you caught ends the night.
	# The night stops there (phase "over"), a moment (Hud.HOLD_S) to see it
	# end before its page comes up; nothing pressed meanwhile counts.
	if thieves.any(func(p): return p.out and not p.safe):
		_night_over("caught")
	elif thieves.all(func(p): return p.safe):
		sfx.ui("escaped")
		_night_over("escaped")


## A new round: the loudspeaker starts from nothing, and welcomes the gang.
func _start_megaphone(n: int) -> void:
	mega = Megaphone.new(n if mode == "story" else 0, guards.size(), thieves.size(), Heist.loot.name, randi())
	mega_still = 0.0
	mega_suspicion = 0
	mega_exit_said = false
	hud.megaphone("")
	mega_voice.stop(true)
	_mega("start")


## A thief (who, or -1) did something the loudspeaker may remark on, some
## of the time (Megaphone.act): a roll, a crash, a bin over...
func _act(what: String, who := -1) -> void:
	if megaphone_mode != "off" and mega and mode != "practica" and phase == "playing":
		mega.act(what, HeistStats.time, who)


## Something happened the loudspeaker may have a word about.
func _mega(kind: String) -> void:
	if megaphone_mode != "off" and mega and mode != "practica":
		mega.say(kind, HeistStats.time)


## Every tick: what the guards' suspicion and the door say, how long the
## gang has stood still, and the notice that comes of it, if any.
func _megaphone_tick(dt: float) -> void:
	if megaphone_mode == "off" or mega == null or mode == "practica":
		return
	var suspicion := 0
	for g in guards:
		suspicion = maxi(suspicion, g.suspicion)
	if suspicion > mega_suspicion and suspicion < 3:
		mega.say("suspect", HeistStats.time)
	if mega_suspicion >= 2 and suspicion == 0:
		_act("phew")
	mega_suspicion = suspicion
	for i in thieves.size():
		var p := thieves[i]
		var going := p.speed > 0.05 and not p.out and not p.rolling and p.dizzy <= 0.0 and not p.hiding
		mega.hold("crawl", going and p.crouched and p.posture > 0.5, dt, HeistStats.time, i)
		mega.hold("run", going and p.sprinting, dt, HeistStats.time, i)
		mega.hold("sneak", going and p.slow, dt, HeistStats.time, i)
	var moving := false
	for p in thieves:
		if not p.out and (p.speed > 0.05 or p.game != null or p.hiding or p.posing):
			moving = true
	mega_still = 0.0 if moving else mega_still + dt
	if Heist.taken and not mega_exit_said:
		for p in thieves:
			if not p.out and Museum.dist(p.x, p.y, Heist.exit.x + 0.5, Heist.exit.y + 0.5) < 6.0:
				mega_exit_said = true
				mega.say("near_exit", HeistStats.time)
	var tense := suspicion > 0 or guards.any(func(g): return g.alert or g.sees_player)
	var told := mega.tick(HeistStats.time, mega_still, tense)
	if not told.is_empty():
		var secs := mega_voice.speak(told.key, megaphone_mode, mode)
		if Settings.megaphone_text(megaphone_mode):
			hud.megaphone(told.text, MegaVoice.hold_for(secs))


func _night_over(how: String) -> void:
	phase = "over"
	mega_voice.stop()
	_close_map()
	get_tree().create_timer(Hud.HOLD_S).timeout.connect(func() -> void:
		if phase == "over":
			phase = how
			_show_end())


## The name of the guard nearest thief p: the one that caught it.
func _nearest_guard(p: Thief) -> String:
	var best: Guard = null
	for g in guards:
		if best == null or Museum.dist(g.x, g.y, p.x, p.y) < Museum.dist(best.x, best.y, p.x, p.y):
			best = g
	return best.name if best else ""


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
	# The camera is ~17 m from the floor: no need to spend froxels any further
	# (further when it pulls back to keep a gang in, _follow_camera).
	env.volumetric_fog_length = FOG_LENGTH
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
	Quality.apply_environment(env)
	var we := WorldEnvironment.new()
	we.environment = env
	world_env = env
	add_child(we)
	# Moonlight through the high windows: cold and faint, from one side. It
	# shades the tops of walls and cases apart from their faces, and draws the
	# rim round the figures in the dark (Figure's materials).
	moon = DirectionalLight3D.new()
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
	Quality.apply_light(moon)
	moon_light = moon
	add_child(moon)
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	# The ears are the thief's, not the camera's (high above): a guard's
	# steps grow as it comes near you, from the side it comes from.
	ear = AudioListener3D.new()
	add_child(ear)
	ear.make_current()


## The practice ground's scarecrows (see _build_world), and the alarm they
## share (Practice.alert_step).
var mannequins: Array[Figure] = []
var scarecrow_list: Array = []
var scarecrow_alert := Practice.alert_new()
## The bench of practice cases (Practice.bench_new), who is standing still at
## one (thief id -> {i, t}) and what each game running on the bench is for
## (thief id -> the action it began from).
var bench := Practice.bench_new()
var bench_hold := {}
var bench_target := {}

## The "moon" light, and whether the world is in the band's house's mood
## (warm and soft, DenView.mood) instead of the museums' night.
var moon: DirectionalLight3D
var mood_home := false


## The house or the museums' night: the Environment and the moon changed only
## when the round moves from one to the other.
func _set_mood(home: bool) -> void:
	if world_env == null or home == mood_home:
		return
	mood_home = home
	if home:
		DenView.mood(world_env, moon)
		return
	world_env.background_color = BACKGROUND
	world_env.ambient_light_color = AMBIENT_COLOUR
	world_env.ambient_light_energy = AMBIENT_ENERGY
	world_env.tonemap_exposure = 1.25
	world_env.tonemap_white = 6.0
	world_env.adjustment_saturation = 1.12
	world_env.adjustment_contrast = 1.08
	world_env.glow_intensity = 0.7
	world_env.glow_hdr_threshold = 1.0
	world_env.volumetric_fog_density = FOG_DENSITY
	world_env.volumetric_fog_albedo = Color("#c4c8ec")
	world_env.ssr_enabled = true
	world_env.ssil_enabled = true
	moon.light_color = MOON_COLOUR
	moon.light_energy = MOON_ENERGY
	moon.shadow_opacity = 0.85


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
	# The band's house is built by its own view (DenView), a MuseumView all the same.
	var view: MuseumView
	if mode == Practice.MODE:
		DenView.players = players
		view = DenView.new()
	else:
		view = MuseumView.new()
	_set_mood(mode == Practice.MODE)
	# The house begins with every door shut (the lounge is where the band is),
	# on the plan too; the view draws them as they are.
	den_view = null
	if mode == Practice.MODE:
		Den.reset_doors()
		Den.apply_doors()
	view.build()
	world.add_child(view)
	if mode == Practice.MODE:
		den_view = view as DenView
	# (The world is new: what the last one held of a game went with it.)
	_dojo_game = null
	_dojo_lantern = null
	_dojo_view = null
	if mode == Practice.MODE:
		_dojo_view = DojoGamesView.new()
		world.add_child(_dojo_view)
		_dojo_view.setup(camera)
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
	# The practice ground has no guards, only scarecrows in a guard's coat
	# (Practice.scarecrows) where the lessons put them, each with a torch:
	# standing still, to sneak round. DenView dresses them with their cross.
	mannequins.clear()
	scarecrow_list.clear()
	scarecrow_alert = Practice.alert_new()
	bench = Practice.bench_new()
	bench_hold.clear()
	bench_target.clear()
	if mode == Practice.MODE:
		for sc in Practice.scarecrows(players):
			var dummy := Figure.make("guard", COLOURS.guard, COLOURS.guard_dark)
			world.add_child(dummy)
			dummy.set_state(_to_world(sc.at.x + 0.5, sc.at.y + 0.5), sc.dir, 0.0, 0.0)
			dummy.set_meta("dir", sc.dir)
			mannequins.append(dummy)
			scarecrow_list.append(sc)
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
	sack_node = LootModels.sack()
	# Big enough to read from the camera up high.
	sack_node.scale = Vector3.ONE * 1.4
	sack_node.visible = false
	world.add_child(sack_node)
	# The star of the collection gets a spotlight from the ceiling: a cone of
	# warm white straight down on its case, its beam showing in the dust.
	# (The band's house has neither the spotlight nor the door of a heist:
	# its own front door is DenView's.)
	var home := mode == Practice.MODE
	loot_spot = null
	if not home:
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
	if home:
		panel_mats.clear()
		panel_glows.clear()
		return

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
		var held := (Heist.panel_by if i == 0 else Heist.panel2_by) != "" or (Heist.panel_off if i == 0 else Heist.panel2_off)
		var c := COLOURS.switch_on if held else Color("#ff922b")
		panel_mats[i].albedo_color = c
		panel_mats[i].emission = c
		panel_glows[i].light_color = c
		# Blinks while someone waits at the case for it.
		panel_glows[i].light_energy = 1.2 if held or not Heist.waiting else (0.4 + 1.2 * absf(sin(t * 6.0)))


## Each piece its own shape: a cut gem, an egg, a crown with points, a jade
# --- Drawing -------------------------------------------------------------------------

func _draw_frame(dt: float) -> void:
	if camera and hud:
		_draw_game_boxes()
		_draw_prompts(dt)
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
		f.set_state(_to_world(p.x, p.y, Plinths.HEIGHT if p.posing else 0.0), p.dir, p.posture, dt, _pose_of(p))
		# On one foot on a pedestal, the statue sways as its balance does.
		f.set_lean((p.game as BalanceGame).lean if p.posing and p.game is BalanceGame else 0.0)
		# Gone out of the door: not in the museum any more.
		f.visible = not p.safe and not p.hiding
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
	for d in mannequins:
		d.set_state(d.position, float(d.get_meta("dir", PI)), 0.0, dt)
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
	# The piece shows only on its case; taken, it is in the sack.
	loot_node.visible = not Heist.taken and _home_shows(Heist.at.x + 0.5, Heist.at.y + 0.5)
	loot_node.position = _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05 + sin(t * 2.0) * 0.05)
	loot_node.rotation.y = t * 1.2
	sack_node.visible = false
	if Heist.carrier != "":
		var c: Thief = thieves[0]
		for p in thieves:
			if p.id == Heist.carrier:
				c = p
		# Out of the door with it: gone with them.
		if not c.safe and not c.hiding:
			sack_node.visible = true
			# Slung on the back, lower when down on all fours.
			sack_node.position = _to_world(c.x - cos(c.dir) * 0.32, c.y - sin(c.dir) * 0.32, 0.45 - c.posture * 0.2 + (Plinths.HEIGHT if c.posing else 0.0))
			sack_node.rotation = Vector3(0, -c.dir + PI / 2, 0)
	elif Heist.dropped != Vector2.INF:
		sack_node.visible = true
		sack_node.position = _to_world(Heist.dropped.x, Heist.dropped.y, 0.0)
		sack_node.rotation = Vector3.ZERO


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
	var key := "%d:%d:%s" % [g.suspicion, step, g.knows_kind]
	if key == suspicion_keys[i]:
		return
	var was := suspicion_keys[i]
	var rose := was == "" or int(was.get_slice(":", 0)) < g.suspicion or (g.knows_kind != "" and was.get_slice(":", 2) != g.knows_kind)
	suspicion_keys[i] = key
	mark.texture = ImageTexture.create_from_image(_suspicion_image(g.suspicion, float(step) / SUSPICION_STEPS, g.knows_kind))
	mark.visible = true
	# Going up a level, or finding out where you are: a pop, so you notice.
	if rose:
		mark.scale = Vector3.ONE * 1.8
		create_tween().tween_property(mark, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## What a guard that saw you get in shows beside its marks: the thing you
## are in (Guard.knows_kind), by its icon in the editor's catalogue.
const HIDEOUT_ICONS := {"plinth": "exhibit_plinth", "sarcophagus": "big_sarcophagus", "armour": "prop_armour",
	"trojan_horse": "big_trojan_horse", "mammoth": "big_mammoth", "log": "big_log", "car": "big_car",
	"fridge": "exhibit_fridge", "box": "exhibit_box", "legionary": "exhibit_legionary", "confessional": "exhibit_confessional",
	"chest": "exhibit_chest", "egg": "exhibit_egg", "shell": "exhibit_shell"}
## How big the icon is, in the marks' pixels.
const HIDEOUT_ICON_PX := 22
static var _hideout_icons := {}


## The marks (as many as the level) over a bar filled to `fill`, in pixels
## with a dark outline so they read on floor, wall or torch light alike;
## and, for a guard that knows where you are hiding, the icon of it.
static func _suspicion_image(level: int, fill: float, hideout := "") -> Image:
	var marks := _marks_image(level, fill)
	if hideout == "" or not HIDEOUT_ICONS.has(hideout):
		return marks
	if not _hideout_icons.has(hideout):
		var icon: Image = load("res://assets/icons/objects/%s.png" % HIDEOUT_ICONS[hideout]).get_image()
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(HIDEOUT_ICON_PX, HIDEOUT_ICON_PX, Image.INTERPOLATE_LANCZOS)
		_hideout_icons[hideout] = icon
	var icon: Image = _hideout_icons[hideout]
	# Side by side, the icon on the right; mirrored room on the left so the
	# marks stay centred over the guard's head.
	var w := marks.get_width() + 2 * (HIDEOUT_ICON_PX + 1)
	var h := maxi(marks.get_height(), HIDEOUT_ICON_PX)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(marks, Rect2i(Vector2i.ZERO, marks.get_size()), Vector2i(HIDEOUT_ICON_PX + 1, 0))
	img.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(HIDEOUT_ICON_PX + 1 + marks.get_width() + 1, 0))
	return img


static func _marks_image(level: int, fill: float) -> Image:
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
## With several thieves the camera pulls back (along CAM_OFFSET) to keep them
## all in: this share of the half-screen each way is where they may go, so
## nobody reaches the edge while the follow catches up; never further back
## than CAM_MAX_ZOOM times the usual.
const CAM_MARGIN_X := 0.82
const CAM_MARGIN_Y := 0.7
const CAM_MAX_ZOOM := 4.0
## How close the camera starts a night, as a share of the usual distance.
const CAM_INTRO_NEAR := 0.5
## How far up the plan from the gang the camera looks then, so the count in
## the middle of the screen does not cover them.
const CAM_INTRO_LOW := 0.6
## How long (s) the pull back takes, and the coming back in: out quickly
## (someone is about to leave the picture), in lazily.
const CAM_ZOOM_OUT := 0.12
const CAM_ZOOM_IN := 1.2
const FOG_LENGTH := 25.0

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
## how far back the camera sits: 1 as usual, more to fit a spread-out gang
var cam_zoom := 1.0
## the Environment, for the fog to reach as far as the camera pulls back
var world_env: Environment
var moon_light: DirectionalLight3D
var punch_tween: Tween
## 0..1: how close the camera is on the gang at the start of a night (1 on top
## of them, 0 the usual follow), so you see where you are before you go
var intro := 0.0
var intro_tween: Tween


## The thieves the camera keeps in: those still in, or everyone at the end.
func _watched() -> Array:
	var live := thieves.filter(func(p): return not p.out)
	return live if not live.is_empty() else thieves


func _camera_target() -> Vector3:
	var watched := _watched()
	# The middle of the box round them, not their average: three on one side
	# must not push the fourth out of the picture.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in watched:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid := (lo + hi) / 2.0
	# Keep the frame inside the building.
	return _to_world(clampf(mid.x, 7, Museum.w - 7), clampf(mid.y, 5.5, Museum.h - 5.5), 0.6)


## How far back (1 = CAM_OFFSET) the camera must sit, looking at `focus`, for
## every thief to be inside the margins. The camera only pulls straight back
## along CAM_OFFSET (length D), so a point dx across and dz down the plan
## from the focus lands dx across and dz·up up the screen, at depth
## D·k - dz·back: nearer the camera the further down the plan it is. Keeping
## each inside its margin of the view gives the bound on k below.
func _zoom_to_fit(focus: Vector3) -> float:
	var d := CAM_OFFSET.length()
	var up := CAM_OFFSET.y / d  # how much of a step down the plan shows on screen
	var back := CAM_OFFSET.z / d  # how much of it goes into depth instead
	var tan_y := tan(deg_to_rad(camera.fov) / 2.0)
	var size := get_viewport().get_visible_rect().size
	var tan_x := tan_y * size.x / maxf(size.y, 1.0)
	# On your own the usual follow does: the camera never pulls back.
	var watched := _watched()
	if watched.size() < 2:
		return 1.0
	var k := 1.0
	for p in watched:
		var w := _to_world(p.x, p.y)
		var dx := absf(w.x - focus.x)
		var dz := w.z - focus.z
		var depth_y := up * absf(dz) / (tan_y * CAM_MARGIN_Y)
		var depth_x := dx / (tan_x * CAM_MARGIN_X)
		k = maxf(k, (maxf(depth_x, depth_y) + back * dz) / d)
	return minf(k, CAM_MAX_ZOOM)


func _snap_camera() -> void:
	var t := _camera_target()
	cam_rest = t + CAM_OFFSET
	cam_goal = t
	cam_vel = Vector3.ZERO
	cam_zoom = _zoom_to_fit(t)
	trauma = 0.0
	punch = 0.0
	if punch_tween:
		punch_tween.kill()
	intro = 0.0
	if intro_tween:
		intro_tween.kill()
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	camera.position = t + CAM_OFFSET * cam_zoom
	camera.look_at(t)
	_fog_follows_zoom()


## The fog reaches as far as the floor, however far back the camera is.
func _fog_follows_zoom() -> void:
	if world_env:
		world_env.volumetric_fog_length = FOG_LENGTH * cam_zoom


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
	# Pull back as far as it takes to keep everyone in, measured from where
	# the camera is really looking (it lags the target).
	var want := _zoom_to_fit(focus)
	var ease := CAM_ZOOM_OUT if want > cam_zoom else CAM_ZOOM_IN
	cam_zoom = lerpf(cam_zoom, want, 1.0 - exp(-dt / ease))
	_fog_follows_zoom()
	# The way in: close on the gang itself (not the frame kept inside the
	# building), easing out to the usual follow.
	# The gang sits below the middle, clear of the count.
	if intro > 0.0:
		focus = focus.lerp(_gang_middle() + Vector3(0, 0, -CAM_INTRO_LOW), intro)
	var near := lerpf(1.0, CAM_INTRO_NEAR, intro)
	camera.position = focus + CAM_OFFSET * cam_zoom * near * (1.0 - 0.22 * punch)
	camera.look_at(focus)
	# The shake slides the picture rather than moving the camera, so the
	# lights nearest the camera do not flicker from room to room.
	trauma = maxf(trauma - SHAKE_DECAY * dt, 0.0)
	var s := trauma * trauma
	var time := Time.get_ticks_msec() / 1000.0
	camera.h_offset = SHAKE_MOVE * s * (sin(time * 47.0) + 0.5 * sin(time * 83.0 + 1.3)) / 1.5
	camera.v_offset = SHAKE_MOVE * s * (sin(time * 53.0 + 2.1) + 0.5 * sin(time * 71.0 + 0.4)) / 1.5
	camera.rotate_object_local(Vector3.BACK, SHAKE_ROLL * s * sin(time * 37.0 + 0.7))


## The middle of the gang on the plan, where the way in starts.
func _gang_middle() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in _watched():
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid := (lo + hi) / 2.0
	return _to_world(mid.x, mid.y, 0.6)


## The camera starts right on the gang and pulls back to the usual follow
## over `seconds`: slow at first, so you spot yourself, then away.
func _intro_camera(seconds: float) -> void:
	if intro_tween:
		intro_tween.kill()
	intro = 1.0
	intro_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro_tween.tween_property(self, "intro", 0.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


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
	if mode == Practice.MODE:
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
