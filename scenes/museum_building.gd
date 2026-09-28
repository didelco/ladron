class_name MuseumBuilding
extends Node3D
## A museum of the story as a building in the town (CityStage), bigger
## than anything round it, each its own (by its theme): the prehistory
## museum a classical building of three floors behind a granite square
## (_prehistory); the rest, for now, one plain classical hall with a dome
## in its own colour (_hall).
##
## Its five rooms are windows (windows, in the rooms' order), the big job's
## always the big one in the middle of its front. Only a room reached shows
## as one: lit warm, its piece on show in it (and the big job's crown). In
## the prehistory museum, one not reached yet is just another of its many
## windows (on its front and its sides), dark or lit like the rest; in the
## hall, where every window is a room, it is dark with a padlock. Picking
## one (pick) lights it up (CityStage draws the ring).
##
## Built facing +z, its middle on the ground at its origin; x across. Each
## window faces its own way (face: out of its wall along its +z).

## Its size: across, deep, and the walls' height over the plinth.
const W := 5.4
const D := 3.2
const H := 1.9
const PLINTH := 0.3
## The windows: across, tall, where their middles are; the big job's.
const WINDOW := Vector2(0.52, 0.95)
const WINDOW_Y := PLINTH + 1.0
const WINDOWS_X := [-2.1, -1.2, 1.2, 2.1]
const BIG_WINDOW := Vector2(0.8, 1.05)
const BIG_WINDOW_Y := PLINTH + 1.3
const COLUMNS_X := [-2.6, -1.65, -0.72, 0.72, 1.65, 2.6]
const DOME_R := 0.8

## The building's own colours: all here, to change in one place.
const STONE := Color("#e8dcc4")
const STONE_DARK := Color("#b9a98e")
const WOOD := Color("#4a2f22")
const GLASS_DARK := Color("#1a1530")
const LIT := Color("#ffd28a")
const LIT_PICKED := Color("#fff0c0")
const GOLD := Color("#e8b84a")
const POLE := Color("#8a7a6a")
## The prehistory museum: across, deep (behind its front, at z 0), its
## basement, a floor's height and how many; its windows (a room's, the big
## job's); where the wings' windows are across, and the portico's columns;
## how far the portico stands out; how deep the square before it.
const P_W := 5.0
const P_D := 2.6
const P_BASE := 0.3
const P_FLOOR := 0.8
const P_FLOORS := 3
const P_WINDOW := Vector2(0.34, 0.5)
const P_BIG := Vector2(0.46, 0.62)
const P_WINGS_X := [-2.05, -1.45, 1.45, 2.05]
## The windows down each side, where they are back from the front (z), and
## a little wider than the front's: the camera sees the side askew.
const P_SIDE_Z := [-0.62, -1.3, -1.98]
const P_SIDE_WINDOW := Vector2(0.42, 0.5)
## Where the rooms but the big job's are, in the rooms' order: on the front
## (side 0, across: x) or on the side the camera sees (side 1, +x; across:
## z), and on which floor. Spread over both and all three floors; any room
## past these, in the last.
const P_ROOMS := [
	{"side": 0, "across": -2.05, "floor": 1},
	{"side": 0, "across": 1.45, "floor": 2},
	{"side": 1, "across": -0.62, "floor": 1},
	{"side": 1, "across": -1.98, "floor": 2},
]
const P_COLUMNS_X := [-0.95, -0.47, 0.47, 0.95]
const P_PORCH := 0.62
const P_SQUARE := 2.8
const SANDSTONE := Color("#e6d2a8")
const SANDSTONE_DARK := Color("#b89c72")
const GRANITE := [Color("#8e8a95"), Color("#a3a0aa"), Color("#7a7683"), Color("#96919c")]
const GRANITE_EDGE := Color("#5f5b68")
const SCULPTURE := Color("#d8c9a8")
const SCULPTURE_DARK := Color("#a8977a")
## How dark a shut museum is.
const SHUT := 0.62

var museum := 0
var open := true
## each room's window: {"node" (its middle), "glass", "back", "piece",
## "lock", "boss", "open" (shown as a room: reached, lit, its piece in it),
## "size", "frame", "stone", "arch", "face" (which way it looks, in the
## building: its +z out of the wall)}, in the rooms' own order
var windows: Array[Dictionary] = []
var _colour: Color
var _t := 0.0
var picked := -1
## Where its front is (z), how high the camera looks at it from close, and
## how high it all stands (the sign and the padlock go over it): its style's.
var front_z := D * 0.5
var look_y := PLINTH + H * 0.8
var top := PLINTH + H + 0.6 + DOME_R * 0.8 + 0.9


