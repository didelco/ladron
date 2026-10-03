extends SceneTree
## Con mando, de verdad: Start abre y cierra la pausa, B la cierra, el D-pad
## mueve el cursor y SALIR llega al menú principal. Eventos de mando reales
## por el viewport (Input.parse_input_event), no _intent a mano; en una noche
## suelta y en la guarida.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var m: Game

class OnePad extends Pads.Source:
	func connected() -> Array[int]:
		return [0]
	func info(_device: int) -> Dictionary:
		return {"vendor_id": 0x045e, "product_id": 0x0b13}
	func guid(device: int) -> String:
		return "0500b7b5ac05000004000000ae796d04" if device == 1 else "030000005e040000130b000000000000"


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func frames(n := 6) -> void:
	for i in n:
		await process_frame


func pad(button: int, device := 0) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = device
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await process_frame
	await frames()


func paused_ok(label: String) -> void:
	check(m.phase == "paused" and m.hub.visible and m.hub.active_kind == "pause" and paused, label + ": en pausa y el hub a la vista (" + m.phase + ")")


func playing_ok(label: String) -> void:
	check(m.phase == "playing" and not m.hub.visible and not paused, label + ": jugando y sin hub (" + m.phase + ")")


func pick(id: String) -> void:
	for i in m.hub.active.size():
		if m.hub.active[i].id == id:
			m.hub._select(i)
			return


func circuit(label: String, leave_confirms: bool) -> void:
	await pad(JOY_BUTTON_START)
	paused_ok(label + " Start abre")
	await pad(JOY_BUTTON_START)
	playing_ok(label + " Start cierra")
	await pad(JOY_BUTTON_START)
	paused_ok(label + " Start abre otra vez")
	await pad(JOY_BUTTON_B)
	playing_ok(label + " B cierra")
	await pad(JOY_BUTTON_START)
	await pad(JOY_BUTTON_DPAD_DOWN)
	var c0: int = m.hub.cursor
	await pad(JOY_BUTTON_DPAD_RIGHT)
	check(m.hub.cursor != c0 or m.hub.active.size() == 1, label + " el D-pad mueve el cursor")
	await pad(JOY_BUTTON_DPAD_LEFT)
	pick("leave")
	await frames(2)
	await pad(JOY_BUTTON_A)
	if leave_confirms:
		check(m.phase == "paused" and m.hub.active_kind == "confirm", label + " A en Salir pide confirmación (" + m.phase + ")")
		await pad(JOY_BUTTON_B)
		paused_ok(label + " B cancela la confirmación")
		pick("leave")
		await frames(2)
		await pad(JOY_BUTTON_A)
		pick("yes")
		await frames(2)
		await pad(JOY_BUTTON_A)
	check(m.phase != "paused" and m.phase != "playing" and not paused, label + " A en SÍ sale al menú (" + m.phase + ")")
	await frames(10)
	check(m.hub.visible and m.phase in ["title", "generative", "city", "menu"], label + " ... y se ve un menú (" + m.phase + ", hub " + str(m.hub.visible) + ")")


func _init() -> void:
	Pads.source = OnePad.new()
	Story.save = "user://test_pad_pausa_progress.cfg"
	Settings.path = "user://test_pad_pausa_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	var settings := Settings.DEFAULTS.duplicate()
	settings.screen_mode = "window"
	settings.sound = false
	settings.music = false
	Settings.write(settings)
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames()
	for c in m.get_children():
		if c is TitleScreen:
			c.queue_free()
	await frames()
	# Una noche suelta.
	m.players = 1
	m.mode = "generative"
	m.seats.assign(["any"])
	m._new_round(1)
	m._start_playing()
	await frames()
	# El mando de Mac que manda Start y View cambiados (Pads.SWAPPED_START):
	# su Start llega como View y aun así pausa; su View, como Start, es el mapa.
	check(Pads.button(1, JOY_BUTTON_BACK) == JOY_BUTTON_START and Pads.button(0, JOY_BUTTON_BACK) == JOY_BUTTON_BACK, "solo el mando cambiado se corrige")
	await pad(JOY_BUTTON_BACK, 1)
	paused_ok("cambiado: Start (llega como View) abre")
	await pad(JOY_BUTTON_BACK, 1)
	playing_ok("cambiado: Start cierra")
	await pad(JOY_BUTTON_START, 1)
	check(m.phase == "playing" and m.map_open, "cambiado: View (llega como Start) saca el mapa")
	await pad(JOY_BUTTON_START, 1)
	check(m.phase == "playing" and not m.map_open, "cambiado: View lo guarda")
	await circuit("noche:", true)
	# La guarida.
	m._show_title("dojo", false)
	await frames(12)
	await pad(JOY_BUTTON_A)
	await frames(12)
	check(m.phase == "playing" and m.mode == Practice.MODE, "A entra en la guarida (" + m.phase + ")")
	await circuit("guarida:", false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
