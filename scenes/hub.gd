class_name Hub
extends CanvasLayer
## Menú único de pegatinas: inicio, pausa y pantallas de configuración.
## Cada pantalla declara sus opciones, fase y destino de Volver/Esc.
## Los dioramas de los menús históricos están guardados fuera del juego activo.

var host: Game

const STICKERS := "res://assets/ui/hub/"
const OPTIONS := [
	{"id": "dojo", "label": "Guarida", "sticker": "dojo.png"},
	{"id": "story", "label": "Modo Historia", "sticker": "historia.png"},
	{"id": "challenge", "label": "Misiones", "sticker": "jugar-mapas.png"},
	{"id": "generative", "label": "Atraco Sorpresa", "sticker": "generativo.png"},
	{"id": "settings", "label": "Ajustes", "sticker": "ajustes.png"},
	{"id": "quit", "label": "Cerrar Ninja Karma", "sticker": "apagar.png"},
]
const SETTINGS_OPTIONS := [
	{"id": "back", "label": "Volver", "sticker": "volver.png"},
	{"id": "sound", "label": "Sonido", "sticker": "sonido.png"},
	{"id": "screen", "label": "Pantalla", "sticker": "pantalla.png"},
	{"id": "controls", "label": "Controles", "sticker": "controles.png"},
	{"id": "options", "label": "Opciones", "sticker": "opciones.png"},
]
## Los iconos de "cuántos jugadores" son los de siempre (assets/ui/ninjas_N.png,
## los mismos que usa _pick_players), no pegatinas nuevas.
const PLAYERS_OPTIONS := [
	{"id": "back", "label": "Volver", "sticker": "volver.png"},
	{"id": "p1", "label": "1 Jugador", "res": "res://assets/ui/ninjas_1.png"},
	{"id": "p2", "label": "2 Jugadores", "res": "res://assets/ui/ninjas_2.png"},
	{"id": "p3", "label": "3 Jugadores", "res": "res://assets/ui/ninjas_3.png"},
	{"id": "p4", "label": "4 Jugadores", "res": "res://assets/ui/ninjas_4.png"},
]
## En la guarida (modo práctica) no hay nada que perder: la pausa muestra el
## mismo carril entero de siempre, con Seguir en vez de Guarida (ya estás
## aquí). En medio de un golpe de verdad, solo lo seguro: Seguir, Ajustes y
## Salir (que sí confirma antes de abandonar progreso sin guardar).
const PAUSE_OPTIONS_FULL := [
	{"id": "resume", "label": "Seguir", "sticker": "pausa-reanudar.png"},
	{"id": "story", "label": "Modo Historia", "sticker": "historia.png"},
	{"id": "challenge", "label": "Misiones", "sticker": "jugar-mapas.png"},
	{"id": "generative", "label": "Atraco Sorpresa", "sticker": "generativo.png"},
	{"id": "settings", "label": "Ajustes", "sticker": "ajustes.png"},
	{"id": "leave", "label": "Salir", "sticker": "ciudad.png"},
	{"id": "quit_game", "label": "Cerrar Ninja Karma", "sticker": "apagar.png"},
]
const PAUSE_OPTIONS_SHORT := [
	{"id": "resume", "label": "Seguir", "sticker": "pausa-reanudar.png"},
	{"id": "settings", "label": "Ajustes", "sticker": "ajustes.png"},
	{"id": "leave", "label": "Salir", "sticker": "ciudad.png"},
	{"id": "quit_game", "label": "Cerrar Ninja Karma", "sticker": "apagar.png"},
]

const CARD_W := 220.0
const CARD_H := 150.0
const GAP := 70.0
const TILT := -3.0
const SELECTED_SCALE := 1.6
const REST_SCALE := 0.74

var track: Control
var active := OPTIONS
## Qué lista es `active`, en vez de comparar el array: "options", "settings",
## "players" o "pause" — así "Volver" y el contexto de "Guarida" saben dónde
## están sin depender de que dos arrays con el mismo contenido sean "iguales".
var active_kind := "options"
var cards: Array = []
var cursor := 0
## "story" o "dojo" mientras el carril de PLAYERS_OPTIONS está abierto por
## su culpa; vacío el resto del tiempo.
var pending_mode := ""
## El índice del que se salió al abrir un submenú (Ajustes o cuántos
## jugadores), y a qué carril volver ("options" o "pause"), para volver a la
## misma tarjeta, no siempre a la primera ni siempre al hub inicial.
var options_cursor := 0
var return_kind := "options"
## Para que el stick mueva la selección una vez por empuje, no cada frame.
var _stick_side := 0.0
var _stick_vertical := 0.0
var _screen_phase := "title"
var _back_action := Callable()
var _heading: Label
var _detail: Label
var _detail_scroll: ScrollContainer
var _foot: Label
var _track_tween: Tween
var _card_tweens: Array[Tween] = []
var _less: Button
var _more: Button
var _controls: ControlsDiagram


