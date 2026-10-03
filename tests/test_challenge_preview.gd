extends SceneTree
## Retos debe generar y seleccionar cada noche sin cambiar la partida que
## sigue detrás del menú ni separar sus actores de sus nodos de Scenery.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var game: Game


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func frames(n := 3) -> void:
	for i in n:
		await process_frame


func snapshot() -> Dictionary:
	var state := {}
	for script: Script in ChallengeScreens.layout_state:
		var fields := {}
		for field in String(ChallengeScreens.layout_state[script]).split(" "):
			var value: Variant = script.get(field)
			fields[field] = value.duplicate(true) if value is Array or value is Dictionary else value
		state[script] = fields
	return state


func unchanged(was: Dictionary) -> bool:
	for script: Script in was:
		for field in was[script]:
			if script.get(field) != was[script][field]:
				print("Estado alterado: ", script.resource_path, ".", field)
				return false
	return true


func traverse(label: String) -> void:
	game.challenges.night_maps.clear()
	game.challenges.show_workshop()
	await frames()
	var prior := snapshot()
	var actors := [game.thieves, game.guards]
	# Independent sentinels catch lost references even if a global is omitted
	# from the implementation's field list.
	var live_grid := Museum.grid
	var live_rooms := Museum.rooms
	var live_props := Props.list
	var live_loot := Heist.loot
	var job := [Heist.at, Heist.exit, Heist.progress, Heist.by]
	var tuning := [Sim.custom.duplicate(true), Sim.gang]
	var world := game.world
	var settings := [game.mode, game.players, game.level, game.saved_map]
	var counts := {}
	for n in range(1, Story.count() + 1):
		game.challenges.land_night(n)
		var m := game.challenges.night_as_map(n)
		counts[m.guards.size()] = true
		check(m.night == n and m.check().is_empty(), "%s: plano jugable de noche %d" % [label, n])
		check(Museum.grid == live_grid and is_same(Museum.rooms, live_rooms) and is_same(Props.list, live_props)
			and is_same(Heist.loot, live_loot) and job == [Heist.at, Heist.exit, Heist.progress, Heist.by]
			and tuning == [Sim.custom, Sim.gang], "%s: referencias originales y golpe conservados" % label)
		check(unchanged(prior), "%s: museo, golpe y objetos intactos tras noche %d" % [label, n])
		check(is_same(game.thieves, actors[0]) and is_same(game.guards, actors[1]) and game.world == world
			and settings == [game.mode, game.players, game.level, game.saved_map], "%s: actores y partida intactos tras noche %d" % [label, n])
		check(game.guards.size() == game.scenery.guard_nodes.size() and game.thieves.size() == game.scenery.thief_nodes.size(), "%s: actores y nodos sincronizados" % label)
		# Exercise the exact draw path that used to raise on Robo 2.
		game.scenery.draw_figures(0.016)
		await frames(1)
		# A caller may edit its returned map without contaminating the cache.
		m.name = "edited preview"
		check(game.challenges.night_as_map(n).name != m.name, "%s: copia independiente del plano" % label)
	check(counts.size() > 1, "%s: recorrido con distintos números de guardias" % label)
	check(is_same(Plinths.list, Placed.plinths) and is_same(Hideouts.pieces, Placed.furniture), "%s: alias de objetos conservados" % label)


func _init() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	await traverse("portada")
	# A previous multiplayer round has real guards, thieves, props and a
	# partially opened case: preserve it, rather than just avoiding an index.
	game.mode = "story"
	game.players = 2
	game._new_round(12)
	game.phase = "menu"
	Heist.progress = 0.42
	Heist.by = "p1"
	Museum.lights_left[0] = 1234.0
	await traverse("tras partida")
	quit(qa.summary())
