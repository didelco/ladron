class_name MuseumView
extends Node3D
## The museum as drawn: floor, walls, the collection in its cases, paintings
## and the emergency lighting. Built once per round from Museum; nothing here
## changes while the round runs. Port of the web version's Floor, Walls,
## Exhibits, Paintings and EmergencyLights.

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
## Warm wall lamps, one on the north wall of a gallery: the warm pools in the
## blue night. Few, small and shadowless, so they cost next to nothing.
const MAX_SCONCES := 6
const SCONCE_COLOUR := Color("#ffb45a")
const SCONCE_ENERGY := 1.4
const SCONCE_RANGE := 3.2
const SCONCE_HEIGHT := 0.98

const C := {
	"night": Color("#0f0d14"),
	"floor": Color("#2b2834"),
	"floor_line": Color("#474357"),
	"gold": Color("#f0c46a"),
	"gold_dim": Color("#9a7a3c"),
	"wall_top": Color("#544a5e"),
	"bone": Color("#e8ddc0"),
	"bone_dark": Color("#b9a883"),
	"mineral": Color("#7ad6ff"),
	"mineral_warm": Color("#ff8ab5"),
	"fern": Color("#4f9e5e"),
	"stone": Color("#5a5560"),
	"crimson": Color("#9b2c3f"),
	"wall_side": Color("#211d29"),
	"wall_cap": Color("#6f6479"),
	"ink": Color("#08070c"),
	## the solid heart of a thick wall, read as filled in, not as roof
	"core": Color("#15111d"),
	"case_dark": Color("#232634"),
	"glass": Color("#a8d8e8"),
	"emergency": Color("#4ade80"),
}

## The styles a museum can be built in, so the nights do not all look alike:
## the floor (floor.gdshader: pattern, two tones, joint, gloss) and the walls
## (wall.gdshader: wallpaper, pattern, wainscot and dado; cap, trim, skirting).
const THEMES := [
	# A classical museum: marble, crimson damask over a wooden wainscot.
	{"floor": 0, "stone": Color("#2a2530"), "stone2": Color("#3a3340"), "joint": Color("#4a4458"), "gloss": 0.22,
		"paper": Color("#4a1826"), "paper2": Color("#5e2233"), "wallpaper": 1, "wainscot": Color("#3a2416"), "dado": 0.5,
		"cap": Color("#7a6a5a"), "trim": Color("#9a7a3c"), "skirt": Color("#08070c")},
	# A modern gallery: polished concrete, pale plaster, a black skirting.
	{"floor": 1, "stone": Color("#34343c"), "stone2": Color("#3b3b44"), "joint": Color("#1c1c22"), "gloss": 0.3,
		"paper": Color("#5c5955"), "paper2": Color("#5c5955"), "wallpaper": 0, "wainscot": Color("#5c5955"), "dado": 0.0,
		"cap": Color("#56534f"), "trim": Color("#1c1c22"), "skirt": Color("#08070c")},
	# An old natural-history museum: oak boards, green stripes, panelling.
	{"floor": 2, "stone": Color("#3a2416"), "stone2": Color("#4d301c"), "joint": Color("#140c07"), "gloss": 0.4,
		"paper": Color("#1c3326"), "paper2": Color("#23402f"), "wallpaper": 2, "wainscot": Color("#4a2e1a"), "dado": 0.55,
		"cap": Color("#5a4a36"), "trim": Color("#9a7a3c"), "skirt": Color("#140c07")},
]

## Every look there is, the generator's and the story museums': the floor
## of one and the walls of another can be mixed (the map editor does).
static func looks() -> Array:
	var all: Array = THEMES.duplicate()
	for m in Story.MUSEUMS:
		all.append(m.palette)
	return all


const FLOOR_KEYS := ["floor", "stone", "stone2", "joint", "gloss"]
const WALL_KEYS := ["paper", "paper2", "wallpaper", "wainscot", "dado", "cap", "trim", "skirt"]


## The floor of look `floor_i` and the walls of look `wall_i` (looks()).
static func mix(floor_i: int, wall_i: int) -> Dictionary:
	var all := looks()
	var out := {}
	for k in FLOOR_KEYS:
		out[k] = all[floor_i][k]
	for k in WALL_KEYS:
		out[k] = all[wall_i][k]
	return out


## The wall tiles with a painting on them, so a lamp is not hung over one.
var _hung := {}
## this museum's style (THEMES), from its seed: the same night, the same look
var theme: Dictionary = THEMES[0]
## A style to build in instead (THEMES keys): the story's museums each have
## their own (Story.palette). Empty, the style comes from the seed.
static var palette := {}
## What stands on a case, chosen by hand (a map from the editor): tile to one
## of EXHIBITS. The rest, and every case when empty, as the hash says.
static var exhibits := {}
const EXHIBITS := ["colours", "butterflies", "minerals", "ammonite", "meteorite", "statue", "skull", "lego_skull", "diorama", "amphora", "globe", "totem", "bear", "plinth"]


func build() -> void:
	theme = palette if not palette.is_empty() else THEMES[posmod(Museum.seed_used, THEMES.size())]
	_floor()
	_walls()
	_exhibits()
	_paintings()
	_emergency_lights()
	_sconces()


static func to_world(x: float, y: float, height := 0.0) -> Vector3:
	return Vector3(x - Museum.w / 2.0, height, y - Museum.h / 2.0)


