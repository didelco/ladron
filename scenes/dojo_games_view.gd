class_name DojoGamesView
extends Node3D
## The dojo's games as seen (DojoGame): the golden sock, the pins, the lit
## pedestal or hideouts in the world, each with a column of light, and on top,
## in 2D, the rings that empty, the arrows at the edge of the screen for what is
## off it, the lantern's cone, the sneeze bars and the lean, the head-up display
## (NIVEL n, the count, MEJOR, the time) and, at the end, the panel (¡SE FUE
## EL CALCETÍN! / ¡GANASTE!, the level reached, ¡NUEVO RÉCORD!, the MVP, and
## OTRA VEZ / SEGUIR / SALIR).
##
## Nothing here decides anything: show(view) is given DojoGame.view() every
## frame, react(events) the events of step(). Whoever runs it (Main) reads the
## keys on the panel: MenuKeys.of(event) -> "accept" is accept() (its id),
## "back" is "exit", the arrows move(dir).

const INK := Color("#2a160d")
const CREAM := Color("#f1dfbd")
const GOLD := Color("#ffcf3a")
const RED := Color("#ff3b3b")
const GREEN := Color("#7be07b")
const PANEL := Color("#35211a")
const FONT_SIZE := 22
const RING_R := 34.0
const EDGE := 40.0
## What sound each event has (Sfx's names); "" for none. The sock's turning
## up, a tick, catching, going up a level, the alarm, losing, winning.
const SOUNDS := {"spawn": "pin", "tick": "tick", "catch": "stolen", "knock": "bin", "strike": "sting", "clear": "ok",
	"level": "go", "alarm": "siren", "lost": "caught", "won": "escaped", "sneeze": "sneeze", "tickle": "nav",
	"up": "go", "in": "ok", "fall": "roll_bump", "ready": "nav"}

var _camera: Camera3D
var _layer: CanvasLayer
var _ui: Control
var _view := {}
var _t := 0.0
var _nodes: Array[Node3D] = []
var _column: Array[MeshInstance3D] = []
var _selected := 0
var _popups: Array[Dictionary] = []


