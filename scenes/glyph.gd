class_name Glyph
extends Control
## A key or a pad button, drawn: what to press, as it looks in your hands.
## A keyboard key is a cream cap on a lip, sinking when it is pressed. A pad's
## face button is round, in its maker's colours and marks (Xbox letters,
## PlayStation shapes, Nintendo letters where Nintendo puts them), with a
## little diamond beside it lighting which of the four it is, so the same
## button reads on any pad. The stick is a knob in its ring. The four keys
## to move are four caps where the hand finds them, one on top and three
## under it; the arrow keys, with arrows on them.
##
## The spec (Main._glyph builds them for each thief):
##   kind    "key", "pad", "stick" or "keys4"
##   label   the key's name ("E", "ESPACIO")
##   labels  keys4: up, left, down and right (["W", "A", "S", "D"]), or
##           "arrows" for the arrow keys
##   lit     keys4: which of the four count (the others dimmed); all if left out
##   pos     a pad button's place: "south", "east", "west" or "north"
##   family  a pad's maker: "xbox", "ps" or "nintendo"

## How each maker marks its four face buttons, by place: the face colour and
## the mark on it (a letter, or a shape for PlayStation).
const PADS := {
	"xbox": {
		"south": [Color("#3fae49"), "A"], "east": [Color("#e0413a"), "B"],
		"west": [Color("#3a86e0"), "X"], "north": [Color("#f2c230"), "Y"],
	},
	"ps": {
		"south": [Color("#2b2b36"), "cross"], "east": [Color("#2b2b36"), "circle"],
		"west": [Color("#2b2b36"), "square"], "north": [Color("#2b2b36"), "triangle"],
	},
	"nintendo": {
		"south": [Color("#3a3a46"), "B"], "east": [Color("#3a3a46"), "A"],
		"west": [Color("#3a3a46"), "Y"], "north": [Color("#3a3a46"), "X"],
	},
}
## The PlayStation marks keep their colours on the dark buttons.
const PS_MARKS := {"cross": Color("#8fb4ff"), "circle": Color("#ff7a7a"), "square": Color("#f59ad8"), "triangle": Color("#4fd8a8")}
const DIAMOND := {"north": Vector2(0, -1), "east": Vector2(1, 0), "south": Vector2(0, 1), "west": Vector2(-1, 0)}

var spec := {}
## its height; the rest scales with it
var h := 28.0
## 0..1: how far down it is, springing back up after a press
var _down := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_spec(s: Dictionary, height := 28.0) -> void:
	if s == spec and height == h:
		return
	spec = s
	h = height
	custom_minimum_size = Vector2(_width(), _height())
	size = custom_minimum_size
	queue_redraw()


## Sinks it for a moment: the press seen as it happens.
func press() -> void:
	_down = 1.0
	queue_redraw()


func _process(dt: float) -> void:
	if _down > 0.0:
		_down = maxf(0.0, _down - dt * 6.0)
		queue_redraw()
	elif spec.get("kind") == "stick":
		queue_redraw()


func _width() -> float:
	match spec.get("kind", "key"):
		"keys4":
			return _cap() * 3 + _gap() * 2
		"pad":
			return h * 1.55
		"stick":
			return h
	var text: String = spec.get("label", "?")
	return maxf(h, Hud.ARCADE.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size()).x + h * 0.6)


func _height() -> float:
	return _cap() * 2 + _gap() if spec.get("kind") == "keys4" else h


## keys4: the side of one cap, and the gap between them.
func _cap() -> float:
	return roundf(h * 0.78)


func _gap() -> float:
	return maxf(1.0, roundf(h * 0.06))


func _font_size() -> int:
	return int(h * 0.36)


func _draw() -> void:
	match spec.get("kind", "key"):
		"pad":
			_draw_pad()
		"stick":
			_draw_stick()
		"keys4":
			_draw_keys4()
		_:
			_draw_key()


## A cream cap on a darker lip; pressed, the cap sinks onto it.
func _draw_key() -> void:
	var w := size.x
	var lip := h * 0.14
	var sink := lip * _down
	var r := h * 0.2
	_round_rect(Rect2(0, lip, w, h - lip), r, Hud.INK_SOFT.darkened(0.25))
	var face := Rect2(0, sink, w, h - lip)
	_round_rect(face, r, Hud.CREAM.lightened(0.15 * _down))
	var text: String = spec.get("label", "?")
	var fs := _font_size()
	var ascent := Hud.ARCADE.get_ascent(fs)
	draw_string(Hud.ARCADE, Vector2(0, face.position.y + face.size.y / 2 + ascent / 2 - 1), text, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Hud.INK)


