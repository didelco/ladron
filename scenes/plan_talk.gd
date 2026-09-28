class_name PlanTalk
extends Control
## The telling over the plan (Tour, CityStage.raise_plan), a page at a time,
## each waiting for SIGUIENTE (A, E or the full stop): first the piece's own tale,
## big, on the gang's job sheet (EndPages.piece_card) over the dark while
## the plan comes out of its room behind it, a page or two; then, one by
## one, each out of its place on the plan (PlanBeats.steps), the camera on
## the plan closing in on it and a line from there to its card: the job at
## the case (what getting it out takes, the stars), what is new tonight,
## big, with its little scene (LessonStage), and the rules of the night,
## each by what it is about; then the plan to look round (explore), with
## ¡A ROBAR! picked. The way in and out, and what is as ever, are not gone
## through: they are there to pick looking round. Start or Tab skip to it,
## B goes back a page (from the tale, to the museum).
##
## Looking round: the plan to the left, pinned with all there is on it
## (PlanBeats.marks: the case, what is new, the guards, the alarm, the way
## in and out); on the right, the list for the night: the piece and what
## getting it out takes, the rules (Briefing.tips) and the goals for the
## stars, those won ticked. The arrows go from pin to pin, lighting the
## rules about it on the list; A shows what one is about (the case, the
## piece's tale again), and ¡A ROBAR! (A on it, or Start) starts the heist.
##
## modes: "story" the tale, "step" a step over the plan (the job, what is
## new, a rule), "explore" looking round, "look" a pin's card open.

## Start the heist.
signal go
## Back to the museum.
signal back
## The telling is over (skipped or done): not to be told again.
signal told

## The cards' look: all here, to change in one place.
const CARD := Color("#150f24", 0.92)
const CARD_EDGE := Color("#ffae42")
const CARD_TEXT := Color("#fff0d6")
const CARD_TITLE := Color("#ffe066")
const RING := Color("#ffc94a")
const PIN := Color("#1c1210")
## Each kind of pin's head (the piece's is the piece's own colour).
const PIN_HEADS := {"news": Color("#ffe066"), "rule": Color("#ff6b4a"), "start": Color("#2ec4a6"), "exit": Color("#4ade80")}
const LINE := Color("#ffc94a", 0.85)
## The dark over everything behind the tale, and behind what is new.
const VEIL := Color("#0b0816")
const VEIL_STORY := 0.78
const VEIL_NEWS := 0.35
## SIGUIENTE's button, and ¡A ROBAR!'s.
const NEXT := Color("#ffc94a")
const NEXT_LIT := Color("#ffe08a")
const NEXT_EDGE := Color("#5a3a10")
const NEXT_INK := Color("#2a1804")
const GO := Color("#2ec4a6")
const GO_LIT := Color("#3fe0c0")
const GO_EDGE := Color("#0c3d34")
const GO_INK := Color("#08231d")
## How close the camera comes on each kind of card beside the plan.
const ZOOM := {"piece": 1.35, "news": 1.25, "rule": 1.2, "start": 1.15, "exit": 1.15}
## A tale longer than this many letters goes over two pages.
const PAGE_CHARS := 360
## What is new: its little scene and its words, this big.
const NEWS_SCENE := Vector2(560, 360)
const NEWS_TEXT_W := 560
## A pin's head, and how far over its point it stands.
const PIN_R := 14.0
const PIN_UP := 30.0
## Looking round: where the plan goes (fractions of the screen), the list
## beside it, and each pin landing this long after the one before.
const EXPLORE := Rect2(0.015, 0.12, 0.665, 0.76)
const LIST_W := 360
const PIN_DROP_S := 0.07
## Each kind of mark's head while looking round, and the list's colours.
const MARK_HEADS := {"news": Color("#ffe066"), "guard": Color("#e0405a"), "panel": Color("#ff922b"),
	"start": Color("#2ec4a6"), "exit": Color("#4ade80"), "rule": Color("#ff6b4a")}
const LIST_DIM := Color("#b9a9d8")
const LIST_LIT := Color("#ffe066")
const TAG := Color("#fff0d6")
const TAG_INK := Color("#1c1210")

