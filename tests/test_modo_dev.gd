extends SceneTree
## Modo dev: lo abre todo (robos, museos, salas, misiones, lecciones) y no
## guarda nada de lo que se juega en el progreso; apagado, todo se guarda y se
## ve el progreso real. Usa archivos propios, no la partida real.
##   godot --headless --script tests/test_modo_dev.gd
const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func _init() -> void:
	Story.save = "user://test_modo_dev.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.dev = false
	var fosiles := MapFile.read("res://maps/ala_de_los_fosiles.json")
	var cruz := MapFile.read("res://maps/cruz_del_baron.json")
	var trial := DojoTrials.ids()[0]
	var late_trial := DojoTrials.ids().filter(func(id: String) -> bool: return Story.lesson_night(String(DojoTrials.info(id).lesson)) > 1)

	# Sin dev: cerrado, y lo jugado se guarda.
	qa.check(Story.unlocked(1) == 1 and not Missions.is_open(fosiles) and not Missions.is_open(cruz), "sin dev solo está abierto el primer robo y las misiones cerradas")
	qa.check(not late_trial.is_empty() and not DojoTrials.unlocked(late_trial[0], 1), "sin dev las pruebas del dojo de lecciones tardías están cerradas")

	# Con dev: todo abierto, sin escribir nada.
	Story.dev = true
	qa.check(Story.unlocked(1) == Story.count() and Story.unlocked(4) == Story.count(), "dev: todos los robos (todos los museos y salas) abiertos")
	qa.check(Story.reached(1) == 1, "dev: el progreso real sigue siendo el real")
	qa.check(Missions.is_open(fosiles) and Missions.is_open(cruz), "dev: todas las misiones abiertas")
	qa.check(DojoTrials.unlocked(late_trial[0], 1) and Practice.reached(1) == Story.count(), "dev: pruebas y lecciones del dojo abiertas")
	qa.check(StarSlots.room_line(25, 1) != "", "dev: las estrellas de cualquier sala se enseñan")
	Story.unlock(10, 1)
	var fresh := Story.keep_stars(3, 1, Story.STAR_TAKEN | Story.STAR_FAST)
	Story.record_time(3, 1, 12.0)
	var gift := Missions.complete(fosiles)
	var record := DojoTrials.record(trial, 1, 50.0, true)
	qa.check(fresh == (Story.STAR_TAKEN | Story.STAR_FAST) and gift.is_empty() and record, "dev: el resultado de la partida se puede enseñar (estrellas nuevas, récord) sin dar obsequio")
	qa.check(not FileAccess.file_exists(Story.save), "dev: no se ha escrito el archivo de progreso")
	Story.dev = false
	qa.check(Story.unlocked(1) == 1 and Story.stars(3, 1) == 0 and Story.best_time(3, 1) == 0.0, "al apagar dev, el progreso real: sin robo, estrellas ni récord")
	qa.check(not Missions.is_done(fosiles) and Missions.inventory().is_empty() and DojoTrials.best(trial, 1) == 0.0 and not DojoTrials.won(trial, 1), "ni misión, ni inventario, ni prueba del dojo")
	qa.check(not Missions.is_open(fosiles), "al apagar dev las misiones vuelven a estar cerradas")

	# Sin dev se guarda todo.
	Story.unlock(10, 1)
	Story.keep_stars(3, 1, Story.STAR_TAKEN)
	Story.record_time(3, 1, 12.0)
	var real := Missions.complete(fosiles)
	DojoTrials.record(trial, 1, 50.0, true)
	qa.check(Story.unlocked(1) == 10 and Story.stars(3, 1) == 1 and Story.best_time(3, 1) == 12.0, "sin dev se guardan robo, estrellas y récord")
	qa.check(Missions.is_done(fosiles) and real.name == fosiles.gift.name and Missions.inventory().size() == 1 and DojoTrials.won(trial, 1), "sin dev se guardan misión, obsequio y prueba")

	# Jugar con dev encima de un progreso real no lo cambia.
	var before := FileAccess.get_file_as_string(Story.save)
	Story.dev = true
	Story.unlock(20, 1)
	Story.keep_stars(4, 1, Story.STAR_TAKEN | Story.STAR_UNSEEN | Story.STAR_FAST)
	Story.record_time(3, 1, 5.0)
	Missions.complete(cruz)
	DojoTrials.record(trial, 1, 1.0, true)
	qa.check(FileAccess.get_file_as_string(Story.save) == before, "dev sobre un progreso real: el archivo queda idéntico")
	Story.dev = false
	qa.check(Story.unlocked(1) == 10 and Story.best_time(3, 1) == 12.0 and not Missions.is_done(cruz), "y al apagar dev se ve el progreso de antes")

	# El ajuste de Game apaga/enciende el interruptor.
	var game := Game.new()
	game.dev_mode = true
	var on := Story.dev
	game.dev_mode = false
	qa.check(on and not Story.dev, "Game.dev_mode gobierna Story.dev")
	game.free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
