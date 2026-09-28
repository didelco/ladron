extends SceneTree
## The documentation's pictures and data, taken from the game itself (docs/).
##
##   godot --path . --script tools/capture_docs.gd            # everything
##   godot --path . --script tools/capture_docs.gd -- shots   # only: shots, assets, models, objects, sounds, data
##
## It opens the game in a window of its own, with settings and progress of
## its own (user://docs/), so the player's are never touched: every screen,
## several nights in play, the assets page piece by piece, each .glb on its
## own, the sounds as .wav, and the palette, the story and the maps as JSON.
## tools/docs.py runs it and builds the rest; docs/index.html shows it all.

const OUT := "res://docs/"
const SIZE := Vector2i(1600, 900)
const MODEL_SIZE := 480

## The .glb each of MuseumView's own pieces and each big piece is shown with
## (museum_view.gd), for the docs' catalogue: the theme's pieces are their
## own path, and the props have their own picture (_assets). Butterflies, minerals and the diorama
## are built in code and have none.
const MODEL_OF := {
	"exhibit:ammonite": "amonite", "exhibit:meteorite": "meteorito", "exhibit:statue": "statue-a", "exhibit:skull": "craneo",
	"exhibit:lego_skull": "craneo_lego", "exhibit:amphora": "anfora", "exhibit:globe": "globo", "exhibit:totem": "totem",
	"exhibit:bear": "oso", "exhibit:plinth": "pedestal",
	"big:dinosaur": "dinosaurio", "big:sarcophagus": "sarcofago", "big:bear": "oso",
}

var main: Node3D
var shots: Array = []
var only: Array = []


func _initialize() -> void:
	only = Array(OS.get_cmdline_user_args())
	_run.call_deferred()


func _wants(part: String) -> bool:
	return only.is_empty() or part in only


func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://docs")
	Settings.path = "user://docs/settings.cfg"
	Story.save = "user://docs/progress.cfg"
	# A window, not the full screen; quiet; every night open to every gang.
	var s := Settings.DEFAULTS.duplicate()
	s.fullscreen = false
	s.sound = false
	s.music = false
	Settings.write(s)
	for n in range(1, 5):
		Story.unlock(Story.count(), n)
	for d in ["capturas", "assets/piezas", "assets/objetos", "assets/objetos/mapa", "assets/objetos/cerca", "assets/modelos", "assets/sonidos", "data"]:
		DirAccess.make_dir_recursive_absolute(_path(d))
	root.size = SIZE
	root.content_scale_size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _wait(1.0)
	get_root().size = SIZE
	if _wants("data"):
		_data()
	if _wants("shots"):
		await _shots()
	if _wants("assets"):
		await _assets()
	if _wants("sounds"):
		_sounds()
	if _wants("models"):
		await _models()
	if _wants("objects"):
		await _objects()
	if _wants("shots") or _wants("assets"):
		_save_shots()
	print("docs: hecho")
	quit()


# --- Helpers -------------------------------------------------------------------------

func _path(rel: String) -> String:
	return ProjectSettings.globalize_path(OUT + rel)


func _wait(secs: float) -> void:
	await create_timer(secs, true).timeout
	await RenderingServer.frame_post_draw


## The whole window, as the player sees it.
func _shot(id: String, section: String, title: String, text := "") -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_webp(_path("capturas/%s.webp" % id), true, 0.85)
	shots.append({"id": id, "section": section, "title": title, "text": text, "file": "capturas/%s.webp" % id})
	print("  ", id)


## The list of shots: this run's, and the earlier ones it did not retake
## (a run of only the assets keeps the screens), while their file is there.
func _save_shots() -> void:
	var taken := {}
	for s in shots:
		taken[s.id] = true
	var before: Variant = JSON.parse_string(FileAccess.get_file_as_string(_path("data/capturas.json")))
	var out: Array = []
	var order := ["menus", "ajustes", "previas", "juego", "finales", "assets"]
	if before is Array:
		for s in before:
			if not taken.has(s.id) and FileAccess.file_exists(_path(s.file)):
				out.append(s)
	out.append_array(shots)
	# By section, and in the order taken within one (sort_custom is not stable).
	for i in out.size():
		out[i]["_at"] = order.find(out[i].section) * 1000 + i
	out.sort_custom(func(a, b): return a._at < b._at)
	for s in out:
		s.erase("_at")
	_save_json("data/capturas.json", out)


