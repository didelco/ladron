class_name DenView
extends MuseumView
## The band's house as drawn (Den): a home, not a museum. Wooden floors,
## carpet, straw mats and tiles, papered walls, Kenney's furniture (assets/
## models/casa) in warm toon shading, lamps instead of torches, posters, a
## front door, the trophy room's gallery (25 stands filling with the pieces
## stolen, from Story) and the
## dojo's things as far as they are unlocked (Practice.ITEMS).
##
## It is a MuseumView all the same, so the round builds it where it builds a
## museum (Main._build_world) and everything that walks, hides or falls goes
## on as in one. Built once per round.

## The gang's size, for the trophy room (the progress is by size of band).
static var players := 1

## Walls and trim: warm plaster over a stained wainscot (wall.gdshader).
const HOME := {
	"floor": 0, "stone": Color("#b07a4a"), "stone2": Color("#a06c3f"), "joint": Color("#5a3a20"), "gloss": 0.2,
	"paper": Color("#d8b48a"), "paper2": Color("#e6c99f"), "wallpaper": 2, "wainscot": Color("#9a6a44"), "dado": 0.38,
	"cap": Color("#f0e0c0"), "trim": Color("#c9974f"), "skirt": Color("#6b4526"),
}

## The lamps' warm white, and the paper lanterns' of the dojo.
const LAMP := Color("#ffc98a")
const LANTERN := Color("#ffb060")
const PX := 16
## Kenney's pieces drawn this much bigger than Den says (the ninjas are chubby).
const FIT := 1.35
const WOOD := Color("#a0693a")

# --- The house's light: every knob in one place -----------------------------------------
# It had burnt out (mostly the dojo: pale straw, two lanterns and the ambient
# and the sun on top). Softer now, still warm. Before -> now:
## the ambient (mood): 0.5 -> 0.36
const LIGHT_AMBIENT := 0.36
## the "moon" (mood), the house's sun: 0.55 -> 0.32
const LIGHT_SUN := 0.32
## the exposure of the tonemap (mood): 1.0 -> 0.95
const LIGHT_EXPOSURE := 0.95
## the glow: intensity 0.35 -> 0.12, and only what is brighter than the
## threshold (1.0 -> 1.4) blooms
const LIGHT_GLOW := 0.12
const LIGHT_GLOW_THRESHOLD := 1.4
## what the lamps' energies of the list in _lamps are multiplied by: 0.7 -> 0.5
const LIGHT_LAMP_GAIN := 0.5
## a dojo lantern's light, as it shines (it was 1.2 * 0.7 = 0.84) -> 0.5; and
## how far it reaches, in tiles: 9 -> 8
const LIGHT_LANTERN := 0.5
const LIGHT_LANTERN_RANGE := 8.0
## the bathroom's lamps: from a cold white (#fff0dc, 1.1 and 0.8) to a warm one
const LIGHT_BATH := Color("#ffe2bd")
## what the paper lanterns' bulbs, the front door's window and the patches of
## light glow with: 1.4 -> 0.8, 0.9 -> 0.6
const GLOW_LANTERN := 0.8
const GLOW_WINDOW := 0.6
## the dojo's straw mats: #c8c08a -> a shade less bright
const STRAW := Color("#b8b07c")

# --- Rooms in the dark ---------------------------------------------------------------------
## A room nobody is in, and no open door lets be seen, is dark: a veil over
## it (this dark, of 1) and none of its contents drawn (Den.visible_rooms).
## A room nobody sees is nearly black: 95 % opaque, so that its shape is
## guessed at and little more (the walls' tops, a faint floor). Pure black and
## unshaded, so no light or shine of the rooms next door gets through as stains;
## and never 1.0, or even the shape would be lost.
const VEIL_ALPHA := 0.95
const VEIL_COLOUR := Color(0, 0, 0)
## The veil is a box just over the walls' height (WALL_HEIGHT + cap).
const VEIL_HEIGHT := 1.3
## Seconds to go dark or light (the same as a door's swing).
const VEIL_SECONDS := 0.3

## room id -> the node its contents hang from (hidden when it is dark)
var _room_nodes := {}
## room id -> its veil
var _veils := {}
## room id -> how dark it is now (0 lit .. 1 dark) and where it is going
var _dark := {}
var _dark_goal := {}
## door id -> {leaves: [Node3D, Node3D], length: float, open: float (0..1), goal: float}
var _door_nodes := {}


func build() -> void:
	theme = HOME
	_floors()
	# The walls are built with every doorway open: the plan has the shut doors
	# as wall, and a solid block there would swallow the leaves (the doors are
	# drawn on their own, _doors, and they close the gap).
	var opened := Den.open_doors()
	for d in Den.DOORS:
		Den.set_open(d.id, true)
	Den.apply_doors()
	_walls()
	for d in Den.DOORS:
		Den.set_open(d.id, opened.has(d.id))
	Den.apply_doors()
	# What is built from here on is sorted into its room afterwards.
	var base := get_child_count()
	_furniture()
	_posters()
	_front_door()
	_trophies()
	_dojo()
	_dojo_walls()
	_dojo_wall_things()
	_bench()
	_game_starts()
	_scarecrows()
	_alarm_lights()
	_bath()
	_lamps()
	_sort_into_rooms(base)
	_veil_rooms()
	_doors()


# --- The models ---------------------------------------------------------------

static var _house_mats := {}


## One of Kenney's furniture models (assets/models/casa), lit and toon shaded
## like the rest of the game instead of flat as the kit ships it.
static func house(name: String) -> Node3D:
	var scene: PackedScene = load("res://assets/models/casa/%s.glb" % name)
	var node: Node3D = scene.instantiate()
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null:
				continue
			if not _house_mats.has(src):
				var m := src.duplicate() as BaseMaterial3D
				m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
				m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				m.albedo_color = Color("#5f9a94") if String(src.resource_name) == "carpet" else m.albedo_color * 0.78
				m.metallic = 0.0
				m.roughness = 1.0
				_house_mats[src] = m
			mi.set_surface_override_material(s, _house_mats[src])
	return node


## A model stood by its middle: on the floor (or `lift` up), scaled, turned.
## Where its front (+Z) looks is yaw, in degrees (0 south).
func _stand(parent: Node3D, name: String, at: Vector2, yaw: float, scale: float, lift: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = to_world(at.x, at.y, lift * FIT)
	pivot.rotation.y = deg_to_rad(yaw)
	parent.add_child(pivot)
	# (A model with a folder, "temas/moderna/recreativa", is the museum's own.)
	var model: Node3D
	if "/" in name:
		model = asset(name)
		if name == Arcades.MODEL:
			arcade_game(model, ARCADE_GAME)
	else:
		model = house(name)
	var box := _bounds(model, Transform3D.IDENTITY)
	scale *= FIT
	model.scale = Vector3.ONE * scale
	model.position = Vector3(-(box.position.x + box.size.x / 2.0), -box.position.y, -(box.position.z + box.size.z / 2.0)) * scale
	pivot.add_child(model)
	return pivot


func _furniture() -> void:
	for f in Den.furniture():
		if f.get("kind", "") == "sandbag":
			_sandbag(f.at)
		if String(f.m) == "":
			continue
		var pivot := _stand(self, f.m, f.at, f.yaw, f.s, f.lift)
		if f.get("kind", "") == "arcade":
			_arcade_glow(pivot)


## Which of the machine's games the lounge's arcade wears.
const ARCADE_GAME := "invasores"
var _arcade_pictures: Array[StandardMaterial3D] = []
var _arcade_clock := 0.0


## The lounge machine's screen alive: its own copy of the picture's material
## (blinking a little in _process, not the museum's) and a soft glow on the floor
## in front of it.
func _arcade_glow(pivot: Node3D) -> void:
	for mi: MeshInstance3D in pivot.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is QuadMesh and mi.material_override is StandardMaterial3D:
			var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
			mi.material_override = m
			_arcade_pictures.append(m)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 1.8)
	q.orientation = PlaneMesh.FACE_Y
	glow.mesh = q
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = _radial(Color(0.35, 0.9, 1.0))
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = to_world(Den.ARCADE_AT.x + 0.5 + 0.0, Den.ARCADE_AT.y + 1.2, 0.03)
	add_child(glow)


# --- Floors ---------------------------------------------------------------------

