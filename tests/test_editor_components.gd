extends SceneTree
## Integración del editor: vista 3D y acciones de mando sin dispositivos físicos.
const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")
var editor: MapEditor
var rebuilds := 0
var requested: MapFile

func frames(n := 2) -> void:
	for i in n:
		await process_frame

func button(index: int, pressed := true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = pressed
	return event

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Text.setup()
	var world := Node3D.new()
	root.add_child(world)
	var original := Camera3D.new()
	world.add_child(original)
	original.make_current()
	editor = MapEditor.new()
	root.add_child(editor)
	await frames()
	editor.open(MapFile.generated(4242, "small"))
	editor.set_process(false)
	editor.preview.connect(func(map: MapFile) -> void:
		rebuilds += 1
		requested = map)
	qa.check(editor.map.check().is_empty(), "plano inicial jugable")
	var initial_kind := editor.kind
	editor._pad_kind(1)
	qa.check(editor.kind != initial_kind, "mando cambia la categoría")
	editor._pad_kind(-1)
	qa.check(editor.kind == initial_kind, "mando vuelve a la categoría inicial")
	editor._pick_kind("construir")
	editor._pick_tool("wall")
	editor._pad_item(1)
	qa.check(editor.tool != "wall", "mando selecciona otra herramienta del catálogo")
	editor._pad_dir = Vector2i.ONE
	editor._pad_cursor(0.01)
	qa.check(editor._pad_dir == Vector2i.ZERO, "mando sin dirección detiene la repetición del cursor")
	editor.hover = MapFile.NONE
	editor._pick_tool("spawn")
	editor._pad_on_plan(button(JOY_BUTTON_A))
	qa.check(editor.hover == editor.map.spawn, "primera acción del mando coloca el cursor en el inicio")
	editor._pad_on_plan(button(JOY_BUTTON_A, false))
	var free: Array[Vector2i] = []
	for y in range(1, editor.map.h - 1):
		for x in range(1, editor.map.w - 1):
			var tile := Vector2i(x, y)
			if editor.map.at(tile) == Tiles.FLOOR and tile not in [editor.map.spawn, editor.map.piece, editor.map.exit]:
				free.append(tile)
	var at := free[0]
	editor.hover = at
	editor._pick_tool("wall")
	editor._pad_on_plan(button(JOY_BUTTON_A))
	qa.check(editor.map.at(at) == Tiles.WALL and editor._pad_stroke == 1, "A inicia trazo y pinta la casilla del cursor")
	editor._pad_on_plan(button(JOY_BUTTON_A, false))
	qa.check(editor._pad_stroke == 0, "soltar A termina el trazo")
	editor._pad_on_plan(button(JOY_BUTTON_B))
	qa.check(editor.map.at(at) == Tiles.FLOOR, "B deshace el trazo")
	editor.map.apply()
	editor.start_preview(world)
	var preview_camera := editor._cam
	qa.check(editor.in_3d and root.get_camera_3d() == preview_camera, "3D activa su propia cámara")
	qa.check(not editor._back.visible and editor._view_button.tooltip_text == Text.t("EDITOR_2D"), "3D cambia fondo y botón de retorno")
	editor._rebuild()
	qa.check(rebuilds == 1 and requested != editor.map and requested.check().is_empty(), "reconstruir emite una copia jugable del mapa")
	editor.hover = at
	editor._pick_tool("wall")
	editor._pad_on_plan(button(JOY_BUTTON_A))
	qa.check(editor._marks.get_child_count() > 0 and rebuilds == 1, "trazo 3D marca cambios sin reconstruir todavía")
	editor._pad_on_plan(button(JOY_BUTTON_A, false))
	qa.check(rebuilds == 2 and not editor._pad_marked, "soltar trazo 3D reconstruye una sola vez")
	var valid_spawn := editor.map.spawn
	editor.map.spawn = MapFile.NONE
	editor._rebuild()
	qa.check(rebuilds == 2, "mapa inválido no pide reconstrucción")
	editor.map.spawn = valid_spawn
	editor.stop_preview()
	await frames()
	qa.check(not editor.in_3d and root.get_camera_3d() == original, "volver a 2D restaura cámara anterior")
	qa.check(not is_instance_valid(preview_camera) and editor._back.visible, "volver a 2D libera cámara y devuelve fondo")
	editor.start_preview(world)
	editor.queue_free()
	await frames()
	qa.check(root.get_camera_3d() == original, "cerrar el editor en 3D restaura cámara anterior")
	world.queue_free()
	await frames()
	quit(qa.summary())
