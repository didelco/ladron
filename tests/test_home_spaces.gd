extends SceneTree
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var game: Game
func _init() -> void: call_deferred("run")
func frames(n := 3) -> void:
	for i in n: await process_frame

func cross(target: String) -> void:
	var portal: Dictionary = Den.PORTALS.filter(func(p): return p.target == target)[0]
	var r: Array = portal.rect
	game.thieves[0].x = r[0] + r[2] / 2.0
	game.thieves[0].y = r[1] + r[3] / 2.0
	qa.check(game.house.home_tick(), "cruzar puerta cambia de escena: " + target)
	await frames()
	qa.check(game.house.space_id == target and game.phase == "playing" and not game.hub.visible and not paused, "acceso directo sin menú: " + target)
	qa.check(game.den_view.scene_file_path == "res://scenes/home/%s.tscn" % target, "PackedScene independiente: " + target)
	for p in game.thieves:
		qa.check(Museum.tile_at(p.x, p.y) == Tiles.FLOOR, "llegada sobre suelo libre: " + p.id)
	qa.check(not game.house.home_tick(), "la llegada no vuelve a cruzar la puerta")

func run() -> void:
	Story.save = "user://test_home_spaces.cfg"
	Settings.path = "user://test_home_spaces_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Story.unlock(Story.count(), 1)
	var records := Story.unlocked(1)
	var original_dojo_plan := Den.DOJO_PLAN.duplicate()
	var original_dojo_map := Practice.map(1)
	var salon: HomeSpace = load("res://scenes/home/salon.tscn").instantiate()
	var dojo: HomeSpace = load("res://scenes/home/dojo.tscn").instantiate()
	var museum: HomeSpace = load("res://scenes/home/museo_casa.tscn").instantiate()
	qa.check(salon.rooms.keys() == ["salon"] and museum.rooms.keys() == ["trofeos"] and not dojo.rooms.has("salon") and not dojo.rooms.has("trofeos"), "cada espacio tiene su propia geometría")
	salon.rooms.salon[2] += 5
	qa.check(museum.rooms.trofeos[2] == 19 and dojo.rooms.dojo[2] == 41, "editar el salón no cambia el dojo ni el museo")
	qa.check(dojo.dojo_plan == original_dojo_plan, "el dojo conserva exactamente su distribución original")
	dojo.configure()
	var split_dojo := Practice.map(1)
	var same := true
	for id in dojo.rooms:
		var r := Den.rect(id)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if split_dojo.at(Vector2i(x, y)) != original_dojo_map.at(Vector2i(x, y)):
					same = false
	qa.check(same, "separar la escena no cambia ninguna casilla ni objeto del dojo, aseo y alas")
	salon.free(); dojo.free(); museum.free()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.hub._pick("dojo")
	await frames()
	qa.check(game.house.space_id == "salon" and game.phase == "playing" and not game.hub.visible, "Guarida entra directamente al salón")
	qa.check(game.house.mannequins.is_empty() and Props.list.is_empty() and Den.stands().is_empty(), "el salón no carga objetos del dojo ni los trofeos")
	for count in range(1, 5):
		game.players = count
		game.seats.assign(["kb_left", "kb_right", "pad:0", "pad:1"].slice(0, count))
		game._dojo_start(count, true)
		await frames()
		var seats := game.seats.duplicate()
		await cross("dojo")
		qa.check(game.thieves.size() == count and game.seats == seats and Den.ROOMS.has("dojo") and Arcades.list.is_empty(), "el dojo conserva la banda y sus controles")
		if count == 1:
			qa.check(not game.house.mannequins.is_empty(), "el dojo mantiene sus espantapájaros desbloqueados")
			game.house.trial_start("lockpick")
			qa.check(game.house.trial != null, "las pruebas arrancan en el dojo")
			game.house.trial_end()
		await cross("salon")
		await cross("museo_casa")
		qa.check(Den.stands().size() == 25 and game.house.mannequins.is_empty() and Arcades.list.is_empty(), "el museo contiene la colección y no carga el dojo")
		await cross("dojo")
		await cross("museo_casa")
		await cross("salon")
	qa.check(Story.unlocked(1) == records, "los cambios de escena conservan el progreso")
	game.queue_free()
	await frames()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
