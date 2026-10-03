class_name CameraRig
extends RefCounted
## The plan camera: high up and a little behind the gang, a loose spring that follows it, pulling
## back to keep several thieves in, close on them as a night begins, swooping in on the steal and
## shaking with crashes (trauma). The Camera3D itself is Game's (made by NightEnv); this moves it.

## Where the camera sits over what it looks at: high up and a little behind.
const CAM_OFFSET := Vector3(0, 15.4, 6)

## How far (m) the thief can wander from the middle before the camera moves.
const CAM_SLACK := 0.9

## Roughly how long (s) the camera takes to catch up: higher is lazier.
const CAM_SMOOTH := 0.55

## The shake at full trauma: how far the view slides (in metres at the
## camera) and how far it rolls (radians).
const SHAKE_MOVE := 0.45
const SHAKE_ROLL := 0.025

## How much of the trauma wears off each second.
const SHAKE_DECAY := 1.2

## With several thieves the camera pulls back (along CAM_OFFSET) to keep them
## all in: this share of the half-screen each way is where they may go, so
## nobody reaches the edge while the follow catches up; never further back
## than CAM_MAX_ZOOM times the usual.
const CAM_MARGIN_X := 0.82
const CAM_MARGIN_Y := 0.7
const CAM_MAX_ZOOM := 4.0

## How close the camera starts a night, as a share of the usual distance.
const CAM_INTRO_NEAR := 0.5

## How far up the plan from the gang the camera looks then, so the count in
## the middle of the screen does not cover them.
const CAM_INTRO_LOW := 0.6

## How long (s) the pull back takes, and the coming back in: out quickly
## (someone is about to leave the picture), in lazily.
const CAM_ZOOM_OUT := 0.12
const CAM_ZOOM_IN := 1.2

## The menu's picture: the hideout behind the menus seen from closer than
## when playing, so it reads as a backdrop and its details show: the play
## camera's own view, this share of its distance. Choosing GUARIDA pulls back
## to the play camera.
const MENU_NEAR := 0.68

## How long (s) the camera takes to go between the menu's picture and the play camera.
const MENU_BLEND_S := 1.3

var host: Game

## where the camera is headed, followed smoothly; the shake and the punch are
## put on top of it every frame, so they never pile up in the follow
var cam_rest := Vector3.ZERO

## how fast cam_rest is moving: the follow is a spring, so it winds up when
## you set off and runs on a little, easing to a stop, when you halt
var cam_vel := Vector3.ZERO

## the point the spring pulls towards: it only moves once the thief strays
## past CAM_SLACK from it, so small moves do not drag the whole picture
var cam_goal := Vector3.ZERO

## 0..1: how shaken the camera is. It is squared for the shake, so small
## knocks barely move it and big ones hit hard, and it decays by itself.
var trauma := 0.0

## 0..1: how far the camera has swooped in towards the thief (the steal)
var punch := 0.0

## how far back the camera sits: 1 as usual, more to fit a spread-out gang
var cam_zoom := 1.0
var punch_tween: Tween

## 0..1: how close the camera is on the gang at the start of a night (1 on top
## of them, 0 the usual follow), so you see where you are before you go
var intro := 0.0
var intro_tween: Tween

## 0..1: how far the camera is from the play camera towards the menu's
## closer picture of the house (1 in the menu, 0 playing), and where it goes.
var menu_blend := 0.0
var menu_tween: Tween


func _init(game: Game) -> void:
	host = game


## The thieves the camera keeps in: those still in, or everyone at the end.
func watched() -> Array:
	var live := host.thieves.filter(func(p): return not p.out)
	return live if not live.is_empty() else host.thieves


func camera_target() -> Vector3:
	var watched := watched()
	# The middle of the box round them, not their average: three on one side
	# must not push the fourth out of the picture.
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in watched:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid := (lo + hi) / 2.0
	# Keep the frame inside the building.
	return host._to_world(clampf(mid.x, 7, Museum.w - 7), clampf(mid.y, 5.5, Museum.h - 5.5), 0.6)


## How far back (1 = CAM_OFFSET) the camera must sit, looking at `focus`, for
## every thief to be inside the margins. The camera only pulls straight back
## along CAM_OFFSET (length D), so a point dx across and dz down the plan
## from the focus lands dx across and dz·up up the screen, at depth
## D·k - dz·back: nearer the camera the further down the plan it is. Keeping
## each inside its margin of the view gives the bound on k below.
func zoom_to_fit(focus: Vector3) -> float:
	var d := CAM_OFFSET.length()
	var up := CAM_OFFSET.y / d  # how much of a step down the plan shows on screen
	var back := CAM_OFFSET.z / d  # how much of it goes into depth instead
	var tan_y := tan(deg_to_rad(host.camera.fov) / 2.0)
	var size := host.get_viewport().get_visible_rect().size
	var tan_x := tan_y * size.x / maxf(size.y, 1.0)
	# On your own the usual follow does: the camera never pulls back.
	var watched := watched()
	if watched.size() < 2:
		return 1.0
	var k := 1.0
	for p in watched:
		var w := host._to_world(p.x, p.y)
		var dx := absf(w.x - focus.x)
		var dz := w.z - focus.z
		var depth_y := up * absf(dz) / (tan_y * CAM_MARGIN_Y)
		var depth_x := dx / (tan_x * CAM_MARGIN_X)
		k = maxf(k, (maxf(depth_x, depth_y) + back * dz) / d)
	return minf(k, CAM_MAX_ZOOM)


