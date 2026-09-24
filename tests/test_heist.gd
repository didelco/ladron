extends SceneTree
## The job: a piece in a gallery far from the entrance, a door in the outer
## wall, stealing it standing still (with its alarm), and getting out.
##   godot --headless --script tests/test_heist.gd

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


func _init() -> void:
	var doors_off_bbox := 0
	for size in ["small", "medium", "large"]:
		for k in 6:
			Sim.new_map(1000 + k * 7919, size)
			Heist.plan_job(1)
			var wall := Heist.exit + Heist.exit_face
			var ok_door := Museum.tile_at(wall.x + 0.5, wall.y + 0.5) == Tiles.WALL and Museum.is_outside(wall.x + Heist.exit_face.x, wall.y + Heist.exit_face.y)
			var ok_route := Heist.route.size() > 5 and Heist.route[0] == Heist.start and Heist.route[-1] == Heist.exit
			if not (ok_door and ok_route):
				check(false, "%s/%d (%s): puerta %s ruta %d" % [size, k, Museum.shape, ok_door, Heist.route.size()])
			var bbox_edge := wall.x == 0 or wall.y == 0 or wall.x == Museum.w - 1 or wall.y == Museum.h - 1
			if not bbox_edge:
				doors_off_bbox += 1
	check(true, "18 golpes planificados; %d puertas en muros exteriores que no son el borde del rectángulo" % doors_off_bbox)

	Sim.new_map(4242, "small")
	Heist.plan_job(1)
	check(Museum.room_at(Heist.at.x + 0.5, Heist.at.y + 0.5) != null, "la pieza está en una sala")
	# Stand at the case, facing it, still.
	var p := Sim.new_thief()
	var stand := Heist.route[0]
	for t in Heist.route:
		if Museum.dist(t.x + 0.5, t.y + 0.5, Heist.at.x + 0.5, Heist.at.y + 0.5) < 1.1:
			stand = t
			break
	p.x = stand.x + 0.5
	p.y = stand.y + 0.5
	p.dir = atan2(Heist.at.y - stand.y, Heist.at.x - stand.x)
	var thieves: Array[Thief] = [p]
	var now := 1000.0
	var alarms := 0
	var event := ""
	var secs := 0.0
	while event != "stolen" and secs < 10:
		var noises: Array[SoundEvent] = []
		event = Heist.step(thieves, 1.0 / 60, now, noises)
		alarms += noises.size()
		now += 1000.0 / 60
		secs += 1.0 / 60
	check(event == "stolen", "robada quieto delante en %.1f s (hacían falta %s)" % [secs, Heist.loot.seconds])
	check(alarms >= 3, "la alarma sonó %d veces mientras la forzaba" % alarms)
	p.x = Heist.exit.x + 0.5
	p.y = Heist.exit.y + 0.5
	var noises2: Array[SoundEvent] = []
	check(Heist.step(thieves, 1.0 / 60, now, noises2) == "out", "con la pieza en la puerta: fuera")

	# Two thieves: the case waits for the panel, then opens in silence.
	Sim.new_map(4242, "small")
	Heist.plan_job(1, {}, true)
	check(Heist.team and Heist.panel.x >= 0, "con dos, hay cuadro de alarma en (%d, %d)" % [Heist.panel.x, Heist.panel.y])
	var wall := Heist.panel + Heist.panel_face
	check(Museum.tile_at(wall.x + 0.5, wall.y + 0.5) == Tiles.WALL, "el cuadro está en una pared")
	check(Museum.room_at(Heist.panel.x + 0.5, Heist.panel.y + 0.5) != Museum.room_at(Heist.at.x + 0.5, Heist.at.y + 0.5) or Museum.room_at(Heist.at.x + 0.5, Heist.at.y + 0.5) == null, "el cuadro no está en la sala de la pieza")
	var a := Sim.new_thief("p1")
	var b := Sim.new_thief("p2")
	for t in Heist._stand_tiles(Heist.at):
		a.x = t.x + 0.5
		a.y = t.y + 0.5
		a.dir = atan2(Heist.at.y - t.y, Heist.at.x - t.x)
		break
	b.x = Heist.start.x + 0.5
	b.y = Heist.start.y + 0.5
	var pair: Array[Thief] = [a, b]
	var sounds: Array[SoundEvent] = []
	for i in 120:
		Heist.step(pair, 1.0 / 60, now, sounds)
		now += 1000.0 / 60
	check(Heist.progress == 0.0 and Heist.waiting and sounds.is_empty(), "sin nadie en el cuadro la vitrina no cede (%.2f)" % Heist.progress)
	b.x = Heist.panel.x + 0.5
	b.y = Heist.panel.y + 0.5
	event = ""
	secs = 0.0
	while event != "stolen" and secs < 10:
		event = Heist.step(pair, 1.0 / 60, now, sounds)
		now += 1000.0 / 60
		secs += 1.0 / 60
	check(event == "stolen" and sounds.is_empty(), "con el compañero en el cuadro: robada en %.1f s sin alarma" % secs)
	# The partner caught: the one left forces it alone, loudly.
	Heist.plan_job(1, {}, true)
	for t in Heist._stand_tiles(Heist.at):
		a.x = t.x + 0.5
		a.y = t.y + 0.5
		a.dir = atan2(Heist.at.y - t.y, Heist.at.x - t.x)
		break
	b.out = true
	sounds.clear()
	event = ""
	secs = 0.0
	while event != "stolen" and secs < 10:
		event = Heist.step(pair, 1.0 / 60, now, sounds)
		now += 1000.0 / 60
		secs += 1.0 / 60
	check(event == "stolen" and not sounds.is_empty(), "con el compañero pillado, se fuerza solo y suena la alarma")

	# The story: ten nights, each a playable museum, harder as they go.
	var last_guards := 0
	var last_view := 0.0
	var harder := true
	for n in range(1, Story.count() + 1):
		var night := Story.level(n)
		Sim.custom = Story.tuning(n)
		Sim.new_map(Story.seed_for(n), night.size, -1, night.shape)
		Heist.plan_job(n, night.loot, n % 2 == 0)
		var guards := Sim.new_guards(Sim.guard_count(Museum.size_name))
		if guards.size() < last_guards or Sim.tuning("view") < last_view or Heist.route.size() < 5:
			harder = false
		last_guards = guards.size()
		last_view = Sim.tuning("view")
		print("  noche %2d: %-6s %-7s %d guardias · %s · %.1f s" % [n, night.size, Museum.shape, guards.size(), Heist.loot.name, Heist.loot.seconds])
	check(harder, "diez noches jugables, cada una igual o más difícil")
	Sim.custom = {}

	if failures.is_empty():
		print("OK: el golpe funciona")
		quit(0)
	else:
		printerr("%d fallos" % failures.size())
		quit(1)
