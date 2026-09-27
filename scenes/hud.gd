class_name Hud
extends CanvasLayer
## Everything drawn over the game: the status line, the log, the job's
## progress and the arrow to the objective, the guards' yell, and the
## full-screen panels (title, mission, pause, end of round).

## The menus' toy palette: cream cards and buttons, dark ink text.
const CREAM := Color("#f1dfbd")
const INK := Color("#2a160d")
const INK_SOFT := Color("#b9a07a")
## The night museum's furniture: walnut panels, brass fittings, parchment.
const WALNUT := Color("#35211a")
const WALNUT_LIT := Color("#4a2f24")
const WALNUT_EDGE := Color("#120906")
const BRASS := Color("#d8ac5c")
const BRASS_DARK := Color("#7a5a32")
## The menus' frames: dark smoked glass with a thin pale rim, and a warm glow
## round the one with the focus, lit like the cases in the hall behind.
const GLASS := Color("#150f24", 0.84)
const GLASS_LIT := Color("#241838", 0.92)
const GLASS_EDGE := Color("#8f82b8", 0.5)
const GLOW := Color("#ffae42")
const GLOW_TEXT := Color("#fff0d6")

## Behind every menu: a museum wall at night — aubergine above, dark wood
## below, a faint striped wallpaper with a damask dot, the warm pool of a
## lamp from the top, a vignette round the edge.
## Out of the game a picture of the museum hall shows instead (MENU_PICTURE),
## darker at the top and bottom so the headings and buttons read, looking at a
## different part of it on each screen (focus, SPOTS) and drifting.
const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.16, 0.09, 0.2, 0.97);
uniform vec4 bottom : source_color = vec4(0.08, 0.045, 0.035, 0.98);
uniform sampler2D picture : filter_linear, repeat_disable;
uniform float cover = 0.0;
uniform vec2 focus = vec2(0.5);
const float ZOOM = 1.15;
void fragment() {
	vec4 c = mix(top, bottom, smoothstep(0.0, 1.0, UV.y));
	float stripe = step(0.5, fract(FRAGCOORD.x / 64.0));
	c.rgb += stripe * 0.012 * (1.0 - UV.y);
	vec2 g = fract(FRAGCOORD.xy / vec2(64.0, 80.0) + vec2(0.25, 0.0)) - 0.5;
	c.rgb += smoothstep(0.09, 0.06, length(g * vec2(1.0, 0.7))) * 0.018 * (1.0 - UV.y);
	// A wainscot rail across the lower third.
	c.rgb += smoothstep(0.004, 0.0, abs(UV.y - 0.72)) * 0.05;
	if (cover > 0.0) {
		vec2 pic = vec2(textureSize(picture, 0));
		float screen = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
		float aspect = pic.x / pic.y;
		vec2 span = vec2(screen / aspect, 1.0);
		if (screen > aspect) {
			span = vec2(1.0, aspect / screen);
		}
		span /= ZOOM;
		vec2 drift = vec2(sin(TIME * 0.05), cos(TIME * 0.037)) * 0.02;
		vec2 centre = clamp(focus + drift, span * 0.5, 1.0 - span * 0.5);
		vec3 p = texture(picture, centre + (UV - 0.5) * span).rgb * 0.7;
		// Darker at the top, under the heading, and at the bottom, under the buttons.
		p *= 1.0 - 0.35 * smoothstep(0.3, 0.0, UV.y);
		p *= 1.0 - 0.4 * pow(clamp((UV.y - 0.6) / 0.4, 0.0, 1.0), 2.0);
		c.rgb = mix(c.rgb, p, cover);
	}
	// The lamp: warm light pooling from the top centre, breathing slowly.
	float lamp = exp(-pow(distance(UV * vec2(1.6, 1.0), vec2(0.8, 0.05)) * 1.9, 2.0));
	c.rgb += vec3(0.45, 0.28, 0.12) * lamp * (0.3 + 0.03 * sin(TIME * 1.3)) * (1.0 - cover);
	c.rgb *= 1.0 - distance(UV, vec2(0.5)) * 0.55;
	COLOR = c;
}
"""
const MENU_PICTURE := "res://assets/ui/fondo_menu.png"
## Where the menus out of the game look in MENU_PICTURE (Hud.backdrop), as
## fractions of it: the title at the lit case in the middle, the story at the
## vase on the left, the generative at the cases on the right, the challenges
## at the tall windows, the settings at the banners.
const SPOTS := {
	"title": Vector2(0.5, 0.6),
	"story": Vector2(0.15, 0.6),
	"generative": Vector2(0.85, 0.6),
	"challenge": Vector2(0.7, 0.2),
	"settings": Vector2(0.3, 0.2),
}

## A picture with rounded corners, to sit inside a rounded card.
const ROUNDED_SHADER := """
shader_type canvas_item;
uniform vec2 box = vec2(300.0, 200.0);
uniform float radius = 18.0;
void fragment() {
	vec2 p = UV * box;
	vec2 q = min(p, box - p);
	float a = 1.0;
	if (q.x < radius && q.y < radius) {
		a = 1.0 - smoothstep(radius - 1.5, radius, length(vec2(radius) - q));
	}
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= a;
}
"""

const C := {
	"text": Color("#eef2ff"),
	"dim": Color("#9aa0c8"),
	"gold": Color("#ffe066"),
	"alert": Color("#ff3d6e"),
	"safe": Color("#22d3ee"),
	"green": Color("#4ade80"),
	"panel": Color("#0b0820", 0.92),
}
## How long the yell fills the screen.
const SHOUT_S := 1.4
## A menu sound to play: "nav" moving about, "ok" choosing, "back" going back.
signal ui_sound(kind: String)
## How long a full-screen menu takes to fade in or out over the game.
const FADE_S := 0.2
## The arcade face, for titles, buttons, the clock and the yell only: it is a
## shouting font and unreadable in paragraphs, so the log and the IA panel keep
## the plain one.
const ARCADE := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _status: Label
## the guards' alarm, top centre: the most alarmed guard's ! !! !!!
var _alarm: TextureRect
var _alarm_level := -1
## the gang, bottom centre: a live portrait of each thief (Hud.set_gang)
var _gang: HBoxContainer
var _portraits: Array[Dictionary] = []
var _log: Label
## the game's version (project.godot, tools/version.py), in the title's corner
var _version: Label
var _job: Label
## the way to the objective: a kunai at the edge of the screen
var _arrow: Control
var _shout: Control
var _shout_word: Label
var _shout_text: Label
var _shout_arrow: Label
var _shout_left := 0.0
var _shout_angle := 0.0
var _panel: ColorRect
var _panel_box: VBoxContainer
## whether a menu is up, as far as the game is concerned: false the moment it
## starts fading out, while the panel itself is still visible
var _shown := false
var _fade: Tween
## The backdrop panning or fading between the picture and the wall.
var _backdrop: Tween
## where in the picture it looks (the wall keeps the last, to fade from)
var _focus := Vector2(0.5, 0.5)
## what is drawn over the game while playing; hidden behind a menu
var _play: Array[Control] = []
var _count: Label
var _count_left := 0.0
var _count_step := -1
var _count_on_step: Callable
var _count_on_done: Callable
var _map: Control
var _map_picture: TextureRect
var _map_stage: MapStage
## the folded map on the menu on show, if any, to lean with the arrows
var _menu_map: MapStage
var _map_legend: VBoxContainer
var _ia: PanelContainer
var _ia_box: VBoxContainer


func _ready() -> void:
	_status = _label(16, C.text, self, true)
	_status.position = Vector2(24, 16)
	_version = _label(12, C.dim)
	_version.text = "v" + str(ProjectSettings.get_setting("application/config/version", ""))
	_version.visible = false
	_log = _label(15, C.dim)
	_log.position = Vector2(24, 64)
	_job = _label(14, C.gold, self, true)
	_job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow = _pointer()

	_shout = Control.new()
	_shout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shout)
	_shout_word = _label(96, C.alert, _shout, true)
	_shout_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout_text = _label(20, C.gold, _shout)
	_shout_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout_arrow = _label(64, C.alert, _shout)
	_shout_arrow.text = "▶"
	_shout.visible = false

	_count = _label(150, C.gold, self, true)
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.add_theme_constant_override("outline_size", 24)
	_count.add_theme_color_override("font_outline_color", Color("#b45309"))
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.visible = false

	# The map you can take out while playing: a folded paper map in 3D
	# (MapStage), over a dimmed game, under the menus.
	_map = Control.new()
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(dim)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(column)
	_map_stage = MapStage.new()
	_map.add_child(_map_stage)
	_map_picture = TextureRect.new()
	_map_picture.texture = _map_stage.get_texture()
	_map_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_map_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_picture.custom_minimum_size = Vector2(MapStage.SIZE) * 0.95
	_map_picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_map_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_map_picture)
	# The legend is filled in when the map comes out (show_map): it knows
	# how many thieves there are and the colour of the piece.
	_map_legend = VBoxContainer.new()
	_map_legend.add_theme_constant_override("separation", 6)
	column.add_child(_map_legend)
	_map.visible = false
	_map_stage.process_mode = Node.PROCESS_MODE_DISABLED

	_panel = ColorRect.new()
	_panel.color = C.panel
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := Shader.new()
	backdrop.code = BACKDROP_SHADER
	_panel.material = ShaderMaterial.new()
	(_panel.material as ShaderMaterial).shader = backdrop
	add_child(_panel)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(centre)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 10)
	centre.add_child(_panel_box)
	# Up top, only how alarmed the guards are; at the bottom, the gang.
	_status.visible = false
	_alarm = TextureRect.new()
	_alarm.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_alarm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_alarm)
	_gang = HBoxContainer.new()
	_gang.add_theme_constant_override("separation", 14)
	_gang.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gang)
	_play = [_log, _job, _arrow, _alarm, _gang]

	# The model's reasoning, for whoever wants to watch it think: a card per
	# guard with its plan and the probabilities Laya gave each option.
	_ia = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#140f2e", 0.92)
	style.border_color = Color("#241d52")
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	_ia.add_theme_stylebox_override("panel", style)
	_ia.custom_minimum_size = Vector2(300, 0)
	add_child(_ia)
	move_child(_ia, _panel.get_index())
	_ia_box = VBoxContainer.new()
	_ia.add_child(_ia_box)
	_ia.visible = false


## The kunai's outline: a long point ahead, a short one behind.
const KUNAI_BLADE := [Vector2(30, 0), Vector2(-4, -9), Vector2(-12, 0), Vector2(-4, 9)]


## A kunai's blade pared down to a kite, drawn round its own origin and
## pointing right until rotated: a long point ahead and a short one behind, so
## there is no doubt which end leads. Its colour is its modulate.
func _pointer() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.visible = false
	add_child(c)
	var blade := PackedVector2Array(KUNAI_BLADE)
	c.draw.connect(func() -> void:
		var ring := blade.duplicate()
		ring.append(blade[0])
		c.draw_polyline(ring, MAP_INK, 3.0, true)
		c.draw_colored_polygon(blade, Color.WHITE))
	return c


func _label(size: int, colour: Color, parent: Node = self, arcade := false) -> Label:
	var l := Label.new()
	if arcade:
		l.add_theme_font_override("font", ARCADE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


# --- Panels --------------------------------------------------------------------

## A full-screen menu. items, top to bottom, each one of:
##   {"title": text, "colour": Color, "size": int, "align"?}
##                                                    the heading ("left" for
##                                                    against the left edge)
##   {"text": text, "size"?, "colour"?, "wrap"?, "width"?, "align"?}
##                                                    a line, or a paragraph
##                                                    (wrap at width)
##   {"columns": [{"items", "width"?}], "separation"?}
##                                                    items side by side (_columns)
##   {"picture": Texture2D, "smooth"?, "height"?, "id"?}
##                                                    the map, the piece (an id:
##                                                    set_picture changes it)
##   {"list": [{"text", "call"?, "open", "colour"?, "selected"?} or {"head": text}],
##     "width"?, "height"?}                           lines to go down with the
##                                                    arrows, in a box that scrolls:
##                                                    landing on one calls "call",
##                                                    pressing it "open" (_list)
##   {"buttons": [{"text", "call", "icon"?, "colour"?}], "row": bool, "focus"?: int}
##                                                    text buttons, all one width
##                                                    ("step" for "call": a setting, _stepper)
##   {"cards": [{"title", "text"?, "picture", "call", "colour"?, "selected"?,
##     "focus"?}], "width"?: int}                     big picture cards in a row
##   {"nights": [{"n", "colour", "locked", "selected", "call", "open"?,
##     "boss"?}],
##     "style"?, "width"?, "height"?}                 the story's maps (NightMap):
##                                                    landing on a stop calls
##                                                    "call", pressing it "open"
##   {"legend": [keys], "thieves": [Color], "loot": Color}
##                                                    the map's legend (LEGEND)
##   {"table": [[cell, ...], ...], "widths": [int], "heads"?: int}
##                                                    short texts in rows and
##                                                    columns on a board (_table)
##   {"footer": text}                                 what to press
## Buttons work with the mouse, and with the arrows and Enter; the first one
## has the focus.
func show_menu(items: Array) -> void:
	_version.visible = false
	for c in _panel_box.get_children():
		c.queue_free()
	# What the items leave behind: rows of focusable controls, top to
	# bottom, for the arrows, and the control to start on.
	var st := MenuState.new()
	_named.clear()
	_pictures.clear()
	_nights.clear()
	_menu_map = null
	_titles.clear()
	for item in items:
		_menu_item(item, _panel_box, st)
	var rows := st.rows
	var first := st.first
	var focus_on := st.focus_on
	# Only a menu coming up over the game fades in; one replacing another
	# (a difficulty picked, a night chosen) is rebuilt in place, at once.
	if not _shown:
		_shown = true
		# The controls in it are brand new; only the frame around them was
		# made click-through by hide_panel.
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		(_panel.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_PASS
		_panel_box.mouse_filter = Control.MOUSE_FILTER_PASS
		if not _panel.visible:
			_panel.modulate.a = 0.0
		_panel.visible = true
		_fade_panel(1.0)
	for c in _play:
		c.visible = false
	_wire(rows)
	# Once laid out, up and down go by where things are on screen.
	_rows = rows
	_rewire.call_deferred(rows)
	if focus_on:
		first = focus_on
	if first:
		# The focus a menu opens with is not a move: no sound for it.
		_quiet = true
		first.grab_focus.call_deferred()
		set_deferred("_quiet", false)


## A menu being built: its rows of focusable controls, top to bottom, the
## first one and the one to start on, if not the first.
class MenuState:
	var rows: Array = []
	var first: Button = null
	var focus_on: Button = null


## One item of a menu (show_menu), added to parent.
func _menu_item(item: Dictionary, parent: BoxContainer, st: MenuState) -> void:
	if item.has("columns"):
		_columns(item, parent, st)
	elif item.has("title"):
		# Pixel faces run wide: the arcade title at about two thirds the size.
		var t := _label(int(item.get("size", 56) * 0.55), item.get("colour", Color("#f0c46a")), parent, true)
		t.text = item.title
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if item.get("align", "") == "left" else HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 14)
		t.add_theme_color_override("font_outline_color", Color("#2a150c"))
		t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 7)
		t.resized.connect(func() -> void: t.pivot_offset = t.size / 2)
		_titles.append(t)
		# Room for it to bob without brushing what comes next.
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		parent.add_child(gap)
	elif item.has("text"):
		var l := _label(int(item.get("size", 20) * 0.85), item.get("colour", C.text), parent)
		l.text = item.text
		if item.has("id"):
			_named[item.id] = l
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if item.get("align", "") == "left" else HORIZONTAL_ALIGNMENT_CENTER
		if item.get("wrap", false):
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(item.get("width", 560), 0)
	elif item.has("gap"):
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, item.gap)
		parent.add_child(gap)
	elif item.has("map"):
		# The plan on the folded paper map, unfolding as the screen opens.
		var stage := MapStage.new()
		parent.add_child(stage)
		stage.print_plan(item.map)
		stage.unfold()
		var r := TextureRect.new()
		r.texture = stage.get_texture()
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.custom_minimum_size = Vector2(MapStage.SIZE) * (float(item.get("height", 400.0)) / MapStage.SIZE.y)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		parent.add_child(r)
		# The arrows lean it, as in play.
		_menu_map = stage
	elif item.has("legend"):
		legend_row(parent, item.legend, item.get("thieves", []), item.get("loot", Color.WHITE))
	elif item.has("stage"):
		var stage: MenuStage = item.stage
		parent.add_child(stage)
		stage.active = true
		var r := TextureRect.new()
		r.texture = stage.get_texture()
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.custom_minimum_size = Vector2(stage.size) * (float(item.get("height", 200.0)) / stage.size.y)
		parent.add_child(r)
	elif item.has("picture"):
		var picture: Texture2D = item.picture
		var r := TextureRect.new()
		r.texture = picture
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var size := Vector2(picture.get_size())
		var k := minf(720.0 / size.x, float(item.get("height", 420.0)) / size.y)
		r.custom_minimum_size = size * k
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if item.get("smooth", false) else CanvasItem.TEXTURE_FILTER_NEAREST
		parent.add_child(r)
		if item.has("id"):
			_pictures[item.id] = r
	elif item.has("list"):
		_list(item, parent, st)
	elif item.has("cards"):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		parent.add_child(row)
		var line: Array = []
		for c in item.cards:
			var card := _card(c, item.get("width", 300), item.get("arrows", false))
			row.add_child(card)
			card.set_meta("selected", c.get("selected", false) or c.get("focus", false))
			line.append(card)
			if st.first == null or c.get("focus", false):
				st.first = card
		st.rows.append(line)
		if item.get("arrows", false):
			row.add_theme_constant_override("separation", 28)
			row.add_child(_card_arrow(">", line, 1))
			row.add_child(_card_arrow("<", line, -1))
			row.move_child(row.get_child(-1), 0)
			parent.add_child(_pedestal(line, item.get("width", 300)))
	elif item.has("nights"):
		# The nights as stops on a map, the road winding through them.
		var map := NightMap.new(item)
		map.custom_minimum_size = Vector2(item.get("width", 1120), item.get("height", 190))
		map.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		parent.add_child(map)
		var nights: Array = item.nights
		var line: Array = []
		for i in nights.size():
			var node := _night(nights[i])
			map.add_stop(node, nights[i].locked)
			if not nights[i].locked:
				line.append(node)
				node.set_meta("selected", nights[i].selected)
			if nights[i].get("selected", false):
				st.first = node
		for node in line:
			node.set_meta("sticky", true)
		st.rows.append(line)
	elif item.has("buttons"):
		var box: BoxContainer = HBoxContainer.new() if item.get("row", false) else VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 24 if item.get("row", false) else 10)
		parent.add_child(box)
		var line: Array = []
		for bi in item.buttons.size():
			var b: Dictionary = item.buttons[bi]
			var button := _button(b)
			# The one to start on, when it is not the first.
			if item.get("focus", -1) == bi:
				st.focus_on = button
			if not b.has("icon"):
				# big: the one thing to do next; small: the way back.
				if item.get("big", false):
					button.custom_minimum_size = Vector2(380, 62)
					button.add_theme_font_size_override("font_size", 17)
				elif item.get("small", false):
					button.custom_minimum_size = Vector2(item.get("width", 240), 38)
					button.add_theme_font_size_override("font_size", 10)
				else:
					button.custom_minimum_size = Vector2(240 if item.get("row", false) else 400, 42)
			box.add_child(button)
			if item.get("row", false):
				line.append(button)
			else:
				st.rows.append([button])
			if st.first == null:
				st.first = button
		if not line.is_empty():
			st.rows.append(line)
	elif item.has("table"):
		_table(item, parent)
	elif item.has("footer"):
		var f := _label(14, C.gold, parent, true)
		f.text = item.footer
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## A board of short texts: {"table": [[cell, ...], ...], "widths": [int, ...],
## "heads"?: int}. The first row is the heading, in gold arcade letters; the
## "heads" - 1 rows after it say a little more under it, small and dim. Below
## a brass rule, the first column names each row in the arcade face and the
## rest are in the plain one, to be read at a glance, on alternate stripes.
## A cell is a text, or {"text", "span"} to run across several columns.
func _table(item: Dictionary, parent: BoxContainer) -> void:
	var board := PanelContainer.new()
	var st := _frame(BRASS, false, false, 18)
	st.set_content_margin_all(14)
	st.content_margin_left = 16
	st.content_margin_right = 16
	board.add_theme_stylebox_override("panel", st)
	board.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(board)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	board.add_child(lines)
	var widths: Array = item.widths
	var rows: Array = item.table
	var heads: int = item.get("heads", 1)
	for r in rows.size():
		if r == heads:
			var rule := ColorRect.new()
			rule.color = GLASS_EDGE
			rule.custom_minimum_size = Vector2(0, 2)
			lines.add_child(rule)
		var stripe := PanelContainer.new()
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(1, 1, 1, 0.05) if r >= heads and (r - heads) % 2 == 0 else Color(0, 0, 0, 0)
		bg.set_corner_radius_all(8)
		stripe.add_theme_stylebox_override("panel", bg)
		lines.add_child(stripe)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 0)
		stripe.add_child(line)
		var col := 0
		for cell in rows[r]:
			var c: Dictionary = cell if cell is Dictionary else {"text": cell}
			var span: int = c.get("span", 1)
			var w := 0
			for k in span:
				w += int(widths[mini(col + k, widths.size() - 1)])
			var l: Label
			if r == 0:
				l = _label(11, C.gold, line, true)
			elif r < heads:
				l = _label(13, C.dim, line)
			elif col == 0:
				l = _label(11, CREAM, line, true)
			else:
				l = _label(18, C.text, line)
			l.text = c.text
			l.custom_minimum_size = Vector2(w, 20 if r < heads else 30)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if col == 0 else HORIZONTAL_ALIGNMENT_CENTER
			if col == 0:
				# The row's name clear of the stripe's rounded end.
				l.custom_minimum_size.x -= 12
				var pad := Control.new()
				pad.custom_minimum_size = Vector2(12, 0)
				line.add_child(pad)
				line.move_child(pad, 0)
			col += span


## Items side by side: {"columns": [{"items": [...], "width"?: int}, ...],
## "separation"?: int}, each column its own stack of menu items.
func _columns(item: Dictionary, parent: BoxContainer, st: MenuState) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", item.get("separation", 40))
	parent.add_child(row)
	for col in item.columns:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", col.get("separation", 10))
		box.alignment = BoxContainer.ALIGNMENT_CENTER if col.get("middle", false) else BoxContainer.ALIGNMENT_BEGIN
		box.custom_minimum_size.x = col.get("width", 0)
		row.add_child(box)
		for sub in col.items:
			_menu_item(sub, box, st)


## Labels a menu gave an id, to change without rebuilding it; pictures too.
var _named := {}
var _pictures := {}
## while a menu takes its first focus
var _quiet := false
## the menu's titles, bobbing gently
var _titles: Array[Label] = []
var _clock := 0.0
## the path's night buttons, to move the "picked" look along with the focus
var _nights: Array[Button] = []
## the focusable rows of the menu on screen
var _rows: Array = []


func set_text(id: String, text: String, colour: Color) -> void:
	if _named.has(id):
		var l: Label = _named[id]
		l.text = text
		l.add_theme_color_override("font_color", colour)


## A picture a menu gave an id, changed in place: the new one fits the room
## the first took.
func set_picture(id: String, picture: Texture2D) -> void:
	if _pictures.has(id):
		(_pictures[id] as TextureRect).texture = picture


## A list in a box that scrolls with the focus: {"list": [...], "width"?,
## "height"?}. Each line is {"text", "call"?, "open", "colour"?, "selected"?}:
## landing on it (the arrows, the mouse) calls "call" — to show it beside the
## list — and pressing it calls "open". {"head": text} is a heading between
## lines. The line "selected" is the one the menu opens on.
func _list(item: Dictionary, parent: BoxContainer, st: MenuState) -> void:
	var width: int = item.get("width", 360)
	var frame := PanelContainer.new()
	var fs := _frame(BRASS, false, false, 18)
	fs.set_content_margin_all(10)
	frame.add_theme_stylebox_override("panel", fs)
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, item.get("height", 420))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	frame.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	scroll.add_child(box)
	for e in item.list:
		if e.has("head"):
			var h := _label(10, C.gold, box, true)
			h.text = e.head
			h.custom_minimum_size = Vector2(0, 30)
			h.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			continue
		var b := Button.new()
		b.text = e.text
		b.focus_mode = Control.FOCUS_ALL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.clip_text = true
		b.custom_minimum_size = Vector2(width - 16, 34)
		b.add_theme_font_override("font", ARCADE)
		b.add_theme_font_size_override("font_size", 10)
		var colour: Color = e.get("colour", CREAM)
		for state in ["normal", "hover", "pressed", "focus"]:
			var s := _frame(colour, state != "normal", false, 12)
			if state == "normal":
				s.bg_color = Color(0, 0, 0, 0)
				s.border_color = Color(0, 0, 0, 0)
				s.shadow_color = Color(0, 0, 0, 0)
			s.set_content_margin_all(6)
			s.content_margin_left = 14
			b.add_theme_stylebox_override(state, s)
		b.add_theme_color_override("font_color", colour)
		for key in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(key, GLOW_TEXT)
		b.focus_entered.connect(func() -> void:
			if not _quiet:
				ui_sound.emit("nav")
			if e.has("call"):
				e.call.call())
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		b.pressed.connect(e.open)
		b.pressed.connect(func() -> void: ui_sound.emit("ok"))
		box.add_child(b)
		st.rows.append([b])
		if st.first == null:
			st.first = b
		if e.get("selected", false):
			st.focus_on = b


## The arrows go where the eye expects: left and right along a row (round
## the ends), up and down to the row above or below — to its picked control
## if it has one, else to the one in the same place along it.
func _wire(rows: Array) -> void:
	rows = rows.filter(func(r): return not (r as Array).is_empty())
	var flat: Array = []
	for r in rows:
		flat.append_array(r)
	var towards := func(row: Array, i: int, n: int) -> Control:
		for c in row:
			if (c as Control).get_meta("selected", false):
				return c
		if row.size() == 1 or n == 1:
			return row[(row.size() - 1) / 2]
		return row[roundi(float(i) / (n - 1) * (row.size() - 1))]
	_link(rows, towards)
	for k in flat.size():
		var c: Control = flat[k]
		c.focus_next = c.get_path_to(flat[(k + 1) % flat.size()])
		c.focus_previous = c.get_path_to(flat[(k - 1 + flat.size()) % flat.size()])


## Up and down again, now that the menu has its layout: to the control
## nearest across in the next row. The path of nights always takes you back
## to the night picked (landing on another would pick it); from a lone
## button, a row gives its picked control or its middle one.
func _rewire(rows: Array) -> void:
	await get_tree().process_frame
	rows = rows.filter(func(r): return not (r as Array).is_empty() and is_instance_valid(r[0]))
	if rows.is_empty():
		return
	var towards := func(row: Array, i: int, n: int, from: Control) -> Control:
		var picked: Control = null
		for c in row:
			if (c as Control).get_meta("selected", false):
				picked = c
		if picked and ((row[0] as Control).get_meta("sticky", false) or n == 1):
			return picked
		if n == 1 and row.size() > 1:
			return row[(row.size() - 1) / 2]
		var x := from.get_global_rect().get_center().x
		var best: Control = row[0]
		for c in row:
			if absf((c as Control).get_global_rect().get_center().x - x) < absf(best.get_global_rect().get_center().x - x):
				best = c
		return best
	_link(rows, towards, true)


func _link(rows: Array, towards: Callable, by_place := false) -> void:
	for ri in rows.size():
		var row: Array = rows[ri]
		var up: Array = rows[(ri - 1 + rows.size()) % rows.size()]
		var down: Array = rows[(ri + 1) % rows.size()]
		for i in row.size():
			var c: Control = row[i]
			c.focus_neighbor_left = c.get_path_to(row[(i - 1 + row.size()) % row.size()])
			c.focus_neighbor_right = c.get_path_to(row[(i + 1) % row.size()])
			var top: Control = towards.call(up, i, row.size(), c) if by_place else towards.call(up, i, row.size())
			var bottom: Control = towards.call(down, i, row.size(), c) if by_place else towards.call(down, i, row.size())
			c.focus_neighbor_top = c.get_path_to(top)
			c.focus_neighbor_bottom = c.get_path_to(bottom)


## A menu button: a framed line of text, or a big icon (the thieves on the
## title), lit up on hover and focus.
func _button(b: Dictionary) -> Button:
	var button := Button.new()
	button.text = b.get("text", "")
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", ARCADE)
	button.add_theme_font_size_override("font_size", 12)
	var colour: Color = b.get("colour", C.safe)
	# selected: the tab you are on, marked even without the focus.
	var selected: bool = b.get("selected", false)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := _frame(colour, state != "normal", selected, 22)
		st.set_content_margin_all(12)
		st.content_margin_left = 28
		st.content_margin_right = 28
		button.add_theme_stylebox_override(state, st)
	_lift(button)
	button.add_theme_color_override("font_color", C.gold if selected else CREAM)
	for key in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, GLOW_TEXT)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if b.has("icon"):
		var icon: Texture2D = b.icon
		button.icon = icon
		button.expand_icon = true
		# As tall as the single thief, as wide as however many there are.
		var h := 120.0
		var w := h * icon.get_width() / icon.get_height()
		button.custom_minimum_size = Vector2(w + 40, h + 30)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	if b.has("glyph"):
		button.icon = glyph(b.glyph)
		button.add_theme_constant_override("icon_max_width", 20)
		button.add_theme_constant_override("h_separation", 14)
		button.add_theme_color_override("icon_normal_color", CREAM)
		for key in ["icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(key, GLOW)
	if b.has("step"):
		_stepper(button, b.step)
		button.pressed.connect(func() -> void: ui_sound.emit("ok"))
	else:
		button.pressed.connect(b.call)
		var back: bool = String(b.get("text", "")).begins_with("<")
		button.pressed.connect(func() -> void: ui_sound.emit("back" if back else "ok"))
	return button


## A button that holds a setting: {"text", "step"} instead of "call", where
## step(dir) changes it and returns the button's new text. Enter or a click
## is dir 0 (the next value, round the end), ← and → are -1 and +1. The text
## changes in place, so the focus stays put for the next press. A button in a
## column has no neighbours across, so the arrows are free for this.
func _stepper(button: Button, step: Callable) -> void:
	button.pressed.connect(func() -> void: button.text = step.call(0))
	button.gui_input.connect(func(event: InputEvent) -> void:
		for dir in [-1, 1]:
			if event.is_action_pressed("ui_left" if dir < 0 else "ui_right", true):
				button.text = step.call(dir)
				button.accept_event())


## The frame every menu control shares: a pill of dark glass with a thin
## pale rim and a soft shadow; with the focus the rim turns warm and glows.
## selected (the choice in force) keeps a rim of its colour while it waits.
func _frame(colour: Color, lit: bool, selected := false, radius := 26) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = GLASS_LIT if lit else GLASS
	st.set_corner_radius_all(radius)
	st.anti_aliasing = true
	st.border_color = GLOW if lit else (colour.lerp(GLOW, 0.5) if selected else GLASS_EDGE)
	st.set_border_width_all(3 if lit or selected else 2)
	if lit:
		st.shadow_color = Color(GLOW, 0.45)
		st.shadow_size = 16
		st.shadow_offset = Vector2.ZERO
	else:
		st.shadow_color = Color(0, 0, 0, 0.35)
		st.shadow_size = 6
		st.shadow_offset = Vector2(0, 3)
	return st


## A picture clipped to rounded corners.
func _round_corners(r: TextureRect, box: Vector2, radius: float) -> void:
	var shader := Shader.new()
	shader.code = ROUNDED_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("box", box)
	m.set_shader_parameter("radius", radius)
	r.material = m


## Grows a little under the mouse or the focus; the mouse takes the focus,
## so the arrows and the mouse never point at two different things.
func _lift(c: Control, grow := 1.07, rest := 1.0) -> void:
	c.focus_entered.connect(func() -> void:
		if not _quiet:
			ui_sound.emit("nav"))
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2)
	c.mouse_entered.connect(func() -> void:
		if c is BaseButton and not (c as BaseButton).disabled:
			c.grab_focus())
	# A springy pop, overshooting a little, like a jelly button.
	c.focus_entered.connect(func() -> void:
		c.scale = Vector2(0.96, 1.04)
		create_tween().tween_property(c, "scale", Vector2.ONE * grow, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	c.focus_exited.connect(func() -> void: create_tween().tween_property(c, "scale", Vector2.ONE * rest, 0.15).set_trans(Tween.TRANS_QUAD))
	if c is BaseButton:
		# A squash on the press.
		(c as BaseButton).button_down.connect(func() -> void: c.scale = Vector2(1.1, 0.92))


const DIM_CARD := Color(0.7, 0.7, 0.8)


## An arrow beside a row of cards: a click moves the focus to the card
## beside the one that has it, round the ends. It never takes the focus.
func _card_arrow(text: String, cards: Array, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", ARCADE)
	b.add_theme_font_size_override("font_size", 28)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, GLOW if key != "font_color" else CREAM)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		var at := maxi(0, cards.find(get_viewport().gui_get_focus_owner()))
		(cards[posmod(at + dir, cards.size())] as Control).grab_focus())
	return b


## Under a row of cards, a stone plinth lit from above that slides under the
## card with the focus: a slab with a warm glowing lip on a wider, darker one.
func _pedestal(cards: Array, width: int) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 34)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plinth := Control.new()
	plinth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plinth.size = Vector2(width + 120, 34)
	holder.add_child(plinth)
	var slabs := [[Rect2(40, 0, width + 40, 16), Color("#1d1428"), true], [Rect2(0, 14, width + 120, 18), Color("#110b19"), false]]
	for s in slabs:
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.position = s[0].position
		panel.size = s[0].size
		var st := StyleBoxFlat.new()
		st.bg_color = s[1]
		st.set_corner_radius_all(4)
		if s[2]:
			st.border_color = GLOW
			st.border_width_top = 2
			st.shadow_color = Color(GLOW, 0.35)
			st.shadow_size = 14
		panel.add_theme_stylebox_override("panel", st)
		plinth.add_child(panel)
	plinth.move_child(plinth.get_child(1), 0)
	var place := func(card: Control, slide: bool) -> void:
		var x := card.global_position.x - holder.global_position.x + card.size.x / 2 - plinth.size.x / 2
		if slide:
			create_tween().tween_property(plinth, "position:x", x, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		else:
			plinth.position.x = x
	for card in cards:
		(card as Control).focus_entered.connect(func() -> void: place.call(card, true))
	holder.resized.connect(func() -> void:
		var focused := get_viewport().gui_get_focus_owner()
		place.call(focused if focused in cards else cards[0], false))
	return holder


static var _glyphs := {}


## A small line icon for a button, drawn here at four samples a pixel:
## "settings" a cog, "quit" an arrow going into a door.
static func glyph(kind: String) -> ImageTexture:
	if _glyphs.has(kind):
		return _glyphs[kind]
	const N := 36
	const SS := 4
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var hit := 0
			for sy in SS:
				for sx in SS:
					var p := Vector2(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS) - Vector2(N, N) / 2
					if _glyph_in(kind, p):
						hit += 1
			img.set_pixel(x, y, Color(1, 1, 1, float(hit) / (SS * SS)))
	_glyphs[kind] = ImageTexture.create_from_image(img)
	return _glyphs[kind]


static func _glyph_in(kind: String, p: Vector2) -> bool:
	if kind == "settings":
		var r := p.length()
		var teeth := 13.0 if cos(p.angle() * 8.0) > 0.2 else 10.0
		return r < teeth and r > 4.5
	# quit: an open door (a frame on the right, open on the left) and an
	# arrow going in.
	var frame := Rect2(-5, -13, 18, 26)
	var inside := frame.grow(-3)
	var in_frame := frame.has_point(p) and not inside.has_point(p) and not (p.x < -1 and absf(p.y) < 6)
	var shaft := p.x > -15 and p.x < 5 and absf(p.y) < 1.6
	var head := p.x >= 0 and p.x < 8 and absf(p.y) < 8 - p.x
	return in_frame or shaft or head


## A big card: a picture, a title and a line under it.
## back: the cards waiting sit smaller, further back (the title's row).
func _card(c: Dictionary, width: int, back := false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var colour: Color = c.get("colour", C.safe)
	var selected: bool = c.get("selected", false)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := _frame(colour, state != "normal", selected, 22)
		if state != "normal":
			st.set_border_width_all(4)
		st.set_content_margin_all(12)
		b.add_theme_stylebox_override(state, st)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 12
	box.offset_right = -12
	box.offset_top = 12
	box.offset_bottom = -12
	b.add_child(box)
	var height := 0.0
	# A live 3D stage: shown through its texture, animated while focused.
	if c.has("stage"):
		var stage: MenuStage = c.stage
		b.add_child(stage)
		c.picture = stage.get_texture()
		b.focus_entered.connect(func() -> void: stage.active = true)
		b.focus_exited.connect(func() -> void: stage.active = false)
	if c.has("picture"):
		var picture: Texture2D = c.picture
		var r := TextureRect.new()
		r.texture = picture
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if c.has("stage") else CanvasItem.TEXTURE_FILTER_NEAREST
		var k := (width - 24.0) / picture.get_width()
		r.custom_minimum_size = Vector2(width - 24, picture.get_height() * k)
		_round_corners(r, r.custom_minimum_size, 16.0)
		height += r.custom_minimum_size.y
		box.add_child(r)
	# The title on one line: the pixel font is one em a character, so a long
	# title on a narrow card takes a smaller size.
	var title_size: int = mini(c.get("title_size", 13), floori((width - 30.0) / maxi(1, String(c.title).length())))
	var t := _label(title_size, CREAM, box, true)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	t.text = c.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height += 24
	if c.has("text"):
		var l := _label(12, C.dim, box)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		l.text = c.text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width - 24, 0)
		# Room for every line it wraps to (about 6.5 px a character).
		var lines := ceili(l.text.length() * 6.5 / (width - 24))
		height += 10 + 17 * maxi(2, lines)
	b.custom_minimum_size = Vector2(width, height + 34)
	# A card to look at, not to press (the player-select seats).
	if c.get("static", false):
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if c.has("stage"):
			(c.stage as MenuStage).active = c.get("animate", false)
		# Waiting for someone: dimmed.
		if c.get("dim", false):
			b.modulate = Color(1, 1, 1, 0.5)
		return b
	b.pressed.connect(c.call)
	b.pressed.connect(func() -> void: ui_sound.emit("ok"))
	var rest := 0.9 if back else 1.0
	_lift(b, 1.1, rest)
	b.scale = Vector2.ONE * rest
	# The ones waiting sit back in the dark; the one with the focus comes up.
	b.modulate = DIM_CARD
	b.focus_entered.connect(func() -> void: create_tween().tween_property(b, "modulate", Color.WHITE, 0.2))
	b.focus_exited.connect(func() -> void: create_tween().tween_property(b, "modulate", DIM_CARD, 0.2))
	return b


## One night on the story's path: a round stone with its number, in the
## colour of its piece once reached, grey and shut before.
func _night(n: Dictionary) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE if n.locked else Control.FOCUS_ALL
	b.text = "?" if n.locked else str(n.n)
	b.disabled = n.locked
	b.add_theme_font_override("font", ARCADE)
	b.add_theme_font_size_override("font_size", 12)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.set_meta("colour", n.colour)
	b.set_meta("locked", n.locked)
	# A museum's big job: ringed in gold and a size up, open or not.
	b.set_meta("boss", n.get("boss", false))
	b.add_theme_color_override("font_disabled_color", Color("#6d5a78"))
	_night_look(b, n.selected)
	if not n.locked:
		# Landing on a night picks it; the picked look moves with it.
		b.focus_entered.connect(func() -> void:
			for other in _nights:
				_night_look(other, other == b)
				other.set_meta("selected", other == b)
			_rewire(_rows)
			n.call.call())
		b.pressed.connect(n.get("open", n.call))
		_nights.append(b)
	_lift(b)
	return b


func _night_look(b: Button, picked: bool) -> void:
	var colour: Color = b.get_meta("colour")
	var locked: bool = b.get_meta("locked")
	var boss: bool = b.get_meta("boss", false)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(25 if picked and not locked else 21)
		st.anti_aliasing = true
		st.shadow_size = 1
		st.shadow_offset = Vector2(0, 5)
		if locked:
			st.bg_color = Color("#2a1d2e")
			st.border_color = BRASS.darkened(0.45) if boss else Color("#3d2c40")
			st.set_border_width_all(4 if boss else 2)
			st.shadow_color = WALNUT_EDGE
		elif picked:
			# The night in force: in full colour, a thick brass ring and a glow
			# of its own colour round it, so it stands out from the rest.
			st.bg_color = colour
			st.border_color = BRASS.lightened(0.25)
			st.set_border_width_all(5)
			st.shadow_color = Color(colour.lightened(0.3), 0.8)
			st.shadow_size = 12
			st.shadow_offset = Vector2.ZERO
		else:
			# The others stay back: dim, a thin rim, lit only while the
			# cursor is on them.
			var lit: bool = state != "normal"
			st.bg_color = colour.darkened(0.25) if lit else colour.darkened(0.6)
			st.border_color = CREAM if lit else (BRASS if boss else colour.darkened(0.35))
			st.set_border_width_all(4 if boss else (3 if lit else 2))
			st.shadow_color = WALNUT_EDGE
		b.add_theme_stylebox_override(state, st)
	# Dark numbers on the picked night (light ones vanish on a pale colour).
	b.add_theme_color_override("font_color", INK if picked else CREAM.darkened(0.15))
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_hover_color", INK if picked else CREAM)
	# And bigger than the rest, whether or not the cursor is on it.
	b.pivot_offset = b.size / 2
	var grow := 8.0 if boss else 0.0
	b.custom_minimum_size = Vector2(50, 50) + Vector2(grow, grow) if picked else Vector2(42, 42) + Vector2(grow, grow)


## The thief on the title screen, as the web draws it: a hooded figure in
## pixels with the slit of a visor. One per player, side by side.
static func thief_icon(colours: Array) -> ImageTexture:
	var cell := 10
	var img := Image.create(12 * colours.size() - 2, 14, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in colours.size():
		var x0 := i * 12
		var c: Color = colours[i]
		for r in [[3, 0, 4, 1], [2, 1, 6, 3], [2, 5, 6, 4], [1, 6, 1, 3], [8, 6, 1, 3], [2, 10, 2, 4], [6, 10, 2, 4]]:
			img.fill_rect(Rect2i(x0 + r[0], r[1], r[2], r[3]), c)
		img.fill_rect(Rect2i(x0 + 3, 2, 4, 1), Color("#0b0820"))
	img.resize(img.get_width() * cell, img.get_height() * cell, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## The simple case: a heading, some lines, maybe the map, and a footer.
func show_panel(title: String, title_colour: Color, lines: Array, footer: String, picture: Texture2D = null) -> void:
	var items: Array = [{"title": title, "colour": title_colour}]
	for line in lines:
		items.append({"text": line})
	if picture:
		items.append({"picture": picture})
	items.append({"footer": footer})
	show_menu(items)


## Fades the menu away. It is gone for the game straight away: it lets go of
## the focus and lets clicks through while it fades, so a menu on its way out
## never swallows a key or a click. Calling it again when hidden does nothing.
func hide_panel() -> void:
	for c in _play:
		c.visible = true
	if not _shown:
		return
	_shown = false
	get_viewport().gui_release_focus()
	_panel.propagate_call("set", ["mouse_filter", Control.MOUSE_FILTER_IGNORE])
	_panel.propagate_call("set", ["focus_mode", Control.FOCUS_NONE])
	_fade_panel(0.0)


func _fade_panel(to: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_panel, "modulate:a", to, FADE_S * absf(to - _panel.modulate.a))
	if to == 0.0:
		_fade.tween_callback(func() -> void:
			_panel.visible = false
			backdrop(null))


## Behind the menus, MENU_PICTURE looking at focus (a point in it, see
## SPOTS), or the museum wall with null. Menu to menu it pans and
## fades across; a menu coming up takes it at once. The wall comes back when
## the menu goes away, so the menus over the game keep it.
func backdrop(focus: Variant) -> void:
	var m := _panel.material as ShaderMaterial
	if focus != null and m.get_shader_parameter("picture") == null:
		if not ResourceLoader.exists(MENU_PICTURE):
			return
		m.set_shader_parameter("picture", load(MENU_PICTURE))
	if _backdrop:
		_backdrop.kill()
	var cover := 0.0 if focus == null else 1.0
	if focus != null:
		_focus = focus
	if not (_panel.visible and _panel.modulate.a > 0.5):
		m.set_shader_parameter("cover", cover)
		m.set_shader_parameter("focus", _focus)
		return
	_backdrop = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Through set_shader_parameter: a parameter never set yet is not a
	# property the tween can find.
	var was_cover: Variant = m.get_shader_parameter("cover")
	var was_focus: Variant = m.get_shader_parameter("focus")
	_backdrop.tween_method(func(v: float) -> void: m.set_shader_parameter("cover", v), 0.0 if was_cover == null else float(was_cover), cover, 0.5)
	if was_focus != null and typeof(was_focus) == typeof(_focus):
		_backdrop.tween_method(func(v: Variant) -> void: m.set_shader_parameter("focus", v), was_focus, _focus, 1.4)
	else:
		m.set_shader_parameter("focus", _focus)



func menu_open() -> bool:
	return _shown


## The IA panel: one card per guard. entries are {"name", "title", "colour",
## "options": [[label, probability]], "note"}.
## The version in the bottom right corner, on the title only (show_menu
## hides it again).
func show_version() -> void:
	var view := get_viewport().get_visible_rect().size
	_version.position = view - _version.get_minimum_size() - Vector2(16, 12)
	_version.visible = true
	move_child(_version, get_child_count() - 1)


func set_ia(on: bool, entries: Array) -> void:
	_ia.visible = on and not _shown
	if not _ia.visible:
		return
	var view := get_viewport().get_visible_rect().size
	_ia.position = Vector2(view.x - 324, 64)
	for c in _ia_box.get_children():
		c.queue_free()
	for e in entries:
		var name := _label(17, C.text, _ia_box)
		name.text = "%s · %s" % [e.name, e.title]
		name.add_theme_color_override("font_color", e.get("colour", C.text))
		for o in e.get("options", []):
			var line := _label(13, C.dim, _ia_box)
			var bar := "▮".repeat(roundi(float(o[1]) * 12))
			line.text = "  %-18s %s %d%%" % [o[0], bar, roundi(float(o[1]) * 100)]
		if e.has("note"):
			var n := _label(13, C.dim, _ia_box)
			n.text = "  " + e.note


## Take the map out (or put it away) during play: it unfolds as it comes.
func show_map(plan: Image, thief_colours: Array = []) -> void:
	for c in _map_legend.get_children():
		c.queue_free()
	var keys := ["thief", "gem", "exit", "prop"]
	if Heist.team and not Heist.taken:
		keys.append("panel")
	legend_row(_map_legend, keys, thief_colours, Color(Heist.loot.colour))
	var hint := _label(12, C.dim, _map_legend)
	hint.text = Text.t("HUD_MAP_HIDE")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_map_stage.print_plan(plan)
	_map_stage.process_mode = Node.PROCESS_MODE_INHERIT
	_map_stage.unfold()
	_map.visible = true


func update_map(plan: Image) -> void:
	_map_stage.print_plan(plan)


## Which way the controls push while the map is out, for it to lean.
func push_map(v: Vector2) -> void:
	_map_stage.push(v)


func hide_map() -> void:
	_map.visible = false
	_map_stage.process_mode = Node.PROCESS_MODE_DISABLED


## The map as taken out mid-job, on parchment: the plan, where each thief is
## now, the piece (or where it lies), the door, and the alarm panel for two.
## No guards: a map does not know where they are.
## The map you take out mid-job: the plan with its cases, the things you
## can knock over, the piece, the way out and where the thieves are — the
## important ones as icons, all of them in the legend under it.
static func live_map(thieves: Array[Thief], colours: Array) -> Image:
	var none: Array[Guard] = []
	return _draw_map(thieves, colours, none, [])


## The plan on parchment, before the job: the same map, with the route in
## ink dots, where you come in (the thieves' icons) and where each guard
## starts (a red cross).
static func plan_map(guards: Array[Guard], colours: Array) -> Image:
	var none: Array[Thief] = []
	return _draw_map(none, [], guards, colours)


## Pixels a tile: the plan fills about MAP_WIDTH whatever the museum's size,
## so the icons (a fixed size in pixels) read the same on every map.
const MAP_WIDTH := 720.0
const MAP_INK := Color("#1c1210")
const MAP_FLOOR := Color("#e8d6b4")
const MAP_CASE := Color("#b89a70")
const MAP_PROP := Color("#c4906a")
const MAP_ROUTE := Color("#5a3a22")
const MAP_WALL := Color("#4a2f22")
const MAP_GUARD := Color("#c42a3c")

## The alarm panel as a pixel mask: '#' orange, 'w' the dark mark.
const ICON_PANEL := [
	".#####.",
	"###w###",
	"###w###",
	"###w###",
	"#######",
	"###w###",
	".#####.",
]


static func _draw_map(thieves: Array[Thief], colours: Array, guards: Array[Guard], start_colours: Array) -> Image:
	var s := clampi(int(MAP_WIDTH / Museum.w), 8, 32)
	var img := Image.create(Museum.w * s, Museum.h * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# The plan in three tones: floor, the cases on it, walls; and what can be
	# knocked over, still standing, a tile a shade off the cases.
	for y in Museum.h:
		for x in Museum.w:
			if Museum.is_outside(x, y):
				continue
			var t := Museum.grid[y * Museum.w + x]
			img.fill_rect(Rect2i(x * s, y * s, s, s), MAP_WALL if t == Tiles.WALL else (MAP_CASE if t == Tiles.COVER else MAP_FLOOR))
	for p in Props.list:
		if not p.fallen:
			img.fill_rect(Rect2i(p.tile.x * s, p.tile.y * s, s, s), MAP_PROP)
	var at := func(p: Vector2) -> Vector2i: return Vector2i(int(p.x * s), int(p.y * s))
	var mid := func(t: Vector2i) -> Vector2: return Vector2(t.x + 0.5, t.y + 0.5)
	# The plan, before the job: the way from the way in to the piece to the door.
	if not start_colours.is_empty():
		var d := maxi(6, s / 2)
		for i in Heist.route.size():
			if i % 2 == 0:
				var t: Vector2i = Heist.route[i]
				img.fill_rect(Rect2i(t.x * s + s / 2 - d / 2, t.y * s + s / 2 - d / 2, d, d), MAP_ROUTE)
	# The door, in green, and its sign just inside it.
	var door: Vector2i = Heist.exit + Heist.exit_face
	img.fill_rect(Rect2i(door.x * s, door.y * s, s, s), C.green)
	if Heist.team and not Heist.taken:
		_stamp(img, ICON_PANEL, at.call(mid.call(Heist.panel)), 4, {"#": Color("#ff922b"), "w": MAP_INK})
		if Heist.panel2.x >= 0:
			_stamp(img, ICON_PANEL, at.call(mid.call(Heist.panel2)), 4, {"#": Color("#ff922b"), "w": MAP_INK})
	# The piece: a gem in its colour, sparkling, wherever it is.
	# The piece: a diamond in its colour, giving off light.
	var gem := func(p: Vector2, r: int) -> void:
		var c: Vector2i = (at.call(p) as Vector2i).clamp(Vector2i(r * 2, r * 2), img.get_size() - Vector2i(r * 2, r * 2))
		_diamond(img, c, r, Color(Heist.loot.colour))
	if not Heist.taken:
		gem.call(mid.call(Heist.at), 20)
	elif Heist.dropped != Vector2.INF:
		gem.call(Heist.dropped, 16)
	for g in guards:
		_square(img, at.call(Vector2(g.x, g.y)), 12, MAP_GUARD)
	# The way out: the kunai that points the way in play, green, through the
	# door and pointing out.
	_kunai(img, at.call(mid.call(Heist.exit) + Vector2(Heist.exit_face) * 0.3), Vector2(Heist.exit_face), 1.6, C.green)
	# Where you come in: a dot for each thief who will, side by side.
	for i in start_colours.size():
		var off := Vector2((i - (start_colours.size() - 1) / 2.0) * 34.0 / s, 0)
		_dot(img, at.call(mid.call(Heist.start) + off), 14, start_colours[i], MAP_INK)
	for i in thieves.size():
		var p := thieves[i]
		if p.out:
			continue
		var c: Vector2i = at.call(Vector2(p.x, p.y))
		# The piece rides along with whoever has it, glowing behind them.
		if Heist.carrier == p.id:
			_glow(img, c, 44, Color(Heist.loot.colour))
		_dot(img, c, 14, colours[i], Color.WHITE)
	return img


## A thief: a disc in its colour with a ring round it.
static func _dot(img: Image, c: Vector2i, r: int, colour: Color, ring: Color) -> void:
	_disc(img, c, r + 3, MAP_INK)
	_disc(img, c, r + 1, ring)
	_disc(img, c, r - 2, colour)


## A guard: a red square, outlined.
static func _square(img: Image, c: Vector2i, half: int, colour: Color) -> void:
	img.fill_rect(Rect2i(c.x - half - 3, c.y - half - 3, half * 2 + 6, half * 2 + 6), MAP_INK)
	img.fill_rect(Rect2i(c.x - half, c.y - half, half * 2, half * 2), colour)


## Light spilling round something bright: blended over what is under it,
## strongest in the middle and gone at r.
static func _glow(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	var lit := colour.lightened(0.35)
	for y in range(maxi(0, c.y - r), mini(img.get_height(), c.y + r + 1)):
		for x in range(maxi(0, c.x - r), mini(img.get_width(), c.x + r + 1)):
			var d := Vector2(x - c.x, y - c.y).length() / r
			if d >= 1.0:
				continue
			var k := pow(1.0 - d, 1.6) * 0.85
			var under := img.get_pixel(x, y)
			var mixed := under.lerp(lit, k)
			mixed.a = maxf(under.a, k)
			img.set_pixel(x, y, mixed)


## The piece: a diamond (a square on its point) in its colour, lighter on
## its upper facets with a white glint, in a halo of its own light with
## four rays.
static func _diamond(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	_glow(img, c, r * 3, colour)
	for k in 4:
		var dir := Vector2.from_angle(k * PI / 2 + PI / 4)
		for t in range(r + 4, r * 2 + 2):
			var q := Vector2(c) + dir * t
			img.fill_rect(Rect2i(int(q.x) - 1, int(q.y) - 1, 3, 3), Color(1, 1, 0.9).lerp(colour.lightened(0.5), float(t - r) / (r + 2)))
	for pass_n in 2:
		var rr := r + 3 - pass_n * 3
		var fill: Color = MAP_INK if pass_n == 0 else colour
		for dy in range(-rr, rr + 1):
			var half := rr - absi(dy)
			img.fill_rect(Rect2i(c.x - half, c.y + dy, half * 2 + 1, 1), fill)
	for dy in range(-r + 2, 0):
		var half := r - absi(dy) - 2
		img.fill_rect(Rect2i(c.x - half, c.y + dy, half * 2 + 1, 1), colour.lightened(0.3))
	img.fill_rect(Rect2i(c.x - r / 3, c.y - r / 2, r / 4 + 2, r / 4 + 2), Color.WHITE)


## The HUD's kunai (KUNAI_BLADE) scaled by k, centred on c and pointing
## along dir, outlined.
static func _kunai(img: Image, c: Vector2i, dir: Vector2, k: float, colour: Color) -> void:
	var angle := dir.angle()
	var blade := PackedVector2Array()
	for q in KUNAI_BLADE:
		# Centred on its length: the blade runs from -12 to 30.
		blade.append(((q - Vector2(9, 0)) * k).rotated(angle))
	var ring: PackedVector2Array = Geometry2D.offset_polygon(blade, 3.5)[0]
	var reach := int(30 * k) + 4
	for y in range(maxi(0, c.y - reach), mini(img.get_height(), c.y + reach + 1)):
		for x in range(maxi(0, c.x - reach), mini(img.get_width(), c.x + reach + 1)):
			var p := Vector2(x - c.x, y - c.y)
			if Geometry2D.is_point_in_polygon(p, blade):
				img.set_pixel(x, y, colour)
			elif Geometry2D.is_point_in_polygon(p, ring):
				img.set_pixel(x, y, MAP_INK)


## What the map's legend lists, in this order: the icon and its words (keys
## into Text).
const LEGEND := {
	"thief": "LEGEND_THIEF", "gem": "LEGEND_GEM", "exit": "LEGEND_EXIT", "guard": "LEGEND_GUARD",
	"prop": "LEGEND_PROP", "route": "LEGEND_ROUTE", "panel": "LEGEND_PANEL",
}


## A legend icon: the map's own mark, drawn small on its own.
static func legend_icon(key: String, colour := Color.WHITE) -> ImageTexture:
	var img := Image.create(64, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2i(32, 20)
	match key:
		"thief":
			img = Image.create(40, 40, false, Image.FORMAT_RGBA8)
			img.fill(Color(0, 0, 0, 0))
			_dot(img, Vector2i(20, 20), 11, colour, MAP_INK)
		"gem": _diamond(img, c, 9, colour)
		"guard": _square(img, c, 10, MAP_GUARD)
		"panel": _stamp(img, ICON_PANEL, c, 4, {"#": Color("#ff922b"), "w": MAP_INK})
		"prop":
			img.fill_rect(Rect2i(c.x - 12, c.y - 12, 24, 24), MAP_WALL)
			img.fill_rect(Rect2i(c.x - 10, c.y - 10, 20, 20), MAP_PROP)
		"route":
			for k in 3:
				img.fill_rect(Rect2i(10 + k * 17, 15, 10, 10), Color("#e8d6b4"))
		"exit": _kunai(img, c, Vector2.RIGHT, 1.2, C.green)
	return ImageTexture.create_from_image(img)


## The legend as a row: each entry its icon and its words. thief_colours
## paints the thieves' icon, loot_colour the gem.
func legend_row(parent: Node, keys: Array, thief_colours: Array, loot_colour: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	for key in keys:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		row.add_child(entry)
		var icons: Array = thief_colours if key == "thief" else [loot_colour if key == "gem" else Color.WHITE]
		for colour in icons:
			var r := TextureRect.new()
			r.texture = legend_icon(key, colour)
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.custom_minimum_size = Vector2(r.texture.get_width(), r.texture.get_height()) * 0.8
			entry.add_child(r)
		var l := _label(14, Color("#e8d6b4"), entry)
		l.text = Text.t(LEGEND[key])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row


static func _disc(img: Image, c: Vector2i, r: int, colour: Color) -> void:
	for dy in range(-r, r + 1):
		var half := int(sqrt(float(r * r - dy * dy)))
		img.fill_rect(Rect2i(c.x - half, c.y + dy, half * 2 + 1, 1), colour)


## A mask stamped centred on c, k pixels a cell; with an outline (ink by
## default) round every filled cell so it stands off the plan.
static func _stamp(img: Image, mask: Array, c: Vector2i, k: int, colours: Dictionary, outline := true, ring := MAP_INK) -> void:
	var w: int = mask[0].length()
	var h := mask.size()
	var x0 := c.x - w * k / 2
	var y0 := c.y - h * k / 2
	var o := maxi(2, k / 2)
	if outline:
		for y in h:
			for x in w:
				if mask[y][x] != ".":
					img.fill_rect(Rect2i(x0 + x * k - o, y0 + y * k - o, k + o * 2, k + o * 2), ring)
	for y in h:
		for x in w:
			var ch: String = mask[y][x]
			if colours.has(ch):
				img.fill_rect(Rect2i(x0 + x * k, y0 + y * k, k, k), colours[ch])


## The mission map: the plan, the route from the way in to the piece to the
## door, and where each guard starts.
static func mission_map(guards: Array[Guard]) -> ImageTexture:
	var s := 8
	var img := Image.create(Museum.w * s, Museum.h * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in Museum.h:
		for x in Museum.w:
			if Museum.is_outside(x, y):
				continue
			var t := Museum.grid[y * Museum.w + x]
			var c := Color("#1a1538") if t == Tiles.WALL else (Color("#3a3a5a") if t == Tiles.COVER else Color("#2a2550"))
			img.fill_rect(Rect2i(x * s, y * s, s, s), c)
	for t in Heist.route:
		img.fill_rect(Rect2i(t.x * s + s / 2 - 1, t.y * s + s / 2 - 1, 2, 2), Color("#e8ddc0"))
	var mark := func(t: Vector2i, colour: Color, r: int) -> void:
		img.fill_rect(Rect2i(t.x * s + s / 2 - r, t.y * s + s / 2 - r, r * 2, r * 2), colour)
	# Things to knock over, for planning a distraction.
	for p in Props.list:
		mark.call(p.tile, Color("#c9a15a"), 2)
	# Guards first: the way in, the piece and the door go on top.
	for g in guards:
		mark.call(Vector2i(int(g.x), int(g.y)), C.alert, 3)
	mark.call(Heist.start, C.safe, 3)
	mark.call(Heist.at, Color(Heist.loot.colour), 4)
	mark.call(Heist.exit, C.green, 3)
	if Heist.team:
		mark.call(Heist.panel, Color("#ff922b"), 3)
	return ImageTexture.create_from_image(img)


# --- During play -----------------------------------------------------------------

## The status line, the log, the job and the arrow to the objective.
## job is {"dropped": bool, "name": String, "panel": bool}: what the whole
## gang should know (each thief's own goes in its Prompt); way is {} to hide
## the kunai, or
## {"from": Vector2, "goal": Vector2} in screen terms: the thief, and the
## objective it points at.
func update_play(log_lines: Array[String], job: Dictionary, way: Dictionary, objective_colour: Color, alarm: int) -> void:
	var view := get_viewport().get_visible_rect().size
	_log.text = "\n".join(log_lines)
	# What happened lately: bottom left.
	_log.position = Vector2(24, view.y - 20 - _log.get_minimum_size().y)
	_draw_alarm(alarm, view)
	_gang.position = Vector2(view.x / 2 - _gang.get_combined_minimum_size().x / 2, view.y - PORTRAIT - 22)
	# What one thief can do, or is doing, goes over its head (Prompt); here
	# only what the whole gang should know.
	if job.get("dropped", false):
		_job.text = Text.t("HUD_JOB_DROPPED") % String(job.name).to_upper()
	elif job.get("panel", false):
		_job.text = Text.t("HUD_JOB_PANEL_HELD")
	else:
		_job.text = ""
	_job.size = Vector2(view.x, 30)
	_job.position = Vector2(0, view.y - PORTRAIT - 84)
	# The kunai rides the edge of the screen, where the line from the thief
	# to the objective leaves it, or sits on the objective once it is in
	# sight. It glides there on a spring of its own, looser than the camera.
	_arrow.visible = not way.is_empty()
	if not _arrow.visible:
		_kunai_tip = Vector2.INF
	else:
		var inside := Rect2(Vector2.ONE * KUNAI_MARGIN, view - Vector2.ONE * KUNAI_MARGIN * 2)
		var from: Vector2 = way.from.clamp(inside.position, inside.end)
		var target: Vector2 = way.goal
		if not inside.has_point(target):
			target = _to_edge(from, (target - from).normalized(), inside)
		var dt := get_process_delta_time()
		if _kunai_tip == Vector2.INF:
			_kunai_tip = target
			_kunai_vel = Vector2.ZERO
		_kunai_vel += ((target - _kunai_tip) * KUNAI_PULL - _kunai_vel * KUNAI_DAMP) * dt
		_kunai_tip += _kunai_vel * dt
		var angle: float = (way.goal - way.from).angle()
		var dir := Vector2.from_angle(angle)
		_arrow.modulate = objective_colour
		_arrow.position = _kunai_tip - dir * (30.0 + sin(_clock * 6.0) * 4.0)
		_arrow.rotation = angle
		_arrow.queue_redraw()


## How far in from the edge of the screen the kunai's point keeps.
const KUNAI_MARGIN := 36.0
## Its spring: a little under critical damping, so it settles with a sway.
const KUNAI_PULL := 28.0
const KUNAI_DAMP := 7.5
## Where its point is on screen and how fast it is going; INF when hidden, to
## appear straight in place.
var _kunai_tip := Vector2.INF
var _kunai_vel := Vector2.ZERO


## Where a ray from p (inside r) along dir leaves r.
static func _to_edge(p: Vector2, dir: Vector2, r: Rect2) -> Vector2:
	var t := INF
	if dir.x > 0.0001:
		t = minf(t, (r.end.x - p.x) / dir.x)
	elif dir.x < -0.0001:
		t = minf(t, (r.position.x - p.x) / dir.x)
	if dir.y > 0.0001:
		t = minf(t, (r.end.y - p.y) / dir.y)
	elif dir.y < -0.0001:
		t = minf(t, (r.position.y - p.y) / dir.y)
	return p + dir * t


## Size of a thief's portrait, in pixels.
const PORTRAIT := 110
## The alarm's marks: one slot per level, lit up to the level in its colour.
const ALARM_COLOURS := [Color("#3a2a40"), Color("#ffd43b"), Color("#ff922b"), Color("#ff3048")]


## Top centre: three ! slots, lit up to how alarmed the most alarmed guard
## is — none, something odd, alert, after you. Pops when it goes up.
func _draw_alarm(level: int, view: Vector2) -> void:
	if level != _alarm_level:
		var rose := level > _alarm_level and _alarm_level >= 0
		_alarm_level = level
		var img := Image.create(23, 15, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		for k in 3:
			var x := k * 8
			var lit := k < level
			var c: Color = ALARM_COLOURS[level] if lit else ALARM_COLOURS[0]
			img.fill_rect(Rect2i(x, 0, 7, 10), Color("#1c1210"))
			img.fill_rect(Rect2i(x, 11, 7, 4), Color("#1c1210"))
			img.fill_rect(Rect2i(x + 2, 1, 3, 8), c)
			img.fill_rect(Rect2i(x + 2, 12, 3, 2), c)
		_alarm.texture = ImageTexture.create_from_image(img)
		_alarm.size = Vector2(23, 15) * 3
		_alarm.pivot_offset = _alarm.size / 2
		if rose:
			_alarm.scale = Vector2.ONE * 1.6
			create_tween().tween_property(_alarm, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_alarm.position = Vector2(view.x / 2 - _alarm.size.x / 2, 18)


## The gang at the bottom: for each thief a little stage with its own
## figure, in its colours, that stands, walks, crawls and carries the piece
## just as the thief does (update_gang).
func set_gang(colours: Array, darks: Array, loot: Dictionary) -> void:
	for c in _gang.get_children():
		c.queue_free()
	_portraits.clear()
	_alarm_level = -1
	for i in colours.size():
		var view := SubViewport.new()
		view.size = Vector2i(PORTRAIT, PORTRAIT) * 2
		view.own_world_3d = true
		view.transparent_bg = true
		view.msaa_3d = Viewport.MSAA_4X
		var env := Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("#b8a8d8")
		env.ambient_light_energy = 0.7
		var we := WorldEnvironment.new()
		we.environment = env
		view.add_child(we)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-40, 30, 0)
		sun.light_energy = 1.2
		view.add_child(sun)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		# Looking a little down at it, its middle (0.62 m up) in the middle,
		# with room round it for the piece on its back.
		cam.size = 2.4
		cam.rotation_degrees = Vector3(-18, 0, 0)
		cam.position = Vector3(0, 0.62 + 4.0 * tan(deg_to_rad(18.0)), 4.0)
		view.add_child(cam)
		# The figure walks on the spot: its anchor slides back as it steps.
		var anchor := Node3D.new()
		view.add_child(anchor)
		var fig := Figure.make("thief", colours[i], darks[i])
		anchor.add_child(fig)
		var piece := LootModels.sack()
		piece.scale = Vector3.ONE * 1.1
		piece.visible = false
		fig.add_child(piece)
		var frame := PanelContainer.new()
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.07, 0.05, 0.1, 0.75)
		box.set_corner_radius_all(18)
		box.set_border_width_all(4)
		box.border_color = colours[i]
		frame.add_theme_stylebox_override("panel", box)
		frame.add_child(view)
		var pic := TextureRect.new()
		pic.texture = view.get_texture()
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(pic)
		var smoke := _smoke_row()
		frame.add_child(smoke)
		_gang.add_child(frame)
		_portraits.append({"anchor": anchor, "fig": fig, "piece": piece, "frame": frame, "box": box, "colour": colours[i], "walked": 0.0, "smoke": smoke})


## The smoke bombs a thief has in hand (Smoke.PER_THIEF places, the used
## ones dim), little grey puffs along the bottom of its portrait.
const SMOKE_ICON := 16.0


func _smoke_row() -> Control:
	var row := Control.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(SMOKE_ICON * Smoke.PER_THIEF + 4.0 * (Smoke.PER_THIEF - 1), SMOKE_ICON)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.size_flags_vertical = Control.SIZE_SHRINK_END
	row.set_meta("count", 0)
	row.draw.connect(func() -> void:
		var have: int = row.get_meta("count", 0)
		for k in Smoke.PER_THIEF:
			var mid := Vector2(SMOKE_ICON / 2.0 + k * (SMOKE_ICON + 4.0), SMOKE_ICON / 2.0)
			var lit := k < have
			var c := Color("#d9d6e0") if lit else Color(1, 1, 1, 0.16)
			# A bomb: a round body, a fuse, a spark on it when it is there to use.
			row.draw_circle(mid + Vector2(0, 1), SMOKE_ICON * 0.36, Color(0, 0, 0, 0.6))
			row.draw_circle(mid + Vector2(0, 1), SMOKE_ICON * 0.3, c)
			row.draw_line(mid + Vector2(2, -3), mid + Vector2(5, -7), c, 2.0)
			if lit:
				row.draw_circle(mid + Vector2(5.5, -7.5), 2.0, Color("#ffb347"))
	)
	return row


## Each thief as it is now: {posture, speed, carrying, seen, out, safe,
## pose (Roll.pose), smoke (bombs left)}. The
## frame says how it is doing — its colour hidden, red seen, grey caught,
## green out of the door.
func update_gang(states: Array, dt: float) -> void:
	for i in mini(states.size(), _portraits.size()):
		var st: Dictionary = states[i]
		var p: Dictionary = _portraits[i]
		p.walked += float(st.speed) * dt
		var smoke: Control = p.smoke
		if smoke.get_meta("count", -1) != int(st.get("smoke", 0)):
			smoke.set_meta("count", int(st.get("smoke", 0)))
			smoke.queue_redraw()
		var fig: Figure = p.fig
		# Out of the door: jumping for joy on the spot, fists in the air.
		var pose := "victory" if st.safe else str(st.get("pose", ""))
		fig.set_state(Vector3(p.walked, 0, 0), PI / 2 - 0.6, float(st.posture), dt, pose)
		(p.anchor as Node3D).position.x = -p.walked
		var piece: Node3D = p.piece
		piece.visible = st.carrying
		# The sack on its back, lower when it is down on all fours.
		# High enough to peek over the shoulder at the camera.
		piece.position = Vector3(0, 0.62 - 0.25 * float(st.posture), -0.36)
		var box: StyleBoxFlat = p.box
		var frame: Control = p.frame
		if st.safe:
			box.border_color = C.green
			frame.modulate = Color.WHITE
		elif st.out:
			box.border_color = Color("#6d6a78")
			frame.modulate = Color(0.5, 0.5, 0.5, 0.8)
		else:
			box.border_color = C.alert if st.seen else p.colour
			frame.modulate = Color.WHITE


## A guard's yell: huge for a beat, leaning and pointing towards where it
## came from, with who heard it underneath.
func shout(word: String, text: String, angle: float) -> void:
	_shout_word.text = word
	_shout_text.text = text
	_shout_angle = angle
	_shout_left = SHOUT_S
	_shout.visible = true


## 3, 2, 1, GO! in the middle of the screen, each one swelling and fading
## as it goes. on_step(i) is called as each appears (3 for GO!), on_done at
## the end.
const COUNT := ["3", "2", "1", "HUD_COUNT_GO"]
const COUNT_S := 0.8


func countdown(on_step: Callable, on_done: Callable) -> void:
	_count_on_step = on_step
	_count_on_done = on_done
	_count_left = COUNT_S * COUNT.size()
	_count_step = -1
	_count.visible = true


func counting() -> bool:
	return _count_left > 0


func _draw_count(dt: float) -> void:
	_count_left -= dt
	if _count_left <= 0:
		_count.visible = false
		_count_on_done.call()
		return
	var elapsed := COUNT_S * COUNT.size() - _count_left
	var i := mini(int(elapsed / COUNT_S), COUNT.size() - 1)
	if i != _count_step:
		_count_step = i
		_count.text = Text.t(COUNT[i])
		var go := i == COUNT.size() - 1
		_count.add_theme_color_override("font_color", C.safe if go else C.gold)
		_count.add_theme_color_override("font_outline_color", Color("#0e7490") if go else Color("#b45309"))
		_count_on_step.call(i)
	var t := fmod(elapsed, COUNT_S) / COUNT_S
	var view := get_viewport().get_visible_rect().size
	_count.size = Vector2(view.x, 260)
	# Above the middle, where the camera coming in on the gang leaves room.
	_count.position = Vector2(0, view.y * 0.34 - 130)
	_count.pivot_offset = Vector2(view.x / 2, 130)
	# Pops in, then keeps growing as it fades away.
	var pop := 0.4 + 0.75 * minf(1.0, t / 0.12)
	_count.scale = Vector2.ONE * (pop + t * t * 1.6)
	_count.modulate.a = 1.0 if t < 0.45 else clampf(1.0 - (t - 0.45) / 0.55, 0.0, 1.0)


func _process(dt: float) -> void:
	_clock += dt
	for i in _titles.size():
		var t := _titles[i]
		if is_instance_valid(t):
			t.rotation = sin(_clock * 1.3 + i) * 0.025
			t.scale = Vector2.ONE * (1.0 + sin(_clock * 2.1 + i) * 0.025)
	if _count_left > 0:
		_draw_count(dt)
	if _shout_left <= 0:
		return
	_shout_left -= dt
	var view := get_viewport().get_visible_rect().size
	var t := 1.0 - _shout_left / SHOUT_S
	# Slams in oversized, holds, then drops away.
	var k := 1.9 - 0.9 * minf(1.0, t / 0.08) if t < 0.2 else (1.0 if t < 0.78 else 1.0 + (t - 0.78) * 0.4)
	var lean := Vector2(cos(_shout_angle), sin(_shout_angle)) * Vector2(view.x * 0.06, view.y * 0.06)
	_shout_word.scale = Vector2.ONE * k
	_shout_word.size = Vector2(view.x, 160)
	_shout_word.pivot_offset = Vector2(view.x / 2, 80)
	_shout_word.position = Vector2(0, view.y / 2 - 110) + lean
	_shout_text.size = Vector2(view.x, 30)
	_shout_text.position = Vector2(0, view.y / 2 + 50)
	_shout_arrow.position = view / 2 + Vector2(cos(_shout_angle) * view.x * 0.44, sin(_shout_angle) * view.y * 0.4) - Vector2(20, 40)
	_shout_arrow.pivot_offset = Vector2(20, 40)
	_shout_arrow.rotation = _shout_angle
	_shout.modulate.a = 1.0 if t < 0.78 else clampf(1.0 - (t - 0.78) / 0.22, 0.0, 1.0)
	if _shout_left <= 0:
		_shout.visible = false