static func toon(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m


## A piece modelled in Blender (a collection in art/*.blend, exported to
## assets/models/<name>.glb), in the same toon shading as the rest: each
## material keeps its colour, texture, glow and transparency. What is see-through
## casts no shadow.
static func asset(name: String) -> Node3D:
	var scene: PackedScene = load("res://assets/models/%s.glb" % name)
	var node: Node3D = scene.instantiate()
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src == null:
				continue
			if not _asset_mats.has(src):
				var m := src.duplicate() as BaseMaterial3D
				m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				m.metallic = 0.0
				m.roughness = 1.0
				_asset_mats[src] = m
			mi.set_surface_override_material(s, _asset_mats[src])
			if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static var _asset_mats := {}


## The arcade machines' games (Themes.VARIANTS), one look each, in the modern
## age's pop colours: the cabinet ("mueble"), the marquee and its stripes
## ("marquesina", with the lid, what the camera sees most), the screen, and
## what is on it, in pixels ("." is the screen, a letter one of its inks).
## You play pong on every one of them all the same (Arcades).
const ARCADE_GAMES := {
	# Table tennis: the first machine, as it was modelled.
	"tenis": {"mueble": "#7a3ce0", "marquesina": "#ffd400", "screen": "#0b3326", "ink": {"a": "#3cffb0"},
		"art": ["........a.......", ".a..............", ".a......a.......", ".a..............", "........a...a...",
			"..............a.", "........a.....a.", "..............a.", "........a......."]},
	# Invaders from space, rank on rank, and the gun under them.
	"invasores": {"mueble": "#00c2d8", "marquesina": "#ff4f9a", "screen": "#07071a",
		"ink": {"g": "#7dff5a", "w": "#ffffff", "c": "#00c2d8"},
		"art": ["................", "..g...g...g...g.", ".ggg.ggg.ggg.ggg", ".g.g.g.g.g.g.g.g", "................",
			"..........w.....", "................", ".......c........", "......ccc......."]},
	# The dot-eater, a ghost after it, in a maze.
	"comecocos": {"mueble": "#ffd400", "marquesina": "#00c2d8", "screen": "#0a0f3a",
		"ink": {"b": "#2f5fd0", "y": "#ffd400", "w": "#ffe9c0", "p": "#ff4f9a"},
		"art": ["bbbbbbbbbbbbbbbb", "................", ".yyy........ppp.", "yy.......w.ppppp", "y..w..w..w.ppppp",
			"yy.........ppppp", ".yyy.......p.p.p", "................", "bbbbbbbbbbbbbbbb"]},
	# Falling blocks, a well filling up.
	"bloques": {"mueble": "#ff4f9a", "marquesina": "#8a4dff", "screen": "#120a28",
		"ink": {"c": "#00c2d8", "y": "#ffd400", "p": "#ff4f9a", "g": "#5cff7a", "v": "#8a4dff"},
		"art": ["......ppp.......", ".......p........", "................", "................", "................",
			"c.............yy", "cc..gg....vv.yyy", "ccggg.yyyvvv.ppp", "cyyggppyyvvcc.pp"]},
	# The snake, and the apple it is after.
	"serpiente": {"mueble": "#3ccf6a", "marquesina": "#ff8a1c", "screen": "#0e2a12",
		"ink": {"s": "#9dff3a", "r": "#ff3a4a"},
		"art": ["................", "..ssssssss......", "..s.......s.....", "..s.......s.....", "..s.......sssss.",
			"..s..........s..", "..sss......r.s..", "................", "................"]},
	# Racing: two cars on a road, seen from above.
	"carreras": {"mueble": "#ff5a36", "marquesina": "#f4f2ec", "screen": "#2a2a33",
		"ink": {"g": "#3ccf6a", "w": "#f4f2ec", "c": "#00c2d8", "y": "#ffd400"},
		"art": ["gg.....w......gg", "gg..c.........gg", "gg.ccc.w......gg", "gg..c.........gg", "gg.....w......gg",
			"gg.........y..gg", "gg.....w..yyy.gg", "gg.........y..gg", "gg.....w......gg"]},
}
## The first model's materials (art/temas/moderna.py), before they were named
## the way the game tints them: as which "color_..." each is taken.
const ARCADE_OLD_NAMES := {"morado": "color_mueble", "morado_oscuro": "color_mueble_oscuro_40", "cartel": "color_marquesina"}


## Dress an arcade machine (asset(Arcades.MODEL)) as one of its games
## (ARCADE_GAMES), cheaper than a model per game. As with the pieces to steal
## (LootModels), the materials whose name starts with "color" take the
## game's colours: "color_mueble" the cabinet's, "color_marquesina" the
## marquee's, and a "_claro_N" or "_oscuro_N" after it N % lighter or
## darker; the rest (the screen, the black, the metal) keep their own. And on
## the screen (the material whose name starts with "pantalla"), the game's
## picture.
static func arcade_game(model: Node3D, game: String) -> void:
	var look: Dictionary = ARCADE_GAMES[game]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var screen := false
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src == null:
				continue
			var name: String = ARCADE_OLD_NAMES.get(src.resource_name, src.resource_name)
			screen = screen or name.begins_with("pantalla")
			var c := _arcade_colour(look, name)
			if c.a == 0.0:
				continue
			var key := "%s/%s" % [game, src.resource_name]
			if not _arcade_mats.has(key):
				var m := mi.get_active_material(s).duplicate() as BaseMaterial3D
				m.albedo_color = c
				if m.emission_enabled:
					m.emission = c
				_arcade_mats[key] = m
			mi.set_surface_override_material(s, _arcade_mats[key])
		if screen:
			_arcade_screen(mi, game)


## The game's colour for a material named "color_<part>[_claro|_oscuro_N]",
## or none (transparent) for any other.
static func _arcade_colour(look: Dictionary, name: String) -> Color:
	var bits := name.split("_")
	if bits.size() < 2 or bits[0] != "color" or not look.has(bits[1]):
		return Color(0, 0, 0, 0)
	var c := Color(look[bits[1]])
	if bits.size() >= 4 and bits[2] == "claro":
		c = c.lightened(int(bits[3]) / 100.0)
	elif bits.size() >= 4 and bits[2] == "oscuro":
		c = c.darkened(int(bits[3]) / 100.0)
	return c


## The game's picture on the screen's glass, just in front of it: facing the
## way the glass faces (its broad faces, front and back, towards +Z), as
## wide as it is and leaning back as it does.
static func _arcade_screen(mi: MeshInstance3D, game: String) -> void:
	var faces := mi.mesh.get_faces()
	var normal := Vector3.ZERO
	var centre := Vector3.ZERO
	var area := 0.0
	var mids: Array[Vector3] = []
	for i in range(0, faces.size(), 3):
		var n := (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i])
		if n.z < 0.0:
			n = -n
		if n.length() == 0.0 or n.normalized().z < 0.3:
			continue
		var mid := (faces[i] + faces[i + 1] + faces[i + 2]) / 3.0
		normal += n
		centre += mid * n.length()
		area += n.length()
		mids.append(mid)
	if area == 0.0:
		return
	normal = normal.normalized()
	centre /= area
	# From the middle of the glass to its front face.
	var front := 0.0
	for mid in mids:
		front = maxf(front, (mid - centre).dot(normal))
	centre += normal * front
	var box := mi.get_aabb()
	var picture := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(box.size.x, box.size.y / maxf(normal.z, 0.3)) * 0.9
	picture.mesh = quad
	picture.material_override = _arcade_picture(game)
	picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	picture.basis = Basis(Vector3.RIGHT, normal.cross(Vector3.RIGHT), normal)
	picture.position = centre + normal * 0.003
	mi.add_child(picture)


static var _arcade_mats := {}


