class_name CityStage
extends SubViewport
## The story's way in to a heist, as one 3D place seen from above at the
## menus' axonometric angle: the town at night, bigger than the screen (streets,
## blocks of houses and shops, parks, a river, lamps: TownBuilder) and in
## it the five museums, each a museum building in its own colour
## (MuseumBuilding), a lit road from the gang's hideout past their doors;
## and inside the museum picked, its five rooms as a doll's house with the
## roof off. Tour drives it and draws the words over it. The town is bigger
## than the screen: the camera looks at the museum picked, two or three of
## them in sight (CITY_VIEW), and glides over the town to the next
## (FOLLOW_S). They zigzag (MUSEUM_SPOTS), so each step goes another way,
## up and down as well as across. Inside a museum, the camera (still
## orthographic) swings round the building to each room picked, looking at
## its wall three quarters on from a little above and closing in on it
## (room_shot); the arrows go round the building wall by wall (room_along).
##
## Everything is laid out on the town's own plan: x across the screen, z
## towards the viewer; the plan is turned a little (YAW) so the buildings
## show a front and a side.

## The town's colours, new with it: all here, to change in one place.
const SKY := Color("#110d1f")
const RING := Color("#ffc94a")
## seconds the ninja star round the museum picked takes to turn once
const STAR_TURN_S := 10.0
const LOCK := Color("#9a8fb0")
## The padlock over a shut museum: light, to stand out over the town.
const PADLOCK := Color("#e4dcf5")
const WINDOW := Color("#ffd479")
const ROUTE := Color("#ffc94a")
const ROUTE_DIM := Color("#6a5a7a")
const SHUT := 0.62
## A shut museum's padlock, this big over its dome.
const LOCK_SIZE := 1.6

## The plan's turn under the camera.
const YAW := 20.0
## Where the museums stand, in the order they open, and the gang's hideout:
## s along the river and q up from its middle (TownBuilder.frame), each on
## the block under it (TownBuilder.claim). A zigzag across the river and
## back: the first on the near bank, by the water; over the first bridge,
## the next two up in the high town, one above the other; across it to the
## fourth; and over the second bridge to the last, by the water again.
const MUSEUM_SPOTS := [Vector2(-12, -7.5), Vector2(-7, 13), Vector2(-20, 32), Vector2(15, 13), Vector2(20, -7.5)]
const HIDEOUT_SPOT := Vector2(-21, -8)
## The river runs across the screen this steeply (up for each one across).
const RIVER_TILT := 0.45
## The districts: two on the near bank, two on the high one, each its grid
## turned its own way (degrees), a block of it right on a point of its own
## (s, q up from the river: its first museum's), and where the two of each
## bank meet (s).
const DISTRICT_ANGLES := [0.0, 20.0, -16.0, 13.0]
const DISTRICT_ORIGINS := [Vector2(-12, -7.5), Vector2(20, -7.5), Vector2(-7, 13), Vector2(15, 13)]
const SPLIT_LOW := 4.0
const SPLIT_HIGH := 5.0
## How far the camera sees (orthographic height) over the town, and over a museum.
const CITY_VIEW := 30.0
## The widest screen the town is made for (2:1: 16:9, 16:10, 4:3 and the
## laptops' 18:9 fit in it); the camera keeps its height (CITY_VIEW), so the
## wider the screen the more it sees across. Wider still (21:9, 32:9), the
## sides fade into the sky (Tour): only this much is ever built (sight).
const WIDEST := 2.0
## Round all the camera can ever see, this much more kept (in the town's
## units, on the screen's plane): a safe margin. Past it nothing is built.
const SAFE := 4.0
## How quickly the camera glides to the museum picked (the larger, the
## quicker: it closes this share of the way in a second, as an exponential).
const FOLLOW_S := 2.6
const MUSEUM_VIEW := 7.0
## A room that is a whole floor (a tower's): how far beside it, left, its
## sign goes, and right, its stars.
const FLOOR_SIGN := 1.9
const FLOOR_STARS := 0.55
## How long the camera takes into a museum and back out (s).
const ZOOM_S := 1.5
## The camera over the town: this far down (pitch) and turned this way
## (yaw), in degrees: the menus' axonometric angle.
const CITY_PITCH := -35.264
const CITY_YAW := 45.0
## On a room picked, the camera swings round the museum to look at its
## window: from this far round from straight on (degrees, a three
## quarter view that shows the wall and a little of the next), this far
## down, and this close: at least ROOM_VIEW, and the window ROOM_FIT times
## over (a whole floor: with room beside it for its sign and its stars).
const ROOM_TURN := 20.0
const ROOM_PITCH := -32.0
const ROOM_VIEW := 4.8
const ROOM_FIT := 3.2
## How long it takes from one room to the next (s): Hud's pan, and up to
## this much more for a half turn round the building.
const ROOM_S := Hud.PAN_S
const ROOM_SPIN_S := 0.5
## Close on a room, all the town nearer the camera than this in front of the
## window is left out (the camera's near plane): the houses round a museum
## never stand between the camera and a wall, whichever it looks at.
const CLIP := 3.5
## ... and the town's buildings further off, taller than that, seen through
## round the line from the window to the camera, this share of the view out
## (TownBuilder.see_through): a neighbour tower never hides a room.
const SEE_THROUGH := 0.4
## How far back the camera stands from where it looks.
const BACK := 80.0
## How long the plan takes out of its room and open in front of you (s),
## and how much of the screen it fills then, across and up.
const PLAN_S := 2.1
const PLAN_FILL := Vector2(0.94, 0.76)
## How dark the town goes behind the plan.
const PLAN_VEIL := 0.8
## The lights: the lamp's and the ambient's strength over the town, and
## the one on a museum's front from close.
const KEY := 0.7
const AMBIENT := 0.55
const FRONT_LIGHT := 0.9

