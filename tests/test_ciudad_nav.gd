extends SceneTree
## Moverse por la ciudad de la historia (Tour): una sola regla, la dirección
## que se pulsa (flechas, WASD, cruceta, stick en cualquier ángulo) lleva a la
## parada (los museos abiertos y la casita) que está en esa dirección en la
## pantalla; el ratón, por encima y clic; LB/RB, sin efecto en la ciudad; y las
## flechas que dicen a dónde lleva cada dirección.
##   godot --headless --script tests/test_ciudad_nav.gd
var fails := 0
var sounds: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1


func frames(n := 4) -> void:
	for i in n:
		await process_frame


func key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func pad(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = b
	e.pressed = true
	return e


func stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e


## A town with the first `night` heists reached (a fresh save each time),
## the museum `pick` picked.
func city(night: int, pick := 0) -> Tour:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(night, 1)
	var t := Tour.new()
	root.add_child(t)
	t.stage.hurry = true
	t.open_city(1, pick)
	t.sound.connect(func(kind: String) -> void: sounds.append(kind))
	return t


func _init() -> void:
	Story.save = "user://test_ciudad_nav.cfg"
	_run.call_deferred()


func _run() -> void:
	# --- Choosing by direction, on made-up ground -------------------------------------
	var stops := {1: Vector2(10, 0), 2: Vector2(0, -10), 3: Vector2(8, -8), 4: Vector2(30, -1)}
	var o := Vector2.ZERO
	check(Tour.toward(o, Vector2(1, 0), stops) == 1, "a la derecha, el más cercano dentro del cono (no el lejano)")
	check(Tour.toward(o, Vector2(0, -1), stops) == 2, "arriba, el de arriba")
	check(Tour.toward(o, Vector2(1, -1), stops) == 3, "en diagonal, el más alineado con ella (el de 45º, no el más cercano)")
	check(Tour.toward(o, Vector2(-1, 0), stops) == -1 and Tour.toward(o, Vector2(0, 1), stops) == -1, "sin nadie por ese lado, nada")
	check(Tour.toward(o, Vector2.ZERO, stops) == -1, "sin dirección, nada")
	var edge := {7: Vector2(10, -40)}
	check(Tour.toward(o, Vector2(1, 0), edge) == -1, "a 76º de la derecha: pasado de MAX_OFF, nada")
	edge = {7: Vector2(10, -20)}
	check(Tour.toward(o, Vector2(1, 0), edge) == 7, "fuera del cono pero casi: si no hay otro, el más alineado")
	check(Tour.toward(o, Vector2(1, 0), {7: Vector2(10, -20), 8: Vector2(30, 5)}) == 8, "dentro del cono gana aunque haya otro más alineado más cerca fuera")
	check(Tour.toward(o, Vector2(1, 0), {7: Vector2(-10, 0)}) == -1, "nunca hacia atrás")
	check(Tour.toward(o, Vector2(1, -1), {7: Vector2(-10, -1)}) == -1, "una diagonal no salta a lo que queda al otro lado")

	# --- The real town, everything open -----------------------------------------------
	var t := city(Story.count(), 0)
	await frames()
	var H := CityStage.HIDEOUT
	# The route: the hideout, then the museums 1 to 5.
	# No route buttons in the town: LB and RB do nothing there.
	t._pick_museum(0)
	t.input(pad(JOY_BUTTON_LEFT_SHOULDER))
	t.input(pad(JOY_BUTTON_RIGHT_SHOULDER))
	check(t.stage.picked == 0, "LB y RB no mueven nada en la ciudad")
	check(not t.has_method("_step_route") and t.find_children("*", "Button", true, false).is_empty(), "sin botones de ruta en la ciudad")

	# The hideout lies to the right of the first museum, apart from it, and out of the river.
	var at_h: Vector2 = t.stage.stop_on_screen(H)
	var at_1: Vector2 = t.stage.stop_on_screen(0)
	check(at_h.x > at_1.x + 20.0, "la casita queda a la derecha del primer museo en la pantalla (%.0f unidades)" % (at_h.x - at_1.x))
	check(at_h.distance_to(at_1) > 30.0, "... y bien lejos de él (%.0f unidades)" % at_h.distance_to(at_1))

	# One key: the stop that way. The town's own geometry.
	var expect := [
		[0, "right", 4], [0, "up", 1], [0, "left", 2], [0, "down", -1],
		[4, "right", H], [H, "left", 4], [4, "up", 3], [3, "left", 1], [1, "down", 0],
		[1, "left", 2], [2, "right", 1],
	]
	for e in expect:
		t._pick_museum(e[0])
		t.act(e[1])
		var want: int = e[0] if e[2] == -1 else e[2]
		check(t.stage.picked == want, "desde %s, %s: %s (salió %s)" % [_name(e[0]), e[1], _name(want), _name(t.stage.picked)])
	# Every stop can be reached from another one by some arrow.
	var reach := {}
	for from in [H, 0, 1, 2, 3, 4]:
		for dir in ["left", "right", "up", "down"]:
			t._pick_museum(from)
			t.act(dir)
			reach[t.stage.picked] = true
	check(reach.size() == 6, "con las flechas se llega a todas las paradas (%d de 6)" % reach.size())

	# The stick points any angle: the stop most in line with it.
	for e in [[0, Vector2(1, -1), 3], [0, Vector2(-1, -1), 2], [0, Vector2(1, 1), H], [0, Vector2(0.9, -0.3), 4], [0, Vector2(0.05, -1), 1]]:
		t._pick_museum(e[0])
		t.step(e[1])
		check(t.stage.picked == e[2], "el stick hacia %s desde %s: %s (salió %s)" % [e[1], _name(e[0]), _name(e[2]), _name(t.stage.picked)])
	t._pick_museum(0)
	t.step(Vector2.ZERO)
	check(t.stage.picked == 0, "el stick quieto no mueve")
	t._pick_museum(3)
	t.step(Vector2(1, -1))
	check(t.stage.picked == 3, "hacia donde no hay nadie: se queda")

	# --- Each device moves once per push, straight away ---------------------------------
	t._pick_museum(0)
	sounds.clear()
	t.input(key(KEY_UP))
	check(t.stage.picked == 1 and sounds == ["nav"], "una flecha mueve al momento, una vez")
	t.input(key(KEY_S))
	check(t.stage.picked == 0, "S baja: la misma regla que las flechas")
	t._pick_museum(0)
	t.input(key(KEY_D))
	check(t.stage.picked == 4, "D va a la derecha (el museo 5, a la derecha en la pantalla)")
	t._pick_museum(0)
	t.input(pad(JOY_BUTTON_DPAD_UP))
	check(t.stage.picked == 1, "la cruceta arriba: lo mismo que la flecha arriba")
	# The stick: both axes of a diagonal come as two events and make one move.
	t._pick_museum(0)
	sounds.clear()
	t.input(stick(JOY_AXIS_LEFT_X, 0.9))
	t.input(stick(JOY_AXIS_LEFT_Y, -0.9))
	await frames(2)
	check(t.stage.picked == 3 and sounds == ["nav"], "el stick en diagonal (arriba y derecha): un solo salto al de esa diagonal (%s, %s)" % [_name(t.stage.picked), sounds])
	await frames(2)
	check(sounds.size() == 1, "mantenido, no repite")
	t.input(stick(JOY_AXIS_LEFT_X, 0.0))
	t.input(stick(JOY_AXIS_LEFT_Y, 0.0))
	await frames(2)
	t._pick_museum(0)
	t.input(stick(JOY_AXIS_LEFT_X, 0.9))
	await frames(2)
	check(t.stage.picked == 4, "el stick a la derecha: a la derecha")
	t.input(stick(JOY_AXIS_LEFT_X, 0.0))
	await frames(2)
	t.input(stick(JOY_AXIS_LEFT_Y, -0.9))
	await frames(2)
	check(t.stage.picked == 3, "... soltado y pulsado arriba, otra vez (desde el museo 5, arriba está el 4)")
	t.input(stick(JOY_AXIS_LEFT_Y, 0.0))
	await frames(2)
	# Accept takes what was pushed first.
	t._pick_museum(0)
	sounds.clear()
	t.input(key(KEY_UP))
	t.input(key(KEY_E))
	await frames(2)
	check(t.state in ["zoom", "museum"] and t.stage.picked == 1, "aceptar tras una pulsación: primero se mueve y luego entra en el elegido (%s)" % t.state)
	t.queue_free()
	await frames()

	# --- Closed museums are not chosen; the hideout always is ------------------------------
	t = city(1, 0)
	await frames()
	t.act("up")
	check(t.stage.picked == 0, "el segundo, cerrado, no se elige (arriba)")
	t.step(Vector2(1, -1))
	check(t.stage.picked == H, "... ni en diagonal (arriba y derecha: el cuarto, cerrado): la casita, lo abierto más cerca de esa diagonal")
	t.act("left")
	check(t.stage.picked == 0, "a la izquierda de la casita, el primer museo")
	t.act("right")
	check(t.stage.picked == H, "a la derecha del primero, la casita aunque el quinto esté cerrado")
	t.queue_free()
	await frames()

	# Two museums open: the fifth shut, the hideout reached from the first.
	t = city(6, 1)
	await frames()
	t.act("left")
	check(t.stage.picked == 1, "a la izquierda del segundo está el tercero, cerrado: se queda")
	t.act("down")
	check(t.stage.picked == 0, "abajo, el primero")
	t.act("right")
	check(t.stage.picked == H, "a la derecha del primero, la casita")
	t.queue_free()
	await frames()

	# --- The arrows over the town and the mouse ------------------------------------------
	root.size = Vector2i(1280, 720)
	t = city(Story.count(), 0)
	await frames(2)
	check(t._arrows.visible and t._arrows.mouse_filter == Control.MOUSE_FILTER_IGNORE, "las flechas se ven en la ciudad y no tapan el ratón")
	# Every arrow points where its push leads, on the screen.
	var from: Vector2 = t.stage.stop_point(0)
	var here: Vector2 = t.stage.stop_on_screen(0)
	stops = t._stops_open()
	for d in Tour.DIR_VECTORS:
		var to := Tour.toward(here, Tour.DIR_VECTORS[d], stops)
		if to < 0:
			continue
		var dir: Vector2 = (t.stage.stop_point(to) - from).normalized()
		var want: Vector2 = Tour.DIR_VECTORS[d]
		check(dir.dot(want) > 0.2, "la flecha de %s apunta hacia donde se ve el destino (%s)" % [d, _name(to)])
	# The mouse: over a stop picks it (the hideout too), a click on it goes in.
	var over := InputEventMouseMotion.new()
	over.position = t.stage.stop_point(H)
	t._on_mouse(over)
	check(t.stage.picked == H, "el ratón sobre la casita la elige")
	over.position = t.stage.stop_point(2)
	t._on_mouse(over)
	check(t.stage.picked == 2, "el ratón sobre un museo lo elige")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = t.stage.stop_point(1)
	t._on_mouse(click)
	check(t.stage.picked == 1, "el clic sobre otro museo lo elige")
	t.act("accept")
	await frames(2)
	check(t.state in ["zoom", "museum"], "aceptar entra en el elegido")
	check(not t._arrows.visible, "dentro de un museo, sin flechas")
	t.queue_free()
	await frames()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("FALLOS: %d" % fails if fails else "OK: moverse por la ciudad")
	quit(1 if fails else 0)


func _name(m: int) -> String:
	return "la casita" if m == CityStage.HIDEOUT else "el museo %d" % (m + 1)