## The whole plan's floor in one picture: each room its own (boards, carpet,
## mats, tiles), the doorways in boards.
func _floors() -> void:
	var w := Museum.w
	var h := Museum.h
	var img := Image.create(w * PX, h * PX, false, Image.FORMAT_RGB8)
	_boards(img, Rect2i(0, 0, w, h))
	_gallery_floor(img, Den.rect("trofeos"))
	_straw(img, Den.rect("dojo"))
	_tiles(img, Den.rect("aseo"))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, h)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = m
	add_child(node)


func _rect_px(r: Rect2i) -> Rect2i:
	return Rect2i(r.position * PX, r.size * PX)


## Oak boards a third of a tile wide, end to end and staggered, each a shade
## of its own.
func _boards(img: Image, r: Rect2i) -> void:
	var rp := _rect_px(r)
	var base := Color("#b8865a")
	var plank := PX / 3
	for y in range(rp.position.y, rp.end.y):
		var row := (y - rp.position.y) / plank
		var seam_y := (y - rp.position.y) % plank == 0
		var stagger := int(_hash01(row, 3, 9) * PX * 3)
		for x in range(rp.position.x, rp.end.x):
			var board := ((x - rp.position.x) + stagger) / (PX * 3)
			var shade := 0.9 + 0.2 * _hash01(row, board, 5)
			var c := base * shade
			var grain := 0.97 + 0.05 * _hash01(x / 3, row, 17)
			c = Color(c.r * grain, c.g * grain, c.b * grain)
			if seam_y or ((x - rp.position.x) + stagger) % (PX * 3) == 0:
				c = c.darkened(0.32)
			img.set_pixel(x, y, c)


## The gallery's floor: pale marble in big squares, and under each museum's
## section a runner in its colour, with a gold line inside its edge.
func _gallery_floor(img: Image, r: Rect2i) -> void:
	var rp := _rect_px(r)
	for y in range(rp.position.y, rp.end.y):
		for x in range(rp.position.x, rp.end.x):
			var tx := (x - rp.position.x) / PX
			var ty := (y - rp.position.y) / PX
			var c := Color("#ddd6c8") if (tx + ty) % 2 == 0 else Color("#cfc7b6")
			c = c * (0.985 + 0.03 * _hash01(x / 5, y / 5, 21))
			if (x - rp.position.x) % PX == 0 or (y - rp.position.y) % PX == 0:
				c = c.darkened(0.1)
			c.a = 1.0
			img.set_pixel(x, y, c)
	for m in Story.MUSEUMS.size():
		var col := Color(Story.MUSEUMS[m].colour)
		var run := Rect2i(Den.section_x(m) * PX - PX / 4, r.position.y * PX + PX, (Den.SECTION_WIDTH * PX) + PX / 2, 6 * PX)
		for y in range(run.position.y, run.end.y):
			for x in range(run.position.x, run.end.x):
				var d := mini(mini(x - run.position.x, run.end.x - 1 - x), mini(y - run.position.y, run.end.y - 1 - y))
				var weave := 0.95 + 0.05 * float((x / 2 + y / 2) % 2)
				var c := col.darkened(0.35).lerp(Color("#cfc7b6"), 0.15) * weave
				if d >= 3 and d <= 4:
					c = Color("#d9a94a")
				c.a = 1.0
				img.set_pixel(x, y, c)


## Straw mats, two tiles by one, laid the way of a dojo: the dark green edge
## of each showing, the weave in fine lines.
func _straw(img: Image, r: Rect2i) -> void:
	var rp := _rect_px(r)
	for y in range(rp.position.y, rp.end.y):
		for x in range(rp.position.x, rp.end.x):
			var tx := (x - rp.position.x) / PX
			var ty := (y - rp.position.y) / PX
			# Mats lie in pairs across, then along.
			var block := (tx / 2 + ty / 2) % 2
			var lx := (x - rp.position.x) % (PX * 2)
			var ly := (y - rp.position.y) % (PX * 2)
			var u: int
			var v: int
			var mat_w: int
			var mat_h: int
			if block == 0:
				u = lx
				v = ly % PX
				mat_w = PX * 2
				mat_h = PX
			else:
				u = lx % PX
				v = ly
				mat_w = PX
				mat_h = PX * 2
			var line := (v / 2 % 2) if block == 0 else (u / 2 % 2)
			var c := STRAW * (0.96 + 0.05 * float(line))
			if u <= 0 or v <= 0 or u >= mat_w - 1 or v >= mat_h - 1:
				c = Color("#7c8656")
			c.a = 1.0
			img.set_pixel(x, y, c)


## Bathroom tiles: pale and mint in a check, a fine grout line.
func _tiles(img: Image, r: Rect2i) -> void:
	var rp := _rect_px(r)
	var cell := PX / 2
	for y in range(rp.position.y, rp.end.y):
		for x in range(rp.position.x, rp.end.x):
			var cx := (x - rp.position.x) / cell
			var cy := (y - rp.position.y) / cell
			var c := Color("#e9f0ec") if (cx + cy) % 2 == 0 else Color("#a9d3c6")
			if (x - rp.position.x) % cell == 0 or (y - rp.position.y) % cell == 0:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)


# --- Walls: what hangs on them, and the door --------------------------------------

## Framed pictures and posters on the walls the camera sees, and a few with
## words. Each is (room wall, x or y along it, seed): on the north walls of
## the rooms (facing south), a few on the west and east.
func _posters() -> void:
	var north := [
		["salon", 3.0, 3], ["salon", 7.5, 8], ["salon", 12.4, 14], ["salon", 16.2, 19],
		["aseo", 22.5, 40], ["aseo", 29.5, 44],
	]
	for p in north:
		var r := Den.rect(p[0])
		var pivot := _pivot(self, to_world(p[1], r.position.y - 0.005), 0.0)
		# Above the kitchen run there is no room for tall pictures.
		if p[0] == "salon" and p[1] > 11.0:
			pivot.position.y = 0.42
		_painting(pivot, p[2], "", Vector3(0.7, 0.5, 0.78))
	# Three with words, on the lounge's west wall and the trophy room's, and a
	# window with its curtains between them (the lounge's, west).
	_word_poster(to_world(1.005, 13.0), PI / 2, Text.t("HIDEOUT_POSTER_1"), Color("#f4d35e"))
	_word_poster(to_world(1.005, 18.3), PI / 2, Text.t("HIDEOUT_POSTER_2"), Color("#ee6c4d"))
	_word_poster(to_world(1.005, 4.0), PI / 2, Text.t("HIDEOUT_POSTER_3"), Color("#84a98c"))
	_window(to_world(1.005, 16.0), PI / 2, Color("#c1666b"))
	_window(to_world(20.0 - 0.005, 17.0), -PI / 2, Color("#c1666b"))
	# Pictures in the trophy room's west wall, over the benches.
	for spot in [[1.005, 2.2, 71], [1.005, 6.4, 72]]:
		var pivot := _pivot(self, to_world(spot[0], spot[1]), PI / 2)
		_painting(pivot, spot[2], "", Vector3(0.7, 0.5, 0.78))


## A window in a wall (pivot at its foot, +z out of the wall into the room): a
## frame, a dark night pane with its bars, a sill, and curtains on a rail.
func _window(at: Vector3, yaw: float, curtain: Color) -> void:
	var pivot := _pivot(self, at, yaw)
	var frame := Color("#5a3a22")
	_mesh(pivot, _box(Vector3(1.3, 0.72, 0.05)), frame, Vector3(0, 0.72, 0.025), true)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#3d5673")
	glass.emission_enabled = true
	glass.emission = Color("#5d7fa6")
	glass.emission_energy_multiplier = 0.35
	var pane := MeshInstance3D.new()
	pane.mesh = _box(Vector3(1.14, 0.56, 0.02))
	pane.material_override = glass
	pane.position = Vector3(0, 0.72, 0.055)
	pivot.add_child(pane)
	_mesh(pivot, _box(Vector3(0.04, 0.58, 0.03)), frame, Vector3(0, 0.72, 0.075), true)
	_mesh(pivot, _box(Vector3(1.16, 0.04, 0.03)), frame, Vector3(0, 0.72, 0.075), true)
	_mesh(pivot, _box(Vector3(1.5, 0.045, 0.14)), Color("#c9974f"), Vector3(0, 0.34, 0.07), true)
	_mesh(pivot, _box(Vector3(1.75, 0.035, 0.035)), Color("#3b2614"), Vector3(0, 1.08, 0.1), true)
	for sx in [-0.7, 0.7]:
		_mesh(pivot, _box(Vector3(0.34, 0.82, 0.09)), curtain, Vector3(sx, 0.66, 0.09), true)
		_mesh(pivot, _box(Vector3(0.05, 0.8, 0.1)), curtain.darkened(0.2), Vector3(sx + 0.06 * signf(sx), 0.66, 0.1), true)


