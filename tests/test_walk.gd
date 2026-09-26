extends SceneTree
## Walking slowly and crawling: holding the slow key walks at Sim.SLOW_SPEED,
## never winding up to a run, standing and quieter than a walk; on all fours
## you go at Sim.CROUCH_SPEED without a sound.
##   godot --headless --script tests/test_walk.gd

const DT := 1.0 / 60.0

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


func thief_at(x: float, y: float) -> Thief:
	var p := Sim.new_thief()
	p.x = x
	p.y = y
	return p


## Walks for this many seconds holding these keys: {distance, top (fastest
## speed), sprinted, loudest (step noise), noises (how many steps made one)}.
func walk(p: Thief, keys: Dictionary, seconds: float, scheme := "wasd") -> Dictionary:
	var x0 := p.x
	var y0 := p.y
	var top := 0.0
	var sprinted := false
	var loudest := 0.0
	var noises := 0
	for f in int(round(seconds / DT)):
		var px := p.x
		var py := p.y
		var step := Sim.step_thief(p, keys, DT, scheme)
		top = maxf(top, p.speed)
		sprinted = sprinted or p.sprinting
		var noise := Hearing.thief_noise(px, py, p, step.entered_cover, step.bumped, Sim.TOP_SPEED)
		if noise:
			noises += 1
			loudest = maxf(loudest, noise.loudness)
	return {"distance": Museum.dist(x0, y0, p.x, p.y), "top": top, "sprinted": sprinted, "loudest": loudest, "noises": noises}


func _init() -> void:
	open_room()

	print("Andar lento")
	var slow := thief_at(2.5, 8.5)
	var s := walk(slow, {"d": true, "lalt": true}, 3.0)
	check(is_equal_approx(s.top, Sim.SLOW_SPEED) and absf(s.distance - Sim.SLOW_SPEED * 3.0) < 0.05,
		"anda a %.1f casillas/s (%.2f casillas en 3 s)" % [Sim.SLOW_SPEED, s.distance])
	check(not s.sprinted and slow.slow, "no acelera hasta correr")
	check(slow.posture == 0.0, "va de pie")
	var watcher: Guard = Sim.new_guards(1)[0]
	watcher.x = slow.x - 3.0
	watcher.y = slow.y
	watcher.dir = 0.0
	check(Sim.can_see(watcher, slow), "y le ven de pie")

	# The same room, the same start, the same key held down: only the slow key differs.
	var normal := thief_at(2.5, 8.5)
	var n := walk(normal, {"d": true}, 3.0)
	var creep := thief_at(2.5, 8.5)
	var c := walk(creep, {"d": true}, DT * 2)
	check(s.noises > 0 and s.loudest > 0.0, "sus pasos se oyen (%.2f casillas)" % s.loudest)
	check(s.loudest < c.loudest * 0.6, "más bajo que el paso más suave andando (%.2f frente a %.2f)" % [s.loudest, c.loudest])
	check(s.loudest < n.loudest * 0.25, "mucho más bajo que andar 3 s hasta correr (%.2f frente a %.2f)" % [s.loudest, n.loudest])
	check(n.distance > s.distance * 2.0, "andando normal se llega mucho más lejos (%.1f frente a %.1f)" % [n.distance, s.distance])

	print("Frenar al andar lento")
	var runner := thief_at(2.5, 8.5)
	walk(runner, {"d": true}, 2.0)
	var was := runner.speed
	walk(runner, {"d": true, "lalt": true}, 0.2)
	var braking := runner.speed
	walk(runner, {"d": true, "lalt": true}, 0.8)
	check(was > Sim.RUN_THRESHOLD and braking > Sim.SLOW_SPEED and braking < was, "corriendo, frena poco a poco (%.1f → %.1f)" % [was, braking])
	check(is_equal_approx(runner.speed, Sim.SLOW_SPEED) and not runner.sprinting, "y en un segundo va despacio")
	walk(runner, {"d": true}, 0.1)
	check(not runner.slow and runner.speed >= Sim.CREEP, "al soltar vuelve a andar")

	print("Teclas")
	var p1 := thief_at(2.5, 8.5)
	walk(p1, {"d": true, "ralt": true}, 1.0, "wasd")
	check(not p1.slow and p1.speed > Sim.SLOW_SPEED, "P1 no anda lento con el Alt de P2")
	var p2 := thief_at(2.5, 8.5)
	walk(p2, {"right": true, "ralt": true}, 1.0, "arrows")
	check(p2.slow and is_equal_approx(p2.speed, Sim.SLOW_SPEED), "P2 anda lento con el Alt derecho")
	for key in ["lalt", "ralt"]:
		var solo := thief_at(2.5, 8.5)
		walk(solo, {"d": true, key: true}, 1.0, "solo")
		check(solo.slow and is_equal_approx(solo.speed, Sim.SLOW_SPEED), "solo vale cualquier Alt (%s)" % key)
	for scheme in Sim.SCHEMES:
		check((Sim.SCHEMES[scheme] as Dictionary).has("slow"), "%s tiene tecla de andar lento" % scheme)

	print("A gatas")
	var crawler := thief_at(2.5, 8.5)
	Sim.step_thief(crawler, {"c": true}, DT, "wasd")
	walk(crawler, {}, Sim.CROUCH_SECONDS + 0.1)
	check(crawler.posture >= 1.0, "a gatas del todo")
	var k := walk(crawler, {"d": true}, 2.0)
	check(is_equal_approx(k.top, Sim.CROUCH_SPEED) and absf(k.distance - Sim.CROUCH_SPEED * 2.0) < 0.05,
		"gatea a %.1f casillas/s (%.2f casillas en 2 s)" % [Sim.CROUCH_SPEED, k.distance])
	check(Sim.CROUCH_SPEED > Sim.SLOW_SPEED and Sim.CROUCH_SPEED < Sim.RUN_THRESHOLD, "más rápido que andar lento, lejos de correr")
	check(k.noises == 0, "sin hacer ruido")
	var k2 := walk(crawler, {"d": true, "lalt": true}, 1.0)
	check(not crawler.slow and absf(k2.distance - Sim.CROUCH_SPEED) < 0.05, "a gatas, la tecla de andar lento no cambia nada")

	if failures.is_empty():
		print("OK: andar lento y a gatas")
		quit(0)
	else:
		printerr("%d fallos" % failures.size())
		quit(1)