var tour: Tour
var stage: CityStage
var beats: Array = []
## the job sheet's words and photo (EndPages.piece_card)
var sheet := {}
## the goals for the stars, [words, won]
var goals: Array = []
## what can be picked looking round (PlanBeats.marks), and what getting
## the piece out takes (Briefing.takes)
var marks: Array = []
var takes := ""
var mode := ""
## the page of the tale, or the step, on screen
var page := 0
## the pages of the tale: its words split where it is long
var pages: PackedStringArray = []
## what SIGUIENTE goes through over the plan (PlanBeats.steps)
var steps: Array = []
## the mark picked while looking round; marks.size() is the start button
var cursor := 0
## the plan is open (CityStage.raise_plan done): the pages that point at it
## wait for it, and so does looking round
var plan_open := false
var _pending := ""
## beats pinned so far
var _told := {}
var _card: Control
## the beat the card is about (-1 none), and where on the plan it points
## (INF: a page in the middle of the screen)
var _card_for := -1
var _card_at := Vector2.INF
## when the pins began to land, looking round
var _dropped := -INF
var _t := 0.0
var _veil: ColorRect
var _veil_tween: Tween
var _next: Control
var _start: Button
var _list: PanelContainer
## the rules on the list, each its line, to light up
var _rule_lines: Array[Label] = []
var _stages: Array[MenuStage] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(VEIL, 0.0)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


func _ready() -> void:
	steps = PlanBeats.steps(beats, marks)
	pages = split_tale(String(sheet.get("story", "")))


## A tale in pages: whole if it is short, else in two at a full stop near
## the middle.
static func split_tale(tale: String) -> PackedStringArray:
	tale = tale.strip_edges()
	if tale.length() <= PAGE_CHARS:
		return PackedStringArray([tale])
	var best := -1
	for i in tale.length():
		if tale[i] in ".!?" and i + 1 < tale.length() and tale[i + 1] == " ":
			if best < 0 or absi(i - tale.length() / 2) < absi(best - tale.length() / 2):
				best = i
	if best < 0:
		return PackedStringArray([tale])
	return PackedStringArray([tale.left(best + 1).strip_edges(), tale.substr(best + 1).strip_edges()])


## Tell it all, from the piece's tale.
func tell() -> void:
	_story(0)


## Straight to looking round, every pin on the plan (told before, or
## skipped): once the plan is open. to_go: with ¡A ROBAR! picked (the
## telling done), so SIGUIENTE once more is off to the heist.
func skip(to_go := false) -> void:
	if not plan_open:
		_pending = "explore"
		_drop_card()
		_veil_to(VEIL_STORY)
		_next_button("")
		return
	for i in beats.size():
		_told[i] = true
	_drop_card()
	_veil_to(0.0)
	_next_button("")
	_rest()
	mode = "explore"
	cursor = marks.size() if to_go else 0
	_dropped = _t
	_explore_ui()
	_light_rules()
	told.emit()


## The camera back on the whole plan, to the left of the list.
func _rest() -> void:
	stage.plan_frame(EXPLORE, 0.0 if stage.hurry else 0.6)


## The plan is out and open: what was waiting for it goes on.
func plan_ready() -> void:
	plan_open = true
	var want := _pending
	_pending = ""
	match want:
		"explore": skip()
		"step": _step(page)


# --- The pages --------------------------------------------------------------------

## The tale's page p: the job sheet big over the dark, its words that page's.
func _story(p: int) -> void:
	mode = "story"
	page = clampi(p, 0, pages.size() - 1)
	_told[0] = true
	_drop_card()
	_veil_to(VEIL_STORY)
	var words := sheet.duplicate()
	words.story = pages[page]
	_card_for = -1
	_card = _page_card(words)
	add_child(_card)
	_next_button(Text.t("MENU_NEXT"))
	tour._set_hints([["skip", Text.t("TOUR_HINT_SKIP")], ["back", Text.t("TOUR_HINT_MUSEUM") if page == 0 else Text.t("TOUR_HINT_PREV")]])


