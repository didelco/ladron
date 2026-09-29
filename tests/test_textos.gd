extends SceneTree
## Los textos: ninguna clave que pide el código se queda sin texto (en pantalla
## saldría en crudo: HIDEOUT_GAME_START, HUD_…). Se recorren, en la traducción
## que carga el juego (locale/texts.es.translation, la que genera Godot al
## importar el CSV):
##  1. Cada literal MAYÚSCULAS_CON_GUION de scenes/ y logic/ (claves sueltas,
##     tablas de datos, listas de claves, ramas de un if...).
##  2. Las claves que el código arma con prefijo o número (NIGHT…, EDITOR_TOOL_…,
##     GEN_…, MEGA_…, HIDEOUT_ROOM_…): cada variante que las tablas de datos
##     pueden producir.
##  3. Que cada fila del CSV tenga la clave bien escrita y su texto en la
##     traducción cargada (si no, falta reimportar: godot --headless --import).
##  4. Que ningún texto con formato roto: a cada Text.t("CLAVE") % [...] del
##     código le tienen que cuadrar los %s/%d del texto con lo que se le pasa.
## Si un test cualquiera pide una clave sin texto, Text lo avisa (WARNING) y lo
## apunta en Text.missing.
var fails := 0
var asked := {}          ## Las claves comprobadas (para contarlas).

## Literales en mayúsculas que NO son claves de Text, o que solo son la base de
## otras (la variante _ONE/_MANY/_1 se comprueba aparte), y se saltan.
const NOT_KEYS := [
	# Los rasgos de los guardias: TIP_TRAIT_<rasgo> y TIP_ADVICE_<rasgo> se comprueban abajo.
	"SHARP_EARS", "FAST", "FAR_EYES", "DULL_EARS", "SHORT_EYES", "SLOW",
]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok:
		fails += 1


## Una clave que tiene que tener texto.
func need(key: String, where := "") -> bool:
	asked[key] = true
	return Text.has(key)


func need_all(keys: Array, what: String) -> void:
	var lost: Array[String] = []
	for k in keys:
		if not need(String(k)):
			lost.append(String(k))
	check(lost.is_empty(), "%s: %d claves, todas con texto%s" % [what, keys.size(), "" if lost.is_empty() else " (faltan " + ", ".join(lost) + ")"])


func numbered(prefix: String, from: int, to: int, suffix := "") -> Array:
	var out := []
	for i in range(from, to + 1):
		out.append("%s%d%s" % [prefix, i, suffix])
	return out


func upper(s) -> String:
	return String(s).to_upper()


func _init() -> void:
	Text.setup()
	_csv()
	_literals()
	_families()
	_formats()
	check(Text.missing.is_empty(), "nadie ha pedido una clave sin texto mientras tanto (%s)" % ", ".join(Text.missing.keys()))
	print("%d claves comprobadas" % asked.size())
	print("FALLOS: %d" % fails)
	quit(1 if fails > 0 else 0)


# --- El CSV y la traducción cargada -----------------------------------------------

func _csv() -> void:
	var f := FileAccess.open("res://locale/texts.csv", FileAccess.READ)
	f.get_csv_line()
	var rx := RegEx.create_from_string("^[A-Z][A-Z0-9]*(_[A-Z0-9]+)*$")
	var seen := {}
	var bad_name: Array[String] = []
	var dup: Array[String] = []
	var empty: Array[String] = []
	var unloaded: Array[String] = []
	var rows := 0
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() == 1 and r[0] == "":
			continue
		rows += 1
		var key := r[0]
		if r.size() != 2 or rx.search(key) == null:
			bad_name.append(key)
			continue
		if seen.has(key):
			dup.append(key)
		seen[key] = true
		if r[1] == "":
			empty.append(key)
		elif not Text.has(key):
			unloaded.append(key)
	check(bad_name.is_empty(), "el CSV: %d filas, todas con clave bien escrita y solo dos columnas%s" % [rows, "" if bad_name.is_empty() else " (mal: " + ", ".join(bad_name.slice(0, 8)) + ")"])
	check(dup.is_empty(), "el CSV: ninguna clave repetida%s" % ("" if dup.is_empty() else " (" + ", ".join(dup) + ")"))
	check(empty.is_empty(), "el CSV: ningún texto vacío%s" % ("" if empty.is_empty() else " (" + ", ".join(empty.slice(0, 8)) + ")"))
	check(unloaded.is_empty(), "la traducción cargada tiene todas las filas del CSV (si no, godot --headless --import)%s" % ("" if unloaded.is_empty() else ": " + ", ".join(unloaded.slice(0, 8))))


