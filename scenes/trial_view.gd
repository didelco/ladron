class_name TrialView
extends Node3D
## The dojo's trials as seen (DojoTrial), all the same: the golden sock, the pins,
## the lit pedestal, hideouts or station in the world, each with a column of light,
## and on top, in 2D, the rings that empty, the arrows at the edge of the screen for
## what is off it, the lantern's cone, the sneeze bars and the lean, the head-up display
## (the name of the trial and its difficulty, how far it is, MEJOR, the clock and TAB:
## SALIR: the same place and style for every trial) and, at the end, the panel: the
## result (¡PRUEBA SUPERADA! / the trial's own failure), the mark, the best mark of
## that difficulty and size of band, ¡NUEVO RÉCORD! and the choices (SEGUIR, OTRA VEZ,
## SALIR) as the menus' buttons, one of them selected (TrialMenu).
##
## Nothing here decides anything: show_view(view) is given DojoTrial.view() every
## frame, react(events) the events of step(). Whoever runs it (HouseRun) gives the
## keys to `menu` (TrialMenu.input) and the mouse comes through the signals: `moved` when
## the mouse selects another choice, `picked(id)` when it clicks one.

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
	"in": "ok", "fall": "roll_bump", "ready": "nav"}

## The choices at the end (the panel's selection; HouseRun gives it the keys)
var menu := TrialMenu.new()
## The mouse selected another choice / clicked one (its id)
signal moved
signal picked(id: String)

var _camera: Camera3D
var _layer: CanvasLayer
var _ui: Control
var _view := {}
var _t := 0.0
var _nodes: Array[Node3D] = []
var _column: Array[MeshInstance3D] = []
var _popups: Array[Dictionary] = []
## the panel at the end (nodes, so its buttons are the menus' own) and its parts
var _panel: Control
var _buttons := {}
var _help: Label
var _panel_stamp := ""


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


## Show the trial as it is (DojoTrial.view()); an empty or idle one hides it all.
func show_view(view: Dictionary) -> void:
	_view = view
	var on: bool = not view.is_empty() and view.get("state", "idle") != "idle"
	visible = on
	if _layer != null:
		_layer.visible = on
	if not on:
		_update_objects([])
		_close_panel()
		return
	_update_objects(view.get("objects", []))
	var at_end: bool = String(view.state) in ["won", "lost"]
	var stamp := "%s:%d:%s:%s" % [view.id, int(view.tier), view.state, view.result.get("title", "")]
	if at_end and (_panel == null or stamp != _panel_stamp):
		_open_panel(view.result)
		_panel_stamp = stamp
	elif not at_end:
		_close_panel()
	if _ui != null:
		_ui.queue_redraw()


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

## The labels of the choices.
const CHOICES := {"next": "HIDEOUT_TRIAL_NEXT", "again": "HIDEOUT_GAME_AGAIN", "exit": "HIDEOUT_GAME_EXIT"}


## Whether the panel is up.
func panel_open() -> bool:
	return _panel != null


## The choices that are up, left to right.
func choices() -> Array[String]:
	return menu.options


## The panel of a result (DojoTrial.result()): opens with the choice that goes on selected.
func _open_panel(r: Dictionary) -> void:
	_close_panel()
	var won: bool = r.won
	menu.open(TrialMenu.options_for(won, r.has_next), TrialMenu.default_for(won, r.has_next))
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_panel)
	var box := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(PANEL, 0.94)
	st.set_border_width_all(3)
	st.border_color = GOLD
	st.set_corner_radius_all(14)
	st.set_content_margin_all(26)
	box.add_theme_stylebox_override("panel", st)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.custom_minimum_size = Vector2(640, 0)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	_row(col, String(r.title), 26, GREEN if won else RED)
	_row(col, String(r.line), 12, CREAM)
	_row(col, String(r.score_line), 18, CREAM)
	if String(r.best_line) != "":
		_row(col, String(r.best_line), 12, GOLD)
	if r.new_record:
		_row(col, Text.t("HIDEOUT_GAME_NEW_RECORD"), 20, GOLD)
	if String(r.mvp) != "":
		_row(col, String(r.mvp), 12, CREAM)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(gap)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_buttons.clear()
	for id in menu.options:
		var b := Hud.pill_button(Text.t(CHOICES[id]), 16)
		b.resized.connect(func() -> void: b.pivot_offset = b.size / 2)
		b.mouse_entered.connect(_hover.bind(id))
		b.pressed.connect(func() -> void: picked.emit(id))
		row.add_child(b)
		_buttons[id] = b
	_help = _row(col, "", 10, Color(CREAM, 0.75))
	refresh()


