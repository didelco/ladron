class_name Tour
extends CanvasLayer
## The story's way in to a heist, told as one scene, the way a film plans a
## robbery: the town from above (CityStage), the camera gliding down onto a
## museum and into it, its rooms, the one picked. Over the 3D, the words:
## the sign over what is picked, the heading, and what to press.
##
## Its steps (state):
##   "city"     the town: the arrows pick a museum, A goes in, B back out
##   "zoom"     gliding in or out; nothing to press
##   "museum"   inside one: the arrows pick a room reached, A plans it, B out
##   "plan"     the room's plan coming out of it and opening, the piece's
##              tale and what is new told big over it, a page at a time,
##              then the plan looked round (PlanTalk)
##   "going"    off to the heist: the plan fades into the game
## Main listens for what it asks for (left, room_chosen, go) and forwards
## the input while it is up (input).

## Out of the town, back to the story's menu.
signal left
## A room picked for tonight: heist n. Main lays it out and hands its plan
## back (show_plan).
signal room_chosen(n: int)
## ¡A ROBAR!: heist n, now.
signal go(n: int)
## The hideout gone into: the practice room, no heist and no stars.
signal practice
## Heist n's plan has been told: next time, straight to looking round.
signal told(n: int)
## A menu sound to play: "nav", "ok" or "back".
signal sound(kind: String)

## The words over the scene, all here to change in one place.
const SIGN := Color("#fff0d6")
const SIGN_DIM := Color("#b9a9d8")
const SIGN_SHUT := Color("#8a7fa3")

## Picking a stop of the town by the way you push (the arrows, WASD, the cross
## or the stick): the stops within this many degrees of that way are the
## candidates, the nearest wins; none there, the most in line (no more than
## MAX_OFF off), or nothing.
## The arrows over the town: cream, this far (px) from the stop picked.
const ARROW := Color(1.0, 0.94, 0.84)
const ARROW_R := 150.0
const CONE := 60.0
const MAX_OFF := 75.0
const DIR_VECTORS := {"left": Vector2(-1, 0), "right": Vector2(1, 0), "up": Vector2(0, -1), "down": Vector2(0, 1)}
var stage: CityStage
var state := "city"
var players := 1
## the museums open (0-based up to), the heist reached
var reached := 1
var _root: Control
var _view: SubViewportContainer
var _sign: VBoxContainer
var _sign_title: Label
var _sign_line: Label
var _sign_stars: Label
var _title: Label
var _subtitle: Label
var _hints: HBoxContainer
var _pad := false
## the stick, per pad: where it is, whether it is pushed (it moves once per
## push, and not again until it is let back), and the pad whose push waits
## for the next frame (its two axes come as two events)
var _sticks := {}
var _stick_on := {}
var _stick_push := -100
var _stick_vec := Vector2.ZERO
## over the town: the way each direction leads from the stop picked
var _arrows: Control
## the rooms of the museum inside, as Story has them: heist numbers
var _nights: Array[int] = []
## under each room reached, its stars
var _room_stars: Array[Label] = []
## the plan out and what is told over it, and whose it is
var talk: PlanTalk
var night := 0


func _init() -> void:
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# The night sky behind the town.
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.material = _sky_material()
	_root.add_child(sky)
	_view = SubViewportContainer.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.stretch = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.material = _edge_material()
	_root.add_child(_view)
	stage = CityStage.new()
	_view.add_child(stage)
	# The sign over the museum or room picked.
	_sign = VBoxContainer.new()
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign.add_theme_constant_override("separation", 2)
	_root.add_child(_sign)
	_sign_title = _label(_sign, 26, SIGN, true)
	_sign_line = _label(_sign, 17, SIGN_DIM)
	_sign_stars = _label(_sign, 20, Hud.C.gold)
	for l in [_sign_title, _sign_line, _sign_stars]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Up top: where you are; at the bottom: what to press.
	_title = _label(_root, 30, Color("#f0c46a"), true)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_KEEP_SIZE, 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle = _label(_root, 17, SIGN_DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hints = HBoxContainer.new()
	_hints.add_theme_constant_override("separation", 28)
	_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hints)
	_arrows = Control.new()
	_arrows.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arrows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrows.draw.connect(_draw_arrows)
	_root.add_child(_arrows)


