class_name MapEditor
extends CanvasLayer

## The map editor, for the challenges: the plan seen from above, tile by
## tile, to draw a museum on — or to roll one from the generator and touch it
## up — and save it (MapFile).
##
## The plan (or the museum in 3D) fills the screen: the left button draws
## with the tool in hand, the right one rubs out (what stands on a tile
## first, then the tile, back to floor). Along the bottom, as in a building
## game: a compact block at the left, what to do (play it, undo, save,
## leave, the options) over the four kinds of tool
## (wall and floor, the characters, the objects, the rooms); and the rest of the
## bar the catalogue of the kind in hand — the objects with tabs to show one
## theme or all, one type of piece or all; the options, the building's size
## and look, rolling a museum or clearing it, the difficulty. Saving asks
## for the map's name, what is stolen and its tale. Over the plan, the name
## and what still stops it
## being played, and in the top right corner the switch between the plan
## and the museum in 3D.
##
## Keyboard: Tab (or the arrows off the edge) between the plan and the
## buttons; on the plan the arrows move a cursor, Space draws, Delete rubs
## out. R turns a room round, Ctrl+Z undoes, Esc leaves (asking first, if
## there are changes not saved).
##
## Pad, made to need nothing else (PAD_*): the cross or the left stick move
## the cursor (held, it runs on); A puts down what is in hand and X rubs out
## — held while moving, they go on painting or rubbing; B undoes; Y takes up
## whatever stands on the tile (or turns a room); LB/RB the thing before or
## after in the catalogue, LT/RT the kind of tool; Start over to the buttons
## (and back), View between the plan and the 3D, where the right stick turns
## the camera round.

signal closed
## Play it now, as it is.
signal play(map: MapFile)
## Build it in 3D behind the editor: Main answers with start_preview().
signal preview(map: MapFile)
## "nav", "ok", "back", as the menus make.
signal ui_sound(kind: String)

## The kinds of tool: the three big ones left to right, and the options (a
## small button up with what to do). "construir" is wall/floor, the
## characters and the rooms together, one catalogue after another.
const KINDS := ["construir", "objects", "options"]
## The kinds LT/RT go round (the options have no tool to hold).
const PAD_KINDS := ["construir", "objects"]
## A direction held on the pad: the first step at once, the next after this
## long (s), then one every PAD_REPEAT.
const PAD_DELAY := 0.24
const PAD_REPEAT := 0.07
## How far the stick or a trigger goes before it counts.
const PAD_DEAD := 0.5
## The bottom bar's height.
const BAR := 168
## The guard sidebar's width, docked at the right.
const GUARD_SIDEBAR_WIDTH := 300
## Colours a piece to steal can be.
const LOOT_COLOURS := ["#f0c46a", "#f4f1e6", "#ff6b6b", "#ffd43b", "#7bc043", "#4dabf7", "#9b5de5", "#f783ac", "#e8590c", "#8b5a2b"]
const LOOT_SECONDS := [1.5, 2.0, 3.0, 4.0, 5.0, 6.0]
## The characters: the door in, the case with the piece to steal, the way
## out, the guards, and a door in a wall (like the house's, MapFile.doors:
## opens and shuts on the night, not to be confused with `exit`, the way
## out). In this order in the "construir" row (wall, then these, "rooms"
## stepped in after "door" — see _fill_catalogue). No manual column (that
## stayed MuseumView's own, by theme — Themes.column_style) nor a random
## case (Themes.catalogue's own "case", kept for the objects tab only): the
## editor's tools for them were dropped, at the word of whoever plays it.
const MAIN_TOOLS := ["door", "spawn", "exit", "piece", "guard"]
const TOOL_ICONS := {"spawn": "flag", "piece": "piece", "exit": "exit_door", "guard": "guard", "door": "door"}
## Ready-made rooms, as MapFile.stamp takes them: '#' wall, '.' floor, 'o'
## case, 'D' dinosaur, 'S' sarcophagus, 'O' bear, 'b' a bust. The gaps in the border
## are doors. gallery: its inside is a room with a light and a name.
const TEMPLATES := [
	{"key": "EDITOR_T_EMPTY", "gallery": true, "rows": [
		"####.####",
		"#.......#",
		"#.......#",
		".........",
		"#.......#",
		"#.......#",
		"####.####"]},
	{"key": "EDITOR_T_CASES", "gallery": true, "rows": [
		"####.####",
		"#o.o.o.o#",
		"#.......#",
		".........",
		"#.......#",
		"#o.o.o.o#",
		"####.####"]},
	{"key": "EDITOR_T_BUSTS", "gallery": true, "rows": [
		"####.####",
		"#.b...b.#",
		"#.......#",
		"....o....",
		"#.......#",
		"#.b...b.#",
		"####.####"]},
	{"key": "EDITOR_T_COLUMNS", "gallery": true, "rows": [
		"#####.#####",
		"#.........#",
		"#.#..#..#.#",
		"#.........#",
		".....o.....",
		"#.........#",
		"#.#..#..#.#",
		"#.........#",
		"#####.#####"]},
	{"key": "EDITOR_T_SHELVES", "gallery": true, "rows": [
		"####.####",
		"#.......#",
		"#.#.#.#.#",
		".o#.#.#o.",
		"#.#.#.#.#",
		"#.......#",
		"####.####"]},
	{"key": "EDITOR_TOOL_BIG_DINOSAUR", "gallery": true, "rows": [
		"#####.#####",
		"#.........#",
		"#....DD...#",
		"#o...DD..o#",
		".....DD....",
		"#.........#",
		"#o.......o#",
		"#.........#",
		"#####.#####"]},
	{"key": "EDITOR_TOOL_BIG_SARCOPHAGUS", "gallery": true, "rows": [
		"####.####",
		"#.......#",
		"#o.SSS.o#",
		".........",
		"#.......#",
		"#o.....o#",
		"####.####"]},
	{"key": "EDITOR_T_CORRIDOR", "gallery": false, "rows": [
		"#########",
		".........",
		"#########"]},
]
const SIZES := ["small", "medium", "large"]
const DIFFICULTIES := ["easy", "medium", "hard"]
## Their names on screen, as the generative menu has them.
const SIZE_NAMES := {"small": "MENU_SIZE_SMALL", "medium": "MENU_SIZE_MEDIUM", "large": "MENU_SIZE_LARGE"}
const DIFFICULTY_NAMES := {"easy": "MENU_DIFFICULTY_EASY", "medium": "MENU_DIFFICULTY_MEDIUM", "hard": "MENU_DIFFICULTY_HARD"}
## The options, a page each: a list down the left of the catalogue, and the
## page's choices to its right.
## (The guards are placed with the characters: how many there are is theirs.)
## (What is stolen, and its tale, are written when saving: _save_panel.)
## (A new map, one from the generator, or one from disk: buttons of their
## own at the bottom now, not a page here — _new_button/_random/_import_map.)
const OPTION_PAGES := ["size", "floor", "wall", "difficulty"]
const OPTION_ICONS := {"size": "size", "floor": "rooms", "wall": "wall", "difficulty": "difficulty"}
const PROP_ORDER := ["bust", "bin", "panel", "armour"]
## The objects tab's theme filter, along the top, in this order: all of
## them, "comunes" (Themes.catalogue's pieces with no theme of their own),
## then the five themes (Themes.ALL's own order does not match the one
## asked for here).
const THEME_FILTER_ORDER := ["", "comunes", "prehistoria", "antiguo", "edad_media", "naturaleza", "moderna"]
## The objects tab's type filter, down the left: fewer, broader groups than
## Themes.TYPES itself (which other code still depends on as it is) —
## "expositores" folds vitrina and pequeño together, "especiales" tirable
## and escondite.
const TYPE_FILTER_GROUPS := {"": [], "cases": ["case", "small"], "big": ["big"], "special": ["prop", "hide"]}
const TYPE_FILTER_ORDER := ["", "cases", "big", "special"]
const TYPE_FILTER_LABELS := {"": "EDITOR_TYPEGROUP_ALL", "cases": "EDITOR_TYPEGROUP_CASES", "big": "EDITOR_TYPEGROUP_BIG", "special": "EDITOR_TYPEGROUP_SPECIAL"}
const UNDO_STEPS := 60

## The plan's colours: the paper map's (Hud), so the editor and the map you
## take out mid-job look like the same drawing.
const INK := Color("#1c1210")
const OUTSIDE := Color("#140d18")
const THIEF := Color("#2ec4a6")
const GUARD := Color("#c42a3c")
const EXIT := Color("#4ade80")
const PIECE := Color("#ffe066")
const PROP := Color("#ff8c2e")
const ROOM := Color("#d8ac5c")
const DOOR := Color("#4dabf7")
const COLUMN := Color("#c9a869")

## Controladores sin nodos: comparten el mapa y los controles de este editor.
var widgets := EditorWidgets.new(self)
var guard_panel := EditorGuardPanel.new(self)
var view_3d := EditorPreview3D.new(self)
var pad_navigation := EditorPadNavigation.new(self)

