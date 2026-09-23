extends Node3D
## The game, still without the looks: the museum is boxes, the thief and the
## guards are capsules with a nose. The guards think with Laya through the
## brain service (BrainClient), and with the fallback rules (Mind.fallback)
## whenever it is not there. Everything is built from code, so this one scene
## is the whole game for now. The loop is the web version's Game.tsx tick:
## thieves, noises, guards, the yell, the warning, keeping apart, lights,
## hidden, caught, the clock.

## small, medium or large
@export var size := "small"
## the guards think this often, like the web's think() without Laya
const THINK_EVERY_MS := 1100.0

const COLOURS := {
	"night": Color("#0f0d14"),
	"floor": Color("#2b2834"),
	"wall": Color("#3a3446"),
	"cover": Color("#5b6f86"),
	"thief": Color("#2ec4a6"),
	"thief_dark": Color("#12705f"),
	"guard": Color("#9b2c3f"),
	"guard_dark": Color("#5e1826"),
	"ink": Color("#08070c"),
	"alert": Color("#ff3d6e"),
	"cone": Color("#ffd479"),
	"cone_alert": Color("#ffa94d"),
	"lit": Color("#eef3ff"),
	"switch_off": Color("#f87171"),
	"switch_on": Color("#4ade80"),
}

## Physical keys the game reads, by the names Sim.SCHEMES uses.
const KEYS := {
	KEY_W: "w", KEY_A: "a", KEY_S: "s", KEY_D: "d",
	KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right",
	KEY_C: "c", KEY_SHIFT: "shift", KEY_MINUS: "minus", KEY_SLASH: "slash",
}

var thieves: Array[Thief] = []
var guards: Array[Guard] = []
var phase := "playing"
var time_left := Sim.ROUND_SECONDS
var stride := [0.0, 0.0]
var last_think := 0.0
var last_spread := 0.0
var log_lines: Array[String] = []
var think_tick := 0
var brain: BrainClient

var world: Node3D
var camera: Camera3D
var thief_nodes: Array[Figure] = []
var guard_nodes: Array[Figure] = []
var torches: Array[SpotLight3D] = []
## A fixed handful of room lights, handed to the lit rooms nearest the camera:
## a light per room would slow a big museum down.
const ROOM_LIGHT_POOL := 4
var room_lights: Array[OmniLight3D] = []
var cones: Array[MeshInstance3D] = []
var switch_marks: Array[MeshInstance3D] = []
var lit_washes: Array[MeshInstance3D] = []
var hud: Label
var banner: Label
var log_label: Label


func _ready() -> void:
	brain = BrainClient.new()
	add_child(brain)
	brain.decided.connect(_on_decided)
	brain.failed.connect(_on_brain_failed)
	_build_environment()
	_build_hud()
	new_round()


# --- Rounds ------------------------------------------------------------------

func new_round() -> void:
	Sim.new_map(randi() % 1000000000, size)
	thieves = [Sim.new_thief("p1")]
	guards = Sim.new_guards(Museum.SIZES[size].guards)
	phase = "playing"
	time_left = Sim.ROUND_SECONDS
	stride = [0.0, 0.0]
	last_think = 0.0
	log_lines.clear()
	Sim.thoughts.clear()
	Sim.light_events.clear()
	_build_world()
	_snap_camera()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE and phase != "playing":
			new_round()
		elif event.keycode in [KEY_1, KEY_2, KEY_3] and phase != "playing":
			size = ["small", "medium", "large"][event.keycode - KEY_1]
			new_round()


func _pressed_keys() -> Dictionary:
	var keys := {}
	for k in KEYS:
		if Input.is_physical_key_pressed(k):
			keys[KEYS[k]] = true
	return keys


# --- The loop --------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	if phase == "playing":
		_tick(dt)
	_draw_frame(dt)


