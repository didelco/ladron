class_name LessonStage
extends MenuStage
## One little scene for each thing a night teaches (Story.LESSONS), on the
## same toy island as the menus but acted out: the heist done start to
## finish, a guard's torch sweeping past someone hiding, footsteps rippling
## out, a bin knocked over to pull a guard away... Each is a loop of a few
## seconds, worked out from the time alone, so it never drifts.
##
## Every lesson has a scene of its own: none borrows another's. Each ends
## where the action is, and fades to black before it starts again.

const GANG := [[Color("#2ec4a6"), Color("#12705f")], [Color("#f0a13a"), Color("#8a5410")], [Color("#b07cff"), Color("#5b3a99")], [Color("#4dabf7"), Color("#1c5d99")]]
const ORANGE := Color("#ff922b")
const RED := Color("#ff3048")
const BEAM := Color("#ffe7a8")
## Crouched and on all fours, as a Figure's posture.
const CROUCH := 0.55
## The game's case, shrunk to the dioramas' figures.
const CASE_SCALE := 0.7
const CRAWL := 1.0

## How long each lesson's loop lasts, in seconds.
const LOOPS := {"heist": 6.8, "heist2": 7.2, "heist3": 7.2, "heist4": 7.2, "guard": 7.6, "torch": 8.0, "noise": 9.0,
	"props": 9.0, "case_alarm": 8.0, "two": 7.0, "lights": 8.0, "big": 9.0, "finale": 6.0}

var _crew: Array[Figure] = []
var _watch: Array[Figure] = []
## named pieces the loop moves about: gem, meters, labels, cones, lights...
var _bits := {}
## sound rings on their way out: [ring, born, reach]
var _rings: Array = []
var _lamp_light: OmniLight3D
## black over the whole card, for the fade in and out of every loop
var _fade: ColorRect


func _build() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.size = Vector2(size)
	layer.add_child(_fade)
	_frame(3.5, 0.45)
	_island(3.5, 2.6, Color("#3a2c3e"), WOOD)
	match arg:
		"heist": _heist(1)
		"heist2": _heist(2)
		"heist3": _heist(3)
		"heist4": _heist(4)
		"guard": _guard_round()
		"torch": _torch()
		"noise": _noise()
		"props": _props()
		"case_alarm": _case_alarm()
		"two": _two()
		"lights": _lights()
		"big": _big()
		"finale": _finale()


func _pose(dt: float) -> void:
	_play(0.0, dt)
	_fade.color.a = 0.0


func _animate(dt: float) -> void:
	var loop: float = LOOPS.get(arg, 8.0)
	var u := fmod(_t, loop)
	_play(u, dt)
	_age_rings()
	# In from black, and out to black at the end of the loop.
	_fade.size = Vector2(size)
	_fade.color.a = maxf(1.0 - clampf(u / 0.4, 0.0, 1.0), clampf((u - (loop - 0.7)) / 0.6, 0.0, 1.0))


func _play(u: float, dt: float) -> void:
	match arg:
		"heist", "heist2", "heist3", "heist4": _play_heist(u, dt)
		"guard": _play_guard(u, dt)
		"torch": _play_torch(u, dt)
		"noise": _play_noise(u, dt)
		"props": _play_props(u, dt)
		"case_alarm": _play_case_alarm(u, dt)
		"two": _play_two(u, dt)
		"lights": _play_lights(u, dt)
		"big": _play_big(u, dt)
		"finale": _play_finale(u, dt)


# --- The heist: to the case, still beside it while it opens, the piece held high -----

## Spread out, so each one's job reads on its own: the case on the left, the
## alarm panel far off on the right (the second, with four, at the back),
## the way in at the front.
const CASE_AT := Vector3(-1.0, 0, 0.45)
const PANEL_AT := [Vector3(1.1, 0, -0.55), Vector3(-0.95, 0, -1.0)]
const DOOR_AT := Vector3(0.95, 0, 1.0)


func _heist(n: int) -> void:
	_case(CASE_AT, n >= 3)
	if n >= 2:
		_panel(PANEL_AT[0])
	if n >= 4:
		_panel(PANEL_AT[1])
	for i in n:
		_crew.append(_thief(i))


