class_name ContemporaryBuilding
extends RefCounted
## Constructor del museo de arte contemporáneo: pisos, juntas iluminadas y arte de la plaza.
## MuseumBuilding conserva los recursos comunes, ventanas y estado de selección.
## Este componente añade nodos al mismo edificio y conserva el orden de su RNG.

var host: MuseumBuilding

func _init(building: MuseumBuilding) -> void:
	host = building

func build(rooms: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5077 + host.museum
	# Where each floor starts, up from the glass ground floor.
	var base: Array[float] = []
	var y := MuseumBuilding.C_LOBBY
	for f: Dictionary in MuseumBuilding.C_FLOORS:
		base.append(y)
		y += (f.size as Vector3).y
	var roof_y := y
	host.front_z = 0.0
	host.look_y = 2.57
	host.top = roof_y + 0.9
	host.view = 10.5
	# Fine boxes in their own colours (the skin's ribs, the glass's
	# mullions), all in one MultiMesh: [transform, colour].
	var bits: Array = []
	square(rng, bits)
	lobby(bits)
	# The boxes and the joints under them: lit all through in the town's
	# view, dim in a museum gone into until its room's reached.
	var boxes: Array[MeshInstance3D] = []
	var joints: Array[MeshInstance3D] = []
	for k in MuseumBuilding.C_FLOORS.size():
		boxes.append(floor_box(k, base[k], bits))
		joints.append(floor_joint(k, base[k], host.open and rooms.is_empty(), bits))
	# The giant rubber duck on the first terrace, looking out.
	var duck := Node3D.new()
	duck.position = Vector3(-1.5, base[1], 0.0)
	duck.rotation.y = 0.35
	duck.scale = Vector3.ONE * 1.15
	host.add_child(duck)
	duck(duck)
	# The rooms: a floor each, in order up the tower, the big job's the top.
	var normal := 0
	var count := rooms.size() if not rooms.is_empty() else Story.ROOMS
	for i in count:
		var r: Dictionary = rooms[i] if not rooms.is_empty() else {"boss": i == count - 1, "open": false}
		var k := MuseumBuilding.C_FLOORS.size() - 1
		if not r.boss:
			k = mini(normal, MuseumBuilding.C_FLOORS.size() - 2)
			normal += 1
		var f: Dictionary = MuseumBuilding.C_FLOORS[k]
		var s: Vector3 = f.size
		# Its node in the middle of the wall it is seen from, looking out of
		# it; across and deep, as that wall has them.
		var turn := Basis(Vector3.UP, int(MuseumBuilding.C_FACES[k]) * PI * 0.5)
		var along := s.x if int(MuseumBuilding.C_FACES[k]) % 2 == 0 else s.z
		var deep := s.z if int(MuseumBuilding.C_FACES[k]) % 2 == 0 else s.x
		var node := Node3D.new()
		node.basis = turn
		node.position = Vector3(f.x, base[k] + s.y * 0.5, float(f.front) - s.z * 0.5) + turn.z * deep * 0.5
		host.add_child(node)
		var shown: bool = host.open and r.has("shape") and bool(r.get("open", false))
		var box := boxes[k]
		var joint := joints[k]
		var skin := host._shade(MuseumBuilding.C_SKIN[k % MuseumBuilding.C_SKIN.size()])
		var rest := MuseumBuilding._lit_material(MuseumBuilding.LIT, MuseumBuilding.C_JOINT_GLOW)
		var reached: Material = MuseumBuilding._lit_material(skin, MuseumBuilding.C_ROOM_GLOW)
		if shown:
			joint.material_override = rest
			box.material_override = reached
			if r.boss:
				# The big job's crown, on the roof.
				var crown := Node3D.new()
				crown.position = Vector3(0, s.y * 0.5 + 0.4, -deep * 0.45)
				node.add_child(crown)
				CityStage.crown(crown, Vector3.ZERO, MenuStage.GOLD, 1.6)
		# Nothing of the room is seen: its piece is left empty.
		var piece := Node3D.new()
		node.add_child(piece)
		host.windows.append({"node": node, "back": joint, "glass": joint, "piece": piece, "lock": null, "boss": r.boss, "open": shown,
			"size": Vector2(along, s.y), "frame": [box], "stone": reached, "arch": false, "face": node.basis,
			"rest": rest, "glow": MuseumBuilding._lit_material(MuseumBuilding.LIT_PICKED, MuseumBuilding.C_JOINT_PICKED),
			"frame_glow": MuseumBuilding._lit_material(skin.lerp(MuseumBuilding.LIT_PICKED, MuseumBuilding.C_PICKED_TINT), MuseumBuilding.C_PICKED_GLOW),
			"shape": "floor", "volume": AABB(Vector3(-along * 0.5, -s.y * 0.5 + MuseumBuilding.C_JOINT, -deep), Vector3(along, s.y - MuseumBuilding.C_JOINT, deep))})
	flush_parts(bits)


## Floor k of the tower's box, from y0 up over its joint, blind in its
## skin, the skin's ribs up all four sides. Returns the box.
func floor_box(k: int, y0: float, bits: Array) -> MeshInstance3D:
	var f: Dictionary = MuseumBuilding.C_FLOORS[k]
	var s: Vector3 = f.size
	var x: float = f.x
	var front: float = f.front
	var skin := host._shade(MuseumBuilding.C_SKIN[k % MuseumBuilding.C_SKIN.size()])
	# The ground floor's window of light keeps its full height; the rest,
	# much lower, a quarter of it, so the boxes read as solid with just a
	# thin seam of light, not a stack of lit slabs.
	var joint_h := MuseumBuilding.C_JOINT if k == 0 else MuseumBuilding.C_JOINT * 0.25
	var lo := y0 + joint_h
	var box := host._box(Vector3(s.x, s.y - joint_h, s.z), skin, Vector3(x, (lo + y0 + s.y) * 0.5, front - s.z * 0.5))
	if host.open:
		# White at night: lit a little from the town round it.
		box.material_override = MuseumBuilding._lit_material(skin, MuseumBuilding.C_SKIN_GLOW)
	var tint := host._shade(MuseumBuilding.C_RIB_TINT)
	var r0 := lo + 0.03
	var r1 := y0 + s.y - 0.03
	var n := int((s.x - 0.16) / MuseumBuilding.C_RIB)
	for i in n + 1:
		for z: float in [front + 0.006, front - s.z - 0.006]:
			var at := Vector3(x - (n * MuseumBuilding.C_RIB) * 0.5 + i * MuseumBuilding.C_RIB, (r0 + r1) * 0.5, z)
			bits.append([Transform3D(Basis.from_scale(Vector3(0.02, r1 - r0, 0.014)), at), tint])
	var m := int((s.z - 0.16) / MuseumBuilding.C_RIB)
	for i in m + 1:
		for sx: int in [-1, 1]:
			var at := Vector3(x + sx * (s.x * 0.5 + 0.006), (r0 + r1) * 0.5, front - s.z * 0.5 - (m * MuseumBuilding.C_RIB) * 0.5 + i * MuseumBuilding.C_RIB)
			bits.append([Transform3D(Basis.from_scale(Vector3(0.014, r1 - r0, 0.02)), at), tint])
	return box


## The joint under floor k's box (from y0 up, C_JOINT tall): glass set back
## C_JOINT_IN from its front and its side, lit (lit), dim (open, not lit)
## or dark, thin mullions across it. Returns the glass.
func floor_joint(k: int, y0: float, lit: bool, bits: Array) -> MeshInstance3D:
	var f: Dictionary = MuseumBuilding.C_FLOORS[k]
	var s: Vector3 = f.size
	var x: float = f.x
	var front: float = float(f.front) - MuseumBuilding.C_JOINT_IN
	var w := s.x - MuseumBuilding.C_JOINT_IN * 2.0
	var d := s.z - MuseumBuilding.C_JOINT_IN * 2.0
	var joint_h := MuseumBuilding.C_JOINT if k == 0 else MuseumBuilding.C_JOINT * 0.25
	var cy := y0 + joint_h * 0.5
	var glass := host._box(Vector3(w, joint_h, d), host._shade(MuseumBuilding.GLASS_DARK), Vector3(x, cy, front - d * 0.5))
	if host.open:
		glass.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT, MuseumBuilding.C_JOINT_GLOW) if lit else MuseumBuilding._lit_material(MuseumBuilding.C_JOINT_OFF, MuseumBuilding.C_JOINT_DIM)
	var mullion := host._shade(MuseumBuilding.C_MULLION)
	var n := int(w / 0.3)
	for i in n + 1:
		for z: float in [front + 0.008, front - d - 0.008]:
			var at := Vector3(x - w * 0.5 + i * (w / n), cy, z)
			bits.append([Transform3D(Basis.from_scale(Vector3(0.018, joint_h, 0.016)), at), mullion])
	var m := int(d / 0.3)
	for i in m + 1:
		for sx: int in [-1, 1]:
			var at := Vector3(x + sx * (w * 0.5 + 0.008), cy, front - i * (d / m))
			bits.append([Transform3D(Basis.from_scale(Vector3(0.016, joint_h, 0.018)), at), mullion])
	return glass