func _word_poster(at: Vector3, yaw: float, text: String, paper: Color) -> void:
	var pivot := _pivot(self, at, yaw)
	_mesh(pivot, _box(Vector3(0.62, 0.8, 0.02)), Color("#4a3020"), Vector3(0, 0.72, 0.01))
	_mesh(pivot, _box(Vector3(0.54, 0.72, 0.02)), paper, Vector3(0, 0.72, 0.025))
	var label := Label3D.new()
	label.text = text
	label.font = Hud.ARCADE
	label.font_size = 22
	label.pixel_size = 0.005
	label.modulate = Color("#2a1a12")
	label.outline_size = 0
	label.position = Vector3(0, 0.72, 0.045)
	pivot.add_child(label)


## The front door in the south wall of the lounge: a pair of leaves and their
## frame on the wall's face, a warm window, and a little board over it saying
## where it goes. In front, the mat and a patch of light.
func _front_door() -> void:
	var d: Array = Den.FRONT_DOOR
	var centre := to_world(d[0] + d[2] / 2.0, d[1] + 0.0)
	var pivot := _pivot(self, centre + Vector3(0, 0, -0.02), PI)
	var frame := Color("#5a3a22")
	var leaf := Color("#c98a4b")
	_mesh(pivot, _box(Vector3(2.0, 1.08, 0.06)), frame, Vector3(0, 0.54, 0.03))
	_mesh(pivot, _box(Vector3(0.92, 0.96, 0.05)), leaf, Vector3(-0.47, 0.5, 0.05))
	_mesh(pivot, _box(Vector3(0.92, 0.96, 0.05)), leaf, Vector3(0.47, 0.5, 0.05))
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#ffd9a0")
	glass.emission_enabled = true
	glass.emission = Color("#ffcf80")
	glass.emission_energy_multiplier = GLOW_WINDOW
	for sx in [-0.47, 0.47]:
		var w := MeshInstance3D.new()
		w.mesh = _box(Vector3(0.5, 0.34, 0.02))
		w.material_override = glass
		w.position = Vector3(sx, 0.72, 0.08)
		pivot.add_child(w)
	_mesh(pivot, _box(Vector3(0.06, 0.06, 0.05)), Color("#f0c46a"), Vector3(-0.08, 0.45, 0.09))
	_mesh(pivot, _box(Vector3(0.06, 0.06, 0.05)), Color("#f0c46a"), Vector3(0.08, 0.45, 0.09))
	# The board over the door.
	var sign := Label3D.new()
	sign.text = Text.t("HIDEOUT_DOOR_SIGN")
	sign.font = Hud.ARCADE
	sign.font_size = 44
	sign.pixel_size = 0.0065
	sign.modulate = Color("#ffe3b0")
	sign.outline_modulate = Color("#3a2414")
	sign.outline_size = 14
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = to_world(d[0] + d[2] / 2.0, d[1] - 1.2, 1.9)
	add_child(sign)
	# A patch of light from outside on the floor in front of it.
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 1.6)
	q.orientation = PlaneMesh.FACE_Y
	glow.mesh = q
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = _radial(Color(1.0, 0.85, 0.55))
	glow.material_override = gm
	glow.position = to_world(d[0] + d[2] / 2.0, d[1] - 0.6, 0.03)
	add_child(glow)


## A soft round spot, opaque in the middle and clear at the edge.
static func _radial(colour: Color) -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - s / 2.0 + 0.5, y - s / 2.0 + 0.5).length() / (s / 2.0)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(colour, a * a * 0.5))
	return ImageTexture.create_from_image(img)


# --- The trophy room -----------------------------------------------------------------

## The gallery: a section along the room for each museum, with its colour on
## the floor and a board over it, and in it a stand for each of its five
## heists (Den.stands): a niche on the north wall for the first three, a glass
## case on the floor for the last two. All of them are there from the start,
## empty, with a plaque (the heist's number); the piece stands in its stand,
## lit, once it has been stolen (Den.is_filled), and the plaque shows the
## stars won. A museum done, whole, has its sock over the board.
func _trophies() -> void:
	var most := Story.MUSEUMS.size() * Story.ROOMS * Story.STARS_EACH
	var total := 0
	var taken := 0
	for m in Story.MUSEUMS.size():
		var colour := Color(Story.MUSEUMS[m].colour)
		var done := 0
		for st in Den.stands():
			if st.museum == m and Den.is_filled(st.n, players):
				done += 1
		var stars := Story.stars_in(m, players)
		total += stars
		taken += done
		_section_board(m, colour, stars, done)
	for st in Den.stands():
		_museum_stand(st, Color(Story.MUSEUMS[st.museum].colour))
	# The total, over the bench in the middle.
	var sum := Label3D.new()
	sum.text = "★ %d/%d\n%d/%d %s" % [total, most, taken, Story.count(), Text.t("HIDEOUT_ROOM_TROFEOS")]
	sum.font = Hud.ARCADE
	sum.font_size = 30
	sum.pixel_size = 0.0068
	sum.line_spacing = 10.0
	sum.modulate = Color("#ffe28a")
	sum.outline_size = 10
	sum.outline_modulate = Color("#2a1810")
	sum.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sum.position = to_world(10.0, 7.7, 0.9)
	add_child(sum)


## The board of museum m's section, on the north wall over its niches: a band
## in the museum's colour, its name and the stars won in it.
func _section_board(m: int, colour: Color, stars: int, done: int) -> void:
	var x0 := Den.section_x(m)
	var top := Den.rect("trofeos").position.y
	var pivot := _pivot(self, to_world(x0 + Den.SECTION_WIDTH / 2.0, top - 0.005), 0.0)
	_mesh(pivot, _box(Vector3(Den.SECTION_WIDTH + 0.1, 0.34, 0.05)), colour.darkened(0.25), Vector3(0, 1.5, 0.025))
	_mesh(pivot, _box(Vector3(Den.SECTION_WIDTH + 0.1, 0.05, 0.07)), Color("#e8d4a8"), Vector3(0, 1.69, 0.035))
	var label := Label3D.new()
	label.text = "%s\n★ %d/%d" % [_short_name(m), stars, Story.STARS_EACH * Story.ROOMS]
	label.font = Hud.ARCADE
	label.font_size = 32
	label.pixel_size = 0.0050
	label.line_spacing = 10.0
	label.modulate = colour.lightened(0.45) if done > 0 else Color("#e6dcc4")
	label.outline_size = 8
	label.outline_modulate = Color("#2a1810")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.15, 0.1)
	pivot.add_child(label)
	# A museum done, whole: its sock, in its colour, on the band.
	if done == Story.ROOMS:
		var sock := LootModels.build("sock", colour)
		_fit(sock, 0.5)
		sock.position = Vector3(Den.SECTION_WIDTH / 2.0 - 0.1, 1.72, 0.15)
		pivot.add_child(sock)


