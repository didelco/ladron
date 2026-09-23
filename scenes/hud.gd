class_name Hud
extends CanvasLayer
## Everything drawn over the game: the status line, the log, the job's
## progress and the arrow to the objective, the guards' yell, and the
## full-screen panels (title, mission, pause, end of round).

const C := {
	"text": Color("#eef2ff"),
	"dim": Color("#9aa0c8"),
	"gold": Color("#ffe066"),
	"alert": Color("#ff3d6e"),
	"safe": Color("#22d3ee"),
	"green": Color("#4ade80"),
	"panel": Color("#0b0820", 0.92),
}
## How long the yell fills the screen.
const SHOUT_S := 1.4

var _status: Label
var _log: Label
var _job: Label
var _bar_back: ColorRect
var _bar: ColorRect
var _arrow: Label
var _shout: Control
var _shout_word: Label
var _shout_text: Label
var _shout_arrow: Label
var _shout_left := 0.0
var _shout_angle := 0.0
var _panel: ColorRect
var _panel_box: VBoxContainer


func _ready() -> void:
	_status = _label(24, C.text)
	_status.position = Vector2(24, 16)
	_log = _label(15, C.dim)
	_log.position = Vector2(24, 64)
	_job = _label(20, C.gold)
	_job.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_back = ColorRect.new()
	_bar_back.color = Color("#241d52")
	add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = C.gold
	add_child(_bar)
	_arrow = _label(40, C.gold)
	_arrow.text = "▶"
	_arrow.pivot_offset = Vector2(14, 28)

	_shout = Control.new()
	_shout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shout)
	_shout_word = _label(120, C.alert, _shout)
	_shout_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout_text = _label(20, C.gold, _shout)
	_shout_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shout_arrow = _label(64, C.alert, _shout)
	_shout_arrow.text = "▶"
	_shout.visible = false

	_panel = ColorRect.new()
	_panel.color = C.panel
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(centre)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 14)
	centre.add_child(_panel_box)


func _label(size: int, colour: Color, parent: Node = self) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_y", 2)
	parent.add_child(l)
	return l


# --- Panels --------------------------------------------------------------------

## A full-screen panel: a title, lines of text, an optional picture (the
## mission map) and a footer with what to press.
func show_panel(title: String, title_colour: Color, lines: Array, footer: String, picture: Texture2D = null) -> void:
	for c in _panel_box.get_children():
		c.queue_free()
	var t := _label(56, title_colour, _panel_box)
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for line in lines:
		var l := _label(20, C.text, _panel_box)
		l.text = line
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if picture:
		var r := TextureRect.new()
		r.texture = picture
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		var size := Vector2(picture.get_size())
		var k := minf(720.0 / size.x, 420.0 / size.y)
		r.custom_minimum_size = size * k
		r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_panel_box.add_child(r)
	var f := _label(22, C.gold, _panel_box)
	f.text = footer
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.visible = true


func hide_panel() -> void:
	_panel.visible = false


