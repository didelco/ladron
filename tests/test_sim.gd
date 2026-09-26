extends SceneTree
## Behaviour checks for the simulation: the scenarios the web version was
## tested with. godot --headless --script tests/test_sim.gd

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


## An empty walled room to test in.
func open_room() -> void:
	Museum.regenerate(1, "small", "rect")
	var w := Museum.w
	var h := Museum.h
	for y in h:
		for x in w:
			Museum.grid[y * w + x] = Tiles.WALL if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else Tiles.FLOOR


## The simulation's clock for the timed checks, in ms.
var clock := 1000.0


## Let this many seconds go by for a guard with nothing to see or hear.
func wait(g: Guard, seconds: float) -> void:
	var none: Array[Thief] = []
	for f in int(seconds * 60):
		clock += 1000.0 / 60
		Sim.step_guard(g, none, [] as Array[SoundEvent], clock, 1.0 / 60)


func guard_at(x: float, y: float, dir: float = 0.0) -> Guard:
	var g: Guard = Sim.new_guards(1)[0]
	g.x = x
	g.y = y
	g.dir = dir
	g.path.clear()
	return g


func _init() -> void:
	print("Captura")
	for c in [[5.12, 5.5, 0.0, 5.95, 5.5, "misma casilla, bordes opuestos"], [5.2, 5.5, 0.0, 6.15, 5.9, "casilla contigua"], [5.5, 5.5, PI, 6.4, 5.5, "a su espalda"]]:
		open_room()
		var g := guard_at(c[0], c[1], c[2])
		var p := Sim.new_thief()
		p.x = c[3]
		p.y = c[4]
		var thieves: Array[Thief] = [p]
		var noises: Array[SoundEvent] = []
		var frames := 0
		while frames < 180 and not Sim.caught([g], p):
			Sim.step_guard(g, thieves, noises, 1000.0 + frames * 16, 1.0 / 60)
			frames += 1
		check(Sim.caught([g], p), "%s: pillado en %d fotogramas" % [c[5], frames])

	print("Puerta")
	open_room()
	for y in range(1, Museum.h - 1):
		if y != 8:
			Museum.grid[y * Museum.w + 10] = Tiles.WALL
	for y0 in [8.5, 8.9, 8.2]:
		var p := Sim.new_thief()
		p.x = 8.5
		p.y = y0
		var bumps := 0
		for f in 120:
			if Sim.step_thief(p, {"d": true}, 1.0 / 60).bumped != "":
				bumps += 1
		check(p.x > 12 and bumps == 0, "entra por la puerta desde y=%.1f (x=%.2f, golpes %d)" % [y0, p.x, bumps])

	print("A gatas")
	open_room()
	Museum.grid[8 * Museum.w + 10] = Tiles.COVER
	var t := Sim.new_thief()
	t.x = 11.5
	t.y = 8.5
	Sim.step_thief(t, {"c": true}, 1.0 / 60)
	for f in 100:
		Sim.step_thief(t, {}, 1.0 / 60)
	check(t.posture >= 1.0, "a gatas del todo tras 1,6 s")
	var watcher := guard_at(6.5, 8.5, 0.0)
	watcher.alert = true
	check(not Sim.can_see(watcher, t), "a gatas tras la vitrina: no te ve")
	var standing := Sim.new_thief()
	standing.x = 11.5
	standing.y = 8.5
	check(Sim.can_see(watcher, standing), "de pie en el mismo sitio: te ve")
	Sim.step_thief(t, {"c": true}, 1.0 / 60)
	var x0 := t.x
	for f in 60:
		Sim.step_thief(t, {"c": true, "d": true}, 1.0 / 60)
	check(is_equal_approx(t.x, x0), "levantándote no te mueves")

	print("Alerta")
	open_room()
	var g := guard_at(5.5, 5.5)
	var none: Array[Thief] = []
	clock = 1000.0
	Sim.step_guard(g, none, [SoundEvent.make(6.5, 5.5, "sprint")], clock, 1.0 / 60)
	check(g.suspicion == 1 and not g.alert and g.memory != null, "oye un paso: sospecha (!), sin alerta")
	clock += 1500.0
	Sim.step_guard(g, none, [SoundEvent.make(6.5, 5.5, "sprint")], clock, 1.0 / 60)
	check(g.suspicion == 2 and g.alert and g.alarms == 1, "otro paso: en alerta (!!)")
	wait(g, 25.0)
	check(g.suspicion == 2 and g.alert, "25 s después: sigue en alerta (aguanta medio minuto)")
	wait(g, 6.0)
	check(g.suspicion == 1 and not g.alert and g.memory == null, "pasado el medio minuto: baja a sospecha y olvida")
	wait(g, 5.0)
	check(g.suspicion == 0, "unos segundos más sin nada: tranquilo")
	var crash := guard_at(5.5, 5.5)
	Sim.step_guard(crash, none, [SoundEvent.make(6.5, 5.5, "bust", 20.0)], clock, 1.0 / 60)
	check(crash.suspicion == 2 and crash.alert, "un estruendo: en alerta directamente")
	Sim.step_guard(g, none, [SoundEvent.make(g.x + 1, g.y, "sprint")], clock, 1.0 / 60)
	clock += 1500.0
	Sim.step_guard(g, none, [SoundEvent.make(g.x + 1, g.y, "sprint")], clock, 1.0 / 60)
	check(g.alert and g.calm_in == INF, "en media, a la segunda alerta: alerta para siempre")

	print("Museo generado: luces y aviso")
	Sim.new_map(12345, "small")
	var gs := Sim.new_guards(2)
	var a := gs[0]
	var b := gs[1]
	a.alert = true
	a.calm_in = INF
	# Find a guard's-eye view of a dark room's switch that does not also show
	# the whole room: from there it should go and switch the light on. (A room
	# it can see all of, empty, it rightly leaves dark.)
	var room: Museum.Room = null
	var from := Vector2i(-1, -1)
	for seed in [12345, 777, 4242, 99, 31337]:
		Sim.new_map(seed, "medium")
		for r in Museum.rooms:
			var sw := r.switch_at
			for tile in Museum.open_tiles:
				var d := Museum.dist(tile.x, tile.y, sw.x, sw.y)
				if d < 2 or d > 6 or not Museum.has_line_of_sight(tile.x + 0.5, tile.y + 0.5, sw.x + 0.5, sw.y + 0.5):
					continue
				var probe: Guard = Sim.new_guards(1)[0]
				probe.alert = true
				probe.calm_in = INF
				probe.x = tile.x + 0.5
				probe.y = tile.y + 0.5
				probe.dir = atan2(sw.y - tile.y, sw.x - tile.x)
				Sim.step_guard(probe, none, [] as Array[SoundEvent], clock, 1.0 / 60)
				if probe.errand == "lights" and probe.errand_room == r.id:
					room = r
					from = tile
					break
			if room:
				break
		if room:
			break
	check(room != null, "hay un interruptor visible sin ver la sala entera")
	if room:
		a = Sim.new_guards(1)[0]
		a.alert = true
		a.calm_in = INF
		a.x = from.x + 0.5
		a.y = from.y + 0.5
		a.dir = atan2(room.switch_at.y - from.y, room.switch_at.x - from.x)
		var secs := 0.0
		while Museum.lights_left[room.id] == 0 and secs < 20:
			clock += 1000.0 / 60
			Sim.step_guard(a, none, [] as Array[SoundEvent], clock, 1.0 / 60)
			Sim.tick_lights(1.0 / 60)
			secs += 1.0 / 60
		check(Museum.lights_left[room.id] > 0, "ve el interruptor y enciende la luz en %.1f s" % secs)

	# Warning: a sees b, unaware, a few tiles away.
	Sim.new_map(12345, "small")
	gs = Sim.new_guards(2)
	a = gs[0]
	b = gs[1]
	a.alert = true
	a.calm_in = INF
	for tile in Museum.open_tiles:
		var d := Museum.dist(tile.x + 0.5, tile.y + 0.5, a.x, a.y)
		if d > 3 and d < 5 and Museum.has_line_of_sight(a.x, a.y, tile.x + 0.5, tile.y + 0.5):
			b.x = tile.x + 0.5
			b.y = tile.y + 0.5
			break
	a.dir = atan2(b.y - a.y, b.x - a.x)
	b.sweep = 5
	var told := false
	for f in 60 * 15:
		clock += 1000.0 / 60
		Sim.step_guard(a, none, [] as Array[SoundEvent], clock, 1.0 / 60)
		Sim.step_guard(b, none, [] as Array[SoundEvent], clock, 1.0 / 60)
		if not Sim.warn_partners(gs, clock).is_empty():
			told = true
			break
	check(told and b.alert and b.calm_in == INF, "avisa al compañero y queda en alerta para siempre")

	print("Mente (reglas de reserva)")
	var others: Array[Guard] = [b]
	var mind := Mind.of(a, others, clock)
	check(not (mind.options as Array).is_empty(), "menú con %d opciones" % (mind.options as Array).size())
	var fb := Mind.fallback(a, others, clock)
	check(fb.label != "", "decisión de reserva: %s" % fb.label)

	print("Dificultad")
	open_room()
	var seer := guard_at(5.5, 8.5, 0.0)
	seer.alert = true
	var target := Sim.new_thief()
	target.x = 5.5 + 8.5
	target.y = 8.5
	Sim.difficulty = "easy"
	var easy_sees := Sim.can_see(seer, target)
	var easy_lock: float = Heist.loot_for(1).seconds
	Sim.difficulty = "hard"
	var hard_sees := Sim.can_see(seer, target)
	var hard_lock: float = Heist.loot_for(1).seconds
	# Times on alert before it is for good: easy 3, medium 2, hard 1.
	var stays := {}
	for d in ["easy", "medium", "hard"]:
		Sim.difficulty = d
		var ear := guard_at(5.5, 5.5)
		var n := 0
		while ear.calm_in != INF and n < 10:
			# Each time from a hunch, so every sound puts it on alert.
			ear.alert = false
			ear.suspicion = 1
			Sim.step_guard(ear, none, [SoundEvent.make(6.5, 5.5, "sprint")], clock + n * 20000.0, 1.0 / 60)
			n += 1
		stays[d] = n
	Sim.difficulty = "medium"
	check(stays.easy == 3 and stays.medium == 2 and stays.hard == 1, "ruidos hasta la alerta permanente: fácil %d, media %d, difícil %d" % [stays.easy, stays.medium, stays.hard])
	check(not easy_sees and hard_sees, "a 8,5 casillas: en fácil no te ve, en difícil sí")
	check(easy_lock < Heist.loot_for(1).seconds and hard_lock > Heist.loot_for(1).seconds, "forzar: %s s fácil, %s s media, %s s difícil" % [easy_lock, Heist.loot_for(1).seconds, hard_lock])

	if failures.is_empty():
		print("OK: simulación como en la web")
		quit(0)
	else:
		printerr("%d fallos" % failures.size())
		quit(1)
