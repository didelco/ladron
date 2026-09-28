class_name Figure
extends Node3D
## A figure: the ninja thief or the guard, modelled and rigged in Blender
## (art/characters/, exported to assets/models/ninja.glb and guardia.glb).
##
## The rest of the game only calls set_state() each frame with where the
## figure is, which way it faces and how far down it is; from how fast it is
## moving, this picks the clip (standing, walking, running, and for thieves
## crawling) and plays it at the pace of the feet, so they do not slide.
##
## Drawing: the model's own materials, with a rim of whatever light is about,
## an ink outline from an inflated inside-out copy (the material's next pass)
## and Godot's stencil x-ray: where something covers the figure it shows
## through as a flat silhouette in its state colour. A thief's suit is the
## player's colour, its lapels a shade darker, and the headband, belt and
## cuffs black: a bright figure on a dark floor.

const MODELS := {
	"thief": preload("res://assets/models/ninja.glb"),
	"guard": preload("res://assets/models/guardia.glb"),
}
## Size of each model in the game: the ninja is drawn a little bigger, as tall
## as the guard's cap.
const SIZE := {"thief": 1.1, "guard": 1.0}
## Ground speed (m/s) at which each clip's feet keep up with the floor at
## normal playback; the clip plays faster or slower to match the figure.
const PACE := {
	"thief": {"andar": 1.4, "correr": 4.6, "gatear": 0.9},
	"guard": {"andar": 0.8, "correr": 3.0},
}
## From this speed a figure runs rather than walks.
const RUN_FROM := {"thief": 3.0, "guard": 2.0}
## Slower than this counts as standing still.
const STILL := 0.12
## From this posture (0 standing, 1 on all fours) a thief crawls.
const CRAWL_FROM := 0.35
## Crossfade between clips, in seconds.
const BLEND := 0.22

const INK := Color("#08070c")
## How far out the ink outline sits, in metres.
const INK_GROW := 0.01
const RIM := 0.6
const RIM_TINT := 0.35
## Materials too small or too bright for an outline (eyes, brows, badges).
const NO_INK := ["ojo", "pupila", "ceja", "vello", "oro", "lente", "piloto", "rejilla"]
## The thief's materials in the player's colour.
const PLAYER_COLOUR := ["traje"]
## A shade of the player's colour, and what is black on a coloured suit.
const PLAYER_SHADE := ["solapa"]
const BLACK := ["cinta"]
const BELT := Color("#141418")

## Rolling (Roll): the crawl pose squeezed into a ball this big (m, radius)
## and this squashed along its length and height, tumbling head over heels.
const BALL := 0.34
const BALL_SQUASH := Vector3(0.8, 0.5, 0.7)
## Where the middle of the crawl pose is, in the model's own metres.
const CRAWL_MIDDLE := Vector3(0, 0.5, 0.0)
## Dizzy: flat on its back, this high off the floor (the depth of its back);
## how fast it tips back upright when getting up.
const LYING := 0.25
const TIP := 4.0
## The stars going round the head: how many, how far out, turns a second,
## and each one's size (m); drawn bigger than life, to read from up high.
const DAZE_STARS := 4
const DAZE_RING := 0.3
const DAZE_SPIN := 1.3
const DAZE_SIZE := 0.11
const DAZE_COLOUR := Color("#ffd23f")

var guard := false
var _kind := "thief"
var _player: AnimationPlayer
## Between the figure and the model: tumbles it (a roll) or lays it down.
var _pivot: Node3D
var _model: Node3D
var _spin := 0.0
var _daze: Node3D
var _sweat: Node3D
var _sweat_t := 0.0
var _materials: Array[StandardMaterial3D] = []
var _ghost_colour := Color.WHITE

var _last_pos := Vector3.INF
var _speed := 0.0
var _clip := ""
## The clip's own playback speed, and the seconds left of the crossfade into
## it. The player's speed_scale stays at 1 so the crossfade runs on the clock:
## scaled down to 0 (on all fours and still) it would never end, and a thief
## getting down or up on the spot would keep the old pose until it moved.
var _pace := 1.0
var _fade := 0.0
var _dt := 0.0