## The town for a gang of `n`, as far as it has got: museum `pick` picked.
## fresh: a museum just opened, whose padlock pops off as the town shows.
func open_city(n: int, pick: int, fresh := -1) -> void:
	players = n
	reached = Story.unlocked(n)
	stage.build(Story.museum_of(reached), pick)
	_show_city()
	if fresh >= 0:
		stage.relock(fresh)
		get_tree().create_timer(0.0 if stage.hurry else 0.8).timeout.connect(func() -> void:
			stage.unlock(fresh)
			_sound("ok"))


func _show_city() -> void:
	state = "city"
	_title.text = Text.t("STORY_MAP_TITLE")
	_subtitle.text = Text.t("STORY_GANG_%d" % players)
	_pick_museum(stage.picked)
	_set_hints([["move", Text.t("TOUR_HINT_PICK")], ["accept", Text.t("TOUR_HINT_ENTER")], ["back", Text.t("TOUR_HINT_BACK")]])


## Straight inside museum m with heist n picked (back from a heist).
func open_museum(n: int, pick_n: int) -> void:
	players = n
	reached = Story.unlocked(n)
	var m := Story.museum_of(pick_n)
	stage.build(Story.museum_of(reached), m)
	stage.be_in(m, _rooms_of(m))
	_inside(m, pick_n)


# --- The town ---------------------------------------------------------------------

func _pick_museum(m: int) -> void:
	stage.pick(m)
	if stage.is_hideout(m):
		_sign_title.text = Text.t("HIDEOUT_NAME").to_upper()
		_arcade(_sign_title)
		_sign_line.text = Text.t("HIDEOUT_LINE")
		_sign_title.add_theme_color_override("font_color", Color("#e2262f").lightened(0.3))
		_sign_stars.visible = false
		_set_hints([["move", Text.t("TOUR_HINT_PICK")], ["accept", Text.t("TOUR_HINT_PRACTICE")], ["back", Text.t("TOUR_HINT_BACK")]])
		return
	_set_hints([["move", Text.t("TOUR_HINT_PICK")], ["accept", Text.t("TOUR_HINT_ENTER")], ["back", Text.t("TOUR_HINT_BACK")]])
	var museum := Story.museum(m)
	var nights := Story.nights_in(m)
	var done := nights.filter(func(k: int) -> bool: return k < reached).size()
	_sign_title.text = String(museum.name).to_upper()
	_arcade(_sign_title)
	if stage.is_open(m):
		_sign_line.text = Text.t("TOUR_MUSEUM_DONE") % [done, nights.size()]
		_sign_title.add_theme_color_override("font_color", Color(Story.MUSEUMS[m].colour).lightened(0.25))
	else:
		_sign_line.text = Text.t("TOUR_MUSEUM_SHUT") % Story.museum_in(m - 1)
		_sign_title.add_theme_color_override("font_color", SIGN_SHUT)
	_sign_stars.text = StarSlots.museum_line(m, players)
	_sign_stars.visible = stage.is_open(m)


## Which of `stops` (id -> where on the screen) lies the way `dir` says
## from `from`, both on the screen's plane (y down). One way (an arrow): of
## those within CONE degrees of it the nearest; none there, the most in line
## unless it is MAX_OFF degrees off or worse. Two ways at once (dir the sum:
## a diagonal): the most in line. -1 for none.
static func toward(from: Vector2, dir: Vector2, stops: Dictionary) -> int:
	if dir.length() < 0.01:
		return -1
	var diagonal := absf(dir.x) > 0.01 and absf(dir.y) > 0.01
	var near := -1
	var near_d := INF
	var line := -1
	var line_a := INF
	var line_d := INF
	for id in stops:
		var v: Vector2 = stops[id] - from
		var d := v.length()
		if d < 0.5:
			continue
		var a := rad_to_deg(absf(v.angle_to(dir)))
		if a > MAX_OFF:
			continue
		if a < line_a - 0.01 or (absf(a - line_a) <= 0.01 and d < line_d):
			line = id
			line_a = a
			line_d = d
		if a <= CONE and d < near_d:
			near = id
			near_d = d
	if diagonal or near < 0:
		return line
	return near


## The other stops that can be picked (open ones), where they are on the screen.
func _stops_open() -> Dictionary:
	var stops := {}
	for m in [CityStage.HIDEOUT, 0, 1, 2, 3, 4]:
		if m != stage.picked and stage.is_open(m):
			stops[m] = stage.stop_on_screen(m)
	return stops


## Move the pick the way `v` points on the screen (x right, y down; an arrow
## is one of DIR_VECTORS, the stick any angle), among the open stops.
func step(v: Vector2) -> void:
	var to := toward(stage.stop_on_screen(stage.picked), v, _stops_open())
	if to < 0:
		return
	_nav()
	_pick_museum(to)


