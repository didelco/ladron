extends SceneTree
## Los modos de la noche (NightAlert) y la ganzúa con alarma:
##   - la ganzúa y la ventosa: verde, naranja, rojo por enganche, y de nuevo
##     verde en el siguiente; solo donde hay alarma;
##   - la alarma: solo en rojo y solo donde toca; dura 20 s y otro rojo la
##     reinicia; pone el modo intruso;
##   - intruso: por ver a alguien (sin sirena) o por la alarma; todos en
##     alerta, y 45 s sin ver a nadie y sin sirena después, cada guardia baja
##     a su ritmo;
##   - el robo descubierto: solo mirando la vitrina vacía, a los 200 ms y
##     cada 500 ms, con BASE × atención × cercanía; luego nadie baja de 1 y
##     uno vigila la salida 20 s de cada 60;
##   - la megafonía: alarma solo al saltar, "robada" solo al descubrirse,
##     "abren la vitrina" solo con la alarma sonando.
## godot --headless --script tests/test_modos.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")
const DT := 1.0 / 60
var clock := 1000.0


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func _init() -> void:
	call_deferred("run")


func run() -> void:
	hooks()
	alarm_in_heist()
	siren()
	intruder()
	theft()
	robbed()
	attention_trait()
	await megaphone()
	quit(qa.summary())


## An open room: walls round the edge, floor inside.
func open_room() -> void:
	Museum.regenerate(1, "small", "rect")
	var w := Museum.w
	var h := Museum.h
	for y in h:
		for x in w:
			Museum.grid[y * w + x] = Tiles.WALL if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else Tiles.FLOOR
	for i in Museum.lights_left.size():
		Museum.lights_left[i] = 0.0


var _guards_made := 0


## A guard of its own (its own id and name: NightAlert tells them apart).
func guard_at(x: float, y: float, dir: float = 0.0) -> Guard:
	var g: Guard = Sim.new_guards(1)[0]
	_guards_made += 1
	g.id = "t%d" % _guards_made
	g.name = "Guardia %d" % _guards_made
	g.x = x
	g.y = y
	g.dir = dir
	g.path.clear()
	g.post = Vector2i(-1, -1)
	return g


## One press of the pick: on the green (hit) or right across the dial. Returns
## what happened that frame; the key is let go of with release().
func press(g: Minigame, hit: bool) -> Array[String]:
	var pk := g as LockpickGame
	pk.lock = 0.0
	pk.sweep = fposmod((pk.spot if hit else pk.spot + 0.5) - DT / LockpickGame.PIN_PERIOD, 1.0)
	g.tick({"action": true}, DT)
	return g.events.duplicate()


func release(g: Minigame) -> void:
	g.tick({}, 0.0)


## The suction cup held in the ring for `seconds` (frame by frame), or put
## out of it for one frame. Returns what happened in the last frame.
func cup(g: Minigame, inside: bool, seconds := DT) -> Array[String]:
	var s := g as SteadyGame
	var out: Array[String] = []
	for f in maxi(1, roundi(seconds / DT)):
		s.cup = Vector2.ZERO if inside else Vector2(1.3, 0.0)
		s.cup_v = Vector2.ZERO
		s.drift = Vector2.ZERO
		s._drift_to = Vector2.ZERO
		s._gust_in = 10.0
		g.tick({}, DT)
		out = g.events.duplicate()
	return out


