class_name EditorPadNavigation
## Navegación del mando: catálogo, cursor, trazos y botones del plano.
## Reutiliza las acciones del editor; no mantiene una segunda copia del mapa.
extends RefCounted

var host: MapEditor

func _init(editor: MapEditor) -> void:
	host = editor


# --- The pad ---------------------------------------------------------------------

## Whether the pad or the mouse and keyboard were used last: the help line
## shows the buttons of whichever it is. The buttons that work anywhere in
## the editor (not in a panel) are here too.
func handle_input(event: InputEvent) -> void:
	if not host.visible or host.map == null:
		return
	var pad := event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > host.PAD_DEAD)
	if pad != host._pad and (pad or event is InputEventMouseButton or event is InputEventKey):
		host._pad = pad
		host._refresh()
	if host.panel != "":
		return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
		var i := 0 if event.axis == JOY_AXIS_TRIGGER_LEFT else 1
		var down: bool = event.axis_value > host.PAD_DEAD
		if down and not host._pad_triggers[i]:
			step_kind(-1 if i == 0 else 1)
			host.ui_sound.emit("nav")
		host._pad_triggers[i] = down
		host.get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_LEFT_SHOULDER: step_item(-1)
			JOY_BUTTON_RIGHT_SHOULDER: step_item(1)
			JOY_BUTTON_START:
				# Over to the buttons, and back.
				if host._plan.has_focus():
					host._play_button.grab_focus()
				else:
					host._plan.grab_focus()
			JOY_BUTTON_BACK: host._toggle_3d()
			_: return
		host.ui_sound.emit("nav")
		host.get_viewport().set_input_as_handled()


## A, X, B and Y on the plan (or the museum in 3D).
func on_plan(event: InputEvent) -> void:
	if not event is InputEventJoypadButton:
		return
	var b: int = event.button_index
	if not event.pressed:
		# A or X let go: the stroke is over, and the 3D builds what it painted.
		if (b == JOY_BUTTON_A and host._pad_stroke == 1) or (b == JOY_BUTTON_X and host._pad_stroke == 2):
			host._pad_stroke = 0
			if host.in_3d and host._pad_marked:
				host._rebuild()
			host._pad_marked = false
		return
	if host.hover == MapFile.NONE:
		host.hover = host.map.spawn
	match b:
		JOY_BUTTON_A:
			if host.tool == "room" and host.room_from != MapFile.NONE:
				host._mark_room(host.hover)
			else:
				host._press(host.hover, false)
			host._pad_stroke = 1
			after_change()
		JOY_BUTTON_X:
			host._press(host.hover, true)
			host._pad_stroke = 2
			after_change()
		JOY_BUTTON_B:
			host.ui_sound.emit("back")
			host._undo()
		JOY_BUTTON_Y:
			if host.tool == "stamp":
				host._turn()
			else:
				pick_up(host.hover)
			host.ui_sound.emit("nav")


## A change made on the tile under the cursor: in 3D, a stroke's tiles are
## marked and built when it ends; anything else is built at once.
func after_change() -> void:
	if not host.in_3d:
		return
	if host._paints() or host._pad_stroke == 2:
		host._mark(host.hover)
		host._pad_marked = true
	elif host.tool != "room":
		host._rebuild()


