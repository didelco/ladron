class_name ControlsDiagram
extends Control
## A physical map of each game's input layout. Colours and numbers connect
## the keys/buttons to the action legend, without changing the bindings.
const ACTIONS := ["CONTROLS_MOVE", "CONTROLS_PUSH", "CONTROLS_ROLL", "CONTROLS_CROUCH", "CONTROLS_SLOW", "CONTROLS_SMOKE", "CONTROLS_MAP", "CONTROLS_PAUSE", "CONTROLS_MUTE"]
const COLOURS := [Color("#63d5ce"), Color("#ffcf69"), Color("#f58b71"), Color("#a999ee"), Color("#9ac76d"), Color("#f2a1cc"), Color("#72b9ee"), Color("#e0c4a1"), Color("#c9c5d6")]
const ASSETS := "res://assets/ui/controls/"
var device := "kb_left"
var _font: Font
var _textures := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	for asset in ["keycap", "controller_xboxseries", "xbox_button_color_a", "xbox_button_color_b", "xbox_button_color_x", "xbox_button_color_y", "xbox_button_view", "xbox_button_menu", "xbox_lb", "xbox_rb", "xbox_lt", "xbox_rt", "xbox_guide", "xbox_stick_top_l", "xbox_stick_top_r", "xbox_dpad"]:
		_textures[asset] = load(ASSETS + asset + ".svg")
	resized.connect(queue_redraw)

func show_device(which: String) -> void:
	device = which
	visible = which != ""
	queue_redraw()

func _text(at: Vector2, text: String, colour := Hud.CREAM, font_size := 22) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, colour)

func _box(rect: Rect2, fill: Color, border := Hud.CREAM, radius := 9.0) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(radius))
	draw_style_box(style, rect)

func _draw() -> void:
	if not _font or device == "": return
	var zoom := minf(size.x / 1180.0, size.y / 350.0)
	draw_set_transform(Vector2((size.x - 1180.0 * zoom) / 2.0, (size.y - 350.0 * zoom) / 2.0), 0.0, Vector2.ONE * zoom)
	_box(Rect2(0, 0, 1180, 350), Color("#21172a", 0.95), Color("#91786e"), 18)
	if device == "pad": _pad()
	else: _keyboard()
	for i in ACTIONS.size():
		var cells := Text.t(ACTIONS[i]).replace("{slash}", Hands.key_label(KEY_SLASH)).replace("{period}", Hands.key_label(KEY_PERIOD)).replace("{comma}", Hands.key_label(KEY_COMMA)).split("|")
		var column := cells.size() - 1 if device == "pad" else (2 if device == "kb_right" and cells.size() == 4 else 1)
		var mapping: String = cells[column]
		var y := 28.0 + i * 35.0
		draw_circle(Vector2(816, y - 7), 12, COLOURS[i])
		_text(Vector2(810, y - 1), str(i + 1), Hud.INK, 17)
		_text(Vector2(838, y - 3), cells[0], COLOURS[i], 19)
		_text(Vector2(838, y + 15), mapping, Hud.CREAM, 17)

func _key(rect: Rect2, label: String, action := -1) -> void:
	var caption := "⇧" if label.begins_with("Shift") else label
	var colour: Color = COLOURS[action] if action >= 0 else Color("#706575")
	_box(Rect2(rect.position + Vector2(0, 3), rect.size), Color("#130e1c"), Color("#130e1c"), 5)
	_box(rect, colour.darkened(0.67) if action >= 0 else Color("#403748"), Color("#403748"), 5)
	if rect.size.x > rect.size.y * 1.25 or rect.size.y > rect.size.x * 1.25:
		_box(rect, colour.darkened(0.67) if action >= 0 else Color("#403748"), colour, 5)
	else:
		draw_texture_rect(_textures.keycap, rect, false, colour)
	var font_size := 15
	var label_width := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if label_width > rect.size.x - 8:
		font_size = int(font_size * (rect.size.x - 8) / label_width)
	var text_size := _font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_text(rect.position + Vector2((rect.size.x - text_size.x) / 2.0, rect.size.y * 0.58), caption, Hud.CREAM, font_size)
	if action >= 0:
		_text(rect.position + Vector2(rect.size.x - 10, rect.size.y - 3), str(action + 1), colour, 10)

func _key_row(y: float, keys: Array, mappings: Dictionary) -> void:
	var x := 30.0
	for entry in keys:
		var label: String = entry[0]
		var units: float = entry[1]
		_key(Rect2(x, y, units * 32 - 3, 35), label, mappings.get(label, -1))
		x += units * 32

