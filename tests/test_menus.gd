extends SceneTree
## Las teclas de los menús: aceptar y atrás significan lo mismo en todas las
## pantallas y lo mismo que jugando (cada mitad del teclado es un mando).
## Aceptar: E, el punto, A (la acción). Atrás: Esc, Espacio, Enter, B (rodar,
## soltar). En cada pantalla con menú, cada una de esas teclas, pulsada de
## verdad (Input.parse_input_event), hace lo que le toca: aceptar avanza,
## atrás vuelve. Sobre la escena principal.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var m
var hud: Hud

const ACCEPTS := [KEY_E, KEY_PERIOD, "A"]
const BACKS := [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, "B"]
const W := Hud.SWAP_WAIT_FRAMES + 3


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func key_event(k: Key, down: bool) -> InputEventKey:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = down
	return e


func pad_event(b: JoyButton, down: bool) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new(); e.device = 0; e.button_index = b; e.pressed = down
	return e


## A key (Key) or a pad's button ("A", "B"), pressed and let go a frame later.
func hit(k) -> void:
	var down: InputEvent = pad_event(JOY_BUTTON_A if k == "A" else JOY_BUTTON_B, true) if k is String else key_event(k, true)
	var up: InputEvent = pad_event(JOY_BUTTON_A if k == "A" else JOY_BUTTON_B, false) if k is String else key_event(k, false)
	Input.parse_input_event(down); Input.flush_buffered_events()
	await process_frame
	Input.parse_input_event(up); Input.flush_buffered_events()


func name_of(k) -> String:
	if k is String:
		return k
	return {KEY_E: "E", KEY_PERIOD: "punto", KEY_ESCAPE: "Esc", KEY_SPACE: "Espacio", KEY_ENTER: "Enter", KEY_KP_ENTER: "Enter del teclado numérico"}.get(k, str(k))


func frames(n := 1) -> void:
	for i in n:
		await process_frame


## Each key of keys, on the screen open() puts up: then() says whether it
## went where it should.
func each(keys: Array, screen: String, open: Callable, then: Callable, what: String) -> void:
	for k in keys:
		await open.call()
		await frames(W)
		await hit(k)
		await frames(W)
		check(then.call(), "%s · %s: %s (fase %s)" % [screen, name_of(k), what, m.phase])


