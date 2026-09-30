extends SceneTree
## Saved maps (MapFile), for the challenges:
##   - a generated museum, saved and read back, is the same museum as
##     Museum.regenerate builds from its seed, galleries' names and all;
##   - what makes a map unplayable is caught (a hole to the outside, a closed
##     room, no piece, no door...);
##   - a saved map plays: its piece, its door and its guards where it says,
##     and the job can be done;
##   - a story night's museum, taken as a map, builds the same museum and the
##     same job; saved, the night finds it, and taken away it builds its own.
##   godot --headless --script tests/test_mapfile.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func _init() -> void:
	_round_trip()
	_invalid()
	_on_disk()
	_doors()
	_columns()
	_auto_columns()
	_guard_traits()
	_plays()
	_heist()
	_story_nights()
	quit(qa.summary())


## Everything a museum is, as one string.
## The piece, its tale and the pieces chosen for the cases: kept on disk,
## and the piece is what the job steals.
func _heist() -> void:
	var m := MapFile.generated(777, "small")
	check(m.loot_piece().is_empty(), "sin pieza elegida, la elige el juego")
	m.loot = {"shape": "duck", "colour": "#ffd43b", "name": "el patito de la reina", "blurb": "De goma.", "story": "La reina lo echa de menos.", "seconds": 4.0}
	var t: Vector2i = m.piece_spots(m.distances(m.spawn))[0]
	m.exhibits[t] = "bear"
	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(back.loot == m.loot, "la pieza y su historia se guardan")
	check(back.exhibits.get(t, "") == "bear", "la pieza de una vitrina se guarda")
	back.apply()
	Heist.plan_job(1, back.loot_piece(), 1, back.job())
	check(Heist.loot.name == "el patito de la reina" and Heist.loot.story == "La reina lo echa de menos." and Heist.loot.shape == "duck" and Heist.loot.seconds == 4.0,
		"el golpe roba la pieza del mapa")


func _story_nights() -> void:
	var same := 0
	var nights := [1, 5, 9, 14, 20]
	for n in nights:
		var night := Story.level(n)
		Sim.custom = Story.tuning(n)
		var seed_ := Story.seed_for(n, 1)
		Sim.new_map(seed_, night.size, -1, night.shape)
		Heist.plan_job(n, night.loot, 1, {})
		var want := _museum_print() + "%s %s" % [Heist.at, Heist.exit]
		var none: Array[GuardSpawn] = []
		var m := MapFile.from_museum(n, seed_, none)
		var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
		back.apply()
		Heist.plan_job(n, night.loot, 1, back.job())
		if _museum_print() + "%s %s" % [Heist.at, Heist.exit] == want and back.night == n:
			same += 1
	check(same == nights.size(), "el museo de una noche, como mapa, es el mismo museo y el mismo golpe (%d de %d)" % [same, nights.size()])
	Sim.custom = {}
	var made := MapFile.generated(4242, "small")
	made.night = 99
	made.name = "noche de prueba"
	check(made.save() == OK and made.path == MapFile.story_file(99), "el mapa de una noche se guarda donde la noche lo busca")
	var found := MapFile.for_night(99)
	check(found != null and found.night == 99 and found.grid == made.grid, "la noche encuentra su mapa")
	check(not MapFile.list().any(func(x: MapFile) -> bool: return x.night == 99), "y no sale entre los retos")
	MapFile.remove(found)
	check(MapFile.for_night(99) == null, "volver al original lo quita")


func _museum_print() -> String:
	var s := "%d %d %d|%s|%s|%s|%s|%s|%s|%s|" % [Museum.w, Museum.h, Museum.seed_used, Museum.grid, Museum.outside, Museum.ring,
		Museum.spawn, Museum.big_pieces, Museum.watchpoints, Museum.size_name]
	for r in Museum.rooms:
		s += "%s %s %s;" % [r.rect, r.switch_at, r.face]
	for z in Museum.zones:
		s += "%s %s %d %s;" % [z.name, z.label, z.room, z.tiles]
	return s