static func make(kind: String, colour: Color, _accent: Color) -> Figure:
	var f := Figure.new()
	f.guard = kind == "guard"
	f._kind = "guard" if f.guard else "thief"
	f._build(colour)
	return f


## Colour of the silhouette seen through whatever covers the figure, and how
## strongly (0..1: darker is fainter).
func set_ghost(colour: Color, strength: float) -> void:
	var c := colour * strength
	c.a = 1.0
	if c.is_equal_approx(_ghost_colour):
		return
	_ghost_colour = c
	for m in _materials:
		m.stencil_color = c


## How far the figure sways, as a statue on one foot (Minigame "balance"):
## MAX_LEAN radians for each 1 of lean, negative over to the screen's left,
## positive to its right, about the foot it stands on (it falls at
## BalanceGame.FALL). The pedestal's statue faces the camera, so the screen's right
## is its own left. Past BalanceGame.WOBBLE a big drop of sweat runs down
## beside its head.
const MAX_LEAN := 0.4
## The drop of sweat: its size (m, radius of the round end), where it sits
## beside the head, how far it runs down before it starts again, and how
## fast.
const SWEAT_SIZE := 0.1
const SWEAT_AT := Vector3(0.3, 1.02, 0.14)
const SWEAT_RUN := 0.12
const SWEAT_SPEED := 0.5
const SWEAT_COLOUR := Color("#9fe0ff")


func set_lean(amount: float) -> void:
	if _pivot:
		_pivot.rotation.z = -amount * MAX_LEAN
	_sweat_show(absf(amount) >= BalanceGame.WOBBLE)


## How strong the rim light round the figure is (the dioramas' daylight
## washes it out at the game's strength).
func set_rim(amount: float) -> void:
	for m in _materials:
		if m.rim_enabled:
			m.rim = amount


## Place and pose the figure for this frame. dir is the grid heading (radians
## from +x); posture 0 standing, 1 on all fours. pose "roll" curls a thief
## into a tumbling ball, "dizzy" lays it on its back with stars round its
## head (Roll); "victory" jumps for joy, fists in the air (a thief out of
## the door); "statue" strikes a ninja pose, still as stone (on a pedestal,
## Plinths); "" is everything else.
func set_state(pos: Vector3, dir: float, posture: float, dt: float, pose := "") -> void:
	var raw := 0.0
	if _last_pos != Vector3.INF and dt > 0:
		raw = Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() / dt
		# Smoothed: the sim moves in steps, the clip should not flicker.
		_speed += (raw - _speed) * minf(dt * 10.0, 1.0)
	_last_pos = pos
	_dt = dt
	position = pos
	rotation.y = -dir + PI / 2
	_curl(pose, raw, dt)
	if pose == "roll":
		# Held in the crawl, tucked up: the tumbling does the moving.
		_play("reposo", 1.0, 0.08)
	elif pose == "dizzy":
		_play("reposo", 0.35)
	elif pose == "victory" and _player.has_animation("victoria"):
		_play("victoria", 1.0)
	elif pose == "statue" and _player.has_animation("estatua"):
		_play("estatua", 1.0, 0.12)
	else:
		_animate(posture)