## A game's picture, lit from within: its pixels, sharp.
static func _arcade_picture(game: String) -> StandardMaterial3D:
	var key := "%s/picture" % game
	if _arcade_mats.has(key):
		return _arcade_mats[key]
	var look: Dictionary = ARCADE_GAMES[game]
	var rows: Array = look.art
	var img := Image.create(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	img.fill(Color(look.screen))
	for y in rows.size():
		for x in rows[y].length():
			var ink: String = rows[y][x]
			if ink != ".":
				img.set_pixel(x, y, Color(look.ink[ink]))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_arcade_mats[key] = m
	return m


# --- Floor -------------------------------------------------------------------

## The marble floor: a shader does the slabs, veins, joints and the contact
## shadow (floor.gdshader). All it needs from here is the plan, one texel a
## tile: how solid each tile is, and whether it is outside the building.
func _floor() -> void:
	var w := Museum.w
	var h := Museum.h
	var img := Image.create(w, h, false, Image.FORMAT_RG8)
	for y in h:
		for x in w:
			var t := Museum.grid[y * w + x]
			var solid := 1.0 if t == Tiles.WALL else (0.6 if t == Tiles.COVER else 0.0)
			img.set_pixel(x, y, Color(solid, 1.0 if Museum.is_outside(x, y) else 0.0, 0))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var veins := NoiseTexture2D.new()
	veins.noise = noise
	veins.seamless = true
	veins.width = 256
	veins.height = 256
	var m := ShaderMaterial.new()
	m.shader = preload("res://scenes/floor.gdshader")
	m.set_shader_parameter("plan", ImageTexture.create_from_image(img))
	m.set_shader_parameter("veins", veins)
	m.set_shader_parameter("size", Vector2(w, h))
	m.set_shader_parameter("pattern", theme.floor)
	for k in ["stone", "stone2", "joint"]:
		var c: Color = theme[k]
		m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("gloss_roughness", theme.gloss)
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, h)
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = m
	add_child(node)


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
		var all: Array[Vector2i] = set_and_h[0]
		var wh: float = set_and_h[1]
		# A thick mass of wall: only its rim is dressed as a wall; the core,
		# the cells with no floor round them, is solid dark, like the filled-in
		# walls of a plan — not a broad slab of lit roof.
		var cells: Array[Vector2i] = []
		var core: Array[Vector2i] = []
		for t in all:
			(core if _is_core(t) else cells).append(t)
		_instances(_box(Vector3(1, wh, 1)), core, wh / 2, toon(C.core))
		_instances(_box(Vector3(1, wh, 1)), cells, wh / 2, _wall_face(), 0.16)
		_instances(_box(Vector3(1.04, CAP_H, 1.04)), cells, wh + CAP_H / 2, toon(theme.cap), 0.14, true)
		_instances(_box(Vector3(1.02, TRIM_H, 1.02)), cells, wh - TRIM_H * 1.5, toon(theme.trim))
		_instances(_box(Vector3(1.03, SKIRT_H, 1.03)), cells, SKIRT_H / 2, toon(theme.skirt))
		# A dado rail over the wainscot, where the style has one.
		if theme.dado > 0:
			_instances(_box(Vector3(1.015, 0.035, 1.015)), cells, theme.dado, toon(theme.trim))


## The wall faces in this museum's style: wallpaper over a wainscot
## (wall.gdshader), each block's shade from its instance colour.
func _wall_face() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://scenes/wall.gdshader")
	for k in ["paper", "paper2", "wainscot"]:
		var c: Color = theme[k]
		m.set_shader_parameter(k, Vector3(c.r, c.g, c.b))
	m.set_shader_parameter("pattern", theme.wallpaper)
	m.set_shader_parameter("dado", theme.dado)
	return m


## Deep inside a wall mass: no floor or case in any of the eight cells round it.
func _is_core(t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := t.x + dx
			var y := t.y + dy
			if x < 0 or y < 0 or x >= Museum.w or y >= Museum.h:
				continue
			if Museum.grid[y * Museum.w + x] != Tiles.WALL:
				return false
	return true


func _cap_shade(t: Vector2i) -> float:
	for d in Museum.DIRS:
		var x := t.x + d.x
		var y := t.y + d.y
		if x >= 0 and y >= 0 and x < Museum.w and y < Museum.h and Museum.grid[y * Museum.w + x] != Tiles.WALL:
			return 1.0
	return 0.45


# --- The collection ------------------------------------------------------------

## What stands on each piece of cover: a glass case of butterflies, minerals or
## a fossil, a skull or a statue on a plinth, a fern diorama. The big pieces (a dinosaur, sarcophagi, a bear) stand on
## blocks of cover of their own. Which piece a tile gets is the museum's
## collection's (Collection): from a hash of its coordinates, so a gallery
## looks the same every time, keeping count so an icon stands once and each
## arcade machine is a different game. All waist-high: the
## rules hide someone on all fours behind any of them. The job's own case is
## an empty vitrine: the piece itself is drawn by the game, glowing.
func _exhibits() -> void:
	Collection.ensure()
	for b in Museum.big_pieces:
		_big_piece(b.kind, b.rect)
	for t in Museum.cover_tiles:
		if not Museum.big_piece_at(t).is_empty():
			continue
		var piece := Node3D.new()
		piece.position = to_world(t.x + 0.5, t.y + 0.5)
		add_child(piece)
		# An empty pedestal, low, for a thief to pose on (Plinths).
		if Plinths.is_plinth(t) or exhibits.get(t, "") == "plinth":
			_empty_plinth(piece)
			continue
		# A piece of furniture to hide in (Hideouts).
		var hide: String = Hideouts.pieces.get(t, exhibits.get(t, ""))
		if Hideouts.PIECES.has(hide):
			_hideout(piece, hide, t)
			continue
		_base(piece)
		var yaw := _hash01(t.x, t.y, 3) * TAU
		if t == Heist.at:
			_vitrine(piece, null)
		elif exhibits.has(t):
			_exhibit(piece, exhibits[t], t, yaw)
		else:
			# What the gallery's theme shows (a corridor, a bit of everything).
			var pick := Collection.at(t)
			_themed(piece, pick[0], pick[1], t, yaw, pick[2])


## The way a piece on tile t with a front faces: onto the free floor beside
## it, the camera's side (south) first, then east and west, north last.
## Vector2i.ZERO if there is none.
static func front_of(t: Vector2i) -> Vector2i:
	for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
		if Museum.tile_at(t.x + d.x + 0.5, t.y + d.y + 0.5) == Tiles.FLOOR:
			return d
	return Vector2i.ZERO


## The turn that puts a model's front (+Z) toward front_of(t): facing south
## if it has nowhere to face.
static func front_yaw(t: Vector2i) -> float:
	var d := front_of(t)
	return atan2(d.x, d.y) if d != Vector2i.ZERO else 0.0


## A piece of a theme in its place: in a glass case, on a plinth, or
## standing on the slab. One of MuseumView's own ("@...") has its own stand.
## A piece with variants (Themes.VARIANTS) is dressed as this one.
func _themed(piece: Node3D, where: String, what: String, t: Vector2i, yaw: float, variant := "") -> void:
	if what.begins_with("@") or not "/" in what:
		_exhibit(piece, what.trim_prefix("@"), t, yaw)
		return
	var model := asset(what)
	if what == Arcades.MODEL and variant != "":
		arcade_game(model, variant)
	# Turned to a quarter, a little off square: the front is seen from most
	# sides. One with a front that must not face a wall, to the free floor.
	var quarter: float = front_yaw(t) if what in Themes.FRONTED else round(yaw / (PI / 2)) * PI / 2
	var turn: float = quarter + (_hash01(t.x, t.y, 13) - 0.5) * 0.5
	match where:
		"case":
			var inside := Node3D.new()
			inside.rotation.y = turn
			inside.add_child(model)
			_vitrine(piece, inside)
		"plinth":
			_pedestal(piece, t)
			_on_pedestal(piece, model, front_yaw(t) + _nudge(t))
		_:
			_pivot(piece, Vector3(0, 0.16, 0), turn).add_child(model)


## One of EXHIBITS on its case, as a map asks for it.
func _exhibit(piece: Node3D, what: String, t: Vector2i, yaw: float) -> void:
	var odd := _hash01(t.x, t.y, 5) < 0.5
	match what:
		"butterflies": _vitrine(piece, _butterflies(t.x + t.y))
		"colours": _vitrine(piece, _colours(t))
		"minerals": _vitrine(piece, _minerals(t.x + t.y))
		# Out of the case, on a plinth of their own: the detailed ones.
		"ammonite", "meteorite":
			_pedestal(piece, t)
			_on_pedestal(piece, _ammonite() if what == "ammonite" else _rock(), front_yaw(t) + _nudge(t))
		"statue":
			_pedestal(piece, t)
			var p := _pivot(piece, Vector3.ZERO, front_yaw(t) + _nudge(t))
			_specimen(p, "res://assets/models/statue-%s.glb" % ("a" if odd else "b"), 0.5, 0.88, 0.8, C.bone_dark)
		"skull", "lego_skull":
			# Facing the gallery (the camera), a little off square.
			_pedestal(piece, t)
			_on_pedestal(piece, asset("craneo_lego" if what == "lego_skull" else "craneo"), front_yaw(t) + _nudge(t))
		"diorama": _diorama(piece, t.x + t.y)
		"amphora":
			_pedestal(piece, t, 0.42)
			_amphora(_pivot(piece, Vector3.ZERO, front_yaw(t) + _nudge(t)), 0.42)
		"globe": _globe(_pivot(piece, Vector3.ZERO, yaw))
		"plinth": _empty_plinth(piece)
		_ when Hideouts.PIECES.has(what): _hideout(piece, what, t)
		"totem": _totem(_pivot(piece, Vector3.ZERO, round(yaw / (PI / 2)) * PI / 2))
		"bear":
			# A map from before the bear took two tiles: at its old size, on one.
			var p := _pivot(piece, Vector3.ZERO, yaw)
			_plinth(p, 0.3, 0.98)
			var small := _pivot(p, Vector3(0, 0.3, 0))
			small.scale = Vector3(0.5, 1.0 / 2.4, 0.5)
			small.add_child(asset("oso"))
		_ when "/" in what: _themed(piece, Themes.where_of(what), what, t, yaw, Collection.variant_at(t))
		_: _vitrine(piece, null)


## A piece of furniture to hide in (Hideouts.PIECES), standing on the floor
## with its front (a door, a lid, an opening) to the free floor beside it —
## the camera's side if it can.
func _hideout(piece: Node3D, kind: String, t: Vector2i) -> void:
	_pivot(piece, Vector3.ZERO, front_yaw(t)).add_child(asset(Hideouts.PIECES[kind].model))


## The big pieces' models (the ones you hide in are the themes').
const BIG_MODELS := {"dinosaur": "dinosaurio", "sarcophagus": "sarcofago", "trojan_horse": "temas/antiguo/caballo_troya",
	"mammoth": "temas/prehistoria/mamut", "log": "temas/naturaleza/tronco", "car": "temas/moderna/coche"}


## A piece standing on a block of tiles (Museum.big_pieces): the dinosaur on
## its 3x2 platform, the sarcophagus on its 3x1 bier, the bear on a 2x1
## plinth, the Trojan horse on its wheeled deck, the mammoth, the hollow log,
## the little car on its show stand.
## The models lie along their length (along x, all but the sarcophagus, which
## lies along z); either end may face either way.
func _big_piece(kind: String, r: Rect2i) -> void:
	# A square one (the Trojan horse) stands side on to the camera, its hatch
	# to the front.
	var along_x := r.size.x >= r.size.y
	var flip := PI if _hash01(r.position.x, r.position.y, 17) < 0.5 and r.size.x != r.size.y else 0.0
	var yaw := (PI / 2 if along_x else 0.0) if kind == "sarcophagus" else (0.0 if along_x else PI / 2)
	var at := to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0)
	var p := _pivot(self, at, yaw + flip)
	if kind == "bear":
		_long_plinth(p, BEAR_PLINTH)
		_pivot(p, Vector3(0, BEAR_PLINTH.y, 0)).add_child(asset("oso"))
	else:
		p.add_child(asset(BIG_MODELS.get(kind, "sarcofago")))