func _play_heist(u: float, dt: float) -> void:
	var n := _crew.size()
	# In from the front, each to their place; the case gives while they hold.
	var open_from := 2.3
	var open_to := 4.4 if n == 1 else 4.8
	# Beside the case and the panels, never in front of them: the camera must
	# see them.
	var at_case := [CASE_AT + Vector3(0.55, 0, 0.0), CASE_AT + Vector3(0.0, 0, -0.55)]
	var at_panel := [PANEL_AT[0] + Vector3(-0.5, 0, 0.0), PANEL_AT[1] + Vector3(0.4, 0, -0.2)]
	var spots: Array = [at_case[0]]
	if n == 2:
		spots = [at_panel[0], at_case[0]]
	elif n == 3:
		spots = [at_panel[0], at_case[1], at_case[0]]
	elif n == 4:
		spots = [at_panel[0], at_case[1], at_case[0], at_panel[1]]
	for i in n:
		var door := DOOR_AT + Vector3((i - (n - 1) / 2.0) * 0.22, 0, (i - (n - 1) / 2.0) * -0.22)
		var keys := [[0.0, door], [0.2 + i * 0.15, door], [2.1, spots[i]]]
		_walk(_crew[i], keys, u, 0.0, dt)
		# The job done, everyone hops for joy where they stand.
		if u > open_to:
			_hop(_crew[i], u * 9.0 + i, 0.08)
	# Whoever is at an alarm panel holds it: it glows while held.
	var held := u > 2.1
	for light in _bits.get("panel_lights", []):
		(light as OmniLight3D).light_energy = (1.5 + sin(u * 12.0) * 0.8) if held else 0.0
	# The meter(s) over the case fill while the thief keeps still.
	var fill := clampf((u - open_from) / (open_to - open_from), 0.0, 1.0)
	for m in _bits.meters:
		_meter_fill(m, fill)
	# The piece: in its case, then over the head of whoever took it.
	var gem: Node3D = _bits.gem
	var carrier: Figure = _crew[0] if n == 1 else _crew[2 if n >= 3 else 1]
	if u < open_to:
		gem.position = CASE_AT + Vector3(0, 0.42 * CASE_SCALE + 0.06, 0)
		gem.scale = Vector3.ONE
	else:
		# Held up high by whoever took it.
		var up := clampf((u - open_to) / 0.4, 0.0, 1.0)
		gem.position = (CASE_AT + Vector3(0, 0.42 * CASE_SCALE + 0.06, 0)).lerp(carrier.position + Vector3(0, 1.05 + sin(u * 8.0) * 0.03, 0), up)
		gem.scale = Vector3.ONE * (1.0 + 0.3 * up)
	gem.rotation.y = u * 2.0


# --- The guard's torch: near it sees you always; far only standing; a case hides you --

const GUARD_AT := Vector3(-1.35, 0, -0.85)
const GUARD_REACH := 2.4
## The case stands a little to one side of the beam, still in its light.
const CASE_SIDE := -0.25


func _guard_round() -> void:
	_watch.append(_guard(true, GUARD_REACH))
	_crew.append(_thief(0))
	_case(_torch_point(1.7, CASE_SIDE), false)
	_bits.alert = _word("!", RED, 0.009)


## A point in the guard's torchlight: this far along the beam, this far to its side.
func _torch_point(d: float, side: float) -> Vector3:
	var dir := Vector3(0.8, 0, 0.6).normalized()
	return GUARD_AT + dir * d + Vector3(-dir.z, 0, dir.x) * side


func _play_guard(u: float, dt: float) -> void:
	var sway := sin(u * 1.2) * 0.1
	var heading := atan2(0.6, 0.8) + sway
	_watch[0].set_state(GUARD_AT, heading, 0.0, dt)
	# Standing far off: seen. Crouched there: not. Crouched close: seen. On
	# all fours behind the case: hidden, even in the light.
	# The case stands at 1.7 along the beam, a little to its side: every leg
	# keeps well clear of it.
	var keys := [[0.0, _torch_point(2.2, 0.62)], [2.4, _torch_point(2.2, 0.62)], [3.0, _torch_point(1.15, 0.62)], [3.5, _torch_point(0.9, 0.25)],
		[4.0, _torch_point(0.9, 0.25)], [4.4, _torch_point(1.05, 0.72)], [5.2, _torch_point(2.4, 0.72)], [5.7, _torch_point(2.5, CASE_SIDE)], [8.0, _torch_point(2.5, CASE_SIDE)]]
	var posture := 0.0 if u < 1.9 else (CROUCH if u < 4.0 else CRAWL)
	_walk(_crew[0], keys, u, posture, dt)
	var rel := _crew[0].position - GUARD_AT
	var dir := Vector3(cos(heading), 0, sin(heading))
	var d := rel.dot(dir)
	var lateral := absf(rel.dot(Vector3(-dir.z, 0, dir.x)))
	var in_beam := d > 0.0 and lateral < d * 0.3 + 0.1
	var hidden := u > 5.6
	var near_seen := in_beam and d < GUARD_REACH * 0.5 and not hidden
	var far_seen := in_beam and d >= GUARD_REACH * 0.5 and d < GUARD_REACH and posture < 0.3 and not hidden
	_beam(near_seen, far_seen)
	var alert: Label3D = _bits.alert
	alert.visible = near_seen or far_seen
	alert.position = _watch[0].position + Vector3(0, 1.12 + absf(sin(u * 8.0)) * 0.1, 0)


