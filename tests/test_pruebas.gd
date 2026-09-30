extends SceneTree
## Las pruebas del dojo, todas iguales (DojoTrials): el contrato que cumple cada fila del
## registro (ciclo de vida, tres dificultades, punto de inicio alcanzable, récord, panel),
## el panel de fin (TrialMenu, TrialView) con teclado izquierdo y derecho, mando y ratón,
## la opción elegida de entrada, que la pulsación que acaba la prueba no acepte y que no se
## acepte dos veces, y el recorrido de cada una en la casa (empezar con la acción, HUD común,
## ganar y perder hasta el panel, SEGUIR / OTRA VEZ / SALIR, una prueba a la vez, Tab).
const Support := preload("res://tests/support.gd")
var qa := Support.new()
const DT := 1.0 / 60.0
var m


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func frames(n := 4) -> void:
	for i in n:
		await process_frame


## Frames of the game, as the physics would run them.
func run(n: int) -> void:
	for f in n:
		m.hands.pad_frame = Engine.get_physics_frames() - 1
		m.loop.tick(DT)


func key(code: Key, physical := false) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	if physical:
		e.physical_keycode = code
	e.pressed = true
	return e


func pad(button: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = true
	return e


func stick(axis: int, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	return e


func bl(list: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(list)
	return out


func _init() -> void:
	Story.save = "user://test_pruebas.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Text.setup()
	_contract()
	_records()
	_menu()
	await _view()
	await _house()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())


# --- El contrato de cada fila del registro ---------------------------------------------------

func _contract() -> void:
	var ids := DojoTrials.ids()
	check(ids.size() == 9 and ids.size() == Den.DOJO_ZONES.size(), "nueve pruebas, cada una con su zona: %s" % [ids])
	var kinds := {}
	for row in DojoTrials.TABLE:
		kinds[row.kind] = int(kinds.get(row.kind, 0)) + 1
	check(kinds == {"game": 4, "bench": 4, "circuit": 1}, "cuatro juegos, cuatro pruebas del banco y el circuito: %s" % [kinds])
	# The full map, everything open: the start points are there to be got to.
	Story.unlock(25, 1)
	var map := Practice.map(1)
	var reach := map.distances(map.spawn)
	var f := DojoField.from_den(map)
	f.set_scarecrows(Practice.scarecrows(1))
	for row in DojoTrials.TABLE:
		var id := String(row.id)
		check(row.cls != null and (row.cls as GDScript).new() is DojoTrial, "%s: su clase es una DojoTrial" % id)
		check(Story.LESSONS.has(row.lesson) and Text.t(row.name) != row.name and Text.t(row.hint) != row.hint, "%s: lección, nombre y línea de «¿LISTOS?» con texto" % id)
		check(Practice.VIAS.has(row.via) and row.starts.size() == 3, "%s: tres puntos de inicio, de un tipo que existe (%s)" % [id, row.via])
		check(Practice.VIAS[row.via].action == (String(row.start_text) != ""), "%s: se empieza con la acción si y solo si dice qué hace la acción" % id)
		check(DojoTrials.unlocked(id, 1), "%s: con todo enseñado, abierta" % id)
		for tier in 3:
			var stand := Practice.stand_of(id, tier)
			var tile := Vector2i(int(floor(stand.x)), int(floor(stand.y)))
			check(map.at(tile) == Tiles.FLOOR and reach[tile.y * map.w + tile.x] >= 0, "%s %d: se llega a donde se está para empezarla %s" % [id, tier, stand])
			var at: Vector2i = row.starts[tier]
			var cover: bool = map.at(at) == Tiles.COVER
			check(cover == Practice.VIAS[row.via].solid or row.via == "armour", "%s %d: su casilla %s bloquea si es un objeto que ocupa sitio" % [id, tier, at])
			if row.has("wall"):
				check(map.at(at) == Tiles.FLOOR and map.at(at + row.wall) == Tiles.WALL, "%s %d: colgada de la pared que dice" % [id, tier])
			if Practice.VIAS[row.via].action:
				check(Practice.start_at(stand, 1) == {"id": id, "tier": tier}, "%s %d: la acción junto a ella la empieza a su dificultad" % [id, tier])
			# The life cycle.
			var t := DojoTrials.make(id, 1, 5, f, at, tier)
			t.starter = 0
			check(t.state == "idle" and not t.active() and t.tier == tier and t is DojoTrial, "%s %d: recién hecha, parada, a su dificultad" % [id, tier])
			check(t.title() == "%s  %s" % [Text.t(row.name), Text.t(DojoTrials.TIERS[tier].text)], "%s %d: título «NOMBRE  DIFICULTAD»" % [id, tier])
			t.start()
			var v := t.view()
			check(t.state == "ready" and v.state == "ready" and v.hud.size() >= 1 and String(v.hud.back()).begins_with("MEJOR"), "%s %d: start() la pone en «¿LISTOS?» con las líneas de siempre: %s" % [id, tier, v.hud])
			var body := {"id": 0, "pos": Vector2(at) + Vector2(0.5, 1.5), "out": false, "hidden": row.via == "plinth" or row.via == "armour", "posing": row.via == "plinth", "speed": 0.0, "low": false}
			if row.kind == "bench":
				body["game"] = (t as BenchTrial).minigame({})
			var evs := []
			for i in int(DojoTrial.READY_S / DT) + 5:
				evs.append_array(t.step(DT, bl([body])))
			check(t.state == "playing", "%s %d: pasados los 2 s, en juego" % [id, tier])
			if row.kind == "bench":
				check(evs.any(func(e): return e.e == "go") and body.game.blocked == "ready", "%s %d: el minijuego está retenido hasta el «go» (lo suelta el anfitrión)" % [id, tier])
			t.abort()
			check(t.state == "idle" and not t.active(), "%s %d: abort() la deja parada" % [id, tier])
			# The end: won and lost, and what the panel is told.
			t.start()
			t._win()
			var won := t.view()
			check(t.finished() and t.won() and won.result.won and won.result.title == Text.t("HIDEOUT_TRIAL_WON") and won.result.has_next == (tier < 2), "%s %d: superada: resultado con SEGUIR solo si hay otra dificultad" % [id, tier])
			check(won.result.score_line != "" and won.result.line != "", "%s %d: y con su marca y su línea" % [id, tier])
			var t2 := DojoTrials.make(id, 1, 5, f, at, tier)
			t2.start()
			t2._lose("time")
			var lost := t2.view()
			check(t2.finished() and not lost.result.won and not lost.result.has_next and lost.result.title != "" and lost.result.line != "", "%s %d: fallada: resultado sin SEGUIR" % [id, tier])
			check(TrialMenu.options_for(won.result.won, won.result.has_next) == ([TrialMenu.NEXT, TrialMenu.AGAIN, TrialMenu.EXIT] if tier < 2 else [TrialMenu.AGAIN, TrialMenu.EXIT]) \
				and TrialMenu.options_for(false, false) == [TrialMenu.AGAIN, TrialMenu.EXIT], "%s %d: las opciones del panel" % [id, tier])
	# Lost by the clock, from the outside: the tests of the bench and the circuit.
	for id in ["lockpick", "squeeze", "wires", "steady", "circuit"]:
		var row := DojoTrials.info(id)
		var t := DojoTrials.make(id, 1, 5, f, row.starts[1], 1)
		t.starter = 0
		t.start()
		var body := {"id": 0, "pos": Vector2(40, 3), "out": false, "hidden": false, "speed": 0.0}
		if id != "circuit":
			body["game"] = (t as BenchTrial).minigame({})
			body.game.blocked = ""
		for i in int(90.0 / DT):
			t.step(DT, bl([body]))
			if t.finished():
				break
		check(t.state == "lost" and t.lost_why == "time", "%s: sin hacerla, se pierde por el reloj (%s tras %.0f s)" % [id, t.lost_why, t.time])
	# The bench: done, the minigame's word; left, gone.
	var b := DojoTrials.make("lockpick", 1, 5, f, Vector2i(27, 5), 1) as BenchTrial
	b.starter = 0
	b.start()
	var g := b.minigame({})
	g.blocked = ""
	var bodyb := {"id": 0, "pos": Vector2(27.5, 6.5), "out": false, "hidden": false, "speed": 0.0, "game": g}
	for i in 200:
		b.step(DT, bl([bodyb]))
	check(b.state == "playing" and b.view().progress == 0.0 and b.view().timer.max == 40.0, "GANZÚA medio: en juego, con su reloj de 40 s")
	g.done = true
	var evs_b := b.step(DT, bl([bodyb]))
	check(b.state == "won" and evs_b.any(func(e): return e.e == "won") and b.score() > 1.0 and b.score() < 6.0, "... hecha, gana con su tiempo (%.1f s)" % b.score())
	var b2 := DojoTrials.make("wires", 1, 5, f, Vector2i(41, 1), 0) as BenchTrial
	b2.starter = 0
	b2.start()
	for i in 200:
		b2.step(DT, bl([{"id": 0, "pos": Vector2(41.5, 1.5), "out": false, "game": null}]))
	check(b2.state == "idle", "CABLES: si el ladrón suelta el minijuego, la prueba acaba sin panel ni marca")
	check(BenchTrial.steps_for("lockpick", 2) == 3 and BenchTrial.steps_for("steady", 1) == 6 and BenchTrial.steps_for("squeeze", 0) == Hideouts.TIGHT.get("fridge", 0) \
		and BenchTrial.steps_for("squeeze", 1) == Hideouts.TIGHT.get("box", 0), "los pasos de cada dificultad del banco: pines, lámparas, apretón del mueble")
	# The circuit: the goal wins, a torch on you loses.
	var c := DojoTrials.make("circuit", 1, 5, f, Vector2i(21, 20), 1) as CircuitTrial
	c.starter = 0
	c.guards = [{"id": "g", "at": Vector2i(33, 19), "dir": PI}]
	c.los = func(_a, _b, _low): return true
	c.start()
	for i in 130:
		c.step(DT, bl([{"id": 0, "pos": Vector2(22.5, 20.5), "out": false, "hidden": false}]))
	check(c.state == "playing", "circuito: en juego, lejos de las linternas")
	var seen_evs := c.step(DT, bl([{"id": 0, "pos": Vector2(30.5, 19.5), "out": false, "hidden": false}]))
	check(c.state == "lost" and c.lost_why == "seen" and seen_evs.any(func(e): return e.e == "seen"), "circuito: una linterna que te ve, prueba fallada")
	var c2 := DojoTrials.make("circuit", 1, 5, f, Vector2i(21, 20), 0) as CircuitTrial
	c2.starter = 0
	c2.guards = c.guards
	c2.los = c.los
	c2.start()
	for i in 130:
		c2.step(DT, bl([{"id": 0, "pos": Vector2(22.5, 20.5), "out": false, "hidden": false}]))
	c2.step(DT, bl([{"id": 0, "pos": Vector2(33.5, 27.5), "out": false, "hidden": false}]))
	check(c2.state == "won" and c2.score() > 0.0, "circuito: llegar a la meta gana con el tiempo (%.1f s)" % c2.score())
	check(c.speed() == 1.0 and c2.speed() == 0.7 and (DojoTrials.make("circuit", 1, 5, f, Vector2i(21, 20), 2) as CircuitTrial).speed() == 1.4, "circuito: los espantapájaros barren más rápido cuanto más difícil")
	Story.save = "user://test_pruebas.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))


# --- Los récords, iguales para todas ------------------------------------------------------------

func _records() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(3, 1)
	# Time: less is better; a lost one is no mark.
	check(DojoTrials.record_kind("lockpick") == "time" and DojoTrials.record_kind("circuit") == "time" and DojoTrials.record_kind("atrapa") == "level", "los juegos guardan el nivel; el banco y el circuito, el tiempo")
	check(DojoTrials.best("lockpick", 1, 1) == 0.0 and not DojoTrials.won("lockpick", 1, 1), "sin fichero, nada")
	check(not DojoTrials.record("lockpick", 1, 5.0, false, 1) and DojoTrials.best("lockpick", 1, 1) == 0.0, "una perdida no guarda tiempo")
	check(DojoTrials.record("lockpick", 1, 12.345, true, 1) and is_equal_approx(DojoTrials.best("lockpick", 1, 1), 12.35) and DojoTrials.won("lockpick", 1, 1), "la primera pasada es récord, con dos decimales")
	check(not DojoTrials.record("lockpick", 1, 12.35, true, 1) and not DojoTrials.record("lockpick", 1, 20.0, true, 1) and is_equal_approx(DojoTrials.best("lockpick", 1, 1), 12.35), "igual o más lenta, no es récord y no pisa")
	check(DojoTrials.record("lockpick", 1, 9.0, true, 1) and is_equal_approx(DojoTrials.best("lockpick", 1, 1), 9.0), "más rápida, sí")
	check(DojoTrials.best("lockpick", 1, 0) == 0.0 and DojoTrials.best("lockpick", 1, 2) == 0.0 and DojoTrials.best("lockpick", 2, 1) == 0.0 and DojoTrials.best("wires", 1, 1) == 0.0, "por dificultad, por banda y por prueba")
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	check(cfg.has_section_key("dojo", "lockpick_medium_time_1") and cfg.has_section_key("dojo", "lockpick_medium_won_1") and Array(cfg.get_sections()).all(func(s): return s in ["story", "dojo"]),
		"clave <prueba>_<dificultad>_time_<n> en [dojo], junto a las de siempre")
	# settle() on the ends of a bench trial and of a game.
	var f := DojoField.from_map(MapFile.blank(20, 20), Rect2i(1, 1, 18, 18), Callable(), [])
	var t := DojoTrials.make("wires", 1, 3, f, Vector2i(5, 5), 2)
	t.start()
	t.time = 21.5
	t._win()
	check(DojoTrials.settle(t, t.step(DT, bl([]))) and t.new_record and t.best == 21.5, "settle: una pasada del banco guarda su tiempo y lo marca como récord")
	var t2 := DojoTrials.make("wires", 1, 3, f, Vector2i(5, 5), 2)
	check(t2.best == 21.5 and t2.best_text() == "MEJOR 21.5 s", "make trae la mejor marca, en palabras: %s" % t2.best_text())
	t2.start()
	t2.time = 30.0
	t2._win()
	check(not DojoTrials.settle(t2, t2.step(DT, bl([]))) and not t2.new_record, "... y una más lenta no es récord")
	check(t2.result().best_line == "DIFÍCIL · 1 LADRÓN · MEJOR 21.5 s", "la línea de la mejor marca del panel: %s" % t2.result().best_line)
	var t3 := DojoTrials.make("atrapa", 2, 3, f, Vector2i(5, 5), 1)
	check(t3.band_text() == "2 LADRONES" and t3.best_text() == "MEJOR --", "por banda de dos: «2 LADRONES», sin marca")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))


