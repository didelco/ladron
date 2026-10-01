extends SceneTree
## Contrato de navegación del menú único: teclado/mando, Esc y origen.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var m: Game
const ACCEPTS := [KEY_E, KEY_PERIOD, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, "A"]
const BACKS := [KEY_ESCAPE, KEY_BACKSPACE, "B"]

class TestPads extends Pads.Source:
	func connected() -> Array[int]: return [0]
	func info(_device: int) -> Dictionary: return {"vendor_id": 1234, "product_id": 5678}

func frames(n := 3) -> void:
	for i in n: await process_frame

func hit(k: Variant) -> void:
	for down in [true, false]:
		var e: InputEvent
		if k is String:
			var pad := InputEventJoypadButton.new()
			pad.device = 0
			pad.button_index = JOY_BUTTON_A if k == "A" else JOY_BUTTON_B
			pad.pressed = down
			e = pad
		else:
			var key := InputEventKey.new()
			key.keycode = k; key.physical_keycode = k; key.pressed = down
			e = key
		Input.parse_input_event(e); Input.flush_buffered_events()
		await process_frame
	await frames()

func select(id: String) -> void:
	for i in m.hub.active.size():
		if m.hub.active[i].id == id:
			m.hub._select(i, false)
			return
	qa.check(false, "opción accesible: " + id)