func setup(camera: Camera3D) -> void:
	_camera = camera
	_layer = CanvasLayer.new()
	_layer.layer = 30
	add_child(_layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	_layer.add_child(_ui)
	visible = false
	_layer.visible = false


## The sound of an event ("" for none).
static func sound_for(event: Dictionary) -> String:
	return String(SOUNDS.get(event.get("e", ""), ""))


## Show the game as it is (DojoGame.view()); an empty or idle one hides it all.
func show_view(view: Dictionary) -> void:
	var was := String(_view.get("state", ""))
	_view = view
	var on: bool = not view.is_empty() and view.get("state", "idle") != "idle"
	visible = on
	if _layer != null:
		_layer.visible = on
	if not on:
		_update_objects([])
		return
	_update_objects(view.get("objects", []))
	if String(view.state) != was:
		_selected = 0
	if _ui != null:
		_ui.queue_redraw()


## As the name in the brief: show(view).
func show_game(view: Dictionary) -> void:
	show_view(view)


## Sounds and bursts for the events of a frame; sfx and the parent for the
## bursts (the world's node) may be null.
func react(events: Array, sfx: Sfx = null, world: Node3D = null) -> void:
	for e in events:
		var sound := sound_for(e)
		if sfx != null and sound != "":
			sfx.ui(sound, 0.7 if e.e == "tick" else 1.0)
		match e.e:
			"catch":
				if world != null:
					Fx.sparkle(world, MuseumView.to_world(e.pos.x, e.pos.y, 0.6), GOLD)
				_pop("+1", e.pos, GOLD)
			"knock":
				if world != null:
					Fx.puff(world, MuseumView.to_world(e.pos.x, e.pos.y, 0.3), e.chain)
			"strike":
				_pop(Text.t("HIDEOUT_GAME_STRIKE"), Vector2.ZERO, GOLD, true)
			"alarm":
				_pop(Text.t("HIDEOUT_GAME_ALARM"), Vector2.ZERO, RED, true)
	if _ui != null:
		_ui.queue_redraw()


# --- The panel at the end ---------------------------------------------------------------

## The choices of the panel at the end, in order: "again", "go_on" (only after
## winning), "exit".
func menu() -> Array[String]:
	var out: Array[String] = ["again"]
	if _view.get("state", "") == "won":
		out.append("go_on")
	out.append("exit")
	return out


func selected() -> String:
	var m := menu()
	return m[clampi(_selected, 0, m.size() - 1)]


func move(dir: int) -> void:
	var m := menu()
	_selected = wrapi(_selected + dir, 0, m.size())
	if _ui != null:
		_ui.queue_redraw()


## The choice made ("again", "go_on" or "exit"); "" if the game is not at its end.
func accept() -> String:
	if not (_view.get("state", "") in ["won", "lost"]):
		return ""
	return selected()


# --- The world ---------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t += dt
	for i in _nodes.size():
		if _nodes[i].visible:
			_nodes[i].rotation.y = _t * 1.6 if _nodes[i].name.begins_with("sock") else _nodes[i].rotation.y
			var bob := 0.08 * sin(_t * 4.0 + i)
			_nodes[i].position.y = _base_y(_nodes[i]) + bob
	if _ui != null and _ui.is_visible_in_tree():
		_ui.queue_redraw()


func _base_y(n: Node3D) -> float:
	return float(n.get_meta("y", 0.0))


func _update_objects(objects: Array) -> void:
	while _nodes.size() < objects.size():
		var holder := Node3D.new()
		add_child(holder)
		_nodes.append(holder)
		var col := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.3
		cyl.bottom_radius = 0.3
		cyl.height = 3.0
		col.mesh = cyl
		col.material_override = _glow(Color(GOLD, 0.22))
		col.position.y = 1.5
		col.visible = false
		add_child(col)
		_column.append(col)
	for i in _nodes.size():
		var n := _nodes[i]
		if i >= objects.size():
			n.visible = false
			_column[i].visible = false
			continue
		var o: Dictionary = objects[i]
		var kind := String(o.kind)
		var want := "%s%d" % [kind, i]
		if n.name != want or n.get_child_count() == 0:
			for c in n.get_children():
				c.queue_free()
			n.name = want
			_build(n, kind)
		var p: Vector2 = o.pos
		var w := MuseumView.to_world(p.x, p.y, 0.0)
		n.visible = true
		n.position = w
		n.set_meta("y", 0.0)
		n.rotation.z = 0.0
		if kind == "pin" and o.get("down", false):
			n.rotation.z = deg_to_rad(90.0) * float(o.get("fell", 1.0))
		_column[i].visible = kind != "pin" or not o.get("down", false)
		_column[i].position = Vector3(w.x, 1.5, w.z)
		_column[i].material_override = _glow(Color(RED if o.get("gate", "") != "" else GOLD, 0.2))


func _build(n: Node3D, kind: String) -> void:
	match kind:
		"sock":
			var leg := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.28, 0.7, 0.28)
			leg.mesh = b
			leg.material_override = _flat(GOLD)
			leg.position.y = 0.6
			n.add_child(leg)
			var foot := MeshInstance3D.new()
			var f := BoxMesh.new()
			f.size = Vector3(0.6, 0.26, 0.28)
			foot.mesh = f
			foot.material_override = _flat(GOLD.darkened(0.15))
			foot.position = Vector3(0.16, 0.25, 0.0)
			n.add_child(foot)
		"pin":
			var m := MeshInstance3D.new()
			var c := CapsuleMesh.new()
			c.radius = 0.2
			c.height = 0.85
			m.mesh = c
			m.material_override = _flat(CREAM)
			m.position.y = 0.45
			n.add_child(m)
			var band := MeshInstance3D.new()
			var tb := TorusMesh.new()
			tb.inner_radius = 0.19
			tb.outer_radius = 0.24
			band.mesh = tb
			band.material_override = _flat(RED)
			band.position.y = 0.62
			n.add_child(band)
		"pedestal":
			var ring := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = 0.55
			t.outer_radius = 0.7
			ring.mesh = t
			ring.material_override = _glow(Color(GREEN, 0.8))
			ring.position.y = 0.05
			n.add_child(ring)
		_:
			var ring2 := MeshInstance3D.new()
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.55
			t2.outer_radius = 0.7
			ring2.mesh = t2
			ring2.material_override = _glow(Color(GOLD, 0.8))
			ring2.position.y = 0.05
			n.add_child(ring2)


func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 0.35
	return m


func _glow(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = colour
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _screen(p: Vector2, height := 0.6) -> Vector2:
	if _camera == null:
		return Vector2.ZERO
	return _camera.unproject_position(MuseumView.to_world(p.x, p.y, height))


func _pop(text: String, at: Vector2, colour: Color, centred := false) -> void:
	_popups.append({"text": text, "at": at, "colour": colour, "age": 0.0, "centred": centred})
	if _popups.size() > 8:
		_popups.remove_at(0)


# --- The screen ---------------------------------------------------------------------------

func _text(s: String, pos: Vector2, size: int, colour: Color, centred := false, width := 0.0) -> void:
	var font: Font = Hud.ARCADE
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := pos
	if centred:
		at.x -= w * 0.5
	_ui.draw_string_outline(font, at + Vector2(0, size), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, INK)
	_ui.draw_string(font, at + Vector2(0, size), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func _draw_ui() -> void:
	if _view.is_empty() or _view.get("state", "idle") == "idle":
		return
	var size := _ui.size
	var v := _view
	# The dojo goes red when the scarecrows see somebody.
	var alert: float = v.get("alert", 0.0)
	if alert > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, size), Color(RED, 0.28 * alert * (0.6 + 0.4 * sin(_t * 12.0))))
	# The world's marks.
	if _camera != null:
		_draw_world_marks(size)
	_draw_hud(size)
	_draw_popups(size)
	match String(v.state):
		"ready":
			_text(Text.t("HIDEOUT_GAME_READY"), Vector2(size.x * 0.5, size.y * 0.36), 44, GOLD, true)
			_text(_goal_hint(), Vector2(size.x * 0.5, size.y * 0.36 + 64), 20, CREAM, true)
		"won", "lost":
			_draw_end(size)


