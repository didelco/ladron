extends SceneTree
## Moverse por la ciudad de la historia (Tour): elegir la parada (los museos
## abiertos y la casita) por la dirección que se pulsa en la pantalla, con
## una tecla o con dos a la vez (diagonal), agrupando pulsaciones casi
## simultáneas; siguiente y anterior por la ruta; y los dos botones de los
## lados, que hacen lo mismo con el ratón.
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
	check(t._route_order() == [H, 0, 1, 2, 3, 4], "la ruta: la casita y los cinco museos")
	t._pick_museum(H)
	var chain: Array[int] = [H]
	for k in 7:
		t.act("next")
		if t.stage.picked != chain[-1]:
			chain.append(t.stage.picked)
	check(chain == [H, 0, 1, 2, 3, 4], "siguiente sigue la ruta, de la casita al último museo: " + str(chain))
	t.act("next")
	check(t.stage.picked == 4, "... y al final se queda")
	chain = [4]
	for k in 7:
		t.act("prev")
		if t.stage.picked != chain[-1]:
			chain.append(t.stage.picked)
	check(chain == [4, 3, 2, 1, 0, H], "anterior la sigue al revés")
	t.act("prev")
	check(t.stage.picked == H, "... y en la casita se queda")
	# The pad's shoulders are the same.
	t.act("next")
	check(t.stage.picked == 0, "LB y RB: la ruta (siguiente)")

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

	# Two keys at once: the diagonal.
	t._pick_museum(0)
	t.step_dirs(["up", "right"])
	check(t.stage.picked == 3, "arriba y derecha desde el primer museo: el que está arriba a la derecha (el cuarto)")
	t._pick_museum(0)
	t.step_dirs(["right", "up"])
	check(t.stage.picked == 3, "... da igual el orden")
	t._pick_museum(0)
	t.step_dirs(["down", "right"])
	check(t.stage.picked == H, "abajo y derecha desde el primer museo: la casita")
	t._pick_museum(0)
	t.step_dirs(["left", "right"])
	check(t.stage.picked == 0, "izquierda y derecha a la vez se anulan: nada")
	t._pick_museum(0)
	t.step_dirs(["up", "down", "right"])
	check(t.stage.picked == 4, "arriba, abajo y derecha: arriba y abajo se anulan, queda la derecha")
	t._pick_museum(3)
	t.step_dirs(["up", "right"])
	check(t.stage.picked == 3, "diagonal sin nadie por ese lado: se queda")

	# --- Pushes close together are one move -------------------------------------------
	t._pick_museum(0)
	sounds.clear()
	t.dir_window = 0.1
	t.input(key(KEY_UP))
	check(t.stage.picked == 0, "una tecla espera a la ventana antes de mover")
	t.input(key(KEY_RIGHT))
	await create_timer(0.25).timeout
	check(t.stage.picked == 3 and sounds == ["nav"], "arriba y derecha con unos milisegundos de diferencia: un solo salto en diagonal (%s, %s)" % [_name(t.stage.picked), sounds])
	t._pick_museum(0)
	sounds.clear()
	t.input(key(KEY_D))
	await create_timer(0.02).timeout
	t.input(key(KEY_W))
	await create_timer(0.25).timeout
	check(t.stage.picked == 3 and sounds.size() == 1, "... también con W y D, y sea cual sea la primera")
	t._pick_museum(0)
	sounds.clear()
	t.input(key(KEY_UP))
	await create_timer(0.25).timeout
	check(t.stage.picked == 1 and sounds.size() == 1, "una sola tecla, pasada la ventana: se mueve, una vez")
	t.input(key(KEY_DOWN))
	await create_timer(0.02).timeout
	t.input(key(KEY_LEFT))
	await create_timer(0.25).timeout
	check(t.stage.picked == 0 and sounds.size() == 2, "abajo y luego izquierda casi a la vez, desde el segundo: la diagonal de abajo y a la izquierda; el primero (el más alineado)")
	t._pick_museum(0)
	sounds.clear()
	t.input(key(KEY_UP))
	await create_timer(0.3).timeout
	t.input(key(KEY_RIGHT))
	await create_timer(0.25).timeout
	check(sounds.size() == 2, "dos pulsaciones separadas por más que la ventana son dos movimientos, no una diagonal")
	# The pad's cross and the stick.
	t._pick_museum(0)
	sounds.clear()
	t.input(pad(JOY_BUTTON_DPAD_UP))
	t.input(pad(JOY_BUTTON_DPAD_RIGHT))
	await create_timer(0.25).timeout
	check(t.stage.picked == 3 and sounds.size() == 1, "la cruceta en diagonal (arriba y derecha)")
	t._pick_museum(0)
	sounds.clear()
	t.input(stick(JOY_AXIS_LEFT_X, 0.9))
	t.input(stick(JOY_AXIS_LEFT_Y, -0.9))
	await create_timer(0.25).timeout
	check(t.stage.picked == 3 and sounds.size() == 1, "el stick en diagonal")
	t.input(stick(JOY_AXIS_LEFT_X, 0.0))
	t.input(stick(JOY_AXIS_LEFT_Y, 0.0))
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
	check(t._route_order() == [H, 0], "solo el primer museo abierto: la ruta es la casita y él")
	t.act("up")
	check(t.stage.picked == 0, "el segundo, cerrado, no se elige (arriba)")
	t.step_dirs(["up", "right"])
	check(t.stage.picked == H, "... ni en diagonal (arriba y derecha: el cuarto, cerrado): la casita, lo abierto más cerca de esa diagonal")
	t.act("left")
	check(t.stage.picked == 0, "a la izquierda de la casita, el primer museo")
	t.act("right")
	check(t.stage.picked == H, "a la derecha del primero, la casita aunque el quinto esté cerrado")
	t.act("next")
	check(t.stage.picked == 0, "siguiente desde la casita, el primer museo")
	t.act("next")
	check(t.stage.picked == 0, "siguiente desde el último abierto se queda")
	t.act("prev")
	check(t.stage.picked == H, "anterior, la casita")
	t.queue_free()
	await frames()

	# Two museums open: the fifth shut, the hideout reached from the first.
	t = city(6, 1)
	await frames()
	check(t._route_order() == [H, 0, 1], "con dos museos abiertos, la ruta es la casita y los dos")
	t.act("left")
	check(t.stage.picked == 1, "a la izquierda del segundo está el tercero, cerrado: se queda")
	t.act("down")
	check(t.stage.picked == 0, "abajo, el primero")
	t.act("right")
	check(t.stage.picked == H, "a la derecha del primero, la casita")
	t.queue_free()
	await frames()

	# --- The buttons at the sides ------------------------------------------------------
	for shape in [["4:3", Vector2i(1024, 768)], ["16:9", Vector2i(1600, 900)], ["32:9", Vector2i(1920, 540)]]:
		root.size = shape[1]
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		t = city(Story.count(), 2)
		await frames()
		var view: Vector2 = t._root.get_viewport_rect().size
		var prev := t._prev_btn.get_global_rect()
		var next := t._next_btn.get_global_rect()
		var whole := Rect2(Vector2.ZERO, view)
		check(t._prev_btn.visible and t._next_btn.visible, "%s: los dos botones, en la ciudad" % shape[0])
		check(whole.encloses(prev) and whole.encloses(next), "%s: dentro de la pantalla (%s, %s en %s)" % [shape[0], prev, next, view])
		check(prev.position.x < view.x * 0.25 and next.end.x > view.x * 0.75, "%s: uno a cada lado" % shape[0])
		check(absf(prev.get_center().y - view.y * 0.5) < 2.0 and absf(next.get_center().y - view.y * 0.5) < 2.0, "%s: a media altura" % shape[0])
		check(prev.size.x >= 180 and prev.size.y >= 64 and next.size.x >= 180 and next.size.y >= 64, "%s: grandes (%s)" % [shape[0], prev.size])
		var where: Vector2 = t.stage.museum_on_screen(t.stage.picked)
		check(not prev.grow(20).has_point(where) and not next.grow(20).has_point(where), "%s: no tapan el museo elegido" % shape[0])
		check(t._prev_btn.focus_mode == Control.FOCUS_NONE and t._next_btn.focus_mode == Control.FOCUS_NONE, "%s: no toman el foco" % shape[0])
		t.queue_free()
		await frames()

	root.size = Vector2i(1280, 720)
	t = city(Story.count(), 2)
	await frames(2)
	sounds.clear()
	t._next_btn.pressed.emit()
	check(t.stage.picked == 3 and sounds == ["nav"], "el botón SIGUIENTE lleva al museo siguiente de la ruta, con su sonido")
	t._prev_btn.pressed.emit()
	t._prev_btn.pressed.emit()
	check(t.stage.picked == 1, "el botón ANTERIOR, al anterior")
	# A real click through the interface.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = t._next_btn.get_global_rect().get_center()
	root.push_input(press)
	var release := press.duplicate()
	release.pressed = false
	root.push_input(release)
	await frames(2)
	check(t.stage.picked == 2, "un clic del ratón sobre SIGUIENTE cambia la parada elegida")
	t._pick_museum(4)
	await frames(2)
	check(t._next_btn.disabled and not t._prev_btn.disabled and t._next_btn.modulate.a < 0.6, "en el último museo, SIGUIENTE se atenúa")
	t._pick_museum(H)
	await frames(2)
	check(t._prev_btn.disabled and not t._next_btn.disabled, "en la casita, ANTERIOR se atenúa")
	sounds.clear()
	t._prev_btn.pressed.emit()
	check(t.stage.picked == H, "... y pulsarlo no hace nada")
	# The click on a museum still works.
	t._pick_museum(0)
	await frames(2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = t.stage.on_screen(t.stage._museums[1].global_position + Vector3(0, 1.0, 0))
	t._on_mouse(click)
	check(t.stage.picked == 1, "el clic directo sobre un museo sigue eligiéndolo")
	# Out of the town they are gone.
	t.act("accept")
	await frames(2)
	check(t.state in ["zoom", "museum"] and not t._prev_btn.visible and not t._next_btn.visible, "dentro de un museo, sin botones")
	t.queue_free()
	await frames()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("FALLOS: %d" % fails if fails else "OK: moverse por la ciudad")
	quit(1 if fails else 0)


func _name(m: int) -> String:
	return "la casita" if m == CityStage.HIDEOUT else "el museo %d" % (m + 1)
