extends SceneTree
## La previa de la historia como una sola escena (Tour): la ciudad en 3D con
## sus museos abiertos y cerrados, entrar en uno, elegir sala, el plano que
## sale de ella y lo que se cuenta encima, explorarlo e ir al robo; la
## vuelta al museo tras el robo, a la ciudad tras un gran golpe, y el plano
## que ya no se cuenta al repetir. Con uno y con dos ladrones.
var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1


func frames(n := 4) -> void:
	for i in n:
		await process_frame


func key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = true
	return e


func pad(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = b
	e.pressed = true
	return e


func _init() -> void:
	# Nothing here is saved where the player keeps the story.
	Story.save = "user://test_previa.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.tour_hurry = true

	# The first time: the tale, then the town.
	m._story_gang(1)
	check(m.phase == "prologue", "la primera vez, el prólogo")
	m._show_city()
	await frames()
	var t: Tour = m.tour
	check(m.phase == "tour" and t.state == "city", "después, la ciudad")
	check(t.stage.is_open(0) and not t.stage.is_open(1), "solo el primer museo abierto")
	t.act("right")
	check(t.stage.picked == 0, "las flechas no llevan a un museo cerrado")
	t.stage.pick(1)
	t._enter_museum()
	check(t.state == "city", "un museo cerrado no se acepta")
	t._pick_museum(0)

	# The controls, in the tour's own words.
	check(t.intent(key(KEY_E)) == "accept" and t.intent(key(KEY_ENTER)) == "accept", "E o Enter aceptan")
	check(t.intent(key(KEY_SPACE)) == "back" and t.intent(key(KEY_ESCAPE)) == "back", "Espacio o Esc, atrás")
	check(t.intent(key(KEY_TAB)) == "skip", "Tab salta")
	check(t.intent(key(KEY_D)) == "right" and t.intent(key(KEY_UP)) == "up", "WASD y flechas mueven")
	check(t.intent(pad(JOY_BUTTON_A)) == "accept" and t.intent(pad(JOY_BUTTON_B)) == "back" and t.intent(pad(JOY_BUTTON_START)) == "skip", "mando: A, B y Start")
	check(t.intent(pad(JOY_BUTTON_DPAD_LEFT)) == "left", "la cruceta mueve")
	var stick := InputEventJoypadMotion.new()
	stick.device = -1
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.9
	check(t.intent(stick) == "right", "el stick mueve")
	check(t.intent(stick) == "", "... una vez por empujón")

	# Into the museum: its first room, the rest shut.
	t.act("accept")
	await frames()
	check(t.state == "museum" and t.stage.room == 0, "al entrar, el museo con su primera sala")
	t.act("right")
	check(t.stage.room == 0, "no se elige una sala cerrada")

	# Further on: two museums open, the second's third room the next to do.
	Story.unlock(8, 1)
	m.story_pick = 8
	m._show_city()
	await frames()
	t = m.tour
	check(t.stage.picked == 1 and t.stage.is_open(1) and not t.stage.is_open(2), "robo 8: el segundo museo elegido, el tercero cerrado")
	t.act("right")
	check(t.stage.picked == 1, "a la derecha, cerrado: se queda")
	t.act("left")
	check(t.stage.picked == 0, "a la izquierda, el primero")
	t.act("right")
	t.act("accept")
	await frames()
	check(t.state == "museum" and t._nights[t.stage.room] == 8, "dentro, la siguiente sala sin hacer (robo 8)")
	t.act("left")
	check(t._nights[t.stage.room] == 7, "se puede elegir una ya hecha")
	check(StarSlots.room_line(7, 1) == "☆☆☆" and StarSlots.room_line(10, 1) == "", "estrellas de cada sala; nada en las cerradas")
	t.act("right")

	# The plan out of the room, and what is told over it.
	t.act("accept")
	await frames(8)
	check(m.level == 8 and t.state == "plan" and t.stage.sheet != null, "el plano de la sala 8 sale y se despliega")
	var talk: PlanTalk = t.talk
	check(talk.mode == "story" and talk.beats[0].kind == "piece", "primero, la pieza")
	check(Vector2i(talk.beats[0].at) == Heist.at, "... señalada en su vitrina")
	var kinds: Array = talk.beats.map(func(b): return b.kind)
	check("news" in kinds, "el robo 8 enseña algo: lo nuevo " + str(kinds))
	check(kinds.count("rule") >= 1 and kinds.count("rule") <= Briefing.MOST, "las reglas, de 1 a %d" % Briefing.MOST)
	check(kinds[-2] == "start" and kinds[-1] == "exit", "y al final la entrada y la salida")
	var inside := talk.beats.all(func(b): return b.at.x >= 0 and b.at.y >= 0 and b.at.x <= Museum.w and b.at.y <= Museum.h)
	check(inside, "todo señalado dentro del plano")
	check(talk.goals.size() == 3, "los tres objetivos de las estrellas")
	# The tale first, big, and nothing goes on by itself: only SIGUIENTE.
	check(talk._card != null and talk._card_for < 0 and talk.pages.size() >= 1, "la historia de la pieza, en grande, en su página")
	await create_timer(0.5).timeout
	check(talk.mode == "story", "... y espera a SIGUIENTE")
	check(PlanTalk.split_tale("Uno dos tres. " .repeat(40)).size() == 2 and PlanTalk.split_tale("Corta.").size() == 1, "un relato largo va en dos páginas")
	t.act("accept")
	check(talk.mode == "news" and talk.page == 0, "SIGUIENTE: lo nuevo, en grande")
	check(talk._card != null and talk._card_for == talk.news[0], "... señalando en el plano lo que lo lleva")
	t.act("back")
	check(talk.mode == "story", "B: un paso atrás, a la historia")
	t.act("accept")
	for i in talk.news.size():
		t.act("accept")
	check(talk.mode == "explore" and talk._told.size() == talk.beats.size(), "SIGUIENTE tras lo nuevo: el plano para explorar, todo clavado")
	check(m._told(8), "... y queda contado")
	# Looking round: the guards, the case, the way in and out, and the list.
	var mk: Array = talk.marks.map(func(k): return k.kind)
	check(mk.count("guard") == m.guards.size() and "piece" in mk and "start" in mk and "exit" in mk, "al explorar, los guardias, la vitrina, la entrada y la salida " + str(mk))
	check(talk._list != null and talk._list.visible and talk._rule_lines.size() == kinds.count("rule"), "a la derecha, la lista de la noche con sus reglas")
	var ruled := 0
	for k in talk.marks:
		ruled += k.rules.size()
	check(ruled == kinds.count("rule"), "cada regla, con lo que la lleva en el plano")
	var guard_at: int = mk.find("guard")
	talk._pick(guard_at)
	var lit := talk._rule_lines.filter(func(l): return l.text.begins_with("▶")).size()
	check(lit == talk.marks[guard_at].rules.size(), "elegir un guardia resalta sus reglas en la lista")
	t.act("accept")
	check(talk.mode == "look" and talk._card != null and talk._card_at == talk.marks[guard_at].at, "A sobre el guardia: su ficha junto a él")
	t.act("back")
	check(talk.mode == "explore" and talk._list.visible, "B la cierra, la lista sigue")
	var sheet: PlanSheet = t.stage.sheet
	check(sheet.fold > 0.0 and sheet.fold < 0.2, "el plano abierto sigue con sus pliegues")
	talk.cursor = 0
	t.act("accept")
	check(talk.mode == "look" and talk._card != null and talk._card_for < 0, "A sobre la chincheta de la pieza: su historia otra vez, en grande")
	t.act("back")
	check(talk.mode == "explore", "y B la cierra")
	t.act("back")
	await frames(6)
	check(t.state == "museum", "B en el plano: vuelve al museo")
	t.act("back")
	await frames(6)
	check(t.state == "city", "B en el museo: a la ciudad")

	# To the heist: again into the museum and its plan, told before now.
	t.act("accept")
	await frames()
	t.stage.pick_room(1)
	t.act("accept")
	await frames(8)
	check(t.talk.mode == "explore", "un plano ya contado se salta la narración")
	t.act("skip")
	await frames()
	check(m.phase == "countdown" and m.tour == null and m.level == 7, "¡A robar!: del plano a la cuenta atrás")
	check(not m.get_viewport().disable_3d, "... y el juego se ve")

	# Out with the piece: the museum again, the next room picked.
	m.phase = "escaped"
	m._show_end()
	m._again()
	await frames()
	t = m.tour
	check(m.phase == "tour" and t.state == "museum" and t._nights[t.stage.room] == 8, "tras escapar, al museo con la sala siguiente")

	# Caught: the same room, its plan straight back out, not told again.
	t.act("accept")
	await frames(8)
	t.act("skip")
	t.act("skip")
	await frames()
	m.phase = "caught"
	m._show_end()
	m._again()
	await create_timer(1.2).timeout
	await frames(8)
	t = m.tour
	check(t.state == "plan" and m.level == 8 and t.talk.mode == "explore", "pillado: la misma sala, su plano, sin contar")

	# A big job done: the town, the next museum open and picked.
	Story.unlock(10, 1)
	m._show_museum_tour(10)
	await frames()
	m.tour.act("accept")
	await frames(8)
	m.tour.act("skip")
	m.tour.act("skip")
	await frames()
	m.phase = "escaped"
	m._show_end()
	for b in m.hud._panel_box.find_children("*", "Button", true, false):
		if (b as Button).text == Text.t("END_NEXT_MUSEUM"):
			(b as Button).pressed.emit()
			break
	await frames()
	t = m.tour
	check(t != null and t.state == "city" and t.stage.picked == 2 and t.stage.is_open(2), "tras el gran golpe, la ciudad con el museo siguiente abierto y elegido")

	# A gang of two: its own way through, the gang's words.
	m.players = 2
	m.seats.assign(["kb_left", "kb_right"])
	m._story_gang(2)
	check(m.phase == "prologue", "la banda de 2 empieza por su prólogo")
	m._show_city()
	await frames()
	t = m.tour
	check(t.stage.is_open(0) and not t.stage.is_open(1), "la banda de 2 tiene su propio progreso")
	t.act("accept")
	await frames()
	t.act("accept")
	await frames(8)
	check(m.thieves.size() == 2 and t.state == "plan", "dos ladrones: el plano del robo 1")
	var news: Array = t.talk.beats.filter(func(b): return b.kind == "news")
	check(news.size() == 1 and news[0].stage == "lesson:heist2", "lo nuevo, el de la banda")
	check(t.talk.beats[-2].text == Text.t("TOUR_MARK_START_MANY"), "«Entráis por aquí»")
	check(t.talk.mode == "story", "la historia primero, también para la banda")
	t.act("skip")
	check(t.talk.mode == "explore", "Start salta de la historia al plano")
	t.act("skip")
	await frames()
	check(m.phase == "countdown" and m.thieves.size() == 2, "y al robo, los dos")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("FALLOS: %d" % fails if fails else "OK: la previa de la historia")
	quit(1 if fails else 0)
