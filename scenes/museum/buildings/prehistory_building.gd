class_name PrehistoryBuilding
extends RefCounted
## Constructor del museo de prehistoria: fachada, ventanas y esculturas de dinosaurios.
## MuseumBuilding conserva los recursos comunes, ventanas y estado de selección.
## Este componente añade nodos al mismo edificio y conserva el orden de su RNG.

var host: MuseumBuilding

func _init(building: MuseumBuilding) -> void:
	host = building

## The prehistory museum: a classical building of three floors in warm
## sandstone, bands between the floors, a cornice and a parapet; its middle
## standing out, and before it a portico of four columns two floors high
## under a pediment, a flight of steps up to it. In front, a square of
## granite flags with a dinosaur in pale stone on a plinth each side of the
## steps. Its windows plain ones with glazing bars, some lit, on its front
## down both its sides and across its back; the rooms' are some of them
## (P_ROOMS, one on each wall), the big
## job's the big one over the door, between the columns. A room not reached
## yet is just a window like the rest.
func build(rooms: Array) -> void:
	var wall := host._shade(MuseumBuilding.SANDSTONE)
	var trim := host._shade(MuseumBuilding.SANDSTONE_DARK)
	var stone := host._shade(MuseumBuilding.STONE)
	var accent := host._shade(host._colour)
	var roof_y := MuseumBuilding.P_BASE + MuseumBuilding.P_FLOOR * MuseumBuilding.P_FLOORS
	var porch_top := MuseumBuilding.P_BASE + MuseumBuilding.P_FLOOR * 2.0
	host.front_z = MuseumBuilding.P_PORCH
	host.look_y = MuseumBuilding.P_BASE + MuseumBuilding.P_FLOOR * 1.4
	host.top = roof_y + 1.3
	var rng := RandomNumberGenerator.new()
	rng.seed = 4021 + host.museum
	# The square before it, and the building's basement, walls and bands.
	host._square(Vector3(0, 0, MuseumBuilding.P_SQUARE * 0.5), Vector2(MuseumBuilding.P_W + 0.5, MuseumBuilding.P_SQUARE), rng)
	host._box(Vector3(MuseumBuilding.P_W + 0.16, MuseumBuilding.P_BASE, MuseumBuilding.P_D + 0.16), trim, Vector3(0, MuseumBuilding.P_BASE * 0.5, -MuseumBuilding.P_D * 0.5))
	host._box(Vector3(MuseumBuilding.P_W, roof_y - MuseumBuilding.P_BASE, MuseumBuilding.P_D), wall, Vector3(0, (roof_y + MuseumBuilding.P_BASE) * 0.5, -MuseumBuilding.P_D * 0.5))
	for f in range(1, MuseumBuilding.P_FLOORS):
		host._box(Vector3(MuseumBuilding.P_W + 0.06, 0.06, MuseumBuilding.P_D + 0.06), stone, Vector3(0, MuseumBuilding.P_BASE + f * MuseumBuilding.P_FLOOR, -MuseumBuilding.P_D * 0.5))
	host._box(Vector3(MuseumBuilding.P_W + 0.24, 0.14, MuseumBuilding.P_D + 0.24), stone, Vector3(0, roof_y + 0.07, -MuseumBuilding.P_D * 0.5))
	host._box(Vector3(MuseumBuilding.P_W - 0.1, 0.2, MuseumBuilding.P_D - 0.1), trim, Vector3(0, roof_y + 0.24, -MuseumBuilding.P_D * 0.5))
	# A gabled roof, its ridge along the front (the long side): it slopes
	# down to the front and the back, and shows its triangular end at
	# each side.
	var roof_rise := 0.5
	var roof_over := 0.18
	var roof_prism := PrismMesh.new()
	roof_prism.size = Vector3(MuseumBuilding.P_D + roof_over * 2.0, roof_rise, MuseumBuilding.P_W + roof_over * 2.0)
	roof_prism.left_to_right = 0.5
	var roof := host._mesh(roof_prism, trim.darkened(0.1), Vector3(0, roof_y + 0.34 + roof_rise * 0.5, -MuseumBuilding.P_D * 0.5))
	roof.rotation.y = PI / 2.0
	# The pilasters on the corners, seen from the front, the back and the
	# sides.
	for sx in [-1, 1]:
		for z in [0.02, -MuseumBuilding.P_D - 0.02]:
			host._box(Vector3(0.16, roof_y - MuseumBuilding.P_BASE, 0.06), stone, Vector3(sx * (MuseumBuilding.P_W * 0.5 - 0.08), (roof_y + MuseumBuilding.P_BASE) * 0.5, z))
		for z in [-0.08, -MuseumBuilding.P_D + 0.08]:
			host._box(Vector3(0.06, roof_y - MuseumBuilding.P_BASE, 0.16), stone, Vector3(sx * (MuseumBuilding.P_W * 0.5 + 0.02), (roof_y + MuseumBuilding.P_BASE) * 0.5, z))
	# Its middle standing out, the full height.
	host._box(Vector3(2.3, roof_y - MuseumBuilding.P_BASE, 0.1), wall.lightened(0.05), Vector3(0, (roof_y + MuseumBuilding.P_BASE) * 0.5, 0.05))
	# The portico: its floor, the steps down to the square, the columns, the
	# beam over them with the museum's name, the pediment.
	host._box(Vector3(2.5, MuseumBuilding.P_BASE, MuseumBuilding.P_PORCH + 0.1), trim, Vector3(0, MuseumBuilding.P_BASE * 0.5, (MuseumBuilding.P_PORCH + 0.1) * 0.5))
	for k in range(1, 6):
		var h := MuseumBuilding.P_BASE * (6 - k) / 6.0
		host._box(Vector3(2.5 + k * 0.14, h, 0.17), stone if k % 2 == 1 else trim.lightened(0.1), Vector3(0, h * 0.5, MuseumBuilding.P_PORCH + 0.1 + (k - 0.5) * 0.17))
	for x in MuseumBuilding.P_COLUMNS_X:
		var col := CylinderMesh.new()
		col.top_radius = 0.075
		col.bottom_radius = 0.09
		col.height = porch_top - MuseumBuilding.P_BASE - 0.16
		col.radial_segments = 12
		host._mesh(col, stone, Vector3(x, (porch_top + MuseumBuilding.P_BASE) * 0.5, MuseumBuilding.P_PORCH - 0.08))
		host._box(Vector3(0.24, 0.08, 0.24), stone, Vector3(x, MuseumBuilding.P_BASE + 0.04, MuseumBuilding.P_PORCH - 0.08))
		host._box(Vector3(0.26, 0.08, 0.26), stone, Vector3(x, porch_top - 0.04, MuseumBuilding.P_PORCH - 0.08))
	# The entablature: a cornice standing proud of the tympanum along the
	# base and both raking (sloped) sides; the tympanum itself set back
	# behind it, not flush.
	var corn_d := MuseumBuilding.P_PORCH + 0.16
	host._box(Vector3(2.5, 0.05, corn_d), stone, Vector3(0, porch_top + 0.1, corn_d * 0.5 + 0.02))
	host._box(Vector3(2.52, 0.05, 0.04), accent, Vector3(0, porch_top + 0.04, MuseumBuilding.P_PORCH + 0.1))
	var ped_w := 2.1
	var ped_rise := 0.42
	var ped := PrismMesh.new()
	ped.size = Vector3(ped_w, ped_rise, MuseumBuilding.P_PORCH + 0.06)
	host._mesh(ped, stone, Vector3(0, porch_top + 0.13 + ped_rise * 0.5, (MuseumBuilding.P_PORCH + 0.06) * 0.5 + 0.02))
	var tym := PrismMesh.new()
	tym.size = Vector3(ped_w - 0.3, ped_rise - 0.16, 0.03)
	host._mesh(tym, accent, Vector3(0, porch_top + 0.13 + (ped_rise - 0.16) * 0.5 + 0.03, MuseumBuilding.P_PORCH + 0.08))
	var slope_len := Vector2(ped_w * 0.5, ped_rise).length()
	var slope_angle := atan2(ped_rise, ped_w * 0.5)
	for sx in [-1, 1]:
		var raking := host._box(Vector3(slope_len + 0.16, 0.06, corn_d), stone,
			Vector3(sx * ped_w * 0.25, porch_top + 0.13 + ped_rise * 0.5, corn_d * 0.5 + 0.02))
		raking.rotation.z = -sx * slope_angle
	# The door, lit round its edge when open.
	host._box(Vector3(0.5, 0.62, 0.05), MuseumBuilding.WOOD.darkened(0.0 if host.open else 0.4), Vector3(0, MuseumBuilding.P_BASE + 0.31, 0.12))
	if host.open:
		host._glow(Vector3(0.58, 0.04, 0.03), MuseumBuilding.LIT, Vector3(0, MuseumBuilding.P_BASE + 0.64, 0.13), 1.5)
	# A banner in its colour down each wing, a flag on the roof.
	for sx in [-1, 1]:
		host._box(Vector3(0.18, 1.1, 0.02), accent, Vector3(sx * 1.75, MuseumBuilding.P_BASE + MuseumBuilding.P_FLOOR * 2.3, 0.02))
		host._box(Vector3(0.18, 0.06, 0.025), MuseumBuilding.GOLD.darkened(0.0 if host.open else MuseumBuilding.SHUT), Vector3(sx * 1.75, MuseumBuilding.P_BASE + MuseumBuilding.P_FLOOR * 2.3 - 0.52, 0.025))
	host._box(Vector3(0.03, 0.8, 0.03), MuseumBuilding.POLE, Vector3(0, roof_y + 0.7, -0.4))
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0, roof_y + 0.95, -0.4)
	host.add_child(flag)
	host._box_in(flag, Vector3(0.45, 0.26, 0.02), host._colour if host.open else accent, Vector3(0.225, 0, 0))
	# The plain windows of the wings, three floors of them, down both sides
	# and across the back, lit here and there; but where a room is (it has
	# its own).
	var taken := {}
	for s in MuseumBuilding.P_ROOMS:
		taken[window_key(s.side, s.across, s.floor)] = true
	for f in MuseumBuilding.P_FLOORS:
		for x in MuseumBuilding.P_WINGS_X:
			if not taken.has(window_key(0, x, f)):
				plain_window(window_position(0, x, f), MuseumBuilding.P_WINDOW, host.open and rng.randf() < 0.35, window_rotation(0))
		for side in [-1, 1]:
			for z in MuseumBuilding.P_SIDE_Z:
				if not taken.has(window_key(side, z, f)):
					plain_window(window_position(side, z, f), MuseumBuilding.P_SIDE_WINDOW, host.open and rng.randf() < 0.35, window_rotation(side))
		for x in MuseumBuilding.P_BACK_X:
			if not taken.has(window_key(2, x, f)):
				plain_window(window_position(2, x, f), MuseumBuilding.P_WINDOW, host.open and rng.randf() < 0.35, window_rotation(2))
	# The lamps on the square, each side of the steps.
	for sx in [-1, 1]:
		var post := CylinderMesh.new()
		post.top_radius = 0.025
		post.bottom_radius = 0.035
		post.height = 0.75
		host._mesh(post, Color("#2a2433"), Vector3(sx * 1.55, 0.375, MuseumBuilding.P_PORCH + 0.55))
		var head := SphereMesh.new()
		head.radius = 0.08
		head.height = 0.16
		var lamp := host._mesh(head, MuseumBuilding.LIT, Vector3(sx * 1.55, 0.8, MuseumBuilding.P_PORCH + 0.55))
		if host.open:
			lamp.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT, 3.0)
	# The dinosaurs on their plinths (real models, Gobkit's pack): a trex on
	# the left, a triceratops on the right, both turned a little to the steps.
	for sx in [-1, 1]:
		var at := Vector3(sx * 1.75, 0, MuseumBuilding.P_SQUARE - 0.75)
		host._box(Vector3(0.62, 0.34, 0.8), host._shade(MuseumBuilding.GRANITE[2]), at + Vector3(0, 0.17, 0))
		host._box(Vector3(0.7, 0.05, 0.88), host._shade(MuseumBuilding.GRANITE_EDGE), at + Vector3(0, 0.36, 0))
		var dino := Node3D.new()
		dino.position = at + Vector3(0, 0.38, 0)
		dino.rotation.y = -sx * 0.45
		dino.scale = Vector3.ONE * 1.35
		host.add_child(dino)
		if sx < 0:
			dinosaur_model(dino, "trex", 0.95)
		else:
			dinosaur_model(dino, "triceratops", 0.6)
	# The rooms: some of the wings' windows and the side's (P_ROOMS), the big
	# job's over the door. Only one reached shows as a room: its window lit up
	# warm and bright, no bars across it and nothing in it (and the crown on
	# the pediment for the big job's); the rest are windows like any other,
	# bars and all, dim if lit, and nothing to pick.
	var boss_at := Vector3(0.0, MuseumBuilding.P_BASE + MuseumBuilding.P_FLOOR * 1.5, 0.1)
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var at := boss_at
		var turn := 0.0
		var size := MuseumBuilding.P_BIG
		if not r.boss:
			var s: Dictionary = MuseumBuilding.P_ROOMS[mini(normal, MuseumBuilding.P_ROOMS.size() - 1)]
			normal += 1
			at = window_position(s.side, s.across, s.floor)
			turn = window_rotation(s.side)
			size = MuseumBuilding.P_SIDE_WINDOW if absi(s.side) == 1 else MuseumBuilding.P_WINDOW
		var shown: bool = host.open and r.has("shape") and bool(r.get("open", false))
		var w := host._plain(at, size, true, false, turn) if shown else plain_window(at, size, host.open and rng.randf() < 0.35, turn)
		var node: Node3D = w.node
		# Nothing in it: the piece's place, kept empty.
		var piece := Node3D.new()
		piece.position = Vector3(0, -size.y * 0.18, 0.1)
		node.add_child(piece)
		if shown and r.boss:
			# The big job's crown, on the pediment's top.
			var crown := Node3D.new()
			crown.position = Vector3(0, porch_top + 0.78 - at.y, 0.35 - at.z)
			node.add_child(crown)
			CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD, 1.3)
		host.windows.append({"node": node, "back": w.glass, "glass": w.glass, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": size, "frame": w.frame, "stone": w.stone, "arch": false, "face": node.basis})


## Where a window of the prehistory museum is: on its front (side 0, across
## its x), down a side (-1 left, 1 right, across its z, back from the front)
## or on its back (side 2, across its x), on floor f (0 the ground one): its
## middle, and its turn to face out of its wall.
func window_position(side: int, across: float, f: int) -> Vector3:
	var y := MuseumBuilding.P_BASE + MuseumBuilding.P_FLOOR * (f + 0.5)
	if side == 0:
		return Vector3(across, y, 0.0)
	if side == 2:
		return Vector3(across, y, -MuseumBuilding.P_D)
	return Vector3(side * MuseumBuilding.P_W * 0.5, y, across)


func window_rotation(side: int) -> float:
	return side * PI * 0.5


func window_key(side: int, across: float, f: int) -> String:
	return "%d:%.2f:%d" % [side, across, f]


## A window of the prehistory museum that is not a room: bars and all, and
## if lit, only dimly (P_DIM). As _plain.
func plain_window(at: Vector3, size: Vector2, lit: bool, turn: float) -> Dictionary:
	var w := host._plain(at, size, lit, true, turn)
	if lit:
		(w.glass as MeshInstance3D).material_override = MuseumBuilding._lit_material(MuseumBuilding.P_DIM, MuseumBuilding.P_DIM_ENERGY)
	return w


## A real dinosaur model (art/dinosaurios_gobkit.blend, PROCEDENCIA.json
## gobkit-dino-pack) standing on its plinth, its own colour, scaled to the
## museum's compressed scale, at its rig's rest pose (no animation played).
func dinosaur_model(at: Node3D, name: String, tall: float) -> void:
	var model := MuseumView.asset("dinosaurios/%s" % name)
	var low := INF
	var high := -INF
	for p in host._points_of(model):
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var s := tall / maxf(high - low, 0.001)
	model.position = Vector3(0, -low * s, 0)
	model.scale = Vector3.ONE * s
	at.add_child(model)
	var stone := MenuStage._material(host._shade(MuseumBuilding.SCULPTURE))
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = stone