## the town turned under the camera: everything but the camera hangs off it
var town: Node3D
## the ground, the river, the road and the trees: what sinks away when a
## museum is gone into
var _scenery: Node3D
var _cam: Camera3D
var _env: Environment
var _key: DirectionalLight3D
var _front_light: SpotLight3D
## where the camera looks and how much it sees, eased towards the goals;
## which way it looks (degrees, as CITY_PITCH and CITY_YAW) and how much in
## front of where it looks it keeps (CLIP; INF, all of it)
var focus := Vector3.ZERO
var view := CITY_VIEW
var pitch := CITY_PITCH
var yaw := CITY_YAW
var clip := INF
## the camera swinging round the museum from room to room, and whether the
## next one is straight there (back from a heist: be_in)
var _orbit: Tween
var _jump := false
var _museums: Array[Node3D] = []
## the town's plan (TownBuilder): its districts, and where the museums and
## the hideout stand in it ([district, block])
var _builder: TownBuilder
var _lots: Array = []
var _hideout_lot: Array = []
## where each museum stands, on the town's plan (known before it is built)
var _spots: Array[Vector3] = []
## all the camera can ever see and the safe margin round it (sight), on the
## screen's plane: what the town builds
var _keep := PackedVector2Array()
var _shells: Array[Node3D] = []
var _locks: Array[Node3D] = []
var _open: Array[bool] = []
## the ninja star spinning round the museum picked, and its spotlight
var _star: MeshInstance3D
var _star_light: SpotLight3D
var picked := 0
var _t := 0.0
## the museum gone into (-1 in the town), its rooms (their windows)
var inside := -1
var _rooms: Array[Dictionary] = []
var room := -1
var _room_ring: MeshInstance3D
## round a room that is a whole floor (its window's "shape" "floor"), the
## edges of its box in light instead: its twelve bars, and how big
var _room_frame: Node3D
var _frame_size := Vector3.ZERO
var _room_light: SpotLight3D
var _tween: Tween
## everything moves at once (the tests)
var hurry := false
## only what can be seen is built (sight); the tools turn it off to compare
var cut := true
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
	_env = env
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a5a9a")
	env.ambient_light_energy = AMBIENT
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
	_key = key
	key.rotation_degrees = Vector3(-50, -25, 0)
	key.light_color = Color("#ffcf96")
	key.light_energy = KEY
	key.shadow_enabled = true
	key.shadow_blur = 1.5
	key.directional_shadow_max_distance = 80.0
	add_child(key)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-30, 150, 0)
	moon.light_color = Color("#8f9cff")
	moon.light_energy = 0.5
	add_child(moon)
	# A lamp on a museum's front, from close.
	_front_light = SpotLight3D.new()
	_front_light.light_color = Color("#ffe0b0")
	_front_light.light_energy = 0.0
	_front_light.spot_range = 16.0
	_front_light.spot_angle = 30.0
	_front_light.shadow_enabled = true
	add_child(_front_light)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.rotation_degrees = Vector3(CITY_PITCH, CITY_YAW, 0)
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
	var builder := TownBuilder.new(_scenery)
	_builder = builder
	# The river runs across the screen, a little uphill; the high bank is
	# the far one, up the screen.
	# (By their own transforms: the stage may not be in the tree yet.)
	var to_plan := town.transform.basis.inverse()
	var right3 := to_plan * _cam.transform.basis.x
	var ahead3 := to_plan * -_cam.transform.basis.z
	var right := Vector2(right3.x, right3.z).normalized()
	var ahead := Vector2(ahead3.x, ahead3.z).normalized()
	builder.along = (right + ahead * RIVER_TILT).normalized()
	builder.up = Vector2(-builder.along.y, builder.along.x)
	if builder.up.dot(ahead) < 0.0:
		builder.up = -builder.up
	builder.split_low = SPLIT_LOW
	builder.split_high = SPLIT_HIGH
	# Each grid set so that a block's middle falls right on its point.
	var origins: Array[Vector2] = []
	var half := TownBuilder.PITCH * TownBuilder.TILE * 0.5
	for i in DISTRICT_ORIGINS.size():
		var o: Vector2 = DISTRICT_ORIGINS[i]
		var at := builder.point(o.x, builder.river_at(o.x) + o.y)
		var off := Basis(Vector3.UP, deg_to_rad(DISTRICT_ANGLES[i])) * Vector3(half, 0, half)
		origins.append(at - Vector2(off.x, off.z))
	builder.plan(DISTRICT_ANGLES, origins)
	var spot := func(sq: Vector2) -> Array:
		var p := builder.point(sq.x, builder.river_at(sq.x) + sq.y)
		var i := builder.bank_of(p)
		return [i, builder.claim(i, p)]
	_lots.clear()
	_spots.clear()
	for sq in MUSEUM_SPOTS:
		var lot: Array = spot.call(sq)
		_lots.append(lot)
		var c := builder.block_top(lot[0], lot[1])
		builder.museums.append(Vector2(c.x, c.z))
		_spots.append(c + Vector3(0, 0.09, 0))
	_hideout_lot = spot.call(HIDEOUT_SPOT)
	# Only what the camera can ever see, and a safe margin round it.
	_keep = sight(WIDEST, SAFE)
	if cut:
		builder.seen = _in_sight
	builder.build()
	_hideout()
	_route(open_to)
	for m in Story.MUSEUMS.size():
		var lot := Node3D.new()
		var district: TownBuilder.District = builder.districts[_lots[m][0]]
		lot.position = _spots[m]
		lot.rotation.y = district.angle
		town.add_child(lot)
		_museums.append(lot)
		_open.append(m <= open_to)
		var shell := Node3D.new()
		lot.add_child(shell)
		_shells.append(shell)
		var body := MuseumBuilding.new()
		shell.add_child(body)
		body.build(m, m <= open_to)
		var lock := padlock()
		lock.scale = Vector3.ONE * LOCK_SIZE
		lock.position = Vector3(0, _roof_height(m) + 1.6, 0.4)
		lock.visible = m > open_to
		lot.add_child(lock)
		_locks.append(lock)
	_star = MeshInstance3D.new()
	var hole := TownBuilder.block_size() * 0.68
	_star.mesh = shuriken(hole, hole + 0.45, hole + 2.0)
	var shine := _glow_material(RING, 0.35)
	shine.vertex_color_use_as_albedo = true
	_star.material_override = shine
	town.add_child(_star)
	_star_light = SpotLight3D.new()
	_star_light.light_color = Color("#ffd9a0")
	_star_light.light_energy = 4.0
	_star_light.spot_range = 20.0
	_star_light.spot_angle = 24.0
	_star_light.rotation_degrees = Vector3(-90, 0, 0)
	town.add_child(_star_light)
	picked = clampi(pick, 0, _museums.size() - 1)
	focus = _look_at(picked)
	view = CITY_VIEW
	_place_camera()


