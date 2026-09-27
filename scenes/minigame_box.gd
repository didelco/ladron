class_name MinigameBox
extends Control
## The box a thief's minigame (Minigame) is played in: beside the thief on
## screen, never over it, so what comes round the corner stays in sight. A
## walnut frame with a brass edge in the thief's colour, like the menus'
## buttons, round a little 3D scene (MinigameStage); under it, what to do
## and with which keys or buttons — this thief's own (Main._controls) — or
## why it has to wait. One per thief; hidden while its hands are free.

const STAGE := MinigameStage.SIZE
const PAD := 8.0
## the strip under the scene for the two lines of how to play
const STRIP := 66.0
const SIZE := Vector2(STAGE.x + PAD * 2, STAGE.y + PAD + STRIP)
## How far from the thief's head the box keeps, and from the screen's edge.
const GAP := 48.0
const MARGIN := 16.0

var game: Minigame
var _stage: MinigameStage
var _frame: Panel
var _style: StyleBoxFlat
var _picture: TextureRect
## the two lines of how to play, and what they were built from
var _how: VBoxContainer
var _how_for := ""


func _init() -> void:
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_style = StyleBoxFlat.new()
	_style.bg_color = Hud.GLASS
	_style.set_corner_radius_all(20)
	_style.anti_aliasing = true
	_style.set_border_width_all(3)
	_style.border_color = Hud.GLASS_EDGE
	_style.shadow_color = Color(0, 0, 0, 0.35)
	_style.shadow_size = 8
	_style.shadow_offset = Vector2(0, 3)
	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", _style)
	_frame.size = SIZE
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_stage = MinigameStage.new()
	add_child(_stage)
	_picture = TextureRect.new()
	_picture.texture = _stage.get_texture()
	_picture.position = Vector2(PAD, PAD)
	_picture.size = Vector2(STAGE)
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_picture)
	_how = VBoxContainer.new()
	_how.position = Vector2(0, STAGE.y + PAD)
	_how.size = Vector2(SIZE.x, STRIP - 6)
	_how.alignment = BoxContainer.ALIGNMENT_CENTER
	_how.add_theme_constant_override("separation", 3)
	_how.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_how)


## Show it for this game, beside a thief whose head is at `head` on screen.
func follow(g: Minigame, head: Vector2, thief_colour: Color, controls: Dictionary) -> void:
	if g != game:
		_pop()
	game = g
	visible = g != null
	_stage.show_game(g, thief_colour)
	if not visible:
		return
	_style.border_color = thief_colour.lerp(Hud.GLOW, 0.35)
	var view := get_viewport_rect().size
	# To the right of the thief, or to its left against the right edge; its
	# middle level with the head, kept on screen.
	var at := Vector2(head.x + GAP, head.y - SIZE.y * 0.6)
	if at.x + SIZE.x > view.x - MARGIN:
		at.x = head.x - GAP - SIZE.x
	at.x = clampf(at.x, MARGIN, view.x - SIZE.x - MARGIN)
	at.y = clampf(at.y, MARGIN, view.y - SIZE.y - MARGIN)
	position = at
	# Under the scene: why it waits, or else what to do and how to let go.
	var lines: Array[String] = []
	if g.done:
		lines = [Text.t("GAME_READY")]
	elif g.blocked == "panel":
		lines = [Text.t("GAME_WAIT_PANEL")]
	elif g.blocked == "hands":
		lines = [Text.t("GAME_WAIT_HANDS")]
	else:
		lines = [Text.t({"lockpick": "GAME_HOW_LOCKPICK", "steady": "GAME_HOW_STEADY", "wires": "GAME_HOW_WIRES", "balance": "GAME_HOW_BALANCE"}[g.kind]),
			Text.t("GAME_LET_GO")]
	_show_how(lines, controls)


## Builds the lines of how to play, if they changed: "{action}" and the like
## become this thief's key or button, drawn (Glyph) where there is one in
## controls.glyphs, else a keycap with its name; the rest plain words.
func _show_how(lines: Array[String], controls: Dictionary) -> void:
	var key := "|".join(lines) + str(controls)
	if key == _how_for:
		return
	_how_for = key
	for c in _how.get_children():
		c.queue_free()
	for line in lines:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_how.add_child(row)
		var rest := line
		while rest != "":
			var open := rest.find("{")
			var close := rest.find("}", open)
			if open < 0 or close < 0:
				row.add_child(_words(rest))
				break
			if open > 0:
				row.add_child(_words(rest.substr(0, open).strip_edges()))
			var name := rest.substr(open + 1, close - open - 1)
			var glyphs: Dictionary = controls.get("glyphs", {})
			if glyphs.has(name):
				var g := Glyph.new()
				# The four to move stand two caps tall: a little smaller, to fit.
				g.set_spec(glyphs[name], 18.0 if glyphs[name].get("kind") == "keys4" else 20.0)
				row.add_child(g)
			else:
				row.add_child(_keycap(String(controls.get(name, "?"))))
			rest = rest.substr(close + 1).strip_edges()


func _words(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Hud.ARCADE)
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", Hud.CREAM)
	return l


## A key or button: a cream cap with a lip, as the controls screen has them.
func _keycap(text: String) -> Label:
	var l := _words(text)
	l.add_theme_font_size_override("font_size", 9)
	l.add_theme_color_override("font_color", Hud.INK)
	var cap := StyleBoxFlat.new()
	cap.bg_color = Hud.CREAM
	cap.set_corner_radius_all(5)
	cap.content_margin_left = 6
	cap.content_margin_right = 6
	cap.content_margin_top = 3
	cap.content_margin_bottom = 3
	cap.shadow_color = Hud.INK_SOFT
	cap.shadow_size = 1
	cap.shadow_offset = Vector2(0, 2)
	l.add_theme_stylebox_override("normal", cap)
	return l


## Springs open like the menus' buttons.
func _pop() -> void:
	pivot_offset = SIZE / 2
	scale = Vector2(0.9, 0.9)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
