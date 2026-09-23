extends SceneTree
## Parity with the web version for the museum built around the plan: the
## outline picked from the seed, rooms and their switches, the named zones and
## the guards' round.
##   godot --headless --script tests/test_museum.gd


func _init() -> void:
	var failures: Array[String] = []
	var cases: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/museum_state.json"))
	for c in cases:
		var tag := "%s/%d" % [c.size, int(c.seed)]
		Museum.regenerate(int(c.seed), c.size)
		if Museum.shape != c.shape:
			failures.append("%s: forma %s en vez de %s" % [tag, Museum.shape, c.shape])
			continue
		if Museum.rooms.size() != c.rooms.size():
			failures.append("%s: %d salas en vez de %d" % [tag, Museum.rooms.size(), c.rooms.size()])
		else:
			for i in Museum.rooms.size():
				var r := Museum.rooms[i]
				var e: Dictionary = c.rooms[i]
				if r.rect != Rect2i(int(e.x), int(e.y), int(e.w), int(e.h)) \
						or r.switch_at != Vector2i(int(e.sw[0]), int(e.sw[1])) \
						or r.face != Vector2i(int(e.face[0]), int(e.face[1])):
					failures.append("%s: sala %d o su interruptor distinto" % [tag, i])
					break
		if Museum.zones.size() != c.zones.size():
			failures.append("%s: %d zonas en vez de %d" % [tag, Museum.zones.size(), c.zones.size()])
		else:
			for i in Museum.zones.size():
				var z := Museum.zones[i]
				var e: Dictionary = c.zones[i]
				if z.name != e.name or z.label != e.label or z.room != int(e.room) or z.tiles.size() != int(e.n):
					failures.append("%s: zona %d: '%s' (%d) en vez de '%s' (%d)" % [tag, i, z.name, z.tiles.size(), e.name, int(e.n)])
					break
		var wp: Array = c.watchpoints
		if Museum.watchpoints.size() != wp.size():
			failures.append("%s: ronda de %d paradas en vez de %d" % [tag, Museum.watchpoints.size(), wp.size()])
		else:
			for i in wp.size():
				if Museum.watchpoints[i] != Vector2i(int(wp[i][0]), int(wp[i][1])):
					failures.append("%s: parada %d distinta" % [tag, i])
					break
	print("%d museos comprobados" % cases.size())
	if failures.is_empty():
		print("OK: museo idéntico a la web")
		quit(0)
	else:
		for f in failures.slice(0, 20):
			printerr(f)
		printerr("%d diferencias" % failures.size())
		quit(1)
