extends SceneTree
## Las transiciones entre pantallas: ninguna se come una pulsación ni la
## cuenta dos veces. Del título al menú, del menú a la partida y del final
## a lo siguiente; y el foco, que no salta al rehacer la misma pantalla.
## Pulsaciones de verdad (Input.parse_input_event), sobre la escena principal.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var m


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


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


## n physics ticks. The night is played in _physics_process (main.gd
## _tick, which ends it into "over"): idle frames come faster than the
## 60 Hz physics, so two of them can pass without a single tick.
func ticks(n := 1) -> void:
	for i in n:
		await physics_frame


func focused() -> Control:
	return root.gui_get_focus_owner()


func _init() -> void:
	Story.save = "user://test_transiciones.cfg"
	Settings.path = "user://test_transiciones_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames(3)
	var hud: Hud = m.hud

	# --- The title: the cover, over the hub already there (scenes/hub.gd) --------------
	var cover: TitleScreen = null
	for c in m.get_children():
		if c is TitleScreen:
			cover = c
	check(cover != null, "sin argumentos, sale la portada")
	check(m.phase == "title" and m.hub.visible, "... con el hub ya debajo, para fundirse sobre él y no sobre la guarida")
	key(KEY_E, true)
	await frames()
	check(cover._leaving and m.phase == "title", "la tecla que quita la portada no elige también la tarjeta")
	# The same press arriving twice (a pad seen as two devices): still one.
	key(KEY_E, false)
	key(KEY_E, true)
	await frames()
	key(KEY_E, false)
	check(m.phase == "title", "... ni repetida al instante")
	await create_timer(Hud.FADE_S * 0.6).timeout
	check(is_instance_valid(cover) and cover._leaving, "la portada aún se está yendo")
	await press(KEY_E)
	await frames()
	# Esa pulsación elige lo que tiene el foco: Guarida, la primera tarjeta,
	# que entra directamente a la casa con la banda que hay (ya no pregunta
	# cuántos). Volvemos al carril principal antes de seguir con la historia.
	check(m.mode == Practice.MODE and m.phase == "playing" and not m.hub.visible, "una pulsación nueva mientras se va llega al hub y entra en Guarida: no se pierde (%s, %s)" % [m.phase, m.mode])
	var guard := 0
	while m.hub.active != m.hub.OPTIONS and guard < 5:
		await press(KEY_ESCAPE)
		await frames(Hud.SWAP_WAIT_FRAMES + 2)
		guard += 1
	check(m.hub.active == m.hub.OPTIONS, "... y un atrás lo deja en el carril principal")

	# Los retornos usan el mismo menú, conservan selección y no duplican teclas.
	m._show_title("story", false)
	await press(KEY_E)
	await frames(3)
	check(m.hub.active_kind == "players" and m.hub.pending_mode == "story", "Historia abre jugadores nuevos")
	await press(KEY_ESCAPE)
	await frames(3)
	check(m.hub.active_kind == "options" and m.hub.active[m.hub.cursor].id == "story", "Esc restaura Historia en inicio nuevo")
	m.hub._pick("story")
	m.hub._pick("p2")
	check(m.phase == "join" and m.hub.visible, "2P abre asignación nueva")
	m.hands.unjoin()
	check(m.hub.active_kind == "players" and m.hub.pending_mode == "story", "cancelar asignación vuelve al carril correcto")
	var size_was: String = m.size
	var difficulty_was := Sim.difficulty
	m._show_generative_menu("difficulty")
	m._pick_setting("difficulty")
	await frames()
	m.hub._select(2, false)
	await press(KEY_E)
	await frames(3)
	check(Sim.difficulty == "hard" and m.phase == "generative", "una pulsación elige dificultad y vuelve a configuración")
	check(m.hub.active[m.hub.cursor].id == "difficulty", "se conserva la categoría elegida")
	m._pick_setting("size")
	await press(KEY_3)
	await frames(3)
	check(m.size == "large" and m.hub.active[m.hub.cursor].id == "size", "atajo 3 elige museo grande")
	m._show_title("generative", false)
	await press(KEY_E)
	await frames(3)
	check(m.phase == "generative", "generativo abre con una pulsación")
	m.players = 1
	# --- Into a night ------------------------------------------------------------
	m._start("generative", 1)
	await frames(3)
	check(m.phase == "brief", "a la previa del golpe")
	var last: int = m.briefing.pages().size() - 1
	m.briefing.show(last)
	# Straight away, while the page is still swapping in: the press counts.
	await frames()
	await press(KEY_E)
	await frames()
	check(m.phase == "countdown", "EMPEZAR recién cambiada la página: cuenta atrás")
	check(not hud._count.visible and hud.counting(), "el 3 espera a que se vaya el menú")
	await press(KEY_E)
	await press(KEY_ENTER)
	await press(KEY_SPACE)
	await press(KEY_ESCAPE)
	await frames()
	# Nearly whole still: under load those frames may run past the wait for
	# the menu to go, and the count has then begun, but only just.
	check(m.phase == "countdown" and hud._count_left > Hud.COUNT_S * (Hud.COUNT.size() - 1), "otras pulsaciones no la reinician ni la saltan")
	await create_timer(Hud.FADE_S + 0.1).timeout
	check(hud._count.visible, "ya sin menú, el 3")
	await create_timer(Hud.COUNT_S * Hud.COUNT.size()).timeout
	check(m.phase == "playing", "y a jugar")

	# Tab skips the briefing from the keyboard too, not just Start on a pad.
	m._new_round(1)
	m.briefing.show(0)
	await frames(3)
	await press(KEY_TAB)
	await frames()
	check(m.phase == "countdown", "Tab en la previa salta a la cuenta atrás")
	m._start_playing()
	await frames(2)

	# --- Out of a night: caught ----------------------------------------------------
	m.thieves[0].out = true
	await ticks(2)
	check(m.phase == "over" and not hud.menu_open(), "pillado: la partida se queda quieta un momento")
	# Mashing the roll and the action as it ends: none of it skips the file.
	await press(KEY_SPACE)
	await press(KEY_ENTER)
	await press(KEY_E)
	await press(KEY_ESCAPE)
	await frames()
	check(m.phase == "over", "... y lo que se pulse entonces no cuenta")
	await create_timer(Hud.HOLD_S + 0.05).timeout
	check(m.phase == "caught" and hud.menu_open(), "luego, la ficha")
	await frames(3)
	check(focused() is Button and (focused() as Button).text == Text.t("END_AGAIN"), "con el foco en OTRA VEZ")
	var level: int = m.level
	await press(KEY_E)
	await frames(3)
	check(m.phase == "brief" and m.briefing.brief_page == 0 and m.level == level, "OTRA VEZ, una vez: la previa, en su primera página")
	# A second press is on the new page's button: one page on, never two.
	# The surprise heist's plan is a single page, where the action key starts
	# the night: one press, one start.
	await press(KEY_E)
	await frames(3)
	if m.briefing.pages().size() > 1:
		check(m.phase == "brief" and m.briefing.brief_page == 1, "la siguiente pulsación, una página más")
	else:
		check(m.phase == "countdown" and m.level == level, "la siguiente pulsación, en un plan de una página, empieza el golpe (%s)" % m.phase)

	# --- Out of a night: away with it, and back out to the title --------------------
	m._start_playing()
	await frames(2)
	for t in m.thieves:
		t.out = true
		t.safe = true
	await ticks(2)
	check(m.phase == "over", "escapado: un momento quieto")
	await create_timer(Hud.HOLD_S + 0.05).timeout
	check(m.phase == "escaped", "luego, el periódico")
	await frames(3)
	await press(KEY_ESCAPE)
	await frames(3)
	check(m.phase == "generative" and m.hub.visible, "atrás desde el final: a configuración nueva")
	await press(KEY_ESCAPE)
	await frames(2)
	check(m.phase == "title" and m.hub.visible, "siguiente Esc vuelve al inicio nuevo")

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

	m._set_setting("size", size_was)
	m._set_setting("difficulty", difficulty_was)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