## Step i (steps): out of its place on the plan, the camera on it, its
## card beside it.
func _step(i: int) -> void:
	mode = "step"
	page = i
	_drop_card()
	_next_button(Text.t("MENU_NEXT"))
	tour._set_hints([["skip", Text.t("TOUR_HINT_SKIP")], ["back", Text.t("TOUR_HINT_PREV")]])
	if not plan_open:
		# Behind the tale the plan is still opening: in a moment.
		_pending = "step"
		_veil_to(VEIL_STORY)
		return
	_veil_to(VEIL_NEWS)
	var s: Dictionary = steps[i]
	match s.kind:
		"news": _show(s.beat)
		"piece":
			var at: Vector2 = marks[s.mark].at if s.mark >= 0 else beats[s.beat].at
			_told[s.beat] = true
			_show_card(at, "piece", _job_card(marks[s.mark] if s.mark >= 0 else {}))
		_:
			var m: Dictionary = marks[s.mark]
			var rules: Array = beats.filter(func(b): return b.kind == "rule")
			for r in m.rules:
				_told[beats.find(rules[r])] = true
			_show_card(m.at, "rule", _mark_card(m))


## SIGUIENTE: the next page, or looking round after the last, ¡A ROBAR!
## picked.
func _forward() -> void:
	tour._sound("nav")
	if mode == "story" and page < pages.size() - 1:
		_story(page + 1)
	elif mode == "story" and not steps.is_empty():
		_step(0)
	elif mode == "step" and page < steps.size() - 1:
		_step(page + 1)
	else:
		skip(true)


## B: the page before, or out to the museum from the first.
func _backward() -> void:
	if mode == "step" and page > 0:
		tour._sound("back")
		_step(page - 1)
	elif mode == "step":
		tour._sound("back")
		_story(pages.size() - 1)
	elif mode == "story" and page > 0:
		tour._sound("back")
		_story(page - 1)
	else:
		back.emit()


## Beat i beside its point on the plan: the camera on it, its card beside
## it, its pin placed.
func _show(i: int) -> void:
	_told[i] = true
	var b: Dictionary = beats[i]
	_show_card(b.at, b.kind, _news_card(b) if b.kind == "news" else _line_card(b))
	_card_for = i


## A card beside its point on the plan (at, in tiles), the camera closing
## in on it as close as a kind of card wants (ZOOM).
func _show_card(at: Vector2, kind: String, card: Control) -> void:
	# The card goes on the side away from the point, the point on the other.
	var right := _side(at)
	stage.plan_look(at, ZOOM.get(kind, 1.2), Vector2(0.24 if right else 0.76, 0.52), 0.0 if stage.hurry else 0.8)
	_drop_card()
	_card_at = at
	_card = card
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
	_card_at = Vector2.INF


func _veil_to(a: float) -> void:
	if _veil_tween:
		_veil_tween.kill()
	if stage.hurry:
		_veil.color.a = a
		return
	_veil_tween = create_tween()
	_veil_tween.tween_property(_veil, "color:a", a, 0.35)


func _process(dt: float) -> void:
	_t += dt
	if _card and is_instance_valid(_card):
		_place_card(dt)
	_place_next()
	queue_redraw()


## The card where it goes: a page in the middle of the screen; beside its
## point, kept on screen.
func _place_card(dt: float) -> void:
	var view := get_viewport_rect().size
	var s := _card.get_combined_minimum_size() * _card.scale
	var goal: Vector2
	if _card_at == Vector2.INF:
		goal = Vector2((view.x - s.x) * 0.5, maxf(96.0, (view.y - s.y) * 0.5 - 10.0))
	else:
		var at := stage.plan_on_screen(_card_at)
		var right: bool = _card.get_meta("right", true)
		goal = Vector2(at.x + 70 if right else at.x - 70 - s.x, at.y - s.y * 0.5)
		# Clear of the list for the night, when it is up.
		var edge := view.x * EXPLORE.end.x if _list and _list.visible else view.x - 24
		goal.x = clampf(goal.x, 24, edge - s.x)
		goal.y = clampf(goal.y, 90, view.y - s.y - 90)
	_card.position = goal if _card.position == Vector2.ZERO else _card.position.lerp(goal, 1.0 - exp(-dt * 14.0))