func hooks() -> void:
	print("Ganzúa: verde, naranja, rojo por perno")
	var g := Minigame.make("lockpick", "case", 3, {}, 7) as LockpickGame
	g.alarm = true
	check(g.hook_colour() == 0, "empieza en verde")
	var near_band := g.band()
	# A near miss: just outside the green, which then gets wider (as ever).
	g.lock = 0.0
	g.sweep = fposmod(g.spot + near_band * 1.5 - DT / LockpickGame.PIN_PERIOD, 1.0)
	g.tick({"action": true}, DT)
	var ev := g.events.duplicate()
	release(g)
	check(g.hook_colour() == 1 and ev.has("orange") and not ev.has("red"), "un fallo: naranja (%s)" % [ev])
	check(g.band() > near_band, "y el verde se hace más grande (%.3f > %.3f)" % [g.band(), near_band])
	ev = press(g, false)
	release(g)
	check(g.hook_colour() == 2 and ev.has("red"), "otro fallo en el mismo perno: rojo (%s)" % [ev])
	ev = press(g, false)
	release(g)
	check(g.hook_colour() == 2 and not ev.has("red"), "un tercero: sigue rojo, sin otro aviso de rojo")
	ev = press(g, true)
	release(g)
	check(g.step == 1 and g.hook_colour() == 0 and g.fails == 0, "acertando, el perno siguiente vuelve a verde")
	press(g, false)
	release(g)
	press(g, true)
	release(g)
	check(g.step == 2 and g.hook_colour() == 0, "naranja y acierto: el siguiente, verde otra vez")
	var quiet := Minigame.make("lockpick", "case", 3, {}, 7) as LockpickGame
	var quiet_ev: Array[String] = []
	for k in 3:
		quiet_ev.append_array(press(quiet, false))
		release(quiet)
	check(quiet.hook_colour() == 0 and not quiet_ev.has("red") and not quiet_ev.has("orange"), "sin alarma: siempre verde, falle lo que falle")

	print("Ventosa: la misma regla por lámpara")
	var s := Minigame.make("steady", "panel", 5, {}, 3) as SteadyGame
	s.alarm = true
	cup(s, true, 0.1)
	var sev := cup(s, false)
	check(s.hook_colour() == 1 and sev.has("orange"), "se sale del círculo: naranja (%s)" % [sev])
	cup(s, true, 0.1)
	sev = cup(s, false)
	check(s.hook_colour() == 2 and sev.has("red"), "otra vez antes de la siguiente lámpara: rojo (%s)" % [sev])
	cup(s, true, 0.6)
	check(s.step >= 1 and s.hook_colour() == 0, "una lámpara encendida: verde otra vez")


func alarm_in_heist() -> void:
	print("La alarma en el golpe: solo en rojo, solo donde toca")
	Sim.custom = {}
	Sim.gang = 1
	Sim.new_map(4242, "small")
	Heist.plan_job(1)
	var p := Sim.new_thief()
	var stand: Vector2i = Heist._stand_tiles(Heist.at)[0]
	p.x = stand.x + 0.5
	p.y = stand.y + 0.5
	var thieves: Array[Thief] = [p]
	Heist.start_game(p, Heist.game_for(p), {})
	check(p.game is LockpickGame and p.game.alarm, "vitrina con alarma: la ganzúa cuenta los fallos")
	var noises: Array[SoundEvent] = []
	press(p.game, false)
	Heist.step(thieves, DT, clock, noises)
	release(p.game)
	check(NightAlert.alarms == 0 and noises.is_empty() and not NightAlert.ringing(), "un fallo: naranja, nada suena")
	press(p.game, false)
	Heist.step(thieves, DT, clock, noises)
	release(p.game)
	var at_case := noises.size() == 1 and noises[0].kind == "alarm" and Vector2(noises[0].x, noises[0].y) == Vector2(Heist.at.x + 0.5, Heist.at.y + 0.5)
	check(NightAlert.alarms == 1 and NightAlert.ringing() and at_case, "dos en el mismo perno: rojo y salta la alarma, en la vitrina")
	check(NightAlert.intruder and NightAlert.events.has("alarm") and HeistStats.count("alarms") >= 1, "la alarma pone el modo intruso y se cuenta para el periódico")
	press(p.game, false)
	Heist.step(thieves, DT, clock, noises)
	release(p.game)
	check(NightAlert.alarms == 1, "un tercer fallo no la dispara otra vez")

	Sim.custom = {"case_alarm": false}
	Heist.plan_job(1)
	stand = Heist._stand_tiles(Heist.at)[0]
	p.x = stand.x + 0.5
	p.y = stand.y + 0.5
	p.game = null
	Heist.start_game(p, Heist.game_for(p), {})
	for k in 3:
		press(p.game, false)
		Heist.step(thieves, DT, clock, noises)
		release(p.game)
	check(not p.game.alarm and p.game.hook_colour() == 0 and NightAlert.alarms == 0, "vitrina sin alarma: verde siempre, y nada salta")
	Sim.custom = Story.tuning(7)
	check(not Heist.alarm_live(), "noche 7 (antes de la vitrina con alarma): no puede saltar")
	Sim.custom = Story.tuning(11)
	check(Heist.alarm_live(), "noche 11 (la de la vitrina con alarma): puede saltar")

	print("En banda: la ventosa del cuadro")
	Sim.custom = {}
	Sim.new_map(4242, "small")
	Heist.plan_job(1, {}, 2)
	var a := Sim.new_thief("p1")
	var b := Sim.new_thief("p2")
	a.x = stand.x + 0.5
	a.y = stand.y + 0.5
	for t in Heist._stand_tiles(Heist.at):
		a.x = t.x + 0.5
		a.y = t.y + 0.5
		break
	b.x = Heist.panel.x + 0.5
	b.y = Heist.panel.y + 0.5
	var pair: Array[Thief] = [a, b]
	Heist.start_game(b, Heist.game_for(b), {})
	check(b.game is SteadyGame and b.game.alarm, "la ventosa del cuadro cuenta los fallos")
	noises.clear()
	for k in 2:
		cup(b.game, true, 0.1)
		cup(b.game, false)
		Heist.step(pair, DT, clock, noises)
	check(NightAlert.alarms == 1 and NightAlert.alarm_at == Vector2(Heist.panel.x + 0.5, Heist.panel.y + 0.5), "dos salidas en la misma lámpara: salta, en el cuadro")
	Heist.start_game(a, Heist.game_for(a), {})
	Heist.panel_off = true
	Heist.step(pair, DT, clock, noises)
	check(not a.game.alarm, "con el cuadro cortado, la ganzúa de la vitrina ya no cuenta")


