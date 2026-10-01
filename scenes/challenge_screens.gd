class_name ChallengeScreens
extends RefCounted
## The challenges: museums made by hand (MapFile), the game's own and the player's, and the story's
## nights to touch up. The list and each map's page, the map editor (MapEditor) over everything and
## the way back to it from a game tried out of it (PROBAR). The map picked, the line the list is on,
## a delete waiting for its second press and the nights' museums as they build them.

var host: Game

## The challenges: museums made by hand (MapFile), the game's own and the
## player's — and the story's nights, to touch up. The map picked, the line
## the list is on, a delete waiting for its second press, the editor while it
## is open, and the nights' museums as they build them (_night_as_map).
var challenge_map: MapFile
var challenge_at := ""
var challenge_delete := false
var editor: MapEditor
var night_maps := {}

## A map tried from the editor (PROBAR): every way out of the game goes
## back to editing it, not to the menus. And whether it had changes unsaved.
var testing: MapFile
var testing_dirty := false

## A story night's museum being tried or looked round from the editor: the
## night plays it instead of the one saved for it.
var story_test: MapFile


func _init(game: Game) -> void:
	host = game


## The maps as a list of names — the story's nights, then the challenges — and
## beside it the one the list is on: its plan and what kind of night it is.
## Pressing a line opens it; a new map opens the editor.
func show_menu() -> void:
	host.hud.backdrop(Hud.SPOTS.challenge)
	host.phase = "menu"
	challenge_delete = false
	host.podium.drop()
	var lines: Array = [{"head": Text.t("CHALLENGE_STORY_HEAD")}]
	for n in range(1, Story.count() + 1):
		var edited := MapFile.for_night(n) != null
		lines.append({"text": ("* " + Text.t("CHALLENGE_RETOUCHED") + " · " if edited else "") + night_name(n), "colour": Hud.C.green if edited else Hud.C.text,
			"call": land_night.bind(n), "open": show_night_map.bind(n), "selected": challenge_at == "night:%d" % n})
	lines.append({"head": Text.t("CHALLENGE_MAPS_HEAD")})
	var maps := MapFile.list()
	if maps.is_empty():
		lines.append({"head": Text.t("CHALLENGE_EMPTY")})
	for m in maps:
		lines.append({"text": m.name.to_upper(), "colour": Hud.C.gold if m.built_in else Hud.C.green,
			"call": land_map.bind(m), "open": show_map.bind(m), "selected": challenge_at == "map:" + m.path})
	# The plan's room: as big as the biggest museum's, so none jumps about.
	var room := MapEditor.picture(MapFile.blank(Museum.SIZES.large.w, Museum.SIZES.large.h), 8)
	var small := MapFile.blank(Museum.SIZES.small.w, Museum.SIZES.small.h)
	host.hud.show_menu([
		{"title": Text.t("MENU_CHALLENGE"), "size": 40},
		{"text": Text.t("CHALLENGE_TEXT"), "colour": Hud.C.dim},
		{"text": Text.t("CHALLENGE_EDIT_LEGEND"), "size": 15, "colour": Hud.C.text},
		{"columns": [
			# The challenges, in the middle; its line's right arrow reaches
			# the new-map button, up top on the other side (right_id/id).
			{"items": [{"list": lines, "width": 380, "height": 450, "right_id": "edit_map"}]},
			{"items": [
				{"buttons": [{"text": Text.t("CHALLENGE_NEW"), "id": "edit_map", "call": show_editor.bind(small), "colour": Hud.C.green}], "row": true, "small": true},
				{"text": "", "id": "pick_name", "size": 24, "wrap": true, "width": 560},
				{"text": "", "id": "pick_info", "size": 16, "colour": Hud.C.dim},
				{"picture": room, "id": "pick_plan", "height": 330},
				{"text": Text.t("CHALLENGE_HINT"), "size": 14, "colour": Hud.C.dim},
			], "width": 560},
		], "separation": 30},
		{"buttons": [
			{"text": Text.t("MENU_BACK"), "call": host._show_title, "colour": Hud.C.dim},
		], "row": true, "small": true, "align": "left"},
	])


## The list lands on a story night: its museum, beside it.
func land_night(n: int) -> void:
	challenge_at = "night:%d" % n
	var m := night_as_map(n)
	host.hud.set_text("pick_name", night_name(n), Hud.C.safe)
	host.hud.set_text("pick_info", night_info(n, m), Hud.C.dim)
	host.hud.set_picture("pick_plan", MapEditor.picture(m, 8))


## The list lands on a challenge: its plan, beside it.
func land_map(m: MapFile) -> void:
	challenge_at = "map:" + m.path
	host.hud.set_text("pick_name", m.name.to_upper(), Hud.C.gold if m.built_in else Hud.C.green)
	host.hud.set_text("pick_info", Text.t("CHALLENGE_BUILT_IN" if m.built_in else "CHALLENGE_MINE") + " · " + challenge_info(m), Hud.C.dim)
	host.hud.set_picture("pick_plan", MapEditor.picture(m, 8))


