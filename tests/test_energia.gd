extends SceneTree
## Cansancio: correr gasta aliento, y cansado se corre menos; rodar cuesta un
## tercio de la barra y sin ella no se rueda; la barra se llena a ritmo
## k * energía + mínimo; y en el primer museo, en fácil y en casa no existe.
##   godot --headless --script tests/test_energia.gd

const DT := 1.0 / 60.0

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func _init() -> void:
	call_deferred("run")


## A thief on a long open lane (the first seed with one), facing east.
func lane_thief() -> Thief:
	for seed in range(4242, 4342):
		Sim.new_map(seed, "small")
		for t in Museum.open_tiles:
			var run := 0
			while Museum.tile_at(t.x + run + 1.5, t.y + 0.5) == Tiles.FLOOR:
				run += 1
			if run >= 10:
				var p := Sim.new_thief()
				p.x = t.x + 0.5
				p.y = t.y + 0.5
				return p
	return Sim.new_thief()


## Holds a key for seconds, putting the thief back where it started every
## frame (so a wall never stops it): {speed (final), top (highest), gone
## (tiles it would have covered)}.
func hold(p: Thief, keys: Dictionary, seconds: float) -> Dictionary:
	var x := p.x
	var y := p.y
	var top := 0.0
	var gone := 0.0
	for k in int(seconds / DT):
		Sim.step_thief(p, keys, DT, "wasd")
		top = maxf(top, p.speed)
		gone += p.speed * DT
		p.x = x
		p.y = y
	return {"speed": p.speed, "top": top, "gone": gone}


