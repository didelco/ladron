extends SceneTree
## Minigames: the pick and the wires cannot be failed, only done slowly; a
## steady expert is quick, a fumbler slow, and shaking hands slower still.
## Then the job: the case opens by the pick, and a gang cuts the panel first.
##   godot --headless --script tests/test_minigame.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")
const DT := 1.0 / 60


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


## Seconds to pick a lock of `pins` pins. The expert sees the needle coming
## and presses as it crosses the middle of the green; the novice aims but
## presses `late` seconds after the needle gets there; the fumbler
## (late < 0) presses every `every` seconds whatever the tip is doing.
func pick(pins: int, tremble: float, expert: bool, every := 0.55, seed_ := 7, late := -1.0) -> float:
	var g := Minigame.make("lockpick", "case", pins, {}, seed_) as LockpickGame
	g.tremble = tremble
	var last := 0.0
	var held := false
	var entered := -1.0
	while not g.done and g.t < 60.0:
		var press := false
		if expert:
			press = g.off() <= g.band() * 0.6 and g.lock <= 0.0
		elif late >= 0.0:
			var near := g.off() <= g.band() * 0.6
			if near and entered < 0.0 and g.lock <= 0.0:
				entered = g.t
			press = entered >= 0.0 and g.t - entered >= late
			if press:
				entered = -1.0
		else:
			press = g.t - last >= every
			if press:
				last = g.t
		# A press is a key going down: let go in between.
		var down := press and not held
		held = press
		g.tick({"action": down}, DT)
	return g.t


## Seconds to cut the wires, a reaction time after each way shows; the
## fumbler pulls the wrong way first on every other wire.
func cut(tremble: float, reaction: float, fumble: bool, level := 1) -> float:
	var g := Minigame.make("wires", "panel", 0, {}, 3, level) as WiresGame
	g.tremble = tremble
	var shown := -1.0
	var wrong_done := {}
	var held := ""
	while not g.done and g.t < 60.0:
		var way := g.way()
		var input := {}
		if way < 0:
			shown = -1.0
		elif shown < 0:
			shown = g.t
		elif g.t - shown >= reaction:
			var d: String = Minigame.DIRS[way]
			if fumble and g.step % 2 == 0 and not wrong_done.has(g.step):
				d = Minigame.DIRS[(way + 1) % 4]
				wrong_done[g.step] = true
			if held != d:
				input[d] = true
			shown = -1.0
		held = input.keys()[0] if not input.is_empty() else ""
		g.tick(input, DT)
	return g.t


## Seconds until the cup has been kept in the ring long enough, up to
## `limit`. The player pushes it back to the middle, seeing where it is
## `late` seconds ago (late < 0: hands off).
func steady(late: float, tremble: float, seed_: int, limit := 30.0, level := 1) -> float:
	var g := Minigame.make("steady", "case", 6, {}, seed_, level) as SteadyGame
	g.tremble = tremble
	var seen: Array[Vector2] = []
	while not g.done and g.t < limit:
		seen.append(g.cup)
		var input := {}
		if late >= 0.0:
			var at: Vector2 = seen[maxi(0, seen.size() - 1 - int(late * 60))]
			if at.x > 0.12: input.left = true
			if at.x < -0.12: input.right = true
			if at.y > 0.12: input.up = true
			if at.y < -0.12: input.down = true
		g.tick(input, DT)
	return g.t


## Seconds on one foot before falling, up to `limit`: the player taps
## against the sway seen `late` seconds ago — short taps, a few frames down
## and as many up (late < 0: hands off); `press` frames down each time
## (a long press instead of a tap).
func balance(late: float, pressure: float, seed_: int, limit: float, level := 1, press := 3) -> float:
	var g := Minigame.make("balance", "plinth", 1, {}, seed_, level) as BalanceGame
	g.pressure = pressure
	var seen: Array[float] = []
	var t := 0.0
	var tap := 0
	var tap_dir := ""
	while t < limit:
		seen.append(g.lean + g.lean_v * 0.25)
		var input := {}
		if late >= 0.0:
			var at: float = seen[maxi(0, seen.size() - 1 - int(late * 60))]
			var want := "left" if at > 0.06 else ("right" if at < -0.06 else "")
			# Down for `press` frames, up for 3, then again if still needed.
			if tap <= 0 and want != "":
				tap = press + 3
				tap_dir = want
			if tap > 3:
				input[tap_dir] = true
			tap -= 1
		if g.tick(input, DT) == "fail":
			return t
		t += DT
	return t


