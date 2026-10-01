class_name Hub
extends CanvasLayer
## La casa como punto de partida: un carril de pegatinas en vez del menú de
## tarjetas (Game._show_title), con la casa de verdad detrás en vez de un
## fondo decorativo. Lleva a las mismas pantallas reales de siempre
## (Game._story_players, ChallengeScreens.show_menu, Game._show_generative_menu,
## SettingsScreens.show, Hands.show_join, Game._pause/_start_playing/_ask_leave):
## esto no sustituye su lógica, solo cómo se eligen.
##
## También es la pausa real (Esc/P durante la partida) vista con la misma
## pinta: Game._pause() sigue siendo la que pausa de verdad (ver _process).
##
## Sin tecla propia para abrir/cerrar: al arrancar se muestra sola (como
## _show_title); jugando, ya está Esc/P. Así no choca con las que ya usa el
## juego (Hands.KB_LEFT incluye Tab, por ejemplo).

var host: Game

const STICKERS := "res://assets/ui/hub/"
const OPTIONS := [
	{"id": "dojo", "label": "Guarida", "sticker": "dojo.png"},
	{"id": "story", "label": "Modo Historia", "sticker": "historia.png"},
	{"id": "challenge", "label": "Retos", "sticker": "retos.png"},
	{"id": "generative", "label": "Atraco Sorpresa", "sticker": "generativo.png"},
	{"id": "settings", "label": "Ajustes", "sticker": "ajustes.png"},
	{"id": "quit", "label": "Salir", "sticker": "salir.png"},
]
const SETTINGS_OPTIONS := [
	{"id": "back", "label": "Volver", "sticker": "salir.png", "flip": true},
	{"id": "sound", "label": "Sonido", "sticker": "sonido.png"},
	{"id": "screen", "label": "Pantalla", "sticker": "pantalla.png"},
	{"id": "controls", "label": "Controles", "sticker": "controles.png"},
	{"id": "options", "label": "Opciones", "sticker": "opciones.png"},
]
## Los iconos de "cuántos jugadores" son los de siempre (assets/ui/ninjas_N.png,
## los mismos que usa _pick_players), no pegatinas nuevas.
const PLAYERS_OPTIONS := [
	{"id": "back", "label": "Volver", "sticker": "salir.png", "flip": true},
	{"id": "p1", "label": "1 Jugador", "res": "res://assets/ui/ninjas_1.png"},
	{"id": "p2", "label": "2 Jugadores", "res": "res://assets/ui/ninjas_2.png"},
	{"id": "p3", "label": "3 Jugadores", "res": "res://assets/ui/ninjas_3.png"},
	{"id": "p4", "label": "4 Jugadores", "res": "res://assets/ui/ninjas_4.png"},
]
const PAUSE_OPTIONS := [
	{"id": "resume", "label": "Seguir", "sticker": "pausa-reanudar.png"},
	{"id": "settings", "label": "Ajustes", "sticker": "ajustes.png"},
	{"id": "leave", "label": "Salir", "sticker": "salir.png"},
]

const CARD_W := 220.0
const CARD_H := 150.0
const GAP := 70.0
const TILT := -3.0
const SELECTED_SCALE := 1.6
const REST_SCALE := 0.74

var track: Control
var active := OPTIONS
var cards: Array = []
var cursor := 0
## "story" o "dojo" mientras el carril de PLAYERS_OPTIONS está abierto por
## su culpa; vacío el resto del tiempo.
var pending_mode := ""
## El índice en OPTIONS del que se salió al abrir un submenú (Ajustes o
## cuántos jugadores), para volver a la misma tarjeta, no siempre a la
## primera.
var options_cursor := 0
## Para que el stick mueva la selección una vez por empuje, no cada frame.
var _stick_side := 0.0


func _init(game: Game) -> void:
	host = game


func _ready() -> void:
	layer = 30  # bajo la portada (TitleScreen, 50), encima del juego.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## La pantalla de inicio: lo primero que ve el jugador, donde antes estaba
## _show_title(). Congela el movimiento (phase != "playing") hasta elegir.
func show_start() -> void:
	host.phase = "title"
	pending_mode = ""
	visible = true
	_fill_track(OPTIONS, false)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var screen := get_viewport().get_visible_rect().size

	var hint := Label.new()
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.position.y = screen.y * 0.18
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_override("font", Hud.ARCADE)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Hud.C.gold)
	hint.name = "Hint"
	add_child(hint)

	track = Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.position.y = screen.y / 2.0 - CARD_H / 2.0
	add_child(track)

	var foot := Label.new()
	foot.text = "← → para moverte  ·  aceptar para elegir"
	foot.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	foot.position.y = -screen.y * 0.16
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override("font_size", 12)
	foot.add_theme_color_override("font_color", Color("#8a8a9a"))
	add_child(foot)

	visible = false


