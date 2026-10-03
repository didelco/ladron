extends Node
## PROTOTIPO para probar "la casa como hub": te deja plantado en la casa DE
## VERDAD (el nivel 3D jugable, no el diorama de menú), empezando en el
## salón, listo para caminar con el mismo control que en el juego real.
##
## No toca ningún archivo del juego: lanza el propio Game (scenes/main.tscn)
## tal cual y entra en modo práctica con el spawn normal (Den.SPAWN, en el
## salón), en vez de mostrar el menú de tarjetas.
##   godot tests/visual/dojo_walk.tscn
## Movimiento: el del juego real (flechas/WASD, agacharse, rodar...).
## Arranca con el menú rápido ya abierto, el salón real detrás: así se vería
## encender el juego con este enfoque. Con el menú abierto el juego está en
## pausa y ← → mueven la selección (la tarjeta elegida crece y gira un poco
## cada vez que cambia), Enter/Espacio confirma, Tab lo cierra/abre.
## Cada tarjeta lleva de verdad a su sitio, sin huecos de funcionalidad frente
## al menú real: "Guarida" y "Modo Historia" abren un paso de "¿cuántos
## jugadores?" (con los iconos reales del juego); con 1 van directas, con 2-4
## abren la pantalla real de asignar mandos/teclado (Hands.show_join), el
## mismo sitio al que ya llevaba el menú de tarjetas. "Retos" y "Atraco
## Sorpresa" abren sus pantallas reales completas (lista de mapas + editor;
## dificultad/tamaño/tema/jugadores), no un atajo a un mapa o ajuste fijo.
## "Ajustes" abre un carril con el mismo estilo de pegatinas y cada una abre
## su pantalla de ajustes real. "Salir" cierra el prototipo. Una vez dentro
## de un modo real, su propia navegación (volver, pausa...) ya es la del
## juego de siempre, no la de este menú.

## docs/ lleva un .gdignore a propósito (no son assets del juego), así que
## se cargan directo del disco en vez de como recurso res://.
const STICKERS := "res://docs/propuestas/stickers-menu/"
const OPTIONS := [
	{"id": "dojo", "label": "Guarida", "sticker": "dojo.png"},
	{"id": "story", "label": "Modo Historia", "sticker": "historia.png"},
	{"id": "challenge", "label": "Retos", "sticker": "retos.png"},
	{"id": "generative", "label": "Atraco Sorpresa", "sticker": "generativo.png"},
	{"id": "settings", "label": "Ajustes", "sticker": "ajustes.png"},
	{"id": "quit", "label": "Salir", "sticker": "salir.png"},
]
const SETTINGS_OPTIONS := [
	# No hay sticker de "volver" en stickers-menu: se reutiliza el de salir,
	# volteado, para que la flecha apunte hacia atrás en vez de hacia fuera.
	{"id": "back", "label": "Volver", "sticker": "salir.png", "flip": true},
	{"id": "sound", "label": "Sonido", "sticker": "sonido.png"},
	{"id": "screen", "label": "Pantalla", "sticker": "pantalla.png"},
	{"id": "controls", "label": "Controles", "sticker": "controles.png"},
	{"id": "options", "label": "Opciones", "sticker": "opciones.png"},
]
## Los iconos de "cuántos jugadores" son del juego de verdad
## (assets/ui/ninjas_N.png, los mismos que usa _pick_players), no pegatinas
## del docs/: por eso llevan "res" en vez de "sticker".
const PLAYERS_OPTIONS := [
	{"id": "back", "label": "Volver", "sticker": "salir.png", "flip": true},
	{"id": "p1", "label": "1 Jugador", "res": "res://assets/ui/ninjas_1.png"},
	{"id": "p2", "label": "2 Jugadores", "res": "res://assets/ui/ninjas_2.png"},
	{"id": "p3", "label": "3 Jugadores", "res": "res://assets/ui/ninjas_3.png"},
	{"id": "p4", "label": "4 Jugadores", "res": "res://assets/ui/ninjas_4.png"},
]
## Lo que ve el jugador al pulsar Esc/P durante la partida: no es nuestro, es
## la pausa real (Game._pause(), scenes/main.gd:651) vista con la misma
## estética y filosofía que el resto — pegatinas por delante, pantallas
## reales por detrás (ver _process).
const PAUSE_OPTIONS := [
	{"id": "settings", "label": "Ajustes", "sticker": "ajustes.png"},
	{"id": "leave", "label": "Salir", "sticker": "salir.png"},
]