func siren() -> void:
	print("La sirena: 20 s, y otro rojo la reinicia")
	NightAlert.reset()
	var none: Array[Guard] = []
	var noises: Array[SoundEvent] = []
	NightAlert.trip(Vector2(5.5, 5.5), noises)
	var heard := noises.size()
	for f in int(15.0 * 60):
		NightAlert.step(none, noises, clock, DT)
	check(NightAlert.ringing() and noises.size() - heard >= 9 and noises.size() - heard <= 11, "sigue sonando a los 15 s, y los guardias la oyen cada %.1f s (%d)" % [NightAlert.ALARM_NOISE_EVERY_S, noises.size() - heard])
	NightAlert.trip(Vector2(5.5, 5.5), noises)
	for f in int(19.8 * 60):
		NightAlert.step(none, noises, clock, DT)
	check(NightAlert.ringing(), "otro rojo a los 15 s: a los 34,8 s aún suena")
	NightAlert.events.clear()
	for f in int(0.4 * 60):
		NightAlert.step(none, noises, clock, DT)
	check(not NightAlert.ringing() and NightAlert.events.has("alarm_off"), "a los 20 s del último rojo se apaga sola")
	check(NightAlert.intruder, "apagada, el modo intruso sigue")
	for f in int(44.0 * 60):
		NightAlert.step(none, noises, clock, DT)
	check(NightAlert.intruder, "a los 44 s sin sirena ni nadie visto, aún intruso")
	for f in int(1.5 * 60):
		NightAlert.step(none, noises, clock, DT)
	check(not NightAlert.intruder and NightAlert.events.has("intruder_off"), "a los 45 s se acaba el intruso")


## Every guard a frame: NightAlert first, then each one's own step.
func night(gs: Array[Guard], seconds: float, thieves: Array[Thief] = []) -> void:
	for f in int(seconds * 60):
		clock += 1000.0 * DT
		var noises: Array[SoundEvent] = []
		NightAlert.step(gs, noises, clock, DT)
		for g in gs:
			Sim.step_guard(g, thieves, noises, clock, DT)


