class_name EditorPreview3D
## Cámara orbital y marcas de edición en 3D. El mapa y sus herramientas
## siguen perteneciendo a MapEditor: esta vista llama a sus reglas existentes.
extends RefCounted

var host: MapEditor

func _init(editor: MapEditor) -> void:
	host = editor


# --- The 3D view --------------------------------------------------------------------

func toggle() -> void:
	if host.in_3d:
		stop()
	else:
		host._ask_preview()


## The museum just built from the map in the game's world (Main has laid it
## out): the plan makes way for it, a camera comes round it, and whatever
## changed since the last build throws up a little dust.
func start(world: Node3D) -> void:
	var first := not host.in_3d
	host.in_3d = true
	host._back.visible = false
	if first:
		host._was_current = host.get_viewport().get_camera_3d()
	host._cam = Camera3D.new()
	host._cam.fov = 45
	world.add_child(host._cam)
	host._cam.make_current()
	# A little moonlight from over the camera: the museum at night, but readable.
	host._cam_light = DirectionalLight3D.new()
	host._cam_light.light_color = Color("#b8c4ff")
	host._cam_light.light_energy = 0.5
	world.add_child(host._cam_light)
	if not host._span_set:
		host._span = maxf(host.map.w, host.map.h) * 0.9
		host._span_set = true
	place_camera()
	host._hover_mark = MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(0.96, 0.96)
	host._hover_mark.mesh = q
	host._hover_mark.material_override = mark_material(Color(Hud.CREAM, 0.45))
	host._hover_mark.visible = false
	world.add_child(host._hover_mark)
	host._marks = Node3D.new()
	world.add_child(host._marks)
	for t in changed_tiles(host._built, host.map).slice(0, 14):
		Fx.puff(world, MuseumView.to_world(t.x + 0.5, t.y + 0.5))
	host._built = host.map.copy()
	host._view_button.icon = load("res://assets/icons/editor/rooms.svg")
	host._view_button.tooltip_text = Text.t("EDITOR_2D")
	host._refresh()


## Back to the plan.
func stop() -> void:
	if not host.in_3d:
		return
	host.in_3d = false
	host._back.visible = true
	for n in [host._cam, host._cam_light, host._hover_mark, host._marks]:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(host._was_current):
		host._was_current.make_current()
	host._view_button.icon = load("res://assets/icons/editor/view3d.svg")
	host._view_button.tooltip_text = Text.t("EDITOR_PREVIEW")
	host._refresh()
	host._plan.grab_focus()


func restore_camera() -> void:
	# Leaving from the 3D: the game's camera back.
	if host.in_3d and is_instance_valid(host._was_current):
		host._was_current.make_current()


## Build the museum again from the map as it is now; one that cannot be
## played cannot be built, and waits (with its marks) until it can.
func rebuild() -> void:
	if not host.in_3d:
		return
	if not host.map.check().is_empty():
		host._say(Text.t("EDITOR_3D_WAITS"), Hud.C.gold)
		return
	host.preview.emit(host.map.copy())


## Tiles that differ between two builds: what is on them or stands there.
static func changed_tiles(a: MapFile, b: MapFile) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if a == null or a.w != b.w or a.h != b.h:
		return out
	for y in b.h:
		for x in b.w:
			var t := Vector2i(x, y)
			if a.at(t) != b.at(t) or a.exhibits.get(t, "") != b.exhibits.get(t, "") \
					or a.guards.any(func(g): return g.at == t) != b.guards.any(func(g): return g.at == t) \
					or a.doors.has(t) != b.doors.has(t) or a.columns.has(t) != b.columns.has(t) \
					or a.props.any(func(p): return p.at == t) != b.props.any(func(p): return p.at == t):
				out.append(t)
	for k in [["spawn", a.spawn, b.spawn], ["piece", a.piece, b.piece], ["exit", a.exit, b.exit]]:
		if k[1] != k[2] and b.inside(k[2]):
			out.append(k[2])
	return out


