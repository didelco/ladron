class_name NightMap
extends Control
## The story's nights as stops on a map, like the worlds of a platformer: a
## road winding through three districts of the city at night, a stop for each
## night, the road dotted where it is still locked, and the ninja's token
## hopping on the night picked. The stops are the menu's own night buttons
## (Hud._night): this only places them along the road and draws the rest.

## Nights per district, in order: the old town, the harbour, the hill.
const DISTRICTS := [7, 7, 6]
const DISTRICT_COLOURS := [Color("#3a2a55"), Color("#1f3a55"), Color("#3a4a2e")]
const ROAD := Color("#e9d3a4")
const ROAD_EDGE := Color("#2a160d")
const LOCKED_ROAD := Color("#5a4a66")
const GROUND := Color("#1c1426")
const WINDOW := Color("#ffd479")
const MARGIN := 46.0

var _stops: Array[Button] = []
var _locked: Array[bool] = []
var _points: PackedVector2Array = []
var _token: _Token
var _laid_for := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_token = _Token.new()
	_token.map = self
	resized.connect(_layout)


## Adds a night's button as the next stop along the road.
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


## Where the road runs: across the map, winding up and down, a stop at a time.
func _layout() -> void:
	var n := _stops.size()
	if n == 0 or size.x <= 0:
		return
	_laid_for = size
	_points.clear()
	var w := size.x - 2 * MARGIN
	var mid := size.y * 0.58
	var amp := size.y * 0.25
	for i in n:
		var t := float(i) / maxi(1, n - 1)
		var y := mid + amp * (0.75 * sin(i * 1.05 + 0.4) + 0.25 * sin(i * 0.43 + 2.0))
		_points.append(Vector2(MARGIN + t * w, y))
	for i in n:
		var b := _stops[i]
		b.pivot_offset = b.size / 2
		b.position = _points[i] - b.size / 2
	_token.size = size
	queue_redraw()


func _draw() -> void:
	if _points.is_empty():
		return
	var r := Rect2(Vector2.ZERO, size)
	draw_style_box(_panel(), r)
	_draw_districts()
	_draw_decor()
	_draw_road()


func _panel() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = GROUND
	st.set_corner_radius_all(22)
	st.border_color = Color("#6b4a2e")
	st.set_border_width_all(4)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 6
	st.shadow_offset = Vector2(0, 5)
	return st


## A soft patch of colour under each district's stops.
func _draw_districts() -> void:
	var first := 0
	for d in DISTRICTS.size():
		var last := mini(first + DISTRICTS[d], _points.size()) - 1
		if last < first:
			break
		var x0 := 8.0 if d == 0 else (_points[first - 1].x + _points[first].x) / 2
		var x1 := size.x - 8.0 if last == _points.size() - 1 else (_points[last].x + _points[last + 1].x) / 2
		var st := StyleBoxFlat.new()
		st.bg_color = DISTRICT_COLOURS[d]
		st.set_corner_radius_all(18)
		draw_style_box(st, Rect2(x0 + 3, 8, x1 - x0 - 6, size.y - 16))
		first = last + 1


## Houses with lit windows, trees, lamp posts, the harbour's waves and, at
## the end of the road, the museum. Always the same, from a fixed seed.
func _draw_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	var first := 0
	for d in DISTRICTS.size():
		var last := mini(first + DISTRICTS[d], _points.size()) - 1
		for i in range(first, last + 1):
			var p := _points[i]
			# Something above and below the road at each stop, clear of it.
			for side in [-1, 1]:
				var at := Vector2(p.x + rng.randf_range(-18, 18), p.y + side * rng.randf_range(34, 48))
				if at.y < 22 or at.y > size.y - 18:
					continue
				match d:
					0: _house(at, rng) if rng.randf() < 0.65 else _tree(at, rng)
					1: _waves(at) if side > 0 and rng.randf() < 0.7 else _house(at, rng)
					_: _tree(at, rng) if rng.randf() < 0.7 else _lamp(at)
		first = last + 1
	_museum(_points[_points.size() - 1] + Vector2(-4, -44))