## Whether museum m can be gone into.
func is_open(m: int) -> bool:
	return m >= 0 and m < _open.size() and _open[m]


## Pick museum m (the ring moves over, the building hops, and the camera
## glides over the town to it).
func pick(m: int) -> void:
	picked = clampi(m, 0, _museums.size() - 1)


## Where museum m's sign goes on screen: over its roof.
func museum_on_screen(m: int) -> Vector2:
	var lot := _museums[m]
	return _cam.unproject_position(lot.global_position + Vector3(0, _roof_height(m) + 3.0, 0))


## Where a point of the town (or anything) is on screen.
func on_screen(p: Vector3) -> Vector2:
	return _cam.unproject_position(p)


func camera() -> Camera3D:
	return _cam


# --- Going in and out --------------------------------------------------------------

## Into museum m: the camera glides down onto its front, the town round it
## dimming a little, and there are its rooms, a window each (MuseumBuilding),
## rooms as the tour has them ({"n", "boss", "open", "done", "shape",
## "colour"}). done() once it is all in place.
func go_in(m: int, rooms: Array, done: Callable) -> void:
	inside = m
	picked = m
	_open_rooms(m, rooms)
	if _tween:
		_tween.kill()
	var secs := 0.0 if hurry else ZOOM_S
	_tween = create_tween().set_parallel()
	var whole := _city_shot(m)
	whole.focus = _front_of(m)
	whole.view = _view_of(m)
	_tween.tween_method(_shot_step.bind(_shot(), _towards(whole)), 0.0, 1.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_dim, 0.0, 1.0, secs * 0.6).set_delay(secs * 0.4)
	_tween.chain().tween_callback(done)


## Back out to the town: the camera rises over it all again.
func go_out(done: Callable) -> void:
	if inside < 0:
		done.call()
		return
	var m := inside
	var secs := 0.0 if hurry else ZOOM_S * 0.8
	if _tween:
		_tween.kill()
	if _orbit:
		_orbit.kill()
	_tween = create_tween().set_parallel()
	_tween.tween_method(_shot_step.bind(_shot(), _towards(_city_shot(m))), 0.0, 1.0, secs).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_dim, 1.0, 0.0, secs * 0.6)
	_tween.chain().tween_callback(func() -> void:
		inside = -1
		room = -1
		_rooms.clear()
		_room_ring.visible = false
		_room_frame.visible = false
		_room_light.visible = false
		_body(m).build(m, _open[m])
		done.call())


## Straight into museum m, no glide (back from a heist): its first room
## picked is straight there too.
func be_in(m: int, rooms: Array) -> void:
	var was := hurry
	hurry = true
	go_in(m, rooms, func() -> void: pass)
	_tween.custom_step(1.0)
	hurry = was
	_jump = true


## Where the camera looks at museum m from close: the middle of its front.
func _front_of(m: int) -> Vector3:
	var lot := _museums[m]
	var body := _body(m)
	return lot.global_transform * Vector3(0, body.look_y, body.front_z)


## How much the camera sees of museum m from close: its building's own
## (a tall one sees more), or MUSEUM_VIEW.
func _view_of(m: int) -> float:
	var v: float = _body(m).view
	return v if v > 0.0 else MUSEUM_VIEW


## The town round the museum gone into, a little darker the nearer it is
## to done (0 as it is, 1 at its darkest): the museum's own lamps do the rest.
func _dim(k: float) -> void:
	_env.ambient_light_energy = lerpf(AMBIENT, AMBIENT * 0.55, k)
	_key.light_energy = lerpf(KEY, KEY * 0.6, k)
	_front_light.light_energy = FRONT_LIGHT * k
	_aim_front_light()


## The lamp on the museum from close: from over the camera's shoulder onto
## what it looks at, so it lights whichever wall the camera faces.
func _aim_front_light() -> void:
	if inside < 0:
		return
	var back := _cam.basis.z
	_front_light.position = focus + Vector3(back.x, 0.0, back.z).normalized() * 5.0 + Vector3(0, 4.0, 0)
	_front_light.look_at(focus)


## The camera as it is: where it looks, how much it sees, which way, and
## how much in front of where it looks it keeps (a shot: _shot_step).
func _shot() -> Dictionary:
	return {"focus": focus, "view": view, "pitch": pitch, "yaw": yaw, "clip": clip}