# --- Los literales del código ------------------------------------------------------

func _sources() -> Array[String]:
	var out: Array[String] = []
	for folder in ["res://scenes", "res://logic"]:
		for f in DirAccess.get_files_at(folder):
			if f.ends_with(".gd"):
				out.append(folder + "/" + f)
	return out


func _literals() -> void:
	var rx := RegEx.create_from_string("\"([A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+)\"")
	var lost := {}
	var count := 0
	for path in _sources():
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if line.strip_edges().begins_with("#"):
				continue
			for m in rx.search_all(line):
				var key := m.get_string(1)
				if key in NOT_KEYS:
					continue
				count += 1
				asked[key] = true
				# La base de una clave con variantes: KEY_ONE/KEY_MANY, KEY_1…
				if Text.has(key) or (Text.has(key + "_ONE") and Text.has(key + "_MANY")) or Text.has(key + "_1"):
					continue
				if not lost.has(key):
					lost[key] = "%s:%d" % [path.trim_prefix("res://"), n]
	var lines: Array[String] = []
	for k in lost:
		lines.append("%s (%s)" % [k, lost[k]])
	check(lost.is_empty(), "los literales del código (%d usos) tienen todos texto%s" % [count, "" if lost.is_empty() else ": " + ", ".join(lines)])


# --- Las que se arman con prefijo o número ------------------------------------------