## The glass ground floor under the first box: lit through when open, its
## mullions, the doors in the middle, the museum's name in its colour over
## them; a banner in its colour on a pole and two slim lamps before it.
func lobby(bits: Array) -> void:
	var w := 3.2
	var d := 2.3
	var glass := host._box(Vector3(w, MuseumBuilding.C_LOBBY, d), host._shade(MuseumBuilding.GLASS_DARK.lightened(0.1)), Vector3(0, MuseumBuilding.C_LOBBY * 0.5, MuseumBuilding.C_LOBBY_Z - d * 0.5))
	if host.open:
		glass.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT.lerp(Color.WHITE, 0.35), 0.75)
	var mullion := host._shade(MuseumBuilding.C_MULLION)
	var n := int(w / 0.4)
	for i in n + 1:
		var x := -w * 0.5 + i * (w / n)
		for z: float in [MuseumBuilding.C_LOBBY_Z + 0.01, MuseumBuilding.C_LOBBY_Z - d - 0.01]:
			bits.append([Transform3D(Basis.from_scale(Vector3(0.03, MuseumBuilding.C_LOBBY, 0.03)), Vector3(x, MuseumBuilding.C_LOBBY * 0.5, z)), mullion])
	var m := int(d / 0.4)
	for i in m + 1:
		var z := MuseumBuilding.C_LOBBY_Z - i * (d / m)
		for sx: int in [-1, 1]:
			bits.append([Transform3D(Basis.from_scale(Vector3(0.03, MuseumBuilding.C_LOBBY, 0.03)), Vector3(sx * (w * 0.5 + 0.01), MuseumBuilding.C_LOBBY * 0.5, z)), mullion])
	# A dark slab over the glass (the first joint's light apart from the
	# lobby's), the doors in a dark frame.
	host._box(Vector3(w + 0.06, 0.06, d + 0.06), mullion, Vector3(0, MuseumBuilding.C_LOBBY - 0.03, MuseumBuilding.C_LOBBY_Z - d * 0.5))
	host._box(Vector3(0.62, 0.44, 0.03), mullion, Vector3(0, 0.22, MuseumBuilding.C_LOBBY_Z + 0.02))
	var door := host._box(Vector3(0.54, 0.4, 0.03), host._shade(MuseumBuilding.GLASS_DARK), Vector3(0, 0.2, MuseumBuilding.C_LOBBY_Z + 0.03))
	if host.open:
		door.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT, 1.2)
	host._box(Vector3(0.02, 0.4, 0.04), mullion, Vector3(0, 0.2, MuseumBuilding.C_LOBBY_Z + 0.04))
	# The banner on its pole, left of the doors; the lamps.
	var metal := host._shade(MuseumBuilding.C_METAL)
	host._box(Vector3(0.035, 1.3, 0.035), metal, Vector3(-1.95, 0.65, MuseumBuilding.C_LOBBY_Z + 0.65))
	host._box(Vector3(0.2, 0.7, 0.02), host._shade(host._colour), Vector3(-1.84, 0.85, MuseumBuilding.C_LOBBY_Z + 0.65))
	host._box(Vector3(0.2, 0.05, 0.025), host._shade(MuseumBuilding.C_WHITE), Vector3(-1.84, 0.62, MuseumBuilding.C_LOBBY_Z + 0.65))
	for sx in [-1, 1]:
		var x: float = sx * 1.25
		host._box(Vector3(0.03, 0.8, 0.03), metal, Vector3(x, 0.4, MuseumBuilding.C_SQUARE - 0.35))
		var lamp := host._box(Vector3(0.06, 0.2, 0.06), MuseumBuilding.LIT, Vector3(x, 0.86, MuseumBuilding.C_SQUARE - 0.35))
		if host.open:
			lamp.material_override = MuseumBuilding._lit_material(MuseumBuilding.LIT, 3.0)


