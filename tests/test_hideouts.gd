extends SceneTree
## Hideouts: in with the action key from beside a sarcophagus or a suit of
## armour, where no guard sees you; any way out steps onto free floor; getting
## in in plain sight fools nobody, and a guard beside it pulls you out; a
## suit of armour knocked over tips you out.
##   godot --headless --script tests/test_hideouts.gd

const DT := 1.0 / 60.0
const KEY := {Vector2i(1, 0): "d", Vector2i(-1, 0): "a", Vector2i(0, 1): "s", Vector2i(0, -1): "w"}

var failures: Array[String] = []


func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FALLO ") + what)
	if not ok:
		failures.append(what)


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


func _init() -> void:
	Sim.custom = {}
	Sim.new_map(4242, "medium")
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
	Plinths.place(4242, [] as Array[Vector2i])
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
	Hideouts.place(4242, [] as Array[Vector2i])
	check(Hideouts.pieces.size() >= Hideouts.MIN, "hay muebles para esconderse (%d)" % Hideouts.pieces.size())
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

	print("OK: escondites" if failures.is_empty() else "FALLOS: %d" % failures.size())
	quit(0 if failures.is_empty() else 1)