## A night's name in the list: its number and its piece.
func night_name(n: int) -> String:
	return Text.t("MENU_NIGHT_PIECE") % [n, String(Story.level(n).loot.name).to_upper()]


## Under a night's name: its museum, whether it has been touched up, its guards.
func night_info(n: int, m: MapFile) -> String:
	var edited := MapFile.for_night(n) != null
	var guards := m.guards.size()
	return "%s · %s · %s" % [Story.museum(Story.museum_of(n)).name, Text.t("CHALLENGE_NIGHT_EDITED" if edited else "CHALLENGE_NIGHT_BUILT"),
		Text.t("TIP_GUARDS_ONE") if guards == 1 else Text.t("TIP_GUARDS_MANY") % guards]


## A story night's museum as a map: the one saved for it, or the one the
## night builds (for one thief, the way it plays), kept for the next time.
func night_as_map(n: int) -> MapFile:
	var saved := MapFile.for_night(n)
	if saved:
		saved.name = night_name(n)
		return saved
	if not night_maps.has(n):
		# Layout uses shared simulation data. Borrow it synchronously with fresh
		# containers, then put the live round back before any frame can draw it.
		# A separate Game also keeps the live actors paired with Scenery's nodes.
		var was := _borrow_layout_state()
		var layout := Game.new()
		layout.mode = "story"
		layout.players = 1
		layout.level = n
		MuseumView.palette = Story.palette(n)
		MuseumView.exhibits = {}
		Sim.custom = Story.tuning(n)
		var seed_ := layout._story_seed(n)
		layout._lay_out(n, seed_)
		var at: Array[GuardSpawn] = []
		for g in layout.guards:
			var spawn := GuardSpawn.new()
			spawn.at = Vector2i(floori(g.x), floori(g.y))
			spawn.dir = g.dir
			at.append(spawn)
		var m := MapFile.from_museum(n, seed_, at)
		m.name = night_name(n)
		night_maps[n] = m
		layout.free()
		_restore_layout_state(was)
	return (night_maps[n] as MapFile).copy()


## Mutable globals touched by Game._story_seed/_lay_out, including caches.
## Keep the original containers: an editor/world may still hold their references.
static var layout_state := {
	Museum: "w h shape size_name seed_used grid outside ring open_tiles cover_tiles big_pieces watchpoints rooms zones lights_left spawn doors _doors_open columns paintings only_theme version _room_index _zone_index",
	Heist: "level loot at start exit exit_face route plan progress by carrier dropped taken _last_alarm team panel panel_face panel_by panel2 panel2_face panel2_by waiting hands short_hand panel_off panel2_off",
	Sim: "custom gang",
	MuseumView: "palette exhibits",
	Props: "list knocked",
	Placed: "plinths furniture",
	Collection: "picks _made_from",
	Arcades: "list fronts",
}


static func _borrow_layout_state() -> Dictionary:
	var state := {}
	for script: Script in layout_state:
		var fields := {}
		for field in String(layout_state[script]).split(" "):
			var value: Variant = script.get(field)
			fields[field] = value
			if value is Array or value is Dictionary:
				script.set(field, value.duplicate(true))
		state[script] = fields
	# These are aliases, not independent lists: Museum.clear and the layout
	# helpers must see the same temporary containers throughout generation.
	Plinths.list = Placed.plinths
	Hideouts.pieces = Placed.furniture
	return state


static func _restore_layout_state(state: Dictionary) -> void:
	for script: Script in state:
		for field in state[script]:
			script.set(field, state[script][field])
	Plinths.list = Placed.plinths
	Hideouts.pieces = Placed.furniture


## One story night: its plan, then edit it or, touched up, put it back as the
## night builds it.
func show_night_map(n: int) -> void:
	host.hud.backdrop(Hud.SPOTS.challenge)
	host.phase = "challenge"
	challenge_at = "night:%d" % n
	var m := night_as_map(n)
	var edited := MapFile.for_night(n) != null
	var row: Array = [{"text": Text.t("CHALLENGE_EDIT"), "call": show_editor.bind(m), "colour": Hud.C.gold}]
	if edited:
		row.append({"text": Text.t("CHALLENGE_RESTORE_SURE" if challenge_delete else "CHALLENGE_RESTORE"), "call": restore_night.bind(n), "colour": Hud.C.alert})
	row.append({"text": Text.t("MENU_BACK"), "call": show_menu, "colour": Hud.C.dim})
	host.hud.show_menu([
		{"title": night_name(n), "size": 36, "colour": Hud.C.safe},
		{"text": night_info(n, m), "colour": Hud.C.dim, "size": 17},
		{"picture": MapEditor.picture(m, 8), "height": 300},
		{"text": Text.t("CHALLENGE_NIGHT_TEXT"), "colour": Hud.C.dim, "size": 14, "wrap": true, "width": 640},
		{"buttons": row, "row": true, "small": true},
	], "night:%d" % n)


## Twice to put a night back as it builds itself: the first press only asks.
func restore_night(n: int) -> void:
	if not challenge_delete:
		challenge_delete = true
		show_night_map(n)
		return
	var saved := MapFile.for_night(n)
	if saved:
		MapFile.remove(saved)
	challenge_delete = false
	show_night_map(n)


