class_name Prompt
extends Control
## What a thief can do right now, over its head: never in the middle of the
## screen, so with several thieves each sees its own. A small walnut bubble
## edged in the thief's colour, with a tail down to it, stacking one row per
## thing to do: the key or button (Glyph, this thief's own) and a verb.
## A row without a button just says something (why it waits); a row with
## progress fills a bar under its verb. Rows spring in as they turn up, the
## glyph sinks when it is pressed, and the bubble fades when there is nothing.
##
## One per thief (Main._draw_prompts). Each frame show() is given the rows:
##   {"input": "action"|"crouch"|"roll"|"move"|"" , "glyph": Glyph spec,
##    "verb": String, "progress": float (0..1, or left out)}

const GLYPH_H := 26.0
const PAD := Vector2(10, 7)
## how far above the head the tail's tip keeps
const LIFT := 14.0
const TAIL := 8.0
const MARGIN := 12.0

var _frame: Panel
var _style: StyleBoxFlat
var _rows: VBoxContainer
## the rows on show, by what they were built from
var _built := ""
var _glyphs := {}
var _bars: Array[ColorRect] = []
var _colour := Color.WHITE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(Hud.WALNUT, 0.92)
	_style.set_corner_radius_all(12)
	_style.anti_aliasing = true
	_style.set_border_width_all(2)
	_style.shadow_color = Color(0, 0, 0, 0.35)
	_style.shadow_size = 4
	_style.shadow_offset = Vector2(0, 3)
	_frame = Panel.new()
	_frame.add_theme_stylebox_override("panel", _style)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_rows)
	_rows.position = PAD


## The rows for now, over a head at `head` on screen.
func show_rows(rows: Array, head: Vector2, colour: Color, dt: float) -> void:
	var want := 0.0 if rows.is_empty() else 1.0
	modulate.a = move_toward(modulate.a, want, dt * (8.0 if want > 0 else 5.0))
	visible = modulate.a > 0.01
	if rows.is_empty():
		# Gone: the next rows spring in afresh.
		if not visible:
			_built = ""
		return
	if colour != _colour:
		_colour = colour
		_style.border_color = colour.lerp(Hud.BRASS, 0.25)
		queue_redraw()
	var sig := JSON.stringify(rows.map(func(r): return [r.get("input", ""), r.get("glyph", {}), r.get("verb", ""), r.has("progress")]))
	if sig != _built:
		_build(rows, _built == "")
		_built = sig
	var bar := 0
	for r in rows:
		if r.has("progress") and bar < _bars.size():
			var track: ColorRect = _bars[bar]
			(track.get_child(0) as ColorRect).size.x = track.size.x * clampf(float(r.progress), 0.0, 1.0)
			bar += 1
	# Over the head, the tail pointing down at it; kept on screen.
	var box := _rows.get_combined_minimum_size() + PAD * 2
	_frame.size = box
	var view := get_viewport_rect().size
	var at := Vector2(head.x - box.x / 2, head.y - LIFT - TAIL - box.y)
	at.x = clampf(at.x, MARGIN, view.x - box.x - MARGIN)
	at.y = clampf(at.y, MARGIN, view.y - box.y - MARGIN)
	position = at.round()
	size = box
	_tail_x = clampf(head.x - at.x, 14.0, box.x - 14.0)
	queue_redraw()


## The glyph for this input, if on show, sinks: the press seen.
func press(input: String) -> void:
	if _glyphs.has(input):
		(_glyphs[input] as Glyph).press()


var _tail_x := 0.0


func _draw() -> void:
	var y := _frame.size.y
	var pts := PackedVector2Array([Vector2(_tail_x - TAIL, y - 2), Vector2(_tail_x + TAIL, y - 2), Vector2(_tail_x, y + TAIL)])
	draw_colored_polygon(pts, _style.border_color)
	draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(3, 0), pts[1] - Vector2(3, 0), pts[2] - Vector2(0, 4)]), _style.bg_color)


func _build(rows: Array, fresh: bool) -> void:
	var before := {}
	for c in _rows.get_children():
		before[c.get_meta("sig", "")] = true
		_rows.remove_child(c)
		c.queue_free()
	_glyphs.clear()
	_bars.clear()
	for r in rows:
		var line := VBoxContainer.new()
		line.add_theme_constant_override("separation", 4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(row)
		var input: String = r.get("input", "")
		if input != "":
			var g := Glyph.new()
			g.set_spec(r.get("glyph", {}), GLYPH_H)
			row.add_child(g)
			_glyphs[input] = g
		var words := Label.new()
		words.text = r.get("verb", "")
		words.add_theme_font_override("font", Hud.ARCADE)
		words.add_theme_font_size_override("font_size", 10)
		words.add_theme_color_override("font_color", Hud.CREAM)
		words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		words.custom_minimum_size.y = GLYPH_H if input != "" else 0.0
		row.add_child(words)
		if r.has("progress"):
			var track := ColorRect.new()
			track.color = Color("#241d52")
			track.custom_minimum_size = Vector2(0, 6)
			track.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var fill := ColorRect.new()
			fill.color = Hud.C.gold
			fill.size = Vector2(0, 6)
			fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
			track.add_child(fill)
			line.add_child(track)
			_bars.append(track)
		var sig := JSON.stringify([input, r.get("verb", "")])
		line.set_meta("sig", sig)
		_rows.add_child(line)
		# What is new springs in; the rest stays put.
		if fresh or not before.has(sig):
			_spring(line)
	if fresh:
		_spring(self)


func _spring(c: Control) -> void:
	c.pivot_offset = c.get_combined_minimum_size() / 2
	c.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