func _house(at: Vector2, rng: RandomNumberGenerator) -> void:
	var w := rng.randf_range(16, 24)
	var h := rng.randf_range(14, 22)
	var wall := Color("#4a3a5e").lerp(Color("#5e3a3a"), rng.randf())
	draw_rect(Rect2(at.x - w / 2, at.y - h / 2, w, h), wall)
	draw_colored_polygon([Vector2(at.x - w / 2 - 3, at.y - h / 2), Vector2(at.x, at.y - h / 2 - 9), Vector2(at.x + w / 2 + 3, at.y - h / 2)], Color("#2a1d2e"))
	for k in 2:
		if rng.randf() < 0.7:
			draw_rect(Rect2(at.x - w / 4 + k * w / 2 - 2.5, at.y - 3, 5, 5), WINDOW)


func _tree(at: Vector2, rng: RandomNumberGenerator) -> void:
	draw_rect(Rect2(at.x - 1.5, at.y, 3, 8), Color("#3a2618"))
	var r := rng.randf_range(7, 10)
	draw_circle(at, r, Color("#2e4a2e"))
	draw_circle(at + Vector2(-2, -2), r * 0.55, Color("#3e6a3a"))


func _lamp(at: Vector2) -> void:
	draw_line(at + Vector2(0, 10), at + Vector2(0, -8), Color("#2a1d2e"), 2.0)
	draw_circle(at + Vector2(0, -9), 6, Color(WINDOW, 0.18))
	draw_circle(at + Vector2(0, -9), 2.5, WINDOW)


func _waves(at: Vector2) -> void:
	for k in 2:
		var pts := PackedVector2Array()
		for s in 9:
			pts.append(at + Vector2(-14 + s * 3.5, k * 7 + sin(s * 1.6) * 2))
		draw_polyline(pts, Color("#5a8ac0"), 2.0, true)


func _museum(at: Vector2) -> void:
	var w := 40.0
	draw_colored_polygon([at + Vector2(-w / 2 - 4, -6), at + Vector2(0, -20), at + Vector2(w / 2 + 4, -6)], Color("#c9b48a"))
	draw_rect(Rect2(at.x - w / 2, at.y - 6, w, 20), Color("#b8a07a"))
	for k in 4:
		draw_rect(Rect2(at.x - w / 2 + 4 + k * 9.5, at.y - 4, 4, 16), Color("#e9d9b4"))


## The road: a thick band along a smooth curve through the stops; past the
## last night open, dotted and dim.
func _draw_road() -> void:
	var open := 0
	for i in _locked.size():
		if not _locked[i]:
			open = i
	var curve := _curve()
	var per := (curve.size() - 1) / maxi(1, _points.size() - 1)
	var cut := open * per
	var lit := curve.slice(0, cut + 1)
	var dim := curve.slice(cut)
	if dim.size() > 1:
		for k in range(0, dim.size() - 1, 4):
			draw_line(dim[k], dim[mini(k + 2, dim.size() - 1)], LOCKED_ROAD, 5.0, true)
	if lit.size() > 1:
		draw_polyline(lit, ROAD_EDGE, 13.0, true)
		draw_polyline(lit, ROAD, 8.0, true)
		# The dashes down the middle.
		for k in range(0, lit.size() - 1, 6):
			draw_line(lit[k], lit[mini(k + 2, lit.size() - 1)], Color("#b89a6a"), 2.0, true)


## Catmull-Rom through the stops, a few samples between each pair.
func _curve() -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := _points.size()
	for i in n - 1:
		var p0 := _points[maxi(0, i - 1)]
		var p1 := _points[i]
		var p2 := _points[i + 1]
		var p3 := _points[mini(n - 1, i + 2)]
		for s in 12:
			var t := s / 12.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
	out.append(_points[n - 1])
	return out


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
