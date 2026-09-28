extends SceneTree
## La cámara dentro de un museo: al elegir una sala gira alrededor del
## edificio hasta mirar su pared (de frente o en tres cuartos, un poco desde
## arriba) y se acerca; de una sala a otra se mueve, gira y hace zoom a la
## vez, sin saltos; las flechas rodean el edificio en un orden que no cambia
## al girar; al salir, la ciudad como siempre. También con las salas del
## costado izquierdo y de detrás de la prehistoria.
var fails := 0
func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FALLO ") + what)
	if not ok: fails += 1


func frames(n := 4) -> void:
	for i in n:
		await process_frame


## Whether the camera looks at room i's wall: straight on or three quarters.
func facing(stage: CityStage, i: int) -> bool:
	var look := -stage.camera().global_basis.z
	return look.dot(-stage.room_face(i).z) > 0.6


## Every room reached, from the first round the museum to the last, by the
## right arrow: [order, whether it looked at each and had it on screen].
func walk(tour: Tour) -> Array:
	var stage := tour.stage
	var screen := Rect2(Vector2.ZERO, Vector2(stage.size))
	for k in 6:
		tour.act("left")
	var order: Array[int] = [stage.room]
	var ok := facing(stage, stage.room)
	for k in 6:
		tour.act("right")
		if stage.room != order[-1]:
			order.append(stage.room)
		var i := stage.room
		ok = ok and facing(stage, i) and screen.has_point(stage.room_on_screen(i)) and screen.has_point(stage.room_foot_on_screen(i))
	return [order, ok]


func _init() -> void:
	Story.save = "user://test_camara_museo.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	Story.unlock(Story.count(), 1)

	for m in Story.MUSEUMS.size():
		var tour := Tour.new()
		root.add_child(tour)
		var stage := tour.stage
		stage.hurry = true
		tour.open_city(1, m)
		await frames()
		var city_basis := stage.camera().global_basis
		var city_view := stage.camera().size
		var name: String = Story.museum(m).name
		tour._enter_museum()
		await frames()
		check(tour.state == "museum" and stage.room_open(stage.room), "%s: dentro, una sala elegida" % name)
		check(facing(stage, stage.room) and stage.camera().size < stage._view_of(m), "... la cámara mira su pared y se acerca más que al edificio entero")
		check(stage.camera().near > 1.0, "... y lo que hay entre la cámara y la ventana no estorba")
		var reached: Array = range(5).filter(func(i: int) -> bool: return stage.room_open(i))
		var w := await walk(tour)
		var order: Array = w[0]
		order.sort()
		check(order == reached, "... las flechas recorren todas las salas " + str(w[0]))
		check(w[1], "... cada una, mirando su pared, con su cartel y sus estrellas en pantalla")
		# Stable: the order round the building is the same whichever room the
		# camera is at.
		var along := func() -> Array: return reached.map(func(i: int) -> float: return stage.room_along(i))
		tour._pick_room(reached[0])
		var at_first: Array = along.call()
		tour._pick_room(reached[-1])
		check(along.call() == at_first, "... el orden no cambia al girar la cámara")
		await frames()
		var stars_ok := true
		for i in reached:
			if i == stage.room:
				var l: Label = tour._room_stars[i]
				stars_ok = stars_ok and l.visible and Rect2(Vector2.ZERO, tour._root.get_viewport_rect().size).has_point(l.position)
		check(stars_ok and tour._sign.visible, "... el cartel y las estrellas de la elegida, a la vista")
		tour._leave_museum()
		await frames()
		check(tour.state == "city" and stage.camera().global_basis.is_equal_approx(city_basis) and is_equal_approx(stage.camera().size, city_view),
			"... al salir, la ciudad desde el ángulo de siempre")
		check(stage.camera().near < 1.0, "... sin recortar nada")
		tour.queue_free()
		await frames()

	# Rooms round the back and on the left side: the prehistory museum's.
	var tour := Tour.new()
	root.add_child(tour)
	var stage := tour.stage
	stage.hurry = true
	tour.open_museum(1, Story.nights_in(0)[0])
	await frames()
	var body := stage._body(0)
	var back := -1
	var left := -1
	for i in 5:
		var z := (body.windows[i].face as Basis).z
		if back < 0 and z.z < -0.9:
			back = i
		elif left < 0 and z.x < -0.9:
			left = i
	var wall := func(i: int) -> Vector3:
		return stage._museums[0].global_basis.inverse() * stage.room_face(i).z
	check((wall.call(back) as Vector3).z < -0.9 and (wall.call(left) as Vector3).x < -0.9, "una sala detrás y otra en el costado izquierdo")
	tour._pick_room(back)
	check(facing(stage, back) and stage.room_seen(back), "detrás: la cámara da la vuelta al edificio y la mira")
	check(not stage.room_seen(4), "... y la del gran golpe, en la fachada, no se ve: sin estrellas ni ratón")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = stage.on_screen(stage.room_centre(4))
	tour._on_mouse(click)
	check(stage.room == back, "... un clic donde cae por detrás no la elige")
	tour._pick_room(left)
	check(facing(stage, left), "a la izquierda: la mira también")
	var w := await walk(tour)
	check(w[1] and (w[0] as Array)[0] == left and (w[0] as Array)[-1] == back and (w[0] as Array).size() == 5,
		"las flechas: el costado izquierdo, la fachada, el derecho y detrás " + str(w[0]))
	# Up and down by height, whichever wall.
	tour._pick_room(left)
	var y0 := stage.room_centre(left).y
	tour.act("up")
	var upper := stage.room
	tour.act("down")
	check(upper != left and stage.room_centre(upper).y > y0 and stage.room_centre(stage.room).y < stage.room_centre(upper).y,
		"arriba y abajo, por altura, sea cual sea la pared")

	# The way from one room to another, smooth: no frame jumps far, the
	# shortest way round, and the lamp on the wall looked at.
	tour._pick_room(left)
	stage.hurry = false
	tour._pick_room(back)
	var yaws: Array[float] = [stage.yaw]
	var steps := 0
	while stage._orbit and stage._orbit.is_running() and steps < 400:
		await process_frame
		yaws.append(stage.yaw)
		steps += 1
	var most := 0.0
	for k in yaws.size() - 1:
		most = maxf(most, absf(yaws[k + 1] - yaws[k]))
	check(steps > 5 and most < 20.0, "de una sala a otra, un giro suave (%d fotogramas, como mucho %.1f° en uno)" % [steps, most])
	check(absf(yaws[-1] - yaws[0]) <= 180.0 + 0.01, "... por el camino más corto (%.0f°)" % absf(yaws[-1] - yaws[0]))
	check(facing(stage, back), "... y acaba mirando la sala")
	var lamp := stage._front_light.global_basis.z
	check(lamp.dot(stage.room_face(back).z) > 0.3, "la luz de cerca, sobre la pared elegida")
	# The plan out of a room round the back: out of its window, and not left
	# out by the camera.
	var img := Image.create(60, 40, false, Image.FORMAT_RGBA8)
	stage.raise_plan(img, 4.0, func() -> void: pass)
	check(stage.camera().near < 1.0 and facing(stage, back), "con el plano fuera, nada recortado: sale de su ventana a delante de todo")
	stage.lower_plan(func() -> void: pass)
	await frames(2)
	stage._tween.custom_step(10.0)
	check(stage.camera().near > 1.0 and stage.sheet == null, "... y al guardarlo, otra vez como estaba")
	tour.queue_free()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	print("FALLOS: %d" % fails if fails else "OK: la cámara del museo")
	quit(1 if fails else 0)