## One stand: a niche (a cabinet under a frame against the wall) or a glass
## case, empty or with the piece of its heist, and its plaque.
func _museum_stand(st: Dictionary, colour: Color) -> void:
	var tile: Vector2i = st.tile
	var got := Den.is_filled(st.n, players)
	var niche: bool = st.kind == "niche"
	var pivot: Node3D
	var top: float
	var front: float
	if niche:
		var wall := Den.rect("trofeos").position.y
		pivot = _pivot(self, to_world(tile.x + 0.5, wall - 0.005), 0.0)
		_mesh(pivot, _box(Vector3(0.94, 1.2, 0.04)), colour.darkened(0.6), Vector3(0, 0.6, 0.02))
		_mesh(pivot, _box(Vector3(0.9, 0.5, 0.7)), WOOD, Vector3(0, 0.25, 0.37))
		_mesh(pivot, _box(Vector3(0.96, 0.05, 0.76)), Color("#e8d4a8"), Vector3(0, 0.525, 0.38))
		for sx in [-0.47, 0.47]:
			_mesh(pivot, _box(Vector3(0.05, 1.2, 0.08)), Color("#6b4526"), Vector3(sx, 0.6, 0.06))
		_mesh(pivot, _box(Vector3(0.99, 0.06, 0.1)), Color("#6b4526"), Vector3(0, 1.2, 0.06))
		top = 0.55
		front = 0.72
	else:
		pivot = _pivot(self, to_world(tile.x + 0.5, tile.y + 0.5), 0.0)
		_base(pivot)
		_vitrine(pivot, null)
		top = 0.42
		front = 0.52
	var plaque_y := 0.28 if niche else 0.1
	_mesh(pivot, _box(Vector3(0.8, 0.17, 0.02)), Color("#2a1e14"), Vector3(0, plaque_y, front + 0.01))
	_plaque_text(pivot, str(st.n), Vector3(-0.27, plaque_y, front + 0.05), Color("#e6dcc4") if got else Color("#a89c84"), 24)
	if not got:
		_plaque_text(pivot, "?", Vector3(0.13, plaque_y, front + 0.05), Color("#a89c84"), 26)
		return
	var won := Story.count_stars(Story.star_mask(st.n, players))
	for i in Story.STARS_EACH:
		_plaque_text(pivot, "★", Vector3(i * 0.14, plaque_y, front + 0.05), Color("#ffd23f") if i < won else Color("#6a6258"), 22)
	# The piece, in its stand, and a soft spot of light over it.
	var loot: Dictionary = Story.LEVELS[st.n - 1].loot
	var piece := LootModels.build(loot.shape, Color(loot.colour))
	var box := _fit(piece, 0.46)
	var depth := 0.38 if niche else 0.0
	piece.position = Vector3(0, top - box.position.y * piece.scale.x, depth)
	pivot.add_child(piece)
	var glow := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.1, 1.1)
	q.orientation = PlaneMesh.FACE_Y
	glow.mesh = q
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.albedo_texture = _radial(Color(1.0, 0.9, 0.65))
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.position = Vector3(0, top + 0.02, depth)
	pivot.add_child(glow)


func _plaque_text(parent: Node3D, text: String, at: Vector3, colour: Color, size: int) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = Hud.ARCADE
	l.font_size = size
	l.pixel_size = 0.0062
	l.modulate = colour
	l.outline_size = 0
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	parent.add_child(l)


## A model scaled to fit a cube of this side. Returns its bounds before.
func _fit(node: Node3D, side: float) -> AABB:
	var box := _bounds(node, Transform3D.IDENTITY)
	node.scale = Vector3.ONE * (side / maxf(0.01, maxf(box.size.x, maxf(box.size.y, box.size.z))))
	return box


## "El Museo de la Prehistoria" without the "El Museo de".
func _short_name(m: int) -> String:
	var n := String(Story.museum(m).name)
	for cut in ["El Museo de ", "La Villa de ", "El Museo del "]:
		if n.begins_with(cut):
			n = n.trim_prefix(cut)
			break
	return n.left(1).to_upper() + n.substr(1)


# --- The dojo ---------------------------------------------------------------------

## The dojo's walls and what is open in it: the bench's cases, the pedestals,
## the boxes to hide in (whatever Practice.open_items says), a ring on the wall,
## lanterns, a weapon rack and the board that counts what is open.
func _dojo() -> void:
	for t in Museum.cover_tiles:
		var piece := Node3D.new()
		piece.position = to_world(t.x + 0.5, t.y + 0.5)
		add_child(piece)
		var slot := Practice.bench_slot_of(t)
		if slot >= 0:
			_base(piece)
			_vitrine(piece, null)
			_bench_glass[slot] = piece.get_child(piece.get_child_count() - 1)
			_bench_spots[slot] = piece
		elif Plinths.is_plinth(t):
			_empty_plinth(piece)
		else:
			var hide: String = Hideouts.pieces.get(t, exhibits.get(t, ""))
			if Hideouts.PIECES.has(hide):
				_hideout(piece, hide, t)
	# The ring (ensō) on the north wall, the scrolls at either side.
	var r := Den.rect("dojo")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.34
	ring.mesh = torus
	ring.material_override = toon(Color("#2a1a14"))
	ring.rotation.x = PI / 2
	ring.position = to_world(26.0, r.position.y + PANEL + 0.03, 0.62)
	add_child(ring)
	for sx in [-1.7, 1.7]:
		var scroll := _pivot(self, to_world(26.0 + sx * 0.9, r.position.y + PANEL + 0.01), 0.0)
		_mesh(scroll, _box(Vector3(0.36, 0.86, 0.02)), Color("#efe2c0"), Vector3(0, 0.6, 0.012))
		_mesh(scroll, _box(Vector3(0.38, 0.05, 0.03)), Color("#5a3a22"), Vector3(0, 1.05, 0.02))
		_mesh(scroll, _box(Vector3(0.38, 0.05, 0.03)), Color("#5a3a22"), Vector3(0, 0.16, 0.02))
		_mesh(scroll, _box(Vector3(0.1, 0.42, 0.01)), Color("#2a1a14"), Vector3(0, 0.6, 0.03))
	# A weapon rack (wooden poles) on the east wall, in the hiding corner.
	var rack := _pivot(self, to_world(r.end.x - PANEL - 0.01, r.position.y + 4.5), -PI / 2)
	_mesh(rack, _box(Vector3(1.6, 0.06, 0.08)), Color("#6b4526"), Vector3(0, 0.75, 0.05))
	_mesh(rack, _box(Vector3(1.6, 0.06, 0.08)), Color("#6b4526"), Vector3(0, 0.4, 0.05))
	for i in 5:
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.03
		cyl.height = 1.0
		pole.mesh = cyl
		pole.material_override = toon(Color("#c9a26a"))
		pole.position = Vector3(-0.6 + i * 0.3, 0.6, 0.1)
		rack.add_child(pole)
	# What is open, on a board on the wall, in words.
	var open := Practice.open_items(players).size()
	var board := Label3D.new()
	board.text = "%s\n%d/%d" % [Text.t("HIDEOUT_ROOM_DOJO"), open, Practice.ITEMS.size()]
	board.font = Hud.ARCADE
	board.font_size = 26
	board.pixel_size = 0.0075
	board.line_spacing = 10.0
	board.modulate = Color("#e8f0c0")
	board.outline_size = 8
	board.outline_modulate = Color("#1c2410")
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.position = to_world(r.position.x + 5.0, r.position.y + 0.6, 1.3)
	add_child(board)


# --- The dojo's walls -------------------------------------------------------------------

## How far the dojo's wall dressing stands off the wall, and how thick it is.
const PANEL := 0.05
const DOJO_WOOD := Color("#8a5a34")
const DOJO_WOOD_DARK := Color("#3b2614")
const DOJO_RAIL := Color("#6b4526")
## The dressing's heights: the skirting, the wainscot, then paper to the rail.
const SKIRT_TOP := 0.12
const WAIN_TOP := 0.42
const PAPER_TOP := 1.07