func _tick(dt: float) -> void:
	var now := Sim.now_ms()
	var keys := _pressed_keys()
	var noises: Array[SoundEvent] = []
	for i in thieves.size():
		var p := thieves[i]
		var px := p.x
		var py := p.y
		var step := Sim.step_thief(p, keys, dt, "solo")
		var noise := Hearing.thief_noise(px, py, p, step.entered_cover, step.bumped, Sim.TOP_SPEED)
		# Footsteps land once per stride; a bump is its own event.
		stride[i] += Museum.dist(px, py, p.x, p.y)
		if noise and (noise.kind == "walk" or noise.kind == "sprint"):
			if stride[i] < 0.45 + p.speed / Sim.TOP_SPEED * 0.5:
				noise = null
			else:
				stride[i] = 0.0
		if noise and not p.out:
			noises.append(noise)

	Sim.tick_lights(dt)
	var saw_before := {}
	for g in guards:
		saw_before[g.id] = g.sees_player
	for g in guards:
		Sim.step_guard(g, thieves, noises, now, dt)
	for s in Sim.call_for_backup(saw_before, guards, now):
		if s.first:
			var heard: String = ", ".join(s.heard_by) if not (s.heard_by as Array).is_empty() else "nadie más"
			_log("%s: ¡Alto! (lo oye: %s)" % [s.from, heard])
	for w in Sim.warn_partners(guards, now):
		_log("%s avisa a %s en voz baja" % [w.from, w.to])
	for t in Sim.thoughts:
		_log("%s: %s" % [t.by, t.text])
	Sim.thoughts.clear()
	for e in Sim.light_events:
		var label := "la sala"
		for z in Museum.zones:
			if z.room == e.room:
				label = z.label
		_log("%s enciende las luces de %s" % [e.by, label])
	Sim.light_events.clear()

	if now - last_spread > 500:
		last_spread = now
		Sim.keep_apart(guards)
	# Thinking. Only guards with a decision to make are asked — a guard half
	# way through a plan made on the same facts would ignore the answer — and
	# everyone every third time, to keep pace and torch fresh. Without the
	# brain, the fallback rules decide for the ones that need it.
	if now - last_think > THINK_EVERY_MS:
		last_think = now
		think_tick += 1
		var everyone := think_tick % 3 == 0
		var asking: Array[Guard] = guards.filter(func(g): return not g.sees_player and (everyone or Sim.needs_plan(g)))
		if not brain.ask(asking, guards, now) and not brain.busy:
			for g in asking:
				if Sim.needs_plan(g):
					var others: Array[Guard] = guards.filter(func(o): return o != g)
					Sim.apply_decision(g, Mind.fallback(g, others, now))

	for p in thieves:
		p.hidden = Sim.is_hidden(guards, p)
		if Sim.caught(guards, p):
			p.out = true
			p.speed = 0
			_log("¡Te han pillado!")
	time_left -= dt
	if thieves.all(func(p): return p.out):
		phase = "caught"
	elif time_left <= 0:
		phase = "escaped"


func _on_decided(decisions: Dictionary, _ms: int) -> void:
	if phase != "playing":
		return
	for g in guards:
		if g.sees_player or not decisions.has(g.id):
			continue
		var before := g.decision.label if g.decision else ""
		Sim.apply_decision(g, decisions[g.id])
		# Log what it actually does: a committed guard keeps its plan.
		if g.decision.label != before:
			var p: float = g.decision.probabilities.get(g.decision.option, 0.0)
			_log("%s: %s · %d%%%s" % [g.name, g.decision.label, roundi(p * 100), " (duda)" if g.decision.torn else ""])


func _on_brain_failed(reason: String) -> void:
	_log("IA: reglas de reserva (%s)" % reason)


func _log(line: String) -> void:
	log_lines.push_front(line)
	log_lines = log_lines.slice(0, 8)


# --- Building the world --------------------------------------------------------

## Grid (x, y) to world (x, z): y is up, as Godot expects.
func _to_world(x: float, y: float, height: float = 0.0) -> Vector3:
	return Vector3(x - Museum.w / 2.0, height, y - Museum.h / 2.0)


func _material(colour: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COLOURS.night
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The building is shut and the lights are off: what you see by is the
	# torches, the room lights once switched on, and this faint blue night.
	env.ambient_light_color = Color("#6f78a8")
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	sun.light_energy = 0.12
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)


