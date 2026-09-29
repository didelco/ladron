extends SceneTree
## Los finales y la pausa: el periódico si te escapas, la ficha si te
## pillan (con y sin historia, con uno y con dos), los botones de siempre
## debajo con el foco en el primero; el monitor de la pausa, que se enciende
## y se apaga; y las cifras del golpe, que suman y vuelven a cero.
var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1


func buttons(hud: Hud) -> Array:
	var out: Array = []
	for b in hud._panel_box.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return out


func _init() -> void:
	# Nothing here is saved where the player keeps the story.
	Story.save = "user://test_finales.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))

	# The figures, on their own.
	HeistStats.reset()
	check(HeistStats.time == 0.0 and HeistStats.KINDS.all(func(k): return HeistStats.count(k) == 0), "a cero al empezar")
	HeistStats.add("smoke")
	HeistStats.add("smoke")
	HeistStats.add("hides", 3)
	HeistStats.time = 102.4
	check(HeistStats.count("smoke") == 2 and HeistStats.count("hides") == 3, "suman: 2 bombas, 3 escondites")
	var h := HeistStats.highlights()
	check(h[0] == ["time", 102] and h[1] == ["seen", 0], "primero el tiempo y las veces visto (0 también) " + str(h))
	check(h.size() == 4 and h[2][0] == "smoke" and h[3][0] == "hides", "luego lo que pasó, en su orden")
	for k in HeistStats.KINDS:
		HeistStats.add(k)
	check(HeistStats.highlights().size() == HeistStats.SHOWN, "nunca más de %d cifras" % HeistStats.SHOWN)
	check(HeistStats.clock(102) == "1:42" and HeistStats.clock(5) == "0:05", "el tiempo, como 1:42")
	HeistStats.reset()
	check(HeistStats.highlights().size() == 2, "sin nada que contar: el tiempo y las veces visto")

	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	var hud: Hud = m.hud
	m.just_looking = true

	# Each attempt starts from nothing; the game counts as it goes.
	m.mode = "story"
	m._new_round(3)
	HeistStats.add("seen", 4)
	m.phase = "playing"
	m._tick(0.5)
	check(is_equal_approx(HeistStats.time, 0.5), "el reloj corre jugando")
	var knocked := HeistStats.count("knocked")
	var bin := Props.Prop.new()
	bin.kind = "bin"
	m._prop_fell(bin)
	check(HeistStats.count("knocked") == knocked + 1, "tirar algo cuenta")
	m.phase = "caught"
	m._prop_fell(bin)
	check(HeistStats.count("knocked") == knocked + 1, "... pero solo jugando")
	if not Hideouts.all().is_empty():
		m._hid(m.thieves[0], Hideouts.all()[0])
		check(HeistStats.count("hides") == 1, "esconderse cuenta")
	m._again()
	# In the story, again is back to the museum: the round is laid out as
	# its plan comes out of the room.
	if m.tour:
		m._tour_room(m.level)
	check(HeistStats.time == 0.0 and HeistStats.count("seen") == 0 and HeistStats.count("knocked") == 0, "otra vez: todo a cero")

	# The ends: story and generative, one thief and two.
	for mode in ["story", "generative"]:
		for n in [1, 2]:
			var tag := "%s, %d" % [mode, n]
			m.mode = mode
			m.players = n
			m._new_round(2)
			HeistStats.add("smoke")
			m.phase = "escaped"
			m._show_end()
			await process_frame
			await process_frame
			var paper = hud._panel_box.find_children("*", "PanelContainer", true, false)
			check(not paper.is_empty(), tag + ": sale el periódico")
			var b := buttons(hud)
			var next: String = Text.t("END_NEXT_NIGHT" if mode == "story" else "END_NEXT_HEIST")
			check(b.size() == 2 and b[0] == next and b[1] == Text.t("END_TO_MENU"), tag + ": los botones de siempre " + str(b))
			var focus := root.gui_get_focus_owner()
			check(focus is Button and (focus as Button).text == next, tag + ": el foco en el primero")
			var page: Dictionary = m._front_page(false)
			check(page.headline != "" and page.photo is Texture2D, tag + ": titular y foto de la pieza")
			check(page.figures.size() <= HeistStats.SHOWN and page.figures[0][1] == Text.t("END_STAT_TIME"), tag + ": las cifras, con el tiempo primero")
			check(page.figures[1][1] == Text.t("END_STAT_SEEN_MANY" if n > 1 else "END_STAT_SEEN_ONE"), tag + ": te vieron / os vieron")
			check(page.figures.any(func(f): return f[1] == Text.t("END_STAT_SMOKE_ONE")), tag + ": la bomba tirada sale")
			m.phase = "caught"
			m.caught_by = "Vela"
			m._show_end()
			await process_frame
			await process_frame
			b = buttons(hud)
			check(b.size() == 2 and b[0] == Text.t("END_AGAIN"), tag + ": pillado, OTRA VEZ " + str(b))
			var focus_caught := root.gui_get_focus_owner()
			check(focus_caught is Button and (focus_caught as Button).text == Text.t("END_AGAIN"), tag + ": pillado, el foco en OTRA VEZ")
			var file: Dictionary = m._police_file()
			var crime: String = file.rows[0][1]
			check(file.rows.size() == 1 and file.rows[0][0] == Text.t("END_FILE_CRIME"), tag + ": un solo campo, el delito")
			check(crime.contains("Vela") and crime.contains(Text.t("END_FILE_BY_ONE" if n == 1 else "END_FILE_BY_MANY").replace(" %s", "")), tag + ": el delito dice quién te pilló")
			check(crime.contains(Heist.loot.name), tag + ": ... y qué intentabas llevarte")
			check(file.notes[1] != "" and not file.notes[1].begins_with("END_") and not crime.contains("END_"), tag + ": con delito y observaciones de broma")
			check(not file.has("tick") and file.rows.size() == 1, tag + ": sin alias ni reincidente")
			check(file.stamp.contains(str(n)) if n > 1 else file.stamp == Text.t("END_FILE_STAMP_ONE"), tag + ": el sello cuenta cuántos")
			check(file.photo is Texture2D and file.photo.resource_path == EndPages.MUGSHOT_PHOTO, tag + ": la foto de siempre, de frente y de perfil")
			check(file.number == Text.t("END_FILE_NUMBER") % m.files_opened, tag + ": con su número")
	# A piece with nothing to say about it, and a long name, still make the
	# page: the headline never runs a name too long for it.
	Heist.loot.erase("blurb")
	Heist.loot.erase("story")
	Heist.loot.name = "el pedrusco que cayó del cielo del farero Ramón"
	for lv in range(1, 12):
		m.level = lv
		var bare: Dictionary = m._front_page(false)
		check(bare.headline != "" and not bare.headline.contains("PEDRUSCO"), "sin historia y con un nombre largo, titular que cabe (%d)" % lv)
	m.mode = "story"
	m._new_round(5)
	check(Text.t("END_HEAD_MUSEUM").left(10) in m._front_page(true).headline, "tras el gran golpe, el museo desvalijado")

	# The pause: the monitor on, the menu over it, off again on the way back.
	m.phase = "playing"
	m._pause()
	await process_frame
	check(paused and hud.cctv_on(), "en pausa se ve el monitor")
	check(buttons(hud).size() == 3, "reanudar, ajustes, salir")
	check(Hud.cctv_caps("la sala de los fósiles") == "LA SALA DE LOS FOSILES", "el monitor escribe en mayúsculas sin tildes")
	m.options.show("paused")
	check(hud.cctv_on(), "los ajustes desde la pausa lo mantienen")
	m.options.back()
	m._start_playing()
	check(not paused, "reanudar quita la pausa")
	await create_timer(0.5).timeout
	check(not hud.cctv_on(), "... y el monitor se apaga")
	m._pause()
	m._quit_to_title()
	check(not hud.cctv_on(), "salir al menú lo apaga")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("FALLOS: %d" % fails)
	quit(1 if fails else 0)