## The camera over the town, museum m picked.
func _city_shot(m: int) -> Dictionary:
	return {"focus": _look_at(m), "view": CITY_VIEW, "pitch": CITY_PITCH, "yaw": CITY_YAW, "clip": INF}


## Shot `to` with its yaw the nearest way round from the camera's now.
func _towards(to: Dictionary) -> Dictionary:
	var out := to.duplicate()
	out.yaw = yaw + wrapf(float(to.yaw) - yaw, -180.0, 180.0)
	return out


## How far from one shot to another the camera is (0 to 1): where it looks
## slides straight from one to the other while it turns as the shots say
## (_towards: the shortest way), so from a wall to another it swings round
## the building (orthographic: where it looks may cross the building's
## inside, and the building still shows whole); the view eased in steps of
## scale so the zoom feels even; the town in front of it left out (clip)
## only near the end of the way in to a room, and back at once on the way out.
func _shot_step(k: float, a: Dictionary, b: Dictionary) -> void:
	focus = (a.focus as Vector3).lerp(b.focus, k)
	view = exp(lerpf(log(float(a.view)), log(float(b.view)), k))
	pitch = lerpf(a.pitch, b.pitch, k)
	yaw = lerpf(a.yaw, b.yaw, k)
	var ca: float = a.clip
	var cb: float = b.clip
	if is_inf(cb):
		clip = ca if k < 0.05 and not is_inf(ca) else INF
	elif is_inf(ca):
		clip = INF if k < 0.6 else lerpf(BACK, cb, smoothstep(0.6, 1.0, k))
	else:
		clip = lerpf(ca, cb, k)
	_place_camera()


func _place_camera() -> void:
	_cam.rotation_degrees = Vector3(pitch, yaw, 0)
	_cam.size = view
	_cam.position = focus + _cam.basis.z * BACK
	_cam.near = 0.1 if is_inf(clip) else maxf(0.1, BACK - clip)
	if _builder:
		var see := not is_inf(clip) or (sheet != null and inside >= 0)
		_builder.see_through(focus, _cam.basis.z, view * SEE_THROUGH if see else 0.0)
	_aim_front_light()


## The camera's turn over the town (CITY_PITCH, CITY_YAW).
static func city_basis() -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(CITY_PITCH), deg_to_rad(CITY_YAW), 0))


## Where the camera looks over the town with museum m picked: at it, a
## little up the screen to leave room over it for its sign.
func _look_at(m: int) -> Vector3:
	return town.transform * _spots[m] + Vector3(0, 0.5, 0) + city_basis().y * 2.4


## A point (in the stage's own space) on the town's screen plane: across
## and up, as the camera sees it over the town, in the town's units (the
## town is built for this look: sight).
func on_plane(p: Vector3) -> Vector2:
	var b := city_basis()
	return Vector2(p.dot(b.x), p.dot(b.y))


## All the camera can ever see of the town on a screen `aspect` wide for
## its height, on the screen's plane (on_plane): its look at each museum
## and every way between them (the camera glides straight from one to the
## next, and may turn mid-way, so anywhere between them all), and `margin`
## more all round. Wider screens see more: WIDEST sees it all.
func sight(aspect: float, margin := 0.0) -> PackedVector2Array:
	var half := Vector2(CITY_VIEW * aspect, CITY_VIEW) * 0.5
	var points := PackedVector2Array()
	for m in _spots.size():
		var f := on_plane(_look_at(m))
		for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			points.append(f + half * c)
	var hull := Geometry2D.convex_hull(points)
	hull.remove_at(hull.size() - 1)
	if margin > 0.0:
		hull = Geometry2D.offset_polygon(hull, margin, Geometry2D.JOIN_MITER)[0]
	return hull


## Whether something at a point of the town's plan, `r` round it, falls in
## what the town builds (_keep).
func _in_sight(at: Vector3, r: float) -> bool:
	var p := on_plane(town.transform * at)
	if Geometry2D.is_point_in_polygon(p, _keep):
		return true
	for i in _keep.size():
		var a := _keep[i]
		var b := _keep[(i + 1) % _keep.size()]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < r:
			return true
	return false


## Gliding (not going in or out): nothing between the camera and the
## museum picked but the way there.
func _gliding() -> bool:
	return inside < 0 and not (_tween and _tween.is_running())


func _process(dt: float) -> void:
	_t += dt
	# Over the town, the camera follows the museum picked.
	if _gliding() and not _museums.is_empty():
		focus = focus.lerp(_look_at(picked), 1.0 - exp(-dt * (40.0 if hurry else FOLLOW_S)))
		_place_camera()
	# The picked museum hops a little and a ninja star spins round it.
	for m in _museums.size():
		var shell := _shells[m]
		var hop := 0.0
		if m == picked and inside < 0:
			hop = 0.18 + absf(sin(_t * 3.2)) * 0.12
		shell.get_child(0).position.y = lerpf(shell.get_child(0).position.y, hop, 1.0 - exp(-dt * 12.0))
		var lock := _locks[m]
		if lock.visible:
			lock.rotation.y = sin(_t * 1.6 + m) * 0.35
			lock.position.y = _roof_height(m) + 1.6 + sin(_t * 2.0 + m) * 0.08
	if _star and not _museums.is_empty():
		var lot := _museums[picked]
		_star.visible = inside < 0
		_star_light.visible = inside < 0 and _open[picked]
		_star.position = _star.position.lerp(lot.position + Vector3(0, 0.05, 0), 1.0 - exp(-dt * 10.0))
		# Up +Y, seen from above: turning positive is anticlockwise on screen.
		_star.rotation.y = fmod(_t * TAU / STAR_TURN_S, TAU)
		_star.scale = Vector3.ONE * (1.0 + sin(_t * 4.0) * 0.03)
		var star := _star.material_override as StandardMaterial3D
		star.albedo_color = RING if _open[picked] else LOCK
		star.emission = star.albedo_color
		_star_light.position = _star.position + Vector3(0, 9, 0)
	if inside >= 0:
		_animate_rooms(dt)


