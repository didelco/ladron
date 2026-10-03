extends SceneTree
## Legibilidad y acceso a todas las opciones con ventana pequeña / UI 150%.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var game: Game

func frames(n := 5) -> void:
	for i in n: await process_frame

func selected_visible(label: String) -> void:
	await frames()
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var card: Control = game.hub.cards[game.hub.cursor].container
	qa.check(screen.encloses(card.get_global_rect()), label + ": pegatina seleccionada cabe")
	qa.check(screen.encloses(game.hub._detail_scroll.get_global_rect()), label + ": descripción accesible con scroll")
	qa.check(not game.hud._panel.visible, label + ": no aparece fondo de menú antiguo")
	qa.check(not game.hud._gang.visible, label + ": retratos del juego no tapan el menú")

func no_menu_dioramas(node: Node) -> bool:
	if node is MenuStage: return false
	for child in node.get_children():
		if not no_menu_dioramas(child): return false
	return true

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Story.save = "user://test_menu_clarity.cfg"
	Settings.path = "user://test_menu_clarity_settings.cfg"
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	for c in game.get_children():
		if c is TitleScreen: c.queue_free()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	root.content_scale_size = root.size
	game.ui_scale = 150
	game.options.apply_ui_scale()
	await frames()
	game._show_title("dojo", false)
	await selected_visible("inicio")
	game.hub._ask_players("dojo")
	await selected_visible("jugadores")
	for page in ["sound", "screen", "pads", "options"]:
		game.options.show("title", page)
		for i in game.hub.active.size():
			game.hub._select(i, false)
			await selected_visible(page + ": " + game.hub.active[i].id)
	game._show_generative_menu()
	await selected_visible("generativo")
	for which in ["difficulty", "size", "theme"]:
		game._pick_setting(which)
		for i in game.hub.active.size():
			game.hub._select(i, false)
			await selected_visible(which + ": " + game.hub.active[i].id)
		game.hub._pick("back")
	for key in Game.THEME_NAMES:
		game._pick_setting("theme")
		game.hub._pick(key)
		await frames()
		qa.check(game.theme == key and game.phase == "generative", "elegir tema actualiza la configuración: " + key)
		qa.check(game.hub.cards[game.hub.cursor].picture.texture == Game._theme_picture(key), "usa imagen estática del tema: " + key)
	qa.check(no_menu_dioramas(game.hub), "los menús nuevos no instancian dioramas antiguos")
	if not game.dev_mode:
		game.options.step(0, "dev_mode")
	game.challenges.show_menu()
	var longest := 1
	for n in range(1, Story.count() + 1):
		if game.challenges.night_name(n).length() > game.challenges.night_name(longest).length(): longest = n
	for i in game.hub.active.size():
		if game.hub.active[i].id == "night:%d" % longest:
			game.hub._select(i, false)
			break
	await selected_visible("Misiones")
	qa.check(game.hub._detail.text.contains(game.challenges.night_name(longest)), "Misiones conserva nombre completo en descripción")
	game.hands.show_join("story", 4)
	await selected_visible("asignación 4P")
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
