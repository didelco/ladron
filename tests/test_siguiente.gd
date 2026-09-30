extends SceneTree
## Sobre el plano, SIGUIENTE y nada más: tras la historia de la pieza, cada
## noche de la historia pasa por el encargo (junto a la vitrina), lo nuevo
## (junto a lo que lo lleva) y las reglas de la noche (cada una junto a lo
## que va), sin ir a buscarlas; no pasa por la entrada ni la salida ni por
## lo de siempre, que se eligen al explorar; y acaba en el plano para
## explorar con ¡A ROBAR! elegido. Con uno y con dos ladrones.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func frames(n := 4) -> void:
	for i in n:
		await process_frame


## Night n told from the start, SIGUIENTE after SIGUIENTE: what was on
## screen at each press, and whether it all held.
func walk(m, n: int, players: int) -> void:
	m.players = players
	m.retell = true
	m._show_museum_tour(n)
	m._tour_room(n)
	await frames(8)
	var t: Tour = m.tour
	var talk: PlanTalk = t.talk
	var what := "robo %d (%d)" % [n, players]
	var rules: Array = talk.beats.filter(func(b): return b.kind == "rule")
	var news := Story.news(n, players).size()
	var seen: Array = []
	var ok := true
	var told_rules := {}
	var presses := 0
	while talk.mode in ["story", "step"] and presses < 40:
		if talk.mode == "story":
			seen.append("historia")
		else:
			var s: Dictionary = talk.steps[talk.page]
			seen.append(s.kind if s.kind != "mark" else talk.marks[s.mark].kind)
			# Out of its place: the card points where its thing is.
			var at: Vector2 = talk.marks[s.mark].at if s.mark >= 0 else talk.beats[s.beat].at
			ok = ok and talk._card != null and talk._card_at == at
			if s.mark >= 0:
				for r in talk.marks[s.mark].rules:
					told_rules[r] = told_rules.get(r, 0) + 1
			if s.kind == "mark":
				ok = ok and not (talk.marks[s.mark].rules as Array).is_empty()
		t.act("accept")
		presses += 1
	var steps: Array = seen.filter(func(k): return k != "historia")
	check(ok, what + ": cada cosa sale de su sitio en el plano " + str(seen))
	check(seen.slice(0, talk.pages.size()).all(func(k): return k == "historia") and steps.size() > 0 and steps[0] == "piece",
		what + ": la historia, luego el encargo en la vitrina")
	check(steps.count("news") == news and (news == 0 or steps[1] == "news"), what + ": lo nuevo (%d), justo después" % news)
	check(told_rules.size() == rules.size() and told_rules.values().all(func(c): return c == 1), what + ": cada regla de la noche, una vez (%d)" % rules.size())
	var routine := 0
	for s in talk.steps:
		if s.kind == "mark" and talk.marks[s.mark].kind in ["start", "exit"] and (talk.marks[s.mark].rules as Array).is_empty():
			routine += 1
	check(routine == 0 and talk.steps.all(func(s): return s.beat < 0 or talk.beats[s.beat].kind in ["piece", "news"]),
		what + ": ni la entrada ni la salida de siempre")
	check(steps.size() <= 1 + news + Briefing.MOST, what + ": %d pasos, no más que encargo + lo nuevo + %d reglas" % [steps.size(), Briefing.MOST])
	check(talk.mode == "explore" and talk.cursor == talk.marks.size(), what + ": al final, el plano para explorar con ¡A ROBAR! elegido")
	var kinds: Array = talk.marks.map(func(k): return k.kind)
	check("start" in kinds and "exit" in kinds, what + ": la entrada y la salida, para elegir al explorar")
	# The hint for accepting says what it does: start, or see a mark.
	var accept_hint := func() -> String:
		await frames(1)
		for box in t._hints.get_children():
			if not box.is_queued_for_deletion() and box.get_meta("what", "") == "accept":
				return (box.get_child(1) as Label).text
		return ""
	var on_start: String = await accept_hint.call()
	talk._pick(0)
	var on_mark: String = await accept_hint.call()
	check(on_start == Text.t("TOUR_START") and on_mark == Text.t("TOUR_HINT_SEE"),
		what + ": aceptar, en la ayuda, dice lo que hace: '%s' en ¡A ROBAR!, '%s' en una chincheta" % [on_start, on_mark])
	# The mouse onto the start button, from a mark with rules: its rules go out.
	var ruled: int = talk.marks.find_custom(func(k): return not (k.rules as Array).is_empty())
	if ruled >= 0:
		talk._pick(ruled)
		talk._start.mouse_entered.emit()
		var lit: Array = talk._rule_lines.filter(func(l): return l.text.begins_with("▶"))
		check(talk.cursor == talk.marks.size() and lit.is_empty() and await accept_hint.call() == Text.t("TOUR_START"),
			what + ": el ratón sobre ¡A ROBAR! lo elige y apaga las reglas de la chincheta de antes (%d encendidas)" % lit.size())
	m._close_tour()
	await frames()


func _init() -> void:
	Story.save = "user://test_siguiente.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	m.tour_hurry = true
	m.mode = "story"
	m.seats.assign(["kb_left"])
	var with_news := 0
	var without := 0
	var bosses := 0
	for n in range(1, Story.count() + 1):
		await walk(m, n, 1)
		if Story.is_boss(n):
			bosses += 1
		elif Story.news(n, 1).is_empty():
			without += 1
		else:
			with_news += 1
	check(with_news > 0 and without > 0 and bosses > 0, "noches con lo nuevo (%d), sin él (%d) y grandes golpes (%d)" % [with_news, without, bosses])
	# A gang of two: its own news and its own rules.
	m.seats.assign(["kb_left", "kb_right"])
	for n in [1, 2, 5]:
		await walk(m, n, 2)
	# The boss's own line among what is gone through.
	m.players = 1
	m.seats.assign(["kb_left"])
	var boss := 5
	while not Story.is_boss(boss):
		boss += 1
	m.retell = true
	m._show_museum_tour(boss)
	m._tour_room(boss)
	await frames(8)
	var talk: PlanTalk = m.tour.talk
	var tip := Text.t(String(Story.LEVELS[boss - 1].get("tip", "")))
	var said := false
	while talk.mode in ["story", "step"]:
		if talk.mode == "step" and talk._card:
			for l in talk._card.find_children("*", "Label", true, false):
				said = said or (l as Label).text.ends_with(tip)
		m.tour.act("accept")
	check(tip != "" and said, "el gran golpe %d: su regla propia, dicha junto a lo suyo" % boss)
	m.tour.act("accept")
	await frames()
	check(m.phase == "countdown", "y un SIGUIENTE más: ¡a robar!")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
