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

	_proposals()
	_references()

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


## Las propuestas de assets (docs/data/propuestas.json): lo mismo que valida tools/procedencia.py.
func _proposals() -> void:
	var path := "res://docs/data/propuestas.json"
	if not FileAccess.file_exists(path):
		return
	var props = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(props) != TYPE_ARRAY:
		check(false, "propuestas.json: no es una lista")
		return
	var ids := {}
	for r in props:
		if typeof(r) != TYPE_DICTIONARY:
			check(false, "propuestas.json: una propuesta no es un objeto")
			continue
		var w := "propuestas.json, %s" % str(r.get("id", "?"))
		for k in ["id", "nombre", "pack", "url", "tipo", "licencia", "para", "estado"]:
			check(typeof(r.get(k)) == TYPE_STRING and str(r[k]).strip_edges() != "", "%s: falta %s" % [w, k])
		check(not ids.has(r.get("id")), "%s: id repetido" % w)
		ids[r.get("id")] = true
		check(str(r.get("url", "")).begins_with("http://") or str(r.get("url", "")).begins_with("https://"), "%s: url debe ser http(s)" % w)
		for k in ["pack_url", "preview_url"]:
			var u := str(r.get(k, ""))
			check(u == "" or u.begins_with("http://") or u.begins_with("https://"), "%s: %s debe ser http(s) o vacío" % [w, k])
		check(str(r.get("tipo", "")) in ["modelo", "sonido", "imagen", "otro"], "%s: tipo no válido" % w)
		check(str(r.get("estado", "")) in ["propuesto", "aceptado", "incorporado", "descartado"], "%s: estado no válido" % w)
		check(typeof(r.get("atribucion")) == TYPE_BOOL, "%s: atribucion debe ser booleano" % w)


## Las referencias guardadas (docs/data/referencias.json): lo mismo que valida tools/procedencia.py.
func _references() -> void:
	var path := "res://docs/data/referencias.json"
	if not FileAccess.file_exists(path):
		return
	var refs = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(refs) != TYPE_ARRAY:
		check(false, "referencias.json: no es una lista")
		return
	var ids := {}
	var re := RegEx.create_from_string("^\\d{4}-\\d{2}-\\d{2}$")
	for r in refs:
		if typeof(r) != TYPE_DICTIONARY:
			check(false, "referencias.json: una referencia no es un objeto")
			continue
		var w := "referencias.json, %s" % str(r.get("id", "?"))
		for k in ["id", "titulo", "url", "tipo", "fecha", "estado"]:
			check(typeof(r.get(k)) == TYPE_STRING and str(r[k]).strip_edges() != "", "%s: falta %s" % [w, k])
		check(not ids.has(r.get("id")), "%s: id repetido" % w)
		ids[r.get("id")] = true
		check(str(r.get("url", "")).begins_with("http://") or str(r.get("url", "")).begins_with("https://"), "%s: url debe ser http(s)" % w)
		check(str(r.get("tipo", "")) in ["icons", "modelos", "audio", "arte", "codigo", "articulo", "texturas", "fuentes", "voz", "otro"], "%s: tipo no válido" % w)
		check(str(r.get("estado", "")) in ["guardada", "evaluada", "usada", "descartada"], "%s: estado no válido" % w)
		check(re.search(str(r.get("fecha", ""))) != null, "%s: fecha debe ser YYYY-MM-DD" % w)
		check(typeof(r.get("etiquetas", [])) == TYPE_ARRAY, "%s: etiquetas debe ser una lista" % w)
		var its = r.get("items", [])
		check(typeof(its) == TYPE_ARRAY, "%s: items debe ser una lista" % w)
		if typeof(its) == TYPE_ARRAY:
			for it in its:
				if typeof(it) != TYPE_DICTIONARY:
					check(false, "%s: un item no es un objeto" % w)
					continue
				for k in ["nombre", "para"]:
					check(typeof(it.get(k)) == TYPE_STRING and str(it[k]).strip_edges() != "", "%s: item sin %s" % [w, k])
				if it.has("url"):
					check(str(it["url"]).begins_with("http://") or str(it["url"]).begins_with("https://"), "%s: url de item debe ser http(s)" % w)
				check(typeof(it.get("ya_lo_usamos", false)) == TYPE_BOOL, "%s: ya_lo_usamos debe ser booleano" % w)


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