func _keyboard() -> void:
	_text(Vector2(25, 33), Text.t("CONTROLS_P2_WHERE" if device == "kb_right" else "CONTROLS_P1_WHERE"), Hud.CREAM, 20)
	_box(Rect2(18, 43, 760, 288), Color("#191421"), Color("#8e809c"), 12)
	_box(Rect2(24, 47, 748, 277), Color("#2a2434"), Color("#554962"), 9)
	var mappings: Dictionary = {"M": 6, "P": 7, "Esc": 7, "N": 8}
	if device == "kb_left":
		mappings.merge({"W": 0, "A": 0, "S": 0, "D": 0, "E": 1, "Espacio": 2, "C": 3, "Shift izq.": 4, "F": 5})
	else:
		mappings.merge({"↑": 0, "←": 0, "↓": 0, "→": 0, Hands.key_label(KEY_PERIOD): 1, "Enter": 2, Hands.key_label(KEY_SLASH): 3, "Shift dcha.": 4, Hands.key_label(KEY_COMMA): 5})
	_key(Rect2(30, 56, 29, 27), "Esc", 7)
	for i in 12:
		var x := 94 + i * 32 + (i / 4) * 10
		_key(Rect2(x, 56, 29, 27), "F%d" % (i + 1))
	var top: Array = [["º", 1]]
	for n in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "'", "¡"]:
		top.append([n, 1])
	top.append(["⌫", 2])
	_key_row(98, top, mappings)
	_key_row(141, [["Tab", 1.5], ["Q", 1], ["W", 1], ["E", 1], ["R", 1], ["T", 1], ["Y", 1], ["U", 1], ["I", 1], ["O", 1], ["P", 1], ["`", 1], ["+", 1]], mappings)
	_key_row(184, [["Caps", 1.75], ["A", 1], ["S", 1], ["D", 1], ["F", 1], ["G", 1], ["H", 1], ["J", 1], ["K", 1], ["L", 1], ["Ñ", 1], ["´", 1]], mappings)
	# ISO Enter has a tall top and a wider lower part on a Spanish keyboard.
	var enter := PackedVector2Array([Vector2(462, 141), Vector2(507, 141), Vector2(507, 219), Vector2(438, 219), Vector2(438, 184), Vector2(462, 184), Vector2(462, 141)])
	var enter_colour: Color = COLOURS[2] if device == "kb_right" else Color("#706575")
	draw_colored_polygon(enter, enter_colour.darkened(0.67))
	draw_polyline(enter, enter_colour, 2, true)
	_text(Vector2(466, 171), "↵", Hud.CREAM, 25)
	_text(Vector2(452, 207), "Enter", Hud.CREAM, 14)
	if device == "kb_right": _text(Vector2(494, 214), "3", enter_colour, 10)
	_key_row(227, [["Shift izq.", 1.25], ["<", 1], ["Z", 1], ["X", 1], ["C", 1], ["V", 1], ["B", 1], ["N", 1], ["M", 1], [Hands.key_label(KEY_COMMA), 1], [Hands.key_label(KEY_PERIOD), 1], [Hands.key_label(KEY_SLASH), 1], ["Shift dcha.", 2.75]], mappings)
	_key_row(270, [["Ctrl", 1.5], ["Win", 1], ["Alt", 1.25], ["Espacio", 6.25], ["AltGr", 1.25], ["Fn", 1], ["☰", 1], ["Ctrl", 1.75]], mappings)
	# Navigation cluster and full numeric keypad remain visible for orientation.
	for col in 3:
		_key(Rect2(530 + col * 32, 56, 29, 27), ["Impr", "Bloq", "Pausa"][col])
		_key(Rect2(530 + col * 32, 98, 29, 35), ["Ins", "Inicio", "Pg↑"][col])
		_key(Rect2(530 + col * 32, 141, 29, 35), ["Supr", "Fin", "Pg↓"][col])
	_key(Rect2(562, 227, 29, 35), "↑", mappings.get("↑", -1))
	for col in 3:
		var arrow: String = ["←", "↓", "→"][col]
		_key(Rect2(530 + col * 32, 270, 29, 35), arrow, mappings.get(arrow, -1))
	for col in 3:
		draw_circle(Vector2(666 + col * 32, 59), 3, Color("#9ac76d") if col == 0 else Color("#5a5166"))
		_text(Vector2(653 + col * 32, 78), ["Num", "Caps", "Scroll"][col], Color("#a49ab2"), 9)
	for r in 4:
		for col in 3:
			_key(Rect2(642 + col * 32, 98 + r * 43, 29, 35), [["Num", "/", "*"], ["7", "8", "9"], ["4", "5", "6"], ["1", "2", "3"]][r][col])
	_key(Rect2(738, 98, 29, 35), "−")
	_key(Rect2(738, 141, 29, 78), "+")
	_key(Rect2(738, 227, 29, 78), "↵")
	_key(Rect2(642, 270, 61, 35), "0")
	_key(Rect2(706, 270, 29, 35), ",")

