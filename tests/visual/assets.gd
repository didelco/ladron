extends Node3D
## The modelled pieces (art/*.blend -> assets/models/*.glb) side by side, in
## the game's toon shading and night light, turning slowly, and a row of
## paintings, one of each subject. Run it from the editor, or take a picture:
##   godot --write-movie out.png --fixed-fps 30 --quit-after 2 tests/visual/assets.tscn

const GAP := 1.25
var turntable: Array[Node3D] = []


func _ready() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#0f0d14")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8e96c8")
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55, 30, 0)
	key.light_energy = 1.3
	key.shadow_enabled = true
	add_child(key)

	var view := MuseumView.new()
	add_child(view)
	var pieces: Array[Callable] = [
		func(p: Node3D) -> void: view._vitrine(p, view._butterflies(3)),
		func(p: Node3D) -> void: view._vitrine(p, view._minerals(5)),
		func(p: Node3D) -> void: view._vitrine(p, view._ammonite()),
		func(p: Node3D) -> void: view._vitrine(p, view._rock()),
		func(p: Node3D) -> void: p.add_child(PropsView.model("bin")),
		func(p: Node3D) -> void: p.add_child(PropsView.model("panel")),
		func(p: Node3D) -> void: p.add_child(PropsView.model("armour")),
	]
	for name in PropsView.ON_PEDESTALS:
		pieces.append(func(p: Node3D) -> void:
			var look := Node3D.new()
			look.scale = Vector3.ONE * PropsView.K
			p.add_child(look)
			look.add_child(MuseumView.asset("pedestal"))
			var top := MuseumView.asset(name)
			top.position.y = 0.72
			look.add_child(top))
	pieces.append_array([
		func(p: Node3D) -> void:
			view._plinth(p, MuseumView.CASE_HEIGHT - 0.16, 0.64)
			view._skull(p, 0.0),
		func(p: Node3D) -> void:
			view._plinth(p, MuseumView.CASE_HEIGHT - 0.16, 0.64)
			view._skull(p, 0.0, true),
		func(p: Node3D) -> void:
			view._plinth(p, 0.42, 0.6)
			view._amphora(p, 0.42),
		func(p: Node3D) -> void: view._globe(p),
		func(p: Node3D) -> void: view._totem(p),
		func(p: Node3D) -> void:
			view._plinth(p, 0.3, 0.98)
			var bear := MuseumView.asset("oso")
			bear.position.y = 0.3
			p.add_child(bear),
		func(p: Node3D) -> void: view._diorama(p, 7),
	])
	var cols := 7
	for i in pieces.size():
		var p := Node3D.new()
		p.position = Vector3((i % cols - (cols - 1) / 2.0) * GAP, 0, (i / cols) * GAP * 1.3)
		add_child(p)
		pieces[i].call(p)
		turntable.append(p)
	# One painting of each subject, hung on a strip of wall behind.
	var found := {}
	var seed := 0
	while found.size() < 6 and seed < 2000:
		var kind := int(MuseumView._hash01(seed, 1, 71) * 6)
		if not found.has(kind):
			found[kind] = seed
		seed += 1
	var wall := MeshInstance3D.new()
	wall.mesh = MuseumView._box(Vector3(9.0, 1.4, 0.2))
	wall.material_override = MuseumView.toon(Color("#211d29"))
	wall.position = Vector3(0, 0.7, -1.3)
	add_child(wall)
	var k := 0
	for kind in found:
		var frame := Node3D.new()
		frame.position = Vector3((k - 2.5) * 1.1, 0, -1.2)
		add_child(frame)
		view._painting(frame, found[kind])
		k += 1
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	floor.mesh = plane
	floor.material_override = MuseumView.toon(Color("#2b2834"))
	add_child(floor)
	var cam := Camera3D.new()
	cam.fov = 42
	cam.position = Vector3(0, 6.0, 7.6)
	add_child(cam)
	cam.look_at(Vector3(0, 0.3, 0.9))


func _process(dt: float) -> void:
	for p in turntable:
		p.rotation.y += dt * 0.4
