extends Control
## The minigames on their own, to try them by hand: no museum, no guards,
## the box big in the middle of the screen.
##   godot --path . res://tests/visual/minigames.tscn
##
## 1 pick · 2 suction cup · 3 wires · 4 balance · 5 squeeze · R again · L level
## T: how much the hands shake (0, some, a lot) · P: the pressure on the
## balance (none, a guard near, a guard near and the lights on)
## Playing: WASD or the arrows, E (X on the pad), Space (B) to let go.

const KINDS := ["lockpick", "steady", "wires", "balance", "squeeze"]
const LEVELS := [0.0, 0.55, 1.0]
const ZOOM := 2.0

var _box: MinigameBox
var _holder: Control
var _info: Label
var _result: Label
var _game: Minigame
var _kind := 0
var _shake := 0
var _press := 0
var _level := 1
var _again_in := -1.0
var _was := {}


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#15112a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_holder = Control.new()
	_holder.scale = Vector2.ONE * ZOOM
	add_child(_holder)
	_box = MinigameBox.new()
	_holder.add_child(_box)
	_info = _label(16, Hud.CREAM)
	_info.position = Vector2(24, 20)
	_result = _label(22, Hud.C.gold)
	_start()


func _label(size: int, colour: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Hud.ARCADE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	add_child(l)
	return l


func _start() -> void:
	var kind: String = KINDS[_kind]
	var steps: int = {"lockpick": 4, "steady": 6, "wires": 0, "balance": 1}.get(kind, 0)
	_game = Minigame.make(kind, "case", steps, _keys(), 0, _level)
	_result.text = ""
	_again_in = -1.0


func _keys() -> Dictionary:
	var k := func(keys: Array) -> bool:
		return keys.any(func(key): return Input.is_physical_key_pressed(key))
	var pad := func(button: JoyButton) -> bool:
		return Input.get_connected_joypads().any(func(d): return Input.is_joy_button_pressed(d, button))
	var axis := func(which: JoyAxis, sign_: float) -> bool:
		return Input.get_connected_joypads().any(func(d): return Input.get_joy_axis(d, which) * sign_ > 0.5)
	return {
		"up": k.call([KEY_W, KEY_UP]) or pad.call(JOY_BUTTON_DPAD_UP) or axis.call(JOY_AXIS_LEFT_Y, -1.0),
		"down": k.call([KEY_S, KEY_DOWN]) or pad.call(JOY_BUTTON_DPAD_DOWN) or axis.call(JOY_AXIS_LEFT_Y, 1.0),
		"left": k.call([KEY_A, KEY_LEFT]) or pad.call(JOY_BUTTON_DPAD_LEFT) or axis.call(JOY_AXIS_LEFT_X, -1.0),
		"right": k.call([KEY_D, KEY_RIGHT]) or pad.call(JOY_BUTTON_DPAD_RIGHT) or axis.call(JOY_AXIS_LEFT_X, 1.0),
		"action": k.call([KEY_E]) or pad.call(JOY_BUTTON_X),
		"cancel": k.call([KEY_SPACE]) or pad.call(JOY_BUTTON_B),
	}


## The keyboard's names, or the pad's once one is touched (as the game
## does for a thief playing on its own).
var _pad := false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_pad = false
	elif (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_pad = true


func _controls() -> Dictionary:
	if _pad:
		return {"move": Text.t("KEY_STICK"), "lr": "◀ ▶", "ud": "▲ ▼", "action": "X", "cancel": "B"}
	return {"move": "WASD", "lr": "A D", "ud": "W S", "action": "E", "cancel": Text.t("KEY_SPACE")}


## A key going down this frame (for the test's own keys).
func _pressed(key: Key) -> bool:
	var down := Input.is_physical_key_pressed(key)
	var was: bool = _was.get(key, false)
	_was[key] = down
	return down and not was


func _process(dt: float) -> void:
	for i in KINDS.size():
		if _pressed([KEY_1, KEY_2, KEY_3, KEY_4, KEY_5][i]):
			_kind = i
			_start()
	if _pressed(KEY_R):
		_start()
	if _pressed(KEY_L):
		_level = (_level + 1) % 3
		_start()
	if _pressed(KEY_T):
		_shake = (_shake + 1) % LEVELS.size()
	if _pressed(KEY_P):
		_press = (_press + 1) % LEVELS.size()
	_game.tremble = LEVELS[_shake]
	_game.pressure = LEVELS[_press]
	if _again_in >= 0.0:
		_again_in -= dt
		if _again_in < 0.0:
			_start()
	else:
		match _game.tick(_keys(), dt):
			"done":
				_result.text = "¡HECHO EN %.1f s!" % _game.t
				_again_in = 1.6
			"fail":
				_result.text = "¡TE CAES! AGUANTASTE %.1f s" % _game.t
				_again_in = 1.6
			"quit":
				_result.text = "SUELTAS"
				_again_in = 0.8
	var view := get_viewport_rect().size
	_box.follow(_game, Vector2.ZERO, Color("#2ec4a6"), _controls())
	_box.position = Vector2.ZERO
	_holder.position = (view - MinigameBox.SIZE * ZOOM) / 2 + Vector2(0, 30)
	var names := ["GANZÚA", "VENTOSA", "CABLES", "EQUILIBRIO", "COLARSE"]
	_info.text = "1 GANZUA · 2 VENTOSA · 3 CABLES · 4 EQUILIBRIO · 5 COLARSE · R OTRA VEZ\nL NIVEL: %s · T TEMBLOR: %s · P PRESION: %s\n\n%s   %.1f s" % [
		["FACIL", "MEDIO", "DIFICIL"][_level], ["NADA", "ALGO", "MUCHO"][_shake], ["NADA", "GUARDIA CERCA", "GUARDIA Y LUZ"][_press], names[_kind], _game.t]
	_result.size = Vector2(view.x, 40)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.position = Vector2(0, view.y - 80)
