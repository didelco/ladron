class_name EndPages
extends RefCounted
## The two ends of a night (Hud's "newspaper" and "mugshot" menu items),
## each a few big things and plenty of air, and nothing alike.
##
## Got away with the piece: the town paper's front page, light paper laid
## out wide — the masthead, a big headline and under it, side by side, the
## piece's photo printed in dots and the night in three or four big
## figures, one under another.
##
## Caught: the police file, a white sheet of paper the shape of an A4, a
## little askew and taller than the screen, so only its top shows: the
## station's letterhead, the same two photos every time (the thief's head
## from the front and in profile against the height chart, in hard black
## and white) over a strip with the file's number, two lines of the form
## filled in and a box ticked, and the rest of the form running off the
## bottom. All grey but the red stamp.
##
## And before a heist, the gang's job sheet (Hud's "card"), on the same
## cream paper: a polaroid of the piece turning, taped on, and beside it
## which job this is, the piece's name, what it is like and its tale — so
## the words sit on paper, not straight on the museum's picture.
##
## Faces: the game's plain one for reading and its arcade one for small
## capitals, and two of a paper's: a blackletter for the masthead, a fat
## serif for the headline, the figures and the stamp.

## The paper's colours and the file's: all here, to change in one place.
const PAPER := Color("#efe6d1")
const PAPER_INK := Color("#241a13")
const PAPER_INK_SOFT := Color("#6e5c49")
## The studio behind the piece in its photo, before it is printed.
const PHOTO_BACK := Color("#cfc3ab")
const SHEET := Color("#f7f7f5")
## The job sheet's polaroid: its photo's dark back and the tape on it.
const CARD_PHOTO_BACK := Color("#2a2233")
const CARD_TAPE := Color(0.95, 0.9, 0.72, 0.6)
const SHEET_INK := Color("#1f2023")
const SHEET_INK_SOFT := Color("#7a7c80")
const SHEET_LINE := Color("#b9bbbe")
const STAMP := Color("#d3263a")

const MASTHEAD := preload("res://assets/fonts/UnifrakturMaguntia-Book.ttf")
const HEADLINE := preload("res://assets/fonts/AbrilFatface-Regular.ttf")

## The paper's width inside its margins; the piece's photo, and the column
## of figures beside it.
const PAPER_W := 720
const PAPER_PHOTO := Vector2(456, 236)
const FIGURES_W := 236
## Each of a story heist's three stars under the headline, across.
const STAR_SIZE := 34.0
## The police sheet: an A4's shape (1 : 1.414), and how much of it the menu
## makes room for — the rest runs off the bottom of the screen.
const SHEET_W := 540.0
const SHEET_H := SHEET_W * 1.414
const SHEET_SHOWN := 620.0
const SHEET_MARGIN := 30
## Each of the two photos on it, and how far the sheet is turned (degrees).
const SHEET_PHOTO := Vector2(237, 190)
## The job sheet: how wide it is, its words, its photo, and its tilt.
const CARD_W := 860
const CARD_TEXT_W := 470
const CARD_PHOTO := Vector2(260, 220)
const CARD_TILT := -0.8
## The job sheet as the story's own page before a heist: this much bigger.
const CARD_BIG := 1.3
const SHEET_TILT := 1.2

## A photo printed in a newspaper: grey on the paper, in a screen of dots at
## 45 degrees, bigger where it is darker, over a plain studio backdrop.
const HALFTONE_SHADER := """
shader_type canvas_item;
uniform vec4 paper : source_color;
uniform vec4 ink : source_color;
uniform vec4 back : source_color;
uniform float dots = 3.2;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	vec3 bg = mix(back.rgb * 1.1, back.rgb * 0.78, UV.y);
	vec3 c = mix(bg, t.rgb, t.a);
	float l = clamp(dot(c, vec3(0.299, 0.587, 0.114)) * 1.2, 0.0, 1.0);
	vec2 p = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * FRAGCOORD.xy / dots;
	float d = length(fract(p) - 0.5);
	float r = sqrt(1.0 - l) * 0.62;
	float printed = 1.0 - smoothstep(r - 0.12, r + 0.12, d);
	float tone = mix(1.0 - l, printed, 0.5);
	COLOR = vec4(mix(paper.rgb, ink.rgb, tone * 0.92), 1.0);
}
"""

## A police photo: black and white, hard — the shadows near black — and
## grainy.
const MUGSHOT_SHADER := """
shader_type canvas_item;
float grain(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}
void fragment() {
	vec3 c = texture(TEXTURE, UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	l = pow(smoothstep(0.06, 0.82, l), 1.35);
	l += (grain(floor(FRAGCOORD.xy / 1.5)) - 0.5) * 0.09;
	COLOR = vec4(vec3(l), 1.0);
}
"""