# --- The town ---------------------------------------------------------------------

## The gang's hideout: a little house with a sock hung out as a flag, on
## its block's corner nearest the museums.
func _hideout() -> void:
	var g := Node3D.new()
	var h := TownBuilder.block_size() * 0.5 - 0.9
	var district: TownBuilder.District = _builder.districts[_hideout_lot[0]]
	g.position = _builder.block_top(_hideout_lot[0], _hideout_lot[1]) + district.basis() * Vector3(h, 0.09, h)
	g.rotation.y = district.angle
	g.scale = Vector3.ONE * 1.2
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


## The way from the hideout past every museum's door, along the streets
## and over the bridges (TownBuilder.route): a glowing line as far as the
## last museum open, dim after.
func _route(open_to: int) -> void:
	var stops: Array = [_hideout_lot]
	stops.append_array(_lots)
	for i in stops.size() - 1:
		var pts := _builder.route(stops[i], stops[i + 1])
		var lit := i <= open_to
		for k in pts.size() - 1:
			_dashes(pts[k], pts[k + 1], ROUTE if lit else ROUTE_DIM, lit)


## A dashed line down the middle of the street from a to b, up a bridge's
## slope too (the way's points are at the height of what it runs on:
## TownBuilder.route).
func _dashes(a: Vector3, b: Vector3, colour: Color, lit: bool) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var lift := Vector3(0, 0.06, 0)
	var steps := maxi(1, int(length / 0.5))
	var turn := Basis.looking_at((b - a).normalized(), Vector3.UP)
	for k in steps:
		if k % 2 == 1:
			continue
		var p0 := a.lerp(b, float(k) / steps)
		var p1 := a.lerp(b, float(k + 1) / steps)
		var mi := _box(_scenery, Vector3(0.12, 0.03, p0.distance_to(p1)), colour, (p0 + p1) * 0.5 + lift)
		mi.basis = turn
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if lit:
			mi.material_override = _glow_material(colour, 1.6)

## How tall a museum is, for its sign and its padlock.
func _roof_height(m: int) -> float:
	return _body(m).top


# --- The museums ------------------------------------------------------------------

## A padlock floating over a shut museum.
static func padlock() -> Node3D:
	var g := Node3D.new()
	var body := BoxMesh.new()
	body.size = Vector3(0.8, 0.65, 0.3)
	_part(g, body, PADLOCK, Vector3.ZERO)
	var shackle := TorusMesh.new()
	shackle.inner_radius = 0.2
	shackle.outer_radius = 0.3
	var s := _part(g, shackle, PADLOCK.darkened(0.15), Vector3(0, 0.4, 0))
	s.rotation_degrees.x = 90
	var hole := BoxMesh.new()
	hole.size = Vector3(0.1, 0.2, 0.02)
	_part(g, hole, Color("#1c1210"), Vector3(0, -0.03, 0.16))
	return g


