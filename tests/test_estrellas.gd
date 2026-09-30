extends SceneTree
## Las estrellas de la historia: cuáles gana un intento, el objetivo de
## tiempo de cada robo (alcanzable: nunca por debajo de lo que se tarda en
## hacerlo corriendo sin guardias), lo que se guarda para cada tamaño de
## banda sin perder nada al repetir peor ni tocar el resto del progreso, y
## lo que el periódico enseña.
##   godot --headless --script tests/test_estrellas.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


## Story night n laid out alone as the game does it (Main._lay_out and
## _story_seed): its hand-made map, or its seed, the first of its seeds
## where its guard's post holds if it has one.
func lay_out(n: int) -> void:
	Sim.gang = 1
	Sim.custom = Story.tuning(n)
	var night := Story.level(n)
	var hand := MapFile.for_night(n)
	if hand:
		seed(hand.seed)
		Museum.only_theme = String(Sim.custom.get("theme", ""))
		hand.apply()
		Heist.plan_job(n, night.loot, 1, hand.job())
		return
	var base := Story.seed_for(n)
	var tries := Story.LESSON_TRIES if night.get("post", "") != "" else 1
	for k in tries:
		var map_seed := base + k * Story.SEED_STEP
		seed(map_seed)
		Sim.new_map(map_seed, night.size, -1, night.shape)
		var guards := Sim.new_guards(Sim.guard_count(Museum.size_name))
		Heist.plan_job(n, night.loot, 1)
		if tries == 1:
			return
		var stand := Heist.route[0]
		for t in Heist.route:
			if Museum.dist(t.x + 0.5, t.y + 0.5, Heist.at.x + 0.5, Heist.at.y + 0.5) < 1.1:
				stand = t
				break
		if Sim.feature("props"):
			Props.place(map_seed, [Heist.exit, Heist.panel, Heist.panel2, stand, Heist.start])
		else:
			Props.list.clear()
		if Sim.assign_posts(guards) > 0:
			return