## The cursor on the pad: the cross or the left stick, a step at once and
## then running on while held. In 3D, up is away from the camera.
func move_cursor(dt: float) -> void:
	var v := Vector2.ZERO
	for pad in Input.get_connected_joypads():
		v += Vector2(Input.get_joy_axis(pad, JOY_AXIS_LEFT_X), Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y))
		v.x += float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT))
		v.y += float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)) - float(Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP))
	if v.length() < host.PAD_DEAD:
		host._pad_dir = Vector2i.ZERO
		return
	if host.in_3d:
		# The camera looks at the middle from (cos, sin) of its yaw.
		var c := cos(host._yaw)
		var s := sin(host._yaw)
		v = Vector2(s * v.x + c * v.y, -c * v.x + s * v.y)
	var d := Vector2i(signi(roundi(v.x)) if absf(v.x) >= absf(v.y) else 0, signi(roundi(v.y)) if absf(v.y) > absf(v.x) else 0)
	if d != host._pad_dir:
		host._pad_dir = d
		host._pad_wait = host.PAD_DELAY
	else:
		host._pad_wait -= dt
		if host._pad_wait > 0.0:
			return
		host._pad_wait = host.PAD_REPEAT
	var from := host.hover if host.hover != MapFile.NONE else host.map.spawn
	var next := from + d
	if not host.map.inside(next):
		return
	host.hover = next
	# A or X held: the stroke goes on over the tile.
	if host._pad_stroke != 0 and (host._paints() or host._pad_stroke == 2):
		host._use(host.hover, host._pad_stroke == 2)
		after_change()
		host._refresh()
	if host.in_3d:
		host._place_hover()
	host._plan.queue_redraw()


## The thing before or after in the catalogue (round from the end to the
## start), in hand at once and scrolled into sight.
func step_item(step: int) -> void:
	var items: Array[Button] = []
	var at := -1
	for c in host._catalogue.get_children():
		if c is Button and (c in host._tool_buttons.values() or c in host._template_buttons):
			if (host._tool_buttons.get(host.tool) == c) or (host.tool == "stamp" and host.template >= 0 and host.template < host._template_buttons.size() and host._template_buttons[host.template] == c):
				at = items.size()
			items.append(c)
	if items.is_empty():
		return
	var b := items[posmod(at + step, items.size()) if at >= 0 else (0 if step > 0 else items.size() - 1)]
	b.pressed.emit()
	host._cat_scroll.ensure_control_visible(b)
	host._say(b.tooltip_text, Hud.CREAM)


## The kind of tool before or after (building, objects), with its first
## thing in hand unless what is in hand is already one of its own.
func step_kind(step: int) -> void:
	var i := host.PAD_KINDS.find(host.kind)
	host._pick_kind(host.PAD_KINDS[posmod(i + step, host.PAD_KINDS.size())])
	var own := host.tool in host._tool_buttons or (host.tool == "stamp" and host.kind == "construir")
	if not own:
		step_item(1)
	else:
		host._say(Text.t("EDITOR_KIND_" + host.kind.to_upper()), Hud.CREAM)


## Take up whatever stands on this tile: the same tool in hand, its kind's
## catalogue open (and every theme shown, so it is there to see).
func pick_up(t: Vector2i) -> void:
	var what := "wall"
	var k := "construir"
	var prop: Array = host.map.props.filter(func(p): return p.at == t)
	var big := host.map.big_at(t)
	if host.map.guards.any(func(g): return g.at == t):
		what = "guard"
	elif t == host.map.spawn:
		what = "spawn"
	elif t == host.map.piece:
		what = "piece"
	elif t == host.map.exit:
		what = "exit"
	elif host.map.doors.has(t):
		what = "door"
	elif not prop.is_empty():
		what = "prop:" + String(prop[0].kind)
	elif not big.is_empty():
		what = "big:" + String(big.kind)
	elif host.map.exhibits.has(t):
		what = "exhibit:" + String(host.map.exhibits[t])
	elif host.map.at(t) == Tiles.COVER:
		what = "case"
	if what != "wall" and not (what in host.MAIN_TOOLS):
		k = "objects"
		host.filter = ""
		host.filter_type = ""
	else:
		# wall or a MAIN_TOOLS character: its button lives in construir's
		# own row, not the salas step-in.
		host.building_page = ""
	host.kind = k
	host._fill_catalogue()
	host._pick_tool(what)
	if host._tool_buttons.has(what):
		host._cat_scroll.ensure_control_visible.call_deferred(host._tool_buttons[what])
		host._say(host._tool_buttons[what].tooltip_text, Hud.CREAM)


