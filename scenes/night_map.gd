class_name NightMap
extends Control
## The story's maps, as the menu item's "style" says (Hud.show_menu, "nights"):
##   "city"   the town at night from above: streets that branch and cross, a
##            river with its bridges, the gang's hideout at one end and each
##            museum a building in its own colours, its stop at the door. The
##            streets light up as far as the last museum open.
##   "museum" inside one museum, in its colours (Story.MUSEUMS palette): a row
##            of rooms, a night's stop in each, doors from one to the next.
## The stops are the menu's own buttons (Hud._night): this only places them
## and draws the rest, and the ninja's token hopping on the one picked.

const GROUND := Color("#15111d")
const BLOCK := Color("#1f1929")
const STREET := Color("#3a3246")
const STREET_EDGE := Color("#0c0a12")
const ROAD := Color("#e9d3a4")
const ROAD_EDGE := Color("#2a160d")
const RIVER := Color("#1f3a5e")
const WINDOW := Color("#ffd479")
const DARK := Color("#08070c")

## Where each museum's door is, across the map (0..1 of its size), in
## the order they open: left to right, up and down the town.
const SPOTS := [Vector2(0.14, 0.74), Vector2(0.33, 0.27), Vector2(0.52, 0.72), Vector2(0.73, 0.28), Vector2(0.9, 0.7)]
## The gang's hideout, where every way starts.
const HIDEOUT := Vector2(0.035, 0.5)
## The streets: a line of points and the museum it leads to, lit once that
## museum is open (-1: just a street of the town, never lit). The avenue runs
## from the hideout, a street branching off it to each museum; the rest cross
## it and each other.
const STREETS := [
	[[HIDEOUT, Vector2(0.14, 0.5)], 0],
	[[Vector2(0.14, 0.5), Vector2(0.14, 0.74)], 0],
	[[Vector2(0.14, 0.5), Vector2(0.24, 0.5), Vector2(0.33, 0.42)], 1],
	[[Vector2(0.33, 0.42), Vector2(0.33, 0.27)], 1],
	[[Vector2(0.33, 0.42), Vector2(0.43, 0.5), Vector2(0.52, 0.5)], 2],
	[[Vector2(0.52, 0.5), Vector2(0.52, 0.72)], 2],
	[[Vector2(0.52, 0.5), Vector2(0.64, 0.5), Vector2(0.73, 0.42)], 3],
	[[Vector2(0.73, 0.42), Vector2(0.73, 0.28)], 3],
	[[Vector2(0.73, 0.42), Vector2(0.82, 0.5), Vector2(0.9, 0.56), Vector2(0.9, 0.7)], 4],
	# The rest of the town.
	[[Vector2(0.02, 0.12), Vector2(0.98, 0.12)], -1],
	[[Vector2(0.02, 0.9), Vector2(0.98, 0.9)], -1],
	[[Vector2(0.14, 0.74), Vector2(0.14, 0.9)], -1],
	[[Vector2(0.24, 0.5), Vector2(0.24, 0.12)], -1],
	[[Vector2(0.24, 0.5), Vector2(0.3, 0.9)], -1],
	[[Vector2(0.43, 0.5), Vector2(0.43, 0.12)], -1],
	[[Vector2(0.43, 0.5), Vector2(0.4, 0.9)], -1],
	[[Vector2(0.52, 0.72), Vector2(0.52, 0.9)], -1],
	[[Vector2(0.64, 0.5), Vector2(0.64, 0.9)], -1],
	[[Vector2(0.73, 0.28), Vector2(0.73, 0.12)], -1],
	[[Vector2(0.82, 0.5), Vector2(0.86, 0.12)], -1],
	[[Vector2(0.9, 0.7), Vector2(0.9, 0.9)], -1],
]
## The river down the town, crossed by the avenue and the two long streets.
const RIVER_X := 0.595

var style := "city"
## the menu item: its "nights" (each maybe with a "look", a museum's palette)
## and, inside a museum, its "palette"
var _item := {}
var _stops: Array[Button] = []
var _locked: Array[bool] = []
var _points: PackedVector2Array = []
var _token: _Token
var _laid_for := Vector2.ZERO


func _init(item := {}) -> void:
	_item = item
	style = item.get("style", "city")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_token = _Token.new()
	_token.map = self
	resized.connect(_layout)