const CARD_W := 220.0
const CARD_H := 150.0
const GAP := 70.0

var game: Game
var overlay: CanvasLayer
var overlay_open := false
var track: Control
var active := OPTIONS
var cards: Array = []
var cursor := 0
## "story" o "dojo" mientras el carril de PLAYERS_OPTIONS está abierto por
## su culpa; vacío el resto del tiempo.
var pending_mode := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game = (preload("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	for c in game.get_children():
		if c is TitleScreen:
			c.queue_free()
	# Como _dojo_start, pero sin dojo_from_title: así el spawn es el de
	# siempre (Den.SPAWN, en el salón) en vez del de la entrada del dojo.
	game.mode = Practice.MODE
	game.players = 1
	game.seats = ["any"]
	game.pads_lost.clear()
	game.get_viewport().disable_3d = false
	game._new_round(1)
	game._start_countdown()
	_build_overlay()
	_toggle_overlay()
	if "autotest" in OS.get_cmdline_user_args():
		_autotest()


## Esc/P durante la partida ya dispara la pausa real por su cuenta
## (Game._unhandled_input, intacto: no lo tocamos). No intentamos adelantarnos
## a esa tecla; dejamos que `phase` pase a "paused" de verdad y, en cuanto lo
## vemos, escondemos su pantalla de texto y ponemos la nuestra encima — por
## eso esto funciona igual si la pausa la dispara el teclado, un mando o
## cualquier otro sitio del propio juego, no solo lo que nosotros cableamos.
func _process(_dt: float) -> void:
	if game and game.phase == "paused" and not overlay_open:
		game.hud.hide_panel()
		game.hud.cctv(false)
		pending_mode = ""
		overlay_open = true
		overlay.visible = true
		_fill_track(PAUSE_OPTIONS, false)


## Pasa por cada tarjeta y cada paso intermedio sin intervención, para
## comprobar que ninguno casca: godot tests/visual/dojo_walk.tscn -- autotest
func _autotest() -> void:
	# [id, ...] por paso; cada lista entera son las pulsaciones para llegar a
	# un sitio y volver al carril principal antes del siguiente paso.
	var steps := [
		["story", "p1"],
		["dojo", "p1"],
		["story", "p2"],  # ejercita Hands.show_join de verdad
		["dojo", "p3"],
		["challenge"],
		["generative"],
		["settings", "sound"],
		["settings", "screen"],
		["settings", "controls"],
		["settings", "options"],
	]
	for step in steps:
		await get_tree().create_timer(0.3, true, false, true).timeout
		if not overlay_open:
			_toggle_overlay()
			await get_tree().create_timer(0.1, true, false, true).timeout
		if active != OPTIONS:
			pending_mode = ""
			_fill_track(OPTIONS, false)
		for id in step:
			print("[autotest] -> ", id)
			_pick(id)
			await get_tree().create_timer(0.15, true, false, true).timeout

	# La pausa real (Esc/P) no pasa por _pick: la dispara el propio Game.
	# La probamos disparándola igual que lo haría el teclado, y comprobamos
	# que _process la viste con PAUSE_OPTIONS.
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("[autotest] -> pause real (Game._pause)")
	game._pause()
	await get_tree().create_timer(0.3, true, false, true).timeout
	print("[autotest]    active == PAUSE_OPTIONS? ", active == PAUSE_OPTIONS)
	print("[autotest] -> resume")
	game._start_playing()
	await get_tree().create_timer(0.2, true, false, true).timeout
	print("[autotest]    game.phase == playing? ", game.phase == "playing")

	await get_tree().create_timer(0.3, true, false, true).timeout
	print("[autotest] -> quit")
	_pick("quit")


func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 60
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)

	var screen := get_viewport().get_visible_rect().size

	var hint := Label.new()
	hint.text = "MENÚ RÁPIDO  ·  superpuesto, la casa sigue detrás"
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position.y = screen.y * 0.18
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", Hud.ARCADE)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Hud.C.gold)
	overlay.add_child(hint)

	# Un carril horizontal que luego se desliza entero (track.position.x) para
	# dejar siempre la tarjeta elegida en el centro de la pantalla, en vez de
	# una fila fija: cada tarjeta ocupa un hueco propio en línea.
	track = Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.position.y = screen.y / 2.0 - CARD_H / 2.0
	overlay.add_child(track)

	var foot := Label.new()
	foot.text = "← → para moverte  ·  Enter/Espacio para elegir  ·  Tab para cerrar"
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.position.y = -screen.y * 0.16
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color("#8a8a9a"))
	overlay.add_child(foot)

	overlay.visible = false
	_fill_track(OPTIONS, false)