## Museum m, open or shut; rooms, when looked at up close, as the tour has
## them ({"n", "boss", "open", "shape", "colour"}): their pieces in their
## windows. Without them, the windows are just lit (open) or dark.
func build(m: int, is_open: bool, rooms: Array = []) -> void:
	museum = m
	open = is_open
	for c in get_children():
		c.queue_free()
	windows.clear()
	_colour = Color(Story.MUSEUMS[m].colour)
	match String(Story.MUSEUMS[m].theme):
		"prehistoria":
			_prehistory(rooms)
		_:
			_hall(rooms)


## The plain hall: on a stone plinth, steps up to its door, a row of
## columns across its front under a cornice, a pediment over the middle and
## a dome behind it; a banner in its colour at each end, a flag on the
## dome, a lamp each side of the steps. Its rooms in tall arched windows.
func _hall(rooms: Array) -> void:
	front_z = D * 0.5
	look_y = PLINTH + H * 0.8
	top = PLINTH + H + 0.6 + DOME_R * 0.8 + 0.9
	var m := museum
	var wall := _colour.lerp(Color("#f6ecff"), 0.42)
	var deep := _colour.darkened(0.25)
	var stone := STONE
	var stone_dark := STONE_DARK
	if not open:
		wall = wall.darkened(SHUT)
		deep = deep.darkened(SHUT)
		stone = stone.darkened(SHUT)
		stone_dark = stone_dark.darkened(SHUT)
	# The plinth and the steps up to the door.
	_box(Vector3(W + 0.3, PLINTH, D + 0.3), stone_dark, Vector3(0, PLINTH * 0.5, 0))
	for k in 3:
		_box(Vector3(2.2 - k * 0.2, PLINTH * (k + 1) / 3.0, 0.22), stone, Vector3(0, PLINTH * (k + 1) / 6.0, D * 0.5 + 0.15 + (2 - k) * 0.2 + 0.1))
	# The walls, the cornice and the roof.
	_box(Vector3(W, H, D), wall, Vector3(0, PLINTH + H * 0.5, 0))
	_box(Vector3(W + 0.22, 0.18, D + 0.22), stone, Vector3(0, PLINTH + H + 0.09, 0))
	_box(Vector3(W - 0.3, 0.14, D - 0.3), stone_dark, Vector3(0, PLINTH + H + 0.25, 0))
	# The columns across the front, the frieze over them.
	for x in COLUMNS_X:
		var col := CylinderMesh.new()
		col.top_radius = 0.085
		col.bottom_radius = 0.1
		col.height = H - 0.1
		_mesh(col, stone, Vector3(x, PLINTH + (H - 0.1) * 0.5, D * 0.5 + 0.16))
		_box(Vector3(0.28, 0.08, 0.28), stone, Vector3(x, PLINTH + 0.04, D * 0.5 + 0.16))
		_box(Vector3(0.28, 0.08, 0.28), stone, Vector3(x, PLINTH + H - 0.12, D * 0.5 + 0.16))
	_box(Vector3(W + 0.1, 0.2, 0.36), stone, Vector3(0, PLINTH + H - 0.02, D * 0.5 + 0.13))
	_box(Vector3(W + 0.1, 0.06, 0.37), deep, Vector3(0, PLINTH + H - 0.02, D * 0.5 + 0.13))
	# The pediment over the middle.
	var ped := PrismMesh.new()
	ped.size = Vector3(1.9, 0.55, 0.4)
	_mesh(ped, stone, Vector3(0, PLINTH + H + 0.36, D * 0.5 + 0.1))
	var tym := PrismMesh.new()
	tym.size = Vector3(1.45, 0.36, 0.05)
	_mesh(tym, deep, Vector3(0, PLINTH + H + 0.3, D * 0.5 + 0.31))
	# The dome behind it, a lantern and a flag on top.
	var drum := CylinderMesh.new()
	drum.top_radius = DOME_R * 0.92
	drum.bottom_radius = DOME_R * 0.92
	drum.height = 0.3
	_mesh(drum, stone, Vector3(0, PLINTH + H + 0.45, -0.25))
	var dome := SphereMesh.new()
	dome.radius = DOME_R
	dome.height = DOME_R * 1.6
	dome.is_hemisphere = true
	_mesh(dome, deep, Vector3(0, PLINTH + H + 0.6, -0.25))
	_box(Vector3(0.03, 0.7, 0.03), POLE, Vector3(0, PLINTH + H + 0.6 + DOME_R * 0.8 + 0.35, -0.25))
	var flag := _box(Vector3(0.45, 0.26, 0.02), _colour if open else deep, Vector3(0.24, PLINTH + H + 0.6 + DOME_R * 0.8 + 0.55, -0.25))
	flag.name = "Flag"
	# A banner in its colour at each end, gold along its foot.
	for s in [-1, 1]:
		_box(Vector3(0.36, 0.95, 0.03), _colour if open else deep, Vector3(s * 2.6, PLINTH + H - 0.62, D * 0.5 + 0.3))
		_box(Vector3(0.36, 0.08, 0.035), GOLD.darkened(0.0 if open else SHUT), Vector3(s * 2.6, PLINTH + H - 1.08, D * 0.5 + 0.3))
		_box(Vector3(0.42, 0.04, 0.05), POLE, Vector3(s * 2.6, PLINTH + H - 0.12, D * 0.5 + 0.3))
	# Its name over the columns.
	var sign := Label3D.new()
	sign.text = String(Story.museum(m).name).to_upper()
	sign.font_size = 48
	sign.pixel_size = 0.0028
	sign.outline_size = 0
	sign.modulate = WOOD if open else WOOD.lightened(0.2)
	sign.position = Vector3(0, PLINTH + H - 0.07, D * 0.5 + 0.33)
	sign.width = W * 300.0
	add_child(sign)
	# The door, lit round its edge when open.
	_box(Vector3(0.62, 0.62, 0.05), WOOD.darkened(0.0 if open else 0.4), Vector3(0, PLINTH + 0.31, D * 0.5 + 0.02))
	if open:
		_glow(Vector3(0.7, 0.04, 0.03), LIT, Vector3(0, PLINTH + 0.64, D * 0.5 + 0.03), 1.5)
	# A lamp each side of the steps.
	for s in [-1, 1]:
		var post := CylinderMesh.new()
		post.top_radius = 0.025
		post.bottom_radius = 0.035
		post.height = 0.75
		_mesh(post, Color("#2a2433"), Vector3(s * 1.35, 0.375, D * 0.5 + 0.75))
		var head := SphereMesh.new()
		head.radius = 0.08
		head.height = 0.16
		var lamp := _mesh(head, LIT, Vector3(s * 1.35, 0.8, D * 0.5 + 0.75))
		if open:
			lamp.material_override = _lit_material(LIT, 3.0)
	# The rooms' windows.
	_windows(rooms)


