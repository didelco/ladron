class_name MenuItems
extends RefCounted
## Construye elementos, tablas, columnas y listas; el estado de navegación pertenece a Hud.

var host: Hud

func _init(owner: Hud) -> void:
	host = owner

## One item of a menu (show_menu), added to parent.
func menu_item(item: Dictionary, parent: BoxContainer, st: Hud.MenuState) -> void:
	if item.has("columns"):
		columns(item, parent, st)
	elif item.has("title"):
		# Pixel faces run wide: the arcade title at about two thirds the size.
		var t := host._label(int(item.get("size", 56) * 0.55), item.get("colour", Color("#f0c46a")), parent, true)
		t.text = item.title
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if item.get("align", "") == "left" else HORIZONTAL_ALIGNMENT_CENTER
		t.add_theme_constant_override("outline_size", 14)
		t.add_theme_color_override("font_outline_color", Color("#2a150c"))
		t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
		t.add_theme_constant_override("shadow_offset_x", 0)
		t.add_theme_constant_override("shadow_offset_y", 7)
		t.resized.connect(func() -> void: t.pivot_offset = t.size / 2)
		host._titles.append(t)
		# Room for it to bob without brushing what comes next.
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 6)
		parent.add_child(gap)
	elif item.has("text"):
		var l := host._label(int(item.get("size", 20) * 0.85), item.get("colour", Hud.C.text), parent)
		l.text = item.text
		if item.has("id"):
			host._named[item.id] = l
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if item.get("align", "") == "left" else HORIZONTAL_ALIGNMENT_CENTER
		if item.get("wrap", false):
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(item.get("width", 560), 0)
	elif item.has("gap"):
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, item.gap)
		parent.add_child(gap)
	elif item.has("field"):
		var f: Dictionary = item.field
		var e := LineEdit.new()
		e.text = f.get("text", "")
		e.placeholder_text = f.get("hint", "")
		if f.has("max_length"):
			e.max_length = f.max_length
		e.custom_minimum_size = Vector2(f.get("width", 160), 0)
		e.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		e.alignment = HORIZONTAL_ALIGNMENT_CENTER
		e.add_theme_font_size_override("font_size", 22)
		if f.has("call"):
			e.text_submitted.connect(f.call)
		parent.add_child(e)
		if f.has("id"):
			host._fields[f.id] = e
		st.rows.append([e])
		if st.first == null:
			st.first = e
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
		host._menu_map = stage
		host._menu_map_rect = r
		if not host._map_tip:
			host._map_tip = Prompt.new()
			host.add_child(host._map_tip)
	elif item.has("legend"):
		host.legend_row(parent, item.legend, item.get("thieves", []), item.get("loot", Color.WHITE))
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
	elif item.has("node"):
		# A control drawn by whoever asks (the phone and the caller's face).
		var node: Control = item.node
		node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		parent.add_child(node)
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
			host._pictures[item.id] = r
	elif item.has("list"):
		list(item, parent, st)
	elif item.has("cards"):
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 16)
		parent.add_child(row)
		var line: Array = []
		for c in item.cards:
			var card := host._card(c, item.get("width", 300), item.get("arrows", false))
			row.add_child(card)
			card.set_meta("selected", c.get("selected", false) or c.get("focus", false))
			line.append(card)
			if st.first == null or c.get("focus", false):
				st.first = card
		st.rows.append(line)
		if item.get("arrows", false):
			row.add_theme_constant_override("separation", 28)
			row.add_child(host._card_arrow(">", line, 1))
			row.add_child(host._card_arrow("<", line, -1))
			row.move_child(row.get_child(-1), 0)
	elif item.has("buttons"):
		var box: BoxContainer = HBoxContainer.new() if item.get("row", false) else VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_BEGIN if item.get("align", "") == "left" else BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 24 if item.get("row", false) else 10)
		if item.get("align", "") == "left":
			box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parent.add_child(box)
		# Atraco Sorpresa's plan: the row still does what it says by mouse,
		# but the arrows never reach it (BriefScreens.plan_select has them
		# instead), so it must not look reachable either — no focus ring,
		# out of the arrows' rows (see the hints row by it, plan_items).
		var unfocusable: bool = item.get("unfocusable", false)
		var line: Array = []
		for bi in item.buttons.size():
			var b: Dictionary = item.buttons[bi]
			var button := host._button(b)
			if unfocusable:
				button.focus_mode = Control.FOCUS_NONE
			# The one to start on, when it is not the first.
			if item.get("focus", -1) == bi:
				st.focus_on = button
			if b.has("id"):
				st.by_id[b.id] = button
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
			if b.has("help"):
				var help := host._label(13, Hud.C.text, box)
				help.text = b.help
				help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				help.custom_minimum_size.x = 570
				help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if unfocusable:
				continue
			if item.get("row", false):
				line.append(button)
			else:
				st.rows.append([button])
			if st.first == null:
				st.first = button
		if not line.is_empty():
			st.rows.append(line)
	elif item.has("hints"):
		# Which key or button does what, over the mouse-only row above or
		# below it (see "unfocusable", just above) — the same idea as
		# Tour._set_hints, for a menu built from items instead of a scene of
		# its own: "pad" says whether to show a pad's glyphs or a
		# keyboard's (Tour.glyph_for has both sets; this borrows it rather
		# than keeping a second copy of what every key and button mean).
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 28)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(row)
		var pad: bool = item.get("pad", false)
		for h in item.hints:
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)
			hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.set_meta("what", h[0])
			row.add_child(hbox)
			var g := Glyph.new()
			g.set_spec(Tour.glyph_for(h[0], pad), 26)
			g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(g)
			var l := host._label(15, Hud.C.dim, hbox)
			l.text = h[1]
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			host._hint_boxes.append(hbox)
	elif item.has("table"):
		table(item, parent)
	elif item.has("newspaper"):
		parent.add_child(EndPages.newspaper(item.newspaper))
	elif item.has("mugshot"):
		parent.add_child(EndPages.mugshot(item.mugshot))
	elif item.has("card"):
		parent.add_child(EndPages.piece_card(item.card))
	elif item.has("footer"):
		var f := host._label(14, Hud.C.gold, parent, true)
		f.text = item.footer
		f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## A board of short texts: {"table": [[cell, ...], ...], "widths": [int, ...],