## Rolling, lying dizzy, or neither: the pivot tumbles, tips over or rights
## itself, and the stars come out or go.
func _curl(pose: String, speed: float, dt: float) -> void:
	if _pivot == null:
		return
	var ball := pose == "roll"
	_pivot.scale = BALL_SQUASH if ball else Vector3.ONE
	_model.position = -CRAWL_MIDDLE * SIZE[_kind] if ball else Vector3.ZERO
	if ball:
		# Head over heels, as fast as a ball that size rolls.
		_spin = wrapf(_spin + speed / BALL * dt, -PI, PI)
		_pivot.rotation.x = _spin
		_pivot.position = Vector3(0, BALL, 0)
		return
	_spin = 0.0
	if pose == "dizzy":
		# Flat on its back, face up and head behind: the ball spins too fast
		# to see it land any other way.
		_pivot.rotation.x = -PI / 2
		_daze_show(dt)
	else:
		# Up again (or never down): tipping back upright.
		_pivot.rotation.x = lerp_angle(_pivot.rotation.x, 0.0, minf(1.0, TIP * dt))
		if _daze and _daze.visible:
			_daze.visible = false
	# Raised by as much as its back would sink into the floor.
	_pivot.position = Vector3(0, LYING * clampf(sin(-_pivot.rotation.x), 0.0, 1.0), 0)


# --- Building -------------------------------------------------------------------

func _build(colour: Color) -> void:
	_ghost_colour = colour * 0.75
	_ghost_colour.a = 1.0
	var model: Node3D = MODELS[_kind].instantiate()
	model.scale = Vector3.ONE * SIZE[_kind]
	_pivot = Node3D.new()
	add_child(_pivot)
	_pivot.add_child(model)
	_model = model
	_player = model.find_child("AnimationPlayer", true, false)
	# Every clip is a cycle.
	for name in _player.get_animation_list():
		_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		_dress(mi as MeshInstance3D, colour)
	_play("reposo", 1.0, 0.0)


## Each surface gets its own copy of its material, with the rim, the ink and
## the x-ray added (and the player's colours on a thief's suit).
func _dress(mi: MeshInstance3D, colour: Color) -> void:
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in mi.mesh.get_surface_count():
		var src := mi.mesh.surface_get_material(i) as StandardMaterial3D
		if src == null:
			continue
		var m := src.duplicate() as StandardMaterial3D
		var name := src.resource_name
		if not guard and name in PLAYER_COLOUR:
			m.albedo_color = colour
		elif not guard and name in PLAYER_SHADE:
			m.albedo_color = colour.darkened(0.3)
		elif not guard and name in BLACK:
			m.albedo_color = BELT
		if m.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and not m.emission_enabled:
			m.rim_enabled = true
			m.rim = RIM
			m.rim_tint = RIM_TINT
		if name not in NO_INK:
			var ink := StandardMaterial3D.new()
			ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			ink.albedo_color = INK
			ink.cull_mode = BaseMaterial3D.CULL_FRONT
			ink.grow = true
			ink.grow_amount = INK_GROW
			m.next_pass = ink
		m.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
		m.stencil_color = _ghost_colour
		mi.set_surface_override_material(i, m)
		_materials.append(m)


# --- Animating ---------------------------------------------------------------------

func _animate(posture: float) -> void:
	var pace: Dictionary = PACE[_kind]
	if not guard and posture >= CRAWL_FROM:
		# On all fours: crawl at the pace of the hands, or hold still.
		_play("gatear", clampf(_speed / pace.gatear, 0.0, 1.8))
	elif _speed < STILL:
		_play("reposo", 1.0)
	elif _speed >= RUN_FROM[_kind]:
		_play("correr", clampf(_speed / pace.correr, 0.6, 1.6))
	else:
		_play("andar", clampf(_speed / pace.andar, 0.5, 1.8))


## Play clip at speed times its normal pace, crossfading into it over blend
## seconds of real time whatever the speed.
func _play(clip: String, speed: float, blend := BLEND) -> void:
	_fade = maxf(0.0, _fade - _dt)
	if clip != _clip:
		_clip = clip
		_pace = speed
		_fade = blend
		_player.play(clip, blend, speed)
	elif _fade == 0.0 and absf(speed - _pace) > 0.01:
		# The same clip again only changes its pace (it keeps its place), but
		# it would cut a crossfade short: during one the pace waits.
		_pace = speed
		_player.play(clip, 0.0, speed)


# --- Dizzy ---------------------------------------------------------------------------

