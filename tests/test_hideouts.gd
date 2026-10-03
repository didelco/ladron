extends SceneTree
## Hideouts: in with the action key from beside a sarcophagus or a suit of
## armour, where no guard sees you; any way out steps onto free floor; getting
## in in plain sight fools nobody, and a guard beside it pulls you out; a
## suit of armour knocked over tips you out.
##   godot --headless --script tests/test_hideouts.gd

const DT := 1.0 / 60.0
const KEY := {Vector2i(1, 0): "d", Vector2i(-1, 0): "a", Vector2i(0, 1): "s", Vector2i(0, -1): "w"}

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


## Send the guard that knows away, looking the other way, and let it be:
## true if it comes back and catches the thief within 20 seconds.
func goes_for_it(g: Guard, p: Thief, near: Vector2i, d: Vector2i) -> bool:
	var far := near
	for k in range(1, 8):
		var n := near - d * k
		if Museum.tile_at(n.x + 0.5, n.y + 0.5) != Tiles.FLOOR:
			break
		far = n
	g.x = far.x + 0.5
	g.y = far.y + 0.5
	g.dir = atan2(-d.y, -d.x)
	g.path.clear()
	if g.seen_at.size() != Museum.w * Museum.h:
		g.seen_at = Watch.blank_sight()
	var guards: Array[Guard] = [g]
	var thieves: Array[Thief] = [p]
	var now := 1000.0
	for f in 20 * 60:
		now += 1000.0 / 60
		Sim.step_guard(g, thieves, [] as Array[SoundEvent], now, DT)
		if Sim.caught(guards, p):
			return true
	return false


## A medium museum with a sarcophagus in it, with room to watch it from:
## three free tiles in a row away from the first free tile beside it.
func with_sarcophagus() -> int:
	for sd in range(4242, 4642):
		Sim.new_map(sd, "medium")
		for b in Museum.big_pieces:
			if b.kind != "sarcophagus":
				continue
			var tiles: Array[Vector2i] = []
			var r: Rect2i = b.rect
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					tiles.append(Vector2i(x, y))
			var beside := Vector2i(-1, -1)
			var d := Vector2i.ZERO
			for t in tiles:
				for dd in Museum.DIRS:
					var n: Vector2i = t + dd
					if beside.x < 0 and not (n in tiles) and Museum.tile_at(n.x + 0.5, n.y + 0.5) == Tiles.FLOOR:
						beside = n
						d = -dd
			var room := true
			for k in range(1, 4):
				var o := beside - d * k
				room = room and Museum.tile_at(o.x + 0.5, o.y + 0.5) == Tiles.FLOOR
			if room:
				return sd
	return 4242


## A night as the game lays it out (main._lay_out): the museum, the job, the
## props, the pedestals and furniture, and what stands on every case.
func night(sd: int, size: String, shape := "") -> void:
	Sim.new_map(sd, size, -1, shape)
	Heist.plan_job(1, {}, 1, {})
	Plinths.list.clear()
	Hideouts.pieces.clear()
	if Sim.feature("props"):
		Props.place(sd, [Heist.exit, Heist.panel, Heist.panel2, Heist.start])
	else:
		Props.list.clear()
	Hideouts.spread(sd, [Heist.at] as Array[Vector2i], Sim.feature("plinths"), Sim.feature("hideouts"))
	Collection.lay_out()