func intruder() -> void:
	print("Intruso: por ver a alguien")
	open_room()
	Sim.custom = {}
	Heist.at = Vector2i(10, 5)
	Heist.exit = Vector2i(1, 5)
	Heist.taken = false
	NightAlert.reset()
	var gs: Array[Guard] = [guard_at(3.5, 3.5, PI), guard_at(12.5, 3.5, 0.0), guard_at(8.5, 7.5, PI / 2)]
	gs[0].sees_player = true
	var noises: Array[SoundEvent] = []
	NightAlert.step(gs, noises, clock, DT)
	check(NightAlert.mode(gs) == "intruder" and gs.all(func(g: Guard) -> bool: return g.suspicion >= 2 and g.alert), "uno ve a alguien: intruso, todos en alerta")
	check(not NightAlert.ringing() and NightAlert.alarms == 0 and not NightAlert.events.has("alarm") and noises.is_empty(), "sin sirena ni alarma")
	gs[0].sees_player = false
	night(gs, 44.0)
	check(NightAlert.intruder and gs.all(func(g: Guard) -> bool: return g.suspicion >= 2), "44 s sin ver a nadie: siguen todos en alerta")
	night(gs, 1.5)
	check(not NightAlert.intruder, "45 s: se acaba el intruso")
	var calm_at := -1.0
	var one_at := -1.0
	for s in 60:
		night(gs, 1.0)
		if one_at < 0.0 and gs.all(func(g: Guard) -> bool: return g.suspicion == 1):
			one_at = s + 1.0
		if gs.all(func(g: Guard) -> bool: return g.suspicion == 0 and not g.alert):
			calm_at = s + 1.0
			break
	check(one_at >= 28.0 and one_at <= 32.0, "bajan un escalón: a sospecha a los %.0f s (la bajada de cada uno)" % one_at)
	check(calm_at > one_at and calm_at <= 40.0, "y luego a la calma, a los %.0f s" % calm_at)
	check(NightAlert.mode(gs) == "calm", "noche tranquila otra vez")

	print("Intruso: por la alarma")
	NightAlert.reset()
	NightAlert.trip(Vector2(10.5, 5.5), noises)
	night(gs, 1.0)
	check(NightAlert.intruder and gs.all(func(g: Guard) -> bool: return g.suspicion >= 2 and g.alert), "salta la alarma: intruso, todos en alerta")
	night(gs, 19.0 + 44.0)
	check(NightAlert.intruder, "sirena 20 s y 44 s más: aún intruso")
	night(gs, 1.5)
	check(not NightAlert.intruder, "a los 45 s sin sirena: se acaba")


func theft() -> void:
	print("El robo: solo si la vitrina vacía cae en su mirada")
	open_room()
	Sim.custom = {}
	Sim.gang = 1
	Heist.at = Vector2i(10, 5)
	Heist.exit = Vector2i(1, 9)
	Heist.taken = true
	NightAlert.reset()
	var g := guard_at(5.5, 5.5, 0.0)
	var gs: Array[Guard] = [g]
	var reach: float = Sim.view_of(g).range
	var close := pow(1.0 - 5.0 / reach, 2.0)
	check(is_equal_approx(NightAlert.closeness(g, clock), close), "cercanía (1 - d/alcance)²: %.4f" % NightAlert.closeness(g, clock))
	check(is_equal_approx(NightAlert.find_chance(g, clock), NightAlert.FIND_BASE * close), "tranquilo: BASE × 1 × cercanía")
	g.suspicion = 1
	check(is_equal_approx(NightAlert.attention(g), NightAlert.ATTENTION_SUSPECT), "con sospecha, atención ×%.1f" % NightAlert.ATTENTION_SUSPECT)
	g.suspicion = 2
	g.alert = true
	check(is_equal_approx(NightAlert.attention(g), NightAlert.ATTENTION_ALERT), "en alerta, ×%.1f" % NightAlert.ATTENTION_ALERT)
	var alert_reach: float = Sim.view_of(g).range
	check(alert_reach > reach and NightAlert.closeness(g, clock) > close, "y en alerta ve más lejos: más cerca en proporción")
	g.suspicion = 0
	g.alert = false
	NightAlert.intruder = true
	check(is_equal_approx(NightAlert.attention(g), NightAlert.ATTENTION_ALERT), "en modo intruso, ×%.1f" % NightAlert.ATTENTION_ALERT)
	NightAlert.intruder = false
	NightAlert.alarm_left = 5.0
	check(is_equal_approx(NightAlert.attention(g), NightAlert.ATTENTION_ALARM), "con la alarma sonando, ×%.1f" % NightAlert.ATTENTION_ALARM)
	NightAlert.alarm_left = 0.0
	g.attention_scale = 1.5
	check(is_equal_approx(NightAlert.attention(g), 1.5), "y su rasgo «atento» lo multiplica")
	g.attention_scale = 1.0
	g.dir = PI
	check(NightAlert.find_chance(g, clock) == 0.0, "mirando a otro lado: nada")
	g.dir = 0.0
	g.x = 1.5
	check(NightAlert.find_chance(g, clock) == 0.0, "más lejos de lo que ve: nada")
	g.x = 5.5
	Museum.grid[5 * Museum.w + 8] = Tiles.WALL
	check(NightAlert.find_chance(g, clock) == 0.0, "con una pared en medio: nada")
	Museum.grid[5 * Museum.w + 8] = Tiles.FLOOR

	# The timing: the first roll 200 ms after the look falls on it, then every
	# 500 ms. A guard that barely notices anything (attention 0.001): it rolls,
	# but finding it is all but impossible.
	g.attention_scale = 0.001
	NightAlert.seed_rng(99)
	var noises: Array[SoundEvent] = []
	for f in int(0.15 * 60):
		NightAlert.step(gs, noises, clock, DT)
	check(NightAlert.rolls == 0, "a los 150 ms mirándola, aún no tira")
	for f in int(0.15 * 60):
		NightAlert.step(gs, noises, clock, DT)
	check(NightAlert.rolls == 1, "a los 300 ms, una tirada")
	for f in int(2.0 * 60):
		NightAlert.step(gs, noises, clock, DT)
	check(NightAlert.rolls == 5 and not NightAlert.robbed, "a los 2,3 s, cinco (una cada 500 ms): %d" % NightAlert.rolls)
	g.dir = PI
	NightAlert.step(gs, noises, clock, DT)
	g.dir = 0.0
	var before := NightAlert.rolls
	for f in int(0.15 * 60):
		NightAlert.step(gs, noises, clock, DT)
	check(NightAlert.rolls == before, "deja de mirarla y vuelve: otra vez a esperar 200 ms")

	# The dice: with its own seed, found on the first roll that comes under
	# the chance — the same as the same dice say.
	g.attention_scale = 1.0
	NightAlert.reset()
	var p := NightAlert.find_chance(g, clock)
	var seed_ := 4321
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_
	var expect := 1
	while dice.randf() >= p:
		expect += 1
	NightAlert.seed_rng(seed_)
	var secs := 0.0
	while not NightAlert.robbed and secs < 120.0:
		NightAlert.step(gs, noises, clock, DT)
		secs += DT
	check(NightAlert.robbed and NightAlert.rolls == expect, "con p = %.3f, lo descubre en la tirada %d (esperada %d)" % [p, NightAlert.rolls, expect])
	check(NightAlert.found_by == g.name and NightAlert.events.has("robbed") and g.suspicion >= 2, "quien lo descubre se pone en alerta")
	var global_before := randi()
	seed(global_before)
	var a := randi()
	seed(global_before)
	NightAlert.reset()
	for f in 60:
		NightAlert.step(gs, noises, clock, DT)
	check(randi() == a, "las tiradas no tocan el azar global (el del museo y el golpe)")

	print("Nadie lo descubre sin mirar la vitrina")
	NightAlert.reset()
	Heist.taken = false
	g.dir = 0.0
	for f in 120:
		NightAlert.step(gs, noises, clock, DT)
	check(not NightAlert.robbed and NightAlert.rolls == 0, "con la pieza aún en su sitio, no hay nada que descubrir")
	Heist.taken = true


