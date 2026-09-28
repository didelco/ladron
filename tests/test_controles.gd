extends SceneTree
## Los controles: qué hace cada tecla y botón en partida, en los menús y al
## elegir sitio. Eventos simulados, sobre la escena principal.
var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1
func pad(b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new(); e.device = 0; e.button_index = b; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()
func key(k: Key, down: bool, loc := KEY_LOCATION_UNSPECIFIED) -> InputEventKey:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = down; e.location = loc
	Input.parse_input_event(e); Input.flush_buffered_events()
	return e
func _init() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	# pad: A action, B roll, X crouch, L3 crouch, Y smoke
	for pair in [[JOY_BUTTON_A, 5, "A = acción"], [JOY_BUTTON_B, 6, "B = rodar"], [JOY_BUTTON_X, 4, "X = a gatas"], [JOY_BUTTON_LEFT_STICK, 4, "L3 = a gatas"], [JOY_BUTTON_Y, 8, "Y = humo"]]:
		pad(pair[0], true)
		var o: Array = m._seat_input("pad:0", false)
		check(o[pair[1]] and o.count(true) == 1, pair[2] + " " + str(o))
		pad(pair[0], false)
	pad(JOY_BUTTON_A, true)
	check(not m._seat_input("pad:0", true)[5], "A pulsada desde el menú no actúa al empezar")
	check(not m._seat_input("pad:0", false)[5], "... ni mientras siga pulsada")
	pad(JOY_BUTTON_A, false); m._seat_input("pad:0", false); pad(JOY_BUTTON_A, true)
	check(m._seat_input("pad:0", false)[5], "... y al volver a pulsarla, sí")
	pad(JOY_BUTTON_A, false)
	# keyboard
	for c in [[KEY_E, "kb_left", 5, "E = acción"], [KEY_SPACE, "kb_left", 6, "Espacio = rodar"], [KEY_C, "kb_left", 4, "C = a gatas"], [KEY_PERIOD, "kb_right", 5, ". = acción J2"], [KEY_ENTER, "kb_right", 6, "Enter = rodar J2"], [KEY_SLASH, "kb_right", 4, "tecla tras el punto = a gatas J2"], [KEY_F, "kb_left", 8, "F = humo"], [KEY_COMMA, "kb_right", 8, ", = humo J2"]]:
		key(c[0], true)
		var o: Array = m._seat_input(c[1], false)
		check(o[c[2]] and o.count(true) == 1, c[3] + " " + str(o))
		key(c[0], false)
	m._input(key(KEY_SHIFT, true, KEY_LOCATION_LEFT))
	check(m._seat_input("kb_left", false)[7] and not m._seat_input("kb_right", false)[7], "Shift izq. = lento J1, no J2")
	m._input(key(KEY_SHIFT, false, KEY_LOCATION_LEFT))
	m._input(key(KEY_SHIFT, true, KEY_LOCATION_RIGHT))
	check(m._seat_input("kb_right", false)[7] and not m._seat_input("kb_left", false)[7], "Shift dcha. = lento J2, no J1")
	m._input(key(KEY_SHIFT, false, KEY_LOCATION_RIGHT))
	check(m._seat_input("kb_left", false).count(true) == 0, "sin teclas, nada")
	# menus
	var ev := InputEventJoypadButton.new(); ev.pressed = true
	for c in [["brief", JOY_BUTTON_START, "skip", "Start en la previa = saltar y jugar"], ["prologue", JOY_BUTTON_START, "skip", "Start en la historia = saltar"], ["playing", JOY_BUTTON_START, "pause", "Start jugando = pausa"], ["brief", JOY_BUTTON_LEFT_SHOULDER, "prev", "LB en la previa = pestaña anterior"], ["assets", JOY_BUTTON_RIGHT_SHOULDER, "next", "RB en recursos = pestaña siguiente"], ["playing", JOY_BUTTON_BACK, "map", "View jugando = mapa"], ["playing", JOY_BUTTON_Y, "", "Y jugando = nada"], ["playing", JOY_BUTTON_B, "", "B jugando no es atrás"], ["playing", JOY_BUTTON_A, "", "A jugando no es aceptar"], ["paused", JOY_BUTTON_B, "back", "B en pausa = volver"], ["paused", JOY_BUTTON_START, "back", "Start en pausa = seguir"], ["settings", JOY_BUTTON_START, "accept", "Start en un menú = aceptar"]]:
		m.phase = c[0]; ev.button_index = c[1]
		check(m._intent(ev) == c[2], c[3])
	var kev := InputEventKey.new(); kev.pressed = true
	for c in [[KEY_SPACE, "", "Espacio jugando = rodar, no atrás"], [KEY_ENTER, "", "Enter jugando = rodar J2, no atrás"], [KEY_E, "", "E jugando = acción, no aceptar"], [KEY_ESCAPE, "pause", "Esc jugando = pausa"], [KEY_P, "pause", "P jugando = pausa"], [KEY_M, "map", "M jugando = mapa"]]:
		m.phase = "playing"; kev.keycode = c[0]
		check(m._intent(kev) == c[1], c[2])
	# join: B of an unseated pad does not take someone's seat
	m._show_join("generative", 2)
	m.joining.append_array(["kb_left", "pad:1"])
	var b := InputEventJoypadButton.new(); b.pressed = true; b.button_index = JOY_BUTTON_B; b.device = 0
	m._join_input(b)
	check(m.joining == ["kb_left", "pad:1"], "B de un mando sin asiento no quita a nadie")
	b.device = 1; m._join_input(b)
	check(m.joining == ["kb_left"], "B de su mando lo quita")
	m.joining.clear(); m.joined_at = -INF
	m._join_input(key(KEY_SHIFT, true, KEY_LOCATION_RIGHT)); key(KEY_SHIFT, false)
	check(m.joining == ["kb_right"], "Shift dcha. se sienta en el lado derecho")
	# A pad that drops out mid-game leaves its thief without hands, and the
	# game pauses; the same pad back (same guid), or a press on a free pad,
	# gives them back — never someone else's pad.
	m.seats.assign(["pad:3", "pad:4"])
	m.pad_guids = {3: "guid-a", 4: "guid-b"}
	m.pads_lost.clear()
	m._pad_changed(4, false)
	check(m.seats == ["pad:3", "lost"] and m.pads_lost == {1: "guid-b"}, "se va el mando de J2: J2 sin mando " + str(m.seats))
	check(m._seat_input("lost", false).count(true) == 0, "sin mando, no se mueve")
	m._reclaim_pad(3)
	check(m.seats == ["pad:3", "lost"], "el mando de J1 no le sirve a J2")
	m._reclaim_pad(7)
	check(m.seats == ["pad:3", "pad:7"] and m.pads_lost.is_empty(), "otro mando libre: J2 lo coge")
	m._pad_changed(3, false)
	check(Pads.owner_back(m.pads_lost, "guid-a") == 0, "vuelve el mismo mando de J1: es suyo")
	m._give_pad(0, 5)
	check(m.seats == ["pad:5", "pad:7"] and m.pads_lost.is_empty(), "J1 vuelve a tener mando")
	check(Pads.real(0) and Pads.real(-1), "un mando cualquiera cuenta")
	check(Vector2i(0x05ac, 0x0004) in Pads.FAKE, "el falso mando de Apple (05ac:0004) se ignora")
	m.seats.assign(["any"])
	m.pads_lost.clear()
	print("etiqueta de KEY_SLASH en este teclado: ", m._key_label(KEY_SLASH), " · punto: ", m._key_label(KEY_PERIOD))
	print("FALLOS: %d" % fails)
	quit(1 if fails else 0)