## The bear's plinth (m: long, high, deep): low, as long as its two tiles.
const BEAR_PLINTH := Vector3(1.84, 0.3, 0.9)


## A long plinth: stone, a brass band round the top, a label on the front (+z).
func _long_plinth(parent: Node3D, size: Vector3) -> void:
	_mesh(parent, _box(size), C.wall_top, Vector3(0, size.y / 2, 0))
	_mesh(parent, _box(Vector3(size.x + 0.02, 0.03, size.z + 0.02)), C.gold_dim, Vector3(0, size.y - 0.04, 0))
	_mesh(parent, _box(Vector3(0.24, 0.06, 0.01)), C.bone, Vector3(0, size.y * 0.6, size.z / 2 + 0.006))


## The slab under every exhibit: there is always something visible where the
## collision is, even if a model fails to load.
func _base(parent: Node3D) -> void:
	_mesh(parent, _box(Vector3(0.9, 0.16, 0.9)), C.case_dark, Vector3(0, 0.08, 0))


## A piece on a pedestal faces the gallery (the camera), turned no more than
## this either way: the pedestals stand square, all alike, and pieces turned
## every which way made the repeats show.
const NUDGE := 0.12


func _nudge(t: Vector2i) -> float:
	return (_hash01(t.x, t.y, 13) - 0.5) * 2.0 * NUDGE


## How tall the pedestals are, and how much of their top a piece fills: as
## wide as this, as tall as that, never grown more than MAX_GROW.
const PEDESTAL_H := 0.5
const PIECE_SPAN := 0.52
const PIECE_TALL := 0.62
const MAX_GROW := 2.4
## A piece lower than this share of its width lies flat: it leans back a
## little, its face to the camera.
const FLAT := 0.4
const FLAT_TILT := 0.45


## A pedestal in its gallery's style, top at h: sandstone with a band of
## lapis (ancient), an eight-sided stone column (middle ages), a rough rock
## (prehistory), a tree stump (nature), a black gallery cube (modern); in a
## corridor, the museum's own plinth.
func _pedestal(parent: Node3D, t: Vector2i, h := PEDESTAL_H) -> void:
	var on_plan := t.x < Museum.w and t.y < Museum.h and Museum.grid.size() == Museum.w * Museum.h
	var room := Museum.room_at(t.x + 0.5, t.y + 0.5) if on_plan else null
	var theme: String = room.theme if room else ""
	var drum := func(r: float, height: float, r2: float, sides: int, colour: Color, y: float, spin := 0.0) -> void:
		var c := CylinderMesh.new()
		c.bottom_radius = r
		c.top_radius = r2
		c.height = height
		c.radial_segments = sides
		c.rings = 1
		_mesh(parent, c, colour, Vector3(0, y, 0)).rotation.y = spin
	match theme:
		"antiguo":
			_mesh(parent, _box(Vector3(0.66, 0.06, 0.66)), Color("#9a7a44"), Vector3(0, 0.03, 0))
			_mesh(parent, _box(Vector3(0.56, h - 0.1, 0.56)), Color("#caa66a"), Vector3(0, 0.06 + (h - 0.1) / 2, 0))
			_mesh(parent, _box(Vector3(0.58, 0.05, 0.58)), Color("#2f5fd0"), Vector3(0, h - 0.075, 0))
			_mesh(parent, _box(Vector3(0.6, 0.012, 0.6)), Color("#e8b53a"), Vector3(0, h - 0.044, 0))
			_mesh(parent, _box(Vector3(0.6, 0.038, 0.6)), Color("#d8b87e"), Vector3(0, h - 0.019, 0))
		"edad_media":
			drum.call(0.34, 0.08, 0.32, 8, Color("#55505c"), 0.04, PI / 8)
			drum.call(0.26, h - 0.13, 0.26, 8, Color("#807a86"), 0.08 + (h - 0.13) / 2, PI / 8)
			drum.call(0.31, 0.05, 0.33, 8, Color("#55505c"), h - 0.025, PI / 8)
		"prehistoria":
			var spin := PI / 7
			drum.call(0.34, h, 0.28, 7, Color("#7c6e5e"), h / 2, spin)
			drum.call(0.29, 0.04, 0.25, 7, Color("#968672"), h + 0.0, spin + 0.3)
		"naturaleza":
			drum.call(0.3, h, 0.27, 12, Color("#5a3e26"), h / 2)
			drum.call(0.25, 0.012, 0.25, 12, Color("#c9a06a"), h + 0.006)
			drum.call(0.12, 0.014, 0.12, 12, Color("#a07a48"), h + 0.008)
		"moderna":
			_mesh(parent, _box(Vector3(0.5, 0.04, 0.5)), C.ink, Vector3(0, 0.02, 0))
			_mesh(parent, _box(Vector3(0.58, h - 0.04, 0.58)), Color("#2a2a32"), Vector3(0, 0.04 + (h - 0.04) / 2, 0))
			_mesh(parent, _box(Vector3(0.596, 0.016, 0.596)), Color("#ececf0"), Vector3(0, h - 0.04, 0))
		_:
			_plinth(parent, h, 0.64)