var map: MapFile
var tool := "wall"
## the toolbar button lit (KINDS), and the one whose panel is open ("" none,
## "leave" for the unsaved changes)
var kind := "construir"
## "construir"'s own row ("") or its "salas" step-in (TEMPLATES and the
## room tool), like guard_page/save_page but for a catalogue, not a panel.
var building_page := ""
var panel := ""
## wall/floor: what a drag paints, set by the first tile it starts on
var paint := Tiles.WALL
## the ready-made room in hand (TEMPLATES index), or -1
var template := -1
## quarter turns of the room in hand
var turns := 0
## the tile under the mouse or the keyboard's cursor, and the button held
var hover := MapFile.NONE
var held := 0
## first corner of a room being marked out (tool "room")
var room_from := MapFile.NONE
## The guard whose panel is open ("guard" in _open()), or null.
var selected_guard: GuardSpawn
var undo: Array[MapFile] = []
## What _undo() has popped, to put back with _redo() — cleared the moment a
## new change is remembered (_remember()), as usual.
var redo: Array[MapFile] = []
var dirty := false
## Esc once with changes unsaved: a second one leaves
var leaving := false

var _ui: Control
var _plan: Control
## the map's name at the top (written in the save panel)
var _name: Label
var _status: Label
var _hint: Label
var _tool_buttons := {}
var _template_buttons: Array[Button] = []
var _kind_buttons := {}
var _exit_button: Button
var _save_button: Button
var _new_button: Button
var _kind_name: Label
## the catalogue along the bottom: its tabs (the objects' themes) and its row
var _tabs: HBoxContainer
var _catalogue: HBoxContainer
## the theme the objects are shown for ("" all, "comunes" no theme of its
## own — TYPE_FILTER_GROUPS has the type's own grouping)
var filter := ""
var filter_type := ""
## the panel of choices over the bar (the options, or leaving unsaved)
var _flyout: PanelContainer
var _flyout_scroll: ScrollContainer
var _sub_title: Label
var _sub: VBoxContainer
## A guard's own panel: docked at the right, not floating over the bar —
## it wants more room, and can stay open while the plan is worked on.
var _guard_sidebar: PanelContainer
var _guard_title: Label
var _guard_remove: Button
var _guard_tabs: HBoxContainer
var _guard_sub: VBoxContainer
## the options' page open (OPTION_PAGES)
var option_page := "size"
## the 3D view: its bar, the camera flying round, and how it is held
var _back: ColorRect
var _view_button: Button
## editing on the museum in 3D, not the plan
var in_3d := false
## the map as the 3D museum was last built, to see what a change touched
var _built: MapFile
## in 3D: the tile under the mouse, the marks of a stroke not yet built,
## the right button's drag (it turns the camera; a click without one erases)
var _hover_mark: MeshInstance3D
var _marks: Node3D
var _right_from := Vector2.INF
var _span_set := false
var _cam: Camera3D
var _cam_light: DirectionalLight3D
var _was_current: Camera3D
var _yaw := 0.6
var _pitch := 0.9
var _span := 30.0
## The pad: in use (the help shows its buttons), the direction held and the
## time to its next step, A or X held down (1 puts, 2 rubs out) and whether
## that stroke changed anything to build, the triggers past half way.
var _pad := false
var _pad_dir := Vector2i.ZERO
var _pad_wait := 0.0
var _pad_stroke := 0
var _pad_marked := false
var _pad_triggers := [false, false]
var _cat_scroll: ScrollContainer
var _play_button: Button


func _ready() -> void:
	layer = 5
	_build()
	# For looking at it: `-- --menu=editor --editor=objects` (or main, rooms,
	# options) opens on that straight away.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--editor="):
			var what := arg.substr(9)
			(func() -> void:
				await get_tree().process_frame
				if what in KINDS:
					_pick_kind(what)
				elif what == "save":
					if "--editor-loot" in OS.get_cmdline_user_args():
						map.loot = {"shape": "crown", "colour": LOOT_COLOURS[0], "name": "", "blurb": "", "story": "", "seconds": 3.0}
					# --editor-save=loot (or story): that page of it.
					for a in OS.get_cmdline_user_args():
						if a.begins_with("--editor-save=") and a.substr(14) in SAVE_PAGES:
							save_page = a.substr(14)
					_open("save")
				elif what in OPTION_PAGES:
					# With a piece chosen, to see its page whole.
					if "--editor-loot" in OS.get_cmdline_user_args():
						map.loot = {"shape": "crown", "colour": LOOT_COLOURS[0], "name": "", "blurb": "", "story": "", "seconds": 3.0}
					_pick_kind("options")
					_open_page(what)).call()


## Start on a map (a copy of it: nothing changes until it is saved).
func open(m: MapFile) -> void:
	map = m.copy()
	if map.name == "":
		map.name = Text.t("EDITOR_UNTITLED")
	_name.text = map.name
	undo.clear()
	dirty = false
	_refresh()
	_plan.grab_focus()


# --- Building the screen ---------------------------------------------------------

func _build() -> void:
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_ui)
	var back := ColorRect.new()
	_back = back
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = Hud.BACKDROP_SHADER
	back.material = ShaderMaterial.new()
	(back.material as ShaderMaterial).shader = shader
	_ui.add_child(back)

	# The plan, the whole screen between the name and the bar.
	_plan = Control.new()
	_plan.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plan.offset_left = 16
	_plan.offset_right = -16
	_plan.offset_top = 86
	_plan.offset_bottom = -BAR - 12
	_plan.focus_mode = Control.FOCUS_ALL
	_plan.clip_contents = true
	_plan.draw.connect(_draw_plan)
	_plan.gui_input.connect(_plan_input)
	_plan.mouse_exited.connect(func() -> void:
		if not _plan.has_focus():
			hover = MapFile.NONE
		_plan.queue_redraw())
	_plan.focus_entered.connect(func() -> void:
		if hover == MapFile.NONE:
			hover = map.spawn
		_plan.queue_redraw())
	_plan.focus_exited.connect(_plan.queue_redraw)
	_ui.add_child(_plan)

	# Over it: the title, the name, and what is wrong or what the tool does.
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 12
	top.add_theme_constant_override("separation", 4)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(top)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	top.add_child(line)
	var title := _label(Text.t("EDITOR_TITLE"), 16, Hud.BRASS, line, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name = _label("", 16, Hud.CREAM, line)
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name.custom_minimum_size = Vector2(220, 0)

	_status = _label("", 14, Hud.C.alert, line)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Leaving the editor: left of the 2D/3D switch, up here where it is seen
	# (not lost among undo/save at the bottom any more).
	_exit_button = _button("", _leave, line, Hud.C.alert, false, "exit")
	_exit_button.custom_minimum_size = Vector2(52, 40)
	_exit_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_exit_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_button.add_theme_constant_override("icon_max_width", 26)
	_exit_button.tooltip_text = Text.t("EDITOR_EXIT")
	# The plan or the museum in 3D: the switch in the top right corner.
	_view_button = _button("", _toggle_3d, line, Hud.C.safe, false, "view3d")
	_view_button.custom_minimum_size = Vector2(52, 40)
	_view_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_view_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_view_button.add_theme_constant_override("icon_max_width", 26)
	_view_button.tooltip_text = Text.t("EDITOR_PREVIEW")
	# Play, right beside it: the way to try the map for real (_ask_play).
	_play_button = _button("", _ask_play, line, Hud.C.green, false, "play")
	_play_button.custom_minimum_size = Vector2(52, 40)
	_play_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_play_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_button.add_theme_constant_override("icon_max_width", 26)
	_play_button.tooltip_text = Text.t("EDITOR_PLAY")
	_hint = _label("", 13, Hud.C.dim, top)
	for l in [_status, _hint]:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(300, 0)
		l.max_lines_visible = 2

	# The bar along the bottom.
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -BAR
	var bst := StyleBoxFlat.new()
	bst.bg_color = Hud.GLASS
	bst.border_color = Hud.GLASS_EDGE
	bst.border_width_top = 3
	bst.set_content_margin_all(10)
	bar.add_theme_stylebox_override("panel", bst)
	_ui.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	bar.add_child(row)

	# Left: what to do, over the kinds of tool.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)
	# Nuevo, mapa aleatorio, importar, guardar, deshacer, rehacer: small icon
	# buttons, in the order the hand reaches for them.
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	left.add_child(acts)
	_new_button = _icon_button("new", "EDITOR_NEW", _open.bind("new"), acts, Hud.C.dim)
	_icon_button("random", "EDITOR_RANDOM", _random, acts, Hud.C.dim)
	_icon_button("import", "EDITOR_IMPORT", _import_map, acts, Hud.C.dim)
	_save_button = _icon_button("save", "EDITOR_SAVE", _open.bind("save"), acts, Hud.C.green)
	_icon_button("undo", "EDITOR_UNDO", _undo, acts, Hud.C.dim)
	_icon_button("redo", "EDITOR_REDO", _redo, acts, Hud.C.dim)
	# The three big kinds of tool, side by side, "opciones" the same size as
	# the rest — not a small one off on its own.
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 6)
	left.add_child(kinds)
	for k in KINDS:
		var b := _button(Text.t("EDITOR_KIND_" + k.to_upper()), _pick_kind.bind(k), kinds, Hud.C.safe, false, k)
		b.custom_minimum_size = Vector2(56, 56)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 36)
		b.tooltip_text = Text.t("EDITOR_KIND_" + k.to_upper())
		b.text = ""
		_kind_buttons[k] = b
	# The name of the kind in hand, under its icons.
	_kind_name = _label("", 8, Hud.BRASS, left, true)

	row.add_child(VSeparator.new())

	# Middle: the catalogue of the kind in hand.
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 6)
	row.add_child(mid)
	# The themes' tabs scroll too, rather than widen the bar.
	var tab_scroll := ScrollContainer.new()
	tab_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tab_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tab_scroll.custom_minimum_size = Vector2(0, 28)
	tab_scroll.follow_focus = true
	mid.add_child(tab_scroll)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 4)
	tab_scroll.add_child(_tabs)
	_tabs.visibility_changed.connect(func() -> void: tab_scroll.visible = _tabs.visible)
	var scroll := ScrollContainer.new()
	_cat_scroll = scroll
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	mid.add_child(scroll)
	_catalogue = HBoxContainer.new()
	_catalogue.add_theme_constant_override("separation", 6)
	scroll.add_child(_catalogue)
	# The wheel runs along the row.
	scroll.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			scroll.scroll_horizontal += 80 * (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)
			scroll.accept_event())


	# The panel of choices, floating over the bar.
	_flyout = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Hud.GLASS
	st.border_color = Hud.GLASS_EDGE
	st.set_border_width_all(2)
	st.set_corner_radius_all(14)
	st.set_content_margin_all(12)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 10
	_flyout.add_theme_stylebox_override("panel", st)
	_flyout.visible = false
	_ui.add_child(_flyout)
	_flyout_scroll = ScrollContainer.new()
	_flyout_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_flyout_scroll.follow_focus = true
	_flyout.add_child(_flyout_scroll)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 6)
	inside.custom_minimum_size = Vector2(330, 0)
	_flyout_scroll.add_child(inside)
	_sub_title = _label("", 10, Hud.C.dim, inside, true)
	_sub = VBoxContainer.new()
	_sub.add_theme_constant_override("separation", 6)
	inside.add_child(_sub)

	# A guard's own panel: docked at the right, the same height as the
	# plan, not floating over the bar (it has more to show, and stays put
	# while you click around placing others).
	_guard_sidebar = PanelContainer.new()
	var gst := StyleBoxFlat.new()
	gst.bg_color = Hud.GLASS
	gst.border_color = Hud.GLASS_EDGE
	gst.set_border_width_all(2)
	gst.set_corner_radius_all(14)
	gst.set_content_margin_all(12)
	gst.shadow_color = Color(0, 0, 0, 0.5)
	gst.shadow_size = 10
	_guard_sidebar.add_theme_stylebox_override("panel", gst)
	_guard_sidebar.visible = false
	_guard_sidebar.anchor_left = 1.0
	_guard_sidebar.anchor_right = 1.0
	_guard_sidebar.anchor_top = 0.0
	_guard_sidebar.anchor_bottom = 1.0
	_guard_sidebar.offset_left = -GUARD_SIDEBAR_WIDTH - 16.0
	_guard_sidebar.offset_right = -16.0
	_guard_sidebar.offset_top = 86.0
	_guard_sidebar.offset_bottom = -BAR - 12.0
	_ui.add_child(_guard_sidebar)
	var guard_scroll := ScrollContainer.new()
	guard_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	guard_scroll.follow_focus = true
	_guard_sidebar.add_child(guard_scroll)
	var guard_inside := VBoxContainer.new()
	guard_inside.add_theme_constant_override("separation", 6)
	guard_inside.custom_minimum_size = Vector2(GUARD_SIDEBAR_WIDTH, 0)
	guard_scroll.add_child(guard_inside)
	# Above the tabs, once: the panel's name, and the way to remove the
	# guard — always in reach, whichever tab is open.
	var guard_head := HBoxContainer.new()
	guard_head.add_theme_constant_override("separation", 6)
	guard_inside.add_child(guard_head)
	_guard_title = _label("", 10, Hud.C.dim, guard_head, true)
	_guard_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_guard_remove = _icon_button("clear", "EDITOR_GUARD_REMOVE", _remove_selected_guard, guard_head, Hud.C.alert)
	_guard_tabs = HBoxContainer.new()
	_guard_tabs.add_theme_constant_override("separation", 6)
	guard_inside.add_child(_guard_tabs)
	_guard_sub = VBoxContainer.new()
	_guard_sub.add_theme_constant_override("separation", 6)
	guard_inside.add_child(_guard_sub)

	_pick_kind("construir")