func _save_json(rel: String, data: Variant) -> void:
	var f := FileAccess.open(_path(rel), FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))


## Out of whatever round is on: unpaused, map shut, no menu.
func _reset() -> void:
	paused = false
	main.testing = null
	main._close_map()
	for t in main.thieves:
		t.game = null


## A night in play: the mode, the night and the gang, the countdown skipped.
func _play(mode: String, night: int, gang: int, secs := 2.5) -> void:
	_reset()
	main.mode = mode
	main.players = gang
	var seats: Array[String] = []
	seats.assign(["kb_left", "kb_right", "pad:0", "pad:1"].slice(0, gang) if gang > 1 else ["any"])
	main.seats = seats
	main.story_pick = night
	main._new_round(night)
	main._start_playing()
	await _wait(secs)


## A thief right in front of the first guard, a couple of tiles down its look.
func _in_sight(t: Thief, g: Guard) -> void:
	for d in [4.5, 4.0, 5.0, 3.5]:
		var x: float = g.x + cos(g.dir) * d
		var y: float = g.y + sin(g.dir) * d
		if not Museum.is_wall(x, y):
			t.x = x
			t.y = y
			return


# --- Screens -------------------------------------------------------------------------

func _shots() -> void:
	print("docs: pantallas")
	# The cover, before the menus (only when there is a picture for it).
	if TitleScreen.available():
		main._show_cover()
		await _wait(1.5)
		await _shot("menu_portada", "menus", "Portada", "La primera imagen al abrir el juego; cualquier tecla lleva al título.")
		for c in main.get_children():
			if c is TitleScreen:
				c.queue_free()
	# Menus.
	main._show_title()
	await _wait(1.5)
	await _shot("menu_titulo", "menus", "Pantalla de título", "Los tres modos: historia, generativo y retos.")
	main._show_story_menu()
	await _wait(1.5)
	await _shot("menu_historia_jugadores", "menus", "Historia: cuántos ladrones", "Uno a cuatro, cada banda con su progreso.")
	main.players = 1
	main.story_pick = 1
	main._show_city()
	await _wait(1.5)
	await _shot("menu_historia_ciudad", "menus", "Historia: la ciudad", "La ciudad en 3D: los cinco museos, el río, la carretera y el escondite de la banda.")
	for m in Story.MUSEUMS.size():
		main._show_museum_tour(Story.nights_in(m)[0])
		await _wait(1.5)
		await _shot("menu_museo_%d" % (m + 1), "menus", "Museo %d: %s" % [m + 1, Text.t(Story.MUSEUMS[m].name)], "Por dentro, como una casa de muñecas: sus cinco salas con su pieza, la del gran golpe más ancha.")
	main._close_tour()
	main._show_generative_menu()
	await _wait(1.5)
	await _shot("menu_generativo", "menus", "Modo generativo", "Dificultad, tamaño del museo y número de ladrones.")
	main._show_challenge_menu()
	await _wait(1.5)
	await _shot("menu_retos", "menus", "Retos", "Los robos de la historia y los mapas hechos a mano, con el plano del elegido.")
	var maps := MapFile.list()
	if not maps.is_empty():
		main._show_challenge_map(maps[0])
		await _wait(1.5)
		await _shot("menu_reto_mapa", "menus", "Un reto elegido", maps[0].name if "name" in maps[0] else "")
	main._show_night_map(1)
	await _wait(1.5)
	await _shot("menu_reto_noche", "menus", "Retos: un robo de la historia", "Para retocar su museo en el editor.")
	main._show_editor(MapFile.generated(4242, "small"))
	await _wait(1.5)
	await _shot("menu_editor", "menus", "Editor de mapas")
	main._drop_editor()
	main._show_join("generative", 3)
	await _wait(1.5)
	await _shot("menu_elegir_mandos", "menus", "Elegir mandos", "Cada ladrón pulsa en su mando o en su mitad del teclado.")

	# Settings.
	for page in ["", "sound", "screen", "pads"]:
		main._show_settings("title", page)
		await _wait(1.2)
		await _shot("ajustes_" + (page if page != "" else "inicio"), "ajustes",
			{"": "Ajustes", "sound": "Ajustes: sonido", "screen": "Ajustes: pantalla", "pads": "Ajustes: mandos y controles"}[page])

	# Before a heist: the tale, the news (the lesson) and the plan; the
	# lessons' nights and the museums' big jobs.
	main.mode = "story"
	main.players = 1
	var pages := Story.prologue()
	for p in pages.size():
		main._show_prologue(p)
		await _wait(1.5)
		await _shot("previa_prologo_%d" % (p + 1), "previas", "Prólogo, página %d de %d" % [p + 1, pages.size()])
	# The story's way in (Tour): the plan out of its room, what is told over
	# it (the piece, the news, a rule) and then looked round.
	for n in [1, 2, 5, 6, 8, 11, 16, 25]:
		_reset()
		main.players = 1
		main.retell = true
		main._show_museum_tour(n)
		main._tour_room(n)
		await _wait(2.8)
		var talk: PlanTalk = main.tour.talk
		var what := "Robo %d%s" % [n, " (gran golpe)" if Story.is_boss(n) else ""]
		await _shot("previa_robo_%02d_pieza" % n, "previas", what + ": la pieza", Text.t(Story.level(n).loot.name))
		for kind in ["news", "rule"]:
			var at: int = talk.beats.map(func(b): return b.kind).find(kind)
			if at < 0:
				continue
			while talk.step < at:
				talk._next()
			await _wait(1.6)
			await _shot("previa_robo_%02d_%s" % [n, {"news": "nuevo", "rule": "regla"}[kind]], "previas", what + (": lo nuevo" if kind == "news" else ": una regla"))
		talk.skip()
		await _wait(1.2)
		await _shot("previa_robo_%02d_plano" % n, "previas", what + ": el plano para explorar", "Cada cosa contada, clavada en el plano; las estrellas arriba; ¡A ROBAR!")
		main._close_tour()
	_reset()
	main.mode = "generative"
	main.players = 2
	main._new_round(1)
	main._show_brief(0)
	await _wait(1.6)
	await _shot("previa_generativo_plan", "previas", "Generativo: el plan, dos ladrones")
	main._start_countdown()
	await _wait(0.6)
	await _shot("previa_cuenta_atras", "previas", "La cuenta atrás")
	await _wait(4.0)

	# In play.
	await _play("story", 1, 1)
	await _shot("juego_robo_01", "juego", "Robo 1: el museo vacío", "Sin guardias: aprender a llevarse la pieza.")
	await _play("story", 4, 1, 4.0)
	await _shot("juego_robo_04_linterna", "juego", "Robo 4: la linterna", "Un guardia quieto junto al camino y su cono de luz.")
	await _play("story", 8, 1, 3.0)
	await _shot("juego_robo_08_objetos", "juego", "Robo 8: objetos que se caen", "Papeleras y paneles que hacen ruido (bustos en el mundo antiguo, armaduras en la Edad Media).")
	await _play("story", 13, 2, 3.0)
	await _shot("juego_robo_13_dos", "juego", "Robo 13: dos guardias, dos ladrones")
	await _play("story", 16, 1, 3.0)
	await _shot("juego_robo_16_luces", "juego", "Robo 16: las luces", "Salas encendidas e interruptores.")
	await _play("story", 25, 4, 3.0)
	await _shot("juego_robo_25_final", "juego", "Robo 25: el gran final", "Cuatro guardias y la banda de cuatro.")
	await _play("story", 13, 1, 1.0)
	if not main.guards.is_empty():
		_in_sight(main.thieves[0], main.guards[0])
		main.guards[0].suspicion = 1
		main.guards[0].suspicion_at = Sim.now_ms()
		await _wait(0.4)
		await _shot("juego_algo_raro", "juego", "Algo raro", "Un guardia con el ladrón delante: la marca ! sobre él.")
	# A chase from afar: the guard on the hunt, the thief still well away.
	await _play("story", 16, 1, 1.0)
	for g in main.guards:
		g.alert = true
		g.suspicion = 3
		g.sees_player = true
	await _wait(1.0)
	await _shot("juego_persecucion", "juego", "Alerta", "Los guardias en alerta: linternas rojas y marcas !!! sobre ellos.")
	var games := [["lockpick", "case", 18, "Minijuego: la ganzúa", "Forzar la cerradura de la vitrina."],
		["wires", "panel", 19, "Minijuego: los cables", "Desconectar el cuadro de alarma."],
		["steady", "case", 19, "Minijuego: la ventosa", "Cortar el cristal sin moverse."],
		["balance", "plinth", 21, "Minijuego: el equilibrio", "Hacerse pasar por estatua sobre un pedestal."],
		["squeeze", "hideout", 11, "Minijuego: colarse", "Meterse en un escondite, de dos a cinco segundos a la vista."],
		["sneeze", "hideout", 18, "Minijuego: el estornudo", "Escondido, aguantar el estornudo: pulsar cuando el polvo pasa por la barra."],
		["arcade", "arcade", 21, "Minijuego: la recreativa", "Un pong de broma en la máquina: no se gana nada y los guardias siguen su ronda."]]
	for g in games:
		await _play("story", g[2], 1, 1.0)
		if g[0] == "arcade":
			# In front of a machine: the modern museum's, the first night that has one.
			for n in range(g[2], Story.count() + 1):
				if not Arcades.list.is_empty():
					break
				await _play("story", n + 1, 1, 1.0)
			if Arcades.list.is_empty():
				continue
			var at: Vector2i = Arcades.list[0]
			var front := MuseumView.front_of(at)
			var t0: Thief = main.thieves[0]
			t0.x = at.x + 0.5 + front.x * 0.95
			t0.y = at.y + 0.5 + front.y * 0.95
			t0.arcade = at
			t0.dir = atan2(-front.y, -front.x)
		if g[0] == "sneeze":
			# Already in: the sneeze is what comes on after a while inside.
			for n in range(g[2], Story.count() + 1):
				if not Hideouts.all().is_empty():
					break
				await _play("story", n + 1, 1, 1.0)
			if Hideouts.all().is_empty():
				continue
			var none: Array[Guard] = []
			Hideouts.get_in(main.thieves[0], Hideouts.all()[0], none)
		if g[0] == "balance":
			# Up on a pedestal first: the balance is the pose's.
			for n in range(g[2], Story.count() + 1):
				if not Plinths.list.is_empty():
					break
				await _play("story", n + 1, 1, 1.0)
			if not Plinths.list.is_empty():
				Plinths.climb(main.thieves[0], Plinths.list[0], main.guards)
		if g[0] == "squeeze":
			# Wriggling into a hideout: it needs one to wriggle into.
			var spots := Hideouts.all()
			if not spots.is_empty():
				main.thieves[0].hide_target = spots[0]
		main.thieves[0].game = Minigame.make(g[0], g[1], 3, {})
		await _wait(1.2)
		await _shot("juego_minijuego_" + g[0], "juego", g[3], g[4])
	await _play("story", 21, 1, 2.0)
	main._toggle_map()
	await _wait(1.2)
	await _shot("juego_mapa", "juego", "El mapa", "El plano con la banda, la pieza, la salida y los guardias.")
	await _play("generative", 1, 1, 3.0)
	await _shot("juego_generativo", "juego", "Generativo: un museo nuevo")
	if not maps.is_empty():
		main.challenge_map = maps[0]
		await _play("challenge", 1, 1, 3.0)
		await _shot("juego_reto", "juego", "Un reto hecho a mano")
	await _play("story", 6, 1, 2.0)
	main._pause()
	await _wait(1.0)
	await _shot("juego_pausa", "juego", "Pausa")
	_reset()

	# Endings.
	await _play("story", 5, 1, 1.0)
	main.phase = "caught"
	main._show_end()
	await _wait(1.5)
	await _shot("final_pillado", "finales", "Te han pillado")
	await _play("story", 5, 1, 1.0)
	main.phase = "escaped"
	main._show_end()
	await _wait(1.5)
	await _shot("final_escapado", "finales", "¡Lo habéis conseguido!")
	main._show_ending()
	await _wait(1.5)
	await _shot("final_historia", "finales", "El final de la historia")
	_reset()
	main._show_title()


