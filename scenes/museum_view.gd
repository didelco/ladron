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
	_map_doors_build()
	_map_columns_build()


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
				if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					_glass(m)
				_asset_mats[src] = m
			mi.set_surface_override_material(s, _asset_mats[src])
			if src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static var _asset_mats := {}


## How much light the glass catches along its edges (the rim), and how
## rough it is: the roughness is what keeps the rim to the edges (at 1 it
## would spread over the whole pane).
const GLASS_RIM := 0.45
const GLASS_ROUGH := 0.5

## The sheen over the glass (_glass_sheen): how much of a light passing by
## it catches where you look along a pane, and the faint glint it keeps in
## the dark.
const GLASS_SHEEN := 1.0
const GLASS_SHEEN_DARK := 0.15

static var _sheen: ShaderMaterial


## Glass (the cases': the only see-through material in the models): a rim of
## whatever light is about where you look along the pane, tinted the glass's
## colour, so a case reads as glass and not as an empty frame. The pane is
## nearly clear, and a rim on it would be nearly clear too: the fresnel that
## shows is a pass of its own over it (_glass_sheen).
static func _glass(m: BaseMaterial3D) -> void:
	m.rim_enabled = true
	m.rim = GLASS_RIM
	m.rim_tint = 0.3
	m.roughness = GLASS_ROUGH
	if _sheen == null:
		_sheen = ShaderMaterial.new()
		_sheen.shader = _glass_sheen()
		_sheen.set_shader_parameter("tint", C.glass)
		_sheen.set_shader_parameter("strength", GLASS_SHEEN)
		_sheen.set_shader_parameter("dark", GLASS_SHEEN_DARK)
	m.next_pass = _sheen


## A fresnel added over the glass: nothing on a pane seen face on (the lids,
## from the camera up high), more the more you look along it (the fronts and
## sides). Lit by the lights that reach it, so a torch sweeping past sets the
## panes glinting; and a faint glint of its own, so a case in the dark still
## reads as glass.
static func _glass_sheen() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, specular_disabled, ambient_light_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.66, 0.85, 0.91);
uniform float strength = 1.0;
uniform float dark = 0.15;

void fragment() {
	float edge = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.5);
	ALBEDO = tint * edge;
	EMISSION = tint * edge * dark;
}

