extends SceneTree
## Rolling: eight tiles in a flash, a fifth faster than running, as low as on
## all fours and as quiet. A clean roll ends on all fours, no stars, up in
## about 1.8 s; into a wall it stops dead with a thump the guards hear and
## lies stunned, ninja stars going round, on its feet as far as the guards'
## eyes go, about 3 s on the floor. Not with the sack of loot.
##   godot --headless --script tests/test_roll.gd

const DT := 1.0 / 60.0

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


## An open tile with between min_run and max_run floor tiles east of it, then a wall.
func lane(min_run: int, max_run: int) -> Array:
	for t in Museum.open_tiles:
		var run := 0
		while Museum.tile_at(t.x + run + 1.5, t.y + 0.5) == Tiles.FLOOR:
			run += 1
		if run >= min_run and run <= max_run and Museum.tile_at(t.x + run + 1.5, t.y + 0.5) == Tiles.WALL:
			return [t, run]
	return []


func fresh_thief(at: Vector2i) -> Thief:
	var p := Sim.new_thief()
	p.x = at.x + 0.5
	p.y = at.y + 0.5
	p.dir = 0.0
	return p


## Time from now until the thief (down after a roll) takes a step, mashing the
## roll key and walking all along: {t, rolled_again, low (stayed on all fours
## until getting up), starry (a "dizzy" pose at any point)}.
func time_down(p: Thief) -> Dictionary:
	var at_rest := Vector2(p.x, p.y)
	var down := 0.0
	var rolled_again := false
	var low := true
	var starry := false
	var toggle := true
	var waiting := p.dizzy
	while Vector2(p.x, p.y).distance_to(at_rest) < 0.001 and down < 10.0:
		# Mashing the roll key (pressed, let go, pressed...) and walking back
		# the way it came (away from any wall it hit).
		toggle = not toggle
		starry = starry or Roll.pose(p) == "dizzy"
		Sim.step_thief(p, {"a": true, "space": toggle}, DT, "wasd")
		down += DT
		rolled_again = rolled_again or p.rolling
		if down < waiting - DT and (p.posture < 1.0 or not p.crouched):
			low = false
	return {"t": down, "rolled_again": rolled_again, "low": low, "starry": starry}


