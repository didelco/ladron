class_name PropsView
extends Node3D
## The things you can knock over (Props), as real rigid bodies from the
## start: a bin, a bust on its pedestal, a panel on its stand, a suit of
## armour, standing at rest until something shoves them. Each thief carries an
## invisible body (moved with the thief, never pushed back) that shoves
## whatever it walks into: a bin you bump tips over and rolls, and spills its
## papers; the armour goes over and falls to pieces; one already down gets
## kicked along when you walk over it.
##
## The physics is the truth here, and the game hears about it: `tipped`
## when a prop first leans past falling (the game marks it fallen, with the
## crash guards hear), `kicked` whenever a fallen piece is sent moving by a
## thief (the clatter of a rolling bin, the rustle of paper), for the game to
## turn into noise.

## strength 0..1: how hard it went over (a nudge, or a full-tilt crash).
signal tipped(id: int, dir: float, at: Vector2, strength: float)
signal kicked(kind: String, at: Vector2, strength: float)

## Drawn this much bigger than life, to read from the camera up high.
const K := 1.35
const PAPER := Color("#f1ecdc")
## Leaning further than this from upright, it has fallen.
const TIPPED := 0.64
## A piece faster than this near a thief makes a sound; not again for a while.
const KICK_SPEED := 0.55
const KICK_EVERY := 0.35
## The thief's shoving body: a capsule about a person wide.
const THIEF_RADIUS := 0.24
## The suit of armour is drawn life size (not K bigger: it would stand over
## the walls), its body held at about its middle.
const ARMOUR_MID := 0.55

## prop id -> the bodies that make it up; the first one decides "tipped"
var _bodies := {}
var _tipped := {}
## every loose body (a prop's, and each paper) -> [kind, seconds to the next kick]
var _loose := {}
var _movers: Array[AnimatableBody3D] = []
## every loose body -> where it last was clear of the walls (world)
var _clear_at := {}


func build() -> void:
	_colliders()
	for p in Props.list:
		var at := MuseumView.to_world(p.x, p.y)
		var yaw := atan2(-p.face.x, -p.face.y)
		var parts: Array[RigidBody3D] = []
		match p.kind:
			"bin":
				var body := _body(at + Vector3(0, 0.21 * K, 0), yaw, 1.0)
				_bin(_look(body), -0.21)
				var shape := CylinderShape3D.new()
				shape.radius = 0.16 * K
				shape.height = 0.42 * K
				_shape(body, shape, Vector3.ZERO)
				parts.append(body)
			"bust":
				var column := _body(at + Vector3(0, 0.36 * K, 0), yaw, 2.5)
				_pedestal(_look(column), -0.36)
				var box := BoxShape3D.new()
				box.size = Vector3(0.26, 0.72, 0.26) * K
				_shape(column, box, Vector3.ZERO)
				var bust := _body(at + Vector3(0, 0.765 * K, 0), yaw, 0.8)
				_bust(_look(bust), -0.045, p.id)
				var base := BoxShape3D.new()
				base.size = Vector3(0.24, 0.09, 0.13) * K
				_shape(bust, base, Vector3.ZERO)
				var head := SphereShape3D.new()
				head.radius = 0.09 * K
				_shape(bust, head, Vector3(0, 0.18, 0) * K)
				parts.append_array([column, bust])
			"armour":
				var suit := _body(at + Vector3(0, ARMOUR_MID, 0), yaw, 6.0)
				var look := MuseumView.asset("armadura")
				look.position.y = -ARMOUR_MID
				suit.add_child(look)
				var box := BoxShape3D.new()
				box.size = Vector3(0.6, 1.15, 0.45)
				_shape(suit, box, Vector3(0, 0.575 - ARMOUR_MID, 0))
				parts.append(suit)
			_:
				var stand := _body(at + Vector3(0, 0.5 * K, 0), yaw, 1.2)
				_panel(_look(stand), p.id, -0.5)
				var post := BoxShape3D.new()
				post.size = Vector3(0.06, 0.9, 0.06) * K
				_shape(stand, post, Vector3(0, -0.05, 0) * K)
				var board := BoxShape3D.new()
				board.size = Vector3(0.5, 0.36, 0.05) * K
				_shape(stand, board, Vector3(0, 0.3, 0.02) * K)
				var foot := BoxShape3D.new()
				foot.size = Vector3(0.34, 0.04, 0.26) * K
				_shape(stand, foot, Vector3(0, -0.48, 0) * K)
				parts.append(stand)
		for b in parts:
			# Asleep until something touches it: dozens of props cost nothing.
			b.sleeping = true
			_loose[b] = [p.kind, 0.0]
		_bodies[p.id] = parts