## Each room's window on the front: four in the wings, the big job's tall
## one in the middle. In each, a lit back wall and its piece (or a dark
## one and a padlock), under glass.
func _windows(rooms: Array) -> void:
	var slots: Array = []
	for x in WINDOWS_X:
		slots.append({"x": x, "y": WINDOW_Y, "size": WINDOW, "boss": false})
	var boss_slot := {"x": 0.0, "y": BIG_WINDOW_Y, "size": BIG_WINDOW, "boss": true}
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else 5
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == 4, "open": open}
		var slot: Dictionary = boss_slot if r.boss else slots[mini(normal, slots.size() - 1)]
		if not r.boss:
			normal += 1
		var size: Vector2 = slot.size
		var node := Node3D.new()
		node.position = Vector3(slot.x, slot.y, D * 0.5)
		add_child(node)
		var lit: bool = open and bool(r.get("open", open))
		# The frame, the niche's lit back, an arch over it.
		var frame := _box_in(node, Vector3(size.x + 0.12, size.y + 0.12, 0.05), STONE if open else STONE.darkened(SHUT), Vector3(0, 0, 0.005))
		var back := _box_in(node, Vector3(size.x, size.y, 0.04), GLASS_DARK, Vector3(0, 0, 0.02))
		if lit:
			back.material_override = _lit_material(LIT, 0.9)
		var arch := CylinderMesh.new()
		arch.top_radius = size.x * 0.5 + 0.06
		arch.bottom_radius = size.x * 0.5 + 0.06
		arch.height = 0.05
		var a := _mesh_in(node, arch, STONE if open else STONE.darkened(SHUT), Vector3(0, size.y * 0.5, 0.005))
		var stone_look := a.material_override
		a.rotation_degrees.x = 90
		var arch_glass := CylinderMesh.new()
		arch_glass.top_radius = size.x * 0.5
		arch_glass.bottom_radius = size.x * 0.5
		arch_glass.height = 0.04
		var ag := _mesh_in(node, arch_glass, GLASS_DARK, Vector3(0, size.y * 0.5, 0.02))
		ag.rotation_degrees.x = 90
		if lit:
			ag.material_override = back.material_override
		# The sill.
		_box_in(node, Vector3(size.x + 0.2, 0.06, 0.14), STONE if open else STONE.darkened(SHUT), Vector3(0, -size.y * 0.5 - 0.04, 0.06))
		var piece := Node3D.new()
		piece.position = Vector3(0, -size.y * 0.18, 0.16)
		node.add_child(piece)
		var lock: Node3D = null
		if r.has("shape") and lit:
			var model := LootModels.build(r.shape, Color(r.colour))
			model.scale = Vector3.ONE * (0.66 if r.boss else 0.5)
			piece.add_child(model)
		elif r.has("shape"):
			lock = CityStage.padlock()
			lock.scale = Vector3.ONE * 0.3
			lock.position = Vector3(0, 0.05, 0.12)
			node.add_child(lock)
		if r.boss and r.has("shape"):
			# The big job's crown, over its window on the dome.
			var crown := Node3D.new()
			crown.position = Vector3(0, PLINTH + H + 0.6 + DOME_R * 0.8 + 0.1 - slot.y, -0.25 - D * 0.5)
			node.add_child(crown)
			CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD if lit else MenuStage.GOLD.darkened(0.6), 1.6)
		windows.append({"node": node, "back": back, "glass": ag, "piece": piece, "lock": lock, "boss": r.boss, "open": lit, "size": size,
			"frame": [frame, a], "stone": stone_look, "arch": true, "face": node.basis})


