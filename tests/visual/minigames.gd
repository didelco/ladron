extends Control
## The minigames, loose, to play and to look at:
##   play: 1-6 picks one, the arrows or WASD, E acts, C leaves, R again;
##         P turns the pressure up (0, 0.5, 1).
##   -- --watch: all six at once, each played by a little bot, for a picture:
##   godot --path . --write-movie out.png --fixed-fps 30 --quit-after 300 tests/visual/minigames.tscn -- --watch

const KINDS := ["safe", "lock", "wires", "grate", "sneeze", "pose"]

var _games: Array[Minigame] = []
var _watch := false
var _pick := 0
var _pressure := 0.0
var _info: Label
var _held := {}


func _ready() -> void:
	Text.setup()
	var back := ColorRect.new()
	back.color = Color("#0f0d14")
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_info = Label.new()
	_info.position = Vector2(20, 12)
	_info.add_theme_font_size_override("font_size", 14)
	add_child(_info)
	_watch = "--watch" in OS.get_cmdline_user_args()
	if _watch:
		for i in KINDS.size():
			var g := _make(KINDS[i], i + 3)
			g.position = Vector2(40 + (i % 3) * 270, 60 + (i / 3) * 220)
			g.pressure = 0.4 if i % 2 == 1 else 0.0
	else:
		_open(0)


func _make(kind: String, seed: int) -> Minigame:
	var g: Minigame
	match kind:
		"safe": g = MgSafe.new(3)
		"lock": g = MgLockpick.new(4)
		"wires": g = MgWires.new(5, 3)
		"grate": g = MgGrate.new(4)
		"sneeze": g = MgSneeze.new()
		_: g = MgPose.new()
	g.setup(seed, _pressure)
	g.colour = [Color("#2ec4a6"), Color("#f0a13a"), Color("#b07cff"), Color("#4dabf7")][seed % 4]
	add_child(g)
	_games.append(g)
	return g


func _open(i: int) -> void:
	for g in _games:
		g.queue_free()
	_games.clear()
	_pick = i
	var g := _make(KINDS[i], randi())
	g.position = (get_viewport_rect().size - Minigame.SIZE) / 2.0
	g.scale = Vector2.ONE * 2.0
	g.position -= Minigame.SIZE / 2.0


func _unhandled_input(e: InputEvent) -> void:
	if _watch or not (e is InputEventKey and e.pressed and not e.echo):
		return
	if e.keycode >= KEY_1 and e.keycode <= KEY_6:
		_open(e.keycode - KEY_1)
	elif e.keycode == KEY_R:
		_open(_pick)
	elif e.keycode == KEY_P:
		_pressure = fmod(_pressure + 0.5, 1.5)
		_open(_pick)


func _process(dt: float) -> void:
	if _watch:
		for g in _games:
			g.feed(_bot(g), dt)
		_info.text = "Minijuegos · jugados por un bot"
		return
	var now := {
		"left": Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT),
		"right": Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT),
		"act": Input.is_physical_key_pressed(KEY_E),
		"leave": Input.is_physical_key_pressed(KEY_C),
	}
	var tap := Vector2i.ZERO
	if now.left and not _held.get("left", false):
		tap.x = -1
	if now.right and not _held.get("right", false):
		tap.x = 1
	var input := {"tap": tap, "hold": Vector2(float(now.right) - float(now.left), 0), "act": now.act and not _held.get("act", false),
		"act_held": now.act, "leave": now.leave and not _held.get("leave", false)}
	_held = now
	for g in _games:
		g.feed(input, dt)
	var g0: Minigame = _games[0] if not _games.is_empty() else null
	_info.text = "1-6 elegir · R otra vez · P presión %.1f · %s" % [_pressure, ("HECHO %.1f s" % g0.elapsed) if g0 and g0.over and not g0.left else ""]


## A bot for the picture: plays each the way a person would, a bit slowly.
var _bot_wait := {}
func _bot(g: Minigame) -> Dictionary:
	var none := {"tap": Vector2i.ZERO, "hold": Vector2.ZERO, "act": false, "act_held": false, "leave": false}
	var w: float = _bot_wait.get(g, 0.0) - get_process_delta_time()
	_bot_wait[g] = w
	if g is MgSneeze:
		var s := g as MgSneeze
		var pinch: bool = _bot_wait.get("pinch%d" % g.get_instance_id(), false)
		if s.tickle > 0.75 and s.breath > 0.4:
			pinch = true
		elif s.tickle < 0.2 or s.breath < 0.25:
			pinch = false
		_bot_wait["pinch%d" % g.get_instance_id()] = pinch
		none.act_held = pinch
		return none
	if g is MgPose:
		var p := g as MgPose
		none.hold = Vector2(clampf(-p.needle * 2.0 - p._vel * 0.8, -1.0, 1.0), 0)
		return none
	if w > 0.0:
		return none
	_bot_wait[g] = 0.18
	if g is MgSafe:
		var s := g as MgSafe
		if s.over:
			return none
		var d := MgSafe._diff(float(s.combo[s.got]), s.reading())
		if absf(d) <= MgSafe.ON:
			none.act = true
			_bot_wait[g] = 0.5
		elif absf(d) > 3.0:
			none.hold = Vector2(signf(d), 0)
			_bot_wait[g] = 0.0
		else:
			none.tap = Vector2i(int(signf(d)), 0)
	elif g is MgLockpick:
		var l := g as MgLockpick
		if not l.over:
			none.act_held = l.height < l.bands[l.done] - 0.01
			_bot_wait[g] = 0.0
	elif g is MgWires:
		var wi := g as MgWires
		if not wi.over:
			var want: int = wi.order[wi.step]
			if wi.at != want:
				none.tap = Vector2i(signi(want - wi.at), 0)
			else:
				none.act = true
				_bot_wait[g] = 0.5
	elif g is MgGrate:
		var r := g as MgGrate
		none.tap = Vector2i(-r._last if r._last != 0 else 1, 0)
	return none