func _init() -> void:
	Story.save = "user://test_estrellas.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))

	# What a go wins: nothing caught; the piece out, the first; unseen and
	# under the par, the other two, each on its own.
	var par := Story.par(7)
	check(Story.earned(7, false, 0, 1.0) == 0, "pillado: ninguna estrella, aunque nadie te viera y fueras rápido")
	check(Story.earned(7, true, 3, par + 10) == Story.STAR_TAKEN, "escapar con la pieza: la primera")
	check(Story.earned(7, true, 0, par + 10) == Story.STAR_TAKEN | Story.STAR_UNSEEN, "sin que te vean: la segunda")
	check(Story.earned(7, true, 1, par) == Story.STAR_TAKEN | Story.STAR_FAST, "justo en el objetivo (%d s) cuenta como rápido" % par)
	check(Story.earned(7, true, 0, par - 1) == 7 and Story.count_stars(7) == 3, "las tres")
	check(Story.earned(7, true, 0, par + 0.5) & Story.STAR_FAST == 0, "medio segundo tarde, sin la de rápido")

	# The pars: one for every heist, in whole five seconds, a gang's never
	# shorter; each big job's the longest of its museum, and each museum
	# longer in all than the one before.
	var round_fives := true
	var gangs_longer := true
	for n in range(1, Story.count() + 1):
		round_fives = round_fives and Story.LEVELS[n - 1].has("par") and int(Story.par(n)) % 5 == 0 and Story.par(n) > 0
		for p in [2, 3, 4]:
			gangs_longer = gangs_longer and Story.par(n, p) >= Story.par(n, p - 1) and int(Story.par(n, p)) % 5 == 0
	check(round_fives, "cada robo con su objetivo de tiempo, en múltiplos de 5 s")
	check(gangs_longer, "una banda tiene algo más de tiempo, nunca menos")
	var last_total := 0.0
	var rising := true
	for m in Story.MUSEUMS.size():
		var total := 0.0
		for n in Story.nights_in(m):
			total += Story.par(n)
			if not Story.is_boss(n):
				rising = rising and Story.par(n) < Story.par(Story.nights_in(m)[-1])
		rising = rising and total > last_total
		last_total = total
	check(rising, "cada gran golpe pide más tiempo que sus salas, y cada museo más que el anterior")

	# Reachable: never under the time it takes to run the way (in, to the
	# case, out: Heist.route) at full speed with nobody about and do the job
	# at its quickest — with a quarter more to spare.
	var reachable := true
	for n in range(1, Story.count() + 1):
		lay_out(n)
		var run := (Heist.route.size() - 1) / Sim.TOP_SPEED
		var job := Minigame.pins_for(float(Heist.loot.seconds)) * 0.3 if Heist.minigames() else float(Heist.loot.seconds)
		var least := run + job
		var ok := Story.par(n) >= least * 1.25
		reachable = reachable and ok
		print("  robo %2d: objetivo %3d s · corriendo sin guardias %.1f s" % [n, Story.par(n), least])
		if not ok:
			print("    ¡por debajo!")
	check(reachable, "ningún objetivo por debajo del mínimo teórico del robo (con un 25 % de margen)")

	# The goals on the plan: three short lines, the time as on the paper.
	var goals := Story.goals(7)
	check(goals.size() == 3 and goals[2] == Text.t("STAR_GOAL_FAST") % "0:25", "los tres objetivos del robo 7: %s" % [goals])
	check(Story.goals(25)[2].ends_with("2:25") and Story.goals(3, 2)[1] == Text.t("STAR_GOAL_UNSEEN_MANY"), "en minutos, y a una banda en plural: %s" % [Story.goals(25)])
	check(goals.all(func(g: String) -> bool: return g.split(" ").size() <= 4), "cortos: cuatro palabras como mucho")

	# Kept: the best of each heist for each size of gang; a worse go takes
	# nothing away, and two goes can win two different ones.
	check(Story.stars(7) == 0 and Story.stars_in(1) == 0, "sin progreso, ninguna")
	check(Story.keep_stars(7, 1, Story.STAR_TAKEN | Story.STAR_UNSEEN) == Story.STAR_TAKEN | Story.STAR_UNSEEN, "las primeras, nuevas")
	check(Story.keep_stars(7, 1, Story.STAR_TAKEN) == 0 and Story.stars(7) == 2, "repetir peor no quita ninguna (%d)" % Story.stars(7))
	check(Story.keep_stars(7, 1, Story.STAR_TAKEN | Story.STAR_FAST) == Story.STAR_FAST and Story.stars(7) == 3, "otro intento rápido suma la que faltaba: las tres")
	check(Story.star_mask(7) == 7 and Story.stars(7, 2) == 0, "solo para quien las ganó: a dos, ninguna")
	Story.keep_stars(8, 2, Story.STAR_TAKEN)
	Story.keep_stars(10, 1, Story.STAR_TAKEN)
	check(Story.stars(8, 2) == 1 and Story.stars(8) == 0, "cada banda, las suyas")
	check(Story.stars_in(1) == 4 and Story.stars_in(1, 2) == 1 and Story.stars_in(0) == 0, "el total de un museo: %d/%d" % [Story.stars_in(1), Story.STARS_EACH * Story.ROOMS])
	check(Story.keep_stars(0, 1, 7) == 0 and Story.keep_stars(99, 1, 7) == 0, "fuera de la historia no se guarda nada")

	# With the rest of the progress: how far each gang got (and the old
	# twenty nights carried over) untouched by the stars, and the other way.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var old := ConfigFile.new()
	old.set_value("story", "unlocked", 7)
	old.set_value("story", "unlocked_3", 20)
	old.save(Story.save)
	Story.keep_stars(3, 1, 3)
	check(Story.unlocked(1) == 8 and Story.unlocked(3) == 24, "guardar estrellas no toca lo que se traía de las 20 noches (%d, %d)" % [Story.unlocked(1), Story.unlocked(3)])
	Story.unlock(9, 1)
	check(Story.unlocked(1) == 9 and Story.stars(3) == 2, "ni abrir un robo toca las estrellas")
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	check(cfg.has_section_key("story", "unlocked") and cfg.has_section_key("stars", "robo_1"), "todo en el mismo progreso, cada cosa en su sitio")
	cfg.set_value("stars", "robo_1", "roto")
	cfg.save(Story.save)
	check(Story.stars(3) == 0 and Story.unlocked(1) == 9, "unas estrellas estropeadas se leen como ninguna, sin romper nada")

	# A go, as the game rates it: its stars and which are new.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	HeistStats.reset()
	HeistStats.time = Story.par(4) - 5
	HeistStats.rate(4, 1, true)
	check(HeistStats.stars == 7 and HeistStats.fresh == 7, "rápido y sin que te vean: las tres, nuevas")
	HeistStats.reset()
	check(HeistStats.stars == 0 and HeistStats.fresh == 0, "a cero al empezar otro intento")
	HeistStats.add("seen")
	HeistStats.time = Story.par(4) + 30
	HeistStats.rate(4, 1, true)
	check(HeistStats.stars == Story.STAR_TAKEN and HeistStats.fresh == 0 and Story.stars(4) == 3, "repetido peor: una, ninguna nueva, siguen las tres")
	check(HeistStats.star_row() == [[true, false], [false, false], [false, false]], "la fila del periódico: [ganada, nueva] %s" % [HeistStats.star_row()])
	HeistStats.reset()
	HeistStats.time = 1.0
	HeistStats.rate(5, 1, true, false)
	check(HeistStats.fresh == 7 and Story.stars(5) == 0, "solo mirando: nuevas las que no tiene el progreso, y no se guarda nada")
	HeistStats.rate(4, 1, true, false)
	check(HeistStats.fresh == 0, "…y las que ya tiene, no son nuevas")
	HeistStats.rate(6, 1, false)
	check(HeistStats.stars == 0 and HeistStats.star_row().all(func(s: Array) -> bool: return not s[0]), "pillado: ninguna")

	# On the paper: the stars under the headline, the new ones red.
	HeistStats.reset()
	var page := EndPages.newspaper({"name": "X", "headline": "Y", "figures": [["1:00", "TIEMPO"]],
		"stars": [[true, false], [true, true], [false, false]], "star_names": ["A", "B", "C"]})
	var labels: Array[String] = []
	for l in page.find_children("*", "Label", true, false):
		labels.append((l as Label).text)
	check(labels.has("A") and labels.has("C") and labels.find("Y") < labels.find("A"), "tres estrellas con su nombre, bajo el titular: %s" % [labels])
	var bare := EndPages.newspaper({"name": "X", "headline": "Y", "figures": []})
	check(bare.find_children("*", "Label", true, false).size() == 2, "sin estrellas (fuera de la historia), el periódico de siempre")
	page.free()
	bare.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.save = Story.SAVE
	quit(qa.summary())