func _init() -> void:
	Story.save = "user://test_menus.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames(3)
	hud = m.hud
	for c in m.get_children():
		if c is TitleScreen:
			c.queue_free()
	await frames(2)

	# --- Lo mismo en todas partes ------------------------------------------------------
	var in_map := func(action: String) -> Array:
		var out := []
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				out.append(e.keycode if e.keycode != KEY_NONE else e.physical_keycode)
			elif e is InputEventJoypadButton:
				out.append("pad:%d" % e.button_index)
		return out
	var accept_map: Array = in_map.call("ui_accept")
	var cancel_map: Array = in_map.call("ui_cancel")
	check(accept_map.filter(func(k): return k is int).all(func(k): return k in MenuKeys.ACCEPT_KEYS) and MenuKeys.ACCEPT_KEYS.all(func(k): return k in accept_map) and "pad:%d" % JOY_BUTTON_A in accept_map,
		"ui_accept (los botones de Godot) = E, el punto y A, ni más ni menos: " + str(accept_map))
	check(MenuKeys.BACK_KEYS.all(func(k): return k not in accept_map), "ninguna tecla de atrás pulsa un botón")
	check(KEY_ESCAPE in cancel_map and "pad:%d" % JOY_BUTTON_B in cancel_map and cancel_map.all(func(k): return k not in accept_map), "ui_cancel = Esc y B, nada de aceptar")
	for k in ACCEPTS:
		var e: InputEvent = pad_event(JOY_BUTTON_A, true) if k is String else key_event(k, true)
		check(MenuKeys.of(e) == "accept" and Tour.new().intent(e) == "accept", name_of(k) + " acepta en los menús y en la ciudad")
	for k in BACKS:
		var e: InputEvent = pad_event(JOY_BUTTON_B, true) if k is String else key_event(k, true)
		check(MenuKeys.of(e) == "back" and Tour.new().intent(e) == "back", name_of(k) + " vuelve en los menús y en la ciudad")
	# Jugando, las mismas teclas: aceptar es la acción, atrás (menos Esc) es rodar.
	for k in MenuKeys.ACCEPT_KEYS:
		Input.parse_input_event(key_event(k, true)); Input.flush_buffered_events()
		var o: Array = m.hands.seat_input("kb_left" if k == KEY_E else "kb_right", false)
		check(o[5] and not o[6], name_of(k) + " jugando es la acción (A)")
		Input.parse_input_event(key_event(k, false)); Input.flush_buffered_events()
	for k in MenuKeys.BACK_KEYS:
		if k == KEY_ESCAPE:
			continue
		Input.parse_input_event(key_event(k, true)); Input.flush_buffered_events()
		var o: Array = m.hands.seat_input("kb_left" if k == KEY_SPACE else "kb_right", false)
		check(o[6] and not o[5], name_of(k) + " jugando es rodar (B)")
		Input.parse_input_event(key_event(k, false)); Input.flush_buffered_events()
	# Moverse: las flechas (el de la derecha, cruceta y stick) y WASD (el de la izquierda).
	for pair in [["ui_up", KEY_UP, KEY_W], ["ui_down", KEY_DOWN, KEY_S], ["ui_left", KEY_LEFT, KEY_A], ["ui_right", KEY_RIGHT, KEY_D]]:
		var got: Array = in_map.call(pair[0])
		check(pair[1] in got and pair[2] in got, "%s: la flecha y %s %s" % [pair[0], OS.get_keycode_string(pair[2]), str(got)])
	# Un campo de texto (el editor) sigue escribiendo la E, el espacio y WASD.
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	for c in [[KEY_E, "e"], [KEY_SPACE, " "], [KEY_PERIOD, "."], [KEY_W, "w"], [KEY_A, "a"], [KEY_S, "s"], [KEY_D, "d"]]:
		var e := key_event(c[0], true)
		e.unicode = c[1].unicode_at(0)
		Input.parse_input_event(e); Input.flush_buffered_events()
		await frames()
		Input.parse_input_event(key_event(c[0], false)); Input.flush_buffered_events()
	check(field.text == "e .wasd", "un campo de texto escribe la E, el espacio, el punto y WASD: '%s'" % field.text)
	field.queue_free()
	await frames()

	# --- Moverse por los menús con WASD, igual que con las flechas -----------------------------
	# Where one key takes the focus from where open() leaves it.
	# How many places one key takes the focus along its row or column, from
	# the middle one (a menu built anew keeps the one last in focus: so the
	# same start for the arrow and for WASD).
	var steps_after := func(open: Callable, k: Key) -> int:
		await open.call()
		await frames(W)
		var owner: Control = root.gui_get_focus_owner()
		if owner == null:
			return -99
		var row: Array = owner.get_parent().get_children().filter(func(c): return c is Control and c.focus_mode != Control.FOCUS_NONE and c.visible)
		var mid: int = row.size() / 2
		(row[mid] as Control).grab_focus()
		await frames(2)
		await hit(k)
		await frames(W)
		var i := row.find(root.gui_get_focus_owner())
		return -99 if i < 0 else i - mid
	var column := func() -> void: m.options.show("title")
	var cards := func() -> void:
		m.players = 1
		m._show_title()
	for t in [["ajustes", column, "settings", KEY_DOWN, KEY_S], ["ajustes", column, "settings", KEY_UP, KEY_W],
			["título", cards, "title", KEY_RIGHT, KEY_D], ["título", cards, "title", KEY_LEFT, KEY_A]]:
		var by_arrow: int = await steps_after.call(t[1], t[3])
		var by_wasd: int = await steps_after.call(t[1], t[4])
		check(by_wasd == by_arrow and by_wasd != 0 and by_wasd != -99 and m.phase == t[2] and not hud.bubble_open(),
			"%s · %s mueve el foco como %s (%d, %d)" % [t[0], OS.get_keycode_string(t[4]), OS.get_keycode_string(t[3]), by_wasd, by_arrow])
	var bubble_at := func(k: Key) -> int:
		m.players = 1
		m._show_title()
		await frames(W)
		m._pick_players("generative")
		await frames(W)
		var was: int = hud.bubble_focus()
		await hit(k)
		await frames(W)
		return hud.bubble_focus() - was
	for pair in [[KEY_RIGHT, KEY_D], [KEY_LEFT, KEY_A]]:
		var by_arrow: int = await bubble_at.call(pair[0])
		var by_wasd: int = await bubble_at.call(pair[1])
		check(by_wasd == by_arrow and by_wasd != 0 and m.phase == "pick",
			"bocadillo · %s se mueve lo mismo que %s (%d, %d)" % [OS.get_keycode_string(pair[1]), OS.get_keycode_string(pair[0]), by_wasd, by_arrow])

	# --- El título ---------------------------------------------------------------------
	m.players = 1
	var title := func() -> void: m._show_title()
	await each(ACCEPTS, "título", title, func(): return m.phase == "pick" and hud.bubble_open(), "abre el bocadillo de la tarjeta")
	await each(BACKS, "título", title, func(): return m.phase == "title" and not hud.bubble_open(), "atrás no hace nada")

	# --- Cuántos ladrones: el bocadillo ------------------------------------------------
	var bubble := func() -> void:
		m.players = 1
		m._show_title()
		await frames(W)
		m._pick_players("generative")
	await each(ACCEPTS, "bocadillo", bubble, func(): return m.phase == "generative" and m.players == 1, "elige 1 y va al generativo")
	await each(BACKS, "bocadillo", bubble, func(): return m.phase == "title" and not hud.bubble_open(), "lo cierra")

	# --- El generativo -------------------------------------------------------------------
	var generative := func() -> void:
		m.players = 1
		m._show_generative_menu()
	await each(BACKS, "generativo", generative, func(): return m.phase == "pick" and hud.bubble_open(), "vuelve al bocadillo")
	await each(ACCEPTS, "generativo", generative, func(): return m.phase == "brief" and m.mode == "generative", "EMPEZAR: a la previa")

	# --- La previa (tiene una ronda ya) --------------------------------------------------
	var pages: int = m.briefing.pages().size()
	var brief := func() -> void: m.briefing.show(0)
	if pages > 1:
		await each(ACCEPTS, "previa", brief, func(): return m.phase == "brief" and m.briefing.brief_page == 1, "la página siguiente")
		await each(BACKS, "previa (2.ª página)", func(): m.briefing.show(1), func(): return m.phase == "brief" and m.briefing.brief_page == 0, "la página anterior")
	else:
		print("(la previa del generativo tiene una sola página: aceptar ahí empieza, se prueba en test_transiciones)")
	await each(BACKS, "previa", brief, func(): return m.phase == "generative", "vuelve al generativo")

	# --- La pausa, y los ajustes desde ella ---------------------------------------------------
	var pause := func() -> void:
		m._start_playing()
		await frames(2)
		m._pause()
	await each(ACCEPTS, "pausa", pause, func(): return m.phase == "playing" and not paused, "SEGUIR")
	await each(BACKS, "pausa", pause, func(): return m.phase == "playing" and not paused, "atrás: a jugar")
	await each(BACKS, "ajustes desde la pausa", func():
		await pause.call()
		await frames(W)
		m.options.show("paused"), func(): return m.phase == "paused", "vuelve a la pausa")

	# --- SALIR DEL JUEGO, desde la pausa: pide confirmar, y no cierra de verdad aquí ----------
	var quits := [0]
	m.quit_hook = func() -> void: quits[0] += 1
	var focus_text := func() -> String:
		var f := root.gui_get_focus_owner()
		return (f as Button).text if f is Button else ""
	var buttons_of := func() -> Array:
		var out: Array = []
		var f := root.gui_get_focus_owner()
		if f:
			for c in f.get_parent().get_children():
				if c is Button:
					out.append((c as Button).text)
		return out
	await pause.call()
	await frames(W)
	var opts: Array = buttons_of.call()
	check(opts.size() >= 2 and opts[-1] == Text.t("MENU_QUIT_GAME") and opts.count(Text.t("MENU_QUIT_GAME")) == 1,
		"pausa · SALIR DEL JUEGO existe y es la última (%s)" % [opts])
	for k in [KEY_S, KEY_DOWN]:
		await pause.call()
		await frames(W)
		for i in opts.size() - 1:
			await hit(k)
			await frames(2)
		check(focus_text.call() == Text.t("MENU_QUIT_GAME"), "pausa · %s baja hasta SALIR DEL JUEGO" % OS.get_keycode_string(k))
	for k in ACCEPTS:
		await pause.call()
		await frames(W)
		for i in opts.size() - 1:
			await hit(KEY_DOWN)
			await frames(2)
		await hit(k)
		await frames(W)
		check(m.phase == "paused" and m.quit_asking and quits[0] == 0 and focus_text.call() == Text.t("SETTINGS_NO"),
			"pausa · %s en SALIR DEL JUEGO pregunta, sin salir, con NO elegido" % name_of(k))
		# Atrás (o P, o Start) es NO: vuelve a la pausa, no al juego.
		await hit(KEY_ESCAPE)
		await frames(W)
		check(m.phase == "paused" and not m.quit_asking and quits[0] == 0 and buttons_of.call() == opts,
			"pregunta · Esc cancela: vuelve a la pausa")
	await pause.call()
	await frames(W)
	m._ask_quit()
	await frames(W)
	await hit(KEY_P)
	await frames(W)
	check(m.phase == "paused" and not m.quit_asking and quits[0] == 0, "pregunta · P cancela: vuelve a la pausa")
	m._ask_quit()
	await frames(W)
	await hit("B")
	await frames(W)
	check(m.phase == "paused" and not m.quit_asking and quits[0] == 0, "pregunta · B cancela: vuelve a la pausa")
	m._ask_quit()
	await frames(W)
	await hit(KEY_E)
	await frames(W)
	check(m.phase == "paused" and not m.quit_asking and quits[0] == 0, "pregunta · E sobre NO: vuelve a la pausa")
	m._ask_quit()
	await frames(W)
	await hit(KEY_LEFT)
	await frames(2)
	check(focus_text.call() == Text.t("SETTINGS_YES"), "pregunta · izquierda lleva a SÍ")
	await hit(KEY_E)
	await frames(W)
	check(quits[0] == 1, "pregunta · SÍ cierra el juego (una vez)")
	m.quit_hook = Callable()
	# En la casa de la banda la pausa ya sale por la puerta: sin la opción.
	var was_mode: String = m.mode
	m.mode = Practice.MODE
	m._pause()
	await frames(W)
	check(Text.t("MENU_QUIT_GAME") not in buttons_of.call(), "pausa del dojo · sin SALIR DEL JUEGO")
	m.mode = was_mode

	# --- Jugando: rodar no es atrás, la acción no es aceptar -------------------------------
	var play := func() -> void:
		m._start_playing()
	await each(["A", "B", KEY_E, KEY_PERIOD, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_W, KEY_A, KEY_S, KEY_D], "jugando", play, func(): return m.phase == "playing", "no pausa ni sale")
	await each([KEY_ESCAPE], "jugando", play, func(): return m.phase == "paused", "Esc pausa")

	# --- El final de la noche -----------------------------------------------------------------
	for how in ["caught", "escaped"]:
		var end := func() -> void:
			m._start_playing()
			await frames(2)
			m.phase = how
			m._show_end()
		await each(ACCEPTS, "final (%s)" % how, end, func(): return m.phase == "brief", "OTRA VEZ / SIGUIENTE: a la previa")
		await each(BACKS, "final (%s)" % how, end, func(): return m.phase == "title", "atrás: al menú del modo (el título)")

	# --- El final de la historia --------------------------------------------------------------
	var ending := func() -> void: m._show_ending()
	await each(ACCEPTS + BACKS, "final de la historia", ending, func(): return m.phase == "title", "al título")

	# --- Los retos ----------------------------------------------------------------------------
	var challenges := func() -> void:
		m.challenges.challenge_at = ""
		m.challenges.show_menu()
	await each(ACCEPTS, "retos", challenges, func(): return m.phase == "challenge", "abre el primero de la lista")
	await each(BACKS, "retos", challenges, func(): return m.phase == "title", "vuelve al título")
	await each(BACKS, "un reto", func(): m.challenges.show_night_map(1), func(): return m.phase == "menu", "vuelve a la lista")

	# --- Los ajustes ----------------------------------------------------------------------------
	var settings := func() -> void: m.options.show("title")
	await each(ACCEPTS, "ajustes", settings, func(): return m.phase == "settings" and m.options.settings_page == "sound", "entra en la primera página (sonido)")
	await each(BACKS, "ajustes", settings, func(): return m.phase == "title", "vuelve al título")
	# Un ajuste cambia una vez por pulsación, no dos (el botón la toma al soltar).
	for k in ACCEPTS:
		m.options.show("title", "sound")
		await frames(W)
		var was: bool = m.sound_on
		await hit(k)
		await frames(W)
		check(m.sound_on != was and m.phase == "settings", "ajustes · sonido · %s: cambia el sonido una vez" % name_of(k))
		await hit(k)
		await frames(W)
		check(m.sound_on == was, "... y otra vez, como estaba")
	await each(BACKS, "ajustes · sonido", func(): m.options.show("title", "sound"), func(): return m.phase == "settings" and m.options.settings_page == "", "vuelve a los ajustes")
	# La página de ajustes tiene SONIDO, PANTALLA, CONTROLES, OPCIONES y VOLVER, por ese orden.
	m.options.show("title")
	await frames(W)
	var main_rows: Array = m.hud._panel_box.find_children("*", "Button", true, false).map(func(b): return (b as Button).text)
	check(main_rows == [Text.t("SETTINGS_SOUND_PAGE"), Text.t("SETTINGS_SCREEN_PAGE"), Text.t("SETTINGS_CONTROLS_PAGE"), Text.t("SETTINGS_OPTIONS_PAGE"), Text.t("MENU_BACK")], "ajustes: sonido, pantalla, controles, opciones y volver: %s" % [main_rows])
	# Opciones: la megafonía (y el panel de IA) cambian con aceptar; atrás vuelve a los ajustes.
	for k in ACCEPTS:
		m.options.show("title", "options")
		await frames(W)
		m.options.set_megaphone_mode("both")
		await hit(k)
		await frames(W)
		check(m.megaphone_mode == "text" and m.phase == "settings", "ajustes · opciones · %s: la primera línea es la megafonía y cambia una vez" % name_of(k))
	await each(BACKS, "ajustes · opciones", func(): m.options.show("title", "options"), func(): return m.phase == "settings" and m.options.settings_page == "", "vuelve a los ajustes")
	await each(BACKS, "ajustes · controles", func(): m.options.show("title", "pads"), func(): return m.phase == "settings" and m.options.settings_page == "", "vuelve a los ajustes")

	# --- La historia (el cuento del principio) ----------------------------------------------------
	var tale := func() -> void: m.briefing.show_prologue(0)
	await each(ACCEPTS, "cuento", tale, func(): return m.phase == "prologue" and m.briefing.prologue_page == 1, "la página siguiente")
	await each(BACKS, "cuento (2.ª página)", func(): m.briefing.show_prologue(1), func(): return m.phase == "prologue" and m.briefing.prologue_page == 0, "la página anterior")
	await each(BACKS, "cuento", tale, func(): return m.phase == "pick", "vuelve al título, al bocadillo de la historia")

	# --- Quién juega: aceptar se sienta, B (Espacio, Enter) se levanta ------------------------------
	var join := func() -> void:
		m.hands.show_join("generative", 2)
		m.hands.joined_at = -INF
	await join.call()
	await frames(W)
	await hit(KEY_E)
	m.hands.joined_at = -INF
	await hit(KEY_PERIOD)
	await frames()
	check(m.hands.joining == ["kb_left", "kb_right"], "E sienta al de la izquierda y el punto al de la derecha " + str(m.hands.joining))
	# Moverse no es moverse por el menú aquí: W y ↑ sientan, cada una a los suyos.
	await join.call()
	await frames(W)
	await hit(KEY_W)
	m.hands.joined_at = -INF
	await hit(KEY_UP)
	await frames()
	check(m.hands.joining == ["kb_left", "kb_right"], "W sienta al de la izquierda y ↑ al de la derecha " + str(m.hands.joining))
	await join.call()
	await frames(W)
	await hit(KEY_E)
	m.hands.joined_at = -INF
	await hit(KEY_PERIOD)
	await frames()
	await hit(KEY_SPACE)
	await frames()
	check(m.hands.joining == ["kb_right"], "Espacio levanta al de la izquierda (su B), no al último")
	await hit(KEY_ENTER)
	await frames()
	check(m.hands.joining.is_empty() and m.phase == "join", "Enter levanta al de la derecha")
	m.hands.joined_at = -INF
	await hit("A")
	await frames()
	check(m.hands.joining == ["pad:0"], "A sienta al mando")
	await hit(KEY_SPACE)
	await frames()
	check(m.hands.joining == ["pad:0"], "Espacio no levanta al mando de otro")
	await hit("B")
	await frames()
	check(m.hands.joining.is_empty(), "B lo levanta")
	for k in BACKS:
		await join.call()
		await frames(W)
		await hit(k)
		await frames(W)
		check(m.phase == "generative", "quién juega · %s sin nadie sentado: vuelve (fase %s)" % [name_of(k), m.phase])

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
