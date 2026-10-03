class_name ArcadeAppearance
extends RefCounted
## Aspecto compartido de las recreativas del museo y la casa.
## Crea materiales y pantallas una vez por juego y los conserva en caché.
## No cambia las reglas de la máquina ni añade trabajo por fotograma.

const GAMES := {
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
const LEGACY_MATERIAL_NAMES := {"morado": "color_mueble", "morado_oscuro": "color_mueble_oscuro_40", "cartel": "color_marquesina"}


## Dress an arcade machine (asset(Arcades.MODEL)) as one of its games
## (GAMES), cheaper than a model per game. As with the pieces to steal
## (LootModels), the materials whose name starts with "color" take the
## game's colours: "color_mueble" the cabinet's, "color_marquesina" the
## marquee's, and a "_claro_N" or "_oscuro_N" after it N % lighter or
## darker; the rest (the screen, the black, the metal) keep their own. And on
## the screen (the material whose name starts with "pantalla"), the game's
## picture.
static func apply(model: Node3D, game: String) -> void:
	var look: Dictionary = GAMES[game]
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var screen := false
		for s in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(s)
			if src == null:
				continue
			var name: String = LEGACY_MATERIAL_NAMES.get(src.resource_name, src.resource_name)
			# The table tennis the model has painted on its screen: each game
			# draws its own picture over the glass instead.
			if name == "pantalla_dibujo":
				mi.visible = false
				continue
			screen = screen or name == "pantalla"
			var c := _material_colour(look, name)
			if c.a == 0.0:
				continue
			var key := "%s/%s" % [game, src.resource_name]
			if not _materials.has(key):
				var m := mi.get_active_material(s).duplicate() as BaseMaterial3D
				m.albedo_color = c
				if m.emission_enabled:
					m.emission = c
				_materials[key] = m
			mi.set_surface_override_material(s, _materials[key])
		if screen:
			_add_screen_picture(mi, game)


## The game's colour for a material named "color_<part>[_claro|_oscuro_N]",
## or none (transparent) for any other.
static func _material_colour(look: Dictionary, name: String) -> Color:
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
static func _add_screen_picture(mi: MeshInstance3D, game: String) -> void:
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
	picture.material_override = _picture_material(game)
	picture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	picture.basis = Basis(Vector3.RIGHT, normal.cross(Vector3.RIGHT), normal)
	picture.position = centre + normal * 0.003
	mi.add_child(picture)


static var _materials := {}


## A game's picture, lit from within: its pixels, sharp.
static func _picture_material(game: String) -> StandardMaterial3D:
	var key := "%s/picture" % game
	if _materials.has(key):
		return _materials[key]
	var look: Dictionary = GAMES[game]
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
	_materials[key] = m
	return m