# --- Crouch: standing in the far torchlight you are seen, crouched you are not ------

func _torch() -> void:
	var g := _guard(true, 1.9)
	_watch.append(g)
	_crew.append(_thief(0))
	_bits.alert = _word("!", RED, 0.009)
	_bits.key = _word("C", CREAM, 0.006)


func _play_torch(u: float, dt: float) -> void:
	_watch[0].set_state(Vector3(-1.3, 0, -0.75), atan2(0.55, 1.0), 0.0, dt)
	# First standing: caught in the beam, turns back. Then crouched: straight across.
	var standing := u < 4.0
	var t := u if standing else u - 4.0
	var keys := [[0.0, Vector3(0.35, 0, -1.0)], [1.6, Vector3(0.35, 0, -0.1)], [2.2, Vector3(0.35, 0, -0.1)], [3.8, Vector3(0.35, 0, -1.0)]] if standing \
		else [[0.0, Vector3(0.35, 0, -1.0)], [3.6, Vector3(0.35, 0, 1.0)]]
	_walk(_crew[0], keys, t, 0.0 if standing else CROUCH, dt)
	var seen := standing and t > 1.5 and t < 3.0
	var alert: Label3D = _bits.alert
	alert.visible = seen
	alert.position = _watch[0].position + Vector3(0, 1.12 + absf(sin(u * 8.0)) * 0.12, 0)
	var key: Label3D = _bits.key
	key.visible = not standing
	key.position = _crew[0].position + Vector3(0, 0.85, 0)
	_beam(false, seen)


# --- Noise: running rings out far, walking a little, on all fours not at all -------

func _noise() -> void:
	_watch.append(_guard(false))
	_crew.append(_thief(0))
	_bits.alert = _word("!", RED, 0.009)


func _play_noise(u: float, dt: float) -> void:
	_watch[0].set_state(Vector3(-1.2, 0, -0.55), PI + 0.4 if u > 1.4 else atan2(0.8, 1.8), 0.0, dt)
	var phase := int(u / 3.0)
	var t := fmod(u, 3.0)
	var posture: float = [0.0, 0.0, CRAWL][phase]
	var from := Vector3(1.3, 0, 0.75)
	var to := Vector3(-0.2, 0, 0.75)
	_walk(_crew[0], [[0.0, from], [2.4, to], [3.0, to]], t, posture, dt)
	if phase == 0 and t < 2.4:
		_hop(_crew[0], u * 14.0, 0.08)
	# Footsteps: big rings running, small walking, none crawling.
	var every: float = [0.3, 0.5, 99.0][phase]
	var reach: float = [2.3, 0.6, 0.0][phase]
	if t < 2.4 and _tick(u, dt, every):
		_ring(_crew[0].position, reach, CREAM)
	var alert: Label3D = _bits.alert
	alert.visible = phase == 0 and t > 1.0
	alert.position = _watch[0].position + Vector3(0, 1.12, 0)


# --- The distraction: a bin knocked over far away pulls the guard off the case ------

func _props() -> void:
	_case(Vector3(-0.8, 0, -0.5), false)
	var pivot := Node3D.new()
	pivot.position = Vector3(1.05, 0, -0.25)
	_root.add_child(pivot)
	var can := CylinderMesh.new()
	can.top_radius = 0.13
	can.bottom_radius = 0.11
	can.height = 0.34
	_mesh(pivot, can, Color("#b8483a"), Vector3(0.13, 0.17, 0))
	for k in 3:
		var ball := SphereMesh.new()
		ball.radius = 0.05
		ball.height = 0.1
		_mesh(pivot, ball, CREAM, Vector3(0.1 + k * 0.03, 0.36, -0.03 + k * 0.03))
	_bits.bin = pivot
	_watch.append(_guard(false))
	_crew.append(_thief(0))
	_bits.alert = _word("!", RED, 0.009)
	_bits.key = _word("E", CREAM, 0.006)


