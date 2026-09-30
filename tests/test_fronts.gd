extends SceneTree
## Pieces with a front (a screen, a door, a seat, a face) never face a wall:
## the arcade machine, the throne and Anubis on the floor, and the furniture
## to hide in, like the fridge. Over many museums of every size: each one
## faces free floor, and a floor piece with a front where there is none
## gives way to another.
##   godot --headless --script tests/test_fronts.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func _init() -> void:
	var fronted := 0
	var walled_before := 0
	var walled_now := 0
	var swapped := 0
	var hideouts := 0
	var hideouts_walled := 0
	for size in ["small", "medium", "large"]:
		for seed in range(1, 41):
			Sim.new_map(seed * 7919, size)
			Hideouts.reset()
			Hideouts.spread(seed, [] as Array[Vector2i], false, true)
			Collection.lay_out()
			for t in Museum.cover_tiles:
				if not Museum.big_piece_at(t).is_empty():
					continue
				if Hideouts.pieces.has(t):
					hideouts += 1
					var d := MuseumView.front_of(t)
					if d == Vector2i.ZERO or Museum.tile_at(t.x + d.x + 0.5, t.y + d.y + 0.5) != Tiles.FLOOR:
						hideouts_walled += 1
					continue
				var room := Museum.room_at(t.x + 0.5, t.y + 0.5)
				var theme: String = room.theme if room else ""
				# As it was: the theme's first pick, turned to a quarter at random.
				var old := Themes.pick(theme, MuseumView._hash01(t.x, t.y), MuseumView._hash01(t.x, t.y, 29))
				if old[1] in Themes.FRONTED:
					var yaw: float = round(MuseumView._hash01(t.x, t.y, 3) * TAU / (PI / 2)) * PI / 2
					var ahead := Vector2i(roundi(sin(yaw)), roundi(cos(yaw)))
					if Museum.tile_at(t.x + ahead.x + 0.5, t.y + ahead.y + 0.5) != Tiles.FLOOR:
						walled_before += 1
				# As it is now.
				var pick := Collection.at(t)
				if pick.is_empty():
					continue
				if pick[1] != old[1]:
					swapped += 1
				if pick[1] in Themes.FRONTED:
					fronted += 1
					var yaw := MuseumView.front_yaw(t)
					var ahead := Vector2i(roundi(sin(yaw)), roundi(cos(yaw)))
					if Museum.tile_at(t.x + ahead.x + 0.5, t.y + ahead.y + 0.5) != Tiles.FLOOR:
						walled_now += 1
	print("  piezas con frente en el suelo: %d; antes contra algo: %d; cambiadas por otra: %d" % [fronted, walled_before, swapped])
	check(fronted > 0, "hay piezas con frente en los museos probados")
	check(walled_now == 0, "ninguna pieza con frente mira a una pared o a otra pieza (%d)" % walled_now)
	check(hideouts > 0, "hay escondites en los museos probados (%d)" % hideouts)
	check(hideouts_walled == 0, "ningún escondite (la nevera...) tiene la puerta contra algo (%d)" % hideouts_walled)
	# South first: the camera sees the front when it can.
	var south := 0
	var could := 0
	for t in Museum.cover_tiles:
		if Museum.tile_at(t.x + 0.5, t.y + 1.5) == Tiles.FLOOR:
			could += 1
			if MuseumView.front_of(t) == Vector2i(0, 1):
				south += 1
	check(could > 0 and south == could, "con suelo libre al sur, el frente mira al sur (a la cámara)")
	quit(qa.summary())