## A theme's piece on top of its pedestal, made to fill it: grown or shrunk
## to PIECE_SPAN across and at most PIECE_TALL high, and, if it lies flat,
## leant back towards the camera so its face shows. turn: its own heading.
func _on_pedestal(parent: Node3D, model: Node3D, turn: float, h := PEDESTAL_H) -> void:
	var box := _bounds(model, Transform3D.IDENTITY)
	var span := maxf(maxf(box.size.x, box.size.z), 1e-3)
	var k := minf(minf(PIECE_SPAN / span, PIECE_TALL / maxf(box.size.y, 1e-3)), MAX_GROW)
	var flat := box.size.y < span * FLAT
	var tilt := _pivot(parent, Vector3(0, h + (span * k * 0.5 * sin(FLAT_TILT) if flat else 0.0), 0))
	tilt.rotation.x = FLAT_TILT if flat else 0.0
	var holder := _pivot(tilt, Vector3.ZERO, turn if not flat else 0.0)
	holder.scale = Vector3.ONE * k
	var centre := box.get_center()
	model.position = Vector3(-centre.x, -box.position.y, -centre.z)
	holder.add_child(model)


func _plinth(parent: Node3D, h: float, w: float) -> void:
	_mesh(parent, _box(Vector3(w, h, w)), C.wall_top, Vector3(0, h / 2, 0))
	# A brass band round the top, and a label on the front.
	_mesh(parent, _box(Vector3(w + 0.02, 0.03, w + 0.02)), C.gold_dim, Vector3(0, h - 0.04, 0))
	_mesh(parent, _box(Vector3(0.18, 0.06, 0.01)), C.bone, Vector3(0, h * 0.6, w / 2 + 0.006))


## A low pedestal with nothing on it (Plinths): pale stone that stands out
## from the floor, a brass band, and a blank label.
func _empty_plinth(parent: Node3D) -> void:
	var h := Plinths.HEIGHT
	_mesh(parent, _box(Vector3(0.84, 0.06, 0.84)), C.bone_dark, Vector3(0, 0.03, 0))
	_mesh(parent, _box(Vector3(0.74, h, 0.74)), C.bone, Vector3(0, h / 2, 0))
	_mesh(parent, _box(Vector3(0.76, 0.03, 0.76)), C.gold_dim, Vector3(0, h - 0.04, 0))
	_mesh(parent, _box(Vector3(0.18, 0.06, 0.01)), C.bone_dark, Vector3(0, h * 0.5, 0.376))


## The glass case (one model for all of them, art/museo.blend), and
## whatever it holds sitting on its deck.
func _vitrine(parent: Node3D, contents: Node3D) -> void:
	parent.add_child(asset("vitrina"))
	if contents:
		contents.position = Vector3(0, 0.42, 0)
		parent.add_child(contents)


## Bright, simple things in a glass case, in its gallery's colours
## (Themes "colours", on its "cloth"): a vase, an orb on its ring, a stack
## of blocks, a handful of gems or a bowl with a ball. From the camera they
## read as a spot of colour, not as a detail: the detailed pieces stand
## outside the cases.
func _colours(t: Vector2i) -> Node3D:
	# (Off any plan, as the editor's icons are: any theme.)
	var on_plan := t.x < Museum.w and t.y < Museum.h and Museum.grid.size() == Museum.w * Museum.h
	var room := Museum.room_at(t.x + 0.5, t.y + 0.5) if on_plan else null
	var ids := Themes.ids()
	var theme: String = room.theme if room and room.theme != "" else ids[int(_hash01(t.x, t.y, 41) * ids.size()) % ids.size()]
	var cols: Array = Themes.ALL[theme].colours
	var first := int(_hash01(t.x, t.y, 43) * cols.size()) % cols.size()
	var a := Color(cols[first])
	var b := Color(cols[(first + 1 + int(_hash01(t.x, t.y, 44) * (cols.size() - 1))) % cols.size()])
	var g := Node3D.new()
	_mesh(g, _box(Vector3(0.66, 0.02, 0.66)), Color(Themes.ALL[theme].cloth), Vector3(0, 0.01, 0))
	var drum := func(r: float, h: float, r2 := -1.0, sides := 10) -> CylinderMesh:
		var c := CylinderMesh.new()
		c.top_radius = r if r2 < 0 else r2
		c.bottom_radius = r
		c.height = h
		c.radial_segments = sides
		c.rings = 1
		return c
	var ball := func(r: float, sides := 12) -> SphereMesh:
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2
		s.radial_segments = sides
		s.rings = sides / 2
		return s
	match int(_hash01(t.x, t.y, 47) * 5):
		0:
			# A vase: a round belly, a neck, a lip in the second colour.
			_mesh(g, ball.call(0.17), a, Vector3(0, 0.19, 0), true)
			_mesh(g, drum.call(0.07, 0.14, 0.09), a, Vector3(0, 0.36, 0), true)
			_mesh(g, drum.call(0.1, 0.03), b, Vector3(0, 0.44, 0), true)
			_mesh(g, drum.call(0.12, 0.04, 0.1), b, Vector3(0, 0.04, 0), true)
		1:
			# An orb on its ring.
			_mesh(g, drum.call(0.14, 0.06, 0.1), b, Vector3(0, 0.05, 0), true)
			_mesh(g, ball.call(0.2, 16), a, Vector3(0, 0.27, 0), true)
		2:
			# A stack of blocks, turned a little each.
			for k in 3:
				var box := _mesh(g, _box(Vector3(0.44 - k * 0.08, 0.1, 0.32 - k * 0.04)), a if k % 2 == 0 else b, Vector3(0, 0.07 + k * 0.1, 0), true)
				box.rotation.y = (k - 1) * 0.25
		3:
			# A handful of gems.
			for k in 3:
				var gem := _mesh(g, ball.call(0.1 - k * 0.015, 5), [a, b, a][k], Vector3(cos(k * 2.1) * 0.13, 0.1, sin(k * 2.1) * 0.13), true)
				gem.scale = Vector3(1.0, 1.3, 1.0)
		_:
			# A wide bowl with a ball in it.
			_mesh(g, drum.call(0.09, 0.05, 0.22), b, Vector3(0, 0.05, 0), true)
			_mesh(g, drum.call(0.22, 0.08, 0.26), b, Vector3(0, 0.12, 0), true)
			_mesh(g, ball.call(0.13), a, Vector3(0, 0.24, 0), true)
	return g


