extends SceneTree
## La megafonía: cada suceso tiene sus frases (MEGA_* en el CSV, sin filas
## rotas), cortas; hablan poco (huecos largos y tope por robo), con prioridad;
## comentan lo que hace el ladrón pronto, solo a veces y sin repetir frase (ni en
## el robo siguiente); el primer robo (sin guardias) no habla de guardias; las
## pistas son del museo de la noche; y en el juego el rótulo cabe en 4:3 y en 32:9.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func words(t: String) -> int:
	return t.replace("%s", "").split(" ", false).size()


## The CSV read on its own, row by row (a broken row shows here).
func csv_keys() -> Dictionary:
	var out := {}
	var f := FileAccess.open("res://locale/texts.csv", FileAccess.READ)
	f.get_csv_line()
	var bad := 0
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() == 1 and row[0] == "":
			continue
		if row.size() != 2 or row[0] == "" or row[1] == "":
			bad += 1
			continue
		out[row[0]] = row[1]
	out["__bad"] = bad
	return out


## A night played out for `secs` seconds: an event every `every` seconds.
func run(mega: Megaphone, secs: float, kinds: Array, every: float) -> Array:
	var out: Array = []
	var t := 0.0
	var i := 0
	while t < secs:
		if not kinds.is_empty() and fmod(t, every) < 0.25:
			mega.say(kinds[i % kinds.size()], t)
			i += 1
		var told := mega.tick(t)
		if not told.is_empty():
			out.append([t, told])
		t += 0.25
	return out


## A typical go, as a script: [second, action]. Some of it the loudspeaker
## has a word about, most of it not.
const PLAN := [
	[6.0, "roll"], [7.0, "roll_wall"], [20.0, "knock_bin"], [34.0, "hide_armour"],
	[50.0, "sneeze"], [52.0, "smoke"], [70.0, "roll"], [71.0, "roll_case"],
	[90.0, "knock_bust"], [100.0, "switch"], [104.0, "switch"], [108.0, "switch"],
	[120.0, "knock_panel"], [130.0, "panel"], [135.0, "case"], [140.0, "roll"],
	[141.0, "roll_wall"], [155.0, "hide_other"], [165.0, "roll_wall"],
]


## A go of `secs` seconds playing PLAN: the keys said.
func play_go(night: int, seed: int, always := true, secs := 180.0, players := 1) -> Array:
	var m := Megaphone.new(night, 0 if night == 1 else 2, players, "la momia", seed)
	m.always = always
	m.say("start", 0.0)
	var keys := []
	var t := 0.0
	while t < secs:
		for e in PLAN:
			if absf(e[0] - t) < 0.01:
				m.act(e[1], t, int(e[0]) % players)
		var x := m.tick(t)
		if not x.is_empty():
			keys.append(x.key)
		t += 0.25
	return keys


