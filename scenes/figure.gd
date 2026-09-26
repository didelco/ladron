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

var guard := false
var _kind := "thief"
var _player: AnimationPlayer
var _materials: Array[StandardMaterial3D] = []
var _ghost_colour := Color.WHITE

var _last_pos := Vector3.INF
var _speed := 0.0
var _clip := ""


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


## How strong the rim light round the figure is (the dioramas' daylight
## washes it out at the game's strength).
func set_rim(amount: float) -> void:
	for m in _materials:
		if m.rim_enabled:
			m.rim = amount


## Place and pose the figure for this frame. dir is the grid heading (radians
## from +x); posture 0 standing, 1 on all fours.
func set_state(pos: Vector3, dir: float, posture: float, dt: float) -> void:
	if _last_pos != Vector3.INF and dt > 0:
		var raw := Vector2(pos.x - _last_pos.x, pos.z - _last_pos.z).length() / dt
		# Smoothed: the sim moves in steps, the clip should not flicker.
		_speed += (raw - _speed) * minf(dt * 10.0, 1.0)
	_last_pos = pos
	position = pos
	rotation.y = -dir + PI / 2
	_animate(posture)


# --- Building -------------------------------------------------------------------

func _build(colour: Color) -> void:
	_ghost_colour = colour * 0.75
	_ghost_colour.a = 1.0
	var model: Node3D = MODELS[_kind].instantiate()
	model.scale = Vector3.ONE * SIZE[_kind]
	add_child(model)
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


func _play(clip: String, speed: float, blend := BLEND) -> void:
	_player.speed_scale = speed
	if clip != _clip:
		_clip = clip
		_player.play(clip, blend)