func _icon_button(icon: String, key: String, call: Callable, parent: Node, colour: Color) -> Button:
	return widgets.icon_button(icon, key, call, parent, colour)


func _setting_button(call: Callable, parent: Node, icon: Variant) -> Button:
	return widgets.setting_button(call, parent, icon)


func _label(text: String, size: int, colour: Color, parent: Node, arcade := false) -> Label:
	return widgets.label(text, size, colour, parent, arcade)


func _button(text: String, call: Callable, parent: Node, colour: Color, big := false, icon: Variant = null) -> Button:
	return widgets.button(text, call, parent, colour, big, icon)


func _look(b: Button, selected: bool) -> void:
	widgets.look(b, selected)


func _template_picture(i: int) -> ImageTexture:
	return widgets.template_picture(i)


func _swatch(part: String, which := -2) -> ImageTexture:
	return widgets.swatch(part, which)


func _level_bars_texture(level: int) -> ImageTexture:
	return widgets.level_bars_texture(level)


func _dir_arrow_texture(angle: float) -> ImageTexture:
	return widgets.dir_arrow_texture(angle)


func _in_arrow_shape(lx: float, ly: float, c: float) -> bool:
	return widgets.in_arrow_shape(lx, ly, c)


func _tool_colour(t: String) -> Color:
	return widgets.tool_colour(t)




# --- Tools and settings ------------------------------------------------------------

## A kind of tool: its catalogue along the bottom. "construir" opens
## straight into the wall/floor brush, the one used most.
func _pick_kind(k: String) -> void:
	kind = k
	if k == "construir":
		_pick_tool("wall")
	_fill_catalogue()
	_refresh()


## The catalogue for the kind in hand; for the objects, a tab per theme.
func _fill_catalogue() -> void:
	for box in [_tabs, _catalogue]:
		for c in box.get_children():
			box.remove_child(c)
			c.queue_free()
	_tool_buttons.clear()
	_template_buttons.clear()
	_tabs.visible = kind == "objects"
	match kind:
		"construir":
			if building_page == "rooms":
				# Its own row: the ready-made rooms (TEMPLATES), the turn
				# they go down with, and the plain room tool — a step below
				# the main row, reached through "salas" there.
				_icon_button("undo", "EDITOR_BACK", _pick_building_page.bind(""), _catalogue, Hud.C.dim)
				_catalogue.add_child(VSeparator.new())
				for i in TEMPLATES.size():
					_template_buttons.append(_item(_template_picture(i), Text.t(TEMPLATES[i].key), _choose_template.bind(i), Hud.C.gold))
				_item("turn", Text.t("EDITOR_TURN"), _turn, Hud.C.dim)
				_tool_buttons["room"] = _item("room", Text.t("EDITOR_TOOL_ROOM"), _choose_tool.bind("construir", "room"), ROOM)
			else:
				# One after another, no separators: wall, the door, salas
				# (stepping into its own row), entrada, salida, robo, guardia.
				_tool_buttons["wall"] = _item("wall", Text.t("EDITOR_TOOL_WALL"), _choose_tool.bind("construir", "wall"), Hud.C.safe)
				_tool_buttons["door"] = _item(TOOL_ICONS["door"], Text.t("EDITOR_TOOL_DOOR"), _choose_tool.bind("construir", "door"), _tool_colour("door"))
				_item("rooms", Text.t("EDITOR_TOOL_ROOMS"), _pick_building_page.bind("rooms"), ROOM)
				for t in ["spawn", "exit", "piece", "guard"]:
					_tool_buttons[t] = _item(TOOL_ICONS[t], Text.t("EDITOR_TOOL_" + t.to_upper()), _choose_tool.bind("construir", t), _tool_colour(t))
		"objects":
			# The theme, along the top, with words (not just icons): all of
			# them, "comunes" (no theme of its own), then the five themes in
			# THEME_FILTER_ORDER.
			for id in THEME_FILTER_ORDER:
				var label := Text.t("EDITOR_FILTER_ALL") if id == "" else (Text.t("EDITOR_FILTER_COMMON") if id == "comunes" else Text.t("THEME_" + id.to_upper()))
				var tab := _button(label, _pick_filter.bind(id), _tabs, Hud.C.gold)
				tab.custom_minimum_size = Vector2(0, 26)
				tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				tab.autowrap_mode = TextServer.AUTOWRAP_OFF
				tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
				tab.add_theme_font_size_override("font_size", 8)
				tab.set_meta("filter", id)
			# Down the left of the row, a column by type instead (same width
			# each): expositores (vitrina + pequeño), grandes, especiales
			# (tirable + escondite).
			var type_col := _column(96)
			for cat in TYPE_FILTER_ORDER:
				var tab := _button(Text.t(TYPE_FILTER_LABELS[cat]), _pick_type.bind(cat), type_col, Hud.C.safe)
				tab.custom_minimum_size = Vector2(96, 32)
				tab.autowrap_mode = TextServer.AUTOWRAP_OFF
				tab.add_theme_font_size_override("font_size", 8)
				tab.set_meta("type", cat)
			_catalogue.add_child(VSeparator.new())
			for entry in Themes.catalogue():
				var t: String = entry[0]
				# The random case is its own tool up in "construir" (not any
				# more — see MAIN_TOOLS' note), so it stays out of the
				# objects tab either way: there is nothing to preview for it.
				if t == "case":
					continue
				var themes: Array = entry[1]
				# "Comunes": no theme calls it its own (an empty list in
				# Themes.catalogue — the bare pedestal, the bin, the panel,
				# a big piece no theme picked).
				if filter == "comunes":
					if not themes.is_empty():
						continue
				elif filter != "" and not themes.has(filter):
					continue
				if filter_type != "" and not (entry[2] in TYPE_FILTER_GROUPS[filter_type]):
					continue
				var id := t.replace(":", "_").replace("/", "_")
				var name := Themes.label(t.substr(8)) if t.begins_with("exhibit:") else Text.t("EDITOR_TOOL_" + id.to_upper())
				var b := _item(load("res://assets/icons/objects/%s.png" % id), name, _choose_tool.bind("objects", t), _tool_colour(t))
				_tool_buttons[t] = b
				# A badge, bottom left: tirable or escondite, so the two
				# read apart from the rest at a glance.
				if entry[2] == "prop":
					_badge(b, "type_prop")
				elif entry[2] == "hide":
					_badge(b, "type_hide")
		"options":
			_options()


