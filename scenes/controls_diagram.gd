class_name ControlsDiagram
extends Control
## A physical map of each game's input layout. Colours and numbers connect
## the keys/buttons to the action legend, without changing the bindings.
const ACTIONS := ["CONTROLS_MOVE", "CONTROLS_PUSH", "CONTROLS_ROLL", "CONTROLS_CROUCH", "CONTROLS_SLOW", "CONTROLS_SMOKE", "CONTROLS_MAP", "CONTROLS_PAUSE", "CONTROLS_MUTE"]
const COLOURS := [Color("#63d5ce"), Color("#ffcf69"), Color("#f58b71"), Color("#a999ee"), Color("#9ac76d"), Color("#f2a1cc"), Color("#72b9ee"), Color("#e0c4a1"), Color("#c9c5d6")]
var device := "kb_left"
var _font: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
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
	var colour: Color = COLOURS[action] if action >= 0 else Color("#706575")
	_box(rect, colour.darkened(0.70) if action >= 0 else Color("#342a3b"), colour, 5)
	var font_size := 19
	var label_width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if label_width > rect.size.x - 8:
		font_size = int(font_size * (rect.size.x - 8) / label_width)
	var text_size := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	_text(rect.position + Vector2((rect.size.x - text_size.x) / 2.0, rect.size.y * 0.58), label, Hud.CREAM, font_size)
	if action >= 0:
		_text(rect.position + Vector2(rect.size.x - 13, rect.size.y - 5), str(action + 1), colour, 12)

func _keyboard() -> void:
	_text(Vector2(25, 33), Text.t("CONTROLS_P2_WHERE" if device == "kb_right" else "CONTROLS_P1_WHERE"), Hud.CREAM, 20)
	_box(Rect2(18, 48, 760, 283), Color("#483342"), Hud.CREAM, 16)
	var mappings: Dictionary = {"M": 6, "P": 7, "Esc": 7, "N": 8}
	if device == "kb_left":
		mappings.merge({"W": 0, "A": 0, "S": 0, "D": 0, "E": 1, "Espacio": 2, "C": 3, "Shift izq.": 4, "F": 5})
	else:
		mappings.merge({"↑": 0, "←": 0, "↓": 0, "→": 0, Hands.key_label(KEY_PERIOD): 1, "Enter": 2, Hands.key_label(KEY_SLASH): 3, "Shift dcha.": 4, Hands.key_label(KEY_COMMA): 5})
	var rows := [
		["Esc", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "⌫"],
		["Tab", "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P", "+"],
		["Caps", "A", "S", "D", "F", "G", "H", "J", "K", "L", "Ñ", "Enter"],
		["Shift izq.", "Z", "X", "C", "V", "B", "N", "M", Hands.key_label(KEY_COMMA), Hands.key_label(KEY_PERIOD), Hands.key_label(KEY_SLASH), "Shift dcha."],
	]
	for r in rows.size():
		for col in rows[r].size():
			var label: String = rows[r][col]
			_key(Rect2(30 + col * 61, 62 + r * 48, 56, 42), label, mappings.get(label, -1))
	_key(Rect2(30, 257, 85, 55), "Ctrl")
	_key(Rect2(121, 257, 65, 55), "Alt")
	_key(Rect2(192, 257, 280, 55), "Espacio", mappings.get("Espacio", -1))
	_key(Rect2(478, 257, 65, 55), "Alt")
	_key(Rect2(551, 282, 48, 30), "←", mappings.get("←", -1))
	_key(Rect2(603, 251, 48, 30), "↑", mappings.get("↑", -1))
	_key(Rect2(603, 282, 48, 30), "↓", mappings.get("↓", -1))
	_key(Rect2(655, 282, 48, 30), "→", mappings.get("→", -1))

func _pad_button(at: Vector2, label: String, action: int, radius := 28.0) -> void:
	draw_circle(at, radius + 3, Hud.CREAM)
	draw_circle(at, radius, COLOURS[action].darkened(0.45))
	var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
	_text(at + Vector2(-width / 2, 6), label, Hud.CREAM, 19)
	_text(at + Vector2(-4, radius - 5), str(action + 1), COLOURS[action], 14)

func _pad() -> void:
	# Two grips and an arched body, with shoulder and face controls in their
	# real positions. A/B/X/Y are the game's standard positional names.
	draw_circle(Vector2(190, 236), 94, Hud.CREAM)
	draw_circle(Vector2(610, 236), 94, Hud.CREAM)
	_box(Rect2(127, 70, 550, 175), Hud.CREAM, Hud.CREAM, 75)
	draw_circle(Vector2(190, 234), 87, Color("#483342"))
	draw_circle(Vector2(610, 234), 87, Color("#483342"))
	_box(Rect2(135, 77, 534, 165), Color("#483342"), Color("#483342"), 70)
	_key(Rect2(161, 38, 140, 42), "LB", 4)
	_key(Rect2(503, 38, 140, 42), "RB")
	_pad_button(Vector2(225, 141), "Stick", 0, 44)
	_text(Vector2(170, 201), "L3 · 4", COLOURS[3], 18)
	_key(Rect2(340, 115, 58, 40), "View", 6)
	_key(Rect2(415, 115, 58, 40), "Start", 7)
	_pad_button(Vector2(580, 120), "Y", 5)
	_pad_button(Vector2(541, 160), "X", 3)
	_pad_button(Vector2(619, 160), "B", 2)
	_pad_button(Vector2(580, 200), "A", 1)
	_key(Rect2(305, 221, 36, 77), "", 0)
	_key(Rect2(285, 241, 77, 36), "+", 0)
	draw_circle(Vector2(466, 258), 35, Hud.CREAM)
	draw_circle(Vector2(466, 258), 32, Color("#2a2031"))
	_text(Vector2(303, 327), "Cruceta · 1", COLOURS[0], 18)