# --- El panel de fin: TrialMenu -----------------------------------------------------------------

func _menu() -> void:
	var w := TrialMenu.new()
	w.open(TrialMenu.options_for(true, true), TrialMenu.default_for(true, true))
	check(w.options == ["next", "again", "exit"] and w.current() == "next", "ganada: SEGUIR elegida de entrada")
	var l := TrialMenu.new()
	l.open(TrialMenu.options_for(false, false), TrialMenu.default_for(false, false))
	check(l.options == ["again", "exit"] and l.current() == "again", "perdida: OTRA VEZ elegida de entrada")
	var top := TrialMenu.new()
	top.open(TrialMenu.options_for(true, false), TrialMenu.default_for(true, false))
	check(top.options == ["again", "exit"] and top.current() == "again", "ganada la última dificultad: no hay SEGUIR, OTRA VEZ elegida")
	# Not heard for the first moment: the press that ended the trial does not pick.
	check(w.input(key(KEY_E)).is_empty() and w.input(key(KEY_ESCAPE)).is_empty() and w.input(pad(0)).is_empty() and w.current() == "next", "la pulsación que acaba la prueba no acepta ni sale: el panel está sordo %.1f s" % TrialMenu.GUARD_S)
	check(w.input(key(KEY_RIGHT)).has("move") and w.current() == "again", "... pero moverse, sí")
	w.tick(TrialMenu.GUARD_S - 0.1)
	check(w.input(key(KEY_E)).is_empty(), "... hasta el final del plazo")
	w.tick(0.2)
	# Moving: every way of it, in each half of the keyboard and the pad.
	w.selected = 0
	var moves := [
		["flecha derecha", key(KEY_RIGHT), 1], ["flecha izquierda", key(KEY_LEFT), -1], ["flecha abajo", key(KEY_DOWN), 1], ["flecha arriba", key(KEY_UP), -1],
		["D", key(KEY_D, true), 1], ["A", key(KEY_A, true), -1], ["S", key(KEY_S, true), 1], ["W", key(KEY_W, true), -1],
		["cruceta derecha", pad(JOY_BUTTON_DPAD_RIGHT), 1], ["cruceta izquierda", pad(JOY_BUTTON_DPAD_LEFT), -1],
		["cruceta abajo", pad(JOY_BUTTON_DPAD_DOWN), 1], ["cruceta arriba", pad(JOY_BUTTON_DPAD_UP), -1],
		["RB", pad(JOY_BUTTON_RIGHT_SHOULDER), 1], ["LB", pad(JOY_BUTTON_LEFT_SHOULDER), -1],
	]
	for mv in moves:
		w.selected = 1
		var r := w.input(mv[1])
		check(r.has("move") and w.selected == posmod(1 + int(mv[2]), 3), "mover con %s" % mv[0])
	w.selected = 2
	w.input(key(KEY_RIGHT))
	check(w.current() == "next", "la selección da la vuelta por el final")
	w.input(key(KEY_LEFT))
	check(w.current() == "exit", "... y por el principio")
	# The stick: one move for each push, and again only after coming back.
	w.selected = 0
	check(w.input(stick(JOY_AXIS_LEFT_X, 0.9)).has("move") and w.selected == 1, "stick a la derecha: un paso")
	check(w.input(stick(JOY_AXIS_LEFT_X, 0.95)).is_empty() and w.selected == 1, "... y mantenido, no repite")
	w.input(stick(JOY_AXIS_LEFT_X, 0.0))
	check(w.input(stick(JOY_AXIS_LEFT_X, -0.9)).has("move") and w.selected == 0, "vuelto al centro, otro empujón a la izquierda: otro paso")
	w.input(stick(JOY_AXIS_LEFT_X, 0.0))
	check(w.input(stick(JOY_AXIS_LEFT_Y, 0.9)).has("move") and w.selected == 1 and w.input(stick(JOY_AXIS_RIGHT_X, 0.9)).is_empty(), "stick abajo: un paso; el otro stick no cuenta")
	# Accept and back, the same as on every menu.
	for a in [["E", key(KEY_E)], ["el punto", key(KEY_PERIOD)], ["Espacio", key(KEY_SPACE)], ["Enter", key(KEY_ENTER)], ["A del mando", pad(JOY_BUTTON_A)]]:
		w.selected = 1
		check(w.input(a[1]) == {"pick": "again"}, "aceptar con %s: lo elegido" % a[0])
	for bk in [["Esc", key(KEY_ESCAPE)], ["B del mando", pad(JOY_BUTTON_B)], ["Tab", key(KEY_TAB)], ["Start", pad(JOY_BUTTON_START)]]:
		w.selected = 0
		check(w.input(bk[1]) == {"pick": "exit"}, "atrás con %s: salir" % bk[0])
	var held := key(KEY_E)
	held.echo = true
	check(w.input(held).is_empty() and w.input(key(KEY_Q)).is_empty(), "una tecla retenida (eco) o cualquier otra, nada")
	w.input(pad(JOY_BUTTON_DPAD_LEFT))
	check(w.pad, "el último dispositivo tocado era el mando (para la línea de ayuda)")
	w.input(key(KEY_RIGHT))
	check(not w.pad, "... y luego el teclado")
	var closed := TrialMenu.new()
	check(closed.input(key(KEY_E)).is_empty() and closed.current() == "" and not closed.is_open(), "cerrado, no responde")
	w.select("exit")
	check(w.current() == "exit" and not w.select("exit") and not w.select("nada"), "el ratón selecciona lo que pisa (y no dos veces lo mismo)")


