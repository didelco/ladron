extends SceneTree
## Moverse por la ciudad de la historia (Tour): delante del mapa, una barra con
## la casita y los cinco museos en el orden de la historia. Izquierda y derecha
## (flechas, A y D, cruceta, stick, LB y RB) van por la barra, sea cual sea la
## posición del sitio en el mapa; los cerrados se saltan; al abrir, la selección
## cae sola en el siguiente pendiente; aceptar entra; el ratón, por encima de
## una tarjeta la elige y el clic entra.
##   godot --headless --script tests/test_ciudad_nav.gd
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var sounds: Array[String] = []


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


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


func motion(at: Vector2, rel := Vector2(20, 0)) -> InputEventMouseMotion:
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = rel
	return e


func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.position = at
	e.global_position = at
	e.button_index = button
	e.pressed = true
	return e


## A town with the first `night` heists reached (a fresh save each time), as
## the story opens it: on the stop it asks for next unless `pick` says other.
func city(night: int, pick := -2) -> Tour:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(night, 1)
	var t := Tour.new()
	root.add_child(t)
	t.stage.hurry = true
	t.open_city(1, Tour.next_stop(1) if pick == -2 else pick)
	t.sound.connect(func(kind: String) -> void: sounds.append(kind))
	return t


func _init() -> void:
	# Its own file: other worktrees' tests share user:// and would trample it.
	Story.save = "user://test_ciudad_nav_%d.cfg" % OS.get_process_id()
	_run.call_deferred()


