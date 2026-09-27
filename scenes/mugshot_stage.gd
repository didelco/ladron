class_name MugshotStage
extends MenuStage
## One of the two police photos of the file (EndPages.mugshot), the same
## every time: the ninja's head, close up, from the front or in profile
## (looking left), against the height chart on the station's wall, under a
## hard lamp from above, with the caught face (Figure.caught_face) and a
## drop of sweat. The page prints it in black and white.
##
## Made with MugshotStage.of(side): false for the front, true for the side.

## How far the profile is turned from the front (degrees): not quite side
## on, so an eye and the face still show.
const PROFILE := 55.0

## The wall and its chart.
const CHART_WALL := Color("#b9c3cc")
const CHART_INK := Color("#2b3440")
## The thief's suit: grey in the photo, but a colour for the light to shade.
const SUIT := Color("#2ec4a6")
const SUIT_SHADE := Color("#12705f")
## Between the chart's lines (m), and the one every so often numbered;
## what the numbers say is centimetres.
const CHART_STEP := 0.05
const CHART_EVERY := 2
const CHART_CM := 100.0
const PHOTO := Vector2i(300, 240)
## How much the photo takes in, up and down (m), and the height it is
## centred on: the head, from the chin up.
const SPAN := 0.85
const LOOK_AT := 0.93

var side := false


static func of(profile: bool) -> MugshotStage:
	var s := MugshotStage.new()
	s.kind = "mugshot"
	s.side = profile
	s._setup()
	return s


func _build() -> void:
	size = PHOTO
	_cam.rotation_degrees = Vector3.ZERO
	var distance := SPAN * 0.5 / tan(deg_to_rad(FOV * 0.5))
	_cam.position = Vector3(0, LOOK_AT, distance)
	_harsh()
	_chart(3.0, SPAN * 0.5 * float(size.x) / size.y - 0.08)
	var f := _figure("thief", SUIT, SUIT_SHADE, 1.0)
	f.set_xray(false)
	f.caught_face()


## The station's lamp: hard, straight down from just in front, darkening the
## eyes under the brows; everything else turned down.
func _harsh() -> void:
	for c in get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			env.ambient_light_energy = 0.22
			env.glow_enabled = false
			env.ssao_intensity = 2.2
		elif c is Light3D:
			(c as Light3D).light_energy *= 0.25
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(0, 2.1, 1.1)
	lamp.look_at_from_position(lamp.position, Vector3(0, LOOK_AT, 0.1), Vector3.FORWARD)
	lamp.spot_angle = 22
	lamp.spot_angle_attenuation = 0.6
	lamp.light_energy = 4.0
	lamp.light_color = Color("#fff6e8")
	lamp.shadow_enabled = true
	lamp.shadow_blur = 0.3
	add_child(lamp)


## The wall behind: pale, a black line every CHART_STEP, numbered every
## CHART_EVERY, the numbers this far out from the middle.
func _chart(width: float, edge: float) -> void:
	_box(_root, Vector3(width, 2.2, 0.05), CHART_WALL, Vector3(0, 1.1, -0.45))
	for k in range(10, 30):
		var y := k * CHART_STEP
		var big := k % CHART_EVERY == 0
		_box(_root, Vector3(width, 0.006 if big else 0.003, 0.01), CHART_INK, Vector3(0, y, -0.42))
		if big:
			for s in [-1.0, 1.0]:
				var l := Label3D.new()
				l.text = str(int(round(y * CHART_CM)))
				l.font = Hud.ARCADE
				l.font_size = 32
				l.pixel_size = 0.0011
				l.modulate = CHART_INK
				l.outline_size = 0
				l.position = Vector3(s * edge, y + 0.02, -0.41)
				_root.add_child(l)


func _pose(dt: float) -> void:
	_stand(dt)


func _animate(dt: float) -> void:
	_stand(dt)


## Facing the camera, or turned to show its left side (looking left in the
## photo); sweating.
func _stand(dt: float) -> void:
	var f := _figures[0]
	f.set_state(Vector3.ZERO, PI / 2 + (deg_to_rad(PROFILE) if side else 0.0), 0.0, maxf(dt, 0.016))
	f.sweat(true)