## Rellena el carril con una lista de tarjetas (OPTIONS o SETTINGS_OPTIONS),
## todas con el mismo estilo de pegatina: así "Ajustes" se ve como el menú
## de siempre, no como la pantalla de texto real.
func _fill_track(list: Array, animate := true) -> void:
	active = list
	for c in track.get_children():
		c.queue_free()
	cards.clear()
	var x := 0.0
	for opt in list:
		# Nada de caja detrás: las pegatinas ya traen su propio borde blanco
		# y sombra. Lo que marca la elegida es un resplandor circular difuso
		# (un degradado, no otra copia del sticker) más el tamaño y la
		# inclinación, no un panel rectangular compitiendo con el dibujo.
		var card := Control.new()
		card.position = Vector2(x, 0)
		card.size = Vector2(CARD_W, CARD_H)
		card.pivot_offset = Vector2(CARD_W / 2.0, CARD_H / 2.0)
		var texture: Texture2D = load(opt.res) if opt.has("res") else _load_sticker(opt.sticker)
		var glow := TextureRect.new()
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.texture = _glow_texture()
		glow.modulate = Color(Hud.C.gold, 0.0)
		var glow_size := Vector2(CARD_W, CARD_W) * 1.15
		glow.size = glow_size
		glow.position = Vector2(CARD_W, CARD_H - 30.0) / 2.0 - glow_size / 2.0
		card.add_child(glow)
		var inner := VBoxContainer.new()
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner.add_theme_constant_override("separation", 6)
		card.add_child(inner)
		var picture := TextureRect.new()
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(CARD_W - 24.0, CARD_H - 54.0)
		picture.texture = texture
		picture.flip_h = opt.get("flip", false)
		inner.add_child(picture)
		var label := Label.new()
		label.text = opt.label
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font", Hud.ARCADE)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_color_override("font_outline_color", Color("#2a150c"))
		inner.add_child(label)
		track.add_child(card)
		cards.append({"container": card, "glow": glow, "label": label, "centre_x": x + CARD_W / 2.0})
		x += CARD_W + GAP
	_select(0, animate)


func _load_sticker(file: String) -> ImageTexture:
	var img := Image.new()
	img.load(ProjectSettings.globalize_path(STICKERS + file))
	return ImageTexture.create_from_image(img)


var _glow_cache: GradientTexture2D


## Un círculo difuminado (blanco, de borde a nada) para teñir y usar de
## resplandor: no es una imagen, es un degradado, así no "dobla" el sticker.
func _glow_texture() -> GradientTexture2D:
	if _glow_cache:
		return _glow_cache
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 256
	t.height = 256
	_glow_cache = t
	return t