## White office paper: a faint grain, and fibres running every which way,
## worked out from where on the sheet each point is (so it turns with it).
const SHEET_SHADER := """
shader_type canvas_item;
uniform vec4 paper : source_color;
uniform vec2 box = vec2(540.0, 763.0);
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void fragment() {
	vec2 p = UV * box;
	float grain = hash(floor(p)) - 0.5;
	float cloud = noise(p / 38.0) - 0.5;
	float fibres = noise(p * vec2(0.9, 0.08)) * noise(p * vec2(0.07, 0.8));
	float v = 1.0 + grain * 0.035 + cloud * 0.03 - smoothstep(0.35, 0.6, fibres) * 0.035;
	COLOR = vec4(paper.rgb * v, 1.0);
}
"""


## The front page: {"name", "headline", "photo": Texture2D, "figures":
## [[number, what], ...], "stars"?: [[won, new], ...], "star_names"?}: the
## masthead, the headline, under it a story heist's three stars, and the
## photo on the left and the figures on the right. It spins in, as front
## pages do in old films.
static func newspaper(d: Dictionary) -> Control:
	var paper := PanelContainer.new()
	paper.add_theme_stylebox_override("panel", _sheet(PAPER, 30, 18))
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	paper.add_child(page)
	var name := _line(d.get("name", ""), 42, PAPER_INK, page, MASTHEAD)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rule(page, 2, PAPER_INK)
	var headline := _line(d.get("headline", ""), 42, PAPER_INK, page, HEADLINE)
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.custom_minimum_size.x = PAPER_W
	headline.add_theme_constant_override("line_spacing", -8)
	if d.has("stars"):
		page.add_child(_stars(d.stars, d.get("star_names", [])))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", PAPER_W - int(PAPER_PHOTO.x) - FIGURES_W)
	page.add_child(row)
	if d.get("photo") is Texture2D:
		var photo := TextureRect.new()
		photo.texture = d.photo
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		photo.custom_minimum_size = PAPER_PHOTO
		var print := ShaderMaterial.new()
		print.shader = Shader.new()
		print.shader.code = HALFTONE_SHADER
		print.set_shader_parameter("paper", PAPER)
		print.set_shader_parameter("ink", PAPER_INK)
		print.set_shader_parameter("back", PHOTO_BACK)
		photo.material = print
		row.add_child(photo)
	row.add_child(_figures(d.get("figures", [])))
	_spin_in(paper)
	return _loose(paper)


## The job sheet before a heist: {"heading", "name", "blurb", "story",
## "photo": Texture2D (the piece turning, live)}: the polaroid on the left,
## the words on the right, the sheet a hair askew, dropping in. k: how big,
## everything in it (the story's own page before a heist is CARD_BIG).
static func piece_card(d: Dictionary, k := 1.0) -> Control:
	var sheet := PanelContainer.new()
	var st := _sheet(PAPER, 0, 0)
	st.set_corner_radius_all(4)
	sheet.add_theme_stylebox_override("panel", st)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grain := ColorRect.new()
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := ShaderMaterial.new()
	paper.shader = Shader.new()
	paper.shader.code = SHEET_SHADER
	paper.set_shader_parameter("paper", PAPER)
	paper.set_shader_parameter("box", Vector2(CARD_W, 400) * k)
	grain.material = paper
	sheet.add_child(grain)
	var margin := MarginContainer.new()
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, int(34 * k))
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(28 * k))
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(margin)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(30 * k))
	margin.add_child(row)
	if d.get("photo") is Texture2D:
		row.add_child(_polaroid(d.photo, k))
	var text_w := int(CARD_TEXT_W * k)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", int(6 * k))
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.custom_minimum_size.x = text_w
	row.add_child(words)
	_line(d.get("heading", ""), int(15 * k), PAPER_INK_SOFT, words)
	var name := _line(d.get("name", ""), int(38 * k), PAPER_INK, words, HEADLINE)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = text_w
	name.add_theme_constant_override("line_spacing", int(-6 * k))
	var blurb := _line(d.get("blurb", ""), int(18 * k), PAPER_INK_SOFT, words)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size.x = text_w
	_rule(words, maxi(1, int(k)), PAPER_INK_SOFT)
	var tale := _line(d.get("story", ""), int(18 * k), PAPER_INK, words)
	tale.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tale.custom_minimum_size.x = text_w
	if k > 1.0:
		tale.add_theme_constant_override("line_spacing", int(4 * k))
	_drop_in(sheet, CARD_TILT)
	return _loose(sheet)


