extends SceneTree
## Las transiciones entre pantallas: ninguna se come una pulsación ni la
## cuenta dos veces. Del título al menú, del menú a la partida y del final
## a lo siguiente; y el foco, que no salta al rehacer la misma pantalla.
## Pulsaciones de verdad (Input.parse_input_event), sobre la escena principal.
var fails := 0
var m


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1


func key(k: Key, down: bool) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = down
	Input.parse_input_event(e); Input.flush_buffered_events()


## A press and its release a frame later.
func press(k: Key) -> void:
	key(k, true)
	await process_frame
	key(k, false)


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func focused() -> Control:
	return root.gui_get_focus_owner()


func _init() -> void:
	Story.save = "user://test_transiciones.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames(3)
	var hud: Hud = m.hud

	# --- The title: the cover, over the menu already there -----------------------
	var cover: TitleScreen = null
	for c in m.get_children():
		if c is TitleScreen:
			cover = c
	check(cover != null, "sin argumentos, sale la portada")
	check(m.phase == "title" and hud.menu_open(), "... con el menú ya debajo, para fundirse sobre él y no sobre el museo")
	key(KEY_ENTER, true)
	await frames()
	check(cover._leaving and m.phase == "title", "la tecla que quita la portada no elige también la tarjeta")
	# The same press arriving twice (a pad seen as two devices): still one.
	key(KEY_ENTER, false)
	key(KEY_ENTER, true)
	await frames()
	key(KEY_ENTER, false)
	check(m.phase == "title", "... ni repetida al instante")
	await create_timer(Hud.FADE_S * 0.6).timeout
	check(is_instance_valid(cover) and cover._leaving, "la portada aún se está yendo")
	await press(KEY_ENTER)
	await frames()
	check(m.phase == "story_players", "una pulsación nueva mientras se va llega al menú: no se pierde")
	await press(KEY_ESCAPE)
	await frames(2)
	check(m.phase == "title", "atrás, al título")
	await press(KEY_ESCAPE)
	await frames(2)
	check(m.phase == "title", "... y otro atrás en el título no hace nada")

	# --- The same screen built again keeps the focus -----------------------------------
	# (The size picked is saved: put back as it was at the end.)
	var size_was: String = m.size
	m._show_generative_menu()
	await frames(3)
	var size_card: Control = hud._rows[1][2]
	size_card.grab_focus()
	await frames()
	await press(KEY_ENTER)
	await frames(3)
	check(m.size == "large", "elegir el tamaño grande")
	check(hud._rows[1].find(focused()) == 2, "al rehacerse el menú, el foco sigue en el tamaño elegido, no salta arriba")
	var cards: Array = hud._panel_box.find_children("*", "Button", true, false)
	check(cards.all(func(b): return (b as Control).modulate.a > 0.0) and hud._panel_box.modulate.a == 1.0, "... y el menú está entero, sin fundirse")

	# --- Into a night ------------------------------------------------------------
	m._start("generative", 1)
	await frames(3)
	check(m.phase == "brief", "a la previa del golpe")
	var last: int = m._brief_pages().size() - 1
	m._show_brief(last)
	# Straight away, while the page is still swapping in: the press counts.
	await frames()
	await press(KEY_ENTER)
	await frames()
	check(m.phase == "countdown", "EMPEZAR recién cambiada la página: cuenta atrás")
	check(not hud._count.visible and hud.counting(), "el 3 espera a que se vaya el menú")
	await press(KEY_ENTER)
	await press(KEY_SPACE)
	await press(KEY_ESCAPE)
	await frames()
	check(m.phase == "countdown" and hud._count_left == Hud.COUNT_S * Hud.COUNT.size(), "otras pulsaciones no la reinician ni la saltan")
	await create_timer(Hud.FADE_S + 0.1).timeout
	check(hud._count.visible, "ya sin menú, el 3")
	await create_timer(Hud.COUNT_S * Hud.COUNT.size()).timeout
	check(m.phase == "playing", "y a jugar")

	# Tab skips the briefing from the keyboard too, not just Start on a pad.
	m._new_round(1)
	m._show_brief(0)
	await frames(3)
	await press(KEY_TAB)
	await frames()
	check(m.phase == "countdown", "Tab en la previa salta a la cuenta atrás")
	m._start_playing()
	await frames(2)

	# --- Out of a night: caught ----------------------------------------------------
	m.thieves[0].out = true
	await frames(2)
	check(m.phase == "over" and not hud.menu_open(), "pillado: la partida se queda quieta un momento")
	# Mashing the roll and the action as it ends: none of it skips the file.
	await press(KEY_SPACE)
	await press(KEY_ENTER)
	await press(KEY_ESCAPE)
	await frames()
	check(m.phase == "over", "... y lo que se pulse entonces no cuenta")
	await create_timer(Hud.HOLD_S + 0.05).timeout
	check(m.phase == "caught" and hud.menu_open(), "luego, la ficha")
	await frames(3)
	check(focused() is Button and (focused() as Button).text == Text.t("END_AGAIN"), "con el foco en OTRA VEZ")
	var level: int = m.level
	await press(KEY_ENTER)
	await frames(3)
	check(m.phase == "brief" and m.brief_page == 0 and m.level == level, "OTRA VEZ, una vez: la previa, en su primera página")
	# A second press is on the new page's button: one page on, never two.
	await press(KEY_ENTER)
	await frames(3)
	check(m.phase == "brief" and m.brief_page == mini(1, m._brief_pages().size() - 1), "la siguiente pulsación, una página más")

	# --- Out of a night: away with it, and back out to the title --------------------
	m._start_playing()
	await frames(2)
	for t in m.thieves:
		t.out = true
		t.safe = true
	await frames(2)
	check(m.phase == "over", "escapado: un momento quieto")
	await create_timer(Hud.HOLD_S + 0.05).timeout
	check(m.phase == "escaped", "luego, el periódico")
	await frames(3)
	await press(KEY_ESCAPE)
	await frames(3)
	check(m.phase == "title", "atrás desde el final: al título")
	await press(KEY_ESCAPE)
	await frames(2)
	check(m.phase == "title", "... una sola vez")

	# --- The pause comes and goes with the monitor ------------------------------------
	m._start("generative", 1)
	await frames(2)
	m._start_playing()
	await frames(2)
	await press(KEY_P)
	await frames(2)
	check(m.phase == "paused" and paused, "P: pausa")
	await press(KEY_P)
	await frames(2)
	check(m.phase == "playing" and not paused, "P otra vez: seguir, al momento")

	m._pick_size(size_was)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("FALLOS: %d" % fails)
	quit(1 if fails else 0)
