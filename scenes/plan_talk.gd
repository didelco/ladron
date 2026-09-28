class_name PlanTalk
extends Control
## The telling over the plan, once it is open in front of you (Tour,
## CityStage.raise_plan): one beat after another (PlanBeats), the camera
## closing in on where each happens, a ring round it and a card beside it
## joined to it by a line: the piece and its tale (the job sheet,
## EndPages.piece_card), what is new tonight with its little scene
## (LessonStage), the rules, the way in and out. Each beat told leaves its
## pin on the plan. The piece and the news wait for A; the rest go by on
## their own.
##
## Then the plan to look round (explore): the arrows go from pin to pin, A
## shows what one was about again, and ¡A ROBAR! (A on it, or Start) starts
## the heist. The goals for the stars, top right.
##
## modes: "story" telling, "explore" looking round, "look" a pin's card open.

## Start the heist.
signal go
## Back to the museum.
signal back
## The telling is over (skipped or done): not to be told again.
signal told

## The cards' look: all here, to change in one place.
const CARD := Color("#150f24", 0.9)
const CARD_EDGE := Color("#ffae42")
const CARD_TEXT := Color("#fff0d6")
const CARD_TITLE := Color("#ffe066")
const RING := Color("#ffc94a")
const PIN := Color("#1c1210")
## Each kind of pin's head (the piece's is the piece's own colour).
const PIN_HEADS := {"news": Color("#ffe066"), "rule": Color("#ff6b4a"), "start": Color("#2ec4a6"), "exit": Color("#4ade80")}
const LINE := Color("#ffc94a", 0.85)
## How close the camera comes on each kind of beat.
const ZOOM := {"piece": 1.35, "news": 1.3, "rule": 1.2, "start": 1.15, "exit": 1.15}
## How long a beat that goes by on its own stays: at least this, or this
## long a word.
const BEAT_S := 2.6
const WORD_S := 0.3
## The job sheet, this big beside the plan.
const SHEET_SCALE := 0.84
## A pin's head, and how far over its point it stands.
const PIN_R := 14.0
const PIN_UP := 30.0

var tour: Tour
var stage: CityStage
var beats: Array = []
## the job sheet's words and photo (EndPages.piece_card)
var sheet := {}
## the goals for the stars, [words, won]
var goals: Array = []
var mode := "story"
var step := -1
## the beat picked while looking round; beats.size() is the start button
var cursor := 0
## beats told so far: their pins are on the plan
var _told := {}
var _card: Control
var _card_for := -1
var _left := INF
var _t := 0.0
var _start: Button
var _goals: PanelContainer
var _stages: Array[MenuStage] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Tell it all, from the piece.
func tell() -> void:
	mode = "story"
	step = -1
	_next()


## Straight to looking round, every pin on the plan (told before).
func skip() -> void:
	for i in beats.size():
		_told[i] = true
	_drop_card()
	stage.plan_rest(0.0 if stage.hurry else 0.5)
	mode = "explore"
	cursor = 0
	_left = INF
	_explore_ui()
	told.emit()


func _next() -> void:
	step += 1
	if step >= beats.size():
		skip()
		return
	_show(step)
	var b: Dictionary = beats[step]
	if b.kind in ["piece", "news"]:
		_left = INF
	else:
		_left = maxf(BEAT_S, String(b.text).split(" ").size() * WORD_S)
	tour._set_hints([["accept", Text.t("TOUR_HINT_NEXT")], ["skip", Text.t("TOUR_HINT_SKIP")], ["back", Text.t("TOUR_HINT_MUSEUM")]])


## Beat i on screen: the camera on it, its card beside it, its pin placed.
func _show(i: int) -> void:
	_told[i] = true
	var b: Dictionary = beats[i]
	# The card goes on the side away from the point, the point on the other.
	var right := _side(b.at)
	stage.plan_look(b.at, ZOOM.get(b.kind, 1.2), Vector2(0.3 if right else 0.7, 0.5), 0.0 if stage.hurry else 0.8)
	_drop_card()
	_card_for = i
	match b.kind:
		"piece": _card = _piece_card()
		"news": _card = _news_card(b)
		_: _card = _line_card(b)
	add_child(_card)
	_card.set_meta("right", right)
	_card.modulate.a = 0.0
	var tw := _card.create_tween().set_parallel()
	tw.tween_property(_card, "modulate:a", 1.0, 0.25).set_delay(0.0 if stage.hurry else 0.35)