## A polaroid: the photo on white, with the wide strip under it, a little
## askew, and a strip of tape across its top.
static func _polaroid(photo: Texture2D, k := 1.0) -> Control:
	var frame := PanelContainer.new()
	var st := _box(Color("#fbfaf6"), Color(0, 0, 0, 0), 0)
	st.content_margin_left = 12 * k
	st.content_margin_right = 12 * k
	st.content_margin_top = 12 * k
	st.content_margin_bottom = 40 * k
	st.shadow_color = Color(0, 0, 0, 0.25)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 3)
	frame.add_theme_stylebox_override("panel", st)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := TextureRect.new()
	pic.texture = photo
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.custom_minimum_size = CARD_PHOTO * k
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The photo's own dark back, so the piece stands out as in a flash photo.
	var back := ColorRect.new()
	back.color = CARD_PHOTO_BACK
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(back)
	frame.add_child(pic)
	frame.rotation = deg_to_rad(-3.0)
	var holder := _loose(frame)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tape := ColorRect.new()
	tape.color = CARD_TAPE
	tape.size = Vector2(90, 26) * k
	tape.rotation = deg_to_rad(4.0)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(tape)
	holder.resized.connect(func() -> void:
		tape.position = Vector2(holder.size.x / 2 - 45 * k, -12 * k))
	return holder


## The police file: {"photos": [MugshotStage front, MugshotStage side],
## "number", "letterhead", "stamp", "rows": [[label, value], ...], "tick":
## [question, "YES|NO"], "more": [label, ...], "prints"}: the sheet, only
## its top showing (SHEET_SHOWN), the photos flashing as they come up and
## the stamp coming down after.
static func mugshot(d: Dictionary) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(SHEET_W, SHEET_SHOWN)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The sheet, with its shadow, and the paper over it.
	var sheet := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = SHEET
	st.set_corner_radius_all(3)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 26
	st.shadow_offset = Vector2(0, 10)
	sheet.add_theme_stylebox_override("panel", st)
	sheet.size = Vector2(SHEET_W, SHEET_H)
	sheet.pivot_offset = Vector2(SHEET_W / 2, SHEET_SHOWN / 2)
	sheet.rotation = deg_to_rad(SHEET_TILT)
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(sheet)
	var grain := ColorRect.new()
	grain.set_anchors_preset(Control.PRESET_FULL_RECT)
	grain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := ShaderMaterial.new()
	paper.shader = Shader.new()
	paper.shader.code = SHEET_SHADER
	paper.set_shader_parameter("paper", SHEET)
	paper.set_shader_parameter("box", Vector2(SHEET_W, SHEET_H))
	grain.material = paper
	sheet.add_child(grain)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, SHEET_MARGIN)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(margin)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 14)
	margin.add_child(form)
	# The letterhead, on one line.
	_line(d.get("letterhead", ""), 20, SHEET_INK, form, HEADLINE)
	_rule(form, 2, SHEET_INK)
	# The two photos side by side, the number in a strip under them.
	var shots := VBoxContainer.new()
	shots.add_theme_constant_override("separation", 0)
	form.add_child(shots)
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	shots.add_child(pair)
	for stage in d.get("photos", []):
		pair.add_child(_police_photo(stage))
	var strip := PanelContainer.new()
	strip.add_theme_stylebox_override("panel", _box(SHEET_INK, SHEET_INK, 0, 5))
	shots.add_child(strip)
	var number := _line(d.get("number", ""), 12, SHEET, strip, Hud.ARCADE)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The form filled in.
	var fields := VBoxContainer.new()
	fields.add_theme_constant_override("separation", 6)
	form.add_child(fields)
	for r in d.get("rows", []):
		_field(fields, r[0], r[1])
	var tick: Array = d.get("tick", [])
	if tick.size() == 2:
		var gap := Control.new()
		gap.custom_minimum_size.y = 4
		fields.add_child(gap)
		_tick(fields, tick[0], tick[1])
	# The rest of the form, running off the bottom: blank lines to fill in
	# and a box for the prints.
	var rest := HBoxContainer.new()
	rest.add_theme_constant_override("separation", 22)
	form.add_child(rest)
	var blank := VBoxContainer.new()
	blank.add_theme_constant_override("separation", 6)
	blank.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rest.add_child(blank)
	for label in d.get("more", []):
		_field(blank, label, "")
		_field(blank, "", "")
	rest.add_child(_prints(d.get("prints", "")))
	# The stamp, slammed down on the form.
	var stamp := Label.new()
	stamp.text = d.get("stamp", "")
	stamp.add_theme_font_override("font", HEADLINE)
	stamp.add_theme_font_size_override("font_size", 26)
	stamp.add_theme_color_override("font_color", STAMP)
	stamp.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), STAMP, 4, 8, 10))
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(stamp)
	# At the right of the form filled in, where its lines are short: clear of
	# the faces, the number and what is written.
	var place := func() -> void:
		stamp.pivot_offset = stamp.size / 2
		var at := fields.get_global_transform() * fields.size
		stamp.position = sheet.get_global_transform().affine_inverse() * at - stamp.size * Vector2(1.0, 0.95)
	stamp.resized.connect(place)
	fields.item_rect_changed.connect(place)
	_stamp_down(stamp, -8)
	return holder


