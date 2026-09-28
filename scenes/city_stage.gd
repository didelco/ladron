class_name CityStage
extends SubViewport
## The story's way in to a heist, as one 3D place seen from above at the
## menus' axonometric angle: the town at night (a ground, a river, a road,
## a few trees and the five museums, each a toy building of its theme and
## colour), and inside the museum picked, its five rooms as a doll's house
## with the roof off. Tour drives it and draws the words over it.
##
## Everything is laid out on the town's own plan: x across the screen, z
## towards the viewer; the plan is turned a little (YAW) so the buildings
## show a front and a side.

## The town's colours, new with it: all here, to change in one place.
const SKY := Color("#110d1f")
const GROUND := Color("#2a2140")
const GROUND_SIDE := Color("#191327")
const GRASS := Color("#2f2a48")
const RIVER := Color("#27407a")
const RIVER_EDGE := Color("#1a2a52")
const ROAD := Color("#4a3f5c")
const ROAD_LIT := Color("#8a7358")
const ROAD_DASH := Color("#f0d9a8")
const BRIDGE := Color("#7d6a8f")
const LOT := Color("#3a3050")
const RING := Color("#ffc94a")
const LOCK := Color("#9a8fb0")
const WINDOW := Color("#ffd479")
const SHUT := 0.62

## The plan's turn under the camera, and how big the town is.
const YAW := 20.0
const TOWN := Vector2(34.0, 20.0)
## Each museum's lot: its rooms in a row across it.
const LOT_SIZE := Vector2(4.6, 2.2)
## Where each museum stands on the town's plan, in the order they open.
const SPOTS := [Vector2(-12.5, 2.6), Vector2(-6.5, -3.6), Vector2(0.0, 2.8), Vector2(6.5, -3.6), Vector2(12.5, 2.6)]
## The gang's hideout, where the road starts.
const HIDEOUT := Vector2(-16.0, -2.5)
## The river: a line of points across the town, back to front.
const RIVER_LINE := [Vector2(2.9, -10.5), Vector2(3.6, -5.5), Vector2(2.6, -1.0), Vector2(3.8, 3.5), Vector2(3.0, 10.5)]
const RIVER_WIDTH := 1.5
## How far the camera sees (orthographic height) over the town, and over a museum.
const CITY_VIEW := 21.0
const MUSEUM_VIEW := 3.7
## How long the camera takes into a museum and back out (s).
const ZOOM_S := 1.5
## How long the plan takes out of its room and open in front of you (s),
## and how much of the screen it fills then, across and up.
const PLAN_S := 2.1
const PLAN_FILL := Vector2(0.94, 0.76)
## How dark the town goes behind the plan.
const PLAN_VEIL := 0.8
## A room's size across, the big job's this many times wider; the walls.
const BOSS_WIDTH := 1.6
const WALL_H := 0.42
const WALL_T := 0.07

## the town turned under the camera: everything but the camera hangs off it
var town: Node3D
## the ground, the river, the road and the trees: what sinks away when a
## museum is gone into
var _scenery: Node3D
var _cam: Camera3D
## where the camera looks and how much it sees, eased towards the goals
var focus := Vector3.ZERO
var view := CITY_VIEW
var _museums: Array[Node3D] = []
var _shells: Array[Node3D] = []
var _locks: Array[Node3D] = []
var _open: Array[bool] = []
var _ring: MeshInstance3D
var _ring_light: SpotLight3D
var picked := 0
var _t := 0.0
## the museum gone into (-1 in the town) and its doll's house
var inside := -1
var _house: Node3D
var _rooms: Array[Dictionary] = []
var room := -1
var _room_ring: MeshInstance3D
var _room_light: SpotLight3D
var _tween: Tween
## everything moves at once (the tests)
var hurry := false
## the plan out of its room (PlanSheet), and the veil behind it
var sheet: PlanSheet
var _veil: MeshInstance3D
## where the sheet starts (flat on its room's floor) and where it ends up
## (open, facing the camera), as position, turn and size
var _sheet_from := {}
var _sheet_to := {}
## the camera as the plan opened, to close in on it from and come back to
var _plan_cam := {}


func _init() -> void:
	size = Vector2i(1280, 720)
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a5a9a")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.3
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The menus' lights: a warm lamp from the front left with soft shadows,
	# a cool moon from behind rimming every edge.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -25, 0)
	key.light_color = Color("#ffcf96")
	key.light_energy = 0.7
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 80.0
	add_child(key)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-30, 150, 0)
	moon.light_color = Color("#8f9cff")
	moon.light_energy = 0.5
	add_child(moon)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.rotation_degrees = Vector3(-35.264, 45, 0)
	_cam.near = 0.1
	_cam.far = 400.0
	add_child(_cam)
	town = Node3D.new()
	town.rotation_degrees.y = 45.0 - YAW
	add_child(town)
	_scenery = Node3D.new()
	town.add_child(_scenery)


