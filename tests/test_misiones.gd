extends SceneTree
## Las misiones (los antiguos retos): cada mapa propone un robo con historia,
## pieza y obsequio; el obsequio pasa al inventario la primera vez que se
## escapa con la pieza, y solo esa vez; perder no lo da; el progreso sobrevive
## a recargar. Usa un archivo de progreso propio, no la partida real.
##   godot --headless --script tests/test_misiones.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func _init() -> void:
	Story.save = "user://test_misiones.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))

	var m := MapFile.read("res://maps/cruz_del_baron.json")
	check(m != null and m.loot.name == "Corona del Barón" and String(m.loot.story) != "", "la misión de serie trae pieza e historia")
	check(String(m.gift.get("name", "")) != "", "y un obsequio con nombre")
	var back := MapFile.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check(back.gift == m.gift, "el obsequio se guarda en el mapa y se lee igual")

	check(Missions.inventory().is_empty() and not Missions.is_done(m), "al principio, inventario vacío y misión sin conseguir")
	var won := Missions.complete(m)
	check(won.name == m.gift.name and Missions.is_done(m), "la primera vez da el obsequio y marca la misión")
	check(Missions.inventory().size() == 1 and Missions.inventory()[0].name == m.gift.name, "el obsequio está en el inventario")
	check(Missions.complete(m).is_empty() and Missions.inventory().size() == 1, "repetirla no lo da otra vez ni lo duplica")

	var other := MapFile.read("res://maps/ala_de_los_fosiles.json")
	check(not Missions.is_done(other) and Missions.inventory().size() == 1, "perderla (no completarla) no da nada ni marca otras misiones")
	check(Missions.complete(other).name == other.gift.name and Missions.inventory().size() == 2, "otra misión da su propio obsequio")

	# Recargar: otra lectura del archivo ve lo mismo.
	check(Missions.is_done(m) and Missions.is_done(other) and Missions.inventory().size() == 2, "el progreso persiste al recargar")
	var cfg := ConfigFile.new()
	check(cfg.load(Story.save) == OK and (cfg.get_value("missions", "gifts", []) as Array).size() == 2, "queda escrito en el archivo de progreso")

	# Las misiones se abren con la Historia: cada una al conseguir su robo.
	check(Missions.is_mission(m) and Missions.is_mission(other) and Missions.opens_after(other) == 5, "las de serie son misiones, cada una con su robo de la Historia")
	check(not Missions.is_open(other) and not Missions.is_open(m), "sin avanzar en la Historia están cerradas")
	Story.unlock(6, 2)
	check(Missions.is_open(other) and not Missions.is_open(m), "conseguido el robo 5 (con cualquier banda) se abre la suya y no las demás")

	# Un mapa creado, importado o descargado: fuera de la Historia, no es misión
	# y nunca da premio.
	var mine := MapFile.generated(5, "small")
	mine.name = "Mi museo de prueba"
	check(not Missions.is_mission(mine) and Missions.story_of(mine) == "" and not Missions.has_gift(mine) and Missions.gift_of(mine).is_empty(), "un mapa del jugador no es misión: sin historia ni obsequio")
	check(Missions.complete(mine).is_empty() and not Missions.is_done(mine) and Missions.inventory().size() == 2, "conseguirlo no da premio, no lo marca ni toca el inventario")
	var copy := m.copy()
	copy.built_in = false
	copy.path = "user://maps/cruz_del_baron.json"
	check(not Missions.is_mission(copy) and Missions.complete(copy).is_empty(), "la copia del jugador de una misión tampoco lo es")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