func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	thief_nodes.clear()
	guard_nodes.clear()
	torches.clear()
	room_lights.clear()
	cones.clear()
	switch_marks.clear()
	lit_washes.clear()

	# Floor, walls, cases and emergency lights: built once, never touched again.
	var view := MuseumView.new()
	view.build()
	world.add_child(view)

	# Switches, and the white wash that fills a lit room.
	for r in Museum.rooms:
		var mark := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.25, 0.25, 0.25)
		mark.mesh = b
		mark.material_override = _material(COLOURS.switch_off, true)
		var s := r.switch_at
		mark.position = _to_world(s.x + 0.5 + r.face.x * 0.4, s.y + 0.5 + r.face.y * 0.4, 1.25)
		world.add_child(mark)
		switch_marks.append(mark)
		var wash := MeshInstance3D.new()
		var p := PlaneMesh.new()
		p.size = Vector2(r.rect.size.x, r.rect.size.y)
		wash.mesh = p
		var wm := _material(Color(COLOURS.lit, 0.18), true)
		wm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		wash.material_override = wm
		wash.position = _to_world(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0, 0.02)
		wash.visible = false
		world.add_child(wash)
		lit_washes.append(wash)

	for p in thieves:
		var f := Figure.make("thief", COLOURS.thief, COLOURS.thief_dark)
		world.add_child(f)
		thief_nodes.append(f)
	for i in ROOM_LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = COLOURS.lit
		l.light_energy = 0.0
		l.omni_attenuation = 0.8
		world.add_child(l)
		room_lights.append(l)
	for g in guards:
		var f := Figure.make("guard", COLOURS.guard, COLOURS.guard_dark)
		world.add_child(f)
		guard_nodes.append(f)
		# A torch, not a bulb: narrow cone, soft edge, pointed where it looks.
		var torch := SpotLight3D.new()
		torch.light_color = COLOURS.cone
		torch.spot_attenuation = 1.0
		torch.shadow_enabled = true
		f.add_child(torch)
		torch.position = Vector3(0, 1.15, 0.1)
		torch.rotation.x = -0.35
		torches.append(torch)
		var cone := MeshInstance3D.new()
		cone.mesh = ImmediateMesh.new()
		var cm := _material(Color(COLOURS.cone, 0.12), true)
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cm.no_depth_test = false
		cone.material_override = cm
		world.add_child(cone)
		cones.append(cone)


func _multimesh(mesh: Mesh, tiles: Array[Vector2i], height: float, mat: Material) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = tiles.size()
	for i in tiles.size():
		mm.set_instance_transform(i, Transform3D(Basis(), _to_world(tiles[i].x + 0.5, tiles[i].y + 0.5, height)))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = mat
	world.add_child(node)


# --- Drawing -----------------------------------------------------------------

func _draw_frame(dt: float) -> void:
	for i in thieves.size():
		var p := thieves[i]
		var f := thief_nodes[i]
		f.set_state(_to_world(p.x, p.y), p.dir, p.posture, dt)
		f.scale = Vector3.ONE * (0.75 if p.out else 1.0)
		# Seen through the cases: your colour while nobody sees you, the alarm
		# red the moment one does, all but gone once you are out.
		if p.out:
			f.set_ghost(COLOURS.ink, 0.35)
		elif p.hidden:
			f.set_ghost(COLOURS.thief, 0.75)
		else:
			f.set_ghost(COLOURS.alert, 1.0)
	for i in guards.size():
		var g := guards[i]
		var f := guard_nodes[i]
		f.set_state(_to_world(g.x, g.y), g.dir, 0.0, dt)
		f.set_ghost(COLOURS.alert if g.sees_player else COLOURS.guard, 0.75)
		var view := Sim.view_of(g)
		var torch := torches[i]
		torch.light_color = COLOURS.alert if g.sees_player else COLOURS.cone
		torch.spot_angle = rad_to_deg(view.half) * 0.85
		torch.spot_range = view.range + 1.0
		# Under the ceiling lights a torch is pointless, and switched off.
		torch.light_energy = 0.0 if Museum.is_lit(g.x, g.y) else (6.0 if g.alert else 3.5)
		_draw_cone(g, cones[i])
	var lit: Array = []
	for r in Museum.rooms:
		var on := Museum.lights_left[r.id] > 0
		switch_marks[r.id].material_override.albedo_color = COLOURS.switch_on if on else COLOURS.switch_off
		lit_washes[r.id].visible = on
		if on:
			var c := _to_world(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0, 2.6)
			lit.append([c, c.distance_to(camera.position), Vector2(r.rect.size).length()])
	lit.sort_custom(func(a, b): return a[1] < b[1])
	for i in room_lights.size():
		var l := room_lights[i]
		if i < lit.size():
			l.position = lit[i][0]
			l.omni_range = lit[i][2] / 2.0 + 3.0
			l.light_energy = 2.5
		else:
			l.light_energy = 0.0
	_follow_camera(dt)
	_draw_hud()