## The four caps in their pyramid: up on top, left, down and right under it.
## A press sinks the lit ones; the dimmed ones are there to be recognised.
func _draw_keys4() -> void:
	var k := _cap()
	var g := _gap()
	var labels = spec.get("labels", ["W", "A", "S", "D"])
	var lit: Array = spec.get("lit", [true, true, true, true])
	var at := [Vector2(k + g, 0), Vector2(0, k + g), Vector2(k + g, k + g), Vector2((k + g) * 2, k + g)]
	var lip := maxf(1.0, roundf(k * 0.14))
	var r := k * 0.22
	var fs := int(k * 0.5)
	for i in 4:
		var on: bool = lit[i]
		var sink := lip * _down if on else 0.0
		var alpha := 1.0 if on else 0.35
		_round_rect(Rect2(at[i] + Vector2(0, lip), Vector2(k, k - lip)), r, Color(Hud.INK_SOFT.darkened(0.25), alpha))
		var face := Rect2(at[i] + Vector2(0, sink), Vector2(k, k - lip))
		_round_rect(face, r, Color(Hud.CREAM.lightened(0.15 * _down if on else 0.0), alpha))
		var ink := Color(Hud.INK, alpha)
		if labels is String:
			var c := face.get_center()
			var dir: Vector2 = [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT][i]
			var s := k * 0.2
			var side := dir.orthogonal()
			draw_colored_polygon(PackedVector2Array([c + dir * s, c - dir * s * 0.7 + side * s, c - dir * s * 0.7 - side * s]), ink)
		else:
			var ascent := Hud.ARCADE.get_ascent(fs)
			draw_string(Hud.ARCADE, Vector2(face.position.x, face.position.y + face.size.y / 2 + ascent / 2 - 1), String(labels[i]), HORIZONTAL_ALIGNMENT_CENTER, k, fs, ink)


## The face button, round on its lip, and the diamond of four beside it.
func _draw_pad() -> void:
	var family: Dictionary = PADS.get(spec.get("family", "xbox"), PADS.xbox)
	var pos: String = spec.get("pos", "south")
	var look: Array = family.get(pos, family.south)
	var r := h * 0.42
	var lip := h * 0.1
	var c := Vector2(r + 1, h / 2 - lip / 2 + lip * _down)
	draw_circle(Vector2(r + 1, h / 2 + lip / 2), r, Color(look[0]).darkened(0.45))
	draw_circle(c, r, Color(look[0]).lightened(0.15 * _down))
	draw_arc(c, r - 1, 0, TAU, 32, Color(1, 1, 1, 0.18), 1.5, true)
	var mark: String = look[1]
	if mark in PS_MARKS:
		_draw_ps_mark(mark, c, r * 0.5)
	else:
		var fs := int(h * 0.4)
		draw_string(Hud.ARCADE, Vector2(c.x - r, c.y + Hud.ARCADE.get_ascent(fs) / 2 - 1), mark, HORIZONTAL_ALIGNMENT_CENTER, r * 2, fs, Color.WHITE)
	# Which of the four: the lit dot in the diamond.
	var d := Vector2(r * 2 + h * 0.32, h / 2)
	var step := h * 0.17
	for p in DIAMOND:
		var lit: bool = p == pos
		draw_circle(d + DIAMOND[p] * step, h * (0.085 if lit else 0.06), Hud.CREAM if lit else Color(Hud.CREAM, 0.35))


func _draw_ps_mark(mark: String, c: Vector2, s: float) -> void:
	var col: Color = PS_MARKS[mark]
	var w := maxf(1.5, h * 0.07)
	match mark:
		"cross":
			draw_line(c + Vector2(-s, -s) * 0.8, c + Vector2(s, s) * 0.8, col, w, true)
			draw_line(c + Vector2(-s, s) * 0.8, c + Vector2(s, -s) * 0.8, col, w, true)
		"circle":
			draw_arc(c, s * 0.85, 0, TAU, 24, col, w, true)
		"square":
			draw_rect(Rect2(c - Vector2(s, s) * 0.75, Vector2(s, s) * 1.5), col, false, w)
		"triangle":
			var pts := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.95, s * 0.7), c + Vector2(-s * 0.95, s * 0.7), c + Vector2(0, -s)])
			draw_polyline(pts, col, w, true)


## The stick: a ring, and the knob nudged the way it was last pushed.
func _draw_stick() -> void:
	var c := Vector2(h / 2, h / 2)
	var r := h * 0.46
	draw_circle(c, r, Color("#26262e"))
	draw_arc(c, r - 1, 0, TAU, 32, Color(Hud.CREAM, 0.5), 1.5, true)
	var wobble := Vector2(sin(Time.get_ticks_msec() / 260.0), 0) * r * 0.18 * (1.0 - _down)
	draw_circle(c + wobble + Vector2(0, r * 0.1 * _down), r * 0.55, Color("#4a4a58").lightened(0.2 * _down))
	draw_arc(c + wobble, r * 0.55, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.2, true)


func _round_rect(r: Rect2, radius: float, colour: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.set_corner_radius_all(int(radius))
	box.anti_aliasing = true
	draw_style_box(box, r)