## One thing in the catalogue: its picture, its name under it.
func _item(icon: Variant, name: String, call: Callable, colour: Color) -> Button:
	var b := _button(name, call, _catalogue, colour, false, icon)
	b.custom_minimum_size = Vector2(92, 100)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 62)
	b.add_theme_font_size_override("font_size", 7)
	b.tooltip_text = name
	return b


## A little icon in a card's bottom left corner (an _item's), over its own
## picture: tirable or escondite, marked apart from the rest of "especiales".
func _badge(b: Button, icon: String) -> void:
	var t := TextureRect.new()
	t.texture = load("res://assets/icons/editor/%s.svg" % icon)
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	t.offset_left = 4
	t.offset_top = -20
	t.offset_right = 20
	t.offset_bottom = -4
	b.add_child(t)


func _pick_filter(id: String) -> void:
	filter = id
	_fill_catalogue()
	_refresh()


func _pick_type(type: String) -> void:
	filter_type = type
	_fill_catalogue()
	_refresh()


## Step into "construir"'s own "salas" row, or back out of it ("").
func _pick_building_page(page: String) -> void:
	building_page = page
	_fill_catalogue()
	_refresh()


## The options: the pages down the left, and the one open to their right,
## its choices as cards, the one in force lit.
func _options() -> void:
	var list := GridContainer.new()
	list.columns = 2
	list.add_theme_constant_override("h_separation", 4)
	list.add_theme_constant_override("v_separation", 4)
	_catalogue.add_child(list)
	for page in OPTION_PAGES:
		var b := _button(Text.t("EDITOR_PAGE_" + page.to_upper()), _open_page.bind(page), list, Hud.C.gold, false, OPTION_ICONS[page])
		b.custom_minimum_size = Vector2(150, 30)
		b.add_theme_constant_override("icon_max_width", 16)
		b.add_theme_font_size_override("font_size", 8)
		b.set_meta("page", page)
	_catalogue.add_child(VSeparator.new())
	match option_page:
		"size":
			for k in SIZES:
				var dims: Dictionary = Museum.SIZES[k]
				_choice(Text.t(SIZE_NAMES[k]) + "\n%d×%d" % [dims.w, dims.h], "size", _set_size.bind(k), k, "size")
		"floor", "wall":
			_choice(Text.t("EDITOR_LOOK_AUTO"), option_page, _set_look.bind(option_page, -1), -1, _swatch(option_page, -1))
			for i in MuseumView.looks().size():
				var key := ("EDITOR_LOOK_%d" if option_page == "floor" else "EDITOR_WALL_LOOK_%d") % i
				_choice(Text.t(key), option_page, _set_look.bind(option_page, i), i, _swatch(option_page, i))
		"difficulty":
			for k in DIFFICULTIES:
				_choice(Text.t(DIFFICULTY_NAMES[k]), "difficulty", _set_difficulty.bind(k), k, "difficulty")


## One card of an options page: in force, it is lit (meta "choice" against
## what the map has for `setting`).
func _choice(text: String, setting: String, call: Callable, value: Variant, icon: Variant) -> Button:
	var b := _item(icon, text, call, Hud.C.safe)
	b.custom_minimum_size = Vector2(110, 100)
	if setting != "":
		b.set_meta("setting", setting)
		b.set_meta("choice", value)
	return b


## What the map has for one of the options' settings, to light its card.
func _setting_value(setting: String) -> Variant:
	match setting:
		"size": return map.size_name()
		"floor": return map.floor_look
		"wall": return map.wall_look
		"difficulty": return map.difficulty
	return null


func _open_page(page: String) -> void:
	option_page = page
	_fill_catalogue()
	_refresh()


## A column in the catalogue.
func _column(width := 0.0, parent: Node = null) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(width, 0)
	(parent if parent else _catalogue).add_child(col)
	return col


## The panel over the plan: saving ("save": the name, what is stolen and
## its tale), or leaving with changes not saved ("leave"); "" shuts both it
## and the guard sidebar. "guard" opens the sidebar instead — it wants more
## room than the flyout gives, and stays docked while the plan is worked on.
func _open(k: String) -> void:
	panel = k
	leaving = k == "leave"
	for c in _sub.get_children():
		_sub.remove_child(c)
		c.queue_free()
	for c in _guard_tabs.get_children():
		_guard_tabs.remove_child(c)
		c.queue_free()
	for c in _guard_sub.get_children():
		_guard_sub.remove_child(c)
		c.queue_free()
	_flyout.visible = k != "" and k != "guard"
	_guard_sidebar.visible = k == "guard"
	if k == "":
		_refresh()
		return
	if k == "save":
		_save_panel()
	elif k == "guard":
		_guard_panel()
		_refresh()
		if _guard_sub.get_child_count() > 0:
			(_guard_sub.get_child(0) as Control).grab_focus.call_deferred()
		return
	elif k == "new":
		_sub_title.text = Text.t("EDITOR_NEW_CONFIRM")
		_button(Text.t("EDITOR_NEW_YES"), _confirm_new, _sub, Hud.C.alert)
		_button(Text.t("EDITOR_KEEP_EDITING"), _stay, _sub, Hud.C.dim)
	else:
		_sub_title.text = Text.t("EDITOR_UNSAVED")
		_button(Text.t("EDITOR_SAVE_AND_EXIT"), _save_and_leave, _sub, Hud.C.green)
		_button(Text.t("EDITOR_EXIT_NO_SAVE"), closed.emit, _sub, Hud.C.alert)
		_button(Text.t("EDITOR_KEEP_EDITING"), _stay, _sub, Hud.C.dim)
	_refresh()
	_place_flyout.call_deferred()
	# The first thing to press: on the save panel, the page's own tab.
	var first: Control = _sub.get_child(0) as Control
	for b in _sub.find_children("*", "Button", true, false):
		if not b.has_meta("save_page") or b.get_meta("save_page") == save_page:
			first = b
			break
	first.grab_focus.call_deferred()


## Saving, a page at a time (SAVE_PAGES, tabs along the top): the map's
## name; what is stolen (the piece and its colour in drop-downs, how long its
## case takes on a slider); its tale. Then save it, or go back to it.
const SAVE_PAGES := ["map", "loot", "story"]
var save_page := "map"


func _save_panel() -> void:
	_sub_title.text = Text.t("EDITOR_SAVE")
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_sub.add_child(tabs)
	for page in SAVE_PAGES:
		var b := _button(Text.t("EDITOR_SAVE_TAB_" + page.to_upper()), func() -> void:
			save_page = page
			_open("save"), tabs, Hud.C.gold)
		b.custom_minimum_size = Vector2(120, 34)
		b.set_meta("save_page", page)
	var body := _column(420, _sub)
	body.add_theme_constant_override("separation", 6)
	match save_page:
		"map":
			var name_edit := _field(Text.t("EDITOR_NAME").to_upper(), map.name, Text.t("EDITOR_UNTITLED"), body)
			name_edit.max_length = 32
			name_edit.text_changed.connect(func(t: String) -> void:
				map.name = t
				_name.text = t
				dirty = true)
		"loot":
			_loot_page(body)
		"story":
			_story_page(body)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	_sub.add_child(buttons)
	_button(Text.t("EDITOR_SAVE"), func() -> void:
		_save()
		_open(""), buttons, Hud.C.green, false, "save")
	_button(Text.t("EDITOR_KEEP_EDITING"), _stay, buttons, Hud.C.dim)


## What is stolen: the piece (AL AZAR leaves it to the game) and its colour,
## each in a drop-down, and how long its case takes, on a slider.
func _loot_page(parent: Node) -> void:
	_label(Text.t("EDITOR_LOOT_WHAT"), 8, Hud.BRASS, parent, true)
	var piece := _dropdown(parent)
	var shapes: Array = [""] + MapFile.LOOT_SHAPES
	for i in shapes.size():
		var shape: String = shapes[i]
		var label := Text.t("EDITOR_LOOT_RANDOM" if shape == "" else "EDITOR_SHAPE_" + shape.to_upper())
		if shape == "":
			piece.add_item(label, i)
		else:
			piece.add_icon_item(load("res://assets/icons/objects/loot_%s.png" % shape), label, i)
	piece.select(maxi(0, shapes.find(map.loot.get("shape", ""))))
	piece.item_selected.connect(func(i: int) -> void: _pick_loot(shapes[i]))
	if map.loot.is_empty():
		_nothing_chosen(parent)
		return
	_label(Text.t("EDITOR_LOOT_COLOUR"), 8, Hud.C.dim, parent, true)
	var colour := _dropdown(parent)
	for i in LOOT_COLOURS.size():
		var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
		img.fill(Color(LOOT_COLOURS[i]))
		colour.add_icon_item(ImageTexture.create_from_image(img), Text.t("EDITOR_COLOUR_%d" % i), i)
	colour.select(maxi(0, LOOT_COLOURS.find(map.loot.get("colour", ""))))
	colour.item_selected.connect(func(i: int) -> void:
		map.loot.colour = LOOT_COLOURS[i]
		dirty = true
		_refresh())
	_label(Text.t("EDITOR_LOOT_FORCE"), 8, Hud.C.dim, parent, true)
	_seconds_slider(parent)


