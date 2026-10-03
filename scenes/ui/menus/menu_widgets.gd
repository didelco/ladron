class_name MenuWidgets
extends RefCounted
## Botones y tarjetas de menú: marcos, animaciones, callbacks y caché de glifos.

var host: Hud

func _init(owner: Hud) -> void:
	host = owner

static var _glyphs := {}
## A menu button: a framed line of text, or a big icon (the thieves on the
## title), lit up on hover and focus.
func button(b: Dictionary) -> Button:
	var button := Button.new()
	button.text = b.get("text", "")
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", Hud.ARCADE)
	button.add_theme_font_size_override("font_size", 12)
	var colour: Color = b.get("colour", Hud.C.safe)
	# selected: the tab you are on, marked even without the focus.
	var selected: bool = b.get("selected", false)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := frame(colour, state != "normal", selected, 22)
		st.set_content_margin_all(12)
		st.content_margin_left = 28
		st.content_margin_right = 28
		button.add_theme_stylebox_override(state, st)
	lift(button)
	button.add_theme_color_override("font_color", Hud.C.gold if selected else Hud.CREAM)
	for key in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, Hud.GLOW_TEXT)
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
		button.add_theme_color_override("icon_normal_color", Hud.CREAM)
		for key in ["icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			button.add_theme_color_override(key, Hud.GLOW)
	if b.has("step"):
		stepper(button, b.step)
		button.pressed.connect(func() -> void: host.ui_sound.emit("ok"))
	else:
		button.pressed.connect(b.call)
		var back: bool = String(b.get("text", "")).begins_with("<")
		button.pressed.connect(func() -> void: host.ui_sound.emit("back" if back else "ok"))
	return button

## A button that holds a setting: {"text", "step"} instead of "call", where
## step(dir) changes it and returns the button's new text. Accept or a click
## is dir 0 (the next value, round the end), ← and → are -1 and +1. The text
## changes in place, so the focus stays put for the next press. A button in a
## column has no neighbours across, so the arrows are free for this.
func stepper(button: Button, step: Callable) -> void:
	button.pressed.connect(func() -> void: button.text = step.call(0))
	button.gui_input.connect(func(event: InputEvent) -> void:
		for dir in [-1, 1]:
			if event.is_action_pressed("ui_left" if dir < 0 else "ui_right", true):
				button.text = step.call(dir)
				button.accept_event())

## The frame every menu control shares: a pill of dark glass with a thin
## pale rim and a soft shadow; with the focus the rim turns warm and glows.
## selected (the choice in force) keeps a rim of its colour while it waits.
static func frame(colour: Color, lit: bool, selected := false, radius := 26) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Hud.GLASS_LIT if lit else Hud.GLASS
	st.set_corner_radius_all(radius)
	st.anti_aliasing = true
	st.border_color = Hud.GLOW if lit else (colour.lerp(Hud.GLOW, 0.5) if selected else Hud.GLASS_EDGE)
	st.set_border_width_all(3 if lit or selected else 2)
	if lit:
		st.shadow_color = Color(Hud.GLOW, 0.45)
		st.shadow_size = 16
		st.shadow_offset = Vector2.ZERO
	else:
		st.shadow_color = Color(0, 0, 0, 0.35)
		st.shadow_size = 6
		st.shadow_offset = Vector2(0, 3)
	return st

## A picture clipped to rounded corners.
func round_corners(r: TextureRect, box: Vector2, radius: float) -> void:
	var shader := Shader.new()
	shader.code = Hud.ROUNDED_SHADER
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("box", box)
	m.set_shader_parameter("radius", radius)
	r.material = m

## Grows a little under the mouse or the focus; the mouse takes the focus,
## so the arrows and the mouse never point at two different things.
func lift(c: Control, grow := 1.07, rest := 1.0) -> void:
	c.focus_entered.connect(func() -> void:
		if not host._quiet:
			host.ui_sound.emit("nav"))
	c.resized.connect(func() -> void: c.pivot_offset = c.size / 2)
	c.mouse_entered.connect(func() -> void:
		if c is BaseButton and not (c as BaseButton).disabled:
			c.grab_focus())
	# A springy pop, overshooting a little; always the same both ways, so
	# nothing ever looks squashed.
	c.focus_entered.connect(func() -> void:
		c.scale = Vector2.ONE * rest * 0.97
		host.create_tween().tween_property(c, "scale", Vector2.ONE * grow, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT))
	c.focus_exited.connect(func() -> void:
		# Held up for the bubble it opened (pop_bubble): it stays as it is.
		if not c.get_meta("held", false):
			host.create_tween().tween_property(c, "scale", Vector2.ONE * rest, 0.15).set_trans(Tween.TRANS_QUAD))
	if c is BaseButton:
		# On the press, a little dip and back up to its size.
		(c as BaseButton).button_down.connect(func() -> void:
			c.scale = Vector2.ONE * grow * 0.95
			host.create_tween().tween_property(c, "scale", Vector2.ONE * grow, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))

## An arrow beside a row of cards: a click moves the focus to the card
## beside the one that has it, round the ends. It never takes the focus.
func card_arrow(text: String, cards: Array, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Hud.ARCADE)
	b.add_theme_font_size_override("font_size", 28)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, Hud.GLOW if key != "font_color" else Hud.CREAM)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		var at := maxi(0, cards.find(host.get_viewport().gui_get_focus_owner()))
		(cards[posmod(at + dir, cards.size())] as Control).grab_focus())
	return b

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
					if glyph_in(kind, p):
						hit += 1
			img.set_pixel(x, y, Color(1, 1, 1, float(hit) / (SS * SS)))
	_glyphs[kind] = ImageTexture.create_from_image(img)
	return _glyphs[kind]

