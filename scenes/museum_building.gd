class_name MuseumBuilding
extends Node3D
## A museum of the story as a building in the town (CityStage): a plain
## classical museum, the same for all five but in its own colour, bigger
## than anything round it. On a stone plinth, steps up to its door, a row
## of columns across its front under a cornice, a pediment over the middle
## and a dome behind it; a banner in its colour at each end, a flag on the
## dome, a lamp each side of the steps.
##
## Its five rooms are on its front: rooms 1 and 2 are the windows of the
## left wing, 3 and 4 those of the right, and the big job's the tall window
## in the middle, over the door, with a crown on the dome over it. A room
## reached is lit warm, its piece on show in it; one not yet, dark, with a
## padlock. Picking one (pick) lights it up (CityStage draws the ring).
##
## Built facing +z, its middle on the ground at its origin; x across.

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
## How dark a shut museum is.
const SHUT := 0.62

var museum := 0
var open := true
## each room's window: {"node" (its middle), "glass", "back", "piece",
## "lock", "boss", "open"}, in the rooms' own order
var windows: Array[Dictionary] = []
var _colour: Color
var _t := 0.0
var picked := -1


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
		_box_in(node, Vector3(size.x + 0.12, size.y + 0.12, 0.05), STONE if open else STONE.darkened(SHUT), Vector3(0, 0, 0.005))
		var back := _box_in(node, Vector3(size.x, size.y, 0.04), GLASS_DARK, Vector3(0, 0, 0.02))
		if lit:
			back.material_override = _lit_material(LIT, 1.2)
		var arch := CylinderMesh.new()
		arch.top_radius = size.x * 0.5 + 0.06
		arch.bottom_radius = size.x * 0.5 + 0.06
		arch.height = 0.05
		var a := _mesh_in(node, arch, STONE if open else STONE.darkened(SHUT), Vector3(0, size.y * 0.5, 0.005))
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
			model.scale = Vector3.ONE * (0.55 if r.boss else 0.42)
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
		windows.append({"node": node, "back": back, "glass": ag, "piece": piece, "lock": lock, "boss": r.boss, "open": lit, "size": size})


## Pick room i's window (-1 none): it lights up brighter, its piece turns.
func pick(i: int) -> void:
	picked = i
	for k in windows.size():
		var w: Dictionary = windows[k]
		if not w.open:
			continue
		var m := _lit_material(LIT_PICKED if k == i else LIT, 2.6 if k == i else 1.2)
		(w.back as MeshInstance3D).material_override = m
		(w.glass as MeshInstance3D).material_override = m


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
