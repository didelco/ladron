class_name EditorWidgets
extends RefCounted
## Widgets e iconos del editor. Comparte estilos y mantiene las acciones en MapEditor.

var host: MapEditor

func _init(owner: MapEditor) -> void:
	host = owner

## A small square button with a drawn icon, its name on hover.
func icon_button(icon: String, key: String, call: Callable, parent: Node, colour: Color) -> Button:
	var b := button("", call, parent, colour, false, icon)
	b.custom_minimum_size = Vector2(42, 36)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 20)
	b.tooltip_text = Text.t(key)
	return b

## One of the bar's settings at the right: its value is its text.
func setting_button(call: Callable, parent: Node, icon: Variant) -> Button:
	var b := button("", call, parent, Hud.C.safe, false, icon)
	b.custom_minimum_size = Vector2(220, 38)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.add_theme_constant_override("icon_max_width", 20)
	b.add_theme_font_size_override("font_size", 8)
	return b

func label(text: String, size: int, colour: Color, parent: Node, arcade := false) -> Label:
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
func button(text: String, call: Callable, parent: Node, colour: Color, big := false, icon: Variant = null) -> Button:
	var b := Button.new()
	b.text = text
	if icon is String:
		var stickers := {"new": "editor-mapas", "save": "guardar-mapa", "play": "probar-mapa"}
		if stickers.has(icon):
			b.icon = load("res://assets/ui/hub/%s.png" % stickers[icon])
			b.set_meta("photo", true)
		else:
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
	look(b, false)
	b.pressed.connect(call)
	b.pressed.connect(func() -> void: host.ui_sound.emit("ok"))
	b.focus_entered.connect(func() -> void:
		host.ui_sound.emit("nav")
		if not b.tooltip_text.is_empty() and is_instance_valid(host._hint):
			host._say(b.tooltip_text, Hud.CREAM))
	b.mouse_entered.connect(b.grab_focus)
	parent.add_child(b)
	return b

## selected: the tool in hand, or the room.
func look(b: Button, selected: bool) -> void:
	var colour: Color = b.get_meta("colour")
	for state in ["normal", "hover", "pressed", "focus"]:
		var lit: bool = state != "normal"
		var st := StyleBoxFlat.new()
		st.bg_color = Hud.GLASS_LIT if lit or selected else Hud.GLASS
		st.set_corner_radius_all(12)
		st.border_color = Hud.GLOW if lit else (colour if selected else Hud.GLASS_EDGE)
		st.set_border_width_all(3 if lit or selected else 2)
		if lit:
			st.shadow_color = Color(Hud.GLOW, 0.4)
			st.shadow_size = 10
		st.set_content_margin_all(6)
		b.add_theme_stylebox_override(state, st)
	b.add_theme_color_override("font_color", colour if selected else Hud.CREAM)
	for key in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, Hud.GLOW_TEXT)
	# A drawn icon goes the colour of the text; a picture stays as it is.
	if not b.has_meta("photo"):
		b.add_theme_color_override("icon_normal_color", colour if selected else Hud.CREAM)
		for key in ["icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			b.add_theme_color_override(key, Hud.GLOW)

## A ready-made room as a little plan, in the plan's own colours.
func template_picture(i: int) -> ImageTexture:
	var rows: Array = MapEditor.TEMPLATES[i].rows
	var cell := 4
	var img := Image.create(String(rows[0]).length() * cell, rows.size() * cell, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		for x in String(rows[0]).length():
			var ch := String(rows[y])[x]
			var col: Color = Hud.MAP_WALL if ch == "#" else (Hud.MAP_CASE if ch in ["o", "D", "S", "O", "b"] else Hud.MAP_FLOOR)
			img.fill_rect(Rect2i(x * cell, y * cell, cell, cell), col)
	return ImageTexture.create_from_image(img)

## The floor's or the walls' colours as they are now: two tones of stone in
## a check, or the wallpaper's stripes over its wainscot.
## which: one of the looks (MuseumView.looks), -1 the seed's own, or -2
## (the default) whatever the map has now.
func swatch(part: String, which := -2) -> ImageTexture:
	var look: Dictionary = {}
	if which >= 0:
		look = MuseumView.looks()[which]
	elif which == -2 and host.map:
		look = host.map.palette()
	if look.is_empty():
		look = MuseumView.THEMES[posmod(host.map.seed if host.map else 0, MuseumView.THEMES.size())]
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

## A stat's level (0-4) as a little bar chart, like a volume meter: five
## bars rising left to right, gold up to the level in force, the rest dim.
func level_bars_texture(level: int) -> ImageTexture:
	var w := 160
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var n := 5
	var bw := 20
	var gap := 9
	var start_x := (w - (n * bw + (n - 1) * gap)) / 2
	for i in n:
		var bar_h := roundi(h * (0.3 + 0.7 * float(i + 1) / n))
		var x := start_x + i * (bw + gap)
		var y := h - bar_h
		var col := Hud.C.gold if i <= level else Color(Hud.CREAM, 0.22)
		img.fill_rect(Rect2i(x, y, bw, bar_h), col)
	return ImageTexture.create_from_image(img)

## An upward arrow turned to face one of the eight GUARD_DIRS: each pixel
## checked against the shape unrotated, by undoing the turn on its way in.
func dir_arrow_texture(angle: float) -> ImageTexture:
	var w := 40
	var img := Image.create(w, w, false, Image.FORMAT_RGBA8)
	var c := w / 2.0
	var cos_a := cos(-angle)
	var sin_a := sin(-angle)
	for y in w:
		for x in w:
			var dx := x - c
			var dy := y - c
			var lx := dx * cos_a - dy * sin_a
			var ly := dx * sin_a + dy * cos_a
			if in_arrow_shape(lx, ly, c):
				img.set_pixel(x, y, Hud.CREAM)
	return ImageTexture.create_from_image(img)

## The arrow's shape in its own upward frame (north is -Y): a shaft below
## the centre, a triangular head above it, its tip at the top.
func in_arrow_shape(lx: float, ly: float, c: float) -> bool:
	if absf(lx) <= c * 0.12 and ly >= -c * 0.15 and ly <= c * 0.75:
		return true
	var head_top := -c * 0.85
	var head_base := -c * 0.05
	if ly < head_top or ly > head_base:
		return false
	var t := (ly - head_top) / (head_base - head_top)
	return absf(lx) <= t * c * 0.55

func tool_colour(t: String) -> Color:
	if t.begins_with("prop:"):
		return MapEditor.PROP
	if t.begins_with("big:"):
		return MapEditor.ROOM
	match t:
		"spawn": return MapEditor.THIEF
		"piece": return MapEditor.PIECE
		"exit": return MapEditor.EXIT
		"guard": return MapEditor.GUARD
		"door": return MapEditor.DOOR
		"prop": return MapEditor.PROP
		"case": return MapEditor.PIECE
		"room": return MapEditor.ROOM
	return Hud.C.safe