## Rellena el carril con una lista de tarjetas (OPTIONS, SETTINGS_OPTIONS,
## PLAYERS_OPTIONS o PAUSE_OPTIONS), todas con el mismo estilo de pegatina:
## así cada pantalla a la que se llega se ve igual que esta, aunque por
## debajo sea la pantalla de texto real del juego.
func _fill_track(list: Array, animate := true, start := 0) -> void:
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
		var texture: Texture2D = load(opt.res) if opt.has("res") else load(STICKERS + opt.sticker)
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
	_select(start, animate)


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
			# _show_title; en su lugar, nuestro propio paso de "cuántos" con
			# los iconos reales, que para 2-4 lleva a la pantalla real de
			# asignar mandos/teclado (Hands.show_join) — la misma a la que
			# ya llevaba el menú de tarjetas.
			if active == OPTIONS:
				options_cursor = cursor
			pending_mode = id
			# PLAYERS_OPTIONS es [Volver, 1, 2, 3, 4]: su índice y el número
			# de jugadores coinciden, así que esto empieza en la banda de la
			# última vez, no siempre en Volver.
			_fill_track(PLAYERS_OPTIONS, true, host.players)
		"p1", "p2", "p3", "p4":
			var n := int(id.substr(1))
			var mode_id := pending_mode
			pending_mode = ""
			if n == 1 and mode_id == "dojo":
				# Ya estamos aquí, en solitario: solo falta soltar al
				# jugador a moverse, como SEGUIR en la pausa.
				visible = false
				host._start_playing()
			elif n == 1:
				_go(host._story_players.bind(1))
			else:
				_go(host.hands.show_join.bind(mode_id, n))
		"settings":
			# Mismo carril, otra lista: Sonido/Pantalla/Controles/Opciones
			# como pegatinas, no la pantalla de texto real.
			if active == OPTIONS:
				options_cursor = cursor
			_fill_track(SETTINGS_OPTIONS)
		"back":
			pending_mode = ""
			if active == PAUSE_OPTIONS:
				_pick("resume")  # Esc en la pausa siempre vuelve a jugar.
			else:
				var to := visible_before_settings()
				_fill_track(to, true, options_cursor if to == OPTIONS else 0)
		"challenge":
			# La pantalla real completa: lista de noches + mapas propios,
			# info de cada uno, 1-4 jugadores por mapa, y el editor entero
			# (crear/editar/probar/guardar/borrar/restaurar).
			_go(host.challenges.show_menu)
		"generative":
			# La pantalla real completa: dificultad/tamaño/tema/jugadores.
			_go(host._show_generative_menu)
		"resume":
			_go(host._start_playing)
		"leave":
			# El mismo SALIR real de la pausa: en modo práctica, sin
			# preguntar, vuelve a la ciudad/guarida de donde viniste; en los
			# demás modos pide confirmar con la pregunta real (ver
			# _process, quit_asking). No hay SALIR DEL JUEGO (cerrar del
			# todo) desde aquí todavía: si hace falta, desde el "Salir" del
			# título real al que esto te deja, si vienes de fuera de una
			# partida.
			_go(host._ask_leave)
		"sound":
			_go(host.options.show.bind("paused", "sound"))
		"screen":
			_go(host.options.show.bind("paused", "screen"))
		"controls":
			_go(host.options.show.bind("paused", "pads"))
		"options":
			_go(host.options.show.bind("paused", "options"))
		"quit":
			host._quit()


## "Volver" lleva al carril principal salvo dentro de la pausa, que vuelve a
## sus tres tarjetas (Seguir/Ajustes/Salir), no a las seis de siempre.
func visible_before_settings() -> Array:
	return PAUSE_OPTIONS if host.phase == "paused" else OPTIONS


## Cede el sitio a una pantalla real del juego: se esconde (esas llamadas
## dejan su propia `phase`) y le pasa el mando.
func _go(call: Callable) -> void:
	visible = false
	call.call()


## Esc/P durante la partida ya dispara la pausa real por su cuenta
## (Game._unhandled_input, intacto). No nos adelantamos a esa tecla: dejamos
## que `phase` pase a "paused" de verdad y, en cuanto lo vemos, escondemos su
## pantalla de texto y ponemos la nuestra encima — así funciona igual si la
## pausa la dispara el teclado, un mando, o cualquier otro sitio del juego.
func _process(_dt: float) -> void:
	if not host:
		return
	# quit_asking: hay una pregunta real de verdad (Sí/No, MENÚ o SALIR DEL
	# JUEGO) encima, sin salir de "paused" — la misma señal que usa el
	# juego real para lo mismo (Game._pause pone quit_asking a false al
	# reconstruir la pausa en sí). Mientras esté, nos apartamos: esa
	# pregunta no tiene todavía una versión en pegatinas.
	if host.phase == "paused" and not host.quit_asking and not visible:
		host.hud.hide_panel()
		host.hud.cctv(false)
		pending_mode = ""
		visible = true
		_fill_track(PAUSE_OPTIONS, false)
	elif visible and (host.phase not in ["title", "paused"] or host.quit_asking):
		# Otra pantalla real ha tomado el control (retos, ajustes,
		# generativo, unirse, una pregunta de verdad, un test que llama
		# directo a una de estas sin pasar por nosotros...): nos apartamos
		# para no comernos sus teclas.
		visible = false


func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_RIGHT, KEY_D:
				_select(cursor + 1)
				get_viewport().set_input_as_handled()
				return
			KEY_LEFT, KEY_A:
				_select(cursor - 1)
				get_viewport().set_input_as_handled()
				return
	elif e is InputEventJoypadButton and e.pressed and Pads.real(e.device):
		match e.button_index:
			JOY_BUTTON_DPAD_RIGHT:
				_select(cursor + 1)
				get_viewport().set_input_as_handled()
				return
			JOY_BUTTON_DPAD_LEFT:
				_select(cursor - 1)
				get_viewport().set_input_as_handled()
				return
	elif e is InputEventJoypadMotion and Pads.real(e.device) and e.axis == JOY_AXIS_LEFT_X:
		var side := signf(e.axis_value) if absf(e.axis_value) > 0.6 else 0.0
		if side != 0.0 and side != _stick_side:
			_select(cursor + int(side))
			get_viewport().set_input_as_handled()
		_stick_side = side
		return
	var what := MenuKeys.of(e)
	if what == "accept":
		_pick(active[cursor].id)
		get_viewport().set_input_as_handled()
	elif what == "back" and active != OPTIONS:
		_pick("back")
		get_viewport().set_input_as_handled()