func hub(kind: String) -> bool:
	return m.hub.visible and m.hub.active_kind == kind and not m.hud._panel.visible

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Pads.source = TestPads.new()
	Story.save = "user://test_menus.cfg"
	Settings.path = "user://test_menus_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames()
	for c in m.get_children():
		if c is TitleScreen: c.queue_free()
	await frames()
	qa.check(hub("options") and Den.ORDER.all(func(id): return m.den_view.shows(id)), "arranque: menú nuevo, casa completa y ninguna capa antigua")
	for k in ACCEPTS:
		m._show_title("dojo", false)
		await hit(k)
		qa.check(hub("players") and m.hub.pending_mode == "dojo", str(k) + " abre jugadores de Guarida")
		await hit(KEY_ESCAPE)
		qa.check(hub("options") and m.hub.active[m.hub.cursor].id == "dojo", "Esc vuelve al modo seleccionado")
	for k in BACKS:
		m._show_title()
		await hit(k)
		qa.check(hub("options"), str(k) + " no sale del inicio")
	m._show_title("dojo", false)
	m.hub._pick("dojo")
	m.hub._pick("p1")
	await frames()
	qa.check(m.phase == "playing" and not m.hub.visible and m.dojo_from_title, "Guarida 1P juega y conserva origen de inicio")
	m._pause()
	qa.check(hub("pause") and paused and m.hub.active.size() == Hub.PAUSE_OPTIONS_FULL.size(), "Guarida: pausa completa nueva")
	m.hub._pick("leave")
	await frames()
	qa.check(hub("options") and not paused, "salir de Guarida vuelve al inicio nuevo, sin confirmación")
	for page in ["sound", "screen", "pads", "options"]:
		m.options.show("title", page)
		qa.check(hub("settings"), "ajustes " + page + " usa pegatinas")
		await hit(KEY_ESCAPE)
		qa.check(hub("settings") and m.options.settings_page == "", "Esc desde " + page + " vuelve a categorías")
		await hit(KEY_ESCAPE)
		qa.check(hub("options") and not paused, "Esc desde ajustes de inicio vuelve al inicio, sin pausar")
	m.options.show("title", "sound")
	select("sound")
	var sound_before := m.sound_on
	await hit(KEY_ENTER)
	qa.check(m.sound_on != sound_before and hub("settings"), "aceptar cambia el ajuste y mantiene la página")
	m.options.show("title", "sound")
	select("music_volume")
	m.music_volume = 50
	await hit(KEY_DOWN)
	qa.check(m.music_volume < 50, "abajo reduce el volumen")
	await hit(KEY_UP)
	qa.check(m.music_volume == 50, "arriba incrementa el volumen")
	for k in BACKS:
		m._show_generative_menu("difficulty")
		m._pick_setting("difficulty")
		await hit(k)
		qa.check(hub("generative") and m.hub.active[m.hub.cursor].id == "difficulty", "cancelar selector conserva categoría: " + str(k))
	for k in ACCEPTS:
		m._show_generative_menu("difficulty")
		m._pick_setting("difficulty")
		select("hard")
		await hit(k)
		qa.check(Sim.difficulty == "hard" and hub("generative"), "aceptar dificultad: " + str(k))
	m._pick_generative_players()
	select("p3")
	await hit(KEY_ENTER)
	qa.check(m.players == 3 and hub("generative"), "jugadores de Generativo se conservan")
	await hit(KEY_ESCAPE)
	qa.check(hub("options") and m.hub.active[m.hub.cursor].id == "generative", "Esc desde Generativo vuelve al inicio nuevo")
	m._show_title("story", false)
	m.hub._pick("story")
	m.hub._pick("p2")
	qa.check(hub("join") and m.phase == "join", "asignación multijugador usa menú nuevo")
	m.hands.joining.assign(["kb_left"])
	await hit(KEY_ESCAPE)
	qa.check(m.phase == "join" and m.hands.joining.is_empty(), "Esc en asignación quita el último asiento")
	await hit(KEY_ESCAPE)
	qa.check(hub("players") and m.hub.pending_mode == "story", "Esc sin asientos vuelve a jugadores nuevos")
	m.challenges.show_menu()
	qa.check(hub("challenges") and m.hub.active.any(func(o): return o.id == "night:25"), "Retos nuevos conserva las 25 noches editables")
	await hit(KEY_ESCAPE)
	qa.check(hub("options"), "Esc desde Retos vuelve al inicio nuevo")
	var map := MapFile.generated(4242, "small")
	m.challenges.show_map(map)
	qa.check(hub("challenge_map") and m.hub.active.any(func(o): return o.id == "p4"), "ficha de mapa conserva 1-4 jugadores")
	await hit(KEY_ESCAPE)
	qa.check(hub("challenges"), "Esc desde ficha vuelve a Retos")
	m.players = 1
	m.mode = "generative"
	m._new_round(1)
	m._start_playing()
	for k in BACKS:
		m._pause()
		await hit(k)
		qa.check(m.phase == "playing" and not paused and not m.hub.visible, "Esc/B reanuda la pausa: " + str(k))
	m._pause()
	m.hub._pick("settings")
	m.options.show("paused", "sound")
	await hit(KEY_ESCAPE)
	await hit(KEY_ESCAPE)
	qa.check(hub("pause") and m.hub.active.size() == Hub.PAUSE_OPTIONS_SHORT.size(), "ajustes de golpe vuelve a pausa corta")
	m.hub._pick("quit_game")
	qa.check(hub("confirm") and m.hub.cursor == 1, "cerrar juego pide confirmar con No seleccionado")
	await hit(KEY_ESCAPE)
	qa.check(hub("pause") and paused, "Esc cancela cerrar juego y conserva partida")
	m.hub._pick("leave")
	qa.check(hub("confirm") and m.quit_asking, "abandonar golpe usa confirmación nueva")
	await hit(KEY_ESCAPE)
	qa.check(hub("pause") and not m.quit_asking and paused, "Esc en confirmación cancela y conserva la partida")
	m.hub._pick("leave")
	select("yes")
	await hit(KEY_ENTER)
	qa.check(hub("generative") and not paused, "abandonar Generativo vuelve a configuración nueva")
	# El mapa de juego conserva su contrato: Esc cierra mapa y pausa.
	m.mode = "generative"
	m._new_round(1); m._start_playing(); m._toggle_map()
	await hit(KEY_ESCAPE)
	qa.check(not m.map_open and hub("pause"), "Esc desde mapa cierra mapa y abre pausa nueva")
	m._start_playing()
	# La tecla que acepta un menú sigue siendo acción/rodar durante el juego.
	for pair in [[KEY_E, "kb_left", 5], [KEY_PERIOD, "kb_right", 5], [KEY_SPACE, "kb_left", 6], [KEY_ENTER, "kb_right", 6]]:
		var e := InputEventKey.new()
		e.keycode = pair[0]; e.physical_keycode = pair[0]; e.pressed = true
		Input.parse_input_event(e); Input.flush_buffered_events()
		qa.check(m.hands.seat_input(pair[1], false)[pair[2]], "controles de juego intactos: " + str(pair[0]))
		e.pressed = false
		Input.parse_input_event(e); Input.flush_buffered_events()
	m.quit_hook = func() -> void: m.phase = "closed_for_test"
	m._pause()
	m.hub._pick("quit_game")
	select("yes")
	await hit(KEY_ENTER)
	qa.check(m.phase == "closed_for_test", "confirmar Salir del juego cierra aplicación")
	m._show_title()
	select("quit")
	await hit(KEY_ENTER)
	qa.check(m.phase == "closed_for_test", "Salir del inicio nuevo conserva cierre de aplicación")
	paused = false
	Pads.source = Pads.Source.new()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