## Todos los menús interactivos usan este mismo carril de pegatinas.
## La pantalla conserva su fase de juego y declara adónde vuelve.
func show_screen(title: String, choices: Array, kind: String, phase: String, back: Callable, selected := 0) -> void:
	host.phase = phase
	if kind != "confirm":
		host.quit_asking = false
	_screen_phase = phase
	_back_action = back
	host.hud.hide_panel(true)
	host.hud.hide_gameplay()
	_stick_side = 0.0
	_stick_vertical = 0.0
	visible = true
	_heading.text = title
	# Esc / B returns through _back_action; no duplicate return sticker.
	var selected_id: String = choices[clampi(selected, 0, choices.size() - 1)].id
	var visible_choices := choices.filter(func(opt: Dictionary) -> bool: return opt.id != "back")
	var visible_selected := 0
	for i in visible_choices.size():
		if visible_choices[i].id == selected_id:
			visible_selected = i
	_fill_track(visible_choices, kind, false, visible_selected)
	_layout()


func show_pause() -> void:
	pending_mode = ""
	var choices: Array = (PAUSE_OPTIONS_FULL if host.mode == Practice.MODE else PAUSE_OPTIONS_SHORT).duplicate(true)
	if not host.pads_lost.is_empty():
		var lost: Array[String] = []
		for i in host.pads_lost:
			lost.append(Text.t("PAD_LOST") % (i + 1))
		choices[0].description = " · ".join(lost) + "\n" + Text.t("PAD_LOST_HOW")
	show_screen(Text.t("MENU_PAUSE"), choices, "pause", "paused", host._start_playing)


func _layout() -> void:
	if track == null:
		return
	var screen := get_viewport().get_visible_rect().size
	_heading.position = Vector2(20, screen.y * 0.08)
	_heading.size = Vector2(screen.x - 40, 36)
	_heading.add_theme_font_size_override("font_size", clampi(int((screen.x - 40) / maxi(1, _heading.text.length())), 10, 18))
	var diagram := _controls.visible
	var row_y := 0.22 if diagram else 0.44
	track.position.y = screen.y * row_y - CARD_H / 2.0
	_controls.position = Vector2(24, screen.y * 0.38)
	_controls.size = Vector2(screen.x - 48, screen.y * 0.53)
	_detail_scroll.visible = not diagram
	_detail_scroll.position = Vector2(24, screen.y * 0.77)
	_detail_scroll.size = Vector2(screen.x - 48, screen.y * 0.15)
	_foot.position = Vector2(10, screen.y - 28)
	_foot.size = Vector2(screen.x - 20, 22)
	var distance := minf(screen.x * 0.35, CARD_W * SELECTED_SCALE * 0.6)
	_less.position = Vector2(screen.x / 2.0 - distance - 24, screen.y * row_y - 24)
	_more.position = Vector2(screen.x / 2.0 + distance - 24, screen.y * row_y - 24)
	if not cards.is_empty():
		_select(cursor, false)


func set_preview(texture: Texture2D, description: String) -> void:
	if cards.is_empty():
		return
	cards[cursor].picture.texture = texture
	_detail.text = description


func _step_current(direction: int) -> void:
	var opt: Dictionary = active[cursor]
	if not opt.has("step"):
		return
	opt.label = opt.step.call(direction)
	cards[cursor].label.text = opt.label
	if opt.has("sticker_state"):
		opt.sticker = opt.sticker_state.call()
		cards[cursor].picture.texture = load(STICKERS + opt.sticker)
	host.sfx.ui("nav", 0.6)
	_layout()



func _init(game: Game) -> void:
	host = game


func _ready() -> void:
	layer = 30  # bajo la portada (TitleScreen, 50), encima del juego.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


## La pantalla de inicio: lo primero que ve el jugador, donde antes estaba
## _show_title(). Congela el movimiento (phase != "playing") hasta elegir.
func show_start(pick := "") -> void:
	pending_mode = ""
	host.house.menu_sight()
	var selected := 0
	for i in OPTIONS.size():
		if OPTIONS[i].id == pick:
			selected = i
	show_screen("", OPTIONS, "options", "title", Callable(), selected)