const CONE_RAYS := 40


## The view cone, rebuilt from rays every frame so it stops at the walls.
func _draw_cone(g: Guard, node: MeshInstance3D) -> void:
	var im: ImmediateMesh = node.mesh
	im.clear_surfaces()
	var view := Sim.view_of(g)
	var origin := _to_world(g.x, g.y, 0.03)
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := Vector3.ZERO
	for i in CONE_RAYS:
		var a: float = g.dir - view.half + 2.0 * view.half * i / (CONE_RAYS - 1)
		# Painted over the cases: this is where someone standing is seen.
		var far := Museum.cast_ray(g.x, g.y, a, Sim.LIT_RANGE, true)
		var ex: float = g.x + cos(a) * view.range
		var ey: float = g.y + sin(a) * view.range
		var d: float = far if far > view.range and Museum.is_lit(ex, ey) else minf(far, view.range)
		var pnt := _to_world(g.x + cos(a) * d, g.y + sin(a) * d, 0.03)
		if i > 0:
			im.surface_add_vertex(origin)
			im.surface_add_vertex(prev)
			im.surface_add_vertex(pnt)
		prev = pnt
	im.surface_end()
	var m: StandardMaterial3D = node.material_override
	var colour: Color = COLOURS.alert if g.sees_player else (COLOURS.cone_alert if g.alert else COLOURS.cone)
	m.albedo_color = Color(colour, 0.22 if g.sees_player else (0.14 if g.alert else 0.07))


func _camera_target() -> Vector3:
	var live := thieves.filter(func(p): return not p.out)
	var watched: Array = live if not live.is_empty() else thieves
	var mx := 0.0
	var my := 0.0
	for p in watched:
		mx += p.x
		my += p.y
	mx /= watched.size()
	my /= watched.size()
	# Keep the frame inside the building.
	return _to_world(clampf(mx, 7, Museum.w - 7), clampf(my, 5.5, Museum.h - 5.5), 0.6)


func _snap_camera() -> void:
	var t := _camera_target()
	camera.position = t + Vector3(0, 15.4, 6)
	camera.look_at(t)


func _follow_camera(dt: float) -> void:
	var t := _camera_target()
	var k := 1.0 - pow(0.0015, dt)
	camera.position = camera.position.lerp(t + Vector3(0, 15.4, 6), k)
	camera.look_at(camera.position - Vector3(0, 15.4, 6))


# --- HUD ---------------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(20, 16)
	hud.add_theme_font_size_override("font_size", 22)
	layer.add_child(hud)
	log_label = Label.new()
	log_label.position = Vector2(20, 90)
	log_label.add_theme_font_size_override("font_size", 15)
	log_label.modulate = Color(1, 1, 1, 0.7)
	layer.add_child(log_label)
	banner = Label.new()
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 40)
	layer.add_child(banner)


func _draw_hud() -> void:
	var p := thieves[0]
	var stance := "DE PIE"
	if p.crouched:
		stance = "A GATAS" if p.posture >= 1.0 else "BAJANDO"
	elif p.posture > 0:
		stance = "SUBIENDO"
	var ia := "IA: Laya %d ms" % brain.last_ms if brain.status == "laya" else "IA: reglas"
	hud.text = "%02d   %s   %s   %s   %s" % [ceili(maxf(0.0, time_left)), "A CUBIERTO" if p.hidden else "A LA VISTA", stance, "museo %s (%s)" % [size, Museum.shape], ia]
	log_label.text = "\n".join(log_lines)
	if phase == "caught":
		banner.text = "TE HAN PILLADO\nESPACIO: otra vez · 1/2/3: tamaño"
	elif phase == "escaped":
		banner.text = "HAS AGUANTADO\nESPACIO: otra vez · 1/2/3: tamaño"
	else:
		banner.text = ""
	banner.position = get_viewport().get_visible_rect().size / 2.0 - banner.size / 2.0