func _draw() -> void:
	if stage == null or stage.sheet == null or not plan_open:
		return
	# Looking round: every mark pinned, landing one after another.
	if mode in ["explore", "look"]:
		for i in marks.size():
			var age := _t - _dropped - i * PIN_DROP_S
			if age < 0.0 and not stage.hurry:
				continue
			var land := 1.0 if stage.hurry else clampf(age / 0.25, 0.0, 1.0)
			_pin(i, i == cursor and mode == "explore", land)
		if mode == "explore" and cursor < marks.size():
			_tag(cursor)
	# The ring round the point being told, and the line to its card.
	if _card and _card_at != Vector2.INF and is_instance_valid(_card):
		var p := stage.plan_on_screen(_card_at)
		var r := 30.0 + sin(_t * 5.0) * 4.0
		draw_arc(p, r, 0, TAU, 48, RING, 4.0, true)
		draw_arc(p, r + 8.0, 0, TAU, 48, Color(RING, 0.35), 2.0, true)
		var box := Rect2(_card.position, _card.get_combined_minimum_size() * _card.scale)
		var edge := Vector2(clampf(p.x, box.position.x, box.end.x), clampf(p.y, box.position.y, box.end.y))
		var dir := (edge - p).normalized()
		if p.distance_to(edge) > r + 6.0:
			draw_line(p + dir * (r + 2.0), edge, Color(LINE, LINE.a * _card.modulate.a), 3.0, true)
	# The start button's ring when it is the one picked.
	if mode == "explore" and cursor == marks.size() and _start:
		var box := _start.get_global_rect().grow(8)
		draw_rect(box, Color(RING, 0.6 + sin(_t * 5.0) * 0.3), false, 3.0)


## Mark i's pin: a head in its kind's colour, with its sign on it, on a
## needle stuck in its point; bigger when picked. land: 0 in the air to 1
## stuck in.
func _pin(i: int, lit: bool, land: float) -> void:
	var m: Dictionary = marks[i]
	var at := stage.plan_on_screen(m.at)
	var colour: Color = MARK_HEADS.get(m.kind, Color(Heist.loot.get("colour", "#ffffff")))
	var r := PIN_R * (1.3 if lit else 1.0) * (1.0 + sin(_t * 6.0) * 0.06 if lit else 1.0)
	var drop := (1.0 - land) * 40.0
	var head := at + Vector2(_fan(i), -PIN_UP * (1.15 if lit else 1.0) - drop)
	var a := clampf(land * 2.0, 0.0, 1.0)
	if land >= 1.0:
		draw_circle(at, 5, PIN)
		draw_circle(at, 3, colour)
	draw_line(at - Vector2(0, drop), head, Color(PIN, a), 3.0, true)
	draw_circle(head + Vector2(0, 3), r + 2, Color(0, 0, 0, 0.35 * a))
	draw_circle(head, r + 2.5, Color(RING if lit else PIN, a))
	draw_circle(head, r, Color(colour, a))
	_sign(m.kind, head, r, Color(PIN, a))
	# A shine on the head, like a real drawing pin.
	draw_circle(head + Vector2(-r * 0.4, -r * 0.4), r * 0.24, Color(1, 1, 1, 0.45 * a))


## What a mark is, drawn on its pin's head: the case a diamond, what is new
## a star, a guard or a rule "!", the alarm a bar, the way in an arrow in,
## the way out an arrow out.
func _sign(kind: String, c: Vector2, r: float, ink: Color) -> void:
	var s := r * 0.55
	match kind:
		"piece":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0)]), ink)
		"news":
			draw_colored_polygon(EndPages._star_points(c, s * 1.1, s * 0.45), ink)
		"guard", "rule":
			draw_rect(Rect2(c + Vector2(-s * 0.18, -s), Vector2(s * 0.36, s * 1.2)), ink)
			draw_circle(c + Vector2(0, s * 0.62), s * 0.2, ink)
		"panel":
			draw_rect(Rect2(c - Vector2(s * 0.7, s * 0.25), Vector2(s * 1.4, s * 0.5)), ink)
		"start":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.7, -s * 0.5), c + Vector2(s * 0.7, -s * 0.5), c + Vector2(0, s * 0.7)]), ink)
		"exit":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.5, -s * 0.7), c + Vector2(s * 0.7, 0), c + Vector2(-s * 0.5, s * 0.7)]), ink)


