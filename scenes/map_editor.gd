class_name MapEditor
extends CanvasLayer
## The map editor, for the challenges: the plan seen from above, tile by
## tile, to draw a museum on — or to roll one from the generator and touch it
## up — and save it (MapFile).
##
## The plan (or the museum in 3D) fills the screen: the left button draws
## with the tool in hand, the right one rubs out (what stands on a tile
## first, then the tile, back to floor). Along the bottom, as in a building
## game: a compact block at the left, what to do (the 3D view, play it,
## undo, save, leave) over the kinds of tool (wall and floor, the
## characters, the objects, the rooms, the options); and the rest of the
## bar the catalogue of the kind in hand — the objects with a row of tabs to
## show one theme or all; the options, the building's size and look, rolling
## a museum or clearing it, the difficulty, the guards and the heist (what
## is stolen and its tale). Over the plan, the name and what still stops it
## being played.
##
## Keyboard and pad: Tab (or the arrows off the edge) between the plan and
## the buttons; on the plan the arrows move a cursor, Space or A draws,
## Delete or X rubs out. R turns a room round, Ctrl+Z undoes, Esc or B leaves
## (asking first, if there are changes not saved).

signal closed
## Play it now, as it is.
signal play(map: MapFile)
## Build it in 3D behind the editor: Main answers with start_preview().
signal preview(map: MapFile)
## "nav", "ok", "back", as the menus make.
signal ui_sound(kind: String)

## The kinds of tool, left to right; all but wall and floor fill the catalogue.
const KINDS := ["wall", "main", "objects", "rooms", "options"]
## The bottom bar's height.
const BAR := 168
## Colours a piece to steal can be.
const LOOT_COLOURS := ["#f0c46a", "#f4f1e6", "#ff6b6b", "#ffd43b", "#7bc043", "#4dabf7", "#9b5de5", "#f783ac", "#e8590c", "#8b5a2b"]
const LOOT_SECONDS := [1.5, 2.0, 3.0, 4.0, 5.0, 6.0]
## The characters: where the thieves come in, the case with the piece to
## steal, the way out, the guards.
const MAIN_TOOLS := ["spawn", "piece", "exit", "guard"]
const TOOL_ICONS := {"spawn": "spawn", "piece": "piece", "exit": "exit_door", "guard": "guard"}
## Ready-made rooms, as MapFile.stamp takes them: '#' wall, '.' floor, 'o'
## case, 'D' dinosaur, 'S' sarcophagus, 'b' a bust. The gaps in the border
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
	{"key": "EDITOR_T_DINOSAUR", "gallery": true, "rows": [
		"#####.#####",
		"#.........#",
		"#....DD...#",
		"#o...DD..o#",
		".....DD....",
		"#.........#",
		"#o.......o#",
		"#.........#",
		"#####.#####"]},
	{"key": "EDITOR_T_SARCOPHAGUS", "gallery": true, "rows": [
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
const OPTION_PAGES := ["size", "floor", "wall", "difficulty", "guards", "map", "heist"]
const OPTION_ICONS := {"size": "size", "floor": "rooms", "wall": "wall", "difficulty": "difficulty", "guards": "guard", "map": "random", "heist": "piece"}
const PROP_ORDER := ["bust", "bin", "panel", "armour"]
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

var map: MapFile
var tool := "wall"
## the toolbar button lit (KINDS), and the one whose panel is open ("" none,
## "leave" for the unsaved changes)
var kind := "wall"
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
var undo: Array[MapFile] = []
var dirty := false
## Esc once with changes unsaved: a second one leaves
var leaving := false

var _ui: Control
var _plan: Control
var _name: LineEdit
var _status: Label
var _hint: Label
var _tool_buttons := {}
var _template_buttons: Array[Button] = []
var _kind_buttons := {}
var _exit_button: Button
var _kind_name: Label
## the catalogue along the bottom: its tabs (the objects' themes) and its row
var _tabs: HBoxContainer
var _catalogue: HBoxContainer
## the theme the objects are shown for ("" all)
var filter := ""
## the panel of choices over the bar (the options, or leaving unsaved)
var _flyout: PanelContainer
var _flyout_scroll: ScrollContainer
var _sub_title: Label
var _sub: VBoxContainer
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
				elif what in OPTION_PAGES:
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
	_name = LineEdit.new()
	_name.custom_minimum_size = Vector2(320, 0)
	_name.max_length = 32
	_name.placeholder_text = Text.t("EDITOR_NAME")
	_name.add_theme_font_size_override("font_size", 16)
	_name.text_changed.connect(func(t: String) -> void:
		map.name = t
		dirty = true)
	line.add_child(_name)
	_status = _label("", 14, Hud.C.alert, line)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	bst.bg_color = Color(Hud.WALNUT, 0.96)
	bst.border_color = Hud.BRASS_DARK
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
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 6)
	left.add_child(acts)
	_view_button = _icon_button("view3d", "EDITOR_PREVIEW", _toggle_3d, acts, Hud.C.safe)
	_icon_button("play", "EDITOR_PLAY", _ask_play, acts, Hud.C.green)
	_icon_button("undo", "EDITOR_UNDO", _undo, acts, Hud.C.dim)
	_icon_button("save", "EDITOR_SAVE", _save, acts, Hud.C.green)
	_exit_button = _icon_button("exit", "EDITOR_EXIT", _leave, acts, Hud.C.dim)
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 6)
	left.add_child(kinds)
	for k in KINDS:
		var b := _button(Text.t("EDITOR_KIND_" + k.to_upper()), _pick_kind.bind(k), kinds, Hud.C.safe, false, k)
		b.custom_minimum_size = Vector2(42, 42)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 24)
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
	st.bg_color = Color(Hud.WALNUT, 0.97)
	st.border_color = Hud.BRASS
	st.set_border_width_all(3)
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
	_pick_kind("wall")