## A drop-down in the panel's look: walnut, cream words, the icons small.
func _dropdown(parent: Node) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(260, 38)
	o.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	o.expand_icon = true
	o.add_theme_constant_override("icon_max_width", 24)
	o.add_theme_constant_override("h_separation", 10)
	o.add_theme_font_override("font", Hud.ARCADE)
	o.add_theme_font_size_override("font_size", 10)
	o.set_meta("colour", Hud.C.gold)
	# The pieces' pictures and the colours' swatches keep their own colours.
	o.set_meta("photo", true)
	_look(o, false)
	var popup := o.get_popup()
	popup.add_theme_constant_override("icon_max_width", 24)
	popup.add_theme_font_override("font", Hud.ARCADE)
	popup.add_theme_font_size_override("font_size", 10)
	o.focus_entered.connect(func() -> void: ui_sound.emit("nav"))
	o.item_selected.connect(func(_i: int) -> void: ui_sound.emit("ok"))
	o.mouse_entered.connect(o.grab_focus)
	parent.add_child(o)
	return o


## How long the case takes, as the sound settings show a volume: a bar of
## steps with the value, ‹ and › to go down and up (← and → too, with it in
## focus; a click on the bar goes up, round from the top back to the start).
func _seconds_slider(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var less := _button("‹", _step_seconds.bind(-1), row, Hud.C.safe)
	var bar := _button("", _step_seconds.bind(0), row, Hud.C.safe)
	var more := _button("›", _step_seconds.bind(1), row, Hud.C.safe)
	for b in [less, more]:
		b.custom_minimum_size = Vector2(38, 38)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.custom_minimum_size = Vector2(176, 38)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar.set_meta("seconds", true)
	bar.gui_input.connect(func(e: InputEvent) -> void:
		for pair in [["ui_left", -1], ["ui_right", 1]]:
			if e.is_action_pressed(pair[0], true):
				_step_seconds(pair[1])
				bar.accept_event())


## The slider's text: a mark per step up to the one in force, dots after.
func _seconds_bar() -> String:
	var i := maxi(0, LOOT_SECONDS.find(float(map.loot.get("seconds", 3.0))))
	return "%s%s %s S" % ["|".repeat(i + 1), "·".repeat(LOOT_SECONDS.size() - i - 1), str(LOOT_SECONDS[i])]


## The eight ways a guard can start looking, N first and round clockwise
## (screen down is +Y, so this matches atan2(dy, dx)).
const GUARD_DIRS := [PI * -0.5, PI * -0.25, 0.0, PI * 0.25, PI * 0.5, PI * 0.75, PI, PI * -0.75]
const GUARD_DIR_KEYS := ["N", "NE", "E", "SE", "S", "SO", "O", "NO"]


## The guard clicked in _press (or just placed): two tabs, like the save
## panel's (GUARD_PAGES/guard_page) — "capabilities" (archetype and the
## three sliders it seeds) and "position" (patrols or stands guard, what it
## watches while it does, and which way it looks at the start). Its name and
## the way to remove it sit above the tabs, built once in _build.
const GUARD_PAGES := ["capabilities", "position"]
var guard_page := "capabilities"
func _guard_panel() -> void:
	guard_panel.guard_panel()


func _guard_capabilities_page(g: GuardSpawn) -> void:
	guard_panel.guard_capabilities_page(g)


func _guard_position_page(g: GuardSpawn) -> void:
	guard_panel.guard_position_page(g)


func _level_row(stat: String, title_key: String) -> void:
	guard_panel.level_row(stat, title_key)


func _guard_description(g: GuardSpawn) -> String:
	return guard_panel.guard_description(g)


func _nearest_dir(dir: float) -> int:
	return guard_panel.nearest_dir(dir)


func _step_dir(step: int) -> void:
	guard_panel.step_dir(step)


func _remove_selected_guard() -> void:
	guard_panel.remove_selected_guard()


func _pick_archetype(key: String) -> void:
	guard_panel.pick_archetype(key)


func _step_level(stat: String, step: int) -> void:
	guard_panel.step_level(stat, step)


func _pick_stance(s: String) -> void:
	guard_panel.pick_stance(s)


func _pick_watch(w: String) -> void:
	guard_panel.pick_watch(w)




## Its tale: the piece's name, a line on it, and the story told before the
## job, one under the other. Without a piece chosen, the game tells its own.
func _story_page(parent: Node) -> void:
	if map.loot.is_empty():
		_nothing_chosen(parent)
		return
	var col := parent
	var name_edit := _field(Text.t("EDITOR_LOOT_NAME"), map.loot.name, Text.t("EDITOR_SHAPE_" + String(map.loot.shape).to_upper()).to_lower(), col)
	name_edit.text_changed.connect(func(t: String) -> void:
		map.loot.name = t
		dirty = true)
	var blurb := _field(Text.t("EDITOR_LOOT_BLURB"), map.loot.blurb, Text.t("EDITOR_LOOT_BLURB_HINT"), col)
	blurb.text_changed.connect(func(t: String) -> void:
		map.loot.blurb = t
		dirty = true)
	_label(Text.t("EDITOR_LOOT_STORY"), 8, Hud.C.dim, col, true)
	var story := TextEdit.new()
	story.text = map.loot.story
	story.placeholder_text = Text.t("EDITOR_LOOT_STORY_HINT")
	story.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	story.custom_minimum_size = Vector2(420, 120)
	story.add_theme_font_size_override("font_size", 13)
	story.text_changed.connect(func() -> void:
		map.loot.story = story.text
		dirty = true)
	col.add_child(story)


## No piece chosen: the game picks one, and its tale with it.
func _nothing_chosen(parent: Node) -> void:
	var none := _label(Text.t("EDITOR_LOOT_NONE"), 12, Hud.C.dim, _column(240, parent))
	none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## A labelled line of text in the panel.
func _field(title: String, text: String, hint: String, parent: Node) -> LineEdit:
	_label(title, 8, Hud.C.dim, parent, true)
	var e := LineEdit.new()
	e.text = text
	e.placeholder_text = hint
	e.max_length = 60
	e.add_theme_font_size_override("font_size", 13)
	parent.add_child(e)
	return e


## The piece to steal: a shape (its name, colour and tale kept if there was
## one), or "" to leave it to the game.
func _pick_loot(shape: String) -> void:
	_remember()
	if shape == "":
		map.loot = {}
	elif map.loot.is_empty():
		map.loot = {"shape": shape, "colour": LOOT_COLOURS[0], "name": "", "blurb": "", "story": "", "seconds": 3.0}
	else:
		map.loot.shape = shape
	# Its colour row, name and tale appear, or go.
	_open("save")


## One step down (-1) or up (1), stopping at the ends; 0 goes up, round
## from the top back to the start.
func _step_seconds(dir: int) -> void:
	var i := maxi(0, LOOT_SECONDS.find(float(map.loot.seconds)))
	if dir == 0:
		i = (i + 1) % LOOT_SECONDS.size()
	else:
		i = clampi(i + dir, 0, LOOT_SECONDS.size() - 1)
	map.loot.seconds = LOOT_SECONDS[i]
	dirty = true
	_refresh()


## Over the bar, above the button that opened it, as tall as fits. The
## "unsaved changes" warning ("leave") is not tied to a button on screen
## when it pops up unasked (closing the window, say), so that one goes
## in the middle instead.
func _place_flyout() -> void:
	if panel == "leave":
		_flyout.size = Vector2.ZERO
		var fs := _flyout.get_combined_minimum_size()
		_flyout.position = ((_ui.size - fs) * 0.5).round()
		return
	var from: Button = _save_button if panel == "save" else (_new_button if panel == "new" else _exit_button)
	if from == null:
		return
	var room := _ui.size.y - BAR - 30.0
	var want := minf(_flyout_scroll.get_child(0).get_combined_minimum_size().y + 4, room - 24)
	_flyout_scroll.custom_minimum_size = Vector2(0, want)
	_flyout.size = Vector2.ZERO
	var fs := _flyout.get_combined_minimum_size()
	var r := from.get_global_rect()
	var x := clampf(r.position.x, 10.0, _ui.size.x - fs.x - 10.0)
	_flyout.position = Vector2(x, _ui.size.y - BAR - fs.y - 10.0)


## A choice in the panel: in hand for the plan, and its toolbar button lit.
func _choose_tool(k: String, t: String) -> void:
	kind = k
	_pick_tool(t)


func _choose_template(i: int) -> void:
	kind = "construir"
	_pick_template(i)


func _pick_tool(t: String) -> void:
	tool = t
	template = -1
	room_from = MapFile.NONE
	_refresh()


func _pick_template(i: int) -> void:
	tool = "stamp"
	template = i
	_refresh()


func _turn() -> void:
	turns = (turns + 1) % 4
	_plan.queue_redraw()


## The room in hand as rows, turned as it is.
func _rows() -> Array:
	var rows: Array = TEMPLATES[template].rows
	for k in turns:
		var out: Array = []
		for x in String(rows[0]).length():
			var line := ""
			for y in range(rows.size() - 1, -1, -1):
				line += String(rows[y])[x]
			out.append(line)
		rows = out
	return rows


func _stamp_corner(at: Vector2i) -> Vector2i:
	var rows := _rows()
	return at - Vector2i(String(rows[0]).length() / 2, rows.size() / 2)


func _set_size(k: String) -> void:
	if k == map.size_name():
		return
	var dims: Dictionary = Museum.SIZES[k]
	_remember()
	map = map.resized(dims.w, dims.h)
	hover = MapFile.NONE
	_refresh()
	_rebuild()


## The floor's or the walls' look: -1 AUTO (the seed's), or one of the looks.
func _set_look(part: String, i: int) -> void:
	if part == "floor":
		map.floor_look = i
	else:
		map.wall_look = i
	dirty = true
	_refresh()
	_rebuild()


func _set_difficulty(k: String) -> void:
	map.difficulty = k
	dirty = true
	_refresh()


## Roll a museum from the generator, the size it is now, to start from.
func _random() -> void:
	_remember()
	var m := MapFile.generated(randi() % 1000000000, map.size_name())
	m.name = map.name
	m.difficulty = map.difficulty
	m.guard_count = map.guard_count
	m.floor_look = map.floor_look
	m.wall_look = map.wall_look
	m.path = map.path
	m.built_in = map.built_in
	map = m
	_say(Text.t("EDITOR_RANDOM_DONE"), Hud.C.gold)
	_refresh()
	_rebuild()


func _clear() -> void:
	_remember()
	var m := MapFile.blank(map.w, map.h)
	m.name = map.name
	m.difficulty = map.difficulty
	m.guard_count = map.guard_count
	m.floor_look = map.floor_look
	m.wall_look = map.wall_look
	m.path = map.path
	m.built_in = map.built_in
	map = m
	_refresh()
	_rebuild()


## "Nuevo", confirmed: a blank map the size this one is now (_clear), then
## back to the plan.
func _confirm_new() -> void:
	_clear()
	_open("")


## Load a map from the player's own disk (not the game's user:// folder):
## the system's own file picker, any .json in MapFile.to_dict's shape.
func _import_map() -> void:
	var dlg := FileDialog.new()
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.add_filter("*.json", "Mapa (JSON)")
	dlg.use_native_dialog = true
	dlg.title = Text.t("EDITOR_IMPORT")
	add_child(dlg)
	dlg.file_selected.connect(func(f: String) -> void:
		var m := MapFile.read(f)
		if m == null:
			_say(Text.t("EDITOR_IMPORT_FAILED"), Hud.C.alert)
		else:
			_remember()
			m.name = m.name if m.name != "" else Text.t("EDITOR_UNTITLED")
			# A map of its own, not the file it came from: saving it never
			# touches (or takes the place of) whatever is on disk there.
			m.path = ""
			m.built_in = false
			map = m
			_name.text = map.name
			_refresh()
			_rebuild()
			_say(Text.t("EDITOR_IMPORTED"), Hud.C.green)
		dlg.queue_free.call_deferred())
	dlg.canceled.connect(dlg.queue_free)
	dlg.close_requested.connect(dlg.queue_free)
	dlg.popup_centered_ratio(0.7)


func _remember() -> void:
	undo.append(map.copy())
	if undo.size() > UNDO_STEPS:
		undo.remove_at(0)
	# A new change: whatever _undo() had put aside for _redo() no longer
	# follows from where the map is now.
	redo.clear()
	dirty = true
	leaving = false


func _undo() -> void:
	if undo.is_empty():
		return
	redo.append(map.copy())
	if redo.size() > UNDO_STEPS:
		redo.remove_at(0)
	map = undo.pop_back()
	_name.text = map.name
	_refresh()
	_rebuild()


func _redo() -> void:
	if redo.is_empty():
		return
	undo.append(map.copy())
	if undo.size() > UNDO_STEPS:
		undo.remove_at(0)
	map = redo.pop_back()
	_name.text = map.name
	_refresh()
	_rebuild()


func _save() -> void:
	map.name = map.name.strip_edges()
	if map.name == "":
		map.name = Text.t("EDITOR_UNTITLED")
	_name.text = map.name
	if map.save() != OK:
		_say(Text.t("EDITOR_SAVE_FAILED"), Hud.C.alert)
		return
	dirty = false
	leaving = false
	var errors := map.check()
	_say(Text.t("EDITOR_SAVED") % map.name if errors.is_empty() else Text.t("EDITOR_SAVED_UNPLAYABLE") % map.name, Hud.C.green if errors.is_empty() else Hud.C.gold)


func _ask_play() -> void:
	if not map.check().is_empty():
		ui_sound.emit("back")
		_say(Text.t("EDITOR_CANNOT_PLAY"), Hud.C.alert)
		return
	play.emit(map.copy())


func _ask_preview() -> void:
	if not map.check().is_empty():
		ui_sound.emit("back")
		_say(Text.t("EDITOR_CANNOT_PLAY"), Hud.C.alert)
		return
	preview.emit(map.copy())


## Out, or, with changes not saved, the choice of what to do with them.
func _leave() -> void:
	if not dirty:
		closed.emit()
		return
	_open("leave")


func _stay() -> void:
	_open("")
	_plan.grab_focus()


func _save_and_leave() -> void:
	_save()
	if not dirty:
		closed.emit()


# --- Drawing on the plan -------------------------------------------------------------

## Pixels a tile, and where the plan's top left corner is.
func _cell() -> float:
	return floorf(minf(_plan.size.x / map.w, _plan.size.y / map.h))


func _origin() -> Vector2:
	var c := _cell()
	return ((_plan.size - Vector2(map.w, map.h) * c) / 2.0).floor()


func _tile_at(p: Vector2) -> Vector2i:
	var t := Vector2i(((p - _origin()) / _cell()).floor())
	return t if map.inside(t) else MapFile.NONE


func _plan_input(event: InputEvent) -> void:
	# The pad has its own way round the plan (and the 3D): all of it here,
	# so none of it moves the focus off the plan.
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_pad_on_plan(event)
		_plan.accept_event()
		return
	if in_3d:
		_input_3d(event)
		return
	if event is InputEventMouseMotion:
		var t := _tile_at(event.position)
		if t != hover:
			hover = t
			if held != 0 and t != MapFile.NONE and _paints():
				_use(t, held == MOUSE_BUTTON_RIGHT)
				_refresh()
			_plan.queue_redraw()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			_plan.grab_focus()
			var t := _tile_at(event.position)
			if t == MapFile.NONE:
				return
			held = event.button_index
			_press(t, held == MOUSE_BUTTON_RIGHT)
		else:
			held = 0
			if tool == "room" and room_from != MapFile.NONE and hover != MapFile.NONE and room_from != hover:
				_mark_room(hover)
		_plan.accept_event()
	elif event is InputEventKey:
		var move := Vector2i.ZERO
		for pair in [["ui_left", Vector2i(-1, 0)], ["ui_right", Vector2i(1, 0)], ["ui_up", Vector2i(0, -1)], ["ui_down", Vector2i(0, 1)]]:
			if event.is_action_pressed(pair[0], true):
				move = pair[1]
		if move != Vector2i.ZERO:
			var next := (hover if hover != MapFile.NONE else map.spawn) + move
			# Off the edge of the plan: over to the buttons.
			if not map.inside(next):
				return
			hover = next
			_plan.queue_redraw()
			_plan.accept_event()
		elif event.is_action_pressed("ui_accept") and hover != MapFile.NONE:
			if tool == "room" and room_from != MapFile.NONE:
				_mark_room(hover)
			else:
				_press(hover, false)
			_plan.accept_event()
		elif event.pressed and event.keycode in [KEY_DELETE, KEY_BACKSPACE]:
			if hover != MapFile.NONE:
				_press(hover, true)
			_plan.accept_event()


## Tools that draw as the mouse drags; the rest act once per press.
func _paints() -> bool:
	return tool in ["wall", "case"]


func _press(t: Vector2i, erase: bool) -> void:
	if not erase and tool == "guard":
		var here := map.guards.filter(func(g): return g.at == t)
		if not here.is_empty():
			selected_guard = here[0]
			_open("guard")
			return
	_remember()
	if not erase and tool == "room":
		room_from = t
	else:
		# Wall and floor: a click turns the one into the other, and a drag
		# goes on painting what that first click made.
		if tool == "wall":
			paint = Tiles.FLOOR if map.at(t) == Tiles.WALL else Tiles.WALL
		_use(t, erase)
	_refresh()


func _use(t: Vector2i, erase: bool) -> void:
	var edge := t.x == 0 or t.y == 0 or t.x == map.w - 1 or t.y == map.h - 1
	if erase:
		# What stands on it first, then the tile itself.
		if map.guards.any(func(g): return g.at == t):
			map.guards = map.guards.filter(func(g): return g.at != t)
			if selected_guard != null and selected_guard.at == t:
				selected_guard = null
				if panel == "guard":
					_open("")
		elif map.exhibits.has(t):
			map.exhibits.erase(t)
		elif map.props.any(func(p): return p.at == t):
			map.props = map.props.filter(func(p): return p.at != t)
		elif map.exit == t:
			map.exit = MapFile.NONE
		elif map.piece == t:
			map.piece = MapFile.NONE
		elif map.doors.has(t):
			map.doors.erase(t)
		elif tool == "room" and _room_at(t) >= 0:
			map.rooms.remove_at(_room_at(t))
		elif not edge:
			map.put(t, Tiles.FLOOR)
		elif map.at(t) != Tiles.WALL or map.is_out(t):
			map.put(t, Tiles.WALL)
		return
	match tool:
		"wall":
			# The plan's own edge stays wall: the building is shut.
			if not edge or paint == Tiles.WALL:
				map.put(t, paint)
		"case":
			if not map.blocks_door(t):
				map.put(t, Tiles.COVER)
		"spawn":
			if map.at(t) == Tiles.FLOOR:
				map.spawn = t
		"piece":
			if map.at(t) != Tiles.COVER:
				if map.blocks_door(t):
					return
				map.put(t, Tiles.COVER)
			if map.big_at(t).is_empty():
				map.piece = t
		"exit":
			# On the floor by the outer wall, or on the wall itself.
			if map.door_face(t) != Vector2i.ZERO:
				map.exit = t
			else:
				for d in MapFile.DIRS:
					if map.door_face(t + d) == -d:
						map.exit = t + d
		"guard":
			# An existing guard is picked up by _press (to edit it, not place
			# another): here there is never one already on t.
			if map.at(t) == Tiles.FLOOR and map.guards.size() < MapFile.MAX_GUARDS:
				var spawn := GuardSpawn.new()
				spawn.at = t
				map.guards.append(spawn)
				if map.guard_count > 0:
					map.guard_count = maxi(map.guard_count, map.guards.size())
				selected_guard = spawn
				_open("guard")
		"door":
			# On a wall, not the plan's own edge (the building stays shut):
			# a click marks or clears it, like a door between rooms at home.
			if map.doors.has(t):
				map.doors.erase(t)
			elif map.at(t) == Tiles.WALL and not edge and not map.columns.has(t) and map.door_fits(t) and map.door_clear(t):
				map.doors.append(t)
		_ when tool.begins_with("exhibit:"):
			# On floor or a case; the same piece again leaves the case plain.
			var what := tool.substr(8)
			if map.at(t) == Tiles.WALL and edge:
				return
			if map.at(t) != Tiles.COVER:
				# Only a new case can block a door; toggling one already
				# there is always fine.
				if map.blocks_door(t):
					return
				map.put(t, Tiles.COVER)
			if map.exhibits.get(t, "") == what:
				map.exhibits.erase(t)
			else:
				map.exhibits[t] = what
		_ when tool.begins_with("big:"):
			var r := _big_rect(t)
			var ok := true
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if map.blocks_door(Vector2i(x, y)):
						ok = false
			if ok:
				map.place_big(tool.substr(4), r)
		_ when tool.begins_with("prop:"):
			if map.at(t) != Tiles.FLOOR:
				return
			var what := tool.substr(5)
			var there: Array = map.props.filter(func(p): return p.at == t)
			map.props = map.props.filter(func(p): return p.at != t)
			# The same one again takes it away (always allowed); another
			# swaps it in, unless that would block a door right there.
			if (there.is_empty() or there[0].kind != what) and not map.blocks_door(t):
				map.props.append({"kind": what, "at": t})
		"stamp":
			map.stamp(_rows(), _stamp_corner(t), TEMPLATES[template].gallery)


## The block a big piece in hand would take, centred on `at` and turned
## as R has it.
func _big_rect(at: Vector2i) -> Rect2i:
	var size: Vector2i = MapGen.BIG[tool.substr(4)]
	if turns % 2 == 1:
		size = Vector2i(size.y, size.x)
	return Rect2i(at - size / 2, size)


func _room_at(t: Vector2i) -> int:
	for i in range(map.rooms.size() - 1, -1, -1):
		if map.rooms[i].has_point(t):
			return i
	return -1


func _mark_room(to: Vector2i) -> void:
	var r := Rect2i(room_from, Vector2i.ONE).merge(Rect2i(to, Vector2i.ONE)).intersection(Rect2i(1, 1, map.w - 2, map.h - 2))
	room_from = MapFile.NONE
	if r.size.x >= 2 and r.size.y >= 2:
		map.rooms = map.rooms.filter(func(o): return not o.intersects(r))
		map.rooms.append(r)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# B on the buttons, nothing open: back to the plan (B there undoes).
	if event is InputEventJoypadButton and event.is_action_pressed("ui_cancel") and panel == "" and not _plan.has_focus():
		ui_sound.emit("back")
		_plan.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		ui_sound.emit("back")
		# A panel open shuts first; then the 3D goes back to the plan; then out.
		if panel != "":
			_stay()
		elif in_3d:
			stop_preview()
		else:
			_leave()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed) and event.shift_pressed:
			_redo()
		elif event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			_undo()
		elif event.keycode == KEY_Y and (event.ctrl_pressed or event.meta_pressed):
			_redo()
		elif event.keycode == KEY_R:
			_turn()
		else:
			return
	else:
		return
	get_viewport().set_input_as_handled()