static func _part(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = MenuStage._material(colour)
	mi.position = at
	parent.add_child(mi)
	return mi


## A five-pointed ninja star lying flat on the ground (y up): a round hole
## of radius hole in the middle, straight-edged blades whose notches reach
## out to valley and whose sharp tips reach out to tip. The blades rise to a
## ridge along each point and slope down to a bevelled rim, flat-shaded and
## two-toned in vertex colours: each point's one side lit, the other in shade.
static func shuriken(hole: float, valley: float, tip: float) -> ArrayMesh:
	const POINTS := 5
	const STEPS := 6  # per edge, tip to notch
	const BEVEL := 0.16
	const RIDGE := 0.3  # height at the hole and along each point
	const FLANK := 0.12  # height of the top's rim at the notches
	const SHADE := 0.62  # the shaded side of each point
	const EDGE := 0.55  # the bevel and the walls
	const RIM := 0.03  # height of the bevel's foot
	# The outline, one tip to the next notch to the next tip...: each
	# edge a straight line, sampled at even angles along it.
	var angles := PackedFloat32Array()
	var outer: Array[Vector2] = []
	var top: Array[Vector2] = []
	var lift := PackedFloat32Array()
	var tone := PackedFloat32Array()
	for e in POINTS * 2:
		var a0 := TAU * e / (POINTS * 2)
		var a1 := TAU * (e + 1) / (POINTS * 2)
		var p0 := Vector2.from_angle(a0) * (tip if e % 2 == 0 else valley)
		var p1 := Vector2.from_angle(a1) * (valley if e % 2 == 0 else tip)
		for k in STEPS:
			var a := lerpf(a0, a1, float(k) / STEPS)
			# Where the ray at angle a crosses the edge p0-p1.
			var d := Vector2.from_angle(a)
			var hit: Variant = Geometry2D.line_intersects_line(Vector2.ZERO, d, p0, p1 - p0)
			var p: Vector2 = hit if hit != null else p0
			angles.append(a)
			outer.append(p)
			top.append(p - d * BEVEL)
			# Highest along a point, lowest at a notch.
			var f := float(k) / STEPS
			lift.append(lerpf(RIDGE, FLANK, f) if e % 2 == 0 else lerpf(FLANK, RIDGE, f))
			tone.append(1.0 if e % 2 == 0 else SHADE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := angles.size()
	for i in n:
		var j := (i + 1) % n
		var h0 := Vector2.from_angle(angles[i]) * hole
		var h1 := Vector2.from_angle(angles[j]) * hole
		var hi0 := Vector3(h0.x, RIDGE, h0.y)
		var hi1 := Vector3(h1.x, RIDGE, h1.y)
		var t0 := Vector3(top[i].x, lift[i], top[i].y)
		var t1 := Vector3(top[j].x, lift[j], top[j].y)
		var r0 := Vector3(outer[i].x, RIM, outer[i].y)
		var r1 := Vector3(outer[j].x, RIM, outer[j].y)
		var f0 := Vector3(outer[i].x, 0, outer[i].y)
		var f1 := Vector3(outer[j].x, 0, outer[j].y)
		var b0 := Vector3(h0.x, 0, h0.y)
		var b1 := Vector3(h1.x, 0, h1.y)
		_quad(st, hi0, hi1, t1, t0, Color(tone[i], tone[i], tone[i]))  # the top, hole to rim
		_quad(st, t0, t1, r1, r0, Color(EDGE, EDGE, EDGE))  # the bevel
		_quad(st, r0, r1, f1, f0, Color(EDGE, EDGE, EDGE))  # the outer side
		_quad(st, b0, b1, hi1, hi0, Color(EDGE, EDGE, EDGE))  # the hole's wall
	st.generate_normals()
	return st.commit()


## Quad a-b-c-d, its front the side it winds anticlockwise from, as two
## triangles wound the other way round (Godot's front faces wind clockwise).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
	st.set_color(tint)
	for v: Vector3 in [a, c, b, a, d, c]:
		st.add_vertex(v)


## Museum m's padlock back on, to pop off (unlock) as the town shows it.
func relock(m: int) -> void:
	if m >= 0 and m < _locks.size():
		_locks[m].visible = true
		_locks[m].scale = Vector3.ONE * LOCK_SIZE


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

func _body(m: int) -> MuseumBuilding:
	return _shells[m].get_child(0) as MuseumBuilding


## The museum gone into with its rooms in its windows: rooms is one entry
## per heist in it, {"n", "boss", "open", "done", "shape", "colour"}. Only
## the rooms reached (open) show as rooms, each piece in its window, and can
## be picked; the rest are just windows (MuseumBuilding: in the hall, dark
## with a padlock; elsewhere, windows like any other).
func _open_rooms(m: int, rooms: Array) -> void:
	_rooms.clear()
	room = -1
	var body := _body(m)
	body.build(m, _open[m], rooms)
	for i in rooms.size():
		var r: Dictionary = rooms[i]
		_rooms.append({"n": r.n, "boss": r.boss, "open": r.open, "window": body.windows[i]})
	if _room_ring == null:
		# A ring of light round the window picked, standing on its wall.
		_room_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.5
		torus.outer_radius = 0.57
		torus.rings = 48
		_room_ring.mesh = torus
		_room_ring.material_override = _glow_material(RING, 3.5)
		town.add_child(_room_ring)
		_room_light = SpotLight3D.new()
		_room_light.light_color = Color("#ffe2b0")
		_room_light.light_energy = 5.0
		_room_light.spot_range = 8.0
		_room_light.spot_angle = 14.0
		town.add_child(_room_light)
		_room_frame = Node3D.new()
		for k in 12:
			var bar := MeshInstance3D.new()
			bar.mesh = BoxMesh.new()
			bar.material_override = _room_ring.material_override
			_room_frame.add_child(bar)
		town.add_child(_room_frame)
	_room_ring.visible = false
	_room_frame.visible = false
	_room_light.visible = false


## Pick room i (0-based) of the museum gone into: only one reached (the
## rest are not rooms yet, just windows).
func pick_room(i: int) -> void:
	if not room_open(i):
		return
	room = i
	if inside >= 0:
		_body(inside).pick(room)
		_swing_to(i)


## The camera round the museum to room i: turning, rising or falling and
## closing in all at once, on Hud's curve, longer the further round it goes.
func _swing_to(i: int) -> void:
	if _orbit:
		_orbit.kill()
	var to := _towards(room_shot(i))
	var turn := absf(float(to.yaw) - yaw)
	var secs := 0.0 if hurry or _jump else ROOM_S + ROOM_SPIN_S * minf(turn / 180.0, 1.0)
	_jump = false
	if secs <= 0.0:
		_shot_step(1.0, _shot(), to)
		return
	_orbit = create_tween()
	_orbit.tween_method(_shot_step.bind(_shot(), to), 0.0, 1.0, secs).set_trans(Hud.TRANS).set_ease(Hud.EASE)


## The camera, done swinging to the room picked (the plan comes out of a
## window where it will be seen).
func _settle() -> void:
	if _orbit and _orbit.is_running():
		_orbit.custom_step(INF)


## How the camera looks at room i: its window from ROOM_TURN round to the
## right of straight on and ROOM_PITCH down, close enough to see it well and
## some of the building round it, its sign over it and its stars under it
## on screen (a whole floor: its sign and stars beside it).
func room_shot(i: int) -> Dictionary:
	var face := room_face(i)
	var out := Vector2(face.z.x, face.z.z)
	if out.length() < 0.01:
		out = Vector2(face.y.x, face.y.z)
	var size: Vector2 = _rooms[i].window.size
	var aspect := float(self.size.x) / maxf(self.size.y, 1.0)
	var wide := size.x * ROOM_FIT
	var tall := (size.y + size.x * 0.5) * ROOM_FIT
	if _is_floor(i):
		wide = size.x + (FLOOR_SIGN + 1.6) * 2.0
		tall = size.y * 2.2
	var v := maxf(ROOM_VIEW, maxf(tall, wide / aspect))
	# Round to the right of a wall, but a side's from its front's end: the
	# front has its square or its garden before it, open to see from; the
	# back of a side has the next houses close by.
	var turn := ROOM_TURN
	var n := _museums[inside].global_basis.orthonormalized().inverse() * face.z
	if absf(n.x) > 0.5:
		turn = -ROOM_TURN * signf(n.x)
	return {"focus": room_centre(i) + Vector3(0, v * 0.06, 0), "view": v, "pitch": ROOM_PITCH,
		"yaw": rad_to_deg(atan2(out.x, out.y)) + turn, "clip": CLIP}


## Whether room i of the museum gone into is reached: shown as a room, to
## pick, with its ring, its sign and its stars.
func room_open(i: int) -> bool:
	return i >= 0 and i < _rooms.size() and bool(_rooms[i].open)


## Room i's window, in the world: its middle; where its sign goes on
## screen (over it), and its stars (under its sill, out from its wall).
func room_centre(i: int) -> Vector3:
	return (_rooms[i].window.node as Node3D).global_position


## Which way room i's window looks, in the world: x across it, y up, z out
## of its wall (the front's, or a side's).
func room_face(i: int) -> Basis:
	return (_rooms[i].window.node as Node3D).global_basis.orthonormalized()


func room_on_screen(i: int) -> Vector2:
	var size: Vector2 = _rooms[i].window.size
	if _is_floor(i):
		# A whole floor: its sign beside it, on the left, not over the next.
		var face := room_face(i)
		return _cam.unproject_position(room_centre(i) - face.x * (size.x * 0.5 + FLOOR_SIGN) + face.y * size.y * 0.25)
	return _cam.unproject_position(room_centre(i) + room_face(i).y * (size.y * 0.5 + size.x * 0.5 + 0.2))


func room_foot_on_screen(i: int) -> Vector2:
	var size: Vector2 = _rooms[i].window.size
	var face := room_face(i)
	if _is_floor(i):
		# A whole floor: its stars beside it, on the right.
		return _cam.unproject_position(room_centre(i) + face.x * (size.x * 0.5 + FLOOR_STARS) + face.y * 0.12)
	return _cam.unproject_position(room_centre(i) - face.y * (size.y * 0.5 + 0.12) + face.z * 0.2)


## Where room i's window is across the screen now, left to right.
func room_x(i: int) -> float:
	return room_centre(i).dot(_cam.global_basis.x)


## Whether room i's window faces the camera now (not round the back of the
## building): only then its stars show and the mouse finds it.
func room_seen(i: int) -> bool:
	return room_face(i).z.dot(_cam.global_basis.z) > 0.05


## Whether room i is a whole floor of its building (a tower's), not a
## window in a wall.
func _is_floor(i: int) -> bool:
	return String(_rooms[i].window.get("shape", "")) == "floor"


## Room i's window in its building's own space: x across its front, y up,
## z out of its front.
func _room_local(i: int) -> Vector3:
	return _museums[inside].global_transform.affine_inverse() * room_centre(i)


## Whether the museum's rooms are one over another (a tower's floors)
## rather than round it: they spread further up than across, the building
## as it stands (not as the camera sees it just now).
func rooms_stacked() -> bool:
	if _rooms.is_empty() or inside < 0:
		return false
	var low := INF
	var high := -INF
	var across := 0.0
	for i in _rooms.size():
		var p := _room_local(i)
		low = minf(low, p.y)
		high = maxf(high, p.y)
		for j in _rooms.size():
			var q := _room_local(j)
			across = maxf(across, Vector2(p.x, p.z).distance_to(Vector2(q.x, q.z)))
	return high - low > across


## Which way room i's wall looks, round its building (degrees): 0 its
## front, 90 its right side (as seen from the front), 180 its back, -90
## its left; from -135 (the back's left corner) round to 225, so the way
## round starts down the left side, crosses the front, goes down the right
## and ends across the back.
func room_wall(i: int) -> float:
	var n := _museums[inside].global_basis.orthonormalized().inverse() * room_face(i).z
	var a := rad_to_deg(atan2(n.x, n.z))
	return a + 360.0 if a < -135.0 else a


## Where room i is on the way round its museum the arrows go (right: on
## round, as walking along its walls with them in front of you): wall by
## wall (room_wall), along each from its left to its right as seen from out
## in front of it; or, stacked (rooms_stacked), bottom to top. Where the
## building stands, not where the camera is: the order stays put while the
## camera swings round.
func room_along(i: int) -> float:
	if rooms_stacked():
		return _room_local(i).y
	var wall := snappedf(room_wall(i), 5.0)
	var face := _museums[inside].global_basis.orthonormalized().inverse() * room_face(i)
	var along := _room_local(i).dot(face.x)
	return wall * 100.0 + clampf(along, -49.0, 49.0)


## Room i's window, as the world has it: its middle, its size, and the
## way its wall faces (the plan comes out of it).
func room_window(i: int) -> Dictionary:
	return {"centre": room_centre(i), "size": _rooms[i].window.size, "basis": room_face(i)}


## All the rooms of the museum gone into, reached or not (room_open).
func room_count() -> int:
	return _rooms.size()


func _animate_rooms(dt: float) -> void:
	if room < 0 or _room_ring == null:
		return
	var w: Dictionary = _rooms[room].window
	var size: Vector2 = w.size
	var face := room_face(room)
	if _is_floor(room):
		_frame_floor(dt, w)
		return
	_room_frame.visible = false
	# Round the window (and its arch, if it has one), just out from its
	# wall and lying on it, whichever way it faces.
	var arch: bool = w.get("arch", true)
	var tall := size.y + (size.x * 0.5 if arch else 0.1)
	var mid := room_centre(room) + face.z * 0.1 + face.y * (size.x * 0.25 if arch else 0.02)
	var r0 := 0.53
	var breathe: float = 1.0 + sin(_t * 4.0) * 0.04
	var spread := Basis.from_scale(Vector3((size.x * 0.5 + 0.2) / r0, 1, (tall * 0.5 + 0.18) / r0) * breathe)
	# A window deep in a porch (its door behind columns: "near", how far):
	# its ring drawn that much nearer the camera, straight towards it, over
	# what stands before it; the camera is orthographic, so on screen it is
	# still round the window.
	var near: float = w.get("near", 0.0)
	var goal := Transform3D(face * Basis(Vector3.RIGHT, PI / 2) * spread, mid + _cam.global_basis.z * near)
	# It glides from window to window on the same wall; round a corner (the
	# front to a side) it jumps, not to cut through the building.
	var was := _room_ring.global_transform
	if _room_ring.visible and was.basis.y.normalized().dot(face.z) > 0.99:
		goal = was.interpolate_with(goal, 1.0 - exp(-dt * 12.0))
	_room_ring.global_transform = goal
	var ring := _room_ring.material_override as StandardMaterial3D
	ring.albedo_color = RING if _rooms[room].open else LOCK
	ring.emission = ring.albedo_color
	_room_ring.visible = true
	_room_light.visible = _rooms[room].open
	# Its lamp out in front of its wall, a little above.
	_room_light.global_position = mid + face.z * 4.0 + face.y * 2.5
	_room_light.look_at(mid)


## Round a room that is a whole floor: the edges of its whole box in light
## (its "volume", round its node; without one, a frame round its front),
## a little out from it, breathing; it glides from floor to floor. Its
## lamp out in front, a little above.
func _frame_floor(dt: float, w: Dictionary) -> void:
	var size: Vector2 = w.size
	var face := room_face(room)
	var node := w.node as Node3D
	var volume: AABB = w.get("volume", AABB(Vector3(-size.x * 0.5, -size.y * 0.5, -0.05), Vector3(size.x, size.y, 0.1)))
	var mid := node.global_transform * volume.get_center()
	var breathe: float = 1.0 + sin(_t * 4.0) * 0.015
	var goal_size := (volume.size + Vector3(0.08, 0.08, 0.08)) * breathe
	var goal := Transform3D(face, mid)
	var was := _room_frame.global_transform
	if _room_frame.visible and was.basis.z.normalized().dot(face.z) > 0.99:
		goal = was.interpolate_with(goal, 1.0 - exp(-dt * 12.0))
		goal_size = _frame_size.lerp(goal_size, 1.0 - exp(-dt * 12.0))
	_frame_size = goal_size
	_room_frame.global_transform = goal
	# Four edges along each axis, one at each corner of the other two.
	var t := 0.05
	var half := _frame_size * 0.5
	var bars := _room_frame.get_children()
	for k in 12:
		var bar := bars[k] as MeshInstance3D
		var axis := k >> 2
		var a := -1.0 if k % 2 == 0 else 1.0
		var b := -1.0 if ((k >> 1) & 1) == 0 else 1.0
		var long := _frame_size[axis] + t
		match axis:
			0:
				(bar.mesh as BoxMesh).size = Vector3(long, t, t)
				bar.position = Vector3(0, a * half.y, b * half.z)
			1:
				(bar.mesh as BoxMesh).size = Vector3(t, long, t)
				bar.position = Vector3(a * half.x, 0, b * half.z)
			_:
				(bar.mesh as BoxMesh).size = Vector3(t, t, long)
				bar.position = Vector3(a * half.x, b * half.y, 0)
	var ring := _room_ring.material_override as StandardMaterial3D
	ring.albedo_color = RING if _rooms[room].open else LOCK
	ring.emission = ring.albedo_color
	_room_ring.visible = false
	_room_frame.visible = true
	_room_light.visible = _rooms[room].open
	var front := room_centre(room)
	_room_light.global_position = front + face.z * 4.0 + face.y * 2.5
	_room_light.look_at(front)


## A little crown: a gold band with three points; k times as big.
static func crown(parent: Node3D, at: Vector3, colour: Color, k := 1.0) -> void:
	var band := BoxMesh.new()
	band.size = Vector3(0.36, 0.1, 0.04) * k
	_part(parent, band, colour, at)
	for i in 3:
		var p := PrismMesh.new()
		p.size = Vector3(0.1, 0.14, 0.04) * k
		_part(parent, p, colour, at + Vector3(-0.13 + i * 0.13, 0.12, 0) * k)


# --- The plan ---------------------------------------------------------------------

## Out of the room picked comes its plan: out of its window, glowing,
## folded up; flies to the front, turning to face you; and opens out over
## the whole screen, the town darkening behind it. done() once it is open.
## plan: Hud.plan_map's picture, tile_px pixels a tile in it.
func raise_plan(plan: Image, tile_px: float, done: Callable) -> void:
	drop_plan()
	_settle()
	# Nothing left out in front with the plan out (it flies to well in front
	# of the town, under its veil); only the town's buildings in the way of
	# the window still seen through, for it to come out of.
	clip = INF
	sheet = PlanSheet.new()
	_place_camera()
	add_child(sheet)
	sheet.print_plan(plan, tile_px)
	var window := room_window(room)
	# In the window, facing out of it, as wide as it; out it comes.
	var front := (window.basis as Basis).orthonormalized()
	_sheet_from = {"at": window.centre + front.z * 0.1, "turn": front.get_rotation_quaternion(),
		"size": minf(window.size.x * 0.9, window.size.y * 0.9 / sheet.tall), "out": front.z * 0.9}
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


## The plan back into its window, folding up as it goes (back to the museum).
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
		if inside >= 0:
			clip = CLIP
			_place_camera()
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
	var lifted: Vector3 = _sheet_from.at + (_sheet_from.out as Vector3) * rise
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