void light() {
	// However the light falls on it: glass catches it all along the pane.
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * strength / PI;
}
"""
	return sh


## The arcade machines' games (Themes.VARIANTS), one look each, in the modern
## age's pop colours: the cabinet ("mueble"), the marquee and its stripes
## ("marquesina", with the lid, what the camera sees most), the screen, and
## what is on it, in pixels ("." is the screen, a letter one of its inks).
## You play pong on every one of them all the same (Arcades).
## Catálogo público conservado para los consumidores existentes.
const ARCADE_GAMES := ArcadeAppearance.GAMES


## Aplica el aspecto compartido; las reglas jugables siguen en Arcades.
static func arcade_game(model: Node3D, game: String) -> void:
	ArcadeAppearance.apply(model, game)


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
			# A challenge's own door (Museum.doors) never gets a solid mass
			# here, whatever it is shut or open right now: the gap is real,
			# always, and a leaf of its own fills it (_map_doors_build), the
			# way Den's are never a wall in its plan either. Nor does a
			# column (Museum.columns): it stands on its own, slender, drawn
			# by _map_columns_build.
			if Museum.grid[y * Museum.w + x] != Tiles.WALL or Museum.is_outside(x, y) \
					or Museum.doors.has(Vector2i(x, y)) or Museum.columns.has(Vector2i(x, y)):
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
			# What the gallery's theme shows (a corridor, a bit of everything,
			# unless the whole museum keeps to one: Museum.only_theme), as the
			# museum's collection has it (Collection).
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
	var theme: String = room.theme if room else (Museum.only_theme if on_plan else "")
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
	var own: String = room.theme if room and room.theme != "" else (Museum.only_theme if on_plan else "")
	var theme: String = own if own != "" else ids[int(_hash01(t.x, t.y, 41) * ids.size()) % ids.size()]
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
	if not Museum.paintings.is_empty():
		# Hung by hand in the editor (MapFile.paintings): exactly those, no
		# automatic ones on top. Still checked against the wall as it is now
		# (blocked, span, a column) in case it changed since they were placed.
		var blocked := _blocked()
		for entry in Museum.paintings:
			var at: Vector2i = entry.at
			var span: int = entry.span
			if not _hung.has(at) and _free_wall(at.x, at.y, blocked) >= span:
				_hang_painting(at.x, at.y, span)
				for k in span:
					_hung[Vector2i(at.x + k, at.y)] = true
		return
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
			var pick := _hash01(x, y, 41)
			var span := 3 if pick < 0.1 and run >= 3 else (2 if pick < 0.28 and run >= 2 else 1)
			if span == 1 and pick < 0.46:
				var room := Museum.room_at(x + 0.5, y + 1.5)
				var theme := room.theme if room else Museum.only_theme
				var seed := x * 31 + y * 7
				var frame := Node3D.new()
				frame.position = to_world(x + span / 2.0, y + 1.0, 0.0)
				add_child(frame)
				# Two small ones, or three, side by side on the one module.
				var n := 2 if pick < 0.38 else 3
				var size: Vector3 = SMALL_PAINTINGS[n]
				for i in n:
					var at := _pivot(frame, Vector3((i - (n - 1) / 2.0) * size.x * 1.25, 0, 0))
					_painting(at, seed + i * 13, Themes.painting(theme, _hash01(x + i, y, 37)), size)
			else:
				_hang_painting(x, y, span)
			for k in span:
				_hung[Vector2i(x + k, y)] = true
			hung += span
			x += span + 1


## One painting (or a triptych/big one) at wall tile (x, y), span modules
## wide: its theme's own kind, picked the same way whether it was hung here
## by the automatic sweep or by hand in the editor.
func _hang_painting(x: int, y: int, span: int) -> void:
	var room := Museum.room_at(x + 0.5, y + 1.5)
	var theme := room.theme if room else Museum.only_theme
	var frame := Node3D.new()
	frame.position = to_world(x + span / 2.0, y + 1.0, 0.0)
	add_child(frame)
	var seed := x * 31 + y * 7
	var kind := Themes.painting(theme, _hash01(x, y, 37))
	if span == 3:
		_painting(frame, seed, kind, TRIPTYCH)
	elif span == 2:
		_painting(frame, seed, kind, BIG_PAINTING)
	else:
		_painting(frame, seed, kind)


## Paintings (m): width, height, and the height of their middle on the wall.
## The height is picked so each canvas — fw - edge by fh - edge (divided
## among panels for BIG_PAINTING and TRIPTYCH), _painting's actual quad, not
## the frame's own outer size — comes out true 4:3, so one drawn canvas
## (Canvases, 4:3) fits any of these with no stretch: the frame's edge eats
## a different share at each size. Sized to fill most of the wall module(s)
## they hang on (a museum's paintings should have presence), leaving just
## enough margin to clear the module edge, the ceiling (WALL_HEIGHT) and a
## neighbouring hung tile.
const PAINTING := Vector3(0.85, 0.66, 0.76)
## Two canvases in one frame, across two modules — a small diptych, not one
## overwide canvas, so it keeps its 4:3 panels instead of stretching.
const BIG_PAINTING := Vector3(1.75, 0.7, 0.74)
## Three canvases in one long frame, across three modules; each panel comes
## out 4:3 from this size (see _painting: cw, fh - edge).
const TRIPTYCH := Vector3(2.92, 0.78, 0.73)
## Two or three small ones on one module.
const SMALL_PAINTINGS := {2: Vector3(0.4, 0.316, 0.82), 3: Vector3(0.26, 0.205, 0.84)}


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
				Museum.room_at(t.x + 0.5, y + 1.5) != room or Museum.columns.has(t):
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
	var panels := 3 if size == TRIPTYCH else (2 if size == BIG_PAINTING else 1)
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


## Fachada para los cuadros clásicos; el generador vive junto a sus variantes.
static func _canvas(seed: int, forced := -1) -> Texture2D:
	return PaintingCanvas.texture(seed, forced)


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
		# An alarm beacon beside it (the first MAX_BEACONS), dark till the
		# alarm rings (set_alarm).
		if _beacons.size() < MAX_BEACONS:
			_beacon(to_world(s.x + 0.5, s.y + 0.5, BEACON_HEIGHT))


# --- The alarm's beacons (NightAlert) ---------------------------------------------

## Red lights turning on the corridor round the museum while the alarm
## rings, like the dojo's alarm but turning: a red dome, a red glow round it
## that throbs, and a red beam sweeping the floor. Few and shadowless.
const MAX_BEACONS := 6
const BEACON_HEIGHT := 1.7
const BEACON_COLOUR := Color("#ff2a1f")
const BEACON_ENERGY := 16.0
const BEACON_GLOW := 2.5
## turns a second, and how long it takes to come on or go off
const BEACON_TURNS := 0.9
const BEACON_FADE_S := 0.3

## each beacon's pivot (turning), its beam, its glow, and the domes' shine
var _beacons: Array[Node3D] = []
var _beacon_beams: Array[SpotLight3D] = []
var _beacon_glows: Array[OmniLight3D] = []
var _beacon_clock := 0.0
var _beacon_dome: StandardMaterial3D
## 0..1 how lit the beacons are, and where that is going
var _alarm_lit := 0.0
var _alarm_goal := 0.0


func _beacon(at: Vector3) -> void:
	if _beacon_dome == null:
		_beacon_dome = StandardMaterial3D.new()
		_beacon_dome.albedo_color = BEACON_COLOUR.darkened(0.6)
		_beacon_dome.emission_enabled = true
		_beacon_dome.emission = BEACON_COLOUR
		_beacon_dome.emission_energy_multiplier = 0.0
	var pivot := Node3D.new()
	pivot.position = at
	pivot.visible = false
	add_child(pivot)
	var dome := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.2
	s.height = 0.26
	dome.mesh = s
	dome.material_override = _beacon_dome
	dome.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(dome)
	var beam := SpotLight3D.new()
	beam.light_color = BEACON_COLOUR
	beam.light_energy = 0.0
	beam.spot_range = 8.0
	beam.spot_angle = 32.0
	beam.shadow_enabled = false
	beam.light_volumetric_fog_energy = 2.0
	# Out and down, so its pool sweeps round the floor as it turns.
	beam.rotation = Vector3(-0.6, 0.0, 0.0)
	pivot.add_child(beam)
	var glow := OmniLight3D.new()
	glow.light_color = BEACON_COLOUR
	glow.light_energy = 0.0
	glow.omni_range = 3.5
	glow.shadow_enabled = false
	glow.position = at + Vector3(0, 0.3, 0)
	glow.visible = false
	add_child(glow)
	_beacons.append(pivot)
	_beacon_beams.append(beam)
	_beacon_glows.append(glow)


## The alarm ringing (on) or not: the beacons come on and turn, or go dark.
func set_alarm(on: bool) -> void:
	_alarm_goal = 1.0 if on else 0.0


## How lit the beacons are now (0..1), for the tests.
func alarm_level() -> float:
	return _alarm_lit


func _pose_beacons(dt: float) -> void:
	if _beacons.is_empty() or (_alarm_lit == 0.0 and _alarm_goal == 0.0):
		return
	_alarm_lit = move_toward(_alarm_lit, _alarm_goal, dt / BEACON_FADE_S)
	_beacon_clock += dt
	var on := _alarm_lit > 0.001
	var throb := 0.6 + 0.4 * sin(_beacon_clock * TAU * BEACON_TURNS * 2.0)
	_beacon_dome.emission_energy_multiplier = 6.0 * _alarm_lit
	for i in _beacons.size():
		var pivot := _beacons[i]
		pivot.visible = on
		# Not all in step: each starts a little round from the last.
		pivot.rotation.y = wrapf(pivot.rotation.y + dt * TAU * BEACON_TURNS, -PI, PI) if on else i * 1.3
		_beacon_beams[i].light_energy = BEACON_ENERGY * _alarm_lit
		_beacon_glows[i].visible = on
		_beacon_glows[i].light_energy = BEACON_GLOW * _alarm_lit * throb


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


# --- A challenge's own doors (Museum.doors), like Den's but one tile wide ---------

## Its own leaf for every door the map has: a plain wood panel, closed by
## default, that slides its own width into the wall it sits in when opened
## (Den._doors does the same, two leaves to a wider gap; ours is always one
## tile, so one leaf is enough). DenView never calls this: it draws its own
## doors (Den.DOORS) its own way, over a plan built with every doorway open.
var _map_door_nodes := {}

func _map_doors_build() -> void:
	for t in Museum.doors:
		var horizontal := _wall_like(t + Vector2i(-1, 0)) and _wall_like(t + Vector2i(1, 0))
		var root := _pivot(self, to_world(t.x + 0.5, t.y + 0.5), 0.0 if horizontal else PI / 2.0)
		var leaf := Node3D.new()
		root.add_child(leaf)
		_mesh(leaf, _box(Vector3(0.94, WALL_HEIGHT * 0.88, 0.12)), Color("#7a4a28"), Vector3(0, WALL_HEIGHT * 0.44, 0))
		_mesh(leaf, _box(Vector3(0.74, WALL_HEIGHT * 0.62, 0.14)), Color("#b98552"), Vector3(0, WALL_HEIGHT * 0.44, 0))
		_mesh(leaf, _box(Vector3(0.06, 0.06, 0.16)), Color("#f0c46a"), Vector3(0.32, WALL_HEIGHT * 0.44, 0))
		_map_door_nodes[t] = {"leaf": leaf, "open": 0.0, "goal": 0.0}
		set_map_door(t, Museum.is_door_open(t), true)


## A real wall (not another door) at this tile, for working out which way a
## door's leaf should slide.
func _wall_like(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < Museum.w and t.y < Museum.h \
		and Museum.grid[t.y * Museum.w + t.x] == Tiles.WALL and not Museum.doors.has(t)


## Open or shut a challenge's own door as drawn: swinging, or at once (snap).
func set_map_door(t: Vector2i, open: bool, snap := false) -> void:
	if not _map_door_nodes.has(t):
		return
	var d: Dictionary = _map_door_nodes[t]
	d.goal = 1.0 if open else 0.0
	if snap:
		d.open = d.goal
		_pose_map_door(d)


func _pose_map_door(d: Dictionary) -> void:
	var k: float = d.open
	k = k * k * (3.0 - 2.0 * k)
	(d.leaf as Node3D).position.x = k


## Only a plain MuseumView ticks its own doors: DenView overrides this for
## its own (Den.DOOR_SECONDS) and never calls up to it.
func _process(dt: float) -> void:
	_pose_beacons(dt)
	for t in _map_door_nodes:
		var d: Dictionary = _map_door_nodes[t]
		if d.open != d.goal:
			d.open = move_toward(d.open, d.goal, dt / Den.DOOR_SECONDS)
			_pose_map_door(d)


# --- Exempt columns (Museum.columns, MapFile.columns) ----------------------------

## A column stands exempt: not part of the wall it is marked on, its own
## shape in the middle of the tile with the corners free — structure, so as
## stout and as tall as the wall round it (shaft 0.8 of a tile across, base
## and capital nearly the whole tile, capital level with the wall caps), and
## meant for a gallery's own rows of them rather than for splitting up a
## room the way a wall does.
##
## One logical piece, four looks (COLUMN_*): which one a tile gets follows
## its gallery's theme (Themes.column_style), the same way a pedestal does
## (_pedestal) — never chosen tile by tile.
##
## Collision is the real thing now: the tile is still a plain wall in
## Museum.grid (load_grid keeps it so, for anything that only asks "is this
## a wall" — sight lines aside, see below), but Museum.blocks_move no longer
## treats a column tile as a solid square; Sim._resolve instead pushes
## bodies out of a small circle at the column's centre (Museum.COLUMN_R), so
## a thief or guard can hug the tile's free corners and walk round it. Sight
## gets the same narrow treatment: Museum.has_line_of_sight only lets a
## column cut a look that actually passes within that circle, not the whole
## tile — a glance past its edge is not blocked. See
## docs/pendiente_general.md for what is still left (other, simpler
## "is this a wall" checks — a thrown case's flight, the exit's outward
## side, a guard's plain wall memory — keep treating a column tile as solid
## end to end; narrowing all of those wasn't worth it for this pass).
var _map_column_nodes := {}


func _map_columns_build() -> void:
	for t in Museum.columns:
		var on_plan := t.x < Museum.w and t.y < Museum.h and Museum.grid.size() == Museum.w * Museum.h
		var room := Museum.room_at(t.x + 0.5, t.y + 0.5) if on_plan else null
		var gallery_theme: String = room.theme if room and room.theme != "" else Museum.only_theme
		# Straight, not spun: a random yaw only reads as "the columns are
		# fine on a plain drum, but "dorica"'s square plinth and abacus went
		# diagonal to the room. Every column now sits aligned to the grid.
		var root := _pivot(self, to_world(t.x + 0.5, t.y + 0.5), 0.0)
		_column(root, Themes.column_style(gallery_theme))
		_map_column_nodes[t] = root


## The looks (Themes.COLUMN_STYLES, plus "moderno"/anything else's fallback),
## each a base, a shaft and a capital. The shaft is the collision circle
## (Museum.COLUMN_R); base and capital spread to COLUMN_FOOT, just inside
## the tile, and the capital tops out at COLUMN_TOP, level with the cap on
## the walls (WALL_HEIGHT + CAP_H), so a column stands as high as the wall.
const COLUMN_FOOT := 0.96
const COLUMN_TOP := WALL_HEIGHT + CAP_H


func _column(parent: Node3D, style: String) -> void:
	var r := Museum.COLUMN_R
	var drum := func(r: float, h: float, r2: float, sides: int, colour: Color, y: float) -> void:
		var c := CylinderMesh.new()
		c.bottom_radius = r
		c.top_radius = r2
		c.height = h
		c.radial_segments = sides
		c.rings = 1
		_mesh(parent, c, colour, Vector3(0, y, 0))
	# A notched cylinder in place of a plain drum: alternating in-out radius
	# round the ring reads as real vertical grooves under toon shading
	# (flutes for "dorica", shallower ones as ribs for "gotica"), without a
	# shader — just more vertices, cheap at column scale.
	var fluted := func(r0: float, r1: float, h: float, flutes: int, notch: float, colour: Color, y: float) -> void:
		_mesh(parent, _fluted_shaft(r0, r1, h, flutes, notch), colour, Vector3(0, y, 0))
	match style:
		"dorica":
			# Fluted white-and-cream stone, a wide square plinth, a round
			# echinus under a square abacus (the ancient world's gallery).
			# A touch of entasis: the shaft is wider at the foot than under
			# the capital, instead of a dead-straight tube.
			var shaft_h := COLUMN_TOP - 0.3
			_mesh(parent, _box(Vector3(COLUMN_FOOT, 0.1, COLUMN_FOOT)), Color("#cbb98a"), Vector3(0, 0.05, 0))
			fluted.call(r + 0.02, r - 0.06, shaft_h, 20, 0.22, Color("#e8ddc0"), 0.1 + shaft_h / 2)
			drum.call(r - 0.04, 0.1, COLUMN_FOOT / 2, 16, Color("#cbb98a"), COLUMN_TOP - 0.15)
			_mesh(parent, _box(Vector3(COLUMN_FOOT, 0.1, COLUMN_FOOT)), Color("#cbb98a"), Vector3(0, COLUMN_TOP - 0.05, 0))
		"gotica":
			# A compound gothic pier, not a single drum: a slim central
			# shaft with a ring of slender colonnettes fused round it (a
			# cathedral's bundled pier), rising to a pointed cap. Cheap
			# geometry — a handful of thin CylinderMesh, the bundle as wide as
			# the collision circle (ring_r + col_r = r).
			var core_r := r * 0.55
			var col_r := r * 0.27
			var ring_r := r - col_r
			var cols := 6
			var shaft_h := COLUMN_TOP - 0.26
			var shaft_y := 0.12 + shaft_h / 2
			drum.call(COLUMN_FOOT / 2, 0.12, r + 0.04, 8, Color("#55505c"), 0.06)
			drum.call(core_r, shaft_h, core_r, 10, Color("#807a86"), shaft_y)
			for i in cols:
				var a := TAU * i / cols
				var c := CylinderMesh.new()
				c.bottom_radius = col_r
				c.top_radius = col_r
				c.height = shaft_h
				c.radial_segments = 8
				c.rings = 1
				_mesh(parent, c, Color("#948e99"), Vector3(cos(a) * ring_r, shaft_y, sin(a) * ring_r))
			drum.call(r + 0.02, 0.14, COLUMN_FOOT / 2, 8, Color("#55505c"), COLUMN_TOP - 0.07)
		"madera":
			# A round wooden post, bark-dark at the ends (nature's gallery,
			# and the band's house, Den, if it ever stands one).
			var shaft_h := COLUMN_TOP - 0.26
			drum.call(COLUMN_FOOT / 2, 0.14, r + 0.04, 12, Color("#4a3018"), 0.07)
			drum.call(r - 0.02, shaft_h, r, 12, Color("#7a5230"), 0.14 + shaft_h / 2)
			drum.call(r + 0.04, 0.12, COLUMN_FOOT / 2, 12, Color("#4a3018"), COLUMN_TOP - 0.06)
		"piedra":
			# A rough-squared megalith, in prehistory's own ochre-and-flint
			# browns (Themes.ALL.prehistoria) — three uneven stone blocks
			# stacked square, not a smooth drum: it belongs by the mammoth
			# and the dinosaur, not next to a modern gallery's bare
			# concrete tube. A slight side-to-side offset between blocks
			# (not perfectly stacked) reads as roughly hewn, not milled.
			var seg := (COLUMN_TOP - 0.3) / 2.0
			var d := r * 2
			_mesh(parent, _box(Vector3(COLUMN_FOOT, 0.1, COLUMN_FOOT)), Color("#5a4530"), Vector3(0, 0.05, 0))
			_mesh(parent, _box(Vector3(d - 0.04, seg, d)), Color("#a37f52"), Vector3(0.02, 0.1 + seg / 2, -0.02))
			_mesh(parent, _box(Vector3(d - 0.1, 0.04, d - 0.06)), Color("#5a4530"), Vector3(0, 0.1 + seg + 0.02, 0))
			_mesh(parent, _box(Vector3(d - 0.08, seg, d - 0.14)), Color("#c39a63"), Vector3(-0.02, 0.14 + seg + seg / 2, 0.02))
			_mesh(parent, _box(Vector3(COLUMN_FOOT - 0.1, 0.12, COLUMN_FOOT - 0.06)), Color("#5a4530"), Vector3(0, COLUMN_TOP - 0.06, 0))
		"moderno":
			# A bare concrete cylinder, nothing added: no plinth, no
			# capital, just a smooth pale-grey tube top to bottom, the way
			# a raw-concrete building (Ando-style) stands its columns bare
			# next to the glass (the corridors, prehistory and the modern
			# age's gallery, which have no style of their own to speak of).
			drum.call(r, COLUMN_TOP, r, 20, Color("#d8d5cc"), COLUMN_TOP / 2)
		_:
			# Fallback for an unknown style name: the same bare concrete
			# tube as "moderno" (Themes.column_style never returns anything
			# else today, but a column always has to look like something).
			drum.call(r, COLUMN_TOP, r, 20, Color("#d8d5cc"), COLUMN_TOP / 2)


## A cylinder-like shaft with a notched cross-section: flutes points round
## the ring, alternating a full radius and radius * (1 - notch), extruded
## from y = -h/2 to y = h/2 (same "centred, pass the centre's y" convention
## every other piece here uses) with the top scaled to r1 and the bottom to
## r0, so a taper (entasis) falls out for free when r0 != r1. Flat-shaded
## (generate_normals off a triangle soup, not per-vertex smoothed) so the
## grooves actually read as grooves under toon shading, not smear away.
static func _fluted_shaft(r0: float, r1: float, h: float, flutes: int, notch: float) -> ArrayMesh:
	var n := maxi(3, flutes) * 2
	var bottom: Array[Vector3] = []
	var top: Array[Vector3] = []
	for i in n:
		var a := TAU * i / n
		var k := 1.0 if i % 2 == 0 else (1.0 - notch)
		bottom.append(Vector3(cos(a) * r0 * k, -h / 2, sin(a) * r0 * k))
		top.append(Vector3(cos(a) * r1 * k, h / 2, sin(a) * r1 * k))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(bottom[i])
		st.add_vertex(bottom[j])
		st.add_vertex(top[j])
		st.add_vertex(bottom[i])
		st.add_vertex(top[j])
		st.add_vertex(top[i])
	var bc := Vector3(0, -h / 2, 0)
	var tc := Vector3(0, h / 2, 0)
	for i in n:
		var j := (i + 1) % n
		st.add_vertex(bc)
		st.add_vertex(bottom[j])
		st.add_vertex(bottom[i])
		st.add_vertex(tc)
		st.add_vertex(top[i])
		st.add_vertex(top[j])
	st.generate_normals()
	return st.commit()


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