func _play_props(u: float, dt: float) -> void:
	# Over it goes, a little after the thief reaches it.
	var tip := clampf((u - 1.2) / 0.35, 0.0, 1.0)
	(_bits.bin as Node3D).rotation.z = -tip * tip * PI / 2
	if u > 1.5 and u - dt <= 1.5:
		_ring(Vector3(1.35, 0, -0.25), 2.8, ORANGE)
		_ring(Vector3(1.35, 0, -0.25), 1.6, ORANGE)
	# The guard leaves the case to see what it was, then looks about.
	var gkeys := [[0.0, Vector3(-0.8, 0, 0.0)], [1.8, Vector3(-0.8, 0, 0.0)], [4.5, Vector3(0.75, 0, -0.55)], [9.0, Vector3(0.75, 0, -0.55)]]
	_walk(_watch[0], gkeys, u, 0.0, dt, 0.35)
	if u > 4.5:
		_watch[0].set_state(Vector3(0.75, 0, -0.55), sin(u * 2.0) * 0.8, 0.0, dt)
	# The thief nudges it over (E), then slips round the other way to the case.
	var tkeys := [[0.0, Vector3(0.3, 0, 1.0)], [1.1, Vector3(0.75, 0, -0.2)], [1.6, Vector3(0.75, 0, -0.2)], [3.2, Vector3(-0.2, 0, 0.75)], [5.0, Vector3(-0.3, 0, -0.45)], [9.0, Vector3(-0.3, 0, -0.45)]]
	_walk(_crew[0], tkeys, u, CROUCH if u > 1.6 else 0.0, dt)
	var key: Label3D = _bits.key
	key.visible = u > 0.9 and u < 1.6
	key.position = _crew[0].position + Vector3(0, 0.85, 0)
	var alert: Label3D = _bits.alert
	alert.visible = u > 1.6 and u < 4.5
	alert.position = _watch[0].position + Vector3(0, 1.12, 0)
	(_bits.gem as Node3D).visible = u < 5.8
	(_bits.gem as Node3D).rotation.y = u * 2.0


# --- The case with an alarm: it beeps while forced; let go and hide when they come --

func _case_alarm() -> void:
	_case(Vector3(0.0, 0, -0.35), false)
	_watch.append(_guard(false))
	_crew.append(_thief(0))
	_bits.alert = _word("?", GOLD, 0.008)


func _play_case_alarm(u: float, dt: float) -> void:
	var forcing := u > 0.9 and u < 3.6
	var fill := clampf((u - 0.9) / 4.5, 0.0, 1.0) if forcing else clampf(0.6 - (u - 3.6) * 0.5, 0.0, 0.6)
	for m in _bits.meters:
		_meter_fill(m, fill if u > 0.9 else 0.0)
	# The case beeps red while forced.
	(_bits.alarm as Node3D).visible = forcing and fmod(u, 0.4) < 0.2
	if forcing and _tick(u, dt, 0.4):
		_ring(Vector3(0.0, 0.2, -0.35), 1.8, RED)
	# The thief lets go when the guard comes, and crawls out of sight behind the case.
	var tkeys := [[0.0, Vector3(0.9, 0, 0.9)], [0.9, Vector3(0.0, 0, 0.15)], [3.6, Vector3(0.0, 0, 0.15)], [4.1, Vector3(-0.55, 0, 0.0)], [4.7, Vector3(-0.4, 0, -0.75)], [8.0, Vector3(-0.4, 0, -0.75)]]
	_walk(_crew[0], tkeys, u, CRAWL if u > 3.6 else 0.0, dt)
	var gkeys := [[0.0, Vector3(1.6, 0, 0.2)], [2.0, Vector3(1.6, 0, 0.2)], [4.8, Vector3(0.55, 0, 0.3)], [6.3, Vector3(0.55, 0, 0.3)], [8.0, Vector3(1.6, 0, 0.2)]]
	_walk(_watch[0], gkeys, u, 0.0, dt, 0.35)
	if u > 4.8 and u < 6.3:
		_watch[0].set_state(Vector3(0.55, 0, 0.3), PI + sin(u * 3.0) * 0.9, 0.0, dt)
	var alert: Label3D = _bits.alert
	alert.visible = u > 4.8 and u < 6.3
	alert.position = _watch[0].position + Vector3(0, 1.12, 0)