## A small square button with a drawn icon, its name on hover.
func _icon_button(icon: String, key: String, call: Callable, parent: Node, colour: Color) -> Button:
	var b := _button("", call, parent, colour, false, icon)
	b.custom_minimum_size = Vector2(42, 36)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 20)
	b.tooltip_text = Text.t(key)
	return b


## One of the bar's settings at the right: its value is its text.
func _setting_button(call: Callable, parent: Node, icon: Variant) -> Button:
	var b := _button("", call, parent, Hud.C.safe, false, icon)
	b.custom_minimum_size = Vector2(200, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_font_size_override("font_size", 8)
	return b


func _label(text: String, size: int, colour: Color, parent: Node, arcade := false) -> Label:
	var l := Label.new()
	l.text = text
	if arcade:
		l.add_theme_font_override("font", Hud.ARCADE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


## A button in the menus' look: walnut, brass when it has the focus.
## big: the toolbar's. icon: a name in assets/icons/editor (white, tinted
## like the text), or a texture of its own, shown as it is.
func _button(text: String, call: Callable, parent: Node, colour: Color, big := false, icon: Variant = null) -> Button:
	var b := Button.new()
	b.text = text
	if icon is String:
		b.icon = load("res://assets/icons/editor/%s.svg" % icon)
	elif icon is Texture2D:
		b.icon = icon
		b.set_meta("photo", true)
	if b.icon:
		b.expand_icon = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 34 if big else 24)
		b.add_theme_constant_override("h_separation", 10)
	b.focus_mode = Control.FOCUS_ALL
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(160, 52 if big else 38)
	# The toolbar's words on one line; the panels' may wrap.
	b.autowrap_mode = TextServer.AUTOWRAP_OFF if big else TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", Hud.ARCADE)
	b.add_theme_font_size_override("font_size", 10)
	b.set_meta("colour", colour)
	_look(b, false)
	b.pressed.connect(call)
	b.pressed.connect(func() -> void: ui_sound.emit("ok"))
	b.focus_entered.connect(func() -> void: ui_sound.emit("nav"))
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b


## selected: the tool in hand, or the room.
func _look(b: Button, selected: bool) -> void:
	var colour: Color = b.get_meta("colour")
	for state in ["normal", "hover", "pressed", "focus"]:
		var lit: bool = state != "normal"
		var st := StyleBoxFlat.new()
		st.bg_color = Hud.BRASS if lit else (Hud.WALNUT_LIT if selected else Hud.WALNUT)
		st.set_corner_radius_all(12)
		st.border_color = Hud.CREAM if lit else (colour if selected else Hud.BRASS_DARK)
		st.set_border_width_all(3 if lit or selected else 2)
		st.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, st)
	b.add_theme_color_override("font_color", colour if selected else Hud.CREAM)
	for key in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, Hud.INK)
	# A drawn icon goes the colour of the text; a picture stays as it is.
	if not b.has_meta("photo"):
		b.add_theme_color_override("icon_normal_color", colour if selected else Hud.CREAM)
		for key in ["icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(key, Hud.INK)


## A ready-made room as a little plan, in the plan's own colours.
func _template_picture(i: int) -> ImageTexture:
	var rows: Array = TEMPLATES[i].rows
	var cell := 4
	var img := Image.create(String(rows[0]).length() * cell, rows.size() * cell, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in String(rows[0]).length():
			var ch := String(rows[y])[x]
			var col: Color = Hud.MAP_WALL if ch == "#" else (Hud.MAP_CASE if ch in ["o", "D", "S", "b"] else Hud.MAP_FLOOR)
			img.fill_rect(Rect2i(x * cell, y * cell, cell, cell), col)
	return ImageTexture.create_from_image(img)


## The floor's or the walls' colours as they are now: two tones of stone in
## a check, or the wallpaper's stripes over its wainscot.
## which: one of the looks (MuseumView.looks), -1 the seed's own, or -2
## (the default) whatever the map has now.
func _swatch(part: String, which := -2) -> ImageTexture:
	var look: Dictionary = {}
	if which >= 0:
		look = MuseumView.looks()[which]
	elif which == -2 and map:
		look = map.palette()
	if look.is_empty():
		look = MuseumView.THEMES[posmod(map.seed if map else 0, MuseumView.THEMES.size())]
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c: Color
			if part == "floor":
				c = look.stone if (x / 4 + y / 4) % 2 == 0 else look.stone2
			else:
				c = look.wainscot if y >= 11 else (look.paper if (x / 3) % 2 == 0 else look.paper2)
			img.set_pixel(x, y, c.lightened(0.15))
	return ImageTexture.create_from_image(img)


func _tool_colour(t: String) -> Color:
	if t.begins_with("prop:"):
		return PROP
	if t.begins_with("big:"):
		return ROOM
	match t:
		"spawn": return THIEF
		"piece": return PIECE
		"exit": return EXIT
		"guard": return GUARD
		"prop": return PROP
		"room": return ROOM
	return Hud.C.safe


# --- Tools and settings ------------------------------------------------------------

## A kind of tool: its catalogue along the bottom. Wall and floor has only
## the one tool, straight into the hand.
func _pick_kind(k: String) -> void:
	kind = k
	if k == "wall":
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
		"wall":
			_tool_buttons["wall"] = _item("wall", Text.t("EDITOR_TOOL_WALL"), _choose_tool.bind("wall", "wall"), Hud.C.safe)
			var note := _label(Text.t("EDITOR_WALL_NOTE"), 13, Hud.C.dim, _catalogue)
			note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		"main":
			for t in MAIN_TOOLS:
				_tool_buttons[t] = _item(TOOL_ICONS[t], Text.t("EDITOR_TOOL_" + t.to_upper()), _choose_tool.bind("main", t), _tool_colour(t))
		"objects":
			for id in [""] + Themes.ids():
				var tab := _button(Text.t("EDITOR_FILTER_ALL") if id == "" else Text.t("THEME_" + String(id).to_upper()), _pick_filter.bind(id), _tabs, Hud.C.gold)
				tab.custom_minimum_size = Vector2(0, 26)
				tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				tab.autowrap_mode = TextServer.AUTOWRAP_OFF
				tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
				tab.add_theme_font_size_override("font_size", 8)
				tab.set_meta("filter", id)
			for entry in Themes.catalogue():
				var t: String = entry[0]
				var themes: Array = entry[1]
				if filter != "" and not themes.has(filter):
					continue
				var id := t.replace(":", "_").replace("/", "_")
				var name := Text.t("EDITOR_TOOL_CASE") if t == "case" else (Themes.label(t.substr(8)) if t.begins_with("exhibit:") else Text.t("EDITOR_TOOL_" + id.to_upper()))
				_tool_buttons[t] = _item(load("res://assets/icons/objects/%s.png" % id), name, _choose_tool.bind("objects", t), _tool_colour(t))
		"options":
			_options()
		"rooms":
			for i in TEMPLATES.size():
				_template_buttons.append(_item(_template_picture(i), Text.t(TEMPLATES[i].key), _choose_template.bind(i), Hud.C.gold))
			_item("turn", Text.t("EDITOR_TURN"), _turn, Hud.C.dim)
			_tool_buttons["room"] = _item("room", Text.t("EDITOR_TOOL_ROOM"), _choose_tool.bind("rooms", "room"), ROOM)


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


func _pick_filter(id: String) -> void:
	filter = id
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
		"guards":
			_choice(Text.t("EDITOR_GUARDS_AUTO") % map.guards_tonight(), "guards", _set_guards.bind(0), 0, "guard")
			# Never fewer than the guards placed by hand.
			for n in range(maxi(1, map.guards.size()), MapFile.MAX_GUARDS + 1):
				_choice(str(n), "guards", _set_guards.bind(n), n, "guard")
		"map":
			_choice(Text.t("EDITOR_RANDOM"), "", _random, null, "random")
			_choice(Text.t("EDITOR_CLEAR"), "", _clear, null, "clear")
		"heist":
			_heist_panel()


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
		"guards": return map.guard_count
	return null


func _open_page(page: String) -> void:
	option_page = page
	_fill_catalogue()
	_refresh()


## A column in the catalogue.
func _column(width := 0.0) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.custom_minimum_size = Vector2(width, 0)
	_catalogue.add_child(col)
	return col


## The panel over the bar, for leaving with changes not saved ("leave");
## "" shuts it.
func _open(k: String) -> void:
	panel = k
	leaving = k == "leave"
	for c in _sub.get_children():
		_sub.remove_child(c)
		c.queue_free()
	_flyout.visible = k != ""
	if k == "":
		_refresh()
		return
	_sub_title.text = Text.t("EDITOR_UNSAVED")
	_button(Text.t("EDITOR_SAVE_AND_EXIT"), _save_and_leave, _sub, Hud.C.green)
	_button(Text.t("EDITOR_EXIT_NO_SAVE"), closed.emit, _sub, Hud.C.alert)
	_button(Text.t("EDITOR_KEEP_EDITING"), _stay, _sub, Hud.C.dim)
	_refresh()
	_place_flyout.call_deferred()
	(_sub.get_child(0) as Control).grab_focus.call_deferred()


## What is stolen and why: the piece (a picture each, AL AZAR to let the
## game pick), its colour, its name and a line on it, how long its case
## takes, and the tale told before the job.
func _heist_panel() -> void:
	# Where it is, the case, is picked with the characters (MAIN_TOOLS).
	_catalogue.add_child(VSeparator.new())
	var col := _column()
	_label(Text.t("EDITOR_KIND_HEIST") + " · " + Text.t("EDITOR_LOOT_WHAT"), 8, Hud.BRASS, col, true)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	col.add_child(grid)
	var shapes: Array = [""] + MapFile.LOOT_SHAPES
	for shape in shapes:
		var b := _button("?" if shape == "" else "", _pick_loot.bind(shape), grid, PIECE, false, null if shape == "" else load("res://assets/icons/objects/loot_%s.png" % shape))
		b.custom_minimum_size = Vector2(46, 46)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.add_theme_constant_override("icon_max_width", 38)
		b.tooltip_text = Text.t("EDITOR_LOOT_RANDOM" if shape == "" else "EDITOR_SHAPE_" + String(shape).to_upper())
		b.set_meta("loot", shape)
	if map.loot.is_empty():
		var none := _label(Text.t("EDITOR_LOOT_NONE"), 12, Hud.C.dim, _column(260))
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		return
	col = _column(230)
	_label(Text.t("EDITOR_LOOT_COLOUR"), 8, Hud.C.dim, col, true)
	var colours := GridContainer.new()
	colours.columns = 5
	colours.add_theme_constant_override("h_separation", 4)
	colours.add_theme_constant_override("v_separation", 4)
	col.add_child(colours)
	for hex in LOOT_COLOURS:
		var c := Color(hex)
		var img := Image.create(12, 12, false, Image.FORMAT_RGBA8)
		img.fill(c)
		var b := _button("", func() -> void:
			map.loot.colour = hex
			dirty = true
			_refresh(), colours, c, false, ImageTexture.create_from_image(img))
		b.custom_minimum_size = Vector2(40, 26)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.add_theme_constant_override("icon_max_width", 14)
		b.set_meta("hex", hex)
	var secs := _setting_button(_step_seconds, col, "difficulty")
	secs.set_meta("seconds", true)
	col = _column(240)
	var name_edit := _field(Text.t("EDITOR_LOOT_NAME"), map.loot.name, Text.t("EDITOR_SHAPE_" + String(map.loot.shape).to_upper()).to_lower(), col)
	name_edit.text_changed.connect(func(t: String) -> void:
		map.loot.name = t
		dirty = true)
	var blurb := _field(Text.t("EDITOR_LOOT_BLURB"), map.loot.blurb, Text.t("EDITOR_LOOT_BLURB_HINT"), col)
	blurb.text_changed.connect(func(t: String) -> void:
		map.loot.blurb = t
		dirty = true)
	col = _column(320)
	_label(Text.t("EDITOR_LOOT_STORY"), 8, Hud.C.dim, col, true)
	var story := TextEdit.new()
	story.text = map.loot.story
	story.placeholder_text = Text.t("EDITOR_LOOT_STORY_HINT")
	story.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	story.custom_minimum_size = Vector2(320, 104)
	story.add_theme_font_size_override("font_size", 13)
	story.text_changed.connect(func() -> void:
		map.loot.story = story.text
		dirty = true)
	col.add_child(story)


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
	_fill_catalogue()
	_refresh()


func _step_seconds() -> void:
	var i := LOOT_SECONDS.find(map.loot.seconds)
	map.loot.seconds = LOOT_SECONDS[(i + 1) % LOOT_SECONDS.size()]
	dirty = true
	_refresh()


## Over the bar, above the button that opened it, as tall as fits.
func _place_flyout() -> void:
	var from: Button = _exit_button
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
	kind = "rooms"
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


## 0 AUTO, or how many guards (never fewer than those placed by hand).
func _set_guards(n: int) -> void:
	map.guard_count = n
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


func _remember() -> void:
	undo.append(map.copy())
	if undo.size() > UNDO_STEPS:
		undo.remove_at(0)
	dirty = true
	leaving = false


func _undo() -> void:
	if undo.is_empty():
		return
	map = undo.pop_back()
	_name.text = map.name
	_refresh()
	_rebuild()


func _save() -> void:
	map.name = _name.text.strip_edges()
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
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
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
		elif (event is InputEventKey and event.pressed and event.keycode in [KEY_DELETE, KEY_BACKSPACE]) \
				or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X):
			if hover != MapFile.NONE:
				_press(hover, true)
			_plan.accept_event()


## Tools that draw as the mouse drags; the rest act once per press.
func _paints() -> bool:
	return tool in ["wall", "case"]


func _press(t: Vector2i, erase: bool) -> void:
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
		if map.guards.has(t):
			map.guards.erase(t)
		elif map.exhibits.has(t):
			map.exhibits.erase(t)
		elif map.props.any(func(p): return p.at == t):
			map.props = map.props.filter(func(p): return p.at != t)
		elif map.exit == t:
			map.exit = MapFile.NONE
		elif map.piece == t:
			map.piece = MapFile.NONE
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
		"case": map.put(t, Tiles.COVER)
		"spawn":
			if map.at(t) == Tiles.FLOOR:
				map.spawn = t
		"piece":
			if map.at(t) != Tiles.COVER:
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
			if map.guards.has(t):
				map.guards.erase(t)
			elif map.at(t) == Tiles.FLOOR and map.guards.size() < MapFile.MAX_GUARDS:
				map.guards.append(t)
				if map.guard_count > 0:
					map.guard_count = maxi(map.guard_count, map.guards.size())
		_ when tool.begins_with("exhibit:"):
			# On floor or a case; the same piece again leaves the case plain.
			var what := tool.substr(8)
			if map.at(t) == Tiles.WALL and edge:
				return
			if map.at(t) != Tiles.COVER:
				map.put(t, Tiles.COVER)
			if map.exhibits.get(t, "") == what:
				map.exhibits.erase(t)
			else:
				map.exhibits[t] = what
		_ when tool.begins_with("big:"):
			map.place_big(tool.substr(4), _big_rect(t))
		_ when tool.begins_with("prop:"):
			if map.at(t) != Tiles.FLOOR:
				return
			var what := tool.substr(5)
			var there: Array = map.props.filter(func(p): return p.at == t)
			map.props = map.props.filter(func(p): return p.at != t)
			# The same one again takes it away; another swaps it.
			if there.is_empty() or there[0].kind != what:
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
		if event.keycode == KEY_Z and (event.ctrl_pressed or event.meta_pressed):
			_undo()
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
		_look(tab, tab.get_meta("filter", "") == filter)
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
	# The heist, in the options: the piece and the colour in hand lit, the seconds.
	if kind == "options":
		for b in _catalogue.find_children("*", "Button", true, false):
			if b.has_meta("loot"):
				_look(b, b.get_meta("loot") == map.loot.get("shape", ""))
			elif b.has_meta("hex"):
				_look(b, b.get_meta("hex") == map.loot.get("colour", ""))
			elif b.has_meta("seconds"):
				b.text = Text.t("EDITOR_LOOT_SECONDS") % str(map.loot.seconds)
	var errors := map.check()
	if errors.is_empty():
		_status.text = Text.t("EDITOR_OK")
		_status.add_theme_color_override("font_color", Hud.C.green)
	else:
		_status.text = " · ".join(errors.map(func(e): return Text.t(e)))
		_status.add_theme_color_override("font_color", Hud.C.alert)
	_hint.text = Text.t("EDITOR_HINT_" + (tool.get_slice(":", 0) if ":" in tool else tool).to_upper())
	if in_3d:
		_hint.text = Text.t("EDITOR_3D_HELP") + " · " + _hint.text
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
		_plan.draw_string(Hud.ARCADE, area.get_center() + Vector2(-c * 0.3, c * 0.25), "D" if b.kind == "dinosaur" else "S", HORIZONTAL_ALIGNMENT_LEFT, -1, int(c * 0.6), Hud.CREAM)
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
		var g: Vector2i = map.guards[i]
		_plan.draw_rect(box.call(g, c * 0.15), GUARD)
		_plan.draw_string(Hud.ARCADE, (mid.call(g) as Vector2) + Vector2(-c * 0.2, c * 0.2), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, int(c * 0.45), Color.WHITE)
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
					var col := Hud.MAP_WALL if ch == "#" else (Hud.MAP_CASE if ch in ["o", "D", "S"] else Hud.MAP_FLOOR)
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
		_plan.draw_rect(box.call(hover), Hud.CREAM if _plan.has_focus() else Color(Hud.CREAM, 0.7), false, 2.0)
	if _plan.has_focus():
		_plan.draw_rect(Rect2(o, Vector2(map.w, map.h) * c).grow(2), Hud.BRASS, false, 2.0)


# --- The 3D view --------------------------------------------------------------------

func _toggle_3d() -> void:
	if in_3d:
		stop_preview()
	else:
		_ask_preview()


## The museum just built from the map in the game's world (Main has laid it
## out): the plan makes way for it, a camera comes round it, and whatever
## changed since the last build throws up a little dust.
func start_preview(world: Node3D) -> void:
	var first := not in_3d
	in_3d = true
	_back.visible = false
	if first:
		_was_current = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 45
	world.add_child(_cam)
	_cam.make_current()
	# A little moonlight from over the camera: the museum at night, but readable.
	_cam_light = DirectionalLight3D.new()
	_cam_light.light_color = Color("#b8c4ff")
	_cam_light.light_energy = 0.5
	world.add_child(_cam_light)
	if not _span_set:
		_span = maxf(map.w, map.h) * 0.9
		_span_set = true
	_place_camera()
	_hover_mark = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.96, 0.96)
	_hover_mark.mesh = q
	_hover_mark.material_override = _mark_look(Color(Hud.CREAM, 0.45))
	_hover_mark.visible = false
	world.add_child(_hover_mark)
	_marks = Node3D.new()
	world.add_child(_marks)
	for t in _changed(_built, map).slice(0, 14):
		Fx.puff(world, MuseumView.to_world(t.x + 0.5, t.y + 0.5))
	_built = map.copy()
	_view_button.icon = load("res://assets/icons/editor/rooms.svg")
	_view_button.tooltip_text = Text.t("EDITOR_2D")
	_refresh()


