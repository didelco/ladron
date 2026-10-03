extends SceneTree
## La cámara del menú de inicio (la casa de cerca, como fondo) y la del juego, más lejos.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var m: Game

## The camera moves on the physics tick: wait for a few of those, not just
## drawn frames (three of which may hold none).
func frames(n := 6) -> void:
	for i in n: await physics_frame
	await process_frame

func _init() -> void:
	call_deferred("run")

func run() -> void:
	Story.save = "user://test_camara_menu.cfg"
	Settings.path = "user://test_camara_menu_settings.cfg"
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames()
	for c in m.get_children():
		if c is TitleScreen: c.queue_free()
	m._show_title()
	m.rig.menu_view(true, true)
	await frames()
	var menu_eye := m.camera.position
	var menu_far := menu_eye.distance_to(m.rig.cam_rest - CameraRig.CAM_OFFSET)
	qa.check(m.rig.menu_blend == 1.0, "en el menú la cámara está en el encuadre del menú")
	m._dojo_start(1)
	qa.check(m.rig.menu_blend > 0.99 and m.rig.menu_tween != null, "al entrar en Guarida empieza en el encuadre del menú y hay transición")
	m.rig.menu_tween.custom_step(10.0)
	await frames()
	var play_eye := m.camera.position
	var play_far := play_eye.distance_to(m.rig.cam_rest - CameraRig.CAM_OFFSET)
	qa.check(m.rig.menu_blend == 0.0 and play_far > menu_far * 1.2, "... y acaba en la cámara de juego, más lejos que la del menú (%.1f > %.1f)" % [play_far, menu_far])
	m._pause()
	await frames()
	qa.check(m.rig.menu_blend == 0.0, "la pausa no cambia la cámara")
	m.hub._pick("leave")
	await frames()
	qa.check(m.rig.menu_tween != null and m.rig.menu_blend >= 0.0, "volver al inicio lleva otra vez al encuadre del menú")
	m.rig.menu_tween.custom_step(10.0)
	qa.check(m.rig.menu_blend == 1.0, "... y lo alcanza")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