func _goal_hint() -> String:
	match String(_view.get("id", "")):
		"bolos": return Text.t("HIDEOUT_GAME_ROLL")
		"pedestal": return Text.t("HIDEOUT_GAME_CLIMB")
		"aguanta": return Text.t("HIDEOUT_GAME_HIDE")
	return Text.t("HIDEOUT_GAME_ATRAPA")


func _draw_world_marks(size: Vector2) -> void:
	var v := _view
	var frame := Rect2(Vector2.ZERO, size).grow(-EDGE)
	for o in v.get("objects", []):
		var p := _screen(o.pos)
		var ring: float = o.get("ring", -1.0)
		if frame.has_point(p):
			if ring >= 0.0:
				var col := GOLD.lerp(RED, 1.0 - clampf(ring * 2.0, 0.0, 1.0))
				_ui.draw_arc(p, RING_R, -PI / 2, -PI / 2 + TAU, 40, Color(INK, 0.6), 8.0, true)
				if ring > 0.0:
					_ui.draw_arc(p, RING_R, -PI / 2, -PI / 2 + TAU * ring, 40, col, 6.0, true)
			if o.get("gate", "") != "":
				_text("|-|", p + Vector2(0, -RING_R - 30), 14, RED, true)
		else:
			# Off the screen: an arrow at the edge, towards it.
			var mid := size * 0.5
			var dir := (p - mid).normalized()
			var t := INF
			var half := size * 0.5 - Vector2(EDGE, EDGE)
			if absf(dir.x) > 0.001:
				t = minf(t, half.x / absf(dir.x))
			if absf(dir.y) > 0.001:
				t = minf(t, half.y / absf(dir.y))
			var tip := mid + dir * t
			var side := dir.orthogonal()
			_ui.draw_colored_polygon(PackedVector2Array([tip, tip - dir * 26 + side * 14, tip - dir * 26 - side * 14]), GOLD)
	# The lantern's cone.
	var lan: Dictionary = v.get("lantern", {})
	if not lan.is_empty():
		var from: Vector2 = lan.pos
		var pts := PackedVector2Array([_screen(from, 0.9)])
		for i in 9:
			var a: float = float(lan.angle) - float(lan.cone) + 2.0 * float(lan.cone) * i / 8.0
			pts.append(_screen(from + Vector2.from_angle(a) * float(lan.range), 0.0))
		_ui.draw_colored_polygon(pts, Color(GOLD, 0.16))
	# The sneeze bars, over the heads of the ones that hold it in, and the
	# lean of the one on the pedestal.
	var bars: Dictionary = v.get("bars", {})
	if not bars.is_empty():
		var i := 0
		for k in bars:
			var at := Vector2(size.x * 0.5 - 110 + i * 120, size.y - 90)
			_ui.draw_rect(Rect2(at, Vector2(100, 14)), Color(INK, 0.8))
			_ui.draw_rect(Rect2(at, Vector2(100 * clampf(float(bars[k]), 0.0, 1.0), 14)), GOLD.lerp(RED, clampf(float(bars[k]), 0.0, 1.0)))
			_text(Text.t("HIDEOUT_GAME_SNEEZE") if i == 0 else "", at + Vector2(0, -26), 12, CREAM)
			i += 1
	if v.has("lean") and v.get("phase", "") == "hold":
		var fall: float = v.fall
		var lean: float = v.lean
		var at2 := Vector2(size.x * 0.5 - 150, size.y - 80)
		_ui.draw_rect(Rect2(at2, Vector2(300, 16)), Color(INK, 0.8))
		_ui.draw_rect(Rect2(at2 + Vector2(150 - 300 * 0.6 / fall * 0.5, 0), Vector2(300 * 0.6 / fall, 16)), Color(GREEN, 0.4))
		var x := at2.x + 150 + clampf(lean / fall, -1.0, 1.0) * 150
		_ui.draw_rect(Rect2(Vector2(x - 4, at2.y - 6), Vector2(8, 28)), GOLD if absf(lean) < 0.6 else RED)