func _enter_museum() -> void:
	var m := stage.picked
	if not stage.is_open(m):
		_sound("back")
		return
	if stage.is_hideout(m):
		_sound("ok")
		state = "going"
		_set_hints([])
		practice.emit()
		return
	_sound("ok")
	state = "zoom"
	_sign.visible = false
	_set_hints([])
	_title.text = String(Story.museum(m).name).to_upper()
	_arcade(_title)
	_subtitle.text = Story.museum(m).text
	stage.go_in(m, _rooms_of(m), func() -> void:
		var nights := Story.nights_in(m)
		_inside(m, mini(nights[-1], reached)))


## The rooms of museum m, as the doll's house wants them.
func _rooms_of(m: int) -> Array:
	var out: Array = []
	for n in Story.nights_in(m):
		var loot: Dictionary = Story.LEVELS[n - 1].loot
		out.append({"n": n, "boss": Story.is_boss(n), "open": n <= reached, "done": n < reached, "shape": loot.shape, "colour": loot.colour})
	return out


# --- Inside a museum --------------------------------------------------------------

func _inside(m: int, pick_n: int) -> void:
	state = "museum"
	_nights = Story.nights_in(m)
	_title.text = String(Story.museum(m).name).to_upper()
	_arcade(_title)
	_subtitle.text = Story.museum(m).text
	for l in _room_stars:
		l.queue_free()
	_room_stars.clear()
	for n in _nights:
		var l := _label(_root, 17, Hud.C.gold)
		l.text = ("%d  %s" % [Story.room_of(n), StarSlots.room_line(n, players)]).strip_edges()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_room_stars.append(l)
	_pick_room(_nights.find(pick_n))
	_set_hints([["move", Text.t("TOUR_HINT_ROOM")], ["accept", Text.t("TOUR_HINT_PLAN")], ["back", Text.t("TOUR_HINT_TOWN")]])


## Pick room i: only one reached (stage.room_open); the rest are not rooms
## yet, just windows of the building.
func _pick_room(i: int) -> void:
	i = clampi(i, 0, _nights.size() - 1)
	if not stage.room_open(i):
		return
	stage.pick_room(i)
	var n := _nights[i]
	var loot: Dictionary = Story.level(n).loot
	_sign.visible = true
	_sign_title.text = Text.t("STORY_BOSS_ROOM") if Story.is_boss(n) else Text.t("TOUR_ROOM") % Story.room_of(n)
	_sign_line.text = Heist.first_upper(loot.name)
	_sign_title.add_theme_color_override("font_color", Color(loot.colour).lightened(0.2))
	_arcade(_sign_title)
	_sign_stars.visible = false


## The next room that way (dir -1 left, 1 right) round the museum, wall by
## wall and along each as seen from in front of it (the camera swings round
## to it); or, the rooms one over another (a tower's floors), -1 down and 1
## up (room_along): only among those reached.
func _step_room(dir: int) -> void:
	var order: Array[int] = []
	for i in _nights.size():
		if stage.room_open(i):
			order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool: return stage.room_along(a) < stage.room_along(b))
	var at := order.find(stage.room) + dir
	if at >= 0 and at < order.size():
		_nav()
		_pick_room(order[at])


## The nearest room reached higher up (dir 1) or lower down (-1) than the
## one picked, on any wall; none, it stays.
func _step_height(dir: int) -> void:
	var here := stage.room_centre(stage.room)
	var best := -1
	var near := INF
	for i in _nights.size():
		if i == stage.room or not stage.room_open(i):
			continue
		var at := stage.room_centre(i)
		if (at.y - here.y) * dir < 0.2:
			continue
		if at.distance_to(here) < near:
			near = at.distance_to(here)
			best = i
	if best >= 0:
		_nav()
		_pick_room(best)


func _choose_room() -> void:
	var n := _nights[stage.room]
	if n > reached:
		_sound("back")
		return
	_sound("ok")
	room_chosen.emit(n)


func _leave_museum() -> void:
	_sound("back")
	state = "zoom"
	_sign.visible = false
	for l in _room_stars:
		l.queue_free()
	_room_stars.clear()
	_set_hints([])
	stage.go_out(_show_city)


# --- The plan ---------------------------------------------------------------------