# --- La vista del panel --------------------------------------------------------------------------

func _view() -> void:
	var v := TrialView.new()
	root.add_child(v)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 12, 8), Vector3.ZERO)
	v.setup(cam)
	var f := DojoField.from_map(MapFile.blank(20, 20), Rect2i(1, 1, 18, 18), Callable(), [])
	var t := DojoTrials.make("atrapa", 1, 3, f, Vector2i(5, 5), 0)
	t.start()
	t._win()
	t.step(DT, bl([]))
	v.show_view(t.view())
	await process_frame
	check(v.panel_open() and v.choices() == ["next", "again", "exit"] and v.menu.current() == "next", "vista: el panel se abre con SEGUIR, OTRA VEZ y SALIR, y SEGUIR elegida")
	var lit := v._buttons.keys().filter(func(id): return (v._buttons[id] as Button).get_theme_stylebox("normal").border_color == Hud.GLOW)
	check(lit == ["next"], "... y solo ella con el brillo cálido del menú (%s)" % [lit])
	check(v._help.text == Text.t("HIDEOUT_TRIAL_HELP_KEYS") and v._help.text.contains("ELEGIR") and v._help.text.contains("ACEPTAR") and v._help.text.contains("SALIR"), "la línea de ayuda de teclas: %s" % v._help.text)
	v.menu.input(pad(JOY_BUTTON_DPAD_RIGHT))
	v.refresh()
	check(v.menu.current() == "again" and v._help.text == Text.t("HIDEOUT_TRIAL_HELP_PAD") and v._help.text.contains("A ACEPTAR") and v._help.text.contains("B SALIR"), "con el mando, la ayuda dice A y B y la elección se mueve")
	lit = v._buttons.keys().filter(func(id): return (v._buttons[id] as Button).get_theme_stylebox("normal").border_color == Hud.GLOW)
	check(lit == ["again"], "... y el brillo la sigue")
	# The mouse: over selects, a click picks.
	var moved := [0]
	var picked := []
	v.moved.connect(func() -> void: moved[0] += 1)
	v.picked.connect(func(id: String) -> void: picked.append(id))
	(v._buttons["exit"] as Button).mouse_entered.emit()
	check(v.menu.current() == "exit" and moved[0] == 1, "ratón encima de SALIR: la elige (y avisa para el sonido)")
	(v._buttons["exit"] as Button).mouse_entered.emit()
	check(moved[0] == 1, "... una vez")
	(v._buttons["next"] as Button).pressed.emit()
	check(picked == ["next"], "un clic en un botón lo elige, aunque no sea el seleccionado")
	# A new result: a new panel, its own default.
	var t2 := DojoTrials.make("atrapa", 1, 3, f, Vector2i(5, 5), 1)
	t2.start()
	t2._lose("time")
	t2.step(DT, bl([]))
	v.show_view(t2.view())
	check(v.choices() == ["again", "exit"] and v.menu.current() == "again" and v.menu.age == 0.0, "otro resultado: panel nuevo, OTRA VEZ elegida y sordo otra vez")
	t2.abort()
	v.show_view(t2.view())
	check(not v.panel_open() and not v.menu.is_open(), "parada la prueba, el panel se va")
	v.queue_free()
	cam.queue_free()