## The name of mark i on a label over its pin.
func _tag(i: int) -> void:
	var m: Dictionary = marks[i]
	var f := get_theme_default_font()
	var size := 17
	var words: String = m.tag
	var w := f.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var head := stage.plan_on_screen(m.at) + Vector2(_fan(i), -PIN_UP * 1.15)
	var box := Rect2(head + Vector2(-w * 0.5 - 12, -PIN_R * 1.3 - 40), Vector2(w + 24, 30))
	var view := get_viewport_rect().size
	box.position.x = clampf(box.position.x, 8, view.x - box.size.x - 8)
	draw_rect(Rect2(box.position + Vector2(0, 3), box.size), Color(0, 0, 0, 0.35))
	draw_rect(box, TAG)
	draw_rect(box, RING, false, 2.0)
	draw_string(f, box.position + Vector2(12, 21), words, HORIZONTAL_ALIGNMENT_LEFT, -1, size, TAG_INK)


# --- Cards ------------------------------------------------------------------------

## The job sheet as a page of its own, big (EndPages.CARD_BIG): the piece
## turning in its polaroid, which job, its name, what it is like and its tale.
func _page_card(words: Dictionary) -> Control:
	var card := EndPages.piece_card(words, EndPages.CARD_BIG)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## What is new, big: its title, its little scene, how it works.