# --- Two guards: one sees you and shouts, the other comes running -------------------

func _two() -> void:
	_case(Vector3(0.4, 0, -0.5), false)
	_watch.append(_guard(true))
	_watch.append(_guard(false))
	_crew.append(_thief(0))
	_bits.shout = _word("!!!", RED, 0.008)
	_bits.heard = _word("!", RED, 0.008)


func _play_two(u: float, dt: float) -> void:
	var tkeys := [[0.0, Vector3(-0.2, 0, 1.0)], [1.2, Vector3(-0.2, 0, 0.45)], [1.6, Vector3(-0.2, 0, 0.45)], [3.5, Vector3(1.3, 0, 0.9)], [7.0, Vector3(1.3, 0, 0.9)]]
	_walk(_crew[0], tkeys, u, 0.0, dt)
	if u > 1.6 and u < 3.5:
		_hop(_crew[0], u * 14.0, 0.08)
	# The one who sees: stands and points its torch; shouts at 1.3.
	_watch[0].set_state(Vector3(-1.2, 0, -0.3), atan2(0.75, 1.0), 0.0, dt)
	if u > 1.3 and u - dt <= 1.3:
		_ring(_watch[0].position, 3.2, RED)
		_ring(_watch[0].position, 2.2, RED)
	var shout: Label3D = _bits.shout
	shout.visible = u > 1.3 and u < 4.0
	shout.position = _watch[0].position + Vector3(0, 1.12 + absf(sin(u * 9.0)) * 0.1, 0)
	# The other, round the wall, hears it and comes at a run.
	var gkeys := [[0.0, Vector3(1.2, 0, -0.8)], [1.6, Vector3(1.2, 0, -0.8)], [3.8, Vector3(1.0, 0, 0.55)], [5.5, Vector3(1.0, 0, 0.55)], [7.0, Vector3(1.2, 0, -0.8)]]
	_walk(_watch[1], gkeys, u, 0.0, dt, 0.35)
	if u > 1.6 and u < 3.8:
		_hop(_watch[1], u * 12.0, 0.08)
	var heard: Label3D = _bits.heard
	heard.visible = u > 1.4 and u < 4.5
	heard.position = _watch[1].position + Vector3(0, 1.12, 0)


# --- Lights: a guard on alert turns the room's lamp on; only cases hide you then ----

func _lights() -> void:
	# A switch on a post, a lamp overhead, two cases to crawl behind.
	var post := CylinderMesh.new()
	post.top_radius = 0.04
	post.bottom_radius = 0.05
	post.height = 0.7
	_mesh(_root, post, INK, Vector3(-1.35, 0.35, -0.85))
	_bits.switch = _box(_root, Vector3(0.16, 0.2, 0.08), Color("#e8d6b4"), Vector3(-1.35, 0.75, -0.8))
	_case(Vector3(0.45, 0, -0.1), false)
	var bulb := SphereMesh.new()
	bulb.radius = 0.12
	bulb.height = 0.24
	_bits.bulb = _mesh(_root, bulb, Color("#ffe8a0"), Vector3(0.0, 1.7, 0.0))
	_glow(_bits.bulb, Color("#ffd27a"), 0.0)
	_lamp_light = OmniLight3D.new()
	_lamp_light.position = Vector3(0, 1.6, 0)
	_lamp_light.light_color = Color("#fff1c8")
	_lamp_light.omni_range = 3.5
	_root.add_child(_lamp_light)
	_watch.append(_guard(false))
	_crew.append(_thief(0))
	_bits.alert = _word("!!", RED, 0.008)
	_bits.seen = _word("!", RED, 0.009)


