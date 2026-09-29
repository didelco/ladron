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
	check(m.phase == "pick", "una pulsación nueva mientras se va llega al menú: no se pierde")

	# --- How many thieves: a bubble out of the mode's card ----------------------------
	var story_card: Control = hud._cards["story"]
	await frames(Hud.SWAP_WAIT_FRAMES + 1)
	check(hud.bubble_open() and m.phase == "pick", "elegir la historia abre el bocadillo de cuántos ladrones")
	check(hud.bubble_focus() == m.players - 1, "... con el foco en la banda de la última vez")
	check(hud._panel_box.modulate.a == 1.0 and story_card.modulate == Color.WHITE, "... sin apagar el título ni la tarjeta de la que sale")
	var box: Rect2 = hud._bubble_box.get_global_rect()
	check(absf(box.get_center().x - story_card.get_global_rect().get_center().x) < 2.0 and box.position.y >= story_card.get_global_rect().end.y, "... debajo de su tarjeta")
	await press(KEY_RIGHT)
	await frames()
	check(hud.bubble_focus() == m.players % 4, "las flechas van por el bocadillo")
	await press(KEY_A)
	await frames()
	check(hud.bubble_focus() == m.players - 1, "... y A y D también (el jugador de la izquierda)")
	# Stickers, not 3D: the one with the focus in colour, the rest dark.
	await create_timer(Hud.SWAP_S + 0.1).timeout
	var flat := true
	var lit_ok := true
	for i in hud._bubble_buttons.size():
		var b: Button = hud._bubble_buttons[i]
		if not b.find_children("*", "SubViewport", true, false).is_empty():
			flat = false
		var icons := b.find_children("*", "TextureRect", true, false)
		var lit: float = (icons[0] as TextureRect).material.get("shader_parameter/lit") if icons.size() > 0 else -1.0
		if lit != (1.0 if i == hud.bubble_focus() else 0.0):
			lit_ok = false
	check(flat, "... pegatinas 2D, sin escenas 3D")
	check(lit_ok, "... la elegida encendida, las demás apagadas")
	await press(KEY_ESCAPE)
	await frames(2)
	check(m.phase == "title" and not hud.bubble_open(), "atrás cierra el bocadillo, en el título")
	check(focused() == story_card, "... con el foco en la historia, donde estaba")
	await press(KEY_ESCAPE)
	await frames(2)
	check(m.phase == "title", "... y otro atrás en el título no hace nada")
	# A click off the bubble closes it too.
	await press(KEY_E)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(8, 8)
	hud._bubble.gui_input.emit(click)
	await frames(2)
	check(m.phase == "title" and not hud.bubble_open() and focused() == story_card, "un clic fuera del bocadillo lo cierra")
	# Picking goes straight on: two thieves, to say whose controls are whose.
	await press(KEY_E)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	await press(KEY_2)
	await frames(2)
	check(m.phase == "join" and m.hands.join_for == "story" and m.hands.join_count == 2, "elegir 2 en el bocadillo va directo a los mandos de la historia")
	m.hands.unjoin()
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(m.phase == "pick" and hud.bubble_open() and hud.bubble_focus() == 1, "atrás desde los mandos vuelve al bocadillo, en el 2")
	# The generative: its bubble, then its menu with the gang picked.
	await press(KEY_ESCAPE)
	await frames(2)
	m._show_title()
	await frames(3)
	(hud._cards["generative"] as Button).pressed.emit()
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(m.phase == "pick" and hud._bubble_anchor == hud._cards["generative"], "el generativo abre su bocadillo en su tarjeta")
	hud.bubble_pick(2)
	await frames(3)
	check(m.phase == "generative" and m.players == 3 and not hud.bubble_open(), "elegir 3 lleva al menú del generativo, con 3 ladrones")
	await press(KEY_ESCAPE)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(m.phase == "pick" and hud.bubble_focus() == 2 and hud._bubble_anchor == hud._cards["generative"], "atrás desde el generativo vuelve a su bocadillo, en el 3")
	hud.bubble_pick(0)
	await frames(3)
	check(m.phase == "generative" and m.players == 1, "... y se puede cambiar a 1")

	# --- The generative's settings: two cards, each with its bubble ------------------
	# (The size and difficulty picked are saved: put back as they were at the end.)
	var size_was: String = m.size
	var difficulty_was: String = Sim.difficulty
	m._set_setting("difficulty", "medium")
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	m._show_generative_menu()
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	var start_button := focused() as Button
	check(start_button != null and start_button.text == Text.t("MENU_START"), "el generativo empieza con el foco en EMPEZAR")
	check(hud._cards.size() == 2 and hud._cards.has("difficulty") and hud._cards.has("size"), "... y dos tarjetas: dificultad y tamaño")
	var rims: Array = hud._cards.values().map(func(c): return ((c as Button).get_theme_stylebox("normal") as StyleBoxFlat).border_color)
	check(rims.all(func(r): return r == Hud.GLASS_EDGE), "... con el borde de siempre, sin colores de la elegida")
	var hard_card: Button = hud._cards["difficulty"]
	check(hard_card.find_children("*", "Label", true, false).any(func(l): return (l as Label).text == Text.t("MENU_DIFFICULTY_MEDIUM")), "... la de dificultad dice la que hay")
	hard_card.grab_focus()
	await frames()
	await press(KEY_E)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(m.phase == "pick" and hud._bubble_anchor == hard_card and hud._bubble_buttons.size() == 3, "pulsar la dificultad abre su bocadillo, con tres")
	check(hud.bubble_focus() == 1, "... con el foco en la que hay (media)")
	var stills: Array = hud._bubble.find_children("*", "MenuStage", true, false)
	check(stills.size() == 3 and stills.all(func(s): return not (s as MenuStage).active), "... cada una en su diorama, quieto")
	await press(KEY_4)
	await frames(2)
	check(m.phase == "pick" and hud.bubble_open(), "el 4 no hace nada en un bocadillo de tres")
	await press(KEY_ESCAPE)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(m.phase == "generative" and not hud.bubble_open() and focused() == hard_card and Sim.difficulty == "medium", "Esc lo cierra sin cambiar nada, con el foco en su tarjeta")
	await press(KEY_E)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	await press(KEY_D)
	await frames()
	await press(KEY_E)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(Sim.difficulty == "hard" and m.phase == "generative" and not hud.bubble_open(), "D y E: la difícil, elegida")
	hard_card = hud._cards["difficulty"]
	check(focused() == hard_card, "... el foco vuelve a su tarjeta")
	check(hard_card.find_children("*", "Label", true, false).any(func(l): return (l as Label).text == Text.t("MENU_DIFFICULTY_HARD")), "... que ya dice la difícil")
	var cards: Array = hud._panel_box.find_children("*", "Button", true, false)
	check(cards.all(func(b): return (b as Control).modulate.a > 0.0) and hud._panel_box.modulate.a == 1.0, "... y el menú está entero, sin fundirse")
	(hud._cards["size"] as Button).pressed.emit()
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(m.phase == "pick" and hud._bubble_anchor == hud._cards["size"], "el tamaño abre su bocadillo en su tarjeta")
	await press(KEY_3)
	await frames(Hud.SWAP_WAIT_FRAMES + 2)
	check(m.size == "large" and focused() == hud._cards["size"], "el 3: el grande, con el foco en su tarjeta")
	# Down from the difficulty: EMPEZAR, under it (VOLVER is under the size).
	(hud._cards["difficulty"] as Button).grab_focus()
	await frames()
	await press(KEY_DOWN)
	await frames()
	check(focused() is Button and (focused() as Button).text == Text.t("MENU_START"), "abajo desde la dificultad: EMPEZAR")
	await press(KEY_E)
	await frames(3)
	check(m.phase == "brief" and m.mode == "generative" and m.players == 1, "EMPEZAR: a la previa del golpe, con 1 ladrón")

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
	check(m.phase == "countdown" and hud._count_left == Hud.COUNT_S * Hud.COUNT.size(), "otras pulsaciones no la reinician ni la saltan")
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
	await press(KEY_E)
	await frames(3)
	check(m.phase == "brief" and m.briefing.brief_page == mini(1, m.briefing.pages().size() - 1), "la siguiente pulsación, una página más")

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

	m._set_setting("size", size_was)
	m._set_setting("difficulty", difficulty_was)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("FALLOS: %d" % fails)
	quit(1 if fails else 0)