func _families() -> void:
	# Historia: bandas de 1 a 4 (Tour), titulares y estadísticas del final (Main).
	need_all(numbered("STORY_GANG_", 1, 4), "banda de 1 a 4 ladrones")
	var main_consts: Dictionary = (load("res://scenes/main.gd") as GDScript).get_script_constant_map()
	need_all(numbered("END_HEAD_", 1, int(main_consts.END_HEADS)), "titulares del final")
	var stats := []
	for k in HeistStats.KINDS:
		stats.append_array(["END_STAT_%s_ONE" % upper(k), "END_STAT_%s_MANY" % upper(k)])
	need_all(stats, "estadísticas del final")
	var jokes := []
	var file_jokes: Dictionary = main_consts.FILE_JOKES
	for k in file_jokes:
		jokes.append_array(numbered(String(k) + "_", 1, int(file_jokes[k])))
	need_all(jokes, "chistes de la ficha policial")
	# Ajustes.
	var modes := []
	for m in Settings.MEGAPHONE_MODES:
		modes.append("SETTINGS_MEGAPHONE_" + upper(m))
	need_all(modes, "modos del megáfono")
	# El escondite (Den, dojo): salas, juegos, por qué se pierde, niveles del banco.
	var den := []
	for r in Den.ROOMS:
		den.append("HIDEOUT_ROOM_" + upper(r))
	need_all(den, "salas del refugio")
	var games := []
	for id in DojoTrials.ids():
		var info := DojoTrials.info(id)
		games.append_array([info.name, info.hint])
		if String(info.start_text) != "":
			games.append(info.start_text)
		if info.kind == "game":
			games.append("HIDEOUT_GAME_LOST_" + upper(id))
	for why in ["time", "fall", "down", "late", "seen", "left", "sneeze"]:  # los _lose(...) de logic/*_game.gd y *_trial.gd
		games.append("HIDEOUT_TRIAL_WHY_" + upper(why))
	for t in DojoTrials.TIERS:
		games.append(t.text)
	need_all(games, "pruebas del dojo")
	# Minijuegos (Minigame.how(): GAME_HOW_<tipo>; cada tipo es una clase de logic/).
	var hows := []
	for kind in ["lockpick", "steady", "wires", "balance", "squeeze", "arcade", "sneeze"]:
		hows.append("GAME_HOW_" + upper(kind))
	need_all(hows, "cómo se juega cada minijuego")
	# Museos: galerías y zonas (Themes, Museum), esquinas de pasillo.
	var places := []
	for id in Themes.ALL:
		var key: String = Themes.ALL[id].gallery[1]
		places.append_array([key, key + "_OF", "THEME_" + upper(id)])
	for dir in ["east", "west", "north", "south"]:
		places.append("ZONE_CORRIDOR_" + upper(dir))
	need_all(places, "galerías, temas y pasillos")
	# Piezas: el editor las nombra por herramienta (Themes.catalogue), un modelo
	# por su fichero (PIECE_), y los escondites y objetos por su tipo.
	var pieces := []
	for entry in Themes.catalogue():
		var t: String = entry[0]
		if t == "case":
			pieces.append("EDITOR_TOOL_CASE")
		elif t.begins_with("exhibit:"):
			var kind := t.substr(8)
			pieces.append("PIECE_" + upper(kind.get_file()) if "/" in kind else "EDITOR_TOOL_EXHIBIT_" + upper(kind))
		else:
			pieces.append("EDITOR_TOOL_" + upper(t.replace(":", "_")))
	for kind in Themes.variants("temas/moderna/recreativa"):
		pieces.append("PIECE_RECREATIVA_" + upper(kind))
	for kind in Hideouts.PIECES:
		pieces.append("HIDE_" + upper(kind))
	pieces.append_array(Props.NAMES.values())
	need_all(pieces, "piezas del editor y escondites")
	# Piezas generadas (LootGen): nombres, cuentos, verbos.
	var gen := numbered("GEN_OWNER_", 1, LootGen.OWNERS, "_OF") + numbered("GEN_OWNER_", 1, LootGen.OWNERS, "_WHO")
	gen.append_array(numbered("GEN_HOW_", 1, LootGen.HOW))
	gen.append_array(numbered("GEN_SINCE_", 1, LootGen.SINCE))
	for shape in LootGen.PIECES:
		var p: Dictionary = LootGen.PIECES[shape]
		var key := "GEN_" + upper(shape)
		gen.append(key + "_VERB")
		gen.append_array(numbered(key + "_NOUN_", 1, int(p.nouns)))
		gen.append_array(numbered(key + "_BLURB_", 1, int(p.blurbs)))
		gen.append_array(numbered(key + "_DETAIL_", 1, int(p.details)))
		gen.append("EDITOR_SHAPE_" + upper(shape))
	need_all(gen, "piezas generadas")
	# Editor: pestañas, tipos, páginas, herramientas, colores, aspectos.
	var editor := []
	for k in MapEditor.KINDS:
		editor.append("EDITOR_KIND_" + upper(k))
	for k in ["floor", "wall", "case", "out", "spawn", "piece", "exit", "guard", "prop", "room"]:
		editor.append_array(["EDITOR_TOOL_" + upper(k), "EDITOR_HINT_" + upper(k)])
	editor.append_array(["EDITOR_HINT_STAMP", "EDITOR_HINT_EXHIBIT", "EDITOR_HINT_BIG", "EDITOR_TYPE_ALL", "EDITOR_LOOK_AUTO", "EDITOR_LOOT_RANDOM"])
	for k in Themes.TYPES:
		editor.append("EDITOR_TYPE_" + upper(k))
	for k in MapEditor.OPTION_PAGES:
		editor.append("EDITOR_PAGE_" + upper(k))
	for k in MapEditor.SAVE_PAGES:
		editor.append("EDITOR_SAVE_TAB_" + upper(k))
	editor.append_array(numbered("EDITOR_COLOUR_", 0, MapEditor.LOOT_COLOURS.size() - 1))
	var looks := MuseumView.looks().size()
	editor.append_array(numbered("EDITOR_LOOK_", 0, looks - 1))
	editor.append_array(numbered("EDITOR_WALL_LOOK_", 0, looks - 1))
	for t in MapEditor.TEMPLATES:
		editor.append(t.key)
	need_all(editor, "el editor")
	# Recorrido del plano (PlanBeats): etiquetas y marcas, para 1 ladrón y para varios.
	var tour := []
	for k in ["piece", "news", "guard", "panel", "start", "exit", "rule"]:
		tour.append("TOUR_TAG_" + upper(k))
	for k in ["TOUR_MARK_START", "TOUR_MARK_EXIT", "TOUR_MARK_PANEL", "STAR_GOAL_TAKEN", "STAR_GOAL_UNSEEN"]:
		tour.append_array([k + "_ONE", k + "_MANY"])
	need_all(tour, "el recorrido del plano")
	# Consejos del guardia (Briefing): TIP_TRAIT_<rasgo> y TIP_ADVICE_<rasgo>, en singular y plural.
	var tips := ["TIP_ADVICE_NORMAL_ONE", "TIP_ADVICE_NORMAL_MANY", "TIP_GRUDGE_ONE", "TIP_GRUDGE_MANY", "TIP_LIGHTS_ONE", "TIP_LIGHTS_MANY"]
	for trait_id in ["SHARP_EARS", "FAST", "FAR_EYES", "DULL_EARS", "SHORT_EYES", "SLOW"]:
		for tail in ["_ONE", "_MANY"]:
			tips.append_array(["TIP_TRAIT_" + trait_id + tail, "TIP_ADVICE_" + trait_id + tail])
	need_all(tips, "consejos sobre los guardias")
	# Megafonía: todas las frases de todas las bolsas.
	need_all(Megaphone.all_keys(), "frases de la megafonía")
	# La historia: cada noche, museo y lección con sus textos (literales en las tablas: se piden aquí por si acaso).
	var story := []
	for n in range(1, Story.LEVELS.size() + 1):
		var lv: Dictionary = Story.level(n)
		if lv.has("tip"):
			story.append(lv.tip)
	for m in Story.MUSEUMS:
		story.append(m.name)
	need_all(story, "consejos de cada robo y nombres de los museos")