func _draw_hud(size: Vector2) -> void:
	var v := _view
	var top := Vector2(size.x * 0.5, 14)
	var title := Text.t("HIDEOUT_GAME_LEVEL") % int(v.level)
	if v.get("extra", false):
		title += "  " + Text.t("HIDEOUT_GAME_EXTRA")
	_text(title, top, 26, CREAM, true)
	var line := Text.t("HIDEOUT_GAME_COUNT") % [int(v.got), int(v.goal)] if not v.get("extra", false) else str(int(v.got))
	var best: int = int(v.get("best", 0))
	if best > 0:
		line += "    " + Text.t("HIDEOUT_GAME_BEST") % best
	_text(line, top + Vector2(0, 34), 16, GOLD, true)
	var tm: Dictionary = v.get("timer", {})
	if String(v.state) == "playing" and not tm.is_empty() and float(tm.get("max", 0.0)) > 0.0:
		var frac := clampf(float(tm.left) / float(tm.max), 0.0, 1.0)
		var bar := Rect2(Vector2(size.x * 0.5 - 140, 74), Vector2(280, 12))
		_ui.draw_rect(bar, Color(INK, 0.8))
		var hold := String(tm.get("kind", "limit")) == "hold"
		# A clock to beat empties; one to hold out fills the wait.
		var shown := 1.0 - frac if hold else frac
		var col := GREEN if hold else GOLD.lerp(RED, 1.0 - clampf(frac * 2.0, 0.0, 1.0))
		_ui.draw_rect(Rect2(bar.position, Vector2(bar.size.x * shown, bar.size.y)), col)
		_text("%.1f" % float(tm.left), bar.position + Vector2(bar.size.x + 12, -6), 16, CREAM)
		if String(v.id) == "aguanta" and String(v.get("phase", "")) == "enter":
			_text(Text.t("HIDEOUT_GAME_HIDE"), Vector2(size.x * 0.5, 96), 18, GOLD, true)
		elif String(v.id) == "pedestal" and String(v.get("phase", "")) == "climb":
			_text(Text.t("HIDEOUT_GAME_CLIMB"), Vector2(size.x * 0.5, 96), 18, GOLD, true)


func _draw_popups(size: Vector2) -> void:
	var dt := 1.0 / 60.0
	var keep: Array[Dictionary] = []
	for p in _popups:
		p.age = float(p.age) + dt
		if p.age > 1.2:
			continue
		keep.append(p)
		var a := 1.0 - float(p.age) / 1.2
		var at: Vector2 = Vector2(size.x * 0.5, size.y * 0.3) if p.centred else _screen(p.at) - Vector2(0, 30 + 40 * float(p.age))
		_text(String(p.text), at, 24, Color(p.colour, a), true)
	_popups = keep


func _draw_end(size: Vector2) -> void:
	var v := _view
	var box := Rect2(size * 0.5 - Vector2(280, 190), Vector2(560, 380))
	_ui.draw_rect(box, Color(PANEL, 0.94))
	_ui.draw_rect(box, GOLD, false, 3.0)
	var centre := size.x * 0.5
	var won: bool = v.state == "won"
	var title := Text.t("HIDEOUT_GAME_WON") if won else Text.t("HIDEOUT_GAME_LOST_" + String(v.id).to_upper())
	_text(title, Vector2(centre, box.position.y + 24), 30, GREEN if won else RED, true)
	var sub := Text.t("HIDEOUT_GAME_WON_LINE") if won else Text.t("HIDEOUT_GAME_WHY_" + String(v.get("why", "time")).to_upper())
	_text(sub, Vector2(centre, box.position.y + 74), 14, CREAM, true)
	_text(Text.t("HIDEOUT_GAME_REACHED") % int(v.reached), Vector2(centre, box.position.y + 108), 20, CREAM, true)
	if v.get("new_record", false):
		_text(Text.t("HIDEOUT_GAME_NEW_RECORD"), Vector2(centre, box.position.y + 148 + 3 * sin(_t * 8.0)), 24, GOLD, true)
	if String(v.get("mvp_name", "")) != "":
		_text(Text.t("HIDEOUT_GAME_MVP") % String(v.mvp_name), Vector2(centre, box.position.y + 190), 14, CREAM, true)
	var labels := {"again": Text.t("HIDEOUT_GAME_AGAIN"), "go_on": Text.t("HIDEOUT_GAME_GO_ON"), "exit": Text.t("HIDEOUT_GAME_EXIT")}
	var m := menu()
	for i in m.size():
		var y := box.position.y + 240 + i * 42
		var on := i == _selected
		if on:
			_ui.draw_rect(Rect2(Vector2(box.position.x + 60, y - 4), Vector2(box.size.x - 120, 36)), Color(GOLD, 0.25))
		_text(("> " if on else "  ") + String(labels[m[i]]), Vector2(centre, y), 20, GOLD if on else CREAM, true)