# --- Pieces ------------------------------------------------------------------------

## The night in figures, one under another down a column: each figure big
## in the paper's ink, what it counts beside it in small capitals, thin
## rules between.
static func _figures(figures: Array) -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = FIGURES_W
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 6)
	for i in figures.size():
		if i > 0:
			_rule(column, 1, Color(PAPER_INK, 0.35))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		column.add_child(line)
		var number := _line(figures[i][0], 38, PAPER_INK, line, HEADLINE)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.custom_minimum_size.x = 104
		var what := _line(figures[i][1], 10, PAPER_INK_SOFT, line, Hud.ARCADE)
		what.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		what.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return column


## A story heist's three stars under the headline, printed: each one won
## solid in the paper's ink, or, new tonight, in the stamp's red and
## stamped down once the page has landed; one not won, just its outline.
## What each is for in small capitals under it (names).
static func _stars(row: Array, names: Array) -> Control:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 34)
	for i in row.size():
		var won: bool = row[i][0]
		var fresh: bool = row[i][1]
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		line.add_child(cell)
		var star := Control.new()
		star.custom_minimum_size = Vector2(STAR_SIZE, STAR_SIZE)
		star.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.pivot_offset = Vector2(STAR_SIZE, STAR_SIZE) / 2
		var ink := STAMP if fresh else PAPER_INK
		star.draw.connect(func() -> void:
			var points := _star_points(Vector2(STAR_SIZE, STAR_SIZE) / 2, STAR_SIZE * 0.5, STAR_SIZE * 0.21)
			if won:
				star.draw_colored_polygon(points, ink)
			else:
				points.append(points[0])
				star.draw_polyline(points, Color(PAPER_INK, 0.45), 2.0, true))
		cell.add_child(star)
		if won and fresh:
			_stamp_down(star, -8.0 + i * 8.0)
		if i < names.size():
			var what := _line(names[i], 9, PAPER_INK if won else PAPER_INK_SOFT, cell, Hud.ARCADE)
			what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return line


## A five-pointed star round centre, point up: outer and inner radius.
static func _star_points(centre: Vector2, outer: float, inner: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 10:
		var a := -PI / 2 + k * PI / 5
		out.append(centre + Vector2(cos(a), sin(a)) * (outer if k % 2 == 0 else inner))
	return out


## A police photo, grey, with the flash going off.
static func _police_photo(stage: MugshotStage) -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(SHEET_INK, SHEET_INK, 0, 0))
	var picture := Control.new()
	picture.custom_minimum_size = SHEET_PHOTO
	picture.clip_contents = true
	frame.add_child(picture)
	picture.add_child(stage)
	stage.active = true
	var photo := TextureRect.new()
	photo.texture = stage.get_texture()
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bw := ShaderMaterial.new()
	bw.shader = Shader.new()
	bw.shader.code = MUGSHOT_SHADER
	photo.material = bw
	picture.add_child(photo)
	var flash := ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.add_child(flash)
	flash.tree_entered.connect(func() -> void:
		flash.create_tween().tween_property(flash, "color:a", 0.0, 0.7).set_delay(0.15), CONNECT_ONE_SHOT)
	return frame