## The dojo's walls dressed as a room: over the plaster, every face that
## looks onto the dojo's floor (the outer ones and the inside partitions alike)
## gets a dark skirting, a wooden wainscot, rice paper in laths (shoji) up to a
## wooden rail, posts where a run of wall ends, and here and there a high little
## window. One MultiMesh for each kind, so it is a handful of nodes for all.
func _dojo_walls() -> void:
	var r := Den.rect("dojo")
	var holder := Node3D.new()
	holder.position = to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0)
	add_child(holder)
	var sides := {"N": Vector2i(0, -1), "S": Vector2i(0, 1), "W": Vector2i(-1, 0), "E": Vector2i(1, 0)}
	var faces := {}
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if x < 0 or y < 0 or x >= Museum.w or y >= Museum.h or Museum.grid[y * Museum.w + x] != Tiles.WALL:
				continue
			var t := Vector2i(x, y)
			if Den.DOORS.any(func(d: Dictionary) -> bool: return Den.door_rect(d.id).has_point(t)):
				continue
			for side in sides:
				var n: Vector2i = t + sides[side]
				if r.has_point(n) and Museum.grid[n.y * Museum.w + n.x] != Tiles.WALL:
					faces[[x, y, side]] = true
	var wood: Array = []
	var paper: Array = []
	var panes: Array = []
	for key in faces:
		var t := Vector2i(key[0], key[1])
		var side: String = key[2]
		var out: Vector2i = sides[side]
		var along := Vector2i(out.y, out.x)
		var north_south := side == "N" or side == "S"
		var centre := Vector3(t.x + 0.5 - Museum.w / 2.0, 0, t.y + 0.5 - Museum.h / 2.0) \
			+ Vector3(out.x, 0, out.y) * (0.5 + PANEL / 2.0) - holder.position
		var length := 1.02
		var band := func(y0: float, y1: float, thick: float, colour: Color, into: Array) -> void:
			var size := Vector3(length if north_south else thick, y1 - y0, thick if north_south else length)
			into.append([Transform3D(Basis.from_scale(size), centre + Vector3(0, (y0 + y1) / 2.0, 0) + Vector3(out.x, 0, out.y) * (thick - PANEL) / 2.0), colour])
		band.call(0.0, SKIRT_TOP, PANEL * 1.6, DOJO_WOOD_DARK, wood)
		band.call(SKIRT_TOP, WAIN_TOP, PANEL, DOJO_WOOD * (0.94 + 0.12 * _hash01(t.x, t.y, 61)), wood)
		band.call(WAIN_TOP, PAPER_TOP, PANEL * 0.8, Color.WHITE, paper)
		band.call(PAPER_TOP, PAPER_TOP + 0.075, PANEL * 1.5, DOJO_RAIL, wood)
		# A post where the run of face ends on either side.
		for s: int in [-1, 1]:
			var next: Vector2i = t + along * s
			if not faces.has([next.x, next.y, side]):
				var pc: Vector3 = centre + Vector3(along.x, 0, along.y) * s * 0.5 + Vector3(out.x, 0, out.y) * PANEL * 0.4
				wood.append([Transform3D(Basis.from_scale(Vector3(0.11, PAPER_TOP + 0.075, 0.11)), pc + Vector3(0, (PAPER_TOP + 0.075) / 2.0, 0)), DOJO_RAIL.darkened(0.2)])
		# A little high window in the paper, now and then.
		if _hash01(t.x, t.y, 67) < 0.22:
			var size := Vector3(0.5 if north_south else 0.02, 0.24, 0.02 if north_south else 0.5)
			panes.append([Transform3D(Basis.from_scale(size), centre + Vector3(0, 0.86, 0) + Vector3(out.x, 0, out.y) * PANEL * 0.7), Color.WHITE])
	# The heart of a thick block of wall, dark in the plan, gets a roof like
	# the rest of the wall's, so a block reads as wall from above, not as a pit.
	for y in range(r.position.y - 1, r.end.y + 1):
		for x in range(r.position.x - 1, r.end.x + 1):
			if x < 0 or y < 0 or x >= Museum.w or y >= Museum.h or Museum.grid[y * Museum.w + x] != Tiles.WALL or Museum.is_outside(x, y) or not _is_core(Vector2i(x, y)):
				continue
			var edge := false
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, -1), Vector2i(1, -1)]:
				if Museum.is_outside(x + d.x, y + d.y):
					edge = true
			var top: float = OUTER_HEIGHT if edge else WALL_HEIGHT
			var at := Vector3(x + 0.5 - Museum.w / 2.0, top + 0.02, y + 0.5 - Museum.h / 2.0) - holder.position
			wood.append([Transform3D(Basis.from_scale(Vector3(1.0, 0.06, 1.0)), at), Color(theme.cap).darkened(0.1)])
	var box := BoxMesh.new()
	var lit := StandardMaterial3D.new()
	lit.vertex_color_use_as_albedo = true
	lit.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	lit.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_multi(holder, box, lit, wood)
	var shoji := StandardMaterial3D.new()
	shoji.albedo_texture = _shoji_texture(false)
	shoji.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	shoji.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	shoji.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_multi(holder, box, shoji, paper)
	var glass := StandardMaterial3D.new()
	glass.albedo_texture = _shoji_texture(true)
	glass.emission_enabled = true
	glass.emission_texture = glass.albedo_texture
	glass.emission_energy_multiplier = GLOW_WINDOW * 0.7
	_multi(holder, box, glass, panes)


## A MultiMesh of one mesh in many places and colours: items are [Transform3D
## (relative to the holder), Color].
func _multi(holder: Node3D, mesh: Mesh, mat: Material, items: Array) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(node)


## Rice paper in a lath grid, one wall tile wide: four squares across and
## three high. window: the little high window (a frame round a warm pane).
static func _shoji_texture(window: bool) -> ImageTexture:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	for y in s:
		for x in s:
			var c := Color("#e9dcb8") * (0.97 + 0.04 * float((x / 3 + y / 5) % 2))
			c.a = 1.0
			if x % 16 < 2 or y % 22 < 2 or y >= 62:
				c = Color("#6b4526")
			if window:
				c = Color("#3b2614")
				if x > 5 and x < s - 6 and y > 5 and y < s - 6:
					c = Color("#ffd58a")
					if x % 26 < 2 or y % 26 < 2:
						c = Color("#5a3a22")
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# --- Dojo things -----------------------------------------------------------------------