func _news_card(b: Dictionary) -> Control:
	var box := _frame()
	var col: VBoxContainer = box.get_child(0)
	col.add_theme_constant_override("separation", 10)
	var head := _text(col, Text.t("TOUR_NEWS_HEAD"), 22, CARD_TITLE, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title := _text(col, b.title, 36, CARD_TEXT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Tour._arcade(title)
	var stage3d := MenuStage.make(b.stage)
	stage3d.size = Vector2i(NEWS_SCENE)
	col.add_child(stage3d)
	stage3d.active = true
	_stages.append(stage3d)
	var pic := TextureRect.new()
	pic.texture = stage3d.get_texture()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = NEWS_SCENE
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(pic)
	var text := _text(col, b.text, 24, CARD_TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = NEWS_TEXT_W
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


## A big round button in the bottom right corner, what A does written on it
## beside its key: SIGUIENTE > on the pages, ¡A ROBAR! looking round.
func _pill(words: String, fill: Color, lit: Color, edge: Color, ink: Color, size: int) -> Button:
	var b := Button.new()
	b.text = words
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Hud.ARCADE)
	b.add_theme_font_size_override("font_size", size)
	for state in ["normal", "hover", "pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = fill if state == "normal" else lit
		st.set_corner_radius_all(26)
		st.border_color = edge
		st.set_border_width_all(3)
		st.shadow_color = Color(0, 0, 0, 0.45)
		st.shadow_size = 10
		st.set_content_margin_all(14)
		st.content_margin_left = 30
		st.content_margin_right = 34
		b.add_theme_stylebox_override(state, st)
	for c in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(c, ink)
	return b


## SIGUIENTE's button with its key beside it, or none ("").
func _next_button(words: String) -> void:
	if words == "":
		if _next:
			_next.visible = false
		return
	if _next == null:
		_next = HBoxContainer.new()
		_next.add_theme_constant_override("separation", 12)
		_next.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var g := Glyph.new()
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_next.add_child(g)
		var b := _pill(words, NEXT, NEXT_LIT, NEXT_EDGE, NEXT_INK, 20)
		b.pressed.connect(func() -> void: act("accept"))
		_next.add_child(b)
		add_child(_next)
	(_next.get_child(1) as Button).text = words
	_next.visible = true
	_next_glyph()


func _next_glyph() -> void:
	if _next:
		(_next.get_child(0) as Glyph).set_spec(Tour.glyph_for("accept", tour._pad), 34)


func _place_next() -> void:
	if _next and _next.visible:
		var view := get_viewport_rect().size
		_next.size = _next.get_combined_minimum_size()
		_next.position = Vector2(view.x - _next.size.x - 36, view.y - _next.size.y - 26)


# --- Looking round ----------------------------------------------------------------

## The list for the night and the start button, once the telling is over.
func _explore_ui() -> void:
	if _start == null:
		_start = _pill(Text.t("TOUR_START"), GO, GO_LIT, GO_EDGE, GO_INK, 20)
		_start.pressed.connect(func() -> void: go.emit())
		_start.mouse_entered.connect(func() -> void:
			cursor = marks.size()
			_explore_hints())
		add_child(_start)
	_start.visible = true
	if _list == null:
		_list = _night_list()
		add_child(_list)
	_list.visible = true
	_layout_explore()
	_explore_hints()


## The hints while looking round: accepting sees the mark picked, or with the
## start button picked starts (and then skipping, the same, goes unsaid).
func _explore_hints() -> void:
	if cursor >= marks.size():
		tour._set_hints([["move", Text.t("TOUR_HINT_LOOK")], ["accept", Text.t("TOUR_START")], ["back", Text.t("TOUR_HINT_MUSEUM")]])
	else:
		tour._set_hints([["move", Text.t("TOUR_HINT_LOOK")], ["accept", Text.t("TOUR_HINT_SEE")], ["skip", Text.t("TOUR_START")], ["back", Text.t("TOUR_HINT_MUSEUM")]])


## The list beside the plan, as the old plan page had it: the piece, its
## name in its colour and what getting it out takes; the rules for the
## night; the goals for the stars, those won already ticked.
func _night_list() -> PanelContainer:
	var box := _frame()
	var col: VBoxContainer = box.get_child(0)
	col.add_theme_constant_override("separation", 6)
	var head := _text(col, Text.t("BRIEF_TIPS_TITLE"), 22, CARD_TITLE, true)
	head.custom_minimum_size.x = LIST_W
	var name := _text(col, String(sheet.get("name", "")), 22, Color(Heist.loot.get("colour", "#ffffff")).lightened(0.15))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = LIST_W
	if takes != "":
		var t := _text(col, takes, 16, LIST_DIM)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = LIST_W
	_gap(col, 4)
	_rule_lines.clear()
	for b in beats:
		if b.kind != "rule":
			continue
		var l := _text(col, "• " + String(b.text), 17, CARD_TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = LIST_W
		_rule_lines.append(l)
	if not goals.is_empty():
		_gap(col, 6)
		_text(col, Text.t("TOUR_GOALS"), 18, CARD_TITLE, true)
		for g in goals:
			_text(col, ("%s  %s" % [StarSlots.FULL if g[1] else StarSlots.EMPTY, g[0]]), 17, CARD_TITLE if g[1] else CARD_TEXT)
	return box


func _gap(col: Control, h: int) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = h
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)


## The rules about the mark picked, lit on the list; the rest as they are.
func _light_rules() -> void:
	var lit: Array = marks[cursor].rules if mode in ["explore", "look"] and cursor < marks.size() else []
	for r in _rule_lines.size():
		var on := r in lit
		_rule_lines[r].add_theme_color_override("font_color", LIST_LIT if on else CARD_TEXT)
		_rule_lines[r].text = ("▶ " if on else "• ") + _rule_lines[r].text.substr(2)


func _layout_explore() -> void:
	var view := get_viewport_rect().size
	if _start:
		_start.size = _start.get_combined_minimum_size()
		_start.position = Vector2(view.x - _start.size.x - 36, view.y - _start.size.y - 26)
	if _list:
		_list.size = _list.get_combined_minimum_size()
		var top := 92.0
		var room := (_start.position.y if _start else view.y) - 16.0 - top
		_list.position = Vector2(view.x - _list.size.x - 24, top + maxf(0.0, (room - _list.size.y) * 0.5))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and mode == "explore":
		_layout_explore()


## The pin that way from the one picked (or the start button), if any.
func _move(dir: Vector2) -> void:
	var from := _at(cursor)
	var best := -1
	var score := INF
	for i in marks.size() + 1:
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
		_pick(best)


func _pick(i: int) -> void:
	cursor = i
	tour._nav()
	_light_rules()
	if mode == "explore":
		_explore_hints()


## Where mark i's pin is on screen (the start button for marks.size()).
func _at(i: int) -> Vector2:
	if i >= marks.size():
		return _start.get_global_rect().get_center() if _start else get_viewport_rect().size
	return stage.plan_on_screen(marks[i].at) + Vector2(_fan(i), -PIN_UP)


## Pins stuck in the same place (what is new on the case, two guards
## together) fan out side by side, each head this far across from the point.
func _fan(i: int) -> float:
	var group: Array[int] = []
	for j in marks.size():
		if (marks[j].at as Vector2).distance_to(marks[i].at) < 0.9:
			group.append(j)
	return (group.find(i) - (group.size() - 1) * 0.5) * PIN_R * 2.3


## A press, in the mode it is in.
func act(what: String) -> void:
	_next_glyph()
	match mode:
		"story", "step":
			match what:
				"accept": _forward()
				"skip":
					tour._sound("ok")
					skip()
				"back": _backward()
		"explore":
			match what:
				"left": _move(Vector2.LEFT)
				"right": _move(Vector2.RIGHT)
				"up": _move(Vector2.UP)
				"down": _move(Vector2.DOWN)
				"prev": _pick((cursor - 1 + marks.size() + 1) % (marks.size() + 1))
				"next": _pick((cursor + 1) % (marks.size() + 1))
				"accept":
					if cursor >= marks.size():
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


## Mark i's card: the case, the piece's tale again as a page; what is new,
## big beside it; the rest, what it is and its rules beside it.
func _look(i: int) -> void:
	mode = "look"
	if _start:
		_start.visible = false
	var m: Dictionary = marks[i]
	if m.kind == "piece":
		if _list:
			_list.visible = false
		_drop_card()
		_veil_to(VEIL_STORY)
		var words := sheet.duplicate()
		words.story = " ".join(pages)
		_card = _page_card(words)
		add_child(_card)
	elif m.kind == "news":
		if _list:
			_list.visible = false
		_veil_to(VEIL_NEWS)
		_show(m.beat)
	else:
		_drop_card()
		_card_at = m.at
		_card = _mark_card(m)
		add_child(_card)
		_card.set_meta("right", _side(m.at))
	tour._set_hints([["accept", Text.t("TOUR_HINT_CLOSE")], ["skip", Text.t("TOUR_START")]])


## The job, beside the case: which piece, what getting it out takes, the
## rules about it (the case's alarm, the minigames) and the stars to win,
## those won ticked. m: the case's mark, for its rules.
func _job_card(m: Dictionary) -> Control:
	var box := _frame()
	var col: VBoxContainer = box.get_child(0)
	var tag := _text(col, Text.t("TOUR_TAG_PIECE").to_upper(), 20, CARD_TITLE, true)
	Tour._arcade(tag)
	var name := _text(col, String(sheet.get("name", "")), 24, Color(Heist.loot.get("colour", "#ffffff")).lightened(0.15))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name.custom_minimum_size.x = 340
	if takes != "":
		var t := _text(col, takes, 19, CARD_TEXT)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		t.custom_minimum_size.x = 340
	var rules: Array = beats.filter(func(b): return b.kind == "rule")
	for r in m.get("rules", []):
		var l := _text(col, "▶ " + String(rules[r].text), 19, LIST_LIT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 340
	if not goals.is_empty():
		_gap(col, 4)
		_text(col, Text.t("TOUR_GOALS"), 18, CARD_TITLE, true)
		for g in goals:
			_text(col, ("%s  %s" % [StarSlots.FULL if g[1] else StarSlots.EMPTY, g[0]]), 18, CARD_TITLE if g[1] else CARD_TEXT)
	return box


## A mark as a card beside it: its name, what it is, and the rules about it.
func _mark_card(m: Dictionary) -> Control:
	var box := _frame()
	var col: VBoxContainer = box.get_child(0)
	var tag := _text(col, String(m.tag).to_upper(), 20, CARD_TITLE, true)
	Tour._arcade(tag)
	if String(m.text) != "" and m.kind != "rule":
		var text := _text(col, m.text, 21, CARD_TEXT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.custom_minimum_size.x = 320
	var rules: Array = beats.filter(func(b): return b.kind == "rule")
	for r in m.rules:
		var l := _text(col, "▶ " + String(rules[r].text), 19, LIST_LIT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 320
	return box


func _unlook() -> void:
	_drop_card()
	_veil_to(0.0)
	_rest()
	mode = "explore"
	_explore_ui()
	_light_rules()


## The mouse over the plan: over a pin picks it, a click shows it.
func mouse(event: InputEvent) -> void:
	if mode in ["story", "step", ""]:
		return
	var at: Vector2 = event.position
	var best := -1
	var near := PIN_R * 1.8
	for i in marks.size():
		var d := at.distance_to(_at(i))
		if d < near:
			near = d
			best = i
	if event is InputEventMouseMotion:
		if best >= 0 and best != cursor and mode == "explore":
			_pick(best)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if mode == "look":
			act("back")
		elif best >= 0:
			cursor = best
			act("accept")