## Adds a button as the next stop: the next museum, or the next room.
func add_stop(b: Button, locked: bool) -> void:
	_stops.append(b)
	_locked.append(locked)
	add_child(b)
	b.resized.connect(_layout)
	# The token always over the stops.
	if _token.get_parent():
		move_child(_token, -1)
	else:
		add_child(_token)


func _process(_dt: float) -> void:
	# The layout waits for the map to have its size in the menu.
	if _points.size() != _stops.size() or _laid_for != size:
		_layout()
	_token.queue_redraw()


func _layout() -> void:
	var n := _stops.size()
	if n == 0 or size.x <= 0:
		return
	_laid_for = size
	_points.clear()
	for i in n:
		if style == "city":
			_points.append(_at(SPOTS[mini(i, SPOTS.size() - 1)]))
		else:
			_points.append(Vector2(size.x * (i + 0.5) / n, size.y * 0.6))
	for i in n:
		var b := _stops[i]
		b.pivot_offset = b.size / 2
		b.position = _points[i] - b.size / 2
	_token.size = size
	queue_redraw()


func _at(v: Vector2) -> Vector2:
	return v * size


func _draw() -> void:
	if _points.is_empty():
		return
	if style == "city":
		_draw_city()
	else:
		_draw_inside()


func _panel(colour: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = colour
	st.set_corner_radius_all(22)
	st.border_color = Color("#6b4a2e")
	st.set_border_width_all(4)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 5)
	return st


# --- The town ---------------------------------------------------------------------

func _draw_city() -> void:
	draw_style_box(_panel(GROUND), Rect2(Vector2.ZERO, size))
	_draw_river()
	var open := _last_open()
	# The plain streets under, the ones leading to a museum over them.
	for pass_lit in [false, true]:
		for s in STREETS:
			var line := PackedVector2Array()
			for p in s[0]:
				line.append(_at(p))
			var k: int = s[1]
			if not pass_lit and k < 0:
				draw_polyline(line, STREET_EDGE, 15.0, true)
				draw_polyline(line, STREET, 10.0, true)
			elif pass_lit and k >= 0:
				_draw_way(line, k <= open)
	_draw_bridges()
	_draw_houses()
	_draw_hideout(_at(HIDEOUT))
	for i in _points.size():
		_museum(_points[i] + Vector2(0, -34), _look(i), _locked[i])


## The furthest museum open: the streets are lit up to it.
func _last_open() -> int:
	var open := -1
	for i in _locked.size():
		if not _locked[i]:
			open = i
	return open


## A way to a museum: the lit road with dashes down the middle, or, while it
## is still shut, a street with a dotted line along it.
func _draw_way(line: PackedVector2Array, lit: bool) -> void:
	if lit:
		draw_polyline(line, ROAD_EDGE, 17.0, true)
		draw_polyline(line, ROAD, 11.0, true)
		_dashes(line, Color("#b89a6a"), 2.0)
	else:
		draw_polyline(line, STREET_EDGE, 15.0, true)
		draw_polyline(line, STREET, 10.0, true)
		_dashes(line, Color("#5a4a66"), 2.0)


func _dashes(line: PackedVector2Array, colour: Color, width: float) -> void:
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var steps := int(a.distance_to(b) / 12.0)
		for s in steps:
			if s % 2 == 0:
				draw_line(a.lerp(b, float(s) / steps), a.lerp(b, float(s + 1) / steps), colour, width, true)


func _river_x(y: float) -> float:
	return size.x * RIVER_X + sin(y / size.y * 7.0) * 12.0


func _draw_river() -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for s in 25:
		var y := size.y * s / 24.0
		left.append(Vector2(_river_x(y) - 14, y))
		right.append(Vector2(_river_x(y) + 14, y))
	var shape := left.duplicate()
	right.reverse()
	shape.append_array(right)
	draw_colored_polygon(shape, RIVER)
	# A few ripples in the moonlight.
	for s in 6:
		var y := size.y * (s + 0.5) / 6.0
		draw_line(Vector2(_river_x(y) - 5, y), Vector2(_river_x(y) + 4, y + 1), Color("#5a8ac0"), 2.0, true)


## Where a street crosses the river: a stone bridge with railings.
func _draw_bridges() -> void:
	for y in [0.12, 0.5, 0.9]:
		var c := Vector2(_river_x(y * size.y), y * size.y)
		for s in [-1, 1]:
			draw_line(c + Vector2(-18, s * 8), c + Vector2(18, s * 8), Color("#8a7a6a"), 3.0, true)