## Back to the plan.
func stop_preview() -> void:
	if not in_3d:
		return
	in_3d = false
	_back.visible = true
	for n in [_cam, _cam_light, _hover_mark, _marks]:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(_was_current):
		_was_current.make_current()
	_view_button.icon = load("res://assets/icons/editor/view3d.svg")
	_view_button.tooltip_text = Text.t("EDITOR_PREVIEW")
	_refresh()
	_plan.grab_focus()


func _exit_tree() -> void:
	# Leaving from the 3D: the game's camera back.
	if in_3d and is_instance_valid(_was_current):
		_was_current.make_current()


## Build the museum again from the map as it is now; one that cannot be
## played cannot be built, and waits (with its marks) until it can.
func _rebuild() -> void:
	if not in_3d:
		return
	if not map.check().is_empty():
		_say(Text.t("EDITOR_3D_WAITS"), Hud.C.gold)
		return
	preview.emit(map.copy())


## Tiles that differ between two builds: what is on them or stands there.
static func _changed(a: MapFile, b: MapFile) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if a == null or a.w != b.w or a.h != b.h:
		return out
	for y in b.h:
		for x in b.w:
			var t := Vector2i(x, y)
			if a.at(t) != b.at(t) or a.exhibits.get(t, "") != b.exhibits.get(t, "") or a.guards.has(t) != b.guards.has(t) \
					or a.props.any(func(p): return p.at == t) != b.props.any(func(p): return p.at == t):
				out.append(t)
	for k in [["spawn", a.spawn, b.spawn], ["piece", a.piece, b.piece], ["exit", a.exit, b.exit]]:
		if k[1] != k[2] and b.inside(k[2]):
			out.append(k[2])
	return out


