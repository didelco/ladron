extends SceneTree
## Empty pedestals: up with the action key from beside one, a statue no guard
## sees; any way down steps off onto free floor; climbing up in plain sight
## fools nobody, and a guard beside a blown statue takes you down.
##   godot --headless --script tests/test_plinths.gd

const DT := 1.0 / 60.0

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func _init() -> void:
	# A museum with a pedestal that has two free tiles in a row beside it
	# (to be watched from).
	var none: Array[Vector2i] = []
	var t := Vector2i(-1, -1)
	var d := Vector2i.ZERO
	for sd in range(4242, 4342):
		Sim.new_map(sd, "medium")
		Hideouts.spread(sd, none, true, false)
		check(not Plinths.list.is_empty(), "hay pedestales (%d)" % Plinths.list.size())
		for c in Plinths.list:
			check(Museum.is_cover(c.x + 0.5, c.y + 0.5), "el pedestal %s ocupa una casilla de mueble" % c)
			for dd in Museum.DIRS:
				if t.x < 0 and Museum.tile_at(c.x + dd.x + 0.5, c.y + dd.y + 0.5) == Tiles.FLOOR \
						and Museum.tile_at(c.x + dd.x * 2 + 0.5, c.y + dd.y * 2 + 0.5) == Tiles.FLOOR:
					t = c
					d = dd
		if t.x >= 0:
			break
	var beside: Vector2i = t + d

	var p := Sim.new_thief()
	p.x = beside.x + 0.5
	p.y = beside.y + 0.5
	var thieves: Array[Thief] = [p]
	check(Plinths.within_reach(p, thieves) == t, "al lado, el pedestal está a mano")

	# A guard looking straight at the pedestal from two tiles off, the far side.
	var g := Guard.new()
	g.x = t.x + 0.5 + d.x * 3
	g.y = t.y + 0.5 + d.y * 3
	g.dir = atan2(-d.y, -d.x)
	var guards: Array[Guard] = [g]
	var nobody: Array[Guard] = []

	# Climbing unseen: a statue.
	Plinths.climb(p, t, nobody)
	check(p.posing and not p.pose_blown, "sube sin que le vean")
	check(Vector2(p.x, p.y) == Vector2(t) + Vector2(0.5, 0.5), "de pie en medio del pedestal")
	check(Plinths.within_reach(p, thieves) == null, "subido, no hay otro pedestal que subir")
	check(not Sim.can_see(g, p), "posando, el guardia ve una estatua")
	check(not Sim.caught(guards, p), "y no le pilla")
	# Keys that do nothing up there.
	var step := Sim.step_thief(p, {"c": true, "space": true}, DT, "wasd")
	check(p.posing and not p.rolling and not p.crouched, "agacharse o rodar no le bajan")
	check(not Heist.at_case(p), "posando no fuerza vitrinas")

	# Down the way it came.
	var keys := {}
	keys[{Vector2i(1, 0): "d", Vector2i(-1, 0): "a", Vector2i(0, 1): "s", Vector2i(0, -1): "w"}[d]] = true
	step = Sim.step_thief(p, keys, DT, "wasd")
	check(not p.posing and step.get("plinth", "") == "down", "una dirección le baja")
	check(Vector2(p.x, p.y) == Vector2(beside) + Vector2(0.5, 0.5), "baja a la casilla libre de ese lado")

	# A way with no floor: stays up.
	var walled := Vector2i.ZERO
	for dd in Museum.DIRS:
		if Museum.tile_at(t.x + dd.x + 0.5, t.y + dd.y + 0.5) != Tiles.FLOOR:
			walled = dd
	if walled != Vector2i.ZERO:
		Plinths.climb(p, t, nobody)
		var k2 := {}
		k2[{Vector2i(1, 0): "d", Vector2i(-1, 0): "a", Vector2i(0, 1): "s", Vector2i(0, -1): "w"}[walled]] = true
		Sim.step_thief(p, k2, DT, "wasd")
		check(p.posing, "hacia una pared o un mueble no baja")
		p.posing = false

	# Seen climbing: blown, seen, and taken down from beside it.
	p.x = beside.x + 0.5
	p.y = beside.y + 0.5
	var watcher := Guard.new()
	watcher.x = beside.x + 0.5 + d.x
	watcher.y = beside.y + 0.5 + d.y
	watcher.dir = atan2(-d.y, -d.x)
	var watchers: Array[Guard] = [watcher]
	check(Sim.can_see(watcher, p), "(el guardia le ve antes de subir)")
	Plinths.climb(p, t, watchers)
	check(p.pose_blown, "visto subiendo, la estatua no cuela")
	check(not Sim.caught(watchers, p), "a dos casillas aún no le alcanza")
	watcher.x = beside.x + 0.5
	watcher.y = beside.y + 0.5
	check(Sim.caught(watchers, p), "y un guardia al lado le baja del pedestal")

	# In the editor, one more piece: stood on a case, saved, loaded, played.
	check(Themes.catalogue().any(func(e): return e[0] == "exhibit:plinth"), "el editor tiene el pedestal en su catálogo")
	var m := MapFile.generated(4242, "small")
	var spot := Vector2i(-1, -1)
	for y in m.h:
		for x in m.w:
			var c := Vector2i(x, y)
			if spot.x < 0 and m.at(c) == Tiles.COVER and m.big_at(c).is_empty() and c != m.piece:
				spot = c
	m.exhibits[spot] = "plinth"
	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(back.exhibits.get(spot, "") == "plinth", "el pedestal se guarda y se carga con el mapa")
	back.apply()
	var hand: Array[Vector2i] = [spot]
	Plinths.put(hand)
	check(Plinths.list == hand, "en la partida es un pedestal donde se puso")

	quit(qa.summary())