## Houses with lit windows and trees in the blocks between the streets.
## Always the same, from a fixed seed.
func _draw_houses() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	for k in 150:
		var at := Vector2(rng.randf_range(0.03, 0.97), rng.randf_range(0.05, 0.95)) * size
		var tree := rng.randf() < 0.3
		var w := rng.randf_range(14, 22)
		var h := rng.randf_range(12, 18)
		if not _clear(at, maxf(w, h) * 0.5 + 6):
			continue
		if tree:
			draw_circle(at, 7, Color("#23382a"))
			draw_circle(at + Vector2(-2, -2), 4, Color("#34543a"))
			continue
		var wall := Color("#3a2f4a").lerp(Color("#4a2f3a"), rng.randf())
		draw_rect(Rect2(at.x - w / 2, at.y - h / 2, w, h), wall)
		draw_rect(Rect2(at.x - w / 2, at.y - h / 2, w, 3), wall.lightened(0.15))
		for j in 2:
			if rng.randf() < 0.55:
				draw_rect(Rect2(at.x - w / 4 + j * w / 2 - 2, at.y - 1, 4, 4), WINDOW)


## Whether a house fits here: clear of the streets, the river, the museums
## and the hideout.
func _clear(at: Vector2, r: float) -> bool:
	if absf(at.x - _river_x(at.y)) < r + 16:
		return false
	for p in _points:
		if Rect2(p + Vector2(-58, -76), Vector2(116, 104)).grow(r).has_point(at):
			return false
	if at.distance_to(_at(HIDEOUT)) < r + 30:
		return false
	for s in STREETS:
		var line: Array = s[0]
		for i in line.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(at, _at(line[i]), _at(line[i + 1]))
			if at.distance_to(q) < r + 9:
				return false
	return true


## The gang's hideout: a little house with a sock hung out as a flag.
func _draw_hideout(at: Vector2) -> void:
	var c := at + Vector2(2, -26)
	draw_rect(Rect2(c.x - 13, c.y - 8, 26, 18), Color("#4a3a2a"))
	draw_colored_polygon([c + Vector2(-16, -8), c + Vector2(0, -20), c + Vector2(16, -8)], Color("#2a1d2e"))
	draw_rect(Rect2(c.x - 4, c.y + 1, 8, 9), WINDOW)
	draw_line(c + Vector2(12, -12), c + Vector2(12, -30), Color("#8a7a6a"), 2.0)
	draw_colored_polygon([c + Vector2(13, -30), c + Vector2(22, -30), c + Vector2(22, -22), c + Vector2(27, -18), c + Vector2(22, -15), c + Vector2(17, -21), c + Vector2(13, -21)], Color("#e2262f"))


func _look(i: int) -> Dictionary:
	var nights: Array = _item.get("nights", [])
	return nights[i].get("look", {}) if i < nights.size() else {}


## A museum: steps, columns and a pediment in its own colours; shut and
## dark until it is open.
func _museum(at: Vector2, look: Dictionary, locked: bool) -> void:
	var wall: Color = look.get("paper", Color("#5e2233"))
	var trim: Color = look.get("trim", Color("#9a7a3c"))
	var roof: Color = look.get("cap", Color("#7a6a5a"))
	if locked:
		wall = wall.darkened(0.6)
		trim = trim.darkened(0.65)
		roof = roof.darkened(0.6)
	var w := 76.0
	draw_colored_polygon([at + Vector2(-w / 2 - 6, -18), at + Vector2(0, -38), at + Vector2(w / 2 + 6, -18)], roof)
	draw_line(at + Vector2(-w / 2 - 6, -18), at + Vector2(w / 2 + 6, -18), trim, 3.0)
	draw_rect(Rect2(at.x - w / 2, at.y - 17, w, 30), wall)
	for k in 5:
		draw_rect(Rect2(at.x - w / 2 + 5 + k * 15, at.y - 15, 6, 26), trim.lerp(Color.WHITE, 0.15))
	draw_rect(Rect2(at.x - w / 2 - 4, at.y + 12, w + 8, 5), roof.darkened(0.2))
	# Its lights on inside, once it is open.
	if not locked:
		draw_circle(at + Vector2(0, -27), 3.0, WINDOW)


# --- Inside a museum ---------------------------------------------------------------