func _play_lights(u: float, dt: float) -> void:
	var on := clampf((u - 2.0) * 4.0, 0.0, 1.0) * clampf((7.4 - u) * 4.0, 0.0, 1.0)
	_lamp_light.light_energy = on * 3.5
	(_bits.bulb.material_override as StandardMaterial3D).emission_energy_multiplier = on * 4.0
	(_bits.switch as Node3D).rotation.z = 0.5 if on > 0.5 else -0.5
	# The guard on alert goes to the switch; then turns to look about.
	var gkeys := [[0.0, Vector3(0.8, 0, -0.85)], [1.9, Vector3(-1.1, 0, -0.75)], [8.0, Vector3(-1.1, 0, -0.75)]]
	_walk(_watch[0], gkeys, u, 0.0, dt)
	if u > 1.9:
		_watch[0].set_state(Vector3(-1.1, 0, -0.75), 0.3 + sin(u * 1.5) * 0.6, 0.0, dt)
	var alert: Label3D = _bits.alert
	alert.visible = u < 2.2
	alert.position = _watch[0].position + Vector3(0, 1.12, 0)
	# The thief, crouched in the open, is seen once the lamp is on; drops to
	# all fours and crawls behind the case.
	# Round the case, not through it, to its far side from the guard.
	var tkeys := [[0.0, Vector3(0.0, 0, 0.8)], [2.6, Vector3(0.0, 0, 0.8)], [3.5, Vector3(0.95, 0, 0.55)], [4.3, Vector3(0.95, 0, 0.1)], [8.0, Vector3(0.95, 0, 0.1)]]
	_walk(_crew[0], tkeys, u, CRAWL if u > 2.6 else CROUCH, dt)
	var seen: Label3D = _bits.seen
	seen.visible = u > 2.1 and u < 3.2
	seen.position = _crew[0].position + Vector3(0, 0.85 + absf(sin(u * 9.0)) * 0.08, 0)


# --- A big museum: the plan, and the route drawn across it before going in ---------

func _big() -> void:
	_frame(3.6, 0.0)
	var plan := MapGen.generate(4242, 35, 25, "U")
	var k := 0.095
	_walls = Node3D.new()
	_root.add_child(_walls)
	_plan_blocks(plan, k, 0.12, 0.06)
	_rise(INF)
	# The route: from the way in to the furthest floor and on to a door, a
	# line of dots to be drawn.
	var path := _longest_walk(plan)
	var dots: Array[Node3D] = []
	for i in path.size():
		var t: Vector2i = path[i]
		var d := SphereMesh.new()
		d.radius = 0.04
		d.height = 0.08
		var dot := _mesh(_root, d, GOLD, Vector3((t.x - plan.w / 2.0 + 0.5) * k, 0.06, (t.y - plan.h / 2.0 + 0.5) * k))
		_glow(dot, GOLD, 2.5)
		dots.append(dot)
	_bits.dots = dots
	var start := dots[0].position
	_bits.gem = _gem_at(dots[dots.size() - 1].position + Vector3(0, 0.1, 0))
	var pin := _word("?", CREAM, 0.007)
	_bits.pin = pin
	_bits.start = start


func _play_big(u: float, dt: float) -> void:
	var dots: Array = _bits.dots
	var drawn := int(clampf(u / 6.0, 0.0, 1.0) * dots.size())
	for i in dots.size():
		(dots[i] as Node3D).visible = i < drawn
	var head: Vector3 = (dots[maxi(0, drawn - 1)] as Node3D).position
	var pin: Label3D = _bits.pin
	pin.position = head + Vector3(0, 0.35 + absf(sin(u * 6.0)) * 0.08, 0)
	pin.text = "?" if drawn < dots.size() else "!"
	(_bits.gem as Node3D).rotation.y = u * 2.0
	_root.rotation.y = -0.25 + u / 9.0 * 0.5


## The longest walk on the plan from its way in: a route worth planning.
func _longest_walk(plan: MapGen) -> Array[Vector2i]:
	var from := plan.spawn
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	var last := from
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		last = c
		for d in MapGen.DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= plan.w or n.y >= plan.h or prev.has(n):
				continue
			if plan.at(n.x, n.y) != Tiles.FLOOR:
				continue
			prev[n] = c
			queue.append(n)
	var path: Array[Vector2i] = []
	var at := last
	while at != from:
		path.push_front(at)
		at = prev[at]
	path.push_front(from)
	# Every other tile: dots, not a solid line.
	var out: Array[Vector2i] = []
	for i in path.size():
		if i % 2 == 0:
			out.append(path[i])
	return out


# --- The last night: four guards on fast rounds, one gap, one go --------------------

func _finale() -> void:
	_case(Vector3(0, 0, 0), false)
	for i in 4:
		_watch.append(_guard(true, 0.6, RED))
	_crew.append(_thief(0))
	_bits.alert = _word("!!!", RED, 0.008)