func _cyl(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	return c


## A standing punchbag: a base, a red canvas bag with a strap, a cap.
func _sandbag(at: Vector2) -> void:
	var p := _pivot(self, to_world(at.x, at.y), 0.0)
	_mesh(p, _cyl(0.34, 0.12), DOJO_WOOD_DARK, Vector3(0, 0.06, 0))
	_mesh(p, _cyl(0.06, 0.3), Color("#5a3a22"), Vector3(0, 0.25, 0))
	_mesh(p, _cyl(0.26, 1.0), Color("#a5402f"), Vector3(0, 0.78, 0))
	_mesh(p, _cyl(0.275, 0.07), Color("#e0c898"), Vector3(0, 0.9, 0), true)
	_mesh(p, _cyl(0.24, 0.05), Color("#3b2614"), Vector3(0, 1.3, 0), true)


## What hangs on the dojo's walls besides the scrolls: crossed wooden swords,
## boxing gloves on a peg, and the band's sock flag. On the west wall.
func _dojo_wall_things() -> void:
	var wall_x: float = Den.rect("dojo").position.x + PANEL + 0.01
	var swords := _pivot(self, to_world(wall_x, 6.6), PI / 2)
	for a in [0.55, -0.55]:
		var sword := _mesh(swords, _box(Vector3(0.07, 0.95, 0.03)), Color("#d2a76a"), Vector3(0, 0.68, 0.03), true)
		sword.rotation.z = a
		_mesh(sword, _box(Vector3(0.05, 0.16, 0.05)), Color("#3b2614"), Vector3(0, -0.5, 0), true)
	var gloves := _pivot(self, to_world(wall_x, 9.6), PI / 2)
	_mesh(gloves, _box(Vector3(0.6, 0.04, 0.06)), DOJO_RAIL, Vector3(0, 0.98, 0.04), true)
	for gx in [-0.16, 0.16]:
		var glove := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.1
		cap.height = 0.3
		glove.mesh = cap
		glove.material_override = _toon_cached(Color("#c1272d"))
		glove.position = Vector3(gx, 0.78, 0.1)
		gloves.add_child(glove)
		_mesh(gloves, _box(Vector3(0.1, 0.05, 0.11)), Color("#e8e0d0"), Vector3(gx, 0.63, 0.1), true)
	var flag := _pivot(self, to_world(wall_x, 5.0), PI / 2)
	_mesh(flag, _box(Vector3(0.6, 0.03, 0.04)), DOJO_RAIL, Vector3(0, 1.02, 0.03), true)
	_mesh(flag, _box(Vector3(0.52, 0.7, 0.015)), Color("#a3262e"), Vector3(0, 0.66, 0.03), true)
	var sock := LootModels.build("sock", Color("#f3ece0"))
	_fit(sock, 0.4)
	sock.position = Vector3(0, 0.62, 0.06)
	flag.add_child(sock)



# --- The bench of cases -----------------------------------------------------------------------

## The glass of each bench case (by slot; hidden while it is open) and the node
## each stands on, the glows under them, the socks in them and the boards: the
## count, and on each case its test and difficulty.
var _bench_glass := {}
var _bench_spots := {}
var _bench_glows := {}
var _bench_socks := {}
var _bench_labels := {}
var _bench_clock := 0.0
var _bench_open_now := {}


## The boards and the socks of the bench cases; what shows depends on the
## lessons (Practice.ITEMS). The cases themselves are dressed with the dojo's.
func _bench() -> void:
	# The count, over the cases.
	_bench_labels.count = _board(to_world(28.0, 5.0, 1.4), 26, Color("#ffe28a"))
	for c in Practice.bench_cases(players):
		var t: Vector2i = c.at
		var label := _board(to_world(t.x + 0.5, t.y + 0.5, 1.55), 15, Color("#e8f0c0"))
		label.text = "%s\n%s" % [Text.t(Practice.bench_kind_text(c.kind)), Text.t(DojoGames.TIERS[c.level].text)]
		# Each case holds a sock; the first has main's, the one of the loot.
		if t != Heist.at:
			var sock := LootModels.build("sock", Color("#e2262f"))
			_fit(sock, 0.5)
			sock.position = to_world(t.x + 0.5, t.y + 0.5, 0.62)
			add_child(sock)
			_bench_socks[c.slot] = sock
	# A green glow under each case for while it is open.
	for i in _bench_spots:
		var glow := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(1.9, 1.9)
		q.orientation = PlaneMesh.FACE_Y
		glow.mesh = q
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.albedo_texture = _radial(Color(0.5, 1.0, 0.6))
		glow.material_override = gm
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glow.position = (_bench_spots[i] as Node3D).position + Vector3(0, 0.05, 0)
		glow.visible = false
		add_child(glow)
		_bench_glows[i] = glow
	set_bench(Practice.bench_new())


func _board(at: Vector3, size: int, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.font = Hud.ARCADE
	l.font_size = size
	l.pixel_size = 0.0078
	l.line_spacing = 8.0
	l.modulate = colour
	l.outline_size = 8
	l.outline_modulate = Color("#2a1810")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = at
	add_child(l)
	return l


## The bench as it is now (Practice.bench_new): the count's board, the glass
## up or off, the glows.
func set_bench(state: Dictionary) -> void:
	if _bench_labels.has("count"):
		(_bench_labels.count as Label3D).text = "%s\n%d" % [Text.t("HIDEOUT_BENCH_COUNT"), state.opened]
	for i in _bench_glass:
		var open: bool = state.cases[i].state != "closed"
		(_bench_glass[i] as Node3D).visible = not open or state.cases[i].state == "rearming"
		if _bench_glows.has(i):
			(_bench_glows[i] as Node3D).visible = state.cases[i].state == "open"
		_bench_open_now[i] = state.cases[i].state == "open"


# --- The scarecrows -----------------------------------------------------------------------

## Warm and red for a scarecrow's cone of torchlight.
const CONE_WARM := Color(1.0, 0.8, 0.45)
const CONE_RED := Color(1.0, 0.15, 0.1)
var _cone_mats: Array[StandardMaterial3D] = []

## A guard's coat on a cross of sticks, straw at the neck and wrists, patches,
## and a torch taped to the chest that throws a cone in front (Practice's
## numbers for what it sees). The figure itself (a guard) is Main's; here go the
## cross, the straw, the torch and the light.
func _scarecrows() -> void:
	for sc in Practice.scarecrows(players):
		_scarecrow_post(sc)
		_scarecrow_cone(sc)


## One scarecrow's cross, straw, torch and light, standing where `sc` (as in
## Practice.scarecrows: {at, dir}) says. Returns its root.
func _scarecrow_post(sc: Dictionary) -> Node3D:
	var at: Vector2i = sc.at
	var root := _pivot(self, to_world(at.x + 0.5, at.y + 0.5), -float(sc.dir) + PI / 2)
	var wood := Color("#7a5230")
	var straw := Color("#d8b84a")
	_mesh(root, _box(Vector3(0.08, 1.45, 0.08)), wood, Vector3(0, 0.72, -0.16))
	_mesh(root, _box(Vector3(1.25, 0.08, 0.08)), wood, Vector3(0, 0.7, -0.16))
	for a in [0.5, -0.5]:
		var foot := _mesh(root, _box(Vector3(0.75, 0.06, 0.08)), wood, Vector3(0, 0.03, -0.16), true)
		foot.rotation.y = a
	for sx in [-1.0, 1.0]:
		# A sleeve of coat with a fist of straw out of its end and a patch.
		_mesh(root, _box(Vector3(0.36, 0.16, 0.16)), Color("#33466a"), Vector3(sx * 0.42, 0.7, -0.16), true)
		_mesh(root, _box(Vector3(0.12, 0.1, 0.12)), straw, Vector3(sx * 0.66, 0.7, -0.16), true)
		_mesh(root, _box(Vector3(0.09, 0.09, 0.02)), Color("#c97b3a") if sx < 0 else Color("#7fb069"), Vector3(sx * 0.4, 0.7, -0.075), true)
	_mesh(root, _box(Vector3(0.16, 0.1, 0.16)), straw, Vector3(0, 0.83, -0.02), true)
	_mesh(root, _box(Vector3(0.1, 0.12, 0.04)), straw, Vector3(-0.1, 0.9, 0.0), true)
	# The torch, taped to the chest.
	var lamp := MeshInstance3D.new()
	lamp.mesh = _box(Vector3(0.1, 0.13, 0.1))
	var lm := StandardMaterial3D.new()
	lm.albedo_color = Color("#fff0c0")
	lm.emission_enabled = true
	lm.emission = Color("#ffd58a")
	lm.emission_energy_multiplier = GLOW_WINDOW
	lamp.material_override = lm
	lamp.position = Vector3(0.1, 0.5, Practice.SCARECROW_TORCH - 0.06)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lamp)
	_mesh(root, _box(Vector3(0.13, 0.03, 0.13)), Color("#8a8a8a"), Vector3(0.1, 0.5, Practice.SCARECROW_TORCH - 0.06), true)
	var spot := SpotLight3D.new()
	spot.light_color = LANTERN
	spot.light_energy = 0.9
	spot.spot_range = Practice.SCARECROW_RANGE + 0.5
	spot.spot_angle = rad_to_deg(Practice.SCARECROW_ANGLE) * 1.1
	spot.spot_attenuation = 0.8
	spot.light_specular = 0.0
	spot.position = Vector3(0.1, 0.55, Practice.SCARECROW_TORCH)
	spot.rotation = Vector3(-0.17, PI, 0.0)
	root.add_child(spot)
	return root


## The torch's cone on the floor, cut by the walls (the plan as it is built:
## the doors of the dojo are far from any of them), faint like a guard's.
func _scarecrow_cone(sc: Dictionary) -> void:
	var from := Practice.scarecrow_torch(sc)
	var base := to_world(from.x, from.y)
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rays := 22
	var prev: Array = []
	for i in rays:
		var t := float(i) / (rays - 1)
		var a: float = float(sc.dir) - Practice.SCARECROW_ANGLE + 2.0 * Practice.SCARECROW_ANGLE * t
		var side := smoothstep(0.0, 0.2, t) * smoothstep(1.0, 0.8, t)
		var far := minf(Museum.cast_ray(from.x, from.y, a, Practice.SCARECROW_RANGE, true), Practice.SCARECROW_RANGE)
		var ring: Array = []
		for k in [[0.0, 0.5], [0.45, 0.4], [1.0, 0.0]]:
			var d: float = far * k[0]
			ring.append([to_world(from.x + cos(a) * d, from.y + sin(a) * d, 0.04) - base, Color(1, 1, 1, k[1] * side * 0.5)])
		if i > 0:
			for k in 2:
				for v in [prev[k], prev[k + 1], ring[k], ring[k], prev[k + 1], ring[k + 1]]:
					im.surface_set_color(v[1])
					im.surface_add_vertex(v[0])
		prev = ring
	im.surface_end()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_color = CONE_WARM
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var node := MeshInstance3D.new()
	node.mesh = im
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.position = base
	add_child(node)
	_cone_mats.append(m)


# --- The games' start points and lantern ------------------------------------------------

## the board of each start point, by "<game>:<tier>"
var _start_boards := {}
## the lantern's scarecrow of AGUANTA ESCONDIDO, built the first time it is asked for
var _lantern: Node3D


## The start points of the games the band has got to (Practice.game_starts): a
## pedestal with a golden sock on it (PILLA EL CALCETÍN), a painted circle
## (BOLOS); the pedestals of EQUILIBRIO and the armours of AGUANTA ESCONDIDO are
## dressed with the dojo's and the house's. Over each, a board with the game's
## name, its difficulty and the band's best.
func _game_starts() -> void:
	_start_boards.clear()
	for st in Practice.game_starts(players):
		var t: Vector2i = st.at
		var p := _pivot(self, to_world(t.x + 0.5, t.y + 0.5), 0.0)
		match st.via:
			"sock":
				_empty_plinth(p)
				var sock := LootModels.build("sock", Color("#ffcf3a"))
				_fit(sock, 0.5)
				sock.position = Vector3(0, Plinths.HEIGHT + 0.3, 0)
				p.add_child(sock)
			"ring":
				var disc := MeshInstance3D.new()
				var ring := TorusMesh.new()
				ring.inner_radius = 0.38
				ring.outer_radius = 0.5
				disc.mesh = ring
				disc.material_override = toon(Color("#c1272d") if st.tier == 2 else (Color("#e0a030") if st.tier == 1 else Color("#3f8f4f")))
				disc.position = Vector3(0, 0.03, 0)
				p.add_child(disc)
		_start_boards["%s:%d" % [st.game, st.tier]] = _board(to_world(t.x + 0.5, t.y + 0.5, 1.95), 16, Color("#ffe28a"))
	refresh_signs()


## The boards' words: the game, its difficulty and the band's best level in it.
func refresh_signs() -> void:
	for st in Practice.game_starts(players):
		var key := "%s:%d" % [st.game, st.tier]
		if not _start_boards.has(key):
			continue
		var best := DojoGames.best(st.game, players, st.tier)
		var words := "%s\n%s" % [Text.t(st.text), Text.t(DojoGames.TIERS[st.tier].text)]
		(_start_boards[key] as Label3D).text = words if best <= 0 else "%s · %s" % [words, Text.t("HIDEOUT_GAME_BEST") % best]


## The lantern's scarecrow (AGUANTA ESCONDIDO): standing on its post while the
## game is on, looking where `angle` (radians on the plan) says.
func set_lantern(on: bool, angle := Practice.LANTERN_DIR) -> void:
	if _lantern == null:
		if not on:
			return
		_lantern = _scarecrow_post({"at": Practice.LANTERN_AT, "dir": Practice.LANTERN_DIR})
	_lantern.visible = on
	_lantern.rotation.y = -angle + PI / 2


# --- The dojo's alarm ---------------------------------------------------------------------

## How red the dojo is now (0..1) and where it is going, and the red things.
var _alert := 0.0
var _alert_goal := 0.0
var _alert_clock := 0.0
var _alert_slab: MeshInstance3D
var _alert_lights: Array[OmniLight3D] = []

## The lights of the alarm: a red slab over the whole dojo and a few red bulbs
## in it, all off until a scarecrow sees somebody (set_alert). Only the dojo.
func _alarm_lights() -> void:
	var r := Den.rect("dojo")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(r.size.x, 0.05, r.size.y)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.05, 0.03, 0.0)
	_alert_slab = MeshInstance3D.new()
	_alert_slab.mesh = mesh
	_alert_slab.material_override = mat
	_alert_slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_alert_slab.position = to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0, WALL_HEIGHT + 0.12)
	_alert_slab.visible = false
	add_child(_alert_slab)
	for spot in [Vector2(26, 6), Vector2(26, 11), Vector2(37.5, 5.5), Vector2(37.5, 10), Vector2(46, 3.5), Vector2(54, 3.5), Vector2(46, 10), Vector2(54.5, 10.5)]:
		var l := OmniLight3D.new()
		l.position = to_world(spot.x, spot.y, 1.6)
		l.light_color = Color(1.0, 0.1, 0.06)
		l.light_energy = 0.0
		l.omni_range = 7.5
		l.light_specular = 0.0
		l.visible = false
		add_child(l)
		_alert_lights.append(l)