## The town as this gang has it: museums up to `open_to` (0-based) open,
## the one `pick` picked.
func build(open_to: int, pick: int) -> void:
	_ground()
	_river()
	_road(open_to)
	_trees()
	_hideout()
	for m in Story.MUSEUMS.size():
		var at := SPOTS[m] as Vector2
		var lot := Node3D.new()
		lot.position = Vector3(at.x, 0, at.y)
		town.add_child(lot)
		_museums.append(lot)
		_open.append(m <= open_to)
		_rounded(lot, LOT_SIZE.x + 0.5, LOT_SIZE.y + 0.5, 0.12, 0.2, LOT, Vector3(0, 0.06, 0))
		var shell := Node3D.new()
		lot.add_child(shell)
		_shells.append(shell)
		_building(shell, m, m <= open_to)
		var lock := _padlock()
		lock.position = Vector3(0, 2.6, LOT_SIZE.y * 0.5 + 0.2)
		lock.visible = m > open_to
		lot.add_child(lock)
		_locks.append(lock)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 3.05
	torus.outer_radius = 3.2
	torus.rings = 48
	_ring.mesh = torus
	_ring.material_override = _glow_material(RING, 1.0)
	town.add_child(_ring)
	_ring_light = SpotLight3D.new()
	_ring_light.light_color = Color("#ffd9a0")
	_ring_light.light_energy = 3.0
	_ring_light.spot_range = 14.0
	_ring_light.spot_angle = 22.0
	_ring_light.rotation_degrees = Vector3(-90, 0, 0)
	town.add_child(_ring_light)
	picked = clampi(pick, 0, _museums.size() - 1)
	focus = _town_middle()
	view = CITY_VIEW
	_place_camera()


## Whether museum m can be gone into.
func is_open(m: int) -> bool:
	return m >= 0 and m < _open.size() and _open[m]


## Pick museum m (the ring moves over, the building hops).
func pick(m: int) -> void:
	picked = clampi(m, 0, _museums.size() - 1)


## Where museum m's sign goes on screen: over its roof.
func museum_on_screen(m: int) -> Vector2:
	var lot := _museums[m]
	return _cam.unproject_position(lot.global_position + Vector3(0, _roof_height(m) + 0.6, 0))


## Where a point of the town (or anything) is on screen.
func on_screen(p: Vector3) -> Vector2:
	return _cam.unproject_position(p)


func camera() -> Camera3D:
	return _cam


# --- Going in and out --------------------------------------------------------------

