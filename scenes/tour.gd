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
## Main listens for what it asks for (left, room_chosen) and forwards the
## input while it is up (input).

## Out of the town, back to the story's menu.
signal left
## A room picked for tonight: heist n.
signal room_chosen(n: int)
## A menu sound to play: "nav", "ok" or "back".
signal sound(kind: String)

## The words over the scene, all here to change in one place.
const SIGN := Color("#fff0d6")
const SIGN_DIM := Color("#b9a9d8")
const SIGN_SHUT := Color("#8a7fa3")
## How dark the museum's own picture shows behind the doll's house.
const PICTURE_SHADE := 0.55

var stage: CityStage
var state := "city"
var players := 1
## the museums open (0-based up to), the heist reached
var reached := 1
var _root: Control
var _view: SubViewportContainer
var _picture: TextureRect
var _sign: VBoxContainer
var _sign_title: Label
var _sign_line: Label
var _sign_stars: Label
var _title: Label
var _subtitle: Label
var _hints: HBoxContainer
var _pad := false
## the stick, per pad: where it was last frame, to move once a push
var _stick := {}
## the rooms of the museum inside, as Story has them: heist numbers
var _nights: Array[int] = []
var _fade: Tween


func _init() -> void:
	layer = 2
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	# The night sky behind the town, and the museum's picture behind it
	# once inside.
	var sky := ColorRect.new()
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.material = _sky_material()
	_root.add_child(sky)
	_picture = TextureRect.new()
	_picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.material = _blur_material()
	_picture.modulate.a = 0.0
	_root.add_child(_picture)
	_view = SubViewportContainer.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.stretch = true
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


## The town for a gang of `n`, as far as it has got: museum `pick` picked.
func open_city(n: int, pick: int) -> void:
	players = n
	reached = Story.unlocked(n)
	stage.build(Story.museum_of(reached), pick)
	_show_city()


func _show_city() -> void:
	state = "city"
	_title.text = Text.t("STORY_MAP_TITLE")
	_subtitle.text = Text.t("STORY_GANG_%d" % players)
	_picture.modulate.a = 0.0
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
	var stars := StarSlots.museum_line(m, players)
	_sign_stars.text = stars
	_sign_stars.visible = stars != ""


## The next open museum that way (dir -1 or 1), if any.
func _step_museum(dir: int) -> void:
	var m := stage.picked + dir
	if m < 0 or m >= Story.MUSEUMS.size() or not stage.is_open(m):
		return
	_nav()
	_pick_museum(m)


func _enter_museum() -> void:
	var m := stage.picked
	if not stage.is_open(m):
		_sound("back")
		return
	_sound("ok")
	state = "zoom"
	_sign.visible = false
	_set_hints([])
	_show_picture(m)
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
	_picture.modulate.a = 1.0
	_show_picture(m)
	_pick_room(_nights.find(pick_n))
	_set_hints([["move", Text.t("TOUR_HINT_ROOM")], ["accept", Text.t("TOUR_HINT_PLAN")], ["back", Text.t("TOUR_HINT_TOWN")]])


func _pick_room(i: int) -> void:
	i = clampi(i, 0, _nights.size() - 1)
	stage.pick_room(i)
	var n := _nights[i]
	var loot: Dictionary = Story.level(n).loot
	_sign.visible = true
	if n <= reached:
		_sign_title.text = Text.t("STORY_BOSS_ROOM") if Story.is_boss(n) else Text.t("TOUR_ROOM") % Story.room_of(n)
		_sign_line.text = Heist.first_upper(loot.name)
		_sign_title.add_theme_color_override("font_color", Color(loot.colour).lightened(0.2))
	else:
		_sign_title.text = Text.t("STORY_BOSS_ROOM") if Story.is_boss(n) else Text.t("TOUR_ROOM") % Story.room_of(n)
		_sign_line.text = Text.t("TOUR_ROOM_SHUT")
		_sign_title.add_theme_color_override("font_color", SIGN_SHUT)
	_arcade(_sign_title)
	var stars := StarSlots.room_line(n, players)
	_sign_stars.text = stars
	_sign_stars.visible = stars != ""


func _step_room(dir: int) -> void:
	var i := stage.room + dir
	if i < 0 or i >= _nights.size() or _nights[i] > reached:
		return
	_nav()
	_pick_room(i)


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
	_set_hints([])
	var tw := create_tween()
	tw.tween_property(_picture, "modulate:a", 0.0, 0.0 if stage.hurry else 0.5)
	stage.go_out(_show_city)


