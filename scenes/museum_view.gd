class_name MuseumView
extends Node3D
## The museum as drawn: floor, walls, cases and the emergency lighting. Built
## once per round from Museum; nothing here changes while the round runs.
## Port of the web version's Floor, Walls, Exhibits and EmergencyLights, kept
## simple: no paintings or specimens yet.

const WALL_HEIGHT := 1.15
## The shell is only a little taller than the partitions, and only where the
## void is not to the south: the camera never turns, so a wall with the void
## south of it is always between it and the player.
const OUTER_HEIGHT := 1.45
const CAP_H := 0.07
const TRIM_H := 0.025
const SKIRT_H := 0.12
const CASE_HEIGHT := 0.82
const MAX_EMERGENCY := 10

const C := {
	"night": Color("#0f0d14"),
	"floor": Color("#2b2834"),
	"floor_line": Color("#474357"),
	"rope": Color("#8e2036"),
	"gold": Color("#f0c46a"),
	"gold_dim": Color("#9a7a3c"),
	"wall_side": Color("#211d29"),
	"wall_cap": Color("#6f6479"),
	"ink": Color("#08070c"),
	"case_dark": Color("#232634"),
	"glass": Color("#a8d8e8"),
	"emergency": Color("#4ade80"),
}


func build() -> void:
	_floor()
	_walls()
	_cases()
	_emergency_lights()


static func to_world(x: float, y: float, height := 0.0) -> Vector3:
	return Vector3(x - Museum.w / 2.0, height, y - Museum.h / 2.0)


static func toon(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


# --- Floor -------------------------------------------------------------------

## Marble slabs in two tones, a baked shadow where the floor meets anything
## solid (there is no ambient occlusion to do it for us), and rope barriers a
## pace out from the walls. Painted once into an image.
func _floor() -> void:
	var w := Museum.w
	var h := Museum.h
	# Pixels per tile: sharp on a small plan, within one texture on a big one.
	var px := mini(32, 4096 / maxi(w, h))
	var img := Image.create(w * px, h * px, false, Image.FORMAT_RGBA8)
	img.fill(C.floor)
	var solid := func(x: int, y: int) -> bool:
		return x < 0 or y < 0 or x >= w or y >= h or Museum.grid[y * w + x] != Tiles.FLOOR

	# Slabs, two tiles across, as a checkerboard of lighter and darker stone.
	var slab := px * 2
	for sy in range(0, h * px, slab):
		for sx in range(0, w * px, slab):
			var light := ((sx + sy) / slab) % 2 == 0
			img.fill_rect(Rect2i(sx, sy, slab, slab), C.floor.lightened(0.05) if light else C.floor.darkened(0.12))
	# Grout.
	for x in range(0, w * px, slab):
		img.fill_rect(Rect2i(x, 0, 1, h * px), C.floor_line)
	for y in range(0, h * px, slab):
		img.fill_rect(Rect2i(0, y, w * px, 1), C.floor_line)

	# Contact shadow: every floor tile darkens along each edge it shares with
	# something solid, in a few bands; corners get both and come out darkest.
	var bands := 5
	var reach := int(px * 0.42)
	for y in h:
		for x in w:
			if solid.call(x, y):
				continue
			for d in Museum.DIRS:
				if not solid.call(x + d.x, y + d.y):
					continue
				# Cases are waist-high and cast a lighter shadow than a wall.
				var wall := Museum.tile_at(x + d.x + 0.5, y + d.y + 0.5) != Tiles.COVER
				var strength := 0.55 if wall else 0.4
				for b in bands:
					var depth := reach * (b + 1) / bands
					var alpha := strength * (1.0 - float(b) / bands) / bands * 2.0
					var r: Rect2i
					if d.x == -1:
						r = Rect2i(x * px, y * px, depth, px)
					elif d.x == 1:
						r = Rect2i((x + 1) * px - depth, y * px, depth, px)
					elif d.y == -1:
						r = Rect2i(x * px, y * px, px, depth)
					else:
						r = Rect2i(x * px, (y + 1) * px - depth, px, depth)
					_blend_rect(img, r, Color(0, 0, 0, alpha))

	# Rope barriers along the walls of the long galleries: posts every two
	# tiles, a rope between them, a pace out from the wall.
	for y in range(1, h - 1):
		for side in [-1, 1]:
			var run := 0
			for x in range(0, w + 1):
				var along: bool = x < w and not solid.call(x, y) and Museum.grid[(y + side) * w + x] == Tiles.WALL
				if along:
					run += 1
					continue
				if run >= 4:
					var cy: int = y * px + px / 2 + side * int(px * 0.18)
					var x0 := (x - run) * px + px / 2
					var x1 := x * px - px / 2
					img.fill_rect(Rect2i(x0, cy - 1, x1 - x0, 3), C.rope)
					var post := x0
					while post <= x1:
						img.fill_rect(Rect2i(post - 3, cy - 3, 7, 7), C.gold)
						post += px * 2
				run = 0

	# Off the building: no floor, just the night.
	for y in h:
		for x in w:
			if Museum.is_outside(x, y):
				img.fill_rect(Rect2i(x * px, y * px, px, px), C.night)

	var tex := ImageTexture.create_from_image(img)
	var m := toon(Color.WHITE)
	m.albedo_texture = tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, h)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = m
	add_child(node)


## fill_rect replaces pixels; a shadow has to darken what is there.
static func _blend_rect(img: Image, r: Rect2i, c: Color) -> void:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	for yy in range(r.position.y, r.end.y):
		for xx in range(r.position.x, r.end.x):
			img.set_pixel(xx, yy, img.get_pixel(xx, yy).blend(c))


