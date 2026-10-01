extends SceneTree
## Portada -> Dojo comparte la casa, desbloqueos y marcas con el escondite.
## Teclado/mando/ratón, banda 1–4 y salida según origen. Con -- render, QA
## local de portada normal y ventana pequeña/UI150 en /tmp/dojo-card-qa.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var game: Game

class TestPads extends Pads.Source:
	func connected() -> Array[int]:
		return [0, 1]
	func info(_device: int) -> Dictionary:
		return {"vendor_id": 1234, "product_id": 5678}

const W := Hud.SWAP_WAIT_FRAMES + 5


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func frames(n := W) -> void:
	for i in n:
		await process_frame


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
			key.keycode = k
			key.physical_keycode = k
			key.pressed = down
			e = key
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	await frames()


func click(button: Control) -> void:
	var at := button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.position = at
		e.global_position = at
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	await frames()


func join(n: int) -> void:
	for i in n:
		var e: InputEvent
		if i < 2:
			var key := InputEventKey.new()
			key.keycode = KEY_W if i == 0 else KEY_UP
			key.physical_keycode = key.keycode
			key.pressed = true
			e = key
		else:
			var pad := InputEventJoypadButton.new()
			pad.device = i - 2
			pad.button_index = JOY_BUTTON_A
			pad.pressed = true
			e = pad
		game.hands.joined_at = -INF
		game.hands.join_input(e)
		await frames()
	await create_timer(0.9).timeout
	await frames()


func layout(size: Vector2i, ui: int, label: String) -> void:
	root.size = size
	root.content_scale_size = size
	game.ui_scale = ui
	game.options.apply_ui_scale()
	game._show_title("dojo", false)
	await frames(12)
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var dojo: Control = game.hub.cards[game.hub.cursor].container
	check(screen.encloses(dojo.get_global_rect()), label + ": pegatina seleccionada visible")
	await hit("A")
	check(game.hub.active_kind == "players", label + ": A abre banda nueva")
	await frames(12)
	check(screen.encloses(game.hub.cards[game.hub.cursor].container.get_global_rect()), label + ": jugador seleccionado cabe")
	await hit("B")
	check(game.phase == "title" and game.hub.active[game.hub.cursor].id == "dojo", label + ": B vuelve a Guarida")


func _init() -> void:
	Pads.source = TestPads.new()
	Story.save = "user://test_dojo_card_progress.cfg"
	Settings.path = "user://test_dojo_card_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var settings := Settings.DEFAULTS.duplicate()
	settings.fullscreen = false
	settings.sound = false
	settings.music = false
	Settings.write(settings)
	if OS.get_cmdline_user_args().has("render"):
		DirAccess.make_dir_recursive_absolute("/tmp/dojo-card-qa")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	for c in game.get_children():
		if c is TitleScreen:
			c.queue_free()
	await frames()
	await layout(Vector2i(1280, 720), 100, "1280-ui100")
	await layout(Vector2i(960, 540), 150, "960-ui150")
	root.size = Vector2i(1280, 720)
	root.content_scale_size = root.size
	game.ui_scale = 100
	game.options.apply_ui_scale()
	game._show_title("dojo", false)
	await frames()
	await hit(KEY_ENTER)
	check(game.hub.active_kind == "players", "Enter abre selector nuevo")
	await hit(KEY_ESCAPE)
	check(game.hub.active[game.hub.cursor].id == "dojo", "Esc devuelve Guarida seleccionada")
	await click(game.hub.cards[game.hub.cursor].container)
	check(game.hub.active_kind == "players", "clic en pegatina abre selector")
	await hit(KEY_ESCAPE)
	check(Practice.open_trials(1).is_empty(), "banda nueva: pruebas bloqueadas por Historia")
	for n in range(1, 5):
		Story.unlock(n * 6, n)
		DojoTrials.record("atrapa", n, n + 2, true)
	for n in range(1, 5):
		var before := FileAccess.get_file_as_string(Story.save)
		var open := Practice.open_trials(n).map(func(t: Dictionary) -> String: return t.id)
		game._show_title("dojo")
		await frames()
		game.hub._select(n, false)
		check(game.hub._detail.text == "%dP · %d/%d" % [n, open.size(), DojoTrials.TABLE.size()], "banda%d: disponibilidad visible" % n)
		game.hub._pick("p%d" % n)
		if n > 1:
			check(game.phase == "join" and game.hands.join_for == "dojo", "banda%d: unión de controles" % n)
			game.hands.unjoin()
			await frames()
			check(game.hub.active_kind == "players" and game.hub.pending_mode == "dojo", "banda%d: cancelar unión vuelve Guarida" % n)
			game.hub._pick("p%d" % n)
			await join(n)
		await frames()
		check(game.phase == "playing" and game.mode == Practice.MODE and game.players == n and game.thieves.size() == n, "banda%d: práctica lista sin prólogo ni robo" % n)
		check(game.thieves.all(func(t: Thief) -> bool: return Den.room_at(t.x, t.y) == "dojo" and not Museum.blocks_move(t.x, t.y)), "banda%d: todos llegan al dojo sobre suelo libre" % n)
		check(Practice.open_trials(n).map(func(t: Dictionary) -> String: return t.id) == open and DojoTrials.best("atrapa", n) == n + 2, "banda%d: mismos desbloqueos y marcas" % n)
		check(FileAccess.get_file_as_string(Story.save) == before, "banda%d: entrar no altera progreso" % n)
		game._pause()
		check(game._leave_text() == Text.t("MENU_DOJO_LEAVE"), "banda%d: pausa anuncia portada" % n)
		game._ask_leave()
		await frames()
		check(game.phase == "title" and not paused and game.hub.visible and game.hub.active[game.hub.cursor].id == "dojo", "banda%d: pausa devuelve a card Dojo" % n)
		game._dojo_start(n, true)
		game.thieves[0].x = Den.EXIT.x + 0.5
		game.thieves[0].y = Den.EXIT.y + 0.5
		game.house.home_tick()
		await frames()
		check(game.phase == "title" and game.hub.visible and game.hub.active[game.hub.cursor].id == "dojo", "banda%d: puerta devuelve a card Dojo" % n)
	# Original access is still the house from the town, with its lounge spawn.
	game._show_city(CityStage.HIDEOUT)
	await frames()
	game._tour_practice()
	await frames()
	check(game.mode == Practice.MODE and not game.dojo_from_title and Den.room_at(game.thieves[0].x, game.thieves[0].y) == "salon", "escondite: entrada original al salón")
	check(game._leave_text() == Text.t("PRACTICE_LEAVE"), "escondite: pausa anuncia ciudad")
	game._pause()
	game._ask_leave()
	await frames()
	check(game.phase == "tour" and game.tour != null and game.tour.state == "city", "escondite: pausa vuelve ciudad")
	game._tour_practice()
	await frames()
	game.thieves[0].x = Den.EXIT.x + 0.5
	game.thieves[0].y = Den.EXIT.y + 0.5
	game.house.home_tick()
	await frames()
	check(game.phase == "tour" and game.tour.state == "city", "escondite: puerta vuelve ciudad")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