## Heist n laid out, its plan out of its room (Main._plan_data): image and
## tile_px, the plan's picture; beats (PlanBeats), sheet
## (the job sheet), goals (StarSlots.goals), marks (PlanBeats.marks) and
## takes (Briefing.takes), for looking round; told, whether to go straight
## to looking round. The piece's tale comes up big straight away, the plan
## coming out of its room and opening behind it.
func show_plan(data: Dictionary) -> void:
	state = "plan"
	night = data.n
	_sign.visible = false
	for l in _room_stars:
		l.visible = false
	_title.text = Text.t("STORY_BOSS_ROOM") if Story.is_boss(night) else Text.t("TOUR_ROOM") % Story.room_of(night)
	_arcade(_title)
	_subtitle.text = ""
	_set_hints([])
	if talk:
		talk.queue_free()
	talk = PlanTalk.new()
	talk.tour = self
	talk.stage = stage
	talk.beats = data.beats
	talk.sheet = data.sheet
	talk.goals = data.goals
	talk.marks = data.get("marks", [])
	talk.takes = data.get("takes", "")
	_root.add_child(talk)
	_root.move_child(talk, _view.get_index() + 1)
	talk.go.connect(_go)
	talk.back.connect(_back_to_museum)
	talk.told.connect(func() -> void: told.emit(night))
	var t := talk
	stage.raise_plan(data.image, data.tile_px, func() -> void:
		if is_instance_valid(t):
			t.plan_ready())
	if data.get("told", false):
		talk.skip()
	else:
		talk.tell()


## B on the plan: it folds back into its room.
func _back_to_museum() -> void:
	_sound("back")
	state = "zoom"
	if talk:
		talk.queue_free()
		talk = null
	_set_hints([])
	stage.lower_plan(func() -> void: _inside(Story.museum_of(night), night))


func _go() -> void:
	if state != "plan":
		return
	_sound("ok")
	state = "going"
	go.emit(night)


## Off to the heist: the plan comes at you and everything fades into the
## game behind, then the tour is gone.
func fade_out() -> void:
	state = "going"
	_set_hints([])
	# Out as every screen goes into the game (Hud.FADE_S, Hud's curve).
	var secs := 0.0 if stage.hurry else Hud.FADE_S
	var tw := create_tween().set_parallel()
	tw.tween_property(_root, "modulate:a", 0.0, secs).set_trans(Hud.TRANS).set_ease(Hud.EASE)
	if stage.sheet:
		tw.tween_property(stage.sheet, "scale", stage.sheet.scale * 1.6, secs).set_trans(Hud.TRANS).set_ease(Hud.EASE)
	tw.chain().tween_callback(queue_free)


# --- Input ------------------------------------------------------------------------

## A press, whatever it came from, as what it means here: "left", "right",
## "up", "down", "accept", "back", "skip", "prev", "next", or "" for nothing.
## Keys: the arrows and WASD; accept, back and skip as on every menu
## (MenuKeys: E or the full stop to take, Escape, Space or Enter to go back,
## Tab to skip); a pad: the cross or the left stick, A, B, Start, LB and RB
## (which flick between rooms inside a museum; in the town they do nothing).
func intent(event: InputEvent) -> String:
	var what := MenuKeys.of(event)
	if event is InputEventKey and event.pressed and not event.echo:
		_pad = false
		match event.keycode:
			KEY_LEFT, KEY_A: return "left"
			KEY_RIGHT, KEY_D: return "right"
			KEY_UP, KEY_W: return "up"
			KEY_DOWN, KEY_S: return "down"
		return what if what in ["accept", "back", "skip"] else ""
	elif event is InputEventJoypadButton and event.pressed:
		if not Pads.real(event.device):
			return ""
		_pad = true
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: return "left"
			JOY_BUTTON_DPAD_RIGHT: return "right"
			JOY_BUTTON_DPAD_UP: return "up"
			JOY_BUTTON_DPAD_DOWN: return "down"
		return what if what != "map" else ""
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if not Pads.real(event.device):
			return ""
		# Once a push: past half way it moves, and not again until it is let
		# back under a third. Where it goes is decided next frame (_process),
		# when both axes have come.
		var v: Vector2 = _sticks.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_LEFT_X:
			v.x = event.axis_value
		else:
			v.y = event.axis_value
		_sticks[event.device] = v
		var was: bool = _stick_on.get(event.device, false)
		var now := v.length() > 0.5 or (was and v.length() > 0.33)
		_stick_on[event.device] = now
		if now and not was:
			_pad = true
			_stick_push = event.device
			_stick_vec = Vector2.ZERO
		if _stick_push == event.device and v.length() > _stick_vec.length():
			_stick_vec = v
	return ""


