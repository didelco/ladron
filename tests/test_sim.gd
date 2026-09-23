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
	var clock := 1000.0
	Sim.step_guard(g, none, [SoundEvent.make(6.5, 5.5, "sprint")], clock, 1.0 / 60)
	check(g.alert and g.calm_in > 9.9 and g.calm_in <= 10.0 and g.alarms == 1, "oye un paso: alerta 10 s")
	for f in 60 * 11:
		clock += 1000.0 / 60
		Sim.step_guard(g, none, [] as Array[SoundEvent], clock, 1.0 / 60)
	check(not g.alert and g.memory == null, "11 s sin nada: tranquilo y olvida")
	for k in 1:
		Sim.step_guard(g, none, [SoundEvent.make(g.x + 1, g.y, "sprint")], clock, 1.0 / 60)
		for f in 60 * 11:
			clock += 1000.0 / 60
			Sim.step_guard(g, none, [] as Array[SoundEvent], clock, 1.0 / 60)
	check(g.alert and g.calm_in == INF, "en media, a la segunda: alerta para siempre")

	print("Museo generado: luces y aviso")
	Sim.new_map(12345, "small")
	var gs := Sim.new_guards(2)
	var a := gs[0]
	var b := gs[1]
	a.alert = true
	a.calm_in = INF
	var room: Museum.Room = Museum.rooms[0]
	var sw := room.switch_at
	var from := Vector2i(-1, -1)
	for tile in Museum.open_tiles:
		var d := Museum.dist(tile.x, tile.y, sw.x, sw.y)
		if d > 2 and d < 5 and Museum.has_line_of_sight(tile.x + 0.5, tile.y + 0.5, sw.x + 0.5, sw.y + 0.5):
			from = tile
			break
	a.x = from.x + 0.5
	a.y = from.y + 0.5
	a.dir = atan2(sw.y - from.y, sw.x - from.x)
	b.x = 1.5
	b.y = 15.5
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
	# Sounds to put a guard on alert for good: easy 3, medium 2, hard 1.
	var stays := {}
	for d in ["easy", "medium", "hard"]:
		Sim.difficulty = d
		var ear := guard_at(5.5, 5.5)
		var n := 0
		while ear.calm_in != INF and n < 10:
			ear.alert = false
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