func _select(i: int, animate := true) -> void:
	cursor = posmod(i, cards.size())
	var centre: float = get_viewport().get_visible_rect().size.x / 2.0
	var target_x: float = centre - cards[cursor].centre_x
	if animate:
		var tw := create_tween()
		tw.tween_property(track, "position:x", target_x, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	else:
		track.position.x = target_x
	for j in cards.size():
		_animate_card(cards[j], j == cursor, animate)
		cards[j].label.add_theme_color_override("font_color",
			Hud.GLOW_TEXT if j == cursor else Color("#9b93b0"))


const TILT := -3.0
const SELECTED_SCALE := 1.6
const REST_SCALE := 0.74


## Crece con un asiento elegante (un solo tramo, sin bamboleo) y queda con una
## leve inclinación de pegatina; detrás asoma un halo dorado (no una caja) y
## las demás se quedan atrás, más pequeñas y apagadas, para que destaque sola.
func _animate_card(c: Dictionary, selected: bool, animate: bool) -> void:
	var card: Control = c.container
	card.z_index = 5 if selected else 0
	var scale_to := Vector2(SELECTED_SCALE, SELECTED_SCALE) if selected else Vector2(REST_SCALE, REST_SCALE)
	var rot_to := deg_to_rad(TILT) if selected else 0.0
	var dim_to := Color(1, 1, 1, 1.0) if selected else Color(1, 1, 1, 0.55)
	var glow_to := Color(Hud.C.gold, 0.55 if selected else 0.0)
	if not animate:
		card.scale = scale_to
		card.rotation = rot_to
		card.modulate = dim_to
		c.glow.modulate = glow_to
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", scale_to, 0.3)
	tw.tween_property(card, "rotation", rot_to, 0.3)
	tw.tween_property(card, "modulate", dim_to, 0.22)
	tw.tween_property(c.glow, "modulate", glow_to, 0.3)


func _pick(id: String) -> void:
	match id:
		"dojo", "story":
			# _pick_players(which) abriría un bubble anclado a la tarjeta de
			# _show_title, que aquí no existe (hud.pop_bubble busca
			# hud._cards y, si no la encuentra, no casca: se queda sin abrir
			# nada). En vez de eso, nuestro propio paso de "cuántos" con los
			# iconos reales, que para 2-4 lleva a la pantalla real de
			# asignar mandos/teclado (Hands.show_join) — la misma a la que
			# ya llevaba el menú de tarjetas.
			pending_mode = id
			_fill_track(PLAYERS_OPTIONS)
		"p1", "p2", "p3", "p4":
			var n := int(id.substr(1))
			var mode_id := pending_mode
			pending_mode = ""
			if n == 1 and mode_id == "dojo":
				_toggle_overlay()  # ya estamos aquí, en solitario.
			elif n == 1:
				_go(game._story_players.bind(1))
			else:
				_go(game.hands.show_join.bind(mode_id, n))
		"settings":
			# Mismo carril, otra lista: Sonido/Pantalla/Controles/Opciones
			# como pegatinas, no la pantalla de texto real.
			_fill_track(SETTINGS_OPTIONS)
		"back":
			pending_mode = ""
			_fill_track(OPTIONS)
		"challenge":
			# La pantalla real completa: lista de noches + mapas propios,
			# info de cada uno, 1-4 jugadores por mapa, y el editor entero
			# (crear/editar/probar/guardar/borrar/restaurar). Nada de
			# forzar un mapa fijo a 1 jugador.
			_go(game.challenges.show_menu)
		"generative":
			# La pantalla real completa: dificultad/tamaño/tema/jugadores,
			# no la última configuración guardada en disco a 1 jugador.
			_go(game._show_generative_menu)
		"leave":
			# El mismo SALIR real de la pausa en modo práctica (main.gd:680):
			# sin confirmación, vuelve a la ciudad/guarida de donde viniste.
			_go(game._ask_leave)
		"sound":
			_go(game.options.show.bind("paused", "sound"))
		"screen":
			_go(game.options.show.bind("paused", "screen"))
		"controls":
			_go(game.options.show.bind("paused", "pads"))
		"options":
			_go(game.options.show.bind("paused", "options"))
		"quit":
			get_tree().quit()


## Cede el sitio a una pantalla real del juego (historia, retos, generativo,
## ajustes): cierra nuestro overlay sin tocar `phase` (esas llamadas ya
## dejan la suya propia) y le pasa el mando.
func _go(call: Callable) -> void:
	overlay_open = false
	overlay.visible = false
	call.call()


func _toggle_overlay() -> void:
	# get_tree().paused no sirve aquí: Game se pone a sí mismo en
	# PROCESS_MODE_ALWAYS (scenes/main.gd:171, para su propia pausa) y arrastra
	# a sus hijos, así que ignora la pausa del árbol. El juego real para el
	# movimiento con `phase` (night_loop.gd:38/46, main.gd:1265): "playing" es
	# lo único que mueve a los thieves, así que hacemos lo mismo que el menú
	# de ajustes real al abrirse (settings_screens.gd:29).
	overlay_open = not overlay_open
	overlay.visible = overlay_open
	game.phase = "settings" if overlay_open else "playing"
	if not overlay_open and active != OPTIONS:
		pending_mode = ""
		_fill_track(OPTIONS, false)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var key := (e as InputEventKey).keycode
	if key == KEY_TAB:
		_toggle_overlay()
		return
	if not overlay_open:
		return
	match key:
		KEY_RIGHT, KEY_D:
			_select(cursor + 1)
		KEY_LEFT, KEY_A:
			_select(cursor - 1)
		KEY_ENTER, KEY_SPACE:
			_pick(active[cursor].id)