# --- Assets --------------------------------------------------------------------------

## The assets page, a picture of each piece and prop on its stand, and the
## page itself for the characters and the map's marks.
func _assets() -> void:
	print("docs: assets")
	var out := {"piezas": [], "objetos": [], "paginas": []}
	var loot: Array = main._asset_loot()
	for i in loot.size():
		main._show_assets("loot", i)
		await _wait(0.9)
		var l: Dictionary = loot[i]
		var file := "assets/piezas/%02d.webp" % (i + 1)
		main.preview.get_texture().get_image().save_webp(_path(file), true, 0.9)
		out.piezas.append({"file": file, "name": l.name, "blurb": l.get("blurb", ""), "shape": l.get("shape", ""), "colour": l.get("colour", ""),
			"night": i + 1 if i < Story.count() else 0})
		if i == 0:
			await _shot("assets_piezas", "assets", "Assets: piezas")
	for i in Props.KINDS.size():
		main._show_assets("props", i)
		await _wait(0.9)
		var file := "assets/objetos/%s.webp" % Props.KINDS[i]
		main.preview.get_texture().get_image().save_webp(_path(file), true, 0.9)
		out.objetos.append({"file": file, "kind": Props.KINDS[i], "name": Props.name_of(Props.KINDS[i])})
	for tab in ["props", "people", "sounds", "map"]:
		main._show_assets(tab, 0)
		await _wait(1.5)
		await _shot("assets_" + tab, "assets", "Assets: " + Text.t(main.ASSET_TABS[tab]).to_lower())
	_save_json("data/assets.json", out)