func _build() -> void:
	_heading = Label.new()
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading.add_theme_font_override("font", Hud.ARCADE)
	_heading.add_theme_font_size_override("font_size", 18)
	_heading.add_theme_color_override("font_color", Hud.C.gold)
	_heading.add_theme_constant_override("outline_size", 5)
	add_child(_heading)
	track = Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(track)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_detail_scroll)
	_detail = Label.new()
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_theme_font_size_override("font_size", 15)
	_detail.add_theme_constant_override("outline_size", 4)
	_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_scroll.add_child(_detail)
	_foot = Label.new()
	_foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_foot.add_theme_font_size_override("font_size", 13)
	_foot.add_theme_constant_override("outline_size", 4)
	_foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_foot)
	_less = _step_button("−", -1)
	_more = _step_button("+", 1)
	_controls = ControlsDiagram.new()
	_controls.visible = false
	add_child(_controls)
	get_viewport().size_changed.connect(_layout)
	visible = false
	_layout()


func _step_button(text: String, direction: int) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2(48, 48)
	button.add_theme_font_size_override("font_size", 36)
	button.add_theme_color_override("font_color", Hud.C.gold)
	button.pressed.connect(_step_current.bind(direction))
	add_child(button)
	return button


## Rellena el carril con una lista de tarjetas (OPTIONS, SETTINGS_OPTIONS,
## PLAYERS_OPTIONS o PAUSE_OPTIONS), todas con el mismo estilo de pegatina:
## así cada pantalla a la que se llega se ve igual que esta, aunque por
## debajo sea la pantalla de texto real del juego.
func _fill_track(list: Array, kind: String, animate := true, start := 0) -> void:
	if _track_tween:
		_track_tween.kill()
	for tween in _card_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_card_tweens.clear()
	active = list
	active_kind = kind
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
		var texture: Texture2D = opt.get("picture")
		if texture == null:
			texture = load(opt.res) if opt.has("res") else load(STICKERS + opt.get("sticker", "aceptar.png"))
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
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = CARD_W
		label.add_theme_font_size_override("font_size", 11 if String(opt.label).length() > 24 else 13)
		inner.add_child(label)
		# La pegatina completa también se puede elegir con el ratón.
		var click := Button.new()
		click.flat = true
		click.focus_mode = Control.FOCUS_NONE
		click.set_anchors_preset(Control.PRESET_FULL_RECT)
		click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var index := cards.size()
		click.pressed.connect(func() -> void:
			if active_kind != "join":
				if cursor == index:
					_pick(active[index].id)
				else:
					_select(index))
		card.add_child(click)
		track.add_child(card)
		cards.append({"container": card, "glow": glow, "label": label, "picture": picture, "centre_x": x + CARD_W / 2.0})
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
	if cards.is_empty():
		return
	if _track_tween:
		_track_tween.kill()
	cursor = posmod(i, cards.size())
	var centre: float = get_viewport().get_visible_rect().size.x / 2.0
	var target_x: float = centre - cards[cursor].centre_x
	if animate:
		_track_tween = create_tween()
		_track_tween.tween_property(track, "position:x", target_x, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	else:
		track.position.x = target_x
	for tween in _card_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_card_tweens.clear()
	var opt: Dictionary = active[cursor]
	var device: String = opt.get("controls_device", "")
	if _controls.visible != (device != ""):
		_controls.show_device(device)
		_layout()
		return
	_controls.show_device(device)
	_detail_scroll.scroll_vertical = 0
	_detail.text = opt.get("description", "")
	_less.visible = opt.has("step")
	_more.visible = opt.has("step")
	_foot.text = "← → para moverte · aceptar para elegir · Esc para volver"
	if device != "":
		_foot.text = "← → para ver controles y ajustes · Esc para volver"
	if opt.has("step"):
		_foot.text = "← → elegir ajuste · ↑ ↓ cambiar valor · aceptar aumentar · Esc volver"
	if active_kind == "join":
		_foot.text = Text.t("JOIN_UNDO")
	if opt.has("focus"):
		opt.focus.call()
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
	var selected_scale := 0.95 if _controls.visible else SELECTED_SCALE
	var scale_to := Vector2(selected_scale, selected_scale) if selected else Vector2(REST_SCALE, REST_SCALE)
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
	_card_tweens.append(tw)
	tw.set_parallel(true)
	tw.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "scale", scale_to, 0.3)
	tw.tween_property(card, "rotation", rot_to, 0.3)
	tw.tween_property(card, "modulate", dim_to, 0.22)
	tw.tween_property(c.glow, "modulate", glow_to, 0.3)