## The tile under the mouse: the top of a wall if it points at one, or the
## floor.
func _tile_3d() -> Vector2i:
	if not is_instance_valid(_cam):
		return MapFile.NONE
	var at := get_viewport().get_mouse_position()
	var o := _cam.project_ray_origin(at)
	var d := _cam.project_ray_normal(at)
	for height in [MuseumView.WALL_HEIGHT, 0.0]:
		if absf(d.y) < 0.0001:
			continue
		var k: float = (height - o.y) / d.y
		if k <= 0.0:
			continue
		var p := o + d * k
		var t := Vector2i(floori(p.x + map.w / 2.0), floori(p.z + map.h / 2.0))
		if not map.inside(t):
			continue
		if height == 0.0 or (map.at(t) == Tiles.WALL and not map.is_out(t)):
			return t
	return MapFile.NONE


func _input_3d(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# The right button held: turn round the museum.
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_yaw += event.relative.x * 0.01
			_pitch = clampf(_pitch + event.relative.y * 0.01, 0.25, 1.45)
			_place_camera()
		var t := _tile_3d()
		if t != hover:
			hover = t
			if held == MOUSE_BUTTON_LEFT and t != MapFile.NONE and _paints():
				_use(t, false)
				_mark(t)
		_place_hover()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_span = maxf(8.0, _span * 0.9)
				_place_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				_span = minf(90.0, _span * 1.1)
				_place_camera()
			MOUSE_BUTTON_RIGHT:
				# A click without a drag rubs out, as on the plan.
				if event.pressed:
					_right_from = event.position
				elif _right_from.distance_to(event.position) < 6.0 and hover != MapFile.NONE:
					_press(hover, true)
					_rebuild()
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_plan.grab_focus()
					hover = _tile_3d()
					if hover == MapFile.NONE:
						return
					held = MOUSE_BUTTON_LEFT
					_press(hover, false)
					if _paints():
						_mark(hover)
					elif tool != "room":
						_rebuild()
				else:
					held = 0
					if tool == "room" and room_from != MapFile.NONE and hover != MapFile.NONE and room_from != hover:
						_mark_room(hover)
					if _paints() or tool == "room":
						_rebuild()
	elif event.is_action_pressed("ui_accept") and hover != MapFile.NONE:
		_press(hover, false)
		_rebuild()
	_plan.accept_event()


## A tile painted in a stroke not yet built: a block of wall, a case, or a
## patch of floor, in the plan's colours.
func _mark(t: Vector2i) -> void:
	var tile := map.at(t)
	var tall := 1.2 if tile == Tiles.WALL else (0.8 if tile == Tiles.COVER else 0.04)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, tall, 1.0)
	m.mesh = box
	var colour: Color = Hud.MAP_WALL if tile == Tiles.WALL else (Hud.MAP_CASE if tile == Tiles.COVER else Hud.MAP_FLOOR)
	m.material_override = _mark_look(Color(colour, 0.85))
	m.position = MuseumView.to_world(t.x + 0.5, t.y + 0.5, tall / 2.0)
	_marks.add_child(m)


