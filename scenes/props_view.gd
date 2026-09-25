class_name PropsView
extends Node3D
## The things you can knock over (Props), drawn standing, and when knocked,
## handed to the physics engine: the standing model is swapped for rigid
## bodies pushed the way you were going. The bin rolls and spills its
## papers, which float down; the bust's pedestal topples and the bust rolls
## off; the panel falls flat on its face.
##
## Only the view moves: the game knows that it fell and where it stood, and
## nothing about where the pieces end up. The walls and cases near each
## prop get simple colliders so the pieces stop against them.

const METAL := Color("#59606e")
const METAL_DARK := Color("#3a3f4a")
const PAPER := Color("#f1ecdc")
const MARBLE := Color("#ddd6c6")
const MARBLE_DARK := Color("#a89f8c")
const WOOD := Color("#6b4a2e")

var _standing := {}


func build() -> void:
	_colliders()
	for p in Props.list:
		var node := Node3D.new()
		node.position = MuseumView.to_world(p.x, p.y)
		node.rotation.y = atan2(-p.face.x, -p.face.y)
		add_child(node)
		match p.kind:
			"bin": _bin(node)
			"bust":
				_pedestal(node)
				_bust(node, 0.72)
			_: _panel(node, p.id)
		_standing[p.id] = node


## Knock one over: the standing model goes, rigid bodies take its place.
func knock(p: Props.Prop) -> void:
	var node: Node3D = _standing.get(p.id)
	if node == null:
		return
	_standing.erase(p.id)
	var at := node.position
	var yaw := node.rotation.y
	node.queue_free()
	var push := Vector3(cos(p.fall_dir), 0, sin(p.fall_dir))
	Fx.puff(self, at, p.kind == "bust")
	match p.kind:
		"bin":
			var body := _body(at + Vector3(0, 0.21, 0), yaw, 1.2)
			_bin(body, -0.21)
			var shape := CylinderShape3D.new()
			shape.radius = 0.16
			shape.height = 0.42
			_shape(body, shape, Vector3.ZERO)
			body.apply_impulse(push * 1.1, Vector3(0, 0.18, 0))
			# The papers: sheets that drift down, and a few screwed-up balls.
			for i in 7:
				var sheet := i < 4
				var b := _body(at + Vector3(randf_range(-0.05, 0.05), 0.4, randf_range(-0.05, 0.05)), randf() * TAU, 0.05)
				if sheet:
					_piece(b, MuseumView._box(Vector3(0.15, 0.004, 0.2)), PAPER.darkened(randf() * 0.15), Vector3.ZERO)
					var box := BoxShape3D.new()
					box.size = Vector3(0.15, 0.01, 0.2)
					_shape(b, box, Vector3.ZERO)
					b.gravity_scale = 0.25
					b.linear_damp = 3.0
					b.angular_damp = 2.0
				else:
					var ball := SphereMesh.new()
					ball.radius = 0.04
					ball.height = 0.08
					ball.radial_segments = 5
					ball.rings = 3
					_piece(b, ball, PAPER, Vector3.ZERO)
					var sphere := SphereShape3D.new()
					sphere.radius = 0.04
					_shape(b, sphere, Vector3.ZERO)
				var spread := push.rotated(Vector3.UP, randf_range(-0.9, 0.9))
				b.apply_impulse(spread * randf_range(0.015, 0.035) + Vector3(0, 0.012, 0))
				b.angular_velocity = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 4.0
		"bust":
			var column := _body(at + Vector3(0, 0.36, 0), yaw, 3.0)
			_pedestal(column, -0.36)
			var box := BoxShape3D.new()
			box.size = Vector3(0.26, 0.72, 0.26)
			_shape(column, box, Vector3.ZERO)
			column.apply_impulse(push * 1.6, Vector3(0, 0.3, 0))
			var bust := _body(at + Vector3(0, 0.86, 0), yaw, 1.0)
			_bust(bust, -0.14)
			var sphere := SphereShape3D.new()
			sphere.radius = 0.13
			_shape(bust, sphere, Vector3.ZERO)
			bust.apply_impulse(push * 0.9 + Vector3(0, 0.3, 0))
			bust.angular_velocity = push.cross(Vector3.UP) * -5.0
		_:
			var stand := _body(at + Vector3(0, 0.5, 0), yaw, 1.5)
			_panel(stand, p.id, -0.5)
			var post := BoxShape3D.new()
			post.size = Vector3(0.06, 0.9, 0.06)
			_shape(stand, post, Vector3(0, -0.05, 0))
			var board := BoxShape3D.new()
			board.size = Vector3(0.5, 0.36, 0.05)
			_shape(stand, board, Vector3(0, 0.3, 0.02))
			var foot := BoxShape3D.new()
			foot.size = Vector3(0.34, 0.04, 0.26)
			_shape(stand, foot, Vector3(0, -0.48, 0))
			stand.apply_impulse(push * 1.0, Vector3(0, 0.4, 0))


# --- Models: drawn with their foot at y = base ---------------------------------------