func _pick(id: String) -> void:
	for opt: Dictionary in active:
		if opt.id == id:
			if opt.has("step"):
				_step_current(1)
				return
			if opt.has("call"):
				_go(opt.call)
				return
	match id:
		"dojo":
			# Guarida entra directamente al salón con la banda actual.
			if active_kind == "pause":
				_pick("resume")
			else:
				_go(host._dojo_start.bind(host.players, true))
		"story":
			# Historia comparte el selector de banda con Guarida.
			_ask_players("story")
		"p1", "p2", "p3", "p4":
			var n := int(id.substr(1))
			var mode_id := pending_mode
			pending_mode = ""
			if n == 1 and mode_id == "dojo":
				_go(host._dojo_start.bind(1))
			elif n == 1:
				_go(host._story_players.bind(1))
			else:
				_go(host.hands.show_join.bind(mode_id, n))
		"settings":
			_go(host.options.show.bind("paused" if host.phase == "paused" else "title"))
		"back":
			pending_mode = ""
			if _back_action.is_valid():
				_go(_back_action)

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
			# Práctica vuelve directamente; un golpe pide confirmar.
			_go(host._ask_leave)
		"quit":
			host._quit()
		"quit_game":
			_go(host._ask_quit)


## El paso de "cuántos jugadores" para "which" (dojo o historia), desde el
## hub inicial o desde la pausa en la guarida (return_kind se acuerda de
## cuál, para que "Volver" sepa adónde).
func _ask_players(which: String) -> void:
	if active_kind in ["options", "pause"]:
		options_cursor = cursor
		return_kind = active_kind
	pending_mode = which
	# PLAYERS_OPTIONS es [Volver, 1, 2, 3, 4]: su índice y el número de
	# jugadores coinciden, así que esto empieza en la banda de la última vez.
	var origin := return_kind
	var back := func() -> void:
		if origin == "pause":
			show_pause()
		else:
			show_start(which)
	var choices: Array = PLAYERS_OPTIONS.duplicate(true)
	if which == "dojo":
		for n in range(1, 5):
			choices[n].description = Text.t("MENU_DOJO_BAND") % [n, Practice.open_trials(n).size(), DojoTrials.TABLE.size()]
	show_screen(Text.t("MENU_DOJO_HOW_MANY" if which == "dojo" else "MENU_HOW_MANY"), choices, "players", host.phase, back, host.players)


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
	if host.phase == "paused" and not host.quit_asking and not visible:
		show_pause()
	elif visible and (host.phase != _screen_phase or (host.quit_asking and active_kind != "confirm")):
		visible = false


func _unhandled_input(e: InputEvent) -> void:
	if not visible or host.phase != _screen_phase or active_kind == "join":
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match (e as InputEventKey).keycode:
			KEY_UP, KEY_W:
				_step_current(1)
				get_viewport().set_input_as_handled()
				return
			KEY_DOWN, KEY_S:
				_step_current(-1)
				get_viewport().set_input_as_handled()
				return
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
			JOY_BUTTON_DPAD_UP:
				_step_current(1)
				get_viewport().set_input_as_handled()
				return
			JOY_BUTTON_DPAD_DOWN:
				_step_current(-1)
				get_viewport().set_input_as_handled()
				return
			JOY_BUTTON_DPAD_RIGHT:
				_select(cursor + 1)
				get_viewport().set_input_as_handled()
				return
			JOY_BUTTON_DPAD_LEFT:
				_select(cursor - 1)
				get_viewport().set_input_as_handled()
				return
	elif e is InputEventJoypadMotion and Pads.real(e.device):
		var side := signf(e.axis_value) if absf(e.axis_value) > 0.6 else 0.0
		if e.axis == JOY_AXIS_LEFT_X:
			if side != 0.0 and side != _stick_side:
				_select(cursor + int(side))
			_stick_side = side
		elif e.axis == JOY_AXIS_LEFT_Y:
			if side != 0.0 and side != _stick_vertical:
				_step_current(-int(side))
			_stick_vertical = side
		else:
			return
		get_viewport().set_input_as_handled()
		return
	var what := MenuKeys.of(e)
	if active_kind in ["pause", "confirm"] and ((e is InputEventKey and e.pressed and e.keycode == KEY_P) or (e is InputEventJoypadButton and what == "skip")):
		_pick("back")
		get_viewport().set_input_as_handled()
	elif what == "accept" or (what == "skip" and e is InputEventJoypadButton):
		_pick(active[cursor].id)
		get_viewport().set_input_as_handled()
	elif what == "back" and _back_action.is_valid():
		_pick("back")
		get_viewport().set_input_as_handled()
	elif what in ["prev", "next"]:
		_detail_scroll.scroll_vertical += -36 if what == "prev" else 36
		get_viewport().set_input_as_handled()