## A row of rooms in the museum's colours: the floor's two tones in tiles,
## the walls round them with a trim, a door between each and the next, and
## the way in on the left. The rooms still shut are in the dark.
func _draw_inside() -> void:
	var look: Dictionary = _item.get("palette", {})
	var wall: Color = look.get("paper", Color("#5e2233"))
	var wall2: Color = look.get("wainscot", Color("#3a2416"))
	var trim: Color = look.get("trim", Color("#9a7a3c"))
	var stone: Color = look.get("stone", Color("#2a2530"))
	var stone2: Color = look.get("stone2", Color("#3a3340"))
	draw_style_box(_panel(wall2.darkened(0.3)), Rect2(Vector2.ZERO, size))
	var n := _points.size()
	var inner := Rect2(Vector2(22, 22), size - Vector2(44, 44))
	var room_w := inner.size.x / n
	var tile := 18.0
	for i in n:
		var r := Rect2(inner.position.x + i * room_w, inner.position.y, room_w, inner.size.y)
		# The floor, a checkerboard of its two tones.
		for ty in int(ceil(r.size.y / tile)):
			for tx in int(ceil(r.size.x / tile)):
				var cell := Rect2(r.position + Vector2(tx, ty) * tile, Vector2(tile, tile)).intersection(r)
				draw_rect(cell, stone if (tx + ty) % 2 == 0 else stone2)
		if _locked[i]:
			draw_rect(r, Color(DARK, 0.65))
	# The walls: round the lot and between the rooms, each with a door.
	var band := 10.0
	draw_rect(inner, wall, false, band)
	draw_rect(inner.grow(band / 2), trim, false, 2.0)
	for i in range(1, n):
		var x := inner.position.x + i * room_w
		var door := inner.size.y * 0.3
		var mid := inner.position.y + inner.size.y * 0.6
		draw_line(Vector2(x, inner.position.y), Vector2(x, mid - door / 2), wall, band)
		draw_line(Vector2(x, mid + door / 2), Vector2(x, inner.end.y), wall, band)
	# The way in, on the left: a green door.
	var y := inner.position.y + inner.size.y * 0.6
	draw_rect(Rect2(inner.position.x - band, y - 18, band + 4, 36), Color("#4ade80"))
	# A painting on each room's back wall.
	for i in n:
		var cx := inner.position.x + (i + 0.5) * room_w
		var lit := not _locked[i]
		draw_rect(Rect2(cx - 18, inner.position.y + 10, 36, 24), trim if lit else trim.darkened(0.6))
		draw_rect(Rect2(cx - 14, inner.position.y + 14, 28, 16), Color("#274b6e") if lit else DARK)


## The picked stop: the one whose button carries "selected".
func picked_point() -> Vector2:
	for i in _stops.size():
		if _stops[i].get_meta("selected", false):
			return _points[i] if i < _points.size() else Vector2.ZERO
	return _points[0] if not _points.is_empty() else Vector2.ZERO


## The ninja's token, hopping over the picked stop: a black head, a band in
## the first thief's colour with its tails, two white eyes.
class _Token:
	extends Control
	var map: NightMap
	var _at := Vector2.INF

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var goal := map.picked_point()
		if goal == Vector2.ZERO:
			return
		# Slides to a newly picked stop rather than jumping there.
		_at = goal if _at == Vector2.INF else _at.lerp(goal, 0.25)
		var t := Time.get_ticks_msec() / 1000.0
		var hop := absf(sin(t * 5.0)) * 7.0
		var c := _at + Vector2(0, -38 - hop)
		draw_set_transform(Vector2.ZERO)
		# Its shadow on the stop.
		draw_circle(_at + Vector2(0, -22), 9 - hop * 0.4, Color(0, 0, 0, 0.35))
		var band := Color("#e2262f")
		draw_line(c + Vector2(10, -2), c + Vector2(20, 2 + sin(t * 9.0) * 2), band, 4.0, true)
		draw_line(c + Vector2(10, 0), c + Vector2(18, 7 + sin(t * 9.0 + 1.0) * 2), band, 4.0, true)
		draw_circle(c, 13, Color("#08070c"))
		draw_circle(c, 12, Color("#1a1a20"))
		draw_rect(Rect2(c.x - 12, c.y - 7, 24, 5), band)
		for s in [-1, 1]:
			draw_circle(c + Vector2(s * 4.5, 2), 3.2, Color.WHITE)
			draw_circle(c + Vector2(s * 4.5 - 0.6, 2.4), 1.8, Color("#08070c"))
