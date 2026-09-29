extends SceneTree
## La procedencia de los assets (assets/PROCEDENCIA.json): cada fichero de assets/, audio/, art/
## y lo demás que declara el «ambito» tiene una regla que dice de qué colección sale y con qué
## licencia, y toda licencia declarada está en la lista de permitidas. Lo mismo que hace
## tools/procedencia.py (que además cuida CREDITS.md), pero dentro de tests/run_all.sh.
## Los patrones valen como en fnmatch: «*» cubre cualquier texto, también «/»; gana la primera regla.
var fails := 0
var data := {}


func check(ok: bool, what: String) -> void:
	if not ok:
		print("FALLO " + what)
		fails += 1


func _init() -> void:
	var f := FileAccess.open("res://assets/PROCEDENCIA.json", FileAccess.READ)
	if f == null:
		check(false, "no se puede leer assets/PROCEDENCIA.json")
		_end()
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		check(false, "assets/PROCEDENCIA.json no es un JSON válido")
		_end()
		return
	data = parsed
	var allowed: Array = data.get("permitidas", [])
	var licences: Dictionary = data.get("licencias", {})
	var cols: Dictionary = data.get("colecciones", {})
	var rules: Array = data.get("reglas", [])

	for lid in allowed:
		check(licences.has(lid), "licencia permitida sin describir en 'licencias': %s" % lid)
	for cid in cols:
		var c: Dictionary = cols[cid]
		_licence("colección " + cid, c.get("licencia", ""), allowed, licences)
		for comp in c.get("componentes", []):
			_licence("colección %s, componente %s" % [cid, comp.get("nombre", "?")], comp.get("licencia", ""), allowed, licences)
		check(c.get("tipo", "") in ["propio", "externo"], "colección %s: tipo debe ser propio o externo" % cid)
		check(str(c.get("metodo", "")) != "", "colección %s: sin método" % cid)
		if c.get("documentado", true) == false:
			check(c.get("licencia", "") == "LicenseRef-Sin-Documentar", "colección %s: sin documentar pero con licencia" % cid)
	for i in rules.size():
		var r: Dictionary = rules[i]
		check(cols.has(r.get("coleccion", "")), "regla %d (%s): colección desconocida" % [i + 1, str(r.get("patron"))])
		if r.has("licencia"):
			_licence("regla %d" % (i + 1), r["licencia"], allowed, licences)

	var ignore: Array = data.get("ignorar", [])
	var paths := {}
	for item in data.get("ambito", []):
		if typeof(item) == TYPE_STRING:
			item = {"ruta": item}
		var base: String = item["ruta"]
		if FileAccess.file_exists("res://" + base):
			paths[base] = true
		else:
			_walk(base, item.get("patron", ""), item.get("recursivo", true), paths)
	var total := 0
	var used := []
	used.resize(rules.size())
	used.fill(0)
	var undocumented := 0
	for path in paths:
		if _any(path, ignore):
			continue
		total += 1
		var hit := -1
		for i in rules.size():
			if _any(path, _as_array(rules[i].get("patron", []))):
				hit = i
				break
		if hit < 0:
			check(false, "sin regla de procedencia: %s" % path)
			continue
		used[hit] += 1
		var col: Dictionary = cols.get(rules[hit].get("coleccion", ""), {})
		if rules[hit].get("documentado", col.get("documentado", true)) == false:
			undocumented += 1
	for i in rules.size():
		if used[i] == 0:
			print("AVISO regla sin ficheros: %s" % str(rules[i].get("patron")))
	if undocumented > 0:
		print("AVISO %d ficheros con origen sin documentar" % undocumented)
	print("%d ficheros con procedencia, %d reglas, %d colecciones, %d licencias permitidas" % [total, rules.size(), cols.size(), allowed.size()])
	_end()


func _end() -> void:
	print("FALLOS: %d" % fails)
	quit(1 if fails > 0 else 0)


func _licence(where: String, lid: String, allowed: Array, licences: Dictionary) -> void:
	if lid == "":
		check(false, "%s: sin licencia" % where)
	elif not licences.has(lid):
		check(false, "%s: licencia desconocida «%s»" % [where, lid])
	elif not allowed.has(lid):
		check(false, "%s: licencia «%s» no permitida" % [where, lid])


func _as_array(v) -> Array:
	return v if typeof(v) == TYPE_ARRAY else [v]


func _any(path: String, patterns: Array) -> bool:
	for p in patterns:
		if path.match(p):
			return true
	return false


## Los ficheros de una carpeta (sin las ocultas) con su ruta relativa al proyecto.
func _walk(rel: String, pattern: String, recursive: bool, out: Dictionary) -> void:
	var d := DirAccess.open("res://" + rel)
	if d == null:
		return
	for name in d.get_files():
		if pattern == "" or name.match(pattern):
			out[rel + "/" + name] = true
	if recursive:
		for sub in d.get_directories():
			if not sub.begins_with("."):
				_walk(rel + "/" + sub, pattern, true, out)