func snap() -> void:
	var t := camera_target()
	cam_rest = t + CAM_OFFSET
	cam_goal = t
	cam_vel = Vector3.ZERO
	cam_zoom = zoom_to_fit(t)
	trauma = 0.0
	punch = 0.0
	if punch_tween:
		punch_tween.kill()
	intro = 0.0
	if intro_tween:
		intro_tween.kill()
	menu_blend = 0.0
	if menu_tween:
		menu_tween.kill()
	host.camera.h_offset = 0.0
	host.camera.v_offset = 0.0
	host.camera.position = t + CAM_OFFSET * cam_zoom
	host.camera.look_at(t)
	fog_follows_zoom()


## The fog reaches as far as the floor, however far back the camera is.
func fog_follows_zoom() -> void:
	if host.nightenv.world_env:
		host.nightenv.world_env.volumetric_fog_length = NightEnv.FOG_LENGTH * cam_zoom


func follow(dt: float) -> void:
	var t := camera_target()
	# A loose leash: inside CAM_SLACK the thief moves about the frame and the
	# camera stays put; past it, the goal is dragged along.
	var off := Vector3(t.x - cam_goal.x, 0.0, t.z - cam_goal.z)
	if off.length() > CAM_SLACK:
		cam_goal += off - off.normalized() * CAM_SLACK
	cam_goal.y = t.y
	# A critically damped spring towards it (the SmoothDamp step): it starts
	# slowly, catches up, and settles without overshooting.
	var omega := 2.0 / CAM_SMOOTH
	var x := omega * dt
	var decay := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cam_rest - (cam_goal + CAM_OFFSET)
	var temp := (cam_vel + omega * change) * dt
	cam_vel = (cam_vel - omega * temp) * decay
	cam_rest = cam_goal + CAM_OFFSET + (change + temp) * decay
	var focus := cam_rest - CAM_OFFSET
	# Pull back as far as it takes to keep everyone in, measured from where
	# the camera is really looking (it lags the target).
	var want := zoom_to_fit(focus)
	var ease := CAM_ZOOM_OUT if want > cam_zoom else CAM_ZOOM_IN
	cam_zoom = lerpf(cam_zoom, want, 1.0 - exp(-dt / ease))
	fog_follows_zoom()
	# The way in: close on the gang itself (not the frame kept inside the
	# building), easing out to the usual follow.
	# The gang sits below the middle, clear of the count.
	if intro > 0.0:
		focus = focus.lerp(gang_middle() + Vector3(0, 0, -CAM_INTRO_LOW), intro)
	var near := lerpf(1.0, CAM_INTRO_NEAR, intro)
	var eye := focus + CAM_OFFSET * cam_zoom * near * (1.0 - 0.22 * punch)
	var fog_zoom := cam_zoom
	if menu_blend > 0.0:
		eye = focus + (eye - focus) * lerpf(1.0, MENU_NEAR, menu_blend)
		if host.nightenv.world_env:
			host.nightenv.world_env.volumetric_fog_length = NightEnv.FOG_LENGTH * cam_zoom * lerpf(1.0, MENU_NEAR, menu_blend)
	host.camera.position = eye
	host.camera.look_at(focus)
	# The shake slides the picture rather than moving the camera, so the
	# lights nearest the camera do not flicker from room to room.
	trauma = maxf(trauma - SHAKE_DECAY * dt, 0.0)
	var s := trauma * trauma
	var time := Time.get_ticks_msec() / 1000.0
	host.camera.h_offset = SHAKE_MOVE * s * (sin(time * 47.0) + 0.5 * sin(time * 83.0 + 1.3)) / 1.5
	host.camera.v_offset = SHAKE_MOVE * s * (sin(time * 53.0 + 2.1) + 0.5 * sin(time * 71.0 + 0.4)) / 1.5
	host.camera.rotate_object_local(Vector3.BACK, SHAKE_ROLL * s * sin(time * 37.0 + 0.7))


## The middle of the gang on the plan, where the way in starts.
func gang_middle() -> Vector3:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in watched():
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var mid := (lo + hi) / 2.0
	return host._to_world(mid.x, mid.y, 0.6)


## The camera starts right on the gang and pulls back to the usual follow
## over `seconds`: slow at first, so you spot yourself, then away.
func intro_camera(seconds: float) -> void:
	if intro_tween:
		intro_tween.kill()
	intro = 1.0
	intro_tween = host.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	intro_tween.tween_property(self, "intro", 0.0, seconds).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## The menu looks at the house from close up (on) or the play camera takes
## over, further back (off), either way easing over MENU_BLEND_S; `instant` jumps.
func menu_view(on: bool, instant := false) -> void:
	if menu_tween:
		menu_tween.kill()
	var to := 1.0 if on else 0.0
	if instant or is_equal_approx(menu_blend, to):
		menu_blend = to
		return
	menu_tween = host.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	menu_tween.tween_property(self, "menu_blend", to, MENU_BLEND_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


## A jolt of the camera: 0.6 for a guard's first yell, less for a crash.
func shake(amount: float) -> void:
	trauma = minf(trauma + amount, 1.0)


## The piece is yours: the camera swoops in on the thief and eases back out.
func punch_in() -> void:
	if punch_tween:
		punch_tween.kill()
	punch_tween = host.create_tween()
	punch_tween.tween_property(self, "punch", 1.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	punch_tween.tween_property(self, "punch", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
