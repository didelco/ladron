extends SceneTree
## The smoke bomb: a cloud hides whoever is in it and cuts sight through it,
## a guard that loses you in it no longer knows which way you went, and one
## that sees a cloud comes to look. godot --headless --script tests/test_smoke.gd

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


## An empty walled room.
func open_room() -> void:
	Museum.regenerate(1, "small", "rect")
	for y in Museum.h:
		for x in Museum.w:
			Museum.grid[y * Museum.w + x] = Tiles.WALL if (x == 0 or y == 0 or x == Museum.w - 1 or y == Museum.h - 1) else Tiles.FLOOR
	Museum.lights_left.fill(0.0)


func guard_at(x: float, y: float, dir: float) -> Guard:
	var g: Guard = Sim.new_guards(1)[0]
	g.x = x
	g.y = y
	g.dir = dir
	g.path.clear()
	return g


## A cloud that went off `ago` seconds back, at (x, y).
func cloud_at(x: float, y: float, ago: float) -> Smoke.Cloud:
	var t := Sim.new_thief()
	t.x = x
	t.y = y
	var thieves: Array[Thief] = [t]
	Smoke.reset(thieves)
	var c := Smoke.drop(t, Sim.now_ms() - ago * 1000.0, [] as Array[SoundEvent])
	return c


func _init() -> void:
	Text.setup()
	print("Esconderse")
	open_room()
	var g := guard_at(4.5, 8.5, 0.0)
	var p := Sim.new_thief()
	p.x = 7.5
	p.y = 8.5
	Smoke.list.clear()
	check(Sim.can_see(g, p), "sin humo, el guardia ve al ladrón delante")
	cloud_at(7.5, 8.5, 1.0)
	check(not Sim.can_see(g, p), "dentro de la nube no se le ve")
	p.x = 11.5
	check(not Sim.can_see(g, p), "detrás de la nube, tampoco")
	p.x = 7.5
	p.y = 5.5
	check(Sim.can_see(guard_at(4.5, 5.5, 0.0), p), "fuera de la nube, se le ve")

	print("Dura lo que dura")
	open_room()
	g = guard_at(4.5, 8.5, 0.0)
	p = Sim.new_thief()
	p.x = 7.5
	p.y = 8.5
	cloud_at(7.5, 8.5, Smoke.SECONDS + 0.5)
	check(Sim.can_see(g, p), "pasado su tiempo, ya no tapa")
	var c := cloud_at(7.5, 8.5, 0.05)
	var now := Sim.now_ms()
	check(Smoke.reach(c, now) < Smoke.RADIUS * 0.6, "al estallar aún no llega a todo su tamaño")
	check(absf(Smoke.reach(c, now + Smoke.GROW_S * 1000.0) - Smoke.RADIUS) < 0.01, "en un momento, a todo su tamaño")

	print("Sin gastar lo que no hay")
	var t := Sim.new_thief()
	var ts: Array[Thief] = [t]
	Smoke.reset(ts)
	var noises: Array[SoundEvent] = []
	for k in Smoke.PER_THIEF:
		check(Smoke.drop(t, Sim.now_ms(), noises) != null, "bomba %d" % (k + 1))
	check(Smoke.drop(t, Sim.now_ms(), noises) == null, "sin más bombas, no sale ninguna")
	check(noises.size() == Smoke.PER_THIEF and noises[0].kind == "smoke", "cada una hace su ruido")

	print("Te pierde en el humo")
	open_room()
	g = guard_at(4.5, 8.5, 0.0)
	var m := Guard.Memory.new()
	m.x = 8.5
	m.y = 8.5
	m.kind = "seen"
	m.at = Sim.now_ms()
	m.has_heading = true
	m.vx = 1.0
	g.memory = m
	cloud_at(8.5, 8.5, 1.0)
	Sim.step_guard(g, [] as Array[Thief], [] as Array[SoundEvent], Sim.now_ms(), 1.0 / 60)
	check(not g.memory.has_heading, "no sabe hacia dónde fuiste")

	print("El humo llama la atención")
	open_room()
	g = guard_at(3.5, 8.5, 0.0)
	cloud_at(10.5, 8.5, 1.0)
	check(g.suspicion == 0, "antes, tranquilo")
	Sim.step_guard(g, [] as Array[Thief], [] as Array[SoundEvent], Sim.now_ms(), 1.0 / 60)
	check(g.suspicion >= 1, "ve la nube y sospecha")
	check(g.memory != null and Museum.dist(g.memory.x, g.memory.y, 10.5, 8.5) < 0.1, "va a mirar la nube")
	var before := g.suspicion
	Sim.step_guard(g, [] as Array[Thief], [] as Array[SoundEvent], Sim.now_ms(), 1.0 / 60)
	check(g.suspicion == before, "la misma nube no le alarma dos veces")
	var back := guard_at(3.5, 8.5, PI)
	Sim.step_guard(back, [] as Array[Thief], [] as Array[SoundEvent], Sim.now_ms(), 1.0 / 60)
	check(back.suspicion == 0, "de espaldas, no la ve")

	if failures.is_empty():
		print("OK: la bomba de humo")
	else:
		print("FALLAN %d" % failures.size())
	quit(1 if not failures.is_empty() else 0)
