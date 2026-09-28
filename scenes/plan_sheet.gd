class_name PlanSheet
extends Node3D
## The plan of one room of a museum, as a thing in the town's 3D (CityStage):
## the paper map of MapStage (old parchment, the plan printed on it, folded
## in an accordion) at a width of one unit, to be flown about and opened.
## It lies in its own XY plane, facing +Z; fold is how shut it is, 0 flat
## to 1 folded up (each panel turned FOLD_MOST from flat).
##
## Open, it still shows how it was folded, as a paper map does on a table:
## each panel a little tilted, lit on one side and in shade on the other,
## the creases between them a dark valley or a bright ridge in turn, and
## the softer crease across the middle (PAPER_SHADER).

const COLUMNS := MapStage.COLUMNS
const ROWS := MapStage.ROWS
## How shut it comes out of the room, and how open it lies to be read: a
## crease still showing.
const SHUT := 1.0
const OPEN := 0.04
const FOLD_MOST := 80.0
## How much the open plan still shows its folds: the light across a panel,
## from its lit edge to its shaded one, and how dark a valley crease and
## how bright a ridge.
const PANEL_LIGHT := Vector2(1.08, 0.76)
const VALLEY := 0.7
const RIDGE := 0.3

const PAPER_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D paper : source_color, filter_linear_mipmap;
uniform vec3 glow = vec3(1.0);
uniform float columns = 4.0;
uniform float rows = 2.0;
uniform vec2 panel_light = vec2(1.05, 0.86);
uniform float valley = 0.55;
uniform float ridge = 0.22;
void fragment() {
	vec3 c = texture(paper, UV).rgb * COLOR.rgb * glow;
	// Across: the accordion's panels, each tilted, lit from one edge to the
	// other and every other one the other way.
	float u = UV.x * columns;
	float i = floor(u);
	float f = fract(u);
	float slope = mod(i, 2.0) < 0.5 ? f : 1.0 - f;
	float light = mix(panel_light.x, panel_light.y, smoothstep(0.0, 1.0, slope));
	// The creases: where two shaded edges meet, a valley, dark; where two lit
	// ones do, a ridge, bright with a hair of shade beside it.
	float w = fwidth(u);
	float k = floor(u + 0.5);
	float d = abs(u - k);
	float line = 1.0 - smoothstep(w * 0.6, w * 2.2, d);
	float near = 1.0 - smoothstep(w * 2.0, w * 9.0, d);
	if (k > 0.5 && k < columns - 0.5) {
		if (mod(k, 2.0) > 0.5) {
			light *= 1.0 - line * valley - near * 0.12;
		} else {
			light *= 1.0 + line * ridge;
			light *= 1.0 - (1.0 - smoothstep(w * 2.0, w * 4.0, d)) * (1.0 - line) * 0.1;
		}
	}
	// Down: the crease across the middle, softer, the lower half a touch in shade.
	float v = UV.y * rows;
	float wv = fwidth(v);
	float kv = floor(v + 0.5);
	float dv = abs(v - kv);
	if (kv > 0.5 && kv < rows - 0.5) {
		light *= 1.0 - (1.0 - smoothstep(wv * 0.6, wv * 2.0, dv)) * valley * 0.7;
		light *= 1.0 - (1.0 - smoothstep(wv * 1.5, wv * 14.0, dv)) * 0.06;
	}
	light *= 1.0 - smoothstep(0.0, 1.0, fract(v)) * 0.05;
	ALBEDO = c * light;
}
"""

var fold := SHUT:
	set(v):
		fold = v
		_dirty = true
## width is 1; this is its height
var tall := 0.66
var _paper: MeshInstance3D
var _material: ShaderMaterial
var _dirty := true
## the plan's size in pixels, and a tile's
var _sheet_px := Vector2.ONE
var _tile_px := 1.0


func _init() -> void:
	_paper = MeshInstance3D.new()
	# Unlit, so the plan keeps the colours it was printed in whatever the
	# town's lamps; the folds are shaded by hand (_mesh, PAPER_SHADER).
	_material = ShaderMaterial.new()
	_material.shader = Shader.new()
	_material.shader.code = PAPER_SHADER
	_material.set_shader_parameter("columns", float(COLUMNS))
	_material.set_shader_parameter("rows", float(ROWS))
	_material.set_shader_parameter("panel_light", PANEL_LIGHT)
	_material.set_shader_parameter("valley", VALLEY)
	_material.set_shader_parameter("ridge", RIDGE)
	_paper.material_override = _material
	_paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_paper)


## The plan to print (Hud.plan_map), a tile tile_px pixels across in it.
func print_plan(plan: Image, tile_px: float) -> void:
	var w := plan.get_width() + MapStage.MARGIN * 2
	var h := plan.get_height() + MapStage.MARGIN * 2
	var sheet := (MapStage._parchment(w, h) as Image).duplicate() as Image
	sheet.blend_rect(plan, Rect2i(Vector2i.ZERO, plan.get_size()), Vector2i(MapStage.MARGIN, MapStage.MARGIN))
	sheet.generate_mipmaps()
	_material.set_shader_parameter("paper", ImageTexture.create_from_image(sheet))
	_sheet_px = Vector2(w, h)
	_tile_px = tile_px
	tall = float(h) / w
	_dirty = true


## A glow on the paper as it comes out, 0 none.
func shine(k: float) -> void:
	_material.set_shader_parameter("glow", Vector3(1.0 + k * 0.7, 1.0 + k * 0.55, 1.0 + k * 0.3))


func _process(_dt: float) -> void:
	if _dirty:
		_dirty = false
		_paper.mesh = _mesh()


## Where a point of the museum's plan (in tiles, x across and y down) is on
## the paper, in its own units.
func tile_point(p: Vector2) -> Vector3:
	var uv := (Vector2(MapStage.MARGIN, MapStage.MARGIN) + p * _tile_px) / _sheet_px
	var squeeze := cos(deg_to_rad(fold * FOLD_MOST))
	return Vector3((uv.x - 0.5) * squeeze, (0.5 - uv.y) * tall, 0)


## The same, in the world.
func tile_world(p: Vector2) -> Vector3:
	return global_transform * tile_point(p)


## The folded sheet: an accordion across, a softer crease down the middle.
func _mesh() -> ArrayMesh:
	var w := 1.0
	var h := tall
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	# Each panel keeps its width and turns from flat: across, it takes less
	# room; in depth, every other crease stands out.
	var turn := deg_to_rad(fold * FOLD_MOST)
	var squeeze := cos(turn)
	var depth := w / COLUMNS * sin(turn)
	var point := func(i: int, j: int) -> Vector3:
		var u := float(i) / COLUMNS
		var v := float(j) / ROWS
		var z := (depth if i % 2 == 1 else 0.0) + (fold * 0.03 if j == 1 else 0.0)
		return Vector3((u - 0.5) * w * squeeze, (0.5 - v) * h, z - depth * 0.5)
	for i in COLUMNS:
		for j in ROWS:
			# Every other panel turned from the lamp, a little darker the
			# more it is folded; the lower row under the crease a touch too.
			var shade := 1.0 - sin(turn) * (0.45 if i % 2 == 1 else 0.12) - fold * (0.06 if j == 1 else 0.0)
			st.set_color(Color(shade, shade, shade * 0.97))
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