func robbed() -> void:
	print("Nos han robado: suelo 1 y la salida vigilada")
	open_room()
	Sim.custom = {}
	Heist.at = Vector2i(10, 5)
	Heist.exit = Vector2i(1, 9)
	Heist.taken = true
	NightAlert.reset()
	var gs: Array[Guard] = [guard_at(6.5, 3.5, PI), guard_at(12.5, 8.5, 0.0), guard_at(4.5, 8.5, PI / 2)]
	NightAlert.robbed = true
	NightAlert.door_clock = NightAlert.DOOR_EVERY_S
	var spot := NightAlert.door_spot_for(Heist.exit)
	var d := Museum.dist(spot.x + 0.5, spot.y + 0.5, Heist.exit.x + 0.5, Heist.exit.y + 0.5)
	check(spot.x >= 0 and d >= 3.0 and d <= 4.0, "vigila la salida desde %.1f casillas" % d)
	var lowest := 3
	var sent := []
	var there := -1.0
	var left := -1.0
	var was := ""
	var t := 0.0
	while t < 130.0:
		night(gs, 0.25)
		t += 0.25
		for g in gs:
			lowest = mini(lowest, g.suspicion)
		var who := NightAlert.door_guard
		if who != "" and who != was:
			sent.append(t)
		if who != "" and there < 0.0 and NightAlert.door_left >= 0.0:
			there = t
		if who == "" and was != "" and left < 0.0:
			left = t
		was = who
	check(lowest >= 1, "en 130 s, nadie baja de sospecha (1): mínimo %d" % lowest)
	check(sent.size() >= 2 and sent[0] <= 0.5, "uno va enseguida a vigilar la salida (%s)" % [sent])
	check(there > 0.0 and left - there >= 19.0 and left - there <= 21.0, "se queda unos 20 s (llega a los %.1f s, se va a los %.1f s)" % [there, left])
	check(sent.size() >= 2 and absf(sent[1] - sent[0] - 60.0) <= 0.6, "y otro a los 60 s del anterior (%s)" % [sent])
	check(NightAlert.mode(gs) == "robbed", "modo: robado")
	NightAlert.intruder = true
	check(NightAlert.mode(gs) == "intruder" and NightAlert.robbed, "intruso encima del robo: el robo sigue de fondo")