func _place_hover() -> void:
	if not is_instance_valid(_hover_mark):
		return
	_hover_mark.visible = hover != MapFile.NONE
	if hover != MapFile.NONE:
		var on_wall := map.at(hover) == Tiles.WALL
		_hover_mark.position = MuseumView.to_world(hover.x + 0.5, hover.y + 0.5, MuseumView.WALL_HEIGHT + 0.06 if on_wall else 0.06)


static func _mark_look(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _place_camera() -> void:
	if not is_instance_valid(_cam):
		return
	var at := Vector3(cos(_yaw) * cos(_pitch), sin(_pitch), sin(_yaw) * cos(_pitch)) * _span
	_cam.position = at
	_cam.look_at(Vector3.ZERO)
	_cam_light.transform = _cam.transform


func _process(dt: float) -> void:
	if not in_3d or not _plan.has_focus():
		return
	# The arrows or the stick turn it round and tilt it.
	var turn := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if turn != Vector2.ZERO:
		_yaw += turn.x * dt * 1.5
		_pitch = clampf(_pitch - turn.y * dt * 1.0, 0.25, 1.45)
		_place_camera()


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
		mark.call(g, GUARD)
	if m.exit != MapFile.NONE:
		mark.call(m.exit + m.door_face(m.exit), EXIT)
	mark.call(m.piece, PIECE)
	mark.call(m.spawn, THIEF)
	return ImageTexture.create_from_image(img)
