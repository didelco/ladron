extends SceneTree
## Todos los caminos a Ajustes llevan al mismo carril de categorías, y Volver
## devuelve al sitio de origen (inicio o pausa, en la guarida y en un golpe).
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var m: Game

func frames(n := 3) -> void:
	for i in n: await process_frame

func hit(k: Key) -> void:
	for down in [true, false]:
		var key := InputEventKey.new()
		key.keycode = k; key.physical_keycode = k; key.pressed = down
		Input.parse_input_event(key); Input.flush_buffered_events()
		await process_frame
	await frames()

func select(id: String) -> void:
	for i in m.hub.active.size():
		if m.hub.active[i].id == id:
			m.hub._select(i, false)
			return
	qa.check(false, "opción accesible: " + id)

## El carril de categorías: Ajustes sin página, con Sonido, Pantalla, Controles y Opciones.
func is_rail(what: String) -> void:
	var ids: Array = m.hub.active.map(func(o): return o.id)
	qa.check(m.hub.visible and m.hub.active_kind == "settings" and m.options.settings_page == "" and ids == ["sound", "screen", "controls", "options"], what + ": carril de categorías (" + str(ids) + ", página '" + m.options.settings_page + "')")

func into(page: String) -> void:
	select(page)
	await hit(KEY_ENTER)
	qa.check(m.hub.active_kind == "settings" and m.options.settings_page == ("pads" if page == "controls" else page), "entra en la categoría " + page)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Story.save = "user://test_ajustes_entradas.cfg"
	Settings.path = "user://test_ajustes_entradas_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames()
	for c in m.get_children():
		if c is TitleScreen: c.queue_free()
	await frames()

	# 1. Desde el inicio, tras visitar una categoría antes.
	for page in ["sound", "screen", "controls", "options"]:
		m._show_title("settings", false)
		await frames()
		m.hub._pick("settings")
		is_rail("inicio")
		await into(page)
		await hit(KEY_ESCAPE)
		is_rail("inicio, volver de " + page)
		await hit(KEY_ESCAPE)
		qa.check(m.hub.active_kind == "options" and m.phase == "title", "inicio: Volver del carril vuelve al inicio")
	# Entrada nueva tras dejar recordada una página.
	m.options.show("title", "sound")
	m._show_title("settings", false)
	m.hub._pick("settings")
	is_rail("inicio con página recordada")

	# 2. Desde la pausa en la guarida.
	m._show_title("dojo", false)
	m.hub._pick("dojo")
	await frames()
	m.options.show("paused", "sound")  # visita previa
	m._pause()
	await frames()
	m.hub._pick("settings")
	is_rail("pausa en la guarida")
	await into("screen")
	await hit(KEY_ESCAPE)
	is_rail("pausa en la guarida, volver de categoría")
	await hit(KEY_ESCAPE)
	qa.check(m.hub.active_kind == "pause" and m.hub.active.size() == Hub.PAUSE_OPTIONS_FULL.size(), "pausa guarida: Volver vuelve a la pausa")

	# 3. Desde la pausa en un golpe.
	m.mode = "generative"
	m._pause()
	await frames()
	m.hub._pick("settings")
	is_rail("pausa en un golpe")
	await into("sound")
	await hit(KEY_N)  # silenciar reconstruye la pantalla sin salir de la página
	qa.check(m.options.settings_page == "sound", "N en una categoría la reconstruye en su sitio")
	await hit(KEY_ESCAPE)
	is_rail("pausa en un golpe, volver de categoría")
	await hit(KEY_ESCAPE)
	qa.check(m.hub.active_kind == "pause" and m.hub.active.size() == Hub.PAUSE_OPTIONS_SHORT.size(), "pausa golpe: Volver vuelve a la pausa corta")

	# 4. N en el propio carril lo mantiene.
	m.hub._pick("settings")
	await hit(KEY_N)
	is_rail("N en el carril")

	# 5. La entrada única (open) ignora la página recordada y el origen se deduce.
	m.options.show("title", "screen")
	m.options.open("title")
	is_rail("open('title') con página recordada")
	m._show_title("dojo", false)
	m.options.show("title", "options")
	m.options.open()
	qa.check(m.options.settings_from == "title" and m.options.settings_page == "", "open() sin origen, en el inicio, vuelve al inicio")
	m.mode = "generative"
	m._pause()
	await frames()
	m.options.show("paused", "pads")
	m.options.open()
	qa.check(m.options.settings_from == "paused" and m.options.settings_page == "", "open() sin origen, en la pausa, vuelve a la pausa")
	is_rail("open() en la pausa")
	quit(qa.summary())
