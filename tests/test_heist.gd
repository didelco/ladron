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

	if failures.is_empty():
		print("OK: el golpe funciona")
		quit(0)
	else:
		printerr("%d fallos" % failures.size())
		quit(1)