## One shoving body per thief, following them.
func set_thieves(count: int) -> void:
	for m in _movers:
		m.queue_free()
	_movers.clear()
	for i in count:
		var m := AnimatableBody3D.new()
		m.sync_to_physics = true
		var capsule := CapsuleShape3D.new()
		capsule.radius = THIEF_RADIUS
		capsule.height = 1.0
		var c := CollisionShape3D.new()
		c.shape = capsule
		c.position = Vector3(0, 0.5, 0)
		m.add_child(c)
		add_child(m)
		_movers.append(m)


## Where the thieves are this frame (world positions), out ones far away.
func move_thieves(positions: Array[Vector3]) -> void:
	for i in mini(positions.size(), _movers.size()):
		_movers[i].global_position = positions[i]


## Push one over on purpose: a shove at the top, away from the thief.
func shove(p: Props.Prop) -> void:
	var push := Vector3(cos(p.fall_dir), 0, sin(p.fall_dir))
	for b in _bodies.get(p.id, []):
		var body := b as RigidBody3D
		body.sleeping = false
		body.apply_impulse(push * body.mass * 1.6, Vector3(0, 0.3 * K, 0))


func _physics_process(dt: float) -> void:
	_keep_out_of_walls()
	# Fallen yet? The first body of each prop decides.
	for id in _bodies:
		if _tipped.has(id):
			continue
		var main_body: RigidBody3D = _bodies[id][0]
		if main_body.global_basis.y.dot(Vector3.UP) < cos(TIPPED):
			_tipped[id] = true
			var lean := main_body.global_basis.y
			var at := Vector2(main_body.global_position.x + Museum.w / 2.0, main_body.global_position.z + Museum.h / 2.0)
			# How hard: the speed it is falling at, and the spin; a bust's
			# pedestal going over drags the bust down harder still.
			var force := main_body.linear_velocity.length() + main_body.angular_velocity.length() * 0.35
			tipped.emit(id, atan2(lean.z, lean.x), at, clampf(force / 3.0, 0.0, 1.0))
			var kind: String = _loose[main_body][0]
			Fx.puff(self, main_body.global_position * Vector3(1, 0, 1), kind == "bust")
			if kind == "bin":
				_spill(main_body.global_position, Vector3(lean.x, 0, lean.z).normalized())
			elif kind == "armour":
				_fall_apart(id, main_body)
	# Kicked about by a thief: a sound, now and then.
	for b in _loose:
		var entry: Array = _loose[b]
		entry[1] = maxf(0.0, entry[1] - dt)
		var body := b as RigidBody3D
		if entry[1] > 0.0 or body.sleeping or body.linear_velocity.length() < KICK_SPEED:
			continue
		var near := false
		for m in _movers:
			if m.global_position.distance_to(body.global_position * Vector3(1, 0, 1)) < 0.9:
				near = true
		if not near:
			continue
		entry[1] = KICK_EVERY
		kicked.emit(entry[0], Vector2(body.global_position.x + Museum.w / 2.0, body.global_position.z + Museum.h / 2.0), minf(1.0, body.linear_velocity.length() / 2.5))


## The last word on walls: a piece squeezed between a thief (who pushes
## with no give) and a wall can be forced into it. Any piece whose middle
## ends up inside a wall or case is put back where it last stood clear, and
## stopped.
func _keep_out_of_walls() -> void:
	for b in _loose:
		var body := b as RigidBody3D
		if not is_instance_valid(body):
			continue
		var at := body.global_position
		var tile := Museum.tile_at(at.x + Museum.w / 2.0, at.z + Museum.h / 2.0)
		var inside := tile == Tiles.WALL or (tile == Tiles.COVER and at.y < MuseumView.CASE_HEIGHT)
		if not inside:
			_clear_at[body] = at
		elif _clear_at.has(body):
			body.global_position = _clear_at[body]
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity *= 0.3