## The museum's own picture (Hud.PICTURES), far behind and out of focus.
func _show_picture(m: int) -> void:
	var look: Dictionary = Hud.PICTURES.get("museum_%d" % (m + 1), {})
	if look.is_empty() or not ResourceLoader.exists(look.path):
		return
	_picture.texture = load(look.path)
	_picture.self_modulate = Color(look.tint) * float(look.shade) * PICTURE_SHADE
	_picture.self_modulate.a = 1.0
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(_picture, "modulate:a", 1.0, 0.0 if stage.hurry else 0.9).set_delay(0.0 if stage.hurry else CityStage.ZOOM_S * 0.5)


# --- Input ------------------------------------------------------------------------

## A press, whatever it came from, as what it means here: "left", "right",
## "up", "down", "accept", "back", "skip", or "" for nothing. Keys: the
## arrows and WASD, E or Enter to take, Escape or Space to go back, Tab to
## skip; a pad: the cross or the left stick, A, B and Start.
func intent(event: InputEvent) -> String:
	if event is InputEventKey and event.pressed and not event.echo:
		_pad = false
		match event.keycode:
			KEY_LEFT, KEY_A: return "left"
			KEY_RIGHT, KEY_D: return "right"
			KEY_UP, KEY_W: return "up"
			KEY_DOWN, KEY_S: return "down"
			KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_PERIOD: return "accept"
			KEY_ESCAPE, KEY_SPACE, KEY_BACKSPACE: return "back"
			KEY_TAB: return "skip"
	elif event is InputEventJoypadButton and event.pressed:
		if not Pads.real(event.device):
			return ""
		_pad = true
		match event.button_index:
			JOY_BUTTON_DPAD_LEFT: return "left"
			JOY_BUTTON_DPAD_RIGHT: return "right"
			JOY_BUTTON_DPAD_UP: return "up"
			JOY_BUTTON_DPAD_DOWN: return "down"
			JOY_BUTTON_A: return "accept"
			JOY_BUTTON_B: return "back"
			JOY_BUTTON_START: return "skip"
			JOY_BUTTON_LEFT_SHOULDER: return "prev"
			JOY_BUTTON_RIGHT_SHOULDER: return "next"
	elif event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		if not Pads.real(event.device):
			return ""
		# Once a push: past half way it moves, and not again until it is let
		# back under a third.
		var key := "%d:%d" % [event.device, event.axis]
		var was: int = _stick.get(key, 0)
		var now := 0
		if absf(event.axis_value) > 0.5:
			now = 1 if event.axis_value > 0 else -1
		elif absf(event.axis_value) > 0.33:
			now = was
		_stick[key] = now
		if now != 0 and now != was:
			_pad = true
			if event.axis == JOY_AXIS_LEFT_X:
				return "right" if now > 0 else "left"
			return "down" if now > 0 else "up"
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
				"left", "up", "prev": _step_museum(-1)
				"right", "down", "next": _step_museum(1)
				"accept": _enter_museum()
				"back":
					_sound("back")
					left.emit()
		"museum":
			match what:
				"left", "up", "prev": _step_room(-1)
				"right", "down", "next": _step_room(1)
				"accept": _choose_room()
				"back": _leave_museum()


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
	match state:
		"city":
			for m in Story.MUSEUMS.size():
				var d := at.distance_to(stage.on_screen(stage._museums[m].global_position + Vector3(0, 1.0, 0)))
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
			near = 70.0
			for i in stage.room_count():
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
	_title.position = Vector2(view.x * 0.5 - _title.size.x * 0.5, 22)
	_subtitle.position = Vector2(view.x * 0.5 - _subtitle.size.x * 0.5, 22 + _title.size.y + 6)
	_hints.position = Vector2(view.x * 0.5 - _hints.get_combined_minimum_size().x * 0.5, view.y - 58)
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


func _nav() -> void:
	_sound("nav")


func _sound(kind: String) -> void:
	sound.emit(kind)


## The night sky: a deep violet, lighter towards the horizon.
static func _sky_material() -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.05, 0.04, 0.1, 1.0);
uniform vec4 low : source_color = vec4(0.15, 0.1, 0.24, 1.0);
void fragment() {
	vec3 c = mix(top.rgb, low.rgb, smoothstep(0.0, 1.0, UV.y));
	c *= 1.0 - distance(UV, vec2(0.5, 0.55)) * 0.5;
	COLOR = vec4(c, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	return m


## A picture far off: blurred, as a camera focused on something near sees it.
static func _blur_material() -> ShaderMaterial:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;
uniform float reach = 0.012;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec4 sum = vec4(0.0);
	float n = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			vec2 o = vec2(float(x), float(y)) * reach / 3.0;
			sum += texture(TEXTURE, UV + o);
			n += 1.0;
		}
	}
	vec4 c = sum / n;
	c.rgb *= 1.0 - distance(UV, vec2(0.5)) * 0.6;
	COLOR = c * tint;
}
"""
	var m := ShaderMaterial.new()
	m.shader = s
	return m
