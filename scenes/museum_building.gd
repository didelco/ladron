class_name MuseumBuilding
extends Node3D
## Coordina el edificio de cada museo de la ciudad y sus cinco habitaciones.
## Cada estilo añade sus nodos mediante scenes/museum/buildings/:
## prehistory_building, antiquity_building, contemporary_building y
## middle_ages_building. Naturaleza conserva aquí su estructura y delega
## jardín/plantas en nature_decoration; _hall es el estilo de reserva.
##
## Este nodo conserva los parámetros, materiales y mallas compartidos,
## la posición de cámara (front_z/look_y/top/view) y la lista windows,
## ordenada según las habitaciones. Una habitación alcanzada se ilumina;
## pick selecciona su ventana y _process anima su pieza y la bandera.
## Los helpers antiguos delegan en los componentes para conservar su API.
##
## El frente apunta a +z; x cruza la fachada y el origen está a nivel del
## suelo. Cada ventana incluye su orientación (face) para CityStage.

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
## The windows across its back (x), a row of them on each floor.
const P_BACK_X := [-2.05, -1.45, -0.75, 0.0, 0.75, 1.45, 2.05]
## Where the rooms but the big job's are, in the rooms' order: on the front
## (side 0, across: x), down a side (1 the right, +x, -1 the left; across:
## z) or on the back (side 2, across: x), and on which floor. One a wall
## and each on its own floor, so the camera goes round the building from
## one to the next; any room past these, in the last.
const P_ROOMS := [
	{"side": 0, "across": -2.05, "floor": 1},
	{"side": 1, "across": -1.3, "floor": 2},
	{"side": 2, "across": 0.75, "floor": 1},
	{"side": -1, "across": -0.62, "floor": 0},
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
## The serliana across the back (x).
const A_BACK_X := [-1.55, 0.0, 1.55]
## Where the rooms but the big job's are, as P_ROOMS (all on the main
## floor): the serliana right of the portico, then round the villa: the
## middle one down its right side, the middle one of its back, the middle
## one down its left side; the big job's is behind the door, under the
## portico.
const A_ROOMS := [
	{"side": 0, "across": 1.87},
	{"side": 1, "across": -1.4},
	{"side": 2, "across": 0.0},
	{"side": -1, "across": -1.4},
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
## Half a body high: the plinth that lifts the ground floor clear of the
## water, the moat passing under it.
const M_BASE := 0.4
## The ground floor stands taller than before: the drawbridge has further to
## swing down from its door to the yard.
const M_FLOORS := [1.05, 0.92, 0.9]
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
## windows on a noble floor of its front, down a side or across its back
## (side 2, across its x); down a side at the tower's middle (M_TOWER_Z),
## high on the tower's outer side. Round the palace, one a wall: its front,
## the right tower, its back, its left side.
const M_ROOMS := [
	{"side": 0, "across": -1.45, "floor": 1},
	{"side": 1, "across": M_TOWER_Z, "floor": 2},
	{"side": 2, "across": -0.75, "floor": 1},
	{"side": -1, "across": -1.85, "floor": 2},
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
const M_RIVER := Color("#264456")
const M_RIVER_LIT := Color("#3a6a82")
const M_STEEL := Color("#a9b2c4")
const M_FLAME := Color("#ff9a3a")
const M_DUCK := Color("#ffd23a")
const M_CROQUETTE := Color("#c98a3e")

## Constructores de cada estilo; comparten los helpers y el estado de este edificio.
var prehistory_building := PrehistoryBuilding.new(self)
var antiquity_building := AntiquityBuilding.new(self)
var contemporary_building := ContemporaryBuilding.new(self)
var middle_ages_building := MiddleAgesBuilding.new(self)

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
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0, PLINTH + H + 0.6 + DOME_R * 0.8 + 0.55, -0.25)
	add_child(flag)
	_box_in(flag, Vector3(0.45, 0.26, 0.02), _colour if open else deep, Vector3(0.225, 0, 0))
	# A banner in its colour at each end, gold along its foot.
	for s in [-1, 1]:
		_box(Vector3(0.36, 0.95, 0.03), _colour if open else deep, Vector3(s * 2.6, PLINTH + H - 0.62, D * 0.5 + 0.3))
		_box(Vector3(0.36, 0.08, 0.035), GOLD.darkened(0.0 if open else SHUT), Vector3(s * 2.6, PLINTH + H - 1.08, D * 0.5 + 0.3))
		_box(Vector3(0.42, 0.04, 0.05), POLE, Vector3(s * 2.6, PLINTH + H - 0.12, D * 0.5 + 0.3))
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


func _prehistory(rooms: Array) -> void:
	prehistory_building.build(rooms)


func _slot_at(side: int, across: float, f: int) -> Vector3:
	return prehistory_building.window_position(side, across, f)


func _slot_turn(side: int) -> float:
	return prehistory_building.window_rotation(side)


func _slot_key(side: int, across: float, f: int) -> String:
	return prehistory_building.window_key(side, across, f)


func _p_window(at: Vector3, size: Vector2, lit: bool, turn: float) -> Dictionary:
	return prehistory_building.plain_window(at, size, lit, turn)


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


func _dino_model(at: Node3D, name: String, tall: float) -> void:
	prehistory_building.dinosaur_model(at, name, tall)


func _antiquity(rooms: Array) -> void:
	antiquity_building.build(rooms)


func _a_dome(roof_top: float, z: float) -> float:
	return antiquity_building.dome(roof_top, z)


func _a_slot_at(side: int, across: float, y: float) -> Vector3:
	return antiquity_building.window_position(side, across, y)


func _serliana(at: Vector3, lit: bool, room: bool, turn := 0.0) -> Dictionary:
	return antiquity_building.arched_window(at, lit, room, turn)


func _front_door(open_door: bool) -> Dictionary:
	return antiquity_building.front_door(open_door)


func _cypress(at: Vector3) -> void:
	antiquity_building.cypress(at)


func _statue(model_name: String, tall: float, at: Vector3, turn: float, hat: bool, gag := true) -> void:
	antiquity_building.statue(model_name, tall, at, turn, hat, gag)


func _points_of(model: Node3D) -> PackedVector3Array:
	return antiquity_building.model_points(model)


func _mop(jar: Node3D) -> void:
	antiquity_building.mop(jar)


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
## museum's name, a giant rubber duck on one of the terraces the steps back
## leave; before it a square of polished concrete with long benches, a
## giant banana and a banner.
##
## Each room is a floor, a whole box, in order up the tower (C_FLOORS), the
## big job's the top one; each seen from its own wall (C_FACES), round the
## tower as it goes up. Nothing of what's inside is seen: a room reached
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
## Which of its walls each floor's room is seen from, bottom to top (0 the
## front, 1 the right, 2 the back, 3 the left): up the tower the camera goes
## round it. The big job's, the top one, from the front.
const C_FACES := [0, 1, 2, 3, 0]
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
	contemporary_building.build(rooms)


func _c_box(k: int, y0: float, bits: Array) -> MeshInstance3D:
	return contemporary_building.floor_box(k, y0, bits)


func _c_joint(k: int, y0: float, lit: bool, bits: Array) -> MeshInstance3D:
	return contemporary_building.floor_joint(k, y0, lit, bits)


func _c_lobby(bits: Array) -> void:
	contemporary_building.lobby(bits)


func _c_square(rng: RandomNumberGenerator, bits: Array) -> void:
	contemporary_building.square(rng, bits)


func _c_duck(at: Node3D) -> void:
	contemporary_building.duck(at)


func _pop(mi: MeshInstance3D) -> MeshInstance3D:
	return contemporary_building.pop_art_material(mi)


func _c_bits(bits: Array) -> void:
	contemporary_building.flush_parts(bits)




# --- The middle-ages museum ---------------------------------------------------------

## The small parts of the middle-ages museum (joints, corbels, battlements,
## cobbles, bars...), gathered by colour and drawn as one MultiMesh each.
var _m_parts := {}
static var _m_glass := {}
static var _m_lights := {}
static var _m_glass_texture: ImageTexture


func _middle_ages(rooms: Array) -> void:
	middle_ages_building.build(rooms)


func _m_floor_y(f: int) -> float:
	return middle_ages_building.floor_height(f)


func _m_slot(side: int, across: float, f: int, size: Vector2) -> Vector3:
	return middle_ages_building.window_position(side, across, f, size)


func _m_key(side: int, across: float, f: int) -> String:
	return middle_ages_building.window_key(side, across, f)


func _m_look(rng: RandomNumberGenerator) -> String:
	return middle_ages_building.window_look(rng)


func _m_tower(c: Vector3, s: int, stone: Color, trim: Color, accent: Color, rng: RandomNumberGenerator, rooms: Array[bool]) -> void:
	middle_ages_building.tower(c, s, stone, trim, accent, rng, rooms)


func _m_ashlar(at: Transform3D, size: Vector2, course: float, block: float, colour: Color) -> void:
	middle_ages_building.ashlar(at, size, course, block, colour)


func _m_battlement(a: Vector3, b: Vector3, colour: Color) -> void:
	middle_ages_building.battlement(a, b, colour)


func _m_bifora(at: Vector3, size: Vector2, turn: float, look: String) -> Dictionary:
	return middle_ages_building.two_light_window(at, size, turn, look)


func _m_grille(at: Vector3, turn: float, lit: bool) -> void:
	middle_ages_building.grille(at, turn, lit)


func _m_yard(rng: RandomNumberGenerator) -> void:
	middle_ages_building.yard(rng)


func _m_link(a: Vector3, b: Vector3, colour: Color) -> void:
	middle_ages_building.link(a, b, colour)


func _m_brazier(at: Vector3) -> void:
	middle_ages_building.brazier(at)


func _m_catapult(at: Vector3, turn: float) -> void:
	middle_ages_building.catapult(at, turn)


func _m_knight(at: Node3D) -> void:
	middle_ages_building.knight(at)


func _m_disc(radius: float, thick: float) -> CylinderMesh:
	return middle_ages_building.disc(radius, thick)


func _m_part(size: Vector3, colour: Color, at: Vector3, turned := Basis.IDENTITY) -> void:
	middle_ages_building.add_part(size, colour, at, turned)


func _m_flush() -> void:
	middle_ages_building.flush_parts()


static func _m_lights_mesh(w: float, h: float) -> ArrayMesh:
	return MiddleAgesBuilding.lights_mesh(w, h)


func _m_stained(lit: bool) -> StandardMaterial3D:
	return middle_ages_building.stained_material(lit)


static func _m_glass_image() -> ImageTexture:
	return MiddleAgesBuilding.glass_texture()


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
## turbine, a giant snail and its name on a timber board; all round it a
## square of white stone slabs with a kerb (so the green tower stands out
## from the town's green), beds along the path, trees in planters and a
## giant ladybird. Its rooms are holes among the green: wood-lined niches
## in the balconies, warmly lit, back and floor (N_ROOMS, one on each of
## its four faces; the big job's the wide one at the top of its front, the
## crown over it on the name board). Only a room reached
## is a hole, empty (no piece: the light tells it); one not reached yet is
## a balcony like the rest.
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
## Where the rooms but the big job's are, in the rooms' order: on which
## face (_n_face: 0 the front, 1 the right, 2 the back, 3 the left), in
## which of its three bays (0 to 2, left to right as seen from out in front
## of it), on which floor (0 the first over the lobby). One a face, round
## the tower and up it, a spiral to the big job's (the top floor's middle,
## on the front); any room past these, in the last.
const N_ROOMS := [
	{"face": 0, "bay": 0, "floor": 0},
	{"face": 1, "bay": 2, "floor": 2},
	{"face": 2, "bay": 1, "floor": 3},
	{"face": 3, "bay": 2, "floor": 4},
]
const N_BOSS := {"face": 0, "bay": 1, "floor": N_FLOORS - 1}
## The name board on the roof: how high its middle, how far back.
const N_SIGN_Y := 0.38
const N_SIGN_Z := -0.12
## The lot's half (the tower's front at z 0, its middle at x 0).
const N_LOT := 2.8
## The square: its slabs (across, the joint between them), how high it
## stands (its top), its kerb (wide, high over it).
const N_SLAB_SIZE := 0.56
const N_JOINT := 0.035
const N_PAVE := 0.05
const N_KERB := Vector2(0.14, 0.07)
## The beds along the path: how far out their middles, how long, where
## along it.
const N_BED := Vector3(0.8, 2.0, 1.4)
## Its colours.
const N_CORE := Color("#34313e")
const N_GLASS := Color("#1b1c2c")
const N_MULLION := Color("#4b4858")
const N_WHITE := Color("#ece8f0")
const N_PLANTER_COLOUR := Color("#d2ccdb")
const N_WOOD := Color("#c89160")
const N_WOOD_DARK := Color("#7c5234")
const N_WOOD_GLOW := Color("#ffd9a0")
const N_WATER := Color("#8fd8e8")
const N_POND_EDGE := Color("#8a8478")
const N_MOSS := Color("#5f8f3e")
const N_GRASS := Color("#3b6a40")
const N_PAVING := Color("#f3f0f6")
const N_JOINTS := Color("#c8c1d2")
const N_KERB_COLOUR := Color("#cfc9d9")
## A room's hole lit (its back and the lamp under its ceiling), more when
## picked.
const N_HOLE_LIGHT := 0.55
const N_HOLE_PICKED := 1.3
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
var nature_decoration := NatureDecoration.new(self)
## The plants, [transform, tint] a kind: one MultiMesh each.
var _n_plants := {}


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
	# The white square all round it, the core of the tower.
	_n_square(rng)
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
					# Nothing in front of a room: two floors under a hole, no
					# trees; just under it, only flowers; over it, no vine
					# hanging down.
					var trees := not holes.has(_n_key(k, b, f + 1)) and not holes.has(_n_key(k, b, f + 2))
					var low := (f == N_FLOORS and k == 0) or holes.has(_n_key(k, b, f + 1)) or holes.has(_n_key(k, b, f - 1))
					_n_planter(face, u, y, bay, out, rng, trees, low)
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
	# On the square: a bed of bushes and flowers each side of the path, trees
	# in planters down its sides, lamps, the giant ladybird.
	for sx: int in [-1, 1]:
		_n_bed(Vector3(sx * N_BED.x, N_PAVE, N_BED.z), Vector2(0.3, N_BED.y))
		for j in 4:
			var at := Vector3(sx * N_BED.x, N_PAVE + 0.14, N_BED.z - N_BED.y * 0.5 + 0.2 + j * (N_BED.y - 0.4) / 3.0)
			_n_plant("bloom" if j % 2 == 0 else "bush", at, rng.randf_range(0.28, 0.38), rng)
		for j in 3:
			var at := Vector3(sx * 2.3, N_PAVE, -2.1 + j * 1.3)
			_n_bed(at, Vector2(0.46, 0.46))
			_n_plant("tree" if j % 2 == 0 else "birch", at + Vector3(0, 0.14, 0), rng.randf_range(0.9, 1.2), rng)
		var post := CylinderMesh.new()
		post.top_radius = 0.025
		post.bottom_radius = 0.035
		post.height = 0.7
		_mesh(post, Color("#2a2433"), Vector3(sx * 0.5, N_PAVE + 0.35, 1.5))
		var head := SphereMesh.new()
		head.radius = 0.075
		head.height = 0.15
		var lamp := _mesh(head, LIT, Vector3(sx * 0.5, N_PAVE + 0.74, 1.5))
		if open:
			lamp.material_override = _lit_material(LIT, 3.0)
	_n_ladybird(Transform3D(Basis(Vector3.UP, 0.7), Vector3(-1.85, N_PAVE, 1.3)))
	_n_waterfall(rng)
	# The whole tower as one mesh, the plants as a MultiMesh a kind.
	var body := MeshInstance3D.new()
	body.mesh = _n_body.commit()
	body.material_override = _n_material()
	add_child(body)
	_n_body = null
	_n_flush_plants()
	# The rooms: a hole each where it is reached, empty, warmly lit.
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
			# Its back and its floor (what the camera sees from over it) a
			# warm light (more when picked), and a timber frame round its
			# mouth (gold when picked). No piece: the light tells the room.
			var back := _box_in(node, Vector3(size.x + 0.04, tall - 0.02, 0.02), _shade(N_WOOD), Vector3(0, 0, -out + 0.035))
			var floor := _box_in(node, Vector3(size.x - 0.02, 0.012, out - 0.05), _shade(N_WOOD_GLOW), Vector3(0, -tall * 0.5 + 0.026, -out * 0.5))
			var rim := NMesh.new()
			for sx: int in [-1, 1]:
				rim.add(_n_prim("box"), _n_xf(Vector3(sx * (size.x * 0.5 + 0.03), 0, 0), Vector3(0.05, tall, 0.05)), _shade(N_WOOD_DARK))
			rim.add(_n_prim("box"), _n_xf(Vector3(0, tall * 0.5 - 0.025, 0), Vector3(size.x + 0.11, 0.05, 0.05)), _shade(N_WOOD_DARK))
			rim.add(_n_prim("box"), _n_xf(Vector3(0, -tall * 0.5 + 0.02, 0.01), Vector3(size.x + 0.11, 0.04, 0.07)), _shade(N_WOOD_DARK))
			var frame := MeshInstance3D.new()
			frame.mesh = rim.commit()
			frame.material_override = _n_material()
			node.add_child(frame)
			entry.back = back
			entry.glass = floor
			entry.frame = [frame]
			entry.stone = frame.material_override
			entry.rest = _lit_material(N_WOOD_GLOW, N_HOLE_LIGHT)
			back.material_override = entry.rest
			floor.material_override = entry.rest
			entry.glow = _lit_material(LIT_PICKED, N_HOLE_PICKED)
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


## Entradas compatibles: decoración reunida en su componente, sin redibujarla.
func _n_planter(face: Transform3D, u: float, y: float, bay: float, out: float, rng: RandomNumberGenerator, trees: bool, low: bool) -> void:
	nature_decoration.planter(face, u, y, bay, out, rng, trees, low)


func _n_niche(face: Transform3D, u: float, y: float, bay: float, out: float, hole: Vector2, rng: RandomNumberGenerator) -> void:
	nature_decoration.niche(face, u, y, bay, out, hole, rng)


func _n_square(rng: RandomNumberGenerator) -> void:
	nature_decoration.square(rng)


func _n_bed(at: Vector3, s: Vector2) -> void:
	nature_decoration.raised_bed(at, s)


func _n_roof(roof_y: float, rng: RandomNumberGenerator) -> void:
	nature_decoration.roof(roof_y, rng)


func _n_ladybird(at: Transform3D) -> void:
	nature_decoration.ladybird(at)


func _n_waterfall(rng: RandomNumberGenerator) -> void:
	nature_decoration.waterfall(rng)


func _n_snail(at: Transform3D) -> void:
	nature_decoration.snail(at)


func _n_plant(kind: String, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	nature_decoration.plant(kind, at, size, rng)


func _n_flush_plants() -> void:
	nature_decoration.flush_plants()


static func _n_plant_mesh(kind: String) -> ArrayMesh:
	return NatureDecoration.plant_mesh(kind)


static func _n_prim(kind: String) -> PackedVector3Array:
	return NatureDecoration.primitive_triangles(kind)


static func _n_material() -> StandardMaterial3D:
	return NatureDecoration.material()