## A metal waste-paper bin, open at the top, paper showing.
func _bin(parent: Node3D, base := 0.0) -> void:
	var can := CylinderMesh.new()
	can.top_radius = 0.17
	can.bottom_radius = 0.14
	can.height = 0.42
	can.radial_segments = 12
	_piece(parent, can, METAL, Vector3(0, base + 0.21, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.16
	rim.outer_radius = 0.185
	rim.rings = 12
	_piece(parent, rim, METAL_DARK, Vector3(0, base + 0.42, 0))
	for k in 3:
		var band := CylinderMesh.new()
		band.top_radius = 0.152 + k * 0.009
		band.bottom_radius = band.top_radius
		band.height = 0.015
		band.radial_segments = 12
		_piece(parent, band, METAL_DARK, Vector3(0, base + 0.1 + k * 0.1, 0))
	for k in 3:
		var ball := SphereMesh.new()
		ball.radius = 0.05
		ball.height = 0.09
		ball.radial_segments = 5
		ball.rings = 3
		_piece(parent, ball, PAPER, Vector3(cos(k * 2.1) * 0.07, base + 0.41, sin(k * 2.1) * 0.07))


## A marble pedestal: base, fluted shaft, cap.
func _pedestal(parent: Node3D, base := 0.0) -> void:
	_piece(parent, MuseumView._box(Vector3(0.3, 0.06, 0.3)), MARBLE_DARK, Vector3(0, base + 0.03, 0))
	_piece(parent, MuseumView._box(Vector3(0.22, 0.6, 0.22)), MARBLE, Vector3(0, base + 0.36, 0))
	for k in 4:
		var a := k * PI / 2
		_piece(parent, MuseumView._box(Vector3(0.02, 0.56, 0.02)), MARBLE_DARK, Vector3(cos(a) * 0.111, base + 0.36, sin(a) * 0.111))
	_piece(parent, MuseumView._box(Vector3(0.3, 0.06, 0.3)), MARBLE_DARK, Vector3(0, base + 0.69, 0))


## A marble bust: shoulders, neck, head with a nose and a curl of hair.
func _bust(parent: Node3D, base := 0.0) -> void:
	_piece(parent, MuseumView._box(Vector3(0.26, 0.09, 0.14)), MARBLE, Vector3(0, base + 0.045, 0))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.04
	neck.bottom_radius = 0.05
	neck.height = 0.08
	_piece(parent, neck, MARBLE, Vector3(0, base + 0.12, 0))
	var head := SphereMesh.new()
	head.radius = 0.08
	head.height = 0.19
	_piece(parent, head, MARBLE, Vector3(0, base + 0.23, 0))
	_piece(parent, MuseumView._box(Vector3(0.025, 0.04, 0.04)), MARBLE, Vector3(0, base + 0.22, 0.085))
	var hair := SphereMesh.new()
	hair.radius = 0.085
	hair.height = 0.1
	_piece(parent, hair, MARBLE_DARK, Vector3(0, base + 0.29, -0.015))


## An information panel on a stand, a printed board tilted to be read.
func _panel(parent: Node3D, seed: int, base := 0.0) -> void:
	_piece(parent, MuseumView._box(Vector3(0.34, 0.04, 0.26)), METAL_DARK, Vector3(0, base + 0.02, 0))
	_piece(parent, MuseumView._box(Vector3(0.05, 0.84, 0.05)), METAL, Vector3(0, base + 0.44, 0))
	var board := MeshInstance3D.new()
	board.mesh = MuseumView._box(Vector3(0.5, 0.36, 0.03))
	var m := MuseumView.toon(Color.WHITE)
	m.albedo_texture = _print(seed)
	board.material_override = m
	board.position = Vector3(0, base + 0.8, 0.02)
	board.rotation.x = -0.35
	parent.add_child(board)
	_piece(parent, MuseumView._box(Vector3(0.53, 0.39, 0.02)), WOOD, Vector3(0, base + 0.8, 0.0)).rotation.x = -0.35


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


## The floor, and a box for every wall and case near a prop.
func _colliders() -> void:
	var ground := StaticBody3D.new()
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	ground.add_child(plane)
	add_child(ground)
	var done := {}
	var walls := StaticBody3D.new()
	add_child(walls)
	for p in Props.list:
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var t := p.tile + Vector2i(dx, dy)
				if done.has(t):
					continue
				done[t] = true
				var kind := Museum.tile_at(t.x + 0.5, t.y + 0.5)
				if kind == Tiles.FLOOR:
					continue
				var h := MuseumView.WALL_HEIGHT if kind == Tiles.WALL else MuseumView.CASE_HEIGHT
				var box := BoxShape3D.new()
				box.size = Vector3(1.0 if kind == Tiles.WALL else 0.9, h, 1.0 if kind == Tiles.WALL else 0.9)
				var c := CollisionShape3D.new()
				c.shape = box
				c.position = MuseumView.to_world(t.x + 0.5, t.y + 0.5, h / 2)
				walls.add_child(c)