## Whether the card for a point goes on the right: the point is on the
## plan's left half.
func _side(at: Vector2) -> bool:
	return at.x < Museum.w * 0.5


func _drop_card() -> void:
	if _card:
		var old := _card
		_card = null
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 0.15)
		tw.tween_callback(old.queue_free)
	# Its little scene stops with it (and goes with it).
	for s in _stages:
		if is_instance_valid(s):
			s.active = false
	_stages.clear()
	_card_for = -1


func _process(dt: float) -> void:
	_t += dt
	if mode == "story" and _left < INF:
		_left -= dt
		if _left <= 0.0:
			_left = INF
			_next()
	if _card and is_instance_valid(_card):
		_place_card(dt)
	queue_redraw()


## The card beside its point, kept on screen.
func _place_card(dt: float) -> void:
	var view := get_viewport_rect().size
	var at := stage.plan_on_screen(beats[_card_for].at)
	var s := _card.get_combined_minimum_size() * _card.scale
	var right: bool = _card.get_meta("right", true)
	var goal := Vector2(at.x + 70 if right else at.x - 70 - s.x, at.y - s.y * 0.5)
	goal.x = clampf(goal.x, 24, view.x - s.x - 24)
	goal.y = clampf(goal.y, 90, view.y - s.y - 80)
	_card.position = goal if _card.position == Vector2.ZERO else _card.position.lerp(goal, 1.0 - exp(-dt * 14.0))


func _draw() -> void:
	if stage == null or stage.sheet == null:
		return
	# The pins of what has been told.
	for i in beats.size():
		if not _told.has(i):
			continue
		var p := stage.plan_on_screen(beats[i].at)
		_pin(p, i, i == _card_for or (mode != "story" and i == cursor))
	# The ring round the point being told, and the line to its card.
	if _card and _card_for >= 0 and is_instance_valid(_card):
		var p := stage.plan_on_screen(beats[_card_for].at)
		var r := 30.0 + sin(_t * 5.0) * 4.0
		draw_arc(p, r, 0, TAU, 48, RING, 4.0, true)
		draw_arc(p, r + 8.0, 0, TAU, 48, Color(RING, 0.35), 2.0, true)
		var box := Rect2(_card.position, _card.get_combined_minimum_size() * _card.scale)
		var edge := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))
		var dir := (edge - p).normalized()
		if p.distance_to(edge) > r + 6.0:
			draw_line(p + dir * (r + 2.0), edge, Color(LINE, LINE.a * _card.modulate.a), 3.0, true)
	# The start button's ring when it is the one picked.
	if mode == "explore" and cursor == beats.size() and _start:
		var box := _start.get_global_rect().grow(8)
		draw_rect(box, Color(RING, 0.6 + sin(_t * 5.0) * 0.3), false, 3.0)


## A pin on the plan, numbered in the order it was told: a head in its
## kind's colour on a needle stuck in the point, bigger when in hand.
func _pin(at: Vector2, i: int, lit: bool) -> void:
	var b: Dictionary = beats[i]
	var colour: Color = PIN_HEADS.get(b.kind, Color(Heist.loot.get("colour", "#ffffff")))
	var r := PIN_R * (1.3 if lit else 1.0)
	var head := at + Vector2(_fan(i), -PIN_UP * (1.15 if lit else 1.0))
	draw_circle(at, 5, PIN)
	draw_circle(at, 3, colour)
	draw_line(at, head, PIN, 3.0, true)
	draw_circle(head + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.35))
	draw_circle(head, r + 2.5, RING if lit else PIN)
	draw_circle(head, r, colour)
	# A shine on the head, like a real drawing pin.
	draw_circle(head + Vector2(-r * 0.35, -r * 0.35), r * 0.28, Color(1, 1, 1, 0.45))
	var f := get_theme_default_font()
	var size := int(r * 1.3)
	var label := str(i + 1)
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(f, head + Vector2(-w * 0.5, size * 0.36), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, PIN)


