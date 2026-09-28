class_name MuseumBuilding
extends Node3D
## A museum of the story as a building in the town (CityStage), bigger
## than anything round it, each its own (by its theme): the prehistory
## museum a classical building of three floors behind a granite square
## (_prehistory); the ancient one a Palladian villa after La Rotonda, a
## Doric temple front on a domed block (_antiquity); the rest, for now, one
## plain classical hall with a dome in its own colour (_hall).
##
## Its five rooms are windows (windows, in the rooms' order), the big job's
## always in the middle of its front (the big window, or in the ancient
## museum its door). Only a room reached shows as one: lit warm, its piece
## on show in it (and the big job's crown). In the prehistory and the
## ancient museums, one not reached yet is just another of its many windows
## (on its front and its sides), dark or lit like the rest, or a shut door;
## in the hall, where every window is a room, it is dark with a padlock.
## Picking one (pick) lights it up (CityStage draws the ring).
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
## A window lit that is not a room: a dim, dull light behind its bars, so
## the rooms' (warm and bright, nothing in them) stand out.
const P_DIM := Color("#b08a64")
const P_DIM_ENERGY := 0.2
const P_PORCH := 0.62
const P_SQUARE := 2.8
const SANDSTONE := Color("#e6d2a8")
const SANDSTONE_DARK := Color("#b89c72")
const GRANITE := [Color("#8e8a95"), Color("#a3a0aa"), Color("#7a7683"), Color("#96919c")]
const GRANITE_EDGE := Color("#5f5b68")
const SCULPTURE := Color("#d8c9a8")
const SCULPTURE_DARK := Color("#a8977a")
## The ancient museum, a Palladian villa after La Rotonda: a compact block
## across, deep (behind its front, at z 0); its basement (the portico's
## floor), its main floor and the low one over it; its windows on the main
## floor, serlianas (an arched light between two lower square ones): the
## whole of one, its middle light's width, a side light's; the small ones
## over them; where they are across the front (either side of the portico)
## and down each side, back from the front; its portico's columns across
## the front, how far it stands out; its door; its steps, how many and how
## deep each.
const A_W := 4.6
const A_D := 2.8
const A_BASE := 0.5
const A_MAIN := 1.0
const A_UPPER := 0.5
const A_SERLIANA := Vector2(0.68, 0.62)
const A_ARCH := 0.32
const A_LIGHT := 0.14
const A_SMALL := Vector2(0.24, 0.24)
const A_FRONT_X := [-1.87, 1.87]
const A_SIDE_Z := [-0.48, -1.4, -2.32]
## Where the rooms but the big job's are, as P_ROOMS (all on the main
## floor): the serliana right of the portico (the left one is behind the
## portico, as the camera sees it), then the three down the side the camera
## sees; the big job's is behind the door, under the portico.
const A_ROOMS := [
	{"side": 0, "across": 1.87},
	{"side": 1, "across": -0.48},
	{"side": 1, "across": -1.4},
	{"side": 1, "across": -2.32},
]
const A_COLUMNS_X := [-1.25, -0.79, -0.33, 0.33, 0.79, 1.25]
const A_PORCH := 0.9
const A_DOOR := Vector2(0.4, 0.8)
const A_STEPS := 7
const A_STEP := 0.15
## Its dome, as La Rotonda's but a whole half sphere: its radius; how high
## its drum rises over the roof's top.
const A_DOME := 1.05
const A_DRUM := 0.4
## With the dome it stands taller than the rest: the camera, from close,
## looks this much higher at it and sees this much (as MuseumBuilding.view).
const A_LOOK := 0.8
const A_VIEW := 9.0
const MARBLE := Color("#f7f2ea")
const MARBLE_DARK := Color("#c8bca8")
const STUCCO := Color("#ecdfc8")
const ROOF := Color("#8e6a5c")
const GRAVEL := [Color("#e4dccd"), Color("#d6ccba"), Color("#ece6da"), Color("#cbbfab"), Color("#ddd3c2")]
const GRAVEL_EDGE := Color("#b3a794")
const CYPRESS := Color("#2c5638")
const HEDGE := Color("#3d7444")
const CONE := Color("#ff7424")
## How dark a shut museum is.
const SHUT := 0.62

## The middle-ages museum, a castle made a Renaissance palace: across
## (between its towers' middles), deep (behind its front, at z 0), its
## plinth, each floor's height from the ground up (the noble one tallest).
const M_W := 4.6
const M_D := 2.4
const M_BASE := 0.15
const M_FLOORS := [0.72, 0.92, 0.9]
## Its front's bays across (the middle one the big job's, the crest over
## it), the pilasters between them; down each side, the same (back from the
## front, z), past the tower.
const M_BAYS_X := [-1.45, -0.75, 0.0, 0.75, 1.45]
const M_PILASTERS_X := [-1.8, -1.1, -0.375, 0.375, 1.1, 1.8]
const M_SIDE_Z := [-1.2, -1.85]
const M_SIDE_PILASTERS_Z := [-0.86, -1.53, -2.2]
## The towers on its front corners: how wide, where their middles are (z),
## how high their walls go (the gallery and the battlements on top).
const M_TOWER := 0.95
const M_TOWER_Z := -0.3
const M_TOWER_H := 3.25
## The two-light arched windows: across and tall to where the arch springs
## (it is half as high as it is wide); the big job's; the little barred ones
## of the ground floor; the column between the two lights.
const M_WINDOW := Vector2(0.38, 0.32)
const M_BIG := Vector2(0.5, 0.4)
const M_GRILLE := Vector2(0.26, 0.3)
const M_MULLION := 0.035
## Where the rooms but the big job's are, in the rooms' order (as P_ROOMS):
## windows of its front on a noble floor, or high on a tower's front
## (across, the tower's middle). The camera sees this museum from before
## it, its sides hardly: none down a side.
const M_ROOMS := [
	{"side": 0, "across": -1.45, "floor": 1},
	{"side": 0, "across": 0.75, "floor": 2},
	{"side": 0, "across": -M_W * 0.5, "floor": 2},
	{"side": 0, "across": M_W * 0.5, "floor": 2},
]
## How deep the cobbled yard before it.
const M_YARD := 2.8
const M_SAND := Color("#ecd3a0")
const M_SAND_DARK := Color("#b7976a")
const M_JOINT := Color("#c9ab78")
const M_TRIM := Color("#ecd9ae")
const M_TOWER_STONE := Color("#e0c290")
const M_TILE := Color("#8a4e3e")
const M_IRON := Color("#2b2530")
const M_LEAD := Color("#2a2030")
## The stained glass: warm and cold panes between the lead.
const M_STAINED := [Color("#e0304a"), Color("#3f6fe0"), Color("#f2c24a"), Color("#3fae6a"), Color("#9a55e0"),
	Color("#f07a2a"), Color("#44c4d8")]
const M_COBBLE := [Color("#8f8478"), Color("#a09484"), Color("#7c7268"), Color("#978a7b")]
const M_COBBLE_EDGE := Color("#5e554c")
const M_MOAT := Color("#3a3028")
const M_STEEL := Color("#a9b2c4")
const M_FLAME := Color("#ff9a3a")
const M_DUCK := Color("#ffd23a")
const M_CROQUETTE := Color("#c98a3e")

var museum := 0
var open := true
## each room's window: {"node" (its middle), "glass", "back", "piece",
## "lock", "boss", "open" (shown as a room: reached, lit, its piece in it),
## "size", "frame", "stone", "arch", "face" (which way it looks, in the
## building: its +z out of the wall), and maybe "near" (how much nearer the
## camera its ring goes, over a porch before it); optionally "rest" and
## "glow", its back's look when not picked and picked, where it is not lit
## up like a window}, in the rooms' own order
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
		"antiguo":
			_antiquity(rooms)
		"moderna":
			_contemporary(rooms)
		"edad_media": _middle_ages(rooms)
		"naturaleza":
			_nature(rooms)
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
## one in the middle. In each, a lit back wall and nothing in it (or a dark
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
		# Nothing in it: the piece's place, kept empty.
		var piece := Node3D.new()
		piece.position = Vector3(0, -size.y * 0.18, 0.16)
		node.add_child(piece)
		var lock: Node3D = null
		if r.has("shape") and not lit:
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
				_p_window(_slot_at(0, x, f), P_WINDOW, open and rng.randf() < 0.35, _slot_turn(0))
		for side in [-1, 1]:
			for z in P_SIDE_Z:
				if not taken.has(_slot_key(side, z, f)):
					_p_window(_slot_at(side, z, f), P_SIDE_WINDOW, open and rng.randf() < 0.35, _slot_turn(side))
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
	# job's over the door. Only one reached shows as a room: its window lit up
	# warm and bright, no bars across it and nothing in it (and the crown on
	# the pediment for the big job's); the rest are windows like any other,
	# bars and all, dim if lit, and nothing to pick.
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
		var w := _plain(at, size, true, false, turn) if shown else _p_window(at, size, open and rng.randf() < 0.35, turn)
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


## A window of the prehistory museum that is not a room: bars and all, and
## if lit, only dimly (P_DIM). As _plain.
func _p_window(at: Vector3, size: Vector2, lit: bool, turn: float) -> Dictionary:
	var w := _plain(at, size, lit, true, turn)
	if lit:
		(w.glass as MeshInstance3D).material_override = _lit_material(P_DIM, P_DIM_ENERGY)
	return w


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


## The square: granite flags in rows (or others: flags, edge, and how big
## each: flag), each its own grey, on a darker kerb; one MultiMesh for all
## the flags.
func _square(centre: Vector3, size: Vector2, rng: RandomNumberGenerator, flags: Array = GRANITE, edge := GRANITE_EDGE, flag := 0.44) -> void:
	_box(Vector3(size.x + 0.12, 0.03, size.y + 0.06), _shade(edge), centre + Vector3(0, 0.015, 0))
	var nx := int(size.x / flag)
	var nz := int(size.y / flag)
	var tile := BoxMesh.new()
	tile.size = Vector3(flag - minf(0.03, flag * 0.1), 0.03, flag - minf(0.03, flag * 0.1))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tile
	mm.instance_count = nx * nz
	for i in nx:
		for j in nz:
			var at := centre + Vector3((i - (nx - 1) * 0.5) * flag, 0.035, (j - (nz - 1) * 0.5) * flag)
			mm.set_instance_transform(i * nz + j, Transform3D(Basis.IDENTITY, at))
			mm.set_instance_color(i * nz + j, _shade(flags[rng.randi() % flags.size()]))
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


