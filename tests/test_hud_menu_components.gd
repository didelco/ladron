extends SceneTree
## Menús compuestos conservan estado, foco, callbacks y enlaces entre columnas.
const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Text.setup()
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	var container := VBoxContainer.new()
	hud.add_child(container)
	var state := Hud.MenuState.new()
	var calls := [0]
	var accept := func(): calls[0] += 1
	hud._menu_item({"columns": [{"items": [
		{"text": "TEXTO", "id": "label"},
		{"field": {"text": "NOMBRE", "id": "field"}},
		{"list": [{"text": "PRIMERO", "open": accept, "selected": true}], "right_id": "target"}]},
		{"items": [{"buttons": [{"text": "ACEPTAR", "id": "target", "call": accept}]}]}]}, container, state)
	hud._menu_item({"table": [["CABECERA", "VALOR"], ["FILA", "DATO"]], "widths": [150, 150]}, container, state)
	qa.check(hud._named.label.text == "TEXTO" and hud.field_text("field") == "NOMBRE", "columnas registran texto y campo por id")
	qa.check(state.rows.size() == 3 and state.first == hud._fields.field, "conserva filas y primer foco")
	qa.check(state.focus_on != null and state.focus_on.text == "PRIMERO", "lista conserva selección inicial")
	hud._resolve_right_links(state)
	qa.check(state.by_id.has("target") and state.rows[1].has(state.by_id.target), "lista enlaza al botón de la otra columna")
	state.by_id.target.pressed.emit()
	state.focus_on.pressed.emit()
	qa.check(calls[0] == 2, "lista y botón conservan sus callbacks")
	var stepped := [99]
	var setting := hud._button({"text": "VALOR", "step": func(dir: int): stepped[0] = dir; return "NUEVO"})
	container.add_child(setting)
	setting.pressed.emit()
	qa.check(setting.text == "NUEVO" and stepped[0] == 0, "selector actualiza texto sin reconstruir botón")
	qa.check(setting.get_theme_stylebox("normal") is StyleBoxFlat, "botones conservan marcos compartidos")
	var arrow := hud._card_arrow(">", [setting], 1)
	container.add_child(arrow)
	qa.check(arrow.focus_mode == Control.FOCUS_NONE, "flecha del carrusel no captura el foco")
	var first := Hud.glyph("settings")
	qa.check(first == Hud.glyph("settings"), "glifo conserva su caché compartida")
	hud.queue_free()
	await process_frame
	quit(qa.summary())