## What main forwards while the tour is up.
func input(event: InputEvent) -> void:
	var what := intent(event)
	if what == "":
		return
	_hints_for_device()
	act(what)


## Do what a press means, in the step it is in.
func act(what: String) -> void:
	match state:
		"city":
			match what:
				"left", "up", "right", "down": step(DIR_VECTORS[what])
				"accept": _enter_museum()
				"back":
					_sound("back")
					left.emit()
		"museum":
			match what:
				"left", "prev": _step_room(-1)
				"right", "next": _step_room(1)
				# Up and down by height, whichever wall.
				"up": _step_height(1)
				"down": _step_height(-1)
				"accept": _choose_room()
				"back": _leave_museum()
		"plan":
			if talk:
				talk.act(what)


func _ready() -> void:
	_root.gui_input.connect(_on_mouse)


## The mouse: over a museum or a room picks it, a click on the one picked
## takes it, the right button goes back.
func _on_mouse(event: InputEvent) -> void:
	if not (event is InputEventMouseMotion or (event is InputEventMouseButton and event.pressed)):
		return
	var at: Vector2 = event.position
	var best := -1
	var near := 110.0
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and state in ["city", "museum", "plan"]:
		act("back")
		return
	match state:
		"plan":
			if talk:
				talk.mouse(event)
		"city":
			for m in stage._museums.size():
				var d := at.distance_to(stage.stop_point(m))
				if d < near:
					near = d
					best = m
			if best < 0:
				return
			if event is InputEventMouseButton:
				if event.button_index == MOUSE_BUTTON_LEFT:
					if best == stage.picked:
						_enter_museum()
					elif stage.is_open(best):
						_pick_museum(best)
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					act("back")
			elif best != stage.picked and stage.is_open(best):
				_nav()
				_pick_museum(best)
		"museum":
			# Only near a room reached: the rest are just windows.
			near = 70.0
			for i in stage.room_count():
				if not stage.room_open(i) or not stage.room_seen(i):
					continue
				var d := at.distance_to(stage.on_screen(stage.room_centre(i)))
				if d < near:
					near = d
					best = i
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
				act("back")
				return
			if best < 0 or _nights[best] > reached:
				return
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if best == stage.room:
					_choose_room()
				else:
					_pick_room(best)
			elif best != stage.room:
				_nav()
				_pick_room(best)


# --- Drawing ----------------------------------------------------------------------

func _process(_dt: float) -> void:
	var view := _root.get_viewport_rect().size
	if _stick_push != -100:
		var v := _stick_vec
		_stick_push = -100
		_hints_for_device()
		if state == "city":
			step(v)
		else:
			act(("right" if v.x > 0 else "left") if absf(v.x) > absf(v.y) else ("down" if v.y > 0 else "up"))
	_arrows.visible = state == "city"
	_arrows.queue_redraw()
	# Wider than the town is built for (CityStage.WIDEST), its sides fade
	# into the sky, over the safe margin; close in on a museum, nothing fades.
	var edges := _view.material as ShaderMaterial
	edges.set_shader_parameter("aspect", view.x / maxf(view.y, 1.0))
	edges.set_shader_parameter("edge", CityStage.CITY_VIEW * CityStage.WIDEST * 0.5 / stage.view)
	edges.set_shader_parameter("soft", CityStage.SAFE * 0.9 / stage.view)
	_title.position = Vector2(view.x * 0.5 - _title.size.x * 0.5, 22)
	_subtitle.position = Vector2(view.x * 0.5 - _subtitle.size.x * 0.5, 22 + _title.size.y + 6)
	_hints.position = Vector2(view.x * 0.5 - _hints.get_combined_minimum_size().x * 0.5, view.y - 58)
	for i in _room_stars.size():
		var l := _room_stars[i]
		l.size = l.get_combined_minimum_size()
		l.position = stage.room_foot_on_screen(i) - Vector2(l.size.x * 0.5, -2)
		# Only under a room reached (the rest are not rooms yet) on a wall
		# the camera faces.
		l.visible = state == "museum" and stage.room_open(i) and stage.room_seen(i)
	if _sign.visible:
		var at := Vector2.ZERO
		if state == "city":
			at = stage.museum_on_screen(stage.picked)
		elif state == "museum" and stage.room >= 0:
			at = stage.room_on_screen(stage.room)
		_sign.size = _sign.get_combined_minimum_size()
		var goal := at - Vector2(_sign.size.x * 0.5, _sign.size.y + 6)
		goal.x = clampf(goal.x, 16, view.x - _sign.size.x - 16)
		goal.y = clampf(goal.y, 90, view.y - _sign.size.y - 70)
		_sign.position = goal if _sign.position == Vector2.ZERO else _sign.position.lerp(goal, 0.3)