func _row(parent: Control, text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Hud.ARCADE)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", INK)
	l.add_theme_constant_override("outline_size", 4 if size >= 18 else 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _close_panel() -> void:
	if _panel != null:
		_panel.queue_free()
		_panel = null
	_buttons.clear()
	_help = null
	_panel_stamp = ""
	menu.close()


## The mouse is over a choice: it becomes the selected one.
func _hover(id: String) -> void:
	if menu.select(id):
		refresh()
		moved.emit()


## The panel as the selection says: the lit button, and the help line for the keys
## or the pad, whichever was last touched.
func refresh() -> void:
	for id in _buttons:
		Hud.pill_lit(_buttons[id], id == menu.current())
	if _help != null:
		_help.text = Text.t("HIDEOUT_TRIAL_HELP_PAD" if menu.pad else "HIDEOUT_TRIAL_HELP_KEYS")


# --- The world ---------------------------------------------------------------------------

func _process(dt: float) -> void:
	_t += dt
	for i in _nodes.size():
		if _nodes[i].visible:
			if _nodes[i].name.begins_with("sock"):
				_nodes[i].rotation.y = _t * 1.6
			_nodes[i].position.y = 0.08 * sin(_t * 4.0 + i)
	if _ui != null and _ui.is_visible_in_tree():
		_ui.queue_redraw()


func _update_objects(objects: Array) -> void:
	while _nodes.size() < objects.size():
		_add_slot()
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
		n.rotation.z = 0.0
		if kind == "pin" and o.get("down", false):
			n.rotation.z = deg_to_rad(90.0) * float(o.get("fell", 1.0))
		_column[i].visible = kind != "pin" or not o.get("down", false)
		_column[i].position = Vector3(w.x, 1.5, w.z)
		_column[i].material_override = _glow(Color(RED if o.get("gate", "") != "" else GOLD, 0.2))


## One more thing to show: its holder node and its column of light.
func _add_slot() -> void:
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
		"pedestal", "goal":
			_add_ring(n, GREEN)
		_:
			_add_ring(n, GOLD)


## A glowing ring on the floor (a pedestal, a hideout).
func _add_ring(n: Node3D, colour: Color) -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.55
	t.outer_radius = 0.7
	ring.mesh = t
	ring.material_override = _glow(Color(colour, 0.8))
	ring.position.y = 0.05
	n.add_child(ring)


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


## What the "¿LISTOS?" says under it: the trial's own line (DojoTrials.TABLE `hint`).
func _goal_hint() -> String:
	return Text.t(String(DojoTrials.info(String(_view.get("id", ""))).get("hint", "")))


func _draw_world_marks(size: Vector2) -> void:
	var v := _view
	var frame := Rect2(Vector2.ZERO, size).grow(-EDGE)
	for o in v.get("objects", []):
		var p := _screen(o.pos)
		if frame.has_point(p):
			_draw_ring(o, p)
		else:
			_draw_arrow(p, size)
	var lan: Dictionary = v.get("lantern", {})
	if not lan.is_empty():
		_draw_cone(lan)
	# The sneeze bars, over the heads of the ones that hold it in, and the
	# lean of the one on the pedestal.
	var bars: Dictionary = v.get("bars", {})
	if not bars.is_empty():
		_draw_bars(size, bars)
	if v.has("lean") and v.state == "playing":
		_draw_lean(size, float(v.lean), float(v.fall))


## The ring that empties round a thing on the screen, and a mark on one behind a door.
func _draw_ring(o: Dictionary, p: Vector2) -> void:
	var ring: float = o.get("ring", -1.0)
	if ring >= 0.0:
		var col := GOLD.lerp(RED, 1.0 - clampf(ring * 2.0, 0.0, 1.0))
		_ui.draw_arc(p, RING_R, -PI / 2, -PI / 2 + TAU, 40, Color(INK, 0.6), 8.0, true)
		if ring > 0.0:
			_ui.draw_arc(p, RING_R, -PI / 2, -PI / 2 + TAU * ring, 40, col, 6.0, true)
	if o.get("gate", "") != "":
		_text("|-|", p + Vector2(0, -RING_R - 30), 14, RED, true)


## Off the screen: an arrow at the edge, towards it.
func _draw_arrow(p: Vector2, size: Vector2) -> void:
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


## The lantern's cone on the floor.
func _draw_cone(lan: Dictionary) -> void:
	var from: Vector2 = lan.pos
	var pts := PackedVector2Array([_screen(from, 0.9)])
	for i in 9:
		var a: float = float(lan.angle) - float(lan.cone) + 2.0 * float(lan.cone) * i / 8.0
		pts.append(_screen(from + Vector2.from_angle(a) * float(lan.range), 0.0))
	_ui.draw_colored_polygon(pts, Color(GOLD, 0.16))


func _draw_bars(size: Vector2, bars: Dictionary) -> void:
	var i := 0
	for k in bars:
		var at := Vector2(size.x * 0.5 - 110 + i * 120, size.y - 90)
		_ui.draw_rect(Rect2(at, Vector2(100, 14)), Color(INK, 0.8))
		_ui.draw_rect(Rect2(at, Vector2(100 * clampf(float(bars[k]), 0.0, 1.0), 14)), GOLD.lerp(RED, clampf(float(bars[k]), 0.0, 1.0)))
		_text(Text.t("HIDEOUT_GAME_SNEEZE") if i == 0 else "", at + Vector2(0, -26), 12, CREAM)
		i += 1


## The holder's lean on a bar, the green stretch being the safe one.
func _draw_lean(size: Vector2, lean: float, fall: float) -> void:
	var at := Vector2(size.x * 0.5 - 150, size.y - 80)
	_ui.draw_rect(Rect2(at, Vector2(300, 16)), Color(INK, 0.8))
	_ui.draw_rect(Rect2(at + Vector2(150 - 300 * 0.6 / fall * 0.5, 0), Vector2(300 * 0.6 / fall, 16)), Color(GREEN, 0.4))
	var x := at.x + 150 + clampf(lean / fall, -1.0, 1.0) * 150
	_ui.draw_rect(Rect2(Vector2(x - 4, at.y - 6), Vector2(8, 28)), GOLD if absf(lean) < 0.6 else RED)


## The head-up display, the same for every trial: the name and difficulty, under it how
## far it is and the best mark, the clock, and how to leave.
func _draw_hud(size: Vector2) -> void:
	var v := _view
	var top := Vector2(size.x * 0.5, 14)
	_text(String(v.get("title", "")), top, 26, CREAM, true)
	_text("    ".join(PackedStringArray(v.get("hud", []))), top + Vector2(0, 34), 16, GOLD, true)
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
	if not (String(v.state) in ["won", "lost"]):
		_text(Text.t("HIDEOUT_GAME_LEAVE_KEY"), Vector2(size.x * 0.5, size.y - 34), 14, Color(CREAM, 0.85), true)


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