func _play_finale(u: float, dt: float) -> void:
	for i in 4:
		var a := u * 1.6 + i * TAU / 4
		var pos := Vector3(cos(a) * 0.95, 0, sin(a) * 0.75)
		_watch[i].set_state(pos, atan2(cos(a) * 0.75, -sin(a) * 0.95), 0.0, dt)
		_hop(_watch[i], u * 10.0 + i, 0.05)
	# Waiting at the edge for the gap, a dash in, the piece, a dash out.
	var tkeys := [[0.0, Vector3(-1.4, 0, 0.9)], [1.6, Vector3(-1.4, 0, 0.9)], [2.4, Vector3(-0.3, 0, 0.3)]]
	_walk(_crew[0], tkeys, u, 0.0, dt)
	if u > 1.6 and u < 2.4:
		_hop(_crew[0], u * 16.0, 0.1)
	# The piece, taken right under their noses and held up high.
	var up := clampf((u - 2.8) / 0.4, 0.0, 1.0)
	if u > 3.2:
		_hop(_crew[0], u * 9.0, 0.08)
	var gem: Node3D = _bits.gem
	gem.position = Vector3(0, 0.42 * CASE_SCALE + 0.06, 0).lerp(_crew[0].position + Vector3(0, 1.05, 0), up)
	gem.scale = Vector3.ONE * (1.0 + 0.3 * up)
	gem.rotation.y = u * 2.0
	var alert: Label3D = _bits.alert
	alert.visible = u > 3.4
	alert.position = Vector3(0, 1.3 + absf(sin(u * 9.0)) * 0.1, 0)


# --- Pieces ---------------------------------------------------------------------------

func _thief(i: int) -> Figure:
	return _figure("thief", GANG[i][0], GANG[i][1], 0.8)


## A guard, its torch light and, if lit, the beam drawn as a pale cone.
func _guard(lit: bool, reach := 1.3, colour := BEAM) -> Figure:
	var g := _figure("guard", GUARD, GUARD_DARK, 0.8)
	var torch := SpotLight3D.new()
	torch.position = Vector3(0, 1.0, 0.3)
	torch.rotation = Vector3(-0.45, PI, 0)
	torch.spot_angle = 26
	torch.spot_range = reach + 1.0
	torch.light_energy = 3.0
	torch.light_color = colour
	g.add_child(torch)
	if lit:
		# The torch's two reaches, as in the game (Sim.VIEW): the bright pool
		# near the guard sees you however low you are; the dim throw beyond
		# it, out to twice as far, only sees you standing.
		var half := reach * 0.5
		var mats: Array[StandardMaterial3D] = []
		for k in 2:
			var part := CylinderMesh.new()
			part.top_radius = 0.0 if k == 0 else half * 0.3
			part.bottom_radius = half * 0.3 if k == 0 else reach * 0.3
			part.height = half
			part.radial_segments = 16
			var mi := MeshInstance3D.new()
			mi.mesh = part
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(colour, 0.3 if k == 0 else 0.12)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			mi.material_override = m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.rotation.x = -PI / 2
			mi.position = Vector3(0, 0.3, half * (0.5 + k) + 0.15) / g.scale.x
			mi.scale = Vector3.ONE / g.scale.x
			g.add_child(mi)
			mats.append(m)
		_bits.beam = mats
		_bits.beam_colour = colour
	return g


## Paint the torch's reaches: red where it is catching someone.
func _beam(near_seen: bool, far_seen: bool) -> void:
	var mats: Array = _bits.beam
	var c: Color = _bits.beam_colour
	(mats[0] as StandardMaterial3D).albedo_color = Color(RED if near_seen else c, 0.3)
	(mats[1] as StandardMaterial3D).albedo_color = Color(RED if far_seen else c, 0.12)


## A glass case on its stand with the piece glowing inside, and over it the
## meter(s) that fill while it is being opened.
func _case(at: Vector3, two_locks: bool) -> void:
	# The game's own case (art/vitrina.blend), at the dioramas' scale.
	var v := MuseumView.asset("vitrina")
	v.scale = Vector3.ONE * CASE_SCALE
	v.position = at
	_root.add_child(v)
	_bits.gem = _gem_at(at + Vector3(0, 0.42 * CASE_SCALE + 0.06, 0))
	# Its alarm going off: a red glow in the glass and a red light.
	var glow := MeshInstance3D.new()
	glow.mesh = MuseumView._box(Vector3(0.8, 0.43, 0.8) * CASE_SCALE)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(RED, 0.35)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.material_override = gm
	glow.position = at + Vector3(0, 0.61 * CASE_SCALE, 0)
	glow.visible = false
	_root.add_child(glow)
	_bits.alarm = glow
	var meters: Array = []
	for side in ([-1, 1] if two_locks else [0]):
		var m := _meter(at + Vector3(side * 0.32, 1.05, 0))
		_meter_fill(m, 0.0)
		meters.append(m)
	_bits.meters = meters