## A map's line on its card: its size, difficulty and guards, or that it
## cannot be played yet.
func challenge_info(m: MapFile) -> String:
	if not m.check().is_empty():
		return Text.t("CHALLENGE_UNPLAYABLE")
	return Text.t("CHALLENGE_INFO") % [Heist.first_upper(Text.t(Game.SIZE_NAMES[m.size_name()]).to_lower()),
		Text.t(Game.DIFFICULTY_NAMES[m.difficulty]).to_lower(), m.guards_tonight()]


## One map: its plan, then play it with one to four thieves, edit it, or
## (the player's own) delete it.
func show_map(m: MapFile) -> void:
	host.hud.backdrop(Hud.SPOTS.challenge)
	host.phase = "challenge"
	challenge_map = m
	var items: Array = [
		{"title": m.name.to_upper(), "size": 36, "colour": Hud.C.gold if m.built_in else Hud.C.green},
		{"text": Text.t("CHALLENGE_BUILT_IN" if m.built_in else "CHALLENGE_MINE") + " · " + challenge_info(m), "colour": Hud.C.dim, "size": 17},
		{"picture": MapEditor.picture(m, 8), "height": 260},
	]
	if m.check().is_empty():
		items.append({"cards": [
			{"title": Text.t("MENU_PLAY_1"), "stage": MenuStage.make("players:1"), "call": host._start.bind("challenge", 1), "colour": Game.COLOURS.thief, "title_size": 12},
			{"title": Text.t("MENU_PLAY_2"), "stage": MenuStage.make("players:2"), "call": host._start.bind("challenge", 2), "colour": Game.COLOURS.thief2, "title_size": 12},
			{"title": Text.t("MENU_PLAY_3"), "stage": MenuStage.make("players:3"), "call": host._start.bind("challenge", 3), "colour": Game.COLOURS.thief3, "title_size": 12},
			{"title": Text.t("MENU_PLAY_4"), "stage": MenuStage.make("players:4"), "call": host._start.bind("challenge", 4), "colour": Game.COLOURS.thief4, "title_size": 12},
		], "width": 140})
	var row: Array = [{"text": Text.t("CHALLENGE_EDIT"), "call": show_editor.bind(m), "colour": Hud.C.gold}]
	if not m.built_in:
		row.append({"text": Text.t("CHALLENGE_DELETE_SURE" if challenge_delete else "CHALLENGE_DELETE"), "call": delete_map.bind(m), "colour": Hud.C.alert})
	row.append({"text": Text.t("MENU_BACK"), "call": show_menu, "colour": Hud.C.dim})
	items.append({"buttons": row, "row": true, "small": true})
	host.hud.show_menu(items, "map:" + m.path)


## Twice to delete: the first press only asks.
func delete_map(m: MapFile) -> void:
	if not challenge_delete:
		challenge_delete = true
		show_map(m)
		return
	MapFile.remove(m)
	show_menu()


## The map editor (MapEditor), over everything; back to the challenges when
## it closes.
func show_editor(m: MapFile) -> void:
	host.phase = "editor"
	challenge_delete = false
	host.podium.drop()
	editor = MapEditor.new()
	host.add_child(editor)
	# It fades in over the menus (never over the game behind them), which go
	# once it covers them.
	var coming := editor
	Hud.fade_layer(editor, 1.0).tween_callback(func() -> void:
		if editor == coming:
			host.hud.put_away())
	editor.ui_sound.connect(func(kind: String) -> void: host.sfx.ui(kind, 0.6))
	editor.closed.connect(func() -> void:
		drop_editor()
		show_menu())
	editor.preview.connect(editor_preview)
	editor.play.connect(func(map: MapFile) -> void:
		testing = map.copy()
		testing_dirty = editor.dirty
		drop_editor()
		if map.night > 0:
			story_test = map
			host.story_pick = map.night
			host._start("story", 1)
			return
		challenge_map = map
		host._start("challenge", 1))
	editor.open(m)


func back_to_editor() -> void:
	host.get_tree().paused = false
	var m := testing
	testing = null
	story_test = null
	show_editor(m)
	editor.dirty = testing_dirty


## The editor goes: the menus straight back up behind it, whole, and it
## fades away over them, deaf to every key and click as it does.
func drop_editor() -> void:
	host.hud.visible = true
	host.hud.cover_now()
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
func editor_preview(m: MapFile) -> void:
	host.players = 1
	host.seats = ["any"]
	host.pads_lost.clear()
	if m.night > 0:
		host.mode = "story"
		story_test = m
		host._new_round(m.night)
		story_test = null
	else:
		host.mode = "challenge"
		challenge_map = m
		host._new_round(1)
	editor.start_preview(host.world)


## A story night's museum as touched up by hand, if it has been (the one
## being tried from the editor first); else null.
func night_map(n: int) -> MapFile:
	if story_test and story_test.night == n:
		return story_test
	return MapFile.for_night(n)