## Everything on screen that shows the map, again.
func _refresh() -> void:
	if map == null:
		return
	map.derive_outside()
	for k in _kind_buttons:
		_look(_kind_buttons[k], kind == k)
	_kind_name.text = Text.t("EDITOR_KIND_" + kind.to_upper())
	for tab in _tabs.get_children():
		if tab.has_meta("filter"):
			_look(tab, tab.get_meta("filter") == filter)
	# The type column, down the left of the catalogue itself (not the tabs).
	for tab in _catalogue.find_children("*", "Button", true, false):
		if tab.has_meta("type"):
			_look(tab, tab.get_meta("type") == filter_type)
	for t in _tool_buttons:
		_look(_tool_buttons[t], tool == t)
	for i in _template_buttons.size():
		_look(_template_buttons[i], tool == "stamp" and template == i)
	# The options: the page open lit, and the card in force.
	if kind == "options":
		for b in _catalogue.find_children("*", "Button", true, false):
			if b.has_meta("page"):
				_look(b, b.get_meta("page") == option_page)
			elif b.has_meta("setting"):
				_look(b, _setting_value(b.get_meta("setting")) == b.get_meta("choice"))
	# Saving: the page open lit, the case's seconds on their slider.
	if panel == "save":
		for b in _sub.find_children("*", "Button", true, false):
			if b.has_meta("save_page"):
				_look(b, b.get_meta("save_page") == save_page)
			elif b.has_meta("seconds"):
				b.text = _seconds_bar()
	elif panel == "guard" and selected_guard != null:
		for b in _guard_tabs.get_children():
			if b.has_meta("guard_page"):
				_look(b, b.get_meta("guard_page") == guard_page)
		for b in _guard_sub.find_children("*", "Button", true, false):
			if b.has_meta("guard_dir"):
				var idx := _nearest_dir(selected_guard.dir)
				b.text = GUARD_DIR_KEYS[idx]
				b.icon = _dir_arrow_texture(GUARD_DIRS[idx])
				b.tooltip_text = Text.t("EDITOR_GUARD_" + GUARD_DIR_KEYS[idx])
			elif b.has_meta("guard_level"):
				var stat: String = b.get_meta("guard_level")
				var level := selected_guard.level(stat)
				b.icon = _level_bars_texture(level)
				b.tooltip_text = Text.t(GuardSpawn.LEVEL_LABELS[stat][level])
			elif b.has_meta("guard_stance"):
				_look(b, b.get_meta("guard_stance") == selected_guard.stance)
			elif b.has_meta("guard_watch"):
				_look(b, b.get_meta("guard_watch") == selected_guard.watch)
		for l in _guard_sub.find_children("*", "Label", true, false):
			if l.has_meta("guard_desc"):
				l.text = _guard_description(selected_guard)
	var errors := map.check()
	if errors.is_empty():
		_status.text = Text.t("EDITOR_OK")
		_status.add_theme_color_override("font_color", Hud.C.green)
	else:
		_status.text = " · ".join(errors.map(func(e): return Text.t(e)))
		_status.add_theme_color_override("font_color", Hud.C.alert)
	_hint.text = Text.t("EDITOR_HINT_" + (tool.get_slice(":", 0) if ":" in tool else tool).to_upper())
	if _pad:
		_hint.text = Text.t("EDITOR_PAD_HELP_3D" if in_3d else "EDITOR_PAD_HELP")
	elif in_3d:
		_hint.text = Text.t("EDITOR_3D_HELP") + "\n" + _hint.text
	else:
		_hint.text += "\n" + Text.t("EDITOR_ICONS_HELP")
	_plan.queue_redraw()


