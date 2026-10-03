extends SceneTree
## Modo dev: sobre cada guardia, en una noche, un bloque con sus variables
## efectivas (atención, paso, vista, oído, estado), leídas de las mismas
## funciones que usa la simulación (DevInfo); y en el overlay una línea con el
## estado global de la noche. Con dev apagado no existe nada de esto.
##   godot --headless --script tests/test_dev_guardias.gd
const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")
var game: Game


func _init() -> void:
	call_deferred("run")


func frames(n := 3) -> void:
	for i in n:
		await process_frame


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.0001


func run() -> void:
	Story.save = "user://test_dev_guardias.cfg"
	Settings.path = "user://test_dev_guardias_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	game.story_pick = Story.count()
	game.mode = "story"
	game._new_round(Story.count())
	game._start_playing()
	await frames(5)
	qa.check(game.guards.size() >= 2, "la noche tiene guardias (%d)" % game.guards.size())

	# Dev apagado: nada de bloques ni de línea de la noche.
	game.dev_mode = false
	await frames(3)
	qa.check(game.scenery.dev_labels.is_empty(), "sin dev no se crea ningún bloque")
	qa.check(game.dev_overlay._night.text == "", "sin dev no hay línea de la noche")

	# Dev encendido a mitad de noche (como en Ajustes): aparecen.
	game.dev_mode = true
	game.dev_overlay.set_enabled(true)
	await frames(5)
	qa.check(game.scenery.dev_labels.size() == game.guards.size() and game.scenery.dev_heads.size() == game.guards.size(), "con dev, un bloque y una línea grande por guardia")
	qa.check(game.dev_overlay._night.text.begins_with("Noche: calm"), "la línea de la noche dice el modo: " + game.dev_overlay._night.text)

	var g: Guard = game.guards[0]
	g.attention_scale = 1.5
	g.speed_scale = 1.15
	g.view_scale = 1.2
	g.hearing_scale = 0.8
	var now := Sim.now_ms()

	# Tranquilo: los valores salen de las funciones de la simulación.
	NightAlert.reset()
	g.suspicion = 0
	g.alert = false
	g.sees_player = false
	var v := DevInfo.values(g, now)
	qa.check(near(v.attention, NightAlert.attention(g)) and near(v.attention, 1.5 * NightAlert.ATTENTION_CALM), "atención en calma = rasgo × ×1,0")
	var pace := Sim.pace_of(g, v.aggression, false)
	qa.check(near(v.speed, pace.speed) and near(v.speed, (1.0 + v.aggression * 0.5) * Sim.tuning("speed") * 1.15), "paso en calma: paseo × dial × rasgo")
	var view := Sim.view_of(g)
	qa.check(near(v.view_range, view.range) and near(v.view_range, Sim.VIEW.calm.range * Sim.tuning("view") * 1.2), "vista en calma: alcance de calma × dial × rasgo")
	qa.check(near(v.hearing, Hearing.HEARING_CALM * Sim.tuning("hearing") * 0.8), "oído en calma = ×0,75 × dial × rasgo")
	var calm_text := DevInfo.guard_text(g, now)
	qa.check("Aten 1.50 (1.50 ×1.0)" in calm_text, "el texto enseña la atención efectiva: " + calm_text.replace("\n", " / "))

	# Sospecha: sube la atención.
	g.suspicion = 1
	g.suspicion_at = now
	qa.check(near(DevInfo.values(g, now).attention, 1.5 * NightAlert.ATTENTION_SUSPECT), "con ! la atención sube ×1,5")

	# Alerta: más paso, vista y oído, atención ×2.
	g.suspicion = 2
	g.alert = true
	v = DevInfo.values(g, now)
	qa.check(near(v.attention, 1.5 * NightAlert.ATTENTION_ALERT), "en alerta la atención sube ×2")
	qa.check(near(v.speed, Sim.pace_of(g, v.aggression, true).speed) and v.speed > pace.speed, "en alerta el paso es el de alerta y mayor")
	qa.check(near(v.view_range, Sim.view_of(g).range) and v.view_range > view.range, "en alerta la vista llega más lejos")
	qa.check(near(v.hearing, Hearing.HEARING_ALERT * Sim.tuning("hearing") * 0.8), "en alerta el oído usa ×1,25")
	g.suspicion_at = now - 10000.0
	qa.check(near(DevInfo.values(g, now).drop_in, (Sim.ALERT_HOLD_MS - 10000.0) / 1000.0), "le faltan 20 s para bajar de !!")
	qa.check("baja 20s" in DevInfo.guard_text(g, now), "el texto dice cuánto falta para bajar")
	qa.check(DevInfo.guard_head(g, now) == "Sos:%d  Aten:%.1f  Vel:%.1f  T:20s" % [g.suspicion, DevInfo.values(g, now).attention, DevInfo.values(g, now).speed], "la línea grande resume sospecha, atención, paso y lo que falta: " + DevInfo.guard_head(g, now))

	# Alarma sonando: ×2,5.
	var noises: Array[SoundEvent] = []
	NightAlert.trip(Vector2(5, 5), noises)
	qa.check(near(DevInfo.values(g, now).attention, 1.5 * NightAlert.ATTENTION_ALARM), "con la alarma sonando la atención sube ×2,5")
	var night := DevInfo.night_text(game.guards)
	qa.check("ALARMA suena" in night and "Noche: intruder" in night and "intruso" in night, "la línea de la noche enseña alarma e intruso: " + night)
	NightAlert.alarm_left = 0.0
	NightAlert.quiet = 5.0
	qa.check("alarma callada" in DevInfo.night_text(game.guards) and "intruso 40s" in DevInfo.night_text(game.guards), "callada, enseña lo que queda de intruso")

	# El robo: la probabilidad enseñada es la de la tirada.
	NightAlert.reset()
	g.suspicion = 0
	g.alert = false
	Heist.taken = true
	g.x = Heist.at.x + 0.5 - 2.0
	g.y = Heist.at.y + 0.5
	g.dir = 0.0
	if NightAlert.closeness(g, now) > 0.0:
		qa.check(near(DevInfo.values(g, now).theft_chance, NightAlert.find_chance(g, now)), "la probabilidad de descubrir el robo sale de find_chance")
		qa.check("Vitrina vacia" in DevInfo.guard_text(g, now), "el texto avisa de la vitrina vacía a la vista")
	NightAlert.robbed = true
	NightAlert.found_by = g.name
	qa.check("ROBO DESCUBIERTO" in DevInfo.night_text(game.guards), "la línea de la noche sabe que han robado")
	Heist.taken = false
	NightAlert.reset()

	# Los bloques se refrescan solos con lo que pasa en la noche.
	g.suspicion = 2
	g.alert = true
	g.suspicion_at = Sim.now_ms()
	game.scenery.dev_label_at[0] = -INF
	await frames(3)
	qa.check("ALERTA" in game.scenery.dev_labels[0].text, "el bloque se actualiza solo")

	# Apagar dev a mitad de noche lo quita.
	game.dev_mode = false
	game.dev_overlay.set_enabled(false)
	await frames(3)
	qa.check(game.scenery.dev_labels.is_empty(), "al apagar dev se quitan los bloques")
	qa.check(not game.dev_overlay.visible, "y el overlay")

	game.dev_mode = false
	quit(qa.summary())
