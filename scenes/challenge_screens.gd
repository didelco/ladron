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


## Which of the two lists show_menu is on: the workshop (Taller: the player's
## maps and the editor) or the missions. Every way back to the list keeps it.
var workshop := false


## The missions' list, from the start menu's MISIONES.
func show_missions() -> void:
	workshop = false
	show_menu()


## The workshop's list, from the start menu's TALLER.
func show_workshop() -> void:
	workshop = true
	show_menu()


## One of the two lists of maps, each a line with its name and beside it its
## plan and what it is. The missions: the game's own robberies, opening with
## the story (Missions). The workshop: a new map (the editor), the maps the
## player made, imported or downloaded, outside the story, and with the
## developer's mode on the story's nights to touch up. Pressing a line opens
## it.
func show_menu() -> void:
	challenge_delete = false
	host.podium.drop()
	var from := "workshop" if workshop else "challenge"
	var choices: Array = [{"id": "back", "label": Text.t("MENU_BACK"), "sticker": "volver.png", "call": host._show_title.bind(from, false)}]
	if workshop:
		choices.append({"id": "new", "label": Text.t("CHALLENGE_NEW"), "sticker": "editor-mapas.png", "description": Text.t("CHALLENGE_EDIT_LEGEND"), "call": show_editor.bind(MapFile.blank(Museum.SIZES.small.w, Museum.SIZES.small.h))})
	var listed := 0
	for m in MapFile.list():
		if Missions.is_mission(m) == workshop:
			continue
		# A mission is listed once its phone has rung (Missions.is_called),
		# or always with the developer's mode on.
		if not workshop and not host.dev_mode and not Missions.is_called(m):
			continue
		listed += 1
		choices.append({"id": "map:" + m.path, "label": ("✓ " if Missions.is_done(m) else "") + m.name.to_upper(), "sticker": "jugar-mapas.png" if mission_open(m) else "cancelar.png", "call": show_map.bind(m), "focus": land_map.bind(m)})
	if not workshop and listed == 0:
		choices.append({"id": "none", "label": Text.t("MISSION_NONE"), "sticker": "cancelar.png", "description": Text.t("MISSION_NONE_TEXT"), "call": host._show_title.bind(from, false)})
	if workshop and host.dev_mode:
		for n in range(1, Story.count() + 1):
			choices.append({"id": "night:%d" % n, "label": night_name(n), "sticker": "historia.png", "call": show_night_map.bind(n), "focus": land_night.bind(n)})
	var selected := 2 if workshop and choices.size() > 2 else mini(1, choices.size() - 1)
	for i in choices.size():
		if choices[i].id == challenge_at:
			selected = i
	host.hub.show_screen(Text.t("MENU_WORKSHOP" if workshop else "MENU_CHALLENGE"), choices, "challenges", "menu", host._show_title.bind(from, false), selected)


func land_night(n: int) -> void:
	challenge_at = "night:%d" % n
	var m := night_as_map(n)
	host.hub.set_preview(MapEditor.picture(m, 8), night_name(n) + "\n" + night_info(n, m))


func land_map(m: MapFile) -> void:
	challenge_at = "map:" + m.path
	host.hub.set_preview(MapEditor.picture(m, 8), m.name + "\n" + map_card(m))


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
	Heist: "level loot at start exit exit_face route plan progress by carrier dropped taken team panel panel_face panel_by panel2 panel2_face panel2_by waiting hands short_hand panel_off panel2_off",
	NightAlert: "alarm_left alarm_at alarms intruder quiet robbed found_by door_guard door_spot door_clock door_left clock aims rolls events _noise_in",
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
	challenge_at = "night:%d" % n
	var m := night_as_map(n)
	var choices: Array = [
		{"id": "edit", "label": Text.t("CHALLENGE_EDIT"), "sticker": "editar-mapas.png", "description": night_info(n, m) + "\n" + Text.t("CHALLENGE_NIGHT_TEXT"), "call": show_editor.bind(m)},
	]
	if MapFile.for_night(n) != null:
		choices.append({"id": "restore", "label": Text.t("CHALLENGE_RESTORE_SURE" if challenge_delete else "CHALLENGE_RESTORE"), "sticker": "cancelar.png", "call": restore_night.bind(n)})
	choices.append({"id": "back", "label": Text.t("MENU_BACK"), "sticker": "volver.png", "call": show_menu})
	host.hub.show_screen(night_name(n), choices, "challenge_night", "challenge", show_menu, 1 if challenge_delete else 0)


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