## The dojo goes red (the alarm is on) or back to itself. Fades over a moment.
func set_alert(on: bool) -> void:
	_alert_goal = 1.0 if on else 0.0


## How red the dojo is now (0..1), for the tests.
func alert_level() -> float:
	return _alert


func _pose_alert(dt: float) -> void:
	_alert_clock += dt
	if _alert != _alert_goal:
		_alert = move_toward(_alert, _alert_goal, dt / 0.25)
	var on := _alert > 0.001
	if _alert_slab == null:
		return
	if _alert_slab.visible != on:
		_alert_slab.visible = on
		for l in _alert_lights:
			l.visible = on
		for m in _cone_mats:
			m.albedo_color = CONE_RED if on else CONE_WARM
	if on:
		var pulse := 0.5 + 0.5 * sin(_alert_clock * 7.0)
		(_alert_slab.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.05, 0.03, _alert * (0.13 + 0.1 * pulse))
		for l in _alert_lights:
			l.light_energy = _alert * (0.7 + 0.5 * pulse)


# --- The bathroom -------------------------------------------------------------------

## The bathroom is looks for now (Den.BATH_GAG): a rubber duck on the edge of
## the bath, and the bath's water.
func _bath() -> void:
	var water := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.3, 0.9)
	q.orientation = PlaneMesh.FACE_Y
	water.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#8fd3e8")
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.material_override = m
	water.position = to_world(22.5, 15.7, 0.6)
	add_child(water)
	var duck := LootModels.build("duck", Color("#ffd23f"))
	var b := _bounds(duck, Transform3D.IDENTITY)
	var k := 0.5 / maxf(0.01, maxf(b.size.x, maxf(b.size.y, b.size.z)))
	duck.scale = Vector3.ONE * k
	duck.position = to_world(21.8, 15.7, 0.6 - b.position.y * k)
	duck.rotation.y = 0.4
	add_child(duck)
	# The bath's curtain, drawn back to either end on its rail.
	var rail := _pivot(self, to_world(22.5, 16.45), 0.0)
	_mesh(rail, _box(Vector3(3.0, 0.03, 0.03)), Color("#b8b8b0"), Vector3(0, 1.05, 0), true)
	for cx in [-1.3, 1.3]:
		_mesh(rail, _box(Vector3(0.38, 0.85, 0.06)), Color("#86c5d8"), Vector3(cx, 0.6, 0), true)


# --- Rooms, in the light or the dark -------------------------------------------------------

## The room a spot of the world is in, a little generously (what hangs on a
## wall stands on its line), and the lounge for the front door outside its
## wall. "" for the doorways and the rest.
func _room_of_world(p: Vector3) -> String:
	var at := Vector2(p.x + Museum.w / 2.0, p.z + Museum.h / 2.0)
	for id in Den.ORDER:
		if Rect2(Den.rect(id)).grow(0.1).has_point(at):
			return id
	var d: Array = Den.FRONT_DOOR
	if Rect2(d[0] - 1.0, d[1] - 1.0, d[2] + 2.0, d[3] + 2.0).has_point(at):
		return "salon"
	return ""


## What was built since `base` (children of this node), each into the node of
## the room it stands in: furniture, posters, stands, lamps, labels... A dark
## room hides its node (and the lights in it go out).
func _sort_into_rooms(base: int) -> void:
	var loose := get_children().slice(base)
	for id in Den.ORDER:
		var n := Node3D.new()
		n.name = "Room_" + id
		add_child(n)
		_room_nodes[id] = n
		_dark[id] = 1.0
		_dark_goal[id] = 1.0
	for c in loose:
		if c is Node3D:
			var id := _room_of_world((c as Node3D).position)
			if id != "":
				# (Not reparent: this node is not in the tree yet; the rooms
				# stand where this one does, so nothing needs moving.)
				remove_child(c)
				_room_nodes[id].add_child(c)


## A veil for each room: a dark, see-through box just over the walls, so the
## floor and the walls are a faint outline and nothing else shows through.
func _veil_rooms() -> void:
	for id in Den.ORDER:
		var r := Den.rect(id)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(r.size.x - 0.04, VEIL_HEIGHT, r.size.y - 0.04)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(VEIL_COLOUR, VEIL_ALPHA)
		var box := MeshInstance3D.new()
		box.mesh = mesh
		box.material_override = mat
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box.position = to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0, VEIL_HEIGHT / 2.0)
		add_child(box)
		_veils[id] = box
		_show_room(id)


## Which rooms are seen (Den.visible_rooms); the others go dark, over
## VEIL_SECONDS, or at once (snap: as the round is laid out).
func set_visible_rooms(ids: Array, snap := false) -> void:
	for id in Den.ORDER:
		_dark_goal[id] = 0.0 if ids.has(id) else 1.0
		if snap:
			_dark[id] = _dark_goal[id]
		_show_room(id)


