extends SceneTree
## What stands on the cases (Collection): the same museum always the same;
## an icon (Themes.UNIQUE) once at most; each arcade machine a different game,
## never the same one twice; the machines you play on (Arcades) exactly where
## the view stands them, in the game's colours; and what a map set by hand,
## kept.
##   godot --headless --script tests/test_collection.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


## A night as the game lays it out (main._lay_out).
func night(sd: int, size: String) -> void:
	seed(sd)
	Sim.new_map(sd, size)
	Heist.plan_job(1, {}, 1, {})
	Plinths.list.clear()
	Hideouts.pieces.clear()
	Props.place(sd, [Heist.exit, Heist.panel, Heist.panel2, Heist.start])
	Hideouts.spread(sd, [Heist.at] as Array[Vector2i], true, true)
	Collection.lay_out()
	Arcades.find()


func _init() -> void:
	Sim.custom = {}
	check(Themes.VARIANTS[Arcades.MODEL] == MuseumView.ARCADE_GAMES.keys(), "cada juego de la recreativa tiene su aspecto (%d)" % MuseumView.ARCADE_GAMES.size())
	for piece in Themes.UNIQUE:
		check(MapGen.BIG.has(piece) or Themes.is_piece(piece), "%s, única, está en el catálogo" % piece)

	# Many museums, of every size, mixed and all modern (where the machines
	# are): no icon twice, no game twice.
	var museums := 0
	var twice := 0
	var repeated := 0
	var machines := 0
	var several := 0
	var most := 0
	var ran_out := 0
	var uniques := {}
	for only in ["", "moderna"]:
		# A museum of one theme, as a story night asks for it (Sim.new_map).
		Sim.custom = {"theme": only} if only != "" else {}
		for size in ["small", "medium", "large"]:
			for k in 25:
				var sd := 31 + k * 104729
				night(sd, size)
				museums += 1
				var count := {}
				for b in Museum.big_pieces:
					count[b.kind] = count.get(b.kind, 0) + 1
				for t in Collection.picks:
					var piece: String = Collection.picks[t][1]
					count[piece] = count.get(piece, 0) + 1
				for piece in Themes.UNIQUE:
					if count.get(piece, 0) > 1:
						twice += 1
						check(false, "%s %s semilla %d: %s %d veces" % [only, size, sd, piece, count[piece]])
					if count.get(piece, 0) == 1:
						uniques[piece] = true
				var games: Array = []
				for t in Arcades.list:
					games.append(Collection.variant_at(t))
				for g in games:
					if games.count(g) > 1:
						repeated += 1
					if g == "":
						repeated += 1
				machines += games.size()
				if games.size() > 1:
					several += 1
				most = maxi(most, games.size())
				if games.size() == Themes.variants(Arcades.MODEL).size():
					ran_out += 1
	Sim.custom = {}
	print("  %d museos, %d recreativas; con varias: %d; como mucho %d en uno; con todos los juegos: %d" % [museums, machines, several, most, ran_out])
	check(twice == 0, "ninguna pieza única sale dos veces en un museo")
	check(uniques.size() == Themes.UNIQUE.size(), "y todas salen alguna vez (%d de %d)" % [uniques.size(), Themes.UNIQUE.size()])
	check(repeated == 0, "ninguna recreativa repite juego en un museo")
	check(several > 10, "muchos museos tienen varias recreativas (%d)" % several)
	check(most <= Themes.variants(Arcades.MODEL).size(), "nunca más recreativas que juegos (%d)" % most)
	check(ran_out > 0, "alguno los tiene todos, y en el resto de sitios va otra pieza (%d)" % ran_out)

	# The same seed, the same museum.
	Sim.custom = {"theme": "moderna"}
	night(777, "large")
	var first := var_to_str(Collection.picks)
	var arcades := Arcades.list.duplicate()
	night(778, "large")
	night(777, "large")
	check(var_to_str(Collection.picks) == first and Arcades.list == arcades, "el mismo museo sale igual siempre (%d casillas)" % Collection.picks.size())
	Collection.ensure()
	check(var_to_str(Collection.picks) == first, "y no se vuelve a repartir si nada ha cambiado")

	# The view stands a machine exactly where you can play one, each dressed
	# as its game.
	var view := MuseumView.new()
	view.build()
	var drawn: Array[Vector2i] = []
	var dressed := 0
	for piece: Node3D in view.get_children():
		var machine := piece.find_child("recreativa", true, false)
		if machine == null:
			continue
		var screen := machine.find_child("pantalla", true, false) as MeshInstance3D
		var t := Vector2i(floori(piece.position.x + Museum.w / 2.0), floori(piece.position.z + Museum.h / 2.0))
		drawn.append(t)
		var side := piece.find_child("mueble", true, false) as MeshInstance3D
		var game := Collection.variant_at(t)
		if game != "" and side and (side.get_active_material(0) as BaseMaterial3D).albedo_color == Color(MuseumView.ARCADE_GAMES[game].mueble) \
				and screen and screen.get_child_count() == 1:
			dressed += 1
	drawn.sort()
	check(not drawn.is_empty() and drawn == Arcades.list, "las recreativas que se ven son las que se juegan (%d)" % drawn.size())
	check(dressed == drawn.size(), "cada una con los colores y la pantalla de su juego (%d de %d)" % [dressed, drawn.size()])
	view.free()
	Sim.custom = {}

	# A saved map: what it set by hand stays, a second icon too, and its
	# machines are played on, each a different game.
	var m := MapFile.generated(4242, "medium")
	m.apply()
	Heist.plan_job(1, {}, 1, m.job())
	var cases: Array[Vector2i] = []
	for c in Museum.cover_tiles:
		if Museum.big_piece_at(c).is_empty() and c != Heist.at and cases.size() < 4:
			cases.append(c)
	m.exhibits[cases[0]] = Arcades.MODEL
	m.exhibits[cases[1]] = Arcades.MODEL
	m.exhibits[cases[2]] = "temas/edad_media/trono"
	m.exhibits[cases[3]] = "temas/edad_media/trono"
	MuseumView.exhibits = m.exhibits.duplicate()
	Plinths.list.clear()
	Hideouts.pieces.clear()
	Collection.lay_out()
	Arcades.find()
	check(cases[0] in Arcades.list and cases[1] in Arcades.list, "las recreativas puestas a mano se juegan")
	check(Collection.variant_at(cases[0]) != Collection.variant_at(cases[1]), "y son juegos distintos (%s, %s)" % [Collection.variant_at(cases[0]), Collection.variant_at(cases[1])])
	check(Collection.at(cases[2])[1] == "temas/edad_media/trono" and Collection.at(cases[3])[1] == "temas/edad_media/trono", "lo puesto a mano se respeta, aunque sea una pieza única")
	var thrones := Collection.tiles_of("temas/edad_media/trono").size()
	check(thrones == 2, "y el museo no añade otro trono (%d)" % thrones)
	MuseumView.exhibits = {}

	quit(qa.summary())
