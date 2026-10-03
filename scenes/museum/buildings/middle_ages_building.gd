class_name MiddleAgesBuilding
extends RefCounted
## Constructor del museo de edad media: castillo, vidrieras y decoración del patio.
## MuseumBuilding conserva los recursos comunes, ventanas y estado de selección.
## Este componente añade nodos al mismo edificio y conserva el orden de su RNG.

var host: MuseumBuilding

func _init(building: MuseumBuilding) -> void:
	host = building

## The middle-ages museum, a castle made a museum: a Renaissance palace of
## three floors in sand coloured ashlar (its joints drawn), flat pilasters
## on each floor, a band between the floors (the museum's name on the first)
## and a great cornice on corbels, battlements on it; a square tower on each
## front corner, higher, with a gallery on corbels and its battlements, a
## banner in the museum's colour down its front and a pennant on top. Its
## windows two-light arched ones with stained glass, a column between the
## lights and a round one over them, some lit, on the two noble floors of
## its front, both its sides and its back; little barred ones on the ground
## floor. The rooms' are some of them (M_ROOMS, round the palace); the big job's the big one in the
## middle of the noble floor, on a balcony, the family's crest over it (and
## the crown on the crest). Before it, a cobbled yard: a moat no wider than
## the museum itself, a rubber duck adrift on it, its water just proud of
## its kerb so the stones never show dry; the drawbridge a ramp up from the
## water to the door, on the plinth (M_BASE) that lifts the ground floor
## clear of it; a brazier each side, burning on a low hemisphere foot, no
## pole; a siege catapult; and a suit of armour standing on its plinth.
func build(rooms: Array) -> void:
	host._m_parts.clear()
	var sand := host._shade(MuseumBuilding.M_SAND)
	var sand_dark := host._shade(MuseumBuilding.M_SAND_DARK)
	var joint := host._shade(MuseumBuilding.M_JOINT)
	var trim := host._shade(MuseumBuilding.M_TRIM)
	var tower_stone := host._shade(MuseumBuilding.M_TOWER_STONE)
	var accent := host._shade(host._colour)
	var half := MuseumBuilding.M_W * 0.5
	var roof_y := floor_height(MuseumBuilding.M_FLOORS.size())
	var front := MuseumBuilding.M_W - MuseumBuilding.M_TOWER
	host.front_z = 0.1
	host.look_y = MuseumBuilding.M_BASE + 1.75
	host.top = MuseumBuilding.M_TOWER_H + 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 5071 + host.museum
	var taken := {}
	for s: Dictionary in MuseumBuilding.M_ROOMS:
		taken[window_key(s.side, s.across, s.floor)] = true
	yard(rng)
	# The plinth, the walls, their joints (bigger blocks on the ground floor).
	host._box(Vector3(MuseumBuilding.M_W + 0.12, MuseumBuilding.M_BASE, MuseumBuilding.M_D + 0.12), sand_dark, Vector3(0, MuseumBuilding.M_BASE * 0.5, -MuseumBuilding.M_D * 0.5))
	host._box(Vector3(MuseumBuilding.M_W, roof_y - MuseumBuilding.M_BASE, MuseumBuilding.M_D), sand, Vector3(0, (roof_y + MuseumBuilding.M_BASE) * 0.5, -MuseumBuilding.M_D * 0.5))
	var side_from := MuseumBuilding.M_TOWER_Z - MuseumBuilding.M_TOWER * 0.5
	var side_long := MuseumBuilding.M_D + side_from
	var ground_h: float = MuseumBuilding.M_FLOORS[0]
	var walls: Array[Transform3D] = [Transform3D(Basis.IDENTITY, Vector3(0, MuseumBuilding.M_BASE, 0))]
	for s: int in [-1, 1]:
		walls.append(Transform3D(Basis(Vector3.UP, s * PI * 0.5), Vector3(s * half, MuseumBuilding.M_BASE, side_from - side_long * 0.5)))
	walls.append(Transform3D(Basis(Vector3.UP, PI), Vector3(0, MuseumBuilding.M_BASE, -MuseumBuilding.M_D)))
	for k in walls.size():
		var across: float = front if k == 0 else MuseumBuilding.M_W if k == 3 else side_long
		ashlar(walls[k], Vector2(across, ground_h), 0.16, 0.4, joint)
		ashlar(walls[k].translated_local(Vector3(0, ground_h, 0)), Vector2(across, roof_y - MuseumBuilding.M_BASE - ground_h), 0.12, 0.3, joint)
	# The bands between the floors (the first a frieze), the pilasters on
	# each floor with their capitals, on the front, down the sides and across
	# the back.
	for f in range(1, MuseumBuilding.M_FLOORS.size()):
		var y := floor_height(f)
		var tall := 0.1 if f == 1 else 0.07
		host._box(Vector3(MuseumBuilding.M_W + 0.06, tall, MuseumBuilding.M_D + 0.06), trim, Vector3(0, y, -MuseumBuilding.M_D * 0.5))
		host._box(Vector3(MuseumBuilding.M_W + 0.1, 0.025, MuseumBuilding.M_D + 0.1), trim, Vector3(0, y + tall * 0.5 + 0.0125, -MuseumBuilding.M_D * 0.5))
	for f in MuseumBuilding.M_FLOORS.size():
		var foot := floor_height(f) + (0.07 if f > 0 else 0.0)
		var tall := floor_height(f + 1) - foot - (0.05 if f == 0 else 0.035 if f < MuseumBuilding.M_FLOORS.size() - 1 else 0.13)
		for x: float in MuseumBuilding.M_PILASTERS_X:
			for z: float in [0.017, -MuseumBuilding.M_D - 0.017]:
				add_part(Vector3(0.1, tall, 0.035), trim, Vector3(x, foot + tall * 0.5, z))
				add_part(Vector3(0.14, 0.04, 0.05), trim, Vector3(x, foot + tall - 0.02, z + signf(z) * 0.008))
		for s: int in [-1, 1]:
			for z: float in MuseumBuilding.M_SIDE_PILASTERS_Z:
				add_part(Vector3(0.035, tall, 0.1), trim, Vector3(s * (half + 0.017), foot + tall * 0.5, z))
				add_part(Vector3(0.05, 0.04, 0.14), trim, Vector3(s * (half + 0.025), foot + tall - 0.02, z))
	# The great cornice on its corbels, the battlements on it, the roof.
	host._box(Vector3(MuseumBuilding.M_W + 0.36, 0.1, MuseumBuilding.M_D + 0.36), trim, Vector3(0, roof_y + 0.13, -MuseumBuilding.M_D * 0.5))
	var x0 := -half
	while x0 <= half:
		for z: float in [0.06, -MuseumBuilding.M_D - 0.06]:
			add_part(Vector3(0.06, 0.08, 0.16), trim, Vector3(x0, roof_y + 0.04, z))
		x0 += 0.2
	for s: int in [-1, 1]:
		var z0 := side_from
		while z0 >= -MuseumBuilding.M_D:
			add_part(Vector3(0.16, 0.08, 0.06), trim, Vector3(s * (half + 0.06), roof_y + 0.04, z0))
			z0 -= 0.2
	var deck := roof_y + 0.18
	var e := 0.12
	battlement(Vector3(-front * 0.5, deck, e), Vector3(front * 0.5, deck, e), trim)
	for s: int in [-1, 1]:
		battlement(Vector3(s * (half + e), deck, side_from), Vector3(s * (half + e), deck, -MuseumBuilding.M_D - e), trim)
	battlement(Vector3(half + e, deck, -MuseumBuilding.M_D - e), Vector3(-half - e, deck, -MuseumBuilding.M_D - e), trim)
	host._box(Vector3(MuseumBuilding.M_W + 0.2, 0.02, MuseumBuilding.M_D + 0.2), host._shade(MuseumBuilding.M_SAND_DARK), Vector3(0, deck + 0.01, -MuseumBuilding.M_D * 0.5))
	var roof := PrismMesh.new()
	roof.size = Vector3(MuseumBuilding.M_D - 1.0, 0.3, MuseumBuilding.M_W - 1.4)
	var tiles := host._mesh(roof, host._shade(MuseumBuilding.M_TILE), Vector3(0, deck + 0.15, -MuseumBuilding.M_D * 0.5 - 0.1))
	tiles.rotation.y = PI * 0.5
	# The towers on the front corners.
	for s: int in [-1, 1]:
		var rooms_at: Array[bool] = [taken.has(window_key(0, s * half, 2)), taken.has(window_key(s, MuseumBuilding.M_TOWER_Z, 2))]
		tower(Vector3(s * half, 0, MuseumBuilding.M_TOWER_Z), s, tower_stone, trim, accent, rng, rooms_at)
	# The door: a stone frame, big, the door in the museum's colour studded in
	# gold, lit round its edge when open; a cornice over it. The taller
	# ground floor gives it the room, and the drawbridge outside (_m_yard)
	# the same doorway to close against.
	host._box(Vector3(0.95, 1.0, 0.06), trim, Vector3(0, MuseumBuilding.M_BASE + 0.5, 0.02))
	host._box(Vector3(0.76, 0.88, 0.045), accent.darkened(0.3), Vector3(0, MuseumBuilding.M_BASE + 0.44, 0.035))
	for k in 5:
		add_part(Vector3(0.014, 0.88, 0.012), host._shade(MuseumBuilding.WOOD), Vector3((k - 2) * 0.14, MuseumBuilding.M_BASE + 0.44, 0.058))
	for x: float in [-0.27, -0.09, 0.09, 0.27]:
		for j in 3:
			add_part(Vector3(0.032, 0.032, 0.022), host._shade(MuseumBuilding.GOLD), Vector3(x, MuseumBuilding.M_BASE + 0.19 + j * 0.26, 0.06))
	if host.open:
		host._glow(Vector3(0.8, 0.035, 0.035), MuseumBuilding.LIT, Vector3(0, MuseumBuilding.M_BASE + 0.85, 0.045), 1.5)
	host._box(Vector3(1.15, 0.09, 0.12), trim, Vector3(0, MuseumBuilding.M_BASE + 1.02, 0.045))
	# The bench along its foot, each side of the door.
	for s: int in [-1, 1]:
		host._box(Vector3(1.05, 0.2, 0.18), sand_dark, Vector3(s * 1.28, 0.1, 0.12))
		host._box(Vector3(1.09, 0.03, 0.22), trim, Vector3(s * 1.28, 0.215, 0.12))
	# The frieze under the cornice, plain.
	host._box(Vector3(front, 0.13, 0.03), trim, Vector3(0, roof_y - 0.065, 0.015))
	# The big job's balcony: a slab, a railing hung with a cloth in the
	# museum's colour, gold along its foot.
	var noble := floor_height(1)
	var slab_y := noble + 0.08
	host._box(Vector3(MuseumBuilding.M_BIG.x + 0.4, 0.05, 0.28), trim, Vector3(0, slab_y, 0.14))
	for k in 5:
		add_part(Vector3(0.035, 0.12, 0.035), trim, Vector3((k - 2) * 0.2, slab_y + 0.085, 0.26))
	host._box(Vector3(MuseumBuilding.M_BIG.x + 0.4, 0.035, 0.05), trim, Vector3(0, slab_y + 0.16, 0.26))
	host._box(Vector3(MuseumBuilding.M_BIG.x + 0.1, 0.12, 0.012), accent, Vector3(0, slab_y + 0.08, 0.29))
	host._box(Vector3(MuseumBuilding.M_BIG.x + 0.1, 0.025, 0.014), host._shade(MuseumBuilding.GOLD), Vector3(0, slab_y + 0.03, 0.29))
	# The crest on the top floor, over the big job's window: a shield in the
	# museum's colour edged in gold, a croquette on it.
	var crest_y := floor_height(2) + 0.34
	host._box(Vector3(0.34, 0.26, 0.02), host._shade(MuseumBuilding.GOLD), Vector3(0, crest_y, 0.01))
	var point := PrismMesh.new()
	point.size = Vector3(0.34, 0.16, 0.02)
	host._mesh(point, host._shade(MuseumBuilding.GOLD), Vector3(0, crest_y - 0.21, 0.01)).rotation.z = PI
	host._box(Vector3(0.28, 0.22, 0.03), accent, Vector3(0, crest_y + 0.005, 0.02))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.28, 0.12, 0.03)
	host._mesh(tip, accent, Vector3(0, crest_y - 0.165, 0.02)).rotation.z = PI
	var croquette := host._mesh(host._ball(0.06), host._shade(MuseumBuilding.M_CROQUETTE), Vector3(0, crest_y - 0.02, 0.045))
	croquette.scale = Vector3(1.3, 0.75, 0.6)
	# The windows: two-light ones on the noble floors of the front, down
	# both sides and across the back, little barred ones on the ground
	# floor; but where a room is (it has its own) and in the middle of the
	# front (the big job's and the crest).
	for f: int in [1, 2]:
		for x: float in MuseumBuilding.M_BAYS_X:
			if x != 0.0 and not taken.has(window_key(0, x, f)):
				two_light_window(window_position(0, x, f, MuseumBuilding.M_WINDOW), MuseumBuilding.M_WINDOW, 0.0, window_look(rng))
			if not taken.has(window_key(2, x, f)):
				two_light_window(window_position(2, x, f, MuseumBuilding.M_WINDOW), MuseumBuilding.M_WINDOW, PI, window_look(rng))
		for side: int in [-1, 1]:
			for z: float in MuseumBuilding.M_SIDE_Z:
				if not taken.has(window_key(side, z, f)):
					two_light_window(window_position(side, z, f, MuseumBuilding.M_WINDOW), MuseumBuilding.M_WINDOW, side * PI * 0.5, window_look(rng))
	for x: float in MuseumBuilding.M_BAYS_X:
		if x != 0.0:
			grille(Vector3(x, MuseumBuilding.M_BASE + 0.45, 0.0), 0.0, host.open and rng.randf() < 0.3)
		grille(Vector3(x, MuseumBuilding.M_BASE + 0.45, -MuseumBuilding.M_D), PI, host.open and rng.randf() < 0.3)
	for side: int in [-1, 1]:
		for z: float in MuseumBuilding.M_SIDE_Z:
			grille(Vector3(side * half, MuseumBuilding.M_BASE + 0.45, z), side * PI * 0.5, host.open and rng.randf() < 0.3)
	# The rooms: some of the windows (M_ROOMS), the big job's the balcony's.
	# Only one reached shows as a room: clear glass lit up warm, nothing in it
	# (and the crown on the crest for the big job's); the rest are stained
	# glass like any other window, and nothing to pick.
	var boss_at := window_position(0, 0.0, 1, MuseumBuilding.M_BIG)
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var at := boss_at
		var turn := 0.0
		var size := MuseumBuilding.M_BIG
		if not r.boss:
			var s: Dictionary = MuseumBuilding.M_ROOMS[mini(normal, MuseumBuilding.M_ROOMS.size() - 1)]
			normal += 1
			size = MuseumBuilding.M_WINDOW
			at = window_position(s.side, s.across, s.floor, size)
			turn = s.side * PI * 0.5
		var shown: bool = host.open and r.has("shape") and bool(r.get("open", false))
		var w := two_light_window(at, size, turn, "room" if shown else window_look(rng))
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
		host.windows.append({"node": node, "back": w.back, "glass": w.glass, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": size, "frame": w.frame, "stone": w.stone, "arch": true, "face": node.basis})
	flush_parts()


## The floor f's foot (0 the ground floor's; past the last, the roof's).
func floor_height(f: int) -> float:
	var y := MuseumBuilding.M_BASE
	for k in mini(f, MuseumBuilding.M_FLOORS.size()):
		y += MuseumBuilding.M_FLOORS[k]
	return y


## Where a window of the middle-ages museum goes: on its front (side 0,
## across its x), down a side (-1, 1: across its z) or on its back (side 2,
## across its x), on floor f, its glass's foot a little over the band; on
## the front at a tower's middle, on the tower's front; down a side as far
## back as a tower's middle, on the tower's outer side.
func window_position(side: int, across: float, f: int, size: Vector2) -> Vector3:
	var y := floor_height(f) + 0.12 + size.y * 0.5
	if side == 0:
		var tower := absf(across) > MuseumBuilding.M_W * 0.5 - 0.01
		return Vector3(across, y, MuseumBuilding.M_TOWER_Z + MuseumBuilding.M_TOWER * 0.5 if tower else 0.0)
	if side == 2:
		return Vector3(across, y, -MuseumBuilding.M_D)
	var out := MuseumBuilding.M_W * 0.5 + (MuseumBuilding.M_TOWER * 0.5 if across > MuseumBuilding.M_TOWER_Z - MuseumBuilding.M_TOWER * 0.5 else 0.0)
	return Vector3(side * out, y, across)


func window_key(side: int, across: float, f: int) -> String:
	return "%d:%.2f:%d" % [side, across, f]


## A window not a room: its stained glass lit here and there.
func window_look(rng: RandomNumberGenerator) -> String:
	return "lit" if host.open and rng.randf() < 0.45 else "dark"


## A tower on a front corner (s: -1 left, 1 right), its foot's middle at
## c: a battered foot, its walls with their joints, bands at the palace's
## floors, arrow slits, a two-light window high up on its front and its
## outer side (but where a room is: rooms, [front, side]), a banner down its
## front; a gallery on corbels at the top, battlements round it, a pennant
## on a pole (the right one's waves).
func tower(c: Vector3, s: int, stone: Color, trim: Color, accent: Color, rng: RandomNumberGenerator, rooms: Array[bool]) -> void:
	var hw := MuseumBuilding.M_TOWER * 0.5
	host._box(Vector3(MuseumBuilding.M_TOWER + 0.16, 0.4, MuseumBuilding.M_TOWER + 0.16), host._shade(MuseumBuilding.M_SAND_DARK), c + Vector3(0, 0.2, 0))
	host._box(Vector3(MuseumBuilding.M_TOWER, MuseumBuilding.M_TOWER_H, MuseumBuilding.M_TOWER), stone, c + Vector3(0, MuseumBuilding.M_TOWER_H * 0.5, 0))
	var joint := host._shade(MuseumBuilding.M_JOINT)
	ashlar(Transform3D(Basis.IDENTITY, c + Vector3(0, 0.4, hw)), Vector2(MuseumBuilding.M_TOWER, MuseumBuilding.M_TOWER_H - 0.4), 0.15, 0.32, joint)
	for side: int in [-1, 1]:
		ashlar(Transform3D(Basis(Vector3.UP, side * PI * 0.5), c + Vector3(side * hw, 0.4, 0)), Vector2(MuseumBuilding.M_TOWER, MuseumBuilding.M_TOWER_H - 0.4), 0.15, 0.32, joint)
	for f: int in [1, 2]:
		host._box(Vector3(MuseumBuilding.M_TOWER + 0.05, 0.07, MuseumBuilding.M_TOWER + 0.05), trim, c + Vector3(0, floor_height(f), 0))
	# Its windows: slits low and high, a two-light one on the top floor, on
	# its front and on its outer side.
	for turn: float in [0.0, s * PI * 0.5]:
		var out := Basis(Vector3.UP, turn)
		for y: float in [0.6, MuseumBuilding.M_TOWER_H - 0.45]:
			add_part(Vector3(0.05, 0.3, 0.02), host._shade(MuseumBuilding.M_IRON), c + out * Vector3(0, y, hw + 0.005), out)
			add_part(Vector3(0.12, 0.04, 0.03), trim, c + out * Vector3(0, y - 0.17, hw + 0.01), out)
		if rooms[0 if turn == 0.0 else 1]:
			continue
		two_light_window(c + out * Vector3(0, floor_height(2) + 0.12 + MuseumBuilding.M_WINDOW.y * 0.5, hw), MuseumBuilding.M_WINDOW, turn, window_look(rng))
	# The banner down its front, gold along its foot, a gold lozenge on it.
	var fz := c.z + hw
	host._box(Vector3(0.36, 0.76, 0.02), accent, Vector3(c.x, floor_height(1) + 0.48, fz + 0.012))
	host._box(Vector3(0.36, 0.06, 0.024), host._shade(MuseumBuilding.GOLD), Vector3(c.x, floor_height(1) + 0.13, fz + 0.013))
	host._box(Vector3(0.44, 0.035, 0.05), MuseumBuilding.POLE, Vector3(c.x, floor_height(1) + 0.87, fz + 0.02))
	var lozenge := host._box(Vector3(0.13, 0.13, 0.01), host._shade(MuseumBuilding.GOLD), Vector3(c.x, floor_height(1) + 0.52, fz + 0.025))
	lozenge.rotation.z = PI * 0.25
	# The gallery on its corbels, the battlements round it.
	var g := MuseumBuilding.M_TOWER_H
	host._box(Vector3(MuseumBuilding.M_TOWER + 0.22, 0.2, MuseumBuilding.M_TOWER + 0.22), trim, c + Vector3(0, g + 0.1, 0))
	for k in 4:
		var face := Basis(Vector3.UP, k * PI * 0.5)
		for off: float in [-0.32, 0.0, 0.32]:
			add_part(Vector3(0.08, 0.14, 0.12), trim, c + face * Vector3(off, g - 0.06, hw + 0.05), face)
	var ring := hw + 0.06
	var deck := g + 0.2
	battlement(c + Vector3(-ring, deck, ring), c + Vector3(ring, deck, ring), trim)
	battlement(c + Vector3(ring, deck, ring), c + Vector3(ring, deck, -ring), trim)
	battlement(c + Vector3(ring, deck, -ring), c + Vector3(-ring, deck, -ring), trim)
	battlement(c + Vector3(-ring, deck, -ring), c + Vector3(-ring, deck, ring), trim)
	# The pennant on its pole.
	host._box(Vector3(0.03, 0.7, 0.03), MuseumBuilding.POLE, c + Vector3(0, deck + 0.35, 0))
	var pennant := PrismMesh.new()
	pennant.size = Vector3(0.22, 0.46, 0.02)
	var pivot := Node3D.new()
	pivot.position = c + Vector3(0, deck + 0.58, 0)
	host.add_child(pivot)
	var flag := host._mesh_in(pivot, pennant, host._colour if host.open else accent, Vector3(0.23, 0, 0))
	flag.rotation.z = -PI * 0.5
	if s > 0:
		pivot.name = "Flag"


## Ashlar joints on a wall: at, its foot's middle on its face (its basis x
## along the wall, y up, z out of it); size across and up; courses course
## high, blocks block long, each course's joints half a block on.
func ashlar(at: Transform3D, size: Vector2, course: float, block: float, colour: Color) -> void:
	var rows := maxi(1, int(round(size.y / course)))
	var step := size.y / rows
	for r in rows:
		var y := r * step
		if r > 0:
			add_part(Vector3(size.x, 0.014, 0.01), colour, at * Vector3(0, y, 0.004), at.basis)
		var x := -size.x * 0.5 + block * (0.5 if r % 2 == 1 else 1.0)
		while x < size.x * 0.5 - 0.05:
			add_part(Vector3(0.014, step, 0.01), colour, at * Vector3(x, y + step * 0.5, 0.004), at.basis)
			x += block


## Battlements from a to b, on the deck: a low wall and on it
## swallow-tailed merlons (the same seen from either side).
func battlement(a: Vector3, b: Vector3, colour: Color) -> void:
	var along := (b - a).normalized()
	var turned := Basis(along, Vector3.UP, along.cross(Vector3.UP))
	var long := a.distance_to(b)
	add_part(Vector3(long + 0.1, 0.1, 0.1), colour, (a + b) * 0.5 + Vector3(0, 0.05, 0), turned)
	var n := maxi(1, int(round(long / 0.32)))
	for k in n + 1:
		var at := a.lerp(b, float(k) / n) + Vector3(0, 0.1, 0)
		add_part(Vector3(0.15, 0.12, 0.1), colour, at + Vector3(0, 0.06, 0), turned)
		for sx: int in [-1, 1]:
			var horn := turned * Basis(Vector3.BACK, -sx * 0.35)
			add_part(Vector3(0.05, 0.09, 0.1), colour, at + turned * Vector3(sx * 0.05, 0.15, 0), horn)


## A two-light window, its middle (where its arch springs, less half its
## height) at `at`, turned `turn` round y from facing the front: a round
## arch of stone on its jambs, a sill and a keystone; in it, two arched
## lights with a column between them and a round one over them in the stone
## under the arch. look: "lit" or "dark" stained glass, or "room" (clear
## glass, lit). Returns {"node", "back" (the lights), "glass" (the round
## one), "frame", "stone"}.
func two_light_window(at: Vector3, size: Vector2, turn: float, look: String) -> Dictionary:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = turn
	host.add_child(node)
	var stone := host._shade(MuseumBuilding.M_TRIM)
	var r := size.x * 0.5
	var frame: Array = []
	var arch := host._mesh_in(node, disc(r + 0.075, 0.04), stone, Vector3(0, size.y * 0.5, 0.0))
	arch.rotation.x = PI * 0.5
	frame.append(arch)
	for sx: int in [-1, 1]:
		frame.append(host._box_in(node, Vector3(0.075, size.y + 0.02, 0.04), stone, Vector3(sx * (r + 0.0375), 0, 0.0)))
	frame.append(host._box_in(node, Vector3(size.x + 0.22, 0.05, 0.1), stone, Vector3(0, -size.y * 0.5 - 0.03, 0.04)))
	frame.append(host._box_in(node, Vector3(0.06, 0.09, 0.05), stone, Vector3(0, size.y * 0.5 + r + 0.035, 0.01)))
	var tympanum := host._mesh_in(node, disc(r, 0.02), stone.darkened(0.08), Vector3(0, size.y * 0.5, 0.012))
	tympanum.rotation.x = PI * 0.5
	var glass: Material = MuseumBuilding._lit_material(MuseumBuilding.LIT, 0.9) if look == "room" else stained_material(look == "lit")
	var lights := MeshInstance3D.new()
	lights.mesh = lights_mesh(size.x, size.y)
	lights.material_override = glass
	lights.position = Vector3(0, 0, 0.026)
	node.add_child(lights)
	frame.append(host._box_in(node, Vector3(MuseumBuilding.M_MULLION, size.y, 0.04), stone, Vector3(0, 0, 0.045)))
	frame.append(host._box_in(node, Vector3(0.075, 0.03, 0.05), stone, Vector3(0, size.y * 0.5, 0.045)))
	var eye_y := size.y * 0.5 + r * 0.6
	var eye_ring := host._mesh_in(node, disc(r * 0.34, 0.012), stone, Vector3(0, eye_y, 0.028))
	eye_ring.rotation.x = PI * 0.5
	frame.append(eye_ring)
	var eye := MeshInstance3D.new()
	eye.mesh = disc(r * 0.24, 0.012)
	eye.material_override = glass
	eye.position = Vector3(0, eye_y, 0.034)
	eye.rotation.x = PI * 0.5
	node.add_child(eye)
	return {"node": node, "back": lights, "glass": eye, "frame": frame, "stone": arch.material_override}


## A little window of the ground floor, high up, with a grille: a stone
## frame, a cornice and a sill; the glass dark or lit behind iron bars.
func grille(at: Vector3, turn: float, lit: bool) -> void:
	var node := Node3D.new()
	node.position = at
	node.rotation.y = turn
	host.add_child(node)
	var stone := host._shade(MuseumBuilding.M_TRIM)
	var size := MuseumBuilding.M_GRILLE
	host._box_in(node, Vector3(size.x + 0.1, size.y + 0.1, 0.04), stone, Vector3(0, 0, 0.01))
	var glass := host._box_in(node, Vector3(size.x, size.y, 0.03), MuseumBuilding.GLASS_DARK, Vector3(0, 0, 0.022))
	if lit:
		glass.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT, 0.55)
	host._box_in(node, Vector3(size.x + 0.18, 0.05, 0.08), stone, Vector3(0, size.y * 0.5 + 0.075, 0.03))
	host._box_in(node, Vector3(size.x + 0.14, 0.04, 0.08), stone, Vector3(0, -size.y * 0.5 - 0.07, 0.03))
	var iron := host._shade(MuseumBuilding.M_IRON)
	for k in 3:
		add_part(Vector3(0.018, size.y, 0.018), iron, node.transform * Vector3((k - 1) * size.x * 0.3, 0, 0.045), node.basis)
	for y: float in [-size.y * 0.2, size.y * 0.2]:
		add_part(Vector3(size.x, 0.018, 0.018), iron, node.transform * Vector3(0, y, 0.05), node.basis)


## The yard before the middle-ages museum: cobbles on a kerb; a dry moat
## before the door, a rubber duck in it, a little drawbridge over it on its
## chains; a brazier each side; a well on the left, a knight on the right.
func yard(rng: RandomNumberGenerator) -> void:
	var w := MuseumBuilding.M_W + 0.9
	host._box(Vector3(w + 0.1, 0.03, MuseumBuilding.M_YARD + 0.04), host._shade(MuseumBuilding.M_COBBLE_EDGE), Vector3(0, 0.015, MuseumBuilding.M_YARD * 0.5))
	var cobble := 0.2
	var nx := int(w / cobble)
	var nz := int(MuseumBuilding.M_YARD / cobble)
	for j in nz:
		for i in nx:
			var x := (i - (nx - 1) * 0.5 + (0.25 if j % 2 == 1 else -0.25)) * cobble
			var z := (j + 0.5) * cobble
			if absf(x) < 0.72 and z < 0.72:
				continue
			var at := Vector3(x + rng.randf_range(-0.012, 0.012), 0.035, z + rng.randf_range(-0.012, 0.012))
			var tone: Color = MuseumBuilding.M_COBBLE[rng.randi() % MuseumBuilding.M_COBBLE.size()]
			add_part(Vector3(cobble - 0.035, 0.03, cobble - 0.035), host._shade(tone), at, Basis(Vector3.UP, rng.randf_range(-0.15, 0.15)))
	# The moat before it, a pool no wider than the museum itself, its water
	# a touch proud of its kerb stones (never showing them dry); the duck
	# adrift; the drawbridge a ramp up from the water to the (raised, bigger)
	# door, its chains running up to it.
	var trim := host._shade(MuseumBuilding.M_TRIM)
	var river_w := MuseumBuilding.M_W + 0.2
	var water_y := 0.09
	host._box(Vector3(river_w, 0.02, 0.85), host._shade(MuseumBuilding.M_RIVER if not host.open else MuseumBuilding.M_RIVER_LIT), Vector3(0, water_y, 0.4))
	add_part(Vector3(river_w + 0.08, 0.06, 0.06), trim, Vector3(0, 0.05, 0.83))
	add_part(Vector3(river_w + 0.08, 0.06, 0.06), trim, Vector3(0, 0.05, -0.03))
	var duck := Node3D.new()
	duck.position = Vector3(1.4, water_y + 0.01, 0.55)
	duck.rotation.y = -0.6
	host.add_child(duck)
	host._mesh_in(duck, host._ball(0.065), host._shade(MuseumBuilding.M_DUCK), Vector3(0, 0.05, 0)).scale = Vector3(1, 0.8, 1.3)
	host._mesh_in(duck, host._ball(0.04), host._shade(MuseumBuilding.M_DUCK), Vector3(0, 0.12, 0.05))
	host._box_in(duck, Vector3(0.04, 0.015, 0.04), host._shade(MuseumBuilding.M_FLAME), Vector3(0, 0.115, 0.1))
	var wood := host._shade(MuseumBuilding.WOOD.lightened(0.15))
	var ramp_run := 0.8 * 1.15
	var ramp_rise := MuseumBuilding.M_BASE - water_y
	var ramp_len := Vector2(ramp_run, ramp_rise).length()
	var ramp_angle := atan2(ramp_rise, ramp_run)
	var ramp := host._box(Vector3(0.86, 0.04, ramp_len), wood, Vector3(0, (water_y + MuseumBuilding.M_BASE) * 0.5, 0.05 + ramp_run * 0.5))
	ramp.rotation.x = ramp_angle
	# The planks: cross-strips along the ramp's own length, so it reads as
	# wood, not a flat coloured slab.
	for k in 6:
		host._box_in(ramp, Vector3(0.86, 0.01, 0.012), host._shade(MuseumBuilding.WOOD), Vector3(0, 0.022, -ramp_len * 0.5 + 0.06 + k * (ramp_len - 0.12) / 5.0))
	for sx: int in [-1, 1]:
		link(Vector3(sx * 0.4, water_y, 0.05 + ramp_run), Vector3(sx * 0.44, MuseumBuilding.M_BASE + 0.85, 0.05), host._shade(MuseumBuilding.M_IRON))
	# A brazier each side of it, burning: an iron bowl on a low hemisphere
	# footing, the fire a burst of glowing particles over it.
	for sx: int in [-1, 1]:
		brazier(Vector3(sx * 1.0, 0, 0.95))
	catapult(Vector3(-1.7, 0, 1.8), 0.5)
	var knight := Node3D.new()
	knight.position = Vector3(1.7, 0, 1.85)
	knight.rotation.y = -0.45
	host.add_child(knight)
	knight(knight)


## A chain (a thin bar) from a to b.
func link(a: Vector3, b: Vector3, colour: Color) -> void:
	var up := (b - a).normalized()
	var x := Vector3.RIGHT
	var z := x.cross(up).normalized()
	add_part(Vector3(0.015, a.distance_to(b), 0.015), colour, (a + b) * 0.5, Basis(up.cross(z), up, z))


## A brazier: an iron bowl on a squat hemisphere foot standing on the
## ground (no pole holding it up); its fire a burst of glowing particles
## when open, banked to cold embers when shut.
func brazier(at: Vector3) -> void:
	var iron := host._shade(MuseumBuilding.M_IRON)
	var foot := SphereMesh.new()
	foot.radius = 0.22
	foot.height = 0.22
	foot.is_hemisphere = true
	foot.radial_segments = 10
	foot.rings = 4
	host._mesh(foot, iron, at)
	var bowl := SphereMesh.new()
	bowl.radius = 0.17
	bowl.height = 0.17
	bowl.is_hemisphere = true
	bowl.radial_segments = 10
	bowl.rings = 3
	host._mesh(bowl, iron, at + Vector3(0, 0.32, 0)).rotation.x = PI
	if not host.open:
		host._mesh(host._ball(0.09), host._shade(MuseumBuilding.M_IRON.lightened(0.12)), at + Vector3(0, 0.3, 0))
		return
	var fire := GPUParticles3D.new()
	fire.position = at + Vector3(0, 0.3, 0)
	host.add_child(fire)
	fire.amount = 18
	fire.lifetime = 0.8
	fire.local_coords = true
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 20.0
	pm.gravity = Vector3(0, 0.9, 0)
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.55
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.1))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	grad.add_point(0.4, Color(1.0, 0.55, 0.15, 0.9))
	grad.add_point(1.0, Color(0.5, 0.08, 0.03, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	fire.process_material = pm
	var flame := host._cone(0.0, 0.045, 0.1)
	flame.radial_segments = 5
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.vertex_color_use_as_albedo = true
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame.material = fm
	fire.draw_pass_1 = flame


## A well: a round stone kerb, the water dark in it, two posts and a beam,
## a little tiled roof, a bucket on its rope.
## A siege catapult standing in the yard (Kenney's Castle Kit, PROCEDENCIA.json
## kenney-castle-kit), scaled to the castle's own compressed scale, turned
## to face out over the wall.
func catapult(at: Vector3, turn: float) -> void:
	var model := MuseumView.asset("castillo/siege-catapult")
	var low := INF
	var high := -INF
	for p in host._points_of(model):
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var s := 1.1 / maxf(high - low, 0.001)
	model.position = at - Vector3(0, low * s, 0)
	model.rotation.y = turn
	model.scale = Vector3.ONE * s
	host.add_child(model)


## A suit of armour on a plinth, standing proud: the real armadura model
## (the same the props use, at life size), not built from primitives here.
## Scaled to the castle's own compressed scale, its feet on the plinth's cap.
func knight(at: Node3D) -> void:
	host._box_in(at, Vector3(0.52, 0.26, 0.52), host._shade(MuseumBuilding.M_SAND_DARK), Vector3(0, 0.13, 0))
	host._box_in(at, Vector3(0.58, 0.04, 0.58), host._shade(MuseumBuilding.M_TRIM), Vector3(0, 0.28, 0))
	var suit := MuseumView.asset("armadura")
	var low := INF
	var high := -INF
	for p in host._points_of(suit):
		low = minf(low, p.y)
		high = maxf(high, p.y)
	var s := 1.05 / maxf(high - low, 0.001)
	suit.position = Vector3(0, 0.3 - low * s, 0)
	suit.scale = Vector3.ONE * s
	at.add_child(suit)


## A flat disc facing +y (turn it to face out of a wall).
func disc(radius: float, thick: float) -> CylinderMesh:
	var d := CylinderMesh.new()
	d.top_radius = radius
	d.bottom_radius = radius
	d.height = thick
	d.radial_segments = 16
	d.rings = 0
	return d


## A small box to draw with the rest of its colour (_m_flush).
func add_part(size: Vector3, colour: Color, at: Vector3, turned := Basis.IDENTITY) -> void:
	if not host._m_parts.has(colour):
		host._m_parts[colour] = []
	(host._m_parts[colour] as Array).append(Transform3D(turned * Basis.from_scale(size), at))


func flush_parts() -> void:
	var cube := BoxMesh.new()
	for colour: Color in host._m_parts:
		var list: Array = host._m_parts[colour]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = cube
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = MenuStage._material(colour)
		host.add_child(mmi)
	host._m_parts.clear()


## The two lights of a two-light window w across, h tall to where their
## arches spring: side by side, a column's width between them, each with its
## round top; one mesh, its UVs across each light (for the stained glass).
static func lights_mesh(w: float, h: float) -> ArrayMesh:
	var key := Vector2(w, h)
	if MuseumBuilding._m_lights.has(key):
		return MuseumBuilding._m_lights[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lw := (w - MuseumBuilding.M_MULLION) * 0.5
	var tall := h + lw * 0.5
	for sx: int in [-1, 1]:
		var cx := sx * (MuseumBuilding.M_MULLION + lw) * 0.5
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
	MuseumBuilding._m_lights[key] = mesh
	return mesh


## The stained glass, lit or dark (and darker with the museum shut).
func stained_material(lit: bool) -> StandardMaterial3D:
	var key := "%s:%s" % [lit, host.open]
	if not MuseumBuilding._m_glass.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = glass_texture()
		m.albedo_color = Color.WHITE if lit else Color(0.36, 0.34, 0.46)
		if not host.open:
			m.albedo_color = m.albedo_color.darkened(MuseumBuilding.SHUT)
		m.roughness = 0.3
		if host.open:
			# Lit, its colours glow through; dark, just a hint of them.
			m.emission_enabled = true
			m.emission_texture = m.albedo_texture
			m.emission = Color.WHITE
			m.emission_energy_multiplier = 0.35 if lit else 0.06
		MuseumBuilding._m_glass[key] = m
	return MuseumBuilding._m_glass[key]


## Lozenges of coloured glass between lines of lead, a lead edge round it.
static func glass_texture() -> ImageTexture:
	if MuseumBuilding._m_glass_texture == null:
		var img := Image.create(48, 96, false, Image.FORMAT_RGB8)
		var cell := 12.0
		for y in 96:
			for x in 48:
				var u := (x + y) / cell
				var v := (x - y + 96) / cell
				var c: Color = MuseumBuilding.M_LEAD
				var edge := x < 2 or x >= 46 or y < 2 or y >= 94
				if not edge and fposmod(u, 1.0) > 0.16 and fposmod(v, 1.0) > 0.16:
					c = MuseumBuilding.M_STAINED[absi(int(floor(u)) * 7 + int(floor(v)) * 13) % MuseumBuilding.M_STAINED.size()]
				img.set_pixel(x, y, c)
		img.generate_mipmaps()
		MuseumBuilding._m_glass_texture = ImageTexture.create_from_image(img)
	return MuseumBuilding._m_glass_texture
