class_name MgWires
extends Minigame
## The alarm box: a row of coloured wires, each with a mark on its tag, and
## a little screen blinking the mark of the one to cut. Pick the wire (left
## and right) and cut it (the action button); three to cut, in the order the
## screen says. Cut a wrong one and a spark stings your fingers: a moment
## lost, nothing more. With the guards on alert the screen flickers: the
## mark is harder to read.

const COLOURS := [Color("#e2262f"), Color("#2f7bf0"), Color("#ffd43b"), Color("#2fb84a"), Color("#f4f1e6")]
const MARKS := ["circle", "square", "triangle", "cross", "bar"]

var wires := 5
var order: Array[int] = []
## the mark on each wire's tag
var tags: Array[int] = []
var cut: Array[bool] = []
var at := 0
var step := 0
var _stung := 0.0


func _init(count := 5, cuts := 3) -> void:
	super()
	kind = "action"
	wires = clampi(count, 3, 5)
	order.resize(clampi(cuts, 1, wires))


func _begin() -> void:
	var marks := range(MARKS.size())
	for i in range(marks.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = marks[i]
		marks[i] = marks[j]
		marks[j] = t
	tags.clear()
	cut.clear()
	for i in wires:
		tags.append(marks[i])
		cut.append(false)
	var pool := range(wires)
	for i in order.size():
		var k := rng.randi_range(0, pool.size() - 1)
		order[i] = pool[k]
		pool.remove_at(k)
	at = wires / 2


func title() -> String:
	return Text.t("MG_WIRES")


func help() -> String:
	return Text.t("MG_WIRES_HELP")


func _step(input: Dictionary, dt: float) -> void:
	if _stung > 0.0:
		_stung -= dt
		return
	var tap: Vector2i = input.get("tap", Vector2i.ZERO)
	if tap.x != 0:
		at = clampi(at + tap.x, 0, wires - 1)
	if input.get("act", false) and not cut[at]:
		if at == order[step]:
			cut[at] = true
			step += 1
			feel.emit(0.5)
			_blink(GOOD)
			progress = float(step) / order.size()
			if step >= order.size():
				_done()
		else:
			_slip()
			_stung = 0.6


func _draw_game(area: Rect2) -> void:
	# The screen, top left: the mark of the wire to cut, flickering under pressure.
	var screen := Rect2(area.position + Vector2(0, 0), Vector2(44, 30))
	draw_rect(screen, Color("#0d2a1a"))
	draw_rect(screen, GOOD, false, 1.5)
	var flicker := pressure > 0.0 and fmod(elapsed * (6.0 + pressure * 10.0), 1.0) < pressure * 0.55
	if step < order.size() and not flicker:
		_mark(screen.get_center(), tags[order[step]], 9.0, GOOD)
	# The wires, hanging from the box's top edge.
	var w := (area.size.x - 54) / wires
	for i in wires:
		var x := area.position.x + 54 + w * (i + 0.5)
		var top := area.position.y + 2
		var bottom := area.end.y - 6
		var c: Color = COLOURS[i % COLOURS.size()]
		if cut[i]:
			draw_line(Vector2(x, top), Vector2(x, top + 30), c, 4.0)
			draw_line(Vector2(x, bottom - 30), Vector2(x, bottom), c, 4.0)
		else:
			draw_line(Vector2(x, top), Vector2(x, bottom), c, 4.0)
		_mark(Vector2(x, bottom - 14), tags[i], 6.0, CREAM)
		if i == at:
			draw_rect(Rect2(Vector2(x - w / 2.0 + 2, top - 2), Vector2(w - 4, bottom - top + 4)), GOLD, false, 2.0)
	if _stung > 0.0:
		var x := area.position.x + 54 + w * (at + 0.5)
		for k in 6:
			var a := k * TAU / 6.0 + elapsed * 20.0
			draw_line(Vector2(x, area.get_center().y), Vector2(x, area.get_center().y) + Vector2(cos(a), sin(a)) * 12.0, GOLD, 2.0)


func _mark(c: Vector2, which: int, r: float, col: Color) -> void:
	match MARKS[which]:
		"circle": draw_arc(c, r, 0, TAU, 16, col, 2.0)
		"square": draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2), col, false, 2.0)
		"triangle": draw_polyline(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, r), c + Vector2(-r, r), c + Vector2(0, -r)]), col, 2.0)
		"cross":
			draw_line(c + Vector2(-r, -r), c + Vector2(r, r), col, 2.0)
			draw_line(c + Vector2(r, -r), c + Vector2(-r, r), col, 2.0)
		_: draw_rect(Rect2(c - Vector2(r, r * 0.35), Vector2(r * 2, r * 0.7)), col)