## Pinned butterflies: little bright wings on a card.
func _butterflies(seed: int) -> Node3D:
	var g := Node3D.new()
	_mesh(g, _box(Vector3(0.6, 0.02, 0.6)), C.bone, Vector3(0, 0.01, 0))
	for i in 5:
		var a := _hash01(i, seed) * TAU
		var r := 0.08 + _hash01(i, seed, 4) * 0.14
		var colour: Color = [C.mineral_warm, C.gold, C.mineral, Color("#ff9f1c"), Color("#b07cff")][i]
		for side in [-1, 1]:
			var wing := _mesh(g, _box(Vector3(0.07, 0.008, 0.09)), colour, Vector3(cos(a) * r + side * 0.035, 0.03, sin(a) * r), true)
			wing.rotation.y = a
		_mesh(g, _box(Vector3(0.012, 0.012, 0.08)), C.ink, Vector3(cos(a) * r, 0.035, sin(a) * r), true).rotation.y = a
	return g


## A cluster of crystals catching the light.
func _minerals(seed: int) -> Node3D:
	var g := Node3D.new()
	for i in 4:
		var a := _hash01(i, seed, 2) * TAU
		var r := 0.06 + i * 0.05
		var s := SphereMesh.new()
		s.radius = 0.07 + i * 0.02
		s.height = s.radius * 3.2
		s.radial_segments = 4
		s.rings = 2
		var c := _mesh(g, s, C.mineral_warm if i == 1 else C.mineral, Vector3(cos(a) * r, s.height / 2, sin(a) * r), true)
		c.rotation = Vector3(0.25 * (i - 1.5), a, 0.2)
	return g


## An ammonite on its little stand (art/coleccion.blend).
func _ammonite() -> Node3D:
	return asset("amonite")


## A lump of meteorite on a black stand (art/coleccion.blend).
func _rock() -> Node3D:
	return asset("meteorito")


## A mounted skull, facing the gallery (art/coleccion.blend), or a toy one: a
## minifigure's head with a skull printed on it (art/coleccion.blend).
func _skull(parent: Node3D, yaw: float, toy := false) -> void:
	_pivot(parent, Vector3(0, CASE_HEIGHT - 0.06, 0), yaw).add_child(asset("craneo_lego" if toy else "craneo"))


## A habitat diorama: ferns and a stone in a planter, no glass.
func _diorama(parent: Node3D, seed: int) -> void:
	_mesh(parent, _box(Vector3(0.86, 0.4, 0.86)), C.case_dark, Vector3(0, 0.2, 0))
	_mesh(parent, _box(Vector3(0.8, 0.04, 0.8)), Color("#3b2f24"), Vector3(0, 0.42, 0))
	for i in 6:
		var a := _hash01(i, seed, 5) * TAU
		var r := _hash01(i, seed, 9) * 0.25
		var h := 0.2 + _hash01(i, seed, 11) * 0.3
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.09
		cone.height = h
		cone.radial_segments = 5
		var f := _mesh(parent, cone, C.fern.lightened(_hash01(i, seed, 2) * 0.2), Vector3(cos(a) * r, 0.44 + h / 2, sin(a) * r))
		f.rotation = Vector3(0, a, _hash01(i, seed, 13) * 0.4 - 0.2)
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.12
	s.radial_segments = 6
	s.rings = 3
	_mesh(parent, s, C.stone, Vector3(0.2, 0.46, -0.15))


## A Greek amphora with a band of figures round its belly (art/coleccion.blend).
func _amphora(parent: Node3D, on: float) -> void:
	_pivot(parent, Vector3(0, on, 0)).add_child(asset("anfora"))


## A globe on a wooden stand in a brass meridian (art/coleccion.blend).
func _globe(parent: Node3D) -> void:
	parent.add_child(asset("globo"))


## A totem pole: stacked painted faces, a bird on top (art/coleccion.blend).
func _totem(parent: Node3D) -> void:
	parent.add_child(asset("totem"))


## A downloaded model, fitted to a height and a footprint and sat on its
## plinth: models arrive at whatever scale their author left them in, so the
## bounding box decides. tint repaints it: a museum piece is stone or bone.
func _specimen(parent: Node3D, path: String, on: float, height: float, footprint: float, tint: Color) -> void:
	var scene: PackedScene = load(path)
	if scene == null:
		return
	var model: Node3D = scene.instantiate()
	var holder := Node3D.new()
	holder.add_child(model)
	parent.add_child(holder)
	var box := _bounds(model, Transform3D.IDENTITY)
	if box.size.y <= 0:
		return
	var k := minf(height / box.size.y, footprint / maxf(maxf(box.size.x, box.size.z), 1e-6))
	holder.scale = Vector3.ONE * k
	var centre := box.get_center()
	holder.position = Vector3(-centre.x * k, on - box.position.y * k, -centre.z * k)
	var paint := toon(tint)
	for m in model.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = paint


## Merged bounds of every mesh under a node, in that node's space.
static func _bounds(node: Node, xform: Transform3D) -> AABB:
	var box := AABB()
	var first := true
	var here := xform * (node as Node3D).transform if node is Node3D else xform
	if node is MeshInstance3D:
		var b: AABB = here * (node as MeshInstance3D).get_aabb()
		box = b
		first = false
	for c in node.get_children():
		var cb := _bounds(c, here)
		if cb.size == Vector3.ZERO:
			continue
		box = cb if first else box.merge(cb)
		first = false
	return box


# --- Paintings -----------------------------------------------------------------

## Canvases on the wall faces the camera can see (facing south), each painted
## procedurally, never on a wall with something in front of it (_blocked). A
## stretch of free wall may take a big one: a painting across two modules, or
## a triptych across three; a module may take two or three small ones side by
## side instead of one. A bare module between one and the next.
func _paintings() -> void:
	var most := 6 + Museum.w * Museum.h / 120
	var hung := 0
	var blocked := _blocked()
	for y in range(1, Museum.h - 1):
		var x := 1
		while x < Museum.w - 1:
			if hung >= most:
				return
			var run := _free_wall(x, y, blocked)
			if run == 0 or _hash01(x, y, 23) < 0.72:
				x += 1
				continue
			var room := Museum.room_at(x + 0.5, y + 1.5)
			var theme := room.theme if room else ""
			var pick := _hash01(x, y, 41)
			var span := 3 if pick < 0.1 and run >= 3 else (2 if pick < 0.28 and run >= 2 else 1)
			var frame := Node3D.new()
			frame.position = to_world(x + span / 2.0, y + 1.0, 0.0)
			add_child(frame)
			var seed := x * 31 + y * 7
			var kind := Themes.painting(theme, _hash01(x, y, 37))
			if span == 3:
				_painting(frame, seed, kind, TRIPTYCH)
			elif span == 2:
				_painting(frame, seed, kind, BIG_PAINTING)
			elif pick < 0.46:
				# Two small ones, or three, side by side on the one module.
				var n := 2 if pick < 0.38 else 3
				var size: Vector3 = SMALL_PAINTINGS[n]
				for i in n:
					var at := _pivot(frame, Vector3((i - (n - 1) / 2.0) * size.x * 1.25, 0, 0))
					_painting(at, seed + i * 13, Themes.painting(theme, _hash01(x + i, y, 37)), size)
			else:
				_painting(frame, seed, kind)
			for k in span:
				_hung[Vector2i(x + k, y)] = true
			hung += span
			x += span + 1


