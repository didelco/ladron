class_name MinigameStage
extends SubViewport
## The little 3D scene a minigame (Minigame) is played on, drawn with a
## clear background into the box beside the thief (MinigameBox): the menus'
## lighting (MenuStage), a warm lamp and a cool moon, and a camera; what is
## in it is the kind's own view (MinigameView, scenes/minigame_views/).
## Shaking hands shake the view.

const SIZE := Vector2i(220, 170)
const FOV := 24.0

var game: Minigame
var _view: MinigameView
var _cam: Camera3D
var _kind := ""
var _steps := 0
var _colour := Color("#2ec4a6")


func _init() -> void:
	size = SIZE
	own_world_3d = true
	transparent_bg = true
	Quality.setup_viewport(self)
	render_target_update_mode = SubViewport.UPDATE_DISABLED
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#6a5a9a")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# The menus' lighting: a warm lamp front left with soft shadows, a cool
	# moon rimming the edges from behind.
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -35, 0)
	key.light_color = Color("#ffc98a")
	key.light_energy = 0.9
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 150, 0)
	fill.light_color = Color("#8f9cff")
	fill.light_energy = 0.5
	add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = FOV
	add_child(_cam)


## Play this game (or none: the scene goes still and stops drawing); the
## thief's colour dresses whatever wears it.
func show_game(g: Minigame, colour := Color("#2ec4a6")) -> void:
	game = g
	render_target_update_mode = SubViewport.UPDATE_ALWAYS if g else SubViewport.UPDATE_DISABLED
	if g == null:
		return
	if _view == null or g.kind != _kind or g.steps != _steps or colour != _colour:
		_build(g, colour)
	_view.game = g
	for e in g.events:
		if e in ["pin", "snip", "done"]:
			_view.good = 1.0
		elif e in ["slip", "spark"]:
			_view.bad = 1.0


func _build(g: Minigame, colour: Color) -> void:
	if _view:
		_view.queue_free()
	_kind = g.kind
	_steps = g.steps
	_colour = colour
	_view = MinigameView.make(g.kind)
	_view.game = g
	_view.colour = colour
	add_child(_view)
	_view.build()
	var f := _view.framing()
	_cam.rotation_degrees = f.get("angle", Vector3(-12, 14, 0))
	var span: float = f.get("span", 1.3)
	_cam.position = Vector3(0, f.get("look", 0.0), 0) + _cam.basis.z * (span * 0.5 / tan(deg_to_rad(FOV * 0.5)))


func _process(dt: float) -> void:
	if game == null or _view == null:
		return
	_view.t += dt
	_view.good = maxf(0.0, _view.good - dt * 3.0)
	_view.bad = maxf(0.0, _view.bad - dt * 3.0)
	_cam.h_offset = 0.012 * game.tremble * sin(_view.t * 47.0)
	_cam.v_offset = 0.012 * game.tremble * sin(_view.t * 39.0 + 1.0)
	_view.pose(dt)