func _init() -> void:
	Sim.custom = {}
	# A small museum with a straight run long enough to roll down, and a
	# one-tile gap against a wall: the first seed from 4242 that has both.
	for seed in range(4242, 4342):
		Sim.new_map(seed, "small")
		if not lane(int(Roll.DISTANCE) + 2, 40).is_empty() and not lane(1, 1).is_empty():
			break
	Props.list.clear()

	# --- A clear run: eight tiles, fast, low and silent ---------------------
	var l := lane(int(Roll.DISTANCE) + 2, 40)
	check(not l.is_empty(), "hay un pasillo recto con sitio para rodar")
	var p := fresh_thief(l[0])
	var x0 := p.x
	var y0 := p.y
	var step := Sim.step_thief(p, {"space": true}, DT, "wasd")
	check(step.roll == "start" and p.rolling and p.posture == 1.0, "Espacio empieza a rodar, y ya va tan bajo como a gatas")
	var t := DT
	var low := true
	var quiet := true
	var still_y := true
	var px := p.x
	var py := p.y
	while p.rolling and t < 3.0:
		# Holding up and the roll key again: no steering, no second roll.
		px = p.x
		py = p.y
		step = Sim.step_thief(p, {"space": true, "w": true}, DT, "wasd")
		t += DT
		low = low and p.posture >= Sim.STANDING and p.crouched
		quiet = quiet and Hearing.thief_noise(px, py, p, step.entered_cover, step.bumped, Sim.TOP_SPEED) == null
		still_y = still_y and absf(p.y - y0) < 0.001
	var went := p.x - x0
	check(absf(went - Roll.DISTANCE) < 0.05, "rueda %.1f casillas (%.2f)" % [Roll.DISTANCE, went])
	check(absf(t - Roll.SECONDS) < 0.05, "en %.2f s (%.2f)" % [Roll.SECONDS, t])
	check(Roll.DISTANCE >= 7.0, "rueda lejos: %.0f casillas" % Roll.DISTANCE)
	check(Roll.SPEED > Sim.TOP_SPEED * 1.15, "rodando se va más rápido que corriendo (%.1f frente a %.1f casillas/s)" % [Roll.SPEED, Sim.TOP_SPEED])
	check(Sim.TOP_SPEED * Roll.SECONDS < Roll.DISTANCE - 1.0, "en lo que rueda, corriendo se llega menos lejos (%.1f frente a %.1f casillas)" % [Sim.TOP_SPEED * Roll.SECONDS, Roll.DISTANCE])
	check(low, "mientras rueda cuenta como agachado para la vista")
	check(quiet, "rodando no hace ruido de pasos")
	check(still_y, "no se puede girar mientras rueda")
	check(step.roll == "done" and step.bumped == "" and p.dizzy > 0.0, "al acabar se queda un momento en el suelo, sin golpe")
	check(Hearing.thief_noise(px, py, p, false, step.bumped, Sim.TOP_SPEED) == null, "una voltereta limpia no hace ruido")
	check(Sim.view_posture(p) == 1.0, "tras una voltereta limpia sigue a gatas para la vista")
	check(not p.stars and Roll.pose(p) == "", "sin chocar no ve estrellas: se queda a gatas, no tumbado")

	# Down: can't move, can't roll again, and a little slow to get up.
	var down := time_down(p)
	check(not down.rolled_again, "no se puede encadenar otra rodada en el suelo ni levantándose")
	check(down.low, "mientras está en el suelo sigue a gatas (cuenta como agachado)")
	check(not down.starry, "y en ningún momento salen estrellas")
	check(down.t > Sim.CROUCH_SECONDS + 0.2, "tarda más en levantarse que de gatas (%.1f s frente a %.1f)" % [down.t, Sim.CROUCH_SECONDS])
	check(absf(down.t - (Roll.SETTLE_SECONDS + Roll.RISE_SECONDS)) < 0.1, "%.1f s a gatas y luego se levanta en %.1f s (%.1f s en total)" % [Roll.SETTLE_SECONDS, Roll.RISE_SECONDS, down.t])
	check(down.t < 2.0, "pero no demasiado: menos de 2 s en el suelo")
	check(not p.crouched and p.posture == 0.0 and p.dizzy == 0.0, "acaba de pie")

	# From all fours it rolls too, and still ends up on its feet.
	var q := fresh_thief(l[0])
	q.crouched = true
	q.posture = 1.0
	Sim.step_thief(q, {"space": true}, DT, "wasd")
	check(q.rolling, "se puede rodar a gatas")
	for k in 600:
		Sim.step_thief(q, {}, DT, "wasd")
	check(not q.rolling and q.dizzy == 0.0 and not q.crouched and q.posture == 0.0, "y también acaba de pie")

	# Caught or gone: no rolling.
	var o := fresh_thief(l[0])
	o.out = true
	Sim.step_thief(o, {"space": true}, DT, "wasd")
	check(not o.rolling, "pillado no rueda")
	var s := fresh_thief(l[0])
	s.safe = true
	check(not Roll.start(s), "fuera del museo no rueda")

	# The other thieves' keys: Enter for P2, and both on your own.
	var p2 := fresh_thief(l[0])
	Sim.step_thief(p2, {"space": true}, DT, "arrows")
	check(not p2.rolling, "Espacio no hace rodar a P2")
	Sim.step_thief(p2, {"enter": true}, DT, "arrows")
	check(p2.rolling, "Enter hace rodar a P2")
	var solo := fresh_thief(l[0])
	Sim.step_thief(solo, {"enter": true}, DT, "solo")
	check(solo.rolling, "solo, Enter también rueda")

	# --- Into a wall: stopped dead, and a thump ----------------------------
	var w := lane(1, 1)
	check(not w.is_empty(), "hay una casilla con pared a dos pasos")
	var b := fresh_thief(w[0])
	var bx := b.x
	var noises: Array[SoundEvent] = []
	var crashed := false
	for k in 60:
		var before := Vector2(b.x, b.y)
		step = Sim.step_thief(b, {"space": true}, DT, "wasd")
		var n := Hearing.thief_noise(before.x, before.y, b, step.entered_cover, step.bumped, Sim.TOP_SPEED)
		if n:
			noises.append(n)
		if step.bumped == "roll":
			crashed = true
			break
	var face: float = w[0].x + 2.0
	check(crashed and not b.rolling and b.dizzy > 0.0, "contra la pared se para en seco y queda mareado")
	check(b.x - bx < Roll.DISTANCE - 1.0 and absf(b.x - (face - Sim.BODY)) < 0.05, "se queda pegado a la pared (x=%.2f, cara %.1f)" % [b.x, face])
	check(noises.size() == 1 and noises[0].kind == "roll_bump" and noises[0].loudness >= Hearing.LOUDNESS["armour"] and "roll_bump" in Hearing.CRASHES, "y hace mucho ruido, como una armadura que se cae")
	check(noises.size() == 1 and noises[0].loudness > Hearing.crash_loudness(Sim.TOP_SPEED, Sim.TOP_SPEED, false), "más que chocar corriendo contra una pared")

	# A guard a few tiles off hears it and comes to look.
	var g := Sim.new_guards(1)[0]
	g.x = b.x - 4.0
	g.y = b.y
	g.dir = PI
	g.memory = null
	Sim.step_guard(g, [] as Array[Thief], noises, 2000.0, DT)
	check(g.suspicion >= 1 and g.memory != null and g.memory.kind == "noise", "un guardia cerca lo oye y va a mirar")

	# Rolling right up against the wall: the thump is straight away.
	var c := fresh_thief(w[0])
	c.x = face - Sim.BODY
	step = Sim.step_thief(c, {"space": true}, DT, "wasd")
	check(step.bumped == "roll" and c.dizzy > 0.0, "rodar pegado a la pared es golpe inmediato")

	# Crashed: flat out seeing stars, and a long while getting up.
	check(b.stars and Roll.pose(b) == "dizzy", "tras el golpe queda tumbado viendo estrellas")
	var hurt := time_down(b)
	check(not hurt.rolled_again, "mareado tampoco se puede volver a rodar")
	check(hurt.low, "mareado sigue tumbado en el suelo (el dibujo)")
	check(hurt.starry, "las estrellas giran mientras está mareado")
	check(absf(hurt.t - (Roll.DIZZY_SECONDS + Roll.RISE_SECONDS)) < 0.1, "mareo %.1f s y luego se levanta en %.1f s (%.1f s en total)" % [Roll.DIZZY_SECONDS, Roll.RISE_SECONDS, hurt.t])
	check(hurt.t > down.t + 1.0, "mucho más en el suelo que tras una rodada limpia (%.1f s frente a %.1f)" % [hurt.t, down.t])
	check(Roll.DIZZY_SECONDS >= 1.5 and Roll.DIZZY_SECONDS <= 2.0, "aturdido entre 1,5 y 2 s (%.1f)" % Roll.DIZZY_SECONDS)
	check(hurt.t > 2.8 and hurt.t < 3.2, "unos 3 s en el suelo")
	check(not b.stars and Roll.pose(b) == "" and not b.crouched and b.posture == 0.0, "y se levanta sin estrellas")

	view_and_stun(l[0], int(l[1]))
	sack(l[0])

	quit(qa.summary())