## Paintings (m): width, height, and the height of their middle on the wall.
const PAINTING := Vector3(0.7, 0.5, 0.8)
const BIG_PAINTING := Vector3(1.12, 0.8, 0.72)
## Three canvases in one long frame, across three modules.
const TRIPTYCH := Vector3(2.6, 0.62, 0.78)
## Two or three small ones on one module.
const SMALL_PAINTINGS := {2: Vector3(0.36, 0.3, 0.82), 3: Vector3(0.25, 0.22, 0.84)}


## The floor in front of a wall with something on it or against it — a thing
## to knock over, a light switch, an alarm panel — where no painting hangs.
## (A case in front is not floor, so it has none either.)
func _blocked() -> Dictionary:
	var out := {}
	for p in Props.list:
		out[p.tile] = true
	for r in Museum.rooms:
		out[r.switch_at] = true
	for t in [Heist.panel, Heist.panel2]:
		if t.x >= 0:
			out[t] = true
	return out


## How many wall faces in a row, from (x, y) on, a painting may hang on (up
## to three): facing south onto clear floor of the same gallery.
func _free_wall(x: int, y: int, blocked: Dictionary) -> int:
	var room := Museum.room_at(x + 0.5, y + 1.5)
	var n := 0
	while n < 3 and x + n < Museum.w - 1:
		var t := Vector2i(x + n, y)
		var front := Vector2i(t.x, y + 1)
		if Museum.grid[y * Museum.w + t.x] != Tiles.WALL or Museum.is_outside(t.x, y) or \
				Museum.grid[front.y * Museum.w + front.x] != Tiles.FLOOR or blocked.has(front) or \
				Museum.room_at(t.x + 0.5, y + 1.5) != room:
			break
		n += 1
	return n


## A painting in its frame: size is its width, height and middle's height on
## the wall; a triptych (TRIPTYCH) has three canvases in the one frame.
func _painting(parent: Node3D, seed: int, kind := "", size := PAINTING) -> void:
	var fw := size.x
	var fh := size.y
	var cy := size.z
	_mesh(parent, _box(Vector3(fw + 0.05, fh + 0.05, 0.03)), C.ink, Vector3(0, cy, 0.015))
	_mesh(parent, _box(Vector3(fw, fh, 0.05)), C.gold_dim, Vector3(0, cy, 0.03))
	var panels := 3 if size == TRIPTYCH else 1
	# The border a frame leaves round the canvas, and between a triptych's.
	var edge := clampf(fh * 0.2, 0.04, 0.1)
	var cw := (fw - edge - (panels - 1) * 0.05) / panels
	for i in panels:
		var canvas := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(cw, fh - edge)
		canvas.mesh = q
		var m := StandardMaterial3D.new()
		# Unlit and a little dim: most hang where no light reaches, and a lit
		# canvas in the dark was a black rectangle.
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_texture = Canvases.paint(kind, seed + i * 5) if kind != "" else _canvas(seed + i * 5)
		m.albedo_color = Color(0.62, 0.6, 0.58)
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		canvas.material_override = m
		canvas.position = Vector3((i - (panels - 1) / 2.0) * (cw + 0.05), cy, 0.056)
		parent.add_child(canvas)
	_mesh(parent, _box(Vector3(0.16 if fw > 0.5 else 0.08, 0.05 if fw > 0.5 else 0.03, 0.012)), C.bone, Vector3(0, cy - fh / 2 - (0.08 if fw > 0.5 else 0.05), 0.01))


static func _canvas(seed: int, forced := -1) -> ImageTexture:
	var w := 48
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var r := func(k: int) -> float: return _hash01(seed, k, 71)
	var kind := int(r.call(1) * 6) if forced < 0 else forced
	if kind == 3:
		_pipe(img, r)
		return ImageTexture.create_from_image(img)
	if kind == 4:
		_banana(img, r)
		return ImageTexture.create_from_image(img)
	if kind == 5:
		_ice_cream(img, r)
		return ImageTexture.create_from_image(img)
	if kind == 0:
		# Landscape: sky, a moon or low sun, hills in three planes.
		var dusk: bool = r.call(2) > 0.5
		var top := Color("#2a1f4d") if dusk else Color("#274b6e")
		var bottom := Color("#e07a5f") if dusk else Color("#a8d8e8")
		for yy in h:
			img.fill_rect(Rect2i(0, yy, w, 1), top.lerp(bottom, float(yy) / h))
		var sx := int(8 + r.call(3) * 30)
		var sy := int(8 + r.call(4) * 6)
		for yy in range(-3, 4):
			for xx in range(-3, 4):
				if xx * xx + yy * yy <= 9:
					img.set_pixel(clampi(sx + xx, 0, w - 1), clampi(sy + yy, 0, h - 1), Color("#ffd479") if dusk else Color("#fff4d0"))
		for plane in 3:
			var col: Color = [Color("#4a5d4f"), Color("#2f4a3a"), Color("#1b2c24")][plane]
			for xx in w:
				var top_y := int(20 + plane * 4 + sin(xx * 0.16 + r.call(5 + plane) * 6) * (4 - plane))
				img.fill_rect(Rect2i(xx, top_y, 1, h - top_y), col)
	elif kind == 1:
		# Portrait: a sitter in the dark, lit from one side.
		img.fill(Color("#1d120c"))
		img.fill_rect(Rect2i(8, 4, 32, 28), Color("#3a2618"))
		var coat := Color("#2a1a3a") if r.call(2) > 0.5 else Color("#3a1c1c")
		img.fill_rect(Rect2i(12, 26, 24, 10), coat)
		img.fill_rect(Rect2i(19, 10, 10, 14), Color("#d9b48f"))
		img.fill_rect(Rect2i(25, 10, 4, 14), Color("#a8805f"))
		img.fill_rect(Rect2i(18, 7, 12, 5), Color("#1a120c"))
	else:
		# Abstract: blocks of colour on cream, with black lines.
		img.fill(Color("#e8ddc0"))
		var cols := [Color("#9b2c3f"), Color("#7ad6ff"), Color("#f0c46a"), Color("#1b2433")]
		for j in 4:
			img.fill_rect(Rect2i(int(r.call(10 + j) * 34), int(r.call(20 + j) * 24), 8 + int(r.call(30 + j) * 14), 6 + int(r.call(40 + j) * 12)), cols[(j + int(r.call(2) * 4)) % 4])
		for j in 3:
			var at := 6 + int(r.call(60 + j) * 36)
			if r.call(50 + j) > 0.5:
				img.fill_rect(Rect2i(clampi(at, 0, w - 2), 0, 2, h), Color("#141018"))
			else:
				img.fill_rect(Rect2i(0, clampi(at * h / w, 0, h - 2), w, 2), Color("#141018"))
	return ImageTexture.create_from_image(img)