## The keys or buttons at the bottom and what each does: [what, words],
## what one of "move", "accept", "back", "skip".
func _set_hints(rows: Array) -> void:
	for c in _hints.get_children():
		c.queue_free()
	for r in rows:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.set_meta("what", r[0])
		_hints.add_child(box)
		var g := Glyph.new()
		box.add_child(g)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var l := _label(box, 16, SIGN)
		l.text = r[1]
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hints_for_device()


## The hints as the hands are: a pad's buttons, or the keys.
func _hints_for_device() -> void:
	for box in _hints.get_children():
		var g: Glyph = box.get_child(0)
		g.set_spec(glyph_for(box.get_meta("what"), _pad), 28)


static func glyph_for(what: String, pad: bool) -> Dictionary:
	if pad:
		match what:
			"move": return {"kind": "stick"}
			"accept": return {"kind": "pad", "pos": "south", "family": "xbox"}
			"back": return {"kind": "pad", "pos": "east", "family": "xbox"}
			"skip": return {"kind": "key", "label": "START"}
	match what:
		"move": return {"kind": "keys4", "labels": ["W", "A", "S", "D"]}
		"accept": return {"kind": "key", "label": "E"}
		"back": return {"kind": "key", "label": Text.t("KEY_SPACE")}
		"skip": return {"kind": "key", "label": "TAB"}
	return {"kind": "key", "label": "?"}


func _label(parent: Node, size: int, colour: Color, arcade := false) -> Label:
	var l := Label.new()
	if arcade:
		l.add_theme_font_override("font", Hud.ARCADE)
		size = int(size * 0.6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", Color("#1a1024"))
	l.add_theme_constant_override("outline_size", 8 if arcade else 6)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## The arcade face draws Í and Ó badly: a label with either goes plain.
static func _arcade(l: Label) -> void:
	if "Í" in l.text or "Ó" in l.text:
		l.remove_theme_font_override("font")


## Over the town, from the stop picked: a ring on each stop a push can reach
## and an arrow towards it, on the way it lies on the screen, so what each
## direction does is seen before it is pressed.
func _draw_arrows() -> void:
	if state != "city":
		return
	var from := stage.stop_point(stage.picked)
	var here := stage.stop_on_screen(stage.picked)
	var stops := _stops_open()
	var seen := {}
	for d in DIR_VECTORS:
		var to := toward(here, DIR_VECTORS[d], stops)
		if to < 0 or seen.has(to):
			continue
		seen[to] = true
		var at := stage.stop_point(to)
		var dir := (at - from).normalized()
		var base := from + dir * minf(ARROW_R, from.distance_to(at) * 0.4)
		var side := dir.orthogonal() * 18.0
		_arrows.draw_arc(at, 36.0, 0.0, TAU, 40, Color(ARROW, 0.8), 4.0, true)
		_arrows.draw_colored_polygon(PackedVector2Array([base + dir * 34.0, base + side, base - side]), ARROW)
		_arrows.draw_polyline(PackedVector2Array([base + dir * 34.0, base + side, base - side, base + dir * 34.0]), Color("#1a1024"), 4.0, true)


func _nav() -> void:
	_sound("nav")


func _sound(kind: String) -> void:
	sound.emit(kind)


## The night sky: a deep violet, lighter towards the horizon.
## The town's picture with its sides faded out past `edge` (in screen
## heights from the middle), over `soft` more.
static func _edge_material() -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform float aspect = 1.7778;
uniform float edge = 1.0;
uniform float soft = 0.12;
void fragment() {
	float x = abs(UV.x - 0.5) * aspect;
	COLOR = texture(TEXTURE, UV) * COLOR * (1.0 - smoothstep(edge, edge + soft, x));
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	return m


static func _sky_material() -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.05, 0.04, 0.1, 1.0);
uniform vec4 low : source_color = vec4(0.15, 0.1, 0.24, 1.0);
void fragment() {
	vec3 c = mix(top.rgb, low.rgb, smoothstep(0.0, 1.0, UV.y));
	c *= 1.0 - distance(UV, vec2(0.5, 0.55)) * 0.5;
	// Its own colour, but the node's fade (modulate) as it comes and goes.
	COLOR = vec4(c, COLOR.a);
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	return m