func _glyph(asset: String, rect: Rect2, tint := Color.WHITE) -> void:
	draw_texture_rect(_textures[asset], rect, false, tint)

func _badge(at: Vector2, action: int) -> void:
	draw_circle(at, 11, Hud.INK)
	draw_circle(at, 9, COLOURS[action])
	_text(at + Vector2(-4, 5), str(action + 1), Hud.INK, 14)

func _pad_button(at: Vector2, asset: String, action: int) -> void:
	draw_circle(at + Vector2(0, 3), 23, Color("#120d19"))
	draw_circle(at, 21, Color("#2e243a"))
	draw_arc(at, 22, 0, TAU, 40, COLOURS[action], 2, true)
	_glyph(asset, Rect2(at - Vector2(28, 28), Vector2(56, 56)))
	_badge(at + Vector2(21, 18), action)

func _stick(at: Vector2, left: bool) -> void:
	draw_circle(at, 41, Color("#17101f"))
	draw_arc(at, 40, 0, TAU, 48, Color("#cbbcdf"), 2, true)
	draw_circle(at + Vector2(0, 3), 29, Color("#08060d"))
	draw_circle(at, 28, Color("#4f435e"))
	for i in 24:
		var angle := i * TAU / 24.0
		draw_line(at + Vector2.from_angle(angle) * 22, at + Vector2.from_angle(angle) * 26, Color("#9687a8"), 1, true)
	_glyph("xbox_stick_top_l" if left else "xbox_stick_top_r", Rect2(at - Vector2(22, 22), Vector2(44, 44)), Hud.CREAM)
	if left:
		draw_arc(at, 44, 0, TAU, 48, COLOURS[0], 3, true)
		_badge(at + Vector2(-34, -27), 0)
		_badge(at + Vector2(33, 28), 3)

func _pad() -> void:
	# Kenney's complete Xbox-style shell with controls at its physical positions.
	var body := Rect2(100, 49, 585, 294)
	var source := Rect2(128, 240, 768, 528)
	draw_texture_rect_region(_textures.controller_xboxseries, Rect2(body.position + Vector2(0, 4), body.size), source, Color("#100b17"))
	draw_texture_rect_region(_textures.controller_xboxseries, body, source, Color("#8d7b9e"))
	# Separate triggers and shoulders, with their real glyphs.
	_glyph("xbox_lt", Rect2(196, 0, 92, 60), Color("#a99cb6"))
	_glyph("xbox_rt", Rect2(505, 0, 92, 60), Color("#a99cb6"))
	_glyph("xbox_lb", Rect2(167, 21, 125, 65), COLOURS[4])
	_glyph("xbox_rb", Rect2(497, 21, 125, 65), Hud.CREAM)
	_badge(Vector2(191, 52), 4)
	# Grip seams, screw points and surface texture add depth without obscuring inputs.
	for side in [0, 1]:
		var x := 154.0 if side == 0 else 625.0
		for i in 7:
			draw_line(Vector2(x - 14, 252 + i * 8), Vector2(x + 14, 239 + i * 8), Color("#675674"), 2, true)
		draw_circle(Vector2(x, 222), 4, Color("#392b46"))
		draw_line(Vector2(x - 2, 222), Vector2(x + 2, 222), Color("#b4a5c2"), 1, true)
	_glyph("xbox_guide", Rect2(365, 67, 60, 60), Hud.CREAM)
	_stick(Vector2(252, 125), true)
	_stick(Vector2(441, 200), false)
	_pad_button(Vector2(528, 102), "xbox_button_color_y", 5)
	_pad_button(Vector2(479, 138), "xbox_button_color_x", 3)
	_pad_button(Vector2(577, 138), "xbox_button_color_b", 2)
	_pad_button(Vector2(528, 174), "xbox_button_color_a", 1)
	_glyph("xbox_button_view", Rect2(323, 110, 54, 54), COLOURS[6])
	_glyph("xbox_button_menu", Rect2(405, 110, 54, 54), COLOURS[7])
	_badge(Vector2(344, 154), 6)
	_badge(Vector2(431, 154), 7)
	_glyph("xbox_dpad", Rect2(264, 155, 98, 98), COLOURS[0])
	_badge(Vector2(354, 239), 0)
	_text(Vector2(272, 269), "Cruceta", Hud.CREAM, 15)
	_text(Vector2(195, 189), "L3", COLOURS[3], 16)