## "This is not a pipe": a brown pipe on cream, and a line of writing under it.
static func _pipe(img: Image, r: Callable) -> void:
	img.fill(Color("#e8dcc0"))
	var wood := Color("#6b3a1e")
	var dark := Color("#3a1e0e")
	# The bowl, the shank and the stem, curving down to the mouthpiece.
	img.fill_rect(Rect2i(30, 8, 9, 12), wood)
	img.fill_rect(Rect2i(29, 9, 1, 10), dark)
	img.fill_rect(Rect2i(31, 8, 7, 2), dark)
	img.fill_rect(Rect2i(32, 18, 6, 3), wood)
	for x in range(9, 31):
		var y := 17 + int(2.0 * sin((x - 9) / 22.0 * PI))
		img.fill_rect(Rect2i(x, y, 1, 3), wood)
		img.set_pixel(x, y + 2, dark)
	img.fill_rect(Rect2i(6, 16, 4, 2), Color("#1a1210"))
	img.fill_rect(Rect2i(33, 11, 2, 5), Color("#8a5a32"))
	# The caption, in a copperplate of dots.
	var x := 10
	while x < 38:
		var word := 2 + int(r.call(80 + x) * 4)
		img.fill_rect(Rect2i(x, 28, word, 1), Color("#2a1e14"))
		img.set_pixel(x, 27, Color("#2a1e14"))
		x += word + 2


## A pop-art banana: yellow, curved, on white, with its brown tips.
static func _banana(img: Image, r: Callable) -> void:
	img.fill(Color("#f7f3ea") if r.call(3) > 0.3 else Color("#ff9ec7"))
	var yellow := Color("#ffd23f")
	var shade := Color("#e0a800")
	for i in 60:
		var t := i / 59.0
		var a := lerpf(PI * 1.15, PI * 1.85, t)
		var cx := 24.0 + cos(a) * 18.0
		var cy := 6.0 - sin(a) * 18.0
		var thick := 2.0 + sin(t * PI) * 3.5
		for k in int(thick * 2):
			var y := int(cy - thick + k)
			img.set_pixel(clampi(int(cx), 0, 47), clampi(y, 0, 35), shade if k < 2 else yellow)
		img.set_pixel(clampi(int(cx), 0, 47), clampi(int(cy + thick), 0, 35), Color("#1a1a1a"))
	img.fill_rect(Rect2i(4, 12, 3, 3), Color("#5a3a1a"))
	img.fill_rect(Rect2i(41, 12, 3, 2), Color("#5a3a1a"))
	img.fill_rect(Rect2i(34, 31, 10, 1), Color("#1a1a1a"))


## An ice cream: a crosshatched cone, three scoops and a cherry.
static func _ice_cream(img: Image, r: Callable) -> void:
	img.fill(Color("#a8e0f0") if r.call(4) > 0.5 else Color("#ffd6e8"))
	var cone := Color("#d9954a")
	for y in range(18, 34):
		var half := int((34 - y) * 0.45)
		img.fill_rect(Rect2i(24 - half, y, half * 2 + 1, 1), cone)
		for x in range(24 - half, 25 + half):
			if (x + y) % 4 == 0 or (x - y) % 4 == 0:
				img.set_pixel(x, y, Color("#a8662a"))
	var scoops := [Color("#ff8ab5"), Color("#8fe0b0"), Color("#6b3a2a")]
	var at := [Vector2i(19, 16), Vector2i(29, 16), Vector2i(24, 10)]
	for k in 3:
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				if dx * dx + dy * dy <= 30:
					img.set_pixel(at[k].x + dx, at[k].y + dy, (scoops[k] as Color).lightened(0.25) if dx < -2 and dy < -2 else scoops[k])
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx * dx + dy * dy <= 4:
				img.set_pixel(24 + dx, 3 + dy, Color("#d62839"))
	img.fill_rect(Rect2i(25, 0, 1, 2), Color("#3a6a2a"))


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


# --- Wall lamps -----------------------------------------------------------

## A brass wall lamp with a glowing shade on the north wall of each gallery,
## where the camera sees the wall face. The wall tile nearest the middle of
## that wall gets it, unless the room's switch or a painting is there.
func _sconces() -> void:
	var shade := StandardMaterial3D.new()
	shade.albedo_color = SCONCE_COLOUR
	shade.emission_enabled = true
	shade.emission = SCONCE_COLOUR
	shade.emission_energy_multiplier = 2.0
	var placed := 0
	for r in Museum.rooms:
		if placed >= MAX_SCONCES:
			return
		var y := r.rect.position.y - 1
		if y < 0:
			continue
		var mid := r.rect.position.x + r.rect.size.x / 2
		var best := -1
		for x in range(r.rect.position.x, r.rect.end.x):
			if Museum.grid[y * Museum.w + x] != Tiles.WALL or Museum.grid[(y + 1) * Museum.w + x] != Tiles.FLOOR:
				continue
			if absi(x - r.switch_at.x) <= 1 and absi(y - r.switch_at.y) <= 1:
				continue
			if _hung.has(Vector2i(x, y)):
				continue
			if best < 0 or absi(x - mid) < absi(best - mid):
				best = x
		if best < 0:
			continue
		var at := to_world(best + 0.5, y + 1.0, SCONCE_HEIGHT)
		_mesh(self, _box(Vector3(0.05, 0.14, 0.08)), C.gold_dim, at + Vector3(0, -0.02, 0.04), true)
		var lamp := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.1
		cyl.height = 0.12
		lamp.mesh = cyl
		lamp.material_override = shade
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lamp.position = at + Vector3(0, 0.07, 0.12)
		add_child(lamp)
		var light := OmniLight3D.new()
		light.light_color = SCONCE_COLOUR
		light.light_energy = SCONCE_ENERGY
		light.omni_range = SCONCE_RANGE
		light.omni_attenuation = 1.2
		light.light_volumetric_fog_energy = 2.0
		light.position = at + Vector3(0, 0.05, 0.3)
		add_child(light)
		placed += 1


# --- Helpers ---------------------------------------------------------------------

static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


## One instanced mesh over a set of tiles. tint gives each its own shade of
## the colour, so a run of wall reads as panels; cap darkens the middle of
## big wall masses.
func _instances(mesh: Mesh, tiles: Array[Vector2i], height: float, mat: Material, tint := 0.0, cap := false, offset := Vector3.ZERO) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = tint > 0 or cap
	mm.mesh = mesh
	mm.instance_count = tiles.size()
	if mm.use_colors and mat is StandardMaterial3D:
		(mat as StandardMaterial3D).vertex_color_use_as_albedo = true
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
static func _hash01(x: int, y: int, salt := 41) -> float:
	return fposmod(absf(sin(x * 31.7 + y * 17.3 + salt * 7.13)), 1.0)


## One toon-shaded piece; detail pieces cast no shadow.
func _mesh(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, detail := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = _toon_cached(colour)
	m.position = at
	if detail:
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	return m


var _mats := {}


func _toon_cached(colour: Color) -> StandardMaterial3D:
	var key := colour.to_html()
	if not _mats.has(key):
		_mats[key] = toon(colour)
	return _mats[key]


func _pivot(parent: Node3D, at: Vector3, yaw := 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.rotation.y = yaw
	parent.add_child(n)
	return n