## The stars going round the head of a thief lying dizzy (built the first
## time they are needed).
func _daze_show(dt: float) -> void:
	if _daze == null:
		_daze = Node3D.new()
		add_child(_daze)
		var mesh := _daze_star()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = DAZE_COLOUR
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Always on top, cartoon-style: not lost behind the head or a case.
		mat.no_depth_test = true
		mat.render_priority = 10
		for k in DAZE_STARS:
			var star := MeshInstance3D.new()
			star.mesh = mesh
			star.material_override = mat
			star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_daze.add_child(star)
	# Over the head, which lies behind (see _curl), a little above the floor.
	_daze.position = Vector3(0, 0.55, -0.9 * SIZE[_kind])
	if not _daze.visible:
		_daze.visible = true
	_daze.rotation.y += DAZE_SPIN * TAU * dt
	var n := _daze.get_child_count()
	for k in n:
		var a := k * TAU / n
		var star := _daze.get_child(k) as Node3D
		# Round in a ring, bobbing, each one spinning on itself.
		star.position = Vector3(cos(a) * DAZE_RING, sin(a * 2.0 + _daze.rotation.y * 2.0) * 0.04, sin(a) * DAZE_RING)
		star.rotation.y -= 4.0 * dt


# --- Sweat --------------------------------------------------------------------------

## A big cartoon drop of sweat beside the head, running down and popping up
## again, while the figure wobbles (built the first time it is needed).
func _sweat_show(on: bool) -> void:
	if not on:
		if _sweat and _sweat.visible:
			_sweat.visible = false
		return
	if _sweat == null:
		_sweat = Node3D.new()
		_pivot.add_child(_sweat)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = SWEAT_COLOUR
		# Always on top, cartoon-style, like the dizzy stars.
		mat.no_depth_test = true
		mat.render_priority = 10
		var shine := mat.duplicate() as StandardMaterial3D
		shine.albedo_color = Color.WHITE
		shine.render_priority = 11
		# The round end, and the point on top.
		var ball := SphereMesh.new()
		ball.radius = SWEAT_SIZE
		ball.height = SWEAT_SIZE * 2.0
		var tip := CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = SWEAT_SIZE * 0.93
		tip.height = SWEAT_SIZE * 1.5
		var glint := SphereMesh.new()
		glint.radius = SWEAT_SIZE * 0.22
		glint.height = SWEAT_SIZE * 0.44
		for part in [[ball, mat, Vector3.ZERO], [tip, mat, Vector3(0, SWEAT_SIZE * 0.95, 0)], [glint, shine, Vector3(-SWEAT_SIZE * 0.35, SWEAT_SIZE * 0.3, SWEAT_SIZE * 0.8)]]:
			var mi := MeshInstance3D.new()
			mi.mesh = part[0]
			mi.material_override = part[1]
			mi.position = part[2]
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_sweat.add_child(mi)
	if not _sweat.visible:
		_sweat.visible = true
		_sweat_t = 0.0
	_sweat_t = fmod(_sweat_t + _dt * SWEAT_SPEED, 1.0)
	# Swelling out as it appears, then running down the side of the head.
	var grow := clampf(_sweat_t * 6.0, 0.0, 1.0)
	_sweat.scale = Vector3.ONE * SIZE[_kind] * (0.4 + 0.6 * grow)
	_sweat.position = SWEAT_AT * SIZE[_kind] + Vector3(0, -SWEAT_RUN * _sweat_t, 0)


## A flat five-pointed star lying in the XZ plane, DAZE_SIZE to the points.
static func _daze_star() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in 10:
		var r0 := DAZE_SIZE if k % 2 == 0 else DAZE_SIZE * 0.45
		var r1 := DAZE_SIZE * 0.45 if k % 2 == 0 else DAZE_SIZE
		var a0 := k * TAU / 10.0
		var a1 := (k + 1) * TAU / 10.0
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(cos(a1) * r1, 0, sin(a1) * r1))
		st.add_vertex(Vector3(cos(a0) * r0, 0, sin(a0) * r0))
	return st.commit()
