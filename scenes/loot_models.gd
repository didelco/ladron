class_name LootModels
extends RefCounted
## The pieces to steal, each with a little character: the grandad's dentures
## with pink gums, the opera duck in a bow tie, the yeti-style striped
## sock, the toast with the Barón's burnt moustache, the pickle queen's
## crown, the cheese meteorite, the record ball of chewing gum, the octopus
## wrestler's mask, the alarm clock that runs backwards, the dinosaur egg in
## its nest, a brilliant-cut diamond, the obsidian idol, and the squeeze
## bottle of ketchup so long in the fridge that it has frost on its
## shoulders, mould on its label and a crust on its nozzle. And the ones
## that fit their museum (docs/propuesta_trofeos.md): a gnawed bone, a
## carnivorous plant, a snail, an amethyst, a souvenir amphora, a neon laurel
## wreath, an inflatable Doric column, a David in an apron, a Venus in
## sunglasses, the sword in the stone, Leonardo's ornithopter, a taped
## banana and a mop bucket.
##
## They are modelled in Blender (art/botin.blend, one collection a piece) and
## come out as assets/models/botin/<name>.glb. The materials whose name
## starts with "color" follow the piece's colour: "color" is the colour
## itself, "color_claro_N" and "color_oscuro_N" N % lighter or darker (and
## a last "_NN" is its opacity). Everything glows a touch, so it reads in
## the dark museum: each material's emission, from Blender, relative to its
## colour.
##
## About 0.35 units across, standing on its origin's floor, to turn above
## its case or on the briefing's stand.

## The shapes, and the name of each piece in the catalogue.
const NAMES := {"teeth": "dentadura", "duck": "pato", "sock": "calcetin", "toast": "tostada", "crown": "corona",
	"rock": "queso_lunar", "gum": "chicle", "mask": "mascara", "clock": "despertador", "egg": "huevo",
	"gem": "diamante", "idol": "idolo", "ketchup": "ketchup",
	"bone": "hueso", "plant": "planta", "snail": "caracol", "crystal": "amatista", "amphora": "anfora_souvenir",
	"laurel": "laurel", "column": "columna", "david": "david", "venus": "venus", "sword": "espada",
	"ornithopter": "ornitoptero", "banana": "platano", "bucket": "cubo"}
## The shapes this builds; anything else gets the gem.
const SHAPES := ["teeth", "duck", "sock", "toast", "crown", "rock", "gum", "mask", "clock", "egg", "gem", "idol", "ketchup",
	"bone", "plant", "snail", "crystal", "amphora", "laurel", "column", "david", "venus", "sword", "ornithopter", "banana", "bucket"]


static func build(shape: String, colour: Color) -> Node3D:
	var scene: PackedScene = load("res://assets/models/botin/%s.glb" % NAMES.get(shape, "diamante"))
	var root: Node3D = scene.instantiate()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s) as BaseMaterial3D
			if src != null:
				mi.set_surface_override_material(s, _material(src, colour))
	return root


## The piece's material: its own colour, or the piece's if it follows it;
## lit a little from within, and a rim so it stands out.
static func _material(src: BaseMaterial3D, colour: Color) -> BaseMaterial3D:
	var key := [src, colour]
	if _cache.has(key):
		return _cache[key]
	var m := src.duplicate() as BaseMaterial3D
	var own := src.albedo_color
	var glow := 0.0
	if src.emission_enabled:
		glow = src.emission.get_luminance() * src.emission_energy_multiplier / maxf(own.get_luminance(), 0.01)
	var bits := src.resource_name.split("_")
	if bits[0] == "color":
		var c := colour
		if bits.size() >= 3 and bits[1] == "claro":
			c = c.lightened(int(bits[2]) / 100.0)
		elif bits.size() >= 3 and bits[1] == "oscuro":
			c = c.darkened(int(bits[2]) / 100.0)
		c.a = own.a
		m.albedo_color = c
		own = c
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = Color(own, 1.0)
		m.emission_energy_multiplier = glow
	m.rim_enabled = true
	m.rim = 0.3
	_cache[key] = m
	return m


static var _cache := {}


## The thief's sack: whatever was stolen goes in it and out of sight, so it
## looks the same whatever the piece. Burlap, bulging at the bottom, its
## neck tied with a cord and a tuft sticking out, a patch sewn on the side.
## About 0.45 across, standing on its origin's floor.
static func sack() -> Node3D:
	var root := Node3D.new()
	var m := LootModels.new()
	m._root = root
	m._sack()
	return root


var _root: Node3D
var _colour: Color
var _materials := {}


func _sack() -> void:
	var burlap := Color("#a8804f")
	var cord := Color("#5a3a22")
	# The bulk, full and heavy at the bottom.
	_part(_root, _sphere(0.22, 0.4), burlap, Vector3(0, 0.2, 0), Vector3.ZERO, 0.95, 0.08).scale = Vector3(1.0, 1.0, 0.85)
	# Tapering to the neck, tied, and the tuft over the knot.
	_part(_root, _cylinder(0.06, 0.15, 0.14), burlap, Vector3(0, 0.42, 0), Vector3.ZERO, 0.95, 0.08)
	_part(_root, _torus(0.05, 0.08), cord, Vector3(0, 0.47, 0), Vector3.ZERO, 0.9, 0.05)
	_part(_root, _cylinder(0.1, 0.05, 0.08), burlap.lightened(0.08), Vector3(0, 0.53, 0), Vector3.ZERO, 0.95, 0.08)
	# A patch sewn on the side facing out, and a dollar sign on it.
	_part(_root, _box(Vector3(0.12, 0.12, 0.02)), burlap.darkened(0.25), Vector3(0.0, 0.2, 0.18), Vector3(0, 0, 0.15), 0.95, 0.06)
	_part(_root, _box(Vector3(0.018, 0.1, 0.012)), Color("#f4ecd8"), Vector3(0.0, 0.2, 0.195), Vector3.ZERO, 0.8, 0.4)
	_part(_root, _torus(0.02, 0.035), Color("#f4ecd8"), Vector3(0.0, 0.2, 0.195), Vector3(PI / 2, 0, 0), 0.8, 0.4).scale = Vector3(1, 1, 1.4)


# --- Parts -------------------------------------------------------------------------

## A piece of the model: one mesh, one colour, a faint glow of its own so it
## reads in the dark.
func _part(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, rot := Vector3.ZERO, rough := 0.5, glow := 0.12, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.rotation = rot
	var key := "%s|%s|%s|%s" % [colour.to_html(), rough, glow, metal]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = rough
		m.metallic = metal
		if colour.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if glow > 0.0:
			m.emission_enabled = true
			m.emission = colour
			m.emission_energy_multiplier = glow
		m.rim_enabled = true
		m.rim = 0.3
		_materials[key] = m
	mi.material_override = _materials[key]
	parent.add_child(mi)
	return mi


func _sphere(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = 24
	s.rings = 12
	return s


func _cylinder(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 24
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 10
	return t
