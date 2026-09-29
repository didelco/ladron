extends SceneTree
## Los juegos del dojo de El Escondite del Calcetín (los de DojoGame, en DojoTrials): PILLA EL
## CALCETÍN, BOLOS, EQUILIBRIO y AGUANTA ESCONDIDO. Lógica pura sobre un campo
## sintético (con puerta, laberinto y espantapájaros) y sobre el dojo de verdad
## (Practice.map): niveles, dificultad, pérdida, victoria con un bot, semillas,
## las tres dificultades (tramos de niveles), el guardado de la mejor marca por
## dificultad y banda, los puntos de inicio del dojo y la vista de fin.
## (El contrato común de las pruebas, el banco, el circuito y el panel: test_pruebas.gd.)
var fails := 0
const DT := 1.0 / 60.0
var field: DojoField
var bare: DojoField
var start := Vector2i(3, 8)


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1


func bl(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(list)
	return out


func body(id: int, pos: Vector2, extra := {}) -> Dictionary:
	var b := {"id": id, "pos": pos, "rolling": false, "hidden": false, "speed": 0.0, "out": false}
	b.merge(extra, true)
	return b


## The made-up dojo: 46 x 18, a wall at x = 14 with a door (the gate "puerta"),
## a wall at x = 29 with a gap, a maze of switchbacks from x = 30, three
## scarecrows (on cover tiles), and zones by x.
func synthetic(scarecrows: bool) -> DojoField:
	var m := MapFile.blank(46, 18)
	for y in range(1, 17):
		if y != 8 and y != 9:
			m.grid[y * 46 + 14] = Tiles.WALL
		if y != 2 and y != 3:
			m.grid[y * 46 + 29] = Tiles.WALL
	for x in range(30, 44):
		m.grid[5 * 46 + x] = Tiles.WALL
		m.grid[14 * 46 + x] = Tiles.WALL
	for x in range(32, 45):
		m.grid[10 * 46 + x] = Tiles.WALL
	var zones := func(t: Vector2i) -> String:
		return "tatami" if t.x < 15 else ("circuit" if t.x < 24 else ("aguanta" if t.x < 30 else "circuit"))
	var f := DojoField.from_map(m, Rect2i(1, 1, 44, 16), zones, [{"id": "puerta", "rect": [14, 8, 1, 2]}])
	if scarecrows:
		for t in [Vector2i(17, 2), Vector2i(24, 15), Vector2i(33, 7)]:
			m.grid[t.y * 46 + t.x] = Tiles.COVER
		f = DojoField.from_map(m, Rect2i(1, 1, 44, 16), zones, [{"id": "puerta", "rect": [14, 8, 1, 2]}])
		f.set_scarecrows([{"id": "pasillo", "tile": Vector2i(17, 2), "facing": PI / 2},
			{"id": "sur", "tile": Vector2i(24, 15), "facing": -PI / 2},
			{"id": "laberinto", "tile": Vector2i(33, 7), "facing": 0.0}])
	return f


func game(id: String, seed_ := 7, players := 1, f: DojoField = null, tier := 0) -> DojoGame:
	var g := DojoTrials.make(id, players, seed_, f if f != null else field, start, tier) as DojoGame
	g.starter = 0
	return g


func run(g: DojoGame, secs: float, fn := Callable()) -> Array:
	var evs := []
	for i in int(round(secs / DT)):
		var bodies: Array[Dictionary] = bl([])
		if fn.is_valid():
			bodies = bl(fn.call(g))
		evs.append_array(g.step(DT, bodies))
	return evs


## Until the game is won or lost (or `secs` pass).
func run_end(g: DojoGame, fn: Callable, secs: float) -> Array:
	var evs := []
	for i in int(round(secs / DT)):
		evs.append_array(g.step(DT, bl(fn.call(g)) if fn.is_valid() else bl([])))
		if g.finished():
			break
	return evs


func of(evs: Array, e: String) -> Array:
	return evs.filter(func(x): return x.e == e)


func begin(g: DojoGame, lv := 1) -> Array:
	g.start()
	g.level = lv
	return run(g, DojoTrial.READY_S + 0.1)


func _init() -> void:
	Story.save = "user://test_dojo.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	field = synthetic(true)
	bare = synthetic(false)
	_field_tests()
	_params_tests()
	_base_tests()
	_catch_tests()
	_bowling_tests()
	_pedestal_tests()
	_hide_tests()
	_save_tests()
	_den_tests()
	await _view_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("\n%d fallos" % fails)
	quit(1 if fails > 0 else 0)


# --- The field ---------------------------------------------------------------------------------

func _field_tests() -> void:
	var d := field.dist(start)
	check(d[8 * 46 + 3] == 0 and d[8 * 46 + 4] == 1, "dist: 0 donde se está y 1 al lado")
	check(d[8 * 46 + 16] >= 13, "dist: se llega al otro lado de la puerta abierta")
	var shut := field.dist(start, ["puerta"])
	check(shut[8 * 46 + 16] < 0 and shut[8 * 46 + 5] > 0, "dist con la puerta cerrada: no se pasa, y este lado sí")
	check(field.dist(start, ["*"])[8 * 46 + 16] < 0, "dist con todas las puertas cerradas")
	var all := field.candidates(start, [], 2, 99)
	check(all.size() > 50, "hay puntos donde poner cosas: %d" % all.size())
	var ok := true
	for c in all:
		var t: Vector2i = c.tile
		if not field.is_clear(t) or Vector2(t).distance_to(Vector2(start)) < DojoField.MIN_AWAY:
			ok = false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not field.has_floor(t + Vector2i(dx, dy)):
					ok = false
	check(ok, "un punto válido: suelo con ocho vecinos libres y a 2 casillas del anterior")
	var z := field.candidates(start, ["circuit"], 2, 99)
	check(not z.is_empty() and z.all(func(c): return c.zone == "circuit"), "candidatos: solo de la zona pedida")
	check(field.candidates(start, ["tatami"], 2, 99).all(func(c): return c.zone == "tatami"), "tatami es tatami")
	check(field.candidates(start, ["juegos"], 2, 99).all(func(c): return c.zone == "tatami") and field.candidates(start, ["circuito"], 2, 99).all(func(c): return c.zone == "circuit")
		and field.candidates(start, ["escondites"], 2, 99).all(func(c): return c.zone == "aguanta"), "los grupos de zonas (juegos, circuito, escondites) valen por las zonas de la lista")
	var win := field.candidates(start, [], 8, 12)
	check(not win.is_empty() and win.all(func(c): return c.path >= 8 and c.path <= 12), "candidatos: dentro de la distancia")
	var gate := field.candidates(start, [], 2, 99, {"gate": true})
	check(not gate.is_empty() and gate.all(func(c): return c.gate == "puerta" and field.dist(start, ["puerta"])[c.tile.y * 46 + c.tile.x] < 0),
		"opts.gate: solo lo que una puerta cerrada aísla")
	var maze := field.candidates(Vector2i(31, 3), [], 2, 99, {"maze": true})
	check(not maze.is_empty() and maze.all(func(c): return c.path >= DojoField.MAZE_RATIO * Vector2(c.tile).distance_to(Vector2(31, 3)) - 0.001),
		"opts.maze: el camino al menos 1,6 veces la recta (%d puntos)" % maze.size())
	var av := field.candidates(start, [], 2, 99, {"avoid": [Vector2i(8, 8)]})
	check(av.all(func(c): return maxi(absi(c.tile.x - 8), absi(c.tile.y - 8)) >= DojoField.AVOID), "opts.avoid: lejos de lo evitado")
	# The scarecrows.
	check(field.watchers(Vector2i(17, 5)) == ["pasillo"], "el cono del espantapájaros del pasillo ve (17, 5): %s" % [field.watchers(Vector2i(17, 5))])
	check(field.watchers(Vector2i(17, 12)).is_empty() and field.watchers(Vector2i(3, 3)).is_empty(), "y no ve lejos ni a un lado")
	check(field.watched_by(Vector2i(17, 5)) == "pasillo" and field.watched_by(Vector2i(3, 3)) == "", "watched_by")
	check(not field.sees(field.scarecrow("pasillo"), Vector2(17.5, 5.5), true), "un ladrón escondido no se ve")
	var cross := field.crossed(field.path(Vector2i(16, 9), Vector2i(17, 4)))
	check(cross.has("pasillo"), "un camino que sube por el cono lo cruza")
	var w := field.candidates(start, [], 2, 99, {"watched": true})
	check(not w.is_empty() and w.all(func(c): return not c.cross.is_empty()), "opts.watched: todos en un cono o cruzándolo (%d)" % w.size())
	var w2 := field.candidates(start, [], 2, 99, {"watched": true, "watched_min": 2})
	check(w2.all(func(c): return c.cross.size() >= 2), "watched_min 2: al menos dos espantapájaros (%d)" % w2.size())
	check(bare.candidates(start, [], 2, 99, {"watched": true}).is_empty(), "sin espantapájaros no hay puntos vigilados")
	var inside := w.filter(func(c): return not c.watchers.is_empty())
	check(inside.all(func(c): return c.forced), "un punto dentro del cono cuenta como forzado")
	var rounds := w.filter(func(c): return not c.forced)
	check(rounds.all(func(c): return field.dist(start, [], c.cross)[c.tile.y * 46 + c.tile.x] == c.time_path and c.time_path >= c.path),
		"un punto rodeable: time_path es el camino más corto que evita los conos")
	var rng := Mulberry32.new(3)
	var pk := bare.pick(start, ["laberinto"], 200, 300, {"gate": true, "maze": true}, rng)
	check(not pk.is_empty() and pk.relaxed > 0, "pick afloja la petición si no hay nada (relaxed %s)" % pk.get("relaxed"))
	check(DojoField.new().pick(start, [], 1, 2, {}, rng).is_empty(), "un campo sin suelo: pick vacío sin colgarse")
	check(field.nearest_floor(Vector2i(0, 0)) == Vector2i(1, 1), "nearest_floor")


func _params_tests() -> void:
	var need := {
		"atrapa": ["dmin", "dmax", "zones", "base", "slack", "move", "gate", "watch", "watch_n", "maze", "ring", "min_time"],
		"bolos": ["n", "cluster", "movers", "move", "dmin", "dmax", "zones", "base", "slack", "gate", "maze", "min_time"],
		"pedestal": ["hold"],
		"aguanta": ["hold", "sweep", "amp", "spots", "rise", "burst", "enter"],
	}
	var cls := {"atrapa": CatchGame, "bolos": BowlingGame, "pedestal": PedestalGame, "aguanta": HideGame}
	for id in need:
		var full := true
		for lv in range(1, 11):
			var p: Dictionary = cls[id].params(lv)
			for k in need[id]:
				if not p.has(k):
					full = false
		check(full and cls[id].LEVELS.size() == 10, "%s: diez niveles definidos, con todos sus parámetros" % id)
	# Monotone difficulty.
	var prev := 1e9
	var mono := true
	for lv in range(1, 11):
		var t := CatchGame.time_for(lv, 10)
		if t > prev + 0.0001:
			mono = false
		prev = t
	check(mono, "atrapa: el tiempo para el mismo camino no sube de nivel en nivel (1 a 10)")
	check(CatchGame.params(10).min_time == 4.5 and CatchGame.params(9).min_time == 0.0, "atrapa: tiempo mínimo 4,5 en el 10")
	check(is_equal_approx(CatchGame.time_for(1, 6), 3.0 + 2.2 * 6 * 0.24), "atrapa: tiempo = base + margen * camino * 0,24")
	check(is_equal_approx(CatchGame.time_for(6, 10, true), 2.0 + 1.45 * 10 * 0.24 + 1.5), "atrapa: +1,5 s con puerta")
	check(CatchGame.params(5).move == 0.8 and CatchGame.params(9).move == 1.4 and CatchGame.params(10).move == 1.8, "atrapa: los que se mueven a 0,8, 1,4 y 1,8")
	check(not CatchGame.params(9).ring and CatchGame.params(8).ring, "atrapa: sin anillo desde el nivel 9")
	check(CatchGame.params(7).watch and CatchGame.params(9).watch_n == 2 and CatchGame.params(10).watch_n == 2, "atrapa: vigilado del 7 al 10, cruzando dos en el 9 y el 10")
	mono = true
	prev = 1e9
	var prev_n := 0
	for lv in range(1, 11):
		var t := BowlingGame.time_for(lv, 10)
		if t > prev + 0.0001 or BowlingGame.params(lv).n < prev_n:
			mono = false
		prev = t
		prev_n = BowlingGame.params(lv).n
	check(mono, "bolos: el tiempo no sube y los bolos por ronda no bajan (1 a 10)")
	mono = true
	var last := {}
	for lv in range(1, 11):
		var p := PedestalGame.params(lv)
		if not last.is_empty() and p.hold <= last.hold:
			mono = false
		last = p
	check(mono, "equilibrio: cada ronda más tiempo (1 a 10)")
	check(PedestalGame.params(1).hold == 4.0 and PedestalGame.params(4).hold == 8.0 and PedestalGame.params(7).hold == 15.0, "equilibrio: 4 s, 5, 6, 8, 10, 12, 15...")
	mono = true
	last = {}
	for lv in range(1, 11):
		var p := HideGame.params(lv)
		if not last.is_empty() and (p.hold <= last.hold or p.sweep < last.sweep or p.spots > last.spots or p.rise < last.rise or p.enter > last.enter):
			mono = false
		last = p
	check(mono, "aguanta: más tiempo, linterna más rápida, estornudos más seguidos y menos escondites (1 a 10)")
	check(HideGame.params(1).hold == 5.0 and HideGame.params(4).hold == 12.0, "aguanta: 5 s, 7, 9, 12, 15...")
	check(HideGame.params(4).rise == 0.0 and HideGame.params(5).rise > 0.0, "aguanta: el estornudo llega en el nivel 5")


# --- The state machine ---------------------------------------------------------------------------

func _base_tests() -> void:
	var g := game("atrapa")
	check(g.state == "idle" and not g.active(), "un juego nuevo está parado")
	check(not g.alarm(), "la alarma no vale fuera de juego")
	g.start()
	check(g.state == "ready" and g.level == 1 and g.got == 0 and g.goal == 3, "start: ¿LISTOS?")
	run(g, 1.9)
	check(g.state == "ready", "... dos segundos")
	var evs := run(g, 0.25)
	check(g.state == "playing" and not of(evs, "spawn").is_empty(), "... y sale el primero")
	g.abort()
	check(g.state == "idle", "abort: se sale de donde se esté")
	check(of(g.step(DT, bl([])), "abort").size() == 1, "... y lo dice")
	g.start()
	run(g, 2.2)
	run(g, 60.0)
	check(g.state == "lost" and g.lost_why == "time", "sin nadie, se pierde por tiempo")
	check(not g.alarm() and g.step(DT, bl([])).is_empty(), "perdido, nada más pasa")
	var v := g.view()
	check(v.state == "lost" and v.reached == g.level and v.goal == 3 and v.tier == 0 and v.has("objects") and v.has("timer"), "view() trae lo que la vista necesita")
	check(v.title == "PILLA EL CALCETÍN  FÁCIL" and v.hud.size() == 2 and v.hud[0].begins_with("NIVEL 1") and v.hud[1] == "MEJOR --", "... y el título y las líneas comunes de todas las pruebas: %s %s" % [v.title, v.hud])
	check(v.result.won == false and v.result.title == Text.t("HIDEOUT_GAME_LOST_ATRAPA") and v.result.has_next == false and v.kind == "level", "... y el resultado para el panel")
	check(DojoTrials.make("nada", 1, 1, field, start) == null, "make: un juego que no existe, nulo")
	var same := true
	for e in DojoTrials.of_kind("game"):
		var gg := DojoTrials.make(e.id, 2, 3, field, start)
		same = same and gg.id == e.id and gg is DojoGame and gg.players == 2
	check(same, "make devuelve cada juego con su id")
	check(DojoTrials.unlocked("atrapa", 1) == (Story.unlocked(1) >= Story.lesson_night("games")), "unlocked sigue a la lección (games)")
	var lessons := DojoTrials.of_kind("game").map(func(e): return e.lesson)
	check(lessons == ["games", "games", "props", "torch"] and lessons.all(func(l): return Story.LESSONS.has(l)), "lecciones: atrapa games, pedestal games, bolos props, aguanta torch")


# --- PILLA EL CALCETÍN ---------------------------------------------------------------------------

func _catch_bot(g: DojoGame) -> Array:
	var c := g as CatchGame
	if c.obj.is_empty():
		return [body(0, Vector2(2.5, 2.5))]
	return [body(0, c.obj.pos)]


func _catch_tests() -> void:
	for tier in 3:
		var first: int = DojoTrials.TIERS[tier].from
		var last: int = DojoTrials.TIERS[tier].to
		var n := last - first + 1
		var g := game("atrapa", 11, 1, null, tier)
		g.start()
		check(g.level == first and g.goal == n, "atrapa %s: empieza en el nivel %d y hay que hacer %d" % [DojoTrials.TIERS[tier].id, first, n])
		var evs := run_end(g, _catch_bot, 400.0)
		var spawns := of(evs, "spawn")
		check(g.state == "won" and g.got == n and g.level == last, "atrapa %s: un bot que se pone encima gana el tramo (level %d got %d)" % [DojoTrials.TIERS[tier].id, g.level, g.got])
		check(spawns.size() == n and of(evs, "catch").size() == n and of(evs, "level").size() == n - 1, "atrapa %s: %d apariciones, %d cogidos, %d subidas de nivel" % [DojoTrials.TIERS[tier].id, n, n, n - 1])
		check(of(evs, "won").size() == 1 and g.credits[0] == n, "atrapa %s: ganó, con todos a su nombre" % DojoTrials.TIERS[tier].id)
		var times_ok := true
		for i in spawns.size():
			if spawns[i].level != first + i or spawns[i].time <= 0.0:
				times_ok = false
		check(times_ok, "atrapa %s: cada aparición trae su nivel y su tiempo" % DojoTrials.TIERS[tier].id)
		check(g.state == "won" and g.step(DT, bl([])).is_empty(), "atrapa %s: ganado, no sigue" % DojoTrials.TIERS[tier].id)
	# Determinism.
	var a := game("atrapa", 5, 1, null, 2)
	var b := game("atrapa", 5, 1, null, 2)
	var c := game("atrapa", 6, 1, null, 2)
	for x in [a, b, c]:
		x.start()
	var ta := of(run_end(a, _catch_bot, 400.0), "spawn").map(func(e): return e.tile)
	var tb := of(run_end(b, _catch_bot, 400.0), "spawn").map(func(e): return e.tile)
	var tc := of(run_end(c, _catch_bot, 400.0), "spawn").map(func(e): return e.tile)
	check(ta == tb and ta.size() == 4, "atrapa: la misma semilla, los mismos sitios")
	check(ta != tc, "atrapa: otra semilla, otros sitios")
	# The rule of the catch.
	var h := game("atrapa", 2)
	begin(h)
	var at: Vector2 = h.obj.pos
	run(h, 0.5, func(_g): return [body(0, at + Vector2(0.9, 0))])
	check(h.got == 0, "atrapa: a 0,9 casillas no se coge")
	run(h, 0.1, func(_g): return [body(0, at, {"hidden": true})])
	check(h.got == 0, "atrapa: escondido no vale")
	run(h, 0.1, func(_g): return [body(0, at, {"out": true})])
	check(h.got == 0, "atrapa: fuera de juego no vale")
	run(h, 0.05, func(_g): return [body(0, at + Vector2(0.7, 0))])
	check(h.got == 1, "atrapa: a 0,7 sí")
	var h2 := game("atrapa", 2, 3)
	begin(h2)
	var at2: Vector2 = h2.obj.pos
	run(h2, 0.05, func(_g): return [body(0, Vector2(3, 3)), body(2, at2)])
	check(h2.mvp() == 2 and h2.credits[2] == 1, "atrapa: gana los puntos quien lo coge (MVP)")
	# Losing by time: the ticks.
	var l := game("atrapa", 3)
	var tick_evs := run_end(begin_and_return(l), func(_g): return [body(0, Vector2(3, 3))], 120.0)
	var ticks := of(tick_evs, "tick")
	check(l.state == "lost" and of(tick_evs, "lost")[0].why == "time", "atrapa: se pierde al llegar el tiempo a 0")
	check(ticks.size() >= 6 and ticks.all(func(t): return t.left <= 5.0), "atrapa: tics solo con 5 s o menos (%d)" % ticks.size())
	check(ticks.filter(func(t): return t.left <= 2.0).size() >= 3 and ticks.filter(func(t): return t.left > 2.0).size() >= 3, "atrapa: cada segundo con 5 s, cada medio con 2 s")
	# Levels 1 to 10: the points.
	var reach_ok := true
	var zone_ok := true
	var win_ok := true
	var bad := ""
	for lv in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		for s in range(1, 9):
			var q := game("atrapa", s)
			begin(q, lv)
			var sp: Dictionary = q.last_spawn
			var p := CatchGame.params(lv)
			if sp.is_empty() or not field.is_clear(sp.tile) or field.dist(start)[sp.tile.y * 46 + sp.tile.x] < 0:
				reach_ok = false
				bad = "nivel %d semilla %d" % [lv, s]
			if sp.get("relaxed", 0) == 0:
				var zl: Array = p.zones
				if not zl.is_empty() and not field._zone_ok(sp.zone, zl):
					zone_ok = false
				if sp.path < p.dmin or sp.path > p.dmax:
					win_ok = false
	check(reach_ok, "atrapa: los puntos de los niveles 1 a 10 son claros y alcanzables %s" % bad)
	check(zone_ok, "atrapa: y, si nada se ha aflojado, de su zona")
	check(win_ok, "atrapa: y a su distancia")
	# Door.
	var d := game("atrapa", 4)
	var e6 := begin(d, 6)
	check(of(e6, "spawn")[0].gate == "puerta" and d.shut == ["puerta"], "atrapa: el nivel 6 sale tras la puerta y pide cerrarla")
	check(is_equal_approx(d.obj.max, CatchGame.time_for(6, d.last_spawn.path, true)), "atrapa: ... con el tiempo de la puerta")
	# Wandering.
	var mv := game("atrapa", 4)
	begin(mv, 5)
	var p0: Vector2 = mv.obj.pos
	var far := 0.0
	var on_floor := true
	for i in 300:
		mv.step(DT, bl([body(0, Vector2(3, 3))]))
		mv.obj.left = mv.obj.max
		far = maxf(far, p0.distance_to(mv.obj.pos))
		if not field.has_floor(DojoField.tile_of(mv.obj.pos)):
			on_floor = false
	check(far > 2.0 and on_floor, "atrapa: en el nivel 5 el calcetín se mueve, por el suelo (%.1f casillas en 5 s)" % far)
	var dist_run := 0.0
	var prev_pos: Vector2 = mv.obj.pos
	for i in 120:
		mv.step(DT, bl([body(0, Vector2(3, 3))]))
		mv.obj.left = mv.obj.max
		dist_run += prev_pos.distance_to(mv.obj.pos)
		prev_pos = mv.obj.pos
	check(dist_run <= 0.8 * 2.0 + 0.1, "atrapa: ... a 0,8 casillas por segundo (%.2f en 2 s)" % dist_run)
	# Ring.
	var r9 := game("atrapa", 4)
	begin(r9, 9)
	check(r9.view().objects[0].ring == -1.0, "atrapa: sin anillo en el nivel 9")
	var r1 := game("atrapa", 4)
	begin(r1, 1)
	check(r1.view().objects[0].ring > 0.9, "atrapa: con anillo lleno al salir")
	# The watched levels.
	for lv in [7, 8, 9, 10]:
		var watch_ok := true
		var round_ok := true
		var forced_ok := true
		var found := 0
		var relaxed := 0
		for s in range(1, 13):
			var origin := Vector2i(31, 3) if lv == 8 else start
			var w := DojoTrials.make("atrapa", 1, s, field, origin)
			begin(w, lv)
			var sp: Dictionary = w.last_spawn
			if sp.get("relaxed", 0) > 0:
				relaxed += 1
				continue
			found += 1
			var behind := not field.crossed(field.path(origin, sp.tile)).is_empty()
			if sp.cross.is_empty() or not (not sp.watchers.is_empty() or behind):
				watch_ok = false
			if CatchGame.params(lv).watch_n == 2 and sp.cross.size() < 2:
				watch_ok = false
			var forced: bool = w.obj.forced
			var expect := CatchGame.time_for(lv, sp.time_path, w.obj.gate != "", forced)
			if not is_equal_approx(w.obj.max, expect):
				forced_ok = false
			if not forced and field.dist(origin, [], sp.cross)[sp.tile.y * 46 + sp.tile.x] != sp.time_path:
				round_ok = false
		check(found > 0 and watch_ok, "atrapa nivel %d: el calcetín sale en un cono o tras uno, cruzando %d (%d de 12, %d aflojados)" % [lv, CatchGame.params(lv).watch_n, found, relaxed])
		check(round_ok and forced_ok, "atrapa nivel %d: el tiempo sigue el camino que evita los conos, o lleva el bono si solo se cruza" % lv)
	# Different scarecrows at different levels (they prefer the ones not used).
	var pref := game("atrapa", 9)
	begin(pref, 7)
	var used1: Array = pref.last_spawn.cross.duplicate()
	check(pref.used == used1 and not used1.is_empty(), "atrapa: recuerda qué espantapájaros ha usado")
	# Alarm: -2 s, a red dojo, one for each scarecrow and crossing.
	var al := game("atrapa", 9)
	begin(al, 7)
	al.obj.left = 100.0
	al.obj.max = 100.0
	var sc: Dictionary = field.scarecrow("pasillo")
	var cone_tile := Vector2i(17, 5)
	al.obj.pos = Vector2(40.5, 15.5)
	al.obj.tile = Vector2i(40, 15)
	var in_cone := func(_g): return [body(0, DojoField.center(cone_tile))]
	var alarms := run(al, 1.0, in_cone)
	var first := of(alarms, "alarm")
	check(first.size() == 1 and first[0].by == "pasillo" and first[0].seconds == 2.0, "atrapa: un ladrón en un cono: alarma con el id del espantapájaros")
	check(al.view().alert > 0.0 and al.state == "playing", "atrapa: el dojo se pone rojo y no se pierde")
	check(absf(al.obj.left - 97.0) < 0.05, "atrapa: dos segundos menos (%.2f)" % al.obj.left)
	alarms = run(al, 1.5, in_cone)
	check(of(alarms, "alarm").is_empty(), "atrapa: sin repetir en los 3 s del enfriamiento")
	alarms = run(al, 1.0, in_cone)
	check(of(alarms, "alarm").size() == 1, "atrapa: y otra pasado el enfriamiento")
	var two := run(al, 0.05, func(_g): return [body(0, DojoField.center(Vector2i(17, 5))), body(1, DojoField.center(Vector2i(36, 7)))])
	check(field.watchers(Vector2i(36, 7)) == ["laberinto"] and of(two, "alarm").size() <= 1, "atrapa: cada espantapájaros tiene su enfriamiento")
	al.obj.left = 100.0
	var pen := game("atrapa", 9)
	begin(pen, 7)
	pen.obj.left = 1.0
	pen.alarm(2.0)
	check(pen.state == "playing" and pen.obj.left > 0.0, "atrapa: la alarma nunca pierde por sí sola")
	pen.step(DT, bl([body(0, Vector2(3, 3))]))
	check(pen.alarm(2.0) and of(pen.step(DT, bl([body(0, Vector2(3, 3))])), "alarm").size() == 1, "atrapa: alarm() se anuncia en el siguiente paso")
	# A rule of sight given.
	var inj := game("atrapa", 9)
	begin(inj, 7)
	inj.obj.left = 100.0
	inj.obj.pos = Vector2(40.5, 15.5)
	inj.seen = func(_sc, pos, _hidden): return pos.x < 6.0
	var by := run(inj, 0.3, func(_g): return [body(0, Vector2(3.5, 3.5))])
	check(of(by, "alarm").size() >= 1, "atrapa: la regla de visión inyectada manda")
	# No scarecrows: 7 to 10 fall on a door or the maze.
	for lv in [7, 8, 9, 10]:
		var no := game("atrapa", 3, 1, bare)
		var ev := begin(no, lv)
		var sp := of(ev, "spawn")
		check(sp.size() == 1 and bare.is_clear(sp[0].tile) and no.state == "playing", "atrapa nivel %d sin espantapájaros: sale un punto sin colgarse" % lv)
		check(no.last_spawn.get("gate", "") != "" or no.last_spawn.get("relaxed", 0) >= 0, "atrapa nivel %d sin espantapájaros: pide puerta (o laberinto)" % lv)
	# The whole game watched, on a field with no gate at all.
	var flat := MapFile.blank(30, 14)
	var flat_field := DojoField.from_map(flat, Rect2i(1, 1, 28, 12), Callable(), [])
	var fg := DojoTrials.make("atrapa", 1, 3, flat_field, Vector2i(2, 2))
	begin(fg, 8)
	check(fg.state == "playing" and fg.last_spawn.get("tile") != null, "atrapa nivel 8 en un campo liso: sale un punto")


func begin_and_return(g: DojoGame) -> DojoGame:
	begin(g)
	return g


# --- BOLOS -----------------------------------------------------------------------------------------

func _bowl_bot(g: DojoGame) -> Array:
	var b := g as BowlingGame
	for q in b.pins:
		if not q.down:
			return [body(0, q.pos, {"rolling": true, "speed": Roll.SPEED})]
	return [body(0, Vector2(3, 3))]


func _bowling_tests() -> void:
	for tier in 3:
		var first: int = DojoTrials.TIERS[tier].from
		var last: int = DojoTrials.TIERS[tier].to
		var g := game("bolos", 21, 1, null, tier)
		g.start()
		var evs := run_end(g, _bowl_bot, 600.0)
		var name: String = DojoTrials.TIERS[tier].id
		check(g.state == "won" and g.got == last - first + 1 and g.level == last, "bolos %s: un bot que rueda contra cada bolo gana el tramo (level %d)" % [name, g.level])
		var sp := of(evs, "spawn")
		var counts_ok := true
		var pins := 0
		for i in sp.size():
			if sp[i].pins.size() != BowlingGame.params(first + i).n:
				counts_ok = false
			pins += BowlingGame.params(first + i).n
		check(sp.size() == last - first + 1 and counts_ok, "bolos %s: cada ronda saca los bolos de la tabla (%s)" % [name, sp.map(func(s): return s.pins.size())])
		check(g.pins_down == pins, "bolos %s: y los tira todos (%d)" % [name, g.pins_down])
	var a := game("bolos", 5, 1, null, 2)
	var b := game("bolos", 5, 1, null, 2)
	a.start()
	b.start()
	var ta := of(run_end(a, _bowl_bot, 600.0), "spawn").map(func(e): return e.pins.map(func(p): return p.tile))
	var tb := of(run_end(b, _bowl_bot, 600.0), "spawn").map(func(e): return e.pins.map(func(p): return p.tile))
	check(ta == tb and not ta.is_empty(), "bolos: la misma semilla, los mismos bolos")
	# Only rolling knocks.
	var w := game("bolos", 8)
	begin(w, 1)
	var at: Vector2 = w.pins[0].pos
	var walk := run(w, 1.0, func(_g): return [body(0, at, {"speed": 5.0})])
	check(of(walk, "knock").is_empty() and not w.pins[0].down, "bolos: andando contra el bolo no cae")
	walk = run(w, 0.5, func(_g): return [body(0, at, {"rolling": true, "speed": 3.0})])
	check(of(walk, "knock").is_empty(), "bolos: rodando despacio (3 casillas/s) tampoco")
	walk = run(w, 0.2, func(_g): return [body(0, at + Vector2(1.0, 0), {"rolling": true, "speed": Roll.SPEED})])
	check(of(walk, "knock").is_empty(), "bolos: rodando a 1 casilla, sin tocarlo, tampoco")
	walk = run(w, 0.05, func(_g): return [body(0, at + Vector2(0.5, 0), {"rolling": true, "speed": Roll.SPEED})])
	check(of(walk, "knock").size() == 1 and w.pins[0].down, "bolos: rodando a 7,3 casillas/s contra él, cae")
	check(w.state == "between" or w.level == 2, "bolos: y con todos abajo, se acaba la ronda")
	# Strike: a knocked pin takes the ones beside it.
	var s := game("bolos", 8)
	begin(s, 5)
	check(s.pins.size() == 2 and s.pins[0].pos.distance_to(s.pins[1].pos) <= BowlingGame.CHAIN_R, "bolos: el nivel 5 saca un racimo de dos, juntos")
	var hit := run(s, 0.05, func(_g): return [body(1, s.pins[0].pos, {"rolling": true, "speed": Roll.SPEED}), body(0, Vector2(3, 3))])
	check(of(hit, "knock").size() == 2 and of(hit, "knock")[1].chain and of(hit, "strike").size() == 1, "bolos: uno derriba al otro: pleno")
	check(of(hit, "strike")[0].full and s.strikes == 1 and s.credits[1] == 2, "bolos: cuenta a quien rodó (2)")
	# A batch scattered: apart.
	var sc := game("bolos", 3)
	begin(sc, 4)
	check(sc.pins.size() == 2 and maxi(absi(sc.pins[0].tile.x - sc.pins[1].tile.x), absi(sc.pins[0].tile.y - sc.pins[1].tile.y)) >= DojoField.AVOID,
		"bolos: los bolos sueltos, separados")
	# Lost.
	var l := game("bolos", 4)
	begin(l, 3)
	var lost := run_end(l, func(_g): return [body(0, Vector2(3, 3), {"rolling": true, "speed": Roll.SPEED})], 60.0)
	check(l.state == "lost" and of(lost, "lost")[0].why == "time" and of(lost, "lost")[0].pin >= 0, "bolos: si un bolo agota su tiempo, se pierde (aunque ruedes lejos)")
	check(of(lost, "tick").size() >= 5, "bolos: con tics")
	# One pin down but the other not: still lost.
	var half := game("bolos", 4)
	begin(half, 3)
	run(half, 0.05, func(_g): return [body(0, half.pins[0].pos, {"rolling": true, "speed": Roll.SPEED})])
	check(half.pins[0].down and not half.pins[1].down, "bolos: uno abajo y el otro en pie")
	var lost2 := run_end(half, func(_g): return [body(0, Vector2(3, 3))], 60.0)
	check(half.state == "lost" and of(lost2, "lost")[0].pin == 1, "bolos: con uno en pie se acaba el tiempo y se pierde (el bolo 1)")
	# Moving pins and the door.
	var mv := game("bolos", 6)
	begin(mv, 4)
	var movers: Array = mv.pins.filter(func(q): return q.move > 0.0)
	check(movers.size() == 1 and is_equal_approx(movers[0].move, 0.5), "bolos: el nivel 4 tiene un bolo que se mueve a 0,5")
	var d := game("bolos", 4)
	begin(d, 6)
	check(d.pins.any(func(q): return q.gate == "puerta") and d.shut == ["puerta"], "bolos: el nivel 6 tiene bolos tras la puerta")
	# Time.
	var t := game("bolos", 4)
	begin(t, 2)
	check(is_equal_approx(t.pins[0].max, BowlingGame.time_for(2, t.pins[0].steps)), "bolos: cada bolo con su tiempo (base + margen * camino * 0,3)")
	# Alarm.
	var al := game("bolos", 4)
	begin(al, 1)
	var before: float = al.pins[0].left
	al.alarm(2.0)
	check(is_equal_approx(al.pins[0].left, before - 2.0), "bolos: alarm() le quita 2 s a cada bolo")


# --- EQUILIBRIO --------------------------------------------------------------------------------------

## The holder up on the pedestal, balanced (what the host says when the minigame keeps the pose).
func _ped_up(g: DojoGame) -> Array:
	return [body(0, DojoField.center(g.start_tile), {"posing": true, "hidden": true, "fell": false, "lean": 0.2})]


## Begin at a level with the holder up on the pedestal.
func begin_up(g: DojoGame, lv := 1) -> Array:
	g.start()
	g.level = lv
	return run(g, DojoTrial.READY_S + 0.1, _ped_up)


func _pedestal_tests() -> void:
	for tier in 3:
		var first: int = DojoTrials.TIERS[tier].from
		var last: int = DojoTrials.TIERS[tier].to
		var name: String = DojoTrials.TIERS[tier].id
		var g := game("pedestal", 31, 1, null, tier)
		g.start()
		var evs := run_end(g, _ped_up, 400.0)
		check(g.state == "won" and g.got == last - first + 1 and g.level == last, "equilibrio %s: aguantar las rondas del tramo lo gana (level %d, why %s)" % [name, g.level, g.lost_why])
		var sp := of(evs, "spawn")
		var holds := sp.map(func(e): return e.hold)
		var want := []
		for lv in range(first, last + 1):
			want.append(PedestalGame.params(lv).hold)
		check(holds == want, "equilibrio %s: los tiempos objetivo crecen: %s" % [name, holds])
		check(sp.all(func(e): return e.tile == start), "equilibrio %s: todas las rondas en el mismo pedestal, el de salida" % name)
		check(g.credits[0] == last - first + 1, "equilibrio %s: las rondas, a nombre de quien las aguantó" % name)
	# The minigame's fall, at every level.
	var all_fall := true
	for lv in range(1, 11):
		var f := game("pedestal", 40 + lv)
		begin_up(f, lv)
		run(f, 1.0, _ped_up)
		var e := run(f, 0.1, func(_g): return [body(0, DojoField.center(f.start_tile), {"posing": false, "fell": true, "lean": 1.7})])
		if f.state != "lost" or f.lost_why != "fall" or of(e, "fall").is_empty():
			all_fall = false
	check(all_fall, "equilibrio: el 'fell' del minijuego pierde por caída, en cada nivel")
	var fell_up := game("pedestal", 3)
	begin_up(fell_up, 1)
	run(fell_up, 0.3, func(_g): return [body(0, DojoField.center(fell_up.start_tile), {"posing": true, "fell": true, "lean": 1.7})])
	check(fell_up.state == "lost" and fell_up.lost_why == "fall", "equilibrio: 'fell' pierde aunque el cuerpo siga marcado como subido")
	# Down early.
	var d := game("pedestal", 3)
	begin_up(d, 1)
	run(d, 0.5, _ped_up)
	run(d, 0.2, func(_g): return [body(0, Vector2(3, 3), {"posing": false})])
	check(d.state == "lost" and d.lost_why == "down", "equilibrio: bajarse antes de tiempo pierde")
	# Nobody up there.
	var late := game("pedestal", 3)
	begin_up(late, 1)
	run(late, 0.2, func(_g): return [body(1, DojoField.center(late.start_tile), {"posing": true})])
	check(late.state == "lost" and late.lost_why == "down", "equilibrio: si el que lo empezó no está arriba, se pierde; otro subido no cuenta")
	# The lean reaches the picture; the time is the game's.
	var ext := game("pedestal", 3)
	begin_up(ext, 1)
	run(ext, 1.0, _ped_up)
	check(is_equal_approx(ext.view().lean, 0.2) and ext.view().timer.kind == "hold" and ext.view().fall == BalanceGame.FALL, "equilibrio: la inclinación del minijuego llega a la vista")
	run(ext, 5.0, _ped_up)
	check(ext.state == "between" or ext.got == 1, "equilibrio: con el minijuego llevando el equilibrio, se cuenta el tiempo y se supera la ronda")
	var al := game("pedestal", 3)
	begin_up(al, 1)
	run(al, 0.3, _ped_up)
	var hold0: float = al.hold_left
	al.alarm(2.0)
	check(al.hold_left > hold0 + 1.5, "equilibrio: alarm() alarga lo que hay que aguantar")


# --- AGUANTA ESCONDIDO -----------------------------------------------------------------------------------

var hides: Array[Vector2i] = [Vector2i(5, 4), Vector2i(6, 12), Vector2i(20, 12), Vector2i(26, 5)]


func _hide_game(seed_ := 51, players := 1, tier := 0) -> HideGame:
	var g := game("aguanta", seed_, players, null, tier) as HideGame
	g.set_hideouts(hides)
	g.set_lantern(Vector2i(10, 2), PI / 2.0)
	g.seen = func(_sc, pos, hidden): return not hidden and pos.x > 40.0
	return g


func _hide_bot(g: DojoGame) -> Array:
	var h := g as HideGame
	var out := []
	for i in h.players:
		var at: Vector2i = h.open_hides[i % h.open_hides.size()] if not h.open_hides.is_empty() else hides[0]
		out.append(body(i, DojoField.center(at) + Vector2(0.2, 0), {"hidden": true, "hold": int(h.time * 4.0) % 2 == 0}))
	return out


func _hide_tests() -> void:
	var all_holds := []
	var all_spots := []
	for tier in 3:
		var first: int = DojoTrials.TIERS[tier].from
		var last: int = DojoTrials.TIERS[tier].to
		var g := _hide_game(51, 1, tier)
		g.start()
		var evs := run_end(g, _hide_bot, 400.0)
		check(g.state == "won" and g.got == last - first + 1 and g.level == last, "aguanta %s: un bot escondido que aguanta el estornudo gana el tramo (level %d, why %s)" % [DojoTrials.TIERS[tier].id, g.level, g.lost_why])
		all_holds.append_array(of(evs, "spawn").map(func(e): return e.hold))
		all_spots.append_array(of(evs, "spawn").map(func(e): return e.spots))
	check(all_holds == [5.0, 7.0, 9.0, 12.0, 15.0, 18.0, 21.0, 24.0, 27.0, 30.0], "aguanta: el tiempo a aguantar crece: %s" % [all_holds])
	check(all_spots == [4, 4, 4, 3, 3, 3, 2, 2, 1, 1], "aguanta: cada vez menos escondites abiertos: %s" % [all_spots])
	# The first round leaves open the armour one started in.
	var open_ok := true
	for seed_ in range(1, 13):
		var st := DojoTrials.make("aguanta", 1, seed_, field, hides[3], 2) as HideGame
		st.set_hideouts(hides)
		st.set_lantern(Vector2i(10, 2), PI / 2.0)
		st.start()
		run(st, DojoTrial.READY_S + 0.1)
		if st.spots != 2 or not st.open_hides.has(hides[3]):
			open_ok = false
	check(open_ok, "aguanta: en la primera ronda queda abierto el escondite donde se empezó (con dos abiertos, en el difícil)")
	# Leaving loses.
	var l := _hide_game()
	begin(l, 1)
	run(l, 1.0, _hide_bot)
	check(l.phase == "hold", "aguanta: todos dentro, empieza a contar")
	var e1 := run(l, 0.1, func(_g): return [body(0, Vector2(3, 3), {"hidden": false})])
	check(l.state == "playing", "aguanta: un instante fuera se perdona")
	e1 = run(l, 0.5, func(_g): return [body(0, Vector2(3, 3), {"hidden": false})])
	check(l.state == "lost" and l.lost_why == "left" and of(e1, "lost")[0].by == 0, "aguanta: salir del escondite antes de tiempo pierde")
	# Seen loses.
	var s := _hide_game()
	begin(s, 1)
	var e2 := run(s, 0.3, func(_g): return [body(0, Vector2(41.5, 3.5))])
	check(s.state == "lost" and s.lost_why == "seen", "aguanta: la linterna ve a uno fuera: pierdes")
	var s2 := _hide_game()
	begin(s2, 1)
	run(s2, 0.3, func(_g): return [body(0, Vector2(41.5, 3.5), {"hidden": true})])
	check(s2.state == "playing" or s2.phase == "hold", "aguanta: escondido no te ve")
	# Late.
	var late := _hide_game()
	begin(late, 1)
	run(late, 8.5, func(_g): return [body(0, Vector2(3.5, 3.5))])
	check(late.state == "lost" and late.lost_why == "late", "aguanta: si no se llega a esconderse a tiempo, se pierde")
	# The default sight (the field's) with the lantern's cone.
	var d := game("aguanta", 5) as HideGame
	d.set_hideouts(hides)
	d.set_lantern(Vector2i(10, 2), PI / 2.0)
	begin(d, 1)
	run(d, 0.1, func(_g): return [body(0, Vector2(10.5, 5.0))])
	check(d.state == "lost" and d.lost_why == "seen", "aguanta: sin regla dada, la del campo: delante de la linterna, a la vista")
	var d2 := game("aguanta", 5) as HideGame
	d2.set_hideouts(hides)
	d2.set_lantern(Vector2i(10, 2), PI / 2.0)
	begin(d2, 1)
	run(d2, 0.5, func(_g): return [body(0, Vector2(3.5, 3.5))])
	check(d2.state == "playing", "... y a un lado, no")
	# The sneeze.
	var sn := _hide_game()
	begin(sn, 5)
	var e3 := run_end(sn, func(_g): return [body(0, DojoField.center(sn.open_hides[0]), {"hidden": true, "hold": false})], 60.0)
	check(sn.state == "lost" and sn.lost_why == "sneeze" and not of(e3, "sneeze").is_empty(), "aguanta: sin aguantar el estornudo, sale (nivel 5)")
	check(not of(e3, "tickle").is_empty(), "aguanta: y antes avisa (tickle)")
	var sn4 := _hide_game()
	begin(sn4, 4)
	var e4 := run(sn4, 15.0, func(_g): return [body(0, DojoField.center(sn4.open_hides[0]), {"hidden": true, "hold": false})])
	check(of(e4, "sneeze").is_empty() and sn4.state != "lost", "aguanta: hasta el nivel 4, no hay estornudo")
	var sn9 := _hide_game()
	begin(sn9, 9)
	run(sn9, 2.0, func(_g): return [body(0, DojoField.center(sn9.open_hides[0]), {"hidden": true})])
	check(sn9.bars.size() == 1 and sn9.bars[0] > 0.0, "aguanta: la barra sube")
	# Several thieves: as many as hideouts, up to the whole band.
	var m2 := _hide_game(52, 2)
	begin(m2, 9)
	check(m2.spots == 1 and m2.open_hides.size() == 1, "aguanta: en el nivel 9, un escondite")
	run(m2, 1.0, func(_g): return [body(0, DojoField.center(m2.open_hides[0]), {"hidden": true, "hold": true}), body(1, Vector2(3.5, 3.5))])
	check(m2.phase == "hold" and m2.need == 1 and m2.inside == [0], "aguanta: con un solo escondite basta con que uno se esconda (need %d)" % m2.need)
	run(m2, 0.2, func(_g): return [body(0, DojoField.center(m2.open_hides[0]), {"hidden": true, "hold": true}), body(1, Vector2(41.5, 3.5))])
	check(m2.state == "lost" and m2.lost_why == "seen", "aguanta: y el otro, fuera de la luz, o pierde")
	var m3 := _hide_game(52, 2)
	begin(m3, 1)
	run(m3, 1.0, func(_g): return [body(0, DojoField.center(m3.open_hides[0]), {"hidden": true}), body(1, Vector2(3.5, 3.5))])
	check(m3.phase == "enter" and m3.need == 2, "aguanta: en el nivel 1, con cuatro escondites, se esconden los dos (need %d)" % m3.need)
	var a := _hide_game(9)
	var b := _hide_game(9)
	a.start()
	b.start()
	run(a, 12.0, _hide_bot)
	run(b, 12.0, _hide_bot)
	check(a.open_hides == b.open_hides and a.lantern_angle == b.lantern_angle, "aguanta: la misma semilla, los mismos escondites")
	var lant := _hide_game(9)
	begin(lant, 1)
	var angles := []
	for i in 300:
		lant.step(DT, bl(_hide_bot(lant)))
		angles.append(lant.lantern_angle)
	check(angles.max() - angles.min() > 0.5, "aguanta: la linterna barre (%.2f rad)" % (angles.max() - angles.min()))
	var al := _hide_game(9)
	begin(al, 1)
	run(al, 1.0, _hide_bot)
	var h0: float = al.hold_left
	al.alarm(2.0)
	check(al.hold_left > h0 + 1.5, "aguanta: alarm() alarga la espera")


# --- Saving -------------------------------------------------------------------------------------------

func _save_tests() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	check(DojoTrials.best("atrapa", 1) == 0 and not DojoTrials.won("atrapa", 1), "guardado: sin fichero, nada")
	Story.unlock(3, 1)
	Story.keep_stars(1, 1, Story.STAR_TAKEN)
	var story_before := Story.unlocked(1)
	check(DojoTrials.record("atrapa", 1, 4, false), "guardado: un primer nivel es récord")
	check(DojoTrials.best("atrapa", 1) == 4 and not DojoTrials.won("atrapa", 1), "... y se guarda")
	check(not DojoTrials.record("atrapa", 1, 4, false) and not DojoTrials.record("atrapa", 1, 3, false), "guardado: igual o peor no es récord")
	check(DojoTrials.best("atrapa", 1) == 4, "... y no pisa")
	check(DojoTrials.record("atrapa", 1, 7, false) and DojoTrials.best("atrapa", 1) == 7, "guardado: mejor sí")
	check(DojoTrials.best("atrapa", 2) == 0 and DojoTrials.best("bolos", 1) == 0 and DojoTrials.best("atrapa", 4) == 0, "guardado: otra banda y otro juego, aparte")
	check(DojoTrials.record("atrapa", 2, 2, false) and DojoTrials.best("atrapa", 2) == 2 and DojoTrials.best("atrapa", 1) == 7, "guardado: cada banda con el suyo")
	DojoTrials.record("atrapa", 1, 10, true)
	check(DojoTrials.won("atrapa", 1) and not DojoTrials.won("atrapa", 2), "guardado: ganado, por banda")
	check(not DojoTrials.record("atrapa", 1, 10, true), "guardado: ganar otra vez con el mismo nivel no es récord")
	check(DojoTrials.record("atrapa", 1, 9, false, 2) and DojoTrials.best("atrapa", 1, 2) == 9 and DojoTrials.best("atrapa", 1, 0) == 10
		and DojoTrials.best("atrapa", 1, 1) == 0 and not DojoTrials.won("atrapa", 1, 2), "guardado: cada dificultad con su mejor y su ganado")
	DojoTrials.record("bolos", 3, 500, false)
	check(DojoTrials.best("bolos", 3) == 99, "guardado: tope 99")
	check(Story.unlocked(1) == story_before and (Story.star_mask(1, 1) & Story.STAR_TAKEN) != 0, "guardado: no pierde [story] ni [stars]")
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	check(cfg.has_section_key("dojo", "atrapa_easy_best_1") and cfg.has_section_key("dojo", "atrapa_easy_won_1") and cfg.has_section_key("dojo", "atrapa_easy_best_2")
		and cfg.has_section_key("dojo", "atrapa_hard_best_1"), "guardado: claves <id>_<dificultad>_best_<n> y <id>_<dificultad>_won_<n> en [dojo]")
	check(not DojoTrials.record("nada", 1, 5, false), "guardado: un juego que no existe no se guarda")
	# A progress from before the dojo (no [dojo]).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var old := ConfigFile.new()
	old.set_value("story", "robo_1", 6)
	old.set_value("story", "unlocked", 4)
	old.save(Story.save)
	check(DojoTrials.best("aguanta", 1) == 0 and not DojoTrials.won("aguanta", 1) and Story.unlocked(1) == 6, "migración: un progress.cfg sin [dojo] se lee sin problema")
	check(DojoTrials.record("aguanta", 1, 3, false) and DojoTrials.best("aguanta", 1) == 3 and Story.unlocked(1) == 6, "migración: y se puede guardar sin perder lo de antes")
	var old2 := ConfigFile.new()
	old2.load(Story.save)
	check(old2.get_value("story", "unlocked", 0) == 4, "migración: hasta las claves viejas siguen")
	# settle(): the end of a game.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var g := game("atrapa", 5, 2)
	g.start()
	var evs := run_end(g, func(_g): return [body(0, Vector2(3, 3))], 60.0)
	check(g.state == "lost" and DojoTrials.settle(g, evs) and g.new_record and g.best == g.level, "settle: al perder se guarda el nivel y es récord")
	check(DojoTrials.best("atrapa", 2) == g.level and DojoTrials.best("atrapa", 2, 1) == 0, "... para esa banda y esa dificultad")
	var again := game("atrapa", 5, 2)
	check(again.best == g.level, "make trae el mejor de la banda")
	var hard := game("atrapa", 5, 2, null, 2)
	hard.start()
	var hard_evs := run_end(hard, func(_g): return [body(0, Vector2(3, 3))], 60.0)
	check(hard.level == 7 and DojoTrials.settle(hard, hard_evs) and DojoTrials.best("atrapa", 2, 2) == 7 and hard.best == 7 and again.best == g.level,
		"settle: el difícil empieza en el 7 y guarda en lo suyo, sin tocar el fácil")
	again.start()
	var evs2 := run_end(again, func(_g): return [body(0, Vector2(3, 3))], 60.0)
	check(not DojoTrials.settle(again, evs2) and not again.new_record, "settle: igual, no es récord")
	check(not DojoTrials.settle(again, []), "settle: sin fin, nada")


# --- The real dojo -------------------------------------------------------------------------------------

func _den_tests() -> void:
	var map := Practice.map(1)
	var f := DojoField.from_den(map)
	check(not f.all_clear().is_empty(), "dojo real: hay dónde poner cosas (%d puntos limpios)" % f.all_clear().size())
	var reach := f.dist(map.spawn)
	var some := f.all_clear().filter(func(t): return reach[t.y * f.w + t.x] >= 0)
	check(not some.is_empty(), "dojo real: se llega desde la casa (%d)" % some.size())
	var inside := f.all_clear().all(func(t): return f.region.has_point(t) and map.at(t) == Tiles.FLOOR)
	check(inside, "dojo real: todo punto es suelo dentro del dojo")
	var zones := {}
	for t in f.all_clear():
		zones[f.zone_of(t)] = true
	print("     zonas del dojo: ", zones.keys(), "  puertas: ", f.gates.size(), "  región: ", f.region)
	var from: Vector2i = f.all_clear()[0]
	for id in DojoTrials.of_kind("game").map(func(r): return r.id):
		var g := DojoTrials.make(id, 1, 77, f, from)
		g.starter = 0
		g.start()
		run(g, 2.3, func(_g): return [body(0, DojoField.center(from), {"posing": true})])
		check(g.state == "playing", "dojo real: %s empieza sin colgarse" % id)
		if id == "atrapa":
			var okk := true
			for lv in [1, 3, 6, 8, 10]:
				var q := DojoTrials.make(id, 1, 5 + lv, f, from)
				begin(q, lv)
				okk = okk and q.state == "playing" and not q.obj.is_empty() and f.is_clear(q.last_spawn.tile)
			check(okk, "dojo real: atrapa saca puntos claros en los niveles 1, 3, 6, 8 y 10")
	# With scarecrows put in by hand on the real dojo (no matter which are open).
	var sc: Array = []
	for s in Practice.scarecrows(25):
		sc.append({"id": s.id, "tile": s.at, "facing": s.dir})
	f.set_scarecrows(sc)
	var q := DojoTrials.make("atrapa", 1, 3, f, from)
	begin(q, 7)
	check(q.state == "playing", "dojo real: con los espantapájaros del circuito, el nivel 7 sale (%d espantapájaros)" % sc.size())


# --- The view ------------------------------------------------------------------------------------------

func _view_tests() -> void:
	var v := TrialView.new()
	root.add_child(v)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 12, 8), Vector3.ZERO)
	v.setup(cam)
	var ok := true
	for id in DojoTrials.of_kind("game").map(func(r): return r.id):
		var g := game(id, 3)
		if id == "aguanta":
			(g as HideGame).set_hideouts(hides)
		g.start()
		run(g, 2.3, _ped_up if id == "pedestal" else Callable())
		v.show_view(g.view())
		await process_frame
		v.react(g.step(DT, bl([])))
		check(not v.panel_open(), "vista %s: en juego, sin panel" % id)
		run(g, 90.0)
		v.show_view(g.view())
		await process_frame
		ok = ok and g.state == "lost" and v.visible
		check(v.panel_open() and v.choices() == ["again", "exit"] and v.menu.current() == "again", "vista %s: al perder, OTRA VEZ (elegida) y SALIR" % id)
		v.menu.move(1)
		check(v.menu.current() == "exit", "vista %s: la flecha mueve la elección" % id)
	check(ok, "vista: cada juego se muestra, y el fin de cada uno")
	var w := game("atrapa", 4)
	w.start()
	run_end(w, _catch_bot, 400.0)
	v.show_view(w.view())
	await process_frame
	check(w.state == "won" and v.choices() == ["next", "again", "exit"] and v.menu.current() == "next", "vista: al ganar el fácil, SEGUIR (elegida), OTRA VEZ y SALIR [%s %s]" % [w.state, v.choices()])
	var w3 := game("atrapa", 4, 1, null, 2)
	w3.start()
	run_end(w3, _catch_bot, 400.0)
	v.show_view(w3.view())
	await process_frame
	check(w3.state == "won" and v.choices() == ["again", "exit"] and v.menu.current() == "again", "vista: al ganar el difícil no hay a dónde seguir: OTRA VEZ y SALIR")
	w.abort()
	v.show_view(w.view())
	check(not v.visible and not v.panel_open(), "vista: parado, se esconde y cierra el panel")
	check(TrialView.sound_for({"e": "catch"}) == "stolen" and TrialView.sound_for({"e": "nada"}) == "", "vista: sonido de cada evento")
	var all_sounds := true
	var sounds := ["pin", "tick", "stolen", "bin", "sting", "ok", "go", "siren", "caught", "escaped", "sneeze", "nav", "roll_bump"]
	for k in TrialView.SOUNDS:
		if not sounds.has(TrialView.SOUNDS[k]):
			all_sounds = false
	check(all_sounds, "vista: usa sonidos de Sfx que existen")
	for k in ["HIDEOUT_TRIAL_NAME_ATRAPA", "HIDEOUT_TRIAL_START_ATRAPA", "HIDEOUT_TRIAL_START_BOLOS", "HIDEOUT_GAME_LEAVE_KEY", "HIDEOUT_GAME_READY", "HIDEOUT_TRIAL_LEVEL",
			"HIDEOUT_GAME_LOST_BOLOS", "HIDEOUT_GAME_MVP", "HIDEOUT_TIER_EASY", "HIDEOUT_TIER_MEDIUM", "HIDEOUT_TIER_HARD", "HIDEOUT_TRIAL_WHY_SNEEZE"]:
		check(Text.t(k) != k, "texto %s existe" % k)
	v.queue_free()
	cam.queue_free()
