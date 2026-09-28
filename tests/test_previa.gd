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
	# The prehistory museum on arriving: only room 1 is a room; the rest, and
	# the big job's, just windows of the building.
	var cave: MuseumBuilding = t.stage._body(0)
	var shown: Array = range(5).filter(func(i: int) -> bool: return t.stage.room_open(i))
	check(shown == [0] and cave.windows.filter(func(w: Dictionary) -> bool: return w.open).size() == 1, "al llegar a un museo, solo la ventana de la sala 1 es una sala")
	check(cave.windows.all(func(w: Dictionary) -> bool: return w.lock == null), "... las demás, ventanas normales: sin candado")
	check((cave.windows[1].piece as Node3D).get_child_count() == 0 and not cave.windows[4].open, "... sin pieza, y el gran golpe tampoco se ve aún")
	await frames()
	check(t._room_stars[0].visible and not t._room_stars[1].visible and not t._room_stars[4].visible, "... ni estrellas ni número bajo las que no son salas")
	t._pick_room(2)
	t.stage.pick_room(4)
	check(t.stage.room == 0, "... ni se pueden elegir")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = t.stage.on_screen(t.stage.room_centre(1))
	t._on_mouse(click)
	check(t.state == "museum" and t.stage.room == 0, "... ni con el ratón")

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
	# The museum as a building: each room a window on its front.
	var body: MuseumBuilding = t.stage._body(1)
	check(t.stage.room_count() == 5 and body.windows.size() == 5, "el museo, un edificio con una ventana por sala")
	check((body.windows[4].node as Node3D).position.x == 0.0 and body.windows[4].boss, "el gran golpe, la ventana grande del centro")
	check(body.windows[2].open and not body.windows[3].open and body.windows[3].lock != null, "en el edificio de siempre, las salas cerradas a oscuras y con candado")
	await frames()
	check(not t.stage.room_open(3) and t._room_stars[2].visible and not t._room_stars[3].visible, "... pero no son salas: ni estrellas ni se eligen")
	check((body.windows[0].piece as Node3D).get_child_count() == 1, "en cada ventana abierta, su pieza")
	t.act("right")

	# The plan out of the room, and what is told over it.
	t.act("accept")
	await frames(8)
	check(m.level == 8 and t.state == "plan" and t.stage.sheet != null, "el plano de la sala 8 sale y se despliega")
	check((t.stage._sheet_from.at as Vector3).distance_to(t.stage.room_centre(t.stage.room)) < 0.5, "... de su ventana")
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

	# The prehistory museum with all its rooms reached: rooms on its front and
	# down its side, the arrows going from one to the next as seen on screen.
	var tour := Tour.new()
	root.add_child(tour)
	tour.stage.hurry = true
	tour.open_museum(1, 1)
	await frames()
	var dinos: MuseumBuilding = tour.stage._body(0)
	check(range(5).all(func(i: int) -> bool: return tour.stage.room_open(i)) and dinos.windows.all(func(w: Dictionary) -> bool: return w.open), "con todo desbloqueado, las cinco ventanas son salas")
	var sides := dinos.windows.filter(func(w: Dictionary) -> bool: return (w.face as Basis).z.x > 0.9).size()
	var fronts := dinos.windows.filter(func(w: Dictionary) -> bool: return (w.face as Basis).z.z > 0.9).size()
	check(sides >= 1 and fronts >= 2 and sides + fronts == 5, "salas en la fachada y en el costado que se ve (%d y %d)" % [fronts, sides])
	check((dinos.windows[4].node as Node3D).position.x == 0.0 and dinos.windows[4].boss, "el gran golpe, la ventana grande del centro")
	var seen: Array[int] = [tour.stage.room]
	for k in 5:
		tour.act("right")
		if tour.stage.room != seen[-1]:
			seen.append(tour.stage.room)
	var left_to_right := true
	for k in seen.size() - 1:
		left_to_right = left_to_right and tour.stage.room_x(seen[k]) < tour.stage.room_x(seen[k + 1])
	check(seen.size() == 5 and left_to_right, "las flechas, de ventana en ventana de izquierda a derecha en pantalla " + str(seen))
	var side_room := -1
	for i in 5:
		if (dinos.windows[i].face as Basis).z.x > 0.9:
			side_room = i
	tour._pick_room(side_room)
	await frames()
	var face := tour.stage.room_face(side_room)
	check(tour.stage._room_ring.global_basis.y.normalized().dot(face.z) > 0.99, "el aro de una sala del costado, sobre su pared")
	check(((tour.stage.room_window(side_room).basis as Basis).z).dot(face.z) > 0.99, "... y el plano saldría de ella")
	check(not tour.stage.rooms_stacked(), "... y las salas de la cueva, a lo ancho")
	tour.queue_free()

	# The contemporary museum, a tower: each room a floor, in order up it,
	# the big job's the top one; only a room reached is one; the arrows go
	# up and down its floors.
	var modern := Story.nights_in(4)
	Story.unlock(modern[2], 1)
	tour = Tour.new()
	root.add_child(tour)
	tour.stage.hurry = true
	tour.open_museum(1, modern[0])
	await frames()
	var tower: MuseumBuilding = tour.stage._body(4)
	check(tower.windows.size() == 5 and tower.windows.all(func(w: Dictionary) -> bool: return w.get("shape", "") == "floor"), "la torre: cada sala, una planta")
	var floors_up := true
	for k in 4:
		floors_up = floors_up and (tower.windows[k].node as Node3D).position.y < (tower.windows[k + 1].node as Node3D).position.y
	check(floors_up and tower.windows[4].boss, "... en orden hacia arriba, y el gran golpe, la de arriba del todo")
	var reached_rooms: Array = range(5).filter(func(i: int) -> bool: return tour.stage.room_open(i))
	check(reached_rooms == [0, 1, 2] and tower.windows.filter(func(w: Dictionary) -> bool: return w.open).size() == 3, "con tres salas, solo esas tres plantas son salas")
	check(tower.windows.all(func(w: Dictionary) -> bool: return w.lock == null) and (tower.windows[3].piece as Node3D).get_child_count() == 0 and (tower.windows[2].piece as Node3D).get_child_count() == 1, "... las demás, cajas a oscuras: sin candado ni pieza")
	tour._pick_room(3)
	tour.stage.pick_room(4)
	check(tour.stage.room == 0, "... ni se pueden elegir")
	check(tour.stage.rooms_stacked(), "las salas de la torre, una sobre otra")
	tour.act("up")
	var went_up := tour.stage.room == 1
	tour.act("up")
	went_up = went_up and tour.stage.room == 2
	tour.act("up")
	check(went_up and tour.stage.room == 2, "arriba, planta a planta; la de encima, cerrada: se queda")
	tour.act("down")
	var went_down := tour.stage.room == 1
	tour.act("right")
	var right_up := tour.stage.room == 2
	tour.act("left")
	check(went_down and right_up and tour.stage.room == 1, "abajo baja; derecha e izquierda, siguiente y anterior")
	await frames()
	check(tour.stage._room_frame.visible and not tour.stage._room_ring.visible, "un marco de luz alrededor de la planta, no el aro")
	var floor_win := tour.stage.room_window(1)
	check((floor_win.centre as Vector3).distance_to((tower.windows[1].node as Node3D).global_position) < 0.01 and floor_win.size == tower.windows[1].size and (floor_win.size as Vector2).x > 2.0,
		"el plano saldría del centro de su fachada, del tamaño de la planta")
	tour.queue_free()
	Story.unlock(modern[4], 1)
	tour = Tour.new()
	root.add_child(tour)
	tour.stage.hurry = true
	tour.open_museum(1, modern[0])
	await frames()
	for k in 4:
		tour.act("up")
	check(tour.stage.room == 4 and tour._nights[4] == modern[4], "con todo, arriba del todo, el gran golpe")
	tour.queue_free()

	# The ancient museum, a Palladian villa: on arriving, only room 1 is a
	# room, the rest just serlianas and the big job's a shut door. From a
	# fresh start: the tower's cases above have reached the last museum.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var nights := Story.nights_in(2)
	Story.unlock(nights[0], 1)
	tour = Tour.new()
	root.add_child(tour)
	tour.stage.hurry = true
	tour.open_museum(1, nights[0])
	await frames()
	var villa: MuseumBuilding = tour.stage._body(2)
	check(range(5).filter(func(i: int) -> bool: return tour.stage.room_open(i)) == [0] and villa.windows.filter(func(w: Dictionary) -> bool: return w.open).size() == 1, "el museo antiguo al llegar: solo la sala 1 es una sala")
	var door: Dictionary = villa.windows[4]
	check(door.boss and door.size == MuseumBuilding.A_DOOR and (door.node as Node3D).position.x == 0.0 and (door.node as Node3D).position.y < MuseumBuilding.A_BASE + MuseumBuilding.A_DOOR.y, "... el gran golpe, por la puerta")
	check(not door.open and (door.piece as Node3D).get_child_count() == 0 and not (door.node as Node3D).has_node("Crown"), "... cerrada: sin pieza ni corona")
	check(villa.windows.all(func(w: Dictionary) -> bool: return w.lock == null), "... y nada con candado")
	tour.stage.pick_room(4)
	check(tour.stage.room == 0, "... ni se elige")
	tour.queue_free()
	# With all its rooms reached: rooms on its front and down its side, the
	# door open with its crown and its ring.
	Story.unlock(nights[4], 1)
	tour = Tour.new()
	root.add_child(tour)
	tour.stage.hurry = true
	tour.open_museum(1, nights[0])
	await frames()
	villa = tour.stage._body(2)
	check(villa.windows.all(func(w: Dictionary) -> bool: return w.open), "el museo antiguo con todo: las cinco son salas")
	var a_sides := villa.windows.filter(func(w: Dictionary) -> bool: return (w.face as Basis).z.x > 0.9).size()
	var a_fronts := villa.windows.filter(func(w: Dictionary) -> bool: return (w.face as Basis).z.z > 0.9 and not w.boss).size()
	check(a_sides == 3 and a_fronts == 1, "... una en la fachada y tres en el costado que se ve (%d y %d)" % [a_fronts, a_sides])
	door = villa.windows[4]
	check(door.open and (door.piece as Node3D).get_child_count() == 1 and (door.node as Node3D).has_node("Crown"), "... la puerta abierta, con su pieza y su corona")
	tour._pick_room(4)
	await frames()
	check(tour.stage.room == 4 and tour.stage._room_ring.visible, "... se elige, con su aro")
	check(tour.stage._room_ring.global_basis.y.normalized().dot(tour.stage.room_face(4).z) > 0.99, "... el aro sobre la fachada, alrededor de la puerta")
	for k in 5:
		tour.act("left")
	var a_seen: Array[int] = [tour.stage.room]
	for k in 5:
		tour.act("right")
		if tour.stage.room != a_seen[-1]:
			a_seen.append(tour.stage.room)
	var a_order := true
	for k in a_seen.size() - 1:
		a_order = a_order and tour.stage.room_x(a_seen[k]) < tour.stage.room_x(a_seen[k + 1])
	check(a_seen.size() == 5 and a_seen[0] == 4 and a_order, "... las flechas, de la puerta a las del costado, de izquierda a derecha " + str(a_seen))
	tour.queue_free()

	# The castle of the middle ages (a palace with towers): on arriving only
	# room 1 is a room; later, its rooms on its front and up its towers, the
	# big job's the big window in the middle of the noble floor.
	var knights: Array[int] = Story.nights_in(3)
	Story.unlock(knights[0], 1)
	var castle_tour := Tour.new()
	root.add_child(castle_tour)
	castle_tour.stage.hurry = true
	castle_tour.open_museum(1, knights[0])
	await frames()
	var castle: MuseumBuilding = castle_tour.stage._body(3)
	var castle_shown: Array = range(5).filter(func(i: int) -> bool: return castle_tour.stage.room_open(i))
	check(castle.windows.size() == 5 and castle_shown == [0] and castle.windows.filter(func(w: Dictionary) -> bool: return w.open).size() == 1,
		"el castillo, al llegar: solo la ventana de la sala 1 es una sala")
	check(castle.windows.all(func(w: Dictionary) -> bool: return w.lock == null) and (castle.windows[4].piece as Node3D).get_child_count() == 0
		and (castle.windows[4].node as Node3D).get_child_count() == (castle.windows[1].node as Node3D).get_child_count(),
		"... las demás, vidrieras sin candado ni pieza; el gran golpe, sin corona")
	castle_tour.queue_free()
	Story.unlock(knights[4], 1)
	castle_tour = Tour.new()
	root.add_child(castle_tour)
	castle_tour.stage.hurry = true
	castle_tour.open_museum(1, knights[0])
	await frames()
	castle = castle_tour.stage._body(3)
	check(range(5).all(func(i: int) -> bool: return castle_tour.stage.room_open(i)), "el castillo con todo desbloqueado: cinco salas")
	var on_towers := castle.windows.filter(func(w: Dictionary) -> bool: return absf((w.node as Node3D).position.x) > MuseumBuilding.M_W * 0.5 - 0.01).size()
	var on_front := castle.windows.filter(func(w: Dictionary) -> bool: return (w.face as Basis).z.z > 0.9).size()
	check(on_front == 5 and on_towers == 2, "... en la fachada, dos en lo alto de las torres (%d y %d)" % [on_front, on_towers])
	var boss_w: Dictionary = castle.windows[4]
	check(boss_w.boss and (boss_w.node as Node3D).position.x == 0.0 and (boss_w.size as Vector2).x > (castle.windows[0].size as Vector2).x,
		"... el gran golpe, la ventana grande del centro")
	check((boss_w.piece as Node3D).get_child_count() == 1 and (boss_w.node as Node3D).get_child_count() > (castle.windows[0].node as Node3D).get_child_count(),
		"... con su pieza, y la corona")
	var tower_room := -1
	for i in 4:
		if (castle.windows[i].node as Node3D).position.x > 2.0:
			tower_room = i
	castle_tour._pick_room(tower_room)
	await frames()
	var tower_face := castle_tour.stage.room_face(tower_room)
	check(castle_tour.stage.room == tower_room and castle_tour.stage._room_ring.global_basis.y.normalized().dot(tower_face.z) > 0.99,
		"... se elige la de la torre, su aro sobre su pared")
	castle_tour.queue_free()
	await frames()

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