## A line under the plan for a moment, in place of the hint.
func _say(text: String, colour: Color) -> void:
	_hint.text = text
	_hint.add_theme_color_override("font_color", colour)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if is_instance_valid(_hint) and _hint.text == text:
			_hint.add_theme_color_override("font_color", Hud.C.dim)
			_refresh())


func _draw_plan() -> void:
	# In 3D the museum itself is the plan.
	if map == null or in_3d:
		return
	var c := _cell()
	if c < 2:
		return
	var o := _origin()
	var box := func(t: Vector2i, inset := 0.0) -> Rect2: return Rect2(o + Vector2(t) * c + Vector2.ONE * inset, Vector2.ONE * (c - inset * 2))
	var mid := func(t: Vector2i) -> Vector2: return o + (Vector2(t) + Vector2.ONE * 0.5) * c
	# Stray wall tiles nobody marked (MapFile.exempt_walls): drawn as a
	# column here too, the way they will stand once played, so the plan
	# does not lie about what a lone `#` will look like.
	var auto_columns := MapFile.exempt_walls(map.grid, map.outside, map.w, map.h)
	_plan.draw_rect(Rect2(o, Vector2(map.w, map.h) * c), OUTSIDE)
	for y in map.h:
		for x in map.w:
			var t := Vector2i(x, y)
			if map.is_out(t):
				continue
			var tile := map.at(t)
			_plan.draw_rect(box.call(t), Hud.MAP_WALL if tile == Tiles.WALL else (Hud.MAP_CASE if tile == Tiles.COVER else Hud.MAP_FLOOR))
			if tile == Tiles.COVER:
				_plan.draw_rect(box.call(t, c * 0.18), Color("#8fc4d6"), false, maxf(1.0, c * 0.08))
			elif tile == Tiles.WALL and map.doors.has(t):
				_plan.draw_rect(box.call(t, c * 0.14), DOOR)
			elif tile == Tiles.WALL and (map.columns.has(t) or auto_columns.has(t)):
				_plan.draw_circle(mid.call(t), c * 0.22, COLUMN)
	# A faint grid, to count tiles by.
	if c >= 10:
		for x in map.w + 1:
			_plan.draw_line(o + Vector2(x * c, 0), o + Vector2(x * c, map.h * c), Color(0, 0, 0, 0.12))
		for y in map.h + 1:
			_plan.draw_line(o + Vector2(0, y * c), o + Vector2(map.w * c, y * c), Color(0, 0, 0, 0.12))
	for r in map.rooms:
		_plan.draw_rect(Rect2(o + Vector2(r.position) * c, Vector2(r.size) * c).grow(-2), ROOM, false, 2.0)
	for b in map.big:
		var r: Rect2i = b.rect
		var area := Rect2(o + Vector2(r.position) * c, Vector2(r.size) * c).grow(-c * 0.1)
		_plan.draw_rect(area, Color("#6b4a2e"))
		_plan.draw_string(Hud.ARCADE, area.get_center() + Vector2(-c * 0.3, c * 0.25), MapFile.BIG_LETTERS.find_key(b.kind) if MapFile.BIG_LETTERS.values().has(b.kind) else "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(c * 0.6), Hud.CREAM)
	# A chosen piece: its initial on the case.
	for t in map.exhibits:
		if map.big_at(t).is_empty():
			_plan.draw_string(Hud.ARCADE, (mid.call(t) as Vector2) + Vector2(-c * 0.22, c * 0.22), Themes.label(String(map.exhibits[t])).left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(c * 0.5), INK)
	for p in map.props:
		var m: Vector2 = mid.call(p.at)
		_plan.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -0.35) * c, m + Vector2(0.32, 0.28) * c, m + Vector2(-0.32, 0.28) * c]), PROP)
	# The door: the wall it goes through, in green, and an arrow out.
	var reach := map.distances(map.spawn)
	var door := map.exit
	if door != MapFile.NONE:
		var face := map.door_face(door)
		_plan.draw_rect(box.call(door + face), EXIT)
		_plan.draw_line(mid.call(door), (mid.call(door) as Vector2) + Vector2(face) * c * 1.2, INK, maxf(2.0, c * 0.15))
	if map.piece != MapFile.NONE:
		var m: Vector2 = mid.call(map.piece)
		var r := c * 0.42
		_plan.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r, 0), m + Vector2(0, r), m + Vector2(-r, 0)]), PIECE)
	for i in map.guards.size():
		var g: GuardSpawn = map.guards[i]
		_plan.draw_rect(box.call(g.at, c * 0.15), GUARD)
		if g == selected_guard:
			_plan.draw_rect(box.call(g.at, c * 0.15), Color.WHITE, false, maxf(2.0, c * 0.1))
		var gm: Vector2 = mid.call(g.at)
		_plan.draw_line(gm, gm + Vector2(cos(g.dir), sin(g.dir)) * c * 0.4, INK, maxf(2.0, c * 0.12))
		if g.stance == "post":
			_plan.draw_circle(gm, c * 0.08, INK)
		_plan.draw_string(Hud.ARCADE, gm + Vector2(-c * 0.2, c * 0.2), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(c * 0.45), Color.WHITE)
	_plan.draw_circle(mid.call(map.spawn), c * 0.38, THIEF)
	_plan.draw_arc(mid.call(map.spawn), c * 0.38, 0, TAU, 20, INK, maxf(1.0, c * 0.08))
	# Floor you cannot walk to: crossed out, so a closed space shows itself.
	if map.at(map.spawn) == Tiles.FLOOR:
		for y in map.h:
			for x in map.w:
				if map.grid[y * map.w + x] == Tiles.FLOOR and reach[y * map.w + x] < 0:
					var r: Rect2 = box.call(Vector2i(x, y), c * 0.25)
					_plan.draw_line(r.position, r.end, Hud.C.alert, 2.0)
					_plan.draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), Hud.C.alert, 2.0)
	# What the tool in hand would do here.
	if hover != MapFile.NONE:
		if tool == "stamp":
			var rows := _rows()
			var corner := _stamp_corner(hover)
			for y in rows.size():
				for x in String(rows[0]).length():
					var ch := String(rows[y])[x]
					var col := Hud.MAP_WALL if ch == "#" else (Hud.MAP_CASE if ch in ["o", "D", "S", "O"] else Hud.MAP_FLOOR)
					col.a = 0.7
					_plan.draw_rect(box.call(corner + Vector2i(x, y)), col)
			_plan.draw_rect(Rect2(o + Vector2(corner) * c, Vector2(String(rows[0]).length(), rows.size()) * c), Hud.CREAM, false, 2.0)
		elif tool.begins_with("big:"):
			var r := _big_rect(hover)
			_plan.draw_rect(Rect2(o + Vector2(r.position) * c, Vector2(r.size) * c), Color("#6b4a2e", 0.7))
			_plan.draw_rect(Rect2(o + Vector2(r.position) * c, Vector2(r.size) * c), Hud.CREAM, false, 2.0)
		elif tool == "room" and room_from != MapFile.NONE:
			var r := Rect2i(room_from, Vector2i.ONE).merge(Rect2i(hover, Vector2i.ONE))
			_plan.draw_rect(Rect2(o + Vector2(r.position) * c, Vector2(r.size) * c), ROOM, false, 3.0)
		var edge_hover := hover.x == 0 or hover.y == 0 or hover.x == map.w - 1 or hover.y == map.h - 1
		var blocked := tool == "door" and map.at(hover) == Tiles.WALL and not edge_hover and not map.doors.has(hover) \
			and (map.columns.has(hover) or not map.door_fits(hover) or not map.door_clear(hover))
		var cursor_colour := Hud.C.alert if blocked else (Hud.CREAM if _plan.has_focus() else Color(Hud.CREAM, 0.7))
		_plan.draw_rect(box.call(hover), cursor_colour, false, 2.0)
	if _plan.has_focus():
		_plan.draw_rect(Rect2(o, Vector2(map.w, map.h) * c).grow(2), Hud.BRASS, false, 2.0)


