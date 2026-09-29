extends SceneTree
## The story's museums, a theme each, and the progress kept for each size
## of gang, the old story's carried over.
##   godot --headless --script tests/test_story.gd

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


func _init() -> void:
	# The museums hold every heist once, in order: five rooms each, the last
	# the big job, and one theme each, the first prehistory.
	var all: Array[int] = []
	var themes := {}
	for m in Story.MUSEUMS.size():
		var nights := Story.nights_in(m)
		check(nights.size() == Story.ROOMS, "museo %d: %d robos" % [m + 1, nights.size()])
		for n in nights:
			check(Story.museum_of(n) == m, "el robo %d está en el museo %d" % [n, m + 1])
			check(Story.is_boss(n) == (n == nights[-1]), "robo %d: %s" % [n, "el gran golpe, el último" if Story.is_boss(n) else "una sala"])
			check(Story.tuning(n).theme == Story.MUSEUMS[m].theme, "el robo %d, del tema de su museo" % n)
		check(String(Story.LEVELS[nights[-1] - 1].get("tip", "")) != "", "museo %d: su gran golpe dice qué tiene de especial" % [m + 1])
		all.append_array(nights)
		themes[Story.MUSEUMS[m].theme] = true
		check(Themes.ALL.has(Story.MUSEUMS[m].theme), "museo %d: un tema de los cinco (%s)" % [m + 1, Story.MUSEUMS[m].theme])
		var look: Dictionary = Story.MUSEUMS[m].palette
		for k in MuseumView.THEMES[0]:
			check(look.has(k), "museo %d: su paleta tiene %s" % [m + 1, k])
		check(Story.museum(m).name != Story.MUSEUMS[m].name, "museo %d: con nombre (%s)" % [m + 1, Story.museum(m).name])
	check(themes.size() == Themes.ALL.size() and Story.MUSEUMS[0].theme == "prehistoria", "cinco museos, cinco temas, el primero la prehistoria")
	var in_order := all.size() == Story.count() and Story.count() == 25
	for i in all.size():
		in_order = in_order and all[i] == i + 1
	check(in_order, "los %d robos, cada uno en un museo y en orden" % Story.count())
	var looks := {}
	for m in Story.MUSEUMS.size():
		looks[str(Story.MUSEUMS[m].palette.paper) + str(Story.MUSEUMS[m].palette.stone)] = true
	check(looks.size() == Story.MUSEUMS.size(), "cada museo con sus colores de pared y suelo")

	# A theme a museum: every gallery, and only its own big pieces.
	for m in Story.MUSEUMS.size():
		var n := Story.nights_in(m)[-1]
		var night := Story.level(n)
		Sim.custom = Story.tuning(n)
		Sim.new_map(Story.seed_for(n), night.size, -1, night.shape)
		var ok: bool = Museum.only_theme == Story.MUSEUMS[m].theme
		for r in Museum.rooms:
			ok = ok and r.theme == Story.MUSEUMS[m].theme
		for b in Museum.big_pieces:
			ok = ok and Themes.for_big(b.kind) in [Story.MUSEUMS[m].theme, ""]
		check(ok, "museo %d (robo %d): todo de %s, %d piezas grandes" % [m + 1, n, Story.MUSEUMS[m].theme, Museum.big_pieces.size()])
	Sim.custom = {}
	Sim.new_map(4242, "medium")
	check(Museum.only_theme == "", "fuera de la historia, los temas se mezclan")

	# The pick's pins never go down along the story but where a museum
	# starts; and the first museum stands still at the case, no pick.
	var pins_up := true
	var last_pins := 0
	for n in range(Story.LOCKPICK_NIGHT, Story.count() + 1):
		var pins := Minigame.pins_for(float(Story.LEVELS[n - 1].loot.seconds))
		if pins < last_pins and Story.room_of(n) != 1:
			pins_up = false
			print("    robo %d: %d pernos tras %d" % [n, pins, last_pins])
		last_pins = pins
	check(pins_up, "los pernos de la ganzúa no bajan dentro de un museo")
	check(not Story.tuning(Story.LOCKPICK_NIGHT - 1).lockpick and Story.tuning(Story.LOCKPICK_NIGHT).lockpick, "sin ganzúa en el primer museo")
	# And the plan says which: still for so long, or the pick and its pins.
	for n in [3, Story.LOCKPICK_NIGHT, 14]:
		Sim.custom = Story.tuning(n)
		Heist.loot = Story.level(n).loot
		var line := Briefing.takes()
		var want: String = "quieto 2 segundos" if n == 3 else ("un perno" if n == Story.LOCKPICK_NIGHT else "3 pernos")
		check(line.contains(want), "robo %d: «%s»" % [n, line])
	Sim.custom = {}

	# The progress: its own for each gang, and the old saves carried over.
	Story.save = "user://test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	check(Story.unlocked(1) == 1 and Story.unlocked(3) == 1, "sin partida guardada, solo el primer robo")
	var old := ConfigFile.new()
	old.set_value("story", "unlocked", 7)
	old.save(Story.save)
	check(Story.unlocked(1) == 8, "la partida de antes de las bandas (noche 7 de 20) pasa a ser la de 1 jugador: robo %d" % Story.unlocked(1))
	check(Story.unlocked(2) == 1, "y no abre nada a 2 jugadores (%d)" % Story.unlocked(2))
	old.set_value("story", "unlocked_3", 20)
	old.set_value("story", "unlocked_4", 5)
	old.save(Story.save)
	check(Story.unlocked(3) == 24 and Story.unlocked(4) == 6, "la de 20 noches: museos hechos, museos hechos; noche 20 es el robo %d, noche 5 el %d" % [Story.unlocked(3), Story.unlocked(4)])
	var map := {1: 1, 4: 4, 5: 6, 8: 9, 9: 11, 13: 16, 17: 21, 20: 24}
	var carried := true
	for night in map:
		carried = carried and Story.from_old(night) == map[night]
	check(carried, "de las noches de antes a los robos de ahora, museo a museo")
	Story.unlock(4, 2)
	check(Story.unlocked(2) == 4 and Story.unlocked(1) == 8 and Story.unlocked(4) == 6, "ganar con 2 abre el robo solo para 2")
	Story.unlock(3, 2)
	check(Story.unlocked(2) == 4, "no se retrocede")
	Story.unlock(9, 1)
	check(Story.unlocked(1) == 9, "1 jugador sigue su camino (%d)" % Story.unlocked(1))
	Story.unlock(3, 3)
	check(Story.unlocked(3) == 24, "lo que se traía de antes no se pierde al jugar (%d)" % Story.unlocked(3))
	Story.unlock(99, 4)
	check(Story.unlocked(4) == Story.count(), "nunca más allá del último robo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.save = Story.SAVE

	if failures.is_empty():
		print("OK: la historia, por museos y por jugadores")
		quit(0)
	else:
		printerr("%d fallos" % failures.size())
		quit(1)