# --- El formato: los % del texto contra lo que le pasa el código -----------------------

## Cuántos huecos (%s, %d, %04d...) tiene un texto, o -1 si tiene un % suelto.
func holes(text: String) -> int:
	var s := text.replace("%%", "")
	var spec := RegEx.create_from_string("%[-+#0]*[0-9]*(?:\\.[0-9]+)?[sdfxXcv]")
	var n := spec.search_all(s).size()
	var rest := spec.sub(s, "", true)
	return -1 if "%" in rest else n


## Cuántos valores se pasan en `% [a, b]` (o 1 si es uno solo), leyendo desde el
## texto que sigue al %; -1 si no se sabe (no cabe en la línea).
func passed(after: String) -> int:
	var s := after.strip_edges()
	if not s.begins_with("["):
		return 1
	var depth := 0
	var commas := 0
	var quote := ""
	var filled := false
	for i in s.length():
		var c := s[i]
		if quote != "":
			if c == quote and s[i - 1] != "\\":
				quote = ""
			continue
		if c == "\"" or c == "'":
			quote = c
			filled = true
		elif c in "[({":
			depth += 1
			if depth > 1:
				filled = true
		elif c in "])}":
			depth -= 1
			if depth == 0:
				return commas + (1 if filled else 0)
		elif c == "," and depth == 1:
			commas += 1
			filled = false
		elif c != " " and c != "\t":
			filled = true
	return -1


func _formats() -> void:
	# La propia comprobación, con casos que se sabe cómo van.
	check(holes("a %s y %04d") == 2 and holes("100%% seguro") == 0 and holes("un 50% de") == -1 and holes("sin nada") == 0, "holes cuenta los huecos y ve un % suelto")
	check(passed("[a, b]") == 2 and passed("[a, [b, c], \"x, y\"]") == 3 and passed("nombre") == 1 and passed("[]") == 0, "passed cuenta lo que se pasa")
	var call_rx := RegEx.create_from_string("Text\\.t\\(((?:[^()]|\\([^()]*\\))*)\\)\\s*%\\s*(?!%)(.*)$")
	var key_rx := RegEx.create_from_string("\"([A-Z][A-Z0-9_]*)\"")
	var bad: Array[String] = []
	var checked := 0
	for path in _sources():
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if line.strip_edges().begins_with("#"):
				continue
			var m := call_rx.search(line)
			if m == null:
				continue
			var given := passed(m.get_string(2))
			for km in key_rx.search_all(m.get_string(1)):
				var key := km.get_string(1)
				if not Text.has(key):
					continue
				checked += 1
				var h := holes(Text.t(key))
				var where := "%s:%d %s" % [path.trim_prefix("res://"), n, key]
				if h < 0:
					bad.append(where + " (% suelto)")
				elif given >= 0 and h != given:
					bad.append("%s (el texto tiene %d huecos y se le pasan %d)" % [where, h, given])
	check(bad.is_empty(), "formato: %d Text.t(\"…\") %% … con los huecos que cuadran%s" % [checked, "" if bad.is_empty() else ":\n  " + "\n  ".join(bad)])