## The mission map: the plan, the route from the way in to the piece to the
## door, and where each guard starts.
static func mission_map(guards: Array[Guard]) -> ImageTexture:
	var s := 8
	var img := Image.create(Museum.w * s, Museum.h * s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in Museum.h:
		for x in Museum.w:
			if Museum.is_outside(x, y):
				continue
			var t := Museum.grid[y * Museum.w + x]
			var c := Color("#1a1538") if t == Tiles.WALL else (Color("#3a3a5a") if t == Tiles.COVER else Color("#2a2550"))
			img.fill_rect(Rect2i(x * s, y * s, s, s), c)
	for t in Heist.route:
		img.fill_rect(Rect2i(t.x * s + s / 2 - 1, t.y * s + s / 2 - 1, 2, 2), Color("#e8ddc0"))
	var mark := func(t: Vector2i, colour: Color, r: int) -> void:
		img.fill_rect(Rect2i(t.x * s + s / 2 - r, t.y * s + s / 2 - r, r * 2, r * 2), colour)
	# Guards first: the way in, the piece and the door go on top.
	for g in guards:
		mark.call(Vector2i(int(g.x), int(g.y)), C.alert, 3)
	mark.call(Heist.start, C.safe, 3)
	mark.call(Heist.at, Color(Heist.loot.colour), 4)
	mark.call(Heist.exit, C.green, 3)
	return ImageTexture.create_from_image(img)


# --- During play -----------------------------------------------------------------

## The status line, the log, the job and the arrow to the objective.
## job is {"working": bool, "progress": float, "verb": String, "carrying":
## bool, "dropped": bool, "name": String}; objective_angle is in screen terms,
## or NAN to hide the arrow.
func update_play(status: String, status_colour: Color, log_lines: Array[String], job: Dictionary, objective_angle: float, objective_colour: Color) -> void:
	_status.text = status
	_status.add_theme_color_override("font_color", status_colour)
	_log.text = "\n".join(log_lines)
	var view := get_viewport().get_visible_rect().size
	var working: bool = job.get("working", false)
	_bar_back.visible = working
	_bar.visible = working
	if working:
		var w := 360.0
		_bar_back.position = Vector2(view.x / 2 - w / 2, view.y - 70)
		_bar_back.size = Vector2(w, 14)
		_bar.position = _bar_back.position
		_bar.size = Vector2(w * float(job.progress), 14)
	if working:
		_job.text = job.verb
	elif job.get("carrying", false):
		_job.text = "TIENES %s · ¡A LA SALIDA!" % String(job.name).to_upper()
	elif job.get("dropped", false):
		_job.text = "%s ESTÁ EN EL SUELO" % String(job.name).to_upper()
	else:
		_job.text = ""
	_job.size = Vector2(view.x, 30)
	_job.position = Vector2(0, view.y - 108)
	_arrow.visible = not is_nan(objective_angle)
	if _arrow.visible:
		_arrow.add_theme_color_override("font_color", objective_colour)
		_arrow.position = view / 2 + Vector2(cos(objective_angle) * view.x * 0.45, sin(objective_angle) * view.y * 0.42) - Vector2(14, 28)
		_arrow.rotation = objective_angle


## A guard's yell: huge for a beat, leaning and pointing towards where it
## came from, with who heard it underneath.
func shout(word: String, text: String, angle: float) -> void:
	_shout_word.text = word
	_shout_text.text = text
	_shout_angle = angle
	_shout_left = SHOUT_S
	_shout.visible = true


func _process(dt: float) -> void:
	if _shout_left <= 0:
		return
	_shout_left -= dt
	var view := get_viewport().get_visible_rect().size
	var t := 1.0 - _shout_left / SHOUT_S
	# Slams in oversized, holds, then drops away.
	var k := 1.9 - 0.9 * minf(1.0, t / 0.08) if t < 0.2 else (1.0 if t < 0.78 else 1.0 + (t - 0.78) * 0.4)
	var lean := Vector2(cos(_shout_angle), sin(_shout_angle)) * Vector2(view.x * 0.06, view.y * 0.06)
	_shout_word.scale = Vector2.ONE * k
	_shout_word.size = Vector2(view.x, 160)
	_shout_word.pivot_offset = Vector2(view.x / 2, 80)
	_shout_word.position = Vector2(0, view.y / 2 - 110) + lean
	_shout_text.size = Vector2(view.x, 30)
	_shout_text.position = Vector2(0, view.y / 2 + 50)
	_shout_arrow.position = view / 2 + Vector2(cos(_shout_angle) * view.x * 0.44, sin(_shout_angle) * view.y * 0.4) - Vector2(20, 40)
	_shout_arrow.pivot_offset = Vector2(20, 40)
	_shout_arrow.rotation = _shout_angle
	_shout.modulate.a = 1.0 if t < 0.78 else clampf(1.0 - (t - 0.78) / 0.22, 0.0, 1.0)
	if _shout_left <= 0:
		_shout.visible = false