## Whether the map can be played: a mission once the story has opened it (or
## with the developer's mode on), a map of the player's always.
func mission_open(m: MapFile) -> bool:
	return not Missions.is_mission(m) or host.dev_mode or Missions.is_open(m)


## What a map's card says: a mission's own lines, or for a map of the
## player's that it is theirs and outside the story.
func map_card(m: MapFile) -> String:
	if Missions.is_mission(m):
		return Text.t("MISSION_KIND") + " · " + challenge_info(m) + "\n" + mission_info(m)
	return Text.t("CHALLENGE_BUILT_IN" if m.built_in else "CHALLENGE_MINE") + " · " + challenge_info(m)


## A mission's lines on its card: its story, the piece to steal, its gift, and
## whether it is done (then the gift is already the player's) — or, while the
## story has not opened it, which heist does.
func mission_info(m: MapFile) -> String:
	if not mission_open(m):
		return Text.t("MISSION_LOCKED") % Missions.opens_after(m)
	var done := Missions.is_done(m)
	var lines: Array[String] = []
	var caller := Missions.caller_of(m)
	if not caller.is_empty():
		lines.append(Text.t("MISSION_BY") % caller.name)
	if Missions.story_of(m) != "":
		lines.append(Missions.story_of(m))
	lines.append(Text.t("MISSION_STEAL") % Missions.piece_name(m))
	if Missions.has_gift(m):
		lines.append(Text.t("MISSION_GIFT_WON" if done else "MISSION_GIFT") % Missions.gift_of(m).name)
	lines.append(Text.t("MISSION_DONE" if done else "MISSION_TODO"))
	return "\n".join(lines)


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
	challenge_map = m
	challenge_at = "map:" + m.path
	var info := map_card(m)
	var choices: Array = [{"id": "preview", "label": m.name, "picture": MapEditor.picture(m, 8), "description": info}]
	# A mission the story has not opened yet: to look at, not to play or edit.
	if not mission_open(m):
		choices.append({"id": "back", "label": Text.t("MENU_BACK"), "sticker": "volver.png", "call": show_menu})
		host.hub.show_screen(m.name.to_upper(), choices, "challenge_map", "challenge", show_menu, 1)
		return
	if m.check().is_empty():
		for n in range(1, 5):
			choices.append({"id": "p%d" % n, "label": Text.t("MENU_PLAY_%d" % n), "res": "res://assets/ui/ninjas_%d.png" % n, "description": info, "call": host._start.bind("challenge", n)})
	# A mission is the game's, as written: only the developer's mode edits it.
	if not Missions.is_mission(m) or host.dev_mode:
		choices.append({"id": "edit", "label": Text.t("CHALLENGE_EDIT"), "sticker": "editar-mapas.png", "description": info, "call": show_editor.bind(m)})
	var selected := 1
	if not m.built_in:
		if challenge_delete:
			selected = choices.size()
		choices.append({"id": "delete", "label": Text.t("CHALLENGE_DELETE_SURE" if challenge_delete else "CHALLENGE_DELETE"), "sticker": "cancelar.png", "call": delete_map.bind(m)})
	choices.append({"id": "back", "label": Text.t("MENU_BACK"), "sticker": "volver.png", "call": show_menu})
	host.hub.show_screen(m.name.to_upper(), choices, "challenge_map", "challenge", show_menu, selected)


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