# --- Walls -------------------------------------------------------------------

## Every wall block, its moulded cap with a gold line under it, and a skirting
## board. The cap is lit only along the edge of a wall mass: a thick block of
## wall is a roof seen from above, and lit all over it was the biggest,
## brightest thing on screen.
func _walls() -> void:
	var inner: Array[Vector2i] = []
	var outer: Array[Vector2i] = []
	for y in Museum.h:
		for x in Museum.w:
			if Museum.grid[y * Museum.w + x] != Tiles.WALL or Museum.is_outside(x, y):
				continue
			var edge := false
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1)]:
				if Museum.is_outside(x + d.x, y + d.y):
					edge = true
			(outer if edge else inner).append(Vector2i(x, y))
	for set_and_h in [[inner, WALL_HEIGHT], [outer, OUTER_HEIGHT]]:
		var cells: Array[Vector2i] = set_and_h[0]
		var wh: float = set_and_h[1]
		_instances(_box(Vector3(1, wh, 1)), cells, wh / 2, toon(C.wall_side), 0.22)
		_instances(_box(Vector3(1.04, CAP_H, 1.04)), cells, wh + CAP_H / 2, toon(C.wall_cap), 0.14, true)
		_instances(_box(Vector3(1.02, TRIM_H, 1.02)), cells, wh - TRIM_H * 1.5, toon(C.gold_dim))
		_instances(_box(Vector3(1.03, SKIRT_H, 1.03)), cells, SKIRT_H / 2, toon(C.ink))


func _cap_shade(t: Vector2i) -> float:
	for d in Museum.DIRS:
		var x := t.x + d.x
		var y := t.y + d.y
		if x >= 0 and y >= 0 and x < Museum.w and y < Museum.h and Museum.grid[y * Museum.w + x] != Tiles.WALL:
			return 1.0
	return 0.45


# --- Cases ---------------------------------------------------------------------

## A display case on every piece of cover: dark base, pale glass, brass edge.
## The same waist height the rules use: behind one, on all fours, you are hidden.
func _cases() -> void:
	var tiles := Museum.cover_tiles
	_instances(_box(Vector3(0.9, 0.4, 0.9)), tiles, 0.2, toon(C.case_dark))
	var glass := toon(C.glass)
	glass.albedo_color.a = 0.4
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_instances(_box(Vector3(0.8, 0.42, 0.8)), tiles, 0.61, glass)
	# The brass rim is a frame, not a lid: four bars round the top of the glass.
	var gold := toon(C.gold)
	for side in [Vector3(0, 0, 0.39), Vector3(0, 0, -0.39)]:
		_instances(_box(Vector3(0.82, 0.03, 0.035)), tiles, CASE_HEIGHT, gold, 0.0, false, side)
	for side in [Vector3(0.39, 0, 0), Vector3(-0.39, 0, 0)]:
		_instances(_box(Vector3(0.035, 0.03, 0.82)), tiles, CASE_HEIGHT, gold, 0.0, false, side)


# --- Emergency lights ------------------------------------------------------------

## A few green fittings along the corridor inside the outer wall: enough to
## find your way by, nowhere near enough to search by.
func _emergency_lights() -> void:
	var spots: Array[Vector2i] = []
	for y in range(1, Museum.h - 1):
		for x in range(1, Museum.w - 1):
			if Museum.is_ring(x, y) and Museum.grid[y * Museum.w + x] == Tiles.FLOOR and (x * 3 + y * 5) % 11 == 0:
				spots.append(Vector2i(x, y))
	var every := maxi(1, ceili(spots.size() / float(MAX_EMERGENCY)))
	var fitting := StandardMaterial3D.new()
	fitting.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fitting.albedo_color = C.emergency
	for i in range(0, spots.size(), every):
		var s := spots[i]
		var light := OmniLight3D.new()
		light.light_color = C.emergency
		light.light_energy = 0.8
		light.omni_range = 5.0
		light.position = to_world(s.x + 0.5, s.y + 0.5, 2.1)
		add_child(light)
		var box := MeshInstance3D.new()
		box.mesh = _box(Vector3(0.34, 0.12, 0.1))
		box.material_override = fitting
		box.position = light.position
		add_child(box)


# --- Helpers ---------------------------------------------------------------------

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## One instanced mesh over a set of tiles. tint gives each its own shade of
## the colour, so a run of wall reads as panels; cap darkens the middle of
## big wall masses.
func _instances(mesh: Mesh, tiles: Array[Vector2i], height: float, mat: StandardMaterial3D, tint := 0.0, cap := false, offset := Vector3.ZERO) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = tint > 0 or cap
	mm.mesh = mesh
	mm.instance_count = tiles.size()
	if mm.use_colors:
		mat.vertex_color_use_as_albedo = true
	for i in tiles.size():
		var t := tiles[i]
		mm.set_instance_transform(i, Transform3D(Basis(), to_world(t.x + 0.5, t.y + 0.5, height) + offset))
		if mm.use_colors:
			var k := 1.0 - tint / 2.0 + _hash01(t.x, t.y) * tint
			if cap:
				k *= _cap_shade(t)
			mm.set_instance_color(i, Color(k, k, k))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	add_child(node)


## Deterministic 0..1 from a tile, so the plan looks the same every frame.
static func _hash01(x: int, y: int) -> float:
	return fposmod(absf(sin(x * 31.7 + y * 17.3 + 41 * 7.13)), 1.0)