## The tile under the mouse: the top of a wall if it points at one, or the
## floor.
func tile_under_mouse() -> Vector2i:
	if not is_instance_valid(host._cam):
		return MapFile.NONE
	var at := host.get_viewport().get_mouse_position()
	var o := host._cam.project_ray_origin(at)
	var d := host._cam.project_ray_normal(at)
	for height in [MuseumView.WALL_HEIGHT, 0.0]:
		if absf(d.y) < 0.0001:
			continue
		var k: float = (height - o.y) / d.y
		if k <= 0.0:
			continue
		var p := o + d * k
		var t := Vector2i(floori(p.x + host.map.w / 2.0), floori(p.z + host.map.h / 2.0))
		if not host.map.inside(t):
			continue
		if height == 0.0 or (host.map.at(t) == Tiles.WALL and not host.map.is_out(t)):
			return t
	return MapFile.NONE


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# The right button held: turn round the museum.
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			host._yaw += event.relative.x * 0.01
			host._pitch = clampf(host._pitch + event.relative.y * 0.01, 0.25, 1.45)
			place_camera()
		var t := tile_under_mouse()
		if t != host.hover:
			host.hover = t
			if host.held == MOUSE_BUTTON_LEFT and t != MapFile.NONE and host._paints():
				host._use(t, false)
				mark_tile(t)
		place_hover()
	elif event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				host._span = maxf(8.0, host._span * 0.9)
				place_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				host._span = minf(90.0, host._span * 1.1)
				place_camera()
			MOUSE_BUTTON_RIGHT:
				# A click without a drag rubs out, as on the plan.
				if event.pressed:
					host._right_from = event.position
				elif host._right_from.distance_to(event.position) < 6.0 and host.hover != MapFile.NONE:
					host._press(host.hover, true)
					rebuild()
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					host._plan.grab_focus()
					host.hover = tile_under_mouse()
					if host.hover == MapFile.NONE:
						return
					host.held = MOUSE_BUTTON_LEFT
					host._press(host.hover, false)
					if host._paints():
						mark_tile(host.hover)
					elif host.tool != "room":
						rebuild()
				else:
					host.held = 0
					if host.tool == "room" and host.room_from != MapFile.NONE and host.hover != MapFile.NONE and host.room_from != host.hover:
						host._mark_room(host.hover)
					if host._paints() or host.tool == "room":
						rebuild()
	elif event.is_action_pressed("ui_accept") and host.hover != MapFile.NONE:
		host._press(host.hover, false)
		rebuild()
	host._plan.accept_event()


## A tile painted in a stroke not yet built: a block of wall, a case, or a
## patch of floor, in the plan's colours.
func mark_tile(t: Vector2i) -> void:
	var tile := host.map.at(t)
	var tall := 1.2 if tile == Tiles.WALL else (0.8 if tile == Tiles.COVER else 0.04)
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, tall, 1.0)
	m.mesh = box
	var colour: Color = Hud.MAP_WALL if tile == Tiles.WALL else (Hud.MAP_CASE if tile == Tiles.COVER else Hud.MAP_FLOOR)
	m.material_override = mark_material(Color(colour, 0.85))
	m.position = MuseumView.to_world(t.x + 0.5, t.y + 0.5, tall / 2.0)
	host._marks.add_child(m)


func place_hover() -> void:
	if not is_instance_valid(host._hover_mark):
		return
	host._hover_mark.visible = host.hover != MapFile.NONE
	if host.hover != MapFile.NONE:
		var on_wall := host.map.at(host.hover) == Tiles.WALL
		host._hover_mark.position = MuseumView.to_world(host.hover.x + 0.5, host.hover.y + 0.5, MuseumView.WALL_HEIGHT + 0.06 if on_wall else 0.06)


static func mark_material(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func place_camera() -> void:
	if not is_instance_valid(host._cam):
		return
	var at := Vector3(cos(host._yaw) * cos(host._pitch), sin(host._pitch), sin(host._yaw) * cos(host._pitch)) * host._span
	host._cam.position = at
	host._cam.look_at(Vector3.ZERO)
	host._cam_light.transform = host._cam.transform


func update_camera(dt: float) -> void:
	if not host.in_3d:
		return
	# The arrows or the right stick turn it round and tilt it (the left one
	# moves the cursor).
	var turn := Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	for pad in Input.get_connected_joypads():
		var r := Vector2(Input.get_joy_axis(pad, JOY_AXIS_RIGHT_X), Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y))
		if r.length() > 0.25:
			turn += r
	if turn != Vector2.ZERO:
		host._yaw += turn.x * dt * 1.5
		host._pitch = clampf(host._pitch - turn.y * dt * 1.0, 0.25, 1.45)
		place_camera()


