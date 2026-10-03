extends SceneTree
## El código de colores (ColourCode): la mecánica de la prueba ESCONDITE
## del dojo (BenchTrial, SqueezeGame): nunca se reparte ya resuelto, cambiar
## dos bolas de sitio cambia solo esas dos, se detecta cuando el orden es el
## del código, y cada nivel tiene sus bolas (3, 4, 5) y su distancia.
##   godot --headless --script tests/test_codigo_colores.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func rng(seed_: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	return r


func _init() -> void:
	print("El reparto")
	check(ColourCode.balls_for(0) == 3 and ColourCode.balls_for(1) == 4 and ColourCode.balls_for(2) == 5, "bolas por nivel: 3 fácil, 4 medio, 5 difícil")
	check(ColourCode.swaps_for(0, 0) == 1 and ColourCode.swaps_for(1, 0) == 2 and ColourCode.swaps_for(2, 0) == 3, "cambios mínimos por nivel: 1, 2, 3")
	check(ColourCode.swaps_for(0, 1) == 2 and ColourCode.swaps_for(1, 1) == 3 and ColourCode.swaps_for(2, 1) == 4, "un mueble apretado pide un cambio más: 2, 3, 4")
	check(ColourCode.COLOURS.size() >= ColourCode.BALLS_LEVEL.max(), "hay colores para el código más largo")
	var solved_at_start := 0
	var too_near := 0
	var bad_deal := 0
	var deals := 0
	for n in [2, 3, 4, 5]:
		for min_swaps in range(1, n):
			for s in 200:
				var c := ColourCode.make(n, min_swaps, rng(s * 31 + n * 7 + min_swaps))
				deals += 1
				if c.solved():
					solved_at_start += 1
				if c.distance() < min_swaps:
					too_near += 1
				var sorted_t := c.target.duplicate()
				sorted_t.sort()
				var sorted_b := c.balls.duplicate()
				sorted_b.sort()
				var all := []
				for i in n:
					all.append(i)
				if c.target.size() != n or c.balls.size() != n or sorted_t != all or sorted_b != all:
					bad_deal += 1
	check(deals > 1000 and solved_at_start == 0, "%d repartos de 2 a 5 bolas: ninguno sale resuelto de entrada (%d)" % [deals, solved_at_start])
	check(too_near == 0, "... todos a la distancia pedida por lo menos (%d a menos)" % too_near)
	check(bad_deal == 0, "... y siempre las mismas bolas que colores pide el código, una de cada (%d mal)" % bad_deal)
	# A code three balls, one swap away, with the dice never giving one: turned round by hand.
	var turned := ColourCode.make(3, 2, rng(5))
	check(turned.distance() == 2 and not turned.solved(), "tres bolas a dos cambios: un ciclo de las tres (%s de %s)" % [turned.balls, turned.target])
	var same_a := ColourCode.make(5, 3, rng(99))
	var same_b := ColourCode.make(5, 3, rng(99))
	check(same_a.target == same_b.target and same_a.balls == same_b.balls, "los mismos dados, el mismo reparto")
	var a := ColourCode.make(5, 3, rng(1))
	var b := ColourCode.make(5, 3, rng(2))
	check(a.target != b.target or a.balls != b.balls, "otros dados, otro reparto")
	check(ColourCode.make(9, 1, rng(1)).balls.size() == ColourCode.COLOURS.size() and ColourCode.make(1, 1, rng(1)).balls.size() == 2, "las bolas se quedan entre 2 y los colores que hay")

	print("Los cambios")
	var c := ColourCode.new()
	c.target = [0, 1, 2, 3]
	c.balls = [1, 0, 3, 2]
	check(c.distance() == 2 and c.matched() == 0 and not c.solved(), "dos parejas cruzadas: a dos cambios, ninguna en su sitio")
	check(not c.pick(0) and c.picked == 0 and c.balls == [1, 0, 3, 2], "coger una bola la marca y no mueve nada")
	check(not c.pick(0) and c.picked == -1 and c.swaps == 0, "cogerla otra vez la suelta")
	c.pick(0)
	check(c.pick(1) and c.picked == -1 and c.balls == [0, 1, 3, 2] and c.swaps == 1, "coger otra: las dos cambian de sitio, las demás quietas")
	check(c.matched() == 2 and c.distance() == 1 and not c.solved(), "dos en su sitio, a un cambio")
	c.swap(3, 2)
	check(c.balls == [0, 1, 2, 3] and c.solved() and c.matched() == 4 and c.distance() == 0 and c.swaps == 2, "el último cambio: resuelto")
	c.swap(2, 2)
	c.swap(-1, 0)
	c.swap(0, 7)
	check(c.balls == [0, 1, 2, 3] and c.swaps == 2 and not c.pick(9), "cambiar una bola consigo misma o fuera de la fila no es nada")
	var cyc := ColourCode.new()
	cyc.target = [0, 1, 2, 3, 4]
	cyc.balls = [1, 2, 3, 4, 0]
	check(cyc.distance() == 4, "las cinco en rueda: a cuatro cambios")
	cyc.balls = [0, 1, 2, 3, 4]
	check(cyc.distance() == 0 and cyc.solved(), "en su sitio: a ninguno")
	cyc.balls = [1, 0, 2, 3, 4]
	check(cyc.distance() == 1, "una pareja cruzada: a uno")
	check(ColourCode.colour(0) == ColourCode.COLOURS[0] and ColourCode.colour(99) == ColourCode.COLOURS[-1], "el color de cada bola, sin salirse de la lista")

	print("Dentro del minijuego: la misma semilla y nivel reparten lo mismo")
	var sg1 := Minigame.make("squeeze", "bench", 0, {}, 7, 0) as SqueezeGame
	var sg2 := Minigame.make("squeeze", "bench", 0, {}, 7, 0) as SqueezeGame
	check(sg1.code.target == sg2.code.target and sg1.code.balls == sg2.code.balls and sg1.size() == 3, "la misma semilla y nivel: el mismo código de tres bolas")
	var tight := Minigame.make("squeeze", "bench", Hideouts.TIGHT.get("chest", 0), {}, 7, 2) as SqueezeGame
	check(tight.size() == 5 and tight.code.distance() >= 4, "el baúl, apretado, en difícil: cinco bolas a cuatro cambios")

	quit(qa.summary())