func _toggle_3d() -> void:
	view_3d.toggle()


func start_preview(world: Node3D) -> void:
	view_3d.start(world)


func stop_preview() -> void:
	view_3d.stop()


func _exit_tree() -> void:
	view_3d.restore_camera()


func _rebuild() -> void:
	view_3d.rebuild()


static func _changed(a: MapFile, b: MapFile) -> Array[Vector2i]:
	return EditorPreview3D.changed_tiles(a, b)


func _tile_3d() -> Vector2i:
	return view_3d.tile_under_mouse()


func _input_3d(event: InputEvent) -> void:
	view_3d.handle_input(event)


func _mark(t: Vector2i) -> void:
	view_3d.mark_tile(t)


func _place_hover() -> void:
	view_3d.place_hover()


static func _mark_look(colour: Color) -> StandardMaterial3D:
	return EditorPreview3D.mark_material(colour)


func _place_camera() -> void:
	view_3d.place_camera()


func _process(dt: float) -> void:
	if not visible or map == null or not _plan.has_focus() or panel != "":
		_pad_dir = Vector2i.ZERO
		return
	_pad_cursor(dt)
	view_3d.update_camera(dt)


func _input(event: InputEvent) -> void:
	pad_navigation.handle_input(event)


func _pad_on_plan(event: InputEvent) -> void:
	pad_navigation.on_plan(event)


func _pad_after_change() -> void:
	pad_navigation.after_change()


func _pad_cursor(dt: float) -> void:
	pad_navigation.move_cursor(dt)


func _pad_item(step: int) -> void:
	pad_navigation.step_item(step)


func _pad_kind(step: int) -> void:
	pad_navigation.step_kind(step)


func _pick_up(t: Vector2i) -> void:
	pad_navigation.pick_up(t)


# --- A picture of a map ---------------------------------------------------------------

## The plan as a small picture, for the challenges' cards: a pixel block a
## tile, the way in, the piece and the door marked.
static func picture(m: MapFile, cell := 4) -> ImageTexture:
	var img := Image.create(m.w * cell, m.h * cell, false, Image.FORMAT_RGBA8)
	img.fill(OUTSIDE)
	for y in m.h:
		for x in m.w:
			var t := Vector2i(x, y)
			if m.is_out(t):
				continue
			var tile := m.at(t)
			img.fill_rect(Rect2i(t * cell, Vector2i.ONE * cell), Hud.MAP_WALL if tile == Tiles.WALL else (Hud.MAP_CASE if tile == Tiles.COVER else Hud.MAP_FLOOR))
	var mark := func(t: Vector2i, colour: Color) -> void:
		if m.inside(t):
			img.fill_rect(Rect2i(t * cell - Vector2i.ONE * cell / 2, Vector2i.ONE * cell * 2), colour)
	for g in m.guards:
		mark.call(g.at, GUARD)
	if m.exit != MapFile.NONE:
		mark.call(m.exit + m.door_face(m.exit), EXIT)
	mark.call(m.piece, PIECE)
	mark.call(m.spawn, THIEF)
	return ImageTexture.create_from_image(img)
