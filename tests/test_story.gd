extends SceneTree
## The story's museums and the progress kept for each size of gang.
##   godot --headless --script tests/test_story.gd

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


func _init() -> void:
	# The museums hold every night once, in order, a size each.
	var all: Array[int] = []
	for m in Story.MUSEUMS.size():
		var nights := Story.nights_in(m)
		check(nights.size() >= 3 and nights.size() <= 4, "museo %d: %d noches" % [m + 1, nights.size()])
		var sizes := {}
		for n in nights:
			sizes[Story.level(n).size] = true
			check(Story.museum_of(n) == m, "la noche %d está en el museo %d" % [n, m + 1])
		check(sizes.size() == 1, "museo %d: un solo tamaño (%s)" % [m + 1, ", ".join(sizes.keys())])
		all.append_array(nights)
		var look: Dictionary = Story.MUSEUMS[m].palette
		for k in MuseumView.THEMES[0]:
			check(look.has(k), "museo %d: su paleta tiene %s" % [m + 1, k])
		check(Story.museum(m).name != Story.MUSEUMS[m].name, "museo %d: con nombre (%s)" % [m + 1, Story.museum(m).name])
	var in_order := all.size() == Story.count()
	for i in all.size():
		in_order = in_order and all[i] == i + 1
	check(in_order, "las %d noches, cada una en un museo y en orden" % Story.count())
	var looks := {}
	for m in Story.MUSEUMS.size():
		looks[str(Story.MUSEUMS[m].palette.paper) + str(Story.MUSEUMS[m].palette.stone)] = true
	check(looks.size() == Story.MUSEUMS.size(), "cada museo con sus colores de pared y suelo")

	# The progress: its own for each gang, and the old save is the lone thief's.
	Story.save = "user://test_progress.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	check(Story.unlocked(1) == 1 and Story.unlocked(3) == 1, "sin partida guardada, solo la primera noche")
	var old := ConfigFile.new()
	old.set_value("story", "unlocked", 7)
	old.save(Story.save)
	check(Story.unlocked(1) == 7, "la partida de antes pasa a ser la de 1 jugador (%d)" % Story.unlocked(1))
	check(Story.unlocked(2) == 1, "y no abre nada a 2 jugadores (%d)" % Story.unlocked(2))
	Story.unlock(4, 2)
	check(Story.unlocked(2) == 4 and Story.unlocked(1) == 7 and Story.unlocked(4) == 1, "ganar con 2 abre la noche solo para 2")
	Story.unlock(3, 2)
	check(Story.unlocked(2) == 4, "no se retrocede")
	Story.unlock(8, 1)
	check(Story.unlocked(1) == 8, "1 jugador sigue su camino (%d)" % Story.unlocked(1))
	Story.unlock(99, 4)
	check(Story.unlocked(4) == Story.count(), "nunca más allá de la última noche")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.save = Story.SAVE

	if failures.is_empty():
		print("OK: la historia, por museos y por jugadores")
		quit(0)
	else:
		printerr("%d fallos" % failures.size())
		quit(1)