## The bin's papers, out on the floor: sheets that drift down, a few
## screwed-up balls. They stay about to be kicked (and rustle when they are).
func _spill(at: Vector3, towards: Vector3) -> void:
	for i in 8:
		var sheet := i < 5
		var b := _body(at + Vector3(randf_range(-0.08, 0.08), 0.25, randf_range(-0.08, 0.08)), randf() * TAU, 0.05)
		if sheet:
			_piece(b, MuseumView._box(Vector3(0.15, 0.004, 0.2) * K), PAPER.darkened(randf() * 0.15), Vector3.ZERO)
			var box := BoxShape3D.new()
			box.size = Vector3(0.15, 0.01, 0.2) * K
			_shape(b, box, Vector3.ZERO)
			b.gravity_scale = 0.3
			b.linear_damp = 2.5
			b.angular_damp = 2.0
		else:
			var ball := SphereMesh.new()
			ball.radius = 0.045 * K
			ball.height = 0.09 * K
			ball.radial_segments = 5
			ball.rings = 3
			_piece(b, ball, PAPER, Vector3.ZERO)
			var sphere := SphereShape3D.new()
			sphere.radius = 0.045 * K
			_shape(b, sphere, Vector3.ZERO)
		var spread := towards.rotated(Vector3.UP, randf_range(-1.0, 1.0))
		b.apply_impulse(spread * randf_range(0.03, 0.06) + Vector3(0, 0.015, 0))
		b.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 4.0
		_loose[b] = ["paper", 0.3]


## The suit of armour, going over: from here on each piece of it (art/armadura.blend:
## stand, legs, torso, arms, helm, lance) is a body of its own, moving as it
## was, nudged a little apart — the helm rolls off, the lance clatters away.
## The pieces never collide with each other: they start fitted together, and
## would fly apart like a bomb; they meet the floor, the walls and the thieves.
func _fall_apart(id: int, suit: RigidBody3D) -> void:
	var pieces: Array[RigidBody3D] = []
	for mi: MeshInstance3D in suit.find_children("*", "MeshInstance3D", true, false):
		var box := mi.get_aabb()
		var b := _body(Vector3.ZERO, 0.0, clampf(box.size.x * box.size.y * box.size.z * 60.0, 0.3, 2.0))
		# Bodies are never scaled: the body takes the piece's place and turn,
		# the piece keeps any scale of its own.
		b.global_transform = Transform3D(mi.global_basis.orthonormalized(), mi.global_position)
		mi.reparent(b)
		var shape := BoxShape3D.new()
		shape.size = (box.size * 0.9).max(Vector3.ONE * 0.03)
		_shape(b, shape, box.get_center())
		var arm := b.global_position - suit.global_position
		b.linear_velocity = suit.linear_velocity + suit.angular_velocity.cross(arm)
		b.angular_velocity = suit.angular_velocity
		var spread := Vector3(randf() - 0.5, 0, randf() - 0.5).normalized()
		var away := (Vector3(arm.x, 0, arm.z).normalized() + spread).normalized()
		b.apply_impulse((away * randf_range(0.6, 1.1) + Vector3.UP * randf_range(0.1, 0.3)) * b.mass)
		b.angular_velocity += Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 3.0
		for other in pieces:
			b.add_collision_exception_with(other)
		_loose[b] = ["armour", 0.3]
		pieces.append(b)
	_loose.erase(suit)
	_bodies[id] = pieces
	suit.queue_free()


## Models hang from a scaled child: bodies themselves are never scaled
## (physics does not like it), their shapes are sized by K instead.
func _look(body: Node3D) -> Node3D:
	var l := Node3D.new()
	l.scale = Vector3.ONE * K
	body.add_child(l)
	return l


# --- Models: drawn with their foot at y = base ---------------------------------------

## One prop on its own, standing, for a picture (the assets screen): the
## same model the museum stands about, without its physics.
static func model(kind: String) -> Node3D:
	var root := Node3D.new()
	var look := Node3D.new()
	look.scale = Vector3.ONE * K
	root.add_child(look)
	var pv := PropsView.new()
	match kind:
		"bin": pv._bin(look)
		"bust":
			pv._pedestal(look)
			pv._bust(look, 0.72)
		"panel": pv._panel(look, 1)
		"armour": root.add_child(MuseumView.asset("armadura"))
	pv.free()
	return root


## A metal waste-paper bin, open at the top, paper showing (art/papelera.blend).
func _bin(parent: Node3D, base := 0.0) -> void:
	_model(parent, "papelera", base)