## A press of one key on a squeeze (down one frame, up the next).
func tap(g: SqueezeGame, k: String) -> String:
	var out := g.tick({k: true}, DT)
	g.tick({}, DT)
	return out


## Make a hideout's colour code the straight way: for every slot out of
## place, walk the cursor to it, pick, walk to the ball that goes there, pick.
## The swaps it took (-1 if it never came out).
func solve(g: SqueezeGame) -> int:
	var swaps := 0
	while not g.done and swaps < 16:
		var slot := -1
		for i in g.size():
			if g.code.balls[i] != g.code.target[i]:
				slot = i
				break
		if slot < 0:
			return -1
		var other := g.code.balls.find(g.code.target[slot])
		for to in [slot, other]:
			while g.cursor != to:
				tap(g, "right" if to > g.cursor else "left")
			tap(g, "action")
		swaps += 1
	return swaps if g.done else -1


func _init() -> void:
	print("Ganzúa")
	var fast := pick(4, 0.0, true)
	var shaky := pick(4, 1.0, true)
	var novice := 0.0
	var fumbler := 0.0
	for s in 8:
		novice += pick(4, 0.0, false, 0.55, 200 + s, 0.16)
		fumbler = maxf(fumbler, pick(4, 0.0, false, 0.55, 200 + s))
	novice /= 8
	check(fast >= 1.0 and fast <= 3.0, "experto, 4 pernos: %.1f s (unos 2)" % fast)
	check(novice >= 4.0 and novice <= 12.0, "novato (reacciona tarde), 4 pernos: %.1f s de media (unos 8)" % novice)
	check(fumbler < 60.0, "pulsando a ciegas también se abre, tarde o temprano: %.1f s el peor" % fumbler)
	var shaky_slow := 0.0
	var steady_slow := 0.0
	for s in 8:
		shaky_slow += pick(4, 1.0, false, 0.55, 100 + s)
		steady_slow += pick(4, 0.0, false, 0.55, 100 + s)
	check(shaky_slow > steady_slow, "con las manos temblando cuesta más: %.1f s frente a %.1f s de media" % [shaky_slow / 8, steady_slow / 8])
	check(shaky < 6.0, "experto temblando: %.1f s, más despacio pero la abre" % shaky)
	check(Minigame.pins_for(1.0) == 1 and Minigame.pins_for(3.5) == 1 and Minigame.pins_for(4.0) == 2 \
		and Minigame.pins_for(5.0) == 3 and Minigame.pins_for(6.0) == 4 and Minigame.pins_for(9.0) == 4,
		"pernos según la cerradura: 1 a 4")

	var g := Minigame.make("lockpick", "case", 3, {"action": true, "right": true}) as LockpickGame
	check(g.tick({"action": true, "right": true}, DT) == "" and g.step == 0, "lo que ya estaba pulsado al empezar no cuenta")
	check(g.tick({"action": true, "right": false}, DT) == "", "soltar no hace nada")
	check(g.tick({"right": true}, DT) == "", "una dirección con la ganzúa no la suelta: solo B (rodar)")
	check(g.tick({"cancel": true}, DT) == "quit", "B (rodar) suelta la ganzúa")
	g = Minigame.make("lockpick", "case", 3, {}) as LockpickGame
	g.tick({"action": true}, DT)
	check(g.events.has("slip") and g.lock > 0.0, "fallar el punto: la ganzúa resbala un momento")
	g = Minigame.make("lockpick", "case", 3, {}) as LockpickGame
	g.blocked = "panel"
	g.tick({}, 1.0)
	check(g.t == 0.0, "bloqueada (falta el cuadro): no avanza")

	print("Cables")
	var counts: Array[int] = []
	for level in 3:
		counts.append(Minigame.make("wires", "panel", 0, {}, 11, level).steps)
	check(counts == [3, 4, 6], "cables por nivel: %d, %d y %d" % counts)
	check(cut(0.0, 0.3, false, 2) > cut(0.0, 0.3, false, 0), "más cables, más tiempo")
	var quick := cut(0.0, 0.3, false)
	var clumsy := cut(0.0, 0.6, true)
	var trembling := cut(1.0, 0.3, false)
	check(quick >= 1.0 and quick <= 3.0, "experto, 4 cables: %.1f s" % quick)
	check(clumsy > quick * 2.0, "torpe, tirando mal: %.1f s, pero los corta" % clumsy)
	check(trembling > quick, "con las manos temblando: %.1f s" % trembling)
	var w := Minigame.make("wires", "panel", 5, {})
	check(w.tick({"cancel": true}, DT) == "quit", "B (rodar) suelta los cables")
	check(Minigame.tremble_for(0) == 0.0 and Minigame.tremble_for(3) == 1.0, "tiemblan más cuanto más alerta")

	print("Ventosa")
	var calm := 0.0
	var clumsy_cup := 0.0
	var loose := 0.0
	for s in 8:
		calm += steady(0.12, 0.0, 300 + s)
		clumsy_cup += steady(0.35, 0.0, 300 + s)
		loose = maxf(loose, steady(-1.0, 0.0, 300 + s, 6.0))
	calm /= 8
	clumsy_cup /= 8
	check(calm >= 2.0 and calm <= 5.0, "experto: la mantiene dentro y corta el cristal en %.1f s (hacen falta 3)" % calm)
	check(clumsy_cup > calm, "reaccionando tarde tarda más: %.1f s" % clumsy_cup)
	check(loose >= 6.0, "sin tocar nada se sale y no acaba nunca")
	var cupg := Minigame.make("steady", "case", 6, {}, 9) as SteadyGame
	cupg.cup = Vector2(0.95, 0.0)
	cupg.held = 1.0
	cupg.tick({}, DT)
	check(cupg.held == 0.0 and cupg.step == 0, "fuera del aro: la cuenta vuelve a cero")

	print("Equilibrio")
	var up := 0.0
	var fell := 0.0
	var pressed_up := 0.0
	for s in 8:
		up += balance(0.1, 0.0, 400 + s, 60.0)
		pressed_up += balance(0.1, 1.0, 400 + s, 20.0)
		fell += balance(-1.0, 0.0, 400 + s, 20.0)
	check(up / 8 >= 59.0, "atento a izquierda y derecha aguanta %.1f s de media: con el tiempo se complica, pero muy despacio" % (up / 8))
	var tire := Minigame.make("balance", "plinth", 1, {}, 5, 1) as BalanceGame
	tire.t = 60.0
	check(tire.tired() > 1.3 and tire.tired() < 2.0, "al minuto cuesta %.2f veces lo del principio" % tire.tired())
	var lasts := 0.0
	for s in 4:
		lasts += balance(0.1, 0.0, 400 + s, 600.0)
	check(lasts / 4 < 600.0, "pero no para siempre: atento, sin guardias, cae a los %.0f s de media" % (lasts / 4))
	check(fell / 8 < 5.0, "sin tocar nada se cae en %.1f s de media" % (fell / 8))
	var held_down := 0.0
	for s in 8:
		held_down += balance(0.1, 0.0, 400 + s, 20.0, 1, 36)
	check(held_down / 8 < 10.0, "pulsaciones largas (0,6 s) empujan demasiado y se cae: %.1f s frente a %.1f s a toques" % [held_down / 8, up / 8])
	var push := Minigame.make("balance", "plinth", 1, {}, 5, 1) as BalanceGame
	push.lean = 0.0
	push.lean_v = 0.0
	var tt := 0.0
	while push.tick({"right": true}, DT) != "fail" and tt < 3.0:
		tt += DT
	check(tt < 1.2, "con la tecla pulsada, la fuerza crece y lo tira al otro lado en %.2f s" % tt)
	var slack := 0.0
	var slack_pressed := 0.0
	for s in 8:
		slack += balance(0.3, 0.0, 500 + s, 30.0)
		slack_pressed += balance(0.3, 1.0, 500 + s, 30.0)
	check(slack_pressed < slack * 0.6, "con un guardia encima cuesta mucho más: %.1f s frente a %.1f s" % [slack_pressed / 8, slack / 8])
	var by_near: Array[float] = []
	for near in [0.0, 0.3, 0.6, 1.0]:
		var sum := 0.0
		for s in 8:
			sum += balance(0.3, near, 500 + s, 30.0)
		by_near.append(sum / 8)
	check(by_near[0] >= by_near[1] and by_near[1] >= by_near[2] and by_near[2] >= by_near[3] and by_near[0] > by_near[3],
		"cuanto más cerca el guardia, antes se cae: %.1f s, %.1f s, %.1f s, %.1f s" % by_near)
	var far := Minigame.make("balance", "plinth", 1, {}, 5, 1) as BalanceGame
	var widest := 0.0
	while far.tick({}, DT) != "fail":
		widest = maxf(widest, absf(far.lean))
		if absf(far.lean) < 1.0:
			widest = 0.0
	check(widest > 1.0, "se inclina más allá de donde antes caía (%.2f) antes de caerse" % widest)
	var by_level: Array[float] = []
	for level in 3:
		var sum := 0.0
		for s in 8:
			sum += balance(0.3, 0.6, 600 + s, 60.0, level)
		by_level.append(sum / 8)
	check(by_level[0] > by_level[1] and by_level[1] > by_level[2], "equilibrio por niveles, con un guardia a media distancia: %.1f s fácil, %.1f s medio, %.1f s difícil" % by_level)
	var cup_level: Array[float] = []
	for level in 3:
		var sum := 0.0
		for s in 8:
			sum += steady(0.25, 0.0, 700 + s, 30.0, level)
		cup_level.append(sum / 8)
	check(cup_level[0] < cup_level[1] and cup_level[1] < cup_level[2], "ventosa por niveles: %.1f s fácil, %.1f s medio, %.1f s difícil" % cup_level)

	print("Colarse en un escondite: el código de colores")
	# The same puzzle in a heist and at the dojo's bench, by level: 3, 4 and 5 balls.
	var sizes := [[], [], []]
	for lv in 3:
		for what in ["hideout", "bench"]:
			var sg := Minigame.make("squeeze", what, 0, {}, 3 + lv, lv) as SqueezeGame
			sizes[lv].append(sg.size())
			check(sg.code != null and sg.steps == sg.size() and sg.code.target.size() == sg.size(), "%s nivel %d: un código de %d bolas, los pasos son las bolas" % [what, lv, sg.size()])
	check(sizes[0] == [3, 3] and sizes[1] == [4, 4] and sizes[2] == [5, 5], "fácil 3 bolas, medio 4, difícil 5, en el robo y en el banco igual: %s" % [sizes])
	# Never dealt made already, whatever the dice.
	var dealt_done := 0
	var far_enough := true
	for s in 300:
		var lv := s % 3
		var tight := (s / 3) % 2
		var sg := Minigame.make("squeeze", "hideout", tight, {}, 1000 + s, lv) as SqueezeGame
		if sg.code.solved() or sg.done:
			dealt_done += 1
		if sg.code.distance() < ColourCode.swaps_for(lv, tight):
			far_enough = false
	check(dealt_done == 0, "300 repartos: ninguno sale hecho de entrada (%d)" % dealt_done)
	check(far_enough, "... y todos a los cambios que pide el nivel por lo menos (apretado, uno más)")
	check(ColourCode.swaps_for(0, 0) == 1 and ColourCode.swaps_for(0, 1) == 2 and ColourCode.swaps_for(1, 0) == 2 and ColourCode.swaps_for(2, 1) == 4, "cambios mínimos: 1 fácil, 2 medio, 3 difícil; apretado, uno más (nunca más de bolas - 1)")
	# The E that opened it is not a pick; a swap changes the two balls of place.
	var sq := Minigame.make("squeeze", "hideout", 0, {"action": true}, 3, 1) as SqueezeGame
	sq.tick({"action": true}, DT)
	check(sq.picked() < 0 and sq.code.swaps == 0 and sq.events.is_empty(), "la E que abrió el juego no coge ninguna bola")
	sq.tick({}, DT)
	var before := sq.code.balls.duplicate()
	tap(sq, "action")
	check(sq.picked() == 0 and sq.events.is_empty() and sq.code.balls == before, "la acción coge la bola del cursor: nada cambia aún")
	tap(sq, "right")
	check(sq.cursor == 1 and sq.picked() == 0, "la derecha mueve el cursor, la bola cogida sigue cogida")
	sq.tick({"action": true}, DT)
	check(sq.picked() < 0 and sq.code.swaps == 1 and sq.events.has("pin"), "la acción sobre otra: las dos cambian de sitio")
	check(sq.code.balls[0] == before[1] and sq.code.balls[1] == before[0] and sq.code.balls[2] == before[2], "... la del cursor y la cogida, las demás quietas")
	check(sq.steps == 4 and sq.step == sq.code.matched() and sq.progress() == float(sq.step) / 4.0, "el avance: las bolas en su sitio")
	sq.tick({}, DT)
	tap(sq, "action")
	tap(sq, "action")
	check(sq.picked() < 0 and sq.code.swaps == 1, "cogerla y soltarla en el mismo sitio no cambia nada")
	# The cursor goes round.
	tap(sq, "left")
	tap(sq, "left")
	check(sq.cursor == 3, "a la izquierda del principio, la última")
	tap(sq, "right")
	check(sq.cursor == 0, "... y a la derecha del final, la primera")
	# Made: done, every ball in place.
	var took := solve(sq)
	check(sq.done and took >= 1 and sq.code.solved() and sq.progress() == 1.0 and sq.step == sq.steps, "ordenadas como el código: dentro (%d cambios)" % took)
	# At every level, the straight way makes it in as many swaps as it is dealt from.
	for lv in 3:
		var sg := Minigame.make("squeeze", "bench", 0, {}, 77 + lv, lv) as SqueezeGame
		var away := sg.code.distance()
		var made := solve(sg)
		check(made == away and sg.done, "nivel %d: hecho en %d cambios, los justos (%d bolas)" % [lv, made, sg.size()])
	# Watched is for the box only: the puzzle is the same.
	var seen := Minigame.make("squeeze", "hideout", 0, {}, 3, 1) as SqueezeGame
	seen.watched = true
	check(solve(seen) >= 1 and seen.done, "a la vista se juega igual: solo cuesta el tiempo")
	var hard := Minigame.make("squeeze", "hideout", 1, {}, 3, 2) as SqueezeGame
	check(hard.size() == 5 and hard.code.distance() >= 4, "difícil y apretado: cinco bolas, a cuatro cambios")
	check(hard.tick({"cancel": true}, DT) == "quit", "B (rodar) lo deja")
	# Up and down do nothing: the row is a row.
	var dirs := Minigame.make("squeeze", "hideout", 0, {}, 3, 1) as SqueezeGame
	for k in ["up", "down"]:
		tap(dirs, k)
	check(dirs.cursor == 0 and dirs.picked() < 0 and dirs.code.swaps == 0, "arriba y abajo no hacen nada")

	print("Minijuegos: uno por fichero")
	for k in ["lockpick", "wires", "steady", "balance", "squeeze"]:
		check(Minigame.exists(k) and ResourceLoader.exists(MinigameView.SCRIPTS % k), "%s: lógica y vista" % k)
		var how: String = "GAME_HOW_" + k.to_upper()
		check(Text.t(how) != how, "%s: sabe explicar cómo se juega" % k)

	print("El golpe con ganzúa")
	Sim.custom = {}
	Sim.new_map(4242, "small")
	Heist.plan_job(1)
	var p := Sim.new_thief()
	p.x = Heist.at.x + 0.5 + 1.0
	p.y = Heist.at.y + 0.5
	var thieves: Array[Thief] = [p]
	var kinds := {}
	for n in 10:
		Heist.plan_job(n + 1)
		p.x = Heist.at.x + 0.5 + 1.0
		p.y = Heist.at.y + 0.5
		kinds[Heist.game_for(p).get("kind", "")] = true
	check(kinds.keys() == ["lockpick"], "todas las noches, la vitrina se abre con la ganzúa")
	Heist.plan_job(1)
	p.x = Heist.at.x + 0.5 + 1.0
	p.y = Heist.at.y + 0.5
	var spec := Heist.game_for(p)
	check(spec.get("kind", "") == "lockpick", "junto a la vitrina, E saca la ganzúa")
	Heist.start_game(p, spec, {})
	var noises: Array[SoundEvent] = []
	Sim.step_thief(p, {"d": true}, DT)
	check(not p.moving and is_equal_approx(p.x, Heist.at.x + 1.5), "con las manos ocupadas no se mueve")
	var now := 1000.0
	var alarms := 0
	var result := ""
	while result == "" and now < 60000.0:
		now += 1000.0 * DT
		# Frame-perfect: press the moment the tip is on the spot.
		var pick := p.game as LockpickGame
		var down: bool = pick != null and pick.off() <= pick.band() * 0.5 and pick.lock <= 0.0
		if p.game:
			p.game.tick({"action": down}, DT)
		noises.clear()
		result = Heist.step(thieves, DT, now, noises)
		alarms += noises.size()
	check(result == "stolen" and Heist.carrier == p.id and p.game == null, "abre la vitrina y se lleva la pieza")
	check(alarms > 0, "solo, forzándola: suena la alarma de la vitrina (%d veces)" % alarms)

	print("En equipo: primero el cuadro")
	Sim.new_map(4242, "small")
	Heist.plan_job(1, {}, 2)
	var a := Sim.new_thief("p1")
	var b := Sim.new_thief("p2")
	a.x = Heist.at.x + 1.5
	a.y = Heist.at.y + 0.5
	b.x = Heist.panel.x + 0.5
	b.y = Heist.panel.y + 0.5
	thieves = [a, b]
	Heist.start_game(a, Heist.game_for(a), {})
	var pspec := Heist.game_for(b)
	check(pspec.get("kind", "") == "steady", "junto al cuadro, E saca la ventosa")
	Heist.start_game(b, pspec, {})
	noises.clear()
	Heist.step(thieves, DT, now, noises)
	check(Heist.waiting and a.game.blocked == "panel" and noises.is_empty(), "la vitrina espera al cuadro, sin alarma")
	b.game.step = b.game.steps
	b.game.done = true
	Heist.step(thieves, DT, now, noises)
	check(Heist.panel_off and b.game == null and Heist.panels_held(), "cristal cortado: el cuadro queda desconectado")
	b.x += 6.0
	a.game.step = a.game.steps
	a.game.done = true
	result = Heist.step(thieves, DT, now + 100.0, noises)
	check(result == "stolen" and noises.is_empty(), "con el cuadro cortado, la vitrina se abre en silencio aunque te vayas")

	print("Tres: dos cerraduras")
	Sim.new_map(4242, "medium")
	Heist.plan_job(1, {}, 3)
	var t1 := Sim.new_thief("p1")
	var t2 := Sim.new_thief("p2")
	var t3 := Sim.new_thief("p3")
	for t in [t1, t2]:
		t.x = Heist.at.x + 1.5
		t.y = Heist.at.y + 0.5
	thieves = [t1, t2, t3]
	Heist.panel_off = true
	Heist.start_game(t1, Heist.game_for(t1), {})
	Heist.step(thieves, DT, now, noises)
	check(Heist.short_hand and t1.game.blocked == "hands", "una sola mano en la vitrina: espera a la otra")
	Heist.start_game(t2, Heist.game_for(t2), {})
	t1.game.step = t1.game.steps
	t1.game.done = true
	check(Heist.step(thieves, DT, now, noises) == "" and t1.game != null, "una cerradura hecha, la otra no: sigue cerrada")
	t2.game.step = t2.game.steps
	t2.game.done = true
	check(Heist.step(thieves, DT, now, noises) == "stolen", "las dos: se abre")

	print("Noches sin ganzúa")
	Sim.custom = {"lockpick": false}
	Heist.plan_job(1)
	p.x = Heist.at.x + 1.5
	p.y = Heist.at.y + 0.5
	p.game = null
	check(Heist.game_for(p).is_empty(), "sin ganzúa esa noche: E no saca nada (basta con quedarse quieto)")
	Sim.custom = {}

	print("La recreativa")
	arcade()

	print("El estornudo")
	sneeze()

	quit(qa.summary())