static func glyph_in(kind: String, p: Vector2) -> bool:
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
func card(c: Dictionary, width: int, back := false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var colour: Color = c.get("colour", Hud.C.safe)
	var selected: bool = c.get("selected", false)
	for state in ["normal", "hover", "pressed", "focus"]:
		var st := frame(colour, state != "normal", selected, 22)
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
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if c.has("stage") or c.get("smooth", false) else CanvasItem.TEXTURE_FILTER_NEAREST
		var k := (width - 24.0) / picture.get_width()
		r.custom_minimum_size = Vector2(width - 24, picture.get_height() * k)
		round_corners(r, r.custom_minimum_size, 16.0)
		height += r.custom_minimum_size.y
		box.add_child(r)
	# The title on one line: the pixel font is one em a character, so a long
	# title on a narrow card takes a smaller size.
	var title_size: int = mini(c.get("title_size", 13), floori((width - 30.0) / maxi(1, String(c.title).length())))
	var t := host._label(title_size, Hud.CREAM, box, true)
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	t.text = c.title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	height += 24
	if c.has("text"):
		var l := host._label(12, Hud.C.dim, box)
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
		l.text = c.text
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width - 24, 0)
		# Room for every line it wraps to (about 6.5 px a character).
		var lines := 0
		for paragraph in l.text.split("\n"):
			lines += maxi(1, ceili(paragraph.length() * 6.5 / (width - 24)))
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
	b.pressed.connect(func() -> void: host.ui_sound.emit("ok"))
	var rest := 0.9 if back else 1.0
	lift(b, 1.1, rest)
	b.scale = Vector2.ONE * rest
	# The ones waiting sit back in the dark; the one with the focus comes up.
	b.modulate = Hud.DIM_CARD
	b.focus_entered.connect(func() -> void: host.create_tween().tween_property(b, "modulate", Color.WHITE, 0.2))
	b.focus_exited.connect(func() -> void:
		if not b.get_meta("held", false):
			host.create_tween().tween_property(b, "modulate", Hud.DIM_CARD, 0.2))
	if c.has("id"):
		host._cards[c.id] = b
	return b