func _run() -> void:
	var H := CityStage.HIDEOUT
	# --- Where the town opens: on what is next -----------------------------------------
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	check(Tour.next_stop(1) == 0, "sin nada hecho, el primer museo")
	Story.unlock(6, 1)
	check(Tour.next_stop(1) == 1, "con seis robos alcanzados, el museo de su sala (el segundo)")
	Story.unlock(Story.count(), 1)
	check(Tour.next_stop(1) == 4, "en el último robo sin hacer, el último museo")
	Story.keep_stars(Story.count(), 1, Story.STAR_TAKEN)
	check(Tour.next_stop(1) == H, "con todo hecho, la casita")
	check(Tour.bar_items() == [H, 0, 1, 2, 3, 4], "la barra: la casita y los museos 1 a 5")

	var t := city(6)
	await frames()
	check(t.stage.picked == 1 and t._next == 1, "al abrir la ciudad cae sola en el siguiente pendiente (%d)" % t.stage.picked)
	t.queue_free()
	await frames()
	t = city(Story.count())
	await frames()
	check(t.stage.picked == 4, "con la historia entera por hacer el último, y a la derecha no hay nada")
	Story.keep_stars(Story.count(), 1, Story.STAR_TAKEN)
	t.queue_free()
	await frames()
	t = city(Story.count())
	Story.keep_stars(Story.count(), 1, Story.STAR_TAKEN)
	t.open_city(1, Tour.next_stop(1))
	await frames()
	check(t.stage.picked == H and t._next == H, "con todo hecho, cae en la casita")
	t.queue_free()
	await frames()

	# --- Along the bar: the same on every device, whatever the map looks like ---------------
	t = city(Story.count(), H)
	await frames()
	var order: Array[int] = [H]
	for k in 8:
		t.act("right")
		if t.stage.picked != order[-1]:
			order.append(t.stage.picked)
	check(order == [H, 0, 1, 2, 3, 4], "derecha va de la casita al último museo en orden: " + str(order))
	t.act("right")
	check(t.stage.picked == 4, "... y al final se queda")
	order = [4]
	for k in 8:
		t.act("left")
		if t.stage.picked != order[-1]:
			order.append(t.stage.picked)
	check(order == [4, 3, 2, 1, 0, H], "izquierda la recorre al revés")
	t.act("left")
	check(t.stage.picked == H, "... y en la casita se queda")
	# Every device says the same.
	var devices := {
		"flecha": [key(KEY_RIGHT), key(KEY_LEFT)], "D y A": [key(KEY_D), key(KEY_A)],
		"cruceta": [pad(JOY_BUTTON_DPAD_RIGHT), pad(JOY_BUTTON_DPAD_LEFT)],
		"LB y RB": [pad(JOY_BUTTON_RIGHT_SHOULDER), pad(JOY_BUTTON_LEFT_SHOULDER)],
		"stick": [stick(JOY_AXIS_LEFT_X, 0.9), stick(JOY_AXIS_LEFT_X, -0.9)],
	}
	for d in devices:
		t._pick_museum(1)
		sounds.clear()
		t.input(devices[d][0])
		t.input(stick(JOY_AXIS_LEFT_X, 0.0))
		check(t.stage.picked == 2 and sounds == ["nav"], "%s: derecha va al siguiente de la barra, con su sonido" % d)
		t.input(devices[d][1])
		t.input(stick(JOY_AXIS_LEFT_X, 0.0))
		check(t.stage.picked == 1, "%s: izquierda, al anterior" % d)
	# The map behind does not matter: 3 lies far up and left of 2, and right still goes to it.
	t._pick_museum(1)
	t.act("right")
	check(t.stage.picked == 2, "derecha del museo 2 es el 3, esté donde esté en el mapa")
	t._pick_museum(3)
	t.act("right")
	check(t.stage.picked == 4, "... y del 4 el 5")
	t._pick_museum(1)
	t.act("up")
	t.act("down")
	check(t.stage.picked == 1, "arriba y abajo no hacen nada en la ciudad")
	t.queue_free()
	await frames()

	# --- The order, for every progress and every size of gang --------------------------------
	var bad := 0
	var cases := 0
	for gang in [1, 2, 3, 4]:
		for reached in [1, 4, 5, 6, 9, 10, 11, 15, 16, 20, 21, Story.count()]:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
			Story.unlock(reached, gang)
			t = Tour.new()
			root.add_child(t)
			t.stage.hurry = true
			t.open_city(gang, Tour.next_stop(gang))
			await frames(2)
			var open_stops: Array[int] = []
			for m in [H, 0, 1, 2, 3, 4]:
				if m == H or m <= Story.museum_of(reached):
					open_stops.append(m)
			cases += 1
			var why := ""
			var ok := t.stage.picked == Tour.next_stop(gang) and Tour.next_stop(gang) == Story.museum_of(reached)
			if not ok:
				why += " inicial(%d, %d)" % [t.stage.picked, Tour.next_stop(gang)]
			for m in [H, 0, 1, 2, 3, 4]:
				if t.stage.is_open(m) != (m in open_stops):
					ok = false
					why += " abierto(%d)" % m
			for start in open_stops:
				t._pick_museum(start)
				var seen: Array[int] = [start]
				for k in 8:
					t.act("right")
					if t.stage.picked != seen[-1]:
						seen.append(t.stage.picked)
				if seen != open_stops.slice(open_stops.find(start)):
					ok = false
					why += " derecha desde %d: %s" % [start, seen]
				t._pick_museum(start)
				seen = [start]
				for k in 8:
					t.act("left")
					if t.stage.picked != seen[-1]:
						seen.append(t.stage.picked)
				var back := open_stops.slice(0, open_stops.find(start) + 1)
				back.reverse()
				if seen != back:
					ok = false
					why += " izquierda desde %d: %s" % [start, seen]
			# The cards are drawn in the same order, left to right.
			var xs: Array[float] = []
			for m in open_stops:
				xs.append((t._cards[m] as Rect2).position.x)
			for k in range(1, xs.size()):
				if not xs[k] > xs[k - 1]:
					ok = false
					why += " tarjetas %s" % [xs]
			# The heist numbers agree with the museum: museum n is index n-1 and holds nights 5n-4 to 5n.
			if not ok:
				bad += 1
				print("  mal: banda %d, robo %d:%s" % [gang, reached, why])
			t.queue_free()
			await process_frame
	check(bad == 0, "el orden casita,1,2,3,4,5 (saltando cerrados) al derecho y al revés, desde cada sitio, en %d progresos de 1 a 4 ladrones" % cases)
	for n in range(1, Story.count() + 1):
		if Story.museum_of(n) != (n - 1) / 5:
			bad += 1
	check(bad == 0, "el museo de cada robo es el (n-1)/5, sin desfase")

	# --- Shut museums are seen, not chosen ---------------------------------------------------
	t = city(1)
	await frames()
	check(t.stage.picked == 0, "solo el primero abierto: cae en él")
	t.act("right")
	check(t.stage.picked == 0, "el segundo, cerrado, no se elige")
	t.act("left")
	check(t.stage.picked == H, "a la izquierda del primero, la casita")
	t.act("right")
	check(t.stage.picked == 0, "y de vuelta")
	t.queue_free()
	await frames()
	t = city(11)
	await frames()
	check(t.stage.picked == 2, "con tres abiertos cae en el tercero")
	t.act("right")
	check(t.stage.picked == 2, "el cuarto, cerrado, se salta y no hay más: se queda")
	t.queue_free()
	await frames()

	# --- Accept goes in the one picked; back leaves ------------------------------------------
	t = city(6)
	await frames()
	t.input(key(KEY_E))
	await frames(2)
	check(t.state in ["zoom", "museum"], "aceptar entra en el siguiente pendiente, sin navegar (%s)" % t.state)
	check(not t._bar.visible, "dentro de un museo, sin barra")
	t.queue_free()
	await frames()
	t = city(6)
	await frames()
	t.input(pad(JOY_BUTTON_A))
	check(t.state in ["zoom", "museum"], "A del mando, igual")
	t.queue_free()
	await frames()
	t = city(6, H)
	await frames()
	var practised := [false]
	t.practice.connect(func() -> void: practised[0] = true)
	t.input(key(KEY_PERIOD))
	check(practised[0], "aceptar en la casita entra a la casita")
	t.queue_free()
	await frames()
	t = city(6)
	await frames()
	var left := [false]
	t.left.connect(func() -> void: left[0] = true)
	t.input(key(KEY_SPACE))
	check(left[0], "atrás sale de la ciudad")
	t.queue_free()
	await frames()

	# --- The bar on every screen ---------------------------------------------------------------
	for shape in [["16:9", Vector2i(1280, 720)], ["16:9 pequeña", Vector2i(960, 540)], ["4:3", Vector2i(1024, 768)], ["32:9", Vector2i(1920, 540)]]:
		root.size = shape[1]
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		t = city(Story.count(), 2)
		await frames()
		var view: Vector2 = t._root.get_viewport_rect().size
		var whole := Rect2(Vector2.ZERO, view)
		var last_x := -1.0
		var ordered := true
		var inside := true
		var clear := true
		for m in Tour.bar_items():
			var r: Rect2 = t._cards[m]
			ordered = ordered and r.position.x > last_x
			last_x = r.position.x
			inside = inside and whole.encloses(r.grow(8.0))
			# Over the keys at the bottom.
			clear = clear and r.end.y + 10.0 < t._hints.position.y
		check(t._bar.visible and t._cards.size() == 6, "%s: la barra, con sus seis tarjetas" % shape[0])
		check(ordered, "%s: la casita a la izquierda y los museos en orden hacia la derecha" % shape[0])
		check(inside, "%s: cada tarjeta entera dentro de la pantalla (%s)" % [shape[0], view])
		check(clear, "%s: sin tapar las teclas de abajo" % shape[0])
		var one: Rect2 = t._cards[0]
		check(one.size.x >= 72.0 and one.size.y >= 44.0, "%s: legibles con el mando (%s)" % [shape[0], one.size])
		# The whole strip (cards, the tag and the name over them) is low.
		var strip_top: float = one.position.y - 40.0
		var strip_h := (one.end.y - strip_top) / view.y
		check((one.size.y / view.y) <= 0.10 and strip_h <= 0.15, "%s: la tira ocupa poco de la altura (tarjetas %.1f %%, con el rótulo %.1f %%)" % [shape[0], one.size.y / view.y * 100.0, strip_h * 100.0])
		var widest := (t._cards[4] as Rect2).end.x - (t._cards[H] as Rect2).position.x
		check(widest <= view.x - 100.0, "%s: deja aire a los lados (%.0f de %.0f)" % [shape[0], widest, view.x])
		t.queue_free()
		await frames()

	# --- The mouse ----------------------------------------------------------------------------
	root.size = Vector2i(1280, 720)
	t = city(Story.count(), 1)
	await frames(2)
	var card: Rect2 = t._cards[3]
	# A hover that does not move (a mouse at rest) never picks.
	t._on_mouse(motion(card.get_center(), Vector2.ZERO))
	check(t.stage.picked == 1, "el ratón quieto encima no quita la selección")
	t._on_mouse(motion(card.get_center(), Vector2(3, 0)))
	check(t.stage.picked == 1, "... ni un temblor de unos píxeles")
	t._on_mouse(motion(Vector2(640, 100), Vector2(40, 0)))
	await create_timer(0.3).timeout
	t._on_mouse(motion(card.get_center(), Vector2(40, 0)))
	check(t.stage.picked == 3, "pasar el ratón de verdad por una tarjeta la elige")
	# The pad speaks: the mouse at rest over another card does not take it back.
	t.input(pad(JOY_BUTTON_DPAD_LEFT))
	check(t.stage.picked == 2, "el mando manda cuando se toca")
	t._on_mouse(motion(card.get_center(), Vector2(2, 0)))
	check(t.stage.picked == 2, "... y un ratón casi quieto no se lo quita")
	for i in 60:
		t._on_mouse(motion(card.get_center() + Vector2(i % 3, 0), Vector2(1, 0)))
	check(t.stage.picked == 2, "... ni el temblor de una mano en reposo encima de otra tarjeta (60 microsacudidas)")
	t._on_mouse(motion(Vector2(640, 100), Vector2(40, 0)))
	t._on_mouse(motion(card.get_center(), Vector2(40, 0)))
	check(t.stage.picked == 3, "... pero si el ratón sale y entra de verdad, manda el ratón")
	# Hovering a shut card, or nothing, does nothing.
	t = city(6)
	await frames(2)
	t._on_mouse(motion(t._cards[4].get_center(), Vector2(40, 0)))
	check(t.stage.picked == 1, "sobre una tarjeta cerrada no elige")
	t._on_mouse(click(t._cards[4].get_center()))
	check(t.state == "city" and t.stage.picked == 1, "... ni el clic la abre")
	t._on_mouse(motion(Vector2(640, 100), Vector2(40, 0)))
	check(t.stage.picked == 1, "sobre el vacío, nada")
	# A click on the one picked goes in.
	t._on_mouse(click(t._cards[1].get_center()))
	await frames(2)
	check(t.state in ["zoom", "museum"], "el clic en la tarjeta elegida entra")
	t.queue_free()
	await frames()
	# A click on another open card picks it and goes in at once.
	t = city(11)
	await frames(2)
	sounds.clear()
	t._on_mouse(click(t._cards[0].get_center()))
	await frames(2)
	check(t.stage.picked == 0 and t.state in ["zoom", "museum"], "el clic en otra tarjeta abierta la elige y entra a la vez")
	t.queue_free()
	await frames()
	# The hideout card.
	t = city(6)
	await frames(2)
	var went := [false]
	t.practice.connect(func() -> void: went[0] = true)
	t._on_mouse(click(t._cards[H].get_center()))
	check(went[0], "el clic en la casita entra en ella")
	t.queue_free()
	await frames()
	# The map behind still answers: over a stop or a click on it.
	t = city(11)
	await frames(2)
	t._on_mouse(motion(t.stage.stop_point(0), Vector2(40, 0)))
	check(t.stage.picked == 2, "pasar por encima del sitio en el mapa no cambia nada (la cámara se desliza bajo un ratón quieto): solo el clic")
	t._on_mouse(click(t.stage.stop_point(1)))
	await frames(2)
	check(t.stage.picked == 1 and t.state in ["zoom", "museum"], "el clic sobre el sitio del mapa lo elige y entra")
	t.queue_free()
	await frames()
	# The right button goes back.
	t = city(6)
	await frames(2)
	left[0] = false
	t.left.connect(func() -> void: left[0] = true)
	t._on_mouse(click(Vector2(600, 300), MOUSE_BUTTON_RIGHT))
	check(left[0], "el botón derecho vuelve")
	t.queue_free()
	await frames()

	# A real event through the window, at a size that is not the game's: nothing above blocks it.
	root.size = Vector2i(1600, 900)
	t = city(11)
	await frames(3)
	var scale := root.get_final_transform().get_scale()
	var target: Rect2 = t._cards[0]
	root.push_input(motion(target.get_center() * scale, Vector2(40, 0)))
	await frames(2)
	check(t.stage.picked == 0, "un movimiento de ratón de verdad, con la ventana a 1600x900, elige la tarjeta")
	root.push_input(click(t._cards[2].get_center() * scale))
	await frames(2)
	check(t.stage.picked == 2 and t.state in ["zoom", "museum"], "... y un clic de verdad la elige y entra")
	t.queue_free()
	await frames()
	root.size = Vector2i(1280, 720)

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
