extends SceneTree
## El Escondite del Calcetín: la casita de la banda, vista (sin entrar) a la
## izquierda del primer museo en la ciudad de Historia, y su sala de
## práctica (Practice), a la que solo se entra por la opción Guarida del
## hub: sin guardias, con la vitrina sellada, papeleras que empujar y
## armaduras donde esconderse, sin estrellas ni nada guardado. Se entra sin
## plano, en el salón, y se sale por la pausa al hub.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
const DT := 1.0 / 60.0
var m


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func _accept_key() -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_E
	e.pressed = true
	return e


func frames(n := 4) -> void:
	for i in n:
		await process_frame


## Frames of the game, as the physics would run them.
func run(n: int) -> void:
	for f in n:
		m.hands.pad_frame = Engine.get_physics_frames() - 1
		m.loop.tick(DT)


## How many sock models a node has under it (LootModels' calcetin.glb).
func _socks_in(root: Node) -> int:
	return root.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n.scene_file_path.ends_with("botin/calcetin.glb")).size()


func _init() -> void:
	Story.save = "user://test_escondite.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))

	# The plan: four rooms, all the way round, out of the challenges.
	var map := Practice.map(1)
	check(map.check().is_empty(), "el plano de la casa se puede jugar: %s" % [map.check()])
	check(not MapFile.list().any(func(f: MapFile) -> bool: return f.path.contains("practica")), "... y no sale entre los retos")
	var reach := map.distances(map.spawn)
	for id in Den.ORDER:
		var r := Den.rect(id)
		var ok := false
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if map.at(Vector2i(x, y)) == Tiles.FLOOR and reach[y * map.w + x] >= 0:
					ok = true
		check(ok, "la sala %s se alcanza desde el salón" % id)
	check(Den.room_at(map.spawn.x + 0.5, map.spawn.y + 0.5) == "salon", "se aparece en el salón")
	# The bathroom is a small room: its doors open onto floor on both sides.
	var bath := Den.rect("aseo")
	check(bath.get_area() <= 70 and bath.size.x >= 8 and bath.size.y >= 6, "el aseo es pequeño pero cabe: %s" % [bath.size])
	for door in Den.DOORS:
		var o: Array = door.rect
		for y in range(o[1] - 1, o[1] + o[3] + 1):
			for x in range(o[0] - 1, o[0] + o[2] + 1):
				var in_gap: bool = x >= o[0] and x < o[0] + o[2] and y >= o[1] and y < o[1] + o[3]
				# Across the wall only: the cells along it (beside the gap) are wall.
				var beside: bool = (x >= o[0] and x < o[0] + o[2]) if o[2] >= o[3] else (y >= o[1] and y < o[1] + o[3])
				if in_gap or beside:
					check(map.at(Vector2i(x, y)) == Tiles.FLOOR, "la puerta %s tiene suelo libre en %d,%d" % [o, x, y])
	check(map.door_face(map.exit) != Vector2i.ZERO and reach[map.exit.y * map.w + map.exit.x] >= 0, "la puerta de casa tiene suelo delante")
	Sim.custom = Practice.tuning()
	check(Sim.guard_count("small") == 0, "sin guardias, aunque el tamaño diga otra cosa")
	Sim.custom = {}

	# The doors between rooms (Den.DOORS): each joins two rooms, one on each side.
	var door_ids := {}
	for door in Den.DOORS:
		door_ids[door.id] = true
		var dr := Den.door_rect(door.id)
		var across := dr.size.x >= dr.size.y
		var side_a := Den.tile_room(Vector2i(dr.position.x, dr.position.y - 1) if across else Vector2i(dr.position.x - 1, dr.position.y))
		var side_b := Den.tile_room(Vector2i(dr.position.x, dr.end.y) if across else Vector2i(dr.end.x, dr.position.y))
		var joined := [side_a, side_b]
		joined.sort()
		var said := [door.a, door.b]
		said.sort()
		check(Den.ROOMS.has(door.a) and Den.ROOMS.has(door.b) and door.a != door.b, "la puerta %s une dos salas que existen: %s y %s" % [door.id, door.a, door.b])
		check(joined == said, "la puerta %s da de verdad a esas dos salas: %s" % [door.id, joined])
		check(Den.tile_room(dr.position) == "", "la puerta %s está en el muro, no dentro de una sala" % door.id)
	check(door_ids.size() == Den.DOORS.size(), "ids de puerta distintos")
	Den.reset_doors()
	check(Den.open_doors().is_empty(), "todas las puertas empiezan cerradas")
	check(Den.tile_room(Den.SPAWN) == "salon", "se aparece en el salón")
	var every_door: Array = Den.DOORS.map(func(d: Dictionary) -> String: return d.id)
	# What is seen: the rooms with a thief, and through the open doors.
	check(Den.visible_rooms([], ["salon"]) == ["salon"], "con todo cerrado, solo el salón")
	check(Den.visible_rooms(every_door, ["salon"]) == Den.ORDER, "con todas abiertas se llega a todas las salas desde el salón")
	check(Den.visible_rooms(["salon_trofeos"], ["salon"]) == ["salon", "trofeos"], "una puerta abierta deja ver la sala de al lado")
	check(Den.visible_rooms(["salon_trofeos"], ["trofeos"]) == ["salon", "trofeos"], "... desde cualquiera de los dos lados")
	check(Den.visible_rooms(["dojo_aseo"], ["salon"]) == ["salon"], "una puerta abierta lejos de los ladrones no enseña nada")
	check(Den.visible_rooms(["salon_dojo", "dojo_aseo"], ["salon"]) == ["salon", "dojo", "aseo"], "por dos puertas abiertas seguidas, también")
	check(Den.visible_rooms(["salon_trofeos"], ["aseo"]) == ["aseo"], "una puerta abierta que no toca la sala no enseña nada")
	check(Den.visible_rooms([], ["salon", "aseo"]) == ["salon", "aseo"], "dos ladrones en salas distintas: se ven las dos")
	check(Den.visible_rooms([], Den.ORDER) == Den.ORDER, "un ladrón en cada sala: todas")
	check(Den.visible_rooms(["trofeos_dojo"], ["salon", "salon", "aseo", "salon"]) == ["salon", "aseo"], "cuatro ladrones en dos salas, con una puerta abierta que no toca ninguna")
	check(Den.visible_rooms(["salon_trofeos"], ["trofeos", "aseo"]) == ["salon", "trofeos", "aseo"], "la unión de lo que ve cada uno")
	check(Den.visible_rooms(every_door, []).is_empty() and Den.visible_rooms(every_door, [""]).is_empty(), "sin ladrones en ninguna sala, no se ve nada")
	check(Den.rooms_at(5.5, 15.5) == ["salon"] and Den.rooms_at(9.5, 9.5) == ["salon", "trofeos"] and Den.rooms_at(0.5, 0.5).is_empty(), "un ladrón en el umbral está en las dos salas; en el muro, en ninguna")
	check(Den.door_near(Vector2i(9, 10)) == "salon_trofeos" and Den.door_near(Vector2i(10, 8)) == "salon_trofeos" and Den.door_near(Vector2i(9, 9)) == "salon_trofeos", "junto a la puerta, esa puerta")
	check(Den.door_near(Vector2i(8, 10)) == "" and Den.door_near(Vector2i(9, 12)) == "" and Den.door_near(Vector2i(5, 15)) == "", "en la esquina o lejos, ninguna")
	check(Den.door_near(Vector2i(19, 11)) == "salon_dojo" and Den.door_near(Vector2i(21, 12)) == "salon_dojo" and Den.door_near(Vector2i(28, 28)) == "dojo_aseo", "las puertas de los lados también")
	# Shut one with someone in the doorway or touching it: it does not shut.
	check(Den.in_the_way("salon_trofeos", [Vector2(9.5, 9.5)]) and Den.in_the_way("salon_trofeos", [Vector2(9.5, 10.2)]), "quien está en el umbral o lo toca estorba")
	check(not Den.in_the_way("salon_trofeos", [Vector2(9.5, 10.5), Vector2(3.0, 3.0)]), "quien está a un paso, no")
	check(Den.toggle_door("salon_dojo", []) and Den.is_open("salon_dojo"), "una puerta cerrada se abre")
	check(not Den.toggle_door("salon_dojo", [Vector2(20.5, 11.5)]) and Den.is_open("salon_dojo"), "abierta y con alguien en el umbral, no se cierra")
	check(not Den.can_toggle("salon_dojo", [Vector2(20.5, 11.5)]) and Den.can_toggle("salon_dojo", [Vector2(5.5, 15.5)]), "... y la acción no se ofrece")
	check(Den.toggle_door("salon_dojo", [Vector2(5.5, 15.5)]) and not Den.is_open("salon_dojo"), "sin nadie, se cierra")
	check(not Den.toggle_door("no_hay", []) and Den.open_doors().is_empty(), "una puerta que no existe no hace nada")
	# On the plan: shut is wall, open is floor.
	Museum.w = Den.W
	Museum.h = Den.H
	Museum.grid = map.grid.duplicate()
	Den.reset_doors()
	Den.apply_doors()
	for door in Den.DOORS:
		var dr := Den.door_rect(door.id)
		var mid := Vector2(dr.position) + Vector2(dr.size) / 2.0
		check(Museum.blocks_move(mid.x, mid.y), "la puerta %s cerrada es muro" % door.id)
	var shut := Sim.move_with_collision(9.5, 10.6, 0.0, -1.2)
	check(shut[1] > 10.2, "la puerta cerrada no deja pasar: y = %.2f" % shut[1])
	Den.toggle_door("salon_trofeos", [])
	var through := Sim.move_with_collision(9.5, 10.6, 0.0, -1.2)
	check(through[1] < 10.0, "abierta, deja pasar: y = %.2f" % through[1])
	check(not Museum.blocks_move(9.5, 9.5) and Museum.blocks_move(20.5, 11.5), "... solo esa")
	for door in Den.DOORS:
		if not Den.is_open(door.id):
			# The dojo wings' three doors mind their own sensors now (can_toggle
			# refuses them outright, tested below); forced open here all the
			# same, to check the plan once every door is open, sensors or not.
			if Den.DOOR_SENSORS.has(door.id):
				Den.set_open(door.id, true)
			else:
				Den.toggle_door(door.id, [])
	Den.apply_doors()
	check(Den.open_doors().size() == Den.DOORS.size() and Museum.grid == map.grid, "con todas las puertas abiertas el plano es el del mapa, alcanzable de punta a punta")
	Den.reset_doors()

	# The dojo wings' three doors: a pressure gate (Den.DOOR_SENSORS), not a
	# toggle one works with the action key.
	for id in Den.DOOR_SENSORS:
		var tiles: Array = Den.DOOR_SENSORS[id]
		check(not Den.can_toggle(id, [], 4) and not Den.can_toggle(id, [Vector2(tiles[0].x + 0.5, tiles[0].y + 0.5)], 4), "la puerta %s no se abre con la tecla de acción" % id)
		# One fewer ninja than sensors: never a distinct one on every plate at once.
		var short_points: Array = []
		for i in tiles.size() - 1:
			short_points.append(Vector2(tiles[i].x + 0.5, tiles[i].y + 0.5))
		check(not Den.sensors_satisfied(id, short_points), "con menos gente que sensores en %s, nunca a la vez" % id)
		check(not Den.sensors_tick(id, short_points) and not Den.is_open(id), "... la puerta sigue cerrada")
		# Someone different on every plate at once: the door opens on its own.
		var full_points: Array = []
		for t in tiles:
			full_points.append(Vector2(t.x + 0.5, t.y + 0.5))
		check(Den.sensors_satisfied(id, full_points), "con alguien distinto en cada sensor de %s, a la vez" % id)
		check(Den.sensors_tick(id, full_points) and Den.is_open(id), "... la puerta se abre sola")
		# One steps off a plate: shut again, like a pressure door, not a toggle one stays.
		check(Den.sensors_tick(id, short_points) and not Den.is_open(id), "uno se baja de un sensor y se cierra otra vez")
	Den.reset_doors()

	# The dojo: what is open depends on the job reached.
	check(Practice.open_items(1).is_empty() and Practice.open_trials(1).is_empty(), "recién empezada, el dojo está vacío")
	check(Practice.map(1).props.is_empty() and Practice.scarecrows(1).is_empty(), "... sin cosas que tirar ni espantapájaros")
	var last := 0
	for item in Practice.ITEMS:
		check(Practice.item_night(item) >= 1 and Practice.item_night(item) <= Story.count(), "%s viene con el robo %d" % [item.id, Practice.item_night(item)])
	Story.save = "user://test_escondite_b.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(Story.lesson_night("guard"), 1)
	check(Practice.scarecrows(1).size() == 3 and Practice.open_trials(1).map(func(t): return t.id) == ["circuit"] and Practice.map(1).props.is_empty() and Practice.map(1).guards.is_empty(), "con la lección del guardia, el circuito con sus tres espantapájaros")
	Story.unlock(Story.lesson_night("props"), 1)
	check(Practice.map(1).props.size() == 6 and Practice.map(1).exhibits.values().has("plinth") and Practice.map(1).exhibits.values().has("box") and Practice.map(1).exhibits.values().has("fridge"), "con los objetos, seis cosas (dos papeleras, el busto y tres armaduras), pedestal, caja y taquilla")
	check(Practice.map(1).check().is_empty(), "... y el plano sigue jugable")
	check(Practice.map(2).props.is_empty(), "otra banda, otro avance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.save = "user://test_escondite.cfg"

	# The trophy room, a museum of its own: 25 stands, five to a museum, all
	# there from the start and full only of what has been stolen.
	var stands := Den.stands()
	check(stands.size() == 25 and stands.size() == Story.count(), "25 puestos, uno por robo de la historia: %d" % stands.size())
	var by_museum := {}
	var seen := {}
	for st in stands:
		by_museum[st.museum] = by_museum.get(st.museum, 0) + 1
		seen[st.n] = true
		check(Story.museum_of(st.n) == st.museum, "el puesto %d es del museo %d" % [st.n, st.museum + 1])
	check(by_museum.size() == Story.MUSEUMS.size() and by_museum.values().all(func(c) -> bool: return c == Story.ROOMS), "agrupados de cinco en cinco por museo: %s" % [by_museum])
	check(seen.size() == 25 and seen.keys().min() == 1 and seen.keys().max() == 25, "... con los robos del 1 al 25, cada uno una vez")
	var spots := {}
	for st in stands:
		spots[st.tile] = true
		var r := Den.rect("trofeos")
		check(r.has_point(st.tile), "el puesto %d está en la sala de trofeos" % st.n)
	check(spots.size() == 25, "cada puesto en su casilla")
	Story.save = "user://test_escondite_c.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	check(Den.filled(1).is_empty() and Den.filled(2).is_empty(), "sin robos, todos los puestos vacíos")
	for n in range(1, 8):
		Story.keep_stars(n, 1, Story.STAR_TAKEN | (Story.STAR_UNSEEN if n % 2 == 0 else 0))
	Story.keep_stars(9, 1, Story.STAR_UNSEEN)
	check(Den.filled(1) == [1, 2, 3, 4, 5, 6, 7], "con el botín de los robos 1 a 7, esos puestos llenos y el resto vacíos: %s" % [Den.filled(1)])
	check(not Den.is_filled(9, 1), "una estrella sin la pieza no llena el puesto")
	check(Den.filled(2).is_empty() and Den.filled(4).is_empty(), "por tamaño de banda: las otras siguen vacías")
	Story.keep_stars(3, 2, Story.STAR_TAKEN)
	check(Den.filled(2) == [3] and Den.filled(1).size() == 7, "cada banda con su avance")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.save = "user://test_escondite.cfg"
	# Every stand can be walked up to, and the furniture leaves no one stuck.
	var gallery := Practice.map(1)
	var walk := gallery.distances(gallery.spawn)
	for st in stands:
		var tl: Vector2i = st.tile
		var near := false
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var q: Vector2i = tl + d
			if gallery.at(q) == Tiles.FLOOR and walk[q.y * gallery.w + q.x] >= 0:
				near = true
		check(gallery.at(tl) == Tiles.COVER and near, "el puesto %d bloquea su casilla y se llega hasta él" % st.n)
	var stuck := 0
	for y in gallery.h:
		for x in gallery.w:
			if gallery.at(Vector2i(x, y)) == Tiles.FLOOR and walk[y * gallery.w + x] < 0:
				stuck += 1
	check(stuck == 0, "ninguna casilla de suelo queda aislada: %d" % stuck)

	# --- La orientación de los muebles: una tabla de datos, no a ojo ----------------
	check(Den.audit().is_empty(), "ningún mueble mal orientado: %s" % [Den.audit()])
	check(Den.compass("N") == Vector2(0, -1) and Den.compass("E") == Vector2(1, 0), "la brújula: N arriba, E a la derecha")
	check(is_equal_approx(Den.yaw_for("loungeSofa", "S"), 0.0) and is_equal_approx(Den.yaw_for("loungeSofa", "E"), 90.0) \
		and absf(Den.yaw_for("loungeSofa", "N")) == 180.0 and is_equal_approx(Den.yaw_for("loungeSofa", "W"), -90.0), "el frente de un mueble normal (+Z) mira al sur a 0 grados")
	check(is_equal_approx(Den.yaw_for("showerRound", "NW"), -90.0), "la ducha: el arco de cristal al noroeste pide -90 grados")
	check(Den.facing("showerRound", -90.0).distance_to(Den.compass("NW")) < 0.01, "... y con ellos mira al noroeste")
	check(Den.facing("loungeSofaCorner", 180.0).distance_to(Den.compass("NW")) < 0.01, "el sofá de esquina, a 180, mira al noroeste")
	var seen_models := {}
	var by_wall := {"N": 0, "S": 0, "E": 0, "W": 0}
	for f in Den.furniture():
		var model: String = f.m
		if not Den.FRONTED.has(model):
			continue
		seen_models[model] = true
		var dir := Den.facing(model, f.yaw)
		var ahead := Den.room_reach(f.at, dir)
		check(ahead >= 0.9, "%s en %s mira al interior de %s (%.1f casillas libres delante)" % [model, f.at, Den.room_at(f.at.x, f.at.y), ahead])
		if f.wall != "":
			by_wall[f.wall] += 1
			check(dir.distance_to(-Den.compass(f.wall)) < 0.01 and Den.wall_gap(f.at, f.wall) < 1.0, "%s en %s: espalda a la pared %s, cara al interior" % [model, f.at, f.wall])
	check(seen_models.size() >= 18, "la auditoría cubre %d modelos con frente" % seen_models.size())
	check(by_wall.N > 0 and by_wall.S > 0 and by_wall.E > 0 and by_wall.W > 0, "hay muebles pegados a las cuatro paredes: %s" % [by_wall])
	var shower: Dictionary = Den.furniture().filter(func(f: Dictionary) -> bool: return f.m == "showerRound")[0]
	check(shower.corner == "SE" and Den.facing("showerRound", shower.yaw).distance_to(Den.compass("NW")) < 0.01, "la ducha está en la esquina sureste, con la abertura hacia dentro (noroeste)")
	check(Den.wall_gap(shower.at, "E") < 1.6 and Den.wall_gap(shower.at, "S") < 1.6, "... y sus dos lados cerrados contra los muros")
	# Furniture never blocks a door, the front door, the spawn or the way out.
	var blocked := {}
	for f in Den.furniture():
		var b: Array = f.block
		if b.is_empty():
			continue
		for y in range(b[1], b[1] + b[3]):
			for x in range(b[0], b[0] + b[2]):
				blocked[Vector2i(x, y)] = true
	check(not blocked.has(Den.SPAWN) and not blocked.has(Den.EXIT) and not blocked.has(Vector2i(Den.EXIT.x + 1, Den.EXIT.y)), "los muebles no tapan la aparición ni la puerta de casa")
	for door in Den.DOORS:
		var o: Array = door.rect
		for y in range(o[1] - 1, o[1] + o[3] + 1):
			for x in range(o[0] - 1, o[0] + o[2] + 1):
				var in_gap: bool = x >= o[0] and x < o[0] + o[2] and y >= o[1] and y < o[1] + o[3]
				var beside: bool = (x >= o[0] and x < o[0] + o[2]) if o[2] >= o[3] else (y >= o[1] and y < o[1] + o[3])
				if in_gap or beside:
					check(not blocked.has(Vector2i(x, y)), "ningún mueble en la puerta %s (%d,%d)" % [door.id, x, y])
	for t in blocked:
		check(Den.tile_room(t) != "" and map.at(t) == Tiles.COVER, "el mueble en %s bloquea suelo de una sala" % [t])
	# The arcade machine in the lounge: solid, in front of the wall, playable.
	var arcade: Array = Den.furniture().filter(func(f: Dictionary) -> bool: return f.m == Arcades.MODEL)
	check(arcade.size() == 1 and Den.tile_room(Den.ARCADE_AT) == "salon" and blocked.has(Den.ARCADE_AT) and map.at(Den.ARCADE_AT) == Tiles.COVER, "una recreativa en el salón, en una casilla que bloquea")
	check(arcade[0].wall == "N" and Den.facing(Arcades.MODEL, arcade[0].yaw) == Vector2(0, 1), "... pegada a la pared norte, con la pantalla hacia el salón")
	check(map.at(Den.ARCADE_AT + Den.ARCADE_FRONT) == Tiles.FLOOR, "... y suelo libre delante para jugar")

	# --- El dojo grande: nueve bahías, una por prueba, con espacio para sus tres puntos de inicio --
	var dojo := Den.rect("dojo")
	check(dojo.get_area() >= 2.2 * 481 and dojo.size == Vector2i(41, 28), "el dojo es más de dos veces el de antes (481 casillas): %s = %d" % [dojo.size, dojo.get_area()])
	var full := Practice.map(25)
	var far := full.distances(full.spawn)
	check(Den.DOJO_ZONES.size() == DojoTrials.TABLE.size(), "una zona por prueba: %d" % Den.DOJO_ZONES.size())
	var area := 0
	var zone_rects: Array[Rect2i] = []
	for z in Den.DOJO_ZONES:
		var zr := Practice.zone_rect(z)
		zone_rects.append(zr)
		area += zr.get_area()
		var floors := 0
		var reached := 0
		for y in range(zr.position.y, zr.end.y):
			for x in range(zr.position.x, zr.end.x):
				if full.at(Vector2i(x, y)) == Tiles.FLOOR:
					floors += 1
					if far[y * full.w + x] >= 0:
						reached += 1
		check(floors >= 60 and reached == floors, "la zona %s tiene %d casillas de suelo y se llega a todas" % [z, floors])
		check(dojo.encloses(zr), "la zona %s cae dentro del dojo" % z)
	var overlap := 0
	for i in zone_rects.size():
		for j in range(i + 1, zone_rects.size()):
			if zone_rects[i].intersects(zone_rects[j]):
				overlap += 1
	check(overlap == 0 and area == dojo.get_area(), "las zonas no se solapan y cubren el dojo entero (%d de %d casillas)" % [area, dojo.get_area()])
	# Every trial lives in a bay of its own, with its three start points inside it and apart.
	var used := {}
	for row in DojoTrials.TABLE:
		check(Den.DOJO_ZONES.has(row.zone), "%s: su zona %s existe" % [row.id, row.zone])
		for tile in row.starts:
			check(Practice.zone_rect(row.zone).has_point(tile) and not used.has(tile), "%s: el punto %s está en su zona y no se repite" % [row.id, tile])
			used[tile] = true
		var xs: Array = row.starts.map(func(t): return t.x)
		var ys: Array = row.starts.map(func(t): return t.y)
		var spread: bool = (xs.max() - xs.min() >= 4) or (ys.max() - ys.min() >= 4)
		check(spread, "%s: sus tres puntos van separados (%s)" % [row.id, row.starts])
	# Walls between bays with doorways three wide, except the middle row (the three
	# games of skill), which shares one open room: no inside wall there at all.
	for x in [34, 48]:
		for y in [4, 5, 6, 10, 11, 12, 13, 14, 15, 16, 17, 22, 23, 24]:
			check(full.at(Vector2i(x, y)) == Tiles.FLOOR, "pasillo (o sala común) entre bahías en %d,%d" % [x, y])
		for y in [1, 2, 3, 7, 8, 9, 18, 19, 20, 21, 25, 28]:
			check(full.at(Vector2i(x, y)) == Tiles.WALL, "muro entre bahías en %d,%d" % [x, y])
	for y in [9, 18]:
		for x in [26, 27, 28, 40, 41, 42, 54, 55, 56]:
			check(full.at(Vector2i(x, y)) == Tiles.FLOOR, "pasillo entre filas en %d,%d" % [x, y])
		for x in [21, 25, 29, 34, 39, 43, 48, 53, 57, 61]:
			check(full.at(Vector2i(x, y)) == Tiles.WALL, "muro entre filas en %d,%d" % [x, y])
	# The circuit is walled inside: two runs, so the way from the rings to the goal is a snake.
	var cgoal: Vector2i = DojoTrials.info("circuit").goal
	var cwalk := full.distances(DojoTrials.info("circuit").starts[0])
	check(cwalk[cgoal.y * full.w + cgoal.x] >= 30, "del primer anillo del circuito a la meta hay un buen rodeo: %d pasos" % cwalk[cgoal.y * full.w + cgoal.x])
	# Every bay is reached from the next by its doorways: from the lounge's door to the farthest bay.
	var reach_far := far[Practice.stand_of("aguanta", 2).y as int * full.w + int(Practice.stand_of("aguanta", 2).x)]
	check(reach_far > 40, "de la casa al último punto (AGUANTA, difícil) hay un buen paseo por las bahías: %d" % reach_far)

	# --- Los espantapájaros: los del circuito, que barren, ven como un guardia con sus números ---
	var clear_los := func(_from: Vector2, _to: Vector2, _low: bool) -> bool: return true
	var wall_los := func(_from: Vector2, _to: Vector2, _low: bool) -> bool: return false
	Story.save = "user://test_escondite_full.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(25, 1)
	var guards := Practice.scarecrows(1)
	check(guards.size() == 3 and guards.all(func(g): return g.has("turn") and Den.tile_room(g.at) == "dojo" and Practice.zone_rect("circuit").has_point(g.at)), "tres espantapájaros, todos en el circuito y todos girando")
	Story.save = "user://test_escondite.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_escondite_full.cfg"))
	check(Practice.scarecrows(1).is_empty(), "sin la lección del guardia, ninguno (y ninguno fuera del circuito nunca)")
	var sc: Dictionary = guards[0]
	var torch := Practice.scarecrow_torch(sc)
	check(torch.x < sc.at.x + 0.1 and Vector2i(int(floor(torch.x)), int(floor(torch.y))) != sc.at, "la linterna está delante del palo, fuera de su casilla: %s" % torch)
	var target := Vector2(29.5, 19.5)
	check(Practice.scarecrow_sees(sc, target, false, false, clear_los, 0.0), "ve a un ladrón dentro del cono")
	check(not Practice.scarecrow_sees(sc, target, false, false, wall_los, 0.0), "... no si hay un muro en medio")
	check(not Practice.scarecrow_sees(sc, target, true, false, clear_los, 0.0), "... ni si está escondido")
	check(not Practice.scarecrow_sees(sc, Vector2(25.5, 19.5), false, false, clear_los, 0.0), "... ni fuera del alcance (%.1f)" % Practice.SCARECROW_RANGE)
	check(not Practice.scarecrow_sees(sc, Vector2(31.5, 24.5), false, false, clear_los, 0.0), "... ni fuera del ángulo (a un lado)")
	# It sweeps: the middle of the swing at 0, a side at a quarter of the period.
	var quarter: float = PI / 2.0 / float(sc.turn.speed)
	check(is_equal_approx(Practice.scarecrow_facing(sc, 0.0), PI) and is_equal_approx(Practice.scarecrow_facing(sc, quarter), PI + float(sc.turn.amp)), "gira: mira al medio en 0 y a un lado de su barrido un cuarto de vuelta después")
	check(not Practice.scarecrow_sees(sc, target, false, false, clear_los, quarter), "... y, mirando a un lado, ya no ve lo que veía")
	# On the real plan: the walls and the cover cut its sight.
	Museum.w = full.w
	Museum.h = full.h
	Museum.grid = full.grid.duplicate()
	Den.reset_doors()
	Den.apply_doors()
	check(Practice.scarecrow_sees(sc, target, false, false, Callable(), 0.0), "en el plano de verdad, ve por el carril")
	check(not Practice.scarecrow_sees(sc, Vector2(29.5, 22.5), false, false, Callable(), 0.0), "... pero no por el muro al carril de abajo")
	# The alarm: 3 s red, 1.5 s before it can go again.
	var al := Practice.alert_new()
	al = Practice.alert_step(al, 0.1, false)
	check(not al.active, "sin ver a nadie, la alarma no suena")
	al = Practice.alert_step(al, 0.1, true)
	check(al.active and is_equal_approx(al.left_s, Practice.ALERT_S), "al ver a alguien, suena %.1f s" % Practice.ALERT_S)
	var on_for := 0.0
	while al.active and on_for < 10.0:
		al = Practice.alert_step(al, 0.1, true)
		on_for += 0.1
	check(absf(on_for - 3.0) < 0.15 and not al.active, "sigue a la vista y se apaga a los 3 s: %.1f" % on_for)
	check(is_equal_approx(al.cooldown_s, Practice.ALERT_COOLDOWN_S), "y espera %.1f s para poder volver" % Practice.ALERT_COOLDOWN_S)
	al = Practice.alert_step(al, 1.0, true)
	check(not al.active and al.cooldown_s > 0.0, "a la vista durante el enfriamiento, no se dispara")
	al = Practice.alert_step(al, 0.6, true)
	al = Practice.alert_step(al, 0.1, true)
	check(al.active, "pasado el enfriamiento y aún a la vista, otra vez")

	Story.save = "user://test_escondite.cfg"


	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.tour_hurry = true

	# In the town: the house is one more thing to pick, right of the first museum.
	m._show_city()
	await frames()
	var t: Tour = m.tour
	check(t.state == "city" and t.stage.picked == 0, "la ciudad, con el primer museo elegido")
	check(t.stage.is_open(CityStage.HIDEOUT) and t.stage.is_hideout(CityStage.HIDEOUT) and not t.stage.is_hideout(0), "la casita está abierta y no es un museo")
	t.act("left")
	check(t.stage.picked == CityStage.HIDEOUT, "a la izquierda del primer museo en la barra (el orden de la historia), la casita")
	check(not t._sign_stars.visible and t._sign_title.text == Text.t("HIDEOUT_NAME").to_upper(), "... con su cartel, sin estrellas")
	t.act("left")
	check(t.stage.picked == CityStage.HIDEOUT, "... y más a la izquierda no hay nada")
	t.act("right")
	check(t.stage.picked == 0, "a la derecha, el primer museo otra vez")
	t.act("right")
	check(t.stage.picked == 0, "... y los cerrados siguen cerrados")
	var over := InputEventMouseMotion.new()
	# Hovering only picks on the bar's cards now (the map behind is for clicking).
	over.position = (t._cards[CityStage.HIDEOUT] as Rect2).get_center()
	over.relative = Vector2(40, 0)
	t._on_mouse(over)
	check(t.stage.picked == CityStage.HIDEOUT, "con el ratón encima de su tarjeta, la casita")

	# Visible, pero sin puerta trasera: aceptar sobre ella no entra, solo rebota
	# (como un museo cerrado); la única puerta es la opción Guarida del hub.
	t.act("accept")
	await frames()
	check(t.state == "city" and m.mode == "story" and m.phase == "tour", "aceptar sobre la casita no entra, solo se mira desde la ciudad")

	# In: no plan, no briefing, by the hub's own Guarida door — but its own
	# clear moment of entry, same as a museum's title on its plan.
	m._show_title("dojo", false)
	m._dojo_start(1, true)
	await frames()
	check(m.mode == Practice.MODE and m.phase == "playing", "la casa, jugando nada más entrar: %s %s" % [m.mode, m.phase])
	check(m.hud._room != null and m.hud._room.text == Text.t("HIDEOUT_NAME") and m.hud._room.modulate.a > 0.0, "el nombre de la guarida se anuncia al entrar")
	check(not m.hud.counting() and not m.hud._count.visible, "sin cuenta atrás ni números en pantalla")
	check(m.guards.is_empty() and Sim.guard_count("small") == 0, "sin guardias")
	check(m.thieves.size() == 1, "un ladrón")
	check(Den.room_at(m.thieves[0].x, m.thieves[0].y) == "salon", "... en el salón")
	check(Props.list.is_empty() and m.house.mannequins.is_empty(), "sin nada que tirar ni espantapájaros: aún no se han desbloqueado")
	check(m.world.get_child_count() > 0 and m.hud.home, "el HUD sabe que es la casa")
	check(Sim.feature("case") == false, "la vitrina, sellada")
	check(not Sim.feature("case") and Heist.loot.name == "la pieza de práctica" and Heist.loot.shape != "sock", "la vitrina, sellada, con una pieza que no es un calcetín")
	run(3)
	check(m.phase == "playing" and not m.hud.counting(), "sigue sin cuenta atrás")

	# The map (M, View) works in the house as in a heist: the four rooms' shape,
	# the doors, the band, the rooms nobody sees as unexplored, no piece to steal.
	m._toggle_map()
	check(m.map_open and m.hud._map.visible, "el mapa se abre en la casa")
	var plan: Image = m._live_map()
	var solid := 0
	for py in range(0, plan.get_height(), 4):
		for px in range(0, plan.get_width(), 4):
			if plan.get_pixel(px, py).a > 0.5:
				solid += 1
	check(solid > 1000, "... y tiene plano dibujado (%d puntos)" % solid)
	var ms := plan.get_width() / Museum.w
	var lounge_px := plan.get_pixel(5 * ms + ms / 2, 15 * ms + ms / 2)
	var trophy_px := plan.get_pixel(5 * ms + ms / 2, 5 * ms + ms / 2)
	var shut_px := plan.get_pixel(9 * ms + ms / 2, 9 * ms + ms / 2)
	check(lounge_px == Hud.MAP_FLOOR, "el salón, donde se está, se ve como suelo")
	check(trophy_px == Hud.MAP_FOG, "los trofeos, con la puerta cerrada, salen sin ver")
	check(shut_px == Hud.MAP_DOOR, "una puerta cerrada se marca en el muro")
	m._toggle_map()
	check(not m.map_open and not m.hud._map.visible, "M lo guarda")
	Hud.home_map = false

	# The sealed case: nothing opens it.
	var p: Thief = m.thieves[0]
	p.x = Heist.at.x - 0.6
	p.y = Heist.at.y + 0.5
	check(Heist.at_case(p), "el ladrón junto a la vitrina")
	run(600)
	check(Heist.progress == 0.0 and not Heist.taken and Heist.by == "", "600 ticks a su lado y no cede")
	check(m._action_for(p).get("do", "") != "job", "la acción no ofrece la ganzúa")
	check(m.phase == "playing", "y la noche sigue")

	# With the props open, a bin: pushed, it falls.
	Story.save = "user://test_escondite_b.cfg"
	Story.unlock(Story.lesson_night("props"), 1)
	m._new_round(1)
	Story.save = "user://test_escondite.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_escondite_b.cfg"))
	m._start_playing()
	p = m.thieves[0]
	check(Props.list.size() == 6 and m.house.mannequins.size() == 3, "abierto el dojo: seis cosas y los tres espantapájaros del circuito")
	check(Hideouts.all().filter(func(s) -> bool: return s.kind == "armour").size() == 3, "tres armaduras donde esconderse")
	var bin: Props.Prop = Props.list.filter(func(q: Props.Prop) -> bool: return q.kind == "bin")[0]
	p.x = bin.x + 0.5
	p.y = bin.y + 0.5
	var act: Dictionary = m._action_for(p)
	check(act.get("do", "") == "push", "junto a una papelera, empujar")
	var noises: Array[SoundEvent] = []
	Props.push(bin, p, Sim.now_ms(), noises)
	check(bin.fallen, "la papelera cae")

	m.house.scarecrow_speed = 1.0
	# The arcade machine in the lounge: pong, with nothing to win.
	p.x = 2.5
	p.y = 11.6
	p.moving = false
	p.speed = 0.0
	var aact: Dictionary = m._action_for(p)
	check(aact.get("do", "") == "arcade" and aact.at == Den.ARCADE_AT, "delante de la recreativa, la acción es jugar: %s" % [aact])
	check(m._prompt_rows(0).size() == 1 and m._prompt_rows(0)[0].verb == Text.t("HIDEOUT_ARCADE_PLAY"), "... y la ayuda dice JUGAR")
	var pong := Minigame.make("arcade", "arcade", 1, {})
	check(pong is ArcadeGame, "... el minijuego es el pong de los museos")
	p.y = 14.6
	check(m._action_for(p).get("do", "") != "arcade", "lejos de la recreativa, nada")
	p.x = 4.6
	p.y = 10.7
	check(m._action_for(p).get("do", "") != "arcade", "de lado o por detrás, tampoco")

	# The scarecrows: the corridor's one sees a thief in its cone, and the dojo
	# (only the dojo) goes red for three seconds.
	var dv2: DenView = m.den_view
	m.house.scarecrow_speed = 0.0
	m.house.scarecrow_time = 0.0
	p.x = 29.5
	p.y = 19.5
	m.house.scarecrow_alert = Practice.alert_new()
	m.house.scarecrow_tick(0.1)
	check(m.house.scarecrow_alert.active, "el primer espantapájaros del circuito ve al ladrón en su cono: se dispara la alarma")
	dv2._pose_alert(0.4)
	check(dv2.alert_level() == 1.0 and dv2._alert_slab.visible, "el dojo se pone rojo")
	check(dv2._alert_slab.get_parent().name == "Room_dojo" and dv2._alert_lights.all(func(l: OmniLight3D) -> bool: return l.get_parent().name == "Room_dojo"), "... y el rojo cuelga del dojo, no de otra sala")
	check(m.sfx._streams.has("siren"), "hay una sirena para el dojo")
	for i in 29:
		m.house.scarecrow_tick(0.1)
	check(m.house.scarecrow_alert.active, "a los 2,9 s sigue")
	m.house.scarecrow_tick(0.15)
	dv2.set_alert(false)
	dv2._pose_alert(0.4)
	check(not m.house.scarecrow_alert.active and dv2.alert_level() == 0.0 and not dv2._alert_slab.visible, "a los 3 s se apaga, y con ella el rojo")
	check(m.phase == "playing" and m.guards.is_empty() and not p.out, "nadie es pillado")
	for i in 20:
		m.house.scarecrow_tick(0.1)
	check(m.house.scarecrow_alert.active, "a la vista aún, pasado el enfriamiento, otra vez")
	m.house.scarecrow_alert = Practice.alert_new()
	p.hiding = true
	m.house.scarecrow_tick(0.1)
	check(not m.house.scarecrow_alert.active, "escondido en una caja, no cuenta")
	p.hiding = false
	p.x = 26.5
	p.y = 5.5
	m.house.scarecrow_tick(0.1)
	check(not m.house.scarecrow_alert.active, "en la bahía de GANZÚA, no lo ve")

	# The dojo's objects are dressed, and no sock but PILLA EL CALCETÍN's (its pedestals) and the band's flag.
	Story.save = "user://test_escondite_b.cfg"
	Story.unlock(Story.lesson_night("props"), 1)
	m.house.scarecrow_alert = Practice.alert_new()
	check(m.den_view._trial_parts.size() == 6 and m.den_view._start_boards.size() == Practice.trial_starts(1).size(), "la casa armada con las pruebas que hay: un objeto por punto de inicio, 6 con partes móviles (las dos pruebas del banco enseñadas) y todos con su rótulo")
	var socks := _socks_in(m.den_view)
	var pedestals := Practice.trial_starts(1).filter(func(g): return g.via == "sock").size()
	check(pedestals == 3 and socks == pedestals + 1, "calcetines en el dojo: solo los %d pedestales de PILLA EL CALCETÍN y la bandera de la banda (%d)" % [pedestals, socks])
	m.scenery.draw_loot()
	check(not m.scenery.loot_node.visible, "y ninguno flotando sobre el banco (la pieza de la casa no se enseña)")
	Story.save = "user://test_escondite.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_escondite_b.cfg"))
	p.x = 10.5
	p.y = 15.5

	# Music: the house's, and the museum's back out of it.
	m._music_mood()
	check(m.sfx._house_target == 1.0, "la música de la casa suena")
	# Room names as one walks between rooms.
	p.x = 10.5
	p.y = 5.0
	m.house.home_tick()
	check(m.house.home_room == "trofeos", "entrar en la sala de trofeos la nombra")

	# The pause, and out to the hub (the only door in is Guarida, so the only
	# way back is to it too).
	m._pause()
	check(m.phase == "paused", "la pausa")
	m._quit_to_title()
	await frames()
	check(m.phase == "title" and m.hub.visible and m.hub.active[m.hub.cursor].id == "dojo", "salir de la pausa lleva al hub, con Guarida elegida: %s" % m.phase)

	m._music_mood()
	check(m.sfx._house_target == 0.0, "fuera de casa, la música del museo")

	# Nothing kept.
	check(not FileAccess.file_exists(Story.save), "no se guardó nada")
	check(Story.unlocked(1) == 1 and Story.stars_in(0, 1) == 0, "sin robos hechos ni estrellas")

	# The front door: crossing it takes the band out too.
	m.mode = Practice.MODE
	m.players = 1
	m._new_round(1)
	m._start_playing()
	check(not Den.at_door(9.5, 19.5) and Den.at_door(10.0, 22.5), "la zona de la puerta es el suelo delante de ella")
	m.thieves[0].x = 10.0
	m.thieves[0].y = 22.5
	run(2)
	await frames(6)
	check(m.phase == "title" and m.hub.visible and m.hub.active[m.hub.cursor].id == "dojo", "cruzar la puerta lleva al hub, con Guarida elegida: %s" % m.phase)

	# The trophies follow the band's stars.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.keep_stars(1, 1, Story.STAR_TAKEN | Story.STAR_UNSEEN)
	Story.keep_stars(7, 2, Story.STAR_TAKEN)
	check(Story.stars(1, 1) == 2 and Story.stars(1, 2) == 0 and Story.stars(7, 2) == 1, "las estrellas van por tamaño de banda")
	m.mode = Practice.MODE
	m.players = 1
	m._new_round(1)
	check(DenView.players == 1 and Den.filled(DenView.players) == [1], "la sala de trofeos lee el progreso de la banda de uno")
	check(m.phase != "countdown", "y al armar la casa no hay cuenta atrás")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))

	# The whole band: four thieves, all on the floor.
	m.mode = Practice.MODE
	m.players = 4
	var seats: Array[String] = []
	seats.assign(["kb_left", "kb_right", "pad:0", "pad:1"])
	m.seats = seats
	m._new_round(1)
	check(m.thieves.size() == 4 and m.thieves.all(func(q: Thief) -> bool: return not Museum.is_wall(q.x, q.y)), "cuatro ladrones sobre suelo")

	# The doors in the round: all shut, the band in the lounge, seeing only it.
	var dv: DenView = m.den_view
	check(dv != null and Den.open_doors().is_empty(), "al llegar, todas las puertas cerradas")
	m._start_playing()
	check(m.thieves.all(func(q: Thief) -> bool: return Den.rooms_at(q.x, q.y) == ["salon"]), "... y toda la banda en el salón")
	check(dv.shows("salon") and not dv.shows("trofeos") and not dv.shows("dojo") and not dv.shows("aseo"), "solo se ve el salón; las otras salas, a oscuras")
	check(dv.get_node("Room_salon").visible and not dv.get_node("Room_trofeos").visible and not dv.get_node("Room_dojo").visible, "lo que hay en una sala a oscuras no se dibuja")
	check(not dv.shows_at(25.5, 5.5) and dv.shows_at(5.5, 15.5) and dv.shows_at(9.5, 9.5), "lo que hay en el dojo, oculto; el umbral, no")
	for door in Den.DOORS:
		var dr := Den.door_rect(door.id)
		check(Museum.blocks_move(dr.position.x + 0.5, dr.position.y + 0.5), "en la casa, la puerta %s bloquea el paso" % door.id)
	var t0: Thief = m.thieves[0]
	t0.x = 9.5
	t0.y = 10.5
	var act0: Dictionary = m._action_for(t0)
	check(act0.get("do", "") == "door" and act0.at == "salon_trofeos", "junto a una puerta cerrada, la acción es abrirla: %s" % [act0])
	check(m._prompt_rows(0).size() == 1 and m._prompt_rows(0)[0].verb == Text.t("HIDEOUT_DOOR_OPEN"), "... y la ayuda dice ABRIR")
	check(Den.toggle_door("salon_trofeos", m.house.band_points()), "se abre")
	dv.set_door("salon_trofeos", true)
	m.house.home_sight(true)
	check(dv.shows("trofeos") and not dv.shows("dojo") and not Museum.blocks_move(9.5, 9.5), "abierta, se ve la sala de al lado (solo esa) y se pasa")
	check(m._prompt_rows(0)[0].verb == Text.t("HIDEOUT_DOOR_CLOSE"), "... y la ayuda dice CERRAR")
	t0.y = 9.5
	check(m._action_for(t0).get("do", "") != "door", "con un ladrón en el umbral la puerta no se cierra ni se ofrece")
	check(not Den.toggle_door("salon_trofeos", m.house.band_points()) and Den.is_open("salon_trofeos"), "... y no se cierra")
	t0.y = 10.5
	check(Den.toggle_door("salon_trofeos", m.house.band_points()), "en cuanto se aparta, se cierra")
	dv.set_door("salon_trofeos", false)
	m.house.home_sight(true)
	check(not dv.shows("trofeos") and Museum.blocks_move(9.5, 9.5), "cerrada, la sala vuelve a oscurecerse")
	# One in the dojo, one in the bathroom: the union of the three rooms.
	m.thieves[0].x = 25.5
	m.thieves[0].y = 5.5
	m.thieves[1].x = 25.5
	m.thieves[1].y = 33.5
	m.house.home_sight(true)
	check(dv.shows("salon") and dv.shows("dojo") and dv.shows("aseo") and not dv.shows("trofeos"), "ladrones repartidos por tres salas: se ven esas tres")
	m.thieves[2].x = 10.5
	m.thieves[2].y = 5.0
	m.house.home_sight(true)
	check(dv.shows("trofeos"), "... y con otro en los trofeos, las cuatro")

	# Los trofeos no llevan calcetín: donde el botín es un calcetín, una estrella.
	Story.keep_stars(24, 1, Story.STAR_TAKEN)
	m.mode = Practice.MODE
	m.players = 1
	m._new_round(1)
	var gold_stars: Array = m.den_view.find_children("*", "Label3D", true, false).filter(func(l: Label3D) -> bool: return l.text == "★" and l.font_size == 96)
	check(Story.LEVELS[23].loot.shape == "sock", "el robo 24 roba un calcetín")
	check(Den.is_filled(24, 1) and gold_stars.size() == 1, "lleno, su puesto enseña una estrella (%d), no un calcetín" % gold_stars.size())
	var pedestals2 := Practice.trial_starts(1).filter(func(g): return g.via == "sock").size()
	check(_socks_in(m.den_view) == pedestals2 + 1, "y en toda la casa solo quedan los pedestales de PILLA EL CALCETÍN y la bandera: %d" % _socks_in(m.den_view))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