## The prehistory museum: a classical building of three floors in warm
## sandstone, bands between the floors, a cornice and a parapet; its middle
## standing out, and before it a portico of four columns two floors high
## under a pediment, a flight of steps up to it. In front, a square of
## granite flags with a dinosaur in pale stone on a plinth each side of the
## steps. Its windows plain ones with glazing bars, some lit, on its front
## and down both its sides; the rooms' are some of them (P_ROOMS), the big
## job's the big one over the door, between the columns. A room not reached
## yet is just a window like the rest.
func _prehistory(rooms: Array) -> void:
	var wall := _shade(SANDSTONE)
	var trim := _shade(SANDSTONE_DARK)
	var stone := _shade(STONE)
	var accent := _shade(_colour)
	var roof_y := P_BASE + P_FLOOR * P_FLOORS
	var porch_top := P_BASE + P_FLOOR * 2.0
	front_z = P_PORCH
	look_y = P_BASE + P_FLOOR * 1.4
	top = roof_y + 1.3
	var rng := RandomNumberGenerator.new()
	rng.seed = 4021 + museum
	# The square before it, and the building's basement, walls and bands.
	_square(Vector3(0, 0, P_SQUARE * 0.5), Vector2(P_W + 0.5, P_SQUARE), rng)
	_box(Vector3(P_W + 0.16, P_BASE, P_D + 0.16), trim, Vector3(0, P_BASE * 0.5, -P_D * 0.5))
	_box(Vector3(P_W, roof_y - P_BASE, P_D), wall, Vector3(0, (roof_y + P_BASE) * 0.5, -P_D * 0.5))
	for f in range(1, P_FLOORS):
		_box(Vector3(P_W + 0.06, 0.06, P_D + 0.06), stone, Vector3(0, P_BASE + f * P_FLOOR, -P_D * 0.5))
	_box(Vector3(P_W + 0.24, 0.14, P_D + 0.24), stone, Vector3(0, roof_y + 0.07, -P_D * 0.5))
	_box(Vector3(P_W - 0.1, 0.2, P_D - 0.1), trim, Vector3(0, roof_y + 0.24, -P_D * 0.5))
	# The pilasters on the corners, seen from the front and from the sides.
	for sx in [-1, 1]:
		_box(Vector3(0.16, roof_y - P_BASE, 0.06), stone, Vector3(sx * (P_W * 0.5 - 0.08), (roof_y + P_BASE) * 0.5, 0.02))
		for z in [-0.08, -P_D + 0.08]:
			_box(Vector3(0.06, roof_y - P_BASE, 0.16), stone, Vector3(sx * (P_W * 0.5 + 0.02), (roof_y + P_BASE) * 0.5, z))
	# Its middle standing out, the full height.
	_box(Vector3(2.3, roof_y - P_BASE, 0.1), wall.lightened(0.05), Vector3(0, (roof_y + P_BASE) * 0.5, 0.05))
	# The portico: its floor, the steps down to the square, the columns, the
	# beam over them with the museum's name, the pediment.
	_box(Vector3(2.5, P_BASE, P_PORCH + 0.1), trim, Vector3(0, P_BASE * 0.5, (P_PORCH + 0.1) * 0.5))
	for k in range(1, 6):
		var h := P_BASE * (6 - k) / 6.0
		_box(Vector3(2.5 + k * 0.14, h, 0.17), stone if k % 2 == 1 else trim.lightened(0.1), Vector3(0, h * 0.5, P_PORCH + 0.1 + (k - 0.5) * 0.17))
	for x in P_COLUMNS_X:
		var col := CylinderMesh.new()
		col.top_radius = 0.075
		col.bottom_radius = 0.09
		col.height = porch_top - P_BASE - 0.16
		col.radial_segments = 12
		_mesh(col, stone, Vector3(x, (porch_top + P_BASE) * 0.5, P_PORCH - 0.08))
		_box(Vector3(0.24, 0.08, 0.24), stone, Vector3(x, P_BASE + 0.04, P_PORCH - 0.08))
		_box(Vector3(0.26, 0.08, 0.26), stone, Vector3(x, porch_top - 0.04, P_PORCH - 0.08))
	_box(Vector3(2.5, 0.2, P_PORCH + 0.08), stone, Vector3(0, porch_top + 0.1, (P_PORCH + 0.08) * 0.5 + 0.02))
	_box(Vector3(2.52, 0.05, 0.04), accent, Vector3(0, porch_top + 0.04, P_PORCH + 0.1))
	var ped := PrismMesh.new()
	ped.size = Vector3(2.6, 0.48, P_PORCH + 0.08)
	_mesh(ped, stone, Vector3(0, porch_top + 0.44, (P_PORCH + 0.08) * 0.5 + 0.02))
	var tym := PrismMesh.new()
	tym.size = Vector3(2.0, 0.3, 0.04)
	_mesh(tym, accent, Vector3(0, porch_top + 0.38, P_PORCH + 0.08))
	var sign := Label3D.new()
	sign.text = String(Story.museum(museum).name).to_upper()
	sign.font_size = 48
	sign.pixel_size = 0.0022
	sign.outline_size = 0
	sign.modulate = WOOD if open else WOOD.lightened(0.2)
	sign.position = Vector3(0, porch_top + 0.11, P_PORCH + 0.11)
	sign.width = 2.4 * 450.0
	add_child(sign)
	# The door, lit round its edge when open.
	_box(Vector3(0.5, 0.62, 0.05), WOOD.darkened(0.0 if open else 0.4), Vector3(0, P_BASE + 0.31, 0.12))
	if open:
		_glow(Vector3(0.58, 0.04, 0.03), LIT, Vector3(0, P_BASE + 0.64, 0.13), 1.5)
	# A banner in its colour down each wing, a flag on the roof.
	for sx in [-1, 1]:
		_box(Vector3(0.18, 1.1, 0.02), accent, Vector3(sx * 1.75, P_BASE + P_FLOOR * 2.3, 0.02))
		_box(Vector3(0.18, 0.06, 0.025), GOLD.darkened(0.0 if open else SHUT), Vector3(sx * 1.75, P_BASE + P_FLOOR * 2.3 - 0.52, 0.025))
	_box(Vector3(0.03, 0.8, 0.03), POLE, Vector3(0, roof_y + 0.7, -0.4))
	var flag := _box(Vector3(0.45, 0.26, 0.02), _colour if open else accent, Vector3(0.24, roof_y + 0.95, -0.4))
	flag.name = "Flag"
	# The plain windows of the wings, three floors of them, and down both
	# sides, lit here and there; but where a room is (it has its own).
	var taken := {}
	for s in P_ROOMS:
		taken[_slot_key(s.side, s.across, s.floor)] = true
	for f in P_FLOORS:
		for x in P_WINGS_X:
			if not taken.has(_slot_key(0, x, f)):
				_plain(_slot_at(0, x, f), P_WINDOW, open and rng.randf() < 0.35, true, _slot_turn(0))
		for side in [-1, 1]:
			for z in P_SIDE_Z:
				if not taken.has(_slot_key(side, z, f)):
					_plain(_slot_at(side, z, f), P_SIDE_WINDOW, open and rng.randf() < 0.35, true, _slot_turn(side))
	# The lamps on the square, each side of the steps.
	for sx in [-1, 1]:
		var post := CylinderMesh.new()
		post.top_radius = 0.025
		post.bottom_radius = 0.035
		post.height = 0.75
		_mesh(post, Color("#2a2433"), Vector3(sx * 1.55, 0.375, P_PORCH + 0.55))
		var head := SphereMesh.new()
		head.radius = 0.08
		head.height = 0.16
		var lamp := _mesh(head, LIT, Vector3(sx * 1.55, 0.8, P_PORCH + 0.55))
		if open:
			lamp.material_override = _lit_material(LIT, 3.0)
	# The dinosaurs on their plinths: a tyrannosaur on the left, a long neck
	# on the right, both turned a little to the steps.
	for sx in [-1, 1]:
		var at := Vector3(sx * 1.75, 0, P_SQUARE - 0.75)
		_box(Vector3(0.62, 0.34, 0.8), _shade(GRANITE[2]), at + Vector3(0, 0.17, 0))
		_box(Vector3(0.7, 0.05, 0.88), _shade(GRANITE_EDGE), at + Vector3(0, 0.36, 0))
		var dino := Node3D.new()
		dino.position = at + Vector3(0, 0.38, 0)
		dino.rotation.y = -sx * 0.45
		dino.scale = Vector3.ONE * 1.35
		add_child(dino)
		if sx < 0:
			_tyrannosaur(dino)
		else:
			_long_neck(dino)
	# The rooms: some of the wings' windows and the side's (P_ROOMS), the big
	# job's over the door. Only one reached shows as a room: lit, its piece in
	# it (and the crown on the pediment for the big job's); the rest are
	# windows like any other, bars and all, and nothing to pick.
	var boss_at := Vector3(0.0, P_BASE + P_FLOOR * 1.5, 0.1)
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var at := boss_at
		var turn := 0.0
		var size := P_BIG
		if not r.boss:
			var s: Dictionary = P_ROOMS[mini(normal, P_ROOMS.size() - 1)]
			normal += 1
			at = _slot_at(s.side, s.across, s.floor)
			turn = _slot_turn(s.side)
			size = P_WINDOW if s.side == 0 else P_SIDE_WINDOW
		var shown: bool = open and r.has("shape") and bool(r.get("open", false))
		var w := _plain(at, size, shown or (open and rng.randf() < 0.35), not shown, turn)
		var node: Node3D = w.node
		var piece := Node3D.new()
		piece.position = Vector3(0, -size.y * 0.18, 0.1)
		node.add_child(piece)
		if shown:
			var model := LootModels.build(r.shape, Color(r.colour))
			model.scale = Vector3.ONE * (0.4 if r.boss else 0.3)
			piece.add_child(model)
			if r.boss:
				# The big job's crown, on the pediment's top.
				var crown := Node3D.new()
				crown.position = Vector3(0, porch_top + 0.78 - at.y, 0.35 - at.z)
				node.add_child(crown)
				CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD, 1.3)
		windows.append({"node": node, "back": w.glass, "glass": w.glass, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": size, "frame": w.frame, "stone": w.stone, "arch": false, "face": node.basis})


## Where a window of the prehistory museum is: on its front (side 0, across
## its x) or down a side (-1 left, 1 right, across its z, back from the
## front), on floor f (0 the ground one): its middle, and its turn to face
## out of its wall.
func _slot_at(side: int, across: float, f: int) -> Vector3:
	var y := P_BASE + P_FLOOR * (f + 0.5)
	if side == 0:
		return Vector3(across, y, 0.0)
	return Vector3(side * P_W * 0.5, y, across)


func _slot_turn(side: int) -> float:
	return side * PI * 0.5


func _slot_key(side: int, across: float, f: int) -> String:
	return "%d:%.2f:%d" % [side, across, f]


## A plain window, its middle at `at` on a wall, turned `turn` round y from
## facing the front (+z): a stone surround, a lintel over it and a sill, the
## glass lit or dark, glazing bars (a cross) or, where a piece shows
## through, just the bar across its top. Returns {"node", "glass", "frame"
## (the surround's pieces), "stone" (their look)}.
func _plain(at: Vector3, size: Vector2, lit: bool, bars: bool, turn := 0.0) -> Dictionary:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = turn
	add_child(node)
	var stone := _shade(STONE)
	var frame: Array = []
	for sx in [-1, 1]:
		frame.append(_box_in(node, Vector3(0.05, size.y + 0.08, 0.05), stone, Vector3(sx * (size.x * 0.5 + 0.025), 0, 0.02)))
	frame.append(_box_in(node, Vector3(size.x + 0.16, 0.07, 0.07), stone, Vector3(0, size.y * 0.5 + 0.05, 0.03)))
	frame.append(_box_in(node, Vector3(size.x + 0.14, 0.05, 0.1), stone, Vector3(0, -size.y * 0.5 - 0.03, 0.045)))
	var glass := _box_in(node, Vector3(size.x, size.y, 0.03), GLASS_DARK, Vector3(0, 0, 0.012))
	if lit:
		glass.material_override = _lit_material(LIT, 0.55 if bars else 0.9)
	var bar := WOOD.lightened(0.15) if lit else GLASS_DARK.lightened(0.15)
	_box_in(node, Vector3(size.x, 0.025, 0.02), bar, Vector3(0, size.y * 0.22, 0.03))
	if bars:
		_box_in(node, Vector3(0.025, size.y, 0.02), bar, Vector3(0, 0, 0.03))
	return {"node": node, "glass": glass, "frame": frame, "stone": (frame[0] as MeshInstance3D).material_override}


## The square: granite flags in rows, each its own grey, on a darker kerb;
## one MultiMesh for all the flags.
func _square(centre: Vector3, size: Vector2, rng: RandomNumberGenerator) -> void:
	_box(Vector3(size.x + 0.12, 0.03, size.y + 0.06), _shade(GRANITE_EDGE), centre + Vector3(0, 0.015, 0))
	var flag := 0.44
	var nx := int(size.x / flag)
	var nz := int(size.y / flag)
	var tile := BoxMesh.new()
	tile.size = Vector3(flag - 0.03, 0.03, flag - 0.03)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tile
	mm.instance_count = nx * nz
	for i in nx:
		for j in nz:
			var at := centre + Vector3((i - (nx - 1) * 0.5) * flag, 0.035, (j - (nz - 1) * 0.5) * flag)
			mm.set_instance_transform(i * nz + j, Transform3D(Basis.IDENTITY, at))
			mm.set_instance_color(i * nz + j, _shade(GRANITE[rng.randi() % GRANITE.size()]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.35
	mmi.material_override = m
	add_child(mmi)


## A tyrannosaur in stone, roaring: a leaning body, a big head with its jaw
## open, a tail out behind, two strong legs and two silly little arms.
func _tyrannosaur(at: Node3D) -> void:
	var pale := _shade(SCULPTURE)
	var dark := _shade(SCULPTURE_DARK)
	var body := _mesh_in(at, _ball(0.2), pale, Vector3(0, 0.46, 0))
	body.scale = Vector3(1.0, 1.05, 1.5)
	body.rotation.x = -0.35
	var head := _box_in(at, Vector3(0.2, 0.16, 0.3), pale, Vector3(0, 0.74, 0.3))
	head.rotation.x = -0.25
	var jaw := _box_in(at, Vector3(0.16, 0.05, 0.24), dark, Vector3(0, 0.62, 0.3))
	jaw.rotation.x = 0.35
	var tail := _mesh_in(at, _cone(0.1, 0.0, 0.6), pale, Vector3(0, 0.42, -0.45))
	tail.rotation.x = -PI / 2 + 0.3
	for sx in [-1, 1]:
		_mesh_in(at, _cone(0.05, 0.045, 0.34), dark, Vector3(sx * 0.1, 0.17, -0.02))
		_box_in(at, Vector3(0.09, 0.04, 0.16), dark, Vector3(sx * 0.1, 0.02, 0.04))
		var arm := _box_in(at, Vector3(0.03, 0.03, 0.1), pale, Vector3(sx * 0.1, 0.5, 0.24))
		arm.rotation.x = 0.6


## A long neck in stone: a round body on four legs, a long neck up and
## forward with a little head, a tail out behind.
func _long_neck(at: Node3D) -> void:
	var pale := _shade(SCULPTURE)
	var dark := _shade(SCULPTURE_DARK)
	var body := _mesh_in(at, _ball(0.22), pale, Vector3(0, 0.36, 0))
	body.scale = Vector3(1.0, 0.9, 1.5)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_mesh_in(at, _cone(0.05, 0.05, 0.28), dark, Vector3(sx * 0.12, 0.14, sz * 0.17))
	var neck := _mesh_in(at, _cone(0.07, 0.035, 0.62), pale, Vector3(0, 0.66, 0.34))
	neck.rotation.x = 0.55
	var head := _mesh_in(at, _ball(0.07), pale, Vector3(0, 0.94, 0.52))
	head.scale = Vector3(1, 0.8, 1.4)
	var tail := _mesh_in(at, _cone(0.07, 0.0, 0.6), pale, Vector3(0, 0.3, -0.52))
	tail.rotation.x = -PI / 2 - 0.25


## A colour as it looks with the museum open or shut.
func _shade(c: Color) -> Color:
	return c if open else c.darkened(SHUT)


func _ball(r: float) -> SphereMesh:
	var b := SphereMesh.new()
	b.radius = r
	b.height = r * 2.0
	b.radial_segments = 10
	b.rings = 6
	return b


## A cone (or a tapered post): its radius at the foot and at the top, its height.
func _cone(bottom: float, top_r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.bottom_radius = bottom
	c.top_radius = top_r
	c.height = h
	c.radial_segments = 8
	c.rings = 0
	return c


## Pick room i's window (-1 none): it lights up brighter, its piece turns.
func pick(i: int) -> void:
	picked = i
	for k in windows.size():
		var w: Dictionary = windows[k]
		if not w.open:
			continue
		var m := _lit_material(LIT_PICKED if k == i else LIT, 1.7 if k == i else 0.9)
		(w.back as MeshInstance3D).material_override = m
		(w.glass as MeshInstance3D).material_override = m
		# Its frame in gold, lit.
		for f in w.frame:
			(f as MeshInstance3D).material_override = _lit_material(GOLD, 1.4) if k == i else w.stone


## Room i's window: its middle in the world, and how big it is.
func window_centre(i: int) -> Vector3:
	return (windows[i].node as Node3D).global_position


func _process(dt: float) -> void:
	_t += dt
	for k in windows.size():
		var piece: Node3D = windows[k].piece
		piece.rotation.y += dt * (1.8 if k == picked else 0.5)
		var up := absf(sin(_t * 3.0)) * 0.05 if k == picked else 0.0
		piece.position.y = lerpf(piece.position.y, -(windows[k].size as Vector2).y * 0.18 + up, 1.0 - exp(-dt * 10.0))
	var flag := get_node_or_null("Flag") as Node3D
	if flag:
		flag.rotation.y = sin(_t * 2.2 + museum) * 0.25


# --- Shapes -----------------------------------------------------------------------

func _box(s: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	return _box_in(self, s, colour, at)


func _box_in(parent: Node3D, s: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = s
	return _mesh_in(parent, b, colour, at)


func _mesh(mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	return _mesh_in(self, mesh, colour, at)


func _mesh_in(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MenuStage._material(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


func _glow(s: Vector3, colour: Color, at: Vector3, energy: float) -> MeshInstance3D:
	var mi := _box(s, colour, at)
	mi.material_override = _lit_material(colour, energy)
	return mi


static var _lits := {}


static func _lit_material(colour: Color, energy: float) -> StandardMaterial3D:
	var key := [colour, energy]
	if not _lits.has(key):
		var m := MenuStage._material(colour).duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = energy
		_lits[key] = m
	return _lits[key]