# --- Cada prueba en la casa ----------------------------------------------------------------------

func _house() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(25, 1)
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.tour_hurry = true
	m.mode = Practice.MODE
	m.players = 1
	var seats: Array[String] = ["any"]
	m.seats = seats
	m._new_round(1)
	m._start_playing()
	await frames()
	var h: HouseRun = m.house
	var p: Thief = m.thieves[0]
	# One trial at a time: with one on, nothing else in the house answers.
	var other := Practice.stand_of("wires", 1)
	for id in DojoTrials.ids():
		var row := DojoTrials.info(id)
		for tier in 3:
			h.trial_end()
			h.trial_lock = 0.0
			p.game = null
			p.posing = false
			p.hiding = false
			p.hideout = null
			p.x = Practice.stand_of(id, tier).x
			p.y = Practice.stand_of(id, tier).y
			p.moving = false
			p.speed = 0.0
			var act: Dictionary = m._action_for(p)
			if Practice.VIAS[row.via].action:
				check(act == {"do": "trial", "id": id, "tier": tier}, "%s %d: junto a su objeto, la acción es empezarla" % [id, tier])
				check(m._prompt_rows(0)[0].verb == DojoTrials.start_label(id, tier), "%s %d: y el aviso dice «%s»" % [id, tier, DojoTrials.start_label(id, tier)])
			h.trial_start(id, tier, 0)
			var trial: DojoTrial = h.trial
			check(trial != null and trial.id == id and trial.tier == tier and trial.state == "ready" and h.trial_active() and trial.starter == 0, "%s %d: en marcha, a su dificultad" % [id, tier])
			if tier != 1:
				continue
			# HUD: the same for all. Nothing else answers.
			p.x = other.x
			p.y = other.y
			check(m._action_for(p).is_empty() and (m._prompt_rows(0).is_empty() or row.via in ["plinth", "armour"]), "%s: con ella en marcha, ni otro objeto responde ni hay aviso de acción" % id)
			run(2)
			check(h.trial_view.visible and String(h.trial_view._view.title).begins_with(Text.t(row.name)), "%s: la vista enseña su título común" % id)
			p.x = Practice.stand_of(id, tier).x
			p.y = Practice.stand_of(id, tier).y
			# Ready, then playing (the test's minigame in the hands of the thief).
			run(130)
			check(h.trial != null and (h.trial.state == "playing" or (row.via == "plinth" and h.trial.state == "lost")), "%s: pasado «¿LISTOS?», en juego (%s)" % [id, h.trial.state if h.trial else "fuera"])
			if row.kind == "bench":
				check(p.game != null and p.game.what == "bench" and p.game.kind == row.minigame and p.game.blocked == "", "%s: el minijuego de un robo en las manos, ya libre" % id)
			# Lose it, to the panel: OTRA VEZ is the one.
			h.trial._lose("time")
			run(3)
			check(h.trial.state == "lost" and h.panel_open() and h.trial_view.panel_open() and h.trial_view.menu.current() == "again" and (row.kind != "bench" or p.game == null), "%s: fallada, panel con OTRA VEZ elegida (y el minijuego de una prueba del banco, cerrado)" % id)
			var before_time := DojoTrials.best(id, 1, 1)
			check(row.kind == "game" or before_time == 0.0, "%s: fallar no guarda marca de tiempo" % id)
			# The press that ended it does not pick; a second later, it does.
			m._unhandled_input(key(KEY_E))
			check(h.trial.state == "lost", "%s: la pulsación que acaba la prueba no acepta" % id)
			run(30)
			var frozen := p.x
			m._unhandled_input(key(KEY_RIGHT))
			check(h.trial_view.menu.current() == "exit", "%s: derecha mueve la elección" % id)
			m._unhandled_input(key(KEY_LEFT))
			m._unhandled_input(key(KEY_E))
			check(h.trial != null and h.trial.state == "ready" and h.trial.tier == 1, "%s: E en OTRA VEZ: otra vez a su dificultad" % id)
			m._unhandled_input(key(KEY_E))
			check(h.trial.state == "ready", "%s: y aceptar no se cuenta dos veces" % id)
			# Win it: SEGUIR is the one, to the next difficulty.
			run(130)
			if row.kind == "bench":
				p.game.done = true
			else:
				h.trial._win()
			run(3)
			check(h.trial.state == "won" and h.trial_view.menu.options == ["next", "again", "exit"] and h.trial_view.menu.current() == "next", "%s: superada, panel con SEGUIR elegida" % id)
			var best := DojoTrials.best(id, 1, 1)
			check(best > 0.0 and DojoTrials.won(id, 1, 1), "%s: y guarda su mejor marca de esa dificultad (%.2f)" % [id, best])
			check(h.trial_view._help != null and h.trial_view._panel != null, "%s: con su ayuda de teclas" % id)
			run(30)
			m._unhandled_input(pad(JOY_BUTTON_A))
			check(h.trial != null and h.trial.tier == 2 and h.trial.state == "ready" and h.trial.start_tile == row.starts[1], "%s: A del mando en SEGUIR: la siguiente dificultad, desde el mismo sitio" % id)
			# Leave with Tab, and everything is back.
			m._unhandled_input(key(KEY_TAB))
			check(h.trial == null and not h.trial_active() and (p.game == null or row.via == "plinth"), "%s: Tab deja la prueba, sin nada colgado" % id)
			# And the panel's SALIR with the mouse.
			h.trial_lock = 0.0
			h.trial_start(id, 1, 0)
			run(130)
			h.trial._lose("time")
			run(3)
			h.trial_view._buttons["exit"].pressed.emit()
			check(h.trial == null, "%s: el clic en SALIR sale" % id)
			frozen = p.x
	# Frozen band: while the panel is up nobody walks.
	h.trial_end()
	h.trial_lock = 0.0
	p.x = Practice.stand_of("lockpick", 0).x
	p.y = Practice.stand_of("lockpick", 0).y
	h.trial_start("lockpick", 0, 0)
	run(130)
	h.trial._lose("time")
	run(3)
	var x0 := p.x
	var y0 := p.y
	Input.action_press("ui_right")
	run(30)
	Input.action_release("ui_right")
	check(absf(p.x - x0) < 0.05 and absf(p.y - y0) < 0.05, "con el panel abierto la banda se queda quieta")
	# Pause and leaving the house end the trial too.
	h.trial_end()
	h.trial_lock = 0.0
	h.trial_start("bolos", 0, 0)
	m._pause()
	check(h.trial == null, "la pausa deja la prueba")
	m._start_playing()
	print("      última tanda de mandos y ratón hecha")