## Whether a room's contents are drawn now (not fully dark).
func shows(id: String) -> bool:
	return float(_dark.get(id, 0.0)) < 0.999


## Whether what stands at a point (tiles) is drawn: in a room that is not
## dark, or in a doorway.
func shows_at(x: float, y: float) -> bool:
	var id := Den.room_at(x, y)
	return id == "" or shows(id)


func _show_room(id: String) -> void:
	var dark: float = _dark.get(id, 1.0)
	if _room_nodes.has(id):
		(_room_nodes[id] as Node3D).visible = dark < 0.999
	if _veils.has(id):
		var box := _veils[id] as MeshInstance3D
		box.visible = dark > 0.001
		var mat := box.material_override as StandardMaterial3D
		mat.albedo_color = Color(VEIL_COLOUR, VEIL_ALPHA * dark)


func _process(dt: float) -> void:
	_pose_alert(dt)
	_bench_clock += dt
	for i in _bench_socks:
		# Under the glass it lies still; open, it floats up and turns.
		var open: bool = _bench_open_now.get(i, false)
		_bench_socks[i].position.y = 1.1 + sin(_bench_clock * 3.0) * 0.06 if open else 0.62
		_bench_socks[i].rotation.y = _bench_clock * 1.6 if open else 0.4
	_arcade_clock += dt
	for m in _arcade_pictures:
		# A screen that flickers: bright most of the time, dimmer in steps.
		m.albedo_color = Color.WHITE * (1.0 if int(_arcade_clock * 5.0) % 4 != 0 else 0.72)
	for id in Den.ORDER:
		var goal: float = _dark_goal.get(id, 1.0)
		var dark: float = _dark.get(id, 1.0)
		if dark != goal:
			_dark[id] = move_toward(dark, goal, dt / VEIL_SECONDS)
			_show_room(id)
	for id in _door_nodes:
		var d: Dictionary = _door_nodes[id]
		if d.open != d.goal:
			d.open = move_toward(d.open, d.goal, dt / Den.DOOR_SECONDS)
			_pose_door(d)


# --- The doors between rooms -----------------------------------------------------------------

## A pair of sliding leaves in each gap (Den.DOORS), wood with a brass knob,
## that draw back into the wall on either side when it opens, under a beam
## over the gap. Shut, they fill it; open, the floor shows through.
func _doors() -> void:
	for entry in Den.DOORS:
		var id: String = entry.id
		var r := Den.door_rect(id)
		var horizontal := r.size.x >= r.size.y
		var length := float(maxi(r.size.x, r.size.y))
		# Its x runs along the gap, its z across the wall.
		var root := _pivot(self, to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0), 0.0 if horizontal else PI / 2.0)
		_mesh(root, _box(Vector3(length, 0.1, 0.4)), Color("#7a4a28"), Vector3(0, 1.1, 0))
		var leaves: Array = []
		for s in [-1.0, 1.0]:
			var leaf := Node3D.new()
			root.add_child(leaf)
			var w := length / 2.0 - 0.02
			_mesh(leaf, _box(Vector3(w, 1.02, 0.36)), Color("#7a4a28"), Vector3(0, 0.51, 0))
			_mesh(leaf, _box(Vector3(w - 0.16, 0.78, 0.4)), Color("#b98552"), Vector3(0, 0.51, 0))
			_mesh(leaf, _box(Vector3(0.07, 0.07, 0.46)), Color("#f0c46a"), Vector3(-s * (w / 2.0 - 0.12), 0.5, 0))
			leaves.append(leaf)
		var state := {"leaves": leaves, "length": length, "open": 0.0, "goal": 0.0}
		_door_nodes[id] = state
		set_door(id, Den.is_open(id), true)


## Open or shut a door as drawn (Den says whether it may): swinging, or at
## once (snap).
func set_door(id: String, open: bool, snap := false) -> void:
	if not _door_nodes.has(id):
		return
	var d: Dictionary = _door_nodes[id]
	d.goal = 1.0 if open else 0.0
	if snap:
		d.open = d.goal
		_pose_door(d)


## Each leaf slides its own width into the wall: eased.
func _pose_door(d: Dictionary) -> void:
	var k: float = d.open
	k = k * k * (3.0 - 2.0 * k)
	var length: float = d.length
	var slide := length / 2.0 * k
	var leaves: Array = d.leaves
	var left: Node3D = leaves[0]
	var right: Node3D = leaves[1]
	left.position = Vector3(-length / 4.0 - slide, 0, 0)
	right.position = Vector3(length / 4.0 + slide, 0, 0)


# --- Lights --------------------------------------------------------------------------

func _lamps() -> void:
	# Lamps, warm and shadowless: a few to a room, no more.
	for spot in [
		[2.0, 17.2, 1.5, LAMP, 1.5, 7.0], [5.0, 12.5, 2.0, LAMP, 1.0, 8.0], [10.0, 20.0, 2.5, LAMP, 1.1, 9.0],
		[14.5, 12.0, 2.0, LAMP, 1.1, 8.0], [17.0, 18.0, 2.0, LAMP, 1.0, 8.0],
		[10.0, 6.0, 2.6, LAMP, 0.9, 9.0],
		[2.5, 3.0, 2.4, LAMP, 1.0, 5.5], [6.5, 3.0, 2.4, LAMP, 1.0, 5.5], [10.5, 3.0, 2.4, LAMP, 1.0, 5.5],
		[14.5, 3.0, 2.4, LAMP, 1.0, 5.5], [18.5, 3.0, 2.4, LAMP, 1.0, 5.5],
		[24.0, 4.0, 2.2, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 6.5], [27.5, 11.0, 2.2, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 6.5],
		[34.5, 5.5, 2.0, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 5.5], [40.5, 5.5, 2.0, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 5.5],
		[38.0, 2.5, 2.0, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 5.0], [38.0, 9.5, 2.0, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 5.0],
		[46.5, 3.5, 2.2, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 6.5], [54.0, 3.5, 2.2, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 6.5],
		[45.5, 10.0, 2.0, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 5.5], [49.0, 9.5, 2.0, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 5.0],
		[54.5, 10.5, 2.2, LANTERN, LIGHT_LANTERN / LIGHT_LAMP_GAIN, 6.5],
		[25.0, 18.5, 2.0, LIGHT_BATH, 1.1, 7.0], [22.5, 16.5, 1.5, LIGHT_BATH, 0.8, 5.0],
	]:
		var l := OmniLight3D.new()
		l.position = to_world(spot[0], spot[1], spot[2])
		l.light_color = spot[3]
		l.light_energy = spot[4] * LIGHT_LAMP_GAIN
		l.omni_range = spot[5]
		l.omni_attenuation = 1.0
		l.light_specular = 0.0
		l.light_volumetric_fog_energy = 0.0
		add_child(l)
	# The paper lanterns of the dojo, glowing.
	for t in [Vector2(24.0, 4.0), Vector2(27.5, 11.0), Vector2(34.5, 5.5), Vector2(40.5, 5.5), Vector2(38.0, 2.5), Vector2(38.0, 9.5),
			Vector2(46.5, 3.5), Vector2(54.0, 3.5), Vector2(45.5, 10.0), Vector2(49.0, 9.5), Vector2(54.5, 10.5)]:
		var lantern := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.22
		s.height = 0.5
		lantern.mesh = s
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#ffd9a0")
		m.emission_enabled = true
		m.emission = LANTERN
		m.emission_energy_multiplier = GLOW_LANTERN
		lantern.material_override = m
		lantern.position = to_world(t.x, t.y, 2.2)
		lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lantern)


## The house's mood for the world's Environment and its "moon": warm and
## soft where the museum is a cold night (Main._set_mood).
static func mood(env: Environment, sun: DirectionalLight3D) -> void:
	env.background_color = Color("#1c130e")
	env.ambient_light_color = Color("#ffdcae")
	env.ambient_light_energy = LIGHT_AMBIENT
	env.tonemap_exposure = LIGHT_EXPOSURE
	env.tonemap_white = 8.0
	env.adjustment_saturation = 1.05
	env.adjustment_contrast = 1.02
	env.glow_intensity = LIGHT_GLOW
	env.glow_hdr_threshold = LIGHT_GLOW_THRESHOLD
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color("#ffe8c8")
	env.ssr_enabled = false
	env.ssil_enabled = false
	sun.light_color = Color("#ffe6c4")
	sun.light_energy = LIGHT_SUN
	sun.shadow_opacity = 0.35