## A line of the form: its name small, what was written on it, the line.
static func _field(parent: Node, label: String, value: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	parent.add_child(box)
	if label != "":
		_line(label, 8, SHEET_INK_SOFT, box, Hud.ARCADE)
	var v := _line(value, 16, SHEET_INK, box)
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.custom_minimum_size.x = 200
	_rule(box, 1, SHEET_LINE)


## A question with two boxes, the first ticked: "¿REINCIDENTE? [X] SÍ [ ] NO".
static func _tick(parent: Node, question: String, answers: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var q := _line(question, 8, SHEET_INK_SOFT, row, Hud.ARCADE)
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var words := answers.split("|")
	for i in words.size():
		var box := Control.new()
		box.custom_minimum_size = Vector2(16, 16)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ticked := i == 0
		box.draw.connect(func() -> void:
			box.draw_rect(Rect2(Vector2.ZERO, box.size), SHEET_INK, false, 1.5)
			if ticked:
				box.draw_line(Vector2(3, 3), box.size - Vector2(3, 3), SHEET_INK, 2.5)
				box.draw_line(Vector2(box.size.x - 3, 3), Vector2(3, box.size.y - 3), SHEET_INK, 2.5))
		row.add_child(box)
		var w := _line(words[i], 14, SHEET_INK, row)
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER


## A box for the fingerprints, with one in it: grey ridges round a whorl.
static func _prints(label: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_line(label, 8, SHEET_INK_SOFT, box, Hud.ARCADE)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(120, 120)
	pad.draw.connect(func() -> void:
		pad.draw_rect(Rect2(Vector2.ZERO, pad.size), SHEET_LINE, false, 1.5)
		# Oval ridges round a whorl, each broken somewhere else.
		pad.draw_set_transform(pad.size / 2 + Vector2(0, 4), 0.25, Vector2(0.78, 1.0))
		for k in 9:
			var r := 5.0 + k * 5.0
			var gap := 0.35 + 0.15 * float(k % 3)
			var from := k * 2.1
			pad.draw_arc(Vector2.ZERO, r, from + gap, from + TAU, 40, Color(SHEET_INK, 0.5), 2.0)
		pad.draw_set_transform(Vector2.ZERO))
	box.add_child(pad)
	return box


## c in a plain holder its own size: a container sets its children's
## rotation and scale back to none, and these turn and grow.
static func _loose(c: Control) -> Control:
	var holder := Control.new()
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.add_child(c)
	var fit := func() -> void:
		var m := c.get_combined_minimum_size()
		holder.custom_minimum_size = m
		c.size = m
		c.pivot_offset = m / 2
	c.minimum_size_changed.connect(fit)
	# Once in, and laid out: through c's own method, so that nothing is
	# called should it go before then.
	holder.tree_entered.connect(func() -> void: c.update_minimum_size.call_deferred())
	return holder


static func _line(text: String, size: int, colour: Color, parent: Node, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	if font:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A sheet of paper: its colour, a little rounded, lifted off the screen by
## a soft shadow.
static func _sheet(colour: Color, margin_x: int, margin_y: int) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = colour
	st.set_corner_radius_all(8)
	st.shadow_color = Color(0, 0, 0, 0.55)
	st.shadow_size = 22
	st.shadow_offset = Vector2(0, 8)
	st.content_margin_left = margin_x
	st.content_margin_right = margin_x
	st.content_margin_top = margin_y
	st.content_margin_bottom = margin_y
	return st


static func _box(fill: Color, border: Color, width: int, pad := 0, radius := 0) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fill
	st.border_color = border
	st.set_border_width_all(width)
	st.set_corner_radius_all(radius)
	st.set_content_margin_all(pad)
	return st


static func _rule(parent: Node, thick: int, colour: Color) -> void:
	var r := ColorRect.new()
	r.color = colour
	r.custom_minimum_size = Vector2(0, thick)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)


## Spinning in from nothing to the page, a turn and a half, landing a hair
## askew.
static func _spin_in(c: Control) -> void:
	c.scale = Vector2.ONE * 0.05
	c.rotation = -TAU * 1.5
	c.tree_entered.connect(func() -> void:
		var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.6)
		tw.tween_property(c, "rotation", deg_to_rad(-0.8), 0.6), CONNECT_ONE_SHOT)


## Dropping onto the table: from a little above and larger, landing askew.
static func _drop_in(c: Control, degrees: float) -> void:
	c.rotation = deg_to_rad(degrees - 4.0)
	c.scale = Vector2.ONE * 1.08
	c.modulate.a = 0.0
	c.tree_entered.connect(func() -> void:
		var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.35)
		tw.tween_property(c, "rotation", deg_to_rad(degrees), 0.35)
		tw.tween_property(c, "modulate:a", 1.0, 0.15), CONNECT_ONE_SHOT)


## The stamp comes down hard: big and faint, then there, askew.
static func _stamp_down(c: Control, degrees := -9.0) -> void:
	c.rotation = deg_to_rad(degrees)
	c.scale = Vector2.ONE * 2.2
	c.modulate.a = 0.0
	c.tree_entered.connect(func() -> void:
		var tw := c.create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "scale", Vector2.ONE, 0.25).set_delay(0.55)
		tw.tween_property(c, "modulate:a", 1.0, 0.12).set_delay(0.55), CONNECT_ONE_SHOT)