func _round_trip() -> void:
	var same := 0
	var valid := 0
	var n := 0
	for size in ["small", "medium", "large"]:
		for k in 8:
			var seed := 500 + n * 104729
			n += 1
			Museum.regenerate(seed, size)
			var want := _museum_print()
			var m := MapFile.generated(seed, size)
			var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
			back.apply()
			if _museum_print() == want:
				same += 1
			else:
				print("    distinto: %s/%d" % [size, seed])
			var errors := back.check()
			if errors.is_empty():
				valid += 1
			else:
				print("    %s/%d: %s" % [size, seed, errors])
	check(same == n, "guardar y leer un museo generado da el mismo museo (%d de %d)" % [same, n])
	check(valid == n, "los museos generados pasan la comprobación (%d de %d)" % [valid, n])


## A small good map, and the ways to spoil it.
func _invalid() -> void:
	var good := MapFile.blank(15, 11)
	good.put(Vector2i(7, 5), Tiles.COVER)
	check(good.check().is_empty(), "una sala con una vitrina vale: %s" % [good.check()])

	var m := good.copy()
	m.put(Vector2i(0, 3), Tiles.FLOOR)
	check(m.check().has("EDITOR_ERR_OPEN"), "un hueco en el muro exterior se rechaza")

	m = good.copy()
	m.put(Vector2i(3, 3), MapFile.OUT_TILE)
	check(m.check().has("EDITOR_ERR_OPEN"), "el exterior pegado al suelo se rechaza")

	m = good.copy()
	for t in [Vector2i(10, 1), Vector2i(10, 2), Vector2i(10, 3), Vector2i(11, 3), Vector2i(12, 3), Vector2i(13, 3)]:
		m.put(t, Tiles.WALL)
	check(m.check().has("EDITOR_ERR_CLOSED"), "un cuarto cerrado se rechaza")

	m = good.copy()
	m.put(Vector2i(7, 5), Tiles.FLOOR)
	check(m.check().has("EDITOR_ERR_PIECE"), "sin vitrinas no hay pieza")

	m = good.copy()
	m.piece = Vector2i(4, 4)
	check(m.check().has("EDITOR_ERR_PIECE"), "la pieza en el suelo se rechaza")

	m = good.copy()
	m.exit = Vector2i(7, 3)
	check(m.check().has("EDITOR_ERR_EXIT"), "una puerta lejos del muro exterior se rechaza")
	m.exit = Vector2i(13, 5)
	check(m.check().is_empty(), "una puerta contra el muro exterior vale")

	m = good.copy()
	m.spawn = Vector2i(0, 0)
	check(m.check().has("EDITOR_ERR_SPAWN"), "la entrada en un muro se rechaza")

	var guard_at := func(t: Vector2i) -> GuardSpawn:
		var g := GuardSpawn.new()
		g.at = t
		return g

	m = good.copy()
	m.guards.append(guard_at.call(Vector2i(7, 5)))
	check(m.check().has("EDITOR_ERR_GUARD"), "un guardia sobre una vitrina se rechaza")

	# Painting over things takes them off.
	m = good.copy()
	m.piece = Vector2i(7, 5)
	m.guards.append(guard_at.call(Vector2i(3, 3)))
	m.put(Vector2i(7, 5), Tiles.FLOOR)
	m.put(Vector2i(3, 3), Tiles.WALL)
	check(m.piece == MapFile.NONE and m.guards.is_empty(), "pintar encima quita la pieza y el guardia")

	# A ready-made room: its gallery, its dinosaur, no door into the outer wall.
	m = MapFile.blank(23, 17)
	m.stamp(MapEditor.TEMPLATES[5].rows, Vector2i(1, 1), true)
	check(m.rooms.size() == 1 and m.rooms[0] == Rect2i(2, 2, 9, 7) and m.big.size() == 1 and m.big[0].kind == "dinosaur", "la sala del dinosaurio: su sala y su dinosaurio")
	check(m.at(Vector2i(6, 1)) == Tiles.WALL and m.at(Vector2i(6, 9)) == Tiles.FLOOR, "la puerta contra el muro exterior se queda en muro; la de dentro, abierta")
	check(m.check().is_empty(), "y se puede jugar: %s" % [m.check()])


