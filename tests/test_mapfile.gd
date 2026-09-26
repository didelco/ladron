extends SceneTree
## Saved maps (MapFile), for the challenges:
##   - a generated museum, saved and read back, is the same museum as
##     Museum.regenerate builds from its seed, galleries' names and all;
##   - what makes a map unplayable is caught (a hole to the outside, a closed
##     room, no piece, no door...);
##   - a saved map plays: its piece, its door and its guards where it says,
##     and the job can be done.
##   godot --headless --script tests/test_mapfile.gd

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


func _init() -> void:
	_round_trip()
	_invalid()
	_on_disk()
	_plays()
	_heist()
	if failures.is_empty():
		print("OK: mapas guardados")
		quit(0)
	else:
		printerr("%d fallos" % failures.size())
		quit(1)


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

	m = good.copy()
	m.guards.append(Vector2i(7, 5))
	check(m.check().has("EDITOR_ERR_GUARD"), "un guardia sobre una vitrina se rechaza")

	# Painting over things takes them off.
	m = good.copy()
	m.piece = Vector2i(7, 5)
	m.guards.append(Vector2i(3, 3))
	m.put(Vector2i(7, 5), Tiles.FLOOR)
	m.put(Vector2i(3, 3), Tiles.WALL)
	check(m.piece == MapFile.NONE and m.guards.is_empty(), "pintar encima quita la pieza y el guardia")

	# A ready-made room: its gallery, its dinosaur, no door into the outer wall.
	m = MapFile.blank(23, 17)
	m.stamp(MapEditor.TEMPLATES[5].rows, Vector2i(1, 1), true)
	check(m.rooms.size() == 1 and m.rooms[0] == Rect2i(2, 2, 9, 7) and m.big.size() == 1 and m.big[0].kind == "dinosaur", "la sala del dinosaurio: su sala y su dinosaurio")
	check(m.at(Vector2i(6, 1)) == Tiles.WALL and m.at(Vector2i(6, 9)) == Tiles.FLOOR, "la puerta contra el muro exterior se queda en muro; la de dentro, abierta")
	check(m.check().is_empty(), "y se puede jugar: %s" % [m.check()])


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
	m.guards = [open[0], open[-1]]
	m.props = [{"kind": "bust", "at": open[open.size() / 2]}]
	check(m.check().is_empty(), "el mapa colocado a mano es válido: %s" % [m.check()])

	seed(1)
	Sim.gang = 1
	Sim.custom = m.tuning()
	m.apply()
	var guards := Sim.new_guards(Sim.guard_count(Museum.size_name))
	Sim.place_guards(guards, m.guards)
	Heist.plan_job(1, {}, 1, m.job())
	check(guards.size() == 2 and Vector2i(int(guards[0].x), int(guards[0].y)) == m.guards[0], "dos guardias, donde dice el mapa")
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
