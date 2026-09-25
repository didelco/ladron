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

## Behind every menu: a museum wall at night — aubergine above, dark wood
## below, a faint striped wallpaper with a damask dot, the warm pool of a
## lamp from the top, a vignette round the edge.
const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.16, 0.09, 0.2, 0.97);
uniform vec4 bottom : source_color = vec4(0.08, 0.045, 0.035, 0.98);
void fragment() {
	vec4 c = mix(top, bottom, smoothstep(0.0, 1.0, UV.y));
	float stripe = step(0.5, fract(FRAGCOORD.x / 64.0));
	c.rgb += stripe * 0.012 * (1.0 - UV.y);
	vec2 g = fract(FRAGCOORD.xy / vec2(64.0, 80.0) + vec2(0.25, 0.0)) - 0.5;
	c.rgb += smoothstep(0.09, 0.06, length(g * vec2(1.0, 0.7))) * 0.018 * (1.0 - UV.y);
	// A wainscot rail across the lower third.
	c.rgb += smoothstep(0.004, 0.0, abs(UV.y - 0.72)) * 0.05;
	// The lamp: warm light pooling from the top centre, breathing slowly.
	float lamp = exp(-pow(distance(UV * vec2(1.6, 1.0), vec2(0.8, 0.05)) * 1.9, 2.0));
	c.rgb += vec3(0.45, 0.28, 0.12) * lamp * (0.3 + 0.03 * sin(TIME * 1.3));
	c.rgb *= 1.0 - distance(UV, vec2(0.5)) * 0.55;
	COLOR = c;
}
"""

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
## How long a full-screen menu takes to fade in or out over the game.
const FADE_S := 0.2
## The arcade face, for titles, buttons, the clock and the yell only: it is a
## shouting font and unreadable in paragraphs, so the log and the IA panel keep
## the plain one.
const ARCADE := preload("res://assets/fonts/PressStart2P-Regular.ttf")

var _status: Label
var _log: Label
var _job: Label
var _bar_back: ColorRect
var _bar: ColorRect
var _arrow: Label
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
var _ia: PanelContainer
var _ia_box: VBoxContainer


func _ready() -> void:
	_status = _label(16, C.text, self, true)
	_status.position = Vector2(24, 16)
	_log = _label(15, C.dim)
	_log.position = Vector2(24, 64)
	_job = _label(14, C.gold, self, true)
	_job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_back = ColorRect.new()
	_bar_back.color = Color("#241d52")
	add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = C.gold
	add_child(_bar)
	_arrow = _label(40, C.gold)
	_arrow.text = "▶"
	_arrow.pivot_offset = Vector2(14, 28)

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
	var legend := _label(13, Color("#e8d6b4"), column)
	legend.text = "● tú   ◆ la pieza   ■ salida (verde)   ·   M o Y para guardarlo"
	legend.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_play = [_status, _log, _job, _bar_back, _bar, _arrow]

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
##   {"title": text, "colour": Color, "size": int}   the heading
##   {"text": text, "size"?, "colour"?, "wrap"?}      a line, or a paragraph
##   {"picture": Texture2D, "smooth"?, "height"?}     the map, the piece
##   {"buttons": [{"text", "call", "icon"?, "colour"?}], "row": bool}
##                                                    text buttons, all one width
##                                                    ("step" for "call": a setting, _stepper)
##   {"cards": [{"title", "text"?, "picture", "call", "colour"?, "selected"?,
##     "focus"?}], "width"?: int}                     big picture cards in a row
##   {"nights": [{"n", "colour", "locked", "selected", "call"}]}
##                                                    the story's path of nights
##   {"footer": text}                                 what to press
## Buttons work with the mouse, and with the arrows and Enter; the first one
## has the focus.
func show_menu(items: Array) -> void:
	for c in _panel_box.get_children():
		c.queue_free()
	var first: Button = null
	# Rows of focusable controls, top to bottom, for the arrows.
	var rows: Array = []
	_named.clear()
	_nights.clear()
	_titles.clear()
	for item in items:
		if item.has("title"):
			# Pixel faces run wide: the arcade title at about two thirds the size.
			var t := _label(int(item.get("size", 56) * 0.55), item.get("colour", Color("#f0c46a")), _panel_box, true)
			t.text = item.title
			t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
			_panel_box.add_child(gap)
		elif item.has("text"):
			var l := _label(int(item.get("size", 20) * 0.85), item.get("colour", C.text), _panel_box)
			l.text = item.text
			if item.has("id"):
				_named[item.id] = l
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if item.get("wrap", false):
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.custom_minimum_size = Vector2(560, 0)
		elif item.has("stage"):
			var stage: MenuStage = item.stage
			_panel_box.add_child(stage)
			stage.active = true
			var r := TextureRect.new()
			r.texture = stage.get_texture()
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.custom_minimum_size = Vector2(stage.size) * (float(item.get("height", 200.0)) / stage.size.y)
			_panel_box.add_child(r)
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
			_panel_box.add_child(r)
		elif item.has("cards"):
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 16)
			_panel_box.add_child(row)
			var line: Array = []
			for c in item.cards:
				var card := _card(c, item.get("width", 300))
				row.add_child(card)
				card.set_meta("selected", c.get("selected", false) or c.get("focus", false))
				line.append(card)
				if first == null or c.get("focus", false):
					first = card
			rows.append(line)
		elif item.has("nights"):
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 0)
			_panel_box.add_child(row)
			var nights: Array = item.nights
			var line: Array = []
			for i in nights.size():
				if i > 0:
					var link := ColorRect.new()
					link.custom_minimum_size = Vector2(16, 4)
					link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
					link.color = Color("#3b3470") if nights[i].locked else Color("#8a80d0")
					row.add_child(link)
				var node := _night(nights[i])
				row.add_child(node)
				if not nights[i].locked:
					line.append(node)
					node.set_meta("selected", nights[i].selected)
				if nights[i].get("selected", false):
					first = node
			for node in line:
				node.set_meta("sticky", true)
			rows.append(line)
		elif item.has("buttons"):
			var box: BoxContainer = HBoxContainer.new() if item.get("row", false) else VBoxContainer.new()
			box.alignment = BoxContainer.ALIGNMENT_CENTER
			box.add_theme_constant_override("separation", 24 if item.get("row", false) else 10)
			_panel_box.add_child(box)
			var line: Array = []
			for b in item.buttons:
				var button := _button(b)
				if not b.has("icon"):
					# big: the one thing to do next; small: the way back.
					if item.get("big", false):
						button.custom_minimum_size = Vector2(380, 62)
						button.add_theme_font_size_override("font_size", 17)
					elif item.get("small", false):
						button.custom_minimum_size = Vector2(200, 36)
						button.add_theme_font_size_override("font_size", 10)
					else:
						button.custom_minimum_size = Vector2(240 if item.get("row", false) else 400, 42)
				box.add_child(button)
				if item.get("row", false):
					line.append(button)
				else:
					rows.append([button])
				if first == null:
					first = button
			if not line.is_empty():
				rows.append(line)
		elif item.has("footer"):
			var f := _label(14, C.gold, _panel_box, true)
			f.text = item.footer
			f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	if first:
		first.grab_focus.call_deferred()


## Labels a menu gave an id, to change without rebuilding it.
var _named := {}
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
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := _frame(colour, state != "normal", false, 22)
		st.set_content_margin_all(12)
		st.content_margin_left = 28
		st.content_margin_right = 28
		button.add_theme_stylebox_override(state, st)
	_lift(button)
	button.add_theme_color_override("font_color", CREAM)
	for key in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, INK)
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
	if b.has("step"):
		_stepper(button, b.step)
	else:
		button.pressed.connect(b.call)
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


## The frame every menu control shares: a walnut pill with a brass edge
## and a raised lip underneath; with the focus it turns to polished brass.
## selected (the choice in force) keeps a rim of its colour while it waits.
func _frame(colour: Color, lit: bool, selected := false, radius := 26) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = BRASS if lit else WALNUT
	st.set_corner_radius_all(radius)
	st.anti_aliasing = true
	st.border_color = CREAM if lit else (colour.lerp(BRASS, 0.6) if selected else BRASS_DARK)
	st.set_border_width_all(3 if lit or selected else 2)
	# The raised edge: a darker shadow straight below, no blur.
	st.shadow_color = Color("#5a3a16") if lit else WALNUT_EDGE
	st.shadow_size = 1
	st.shadow_offset = Vector2(0, 6 if lit else 4)
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
func _lift(c: Control) -> void:
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2)
	c.mouse_entered.connect(func() -> void:
		if c is BaseButton and not (c as BaseButton).disabled:
			c.grab_focus())
	# A springy pop, overshooting a little, like a jelly button.
	c.focus_entered.connect(func() -> void:
		c.scale = Vector2(0.96, 1.04)
		create_tween().tween_property(c, "scale", Vector2.ONE * 1.07, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	c.focus_exited.connect(func() -> void: create_tween().tween_property(c, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD))
	if c is BaseButton:
		# A squash on the press.
		(c as BaseButton).button_down.connect(func() -> void: c.scale = Vector2(1.1, 0.92))


## A big card: a picture, a title and a line under it.
func _card(c: Dictionary, width: int) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var colour: Color = c.get("colour", C.safe)
	var selected: bool = c.get("selected", false)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := _frame(colour, state != "normal", selected, 22)
		if state != "normal":
			# A card keeps its wood face with the focus: a brass-lit rim says it.
			st.bg_color = WALNUT_LIT
			st.border_color = colour.lerp(BRASS, 0.75)
			st.set_border_width_all(5)
			st.shadow_color = WALNUT_EDGE
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
	var t := _label(c.get("title_size", 13), CREAM, box, true)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	t.text = c.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height += 24
	if c.has("text"):
		var l := _label(12, INK_SOFT, box)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		l.text = c.text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width - 24, 0)
		height += 34
	b.custom_minimum_size = Vector2(width, height + 34)
	b.pressed.connect(c.call)
	_lift(b)
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
	b.custom_minimum_size = Vector2(42, 42)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.set_meta("colour", n.colour)
	b.set_meta("locked", n.locked)
	_night_look(b, n.selected)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_disabled_color", Color("#6d5a78"))
	if not n.locked:
		# Landing on a night picks it; the picked look moves with it.
		b.focus_entered.connect(func() -> void:
			for other in _nights:
				_night_look(other, other == b)
				other.set_meta("selected", other == b)
			_rewire(_rows)
			n.call.call())
		b.pressed.connect(n.call)
		_nights.append(b)
	_lift(b)
	return b


func _night_look(b: Button, picked: bool) -> void:
	var colour: Color = b.get_meta("colour")
	var locked: bool = b.get_meta("locked")
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(21)
		st.anti_aliasing = true
		st.shadow_size = 1
		st.shadow_offset = Vector2(0, 5)
		if locked:
			st.bg_color = Color("#2a1d2e")
			st.border_color = Color("#3d2c40")
			st.set_border_width_all(2)
			st.shadow_color = WALNUT_EDGE
		else:
			var lit: bool = picked or state != "normal"
			st.bg_color = colour.darkened(0.1) if lit else colour.darkened(0.5)
			st.border_color = CREAM if lit else colour.darkened(0.15)
			st.set_border_width_all(3)
			st.shadow_color = WALNUT_EDGE
		b.add_theme_stylebox_override(state, st)


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
		_fade.tween_callback(func(): _panel.visible = false)


func menu_open() -> bool:
	return _shown


## The IA panel: one card per guard. entries are {"name", "title", "colour",
## "options": [[label, probability]], "note"}.
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
func show_map(plan: Image) -> void:
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
static func live_map(thieves: Array[Thief], colours: Array) -> Image:
	var s := 8
	var img := Image.create(Museum.w * s, Museum.h * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in Museum.h:
		for x in Museum.w:
			if Museum.is_outside(x, y):
				continue
			var t := Museum.grid[y * Museum.w + x]
			var c := Color("#4a2f22") if t == Tiles.WALL else (Color("#b89a70") if t == Tiles.COVER else Color("#e8d6b4"))
			img.fill_rect(Rect2i(x * s, y * s, s, s), c)
	# A mark in a shape: "circle" (a thief), "diamond" (the piece), "square".
	var dot := func(at: Vector2, colour: Color, r: int, ring: Color, shape := "square") -> void:
		var cx := int(at.x * s)
		var cy := int(at.y * s)
		for pass_n in 2:
			var rr := r + 1 - pass_n
			var c: Color = ring if pass_n == 0 else colour
			for dy in range(-rr, rr + 1):
				for dx in range(-rr, rr + 1):
					var inside: bool = true
					if shape == "circle":
						inside = dx * dx + dy * dy <= rr * rr
					elif shape == "diamond":
						inside = absi(dx) + absi(dy) <= rr
					if inside and cx + dx >= 0 and cy + dy >= 0 and cx + dx < img.get_width() and cy + dy < img.get_height():
						img.set_pixel(cx + dx, cy + dy, c)
	var ink := Color("#1c1210")
	dot.call(Vector2(Heist.exit.x + 0.5, Heist.exit.y + 0.5), C.green, 4, ink)
	if Heist.team and not Heist.taken:
		dot.call(Vector2(Heist.panel.x + 0.5, Heist.panel.y + 0.5), Color("#ff922b"), 3, ink)
	if not Heist.taken:
		dot.call(Vector2(Heist.at.x + 0.5, Heist.at.y + 0.5), Color(Heist.loot.colour), 6, ink, "diamond")
	elif Heist.dropped != Vector2.INF:
		dot.call(Heist.dropped, Color(Heist.loot.colour), 5, ink, "diamond")
	for i in thieves.size():
		var p := thieves[i]
		if not p.out:
			dot.call(Vector2(p.x, p.y), colours[i], 5, Color.WHITE, "circle")
	return img


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
## job is {"working": bool, "progress": float, "verb": String, "carrying":
## bool, "dropped": bool, "name": String}; objective_angle is in screen terms,
## or NAN to hide the arrow.
func update_play(status: String, status_colour: Color, log_lines: Array[String], job: Dictionary, objective_angle: float, objective_colour: Color) -> void:
	_status.text = status
	_status.add_theme_color_override("font_color", status_colour)
	_log.text = "\n".join(log_lines)
	var view := get_viewport().get_visible_rect().size
	var working: bool = job.get("working", false) and not job.get("waiting", false)
	_bar_back.visible = working
	_bar.visible = working
	if working:
		var w := 360.0
		_bar_back.position = Vector2(view.x / 2 - w / 2, view.y - 70)
		_bar_back.size = Vector2(w, 14)
		_bar.position = _bar_back.position
		_bar.size = Vector2(w * float(job.progress), 14)
	if job.get("waiting", false):
		_job.text = "¡QUE TU COMPAÑERO SUJETE EL CUADRO DE ALARMA!"
	elif working:
		_job.text = job.verb
	elif job.get("carrying", false):
		_job.text = "TIENES %s · ¡A LA SALIDA!" % String(job.name).to_upper()
	elif job.get("dropped", false):
		_job.text = "%s ESTÁ EN EL SUELO" % String(job.name).to_upper()
	elif job.get("panel", false):
		_job.text = "ALARMA DESCONECTADA · ¡A LA VITRINA!"
	else:
		_job.text = ""
	_job.size = Vector2(view.x, 30)
	_job.position = Vector2(0, view.y - 108)
	_arrow.visible = not is_nan(objective_angle)
	if _arrow.visible:
		_arrow.add_theme_color_override("font_color", objective_colour)
		_arrow.position = view / 2 + Vector2(cos(objective_angle) * view.x * 0.45, sin(objective_angle) * view.y * 0.42) - Vector2(14, 28)
		_arrow.rotation = objective_angle


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
const COUNT := ["3", "2", "1", "GO!"]
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
		_count.text = COUNT[i]
		var go := i == COUNT.size() - 1
		_count.add_theme_color_override("font_color", C.safe if go else C.gold)
		_count.add_theme_color_override("font_outline_color", Color("#0e7490") if go else Color("#b45309"))
		_count_on_step.call(i)
	var t := fmod(elapsed, COUNT_S) / COUNT_S
	var view := get_viewport().get_visible_rect().size
	_count.size = Vector2(view.x, 260)
	_count.position = Vector2(0, view.y / 2 - 130)
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
