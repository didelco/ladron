extends SceneTree
## Hiding played through the game loop (main.gd's _tick), a frame at a time,
## with real key and pad events: in with the action key and a moment's
## wriggling, still inside until a direction is pressed afresh, the sneeze
## after a while, and out again — alone and as two, on the keyboard and on
## a pad.
##   godot --headless --script tests/test_esconderse.gd

const DT := 1.0 / 60.0

var failures: Array[String] = []
var m


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


func key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func button(device: int, b: int, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = device
	e.button_index = b
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func axis(device: int, a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = device
	e.axis = a
	e.axis_value = v
	Input.parse_input_event(e)
	Input.flush_buffered_events()


## Frames of the game, the keys as they are.
func run(frames: int) -> void:
	for f in frames:
		# Frame after frame, as the physics would (no "resumed" gap).
		m.hands.pad_frame = Engine.get_physics_frames() - 1
		m.loop.tick(DT)


## A night with the minigames on (or off), the guards sent far off, and
## thief i next to a hideout of its own: returns the hideout.
func night(n: int, gang: int, seats: Array[String]) -> Hideouts.Spot:
	m.mode = "story"
	m.players = gang
	m.seats = seats
	m._new_round(n)
	m._start_playing()
	for t in m.thieves:
		t.roll_key = false
	m.guards.clear()
	return null


## Put thief p on the free floor beside a hideout nobody is by, where the
## action key would get it in: returns it (and where it stands in `from`).
var from := Vector2i.ZERO
func beside_hideout(p: Thief, skip: Array = []) -> Hideouts.Spot:
	if p.hiding:
		Hideouts.leave(p, Vector2i(int(p.x), int(p.y)), 0.0)
	p.game = null
	p.dizzy = 0.0
	for s in Hideouts.all():
		if skip.any(func(o): return o.same(s)):
			continue
		for t in s.tiles:
			for d in Museum.DIRS:
				var n: Vector2i = t + d
				if n in s.tiles or Museum.tile_at(n.x + 0.5, n.y + 0.5) != Tiles.FLOOR:
					continue
				p.x = n.x + 0.5
				p.y = n.y + 0.5
				var act: Dictionary = m._action_for(p)
				if act.get("do", "") == "hide" and act.at.same(s):
					from = d
					return s
	return null


## The key (keyboard, as P1 or P2) for a way out.
func out_key(d: Vector2i, p2 := false) -> Key:
	if p2:
		return {Vector2i(1, 0): KEY_RIGHT, Vector2i(-1, 0): KEY_LEFT, Vector2i(0, 1): KEY_DOWN, Vector2i(0, -1): KEY_UP}[d]
	return {Vector2i(1, 0): KEY_D, Vector2i(-1, 0): KEY_A, Vector2i(0, 1): KEY_S, Vector2i(0, -1): KEY_W}[d]


## Wriggle in with these two keys, a press every `every` seconds, till in
## (or a time out): the seconds it took, or -1.
func wriggle(p: Thief, left: Callable, right: Callable, every := 0.42, hold_last := true) -> float:
	var t := 0.0
	var side := 0
	while t < 10.0:
		var k: Callable = left if side == 0 else right
		k.call(true)
		run(6)
		if OS.has_environment("DEBUG_WRIGGLE"):
			print("    t=%.2f game=%s step=%s hiding=%s at=(%.2f,%.2f)" % [t, p.game.kind if p.game else "-", p.game.step if p.game else -1, p.hiding, p.x, p.y])
		t += 6 * DT
		if p.hiding:
			if not hold_last:
				k.call(false)
			return t
		k.call(false)
		var rest := int(every / DT) - 6
		run(rest)
		t += rest * DT
		if p.hiding:
			return t
		side = 1 - side
	return -1.0


## Get in from where it stands with this action key and these two keys to
## wriggle: true once in.
func get_in(p: Thief, action: Callable, left: Callable, right: Callable) -> bool:
	action.call(true)
	run(2)
	action.call(false)
	var took := wriggle(p, left, right)
	left.call(false)
	right.call(false)
	run(3)
	return took > 0.0 and p.hiding


## Frames till the sneeze is on.
func till_sneeze(p: Thief) -> void:
	for f in int((SneezeGame.CALM_S + 1.0) / DT):
		if p.game is SneezeGame:
			return
		run(1)


func _init() -> void:
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	# The cover waits for any key: out of the way of the keys pressed here.
	for c in m.get_children():
		if c is TitleScreen:
			c.free()
	var e := func(d): key(KEY_E, d)
	var a := func(d): key(KEY_A, d)
	var dk := func(d): key(KEY_D, d)

	# --- On the keyboard, alone, with the minigames on ---------------------------
	var night_on := Story.LOCKPICK_NIGHT
	night(night_on, 1, ["kb_left"] as Array[String])
	var p: Thief = m.thieves[0]
	var spot := beside_hideout(p)
	check(spot != null, "robo %d: un escondite (%s) con suelo libre al lado" % [night_on, spot.kind if spot else "-"])
	var way := from
	var at := Vector2(p.x, p.y)
	key(KEY_E, true)
	run(1)
	check(p.game is SqueezeGame and not p.hiding, "E junto al escondite: a colarse")
	check(m._prompt_rows(0).is_empty(), "mientras se cuela, sin bocadillo encima")
	run(10)
	key(KEY_E, false)
	run(2)
	check(p.game is SqueezeGame and p.game.step == 0, "la E que te mete no cuenta como contoneo")
	var took := wriggle(p, a, dk)
	check(took > 0.0 and took <= 5.0, "contoneándose con A y D, dentro en %.1f s" % took)
	check(p.hiding, "... y sigue dentro con la última tecla aún pulsada")
	run(30)
	check(p.hiding, "... también medio segundo después")
	key(KEY_A, false)
	key(KEY_D, false)
	run(5)
	check(p.hiding and p.game == null, "suelta las teclas: dentro, quieto, sin minijuego aún")
	check(m._prompt_rows(0).size() == 1 and m._prompt_rows(0)[0].input == "move", "dentro, el bocadillo dice cómo salir")
	# The action key does nothing in there (no switch, no arcade, no push).
	key(KEY_E, true)
	run(2)
	key(KEY_E, false)
	check(p.hiding and p.game == null, "E dentro, antes del estornudo: nada")
	till_sneeze(p)
	check(p.hiding and p.game is SneezeGame and p.hidden_for >= SneezeGame.CALM_S - 0.1, "a los %.0f s dentro, el polvo: estornudo" % SneezeGame.CALM_S)
	# Hold it in: the action as each tickle crosses the bar.
	var held := true
	for f in int(8.0 / DT):
		var g := p.game as SneezeGame
		if g == null:
			held = false
			break
		var on_bar: bool = not g.tickles.is_empty() and absf(g.tickles[0] - SneezeGame.BAR_X) <= g.bar() * 0.4
		key(KEY_E, on_bar and not Input.is_physical_key_pressed(KEY_E))
		run(1)
	key(KEY_E, false)
	check(held and p.hiding, "llevando el ritmo con E, 8 s sin estornudar")
	check(Input.is_physical_key_pressed(KEY_SPACE) == false and (func(): key(KEY_SPACE, true); run(2); key(KEY_SPACE, false); run(1); return p.hiding and p.game is SneezeGame).call(),
		"Espacio no suelta el estornudo")
	# Out with a direction: off the sneeze, on the floor, walking.
	key(out_key(way), true)
	run(1)
	check(not p.hiding and p.game == null, "una dirección: fuera del escondite, sin estornudo")
	var was := Vector2(p.x, p.y)
	run(20)
	key(out_key(way), false)
	check(Vector2(p.x, p.y).distance_to(was) > 0.2, "... y andando")
	run(5)
	# Let it sneeze: nothing pressed.
	p.x = at.x
	p.y = at.y
	check(get_in(p, e, a, dk), "otra vez dentro")
	till_sneeze(p)
	run(int(4.0 / DT))
	check(not p.hiding and p.game == null, "sin pulsar nada: ¡achís!, fuera y sin minijuego")
	check(p.hidden_for == 0.0, "y la cuenta del polvo, a cero")
	run(int(2.0 / DT))
	key(out_key(way), true)
	was = Vector2(p.x, p.y)
	run(20)
	key(out_key(way), false)
	check(Vector2(p.x, p.y).distance_to(was) > 0.2, "después del estornudo se puede andar")
	# Too many presses out of time: the last one only sneezes.
	p.x = at.x
	p.y = at.y
	run(5)
	check(get_in(p, e, a, dk), "y dentro de nuevo")
	till_sneeze(p)
	var pushes := [0]
	var spam := 0
	while p.game is SneezeGame and spam < 400:
		var g := p.game as SneezeGame
		var off: bool = g.tickles.is_empty() or absf(g.tickles[0] - SneezeGame.BAR_X) > g.bar() * 1.5
		key(KEY_E, off and spam % 20 < 3)
		run(1)
		spam += 1
	key(KEY_E, false)
	check(not p.hiding and p.game == null, "tres fallos: ¡achís!")
	check(p.game == null and not (m._action_for(p).get("do", "") == "hide" and p.hiding), "y la E del último fallo no hace nada más")
	run(int(2.0 / DT))
	# B while wriggling lets go, and does not roll.
	p.x = at.x
	p.y = at.y
	run(30)
	key(KEY_E, true)
	run(2)
	key(KEY_E, false)
	run(2)
	key(KEY_SPACE, true)
	run(1)
	check(p.game == null and not p.hiding, "Espacio mientras se cuela: lo deja")
	check(not p.rolling, "... sin echarse a rodar")
	key(KEY_SPACE, false)
	run(40)

	# --- A pad, stick and cross --------------------------------------------------
	night(night_on, 1, ["pad:0"] as Array[String])
	p = m.thieves[0]
	spot = beside_hideout(p)
	way = from
	var pa := func(d): button(0, JOY_BUTTON_A, d)
	# The stick, never quite level: a little up with the left, a little down
	# with the right.
	var sl := func(d): axis(0, JOY_AXIS_LEFT_X, -0.9 if d else 0.0); axis(0, JOY_AXIS_LEFT_Y, -0.35 if d else 0.0)
	var sr := func(d): axis(0, JOY_AXIS_LEFT_X, 0.9 if d else 0.0); axis(0, JOY_AXIS_LEFT_Y, 0.35 if d else 0.0)
	button(0, JOY_BUTTON_A, true)
	run(2)
	button(0, JOY_BUTTON_A, false)
	check(p.game is SqueezeGame, "A junto al escondite: a colarse")
	took = wriggle(p, sl, sr)
	check(took > 0.0 and took <= 5.0, "con el stick algo torcido, dentro en %.1f s" % took)
	check(p.hiding, "... y sigue dentro con el stick aún echado")
	sl.call(false)
	run(5)
	var dz: float = m.deadzone / 100.0
	axis(0, JOY_AXIS_LEFT_X if way.x != 0 else JOY_AXIS_LEFT_Y, signf(way.x + way.y) * (dz + 0.1))
	run(3)
	check(not p.hiding, "stick a medias, pasada la zona muerta: fuera")
	axis(0, JOY_AXIS_LEFT_X, 0.0)
	axis(0, JOY_AXIS_LEFT_Y, 0.0)
	run(30)
	spot = beside_hideout(p)
	var cl := func(d): button(0, JOY_BUTTON_DPAD_LEFT, d)
	var cr := func(d): button(0, JOY_BUTTON_DPAD_RIGHT, d)
	check(get_in(p, pa, cl, cr), "con la cruceta, dentro")
	run(5)

	# --- Two thieves on one keyboard ---------------------------------------------
	var s1: Hideouts.Spot = null
	var s2: Hideouts.Spot = null
	var p1: Thief
	var p2: Thief
	for n in range(night_on, Story.count() + 1):
		night(n, 2, ["kb_left", "kb_right"] as Array[String])
		p1 = m.thieves[0]
		p2 = m.thieves[1]
		s1 = beside_hideout(p1)
		s2 = beside_hideout(p2, [s1] if s1 else [])
		way = from
		if s1 and s2:
			break
	check(s1 != null and s2 != null, "dos escondites, uno para cada uno")
	var p1_at := Vector2(p1.x, p1.y)
	key(KEY_PERIOD, true)
	run(2)
	key(KEY_PERIOD, false)
	check(p2.game is SqueezeGame and p1.game == null, "J2 con el punto: J2 a colarse, J1 nada")
	took = wriggle(p2, func(d): key(KEY_LEFT, d), func(d): key(KEY_RIGHT, d))
	check(took > 0.0 and p2.hiding and not p1.hiding, "J2 con las flechas, dentro en %.1f s" % took)
	check(Vector2(p1.x, p1.y) == p1_at, "y J1 no se ha movido")
	key(KEY_LEFT, false)
	key(KEY_RIGHT, false)
	till_sneeze(p2)
	check(p2.game is SneezeGame and p1.game == null, "el estornudo, solo para J2")
	key(KEY_E, true)
	run(1)
	key(KEY_E, false)
	check(p2.game is SneezeGame and (p2.game as SneezeGame).misses == 0, "la E de J1 no cuenta en el estornudo de J2")
	check(p1.game is SqueezeGame, "... y a J1 lo pone a colarse en el suyo")
	run(3)
	key(KEY_SPACE, true)
	run(1)
	key(KEY_SPACE, false)
	key(out_key(way, true), true)
	run(1)
	check(not p2.hiding and p2.game == null, "J2 sale con las flechas")
	key(out_key(way, true), false)
	run(5)
	# Both at the same one: the second cannot start while the first wriggles.
	p1.x = p1_at.x
	p1.y = p1_at.y
	p2.x = p1_at.x
	p2.y = p1_at.y
	run(2)
	key(KEY_E, true)
	run(2)
	key(KEY_E, false)
	check(p1.game is SqueezeGame and m._action_for(p2).get("do", "") != "hide", "si J1 se está colando, J2 ya no puede en ese")

	# --- Without the minigames: straight in ---------------------------------------
	for n in range(1, Story.LOCKPICK_NIGHT):
		night(n, 1, ["kb_left"] as Array[String])
		p = m.thieves[0]
		spot = beside_hideout(p)
		if spot == null:
			continue
		key(KEY_D, true)
		key(KEY_E, true)
		run(1)
		key(KEY_E, false)
		check(p.hiding and p.game == null, "robo %d: E y dentro al momento, sin contoneo" % n)
		run(10)
		check(p.hiding, "robo %d: con la dirección aún pulsada de venir, sigue dentro" % n)
		key(KEY_D, false)
		run(int((SneezeGame.CALM_S + 3.0) / DT))
		check(p.hiding and p.game == null, "robo %d: sin estornudo" % n)
		break

	# --- The first museum: no minigame of any kind -------------------------------
	for n in range(1, Story.count() + 1):
		check(Story.tuning(n).lockpick == (n >= Story.LOCKPICK_NIGHT), "robo %d: %s" % [n, "con minijuegos" if n >= Story.LOCKPICK_NIGHT else "sin minijuegos"])
	check(Story.LOCKPICK_NIGHT == Story.nights_in(1)[0], "los minijuegos empiezan con el segundo museo (robo %d)" % Story.LOCKPICK_NIGHT)
	var levels: Array = []
	for n in range(Story.LOCKPICK_NIGHT, Story.count() + 1):
		levels.append(Story.tuning(n).game_level)
	var rooms_up := true
	var last := 0
	for n in range(Story.LOCKPICK_NIGHT, Story.count() + 1):
		var lv: int = Story.tuning(n).game_level
		if not Story.is_boss(n):
			rooms_up = rooms_up and lv >= last
			last = lv
	check(levels[0] == 0 and levels[-1] == 2 and rooms_up, "nivel de los minijuegos: fácil al empezar, difícil al final, nunca a menos (%s)" % str(levels))
	for n in range(1, Story.LOCKPICK_NIGHT):
		night(n, 1, ["kb_left"] as Array[String])
		p = m.thieves[0]
		p.game = null
		# At the case: E does nothing; standing still opens it, as ever.
		var stand := Vector2i(-1, -1)
		for t in Heist._stand_tiles(Heist.at):
			if Museum.tile_at(t.x + 0.5, t.y + 0.5) == Tiles.FLOOR:
				stand = t
				break
		p.x = stand.x + 0.5
		p.y = stand.y + 0.5
		key(KEY_E, true)
		run(2)
		key(KEY_E, false)
		check(p.game == null, "robo %d: E en la vitrina no abre minijuego" % n)
		run(int((float(Heist.loot.seconds) + 1.0) / DT))
		check(Heist.taken, "robo %d: quieto, la vitrina se abre (%.1f s)" % [n, Heist.loot.seconds])
		# A pedestal: up at once, no balance.
		if not Plinths.list.is_empty():
			var t: Vector2i = Plinths.list[0]
			for d in Museum.DIRS:
				var f: Vector2i = t + d
				if Museum.tile_at(f.x + 0.5, f.y + 0.5) == Tiles.FLOOR:
					p.x = f.x + 0.5
					p.y = f.y + 0.5
					break
			if m._action_for(p).get("do", "") == "plinth":
				key(KEY_E, true)
				run(2)
				key(KEY_E, false)
				check(p.posing and p.game == null, "robo %d: al pedestal sin equilibrio" % n)
				key(KEY_S, true)
				run(2)
				key(KEY_S, false)
				key(KEY_W, true)
				run(2)
				key(KEY_W, false)
				run(5)
		# An arcade machine stood by hand: no pong.
		p.posing = false
		var front := Vector2i(int(p.x), int(p.y))
		Arcades.list.clear()
		for d in Museum.DIRS:
			var c: Vector2i = front + d
			if Museum.is_cover(c.x + 0.5, c.y + 0.5) and MuseumView.front_of(c) == -d:
				Arcades.list.append(c)
				break
		if not Arcades.list.is_empty():
			Sim.custom.lockpick = true
			var there := Arcades.within_reach(p, m.thieves).x >= 0
			Sim.custom.lockpick = false
			if there:
				check(Arcades.within_reach(p, m.thieves).x < 0 and m._action_for(p).get("do", "") != "arcade", "robo %d: la recreativa no juega" % n)
		Arcades.list.clear()

	print("OK: esconderse, jugando" if failures.is_empty() else "FALLOS: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
