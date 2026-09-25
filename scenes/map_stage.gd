class_name MapStage
extends SubViewport
## The map you take out mid-job, as a thing: a sheet of old paper folded in
## an accordion (four panels across, a crease along the middle), lit by a
## warm lamp so every fold catches the light on one side and falls into
## shade on the other. It unfolds as it comes out, breathes a little as if
## held in two hands, and leans towards wherever you push the controls.
##
## The paper is parchment drawn once (stains, a double rule, a compass rose)
## with the museum's plan printed on it, redrawn as the thieves move.

const SIZE := Vector2i(960, 640)
## Panels across and down: the folds are the lines between them.
const COLUMNS := 4
const ROWS := 2
## How deep the folds stay once the map is open, and when it is shut.
const OPEN_FOLD := 0.13
const SHUT_FOLD := 0.55
const MARGIN := 44

var _paper: MeshInstance3D
var _material: StandardMaterial3D
var _holder: Node3D
var _fold := SHUT_FOLD
var _aspect := 1.5
var _lean := Vector2.ZERO
var _push := Vector2.ZERO
var _t := 0.0
var _base: Image


func _init() -> void:
	size = SIZE
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#8a7aa8")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The lamp from the upper left: the folds facing it glow, the others sink.
	var lamp := DirectionalLight3D.new()
	lamp.rotation_degrees = Vector3(-28, -62, 0)
	lamp.light_color = Color("#ffd9a0")
	lamp.light_energy = 1.25
	lamp.shadow_enabled = true
	add_child(lamp)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-20, 150, 0)
	moon.light_color = Color("#8f9cff")
	moon.light_energy = 0.3
	add_child(moon)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, 0.05, 5.3)
	add_child(cam)
	_holder = Node3D.new()
	add_child(_holder)
	_paper = MeshInstance3D.new()
	_material = StandardMaterial3D.new()
	_material.roughness = 0.85
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_paper.material_override = _material
	_holder.add_child(_paper)


## Out it comes: shut, then unfolding to lie open.
func unfold() -> void:
	_fold = SHUT_FOLD
	_holder.rotation = Vector3(0.5, 0, 0)
	_holder.scale = Vector3.ONE * 0.8
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "_fold", OPEN_FOLD, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_holder, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The plan to print: a new one redraws the paper (the parchment itself is
## drawn once per plan size).
func print_plan(plan: Image) -> void:
	var w := plan.get_width() + MARGIN * 2
	var h := plan.get_height() + MARGIN * 2
	if _base == null or _base.get_width() != w or _base.get_height() != h:
		_base = _parchment(w, h)
		_aspect = float(w) / h
	var sheet := _base.duplicate() as Image
	sheet.blend_rect(plan, Rect2i(Vector2i.ZERO, plan.get_size()), Vector2i(MARGIN, MARGIN))
	sheet.generate_mipmaps()
	_material.albedo_texture = ImageTexture.create_from_image(sheet)


## Which way the controls push, -1..1 each way: the map leans after it.
func push(v: Vector2) -> void:
	_push = v.limit_length(1.0)


func _process(dt: float) -> void:
	_t += dt
	_lean = _lean.lerp(_push, 1.0 - exp(-dt * 6.0))
	# Held in two hands: a slow breath, and the lean from the controls.
	_holder.rotation = _holder.rotation.lerp(Vector3(-0.12 + _lean.y * 0.14 + sin(_t * 1.1) * 0.015,
		_lean.x * 0.2 + sin(_t * 0.7) * 0.02,
		-_lean.x * 0.05 + sin(_t * 0.9) * 0.01), 1.0 - exp(-dt * 8.0))
	_holder.position = Vector3(_lean.x * 0.08, -_lean.y * 0.05 + sin(_t * 1.3) * 0.01, 0)
	_paper.mesh = _sheet_mesh(_fold)


## The folded sheet: an accordion across, a softer crease down the middle,
## each panel flat so the light picks the folds out.
func _sheet_mesh(fold: float) -> ArrayMesh:
	var w := 3.2
	var h := w / _aspect
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# The panels draw together as they fold, so the sheet keeps its size.
	var squeeze := 1.0 - fold * 0.35
	var point := func(i: int, j: int) -> Vector3:
		var u := float(i) / COLUMNS
		var v := float(j) / ROWS
		var z := (fold if i % 2 == 1 else 0.0) + (fold * 0.35 if j == 1 else 0.0)
		return Vector3((u - 0.5) * w * squeeze, (0.5 - v) * h, z - fold * 0.5)
	for i in COLUMNS:
		for j in ROWS:
			var a: Vector3 = point.call(i, j)
			var b: Vector3 = point.call(i + 1, j)
			var c: Vector3 = point.call(i + 1, j + 1)
			var d: Vector3 = point.call(i, j + 1)
			var ua := Vector2(float(i) / COLUMNS, float(j) / ROWS)
			var ub := Vector2(float(i + 1) / COLUMNS, float(j) / ROWS)
			var uc := Vector2(float(i + 1) / COLUMNS, float(j + 1) / ROWS)
			var ud := Vector2(float(i) / COLUMNS, float(j + 1) / ROWS)
			for tri in [[a, ua, b, ub, c, uc], [a, ua, c, uc, d, ud]]:
				for k in 3:
					st.set_uv(tri[k * 2 + 1])
					st.add_vertex(tri[k * 2])
	st.generate_normals()
	return st.commit()


## Old paper: warm and uneven, darker at the edges, a few stains, a double
## rule round the border and a compass rose in the corner.
static func _parchment(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.seed = 7
	var stains := FastNoiseLite.new()
	stains.frequency = 0.004
	stains.seed = 3
	var light := Color("#ecdcb8")
	var dark := Color("#c9ad7c")
	for y in h:
		for x in w:
			var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y)) / 40.0
			var c := light.lerp(dark, n * 0.45 + (1.0 - clampf(edge, 0.0, 1.0)) * 0.45)
			var s := stains.get_noise_2d(x, y)
			if s > 0.35:
				c = c.lerp(Color("#a9854f"), (s - 0.35) * 0.9)
			img.set_pixel(x, y, c)
	var ink := Color("#5a3a22")
	for inset in [12, 17]:
		var t := 3 if inset == 12 else 1
		img.fill_rect(Rect2i(inset, inset, w - inset * 2, t), ink)
		img.fill_rect(Rect2i(inset, h - inset - t, w - inset * 2, t), ink)
		img.fill_rect(Rect2i(inset, inset, t, h - inset * 2), ink)
		img.fill_rect(Rect2i(w - inset - t, inset, t, h - inset * 2), ink)
	# The compass rose, bottom right, over the margin.
	var cx := w - 30
	var cy := h - 30
	for k in 4:
		var dir := Vector2.from_angle(k * PI / 2 - PI / 2)
		for r in 14:
			var width := int((14 - r) / 4.0)
			for s2 in range(-width, width + 1):
				var p := Vector2(cx, cy) + dir * r + dir.orthogonal() * s2
				img.set_pixelv(Vector2i(p), Color("#8a2a2a") if k == 0 else ink)
	return img
