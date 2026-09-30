extends Node3D
## A window to look at what the game builds by code instead of modelling in
## Blender: museums (by theme), wild trees, rocks and the pixel-art
## paintings — one at a time, orbiting it, to work on the functions that
## make them (scenes/museum_building.gd, scenes/town_builder.gd,
## scenes/canvases.gd) without playing the whole game.
##
##   godot --path . tools/asset_lab.tscn
##
## [ / ] previous/next category. , / . previous/next item. R rerolls the
## seed (rocks and paintings change look; trees and museums mostly don't,
## they are closer to fixed). Right mouse button drags to orbit, wheel to
## zoom. Edit the code, quit (Esc) and relaunch to see the change — no
## live reload, just a fast turnaround.

const CATEGORIES := [
	{"name": "museo", "kind": "3d", "items": ["prehistoria", "antiguo", "edad_media", "naturaleza", "moderna"]},
	{"name": "arbol", "kind": "3d", "items": ["pine", "oak", "birch", "poplar", "autumn", "bush", "bloom"]},
	{"name": "roca", "kind": "3d", "items": ["roca"]},
	{"name": "seto", "kind": "3d", "items": ["hedge"]},
	{"name": "cuadro", "kind": "tex", "items": ["landscape", "portrait", "abstract", "pipe", "banana", "ice_cream",
		"pyramids", "hieroglyphs", "nile", "castle", "dragon", "tapestry", "gioconda", "vitruvian"]},
]

var _cat_i := 0
var _item_i := 0
var _seed := 1
var _shown: Node3D
var _cam: Camera3D
var _label: Label
var _yaw := -0.6
var _pitch := 0.4
var _dist := 4.0
var _dragging := false


func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#14121c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#3a3550")
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("#cfd6ff")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("#2a2735")
	ground.material_override = gm
	add_child(ground)

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true

	var canvas := CanvasLayer.new()
	add_child(canvas)
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 22)
	canvas.add_child(_label)

	_rebuild()


func _category() -> Dictionary:
	return CATEGORIES[_cat_i]


func _item() -> String:
	return String(_category().items[_item_i])


func _rebuild() -> void:
	if _shown:
		_shown.queue_free()
		_shown = null
	var cat: String = _category().name
	var item := _item()
	match cat:
		"museo":
			var body := MuseumBuilding.new()
			var idx := 0
			for i in Story.MUSEUMS.size():
				if String(Story.MUSEUMS[i].theme) == item:
					idx = i
					break
			body.build(idx, true)
			_shown = body
			_dist = 9.0
		"arbol", "seto":
			var tb := TownBuilder.new(self)
			tb._rng.seed = _seed
			var mesh: ArrayMesh = tb._plant_mesh(item)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			mi.material_override = m
			_shown = mi
			_dist = 4.0 if cat == "arbol" else 2.4
		"roca":
			var tb := TownBuilder.new(self)
			var mesh: ArrayMesh = tb._rock_mesh(_seed)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			m.albedo_color = Color(0.62, 0.6, 0.58)
			mi.material_override = m
			_shown = mi
			_dist = 4.0
		"cuadro":
			var tex := Canvases.paint(item, _seed)
			var mi := MeshInstance3D.new()
			var q := QuadMesh.new()
			q.size = Vector2(1.6, 1.2)
			mi.mesh = q
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.albedo_texture = tex
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mi.material_override = m
			_shown = mi
			_dist = 2.4
	add_child(_shown)
	_label.text = "%s / %s  (%d de %d)   semilla %d\n[ ] categoría   , . pieza   R semilla nueva" % [
		cat, item, _item_i + 1, _category().items.size(), _seed]
	_update_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_BRACKETLEFT:
				_cat_i = posmod(_cat_i - 1, CATEGORIES.size())
				_item_i = 0
				_rebuild()
			KEY_BRACKETRIGHT:
				_cat_i = posmod(_cat_i + 1, CATEGORIES.size())
				_item_i = 0
				_rebuild()
			KEY_COMMA:
				_item_i = posmod(_item_i - 1, _category().items.size())
				_rebuild()
			KEY_PERIOD:
				_item_i = posmod(_item_i + 1, _category().items.size())
				_rebuild()
			KEY_R:
				_seed = randi()
				_rebuild()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(0.6, _dist - 0.3)
			_update_camera()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(40.0, _dist + 0.3)
			_update_camera()
	if event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * 0.006
		_pitch = clampf(_pitch - event.relative.y * 0.006, -1.3, 1.3)
		_update_camera()


func _update_camera() -> void:
	var look_y := 1.0
	if _shown is MuseumBuilding:
		look_y = _shown.look_y
	elif _category().name == "cuadro":
		look_y = 0.0
	var look := Vector3(0, look_y, 0)
	var offset := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.position = look + offset
	_cam.look_at(look, Vector3.UP)