func _init() -> void:
	Sim.custom = {}
	var sarcophagus_seed := with_sarcophagus()
	Sim.new_map(sarcophagus_seed, "medium")
	Props.list.clear()
	var sarcophagi := Hideouts.all().filter(func(s): return s.kind == "sarcophagus")
	check(not sarcophagi.is_empty(), "hay sarcófago en el museo (%d)" % sarcophagi.size())
	var s: Hideouts.Spot = sarcophagi[0]
	check(s.tiles.size() == 3, "el sarcófago ocupa tres casillas")

	# A free tile beside it, and the way from there into it.
	var beside := Vector2i(-1, -1)
	var d := Vector2i.ZERO
	for t in s.tiles:
		for dd in Museum.DIRS:
			var n: Vector2i = t + dd
			if beside.x < 0 and not (n in s.tiles) and Museum.tile_at(n.x + 0.5, n.y + 0.5) == Tiles.FLOOR:
				beside = n
				d = -dd
	var p := Sim.new_thief()
	p.x = beside.x + 0.5
	p.y = beside.y + 0.5
	var thieves: Array[Thief] = [p]
	check(Hideouts.within_reach(p, thieves) != null, "al lado, el sarcófago está a mano")

	# A guard looking at the thief's tile from two tiles off.
	var g := Guard.new()
	g.x = beside.x + 0.5 - d.x * 2
	g.y = beside.y + 0.5 - d.y * 2
	g.dir = atan2(d.y, d.x)
	var guards: Array[Guard] = [g]
	var nobody: Array[Guard] = []

	# In, unseen: gone.
	Hideouts.get_in(p, Hideouts.within_reach(p, thieves), nobody)
	check(p.hiding and not p.hide_blown, "se mete sin que le vean")
	check(Vector2(p.x, p.y) == s.middle(), "dentro, en medio del sarcófago")
	check(Hideouts.within_reach(p, thieves) == null, "dentro, no hay otro sitio donde meterse")
	check(not Sim.can_see(g, p), "escondido, el guardia no le ve")
	g.x = beside.x + 0.5
	g.y = beside.y + 0.5
	check(not Sim.caught(guards, p), "ni le pilla aunque pase al lado")
	g.x = beside.x + 0.5 - d.x * 2
	g.y = beside.y + 0.5 - d.y * 2
	Sim.step_thief(p, {"c": true, "space": true}, DT, "wasd")
	check(p.hiding and not p.rolling and not p.crouched, "agacharse o rodar no le sacan")
	check(not Heist.at_case(p), "escondido no fuerza vitrinas")
	var p2 := Sim.new_thief()
	p2.x = p.hide_entry.x
	p2.y = p.hide_entry.y
	var two: Array[Thief] = [p, p2]
	check(Hideouts.within_reach(p2, two) == null or not Hideouts.within_reach(p2, two).same(s), "ocupado, otro ladrón no cabe")

	# Out the way it came.
	var keys := {}
	keys[KEY[-d]] = true
	var step := Sim.step_thief(p, keys, DT, "wasd")
	check(not p.hiding and step.get("hideout", "") == "out", "una dirección le saca")
	check(Vector2(p.x, p.y) == Vector2(beside) + Vector2(0.5, 0.5), "sale a la casilla libre de ese lado, junto a donde entró")

	# Seen getting in: blown, and pulled out from beside it.
	var watcher := Guard.new()
	watcher.x = beside.x + 0.5 - d.x
	watcher.y = beside.y + 0.5 - d.y
	watcher.dir = atan2(d.y, d.x)
	var watchers: Array[Guard] = [watcher]
	check(Sim.can_see(watcher, p), "(el guardia le ve antes de meterse)")
	Hideouts.get_in(p, s, watchers)
	check(p.hide_blown, "visto metiéndose, no cuela")
	check(Sim.can_see(watcher, p), "y el guardia sigue sabiendo que está ahí")
	watcher.x = beside.x + 0.5 - d.x * 3
	watcher.y = beside.y + 0.5 - d.y * 3
	check(not Sim.caught(watchers, p), "desde lejos aún no le alcanza")
	watcher.x = beside.x + 0.5
	watcher.y = beside.y + 0.5
	check(Sim.caught(watchers, p), "y un guardia al lado le saca")
	check(watcher.knows == p.id and watcher.knows_kind == "sarcophagus", "el guardia se acuerda de que está en el sarcófago")
	var other := Guard.new()
	other.x = watcher.x
	other.y = watcher.y
	other.dir = watcher.dir
	var others: Array[Guard] = [other]
	check(not Sim.can_see(other, p) and not Sim.caught(others, p), "otro guardia que no lo vio pasa de largo")

	# The one that saw it goes to get it out, even from far and looking away.
	check(goes_for_it(watcher, p, beside, d), "el que lo vio vuelve a por él aunque ya no lo vea, y le saca")
	Hideouts.leave(p, beside, 0.0)
	Sim.known_thief(watcher, thieves)
	check(watcher.knows == "", "si ya no está ahí, el guardia lo olvida")

	# The same for a statue on a pedestal.
	var t: Vector2i = Vector2i(-1, -1)
	Hideouts.spread(4242, [] as Array[Vector2i], true, false)
	t = Plinths.list[0]
	var foot: Vector2i = Plinths._floor_beside(t)[0]
	var pd := t - foot
	p.x = foot.x + 0.5
	p.y = foot.y + 0.5
	var pw := Guard.new()
	pw.x = foot.x + 0.5 - pd.x
	pw.y = foot.y + 0.5 - pd.y
	pw.dir = atan2(pd.y, pd.x)
	Plinths.climb(p, t, [pw] as Array[Guard])
	check(pw.knows == p.id and pw.knows_kind == "plinth", "visto subiendo al pedestal, el guardia se acuerda")
	check(goes_for_it(pw, p, foot, pd), "y vuelve a por él y le baja")
	p.posing = false
	p.perch = Vector2i(-1, -1)
	Props.list.clear()
	p.x = beside.x + 0.5
	p.y = beside.y + 0.5

	# A suit of armour: in, and knocked over with it inside.
	Props.list.clear()
	Props.put("armour", beside)
	var suit: Props.Prop = Props.list[0]
	var spot := Hideouts.within_reach(p, thieves)
	check(spot != null and spot.kind == "armour", "junto a una armadura, se puede meter en ella")
	check(Props.within_reach(p) == suit, "(y también está a mano para tirarla)")
	Hideouts.get_in(p, spot, nobody)
	check(p.hiding and Vector2(p.x, p.y) == Vector2(suit.x, suit.y), "dentro de la armadura")
	check(Props.within_reach(p) == null, "desde dentro no se tira nada")
	suit.fallen = true
	check(Hideouts.all().is_empty() or not Hideouts.all().any(func(o): return o.prop == suit), "una armadura en el suelo ya no esconde")
	Hideouts.tip_out(p)
	check(not p.hiding and Museum.tile_at(p.x, p.y) == Tiles.FLOOR, "al caer la armadura, sale al suelo")

	# Furniture to hide in: a few on cases, each of its gallery's theme.
	Plinths.list.clear()
	Hideouts.spread(4242, [] as Array[Vector2i], false, true)
	check(Hideouts.pieces.size() >= 1, "hay muebles para esconderse (%d)" % Hideouts.pieces.size())
	for at in Hideouts.pieces:
		var kind: String = Hideouts.pieces[at]
		var room := Museum.room_at(at.x + 0.5, at.y + 0.5)
		check(Museum.is_cover(at.x + 0.5, at.y + 0.5) and not Plinths.is_plinth(at), "%s en %s: sobre una casilla de mueble" % [kind, at])
		check(room == null or Hideouts.PIECES[kind].theme == room.theme, "%s en una sala de su tema" % kind)
		check(ResourceLoader.exists("res://assets/models/%s.glb" % Hideouts.PIECES[kind].model), "%s tiene modelo" % kind)
	var cell: Vector2i = Hideouts.pieces.keys()[0]
	var door: Vector2i = Hideouts._floor_beside(cell)[0]
	p.x = door.x + 0.5
	p.y = door.y + 0.5
	var in_it := Hideouts.within_reach(p, thieves)
	check(in_it != null and in_it.kind == Hideouts.pieces[cell], "junto al mueble, está a mano")
	Hideouts.get_in(p, in_it, nobody)
	check(p.hiding and Vector2(p.x, p.y) == Vector2(cell) + Vector2(0.5, 0.5), "dentro del mueble")
	var out_keys := {}
	out_keys[KEY[door - cell]] = true
	# What was held getting in (the last wriggle, the way it came) does not
	# get it out again: that key is let go first.
	Sim.step_thief(p, out_keys, DT, "wasd")
	check(p.hiding, "la dirección que traía pulsada no lo saca")
	Sim.step_thief(p, {}, DT, "wasd")
	Sim.step_thief(p, out_keys, DT, "wasd")
	check(not p.hiding and Vector2(p.x, p.y) == Vector2(door) + Vector2(0.5, 0.5), "y sale por donde entró")
	for k in Hideouts.PIECES:
		check(Themes.is_piece(k) and Themes.catalogue().any(func(e): return e[0] == "exhibit:" + k and e[2] == "hide"), "%s está en el catálogo del editor" % k)

	# The new big pieces: in the generator, in their theme's gallery, and
	# something to hide in.
	var seen := {}
	for sd in range(1, 40):
		Sim.new_map(sd * 7, "large")
		for b in Museum.big_pieces:
			if b.kind in ["trojan_horse", "mammoth", "log", "car"]:
				seen[b.kind] = true
				var rr: Rect2i = b.rect
				var room := Museum.room_at(rr.position.x + rr.size.x / 2.0, rr.position.y + rr.size.y / 2.0)
				if room and room.theme != Themes.for_big(b.kind):
					check(false, "%s en una sala de %s" % [b.kind, room.theme])
		# Both of the ancient world's big pieces keep their gallery.
		var ancient := Museum.big_pieces.filter(func(b): return b.kind in ["sarcophagus", "trojan_horse"])
		for b in ancient:
			var rr: Rect2i = b.rect
			var room := Museum.room_at(rr.position.x + rr.size.x / 2.0, rr.position.y + rr.size.y / 2.0)
			if room and room.theme != "antiguo":
				check(false, "semilla %d: %s fuera de una sala del mundo antiguo" % [sd * 7, b.kind])
	for k in ["trojan_horse", "mammoth", "log", "car"]:
		check(seen.has(k), "el generador pone %s" % k)
		check(k in Hideouts.BIG, "%s es un escondite" % k)

	# Few, and far apart: each story night, the places to hide in and the
	# pedestals together, as many as the museum's size gives, none near
	# another; and every one of them there is to see a place to hide.
	var most := 0
	var closest := INF
	var mixed := 0
	for n in range(1, Story.count() + 1):
		var night := Story.level(n)
		Sim.custom = Story.tuning(n)
		var sd := Story.seed_for(n, 1)
		Sim.new_map(sd, night.size, -1, night.shape)
		Heist.plan_job(n, night.loot, 1, {})
		Plinths.list.clear()
		Hideouts.pieces.clear()
		if Sim.feature("props"):
			Props.place(sd, [Heist.exit, Heist.panel, Heist.panel2, Heist.start])
		else:
			Props.list.clear()
		Hideouts.spread(sd, [Heist.at] as Array[Vector2i], true, true)
		var spots := Hideouts.all()
		var at: Array[Vector2] = []
		for sp in spots:
			at.append(sp.middle())
		for pl in Plinths.list:
			at.append(Vector2(pl) + Vector2(0.5, 0.5))
		var budget := maxi(Hideouts.MIN, Museum.open_tiles.size() / Hideouts.PER_TILES)
		check(at.size() <= budget, "noche %d (%s): %d sitios de %d como mucho" % [n, night.size, at.size(), budget])
		most = maxi(most, at.size())
		for i in at.size():
			for j in range(i + 1, at.size()):
				closest = minf(closest, at[i].distance_to(at[j]))
		if not spots.is_empty() and not Plinths.list.is_empty():
			mixed += 1
		check(not Heist.at in Plinths.list and not Hideouts.pieces.has(Heist.at), "noche %d: nada sobre la vitrina del golpe" % n)
	check(closest >= Hideouts.APART, "ninguno a menos de %.0f casillas de otro (el más cerca, a %.1f)" % [Hideouts.APART, closest])
	check(mixed >= Story.count() - 2, "casi todas las noches hay escondites y pedestales (%d de %d)" % [mixed, Story.count()])
	check(most <= 10, "en el museo más grande, %d sitios" % most)

	# What looks like a place to hide is one: in generated museums of every
	# size and shape, every big piece to hide in and every suit of armour
	# standing is one (Hideouts.all); and there are few of them, far apart.
	Sim.custom = {}
	var nights := 0
	var not_hideouts := 0
	var over := 0
	var under := 0
	var near := 0
	var furthest_short := INF
	var totals := {}
	for size in ["small", "medium", "large"]:
		for shape in MapGen.SHAPES:
			for k in 12:
				var sd := 1000 + k * 7919 + shape.length() * 31
				night(sd, size, shape)
				nights += 1
				var spots := Hideouts.all()
				for b in Museum.big_pieces:
					if b.kind in Hideouts.BIG and not spots.any(func(s): return s.kind == b.kind and s.area == Rect2(b.rect)):
						not_hideouts += 1
				for pr in Props.list:
					if pr.kind == "armour" and not spots.any(func(s): return s.prop == pr):
						not_hideouts += 1
				var at := Hideouts.taken()
				var budget := Hideouts.places(Museum.open_tiles.size())
				if at.size() > budget:
					over += 1
					check(false, "%s/%s semilla %d: %d sitios, más de %d" % [size, shape, sd, at.size(), budget])
				if at.size() < Hideouts.MIN:
					under += 1
				for i in at.size():
					for j in range(i + 1, at.size()):
						if at[i].distance_to(at[j]) < Hideouts.APART:
							near += 1
						furthest_short = minf(furthest_short, at[i].distance_to(at[j]))
				totals[size] = totals.get(size, 0) + at.size()
	print("  sitios de media: pequeño %.1f, mediano %.1f, grande %.1f" % [totals.small / 72.0, totals.medium / 72.0, totals.large / 72.0])
	check(not_hideouts == 0, "toda pieza grande de escondite y toda armadura en pie deja esconderse (%d que no)" % not_hideouts)
	check(over == 0, "en %d museos, ninguno con más sitios de los que le tocan" % nights)
	check(near == 0, "ninguno a menos de %.0f casillas de otro (el más cerca, a %.1f)" % [Hideouts.APART, furthest_short])
	check(under <= nights / 20, "casi siempre al menos %d (%d de %d con menos)" % [Hideouts.MIN, under, nights])

	# Getting in is at once, no minigame and no time out in the open: the
	# only thing that decides if it fools a guard is whether it sees the
	# instant you get in (Hideouts.get_in, already checked above).
	Sim.custom = {}
	Sim.new_map(sarcophagus_seed, "medium")
	Props.list.clear()
	var sq := Hideouts.all().filter(func(o): return o.kind == "sarcophagus")[0] as Hideouts.Spot
	var by := Vector2i(-1, -1)
	for tt in sq.tiles:
		for dd in Museum.DIRS:
			var nb: Vector2i = tt + dd
			if by.x < 0 and not nb in sq.tiles and Museum.tile_at(nb.x + 0.5, nb.y + 0.5) == Tiles.FLOOR:
				by = nb
	var q := Sim.new_thief()
	q.x = by.x + 0.5
	q.y = by.y + 0.5
	var alone: Array[Thief] = [q]
	var sq_spot := Hideouts.within_reach(q, alone)
	var none: Array[Guard] = []
	Hideouts.get_in(q, sq_spot, none)
	check(q.hiding and q.game == null, "junto al sarcófago, dentro al momento, sin minijuego de por medio")

	quit(qa.summary())