## The ancient museum, a Palladian villa after La Rotonda: a compact block
## of cream stucco on a basement, its main floor and a low one over it, a
## cornice all round (triglyphs on its frieze), a low roof and out of it
## a drum with a whole dome on it, a lantern and a flag (_a_dome). Before
## its middle, a temple front standing well out: six tall Doric columns
## in a row the height of both floors (and one more each side), smooth, no
## base; the frieze over them,
## the museum's name on a tablet in its middle, triglyphs and metopes in
## the museum's colour either side; a pediment, its tympanum plain in the
## colour, a bust on its top and one at each end. A flight of steps as wide
## as it down to the gravel, between two solid walls that slope down with
## it, a pedestal at the foot of each with a statue on it: a rearing horse
## with a traffic cone on its head and a fox in a party hat. Either side of
## the portico and down both sides, serlianas with a little pediment over
## them on the main floor, dark, small square windows over those (some
## lit), little ones in the basement. The rooms' are some of the serlianas
## (A_ROOMS), lit once reached (no piece on show: the light is the room);
## the big job's is behind the door, under the portico: shut until reached,
## then open and lit, the crown over the pediment.
## An amphora each side of the door (a mop stuck in one), hedges and
## cypresses round the gravel, a lamp at each front corner.
func _antiquity(rooms: Array) -> void:
	var wall := _shade(STUCCO)
	var stone := _shade(MARBLE)
	var trim := _shade(MARBLE_DARK)
	var accent := _shade(_colour)
	var glyph := trim.darkened(0.12)
	var main_y := A_BASE + A_MAIN * 0.5
	var upper_y := A_BASE + A_MAIN + A_UPPER * 0.5
	var roof_y := A_BASE + A_MAIN + A_UPPER
	var ent_top := roof_y + 0.3
	var back_z := -A_D * 0.5
	var foot_z := A_PORCH + A_STEPS * A_STEP
	front_z = A_PORCH
	look_y = A_BASE + A_MAIN * 0.8 + A_LOOK
	view = A_VIEW
	var rng := RandomNumberGenerator.new()
	rng.seed = 5077 + museum
	# The gravel before it; the basement with its grooves, the walls, a band
	# under the main floor and one over it.
	_square(Vector3(0, 0, 1.4), Vector2(A_W + 0.9, 2.8), rng, GRAVEL, GRAVEL_EDGE, 0.2)
	_box(Vector3(A_W + 0.08, A_BASE, A_D + 0.08), trim, Vector3(0, A_BASE * 0.5, back_z))
	for y in [A_BASE * 0.35, A_BASE * 0.68]:
		_box(Vector3(A_W + 0.1, 0.018, A_D + 0.1), trim.darkened(0.25), Vector3(0, y, back_z))
	_box(Vector3(A_W, roof_y - A_BASE, A_D), wall, Vector3(0, (roof_y + A_BASE) * 0.5, back_z))
	for y in [A_BASE + 0.02, A_BASE + A_MAIN]:
		_box(Vector3(A_W + 0.05, 0.05, A_D + 0.05), stone, Vector3(0, y, back_z))
	# The entablature all round: architrave, frieze (triglyphs along the
	# front either side of the portico, and down the sides), cornice.
	_box(Vector3(A_W + 0.08, 0.1, A_D + 0.08), stone, Vector3(0, roof_y + 0.05, back_z))
	_box(Vector3(A_W + 0.1, 0.12, A_D + 0.1), stone, Vector3(0, roof_y + 0.16, back_z))
	_box(Vector3(A_W + 0.26, 0.08, A_D + 0.26), stone, Vector3(0, roof_y + 0.26, back_z))
	for k in 23:
		var x := -A_W * 0.5 + 0.1 + k * (A_W - 0.2) / 22.0
		if absf(x) > 1.52:
			_box(Vector3(0.07, 0.11, 0.02), glyph, Vector3(x, roof_y + 0.16, 0.06))
	for k in 13:
		var z := -0.1 - k * (A_D - 0.2) / 12.0
		for sx in [-1, 1]:
			_box(Vector3(0.02, 0.11, 0.07), glyph, Vector3(sx * (A_W * 0.5 + 0.06), roof_y + 0.16, z))
	# The roof, low, and on it the drum, the dome, the lantern and a flag.
	var roof := Node3D.new()
	roof.position = Vector3(0, ent_top + 0.14, back_z)
	roof.scale = Vector3(A_W + 0.1, 0.28, A_D + 0.1)
	add_child(roof)
	var hip := CylinderMesh.new()
	hip.radial_segments = 4
	hip.rings = 0
	hip.bottom_radius = sqrt(0.5)
	hip.top_radius = sqrt(0.5) * 0.35
	hip.height = 1.0
	var slopes := _mesh_in(roof, hip, _shade(ROOF), Vector3.ZERO)
	slopes.rotation.y = PI / 4
	top = _a_dome(ent_top + 0.28, back_z) + 0.15
	# The portico's floor on the basement; the steps down to the gravel, as
	# wide as it, between its walls: level along the portico, sloping down
	# with the steps, a pedestal at the foot of each with a statue on it.
	_box(Vector3(2.9, A_BASE, A_PORCH), trim, Vector3(0, A_BASE * 0.5, A_PORCH * 0.5))
	_box(Vector3(2.9, 0.03, A_PORCH), stone, Vector3(0, A_BASE - 0.015, A_PORCH * 0.5))
	for k in range(1, A_STEPS + 1):
		var h := A_BASE * (1.0 - float(k) / (A_STEPS + 1))
		_box(Vector3(2.6, h, A_STEP), stone if k % 2 == 1 else trim.lightened(0.15), Vector3(0, h * 0.5, A_PORCH + (k - 0.5) * A_STEP))
	var run := foot_z - A_PORCH
	for sx in [-1, 1]:
		var wx: float = sx * 1.45
		_box(Vector3(0.3, A_BASE + 0.15, A_PORCH), trim, Vector3(wx, (A_BASE + 0.15) * 0.5, A_PORCH * 0.5))
		_box(Vector3(0.34, 0.04, A_PORCH), stone, Vector3(wx, A_BASE + 0.17, A_PORCH * 0.5))
		_box(Vector3(0.3, 0.3, run), trim, Vector3(wx, 0.15, A_PORCH + run * 0.5))
		var slope := PrismMesh.new()
		slope.left_to_right = 1.0
		slope.size = Vector3(run, A_BASE + 0.15 - 0.3, 0.3)
		var sl := _mesh(slope, trim, Vector3(wx, 0.3 + (A_BASE + 0.15 - 0.3) * 0.5, A_PORCH + run * 0.5))
		sl.rotation.y = PI / 2
		_box(Vector3(0.44, 0.48, 0.44), trim, Vector3(wx, 0.24, foot_z + 0.12))
		_box(Vector3(0.5, 0.05, 0.5), stone, Vector3(wx, 0.5, foot_z + 0.12))
	_statue("statue-a", 0.95, Vector3(-1.45, 0.52, foot_z + 0.12), 0.5, false)
	_statue("statue-b", 0.85, Vector3(1.45, 0.52, foot_z + 0.12), -0.5, true)
	# An amphora each side of the door, a mop stuck in one.
	for sx in [-1, 1]:
		var jar := MuseumView.asset("anfora")
		jar.position = Vector3(sx * 0.56, A_BASE, 0.25)
		jar.rotation.y = sx * 0.6
		jar.scale = Vector3.ONE * 0.9
		add_child(jar)
		if sx > 0:
			_mop(jar)
	# The columns: Doric, smooth, no base; an echinus and an abacus for a
	# capital. Six in a row, and one more down each side.
	var shaft_h := roof_y - A_BASE - 0.09
	var col_at: Array[Vector2] = []
	for x in A_COLUMNS_X:
		col_at.append(Vector2(x, A_PORCH - 0.12))
	for sx in [-1, 1]:
		col_at.append(Vector2(sx * A_COLUMNS_X[5], 0.3))
	for c in col_at:
		var shaft := _cone(0.08, 0.066, shaft_h)
		shaft.radial_segments = 12
		_mesh(shaft, stone, Vector3(c.x, A_BASE + shaft_h * 0.5, c.y))
		_mesh(_cone(0.07, 0.105, 0.05), stone, Vector3(c.x, roof_y - 0.065, c.y))
		_box(Vector3(0.23, 0.04, 0.23), stone, Vector3(c.x, roof_y - 0.02, c.y))
	# Over them, its entablature: the architrave; the frieze, a tablet with
	# the museum's name in its middle, triglyphs and metopes in the museum's
	# colour either side; the cornice; the pediment over it all, its
	# tympanum in the colour, a bust on its top and one at each end.
	var porch_z := A_PORCH
	_box(Vector3(2.78, 0.1, porch_z), stone, Vector3(0, roof_y + 0.05, porch_z * 0.5))
	_box(Vector3(2.8, 0.12, porch_z + 0.01), stone, Vector3(0, roof_y + 0.16, (porch_z + 0.01) * 0.5))
	_box(Vector3(2.96, 0.08, porch_z + 0.08), stone, Vector3(0, roof_y + 0.26, (porch_z + 0.08) * 0.5))
	for k in 14:
		var x := -1.35 + k * 2.7 / 13.0
		if absf(x) < 0.8:
			continue
		_box(Vector3(0.07, 0.11, 0.02), glyph, Vector3(x, roof_y + 0.16, porch_z + 0.015))
		if k < 13 and absf(x + 1.35 / 13.0) > 0.8:
			_box(Vector3(0.1, 0.08, 0.012), accent, Vector3(x + 1.35 / 13.0, roof_y + 0.16, porch_z + 0.011))
	_box(Vector3(1.5, 0.1, 0.02), trim.lightened(0.3), Vector3(0, roof_y + 0.16, porch_z + 0.015))
	var title := Label3D.new()
	title.text = String(Story.museum(museum).name).to_upper()
	title.font_size = 48
	title.pixel_size = 0.0015
	title.outline_size = 0
	title.modulate = WOOD if open else WOOD.lightened(0.2)
	title.position = Vector3(0, roof_y + 0.16, porch_z + 0.027)
	title.width = 1.45 / 0.0015
	add_child(title)
	var ped := PrismMesh.new()
	ped.size = Vector3(2.96, 0.46, porch_z + 0.08)
	_mesh(ped, stone, Vector3(0, ent_top + 0.23, (porch_z + 0.08) * 0.5))
	var tym := PrismMesh.new()
	tym.size = Vector3(2.34, 0.33, 0.03)
	_mesh(tym, accent, Vector3(0, ent_top + 0.17, porch_z + 0.08))
	var busts := {"busto_filosofo": Vector3(0, ent_top + 0.46, porch_z - 0.02),
		"busto_emperador": Vector3(-1.36, ent_top, porch_z - 0.02), "busto_reina": Vector3(1.36, ent_top, porch_z - 0.02)}
	for b: String in busts:
		var at: Vector3 = busts[b]
		_box(Vector3(0.16, 0.06, 0.16), stone, at + Vector3(0, 0.03, 0))
		_statue(b, 0.34, at + Vector3(0, 0.06, 0), 0.0, false, false)
	# The windows: either side of the portico and down both sides, a
	# serliana on the main floor, dark, so that the rooms' stand out (but
	# where a room is: it has its own), a small window over it, a little one
	# in the basement under it.
	var taken := {}
	for s in A_ROOMS:
		taken[_slot_key(s.side, s.across, 0)] = true
	var slots: Array[Vector2] = []
	for x in A_FRONT_X:
		slots.append(Vector2(0, x))
	for side in [-1, 1]:
		for z in A_SIDE_Z:
			slots.append(Vector2(side, z))
	for s in slots:
		var side := int(s.x)
		var turn := _slot_turn(side)
		if not taken.has(_slot_key(side, s.y, 0)):
			_serliana(_a_slot_at(side, s.y, main_y), false, false, turn)
		_plain(_a_slot_at(side, s.y, upper_y), A_SMALL, open and rng.randf() < 0.3, true, turn)
		var low := Node3D.new()
		low.position = _a_slot_at(side, s.y, A_BASE * 0.5)
		low.rotation.y = turn
		add_child(low)
		_box_in(low, Vector3(0.3, 0.18, 0.03), stone, Vector3(0, 0, 0.01))
		_box_in(low, Vector3(0.22, 0.12, 0.03), GLASS_DARK, Vector3(0, 0, 0.02))
	# Round the gravel: hedges down its sides, a cypress at each corner, a
	# lamp at each front corner.
	for sx in [-1, 1]:
		_box(Vector3(0.2, 0.2, 2.3), _shade(HEDGE), Vector3(sx * 2.62, 0.13, 1.35))
		for z in [2.6, -A_D + 0.1]:
			_cypress(Vector3(sx * 2.62, 0.03, z))
		var post := CylinderMesh.new()
		post.top_radius = 0.025
		post.bottom_radius = 0.035
		post.height = 0.75
		_mesh(post, Color("#2a2433"), Vector3(sx * 2.15, 0.375, 2.5))
		var lamp := _mesh(_ball(0.08), LIT, Vector3(sx * 2.15, 0.8, 2.5))
		if open:
			lamp.material_override = _lit_material(LIT, 3.0)
	# The rooms: some of the serlianas (A_ROOMS), the big job's behind the
	# door. Only one reached shows as a room: lit (the door open, and the
	# crown over the pediment, for the big job's); the rest are dark
	# windows like any other, or a shut door, and nothing to pick.
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var shown: bool = open and r.has("shape") and bool(r.get("open", false))
		var w: Dictionary
		var size := A_SERLIANA
		if r.boss:
			size = A_DOOR
			w = _front_door(shown)
		else:
			var s: Dictionary = A_ROOMS[mini(normal, A_ROOMS.size() - 1)]
			normal += 1
			w = _serliana(_a_slot_at(s.side, s.across, main_y), shown, shown, _slot_turn(s.side))
		var node: Node3D = w.node
		# No piece on show (its "piece" empty): the room is its light.
		var piece := Node3D.new()
		piece.position = Vector3(0, -size.y * 0.18, 0.1)
		node.add_child(piece)
		if shown and r.boss:
			# The big job's crown, over the bust on the pediment's top; a
			# warm glow out of the door over the portico's floor.
			var crown := Node3D.new()
			crown.name = "Crown"
			crown.position = Vector3(0, ent_top + 0.98 - node.position.y, porch_z - 0.02 - node.position.z)
			node.add_child(crown)
			CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD, 1.3)
			_glow(Vector3(A_DOOR.x, 0.004, 0.6), LIT, Vector3(0, A_BASE + 0.003, 0.32), 0.6)
		windows.append({"node": node, "back": w.back, "glass": w.glass, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": size, "frame": w.frame, "stone": w.stone, "arch": false, "face": node.basis, "near": A_PORCH * 2.0 if r.boss else 0.0})


## The ancient museum's dome, as La Rotonda's, its axis at z on the roof
## (roof_top, the hip's top): a round drum in the stucco rising out of the
## roof, little dark windows round it, a cornice on it; a whole half sphere
## of tiles on that, stone steps round its foot and stone ribs up it to a
## lantern of little columns round dark glass, its own little dome, a
## ball in the museum's colour, the pole and the flag. Returns how high
## the pole goes.
func _a_dome(roof_top: float, z: float) -> float:
	var wall := _shade(STUCCO)
	var stone := _shade(MARBLE)
	var tiles := _shade(ROOF.lightened(0.12))
	var r := A_DOME
	var drum_r := r + 0.1
	var foot := roof_top - 0.18
	var dome_y := roof_top + A_DRUM
	var drum := _cone(drum_r, drum_r, dome_y - foot)
	drum.radial_segments = 32
	_mesh(drum, wall, Vector3(0, (foot + dome_y) * 0.5, z))
	for k in 8:
		var a := (k + 0.5) * TAU / 8.0
		var slit := _box(Vector3(0.14, 0.18, 0.04), GLASS_DARK, Vector3(sin(a) * drum_r, dome_y - 0.2, z + cos(a) * drum_r))
		slit.rotation.y = a
	var cornice := _cone(drum_r + 0.05, drum_r + 0.05, 0.07)
	cornice.radial_segments = 32
	_mesh(cornice, stone, Vector3(0, dome_y - 0.035, z))
	# The dome: a whole half sphere; stone steps round its foot, each
	# hugging it a little higher up; ribs up it, each a ring standing on
	# end through its axis (their lower halves lost in the drum and the
	# roof).
	var dome := SphereMesh.new()
	dome.radius = r
	dome.height = r
	dome.is_hemisphere = true
	dome.radial_segments = 32
	dome.rings = 12
	_mesh(dome, tiles, Vector3(0, dome_y, z))
	for k in 3:
		var h := k * 0.08
		var step := _cone(sqrt(r * r - (h + 0.08) * (h + 0.08)) + 0.035, sqrt(r * r - (h + 0.08) * (h + 0.08)) + 0.035, 0.08)
		step.radial_segments = 32
		_mesh(step, stone, Vector3(0, dome_y + h + 0.04, z))
	for k in 4:
		var rib := TorusMesh.new()
		rib.inner_radius = r - 0.01
		rib.outer_radius = r + 0.03
		rib.rings = 40
		rib.ring_segments = 6
		var mi := _mesh(rib, stone, Vector3(0, dome_y, z))
		mi.basis = Basis(Vector3.UP, k * PI / 4.0) * Basis(Vector3.RIGHT, PI / 2.0)
	# The lantern on its top.
	var at := dome_y + r - 0.03
	_mesh(_cone(0.2, 0.2, 0.05), stone, Vector3(0, at + 0.025, z))
	_mesh(_cone(0.12, 0.12, 0.22), GLASS_DARK, Vector3(0, at + 0.16, z))
	for k in 6:
		var a := k * TAU / 6.0
		_box(Vector3(0.035, 0.22, 0.035), stone, Vector3(sin(a) * 0.15, at + 0.16, z + cos(a) * 0.15))
	_mesh(_cone(0.19, 0.19, 0.04), stone, Vector3(0, at + 0.29, z))
	var cap := SphereMesh.new()
	cap.radius = 0.15
	cap.height = 0.15
	cap.is_hemisphere = true
	cap.radial_segments = 16
	_mesh(cap, tiles, Vector3(0, at + 0.31, z))
	_mesh(_ball(0.05), _shade(_colour), Vector3(0, at + 0.49, z))
	_box(Vector3(0.03, 0.7, 0.03), POLE, Vector3(0, at + 0.85, z))
	var flag := _box(Vector3(0.42, 0.24, 0.02), _colour if open else _shade(_colour), Vector3(0.22, at + 1.07, z))
	flag.name = "Flag"
	return at + 1.2


## Where a window of the ancient museum is: on its front (side 0, across
## its x) or down a side (-1 left, 1 right, across its z), at height y.
func _a_slot_at(side: int, across: float, y: float) -> Vector3:
	if side == 0:
		return Vector3(across, y, 0.0)
	return Vector3(side * A_W * 0.5, y, across)


## A serliana (a Palladian window), its middle at `at` on a wall, turned
## `turn` round y from facing the front: a tall middle light with a round
## arch over it (a keystone in the museum's colour) between two lower,
## narrow square lights, little columns between them, a short entablature
## over the side lights, a sill under it all, a little pediment over it. Lit or dark; glazing bars,
## but none down the middle light of a room's (room), brighter lit.
## Returns {"node", "back" (the middle light), "glass" (its arch), "frame"
## (the stone round it), "stone" (its look)}.
func _serliana(at: Vector3, lit: bool, room: bool, turn := 0.0) -> Dictionary:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = turn
	add_child(node)
	var stone := _shade(MARBLE)
	var a := A_ARCH
	var p := 0.04
	var s := A_LIGHT
	var foot := -A_SERLIANA.y * 0.5
	var rect := A_SERLIANA.y - a * 0.5
	var spring := foot + rect
	var half := a * 0.5 + p + s
	var frame: Array = []
	# The stone: jambs, the little columns, the entablature over the side
	# lights, the arch round the middle one, the sill.
	for sx in [-1, 1]:
		frame.append(_box_in(node, Vector3(0.05, rect + 0.02, 0.05), stone, Vector3(sx * (half + 0.025), foot + rect * 0.5, 0.02)))
		frame.append(_box_in(node, Vector3(p, rect, 0.05), stone, Vector3(sx * (a * 0.5 + p * 0.5), foot + rect * 0.5, 0.025)))
		frame.append(_box_in(node, Vector3(s + p + 0.06, 0.05, 0.07), stone, Vector3(sx * (a * 0.5 + (s + p) * 0.5 + 0.02), spring + 0.025, 0.03)))
	var ring := _cone(a * 0.5 + 0.05, a * 0.5 + 0.05, 0.04)
	ring.radial_segments = 16
	var arch := _mesh_in(node, ring, stone, Vector3(0, spring, 0.006))
	arch.rotation.x = PI / 2
	frame.append(arch)
	frame.append(_box_in(node, Vector3(2.0 * half + 0.14, 0.05, 0.1), stone, Vector3(0, foot - 0.03, 0.045)))
	_box_in(node, Vector3(0.06, 0.07, 0.05), _shade(_colour), Vector3(0, spring + a * 0.5 + 0.02, 0.03))
	# The little pediment over it all, on a cornice.
	frame.append(_box_in(node, Vector3(2.0 * half + 0.16, 0.03, 0.08), stone, Vector3(0, spring + a * 0.5 + 0.08, 0.04)))
	var hood := PrismMesh.new()
	hood.size = Vector3(2.0 * half + 0.16, 0.08, 0.07)
	frame.append(_mesh_in(node, hood, stone, Vector3(0, spring + a * 0.5 + 0.135, 0.035)))
	# The glass: the middle light and its arch, the side lights.
	var back := _box_in(node, Vector3(a, rect, 0.03), GLASS_DARK, Vector3(0, foot + rect * 0.5, 0.012))
	var disc := _cone(a * 0.5, a * 0.5, 0.03)
	disc.radial_segments = 16
	var glass := _mesh_in(node, disc, GLASS_DARK, Vector3(0, spring, 0.011))
	glass.rotation.x = PI / 2
	var lights: Array[MeshInstance3D] = [back, glass]
	for sx in [-1, 1]:
		lights.append(_box_in(node, Vector3(s, rect, 0.03), GLASS_DARK, Vector3(sx * (a * 0.5 + p + s * 0.5), foot + rect * 0.5, 0.012)))
	if lit:
		var look := _lit_material(LIT, 0.9 if room else 0.55)
		for l in lights:
			l.material_override = look
	# The glazing bars: across each light, and down the middle one.
	var bar := WOOD.lightened(0.15) if lit else GLASS_DARK.lightened(0.15)
	for sx in [-1, 1]:
		_box_in(node, Vector3(s, 0.02, 0.02), bar, Vector3(sx * (a * 0.5 + p + s * 0.5), foot + rect * 0.55, 0.03))
	_box_in(node, Vector3(a, 0.02, 0.02), bar, Vector3(0, spring, 0.03))
	if not room:
		_box_in(node, Vector3(0.02, rect + a * 0.5, 0.02), bar, Vector3(0, foot + (rect + a * 0.5) * 0.5, 0.03))
	return {"node": node, "back": back, "glass": glass, "frame": frame, "stone": (frame[0] as MeshInstance3D).material_override}


## The ancient museum's front door, under the portico: a stone surround with
## a little pediment over it, two wooden leaves. Shut (open_door false): the
## leaves closed on a dark doorway. Open: the leaves swung out, the doorway
## lit. Returns as _serliana does ("back" and "glass" both the doorway).
func _front_door(open_door: bool) -> Dictionary:
	var node := Node3D.new()
	node.position = Vector3(0, A_BASE + A_DOOR.y * 0.5, 0.0)
	add_child(node)
	var stone := _shade(MARBLE)
	var wood := WOOD.darkened(0.0 if open else 0.4)
	var frame: Array = []
	for sx in [-1, 1]:
		frame.append(_box_in(node, Vector3(0.07, A_DOOR.y + 0.07, 0.06), stone, Vector3(sx * (A_DOOR.x * 0.5 + 0.035), 0.035, 0.03)))
	frame.append(_box_in(node, Vector3(A_DOOR.x + 0.22, 0.08, 0.08), stone, Vector3(0, A_DOOR.y * 0.5 + 0.1, 0.04)))
	var hood := PrismMesh.new()
	hood.size = Vector3(A_DOOR.x + 0.3, 0.14, 0.08)
	frame.append(_mesh_in(node, hood, stone, Vector3(0, A_DOOR.y * 0.5 + 0.21, 0.04)))
	var back := _box_in(node, Vector3(A_DOOR.x, A_DOOR.y, 0.02), GLASS_DARK, Vector3(0, 0, 0.008))
	if open_door:
		back.material_override = _lit_material(LIT, 0.9)
	# The leaves, each on its hinge at a jamb: panels, a gold knob.
	for sx in [-1, 1]:
		var hinge := Node3D.new()
		hinge.position = Vector3(sx * A_DOOR.x * 0.5, 0, 0.03)
		hinge.rotation.y = sx * 1.35 if open_door else 0.0
		node.add_child(hinge)
		_box_in(hinge, Vector3(A_DOOR.x * 0.5 - 0.01, A_DOOR.y, 0.03), wood, Vector3(-sx * A_DOOR.x * 0.25, 0, 0))
		for y in [-0.18, 0.17]:
			_box_in(hinge, Vector3(A_DOOR.x * 0.3, 0.26, 0.012), wood.darkened(0.25), Vector3(-sx * A_DOOR.x * 0.25, y, 0.018))
		_mesh_in(hinge, _ball(0.018), GOLD.darkened(0.0 if open else SHUT), Vector3(-sx * (A_DOOR.x * 0.5 - 0.05), -0.02, 0.03))
	return {"node": node, "back": back, "glass": back, "frame": frame, "stone": (frame[0] as MeshInstance3D).material_override}


## A cypress: a tall dark green spindle on a short trunk.
func _cypress(at: Vector3) -> void:
	_mesh(_cone(0.04, 0.03, 0.14), _shade(WOOD), at + Vector3(0, 0.07, 0))
	var body := _mesh(_ball(0.17), _shade(CYPRESS), at + Vector3(0, 0.55, 0))
	body.scale = Vector3(1.0, 2.7, 1.0)


## A statue from the models (model_name), `tall` high, in pale marble, at
## `at` turned `turn`; on its head (its highest point) a traffic cone, or a
## party hat in the museum's colour (hat); or nothing (gag false).
func _statue(model_name: String, tall: float, at: Vector3, turn: float, hat: bool, gag := true) -> void:
	var model := MuseumView.asset(model_name)
	var points := _points_of(model)
	var top_at := Vector3(0, -INF, 0)
	var low := INF
	for p in points:
		low = minf(low, p.y)
		if p.y > top_at.y:
			top_at = p
	var s := tall / maxf(top_at.y - low, 0.001)
	model.position = at - Vector3(0, low * s, 0)
	model.rotation.y = turn
	model.scale = Vector3.ONE * s
	add_child(model)
	var pale := MenuStage._material(_shade(Color("#e9e3d8")))
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = pale
	if not gag:
		return
	var head := Node3D.new()
	head.position = top_at
	head.scale = Vector3.ONE / s
	model.add_child(head)
	if hat:
		_mesh_in(head, _cone(0.07, 0.0, 0.18), _shade(_colour), Vector3(0, 0.07, 0))
		_mesh_in(head, _ball(0.025), _shade(GOLD), Vector3(0, 0.16, 0))
	else:
		_mesh_in(head, _cone(0.07, 0.015, 0.2), _shade(CONE), Vector3(0, 0.09, 0))
		_mesh_in(head, _cone(0.053, 0.045, 0.04), _shade(Color.WHITE), Vector3(0, 0.1, 0))
		_box_in(head, Vector3(0.16, 0.02, 0.16), _shade(CONE), Vector3(0, -0.005, 0))


## Every corner of a model's meshes, in its own space.
func _points_of(model: Node3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != model:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		for surface in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for v in verts:
				out.append(t * v)
	return out


## A mop stuck head up in an amphora: a pale stick, a grey tangle on top.
func _mop(jar: Node3D) -> void:
	var stick := _mesh_in(jar, _cone(0.012, 0.012, 0.6), _shade(Color("#d9b98a")), Vector3(0.03, 0.55, 0))
	stick.rotation.z = -0.25
	var mop := _mesh_in(jar, _ball(0.09), _shade(Color("#b8b4c0")), Vector3(0.1, 0.84, 0))
	mop.scale = Vector3(1.0, 0.7, 1.0)


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


## The contemporary museum (La Torre de Cristal, after SANAA's New Museum):
## a tower of white boxes piled up, each shifted a little from the one
## under it (some stand out, some step back) and each its own height, in a
## skin of pale perforated metal (fine ribs), blind: no windows. The light
## comes out between them: under each box a joint, set back all round, of
## glass lit from inside. Under them a glass ground floor, lit, with the
## museum's name; railings round the terraces the steps back leave, a giant
## rubber duck on one; before it a square of polished concrete with long
## benches, a giant banana and a banner.
##
## Each room is a floor, a whole box, in order up the tower (C_FLOORS), the
## big job's the top one. Nothing of what's inside is seen: a room reached
## has the joint under its box lit and its box a little bright (the big
## job's, the crown on the roof); one not reached yet is just another box,
## its joint dim. Picked, its joint shines and its whole box lights up. The
## entry's "shape" is "floor": CityStage outlines the whole box ("volume":
## its box, round its node).

## How much the camera sees from close (0: CityStage's own): the tower's
## taller than the rest.
var view := 0.0

## The glass ground floor: its height and its front (z); how deep the
## square before it goes.
const C_LOBBY := 0.7
const C_LOBBY_Z := 0.1
const C_SQUARE := 2.8
## The floors, bottom to top: each box's size (across, tall, deep), its
## middle across (x) and its front (z). The last is the big job's.
const C_FLOORS := [
	{"size": Vector3(3.5, 1.0, 2.7), "x": 0.0, "front": 0.25},
	{"size": Vector3(3.0, 0.95, 2.3), "x": 0.25, "front": -0.2},
	{"size": Vector3(3.3, 0.9, 2.5), "x": -0.1, "front": -0.05},
	{"size": Vector3(2.8, 1.0, 2.2), "x": 0.2, "front": -0.3},
	{"size": Vector3(2.4, 1.15, 1.9), "x": -0.1, "front": -0.45},
]
## The joint under each box: how tall, and how far it is set back from the
## box's front and side.
const C_JOINT := 0.24
const C_JOINT_IN := 0.06
## How far apart the skin's ribs are.
const C_RIB := 0.2
const C_SKIN := [Color("#e9ebf1"), Color("#dde0e8"), Color("#e6e8ef"), Color("#d9dce5"), Color("#eef0f4")]
const C_RIB_TINT := Color("#c4c8d4")
const C_MULLION := Color("#353142")
const C_CONCRETE := [Color("#b9b6c0"), Color("#c3c0c9"), Color("#aeabb6"), Color("#bdbac4")]
const C_GROUND := Color("#8d8998")
const C_METAL := Color("#8e8e9c")
const C_DUCK := Color("#ffd23a")
const C_BEAK := Color("#ff8a1e")
const C_BANANA := Color("#ffdf4a")
const C_BANANA_TIP := Color("#5a4630")
const C_WHITE := Color("#f2f2f6")
## How much the white skin and the pop art shine of their own at night; a
## room's box, a little more, and picked, lit up (towards LIT_PICKED).
const C_SKIN_GLOW := 0.2
const C_ROOM_GLOW := 0.35
const C_PICKED_GLOW := 1.0
const C_PICKED_TINT := 0.5
## A joint's glow: lit (a room's, or the town's view), dim (not a room
## yet: dark glass, barely warm), picked.
const C_JOINT_GLOW := 1.1
const C_JOINT_OFF := Color("#3a3048")
const C_JOINT_DIM := 0.3
const C_JOINT_PICKED := 2.4
const C_POP_GLOW := 0.3


func _contemporary(rooms: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5077 + museum
	# Where each floor starts, up from the glass ground floor.
	var base: Array[float] = []
	var y := C_LOBBY
	for f: Dictionary in C_FLOORS:
		base.append(y)
		y += (f.size as Vector3).y
	var roof_y := y
	front_z = 0.0
	look_y = 2.57
	top = roof_y + 0.9
	view = 10.5
	# Fine boxes in their own colours (the skin's ribs, the glass's
	# mullions), all in one MultiMesh: [transform, colour].
	var bits: Array = []
	_c_square(rng, bits)
	_c_lobby(bits)
	# The boxes and the joints under them: lit all through in the town's
	# view, dim in a museum gone into until its room's reached.
	var boxes: Array[MeshInstance3D] = []
	var joints: Array[MeshInstance3D] = []
	for k in C_FLOORS.size():
		boxes.append(_c_box(k, base[k], bits))
		joints.append(_c_joint(k, base[k], open and rooms.is_empty(), bits))
	# Railings round the terraces a step back leaves, and round the roof.
	for k in range(1, C_FLOORS.size()):
		_c_railings(C_FLOORS[k - 1], C_FLOORS[k], base[k])
	_c_railings(C_FLOORS[-1], {}, roof_y)
	# The giant rubber duck on the first terrace, looking out.
	var duck := Node3D.new()
	duck.position = Vector3(-1.5, base[1], 0.0)
	duck.rotation.y = 0.35
	duck.scale = Vector3.ONE * 1.15
	add_child(duck)
	_c_duck(duck)
	# The rooms: a floor each, in order up the tower, the big job's the top.
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var k := C_FLOORS.size() - 1
		if not r.boss:
			k = mini(normal, C_FLOORS.size() - 2)
			normal += 1
		var f: Dictionary = C_FLOORS[k]
		var s: Vector3 = f.size
		var node := Node3D.new()
		node.position = Vector3(f.x, base[k] + s.y * 0.5, f.front)
		add_child(node)
		var shown: bool = open and r.has("shape") and bool(r.get("open", false))
		var box := boxes[k]
		var joint := joints[k]
		var skin := _shade(C_SKIN[k % C_SKIN.size()])
		var rest := _lit_material(LIT, C_JOINT_GLOW)
		var reached: Material = _lit_material(skin, C_ROOM_GLOW)
		if shown:
			joint.material_override = rest
			box.material_override = reached
			if r.boss:
				# The big job's crown, on the roof.
				var crown := Node3D.new()
				crown.position = Vector3(0, s.y * 0.5 + 0.4, -s.z * 0.45)
				node.add_child(crown)
				CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD, 1.6)
		# Nothing of the room is seen: its piece is left empty.
		var piece := Node3D.new()
		node.add_child(piece)
		windows.append({"node": node, "back": joint, "glass": joint, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": Vector2(s.x, s.y), "frame": [box], "stone": reached, "arch": false, "face": node.basis,
			"rest": rest, "glow": _lit_material(LIT_PICKED, C_JOINT_PICKED),
			"frame_glow": _lit_material(skin.lerp(LIT_PICKED, C_PICKED_TINT), C_PICKED_GLOW),
			"shape": "floor", "volume": AABB(Vector3(-s.x * 0.5, -s.y * 0.5 + C_JOINT, -s.z), Vector3(s.x, s.y - C_JOINT, s.z))})
	_c_bits(bits)


## Floor k of the tower's box, from y0 up over its joint, blind in its
## skin, the skin's ribs up its front and its side. Returns the box.
func _c_box(k: int, y0: float, bits: Array) -> MeshInstance3D:
	var f: Dictionary = C_FLOORS[k]
	var s: Vector3 = f.size
	var x: float = f.x
	var front: float = f.front
	var skin := _shade(C_SKIN[k % C_SKIN.size()])
	var lo := y0 + C_JOINT
	var box := _box(Vector3(s.x, s.y - C_JOINT, s.z), skin, Vector3(x, (lo + y0 + s.y) * 0.5, front - s.z * 0.5))
	if open:
		# White at night: lit a little from the town round it.
		box.material_override = _lit_material(skin, C_SKIN_GLOW)
	var tint := _shade(C_RIB_TINT)
	var r0 := lo + 0.03
	var r1 := y0 + s.y - 0.03
	var n := int((s.x - 0.16) / C_RIB)
	for i in n + 1:
		var at := Vector3(x - (n * C_RIB) * 0.5 + i * C_RIB, (r0 + r1) * 0.5, front + 0.006)
		bits.append([Transform3D(Basis.from_scale(Vector3(0.02, r1 - r0, 0.014)), at), tint])
	var m := int((s.z - 0.16) / C_RIB)
	for i in m + 1:
		var at := Vector3(x + s.x * 0.5 + 0.006, (r0 + r1) * 0.5, front - s.z * 0.5 - (m * C_RIB) * 0.5 + i * C_RIB)
		bits.append([Transform3D(Basis.from_scale(Vector3(0.014, r1 - r0, 0.02)), at), tint])
	return box


## The joint under floor k's box (from y0 up, C_JOINT tall): glass set back
## C_JOINT_IN from its front and its side, lit (lit), dim (open, not lit)
## or dark, thin mullions across it. Returns the glass.
func _c_joint(k: int, y0: float, lit: bool, bits: Array) -> MeshInstance3D:
	var f: Dictionary = C_FLOORS[k]
	var s: Vector3 = f.size
	var x: float = f.x
	var front: float = float(f.front) - C_JOINT_IN
	var w := s.x - C_JOINT_IN * 2.0
	var d := s.z - C_JOINT_IN * 2.0
	var cy := y0 + C_JOINT * 0.5
	var glass := _box(Vector3(w, C_JOINT, d), _shade(GLASS_DARK), Vector3(x, cy, front - d * 0.5))
	if open:
		glass.material_override = _lit_material(LIT, C_JOINT_GLOW) if lit else _lit_material(C_JOINT_OFF, C_JOINT_DIM)
	var mullion := _shade(C_MULLION)
	var n := int(w / 0.3)
	for i in n + 1:
		var at := Vector3(x - w * 0.5 + i * (w / n), cy, front + 0.008)
		bits.append([Transform3D(Basis.from_scale(Vector3(0.018, C_JOINT, 0.016)), at), mullion])
	var m := int(d / 0.3)
	for i in m + 1:
		var at := Vector3(x + w * 0.5 + 0.008, cy, front - i * (d / m))
		bits.append([Transform3D(Basis.from_scale(Vector3(0.016, C_JOINT, 0.018)), at), mullion])
	return glass


## The glass ground floor under the first box: lit through when open, its
## mullions, the doors in the middle, the museum's name in its colour over
## them; a banner in its colour on a pole and two slim lamps before it.
func _c_lobby(bits: Array) -> void:
	var w := 3.2
	var d := 2.3
	var glass := _box(Vector3(w, C_LOBBY, d), _shade(GLASS_DARK.lightened(0.1)), Vector3(0, C_LOBBY * 0.5, C_LOBBY_Z - d * 0.5))
	if open:
		glass.material_override = _lit_material(LIT.lerp(Color.WHITE, 0.35), 0.75)
	var mullion := _shade(C_MULLION)
	var n := int(w / 0.4)
	for i in n + 1:
		var x := -w * 0.5 + i * (w / n)
		bits.append([Transform3D(Basis.from_scale(Vector3(0.03, C_LOBBY, 0.03)), Vector3(x, C_LOBBY * 0.5, C_LOBBY_Z + 0.01)), mullion])
	var m := int(d / 0.4)
	for i in m + 1:
		var z := C_LOBBY_Z - i * (d / m)
		bits.append([Transform3D(Basis.from_scale(Vector3(0.03, C_LOBBY, 0.03)), Vector3(w * 0.5 + 0.01, C_LOBBY * 0.5, z)), mullion])
	# A dark slab over the glass (the first joint's light apart from the
	# lobby's), the doors in a dark frame.
	_box(Vector3(w + 0.06, 0.06, d + 0.06), mullion, Vector3(0, C_LOBBY - 0.03, C_LOBBY_Z - d * 0.5))
	_box(Vector3(0.62, 0.44, 0.03), mullion, Vector3(0, 0.22, C_LOBBY_Z + 0.02))
	var door := _box(Vector3(0.54, 0.4, 0.03), _shade(GLASS_DARK), Vector3(0, 0.2, C_LOBBY_Z + 0.03))
	if open:
		door.material_override = _lit_material(LIT, 1.2)
	_box(Vector3(0.02, 0.4, 0.04), mullion, Vector3(0, 0.2, C_LOBBY_Z + 0.04))
	var name_sign := Label3D.new()
	name_sign.text = String(Story.museum(museum).name).to_upper()
	name_sign.font_size = 48
	name_sign.pixel_size = 0.0021
	name_sign.outline_size = 10
	name_sign.outline_modulate = _shade(Color("#2a1030"))
	name_sign.modulate = _shade(_colour)
	name_sign.position = Vector3(0, C_LOBBY - 0.14, C_LOBBY_Z + 0.04)
	add_child(name_sign)
	# The banner on its pole, left of the doors; the lamps.
	var metal := _shade(C_METAL)
	_box(Vector3(0.035, 1.3, 0.035), metal, Vector3(-1.95, 0.65, C_LOBBY_Z + 0.65))
	_box(Vector3(0.2, 0.7, 0.02), _shade(_colour), Vector3(-1.84, 0.85, C_LOBBY_Z + 0.65))
	_box(Vector3(0.2, 0.05, 0.025), _shade(C_WHITE), Vector3(-1.84, 0.62, C_LOBBY_Z + 0.65))
	for sx in [-1, 1]:
		var x: float = sx * 1.25
		_box(Vector3(0.03, 0.8, 0.03), metal, Vector3(x, 0.4, C_SQUARE - 0.35))
		var lamp := _box(Vector3(0.06, 0.2, 0.06), LIT, Vector3(x, 0.86, C_SQUARE - 0.35))
		if open:
			lamp.material_override = _lit_material(LIT, 3.0)


## The square: the lot in pale concrete, big polished slabs before the
## tower, long white benches, and the giant banana on its plinth.
func _c_square(rng: RandomNumberGenerator, bits: Array) -> void:
	_box(Vector3(5.5, 0.03, 5.5), _shade(C_GROUND), Vector3(0, 0.015, 0))
	var slab := 0.66
	var nx := 8
	var nz := int((C_SQUARE - C_LOBBY_Z) / slab)
	for i in nx:
		for j in nz:
			var at := Vector3((i - (nx - 1) * 0.5) * slab, 0.035, C_SQUARE - (j + 0.5) * slab)
			bits.append([Transform3D(Basis.from_scale(Vector3(slab - 0.025, 0.03, slab - 0.025)), at), _shade(C_CONCRETE[rng.randi() % C_CONCRETE.size()])])
	# The benches, long and low, each on two dark feet.
	for b in [Vector3(-1.2, 0, 1.55), Vector3(1.15, 0, 2.05)]:
		var at: Vector3 = b
		_box(Vector3(1.1, 0.07, 0.3), _shade(C_WHITE), at + Vector3(0, 0.2, 0))
		for sx in [-1, 1]:
			_box(Vector3(0.06, 0.17, 0.26), _shade(C_MULLION), at + Vector3(sx * 0.42, 0.1, 0))
	# The banana: bent, standing on its end on a white plinth.
	var plinth := Vector3(1.95, 0, 1.0)
	_box(Vector3(0.5, 0.32, 0.5), _shade(C_WHITE), plinth + Vector3(0, 0.16, 0))
	var banana := Node3D.new()
	banana.position = plinth + Vector3(-0.08, 0.34, 0)
	banana.rotation.y = -0.5
	add_child(banana)
	_c_banana(banana)


## Railings on the top of box `low` (at height y) where the box over it
## (`high`, or none: the roof) leaves it bare: along its front, and down
## either side.
func _c_railings(low: Dictionary, high: Dictionary, y: float) -> void:
	var s: Vector3 = low.size
	var x0: float = float(low.x) - s.x * 0.5
	var x1: float = float(low.x) + s.x * 0.5
	var z1: float = low.front
	var z0: float = z1 - s.z
	var metal := _shade(C_METAL)
	var bare_front := true
	var bare_left := true
	var bare_right := true
	if not high.is_empty():
		var hs: Vector3 = high.size
		bare_front = z1 - float(high.front) > 0.15
		bare_left = (float(high.x) - hs.x * 0.5) - x0 > 0.15
		bare_right = x1 - (float(high.x) + hs.x * 0.5) > 0.15
	var rail := 0.2
	if bare_front:
		_c_rail(Vector3(x0 + 0.04, y, z1 - 0.04), Vector3(x1 - 0.04, y, z1 - 0.04), rail, metal)
	if bare_left:
		_c_rail(Vector3(x0 + 0.04, y, z0 + 0.04), Vector3(x0 + 0.04, y, z1 - 0.04), rail, metal)
	if bare_right:
		_c_rail(Vector3(x1 - 0.04, y, z0 + 0.04), Vector3(x1 - 0.04, y, z1 - 0.04), rail, metal)


## A railing from a to b (along x or z), `tall` high: a bar on posts.
func _c_rail(a: Vector3, b: Vector3, tall: float, colour: Color) -> void:
	var run := b - a
	var along := run.length()
	var bar := Vector3(along, 0.025, 0.025) if absf(run.x) > absf(run.z) else Vector3(0.025, 0.025, along)
	_box(bar, colour, (a + b) * 0.5 + Vector3(0, tall, 0))
	var n := maxi(1, int(along / 0.35))
	for i in n + 1:
		_box(Vector3(0.02, tall, 0.02), colour, a + run * (float(i) / n) + Vector3(0, tall * 0.5, 0))


## A giant rubber duck, its head to +x: a squat yellow body, a round head,
## an orange beak, two black eyes, its tail cocked.
func _c_duck(at: Node3D) -> void:
	var yellow := _shade(C_DUCK)
	var body := _pop(_mesh_in(at, _ball(0.22), yellow, Vector3(0, 0.17, 0)))
	body.scale = Vector3(1.35, 0.8, 1.0)
	_pop(_mesh_in(at, _ball(0.14), yellow, Vector3(0.17, 0.4, 0)))
	var beak := _box_in(at, Vector3(0.12, 0.045, 0.12), _shade(C_BEAK), Vector3(0.33, 0.37, 0))
	beak.rotation.z = -0.15
	for sz in [-1, 1]:
		_mesh_in(at, _ball(0.022), _shade(Color("#1a1420")), Vector3(0.26, 0.45, sz * 0.08))
	var tail := _pop(_mesh_in(at, _cone(0.08, 0.0, 0.16), yellow, Vector3(-0.3, 0.28, 0)))
	tail.rotation.z = 0.8


## A giant banana standing on its end, bending over: yellow segments, a
## brown stalk at the top and a brown tip at its foot.
func _c_banana(at: Node3D) -> void:
	var yellow := _shade(C_BANANA)
	var here := Vector3.ZERO
	var bend := -0.25
	for k in 5:
		var dir := Vector3(sin(bend), cos(bend), 0)
		var seg := CapsuleMesh.new()
		seg.radius = 0.11 - absf(k - 2) * 0.012
		seg.height = 0.34
		seg.radial_segments = 10
		seg.rings = 2
		var mi := _pop(_mesh_in(at, seg, yellow, here + dir * 0.13))
		mi.rotation.z = -bend
		here += dir * 0.24
		bend += 0.24
	_mesh_in(at, _ball(0.05), _shade(C_BANANA_TIP), Vector3(0, 0.0, 0))
	var stalk := _mesh_in(at, _cone(0.045, 0.035, 0.14), _shade(C_BANANA_TIP), here + Vector3(sin(bend), cos(bend), 0) * 0.03)
	stalk.rotation.z = -bend


## A piece of pop art, lit a little of its own when the museum's open.
func _pop(mi: MeshInstance3D) -> MeshInstance3D:
	if open:
		mi.material_override = _lit_material((mi.material_override as StandardMaterial3D).albedo_color, C_POP_GLOW)
	return mi


## The fine boxes gathered along the way ([transform, colour]), all in one
## MultiMesh.
func _c_bits(bits: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = bits.size()
	for i in bits.size():
		mm.set_instance_transform(i, bits[i][0])
		mm.set_instance_color(i, bits[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.45
	mmi.material_override = m
	add_child(mmi)




# --- The middle-ages museum ---------------------------------------------------------

## The small parts of the middle-ages museum (joints, corbels, battlements,
## cobbles, bars...), gathered by colour and drawn as one MultiMesh each.
var _m_parts := {}
static var _m_glass := {}
static var _m_lights := {}
static var _m_glass_texture: ImageTexture


## The middle-ages museum, a castle made a museum: a Renaissance palace of
## three floors in sand coloured ashlar (its joints drawn), flat pilasters
## on each floor, a band between the floors (the museum's name on the first)
## and a great cornice on corbels, battlements on it; a square tower on each
## front corner, higher, with a gallery on corbels and its battlements, a
## banner in the museum's colour down its front and a pennant on top. Its
## windows two-light arched ones with stained glass, a column between the
## lights and a round one over them, some lit, on the two noble floors of
## its front and both its sides; little barred ones on the ground floor. The
## rooms' are some of them (M_ROOMS); the big job's the big one in the
## middle of the noble floor, on a balcony, the family's crest over it (and
## the crown on the crest). Before it, a cobbled yard: a little drawbridge
## over a dry moat (a rubber duck in it), a brazier each side, a well, and a
## knight in armour holding up a plunger for a lance.
func _middle_ages(rooms: Array) -> void:
	_m_parts.clear()
	var sand := _shade(M_SAND)
	var sand_dark := _shade(M_SAND_DARK)
	var joint := _shade(M_JOINT)
	var trim := _shade(M_TRIM)
	var tower_stone := _shade(M_TOWER_STONE)
	var accent := _shade(_colour)
	var half := M_W * 0.5
	var roof_y := _m_floor_y(M_FLOORS.size())
	var front := M_W - M_TOWER
	front_z = 0.1
	look_y = M_BASE + 1.75
	top = M_TOWER_H + 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5071 + museum
	var taken := {}
	for s: Dictionary in M_ROOMS:
		taken[_m_key(s.side, s.across, s.floor)] = true
	_m_yard(rng)
	# The plinth, the walls, their joints (bigger blocks on the ground floor).
	_box(Vector3(M_W + 0.12, M_BASE, M_D + 0.12), sand_dark, Vector3(0, M_BASE * 0.5, -M_D * 0.5))
	_box(Vector3(M_W, roof_y - M_BASE, M_D), sand, Vector3(0, (roof_y + M_BASE) * 0.5, -M_D * 0.5))
	var side_from := M_TOWER_Z - M_TOWER * 0.5
	var side_long := M_D + side_from
	var ground_h: float = M_FLOORS[0]
	var walls: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(0, M_BASE, 0))]
	for s: int in [-1, 1]:
		walls.append(Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(s * half, M_BASE, side_from - side_long * 0.5)))
	for k in walls.size():
		var across := front if k == 0 else side_long
		_m_ashlar(walls[k], Vector2(across, ground_h), 0.16, 0.4, joint)
		_m_ashlar(walls[k].translated_local(Vector3(0, ground_h, 0)), Vector2(across, roof_y - M_BASE - ground_h), 0.12, 0.3, joint)
	# The bands between the floors (the first a frieze), the pilasters on
	# each floor with their capitals, on the front and down the sides.
	for f in range(1, M_FLOORS.size()):
		var y := _m_floor_y(f)
		var tall := 0.1 if f == 1 else 0.07
		_box(Vector3(M_W + 0.06, tall, M_D + 0.06), trim, Vector3(0, y, -M_D * 0.5))
		_box(Vector3(M_W + 0.1, 0.025, M_D + 0.1), trim, Vector3(0, y + tall * 0.5 + 0.0125, -M_D * 0.5))
	for f in M_FLOORS.size():
		var foot := _m_floor_y(f) + (0.07 if f > 0 else 0.0)
		var tall := _m_floor_y(f + 1) - foot - (0.05 if f == 0 else 0.035 if f < M_FLOORS.size() - 1 else 0.13)
		for x: float in M_PILASTERS_X:
			_m_part(Vector3(0.1, tall, 0.035), trim, Vector3(x, foot + tall * 0.5, 0.017))
			_m_part(Vector3(0.14, 0.04, 0.05), trim, Vector3(x, foot + tall - 0.02, 0.025))
		for s: int in [-1, 1]:
			for z: float in M_SIDE_PILASTERS_Z:
				_m_part(Vector3(0.035, tall, 0.1), trim, Vector3(s * (half + 0.017), foot + tall * 0.5, z))
				_m_part(Vector3(0.05, 0.04, 0.14), trim, Vector3(s * (half + 0.025), foot + tall - 0.02, z))
	# The great cornice on its corbels, the battlements on it, the roof.
	_box(Vector3(M_W + 0.36, 0.1, M_D + 0.36), trim, Vector3(0, roof_y + 0.13, -M_D * 0.5))
	var x0 := -half
	while x0 <= half:
		_m_part(Vector3(0.06, 0.08, 0.16), trim, Vector3(x0, roof_y + 0.04, 0.06))
		x0 += 0.2
	for s: int in [-1, 1]:
		var z0 := side_from
		while z0 >= -M_D:
			_m_part(Vector3(0.16, 0.08, 0.06), trim, Vector3(s * (half + 0.06), roof_y + 0.04, z0))
			z0 -= 0.2
	var deck := roof_y + 0.18
	var e := 0.12
	_m_battlement(Vector3(-front * 0.5, deck, e), Vector3(front * 0.5, deck, e), trim)
	for s: int in [-1, 1]:
		_m_battlement(Vector3(s * (half + e), deck, side_from), Vector3(s * (half + e), deck, -M_D - e), trim)
	_m_battlement(Vector3(half + e, deck, -M_D - e), Vector3(-half - e, deck, -M_D - e), trim)
	_box(Vector3(M_W + 0.2, 0.02, M_D + 0.2), _shade(M_SAND_DARK), Vector3(0, deck + 0.01, -M_D * 0.5))
	var roof := PrismMesh.new()
	roof.size = Vector3(M_D - 1.0, 0.3, M_W - 1.4)
	var tiles := _mesh(roof, _shade(M_TILE), Vector3(0, deck + 0.15, -M_D * 0.5 - 0.1))
	tiles.rotation.y = PI * 0.5
	# The towers on the front corners.
	for s: int in [-1, 1]:
		_m_tower(Vector3(s * half, 0, M_TOWER_Z), s, tower_stone, trim, accent, rng, taken.has(_m_key(0, s * half, 2)))
	# The door: a stone frame, the door in the museum's colour studded in
	# gold, lit round its edge when open; a cornice over it.
	_box(Vector3(0.66, 0.66, 0.05), trim, Vector3(0, M_BASE + 0.33, 0.015))
	_box(Vector3(0.48, 0.55, 0.04), accent.darkened(0.3), Vector3(0, M_BASE + 0.275, 0.03))
	for k in 3:
		_m_part(Vector3(0.012, 0.55, 0.01), _shade(WOOD), Vector3((k - 1) * 0.12, M_BASE + 0.275, 0.052))
	for x: float in [-0.18, -0.06, 0.06, 0.18]:
		for j in 3:
			_m_part(Vector3(0.025, 0.025, 0.02), _shade(GOLD), Vector3(x, M_BASE + 0.12 + j * 0.17, 0.055))
	if open:
		_glow(Vector3(0.52, 0.03, 0.03), LIT, Vector3(0, M_BASE + 0.565, 0.04), 1.5)
	_box(Vector3(0.82, 0.07, 0.1), trim, Vector3(0, M_BASE + 0.7, 0.04))
	# The bench along its foot, each side of the door.
	for s: int in [-1, 1]:
		_box(Vector3(1.05, 0.2, 0.18), sand_dark, Vector3(s * 1.28, 0.1, 0.12))
		_box(Vector3(1.09, 0.03, 0.22), trim, Vector3(s * 1.28, 0.215, 0.12))
	# Its name on the frieze under the cornice.
	_box(Vector3(front, 0.13, 0.03), trim, Vector3(0, roof_y - 0.065, 0.015))
	var label := Label3D.new()
	label.text = String(Story.museum(museum).name).to_upper()
	label.font_size = 44
	label.pixel_size = 0.0021
	label.outline_size = 0
	label.modulate = WOOD if open else WOOD.lightened(0.2)
	label.position = Vector3(0, roof_y - 0.065, 0.032)
	label.width = 3.0 / 0.0021
	add_child(label)
	# The big job's balcony: a slab, a railing hung with a cloth in the
	# museum's colour, gold along its foot.
	var noble := _m_floor_y(1)
	var slab_y := noble + 0.08
	_box(Vector3(M_BIG.x + 0.4, 0.05, 0.28), trim, Vector3(0, slab_y, 0.14))
	for k in 5:
		_m_part(Vector3(0.035, 0.12, 0.035), trim, Vector3((k - 2) * 0.2, slab_y + 0.085, 0.26))
	_box(Vector3(M_BIG.x + 0.4, 0.035, 0.05), trim, Vector3(0, slab_y + 0.16, 0.26))
	_box(Vector3(M_BIG.x + 0.1, 0.12, 0.012), accent, Vector3(0, slab_y + 0.08, 0.29))
	_box(Vector3(M_BIG.x + 0.1, 0.025, 0.014), _shade(GOLD), Vector3(0, slab_y + 0.03, 0.29))
	# The crest on the top floor, over the big job's window: a shield in the
	# museum's colour edged in gold, a croquette on it.
	var crest_y := _m_floor_y(2) + 0.34
	_box(Vector3(0.34, 0.26, 0.02), _shade(GOLD), Vector3(0, crest_y, 0.01))
	var point := PrismMesh.new()
	point.size = Vector3(0.34, 0.16, 0.02)
	_mesh(point, _shade(GOLD), Vector3(0, crest_y - 0.21, 0.01)).rotation.z = PI
	_box(Vector3(0.28, 0.22, 0.03), accent, Vector3(0, crest_y + 0.005, 0.02))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.28, 0.12, 0.03)
	_mesh(tip, accent, Vector3(0, crest_y - 0.165, 0.02)).rotation.z = PI
	var croquette := _mesh(_ball(0.06), _shade(M_CROQUETTE), Vector3(0, crest_y - 0.02, 0.045))
	croquette.scale = Vector3(1.3, 0.75, 0.6)
	# The windows: two-light ones on the noble floors of the front and down
	# both sides, little barred ones on the ground floor; but where a room is
	# (it has its own) and in the middle (the big job's and the crest).
	for f: int in [1, 2]:
		for x: float in M_BAYS_X:
			if x != 0.0 and not taken.has(_m_key(0, x, f)):
				_m_bifora(_m_slot(0, x, f, M_WINDOW), M_WINDOW, 0.0, _m_look(rng))
		for side: int in [-1, 1]:
			for z: float in M_SIDE_Z:
				if not taken.has(_m_key(side, z, f)):
					_m_bifora(_m_slot(side, z, f, M_WINDOW), M_WINDOW, side * PI * 0.5, _m_look(rng))
	for x: float in M_BAYS_X:
		if x != 0.0:
			_m_grille(Vector3(x, M_BASE + 0.45, 0.0), 0.0, open and rng.randf() < 0.3)
	for side: int in [-1, 1]:
		for z: float in M_SIDE_Z:
			_m_grille(Vector3(side * half, M_BASE + 0.45, z), side * PI * 0.5, open and rng.randf() < 0.3)
	# The rooms: some of the windows (M_ROOMS), the big job's the balcony's.
	# Only one reached shows as a room: clear glass lit up warm, nothing in it
	# (and the crown on the crest for the big job's); the rest are stained
	# glass like any other window, and nothing to pick.
	var boss_at := _m_slot(0, 0.0, 1, M_BIG)
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var at := boss_at
		var turn := 0.0
		var size := M_BIG
		if not r.boss:
			var s: Dictionary = M_ROOMS[mini(normal, M_ROOMS.size() - 1)]
			normal += 1
			size = M_WINDOW
			at = _m_slot(s.side, s.across, s.floor, size)
			turn = s.side * PI * 0.5
		var shown: bool = open and r.has("shape") and bool(r.get("open", false))
		var w := _m_bifora(at, size, turn, "room" if shown else _m_look(rng))
		var node: Node3D = w.node
		# Nothing in it: the piece's place, kept empty.
		var piece := Node3D.new()
		piece.position = Vector3(0, -size.y * 0.18, 0.14)
		node.add_child(piece)
		if shown and r.boss:
			var crown := Node3D.new()
			crown.position = Vector3(0, crest_y + 0.2 - at.y, 0.05)
			node.add_child(crown)
			CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD, 1.1)
		windows.append({"node": node, "back": w.back, "glass": w.glass, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": size, "frame": w.frame, "stone": w.stone, "arch": true, "face": node.basis})
	_m_flush()


## The floor f's foot (0 the ground floor's; past the last, the roof's).
func _m_floor_y(f: int) -> float:
	var y := M_BASE
	for k in mini(f, M_FLOORS.size()):
		y += M_FLOORS[k]
	return y


## Where a window of the middle-ages museum goes: on its front (side 0,
## across its x) or down a side (-1, 1: across its z), on floor f, its
## glass's foot a little over the band; on the front, at a tower's middle,
## on the tower's front.
func _m_slot(side: int, across: float, f: int, size: Vector2) -> Vector3:
	var y := _m_floor_y(f) + 0.12 + size.y * 0.5
	if side == 0:
		var tower := absf(across) > M_W * 0.5 - 0.01
		return Vector3(across, y, M_TOWER_Z + M_TOWER * 0.5 if tower else 0.0)
	return Vector3(side * M_W * 0.5, y, across)


func _m_key(side: int, across: float, f: int) -> String:
	return "%d:%.2f:%d" % [side, across, f]


## A window not a room: its stained glass lit here and there.
func _m_look(rng: RandomNumberGenerator) -> String:
	return "lit" if open and rng.randf() < 0.45 else "dark"


## A tower on a front corner (s: -1 left, 1 right), its foot's middle at
## c: a battered foot, its walls with their joints, bands at the palace's
## floors, arrow slits, a two-light window high up on its front (but where
## a room is: room) and its outer side, a banner down its front; a gallery
## on corbels at the top, battlements round it, a pennant on a pole (the
## right one's waves).
func _m_tower(c: Vector3, s: int, stone: Color, trim: Color, accent: Color, rng: RandomNumberGenerator, room: bool) -> void:
	var hw := M_TOWER * 0.5
	_box(Vector3(M_TOWER + 0.16, 0.4, M_TOWER + 0.16), _shade(M_SAND_DARK), c + Vector3(0, 0.2, 0))
	_box(Vector3(M_TOWER, M_TOWER_H, M_TOWER), stone, c + Vector3(0, M_TOWER_H * 0.5, 0))
	var joint := _shade(M_JOINT)
	_m_ashlar(Transform3D(Basis.IDENTITY, c + Vector3(0, 0.4, hw)), Vector2(M_TOWER, M_TOWER_H - 0.4), 0.15, 0.32, joint)
	for side: int in [-1, 1]:
		_m_ashlar(Transform3D(Basis(Vector3.UP, side * PI * 0.5), c + Vector3(side * hw, 0.4, 0)), Vector2(M_TOWER, M_TOWER_H - 0.4), 0.15, 0.32, joint)
	for f: int in [1, 2]:
		_box(Vector3(M_TOWER + 0.05, 0.07, M_TOWER + 0.05), trim, c + Vector3(0, _m_floor_y(f), 0))
	# Its windows: slits low and high, a two-light one on the top floor, on
	# its front and on its outer side.
	for turn: float in [0.0, s * PI * 0.5]:
		var out := Basis(Vector3.UP, turn)
		for y: float in [0.6, M_TOWER_H - 0.45]:
			_m_part(Vector3(0.05, 0.3, 0.02), _shade(M_IRON), c + out * Vector3(0, y, hw + 0.005), out)
			_m_part(Vector3(0.12, 0.04, 0.03), trim, c + out * Vector3(0, y - 0.17, hw + 0.01), out)
		if turn == 0.0 and room:
			continue
		_m_bifora(c + out * Vector3(0, _m_floor_y(2) + 0.12 + M_WINDOW.y * 0.5, hw), M_WINDOW, turn, _m_look(rng))
	# The banner down its front, gold along its foot, a gold lozenge on it.
	var fz := c.z + hw
	_box(Vector3(0.36, 0.76, 0.02), accent, Vector3(c.x, _m_floor_y(1) + 0.48, fz + 0.012))
	_box(Vector3(0.36, 0.06, 0.024), _shade(GOLD), Vector3(c.x, _m_floor_y(1) + 0.13, fz + 0.013))
	_box(Vector3(0.44, 0.035, 0.05), POLE, Vector3(c.x, _m_floor_y(1) + 0.87, fz + 0.02))
	var lozenge := _box(Vector3(0.13, 0.13, 0.01), _shade(GOLD), Vector3(c.x, _m_floor_y(1) + 0.52, fz + 0.025))
	lozenge.rotation.z = PI * 0.25
	# The gallery on its corbels, the battlements round it.
	var g := M_TOWER_H
	_box(Vector3(M_TOWER + 0.22, 0.2, M_TOWER + 0.22), trim, c + Vector3(0, g + 0.1, 0))
	for k in 4:
		var face := Basis(Vector3.UP, k * PI * 0.5)
		for off: float in [-0.32, 0.0, 0.32]:
			_m_part(Vector3(0.08, 0.14, 0.12), trim, c + face * Vector3(off, g - 0.06, hw + 0.05), face)
	var ring := hw + 0.06
	var deck := g + 0.2
	_m_battlement(c + Vector3(-ring, deck, ring), c + Vector3(ring, deck, ring), trim)
	_m_battlement(c + Vector3(ring, deck, ring), c + Vector3(ring, deck, -ring), trim)
	_m_battlement(c + Vector3(ring, deck, -ring), c + Vector3(-ring, deck, -ring), trim)
	_m_battlement(c + Vector3(-ring, deck, -ring), c + Vector3(-ring, deck, ring), trim)
	# The pennant on its pole.
	_box(Vector3(0.03, 0.7, 0.03), POLE, c + Vector3(0, deck + 0.35, 0))
	var pennant := PrismMesh.new()
	pennant.size = Vector3(0.22, 0.46, 0.02)
	var flag := _mesh(pennant, _colour if open else accent, c + Vector3(0.23, deck + 0.58, 0))
	flag.rotation.z = -PI * 0.5
	if s > 0:
		flag.name = "Flag"


## Ashlar joints on a wall: at, its foot's middle on its face (its basis x
## along the wall, y up, z out of it); size across and up; courses course
## high, blocks block long, each course's joints half a block on.
func _m_ashlar(at: Transform3D, size: Vector2, course: float, block: float, colour: Color) -> void:
	var rows := maxi(1, int(round(size.y / course)))
	var step := size.y / rows
	for r in rows:
		var y := r * step
		if r > 0:
			_m_part(Vector3(size.x, 0.014, 0.01), colour, at * Vector3(0, y, 0.004), at.basis)
		var x := -size.x * 0.5 + block * (0.5 if r % 2 == 1 else 1.0)
		while x < size.x * 0.5 - 0.05:
			_m_part(Vector3(0.014, step, 0.01), colour, at * Vector3(x, y + step * 0.5, 0.004), at.basis)
			x += block


## Battlements from a to b, on the deck: a low wall and on it
## swallow-tailed merlons (the same seen from either side).
func _m_battlement(a: Vector3, b: Vector3, colour: Color) -> void:
	var along := (b - a).normalized()
	var turned := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var long := a.distance_to(b)
	_m_part(Vector3(long + 0.1, 0.1, 0.1), colour, (a + b) * 0.5 + Vector3(0, 0.05, 0), turned)
	var n := maxi(1, int(round(long / 0.32)))
	for k in n + 1:
		var at := a.lerp(b, float(k) / n) + Vector3(0, 0.1, 0)
		_m_part(Vector3(0.15, 0.12, 0.1), colour, at + Vector3(0, 0.06, 0), turned)
		for sx: int in [-1, 1]:
			var horn := turned * Basis(Vector3.BACK, -sx * 0.35)
			_m_part(Vector3(0.05, 0.09, 0.1), colour, at + turned * Vector3(sx * 0.05, 0.15, 0), horn)


## A two-light window, its middle (where its arch springs, less half its
## height) at `at`, turned `turn` round y from facing the front: a round
## arch of stone on its jambs, a sill and a keystone; in it, two arched
## lights with a column between them and a round one over them in the stone
## under the arch. look: "lit" or "dark" stained glass, or "room" (clear
## glass, lit). Returns {"node", "back" (the lights), "glass" (the round
## one), "frame", "stone"}.
func _m_bifora(at: Vector3, size: Vector2, turn: float, look: String) -> Dictionary:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = turn
	add_child(node)
	var stone := _shade(M_TRIM)
	var r := size.x * 0.5
	var frame: Array = []
	var arch := _mesh_in(node, _m_disc(r + 0.075, 0.04), stone, Vector3(0, size.y * 0.5, 0.0))
	arch.rotation.x = PI * 0.5
	frame.append(arch)
	for sx: int in [-1, 1]:
		frame.append(_box_in(node, Vector3(0.075, size.y + 0.02, 0.04), stone, Vector3(sx * (r + 0.0375), 0, 0.0)))
	frame.append(_box_in(node, Vector3(size.x + 0.22, 0.05, 0.1), stone, Vector3(0, -size.y * 0.5 - 0.03, 0.04)))
	frame.append(_box_in(node, Vector3(0.06, 0.09, 0.05), stone, Vector3(0, size.y * 0.5 + r + 0.035, 0.01)))
	var tympanum := _mesh_in(node, _m_disc(r, 0.02), stone.darkened(0.08), Vector3(0, size.y * 0.5, 0.012))
	tympanum.rotation.x = PI * 0.5
	var glass: Material = _lit_material(LIT, 0.9) if look == "room" else _m_stained(look == "lit")
	var lights := MeshInstance3D.new()
	lights.mesh = _m_lights_mesh(size.x, size.y)
	lights.material_override = glass
	lights.position = Vector3(0, 0, 0.026)
	node.add_child(lights)
	frame.append(_box_in(node, Vector3(M_MULLION, size.y, 0.04), stone, Vector3(0, 0, 0.045)))
	frame.append(_box_in(node, Vector3(0.075, 0.03, 0.05), stone, Vector3(0, size.y * 0.5, 0.045)))
	var eye_y := size.y * 0.5 + r * 0.6
	var eye_ring := _mesh_in(node, _m_disc(r * 0.34, 0.012), stone, Vector3(0, eye_y, 0.028))
	eye_ring.rotation.x = PI * 0.5
	frame.append(eye_ring)
	var eye := MeshInstance3D.new()
	eye.mesh = _m_disc(r * 0.24, 0.012)
	eye.material_override = glass
	eye.position = Vector3(0, eye_y, 0.034)
	eye.rotation.x = PI * 0.5
	node.add_child(eye)
	return {"node": node, "back": lights, "glass": eye, "frame": frame, "stone": arch.material_override}


## A little window of the ground floor, high up, with a grille: a stone
## frame, a cornice and a sill; the glass dark or lit behind iron bars.
func _m_grille(at: Vector3, turn: float, lit: bool) -> void:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = turn
	add_child(node)
	var stone := _shade(M_TRIM)
	var size := M_GRILLE
	_box_in(node, Vector3(size.x + 0.1, size.y + 0.1, 0.04), stone, Vector3(0, 0, 0.01))
	var glass := _box_in(node, Vector3(size.x, size.y, 0.03), GLASS_DARK, Vector3(0, 0, 0.022))
	if lit:
		glass.material_override = _lit_material(LIT, 0.55)
	_box_in(node, Vector3(size.x + 0.18, 0.05, 0.08), stone, Vector3(0, size.y * 0.5 + 0.075, 0.03))
	_box_in(node, Vector3(size.x + 0.14, 0.04, 0.08), stone, Vector3(0, -size.y * 0.5 - 0.07, 0.03))
	var iron := _shade(M_IRON)
	for k in 3:
		_m_part(Vector3(0.018, size.y, 0.018), iron, node.transform * Vector3((k - 1) * size.x * 0.3, 0, 0.045), node.basis)
	for y: float in [-size.y * 0.2, size.y * 0.2]:
		_m_part(Vector3(size.x, 0.018, 0.018), iron, node.transform * Vector3(0, y, 0.05), node.basis)


## The yard before the middle-ages museum: cobbles on a kerb; a dry moat
## before the door, a rubber duck in it, a little drawbridge over it on its
## chains; a brazier each side; a well on the left, a knight on the right.
func _m_yard(rng: RandomNumberGenerator) -> void:
	var w := M_W + 0.9
	_box(Vector3(w + 0.1, 0.03, M_YARD + 0.04), _shade(M_COBBLE_EDGE), Vector3(0, 0.015, M_YARD * 0.5))
	var cobble := 0.2
	var nx := int(w / cobble)
	var nz := int(M_YARD / cobble)
	for j in nz:
		for i in nx:
			var x := (i - (nx - 1) * 0.5 + (0.25 if j % 2 == 1 else -0.25)) * cobble
			var z := (j + 0.5) * cobble
			if absf(x) < 0.72 and z < 0.72:
				continue
			var at := Vector3(x + rng.randf_range(-0.012, 0.012), 0.035, z + rng.randf_range(-0.012, 0.012))
			var tone: Color = M_COBBLE[rng.randi() % M_COBBLE.size()]
			_m_part(Vector3(cobble - 0.035, 0.03, cobble - 0.035), _shade(tone), at, Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)))
	# The moat: a dark pit in stone kerbs, the duck, the drawbridge.
	var trim := _shade(M_TRIM)
	_box(Vector3(1.36, 0.012, 0.62), _shade(M_MOAT), Vector3(0, 0.03, 0.38))
	_m_part(Vector3(1.44, 0.06, 0.06), trim, Vector3(0, 0.05, 0.72))
	for sx: int in [-1, 1]:
		_m_part(Vector3(0.06, 0.06, 0.64), trim, Vector3(sx * 0.7, 0.05, 0.38))
	var duck := Node3D.new()
	duck.position = Vector3(0.45, 0.04, 0.42)
	duck.rotation.y = -0.6
	add_child(duck)
	_mesh_in(duck, _ball(0.065), _shade(M_DUCK), Vector3(0, 0.05, 0)).scale = Vector3(1, 0.8, 1.3)
	_mesh_in(duck, _ball(0.04), _shade(M_DUCK), Vector3(0, 0.12, 0.05))
	_box_in(duck, Vector3(0.04, 0.015, 0.04), _shade(M_FLAME), Vector3(0, 0.115, 0.1))
	var wood := _shade(WOOD.lightened(0.15))
	_box(Vector3(0.5, 0.04, 0.68), wood, Vector3(0, 0.08, 0.38))
	for k in 4:
		_m_part(Vector3(0.5, 0.01, 0.012), _shade(WOOD), Vector3(0, 0.102, 0.12 + k * 0.17))
	for sx: int in [-1, 1]:
		_m_link(Vector3(sx * 0.23, 0.1, 0.7), Vector3(sx * 0.3, M_BASE + 0.62, 0.05), _shade(M_IRON))
	# A brazier each side of it, burning.
	for sx: int in [-1, 1]:
		var at := Vector3(sx * 1.0, 0, 0.95)
		_mesh(_cone(0.035, 0.025, 0.55), _shade(M_IRON), at + Vector3(0, 0.275, 0))
		_mesh(_cone(0.05, 0.1, 0.08), _shade(M_IRON), at + Vector3(0, 0.59, 0))
		var fire := _mesh(_cone(0.08, 0.0, 0.2), M_FLAME, at + Vector3(0, 0.72, 0))
		var core := _mesh(_cone(0.045, 0.0, 0.14), GOLD, at + Vector3(0, 0.7, 0))
		if open:
			fire.material_override = _lit_material(M_FLAME, 2.5)
			core.material_override = _lit_material(GOLD, 3.0)
		else:
			fire.material_override = MenuStage._material(_shade(M_IRON))
			core.material_override = fire.material_override
	_m_well(Vector3(-1.7, 0, 1.8))
	var knight := Node3D.new()
	knight.position = Vector3(1.7, 0, 1.85)
	knight.rotation.y = -0.45
	add_child(knight)
	_m_knight(knight)


## A chain (a thin bar) from a to b.
func _m_link(a: Vector3, b: Vector3, colour: Color) -> void:
	var up := (b - a).normalized()
	var x := Vector3.RIGHT
	var z := x.cross(up).normalized()
	_m_part(Vector3(0.015, a.distance_to(b), 0.015), colour, (a + b) * 0.5, Basis(up.cross(z), up, z))


## A well: a round stone kerb, the water dark in it, two posts and a beam,
## a little tiled roof, a bucket on its rope.
func _m_well(at: Vector3) -> void:
	var stone := _shade(M_SAND_DARK)
	var wood := _shade(WOOD)
	_mesh(_cone(0.27, 0.27, 0.3), stone, at + Vector3(0, 0.15, 0))
	_mesh(_cone(0.3, 0.3, 0.05), _shade(M_TRIM), at + Vector3(0, 0.32, 0))
	_mesh(_cone(0.22, 0.22, 0.02), _shade(Color("#1c2a44")), at + Vector3(0, 0.34, 0))
	for sx: int in [-1, 1]:
		_box(Vector3(0.05, 0.6, 0.05), wood, at + Vector3(sx * 0.25, 0.6, 0))
	var beam := _mesh(_cone(0.022, 0.022, 0.56), wood, at + Vector3(0, 0.8, 0))
	beam.rotation.z = PI * 0.5
	var roof := PrismMesh.new()
	roof.size = Vector3(0.44, 0.2, 0.68)
	var tiles := _mesh(roof, _shade(M_TILE), at + Vector3(0, 1.0, 0))
	tiles.rotation.y = PI * 0.5
	_box(Vector3(0.012, 0.26, 0.012), _shade(M_IRON), at + Vector3(0, 0.66, 0))
	_mesh(_cone(0.06, 0.075, 0.1), _shade(POLE), at + Vector3(0, 0.49, 0))


## A knight in armour on a plinth, standing proud, a red plume on his helmet
## and a shield with a croquette on it; for a lance, a plunger held high.
func _m_knight(at: Node3D) -> void:
	var steel := _shade(M_STEEL)
	var dark := _shade(M_STEEL.darkened(0.35))
	var accent := _shade(_colour)
	_box_in(at, Vector3(0.52, 0.26, 0.52), _shade(M_SAND_DARK), Vector3(0, 0.13, 0))
	_box_in(at, Vector3(0.58, 0.04, 0.58), _shade(M_TRIM), Vector3(0, 0.28, 0))
	var k := Node3D.new()
	k.position = Vector3(0, 0.3, 0)
	k.scale = Vector3.ONE * 1.25
	at.add_child(k)
	for sx: int in [-1, 1]:
		_mesh_in(k, _cone(0.04, 0.045, 0.3), steel, Vector3(sx * 0.06, 0.17, 0))
		_box_in(k, Vector3(0.07, 0.04, 0.13), dark, Vector3(sx * 0.06, 0.02, 0.03))
	_mesh_in(k, _cone(0.14, 0.1, 0.12), dark, Vector3(0, 0.36, 0))
	_mesh_in(k, _ball(0.13), steel, Vector3(0, 0.52, 0)).scale = Vector3(1.0, 1.15, 0.8)
	for sx: int in [-1, 1]:
		_mesh_in(k, _ball(0.06), steel, Vector3(sx * 0.14, 0.62, 0))
	# The helmet, its visor's slit, the plume.
	_mesh_in(k, _cone(0.085, 0.08, 0.17), steel, Vector3(0, 0.78, 0))
	_mesh_in(k, _ball(0.08), steel, Vector3(0, 0.86, 0))
	_box_in(k, Vector3(0.12, 0.02, 0.02), M_IRON, Vector3(0, 0.8, 0.08))
	var plume := _mesh_in(k, _cone(0.04, 0.0, 0.22), accent, Vector3(0, 1.0, -0.04))
	plume.rotation.x = -0.45
	# The arm up with the plunger; the other with the shield.
	var arm := _box_in(k, Vector3(0.05, 0.24, 0.05), steel, Vector3(0.17, 0.74, 0.02))
	arm.rotation.z = -0.15
	_mesh_in(k, _cone(0.014, 0.014, 0.95), _shade(WOOD.lightened(0.3)), Vector3(0.2, 0.95, 0.05))
	_mesh_in(k, _ball(0.075), accent, Vector3(0.2, 1.44, 0.05)).scale = Vector3(1, 0.75, 1)
	_mesh_in(k, _cone(0.085, 0.085, 0.02), accent.darkened(0.2), Vector3(0.2, 1.4, 0.05))
	_box_in(k, Vector3(0.05, 0.22, 0.05), steel, Vector3(-0.16, 0.5, 0.02))
	_box_in(k, Vector3(0.18, 0.22, 0.025), accent, Vector3(-0.16, 0.46, 0.09))
	_box_in(k, Vector3(0.2, 0.03, 0.03), _shade(GOLD), Vector3(-0.16, 0.57, 0.09))
	_mesh_in(k, _ball(0.04), _shade(M_CROQUETTE), Vector3(-0.16, 0.45, 0.11)).scale = Vector3(1.3, 0.75, 0.6)


## A flat disc facing +y (turn it to face out of a wall).
func _m_disc(radius: float, thick: float) -> CylinderMesh:
	var d := CylinderMesh.new()
	d.top_radius = radius
	d.bottom_radius = radius
	d.height = thick
	d.radial_segments = 16
	d.rings = 0
	return d


## A small box to draw with the rest of its colour (_m_flush).
func _m_part(size: Vector3, colour: Color, at: Vector3, turned := Basis.IDENTITY) -> void:
	if not _m_parts.has(colour):
		_m_parts[colour] = []
	(_m_parts[colour] as Array).append(Transform3D(turned * Basis.from_scale(size), at))


func _m_flush() -> void:
	var cube := BoxMesh.new()
	for colour: Color in _m_parts:
		var list: Array = _m_parts[colour]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = cube
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = MenuStage._material(colour)
		add_child(mmi)
	_m_parts.clear()


## The two lights of a two-light window w across, h tall to where their
## arches spring: side by side, a column's width between them, each with its
## round top; one mesh, its UVs across each light (for the stained glass).
static func _m_lights_mesh(w: float, h: float) -> ArrayMesh:
	var key := Vector2(w, h)
	if _m_lights.has(key):
		return _m_lights[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lw := (w - M_MULLION) * 0.5
	var tall := h + lw * 0.5
	for sx: int in [-1, 1]:
		var cx := sx * (M_MULLION + lw) * 0.5
		var left := cx - lw * 0.5
		# Round it anticlockwise, seen from the front: the foot, up the right,
		# over the top.
		var pts: Array[Vector2] = [Vector2(left, -h * 0.5), Vector2(left + lw, -h * 0.5)]
		for k in 9:
			var a := PI * k / 8.0
			pts.append(Vector2(cx + cos(a) * lw * 0.5, h * 0.5 + sin(a) * lw * 0.5))
		for k in range(1, pts.size() - 1):
			# Godot's front faces wind clockwise.
			for p: Vector2 in [pts[0], pts[k + 1], pts[k]]:
				st.set_normal(Vector3.BACK)
				st.set_uv(Vector2((p.x - left) / lw, 1.0 - (p.y + h * 0.5) / tall))
				st.add_vertex(Vector3(p.x, p.y, 0))
	var mesh := st.commit()
	_m_lights[key] = mesh
	return mesh


## The stained glass, lit or dark (and darker with the museum shut).
func _m_stained(lit: bool) -> StandardMaterial3D:
	var key := "%s:%s" % [lit, open]
	if not _m_glass.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = _m_glass_image()
		m.albedo_color = Color.WHITE if lit else Color(0.36, 0.34, 0.46)
		if not open:
			m.albedo_color = m.albedo_color.darkened(SHUT)
		m.roughness = 0.3
		if open:
			# Lit, its colours glow through; dark, just a hint of them.
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission = Color.WHITE
			m.emission_energy_multiplier = 0.35 if lit else 0.06
		_m_glass[key] = m
	return _m_glass[key]


## Lozenges of coloured glass between lines of lead, a lead edge round it.
static func _m_glass_image() -> ImageTexture:
	if _m_glass_texture == null:
		var img := Image.create(48, 96, false, Image.FORMAT_RGB8)
		var cell := 12.0
		for y in 96:
			for x in 48:
				var u := (x + y) / cell
				var v := (x - y + 96) / cell
				var c: Color = M_LEAD
				var edge := x < 2 or x >= 46 or y < 2 or y >= 94
				if not edge and fposmod(u, 1.0) > 0.16 and fposmod(v, 1.0) > 0.16:
					c = M_STAINED[absi(int(floor(u)) * 7 + int(floor(v)) * 13) % M_STAINED.size()]
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		_m_glass_texture = ImageTexture.create_from_image(img)
	return _m_glass_texture


## Pick room i's window (-1 none): it lights up brighter, its piece turns.
func pick(i: int) -> void:
	picked = i
	for k in windows.size():
		var w: Dictionary = windows[k]
		if not w.open:
			continue
		var m: Material = _lit_material(LIT_PICKED if k == i else LIT, 1.7 if k == i else 0.9)
		# A room of its own look ("rest", and "glow" when picked): not lit up.
		if w.has("rest"):
			m = w.glow if k == i else w.rest
		(w.back as MeshInstance3D).material_override = m
		(w.glass as MeshInstance3D).material_override = m
		# Its frame in gold, lit (or as it says: "frame_glow").
		var gilt: Material = w.frame_glow if w.has("frame_glow") else _lit_material(GOLD, 1.4)
		for f in w.frame:
			(f as MeshInstance3D).material_override = gilt if k == i else w.stone


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


# --- The nature museum -------------------------------------------------------------

## The nature museum, a vertical forest: a dark tower whose floors are
## white balconies standing out from it, some far and some less, by turns
## floor to floor and bay to bay (a zigzag up it), each with a planter
## brimming with trees, bushes and flowers, vines hanging over some; a glass
## lobby at its foot; on its roof a meadow, solar panels, a little wind
## turbine, a giant snail and its name on a timber board; before it a lawn
## with a giant ladybird. Its rooms are holes among the green: wood-lined
## niches in the balconies, lit only softly (N_ROOMS, on its front and down
## the side the camera sees; the big job's the wide one at the top of its
## front, the crown over it on the name board). Only a room reached is a
## hole, its piece on a mossy stump in it; one not reached yet is a balcony
## like the rest.
## The tower is baked into one mesh, the plants one MultiMesh a kind.

## Its tower: across, deep (behind its front, at z 0); its lobby's height, a
## floor's and how many over it; a balcony's slab, how far one stands out
## (far or near, by turns); a planter's height and depth.
const N_W := 2.4
const N_D := 2.0
const N_LOBBY := 0.5
const N_FLOOR := 0.5
const N_FLOORS := 6
const N_SLAB := 0.07
const N_OUT := [0.5, 0.26]
const N_PLANTER := Vector2(0.17, 0.12)
## A room's hole and the big job's (across, tall).
const N_HOLE := Vector2(0.52, 0.42)
const N_BIG_HOLE := Vector2(0.7, 0.42)
## Where the rooms but the big job's are, in the rooms' order: on the front
## (face 0) or on the side the camera sees (face 1, +x), in which of its
## three bays (0 to 2, left to right as the camera sees them), on which
## floor (0 the first over the lobby). Spread over both and up the tower;
## any room past these, in the last. The big job's: the top floor's middle.
const N_ROOMS := [
	{"face": 0, "bay": 0, "floor": 0},
	{"face": 0, "bay": 2, "floor": 2},
	{"face": 1, "bay": 0, "floor": 1},
	{"face": 1, "bay": 2, "floor": 3},
]
const N_BOSS := {"face": 0, "bay": 1, "floor": N_FLOORS - 1}
## How far the lawn goes before it (its front at z 0), and the lot's half.
const N_LAWN := 2.8
## The name board on the roof: how high its middle, how far back.
const N_SIGN_Y := 0.38
const N_SIGN_Z := -0.12
const N_LOT := 2.8
## Its colours.
const N_CORE := Color("#34313e")
const N_GLASS := Color("#1b1c2c")
const N_MULLION := Color("#4b4858")
const N_WHITE := Color("#ece8f0")
const N_PLANTER_COLOUR := Color("#d2ccdb")
const N_WOOD := Color("#c89160")
const N_WOOD_DARK := Color("#7c5234")
const N_WOOD_GLOW := Color("#ffd9a0")
const N_MOSS := Color("#5f8f3e")
const N_GRASS := Color("#3b6a40")
const N_GRAVEL := Color("#9b8f8a")
const N_SOLAR := Color("#2e4288")
const N_LADYBIRD := Color("#dc3328")
const N_BLACK := Color("#241f2b")
const N_SHELL := Color("#dba35a")
const N_SHELL_DARK := Color("#9c6a36")
const N_SNAIL := Color("#bfc47e")
## How much lighter its leaves than the town's: the green has to stand out
## on the dark tower.
const N_LEAF_LIGHT := 0.14
const N_FLOWERS := [Color("#e27cb2"), Color("#f2d34a"), Color("#f4f0f6"), Color("#a07cf0")]

## The tower as it is gathered, baked into one mesh at the end.
var _n_body: NMesh
## The plants, [transform, tint] a kind: one MultiMesh each.
var _n_plants := {}
static var _n_prims := {}
static var _n_plant_meshes := {}
static var _n_look: StandardMaterial3D


## Triangles in one mesh, each corner its own colour (flat faces).
class NMesh:
	var verts := PackedVector3Array()
	var colours := PackedColorArray()

	## A primitive's triangles (MuseumBuilding._n_prim), moved by xf, in a colour.
	func add(tris: PackedVector3Array, xf: Transform3D, colour: Color) -> void:
		for v in tris:
			verts.append(xf * v)
			colours.append(colour)

	func commit() -> ArrayMesh:
		var normals := PackedVector3Array()
		normals.resize(verts.size())
		for i in range(0, verts.size(), 3):
			var n := (verts[i] - verts[i + 2]).cross(verts[i] - verts[i + 1]).normalized()
			normals[i] = n
			normals[i + 1] = n
			normals[i + 2] = n
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colours
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return mesh


## A wind turbine's rotor, always turning.
class NRotor:
	extends Node3D
	var speed := 1.6

	func _process(dt: float) -> void:
		rotation.z += dt * speed


func _nature(rooms: Array) -> void:
	_n_body = NMesh.new()
	_n_plants = {}
	var roof_y := N_LOBBY + N_FLOOR * N_FLOORS
	front_z = -N_D * 0.5
	look_y = roof_y * 0.68
	top = roof_y + 1.5
	var rng := RandomNumberGenerator.new()
	rng.seed = 7127 + museum
	# Which room goes where, and which are holes (the rooms reached).
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	var slots: Array[Dictionary] = []
	var holes := {}
	var normal := 0
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var s: Dictionary = N_BOSS
		if not r.boss:
			s = N_ROOMS[mini(normal, N_ROOMS.size() - 1)]
			normal += 1
		var shown: bool = open and r.has("shape") and bool(r.get("open", false))
		slots.append({"room": r, "slot": s, "shown": shown})
		if shown:
			holes[_n_key(s.face, s.bay, s.floor)] = N_BIG_HOLE if r.boss else N_HOLE
	# The lawn, the gravel path up to the door, the core of the tower.
	_n_part(Vector3(N_LOT * 2.0, 0.04, N_LOT * 2.0), N_GRASS, Vector3(0, 0.02, 0))
	_n_part(Vector3(0.8, 0.05, N_LAWN), N_GRAVEL, Vector3(0, 0.025, N_LAWN * 0.5))
	for k in 6:
		_n_part(Vector3(0.3, 0.06, 0.2), N_GRAVEL.lightened(0.15), Vector3(-0.18 + 0.36 * (k % 2), 0.03, 0.35 + k * 0.42))
	_n_part(Vector3(N_W, roof_y, N_D), N_CORE, Vector3(0, roof_y * 0.5, -N_D * 0.5))
	for k in 4:
		var face := _n_face(k)
		var wide := _n_width(k)
		var bay := wide / 3.0
		# The lobby: glass between timber posts.
		_n_part(Vector3(wide, N_LOBBY, 0.02), N_GLASS, Vector3(0, N_LOBBY * 0.5, 0.01), face)
		for p in 7:
			_n_part(Vector3(0.05, N_LOBBY, 0.05), N_WOOD, Vector3(-wide * 0.5 + 0.025 + p * (wide - 0.05) / 6.0, N_LOBBY * 0.5, 0.025), face)
		# Each floor's slab, bay by bay, far or near by turns; the storey's
		# dark glass behind it; on it, a planter full of plants or a hole.
		for f in N_FLOORS + 1:
			var y := N_LOBBY + f * N_FLOOR
			for b in 3:
				var u := (b - 1) * bay
				var hole: Vector2 = holes.get(_n_key(k, b, f), Vector2.ZERO)
				var far := hole != Vector2.ZERO or (f < N_FLOORS and (b + f + k) % 2 == 0)
				var out: float = N_OUT[0] if far else N_OUT[1]
				_n_part(Vector3(bay + 0.012, N_SLAB, out), N_WHITE, Vector3(u, y - N_SLAB * 0.5, out * 0.5), face)
				# Each bay's plants its own, whichever rooms are holes.
				rng.seed = 7127 + museum + k * 1000 + f * 10 + b
				if f < N_FLOORS:
					var storey := N_FLOOR - N_SLAB
					_n_part(Vector3(bay, storey, 0.02), N_GLASS, Vector3(u, y + storey * 0.5, 0.01), face)
					for m in 2:
						_n_part(Vector3(0.025, storey, 0.03), N_MULLION, Vector3(u - bay * 0.5 + (m + 1) * bay / 3.0, y + storey * 0.5, 0.02), face)
				if hole != Vector2.ZERO:
					_n_niche(face, u, y, bay, out, hole, rng)
				else:
					# Under a hole, no trees: nothing in front of a room.
					var trees := not holes.has(_n_key(k, b, f + 1))
					_n_planter(face, u, y, bay, out, rng, trees, f == N_FLOORS and k == 0)
	# The roof: a meadow with bushes, solar panels, a little wind turbine.
	rng.seed = 7127 + museum + 5000
	_n_roof(roof_y, rng)
	# The door, lit round its edge when open, under a timber lintel.
	_n_part(Vector3(0.42, 0.38, 0.04), WOOD, Vector3(0, 0.19 + 0.04, 0.04))
	if open:
		_glow(Vector3(0.48, 0.035, 0.03), LIT, Vector3(0, 0.44, 0.06), 1.5)
	_n_part(Vector3(0.6, 0.06, 0.06), N_WOOD_DARK, Vector3(0, 0.46, 0.05))
	# Its name on a timber board standing on the roof's front edge.
	for sx: int in [-1, 1]:
		_n_part(Vector3(0.05, 0.5, 0.05), N_WOOD_DARK, Vector3(sx * 0.85, roof_y + 0.25, N_SIGN_Z))
	_n_part(Vector3(2.0, 0.22, 0.05), N_WOOD_DARK, Vector3(0, roof_y + N_SIGN_Y, N_SIGN_Z))
	var board := Label3D.new()
	board.text = String(Story.museum(museum).name).to_upper()
	board.font_size = 48
	board.pixel_size = 0.0024
	board.outline_size = 0
	board.modulate = _shade(Color("#f4e6c8"))
	board.position = Vector3(0, roof_y + N_SIGN_Y, N_SIGN_Z + 0.03)
	add_child(board)
	# The lawn: bushes and flowers along the path, lamps, the giant bugs.
	for sx: int in [-1, 1]:
		for j in 4:
			var at := Vector3(sx * rng.randf_range(0.6, 0.75), 0.04, 0.5 + j * 0.62)
			_n_plant("bloom" if j % 2 == 0 else "bush", at, rng.randf_range(0.28, 0.38), rng)
		for j in 5:
			_n_plant("tree" if j % 2 == 0 else "birch", Vector3(sx * rng.randf_range(2.35, 2.6), 0.04, -2.2 + j * 1.1), rng.randf_range(0.9, 1.3), rng)
		var post := CylinderMesh.new()
		post.top_radius = 0.025
		post.bottom_radius = 0.035
		post.height = 0.7
		_mesh(post, Color("#2a2433"), Vector3(sx * 0.62, 0.35, 1.5))
		var head := SphereMesh.new()
		head.radius = 0.075
		head.height = 0.15
		var lamp := _mesh(head, LIT, Vector3(sx * 0.62, 0.74, 1.5))
		if open:
			lamp.material_override = _lit_material(LIT, 3.0)
	_n_ladybird(Transform3D(Basis(Vector3.UP, 0.7), Vector3(-1.85, 0.04, 1.2)))
	# The whole tower as one mesh, the plants as a MultiMesh a kind.
	var body := MeshInstance3D.new()
	body.mesh = _n_body.commit()
	body.material_override = _n_material()
	add_child(body)
	_n_body = null
	_n_flush_plants()
	# The rooms: a hole each where it is reached, its piece in it on a stump.
	var tall := N_FLOOR - N_SLAB
	for e in slots:
		var r: Dictionary = e.room
		var s: Dictionary = e.slot
		var shown: bool = e.shown
		var face := _n_face(s.face)
		var u: float = (int(s.bay) - 1) * _n_width(s.face) / 3.0
		var y: float = N_LOBBY + int(s.floor) * N_FLOOR
		var out: float = N_OUT[0]
		var size: Vector2 = N_BIG_HOLE if r.boss else N_HOLE
		var node := Node3D.new()
		node.transform = face * Transform3D(Basis.IDENTITY, Vector3(u, y + tall * 0.5, out + 0.01))
		add_child(node)
		var piece := Node3D.new()
		piece.position = Vector3(0, -size.y * 0.18, -out * 0.45)
		node.add_child(piece)
		var entry := {"node": node, "back": null, "glass": null, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": size, "frame": [], "stone": null, "arch": false, "face": node.basis}
		if shown:
			# Its back, warm wood softly lit (more when picked), and a timber
			# frame round its mouth (gold when picked).
			var back := _box_in(node, Vector3(size.x + 0.04, tall - 0.02, 0.02), _shade(N_WOOD), Vector3(0, 0, -out + 0.035))
			var rim := NMesh.new()
			for sx: int in [-1, 1]:
				rim.add(_n_prim("box"), _n_xf(Vector3(sx * (size.x * 0.5 + 0.03), 0, 0), Vector3(0.05, tall, 0.05)), _shade(N_WOOD_DARK))
			rim.add(_n_prim("box"), _n_xf(Vector3(0, tall * 0.5 - 0.025, 0), Vector3(size.x + 0.11, 0.05, 0.05)), _shade(N_WOOD_DARK))
			rim.add(_n_prim("box"), _n_xf(Vector3(0, -tall * 0.5 + 0.02, 0.01), Vector3(size.x + 0.11, 0.04, 0.07)), _shade(N_WOOD_DARK))
			var frame := MeshInstance3D.new()
			frame.mesh = rim.commit()
			frame.material_override = _n_material()
			node.add_child(frame)
			var model := LootModels.build(r.shape, Color(r.colour))
			model.scale = Vector3.ONE * (0.46 if r.boss else 0.38)
			piece.add_child(model)
			entry.back = back
			entry.glass = back
			entry.frame = [frame]
			entry.stone = frame.material_override
			entry.rest = _lit_material(_shade(N_WOOD), 0.18)
			back.material_override = entry.rest
			entry.glow = _lit_material(N_WOOD_GLOW, 0.5)
			if r.boss:
				# The big job's crown, on the name board over its hole.
				var crown := Node3D.new()
				crown.position = Vector3(0, roof_y + N_SIGN_Y + 0.24 - (y + tall * 0.5), N_SIGN_Z - out - 0.01)
				node.add_child(crown)
				CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD, 1.3)
		windows.append(entry)


func _n_key(face: int, bay: int, f: int) -> String:
	return "%d:%d:%d" % [face, bay, f]


## Face k of the tower (0 the front, 1 the right, 2 the back, 3 the left):
## its middle at the foot, turned so it looks out along its +z, x across it.
func _n_face(k: int) -> Transform3D:
	var origins: Array[Vector3] = [Vector3(0, 0, 0), Vector3(N_W * 0.5, 0, -N_D * 0.5), Vector3(0, 0, -N_D), Vector3(-N_W * 0.5, 0, -N_D * 0.5)]
	return Transform3D(Basis(Vector3.UP, k * PI * 0.5), origins[k])


func _n_width(k: int) -> float:
	return N_W if k % 2 == 0 else N_D


## A box of the tower: its size, colour (as open or shut) and middle, in a
## face's frame (or the building's).
func _n_part(s: Vector3, colour: Color, at: Vector3, frame := Transform3D.IDENTITY) -> void:
	_n_body.add(_n_prim("box"), frame * _n_xf(at, s), _shade(colour))


## A primitive of the tower (_n_prim): where, how big, turned how.
func _n_shape(kind: String, colour: Color, at: Vector3, s: Vector3, frame := Transform3D.IDENTITY, turn := Basis.IDENTITY) -> void:
	_n_body.add(_n_prim(kind), frame * _n_xf(at, s, turn), _shade(colour))


static func _n_xf(at: Vector3, s: Vector3, turn := Basis.IDENTITY) -> Transform3D:
	return Transform3D(turn * Basis.from_scale(s), at)


## A balcony's planter along its edge, full: trees where it stands far out
## (they reach up past the floor over it, which stands in; not with
## `trees` off), bushes and flowers where it is near; a vine over its edge
## here and there. `low`: only flowers (under the crown).
func _n_planter(face: Transform3D, u: float, y: float, bay: float, out: float, rng: RandomNumberGenerator, trees: bool, low: bool) -> void:
	var h := N_PLANTER.x
	var mid := out - N_PLANTER.y * 0.5
	_n_part(Vector3(bay - 0.03, h, N_PLANTER.y), N_PLANTER_COLOUR, Vector3(u, y + h * 0.5, mid), face)
	var far: bool = trees and out >= N_OUT[0]
	var n := maxi(2, roundi(bay / 0.28))
	for j in n:
		var at := Vector3(u - bay * 0.5 + (j + 0.5) * bay / n + rng.randf_range(-0.04, 0.04), y + h, mid)
		var kind := "bloom"
		var size := rng.randf_range(0.22, 0.3)
		if not low:
			var roll := rng.randf()
			if far and roll < 0.62:
				kind = ["tree", "tree", "pine", "birch", "autumn"][rng.randi() % 5]
				size = rng.randf_range(0.65, 0.95)
			else:
				kind = "bush" if roll < 0.8 else "bloom"
				size = rng.randf_range(0.26, 0.4)
		_n_plant(kind, face * at, size, rng)
	if not low and rng.randf() < 0.6:
		_n_plant("vine", face * Vector3(u + rng.randf_range(-bay * 0.35, bay * 0.35), y + h, out + 0.02), rng.randf_range(0.4, 0.7), rng)


## A room's hole in a balcony: lined with wood (the sides, its ceiling), a
## mossy floor, a stump for its piece; a bit of planter each side of it
## with a bush on it.
func _n_niche(face: Transform3D, u: float, y: float, bay: float, out: float, hole: Vector2, rng: RandomNumberGenerator) -> void:
	var tall := N_FLOOR - N_SLAB
	for sx: int in [-1, 1]:
		_n_part(Vector3(0.04, tall, out), N_WOOD, Vector3(u + sx * (hole.x * 0.5 + 0.02), y + tall * 0.5, out * 0.5), face)
	_n_part(Vector3(hole.x + 0.08, 0.02, out), N_WOOD, Vector3(u, y + tall - 0.01, out * 0.5), face)
	_n_part(Vector3(hole.x, 0.02, out - 0.02), N_MOSS, Vector3(u, y + 0.01, out * 0.5), face)
	var stump := tall * 0.5 - hole.y * 0.18
	_n_shape("trunk", N_WOOD_DARK, Vector3(u, y + stump * 0.5, out * 0.55), Vector3(0.2, stump, 0.2), face)
	_n_shape("cyl", N_MOSS, Vector3(u, y + stump + 0.005, out * 0.55), Vector3(0.15, 0.015, 0.15), face)
	var side := (bay - hole.x) * 0.5 - 0.06
	if side < 0.05:
		return
	var h := N_PLANTER.x
	for sx: int in [-1, 1]:
		var cu := u + sx * (bay * 0.5 - side * 0.5 - 0.015)
		_n_part(Vector3(side, h, N_PLANTER.y), N_PLANTER_COLOUR, Vector3(cu, y + h * 0.5, out - N_PLANTER.y * 0.5), face)
		_n_plant("bloom" if sx > 0 else "bush", face * Vector3(cu, y + h, out - N_PLANTER.y * 0.5), rng.randf_range(0.24, 0.3), rng)


## The roof: a meadow with bushes and a little tree or two, solar panels
## tilted to the sky, a giant snail, a little wind turbine at the back.
func _n_roof(roof_y: float, rng: RandomNumberGenerator) -> void:
	_n_part(Vector3(N_W - 0.1, 0.05, N_D - 0.1), N_GRASS, Vector3(0, roof_y + 0.025, -N_D * 0.5))
	for j in 3:
		for i in 2:
			var at := Vector3(-0.95 + i * 0.6, roof_y + 0.2, -1.1 - j * 0.3)
			_n_shape("box", N_SOLAR, at, Vector3(0.56, 0.03, 0.3), Transform3D.IDENTITY, Basis(Vector3.RIGHT, -0.5))
			_n_part(Vector3(0.03, 0.18, 0.03), N_MULLION, at - Vector3(0, 0.1, 0))
	for j in 5:
		_n_plant("bush" if j % 2 == 0 else "bloom", Vector3(rng.randf_range(0.1, 0.9), roof_y + 0.05, rng.randf_range(-1.8, -1.2)), rng.randf_range(0.3, 0.42), rng)
	_n_plant("tree", Vector3(-0.6, roof_y + 0.05, -0.5), 0.8, rng)
	# A giant snail on its way along the front edge.
	_n_snail(Transform3D(Basis(Vector3.UP, PI * 0.5).scaled(Vector3.ONE * 0.8), Vector3(0.5, roof_y + 0.05, -0.7)))
	# The wind turbine: a mast, its head, and the rotor facing the camera.
	var base := Vector3(0.85, roof_y + 0.05, -1.65)
	var mast := 1.0
	_n_shape("trunk", N_WHITE, base + Vector3(0, mast * 0.5, 0), Vector3(0.08, mast, 0.08))
	var turn := Basis(Vector3.UP, PI * 0.25)
	_n_shape("box", N_WHITE, base + Vector3(0, mast, 0), Vector3(0.1, 0.1, 0.26), Transform3D.IDENTITY, turn)
	var rotor := NRotor.new()
	rotor.transform = Transform3D(turn, base + Vector3(0, mast, 0) + turn * Vector3(0, 0, 0.16))
	rotor.speed = 1.6 if open else 0.0
	add_child(rotor)
	var blades := NMesh.new()
	blades.add(_n_prim("ball"), _n_xf(Vector3.ZERO, Vector3(0.08, 0.08, 0.1)), _shade(_colour))
	for k in 3:
		var a := Basis(Vector3.BACK, k * TAU / 3.0)
		blades.add(_n_prim("box"), Transform3D(a, Vector3.ZERO) * _n_xf(Vector3(0, 0.32, 0), Vector3(0.06, 0.6, 0.015)), _shade(N_WHITE))
	var bm := MeshInstance3D.new()
	bm.mesh = blades.commit()
	bm.material_override = _n_material()
	rotor.add_child(bm)


## A giant ladybird on the lawn, at `at` (its head along +z): a red shell
## with black spots and a black line down it, a black head with two
## antennae and six little legs.
func _n_ladybird(at: Transform3D) -> void:
	_n_shape("half", N_LADYBIRD, Vector3(0, 0.12, 0), Vector3(0.8, 0.62, 1.0), at)
	_n_part(Vector3(0.025, 0.02, 1.0), N_BLACK, Vector3(0, 0.44, -0.02), at)
	_n_shape("ball", N_BLACK, Vector3(0, 0.22, 0.5), Vector3(0.42, 0.34, 0.34), at)
	for sx: int in [-1, 1]:
		_n_shape("ball", Color.WHITE, Vector3(sx * 0.1, 0.3, 0.64), Vector3(0.1, 0.1, 0.06), at)
		_n_shape("ball", N_BLACK, Vector3(sx * 0.1, 0.3, 0.67), Vector3(0.05, 0.05, 0.03), at)
		_n_shape("cyl", N_BLACK, Vector3(sx * 0.14, 0.5, 0.6), Vector3(0.02, 0.36, 0.02), at, Basis(Vector3.BACK, -sx * 0.45) * Basis(Vector3.RIGHT, 0.4))
		_n_shape("ball", N_BLACK, Vector3(sx * 0.22, 0.66, 0.66), Vector3(0.07, 0.07, 0.07), at)
		for j in 3:
			_n_shape("cyl", N_BLACK, Vector3(sx * 0.4, 0.07, -0.25 + j * 0.25), Vector3(0.03, 0.2, 0.03), at, Basis(Vector3.BACK, sx * 1.1))
	# The spots: on the shell's curve, three a side.
	var spots: Array[Vector2] = [Vector2(0.17, 0.25), Vector2(0.24, -0.08), Vector2(0.14, -0.33)]
	for sx: int in [-1, 1]:
		for p in spots:
			var x := sx * p.x
			var z := p.y
			var r := Vector2(x / 0.4, z / 0.5)
			var h := sqrt(maxf(0.0, 1.0 - r.length_squared()))
			var n := Vector3(x / 0.16, h / 0.31, z / 0.25).normalized()
			var spot := Basis.looking_at(n) * Basis(Vector3.RIGHT, PI * 0.5)
			_n_shape("cyl", N_BLACK, Vector3(x, 0.12 + h * 0.31, z) + n * 0.005, Vector3(0.12, 0.02, 0.12), at, spot)


## A giant snail, at `at` (its head along +z): a long soft body,
## a big spiral shell on its back, two stalks with its eyes on top.
func _n_snail(at: Transform3D) -> void:
	_n_shape("ball", N_SNAIL, Vector3(0, 0.1, 0.05), Vector3(0.32, 0.2, 1.1), at)
	_n_shape("ball", N_SNAIL, Vector3(0, 0.22, 0.48), Vector3(0.24, 0.26, 0.26), at)
	_n_shape("ball", N_SHELL, Vector3(0, 0.44, -0.12), Vector3(0.36, 0.62, 0.62), at)
	_n_shape("ring", N_SHELL_DARK, Vector3(0, 0.44, -0.12), Vector3(0.62, 0.5, 0.62), at, Basis(Vector3.BACK, PI * 0.5))
	_n_shape("ring", N_SHELL_DARK, Vector3(0.02, 0.46, -0.1), Vector3(0.36, 0.5, 0.36), at, Basis(Vector3.BACK, PI * 0.5))
	_n_shape("ball", N_SHELL_DARK, Vector3(0.05, 0.47, -0.08), Vector3(0.12, 0.14, 0.14), at)
	for sx: int in [-1, 1]:
		_n_shape("cyl", N_SNAIL, Vector3(sx * 0.06, 0.42, 0.56), Vector3(0.03, 0.3, 0.03), at, Basis(Vector3.BACK, -sx * 0.3))
		_n_shape("ball", Color.WHITE, Vector3(sx * 0.1, 0.57, 0.57), Vector3(0.09, 0.09, 0.09), at)
		_n_shape("ball", N_BLACK, Vector3(sx * 0.1, 0.57, 0.61), Vector3(0.045, 0.045, 0.03), at)


## A plant of a kind (_n_plant_mesh) standing at `at`, `size` tall: its own
## width, turn and tint (shut, darker).
func _n_plant(kind: String, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var wide := size * rng.randf_range(0.85, 1.2)
	var turn := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(wide, size, wide))
	var v := rng.randf_range(0.85, 1.12)
	var tint := _shade(Color(v * rng.randf_range(0.95, 1.05), v, v * rng.randf_range(0.95, 1.05)))
	if not _n_plants.has(kind):
		_n_plants[kind] = []
	(_n_plants[kind] as Array).append([Transform3D(turn, at), tint])


func _n_flush_plants() -> void:
	for kind: String in _n_plants:
		var list: Array = _n_plants[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _n_plant_mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _n_material()
		if kind in ["bush", "bloom", "vine"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	_n_plants = {}


## A kind of plant, about a unit tall, low-poly with flat faces like the
## town's (TownBuilder's colours): a tree, a pine, a birch, an autumn tree,
## a bush, a bush in flower, or a vine hanging down from its top.
static func _n_plant_mesh(kind: String) -> ArrayMesh:
	if _n_plant_meshes.has(kind):
		return _n_plant_meshes[kind]
	var st := NMesh.new()
	var leaf := _n_prim("leaf")
	match kind:
		"tree", "autumn":
			var leaves := (TownBuilder.OAK_GREEN if kind == "tree" else TownBuilder.AUTUMN_LEAVES).lightened(N_LEAF_LIGHT)
			st.add(_n_prim("trunk"), _n_xf(Vector3(0, 0.22, 0), Vector3(0.12, 0.45, 0.12)), TownBuilder.TRUNK)
			st.add(leaf, _n_xf(Vector3(0, 0.62, 0), Vector3.ONE * 0.66), leaves)
			st.add(leaf, _n_xf(Vector3(0.18, 0.8, 0.06), Vector3.ONE * 0.46), leaves.lightened(0.08))
			st.add(leaf, _n_xf(Vector3(-0.15, 0.76, -0.1), Vector3.ONE * 0.42), leaves.darkened(0.08))
		"pine":
			st.add(_n_prim("trunk"), _n_xf(Vector3(0, 0.15, 0), Vector3(0.14, 0.3, 0.14)), TownBuilder.TRUNK)
			for k in 3:
				st.add(_n_prim("cone"), _n_xf(Vector3(0, 0.42 + k * 0.2, 0), Vector3(0.66 - k * 0.17, 0.42, 0.66 - k * 0.17)), TownBuilder.PINE_GREEN.lightened(N_LEAF_LIGHT + k * 0.06))
		"birch":
			st.add(_n_prim("trunk"), _n_xf(Vector3(0, 0.4, 0), Vector3(0.07, 0.8, 0.07)), TownBuilder.BIRCH_BARK)
			st.add(leaf, _n_xf(Vector3(0, 0.74, 0), Vector3(0.44, 0.66, 0.44)), TownBuilder.BIRCH_GREEN.lightened(N_LEAF_LIGHT))
		"bush", "bloom":
			st.add(leaf, _n_xf(Vector3(0, 0.3, 0), Vector3(1.0, 0.7, 1.0)), TownBuilder.BUSH_GREEN.lightened(N_LEAF_LIGHT + 0.08))
			st.add(leaf, _n_xf(Vector3(0.3, 0.26, 0.1), Vector3(0.64, 0.5, 0.64)), TownBuilder.BUSH_GREEN.lightened(N_LEAF_LIGHT + 0.16))
			if kind == "bloom":
				for k in 7:
					var a := k * TAU / 7.0 + 0.4
					st.add(leaf, _n_xf(Vector3(cos(a) * 0.36, 0.42 + 0.1 * sin(a * 3.0), sin(a) * 0.36), Vector3.ONE * 0.2), N_FLOWERS[k % N_FLOWERS.size()])
		"vine":
			for k in 4:
				st.add(leaf, _n_xf(Vector3(0.06 * sin(k * 2.1), -0.12 - k * 0.22, 0.03 * k), Vector3(0.36, 0.34, 0.26) * (1.0 - k * 0.15)), TownBuilder.POPLAR_GREEN.lightened(N_LEAF_LIGHT + 0.05 + k * 0.03))
	var mesh := st.commit()
	_n_plant_meshes[kind] = mesh
	return mesh


## A primitive's triangles, a unit across (and tall): a box, a ball (and a
## rougher one for leaves), a half ball, a cylinder, a cone, a tapered
## trunk, a ring.
static func _n_prim(kind: String) -> PackedVector3Array:
	if _n_prims.has(kind):
		return _n_prims[kind]
	var mesh: PrimitiveMesh
	match kind:
		"box":
			mesh = BoxMesh.new()
		"ball", "leaf", "half":
			var b := SphereMesh.new()
			b.radius = 0.5
			b.height = 1.0
			b.radial_segments = 6 if kind == "leaf" else 12
			b.rings = 3 if kind == "leaf" else 6
			if kind == "half":
				b.height = 0.5
				b.is_hemisphere = true
			mesh = b
		"ring":
			var t := TorusMesh.new()
			t.inner_radius = 0.38
			t.outer_radius = 0.5
			t.rings = 16
			t.ring_segments = 6
			mesh = t
		_:
			var c := CylinderMesh.new()
			c.bottom_radius = 0.5
			c.top_radius = 0.0 if kind == "cone" else (0.35 if kind == "trunk" else 0.5)
			c.height = 1.0
			c.radial_segments = 6 if kind == "cone" else 8
			c.rings = 0
			mesh = c
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var tris := PackedVector3Array()
	for i in index:
		tris.append(verts[i])
	_n_prims[kind] = tris
	return tris


## The look of all that is baked: its own colours, lit like the rest.
static func _n_material() -> StandardMaterial3D:
	if _n_look == null:
		_n_look = StandardMaterial3D.new()
		_n_look.vertex_color_use_as_albedo = true
		_n_look.vertex_color_is_srgb = true
		_n_look.roughness = 0.6
		_n_look.rim_enabled = true
		_n_look.rim = 0.3
		_n_look.rim_tint = 0.6
	return _n_look