## A marble pedestal: base, fluted shaft, cap (art/pedestal.blend).
func _pedestal(parent: Node3D, base := 0.0) -> void:
	_model(parent, "pedestal", base)


## What stands on a pedestal, one per prop: a bust (art/busto_*.blend), or
## something that has no business being in a museum.
const ON_PEDESTALS := ["busto_emperador", "busto_dama", "busto_filosofo", "busto_reina", "regadera", "vater"]


func _bust(parent: Node3D, base := 0.0, which := 0) -> void:
	_model(parent, ON_PEDESTALS[which % ON_PEDESTALS.size()], base)


## An information panel on a stand, a printed board tilted to be read
## (art/panel.blend); the print on its board is drawn here, one per panel.
func _panel(parent: Node3D, seed: int, base := 0.0) -> void:
	var stand := _model(parent, "panel", base)
	var board := stand.find_child("board", true, false) as MeshInstance3D
	var m := MuseumView.toon(Color.WHITE)
	m.albedo_texture = _print(seed)
	board.material_override = m


func _model(parent: Node3D, name: String, base: float) -> Node3D:
	var node := MuseumView.asset(name)
	node.position.y = base
	parent.add_child(node)
	return node


## The board's print: a coloured title bar, a picture and lines of text.
static func _print(seed: int) -> ImageTexture:
	var img := Image.create(50, 36, false, Image.FORMAT_RGBA8)
	img.fill(Color("#f4efe2"))
	var colour: Color = [Color("#2f6f9f"), Color("#9b2c3f"), Color("#3d7a4a"), Color("#b07a1c")][seed % 4]
	img.fill_rect(Rect2i(0, 0, 50, 8), colour)
	img.fill_rect(Rect2i(3, 3, 20, 2), Color("#f4efe2"))
	img.fill_rect(Rect2i(3, 11, 16, 14), colour.lightened(0.35))
	img.fill_rect(Rect2i(6, 15, 10, 7), colour.darkened(0.2))
	for k in 6:
		img.fill_rect(Rect2i(22, 11 + k * 4, 24 - (k % 3) * 4, 1), Color("#6d6a78"))
	for k in 2:
		img.fill_rect(Rect2i(3, 28 + k * 4, 43 - k * 10, 1), Color("#6d6a78"))
	img.resize(200, 144, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


# --- Physics ----------------------------------------------------------------------

func _body(at: Vector3, yaw: float, mass: float) -> RigidBody3D:
	var b := RigidBody3D.new()
	b.mass = mass
	b.position = at
	b.rotation.y = yaw
	b.continuous_cd = true
	var mat := PhysicsMaterial.new()
	mat.friction = 0.7
	mat.bounce = 0.15
	b.physics_material_override = mat
	add_child(b)
	return b


func _shape(body: RigidBody3D, shape: Shape3D, at: Vector3) -> void:
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position = at
	body.add_child(c)


func _piece(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MuseumView.toon(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


## The floor, and every wall and case in the museum: a kicked bin can roll
## anywhere. Walls in a row are one long box, so there are few of them.
func _colliders() -> void:
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	ground.add_child(plane)
	add_child(ground)
	var walls := StaticBody3D.new()
	add_child(walls)
	var add_box := func(x0: int, x1: int, y: int, kind: int) -> void:
		var h := MuseumView.WALL_HEIGHT if kind == Tiles.WALL else MuseumView.CASE_HEIGHT
		var inset := 0.0 if kind == Tiles.WALL else 0.1
		var box := BoxShape3D.new()
		box.size = Vector3(x1 - x0 + 1 - inset, h, 1.0 - inset)
		var c := CollisionShape3D.new()
		c.shape = box
		c.position = MuseumView.to_world((x0 + x1 + 1) / 2.0, y + 0.5, h / 2)
		walls.add_child(c)
	for y in Museum.h:
		var x := 0
		while x < Museum.w:
			var kind := Museum.tile_at(x + 0.5, y + 0.5)
			if kind == Tiles.FLOOR:
				x += 1
				continue
			# Cases one by one (they stand apart); walls as long as the row runs.
			var end := x
			while kind == Tiles.WALL and end + 1 < Museum.w and Museum.tile_at(end + 1.5, y + 0.5) == Tiles.WALL:
				end += 1
			add_box.call(x, end, y, kind)
			x = end + 1