## A challenge's own doors (MapFile.doors, like Den's in the band's house):
## marked on a wall tile, they count as floor to walk to (distances, check),
## save and load back, and the night begins with them shut (Museum), a
## guard's sight and everyone's feet seeing a wall until someone opens one.
func _doors() -> void:
	var m := MapFile.blank(15, 11)
	# A wall splitting the room in two, with one gap marked as a door.
	for y in range(1, 10):
		m.put(Vector2i(7, y), Tiles.WALL)
	m.doors.append(Vector2i(7, 5))
	m.put(Vector2i(9, 5), Tiles.COVER)
	m.piece = Vector2i(9, 5)
	m.exit = Vector2i(13, 5)
	check(m.check().is_empty(), "una sala tras una puerta se puede jugar: %s" % [m.check()])
	check(m.door_fits(Vector2i(7, 5)), "un tramo recto de muro (dos lados opuestos) vale para una puerta")

	# The two tiles of floor right where the door opens, not any floor near it.
	check(m.door_clear(Vector2i(7, 5)), "con el paso libre a los dos lados, la puerta no está bloqueada")
	check(m.blocks_door(Vector2i(6, 5)) and m.blocks_door(Vector2i(8, 5)), "las dos casillas por las que se cruza la puerta cuentan como su paso")
	check(not m.blocks_door(Vector2i(7, 4)), "una casilla fuera de ese eje no cuenta")

	# A case, an exhibit or a big piece right outside it (Tiles.COVER either
	# way) leaves the door open on paper but not to walk through.
	var cased := m.copy()
	cased.put(Vector2i(8, 5), Tiles.COVER)
	check(not cased.door_clear(Vector2i(7, 5)), "una vitrina justo al salir de la puerta la deja bloqueada")
	check(cased.check().has("EDITOR_ERR_DOOR_BLOCKED"), "y el chequeo general lo detecta")

	# A prop stands on plain floor (props is its own list): blocks the same way.
	var propped := m.copy()
	propped.props.append({"kind": "bin", "at": Vector2i(6, 5)})
	check(not propped.door_clear(Vector2i(7, 5)), "un objeto tirado ahí también la bloquea, aunque la casilla siga siendo suelo")
	check(propped.check().has("EDITOR_ERR_DOOR_BLOCKED"), "y se detecta igual")

	# A corner (an L, not a straight stretch): the tile itself a wall, with
	# wall to the south and to the east but floor the other two ways — a
	# door there would cut into the building at an angle, not straight
	# through.
	var corner := m.copy()
	corner.put(Vector2i(5, 5), Tiles.WALL)
	corner.put(Vector2i(5, 6), Tiles.WALL)
	corner.put(Vector2i(6, 5), Tiles.WALL)
	check(not corner.door_fits(Vector2i(5, 5)), "una esquina no vale para una puerta")
	corner.doors.append(Vector2i(5, 5))
	check(corner.check().has("EDITOR_ERR_DOOR"), "una puerta en una esquina se rechaza")

	var without := m.copy()
	without.doors.clear()
	check(without.check().has("EDITOR_ERR_CLOSED") or without.check().has("EDITOR_ERR_PIECE"), "sin marcarla como puerta, la sala queda incomunicada")

	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(back.doors == m.doors, "la puerta se guarda y se lee igual")
	check(back.at(Vector2i(7, 5)) == Tiles.WALL, "en el plano guardado, un muro más")

	m.put(Vector2i(7, 5), Tiles.FLOOR)
	check(m.doors.is_empty(), "pintar encima de la puerta la quita")
	m = back

	m.apply()
	var door := Vector2i(7, 5)
	check(Museum.doors == m.doors, "el museo toma las puertas del mapa")
	check(not Museum.is_door_open(door) and Museum.grid[5 * m.w + 7] == Tiles.WALL, "la noche empieza con la puerta cerrada, un muro más")
	check(Museum.door_near(Vector2i(6, 5)) == door and Museum.door_near(Vector2i(1, 1)) == MapFile.NONE, "junto a la puerta, esa puerta; lejos, ninguna")
	check(Museum.blocks_sight(7.5, 5.5), "cerrada, corta la vista")
	check(Museum.toggle_door(door, []) and Museum.is_door_open(door), "se abre")
	check(Museum.grid[5 * m.w + 7] == Tiles.FLOOR and not Museum.blocks_sight(7.5, 5.5), "y el hueco deja de ser muro y de cortar la vista")
	check(not Museum.toggle_door(door, [Vector2(7.5, 5.5)]) and Museum.is_door_open(door), "abierta y con alguien en el umbral, no se cierra")
	check(Museum.toggle_door(door, []) and not Museum.is_door_open(door), "sin nadie, se cierra")
	check(Museum.grid[5 * m.w + 7] == Tiles.WALL, "y vuelve a ser muro")
	check(not Museum.toggle_door(Vector2i(0, 0), []), "una puerta que no existe no hace nada")