## The square: the lot in pale concrete, big polished slabs before the
## tower, long white benches, and the giant banana on its plinth.
func square(rng: RandomNumberGenerator, bits: Array) -> void:
	host._box(Vector3(5.5, 0.03, 5.5), host._shade(MuseumBuilding.C_GROUND), Vector3(0, 0.015, 0))
	var slab := 0.66
	var nx := 8
	var nz := int((MuseumBuilding.C_SQUARE - MuseumBuilding.C_LOBBY_Z) / slab)
	for i in nx:
		for j in nz:
			var at := Vector3((i - (nx - 1) * 0.5) * slab, 0.035, MuseumBuilding.C_SQUARE - (j + 0.5) * slab)
			bits.append([Transform3D(Basis.from_scale(Vector3(slab - 0.025, 0.03, slab - 0.025)), at), host._shade(MuseumBuilding.C_CONCRETE[rng.randi() % MuseumBuilding.C_CONCRETE.size()])])
	# The benches, long and low, each on two dark feet.
	for b in [Vector3(-1.2, 0, 1.55), Vector3(1.15, 0, 2.05)]:
		var at: Vector3 = b
		host._box(Vector3(1.1, 0.07, 0.3), host._shade(MuseumBuilding.C_WHITE), at + Vector3(0, 0.2, 0))
		for sx in [-1, 1]:
			host._box(Vector3(0.06, 0.17, 0.26), host._shade(MuseumBuilding.C_MULLION), at + Vector3(sx * 0.42, 0.1, 0))
	# The banana: the real model (Plewr's, CC0; PROCEDENCIA.json
	# plewr-banana), lying curved on a white plinth.
	var plinth := Vector3(1.95, 0, 1.0)
	host._box(Vector3(0.5, 0.32, 0.5), host._shade(MuseumBuilding.C_WHITE), plinth + Vector3(0, 0.16, 0))
	var banana := MuseumView.asset("moderno/banana")
	var b_low := INF
	var b_high := -INF
	for p in host._points_of(banana):
		b_low = minf(b_low, p.y)
		b_high = maxf(b_high, p.y)
	var b_s := 0.85 / maxf(b_high - b_low, 0.001)
	banana.position = plinth + Vector3(0, 0.32 - b_low * b_s, 0)
	banana.rotation.y = -0.5
	banana.scale = Vector3.ONE * b_s
	host.add_child(banana)
	var b_yellow := host._shade(MuseumBuilding.C_BANANA)
	for mi: MeshInstance3D in banana.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = MenuStage._material(b_yellow)
		pop_art_material(mi)