func _init() -> void:
	# Except in the intro tests, no wait at the start.
	Megaphone.intro_override = 0.0
	var csv := csv_keys()
	check(csv.__bad == 0, "texts.csv: ninguna fila rota")
	var missing := []
	var long := []
	var keys := Megaphone.all_keys()
	for k in keys:
		if not csv.has(k):
			missing.append(k)
		elif words(csv[k]) > Megaphone.MAX_WORDS:
			long.append(k)
	check(missing.is_empty(), "las %d claves de POOLS están en el CSV %s" % [keys.size(), missing])
	check(long.is_empty(), "ninguna frase pasa de %d palabras %s" % [Megaphone.MAX_WORDS, long])
	var extra := []
	for k in csv:
		if k.begins_with("MEGA_") and k.count("_") >= 2 and k.split("_")[-1].is_valid_int() and not k in keys:
			extra.append(k)
	check(extra.is_empty(), "ninguna frase del CSV sin contar en POOLS %s" % [extra])
	check(Text.t("SETTINGS_MEGAPHONE") != "SETTINGS_MEGAPHONE" and Text.t("MEGA_SOMETHING") != "MEGA_SOMETHING", "los textos del ajuste y del relleno de la pieza")
	check(["BOTH", "TEXT", "SOUND", "OFF"].all(func(o): return Text.t("SETTINGS_MEGAPHONE_" + o) != "SETTINGS_MEGAPHONE_" + o), "los cuatro modos del ajuste tienen su texto")
	var texts := {}
	for k in keys:
		texts[Text.t(k)] = true
	check(texts.size() == keys.size(), "ninguna frase repetida")
	check(keys.size() >= 100, "hay frases de sobra (%d)" % keys.size())
	# The loudspeaker sees nobody: no ninjas, thieves, gang, colours or «tú» (static, on the CSV).
	var banned := RegEx.create_from_string("(?i)\\b(ninjas?|ladr[oó]n(es)?|ladrona|bandas?|turquesa|naranja|morado|morada|azul|vosotros|vosotras|vuestr[oa]s?|tus?|tuyo|tuya|te|ti|os|contigo)\\b")
	var rude := []
	for k in csv:
		if k.begins_with("MEGA_") and banned.search(csv[k]) != null:
			rude.append(k)
	check(rude.is_empty(), "ninguna frase MEGA_ nombra ninjas, ladrones, banda, colores ni habla de tú %s" % [rude])
	check(not csv.keys().any(func(k): return k.begins_with("MEGA_WHO_") or "_NAMED_" in k), "sin nombres de ladrón ni frases «con nombre»")
	# Every kind has phrases and a priority.
	check(Megaphone.KINDS.keys().all(func(k): return Megaphone.POOLS.has(k)), "cada suceso tiene sus frases")
	check(Megaphone.GUARD_KINDS.all(func(k): return Megaphone.KINDS.has(k)), "los de guardias son sucesos")

	# Cooldown: nothing closer than the gap, however much happens; a cap per go.
	Megaphone.forget()
	var m := Megaphone.new(6, 1, 1, "el gnomo", 7)
	var told := run(m, 300.0, ["knocked", "sneeze", "lights_on", "alarm", "smoke", "stolen", "seen"], 1.0)
	var gaps_ok := true
	var same := false
	for i in range(1, told.size()):
		var dt: float = told[i][0] - told[i - 1][0]
		var need := Megaphone.CUT_S if Megaphone.KINDS[told[i][1].kind] >= Megaphone.URGENT else Megaphone.GAP_S
		gaps_ok = gaps_ok and dt >= need - 0.01
		same = same or told[i][1].key == told[i - 1][1].key
	check(told.size() > 3 and gaps_ok, "enfriamiento: %d avisos en 300 s, nunca a menos de %.0f s (%.0f s los de peligro)" % [told.size(), Megaphone.GAP_S, Megaphone.CUT_S])
	check(told.size() <= Megaphone.CAP_MAX + Megaphone.URGENT_EXTRA, "tope por robo: %d avisos como mucho (salen %d)" % [Megaphone.CAP_MAX + Megaphone.URGENT_EXTRA, told.size()])
	check(not same, "nunca el mismo aviso dos veces seguidas")
	check(Megaphone.GAP_S >= 25.0 and Megaphone.CUT_S >= 12.0 and Megaphone.CUT_S < Megaphone.GAP_S, "constantes: hueco %.0f s, peligro %.0f s" % [Megaphone.GAP_S, Megaphone.CUT_S])
	var normal := true
	for i in range(1, told.size()):
		if Megaphone.KINDS[told[i][1].kind] < Megaphone.URGENT:
			normal = normal and told[i][0] - told[i - 1][0] >= Megaphone.GAP_S - 0.01
	check(normal, "los no urgentes esperan el hueco entero (%.0f s)" % Megaphone.GAP_S)
	var cap_early := Megaphone.new(6, 1, 1, "x", 1)
	check(cap_early.cap(0.0) == Megaphone.CAP_MIN and cap_early.cap(10000.0) == Megaphone.CAP_MAX and Megaphone.new(1, 0, 1, "x", 1).cap(10000.0) == Megaphone.TUTORIAL_CAP, "el tope crece con el robo (%d a %d) y en el robo 1 es %d" % [Megaphone.CAP_MIN, Megaphone.CAP_MAX, Megaphone.TUTORIAL_CAP])

	# No phrase comes twice in a go, nor in the next one; when they run out it is silence.
	Megaphone.forget()
	var d := Megaphone.new(6, 1, 1, "x", 3)
	var seen := {}
	var deck_ok := true
	for i in Megaphone.POOLS.alarm:
		var k := d.next_key("alarm")
		deck_ok = deck_ok and k != "" and not seen.has(k)
		seen[k] = true
	check(deck_ok and seen.size() == Megaphone.POOLS.alarm, "ninguna frase se repite en el mismo robo")
	check(d.next_key("alarm") == "", "sin frases nuevas, calla en vez de repetir")
	var d2 := Megaphone.new(6, 1, 1, "x", 4)
	check(d2.next_key("alarm") == "", "el robo siguiente tampoco repite las del anterior")
	d2.next_key("calm")
	var d3 := Megaphone.new(6, 1, 1, "x", 5)
	check(d3.next_key("alarm") != "", "…pero dos robos después ya pueden volver")
	# Two whole goes in a row (same night, then another) share no phrase.
	for pair in [[6, 6], [6, 11], [1, 6]]:
		Megaphone.forget()
		var keys_a := play_go(pair[0], 1)
		var keys_b := play_go(pair[1], 2)
		var shared := keys_a.filter(func(k): return k in keys_b)
		check(keys_a.size() >= 2 and keys_b.size() >= 2 and shared.is_empty(), "dos robos seguidos (noche %d y %d) no comparten frases (%d y %d avisos)" % [pair[0], pair[1], keys_a.size(), keys_b.size()])
		var all_a := keys_a + keys_b
		var dup := false
		for i in all_a.size():
			dup = dup or all_a.find(all_a[i]) != i
		check(not dup, "…ni repite ninguna dentro de cada uno")
	# Exhaust everything: goes run back to back, and a go's phrases never
	# come back the go after (nor twice in the same one).
	Megaphone.forget()
	var last_keys := []
	var ex_ok := true
	var ex_total := 0
	for g in 8:
		var e := Megaphone.new(11, 2, 2, "la momia", 30 + g)
		e.always = true
		var mine := []
		for x in run(e, 600.0, ["knocked", "sneeze", "act_knock_bin", "act_sneeze", "lights_on", "smoke"], 1.0):
			mine.append(x[1].key)
		ex_ok = ex_ok and mine.all(func(k): return not k in last_keys)
		for i in mine.size():
			ex_ok = ex_ok and mine.find(mine[i]) == i
		ex_total += mine.size()
		last_keys = mine
	check(ex_ok and ex_total > 20, "aunque se agoten las frases, ninguna se repite en el robo ni en el siguiente (%d dichas en 8 robos)" % ex_total)

	# Priority: a chase beats a sneeze that was waiting.
	var pr := Megaphone.new(6, 1, 1, "x", 5)
	pr.say("start", 2.0)
	pr.tick(2.0)
	pr.say("sneeze", 14.0)
	pr.say("seen", 14.5)
	pr.say("lights_off", 15.0)
	var got := {}
	var t := 15.0
	while t < 30.0 and got.is_empty():
		got = pr.tick(t)
		t += 0.25
	check(got.get("kind", "") == "seen", "con dos a la vez sale el de más prioridad (%s)" % got.get("kind", "nada"))
	# An urgent one may cut in early; a mild one may not.
	var cut := Megaphone.new(6, 1, 1, "x", 5)
	cut.say("start", 2.0)
	cut.tick(2.0)
	cut.say("smoke", 3.0)
	check(cut.tick(3.0).is_empty() and cut.tick(4.5).is_empty() and cut.tick(3.0 + Megaphone.STALE_S + 1.0).is_empty(), "uno suave no se cuela: espera al hueco (y si tarda, se olvida)")
	var cut2 := Megaphone.new(6, 1, 1, "x", 5)
	cut2.say("start", 2.0)
	cut2.tick(2.0)
	cut2.say("seen", 14.0)
	check(cut2.tick(14.0).is_empty() and cut2.tick(2.0 + Megaphone.CUT_S - 0.5).is_empty() and cut2.tick(2.0 + Megaphone.CUT_S + 0.1).get("kind", "") == "seen", "uno urgente se cuela tras %.0f s, no antes" % Megaphone.CUT_S)
	# A stale event is dropped.
	var st := Megaphone.new(6, 1, 1, "x", 5)
	st.say("start", 2.0)
	st.tick(2.0)
	st.say("sneeze", 3.0)
	check(st.tick(3.0 + Megaphone.STALE_S + 1.0).is_empty(), "un suceso viejo ya no se cuenta")

	# The first heist: no guards, no talk of guards, few notices.
	Megaphone.forget()
	var one := Megaphone.new(1, 0, 1, "la dentadura", 9)
	var guardy := ["seen", "suspect", "hide", "lights_on", "lights_off"]
	var kinds := ["seen", "suspect", "hide", "lights_on", "lights_off", "stolen", "sneeze"]
	var t1 := run(one, 300.0, kinds, 2.0)
	check(t1.all(func(x): return not x[1].kind in guardy), "robo 1: ningún aviso de guardias")
	var one2 := Megaphone.new(1, 0, 1, "la dentadura", 9)
	var calm1 := run(one2, 300.0, [], 1.0)
	var two := Megaphone.new(6, 1, 1, "el gnomo", 9)
	var calm2 := run(two, 300.0, [], 1.0)
	check(calm1.size() < calm2.size(), "robo 1: más callada que el resto (%d contra %d en 300 s de calma)" % [calm1.size(), calm2.size()])
	check(calm1.all(func(x): return not String(x[1].key).begins_with("MEGA_HINT_")), "robo 1: sin pistas de museo")
	# Hints belong to the night's museum.
	var hints_ok := true
	var any_hint := 0
	for n in [6, 11, 16, 21]:
		var h := Megaphone.new(n, 2, 1, "x", n)
		for x in run(h, 400.0, [], 1.0):
			if String(x[1].key).begins_with("MEGA_HINT_"):
				any_hint += 1
				hints_ok = hints_ok and String(x[1].key).begins_with("MEGA_HINT_%d_" % (Story.museum_of(n) + 1))
	check(hints_ok and any_hint >= 3, "las pistas son del museo de la noche (%d vistas)" % any_hint)
	# Standing still gets a word of its own; a gang gets gang jokes.
	var idle := Megaphone.new(6, 1, 1, "x", 1)
	var got_idle := false
	for i in 160:
		var x := idle.tick(float(i), 30.0)
		if not x.is_empty() and x.kind == "idle":
			got_idle = true
	check(got_idle, "quieto un rato: un aviso para él")
	var quiet := Megaphone.new(6, 1, 1, "x", 1)
	check(quiet.tick(50.0, 30.0, true).is_empty(), "con sospecha en el aire, no hay ocurrencias")
	var pair := Megaphone.new(6, 2, 2, "x", 1)
	var team := 0
	for x in run(pair, 600.0, [], 1.0):
		if x[1].kind == "team":
			team += 1
	var solo := Megaphone.new(6, 2, 1, "x", 1)
	check(team > 0 and run(solo, 600.0, [], 1.0).all(func(x): return x[1].kind != "team"), "los chistes de equipo, solo con equipo")
	# The piece's name is filled in.
	Megaphone.forget()
	var pc := Megaphone.new(6, 1, 1, "el gnomo", 1)
	var piece_ok := true
	for i in Megaphone.POOLS.piece:
		var x := pc._speak("piece", float(i * 10))
		piece_ok = piece_ok and not "%s" in x.text
	check(piece_ok, "el nombre de la pieza se rellena")
	# Every kind, said on a night, comes out as a phrase in words.
	Megaphone.forget()
	var all_ok := true
	for kind in Megaphone.KINDS:
		var a := Megaphone.new(11, 3, 2, "la momia", 4)
		a.say(kind, 2.0)
		var x := a.tick(4.0, 0.0, false)
		if x.is_empty() or x.text == x.key or x.text == "":
			all_ok = false
			print("  sin texto: ", kind)
	check(all_ok, "cada suceso tiene su texto")

	# The things a thief does: quick, now and then, never spam.
	var short := []
	for name in Megaphone.ACTS:
		var kind: String = "act_" + name
		if name == "switch":
			continue
		if not Megaphone.KINDS.has(kind) or not Megaphone.POOLS.has(kind):
			short.append(name)
		elif Megaphone.POOLS[kind] < 5:
			short.append(name)
	check(short.is_empty(), "cada acción tiene su prioridad y al menos 5 frases %s" % [short])
	check(Megaphone.KINDS.keys().filter(func(k): return String(k).begins_with("act_")).all(func(k): return Megaphone.KINDS[k] < Megaphone.URGENT), "las reacciones nunca son de peligro (no tapan un peligro)")
	check(Megaphone.POOLS.act_roll_wall + Megaphone.POOLS.act_roll_wall_again >= 12 and Megaphone.POOLS.act_knock_again >= 6 and Megaphone.POOLS.act_sneeze >= 6, "las acciones frecuentes tienen 6 o más frases")
	Megaphone.forget()
	var q := Megaphone.new(6, 2, 1, "x", 11)
	q.always = true
	q.act("roll_wall", 30.0, 0)
	var early := q.tick(30.5)
	var rolled := q.tick(30.0 + Megaphone.ACT_DELAY_S + 0.05)
	check(early.is_empty() and rolled.get("kind", "") == "act_roll_wall" and Megaphone.ACT_DELAY_S <= 2.0, "voltereta y pared: el comentario sale a los %.1f s (no antes, no a los 8)" % Megaphone.ACT_DELAY_S)
	check(String(rolled.get("key", "")).begins_with("MEGA_ACT_ROLL_WALL_") and not "AGAIN" in String(rolled.get("key", "")), "…y es de la primera vez: %s" % rolled.get("text", ""))
	var q2 := Megaphone.new(6, 2, 1, "x", 11)
	q2.always = true
	q2.act("knock_bin", 30.0, -1)
	check(q2.tick(34.0).is_empty(), "una reacción que no sale a tiempo se olvida")
	# The odds: same seed, same luck; rare things rarely, funny ones often.
	var hits := {}
	var same_luck := true
	for name in ["roll", "roll_wall", "knock_bin", "sneeze", "hide_other"]:
		hits[name] = 0
		for sd in 300:
			var l := Megaphone.new(6, 2, 1, "x", sd)
			l.act(name, 30.0, 0)
			var l2 := Megaphone.new(6, 2, 1, "x", sd)
			l2.act(name, 30.0, 0)
			same_luck = same_luck and (l._pending_kind == l2._pending_kind)
			if l._pending_kind != "":
				hits[name] += 1
	check(same_luck, "la suerte es determinista con la misma semilla")
	var rate := func(n): return hits[n] / 300.0
	check(absf(rate.call("roll_wall") - Megaphone.ACTS.roll_wall[0]) < 0.08 and absf(rate.call("roll") - Megaphone.ACTS.roll[0]) < 0.06 and absf(rate.call("knock_bin") - Megaphone.ACTS.knock_bin[0]) < 0.09, "la probabilidad de cada acción se cumple (choque %.2f, voltereta %.2f, papelera %.2f, estornudo %.2f)" % [rate.call("roll_wall"), rate.call("roll"), rate.call("knock_bin"), rate.call("sneeze")])
	check(rate.call("roll_wall") > rate.call("knock_bin") and rate.call("knock_bin") > rate.call("roll"), "lo raro o gracioso se comenta más que lo frecuente")
	var tut := 0
	for sd in 300:
		var l := Megaphone.new(1, 0, 1, "x", sd)
		l.act("roll_wall", 30.0, 0)
		if l._pending_kind != "":
			tut += 1
	check(tut / 300.0 < rate.call("roll_wall") - 0.2, "en el robo 1 se comenta la mitad (%.2f)" % (tut / 300.0))
	# Cooldowns: per action, and the general gap.
	Megaphone.forget()
	var c := Megaphone.new(6, 2, 1, "x", 5)
	c.always = true
	c.act("roll_wall", 30.0, 0)
	check(c.tick(31.5).kind == "act_roll_wall", "primer choque, comentado")
	c.act("hide_other", 40.0, 0)
	check(c._pending_kind == "", "otra reacción dentro del hueco general no sale")
	c.act("roll_wall", 75.0, 0)
	check(c._pending_kind == "", "la misma acción tiene su propio enfriamiento (%.0f s)" % Megaphone.ACTS.roll_wall[1])
	c.act("smoke", 75.0, 0)
	check(c._pending_kind != "", "pasado el hueco, otra acción distinta sí")
	c.tick(76.5)
	c.act("roll_wall", 135.0, 0)
	check(c._pending_kind == "act_roll_wall", "…que acaba")
	# Repetition: the second time it is another phrase, from the «again» ones.
	var t2 := c.tick(136.5)
	check(String(t2.get("key", "")).begins_with("MEGA_ACT_ROLL_WALL_AGAIN_"), "la segunda vez sale una de «otra vez»: %s" % t2.get("text", ""))
	# A streak: the third crash in a minute is its own joke.
	Megaphone.forget()
	var sk := Megaphone.new(6, 2, 1, "x", 8)
	sk.always = true
	sk.act("roll_wall", 10.0, 0)
	sk.act("roll_case", 12.0, 0)
	sk.act("roll_wall", 14.0, 0)
	check(sk._pending_kind == "act_crash_streak" and String(sk.tick(16.0).get("key", "")).begins_with("MEGA_ACT_CRASH_STREAK_"), "tres choques seguidos: comentario de racha")
	var rs := Megaphone.new(6, 2, 1, "x", 8)
	rs.always = true
	rs.act("roll", 10.0, 0)
	rs.act("roll", 20.0, 0)
	rs.act("roll", 24.0, 0)
	check(rs._pending_kind == "act_roll_streak", "tres volteretas seguidas: racha")
	var ks := Megaphone.new(6, 2, 1, "x", 8)
	ks.always = true
	for i in 3:
		ks.act(["knock_bin", "knock_bust", "knock_armour"][i], 10.0 + i * 5.0, -1)
	check(ks._pending_kind == "act_knock_streak", "tres cosas tiradas seguidas: racha")
	var sw := Megaphone.new(6, 2, 1, "x", 8)
	sw.always = true
	sw.act("switch", 10.0)
	check(sw._pending_kind == "", "un interruptor solo no dice nada")
	sw.act("switch", 14.0)
	sw.act("switch", 18.0)
	check(sw._pending_kind == "act_switch_streak", "tres interruptores seguidos: racha")
	# Priority: a reaction beats a calm word, and never a danger.
	var pa := Megaphone.new(6, 2, 1, "x", 2)
	pa.always = true
	pa.act("smoke", 100.0, 0)
	check(pa.tick(101.5, 30.0).get("kind", "") == "act_smoke", "una reacción gana a la ocurrencia de estar quieto")
	var pb := Megaphone.new(6, 2, 1, "x", 2)
	pb.always = true
	pb.say("seen", 50.0)
	pb.act("knock_bin", 50.5, -1)
	check(pb._pending_kind == "seen" and pb.tick(51.7).get("kind", "") == "seen", "si coinciden, el peligro manda")
	var pc2 := Megaphone.new(6, 2, 1, "x", 2)
	pc2.always = true
	pc2.act("knock_bin", 50.0, -1)
	pc2.say("knocked", 50.2)
	check(pc2._pending_kind == "act_knock_bin", "la reacción manda sobre el aviso general de lo mismo")
	var pd := Megaphone.new(6, 2, 1, "x", 2)
	pd.always = true
	pd.act("sneeze", 30.0, 0)
	pd.tick(31.3)
	pd.say("seen", 44.0)
	check(pd.tick(44.0).is_empty() and pd.tick(31.3 + Megaphone.CUT_S + 0.1).get("kind", "") == "seen", "tras una reacción, el peligro sale a los %.0f s" % Megaphone.CUT_S)
	# With a gang the loudspeaker still names nobody: whoever did it, the same words.
	Megaphone.forget()
	var gang_ok := true
	for sd in 20:
		var n2 := Megaphone.new(6, 2, 2, "x", sd)
		n2.always = true
		n2.act("roll_wall", 30.0, 1)
		var x := n2.tick(31.5)
		gang_ok = gang_ok and x.get("kind", "") == "act_roll_wall" and not "%s" in String(x.text)
	check(gang_ok, "con varios ladrones, no se nombra a nadie")
	# No talk of guards in the first heist.
	var g1 := Megaphone.new(1, 0, 1, "x", 4)
	g1.always = true
	g1.act("hide_seen", 60.0, 0)
	g1.act("phew", 60.0, 0)
	check(g1._pending_kind == "", "robo 1: ninguna reacción habla de guardias")
	# Standing, running, crawling: only after a stretch, once.
	var hd := Megaphone.new(6, 2, 1, "x", 6)
	hd.always = true
	var t3 := 30.0
	for i in 20:
		hd.hold("run", true, 0.5, t3, 0)
		t3 += 0.5
	check(hd._pending_kind == "act_run" and hd.counts.get("run", 0) == 1, "correr seis segundos seguidos se comenta, una vez por carrera")
	hd.hold("run", false, 0.5, t3, 0)
	check(not hd._held.has("run0"), "y si paras, vuelve a empezar")
	# Typical goes: how many notices, and none shared with the next.
	Megaphone.intro_override = -1.0
	Megaphone.forget()
	var total := 0
	var worst := 0
	var runs := 60
	for sd in runs:
		var n3 := play_go(6 + (sd % 3) * 5, sd, false).size()
		total += n3
		worst = maxi(worst, n3)
	var avg := total / float(runs)
	print("     robo típico de 3 min con %d cosas hechas: %.1f avisos de media, %d como mucho" % [PLAN.size(), avg, worst])
	check(avg >= 1.0 and avg <= 4.0 and worst <= Megaphone.CAP_MAX + Megaphone.URGENT_EXTRA, "un robo típico: %.1f avisos de media (tope %d)" % [avg, Megaphone.CAP_MAX])
	var tut_total := 0
	for sd in runs:
		tut_total += play_go(1, sd, false).size()
	check(tut_total / float(runs) < avg, "el robo 1 habla menos (%.1f contra %.1f)" % [tut_total / float(runs), avg])

	# The wait at the start: a draw between INTRO_MIN_S and INTRO_MAX_S (more in the first heist), from the seed.
	var lo := 999.0
	var hi := 0.0
	var tlo := 999.0
	var thi := 0.0
	var same_intro := true
	for sd in 200:
		var a1 := Megaphone.new(6, 2, 1, "x", sd)
		var a2 := Megaphone.new(6, 2, 1, "x", sd)
		var tut_b := Megaphone.new(1, 0, 1, "x", sd)
		same_intro = same_intro and a1.intro_s == a2.intro_s
		lo = minf(lo, a1.intro_s)
		hi = maxf(hi, a1.intro_s)
		tlo = minf(tlo, tut_b.intro_s)
		thi = maxf(thi, tut_b.intro_s)
	check(lo >= Megaphone.INTRO_MIN_S and hi <= Megaphone.INTRO_MAX_S and hi - lo > 20.0, "el retardo inicial está entre %.0f y %.0f s (visto %.0f a %.0f)" % [Megaphone.INTRO_MIN_S, Megaphone.INTRO_MAX_S, lo, hi])
	check(tlo >= Megaphone.TUTORIAL_INTRO_MIN_S and thi <= Megaphone.TUTORIAL_INTRO_MAX_S and tlo > Megaphone.INTRO_MIN_S, "en el robo 1, entre %.0f y %.0f s (visto %.0f a %.0f)" % [Megaphone.TUTORIAL_INTRO_MIN_S, Megaphone.TUTORIAL_INTRO_MAX_S, tlo, thi])
	check(same_intro, "el retardo es determinista con la misma semilla")
	# Nothing before it: not the greeting, nor a reaction, nor a calm word; danger only after INTRO_MIN_S.
	var early_ok := true
	var greet_ok := true
	var danger_ok := true
	for sd in 40:
		Megaphone.forget()
		var w := Megaphone.new(6, 2, 1, "x", sd)
		w.always = true
		w.say("start", 0.0)
		var first := {}
		var t4 := 0.0
		while t4 < 120.0 and first.is_empty():
			if fmod(t4, 3.0) == 0.0:
				w.act("roll_wall", t4, 0)
				w.say("knocked", t4)
				if t4 >= 30.0 and fmod(t4, 30.0) == 0.0:
					w.say("alarm", t4)
			first = w.tick(t4, 40.0)
			t4 += 0.25
		if first.is_empty():
			early_ok = false
			continue
		var at: float = w.said[0][0]
		if Megaphone.KINDS[first.kind] >= Megaphone.URGENT:
			danger_ok = danger_ok and at >= minf(Megaphone.INTRO_MIN_S, w.intro_s) - 0.01
		else:
			early_ok = early_ok and at >= w.intro_s - 0.01
		greet_ok = greet_ok and at >= Megaphone.INTRO_MIN_S - 0.01
	check(early_ok and greet_ok and danger_ok, "el primer mensaje nunca sale antes de %.0f s, ni antes del retardo si no es peligro" % Megaphone.INTRO_MIN_S)
	Megaphone.forget()
	var gr := Megaphone.new(6, 2, 1, "x", 21)
	gr.say("start", 0.0)
	check(gr.tick(gr.intro_s - 0.5).is_empty() and gr.tick(gr.intro_s + 0.1).get("kind", "") == "start", "el saludo espera al retardo y sale entonces (a los %.0f s)" % gr.intro_s)
	Megaphone.forget()
	var dg := Megaphone.new(6, 2, 1, "x", 21)
	dg.intro_s = 45.0
	dg.say("alarm", 10.0)
	dg.say("alarm", 21.0)
	check(dg.tick(10.0).is_empty() and dg.tick(21.1).get("kind", "") == "alarm", "el peligro no espera el resto del retardo, pero sí los primeros %.0f s" % Megaphone.INTRO_MIN_S)
	Megaphone.intro_override = 0.0

	# Sus propios ajustes: cambiar de modo guarda, y no debe tocar los del jugador.
	Settings.path = "user://test_megafonia_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	# In the game: wired to the events, and it fits every shape of screen.
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	Story.save = "user://test_megafonia.cfg"
	main.mode = "story"
	main.players = 1
	main.seats.assign(["kb_left"])
	main._new_round(7)
	await process_frame
	check(main.loudspeaker.mega != null and main.loudspeaker.mega.guards == main.guards.size(), "cada robo estrena su megafonía")
	HeistStats.time = 3.0
	main.loudspeaker.say("alarm")
	main.loudspeaker.tick(0.0)
	var hud: Hud = main.hud
	check(hud._mega_text.text != "" and hud._mega_left > 0.0, "el rótulo sale en el HUD: «%s»" % hud._mega_text.text)
	# Los cuatro modos: qué se ve y qué suena en cada uno.
	var modes := {"both": [true, true], "text": [true, false], "sound": [false, true], "off": [false, false]}
	var n_mode := 0
	for md in Settings.MEGAPHONE_MODES:
		main.options.set_megaphone_mode("both")
		hud.megaphone("")
		main.mega_voice.stop(true)
		Megaphone.forget()
		main.loudspeaker.start(7)
		HeistStats.time = 3.0
		main.options.set_megaphone_mode(md)
		main.loudspeaker.say("alarm")
		# Sin saltar en el tiempo: el aviso en cola caduca si se espera demasiado.
		main.loudspeaker.tick(0.0)
		n_mode += 1
		var shown: bool = hud._mega_text.text != "" and hud._mega_left > 0.0
		if md == "off":
			check(not shown and main.loudspeaker.mega.said.is_empty(), "modo «no»: la lógica no corre y no hay cartel")
		else:
			check(shown == modes[md][0], "modo «%s»: el cartel %s" % [md, "sale" if modes[md][0] else "no sale"])
			check(not main.loudspeaker.mega.said.is_empty(), "modo «%s»: la lógica sigue (dice una frase)" % md)
	# Con el modo «solo sonido» la frase cuenta para el enfriamiento aunque no salga nada.
	main.options.set_megaphone_mode("sound")
	hud.megaphone("")
	Megaphone.forget()
	main.loudspeaker.start(7)
	HeistStats.time = 3.0
	main.loudspeaker.say("alarm")
	main.loudspeaker.tick(0.0)
	var said_sound: int = main.loudspeaker.mega.said.size()
	check(hud._mega_text.text == "" and said_sound >= 1 and main.loudspeaker.mega._last_at >= 0.0, "«solo sonido»: sin cartel, y la frase cuenta para el enfriamiento")
	# Cambiar de modo en marcha: sin cartel lo quita, sin sonido corta la voz.
	main.options.set_megaphone_mode("both")
	hud.megaphone("hola")
	main.mega_voice.current = "MEGA_X"
	main.options.set_megaphone_mode("sound")
	check(hud._mega_text.text == "" and main.mega_voice.current == "MEGA_X", "de «ambos» a «solo sonido»: el cartel se va y la voz sigue")
	main.options.set_megaphone_mode("text")
	check(main.mega_voice.current == "", "de «solo sonido» a «solo cartel»: la voz se corta")
	hud.megaphone("hola")
	main.options.set_megaphone_mode("off")
	check(hud._mega_text.text == "", "a «no»: el cartel se va")
	# El ajuste: cicla por los cuatro, adelante y atrás.
	check(Settings.DEFAULTS.megaphone_mode == "both", "el ajuste existe, en «cartel y sonido» por defecto")
	main.options.set_megaphone_mode("both")
	var cycle := []
	for i in 5:
		cycle.append(main.megaphone_mode)
		main.options.step(0, "megaphone")
	check(cycle == ["both", "text", "sound", "off", "both"], "el aceptar cicla por los cuatro modos: %s" % [cycle])
	main.options.set_megaphone_mode("both")  # el bucle acabó en «text»
	main.options.step(-1, "megaphone")
	check(main.megaphone_mode == "off", "← va hacia atrás (de «ambos» a «no»)")
	for md in Settings.MEGAPHONE_MODES:
		main.megaphone_mode = md
		var label: String = main.options.text_of("megaphone")
		check(label.begins_with(Text.t("SETTINGS_MEGAPHONE").split("%")[0]) and label != "megaphone" and not "SETTINGS_" in label, "la fila en «%s»: %s" % [md, label])
	check(main.options.text_of("megaphone_voice") == "megaphone_voice", "ya no hay una fila aparte para la voz")
	main.megaphone_mode = "both"
	# A real roll into a real wall: the loudspeaker remarks on it (sometimes: always, here).
	Megaphone.forget()
	main._new_round(7)
	await process_frame
	main.loudspeaker.mega.always = true
	main.phase = "playing"
	var th: Thief = main.thieves[0]
	var crashed := false
	for ang in 16:
		th.dir = TAU * ang / 16.0
		th.dizzy = 0.0
		th.rolling = false
		th.crouched = false
		th.posture = 0.0
		if not Roll.start(th):
			continue
		HeistStats.time = 40.0 + ang * 100.0
		for f in 100:
			main.loudspeaker.mega._last_at = HeistStats.time - 45.0
			main.hands.pad_frame = Engine.get_physics_frames() - 1
			main.loop.tick(1.0 / 60.0)
			if th.stars:
				crashed = true
				break
		if crashed:
			break
	var walls: int = main.loudspeaker.mega.counts.get("roll_wall", 0) + main.loudspeaker.mega.counts.get("roll_case", 0)
	check(crashed and walls == 1 and String(main.loudspeaker.mega._pending_kind).begins_with("act_roll_"), "rodar contra una pared en el juego lo cuenta la megafonía (%s)" % main.loudspeaker.mega._pending_kind)
	for f in 120:
		main.hands.pad_frame = Engine.get_physics_frames() - 1
		main.loop.tick(1.0 / 60.0)
	var last: Array = main.loudspeaker.mega.said.back() if not main.loudspeaker.mega.said.is_empty() else ["", ""]
	check(String(last[1]).begins_with("MEGA_ACT_ROLL_") and hud._mega_text.text == Text.t(last[1]) and hud._mega_left > 0.0, "…y en pantalla sale su frase: «%s»" % hud._mega_text.text)
	main.mode = "practica"
	var before: int = main.loudspeaker.mega.counts.get("roll_wall", 0)
	main.loudspeaker.act("roll_wall", 0)
	check(main.loudspeaker.mega.counts.get("roll_wall", 0) == before, "en la práctica y la guarida, la megafonía de robo calla")
	main.mode = "story"
	main.megaphone_mode = "off"
	main.loudspeaker.act("roll_wall", 0)
	check(main.loudspeaker.mega.counts.get("roll_wall", 0) == before, "apagada en los ajustes, no comenta ni cuenta")
	main.megaphone_mode = "both"
	var longest := ""
	for k in keys:
		if Text.t(k).length() > longest.length():
			longest = Text.t(k)
	for size in [Vector2i(1024, 768), Vector2i(1280, 720), Vector2i(1920, 540), Vector2i(3840, 1080), Vector2i(640, 480)]:
		root.size = size
		root.content_scale_size = Vector2i.ZERO
		await process_frame
		hud.megaphone(longest)
		hud._draw_megaphone(1.0)
		var r := Rect2(hud._mega_box.position, hud._mega_box.size)
		var view := hud.get_viewport().get_visible_rect()
		check(view.grow(0.5).encloses(r) and r.position.y >= 60.0, "el rótulo cabe en %s (%s dentro de %s)" % [size, r, view.size])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