## An exempt column (MapFile.columns): marked on a wall tile like a door, but
## it never opens — the plan still reads it as a plain wall (check, save and
## load, and Museum's grid once the round starts).
func _columns() -> void:
	var m := MapFile.blank(15, 11)
	for y in range(1, 10):
		m.put(Vector2i(7, y), Tiles.WALL)
	m.columns.append(Vector2i(7, 5))
	m.put(Vector2i(9, 5), Tiles.COVER)
	m.piece = Vector2i(9, 5)
	m.exit = Vector2i(13, 5)
	# Unlike a door, a column never opens: the wall it stands on still shuts
	# the room off completely.
	check(m.check().has("EDITOR_ERR_CLOSED") or m.check().has("EDITOR_ERR_PIECE"), "una columna no abre paso: la sala tras ella sigue incomunicada")

	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(back.columns == m.columns, "la columna se guarda y se lee igual")
	check(back.at(Vector2i(7, 5)) == Tiles.WALL, "en el plano guardado, un muro más")

	m.put(Vector2i(7, 5), Tiles.FLOOR)
	check(m.columns.is_empty(), "pintar encima de la columna la quita")

	# A door and a column never share a tile: marking one where the other
	# stands takes the first away.
	var mixed := MapFile.blank(15, 11)
	mixed.put(Vector2i(7, 5), Tiles.WALL)
	mixed.doors.append(Vector2i(7, 5))
	mixed.columns.append(Vector2i(7, 5))
	check(MapFile.from_dict(JSON.parse_string(JSON.stringify(mixed.to_dict()))).columns.is_empty(), "de vuelta del disco, una puerta ya marcada gana: no hay columna a la vez")

	m = back
	m.apply()
	var col := Vector2i(7, 5)
	check(Museum.columns == m.columns, "el museo toma las columnas del mapa")
	check(Museum.grid[5 * m.w + 7] == Tiles.WALL, "la columna sigue siendo un muro en la rejilla")
	check(Museum.blocks_sight(7.5, 5.5), "eso solo (Museum.blocks_sight, la pregunta llana) la sigue viendo muro entero")

	# But movement and sight are the real, narrower thing: not a solid tile,
	# only a small circle at the column's own centre.
	check(not Museum.blocks_move(7.5, 5.5), "para el movimiento ya no es un cuadrado sólido: Museum.blocks_move la deja pasar (Sim._resolve la trata aparte)")
	var centred := Sim._resolve(7.5, 5.5, Sim.BODY)
	var moved := Vector2(centred[0], centred[1]).distance_to(Vector2(7.5, 5.5))
	check(moved >= Museum.COLUMN_R + Sim.BODY - 0.001, "un cuerpo justo en el centro de la columna es apartado hasta rozar su círculo: %.3f" % moved)
	var grazing_x := 7.5 + Museum.COLUMN_R + Sim.BODY + 0.05
	var hug := Sim._resolve(grazing_x, 5.5, Sim.BODY)
	check(is_equal_approx(hug[0], grazing_x) and is_equal_approx(hug[1], 5.5), "pero pegado al borde de la casilla, sin tocar el círculo de la columna, no se le empuja: puede rodearla")
	check(not Museum.has_line_of_sight(6.0, 5.5, 9.0, 5.5), "una mirada que cruza el centro de la columna sí se corta")
	var graze_y := 5.5 + Museum.COLUMN_R + 0.1
	check(Museum.has_line_of_sight(6.0, graze_y, 9.0, graze_y), "una que solo roza la casilla, fuera del círculo, no se corta")