# --- Cards ------------------------------------------------------------------------

## The job sheet: the piece turning in its polaroid, which job, its name,
## what it is like and its tale.
func _piece_card() -> Control:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var card := EndPages.piece_card(sheet)
	holder.add_child(card)
	holder.scale = Vector2.ONE * SHEET_SCALE
	card.minimum_size_changed.connect(func() -> void:
		holder.custom_minimum_size = card.get_combined_minimum_size())
	return holder


## What is new: its title, its little scene, how it works.
func _news_card(b: Dictionary) -> Control:
	var box := _frame()
	var col: VBoxContainer = box.get_child(0)
	var head := _text(col, Text.t("TOUR_NEWS_HEAD"), 18, CARD_TITLE, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _text(col, b.title, 26, CARD_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tour._arcade(title)
	var stage3d := MenuStage.make(b.stage)
	col.add_child(stage3d)
	stage3d.active = true
	_stages.append(stage3d)
	var pic := TextureRect.new()
	pic.texture = stage3d.get_texture()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(360, 240)
	col.add_child(pic)
	var text := _text(col, b.text, 19, CARD_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 360
	return box


## A rule, or the way in or out: its mark and its line.
func _line_card(b: Dictionary) -> Control:
	var box := _frame()
	var col: VBoxContainer = box.get_child(0)
	var text := _text(col, b.text, 21, CARD_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 320
	return box


func _frame() -> PanelContainer:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = CARD
	st.set_corner_radius_all(16)
	st.border_color = CARD_EDGE
	st.set_border_width_all(3)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 10
	st.set_content_margin_all(18)
	box.add_theme_stylebox_override("panel", st)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	return box


func _text(parent: Node, words: String, size: int, colour: Color, arcade := false) -> Label:
	var l := Label.new()
	l.text = words
	if arcade:
		l.add_theme_font_override("font", Hud.ARCADE)
		size = int(size * 0.6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


# --- Looking round ----------------------------------------------------------------

## The start button and the goals, once the telling is over.
func _explore_ui() -> void:
	if _start == null:
		_start = Button.new()
		_start.text = Text.t("TOUR_START")
		_start.focus_mode = Control.FOCUS_NONE
		_start.add_theme_font_override("font", Hud.ARCADE)
		_start.add_theme_font_size_override("font_size", 16)
		for state in ["normal", "hover", "pressed"]:
			var st := StyleBoxFlat.new()
			st.bg_color = Color("#2ec4a6") if state == "normal" else Color("#3fe0c0")
			st.set_corner_radius_all(22)
			st.border_color = Color("#0c3d34")
			st.set_border_width_all(3)
			st.shadow_color = Color(0, 0, 0, 0.4)
			st.shadow_size = 8
			st.set_content_margin_all(14)
			st.content_margin_left = 34
			st.content_margin_right = 34
			_start.add_theme_stylebox_override(state, st)
		_start.add_theme_color_override("font_color", Color("#08231d"))
		_start.add_theme_color_override("font_hover_color", Color("#08231d"))
		_start.pressed.connect(func() -> void: go.emit())
		_start.mouse_entered.connect(func() -> void:
			cursor = beats.size())
		add_child(_start)
	_start.visible = true
	if _goals == null and not goals.is_empty():
		_goals = _frame()
		var col: VBoxContainer = _goals.get_child(0)
		_text(col, Text.t("TOUR_GOALS"), 18, CARD_TITLE, true)
		for g in goals:
			_text(col, ("%s  %s" % [StarSlots.FULL if g[1] else StarSlots.EMPTY, g[0]]), 18, CARD_TITLE if g[1] else CARD_TEXT)
		add_child(_goals)
	if _goals:
		_goals.visible = true
	_layout_explore()
	tour._set_hints([["move", Text.t("TOUR_HINT_LOOK")], ["accept", Text.t("TOUR_HINT_SEE")], ["skip", Text.t("TOUR_START")], ["back", Text.t("TOUR_HINT_MUSEUM")]])


func _layout_explore() -> void:
	var view := get_viewport_rect().size
	if _start:
		_start.size = _start.get_combined_minimum_size()
		_start.position = Vector2(view.x - _start.size.x - 36, view.y - _start.size.y - 30)
	if _goals:
		_goals.size = _goals.get_combined_minimum_size()
		_goals.position = Vector2(view.x - _goals.size.x - 24, 90)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and mode != "story":
		_layout_explore()


## The pin that way from the one picked (or the start button), if any.
func _move(dir: Vector2) -> void:
	var from := _cursor_at()
	var best := -1
	var score := INF
	for i in beats.size() + 1:
		if i == cursor:
			continue
		var p := _at(i)
		var d := p - from
		if d.length() < 1.0:
			continue
		var along := d.dot(dir)
		if along <= 0.0:
			continue
		# Straight ahead counts more than off to the side.
		var s := along + absf(d.dot(dir.orthogonal())) * 2.0
		if s < score:
			score = s
			best = i
	if best >= 0:
		cursor = best
		tour._nav()


func _cursor_at() -> Vector2:
	return _at(cursor)


## Where pin i is on screen (the start button for beats.size()).
func _at(i: int) -> Vector2:
	if i >= beats.size():
		return _start.get_global_rect().get_center() if _start else get_viewport_rect().size
	return stage.plan_on_screen(beats[i].at) + Vector2(_fan(i), -PIN_UP)


## Pins stuck in the same place (the news on the piece, two rules on one
## guard) fan out side by side, each head this far across from the point.
func _fan(i: int) -> float:
	var group: Array[int] = []
	for j in beats.size():
		if (beats[j].at as Vector2).distance_to(beats[i].at) < 0.9:
			group.append(j)
	return (group.find(i) - (group.size() - 1) * 0.5) * PIN_R * 2.3


## A press, in the mode it is in.
func act(what: String) -> void:
	match mode:
		"story":
			match what:
				"accept":
					tour._sound("nav")
					_next()
				"skip":
					tour._sound("ok")
					skip()
				"back": back.emit()
		"explore":
			match what:
				"left": _move(Vector2.LEFT)
				"right": _move(Vector2.RIGHT)
				"up": _move(Vector2.UP)
				"down": _move(Vector2.DOWN)
				"prev":
					cursor = (cursor - 1 + beats.size() + 1) % (beats.size() + 1)
					tour._nav()
				"next":
					cursor = (cursor + 1) % (beats.size() + 1)
					tour._nav()
				"accept":
					if cursor >= beats.size():
						go.emit()
					else:
						tour._sound("ok")
						_look(cursor)
				"skip": go.emit()
				"back": back.emit()
		"look":
			match what:
				"accept", "back":
					tour._sound("back")
					_unlook()
				"skip": go.emit()


## Pin i's card again, the camera on it.
func _look(i: int) -> void:
	mode = "look"
	if _start:
		_start.visible = false
	if _goals:
		_goals.visible = false
	_show(i)
	tour._set_hints([["accept", Text.t("TOUR_HINT_CLOSE")], ["skip", Text.t("TOUR_START")]])


func _unlook() -> void:
	_drop_card()
	stage.plan_rest(0.0 if stage.hurry else 0.5)
	mode = "explore"
	_explore_ui()


## The mouse over the plan: over a pin picks it, a click shows it.
func mouse(event: InputEvent) -> void:
	if mode == "story":
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			act("accept")
		return
	var at: Vector2 = event.position
	var best := -1
	var near := PIN_R * 1.8
	for i in beats.size():
		var d := at.distance_to(_at(i))
		if d < near:
			near = d
			best = i
	if event is InputEventMouseMotion:
		if best >= 0 and best != cursor and mode == "explore":
			cursor = best
			tour._nav()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "look":
			act("back")
		elif best >= 0:
			cursor = best
			act("accept")
