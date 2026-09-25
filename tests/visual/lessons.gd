extends Control
## The nights' lessons (LO NUEVO) one at a time, big, with their title and
## line: ← → (or A D) to go through them, Esc to quit.
##   godot tests/visual/lessons.tscn              (from the first)
##   godot tests/visual/lessons.tscn -- guard     (from that one)

var names: Array = []
var index := 0
var stage: MenuStage
var picture := TextureRect.new()
var title := Label.new()
var line := Label.new()
var count := Label.new()


func _ready() -> void:
	names = Story.LESSONS.keys()
	var bg := ColorRect.new()
	bg.color = Color("#0f0d14")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(0, 560)
	picture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(picture)
	for l in [title, line, count]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	title.add_theme_font_override("font", Hud.ARCADE)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#f0c46a"))
	line.add_theme_font_size_override("font_size", 22)
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", Color("#8a8a9a"))
	var args := OS.get_cmdline_user_args()
	_show(maxi(0, names.find(args[0])) if not args.is_empty() else 0)


func _show(i: int) -> void:
	index = posmod(i, names.size())
	if stage:
		stage.queue_free()
	var lesson: Dictionary = Story.LESSONS[names[index]]
	stage = MenuStage.make(lesson.stage)
	stage.size = Vector2i(1260, 840)
	add_child(stage)
	stage.active = true
	picture.texture = stage.get_texture()
	title.text = Text.t(lesson.title)
	line.text = Text.t(lesson.text)
	count.text = "%s  ·  %d / %d  ·  ← →  para cambiar, Esc para salir" % [names[index], index + 1, names.size()]


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	match (e as InputEventKey).keycode:
		KEY_RIGHT, KEY_D, KEY_SPACE: _show(index + 1)
		KEY_LEFT, KEY_A: _show(index - 1)
		KEY_ESCAPE: get_tree().quit()
