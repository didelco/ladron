extends SceneTree
## The minigames on their own (scenes/minigames): each played by a script,
## the way a good hand and a clumsy one would. godot --headless --script tests/test_minigames.gd

var failures: Array[String] = []
const DT := 1.0 / 60


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


func input(tap := Vector2i.ZERO, hold := Vector2.ZERO, act := false, act_held := false, leave := false) -> Dictionary:
	return {"tap": tap, "hold": hold, "act": act, "act_held": act_held, "leave": leave}


## The safe played well: turn towards the number, a tap at a time when
## close, press when the click is loudest.
func play_safe(g: MgSafe, careless := false) -> float:
	var t := 0.0
	var wait := 0.0
	while not g.over and t < 60.0:
		t += DT
		wait -= DT
		if wait > 0.0:
			g.feed(input(), DT)
			continue
		var d := MgSafe._diff(float(g.combo[g.got]), g.reading())
		if absf(d) <= MgSafe.ON and not careless:
			g.feed(input(Vector2i.ZERO, Vector2.ZERO, true), DT)
			wait = 0.15
		elif careless and randf() < 0.05:
			g.feed(input(Vector2i.ZERO, Vector2.ZERO, true), DT)
		elif absf(d) > 3.0:
			g.feed(input(Vector2i.ZERO, Vector2(signf(d), 0)), DT)
		else:
			g.feed(input(Vector2i(int(signf(d)), 0)), DT)
			wait = 0.12
	return t


func _init() -> void:
	Text.setup()
	print("Caja fuerte")
	var s := MgSafe.new(3).setup(7)
	var done := [false]
	s.finished.connect(func(ok: bool) -> void: done[0] = ok)
	var t := play_safe(s)
	check(done[0] and s.progress == 1.0, "se abre (%.1f s)" % t)
	check(t >= 1.5 and t <= 12.0, "bien jugada, entre 1,5 y 12 s (%.1f s)" % t)
	var one := MgSafe.new(1).setup(3)
	check(play_safe(one) < t, "con un número, más rápida")
	var shaky := MgSafe.new(3).setup(7, 1.0)
	var ts := play_safe(shaky)
	check(shaky.over, "con alerta, también se abre (%.1f s)" % ts)
	var wrong := MgSafe.new(3).setup(11)
	for k in 30:
		wrong.feed(input(Vector2i.ZERO, Vector2.ZERO, true), DT * 3)
	check(not wrong.over and wrong.got <= 1, "pulsar a lo loco no la abre (no se falla, se pierde tiempo)")
	var gone := MgSafe.new(3).setup(5)
	var left := [true]
	gone.finished.connect(func(ok: bool) -> void: left[0] = ok)
	gone.feed(input(Vector2i.ZERO, Vector2.ZERO, false, false, true), DT)
	check(gone.over and gone.left and not left[0], "C: salir sin abrirla")

	print("Ganzúa")
	var l := MgLockpick.new(4).setup(2)
	t = 0.0
	while not l.over and t < 30.0:
		t += DT
		var holding: bool = l.height < l.bands[l.done] - 0.01
		l.feed(input(Vector2i.ZERO, Vector2.ZERO, false, holding), DT)
	check(l.over and l.progress == 1.0, "se abre soltando en la línea (%.1f s)" % t)
	var early := MgLockpick.new(2).setup(2)
	early.feed(input(Vector2i.ZERO, Vector2.ZERO, false, true), DT)
	early.feed(input(), DT)
	check(early.done == 0 and not early.over, "soltar antes de tiempo: el pin cae, sin fallo")

	print("Alarma")
	var w := MgWires.new(5, 3).setup(4)
	t = 0.0
	while not w.over and t < 30.0:
		t += DT
		var want: int = w.order[w.step]
		if w.at != want:
			w.feed(input(Vector2i(signi(want - w.at), 0)), DT)
		else:
			w.feed(input(Vector2i.ZERO, Vector2.ZERO, true), DT)
	check(w.over and w.progress == 1.0, "tres cables en orden (%.1f s)" % t)
	var bad := MgWires.new(5, 3).setup(4)
	bad.at = (bad.order[0] + 1) % bad.wires
	bad.feed(input(Vector2i.ZERO, Vector2.ZERO, true), DT)
	check(not bad.cut[bad.at] and not bad.over, "cable equivocado: chispa, sin cortar")

	print("Rejilla")
	var r := MgGrate.new(4).setup(1)
	var side := 1
	t = 0.0
	while not r.over and t < 30.0:
		t += DT
		r.feed(input(Vector2i(side, 0)), DT)
		side = -side
	check(r.over and r.progress == 1.0, "cuatro tornillos alternando (%.1f s)" % t)
	var same := MgGrate.new(1).setup(1)
	for k in 20:
		same.feed(input(Vector2i(1, 0)), DT)
	check(same.progress < 0.2, "girar siempre al mismo lado no sirve")

	print("Estornudo")
	var n := MgSneeze.new().setup(9)
	var heard := [0.0]
	n.noise.connect(func(loud: float) -> void: heard[0] = loud)
	t = 0.0
	while not n.over and t < 60.0:
		t += DT
		n.feed(input(), DT)
	check(n.over and heard[0] == MgSneeze.SNEEZE, "sin hacer nada, estornudas (%.1f s) y se oye" % t)
	var careful := MgSneeze.new().setup(9)
	t = 0.0
	var pinching := false
	while not careful.over and t < 12.0:
		t += DT
		if careful.tickle > 0.6 and careful.breath > 0.3:
			pinching = true
		elif careful.tickle < 0.15 or careful.breath < 0.2:
			pinching = false
		careful.feed(input(Vector2i.ZERO, Vector2.ZERO, false, pinching), DT)
	check(not careful.over, "tapándote a tiempo, aguantas 12 s")
	var gasp := MgSneeze.new().setup(9)
	heard[0] = 0.0
	gasp.noise.connect(func(loud: float) -> void: heard[0] = loud)
	t = 0.0
	while not gasp.over and t < 10.0:
		t += DT
		gasp.feed(input(Vector2i.ZERO, Vector2.ZERO, false, true), DT)
	check(gasp.over and heard[0] == MgSneeze.GASP, "tapado sin respirar: boqueas (más flojo)")
	var dusty := MgSneeze.new().setup(9, 1.0)
	t = 0.0
	while not dusty.over and t < 60.0:
		t += DT
		dusty.feed(input(), DT)
	var clean := MgSneeze.new().setup(9)
	var tc := 0.0
	while not clean.over and tc < 60.0:
		tc += DT
		clean.feed(input(), DT)
	check(t < tc, "con más polvo, antes (%.1f s frente a %.1f s)" % [t, tc])

	print("Pose")
	var p := MgPose.new().setup(5)
	t = 0.0
	while not p.over and t < 60.0:
		t += DT
		p.feed(input(), DT)
	check(p.over, "sin corregir, te tambaleas (%.1f s)" % t)
	var steady := MgPose.new().setup(5)
	t = 0.0
	while not steady.over and t < 15.0:
		t += DT
		steady.feed(input(Vector2i.ZERO, Vector2(clampf(-steady.needle * 3.0 - steady._vel, -1.0, 1.0), 0)), DT)
	check(not steady.over, "corrigiendo, aguantas 15 s")

	if failures.is_empty():
		print("OK: minijuegos")
	else:
		print("FALLAN %d" % failures.size())
	quit(1 if not failures.is_empty() else 0)
