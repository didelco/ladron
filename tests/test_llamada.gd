extends SceneTree
## La llamada de las misiones: en la casa de la banda suena el teléfono una vez
## por visita, tras un rato, si la Historia ha abierto una misión que nadie ha
## ofrecido. COGER la ofrece (llamante, pieza, historia y obsequio) y la deja
## en el menú Misiones; NO COGER (o dejar que suene) la deja pendiente; ACEPTAR
## empieza el robo; DEJAR PARA DESPUÉS vuelve a la casa. En dev no suena ni se
## guarda nada. Usa un archivo de progreso propio.
##   godot --headless --script tests/test_llamada.gd
const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")
var game: Game


func _init() -> void:
	call_deferred("run")


func frames(n := 3) -> void:
	for i in n:
		await process_frame


## Pulsa el botón del menú de la llamada con ese texto, como el ratón.
func press(text: String) -> bool:
	for b in game.hud._panel_box.find_children("*", "Button", true, false):
		if (b as Button).text == text:
			(b as Button).pressed.emit()
			return true
	return false


func visit() -> void:
	game._dojo_start(1)
	await frames()
	game.phone.begin_visit()


func listed() -> Array:
	return game.hub.active.map(func(o: Dictionary) -> String: return String(o.id))


func run() -> void:
	Story.save = "user://test_llamada.cfg"
	Settings.path = "user://test_llamada_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Story.dev = false
	var fosiles := MapFile.read("res://maps/ala_de_los_fosiles.json")
	var bustos := MapFile.read("res://maps/galeria_de_los_bustos.json")
	var cruz := MapFile.read("res://maps/cruz_del_baron.json")
	for m in [fosiles, bustos, cruz]:
		qa.check(not Missions.caller_of(m).is_empty() and String(Missions.caller_of(m).name) != "" and not Missions.caller_of(m).face.is_empty(), "cada misión de serie trae su llamante con cara: " + m.name)
	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(fosiles.to_dict())))
	qa.check(back.caller == fosiles.caller, "el llamante se guarda en el mapa y se lee igual")

	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	var phone := game.phone

	# Sin misiones abiertas no suena.
	await visit()
	qa.check(phone.next_call == null and game.phase == "playing", "sin misiones abiertas no hay llamada pendiente")
	phone.step(PhoneCall.DELAY * 3.0)
	qa.check(phone.state == "idle" and game.phase == "playing", "sin misiones abiertas no suena")

	# Abierta una: suena pasado el retardo, no antes, y solo una vez por visita.
	Story.unlock(6, 1)
	await visit()
	qa.check(phone.next_call != null and phone.next_call.name == fosiles.name, "con la primera abierta, es la que llamará")
	phone.step(PhoneCall.DELAY - 1.0)
	qa.check(phone.state == "idle", "no suena antes del retardo")
	phone.step(2.0)
	qa.check(phone.state == "ringing" and game.phase == "call" and paused, "suena tras el retardo y el juego se detiene")
	qa.check(game.hud.menu_open() and phone.texts().has(Text.t("PHONE_RING")), "el aviso es un menú del HUD con el teléfono")
	qa.check(Missions.is_called(fosiles), "al sonar queda guardada como llamada")
	phone.step(PhoneCall.RING_EVERY + 0.1)
	qa.check(phone.state == "ringing", "sigue sonando")

	# NO COGER: vuelve a la casa; sigue en pendientes y ya no vuelve a sonar.
	qa.check(press(Text.t("PHONE_IGNORE")), "el menú tiene NO COGER")
	qa.check(phone.state == "idle" and game.phase == "playing" and not paused, "NO COGER vuelve a la casa")
	phone.step(PhoneCall.DELAY * 3.0)
	qa.check(phone.state == "idle", "solo una llamada por visita")
	game.challenges.show_missions()
	qa.check(("map:" + fosiles.path) in listed() and not ("none" in listed()), "sin coger, la misión está en Misiones como pendiente")
	qa.check(not Missions.is_done(fosiles), "y sin conseguir")
	await visit()
	qa.check(phone.next_call == null, "otra visita: no vuelve a sonar por ella")

	# Sin contestar, se pierde sola.
	Story.unlock(16, 1)
	await visit()
	qa.check(phone.next_call != null and phone.next_call.name == bustos.name, "la siguiente en llamar es la de los bustos")
	phone.step(PhoneCall.DELAY + 0.1)
	qa.check(phone.state == "ringing", "otra misión abierta: suena")
	phone.step(PhoneCall.GIVE_UP + 0.1)
	qa.check(phone.state == "idle" and game.phase == "playing" and not paused and Missions.is_called(bustos), "sin contestar, se corta sola y queda en pendientes")

	# No suena con el mapa abierto.
	Story.unlock(21, 1)
	await visit()
	qa.check(phone.next_call != null and phone.next_call.name == cruz.name, "la tercera, la de la cruz")
	game.map_open = true
	phone.step(PhoneCall.DELAY + 1.0)
	qa.check(phone.state == "idle", "con el mapa abierto no suena")
	game.map_open = false
	phone.step(0.1)
	qa.check(phone.state == "ringing", "cerrado el mapa, suena")

	# COGER: la ficha de la llamada.
	qa.check(press(Text.t("PHONE_ANSWER")) and phone.state == "offer", "COGER enseña la oferta")
	var all := "\n".join(phone.texts())
	var caller := Missions.caller_of(cruz)
	qa.check(all.contains(String(caller.name)), "enseña quién llama")
	qa.check(all.contains(String(cruz.loot.name)), "enseña qué robar")
	qa.check(all.contains(String(cruz.loot.story)), "cuenta la historia")
	qa.check(all.contains(String(cruz.gift.name)), "dice el obsequio")
	qa.check(game.hud._panel_box.find_children("*", "CallerFace", true, false).size() == 1 and press(Text.t("PHONE_LATER")) == true, "la cara de quien llama y DEJAR PARA DESPUÉS")
	qa.check(phone.state == "idle" and game.phase == "playing" and not paused, "DEJAR PARA DESPUÉS vuelve a la casa")
	await visit()
	qa.check(phone.next_call == null, "ya no hay más que llamen")
	game.challenges.show_missions()
	qa.check(listed().size() == 3 and ("map:" + cruz.path) in listed(), "las tres están en Misiones")
	qa.check(game.challenges.mission_info(cruz).contains(String(caller.name)), "su ficha dice quién la encargó")
	var cfg := ConfigFile.new()
	qa.check(cfg.load(Story.save) == OK and (cfg.get_value("missions", "called", []) as Array).size() == 3, "las llamadas quedan guardadas en la sección missions")

	# Atrás (Escape, B) en el aviso es NO COGER, y en la oferta DEJAR PARA DESPUÉS.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(6, 1)
	await visit()
	phone.step(PhoneCall.DELAY + 0.1)
	game._back()
	qa.check(phone.state == "idle" and game.phase == "playing", "atrás en el aviso: NO COGER")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(6, 1)
	await visit()
	phone.step(PhoneCall.DELAY + 0.1)
	press(Text.t("PHONE_ANSWER"))
	game._back()
	qa.check(phone.state == "idle" and game.phase == "playing", "atrás en la oferta: DEJAR PARA DESPUÉS")

	# ACEPTAR: empieza el robo de esa misión con la banda actual.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(6, 1)
	await visit()
	phone.step(PhoneCall.DELAY + 0.1)
	press(Text.t("PHONE_ANSWER"))
	press(Text.t("PHONE_ACCEPT"))
	await frames()
	qa.check(game.mode == "challenge" and game.challenges.challenge_map.name == fosiles.name and game.phase == "brief", "ACEPTAR empieza el robo de esa misión")
	qa.check(game.players == 1, "con la banda actual")

	# Una partida anterior sin el dato: las conseguidas cuentan como ofrecidas.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(21, 1)
	Missions.complete(cruz)
	qa.check(Missions.is_called(cruz) and not Missions.is_called(fosiles), "una misión conseguida sin 'called' guardado cuenta como llamada")
	qa.check(Missions.pending_call().name == fosiles.name, "y la primera pendiente sigue el orden de AFTER")

	# Dev: no suena, todo listado y nada guardado.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	game.dev_mode = true
	qa.check(Missions.pending_call() == null, "dev: no hay llamadas")
	Missions.mark_called(fosiles)
	qa.check(not FileAccess.file_exists(Story.save), "dev: no se guarda nada de 'llamada'")
	game.challenges.show_missions()
	qa.check(listed().size() == 3, "dev: Misiones las lista todas")
	game.dev_mode = false

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	game.free()
	quit(qa.summary())