func attention_trait() -> void:
	print("El rasgo «atento», por guardia")
	var spawn := GuardSpawn.new()
	spawn.at = Vector2i(3, 3)
	spawn.attention_level = 4
	var m := MapFile.blank(15, 11)
	m.guards.append(spawn)
	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(back.guards[0].attention_level == 4, "se guarda y se lee en el mapa")
	open_room()
	var gs := Sim.new_guards(1)
	var at: Array[GuardSpawn] = [spawn]
	Sim.place_guards(gs, at)
	check(is_equal_approx(gs[0].attention_scale, GuardSpawn.LEVELS.attention[4]), "y lo lleva el guardia (×%.2f)" % gs[0].attention_scale)
	check(GuardSpawn.LEVELS.attention[2] == 1.0 and GuardSpawn.STATS.has("attention"), "el guardia normal es 1,0, y el editor lo enseña")


func megaphone() -> void:
	print("Megafonía: solo cuando toca")
	Megaphone.intro_override = 0.0
	Megaphone.forget()
	Settings.path = "user://test_modos_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Story.save = "user://test_modos.cfg"
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.mode = "story"
	main.players = 1
	main.seats.assign(["kb_left"])
	main._new_round(11)
	await process_frame
	main.options.set_megaphone_mode("both")
	HeistStats.time = 30.0
	var mega: Megaphone = main.loudspeaker.mega
	mega.always = true
	var t: Thief = main.thieves[0]
	var stand: Vector2i = Heist._stand_tiles(Heist.at)[0]
	t.x = stand.x + 0.5
	t.y = stand.y + 0.5
	var noises: Array[SoundEvent] = []
	# The loudspeaker only takes in what happens while the night is on.
	main.phase = "playing"
	main.loop._do_action(t, 0, {"do": "job", "at": Heist.game_for(t)}, {}, Sim.now_ms(), noises)
	main.phase = "countdown"
	check(t.game is LockpickGame and not mega.counts.has("case"), "sacar la ganzúa sin alarma: la megafonía calla")
	t.game.step = t.game.steps
	t.game.done = true
	main.loop._job(DT, Sim.now_ms(), noises)
	check(Heist.taken and mega._pending_kind != "stolen", "coger la pieza: nadie dice «robada» todavía")
	NightAlert.events.append("robbed")
	NightAlert.found_by = "Vela"
	main.loop.alert_events()
	check(mega._pending_kind == "stolen" and NightAlert.events.is_empty(), "un guardia ve la vitrina vacía: ahora sí, «robada»")
	NightAlert.trip(Vector2(Heist.at.x + 0.5, Heist.at.y + 0.5), noises)
	main.loop.alert_events()
	check(mega._pending_kind == "alarm", "salta la alarma: su aviso, solo ahora")
	Heist.taken = false
	t.game = null
	main.phase = "playing"
	main.loop._do_action(t, 0, {"do": "job", "at": Heist.game_for(t)}, {}, Sim.now_ms(), noises)
	main.phase = "countdown"
	check(int(mega.counts.get("case", 0)) == 1, "con la alarma sonando, «alguien abre la vitrina» puede salir")

	print("Sirena y luces giratorias mientras suena")
	main.phase = "playing"
	for f in 240:
		await process_frame
		if main.museum_view != null and main.museum_view.alarm_level() >= 1.0:
			break
	check(main.museum_view != null and main.museum_view.alarm_level() >= 1.0, "las luces rojas giran (%.2f)" % (main.museum_view.alarm_level() if main.museum_view else -1.0))
	check(main.sfx.siren_on(), "y suena la sirena")
	NightAlert.alarm_left = 0.0
	for f in 240:
		await process_frame
		if main.museum_view.alarm_level() == 0.0 and not main.sfx.siren_on():
			break
	check(main.museum_view.alarm_level() == 0.0 and not main.sfx.siren_on(), "apagada la alarma: ni luces ni sirena (%.2f)" % main.museum_view.alarm_level())
	main.phase = "title"
	main.queue_free()
	await process_frame