## The arcade machine's pong (ArcadeGame): it never ends, the ball stays on
## the screen, letting go leaves it, and one who follows the ball beats the
## machine. And the machines are where the museum stands them (Arcades).
func arcade() -> void:
	var g := Minigame.make("arcade", "arcade", 1, {}, 3) as ArcadeGame
	var inside := true
	var bounces := 0
	# Two minutes following the ball with the paddle.
	while g.t < 120.0:
		var input := {"up": g.ball.y > g.me + 0.03, "down": g.ball.y < g.me - 0.03}
		check_quiet(g.tick(input, DT) == "", "arcade: nada que acabar")
		bounces += g.events.count("bounce")
		inside = inside and absf(g.ball.x) <= ArcadeGame.HALF_W + 0.1 and absf(g.ball.y) <= ArcadeGame.HALF_H
	check(not g.done and g.progress() == 0.0, "dos minutos jugando y no acaba nunca (ni avanza nada)")
	check(inside, "la pelota no se sale de la pantalla")
	check(bounces > 20, "la pelota va y viene (%d golpes)" % bounces)
	check(g.mine > g.theirs, "siguiendo la pelota se le gana a la máquina (%d a %d)" % [g.mine, g.theirs])
	var idle := Minigame.make("arcade", "arcade", 1, {}, 3) as ArcadeGame
	while idle.t < 60.0:
		idle.tick({}, DT)
	check(idle.theirs > idle.mine, "sin jugar, gana la máquina (%d a %d)" % [idle.theirs, idle.mine])
	check(g.tick({"cancel": true}, DT) == "quit", "soltar: se deja de jugar")

	# Somewhere with machines: a museum of modern galleries.
	var found := false
	for seed_ in range(1, 60):
		Sim.new_map(seed_, "medium")
		Heist.plan_job(1)
		Arcades.find()
		if not Arcades.list.is_empty():
			found = true
			var t: Vector2i = Arcades.list[0]
			check(Collection.at(t)[1] == Arcades.MODEL,
				"la recreativa está donde el museo la pone (semilla %d)" % seed_)
			var front := MuseumView.front_of(t)
			var p := Sim.new_thief()
			p.x = t.x + 0.5 + front.x
			p.y = t.y + 0.5 + front.y
			var ps: Array[Thief] = [p]
			check(Arcades.within_reach(p, ps) == t, "delante de la pantalla, se puede jugar")
			p.x = t.x + 0.5 - front.x * 1.2
			p.y = t.y + 0.5 - front.y * 1.2
			check(Arcades.within_reach(p, ps).x < 0, "por detrás, no")
			break
	check(found, "algún museo tiene recreativa")