func _gem_at(at: Vector3) -> MeshInstance3D:
	var gem := SphereMesh.new()
	gem.radius = 0.09
	gem.height = 0.18
	gem.radial_segments = 6
	gem.rings = 3
	var mi := _mesh(_root, gem, GOLD, at)
	_glow(mi, GOLD, 0.9)
	return mi


## A ring that fills with gold: how far the case has given.
func _meter(at: Vector3) -> Node3D:
	var g := Node3D.new()
	g.position = at
	_root.add_child(g)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.13
	ring.outer_radius = 0.16
	var r := _mesh(g, ring, CREAM, Vector3.ZERO)
	r.rotation.x = PI / 2
	var disc := CylinderMesh.new()
	disc.top_radius = 0.13
	disc.bottom_radius = 0.13
	disc.height = 0.02
	var d := _mesh(g, disc, GOLD, Vector3.ZERO)
	d.rotation.x = PI / 2
	_glow(d, GOLD, 1.2)
	g.set_meta("disc", d)
	# Facing the camera, like a badge.
	g.rotation = Vector3(0, PI / 4, 0)
	g.scale = Vector3.ONE * 1.4
	return g


func _meter_fill(m: Node3D, fill: float) -> void:
	var d: Node3D = m.get_meta("disc")
	d.scale = Vector3(maxf(fill, 0.001), 1, maxf(fill, 0.001))
	m.visible = fill > 0.0


## The alarm panel: an orange box on a post, lit while someone holds it.
func _panel(at: Vector3) -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.035
	post.bottom_radius = 0.045
	post.height = 0.6
	_mesh(_root, post, INK, at + Vector3(0, 0.3, 0))
	_glow(_box(_root, Vector3(0.24, 0.26, 0.1), ORANGE, at + Vector3(0, 0.72, 0)), ORANGE, 1.0)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 0.8, 0.2)
	light.light_color = ORANGE
	light.omni_range = 1.2
	_root.add_child(light)
	var lights: Array = _bits.get("panel_lights", [])
	lights.append(light)
	_bits.panel_lights = lights


# --- Motion ---------------------------------------------------------------------------

## Walk a figure along timed points [[t, pos], ...], facing the way it goes
## (or the way it last went, when still). slow < 1 for a guard's stroll.
func _walk(f: Figure, keys: Array, u: float, posture: float, dt: float, _pace := 1.0) -> void:
	var pos := _along(keys, u)
	var ahead := _along(keys, u + 0.08)
	var step := Vector2(ahead.x - pos.x, ahead.z - pos.z)
	var dir: float = f.get_meta("dir", PI / 4)
	if step.length() > 0.002:
		dir = atan2(step.y, step.x)
		f.set_meta("dir", dir)
	f.set_state(pos, dir, posture, dt)


static func _along(keys: Array, u: float) -> Vector3:
	if u <= float(keys[0][0]):
		return keys[0][1]
	for i in range(1, keys.size()):
		if u <= float(keys[i][0]):
			var a: Array = keys[i - 1]
			var b: Array = keys[i]
			var k := (u - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4)
			return (a[1] as Vector3).lerp(b[1], smoothstep(0.0, 1.0, k))
	return keys[keys.size() - 1][1]


## True once every `every` seconds of the loop.
func _tick(u: float, dt: float, every: float) -> bool:
	return int(u / every) != int(maxf(u - dt, 0.0) / every)


## A ring of sound going out from here, as far as reach.
func _ring(at: Vector3, reach: float, colour: Color) -> void:
	if reach <= 0.0:
		return
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 32
	var mi := MeshInstance3D.new()
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(at.x, 0.05, at.z)
	mi.scale = Vector3.ONE * 0.01
	_root.add_child(mi)
	_rings.append([mi, _t, reach])


func _age_rings() -> void:
	for r in _rings.duplicate():
		var mi: MeshInstance3D = r[0]
		var k := (_t - float(r[1])) / 0.9
		if k >= 1.0 or k < 0.0:
			mi.queue_free()
			_rings.erase(r)
			continue
		mi.scale = Vector3(1, 0.4, 1) * maxf(0.01, k * float(r[2]))
		(mi.material_override as StandardMaterial3D).albedo_color.a = 1.0 - k