## Each sound the game makes up, as a .wav.
func _sounds() -> void:
	print("docs: sonidos")
	var list: Array = []
	for name in main.sfx.sound_names():
		var w: AudioStreamWAV = main.sfx._streams[name]
		var file := "assets/sonidos/%s.wav" % name
		w.save_to_wav(_path(file))
		list.append({"name": name, "file": file, "seconds": snappedf(w.get_length(), 0.01)})
	_save_json("data/sonidos.json", list)


## Each .glb on its own, in the game's toon shading, turned three-quarters.
func _models() -> void:
	print("docs: modelos")
	var vp := SubViewport.new()
	vp.size = Vector2i(MODEL_SIZE, MODEL_SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#c8c0e0")
	env.environment.ambient_light_energy = 0.9
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var list: Array = []
	for rel in _glbs("res://assets/models"):
		var name: String = rel.trim_suffix(".glb")
		var node := MuseumView.asset(name)
		vp.add_child(node)
		var box := _bounds(node)
		var centre := box.get_center()
		var span := maxf(box.size.x, maxf(box.size.y, box.size.z))
		cam.size = span * 1.35
		cam.position = centre + Vector3(1.0, 0.7, 1.3).normalized() * span * 4.0
		cam.look_at(centre)
		cam.near = 0.01
		cam.far = span * 10.0
		await _wait(0.15)
		var file := "assets/modelos/%s.webp" % name.replace("/", "__")
		vp.get_texture().get_image().save_webp(_path(file), true, 0.9)
		var group := "museo"
		if name.begins_with("temas/"):
			group = name.split("/")[1]
		var entry := {"name": name, "file": file, "group": group, "size": [snappedf(box.size.x, 0.01), snappedf(box.size.y, 0.01), snappedf(box.size.z, 0.01)]}
		# A piece with variants (Themes.VARIANTS): each of them too, the same way.
		var variants: Array = []
		for v in Themes.variants(name):
			var dressed := MuseumView.asset(name)
			if name == Arcades.MODEL:
				MuseumView.arcade_game(dressed, v)
			node.visible = false
			vp.add_child(dressed)
			await _wait(0.15)
			var vfile := "assets/modelos/%s__%s.webp" % [name.replace("/", "__"), v]
			vp.get_texture().get_image().save_webp(_path(vfile), true, 0.9)
			variants.append({"id": v, "name": "PIECE_%s_%s" % [name.get_file().to_upper(), v.to_upper()], "file": vfile})
			dressed.queue_free()
			print("  ", name, " ", v)
		if not variants.is_empty():
			entry["variants"] = variants
		list.append(entry)
		node.queue_free()
		print("  ", name)
	vp.queue_free()
	_save_json("data/modelos.json", list)


func _glbs(dir: String, prefix := "") -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb"):
			out.append(prefix + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_glbs(dir + "/" + d, prefix + d + "/"))
	out.sort()
	return out


func _bounds(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# --- Objects -------------------------------------------------------------------------

## The camera's distance for the tiles round a piece, and for the piece close up.
const OBJECT_FAR := 4.2
const OBJECT_NEAR := 1.9
const OBJECT_SIZE := 480

## Each piece of the editor's catalogue (Themes.catalogue) as the game shows
## it: stood the way the editor stands it (in its glass case, on a plinth,
## on the floor, a big piece on its block, a prop), in a little gallery of
## its own, from the game's camera: with the tiles round it, and close up.
func _objects() -> void:
	print("docs: objetos")
	var out: Array = []
	for entry in Themes.catalogue():
		var tool: String = entry[0]
		if tool == "case":
			continue
		# "exhibit", "big" (the big pieces, not the theme's floor pieces) or "prop"
		var what: String = tool.split(":", true, 1)[0]
		var kind: String = tool.split(":", true, 1)[1]
		var id := tool.replace(":", "__").replace("/", "__")
		var m := MapFile.blank(11, 11)
		m.seed = 7
		m.rooms.append(Rect2i(1, 1, 9, 9))
		m.spawn = Vector2i(1, 9)
		# The piece to steal and the guards, well out of the picture.
		m.grid[1 * m.w + 1] = Tiles.COVER
		m.piece = Vector2i(1, 1)
		for g in [Vector2i(9, 9), Vector2i(8, 9), Vector2i(9, 8)]:
			m.guards.append(g)
		var at := Vector2i(5, 5)
		var tiles := Vector2i(1, 1)
		if what == "prop":
			m.props.append({"kind": kind, "at": at})
		else:
			# A prop of its own out of sight, or the night stands a few at random.
			m.props.append({"kind": "bin", "at": Vector2i(9, 1)})
			if what == "big":
				tiles = MapGen.BIG[kind]
				var r := Rect2i(at - (tiles - Vector2i.ONE) / 2, tiles)
				for y in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						m.grid[y * m.w + x] = Tiles.COVER
				m.big.append({"kind": kind, "rect": r})
			else:
				m.grid[at.y * m.w + at.x] = Tiles.COVER
				m.exhibits[at] = kind
		var centre := Vector2(at) + Vector2(tiles) / 2.0 - Vector2((tiles.x - 1) / 2, (tiles.y - 1) / 2)
		_reset()
		main.mode = "challenge"
		main.players = 1
		var seats: Array[String] = ["any"]
		main.seats = seats
		main.challenge_map = m
		main._new_round(1)
		main._start_playing()
		await _wait(0.4)
		# Still (not quite 0: a step of nothing divides by it), with nobody
		# about: no thieves, no guards, nor their torches and cones.
		Engine.time_scale = 0.001
		main.hud.visible = false
		for f in main.thief_nodes + main.guard_nodes:
			f.visible = false
		for t in main.torches:
			t.visible = false
		for c in main.cones:
			c.visible = false
		var files := {}
		for view in [["mapa", OBJECT_FAR], ["cerca", OBJECT_NEAR]]:
			_aim(MuseumView.to_world(centre.x, centre.y, 0.35), view[1] * maxf(1.0, maxf(tiles.x, tiles.y) / 2.2 if view[0] == "cerca" else 1.0))
			for i in 3:
				await RenderingServer.frame_post_draw
			var img := root.get_texture().get_image()
			var side := mini(img.get_width(), img.get_height())
			img = img.get_region(Rect2i((img.get_width() - side) / 2, (img.get_height() - side) / 2, side, side))
			img.resize(OBJECT_SIZE, OBJECT_SIZE, Image.INTERPOLATE_LANCZOS)
			files[view[0]] = "assets/objetos/%s/%s.webp" % [view[0], id]
			img.save_webp(_path(files[view[0]]), true, 0.88)
		Engine.time_scale = 1.0
		main.camera.make_current()
		main.hud.visible = true
		out.append({"tool": tool, "kind": kind, "type": entry[2], "themes": entry[1], "tiles": [tiles.x, tiles.y],
			"model": MODEL_OF.get(tool, kind if "/" in kind else ""), "mapa": files.mapa, "cerca": files.cerca,
			"name": _object_name(what, kind), "desc": _object_desc(what, kind)})
		print("  ", tool)
	_reset()
	main._show_title()
	_save_json("data/objetos.json", out)


## A camera of our own at the game's (its angle and lens, not its zoom, and
## not following anyone), looking at this point from this far.
var _cam: Camera3D

func _aim(target: Vector3, dist: float) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		main.add_child(_cam)
	_cam.fov = main.camera.fov
	_cam.position = target + main.CAM_OFFSET.normalized() * dist
	_cam.look_at(target)
	_cam.make_current()
	main.cam_zoom = dist / main.CAM_OFFSET.length()
	main._fog_follows_zoom()


## A piece's name on screen (Themes.label), as its key.
func _object_name(what: String, kind: String) -> String:
	if what == "prop":
		return "PROP_" + kind.to_upper()
	if what == "big":
		return "EDITOR_TOOL_BIG_" + kind.to_upper()
	if "/" in kind:
		return "PIECE_" + kind.get_file().to_upper()
	return "EDITOR_TOOL_EXHIBIT_" + kind.to_upper()


## The key of its description, written in the docs (DESC_...).
func _object_desc(what: String, kind: String) -> String:
	if what == "prop" or what == "big":
		return "DESC_%s_%s" % [what.to_upper(), kind.to_upper()]
	return "DESC_" + kind.get_file().to_upper()


# --- Data ----------------------------------------------------------------------------

## The palette (every Color constant in the game's scripts, and every table
## of them, with the ## comment above it), the story and the maps.
func _data() -> void:
	print("docs: datos")
	var palette: Array = []
	for dir in ["res://scenes", "res://logic"]:
		for f in DirAccess.get_files_at(dir):
			if not f.ends_with(".gd"):
				continue
			var path: String = dir + "/" + f
			var script: Script = load(path)
			var notes := _const_notes(path)
			var consts := script.get_script_constant_map()
			for k in consts:
				var v: Variant = consts[k]
				var colours := _colours_in(v)
				if colours.is_empty():
					continue
				palette.append({"file": path.trim_prefix("res://"), "name": k, "note": notes.get(k, ""), "colours": colours})
	_save_json("data/paleta.json", palette)
	var nights: Array = []
	for n in range(1, Story.count() + 1):
		var lv: Dictionary = Story.LEVELS[n - 1].duplicate(true)
		lv["n"] = n
		lv["museum"] = Story.museum_of(n) + 1
		lv["news"] = Story.news(n, 1)
		nights.append(_plain(lv))
	var museums: Array = []
	for m in Story.MUSEUMS.size():
		var mu: Dictionary = Story.MUSEUMS[m].duplicate(true)
		mu["n"] = m + 1
		mu["nights_list"] = Story.nights_in(m)
		museums.append(_plain(mu))
	# A save from the story of twenty nights, night by night, as a heist of this one.
	var old: Array = []
	for n in range(1, 21):
		old.append([n, Story.from_old(n)])
	_save_json("data/historia.json", {"museums": museums, "nights": nights, "lessons": _plain(Story.LESSONS),
		"prologue": Story.PROLOGUE, "ending": Story.ENDING, "rooms": Story.ROOMS, "lockpick_night": Story.LOCKPICK_NIGHT,
		"from_old": old, "played": _nights_laid_out()})
	var hide := {}
	for k in Hideouts.PIECES:
		hide[k] = {"model": Hideouts.PIECES[k].model, "theme": Hideouts.PIECES[k].theme, "name": "HIDE_" + k.to_upper()}
	_save_json("data/catalogo.json", {"themes": _plain(Themes.ALL), "exhibits": MuseumView.EXHIBITS, "big": MapGen.BIG.keys(),
		"props": Props.KINDS, "prop_themes": Themes.PROP_THEMES, "model_of": MODEL_OF,
		"unique": Themes.UNIQUE, "variants": Themes.VARIANTS, "fronted": Themes.FRONTED,
		"arcade_games": MuseumView.ARCADE_GAMES, "arcade_model": Arcades.MODEL,
		"hideouts": {"pieces": hide, "big": Hideouts.BIG, "tight": Hideouts.TIGHT,
			"big_names": Hideouts.BIG.map(func(k): return "HIDE_" + k.to_upper())},
		"minigames": _minigames()})


## Every minigame there is (logic/minigames/), with its lines on screen.
func _minigames() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://logic/minigames"):
		if not f.ends_with(".gd"):
			continue
		var kind := f.get_basename()
		var g := Minigame.make(kind, "", 3, {}, 1, 1)
		out.append({"kind": kind, "class": (load("res://logic/minigames/" + f) as Script).get_global_name(),
			"how": g.how(), "let_go": g.let_go(), "can_let_go": g.can_let_go(),
			"logic": "logic/minigames/" + f, "view": "scenes/minigame_views/" + f})
	return out


## Each story night as it is laid out, for a lone thief: what its plan
## screen says (Briefing.tips) and has (the pages), the heading over the
## piece (Story.heading), the minigames' level, and what the museum has to
## hide in, pose on and play (Hideouts, Plinths, Arcades).
func _nights_laid_out() -> Array:
	var out: Array = []
	for n in range(1, Story.count() + 1):
		_reset()
		main.mode = "story"
		main.players = 1
		var seats: Array[String] = ["any"]
		main.seats = seats
		main.story_pick = n
		main._new_round(n)
		var hides := {}
		for s in Hideouts.all():
			hides[s.kind] = hides.get(s.kind, 0) + 1
		var games: Array = []
		for t in Arcades.list:
			games.append(Collection.variant_at(t))
		var icons: Array = []
		for t in Collection.picks:
			var piece: String = Collection.picks[t][1]
			if Themes.is_unique(piece) and not piece in icons:
				icons.append(piece)
		for b in Museum.big_pieces:
			if Themes.is_unique(b.kind) and not b.kind in icons:
				icons.append(b.kind)
		var tuning := Story.tuning(n)
		out.append({"n": n, "heading": Story.heading(n, 1), "heading_gang": Story.heading(n, 2), "pages": main._brief_pages(),
			"tips": Briefing.tips(main.guards, n), "game_level": tuning.game_level, "lockpick": tuning.lockpick,
			"minigames": Heist.minigames(), "hideouts": hides, "plinths": Plinths.list.size(), "arcades": games, "icons": icons,
			"size": Museum.size_name, "w": Museum.w, "h": Museum.h})
	_reset()
	return out


## The "## ..." lines right above each const, by name.
func _const_notes(path: String) -> Dictionary:
	var out := {}
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var last := ""
	for i in lines.size():
		var line := lines[i].strip_edges()
		if not line.begins_with("const "):
			if not line.begins_with("##") and not line.begins_with("\t") and line != "}" and line != "]":
				last = ""
			continue
		var name := line.substr(6).split(" ")[0].split(":")[0]
		var note: Array[String] = []
		var j := i - 1
		while j >= 0 and lines[j].strip_edges().begins_with("##"):
			note.push_front(lines[j].strip_edges().trim_prefix("##").strip_edges())
			j -= 1
		# A run of consts under one comment shares it.
		last = " ".join(note) if not note.is_empty() else last
		out[name] = last
	return out


## A colour, or a table of them (by key or in order): [{key, hex}].
func _colours_in(v: Variant) -> Array:
	var out: Array = []
	if v is Color:
		out.append({"key": "", "hex": "#" + (v as Color).to_html((v as Color).a < 1.0)})
	elif v is Dictionary:
		for k in v:
			if v[k] is Color:
				out.append({"key": str(k), "hex": "#" + (v[k] as Color).to_html((v[k] as Color).a < 1.0)})
	elif v is Array:
		for i in v.size():
			if v[i] is Color:
				out.append({"key": str(i), "hex": "#" + (v[i] as Color).to_html((v[i] as Color).a < 1.0)})
	return out


## Colours as "#rrggbb", so the JSON reads plainly.
func _plain(v: Variant) -> Variant:
	if v is Color:
		return "#" + (v as Color).to_html(false)
	if v is Dictionary:
		var d := {}
		for k in v:
			d[k] = _plain(v[k])
		return d
	if v is Array:
		return (v as Array).map(_plain)
	return v
