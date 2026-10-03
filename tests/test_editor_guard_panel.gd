extends SceneTree
## El panel edita el MISMO guardia y mantiene estilos y acciones del editor.
const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")
var editor: MapEditor

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Text.setup()
	editor = MapEditor.new()
	root.add_child(editor)
	await process_frame
	editor.open(MapFile.generated(4242, "small"))
	var guard := GuardSpawn.new()
	guard.at = editor.map.spawn
	editor.map.guards.append(guard)
	editor.selected_guard = guard
	editor._open("guard")
	qa.check(editor._guard_tabs.get_child_count() == 2, "panel conserva sus dos pestañas")
	qa.check(editor._guard_sub.find_children("*", "Button", true, false).size() >= 9, "capacidades conserva las tres filas de controles")
	editor._step_level("view", 1)
	qa.check(guard.view_level == 3 and editor.dirty, "un paso cambia la vista en el guardia original")
	editor._step_level("view", 0)
	qa.check(guard.view_level == 2, "pulsar la barra devuelve nivel medio")
	editor._pick_archetype("sabueso")
	qa.check(guard.hearing_level == 4 and guard.view_level == 2 and guard.speed_level == 2, "arquetipo aplica los tres niveles")
	editor._step_level("hearing", -1)
	qa.check(guard.hearing_level == 3, "nivel permanece editable después de elegir arquetipo")
	editor._pick_stance("post")
	editor._pick_watch("room")
	qa.check(guard.stance == "post" and guard.watch == "room", "puesto conserva el objetivo de vigilancia")
	editor._pick_stance("round")
	qa.check(guard.watch == "", "patrulla elimina vigilancia de puesto")
	guard.dir = -PI / 2
	editor._step_dir(1)
	qa.check(is_equal_approx(guard.dir, -PI / 4), "orientación avanza45grados")
	qa.check(not editor._guard_description(guard).is_empty(), "descripción sigue las capacidades reales")
	var host := Control.new()
	editor.add_child(host)
	var called := [0]
	var button := editor._button("PRUEBA", func(): called[0] += 1, host, Hud.C.safe, true, "save")
	qa.check(button.has_meta("photo") and button.autowrap_mode == TextServer.AUTOWRAP_OFF, "pegatina de guardar conserva presentación de botón grande")
	button.pressed.emit()
	qa.check(called[0] == 1, "botón ejecuta una sola vez su acción original")
	editor._look(button, true)
	qa.check(button.get_theme_stylebox("normal") is StyleBoxFlat, "selección conserva estilo de botón")
	qa.check(editor._level_bars_texture(4).get_width() == 160 and editor._dir_arrow_texture(0).get_width() == 40, "iconos conservan sus dimensiones")
	var count := editor.map.guards.size()
	editor._remove_selected_guard()
	qa.check(editor.selected_guard == null and editor.map.guards.size() == count - 1, "eliminar modifica el mapa original y cierra selección")
	editor.queue_free()
	await process_frame
	quit(qa.summary())