## Into museum m: the camera glides down onto it, the rest of the town sinks
## into the dark and its roof lifts off, and there are its rooms. done() once
## it is all in place.
func go_in(m: int, rooms: Array, done: Callable) -> void:
	inside = m
	picked = m
	_build_house(m, rooms)
	var lot := _museums[m]
	var shell := _shells[m]
	var goal := lot.global_position + Vector3(0, 0.3, 0)
	if _tween:
		_tween.kill()
	var secs := 0.0 if hurry else ZOOM_S
	_tween = create_tween().set_parallel()
	_tween.tween_method(_zoom_step.bind(focus, view, goal, MUSEUM_VIEW), 0.0, 1.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_scenery, "position:y", -30.0, secs * 0.7).set_delay(secs * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for k in _museums.size():
		if k != m:
			_tween.tween_property(_museums[k], "position:y", -30.0, secs * 0.7).set_delay(secs * 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(shell, "position:y", 12.0, secs * 0.45).set_delay(secs * 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_house.scale = Vector3(1, 0.05, 1)
	_tween.tween_property(_house, "scale", Vector3.ONE, secs * 0.4).set_delay(secs * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(done)


## Back out to the town: the roof comes down, the town comes back up and
## the camera rises over it all.
func go_out(done: Callable) -> void:
	if inside < 0:
		done.call()
		return
	var m := inside
	var secs := 0.0 if hurry else ZOOM_S * 0.8
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_zoom_step.bind(focus, view, _town_middle(), CITY_VIEW), 0.0, 1.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_shells[m], "position:y", 0.0, secs * 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_house, "scale", Vector3(1, 0.05, 1), secs * 0.3)
	_tween.tween_property(_scenery, "position:y", 0.0, secs * 0.7).set_delay(secs * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for k in _museums.size():
		_tween.tween_property(_museums[k], "position:y", 0.0, secs * 0.7).set_delay(secs * 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_callback(func() -> void:
		inside = -1
		room = -1
		if _house:
			_house.queue_free()
			_house = null
		_rooms.clear()
		done.call())


## Straight into museum m, no glide (back from a heist).
func be_in(m: int, rooms: Array) -> void:
	var was := hurry
	hurry = true
	go_in(m, rooms, func() -> void: pass)
	_tween.custom_step(1.0)
	hurry = was


## How far into the way in or out the camera is: from one look to another,
## the view eased in steps of scale so the zoom feels even.
func _zoom_step(k: float, from_focus: Vector3, from_view: float, to_focus: Vector3, to_view: float) -> void:
	focus = from_focus.lerp(to_focus, k)
	view = exp(lerpf(log(from_view), log(to_view), k))
	_place_camera()


func _place_camera() -> void:
	_cam.size = view
	_cam.position = focus + _cam.basis.z * 80.0


func _town_middle() -> Vector3:
	return Vector3(0, 0, 0.8)


func _process(dt: float) -> void:
	_t += dt
	# The picked museum hops a little and its ring breathes round it.
	for m in _museums.size():
		var shell := _shells[m]
		var hop := 0.0
		if m == picked and inside < 0:
			hop = 0.18 + absf(sin(_t * 3.2)) * 0.12
		shell.get_child(0).position.y = lerpf(shell.get_child(0).position.y, hop, 1.0 - exp(-dt * 12.0))
		var lock := _locks[m]
		if lock.visible:
			lock.rotation.y = sin(_t * 1.6 + m) * 0.35
			lock.position.y = 2.6 + sin(_t * 2.0 + m) * 0.08
	if _ring and not _museums.is_empty():
		var lot := _museums[picked]
		_ring.visible = inside < 0
		_ring_light.visible = inside < 0 and _open[picked]
		_ring.position = _ring.position.lerp(Vector3(lot.position.x, 0.14, lot.position.z), 1.0 - exp(-dt * 10.0))
		_ring.scale = Vector3.ONE * (1.0 + sin(_t * 4.0) * 0.03)
		var ring := _ring.material_override as StandardMaterial3D
		ring.albedo_color = RING if _open[picked] else LOCK
		ring.emission = ring.albedo_color
		_ring_light.position = _ring.position + Vector3(0, 9, 0)
	if _house:
		_animate_house(dt)


# --- The town ---------------------------------------------------------------------

## A rounded slab of night ground with a grassy top.
func _ground() -> void:
	_rounded(_scenery, TOWN.x, TOWN.y, 0.8, 1.2, GROUND_SIDE, Vector3(0, -0.42, 0))
	_rounded(_scenery, TOWN.x - 0.2, TOWN.y - 0.2, 0.06, 1.1, GRASS, Vector3(0, 0.0, 0))


## The river, back to front across the town, a ribbon of flat strips.
func _river() -> void:
	var pts := _smooth(RIVER_LINE, 6)
	for i in pts.size() - 1:
		_strip(_scenery, pts[i], pts[i + 1], RIVER_WIDTH + 0.3, RIVER_EDGE, 0.035)
		_strip(_scenery, pts[i], pts[i + 1], RIVER_WIDTH, RIVER, 0.045)


## The road from the hideout past every museum's door, lit (with dashes
## down the middle) as far as the last one open.
func _road(open_to: int) -> void:
	var doors: Array = [HIDEOUT + Vector2(1.2, 0.8)]
	for m in SPOTS.size():
		doors.append(SPOTS[m] + Vector2(0, LOT_SIZE.y * 0.5 + 1.1))
	for i in doors.size() - 1:
		var a: Vector2 = doors[i]
		var b: Vector2 = doors[i + 1]
		var mid := Vector2((a.x + b.x) * 0.5, (a.y + b.y) * 0.5 + (1.0 if i % 2 == 0 else -1.0))
		var pts := _smooth([a, mid, b], 5)
		var lit := i <= open_to
		for k in pts.size() - 1:
			_strip(_scenery, pts[k], pts[k + 1], 1.0, ROAD_LIT if lit else ROAD, 0.06)
			if lit and k % 2 == 0:
				_strip(_scenery, pts[k], pts[k].lerp(pts[k + 1], 0.5), 0.12, ROAD_DASH, 0.075)
		# A bridge where it crosses the river.
		for k in pts.size() - 1:
			var hit: Variant = _river_cross(pts[k], pts[k + 1])
			if hit != null:
				var dir := (pts[k + 1] - pts[k]).normalized()
				_strip(_scenery, hit - dir * 1.3, hit + dir * 1.3, 1.4, BRIDGE, 0.16)
				for s in [-1, 1]:
					var side := Vector2(-dir.y, dir.x) * 0.7 * float(s)
					_strip(_scenery, hit - dir * 1.3 + side, hit + dir * 1.3 + side, 0.1, BRIDGE.lightened(0.2), 0.36)
		# From the road up to the door.
		if i < SPOTS.size():
			var spot: Vector2 = SPOTS[i]
			_strip(_scenery, b, spot + Vector2(0, LOT_SIZE.y * 0.5), 0.6, ROAD_LIT if lit else ROAD, 0.055)


## Where segment a–b crosses the river, or null.
func _river_cross(a: Vector2, b: Vector2) -> Variant:
	var pts := _smooth(RIVER_LINE, 6)
	for i in pts.size() - 1:
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b, pts[i], pts[i + 1])
		if hit != null:
			return hit
	return null


## A few round trees, always the same, clear of the road, the river and the
## museums.
func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var placed := 0
	for k in 200:
		if placed >= 22:
			break
		var at := Vector2(rng.randf_range(-TOWN.x * 0.46, TOWN.x * 0.46), rng.randf_range(-TOWN.y * 0.44, TOWN.y * 0.44))
		if not _clear(at, 1.0):
			continue
		placed += 1
		_tree(Vector3(at.x, 0, at.y), rng.randf_range(0.35, 0.55))


func _clear(at: Vector2, r: float) -> bool:
	var river := _smooth(RIVER_LINE, 6)
	for i in river.size() - 1:
		if at.distance_to(Geometry2D.get_closest_point_to_segment(at, river[i], river[i + 1])) < RIVER_WIDTH * 0.5 + r:
			return false
	for s in SPOTS:
		if Rect2(s - LOT_SIZE * 0.5, LOT_SIZE).grow(r + 1.3).has_point(at):
			return false
		if at.distance_to(s + Vector2(0, LOT_SIZE.y * 0.5 + 1.1)) < r + 1.6:
			return false
	if at.distance_to(HIDEOUT) < r + 1.5:
		return false
	return true


func _tree(at: Vector3, r: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.07
	trunk.bottom_radius = 0.1
	trunk.height = 0.6
	_mesh(_scenery, trunk, MenuStage.SOIL, at + Vector3(0, 0.3, 0))
	for k in 3:
		var ball := SphereMesh.new()
		ball.radius = r * (1.0 - k * 0.25)
		ball.height = ball.radius * 2.0
		_mesh(_scenery, ball, MenuStage.GRASS.darkened(0.1 * k), at + Vector3(0, 0.6 + r * 0.7 + k * r * 0.55, 0))


## The gang's hideout: a little house with a sock hung out as a flag.
func _hideout() -> void:
	var g := Node3D.new()
	g.position = Vector3(HIDEOUT.x, 0, HIDEOUT.y)
	_scenery.add_child(g)
	_rounded(g, 1.4, 1.1, 0.8, 0.08, Color("#4a3a2a"), Vector3(0, 0.4, 0))
	var roof := PrismMesh.new()
	roof.size = Vector3(1.6, 0.6, 1.2)
	_mesh(g, roof, Color("#2a1d2e"), Vector3(0, 1.1, 0))
	_glow_box(g, Vector3(0.3, 0.3, 0.02), WINDOW, Vector3(0, 0.45, 0.56), 1.5)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.025
	pole.bottom_radius = 0.025
	pole.height = 1.1
	_mesh(g, pole, Color("#8a7a6a"), Vector3(0.55, 1.5, 0))
	_box(g, Vector3(0.36, 0.22, 0.03), Color("#e2262f"), Vector3(0.75, 1.9, 0))
	_box(g, Vector3(0.14, 0.3, 0.03), Color("#e2262f"), Vector3(0.86, 1.7, 0))


# --- The museums ------------------------------------------------------------------

## Museum m's building, its look telling its theme and its colour: the
## cave a rocky mound, the bugs' house a greenhouse with a ladybird on it,
## the mummies' temple a step pyramid, the castle its towers, the Barón's
## tower of glass. Shut ones are dark, their windows out.
func _building(shell: Node3D, m: int, open: bool) -> void:
	# What hops: all of it but the lot.
	var body := Node3D.new()
	shell.add_child(body)
	var colour := Color(Story.MUSEUMS[m].colour)
	var look: Dictionary = Story.MUSEUMS[m].palette
	var wall: Color = look.paper
	var trim: Color = look.trim
	var stone: Color = look.cap
	if not open:
		colour = colour.darkened(SHUT)
		wall = wall.darkened(SHUT)
		trim = trim.darkened(SHUT)
		stone = stone.darkened(SHUT)
	var w := LOT_SIZE.x
	var d := LOT_SIZE.y
	var lit := WINDOW if open else Color("#2a2433")
	match Story.MUSEUMS[m].theme:
		"prehistoria":
			# Boulders piled into a hill, a dark mouth in front, a bone over it.
			for b in [[-1.2, 0.0, 1.3, 1.1], [0.2, -0.1, 1.6, 1.5], [1.4, 0.1, 1.2, 1.0], [-0.4, 0.3, 1.0, 0.8]]:
				var s := SphereMesh.new()
				s.radius = b[2]
				s.height = b[3] * 2.0
				_mesh(body, s, colour.lerp(stone, 0.3) if int(b[0] * 10) % 2 == 0 else colour, Vector3(b[0], 0.1, b[1]))
			var mouth := CylinderMesh.new()
			mouth.top_radius = 0.45
			mouth.bottom_radius = 0.45
			mouth.height = 0.2
			var hole := _mesh(body, mouth, Color("#120c08"), Vector3(0.2, 0.35, d * 0.5 + 0.2))
			hole.rotation_degrees.x = 90
			_bone(body, Vector3(0.2, 1.3, d * 0.5 + 0.15), Color("#f4ecd8").darkened(0.0 if open else SHUT))
			_glow_box(body, Vector3(0.5, 0.18, 0.02), lit, Vector3(0.2, 0.3, d * 0.5 + 0.32), 1.2 if open else 0.0)
		"naturaleza":
			# A greenhouse: a low hall with a glass dome, a ladybird on top.
			_rounded(body, w * 0.9, d * 0.9, 0.9, 0.12, wall, Vector3(0, 0.55, 0))
			_box(body, Vector3(w * 0.92, 0.1, d * 0.92), trim, Vector3(0, 1.05, 0))
			var dome := SphereMesh.new()
			dome.radius = 0.95
			dome.height = 1.5
			dome.is_hemisphere = true
			var glass := _mesh(body, dome, Color(colour.lightened(0.2), 0.55), Vector3(0, 1.1, 0))
			glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_ladybird(body, Vector3(0, 2.1, 0), open)
			for k in 4:
				_glow_box(body, Vector3(0.34, 0.4, 0.02), lit, Vector3(-1.5 + k, 0.55, d * 0.45 + 0.01), 1.0 if open else 0.0)
		"antiguo":
			# A step pyramid, a door with columns at its foot.
			for k in 4:
				_box(body, Vector3(w * (0.95 - k * 0.2), 0.5, d * (1.0 - k * 0.2)), colour.darkened(k * 0.06), Vector3(0, 0.25 + k * 0.5, -k * 0.05))
			_box(body, Vector3(0.5, 0.4, 0.4), trim, Vector3(0, 2.2, -0.15))
			for s in [-1, 1]:
				var col := CylinderMesh.new()
				col.top_radius = 0.08
				col.bottom_radius = 0.1
				col.height = 0.7
				_mesh(body, col, Color("#e8d6b4").darkened(0.0 if open else SHUT), Vector3(s * 0.35, 0.35, d * 0.5 + 0.08))
			_glow_box(body, Vector3(0.45, 0.55, 0.02), lit, Vector3(0, 0.3, d * 0.5 + 0.02), 1.3 if open else 0.0)
		"edad_media":
			# A keep with a tower at each corner, red cone roofs and a flag.
			_box(body, Vector3(w * 0.8, 1.2, d * 0.8), stone, Vector3(0, 0.6, 0))
			for k in 6:
				_box(body, Vector3(0.28, 0.25, 0.28), stone, Vector3(-1.5 + k * 0.6, 1.3, d * 0.4 - 0.1))
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					var t := CylinderMesh.new()
					t.top_radius = 0.38
					t.bottom_radius = 0.42
					t.height = 1.8
					var at := Vector3(sx * w * 0.42, 0.9, sz * d * 0.4)
					_mesh(body, t, stone.lightened(0.08), at)
					var cone := CylinderMesh.new()
					cone.top_radius = 0.0
					cone.bottom_radius = 0.5
					cone.height = 0.8
					_mesh(body, cone, colour, at + Vector3(0, 1.3, 0))
			_box(body, Vector3(0.03, 0.8, 0.03), Color("#8a7a6a"), Vector3(-w * 0.42, 2.9, -d * 0.4))
			_box(body, Vector3(0.45, 0.28, 0.03), colour.lightened(0.2), Vector3(-w * 0.42 + 0.24, 3.15, -d * 0.4))
			_glow_box(body, Vector3(0.5, 0.7, 0.02), lit, Vector3(0, 0.35, d * 0.4 + 0.01), 1.3 if open else 0.0)
		_:
			# A tower of glass, stripes of lit floors, the Barón's diamond on top.
			_box(body, Vector3(w * 0.9, 0.5, d * 0.9), wall, Vector3(0, 0.25, 0))
			var tower := _box(body, Vector3(1.8, 4.0, 1.4), Color(colour.darkened(0.45), 0.9), Vector3(0.6, 2.4, -0.2))
			tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for k in 7:
				_glow_box(body, Vector3(1.82, 0.08, 1.42), colour if open else colour.darkened(0.3), Vector3(0.6, 0.8 + k * 0.55, -0.2), 1.4 if open else 0.0)
			var gem := LootModels.build("gem", Color("#74c0fc"))
			gem.scale = Vector3.ONE * 1.6
			gem.position = Vector3(0.6, 4.5, -0.2)
			gem.name = "Gem"
			body.add_child(gem)
			_glow_box(body, Vector3(0.6, 0.35, 0.02), lit, Vector3(-1.0, 0.25, d * 0.45 + 0.01), 1.3 if open else 0.0)


## How tall museum m's building is, for its sign.
func _roof_height(m: int) -> float:
	return [2.0, 2.4, 2.5, 3.4, 5.0][clampi(m, 0, 4)]


func _bone(parent: Node3D, at: Vector3, colour: Color) -> void:
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.06
	shaft.bottom_radius = 0.06
	shaft.height = 0.8
	var s := _mesh(parent, shaft, colour, at)
	s.rotation_degrees.z = 90
	for x in [-0.42, 0.42]:
		for y in [-0.07, 0.07]:
			var knob := SphereMesh.new()
			knob.radius = 0.1
			knob.height = 0.2
			_mesh(parent, knob, colour, at + Vector3(x, y, 0))


## A ladybird: a red shell in two halves, black spots, a black head.
func _ladybird(parent: Node3D, at: Vector3, open: bool) -> void:
	var red := Color("#e03131") if open else Color("#e03131").darkened(SHUT)
	var ink := Color("#1c1210")
	var shell := SphereMesh.new()
	shell.radius = 0.5
	shell.height = 0.6
	shell.is_hemisphere = true
	_mesh(parent, shell, red, at)
	var head := SphereMesh.new()
	head.radius = 0.2
	head.height = 0.3
	_mesh(parent, head, ink, at + Vector3(0, 0.05, 0.45))
	for p in [Vector3(-0.2, 0.25, 0.1), Vector3(0.22, 0.24, -0.1), Vector3(-0.1, 0.28, -0.22), Vector3(0.15, 0.22, 0.25)]:
		var dot := SphereMesh.new()
		dot.radius = 0.08
		dot.height = 0.08
		_mesh(parent, dot, ink, at + p)
	_box(parent, Vector3(0.02, 0.3, 0.9), ink, at + Vector3(0, 0.28, 0))


## A padlock floating over a shut museum.
func _padlock() -> Node3D:
	var g := Node3D.new()
	_rounded(g, 0.8, 0.3, 0.65, 0.1, LOCK, Vector3.ZERO)
	var shackle := TorusMesh.new()
	shackle.inner_radius = 0.2
	shackle.outer_radius = 0.3
	var s := _mesh(g, shackle, LOCK.lightened(0.2), Vector3(0, 0.4, 0))
	s.rotation_degrees.x = 90
	_box(g, Vector3(0.1, 0.2, 0.02), Color("#1c1210"), Vector3(0, -0.03, 0.16))
	return g


## Museum m's padlock back on, to pop off (unlock) as the town shows it.
func relock(m: int) -> void:
	if m >= 0 and m < _locks.size():
		_locks[m].visible = true
		_locks[m].scale = Vector3.ONE


## The padlock of museum m pops off (a museum just opened).
func unlock(m: int) -> void:
	if m < 0 or m >= _locks.size() or not _locks[m].visible:
		return
	var lock := _locks[m]
	var tw := create_tween().set_parallel()
	tw.tween_property(lock, "position:y", lock.position.y + 2.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(lock, "scale", Vector3.ONE * 0.01, 0.6).set_delay(0.2)
	tw.chain().tween_callback(func() -> void: lock.visible = false)


# --- Inside a museum --------------------------------------------------------------

## The doll's house of museum m on its lot: rooms is one entry per heist in
## it, {"n", "boss", "open", "done", "shape", "colour"}. A row of rooms in
## the museum's floor and walls, a door from each to the next and the way in
## on the left; in each its piece on a stand, the big job's a wider hall
## with a red carpet and a crown; shut rooms dark, their piece under a sheet.
func _build_house(m: int, rooms: Array) -> void:
	if _house:
		_house.queue_free()
	_rooms.clear()
	room = -1
	_house = Node3D.new()
	_museums[m].add_child(_house)
	var look: Dictionary = Story.MUSEUMS[m].palette
	var total := 0.0
	for r in rooms:
		total += BOSS_WIDTH if r.boss else 1.0
	var unit := LOT_SIZE.x / total
	var x := -LOT_SIZE.x * 0.5
	var d := LOT_SIZE.y
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		var w: float = unit * (BOSS_WIDTH if r.boss else 1.0)
		var centre := Vector3(x + w * 0.5, 0.12, 0)
		var node := Node3D.new()
		node.position = centre
		_house.add_child(node)
		# The floor in the museum's two stones, in tiles.
		var tiles := 4
		for tx in tiles:
			for tz in tiles * 2:
				var c: Color = look.stone if (tx + tz) % 2 == 0 else look.stone2
				if not r.open:
					c = c.darkened(0.5)
				_box(node, Vector3(w / tiles, 0.04, d / (tiles * 2)), c, Vector3(-w * 0.5 + (tx + 0.5) * w / tiles, 0.02, -d * 0.5 + (tz + 0.5) * d / (tiles * 2)))
		if r.boss:
			_box(node, Vector3(w * 0.3, 0.02, d * 0.9), MenuStage.VELVET.lightened(0.15) if r.open else MenuStage.VELVET.darkened(0.4), Vector3(0, 0.05, 0.05))
		# The back wall, in its paper, a trim along its top.
		_box(node, Vector3(w, WALL_H, WALL_T), look.paper if r.open else Color(look.paper).darkened(0.5), Vector3(0, WALL_H * 0.5, -d * 0.5))
		_box(node, Vector3(w, 0.03, WALL_T + 0.02), look.trim, Vector3(0, WALL_H, -d * 0.5))
		# A painting on it, or over the big job a crown.
		if r.boss:
			_crown(node, Vector3(0, WALL_H + 0.25, -d * 0.5), MenuStage.GOLD if r.open else MenuStage.GOLD.darkened(0.6))
		else:
			_box(node, Vector3(w * 0.4, WALL_H * 0.45, 0.02), look.trim, Vector3(0, WALL_H * 0.55, -d * 0.5 + 0.045))
			_box(node, Vector3(w * 0.32, WALL_H * 0.33, 0.02), Color("#274b6e") if r.open else Color("#101018"), Vector3(0, WALL_H * 0.55, -d * 0.5 + 0.055))
		# The piece on its stand, or a sheet over it while the room is shut.
		var stand := CylinderMesh.new()
		stand.top_radius = 0.12
		stand.bottom_radius = 0.14
		stand.height = 0.16
		_mesh(node, stand, MenuStage.VELVET if r.open else MenuStage.VELVET.darkened(0.55), Vector3(0, 0.12, -0.05))
		var piece := Node3D.new()
		piece.position = Vector3(0, 0.22, -0.05)
		node.add_child(piece)
		if r.open:
			var model := LootModels.build(r.shape, Color(r.colour))
			model.scale = Vector3.ONE * (0.9 if r.boss else 0.7)
			piece.add_child(model)
		else:
			var sheet := SphereMesh.new()
			sheet.radius = 0.16
			sheet.height = 0.22
			_mesh(piece, sheet, Color("#6a6078"), Vector3(0, 0.04, 0))
			var lock := _padlock()
			lock.scale = Vector3.ONE * 0.28
			lock.position = Vector3(0, 0.45, 0.2)
			node.add_child(lock)
		_rooms.append({"node": node, "piece": piece, "w": w, "open": r.open, "n": r.n, "boss": r.boss})
		x += w
	# The walls between the rooms, each with a door; the sides.
	var gap := d * 0.34
	x = -LOT_SIZE.x * 0.5
	for i in rooms.size() + 1:
		var z0 := -d * 0.5
		var z1 := d * 0.5
		var part := Vector3(x, 0.12 + WALL_H * 0.5, 0)
		var colour: Color = look.paper
		if i == 0 or i == rooms.size():
			# The ends: whole, but for the way in on the left.
			if i == 0:
				_box(_house, Vector3(WALL_T, WALL_H, (d - gap) * 0.5), colour, part + Vector3(0, 0, z0 + (d - gap) * 0.25))
				_box(_house, Vector3(WALL_T, WALL_H, (d - gap) * 0.5), colour, part + Vector3(0, 0, z1 - (d - gap) * 0.25))
				_glow_box(_house, Vector3(0.02, WALL_H * 0.8, gap * 0.8), Color("#4ade80"), part + Vector3(-0.05, -WALL_H * 0.1, 0), 1.0)
			else:
				_box(_house, Vector3(WALL_T, WALL_H, d), colour, part)
		else:
			var gold: bool = rooms[i].boss
			_box(_house, Vector3(WALL_T, WALL_H, (d - gap) * 0.5), colour, part + Vector3(0, 0, z0 + (d - gap) * 0.25))
			_box(_house, Vector3(WALL_T, WALL_H, (d - gap) * 0.5), colour, part + Vector3(0, 0, z1 - (d - gap) * 0.25))
			if gold:
				for s in [-1, 1]:
					_box(_house, Vector3(WALL_T * 1.6, WALL_H * 1.05, 0.06), MenuStage.GOLD, part + Vector3(0, 0, s * gap * 0.5))
		if i < rooms.size():
			x += unit * (BOSS_WIDTH if rooms[i].boss else 1.0)
	# A low front wall, so the rooms read as rooms from the front.
	_box(_house, Vector3(LOT_SIZE.x, 0.1, WALL_T), look.wainscot, Vector3(0, 0.17, d * 0.5))
	_room_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.33
	torus.outer_radius = 0.38
	torus.rings = 40
	_room_ring.mesh = torus
	_room_ring.material_override = _glow_material(RING, 2.5)
	_house.add_child(_room_ring)
	_room_light = SpotLight3D.new()
	_room_light.light_color = Color("#ffe2b0")
	_room_light.light_energy = 6.0
	_room_light.spot_range = 5.0
	_room_light.spot_angle = 18.0
	_room_light.rotation_degrees = Vector3(-90, 0, 0)
	_house.add_child(_room_light)


## Pick room i (0-based) of the museum gone into.
func pick_room(i: int) -> void:
	room = clampi(i, 0, _rooms.size() - 1)


## Room i's middle, in the world, and where its sign goes on screen.
func room_centre(i: int) -> Vector3:
	return (_rooms[i].node as Node3D).global_position


func room_on_screen(i: int) -> Vector2:
	return _cam.unproject_position(room_centre(i) + Vector3(0, 0.9, 0))


## Room i's floor, as the world has it: its middle, its size across and
## along, and the town's turn (the plan comes out of it).
func room_floor(i: int) -> Dictionary:
	return {"centre": room_centre(i) + Vector3(0, 0.1, 0), "size": Vector2(_rooms[i].w, LOT_SIZE.y), "basis": town.global_transform.basis}


func room_count() -> int:
	return _rooms.size()


func _animate_house(dt: float) -> void:
	for i in _rooms.size():
		var r: Dictionary = _rooms[i]
		var piece: Node3D = r.piece
		var up := 0.12 + absf(sin(_t * 3.0)) * 0.05 if i == room else 0.0
		piece.position.y = lerpf(piece.position.y, 0.22 + up, 1.0 - exp(-dt * 10.0))
		piece.rotation.y += dt * (1.6 if i == room else 0.4)
	if room >= 0 and _room_ring:
		var goal := (_rooms[room].node as Node3D).position + Vector3(0, 0.07, -0.05)
		_room_ring.position = _room_ring.position.lerp(goal, 1.0 - exp(-dt * 12.0))
		var s: float = 1.0 + sin(_t * 4.0) * 0.05
		_room_ring.scale = Vector3(s, 1, s) * (1.4 if _rooms[room].boss else 1.0)
		_room_light.position = _room_ring.position + Vector3(0, 3.0, 0)
		var ring := _room_ring.material_override as StandardMaterial3D
		ring.albedo_color = RING if _rooms[room].open else LOCK
		ring.emission = ring.albedo_color
	_room_ring.visible = room >= 0
	_room_light.visible = room >= 0 and _rooms[room].open


## A little crown: a gold band with three points.
func _crown(parent: Node3D, at: Vector3, colour: Color) -> void:
	_box(parent, Vector3(0.36, 0.1, 0.04), colour, at)
	for k in 3:
		var p := PrismMesh.new()
		p.size = Vector3(0.1, 0.14, 0.04)
		_mesh(parent, p, colour, at + Vector3(-0.13 + k * 0.13, 0.12, 0))


# --- The plan ---------------------------------------------------------------------

## Out of the room picked comes its plan: it lifts off the floor, glowing,
## folded up; flies to the front, turning to face you; and opens out over
## the whole screen, the town darkening behind it. done() once it is open.
## plan: Hud.plan_map's picture, tile_px pixels a tile in it.
func raise_plan(plan: Image, tile_px: float, done: Callable) -> void:
	drop_plan()
	sheet = PlanSheet.new()
	add_child(sheet)
	sheet.print_plan(plan, tile_px)
	var ground := room_floor(room)
	# Flat on the floor, its height along the room's depth, as long as it.
	var flat := (ground.basis as Basis).orthonormalized() * Basis.from_euler(Vector3(-PI / 2, 0, 0))
	_sheet_from = {"at": ground.centre + Vector3(0, 0.05, 0), "turn": flat.get_rotation_quaternion(),
		"size": ground.size.y * 0.8 / sheet.tall}
	_sheet_to = _front_of_camera()
	_plan_cam = {"at": _cam.position, "size": _cam.size}
	sheet.fold = PlanSheet.SHUT
	_veil_on()
	_sheet_step(0.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_sheet_step, 0.0, 1.0, 0.0 if hurry else PLAN_S)
	_tween.tween_callback(done)


## The plan back into its room, folding up as it goes (back to the museum).
func lower_plan(done: Callable) -> void:
	if sheet == null:
		done.call()
		return
	plan_rest(0.0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_sheet_step, 1.0, 0.0, 0.0 if hurry else PLAN_S * 0.55)
	_tween.tween_callback(func() -> void:
		drop_plan()
		done.call())


func drop_plan() -> void:
	if sheet:
		sheet.queue_free()
		sheet = null
	if _veil:
		_veil.visible = false


## Where the open plan sits: in front of the camera, facing it, as big as
## fits (PLAN_FILL), a little above the middle to leave room for the hints.
func _front_of_camera() -> Dictionary:
	var aspect := float(size.x) / maxf(size.y, 1.0)
	var tall := _cam.size
	var wide := tall * aspect
	var k := minf(wide * PLAN_FILL.x, tall * PLAN_FILL.y / sheet.tall)
	var b := _cam.global_transform.basis.orthonormalized()
	return {"at": _cam.global_position - b.z * 30.0 - b.y * tall * 0.01, "turn": b.get_rotation_quaternion(), "size": k}


## The way out of the room, 0 on the floor to 1 open in front: it lifts
## (the first quarter), flies and turns (to 0.62) and opens (the rest).
func _sheet_step(t: float) -> void:
	if sheet == null:
		return
	var rise := smoothstep(0.0, 0.24, t)
	var fly := smoothstep(0.2, 0.62, t)
	var open := clampf((t - 0.6) / 0.4, 0.0, 1.0)
	# A little overshoot as it snaps open, like a map shaken out.
	var snap := 1.0 - pow(1.0 - open, 3.0) + sin(open * PI) * 0.08
	var lifted: Vector3 = _sheet_from.at + Vector3(0, 0.7 * rise, 0)
	var at := lifted.lerp(_sheet_to.at, fly)
	# An arc on the way, not a straight line.
	at += Vector3(0, sin(fly * PI) * 1.2, 0)
	var turn := (_sheet_from.turn as Quaternion).slerp(_sheet_to.turn, fly)
	# A twirl while it flies.
	turn = turn * Quaternion(Vector3.FORWARD, sin(fly * PI) * 0.5)
	var k: float = exp(lerpf(log(_sheet_from.size), log(_sheet_to.size), fly))
	sheet.transform = Transform3D(Basis(turn) * Basis.from_scale(Vector3.ONE * k), at)
	sheet.fold = lerpf(PlanSheet.SHUT, PlanSheet.OPEN, clampf(snap, 0.0, 1.2))
	sheet.shine(sin(minf(t / 0.62, 1.0) * PI) * 1.2)
	(_veil.material_override as StandardMaterial3D).albedo_color.a = PLAN_VEIL * fly


## The dark behind the plan: a sheet of night between it and the town.
func _veil_on() -> void:
	if _veil == null:
		_veil = MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(400, 400)
		_veil.mesh = q
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(SKY, 0.0)
		_veil.material_override = m
		_cam.add_child(_veil)
		_veil.position = Vector3(0, 0, -55)
	_veil.visible = true


## Where a point of the room's plan (tiles) is on screen, with the plan out.
func plan_on_screen(p: Vector2) -> Vector2:
	return _cam.unproject_position(sheet.tile_world(p)) if sheet else Vector2.ZERO


## The camera closing in on a point of the open plan (tiles): zoom times
## nearer, the point landing at `frac` of the screen (0..1 each way). It
## only slides across its own view, so the plan stays where it is.
func plan_look(p: Vector2, zoom: float, frac: Vector2, secs: float) -> void:
	if sheet == null:
		return
	var tall: float = _plan_cam.size / zoom
	var aspect := float(size.x) / maxf(size.y, 1.0)
	var b := _cam.global_transform.basis.orthonormalized()
	var rel := sheet.tile_world(p) - (_plan_cam.at as Vector3)
	var across := rel.dot(b.x) - (frac.x - 0.5) * tall * aspect
	var up := rel.dot(b.y) + (frac.y - 0.5) * tall
	_cam_to(_plan_cam.at + b.x * across + b.y * up, tall, secs)


## The camera on the whole plan, fitting it in area (fractions of the
## screen, from the top left): room beside it for the list of the night.
func plan_frame(area: Rect2, secs: float) -> void:
	if sheet == null or _plan_cam.is_empty():
		return
	var aspect := float(size.x) / maxf(size.y, 1.0)
	var k := sheet.transform.basis.x.length()
	var tall := maxf(k / (aspect * area.size.x), k * sheet.tall / area.size.y)
	plan_look(Vector2(Museum.w, Museum.h) * 0.5, _plan_cam.size / tall, area.get_center(), secs)


## The camera back to the whole plan.
func plan_rest(secs: float) -> void:
	if not _plan_cam.is_empty():
		_cam_to(_plan_cam.at, _plan_cam.size, secs)


var _cam_tween: Tween


func _cam_to(at: Vector3, tall: float, secs: float) -> void:
	if _cam_tween:
		_cam_tween.kill()
	if secs <= 0.0:
		_cam.position = at
		_cam.size = tall
		return
	_cam_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(_cam, "position", at, secs)
	_cam_tween.tween_property(_cam, "size", tall, secs)


# --- Shapes -----------------------------------------------------------------------

## A flat strip from a to b on the town's plan, at height y.
func _strip(parent: Node3D, a: Vector2, b: Vector2, width: float, colour: Color, y: float) -> void:
	var length := a.distance_to(b)
	if length < 0.001:
		return
	var mi := _box(parent, Vector3(length + width * 0.5, 0.04, width), colour, Vector3((a.x + b.x) * 0.5, y, (a.y + b.y) * 0.5))
	mi.rotation.y = -atan2(b.y - a.y, b.x - a.x)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A line through the points, rounded off (Chaikin), steps times.
static func _smooth(points: Array, steps: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in points:
		out.append(p)
	for s in steps:
		if out.size() < 3:
			break
		var next: Array[Vector2] = [out[0]]
		for i in out.size() - 1:
			next.append(out[i].lerp(out[i + 1], 0.25))
			next.append(out[i].lerp(out[i + 1], 0.75))
		next.append(out[-1])
		out = next
	return out


func _rounded(parent: Node3D, w: float, d: float, h: float, r: float, colour: Color, at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = at
	parent.add_child(g)
	r = minf(r, minf(w, d) * 0.5)
	_box(g, Vector3(w - 2.0 * r, h, d), colour, Vector3.ZERO)
	_box(g, Vector3(w, h, d - 2.0 * r), colour, Vector3.ZERO)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var c := CylinderMesh.new()
			c.top_radius = r
			c.bottom_radius = r
			c.height = h
			c.radial_segments = 16
			c.rings = 1
			_mesh(g, c, colour, Vector3(sx * (w * 0.5 - r), 0, sz * (d * 0.5 - r)))
	return g


func _box(parent: Node3D, s: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = s
	return _mesh(parent, b, colour, at)


func _mesh(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MenuStage._material(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


func _glow_box(parent: Node3D, s: Vector3, colour: Color, at: Vector3, energy: float) -> MeshInstance3D:
	var mi := _box(parent, s, colour, at)
	if energy > 0.0:
		mi.material_override = _glow_material(colour, energy)
	return mi


static var _glows := {}


func _glow_material(colour: Color, energy: float) -> StandardMaterial3D:
	var key := [colour, energy]
	if not _glows.has(key):
		var m := MenuStage._material(colour).duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = energy
		_glows[key] = m
	# The rings change colour as they go: one material of their own.
	return (_glows[key] as StandardMaterial3D).duplicate() if colour == RING else _glows[key]