## A calm guard on the thief's west, facing east, at 5 tiles: past the bright
## pool of its torch (3.5), where only someone standing is picked out.
func dim_guard(p: Thief) -> Guard:
	var g := Sim.new_guards(1)[0]
	g.x = p.x - 5.0
	g.y = p.y
	g.dir = 0.0
	g.alert = false
	return g


## What the guard's eyes make of the thief, rolling, settling and stunned,
## against standing up, in the dim throw of its torch.
func view_and_stun(at: Vector2i, run: int) -> void:
	var stand := fresh_thief(at)
	stand.x += 6.0
	var g := dim_guard(stand)
	var lit := Museum.is_lit(stand.x, stand.y)
	check(lit or Sim.can_see(g, stand), "de pie y a 5 casillas, la linterna lo ve")
	var crouched := fresh_thief(at)
	crouched.x = stand.x
	crouched.crouched = true
	crouched.posture = 1.0
	check(lit or not Sim.can_see(g, crouched), "agachado, a 5 casillas no lo ve (la ventaja de agacharse)")

	# Rolling counts as crouched: the same guard does not see the ball.
	var roller := fresh_thief(at)
	roller.x = stand.x
	g = dim_guard(roller)
	Sim.step_thief(roller, {"space": true}, DT, "wasd")
	g.x = roller.x - 5.0
	check(roller.rolling and (lit or not Sim.can_see(g, roller)), "rodando no lo ve a 5 casillas, como a gatas")

	# Rolled into the wall (a tile and a bit ahead): the crash, the stun, in view.
	var c := fresh_thief(at)
	c.x = at.x + run - 0.5
	g = dim_guard(c)
	var noise: SoundEvent = null
	var step := {}
	for k in 90:
		var before := Vector2(c.x, c.y)
		step = Sim.step_thief(c, {"space": k == 0}, DT, "wasd")
		var n := Hearing.thief_noise(before.x, before.y, c, step.entered_cover, step.bumped, Sim.TOP_SPEED)
		if n:
			noise = n
		if step.bumped == "roll":
			break
	check(step.bumped == "roll" and noise != null and noise.kind == "roll_bump", "chocar rodando suena fuerte (roll_bump)")
	check(noise != null and noise.loudness >= Hearing.LOUDNESS["armour"], "tanto como una armadura al caer (%.0f)" % (noise.loudness if noise else 0.0))
	check(c.dizzy == Roll.DIZZY_SECONDS and c.stars and Roll.pose(c) == "dizzy", "y queda aturdido %.1f s con estrellas" % Roll.DIZZY_SECONDS)
	check(Sim.view_posture(c) == 0.0, "aturdido cuenta como de pie para la vista")
	check(lit or Sim.can_see(g, c), "aturdido lo ve la linterna a 5 casillas")
	# Nothing moves it or does anything during the stun, and it is quiet
	# (the noise was the crash).
	var spot := Vector2(c.x, c.y)
	var moved := false
	var acted := false
	var t := 0.0
	while c.dizzy > 0.05 and t < 3.0:
		var s2 := Sim.step_thief(c, {"a": true, "w": true, "space": int(t * 10) % 2 == 0, "c": int(t * 7) % 2 == 0}, DT, "wasd")
		t += DT
		moved = moved or Vector2(c.x, c.y).distance_to(spot) > 0.001
		acted = acted or c.rolling or s2.roll == "start" or s2.bumped != ""
	check(not moved and not acted, "durante el aturdimiento no se mueve ni rueda")
	check(absf(t - Roll.DIZZY_SECONDS) < 0.1, "dura lo que dice (%.2f s)" % t)


## The thief with the sack does not roll; the others do.
func sack(at: Vector2i) -> void:
	var was := Heist.carrier
	Heist.carrier = "p1"
	var carrier := fresh_thief(at)
	carrier.id = "p1"
	var other := fresh_thief(at)
	other.id = "p2"
	var step := Sim.step_thief(carrier, {"space": true}, DT, "wasd")
	check(not carrier.rolling and not Roll.can_start(carrier) and step.roll == "sack", "con el saco del botín no se rueda")
	check(carrier.roll_key and not carrier.rolling and carrier.dizzy == 0.0 and carrier.posture == 0.0, "y la tecla no hace nada más: no se agacha ni se aturde")
	Sim.step_thief(other, {"space": true}, DT, "wasd")
	check(other.rolling, "el compañero sin el saco sí rueda")
	Heist.carrier = ""
	Sim.step_thief(carrier, {}, DT, "wasd")
	Sim.step_thief(carrier, {"space": true}, DT, "wasd")
	check(carrier.rolling, "sin el saco, el mismo ladrón rueda")
	Heist.carrier = was
