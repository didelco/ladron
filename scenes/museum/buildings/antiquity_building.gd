class_name AntiquityBuilding
extends RefCounted
## Constructor del museo de antigüedad: templo, cúpula, ventanas y estatuas.
## MuseumBuilding conserva los recursos comunes, ventanas y estado de selección.
## Este componente añade nodos al mismo edificio y conserva el orden de su RNG.

var host: MuseumBuilding

func _init(building: MuseumBuilding) -> void:
	host = building

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
## the portico, down both sides and across the back, serlianas with a
## little pediment over them on the main floor, dark, small square windows
## over those (some lit), little ones in the basement. The rooms' are some of the serlianas
## (A_ROOMS), lit once reached (no piece on show: the light is the room);
## the big job's is behind the door, under the portico: shut until reached,
## then open and lit, the crown over the pediment.
## An amphora each side of the door (a mop stuck in one), hedges and
## cypresses round the gravel, a lamp at each front corner.
func build(rooms: Array) -> void:
	var wall := host._shade(MuseumBuilding.STUCCO)
	var stone := host._shade(MuseumBuilding.MARBLE)
	var trim := host._shade(MuseumBuilding.MARBLE_DARK)
	var accent := host._shade(host._colour)
	var glyph := trim.darkened(0.12)
	var main_y := MuseumBuilding.A_BASE + MuseumBuilding.A_MAIN * 0.5
	var upper_y := MuseumBuilding.A_BASE + MuseumBuilding.A_MAIN + MuseumBuilding.A_UPPER * 0.5
	var roof_y := MuseumBuilding.A_BASE + MuseumBuilding.A_MAIN + MuseumBuilding.A_UPPER
	var ent_top := roof_y + 0.3
	var back_z := -MuseumBuilding.A_D * 0.5
	var foot_z := MuseumBuilding.A_PORCH + MuseumBuilding.A_STEPS * MuseumBuilding.A_STEP
	host.front_z = MuseumBuilding.A_PORCH
	host.look_y = MuseumBuilding.A_BASE + MuseumBuilding.A_MAIN * 0.8 + MuseumBuilding.A_LOOK
	host.view = MuseumBuilding.A_VIEW
	var rng := RandomNumberGenerator.new()
	rng.seed = 5077 + host.museum
	# The gravel before it; the basement with its grooves, the walls, a band
	# under the main floor and one over it.
	host._square(Vector3(0, 0, 1.4), Vector2(MuseumBuilding.A_W + 0.9, 2.8), rng, MuseumBuilding.GRAVEL, MuseumBuilding.GRAVEL_EDGE, 0.2)
	host._box(Vector3(MuseumBuilding.A_W + 0.08, MuseumBuilding.A_BASE, MuseumBuilding.A_D + 0.08), trim, Vector3(0, MuseumBuilding.A_BASE * 0.5, back_z))
	for y in [MuseumBuilding.A_BASE * 0.35, MuseumBuilding.A_BASE * 0.68]:
		host._box(Vector3(MuseumBuilding.A_W + 0.1, 0.018, MuseumBuilding.A_D + 0.1), trim.darkened(0.25), Vector3(0, y, back_z))
	host._box(Vector3(MuseumBuilding.A_W, roof_y - MuseumBuilding.A_BASE, MuseumBuilding.A_D), wall, Vector3(0, (roof_y + MuseumBuilding.A_BASE) * 0.5, back_z))
	for y in [MuseumBuilding.A_BASE + 0.02, MuseumBuilding.A_BASE + MuseumBuilding.A_MAIN]:
		host._box(Vector3(MuseumBuilding.A_W + 0.05, 0.05, MuseumBuilding.A_D + 0.05), stone, Vector3(0, y, back_z))
	# The entablature all round: architrave, frieze (triglyphs along the
	# front either side of the portico, across the back and down the sides),
	# cornice.
	host._box(Vector3(MuseumBuilding.A_W + 0.08, 0.1, MuseumBuilding.A_D + 0.08), stone, Vector3(0, roof_y + 0.05, back_z))
	host._box(Vector3(MuseumBuilding.A_W + 0.1, 0.12, MuseumBuilding.A_D + 0.1), stone, Vector3(0, roof_y + 0.16, back_z))
	host._box(Vector3(MuseumBuilding.A_W + 0.26, 0.08, MuseumBuilding.A_D + 0.26), stone, Vector3(0, roof_y + 0.26, back_z))
	for k in 23:
		var x := -MuseumBuilding.A_W * 0.5 + 0.1 + k * (MuseumBuilding.A_W - 0.2) / 22.0
		if absf(x) > 1.52:
			host._box(Vector3(0.07, 0.11, 0.02), glyph, Vector3(x, roof_y + 0.16, 0.06))
		host._box(Vector3(0.07, 0.11, 0.02), glyph, Vector3(x, roof_y + 0.16, -MuseumBuilding.A_D - 0.06))
	for k in 13:
		var z := -0.1 - k * (MuseumBuilding.A_D - 0.2) / 12.0
		for sx in [-1, 1]:
			host._box(Vector3(0.02, 0.11, 0.07), glyph, Vector3(sx * (MuseumBuilding.A_W * 0.5 + 0.06), roof_y + 0.16, z))
	# The roof, low, and on it the drum, the dome, the lantern and a flag.
	var roof := Node3D.new()
	roof.position = Vector3(0, ent_top + 0.14, back_z)
	roof.scale = Vector3(MuseumBuilding.A_W + 0.1, 0.28, MuseumBuilding.A_D + 0.1)
	host.add_child(roof)
	var hip := CylinderMesh.new()
	hip.radial_segments = 4
	hip.rings = 0
	hip.bottom_radius = sqrt(0.5)
	hip.top_radius = sqrt(0.5) * 0.35
	hip.height = 1.0
	var slopes := host._mesh_in(roof, hip, host._shade(MuseumBuilding.ROOF), Vector3.ZERO)
	slopes.rotation.y = PI / 4
	host.top = dome(ent_top + 0.28, back_z) + 0.15
	# The portico's floor on the basement; the steps down to the gravel, as
	# wide as it, between its walls: level along the portico, sloping down
	# with the steps, a pedestal at the foot of each with a statue on it.
	host._box(Vector3(2.9, MuseumBuilding.A_BASE, MuseumBuilding.A_PORCH), trim, Vector3(0, MuseumBuilding.A_BASE * 0.5, MuseumBuilding.A_PORCH * 0.5))
	host._box(Vector3(2.9, 0.03, MuseumBuilding.A_PORCH), stone, Vector3(0, MuseumBuilding.A_BASE - 0.015, MuseumBuilding.A_PORCH * 0.5))
	for k in range(1, MuseumBuilding.A_STEPS + 1):
		var h := MuseumBuilding.A_BASE * (1.0 - float(k) / (MuseumBuilding.A_STEPS + 1))
		host._box(Vector3(2.6, h, MuseumBuilding.A_STEP), stone if k % 2 == 1 else trim.lightened(0.15), Vector3(0, h * 0.5, MuseumBuilding.A_PORCH + (k - 0.5) * MuseumBuilding.A_STEP))
	var run := foot_z - MuseumBuilding.A_PORCH
	for sx in [-1, 1]:
		var wx: float = sx * 1.45
		host._box(Vector3(0.3, MuseumBuilding.A_BASE + 0.15, MuseumBuilding.A_PORCH), trim, Vector3(wx, (MuseumBuilding.A_BASE + 0.15) * 0.5, MuseumBuilding.A_PORCH * 0.5))
		host._box(Vector3(0.34, 0.04, MuseumBuilding.A_PORCH), stone, Vector3(wx, MuseumBuilding.A_BASE + 0.17, MuseumBuilding.A_PORCH * 0.5))
		host._box(Vector3(0.3, 0.3, run), trim, Vector3(wx, 0.15, MuseumBuilding.A_PORCH + run * 0.5))
		var slope := PrismMesh.new()
		slope.left_to_right = 1.0
		slope.size = Vector3(run, MuseumBuilding.A_BASE + 0.15 - 0.3, 0.3)
		var sl := host._mesh(slope, trim, Vector3(wx, 0.3 + (MuseumBuilding.A_BASE + 0.15 - 0.3) * 0.5, MuseumBuilding.A_PORCH + run * 0.5))
		sl.rotation.y = PI / 2
		host._box(Vector3(0.44, 0.48, 0.44), trim, Vector3(wx, 0.24, foot_z + 0.12))
		host._box(Vector3(0.5, 0.05, 0.5), stone, Vector3(wx, 0.5, foot_z + 0.12))
	# An amphora on each pedestal at the foot of the steps, where they
	# actually show (by the door they stood behind the columns, out of
	# sight); a mop stuck in one.
	for sx in [-1, 1]:
		var jar := MuseumView.asset("anfora")
		jar.position = Vector3(sx * 1.45, 0.525, foot_z + 0.12)
		jar.rotation.y = sx * 0.6
		jar.scale = Vector3.ONE * 1.3
		host.add_child(jar)
		if sx > 0:
			mop(jar)
	# The columns: Doric, smooth, no base; an echinus and an abacus for a
	# capital. Six in a row, and one more down each side.
	var shaft_h := roof_y - MuseumBuilding.A_BASE - 0.09
	var col_at: Array[Vector2] = []
	for x in MuseumBuilding.A_COLUMNS_X:
		col_at.append(Vector2(x, MuseumBuilding.A_PORCH - 0.12))
	for sx in [-1, 1]:
		col_at.append(Vector2(sx * MuseumBuilding.A_COLUMNS_X[5], 0.3))
	for c in col_at:
		var shaft := host._cone(0.08, 0.066, shaft_h)
		shaft.radial_segments = 12
		host._mesh(shaft, stone, Vector3(c.x, MuseumBuilding.A_BASE + shaft_h * 0.5, c.y))
		host._mesh(host._cone(0.07, 0.105, 0.05), stone, Vector3(c.x, roof_y - 0.065, c.y))
		host._box(Vector3(0.23, 0.04, 0.23), stone, Vector3(c.x, roof_y - 0.02, c.y))
	# Over them, its entablature: the architrave; the frieze, a tablet with
	# the museum's name in its middle, triglyphs and metopes in the museum's
	# colour either side; the cornice; the pediment over it all, its
	# tympanum in the colour, a bust on its top and one at each end.
	var porch_z := MuseumBuilding.A_PORCH
	host._box(Vector3(2.78, 0.1, porch_z), stone, Vector3(0, roof_y + 0.05, porch_z * 0.5))
	host._box(Vector3(2.8, 0.12, porch_z + 0.01), stone, Vector3(0, roof_y + 0.16, (porch_z + 0.01) * 0.5))
	host._box(Vector3(2.96, 0.08, porch_z + 0.08), stone, Vector3(0, roof_y + 0.26, (porch_z + 0.08) * 0.5))
	for k in 14:
		var x := -1.35 + k * 2.7 / 13.0
		if absf(x) < 0.8:
			continue
		host._box(Vector3(0.07, 0.11, 0.02), glyph, Vector3(x, roof_y + 0.16, porch_z + 0.015))
		if k < 13 and absf(x + 1.35 / 13.0) > 0.8:
			host._box(Vector3(0.1, 0.08, 0.012), accent, Vector3(x + 1.35 / 13.0, roof_y + 0.16, porch_z + 0.011))
	host._box(Vector3(1.5, 0.1, 0.02), trim.lightened(0.3), Vector3(0, roof_y + 0.16, porch_z + 0.015))
	var ped := PrismMesh.new()
	ped.size = Vector3(2.96, 0.46, porch_z + 0.08)
	host._mesh(ped, stone, Vector3(0, ent_top + 0.23, (porch_z + 0.08) * 0.5))
	var tym := PrismMesh.new()
	tym.size = Vector3(2.34, 0.33, 0.03)
	host._mesh(tym, accent, Vector3(0, ent_top + 0.17, porch_z + 0.08))
	var busts := {"busto_filosofo": Vector3(0, ent_top + 0.46, porch_z - 0.02),
		"busto_emperador": Vector3(-1.36, ent_top, porch_z - 0.02), "busto_reina": Vector3(1.36, ent_top, porch_z - 0.02)}
	for b: String in busts:
		var at: Vector3 = busts[b]
		host._box(Vector3(0.16, 0.06, 0.16), stone, at + Vector3(0, 0.03, 0))
		statue(b, 0.34, at + Vector3(0, 0.06, 0), 0.0, false, false)
	# The windows: either side of the portico, down both sides and across
	# the back, a serliana on the main floor, dark, so that the rooms' stand
	# out (but where a room is: it has its own), a small window over it, a
	# little one in the basement under it.
	var taken := {}
	for s in MuseumBuilding.A_ROOMS:
		taken[host._slot_key(s.side, s.across, 0)] = true
	var slots: Array[Vector2] = []
	for x in MuseumBuilding.A_FRONT_X:
		slots.append(Vector2(0, x))
	for side in [-1, 1]:
		for z in MuseumBuilding.A_SIDE_Z:
			slots.append(Vector2(side, z))
	for x in MuseumBuilding.A_BACK_X:
		slots.append(Vector2(2, x))
	for s in slots:
		var side := int(s.x)
		var turn := host._slot_turn(side)
		if not taken.has(host._slot_key(side, s.y, 0)):
			arched_window(window_position(side, s.y, main_y), false, false, turn)
		host._plain(window_position(side, s.y, upper_y), MuseumBuilding.A_SMALL, host.open and rng.randf() < 0.3, true, turn)
		var low := Node3D.new()
		low.position = window_position(side, s.y, MuseumBuilding.A_BASE * 0.5)
		low.rotation.y = turn
		host.add_child(low)
		host._box_in(low, Vector3(0.3, 0.18, 0.03), stone, Vector3(0, 0, 0.01))
		host._box_in(low, Vector3(0.22, 0.12, 0.03), MuseumBuilding.GLASS_DARK, Vector3(0, 0, 0.02))
	# Round the gravel: hedges down its sides, a cypress at each corner, a
	# lamp at each front corner.
	for sx in [-1, 1]:
		host._box(Vector3(0.2, 0.2, 2.3), host._shade(MuseumBuilding.HEDGE), Vector3(sx * 2.62, 0.13, 1.35))
		for z in [2.6, -MuseumBuilding.A_D + 0.1]:
			cypress(Vector3(sx * 2.62, 0.03, z))
		var post := CylinderMesh.new()
		post.top_radius = 0.025
		post.bottom_radius = 0.035
		post.height = 0.75
		host._mesh(post, Color("#2a2433"), Vector3(sx * 2.15, 0.375, 2.5))
		var lamp := host._mesh(host._ball(0.08), MuseumBuilding.LIT, Vector3(sx * 2.15, 0.8, 2.5))
		if host.open:
			lamp.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT, 3.0)
	# The rooms: some of the serlianas (A_ROOMS), the big job's behind the
	# door. Only one reached shows as a room: lit (the door open, and the
	# crown over the pediment, for the big job's); the rest are dark
	# windows like any other, or a shut door, and nothing to pick.
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var shown: bool = host.open and r.has("shape") and bool(r.get("open", false))
		var w: Dictionary
		var size := MuseumBuilding.A_SERLIANA
		if r.boss:
			size = MuseumBuilding.A_DOOR
			w = front_door(shown)
		else:
			var s: Dictionary = MuseumBuilding.A_ROOMS[mini(normal, MuseumBuilding.A_ROOMS.size() - 1)]
			normal += 1
			w = arched_window(window_position(s.side, s.across, main_y), shown, shown, host._slot_turn(s.side))
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
			host._glow(Vector3(MuseumBuilding.A_DOOR.x, 0.004, 0.6), MuseumBuilding.LIT, Vector3(0, MuseumBuilding.A_BASE + 0.003, 0.32), 0.6)
		host.windows.append({"node": node, "back": w.back, "glass": w.glass, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": size, "frame": w.frame, "stone": w.stone, "arch": false, "face": node.basis, "near": MuseumBuilding.A_PORCH * 2.0 if r.boss else 0.0})


## The ancient museum's dome, as La Rotonda's, its axis at z on the roof
## (roof_top, the hip's top): a round drum in the stucco rising out of the
## roof, little dark windows round it, a cornice on it; a whole half sphere
## of tiles on that, stone steps round its foot and stone ribs up it to a
## lantern of little columns round dark glass, its own little dome, a
## ball in the museum's colour, the pole and the flag. Returns how high
## the pole goes.
func dome(roof_top: float, z: float) -> float:
	var wall := host._shade(MuseumBuilding.STUCCO)
	var stone := host._shade(MuseumBuilding.MARBLE)
	var tiles := host._shade(MuseumBuilding.ROOF.lightened(0.12))
	var r := MuseumBuilding.A_DOME
	var drum_r := r + 0.1
	var foot := roof_top - 0.18
	var dome_y := roof_top + MuseumBuilding.A_DRUM
	var drum := host._cone(drum_r, drum_r, dome_y - foot)
	drum.radial_segments = 32
	host._mesh(drum, wall, Vector3(0, (foot + dome_y) * 0.5, z))
	for k in 8:
		var a := (k + 0.5) * TAU / 8.0
		var slit := host._box(Vector3(0.14, 0.18, 0.04), MuseumBuilding.GLASS_DARK, Vector3(sin(a) * drum_r, dome_y - 0.2, z + cos(a) * drum_r))
		slit.rotation.y = a
	var cornice := host._cone(drum_r + 0.05, drum_r + 0.05, 0.07)
	cornice.radial_segments = 32
	host._mesh(cornice, stone, Vector3(0, dome_y - 0.035, z))
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
	host._mesh(dome, tiles, Vector3(0, dome_y, z))
	for k in 3:
		var h := k * 0.08
		var step := host._cone(sqrt(r * r - (h + 0.08) * (h + 0.08)) + 0.035, sqrt(r * r - (h + 0.08) * (h + 0.08)) + 0.035, 0.08)
		step.radial_segments = 32
		host._mesh(step, stone, Vector3(0, dome_y + h + 0.04, z))
	for k in 4:
		var rib := TorusMesh.new()
		rib.inner_radius = r - 0.01
		rib.outer_radius = r + 0.03
		rib.rings = 40
		rib.ring_segments = 6
		var mi := host._mesh(rib, stone, Vector3(0, dome_y, z))
		mi.basis = Basis(Vector3.UP, k * PI / 4.0) * Basis(Vector3.RIGHT, PI / 2.0)
	# The lantern on its top.
	var at := dome_y + r - 0.03
	host._mesh(host._cone(0.2, 0.2, 0.05), stone, Vector3(0, at + 0.025, z))
	host._mesh(host._cone(0.12, 0.12, 0.22), MuseumBuilding.GLASS_DARK, Vector3(0, at + 0.16, z))
	for k in 6:
		var a := k * TAU / 6.0
		host._box(Vector3(0.035, 0.22, 0.035), stone, Vector3(sin(a) * 0.15, at + 0.16, z + cos(a) * 0.15))
	host._mesh(host._cone(0.19, 0.19, 0.04), stone, Vector3(0, at + 0.29, z))
	var cap := SphereMesh.new()
	cap.radius = 0.15
	cap.height = 0.15
	cap.is_hemisphere = true
	cap.radial_segments = 16
	host._mesh(cap, tiles, Vector3(0, at + 0.31, z))
	host._mesh(host._ball(0.05), host._shade(host._colour), Vector3(0, at + 0.49, z))
	host._box(Vector3(0.03, 0.7, 0.03), MuseumBuilding.POLE, Vector3(0, at + 0.85, z))
	var flag := Node3D.new()
	flag.name = "Flag"
	flag.position = Vector3(0, at + 1.07, z)
	host.add_child(flag)
	host._box_in(flag, Vector3(0.42, 0.24, 0.02), host._colour if host.open else host._shade(host._colour), Vector3(0.21, 0, 0))
	return at + 1.2


## Where a window of the ancient museum is: on its front (side 0, across
## its x), down a side (-1 left, 1 right, across its z) or on its back
## (side 2, across its x), at height y.
func window_position(side: int, across: float, y: float) -> Vector3:
	if side == 0:
		return Vector3(across, y, 0.0)
	if side == 2:
		return Vector3(across, y, -MuseumBuilding.A_D)
	return Vector3(side * MuseumBuilding.A_W * 0.5, y, across)


## A serliana (a Palladian window), its middle at `at` on a wall, turned
## `turn` round y from facing the front: a tall middle light with a round
## arch over it (a keystone in the museum's colour) between two lower,
## narrow square lights, little columns between them, a short entablature
## over the side lights, a sill under it all, a little pediment over it. Lit or dark; glazing bars,
## but none down the middle light of a room's (room), brighter lit.
## Returns {"node", "back" (the middle light), "glass" (its arch), "frame"
## (the stone round it), "stone" (its look)}.
func arched_window(at: Vector3, lit: bool, room: bool, turn := 0.0) -> Dictionary:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = turn
	host.add_child(node)
	var stone := host._shade(MuseumBuilding.MARBLE)
	var a := MuseumBuilding.A_ARCH
	var p := 0.04
	var s := MuseumBuilding.A_LIGHT
	var foot := -MuseumBuilding.A_SERLIANA.y * 0.5
	var rect := MuseumBuilding.A_SERLIANA.y - a * 0.5
	var spring := foot + rect
	var half := a * 0.5 + p + s
	var frame: Array = []
	# The stone: jambs, the little columns, the entablature over the side
	# lights, the arch round the middle one, the sill.
	for sx in [-1, 1]:
		frame.append(host._box_in(node, Vector3(0.05, rect + 0.02, 0.05), stone, Vector3(sx * (half + 0.025), foot + rect * 0.5, 0.02)))
		frame.append(host._box_in(node, Vector3(p, rect, 0.05), stone, Vector3(sx * (a * 0.5 + p * 0.5), foot + rect * 0.5, 0.025)))
		frame.append(host._box_in(node, Vector3(s + p + 0.06, 0.05, 0.07), stone, Vector3(sx * (a * 0.5 + (s + p) * 0.5 + 0.02), spring + 0.025, 0.03)))
	var ring := host._cone(a * 0.5 + 0.05, a * 0.5 + 0.05, 0.04)
	ring.radial_segments = 16
	var arch := host._mesh_in(node, ring, stone, Vector3(0, spring, 0.006))
	arch.rotation.x = PI / 2
	frame.append(arch)
	frame.append(host._box_in(node, Vector3(2.0 * half + 0.14, 0.05, 0.1), stone, Vector3(0, foot - 0.03, 0.045)))
	host._box_in(node, Vector3(0.06, 0.07, 0.05), host._shade(host._colour), Vector3(0, spring + a * 0.5 + 0.02, 0.03))
	# The little pediment over it all, on a cornice.
	frame.append(host._box_in(node, Vector3(2.0 * half + 0.16, 0.03, 0.08), stone, Vector3(0, spring + a * 0.5 + 0.08, 0.04)))
	var hood := PrismMesh.new()
	hood.size = Vector3(2.0 * half + 0.16, 0.08, 0.07)
	frame.append(host._mesh_in(node, hood, stone, Vector3(0, spring + a * 0.5 + 0.135, 0.035)))
	# The glass: the middle light and its arch, the side lights.
	var back := host._box_in(node, Vector3(a, rect, 0.03), MuseumBuilding.GLASS_DARK, Vector3(0, foot + rect * 0.5, 0.012))
	var disc := host._cone(a * 0.5, a * 0.5, 0.03)
	disc.radial_segments = 16
	var glass := host._mesh_in(node, disc, MuseumBuilding.GLASS_DARK, Vector3(0, spring, 0.011))
	glass.rotation.x = PI / 2
	var lights: Array[MeshInstance3D] = [back, glass]
	for sx in [-1, 1]:
		lights.append(host._box_in(node, Vector3(s, rect, 0.03), MuseumBuilding.GLASS_DARK, Vector3(sx * (a * 0.5 + p + s * 0.5), foot + rect * 0.5, 0.012)))
	if lit:
		var look := MuseumBuilding._lit_material(MuseumBuilding.LIT, 0.9 if room else 0.55)
		for l in lights:
			l.material_override = look
	# The glazing bars: across each light, and down the middle one.
	var bar := MuseumBuilding.WOOD.lightened(0.15) if lit else MuseumBuilding.GLASS_DARK.lightened(0.15)
	for sx in [-1, 1]:
		host._box_in(node, Vector3(s, 0.02, 0.02), bar, Vector3(sx * (a * 0.5 + p + s * 0.5), foot + rect * 0.55, 0.03))
	host._box_in(node, Vector3(a, 0.02, 0.02), bar, Vector3(0, spring, 0.03))
	if not room:
		host._box_in(node, Vector3(0.02, rect + a * 0.5, 0.02), bar, Vector3(0, foot + (rect + a * 0.5) * 0.5, 0.03))
	return {"node": node, "back": back, "glass": glass, "frame": frame, "stone": (frame[0] as MeshInstance3D).material_override}


## The ancient museum's front door, under the portico: a stone surround with
## a little pediment over it, two wooden leaves. Shut (open_door false): the
## leaves closed on a dark doorway. Open: the leaves swung out, the doorway
## lit. Returns as _serliana does ("back" and "glass" both the doorway).
func front_door(open_door: bool) -> Dictionary:
	var node := Node3D.new()
	node.position = Vector3(0, MuseumBuilding.A_BASE + MuseumBuilding.A_DOOR.y * 0.5, 0.0)
	host.add_child(node)
	var stone := host._shade(MuseumBuilding.MARBLE)
	var wood := MuseumBuilding.WOOD.darkened(0.0 if host.open else 0.4)
	var frame: Array = []
	for sx in [-1, 1]:
		frame.append(host._box_in(node, Vector3(0.07, MuseumBuilding.A_DOOR.y + 0.07, 0.06), stone, Vector3(sx * (MuseumBuilding.A_DOOR.x * 0.5 + 0.035), 0.035, 0.03)))
	frame.append(host._box_in(node, Vector3(MuseumBuilding.A_DOOR.x + 0.22, 0.08, 0.08), stone, Vector3(0, MuseumBuilding.A_DOOR.y * 0.5 + 0.1, 0.04)))
	var hood := PrismMesh.new()
	hood.size = Vector3(MuseumBuilding.A_DOOR.x + 0.3, 0.14, 0.08)
	frame.append(host._mesh_in(node, hood, stone, Vector3(0, MuseumBuilding.A_DOOR.y * 0.5 + 0.21, 0.04)))
	var back := host._box_in(node, Vector3(MuseumBuilding.A_DOOR.x, MuseumBuilding.A_DOOR.y, 0.02), MuseumBuilding.GLASS_DARK, Vector3(0, 0, 0.008))
	if open_door:
		back.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT, 0.9)
	# The leaves, each on its hinge at a jamb: panels, a gold knob.
	for sx in [-1, 1]:
		var hinge := Node3D.new()
		hinge.position = Vector3(sx * MuseumBuilding.A_DOOR.x * 0.5, 0, 0.03)
		hinge.rotation.y = sx * 1.35 if open_door else 0.0
		node.add_child(hinge)
		host._box_in(hinge, Vector3(MuseumBuilding.A_DOOR.x * 0.5 - 0.01, MuseumBuilding.A_DOOR.y, 0.03), wood, Vector3(-sx * MuseumBuilding.A_DOOR.x * 0.25, 0, 0))
		for y in [-0.18, 0.17]:
			host._box_in(hinge, Vector3(MuseumBuilding.A_DOOR.x * 0.3, 0.26, 0.012), wood.darkened(0.25), Vector3(-sx * MuseumBuilding.A_DOOR.x * 0.25, y, 0.018))
		host._mesh_in(hinge, host._ball(0.018), MuseumBuilding.GOLD.darkened(0.0 if host.open else MuseumBuilding.SHUT), Vector3(-sx * (MuseumBuilding.A_DOOR.x * 0.5 - 0.05), -0.02, 0.03))
	return {"node": node, "back": back, "glass": back, "frame": frame, "stone": (frame[0] as MeshInstance3D).material_override}


## A cypress: a tall dark green spindle on a short trunk.
func cypress(at: Vector3) -> void:
	host._mesh(host._cone(0.04, 0.03, 0.14), host._shade(MuseumBuilding.WOOD), at + Vector3(0, 0.07, 0))
	var body := host._mesh(host._ball(0.17), host._shade(MuseumBuilding.CYPRESS), at + Vector3(0, 0.55, 0))
	body.scale = Vector3(1.0, 2.7, 1.0)


## A statue from the models (model_name), `tall` high, in pale marble, at
## `at` turned `turn`; on its head (its highest point) a traffic cone, or a
## party hat in the museum's colour (hat); or nothing (gag false).
func statue(model_name: String, tall: float, at: Vector3, turn: float, hat: bool, gag := true) -> void:
	var model := MuseumView.asset(model_name)
	var points := model_points(model)
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
	host.add_child(model)
	var pale := MenuStage._material(host._shade(Color("#e9e3d8")))
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = pale
	if not gag:
		return
	var head := Node3D.new()
	head.position = top_at
	head.scale = Vector3.ONE / s
	model.add_child(head)
	if hat:
		host._mesh_in(head, host._cone(0.07, 0.0, 0.18), host._shade(host._colour), Vector3(0, 0.07, 0))
		host._mesh_in(head, host._ball(0.025), host._shade(MuseumBuilding.GOLD), Vector3(0, 0.16, 0))
	else:
		host._mesh_in(head, host._cone(0.07, 0.015, 0.2), host._shade(MuseumBuilding.CONE), Vector3(0, 0.09, 0))
		host._mesh_in(head, host._cone(0.053, 0.045, 0.04), host._shade(Color.WHITE), Vector3(0, 0.1, 0))
		host._box_in(head, Vector3(0.16, 0.02, 0.16), host._shade(MuseumBuilding.CONE), Vector3(0, -0.005, 0))


## Every corner of a model's meshes, in its own space.
func model_points(model: Node3D) -> PackedVector3Array:
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
func mop(jar: Node3D) -> void:
	var stick := host._mesh_in(jar, host._cone(0.012, 0.012, 0.6), host._shade(Color("#d9b98a")), Vector3(0.03, 0.55, 0))
	stick.rotation.z = -0.25
	var mop := host._mesh_in(jar, host._ball(0.09), host._shade(Color("#b8b4c0")), Vector3(0.1, 0.84, 0))
	mop.scale = Vector3(1.0, 0.7, 1.0)