## A check that only speaks up when it fails (it runs every frame).
func check_quiet(ok: bool, what: String) -> void:
	qa.check_quiet(ok, what)


## Holding in a sneeze in a hideout (SneezeGame): one who keeps the beat
## stays in for good; one who does nothing, or mashes the key, sneezes
## soon; the bar narrows with time and with nerves; the roll key does not
## let go of it.
func sneeze() -> void:
	var g := Minigame.make("sneeze", "hideout", 1, {}, 9) as SneezeGame
	var wide := g.bar()
	var out := ""
	var held := 0
	while g.t < 120.0 and out == "":
		var press := not g.tickles.is_empty() and absf(g.tickles[0] - SneezeGame.BAR_X) <= g.bar() * 0.5
		out = g.tick({"action": press}, DT)
		held += g.events.count("pin")
		# Let go of the key so the next press counts.
		if press:
			g.tick({}, DT)
	check(out == "", "llevando el ritmo aguanta dos minutos escondido (%d picores)" % held)
	check(g.bar() < wide * 0.6, "la barra se estrecha con el tiempo (%.2f → %.2f)" % [wide, g.bar()])
	check(g.beat() < SneezeGame.BEAT, "y el ritmo se acelera")
	var calm := Minigame.make("sneeze", "hideout", 1, {}, 9) as SneezeGame
	var nervous := Minigame.make("sneeze", "hideout", 1, {}, 9) as SneezeGame
	nervous.tremble = 1.0
	check(nervous.bar() < calm.bar(), "con los guardias alerta, la barra es más estrecha")
	check(calm.tick({"cancel": true}, DT) != "quit", "soltar no sirve: hay que salir del escondite")
	var idle := Minigame.make("sneeze", "hideout", 1, {}, 9) as SneezeGame
	var t_out := -1.0
	while idle.t < 10.0 and t_out < 0.0:
		if idle.tick({}, DT) == "fail":
			t_out = idle.t
	check(t_out > 0.0 and t_out < 3.0, "sin hacer nada, se escapa el primer picor y estornuda (%.1f s)" % t_out)
	var masher := Minigame.make("sneeze", "hideout", 1, {}, 9) as SneezeGame
	var fail := ""
	var k := 0
	while masher.t < 10.0 and fail == "":
		k += 1
		fail = masher.tick({"action": k % 6 < 3}, DT)
	check(fail == "fail" and masher.misses >= 1, "aporreando la tecla se falla y estornuda")
	var forgive := Minigame.make("sneeze", "hideout", 1, {}, 9) as SneezeGame
	forgive.misses = 2
	forgive.held = SneezeGame.CALM_HITS - 1
	forgive.tickles.append(SneezeGame.BAR_X)
	forgive.tick({"action": true}, DT)
	check(forgive.misses == 1, "una racha de aciertos perdona un fallo")