func run() -> void:
	Text.setup()
	Sim.custom = {}
	Sim.difficulty = "medium"
	Sim.gang = 1
	Props.list.clear()

	# --- The switch: one place says whether a night tires ---------------------
	check(Sim.tiring(), "dificultad media: cansa")
	Sim.difficulty = "hard"
	check(Sim.tiring(), "dificultad difícil: cansa")
	Sim.difficulty = "easy"
	check(not Sim.tiring(), "dificultad fácil: no cansa")
	Sim.difficulty = "medium"
	var first_museum := true
	var later := true
	for n in range(1, Story.count() + 1):
		Sim.custom = Story.tuning(n)
		var tires := Sim.tiring()
		if Story.museum_of(n) == 0:
			first_museum = first_museum and not tires
		else:
			later = later and tires
	check(first_museum, "ninguna noche del primer museo cansa (robos 1 a %d)" % Story.ROOMS)
	check(later, "desde el segundo museo todas cansan")
	Sim.custom = Story.tuning(Story.ROOMS + 1)
	Sim.difficulty = "easy"
	check(Sim.tiring(), "la Historia manda sobre la dificultad suelta: el segundo museo cansa")
	Sim.custom = {}
	var map := MapFile.new()
	map.difficulty = "easy"
	Sim.custom = map.tuning()
	check(not Sim.tiring(), "un mapa en fácil no cansa")
	map.difficulty = "hard"
	Sim.custom = map.tuning()
	check(Sim.tiring(), "un mapa en difícil cansa")
	Sim.custom = Practice.tuning()
	Sim.difficulty = "medium"
	check(not Sim.tiring(), "la casa de la banda y el dojo (práctica) no cansan")
	Sim.custom = {}
	Sim.difficulty = "medium"

	# --- Starts full ---------------------------------------------------------
	check(Thief.new().energy == 1.0 and Sim.new_thief("p2").energy == 1.0, "cada ladrón nuevo empieza con la energía llena")

	# --- What tires: running; what does not: the rest -------------------------
	var p := lane_thief()
	var r := hold(p, {"d": true}, 1.0)
	check(p.energy < 1.0, "correr gasta (%.2f tras 1 s)" % p.energy)
	var q := lane_thief()
	q.energy = 0.5
	hold(q, {"d": true, "lalt": true}, 3.0)
	check(q.energy > 0.5, "andar despacio no gasta (sube a %.2f)" % q.energy)
	q = lane_thief()
	q.energy = 0.5
	q.crouched = true
	q.posture = 1.0
	hold(q, {"d": true}, 3.0)
	check(q.energy > 0.5, "ir agachado no gasta (sube a %.2f)" % q.energy)
	q = lane_thief()
	q.energy = 0.5
	hold(q, {}, 3.0)
	check(q.energy > 0.5, "quieto no gasta (sube a %.2f)" % q.energy)
	q = lane_thief()
	q.energy = 0.5
	q.dizzy = 3.0
	hold(q, {"d": true}, 1.0)
	check(q.energy > 0.5, "aturdido se recupera")

	# --- The top speed falls with tiredness, to under a chasing guard ---------
	var g := Sim.new_guards(1)[0]
	var hot: float = Sim.pace_of(g, 0.85, true).speed
	var pace_max: float = Sim.pace_of(g, 1.0, true).speed
	check(is_equal_approx(Energy.top_speed(Thief.new()), Sim.TOP_SPEED) and Sim.TOP_SPEED > hot + 0.8, "lleno corre a %.1f, más que un guardia en persecución (%.1f)" % [Sim.TOP_SPEED, hot])
	var steady := true
	var last := Sim.TOP_SPEED
	var jump := 0.0
	var e := Thief.new()
	for k in 101:
		e.energy = 1.0 - k / 100.0
		var v := Energy.top_speed(e)
		steady = steady and v <= last + 0.0001
		jump = maxf(jump, last - v)
		last = v
	check(steady and jump < 0.1, "la velocidad máxima baja de forma continua con la energía (salto máximo %.3f)" % jump)
	e.energy = Energy.TIRED_BELOW
	check(is_equal_approx(Energy.top_speed(e), Sim.TOP_SPEED), "con energía de sobra (hasta %.0f %%) corre a tope" % (Energy.TIRED_BELOW * 100.0))
	e.energy = 0.0
	check(Energy.top_speed(e) < hot and Energy.top_speed(e) < pace_max - 0.5, "agotado va por debajo de un guardia que persigue (%.1f frente a %.1f)" % [Energy.top_speed(e), hot])
	check(Energy.tired(e) and not Energy.tired(Thief.new()), "cansado se nota (la barra se pone roja)")

	# A flat-out run: how long it lasts, and what is left of it.
	var rp := lane_thief()
	var t_tired := -1.0
	var t_floor := -1.0
	var t := 0.0
	var speed_at_7 := 0.0
	var gap := 8.0
	var best_gap := 0.0
	var gap_at_30 := 0.0
	var x0 := rp.x
	var y0 := rp.y
	var gone := 0.0
	while t < 30.0:
		Sim.step_thief(rp, {"d": true}, DT, "wasd")
		rp.x = x0
		rp.y = y0
		t += DT
		gone += rp.speed * DT
		gap = 8.0 + gone - hot * t
		best_gap = maxf(best_gap, gap)
		if t_tired < 0.0 and rp.energy < Energy.TIRED_BELOW:
			t_tired = t
		if t_floor < 0.0 and Energy.top_speed(rp) < Sim.RUN_THRESHOLD + 0.05:
			t_floor = t
		if absf(t - 7.0) < DT / 2.0:
			speed_at_7 = rp.speed
	gap_at_30 = gap
	print("       carrera a tope: cansa a los %.1f s, trote a los %.1f s, velocidad final %.2f; ventaja máxima sobre un guardia %.1f casillas" % [t_tired, t_floor, rp.speed, best_gap])
	check(t_tired > 5.5 and t_tired < 9.0, "unos 6-8 s de carrera a tope antes de notar el cansancio (%.1f s)" % t_tired)
	check(t_floor > 8.0 and t_floor < 14.0, "agotado en torno a 10-12 s (%.1f s)" % t_floor)
	check(rp.speed < hot, "sin parar, la carrera acaba por debajo del paso del guardia (%.2f frente a %.2f)" % [rp.speed, hot])
	check(best_gap > 12.0, "con la energía llena se saca distancia a un guardia (%.1f casillas de ventaja)" % best_gap)
	check(gap_at_30 < best_gap - 6.0, "pero no se aguanta: a los 30 s la ventaja se ha encogido de %.1f a %.1f" % [best_gap, gap_at_30])

	# --- Rolling: a third of the bar, and not without it ----------------------
	var ro := lane_thief()
	Sim.step_thief(ro, {"space": true}, DT, "wasd")
	check(ro.rolling and absf(ro.energy - (1.0 - Energy.ROLL_COST)) < 0.001, "rodar resta %.2f de la barra (%.2f)" % [Energy.ROLL_COST, ro.energy])
	var before := ro.energy
	for k in 30:
		Sim.step_thief(ro, {}, DT, "wasd")
	check(ro.rolling and ro.energy == before, "mientras rueda no se recupera")
	var weak := lane_thief()
	weak.energy = Energy.ROLL_COST - 0.04
	var step := Sim.step_thief(weak, {"space": true}, DT, "wasd")
	check(not weak.rolling and step.roll == "tired" and weak.energy > Energy.ROLL_COST - 0.04 and not weak.crouched, "sin energía suficiente no rueda, y no gasta nada")
	check(weak.energy_flash > 0.0, "y la barra avisa (parpadea)")
	var just := lane_thief()
	just.energy = Energy.ROLL_COST + 0.001
	Sim.step_thief(just, {"space": true}, DT, "wasd")
	check(just.rolling, "con justo lo que cuesta, rueda")
	var after_roll := lane_thief()
	after_roll.energy = 0.0
	Heist.carrier = "p1"
	step = Sim.step_thief(after_roll, {"space": true}, DT, "wasd")
	Heist.carrier = ""
	check(step.roll == "sack" and not after_roll.rolling, "con el saco y sin energía, manda el saco")

	# --- Filling up: k * energy + minimum -------------------------------------
	check(Energy.regen_rate(0.0) == Energy.REGEN_MIN and Energy.REGEN_MIN > 0.0, "vacía se recupera a un mínimo que no es 0 (%.3f/s)" % Energy.REGEN_MIN)
	check(is_equal_approx(Energy.regen_rate(0.6), Energy.REGEN_K * 0.6 + Energy.REGEN_MIN), "la velocidad es k × energía + mínimo")
	check(Energy.regen_rate(0.8) > Energy.regen_rate(0.2), "se llena más deprisa cuanta más energía queda")
	for lv in [0.0, 0.2, 0.5, 0.7]:
		var f := lane_thief()
		f.energy = lv
		Sim.step_thief(f, {}, 1.0, "wasd")
		check(absf(f.energy - minf(1.0, lv + Energy.REGEN_K * lv + Energy.REGEN_MIN)) < 0.0005, "con %.1f sube %.3f en 1 s (k × e + mínimo)" % [lv, f.energy - lv])
	var fill := lane_thief()
	fill.energy = 0.0
	var tf := 0.0
	var at_half := 0.0
	var at_tenth := 0.0
	while fill.energy < 1.0 and tf < 40.0:
		Sim.step_thief(fill, {}, DT, "wasd")
		tf += DT
		if at_tenth == 0.0 and fill.energy >= 0.1:
			at_tenth = tf
		if at_half == 0.0 and fill.energy >= 0.5:
			at_half = tf
	var from_half := lane_thief()
	from_half.energy = 0.5
	var th := 0.0
	while from_half.energy < 1.0 and th < 40.0:
		Sim.step_thief(from_half, {}, DT, "wasd")
		th += DT
	print("       de vacío a lleno: %.1f s (a 0,1: %.1f s, a la mitad: %.1f s); de la mitad a lleno: %.1f s" % [tf, at_tenth, at_half, th])
	check(fill.energy == 1.0 and tf > 7.0 and tf < 12.5, "de vacío a lleno en unos 8-12 s (%.1f s)" % tf)
	check(th < tf * 0.4 and at_tenth > th, "de la mitad se llena mucho antes (%.1f s) que de vacío, y desde 0 tarda en arrancar (%.1f s al 10 %%)" % [th, at_tenth])

	# --- A night that does not tire -------------------------------------------
	Sim.custom = Story.tuning(1)
	var free := lane_thief()
	r = hold(free, {"d": true}, 20.0)
	check(free.energy == 1.0 and r.top > Sim.TOP_SPEED - 0.05 and Energy.top_speed(free) == Sim.TOP_SPEED, "sin cansancio correr no gasta ni baja la velocidad (%.2f tras 20 s)" % r.speed)
	free.energy = 0.0
	Sim.step_thief(free, {"space": true}, DT, "wasd")
	check(free.rolling and free.energy == 1.0, "sin cansancio rodar no cuesta ni se bloquea por energía")
	var sack := lane_thief()
	Heist.carrier = "p1"
	step = Sim.step_thief(sack, {"space": true}, DT, "wasd")
	Heist.carrier = ""
	check(step.roll == "sack" and not sack.rolling, "sin cansancio el saco sigue sin dejar rodar")
	Sim.custom = {}
	Sim.difficulty = "easy"
	var easy := lane_thief()
	hold(easy, {"d": true}, 15.0)
	check(easy.energy == 1.0, "en fácil, correr 15 s no gasta")
	Sim.difficulty = "medium"

	# --- The bar on screen -----------------------------------------------------
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	Heist.loot = Heist.loot_for(1)
	hud.set_gang([Color.WHITE], [Color.GRAY], Heist.loot)
	var wind: Control = hud._portraits[0].wind
	var state := {"posture": 0.0, "speed": 0.0, "carrying": false, "seen": false, "out": false, "safe": false, "pose": "", "smoke": 0,
		"energy": 1.0, "tiring": false, "tired": false, "no_energy": false}
	hud.update_gang([state], DT)
	check(not wind.visible, "en una noche sin cansancio la barra no se muestra")
	state.tiring = true
	state.energy = 0.7
	hud.update_gang([state], DT)
	check(wind.visible and absf(float(wind.get_meta("level")) - 0.7) < 0.001 and not wind.get_meta("tired"), "en una noche con cansancio, sí (verde)")
	state.energy = 0.2
	state.tired = true
	hud.update_gang([state], DT)
	check(wind.visible and wind.get_meta("tired"), "cansado cambia de color")
	state.safe = true
	hud.update_gang([state], DT)
	check(not wind.visible, "fuera del museo se esconde")

	# --- And the tip -------------------------------------------------------------
	check(Text.t("TIP_WIND").split(" ", false).size() <= Briefing.WORDS, "el consejo cabe en %d palabras" % Briefing.WORDS)

	quit(qa.summary())