## "heads"?: int}. The first row is the heading, in gold arcade letters; the
## "heads" - 1 rows after it say a little more under it, small and dim. Below
## a brass rule, the first column names each row in the arcade face and the
## rest are in the plain one, to be read at a glance, on alternate stripes.
## A cell is a text, or {"text", "span"} to run across several columns.
func table(item: Dictionary, parent: BoxContainer) -> void:
	var board := PanelContainer.new()
	var st := Hud._frame(Hud.BRASS, false, false, 18)
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
			rule.color = Hud.GLASS_EDGE
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
				l = host._label(11, Hud.C.gold, line, true)
			elif r < heads:
				l = host._label(13, Hud.C.dim, line)
			elif col == 0:
				l = host._label(11, Hud.CREAM, line, true)
			else:
				l = host._label(18, Hud.C.text, line)
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
func columns(item: Dictionary, parent: BoxContainer, st: Hud.MenuState) -> void:
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
			menu_item(sub, box, st)

## A list in a box that scrolls with the focus: {"list": [...], "width"?,
## "height"?}. Each line is {"text", "call"?, "open", "colour"?, "selected"?}:
## landing on it (the arrows, the mouse) calls "call" — to show it beside the
## list — and pressing it calls "open". {"head": text} is a heading between
## lines. The line "selected" is the one the menu opens on.
func list(item: Dictionary, parent: BoxContainer, st: Hud.MenuState) -> void:
	var width: int = item.get("width", 360)
	# Its lines' rows, to reach right into another control once it is built
	# (right_id, _resolve_right_links).
	var right_id: String = item.get("right_id", "")
	var my_rows: Array = []
	var frame := PanelContainer.new()
	var fs := Hud._frame(Hud.BRASS, false, false, 18)
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
			var h := host._label(10, Hud.C.gold, box, true)
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
		b.add_theme_font_override("font", Hud.ARCADE)
		b.add_theme_font_size_override("font_size", 10)
		var colour: Color = e.get("colour", Hud.CREAM)
		for state in ["normal", "hover", "pressed", "focus"]:
			var s := Hud._frame(colour, state != "normal", false, 12)
			if state == "normal":
				s.bg_color = Color(0, 0, 0, 0)
				s.border_color = Color(0, 0, 0, 0)
				s.shadow_color = Color(0, 0, 0, 0)
			s.set_content_margin_all(6)
			s.content_margin_left = 14
			b.add_theme_stylebox_override(state, s)
		b.add_theme_color_override("font_color", colour)
		for key in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(key, Hud.GLOW_TEXT)
		b.focus_entered.connect(func() -> void:
			if not host._quiet:
				host.ui_sound.emit("nav")
			if e.has("call"):
				e.call.call())
		b.mouse_entered.connect(func() -> void: b.grab_focus())
		b.pressed.connect(e.open)
		b.pressed.connect(func() -> void: host.ui_sound.emit("ok"))
		box.add_child(b)
		var row: Array = [b]
		st.rows.append(row)
		my_rows.append(row)
		if st.first == null:
			st.first = b
		if e.get("selected", false):
			st.focus_on = b
	if right_id != "":
		st.pending_right.append({"id": right_id, "rows": my_rows})