## A wall tile nobody marked, with no other wall touching it (MapFile.exempt_
## walls): the same treatment a hand-marked column gets, without anyone
## marking it — Museum.load_grid is where every museum (generated, from the
## editor, or a story night's) picks these up on its own.
func _auto_columns() -> void:
	var m := MapFile.blank(15, 11)
	var lone := Vector2i(7, 5)
	m.put(lone, Tiles.WALL)
	m.put(Vector2i(9, 5), Tiles.COVER)
	m.piece = Vector2i(9, 5)
	m.exit = Vector2i(13, 5)
	check(m.columns.is_empty(), "nadie la marcó a mano")
	check(MapFile.exempt_walls(m.grid, m.outside, m.w, m.h) == [lone], "un muro suelto, sin otro muro pegado, se detecta solo")
	check(m.check().is_empty(), "no corta ningún paso: se puede jugar igual: %s" % [m.check()])
	m.apply()
	check(Museum.columns.has(lone), "el museo la trata como columna sin que nadie la marcara")
	check(Museum.grid[lone.y * m.w + lone.x] == Tiles.WALL, "y sigue siendo un muro de verdad en la rejilla")

	# Pegado a otro muro (una pared normal, no suelta) no cuenta.
	var wall_pair := MapFile.blank(15, 11)
	for y in [4, 5]:
		wall_pair.put(Vector2i(7, y), Tiles.WALL)
	check(MapFile.exempt_walls(wall_pair.grid, wall_pair.outside, wall_pair.w, wall_pair.h).is_empty(), "un muro pegado a otro no es una columna")

	# El borde exterior del edificio nunca se vuelve columna: fuera de la
	# rejilla, o donde `out` diga que no hay edificio, cuenta como "no hay
	# muro" — así que un muro suelto de verdad (sin otro muro al lado) sigue
	# siendo el único que se detecta.
	var w := 7
	var h := 3
	var grid_ := PackedInt32Array()
	grid_.resize(w * h)
	grid_.fill(Tiles.FLOOR)
	var out_ := PackedByteArray()
	out_.resize(w * h)
	grid_[1 * w + 0] = Tiles.WALL # en el borde de la rejilla misma
	grid_[1 * w + 3] = Tiles.WALL # suelto de verdad, en medio
	out_[1 * w + 5] = 1 # "fuera del edificio" marcado a mano, dentro de la rejilla
	grid_[1 * w + 6] = Tiles.WALL # pegado a ese "fuera": tampoco cuenta
	var found := MapFile.exempt_walls(grid_, out_, w, h)
	check(found == [Vector2i(3, 1)], "solo el muro realmente suelto por dentro se detecta; el del borde de la rejilla y el pegado a 'fuera' no (%s)" % [found])


func _on_disk() -> void:
	var m := MapFile.generated(31337, "small")
	m.name = "Prueba de test ñ"
	m.difficulty = "hard"
	m.guard_count = 3
	check(m.save() == OK, "se guarda en %s" % m.path)
	check(m.path == "user://maps/prueba_de_test_n.json", "con un nombre de archivo limpio")
	var back := MapFile.read(m.path)
	check(back != null and JSON.stringify(back.to_dict()) == JSON.stringify(m.to_dict()), "y se lee igual")
	check(MapFile.list().any(func(x): return x.path == m.path), "sale en la lista de mapas")
	MapFile.remove(m)
	check(not FileAccess.file_exists(m.path), "y se borra")
	check(MapFile.from_dict(JSON.parse_string("{\"rows\": 3}")) == null, "un archivo que no es un mapa no se lee")
	for built in MapFile.list().filter(func(x): return x.built_in):
		check(built.check().is_empty(), "el reto de serie %s es válido: %s" % [built.name, built.check()])


## A guard's archetype, traits, stance and watch (GuardSpawn): saved and
## read back the same, and scale() stacks its traits onto one multiplier.
func _guard_traits() -> void:
	var m := MapFile.blank(15, 11)
	var g := GuardSpawn.new()
	g.at = Vector2i(3, 3)
	g.dir = PI * 0.5
	g.archetype = "dormilon"
	g.view_level = 2
	g.hearing_level = 1
	g.speed_level = 0
	g.stance = "post"
	g.watch = "room"
	m.guards.append(g)

	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	var bg: GuardSpawn = back.guards[0]
	check(bg.at == g.at and is_equal_approx(bg.dir, g.dir) and bg.archetype == g.archetype
		and bg.view_level == g.view_level and bg.hearing_level == g.hearing_level and bg.speed_level == g.speed_level
		and bg.stance == g.stance and bg.watch == g.watch,
		"arquetipo, niveles, guardia fija y a qué vigila se guardan igual: %s" % [[bg.at, bg.dir, bg.archetype, bg.view_level, bg.hearing_level, bg.speed_level, bg.stance, bg.watch]])

	check(is_equal_approx(g.scale("speed"), 0.7), "cansado (nivel 0) en la velocidad (%.3f)" % g.scale("speed"))
	check(is_equal_approx(g.scale("hearing"), 0.8), "duro de oído (nivel 1) en el oído (%.3f)" % g.scale("hearing"))
	check(g.scale("view") == 1.0, "vista en su nivel normal (2) no cambia nada")
	g.view_level = 0
	check(is_equal_approx(g.scale("view"), 0.6), "un tercer nivel se ajusta sin tocar los otros dos (%.3f)" % g.scale("view"))

	# A map saved before this existed: guards keep patrolling, at the plain
	# middle of every slider.
	var old := MapFile.from_dict({"rows": ["...", "...", "..."], "guards": [[1, 1]]})
	check(old.guards[0].stance == "round" and old.guards[0].view_level == 2 and old.guards[0].hearing_level == 2 and old.guards[0].speed_level == 2,
		"un guardia guardado antes de esto sigue en ronda, en el nivel normal de todo")


