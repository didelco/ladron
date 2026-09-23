extends SceneTree
## Parity with the web version: the same seed must build the same museum.
##
## The fixtures are exported from the frozen web version (tag web-ref): a few
## PRNG sequences, and 90 museums across every size and shape. Run with
##   godot --headless --script tests/test_mapgen.gd
## Exits 0 when everything matches, 1 otherwise, printing the first mismatches.


func _init() -> void:
	var failures: Array[String] = []
	_check_rng(failures)
	_check_museums(failures)
	if failures.is_empty():
		print("OK: generador idéntico a la web")
		quit(0)
	else:
		for f in failures.slice(0, 20):
			printerr(f)
		printerr("%d diferencias" % failures.size())
		quit(1)


func _load(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _check_rng(failures: Array[String]) -> void:
	for case in _load("res://tests/fixtures/rng.json"):
		var r := Mulberry32.new(int(case.seed))
		for v in case.values:
			var mine := r.next()
			# Godot's JSON reader can lose the last bit of a double, so not ==.
			if absf(mine - float(v)) > 1e-12:
				failures.append("rng %d: %f en vez de %f" % [int(case.seed), mine, float(v)])
				break
	print("rng comprobado")


func _check_museums(failures: Array[String]) -> void:
	var cases: Array = _load("res://tests/fixtures/museums.json")
	for case in cases:
		var tag := "%s/%s/%d" % [case.size, case.shape, int(case.seed)]
		var m := MapGen.generate(int(case.seed), int(case.w), int(case.h), case.shape)
		if _digits(m.grid) != case.grid:
			failures.append("%s: el plano no coincide (%s)" % [tag, _first_diff(_digits(m.grid), case.grid, m.w)])
			continue
		if _digits(m.outside) != case.outside:
			failures.append("%s: el exterior no coincide" % tag)
		if _digits(m.ring) != case.ring:
			failures.append("%s: el pasillo exterior no coincide" % tag)
		if m.spawn != Vector2i(int(case.spawn[0]), int(case.spawn[1])):
			failures.append("%s: salida %s en vez de %s" % [tag, m.spawn, case.spawn])
		if m.rooms.size() != case.rooms.size():
			failures.append("%s: %d salas en vez de %d" % [tag, m.rooms.size(), case.rooms.size()])
		else:
			for i in m.rooms.size():
				var r: Dictionary = case.rooms[i]
				if m.rooms[i] != Rect2i(int(r.x), int(r.y), int(r.w), int(r.h)):
					failures.append("%s: sala %d distinta" % [tag, i])
					break
	print("%d museos comprobados" % cases.size())


func _digits(a) -> String:
	var s := PackedStringArray()
	for v in a:
		s.append(str(v))
	return "".join(s)


func _first_diff(a: String, b: String, w: int) -> String:
	for i in mini(a.length(), b.length()):
		if a[i] != b[i]:
			return "primera casilla distinta en (%d, %d)" % [i % w, i / w]
	return "longitudes %d y %d" % [a.length(), b.length()]