## A giant rubber duck, its head to +x: a squat yellow body, a round head,
## an orange beak, two black eyes, its tail cocked.
func duck(at: Node3D) -> void:
	var yellow := host._shade(MuseumBuilding.C_DUCK)
	var body := pop_art_material(host._mesh_in(at, host._ball(0.22), yellow, Vector3(0, 0.17, 0)))
	body.scale = Vector3(1.35, 0.8, 1.0)
	pop_art_material(host._mesh_in(at, host._ball(0.14), yellow, Vector3(0.17, 0.4, 0)))
	var beak := host._box_in(at, Vector3(0.12, 0.045, 0.12), host._shade(MuseumBuilding.C_BEAK), Vector3(0.33, 0.37, 0))
	beak.rotation.z = -0.15
	for sz in [-1, 1]:
		host._mesh_in(at, host._ball(0.022), host._shade(Color("#1a1420")), Vector3(0.26, 0.45, sz * 0.08))
	var tail := pop_art_material(host._mesh_in(at, host._cone(0.08, 0.0, 0.16), yellow, Vector3(-0.3, 0.28, 0)))
	tail.rotation.z = 0.8


## A piece of pop art, lit a little of its own when the museum's open.
func pop_art_material(mi: MeshInstance3D) -> MeshInstance3D:
	if host.open:
		mi.material_override = MuseumBuilding._lit_material((mi.material_override as StandardMaterial3D).albedo_color, MuseumBuilding.C_POP_GLOW)
	return mi


## The fine boxes gathered along the way ([transform, colour]), all in one
## MultiMesh.
func flush_parts(bits: Array) -> void:
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
	host.add_child(mmi)