## A map with its piece, its door and two guards placed by hand, played as
## the game does it (Main._lay_out): the job goes where it says.
func _plays() -> void:
	var m := MapFile.generated(8080, "medium")
	var reach := m.distances(m.spawn)
	var pieces := m.piece_spots(reach)
	var doors := m.door_spots(reach)
	m.piece = pieces[pieces.size() / 2]
	m.exit = doors[0]
	var open: Array[Vector2i] = []
	for y in m.h:
		for x in m.w:
			if reach[y * m.w + x] > 12:
				open.append(Vector2i(x, y))
	var guard_at := func(t: Vector2i) -> GuardSpawn:
		var g := GuardSpawn.new()
		g.at = t
		return g
	m.guards = [guard_at.call(open[0]), guard_at.call(open[-1])]
	m.props = [{"kind": "bust", "at": open[open.size() / 2]}]
	check(m.check().is_empty(), "el mapa colocado a mano es válido: %s" % [m.check()])

	seed(1)
	Sim.gang = 1
	Sim.custom = m.tuning()
	# Standing still at the case (the pick: test_minigame).
	Sim.custom.lockpick = false
	m.apply()
	var guards := Sim.new_guards(Sim.guard_count(Museum.size_name))
	Sim.place_guards(guards, m.guards)
	Heist.plan_job(1, {}, 1, m.job())
	check(guards.size() == 2 and Vector2i(int(guards[0].x), int(guards[0].y)) == m.guards[0].at, "dos guardias, donde dice el mapa")
	check(Heist.at == m.piece, "la pieza en su vitrina")
	var wall := Heist.exit + Heist.exit_face
	check(Heist.exit == m.exit and Museum.is_wall(wall.x + 0.5, wall.y + 0.5) and Museum.is_outside(wall.x + Heist.exit_face.x, wall.y + Heist.exit_face.y), "la puerta donde dice el mapa, en el muro exterior")
	check(Heist.route.size() > 5 and Heist.route[0] == m.spawn and Heist.route[-1] == m.exit, "hay camino de la entrada a la pieza y a la puerta")
	check(m.put_props() and Props.list.size() == 1 and Props.list[0].kind == "bust", "el busto donde dice el mapa")

	# Take it and walk out, with the guards going about their round.
	var p := Sim.new_thief()
	var thieves: Array[Thief] = [p]
	var stand := Heist.route[0]
	for t in Heist.route:
		if Museum.dist(t.x + 0.5, t.y + 0.5, Heist.at.x + 0.5, Heist.at.y + 0.5) < 1.1:
			stand = t
			break
	p.x = stand.x + 0.5
	p.y = stand.y + 0.5
	var now := 1000.0
	var event := ""
	for i in 60 * 12:
		var noises: Array[SoundEvent] = []
		event = Heist.step(thieves, 1.0 / 60, now, noises)
		for g in guards:
			Sim.step_guard(g, [] as Array[Thief], noises, now, 1.0 / 60)
		now += 1000.0 / 60
		if event == "stolen":
			break
	check(event == "stolen", "la pieza se roba")
	p.x = Heist.exit.x + 0.5
	p.y = Heist.exit.y + 0.5
	var none: Array[SoundEvent] = []
	check(Heist.step(thieves, 1.0 / 60, now, none) == "out", "y se sale por la puerta")
	Sim.custom = {}
