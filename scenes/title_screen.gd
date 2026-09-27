class_name TitleScreen
extends CanvasLayer
## The title screen, first thing on: the cover picture filling the screen and
## "press to start" blinking at the bottom. Any key, button or click goes on
## to the menu (started).
##
## The picture covers the screen, cropped at the sides or at the top (the
## floor and the thieves stay), but never so much that the title is cut: past
## that it shrinks, and the rest is a dark band.

signal started

const PICTURE := "res://assets/ui/portada.jpg"
## Where the title is in the picture, as fractions of its width and height,
## and the margin kept round it.
const TITLE := Rect2(0.28, 0.13, 0.44, 0.41)
const MARGIN := 0.02
const BACK := Color("#140c24")

var _picture: Texture2D
var _canvas: Control
var _press: Label
var _t := 0.0
var _leaving := false


## Whether there is a picture to show.
static func available() -> bool:
	return ResourceLoader.exists(PICTURE)


func _ready() -> void:
	layer = 50
	_picture = load(PICTURE)
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_draw_picture)
	_canvas.resized.connect(_canvas.queue_redraw)
	add_child(_canvas)
	_press = Label.new()
	_press.text = Text.t("TITLE_PRESS")
	_press.add_theme_font_override("font", Hud.ARCADE)
	_press.add_theme_font_size_override("font_size", 22)
	_press.add_theme_color_override("font_color", Hud.CREAM)
	_press.add_theme_color_override("font_outline_color", Color("#1a0f2e"))
	_press.add_theme_constant_override("outline_size", 12)
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_press.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_press.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_press.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_press.offset_bottom = -36
	_canvas.add_child(_press)


func _process(delta: float) -> void:
	_t += delta
	if not _leaving:
		_press.modulate.a = 0.55 + 0.45 * cos(_t * 3.2)


## The picture's place on a screen of this size: covering it, but no bigger
## than keeps the title (and its margin) in sight; kept at the bottom when
## the top is cropped, centred otherwise.
static func placement(screen: Vector2, picture: Vector2) -> Rect2:
	var s := maxf(screen.x / picture.x, screen.y / picture.y)
	s = minf(s, screen.x / (picture.x * (TITLE.size.x + MARGIN * 2.0)))
	s = minf(s, screen.y / (picture.y * (1.0 - TITLE.position.y + MARGIN)))
	var size := picture * s
	var at := (screen - size) / 2.0
	if size.y > screen.y:
		at.y = screen.y - size.y
	return Rect2(at, size)


func _draw_picture() -> void:
	var screen := _canvas.size
	_canvas.draw_rect(Rect2(Vector2.ZERO, screen), BACK)
	_canvas.draw_texture_rect(_picture, placement(screen, _picture.get_size()), false)


func _input(event: InputEvent) -> void:
	if _leaving:
		get_viewport().set_input_as_handled()
		return
	var go := false
	if event is InputEventKey:
		go = event.pressed and not event.echo and event.keycode not in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]
	elif event is InputEventJoypadButton or event is InputEventMouseButton:
		go = event.pressed
	if not (event is InputEventMouseMotion or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()
	if go:
		_leave()


func _leave() -> void:
	_leaving = true
	_press.modulate.a = 1.0
	started.emit()
	var tw := create_tween()
	tw.tween_property(_canvas, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
