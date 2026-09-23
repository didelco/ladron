extends Node3D
## The game: screens, the loop, and drawing the world each frame.
##
## Screens: title (pick the museum size) → mission (the job, the plan, a map)
## → playing ⇄ paused → caught, or escaped with the piece (next level). No
## clock: a round lasts as long as it takes. The loop is the web version's Game.tsx tick: thieves and their
## noise, the job and its alarm, guards, the yell, the warning, keeping apart,
## lights, thinking (Laya through BrainClient, or the fallback rules),
## hidden, caught.

## the guards think this often
const THINK_EVERY_MS := 1100.0
const SIZE_NAMES := {"small": "CHICO", "medium": "MEDIANO", "large": "GRANDE"}
const DIFFICULTY_NAMES := {"easy": "FÁCIL", "medium": "MEDIA", "hard": "DIFÍCIL"}
## What a guard yells on spotting you.
const SHOUTS := ["¡ALTO!", "¡QUIETO!", "¡PARA!"]

const COLOURS := {
	"night": Color("#0f0d14"),
	"thief": Color("#2ec4a6"),
	"thief_dark": Color("#12705f"),
	"thief2": Color("#f0a13a"),
	"thief2_dark": Color("#8a5410"),
	"guard": Color("#9b2c3f"),
	"guard_dark": Color("#5e1826"),
	"ink": Color("#08070c"),
	"alert": Color("#ff3d6e"),
	"cone": Color("#ffd479"),
	"cone_alert": Color("#ffa94d"),
	"lit": Color("#eef3ff"),
	"switch_off": Color("#f87171"),
	"switch_on": Color("#4ade80"),
	"safe": Color("#22d3ee"),
}

## Physical keys the game reads, by the names Sim.SCHEMES uses.
const KEYS := {
	KEY_W: "w", KEY_A: "a", KEY_S: "s", KEY_D: "d",
	KEY_UP: "up", KEY_DOWN: "down", KEY_LEFT: "left", KEY_RIGHT: "right",
	KEY_C: "c", KEY_SHIFT: "shift", KEY_MINUS: "minus", KEY_SLASH: "slash",
}
## A fixed handful of room lights, handed to the lit rooms nearest the camera.
const ROOM_LIGHT_POOL := 4
const CONE_RAYS := 40

var size := "small"
## one thief or two on the same keyboard
var players := 1
var sound_on := true
var show_ia := false
## where the settings screen goes back to: "title" or "paused"
var settings_from := "title"
var level := 1
var thieves: Array[Thief] = []
var guards: Array[Guard] = []
var phase := "title"
var stride := [0.0, 0.0]
var last_think := 0.0
var last_spread := 0.0
var think_tick := 0
var log_lines: Array[String] = []

var brain: BrainClient
var sfx: Sfx
var hud: Hud
var world: Node3D
var camera: Camera3D
var thief_nodes: Array[Figure] = []
var guard_nodes: Array[Figure] = []
var torches: Array[SpotLight3D] = []
var room_lights: Array[OmniLight3D] = []
var cones: Array[MeshInstance3D] = []
var switch_marks: Array[MeshInstance3D] = []
var lit_washes: Array[MeshInstance3D] = []
var loot_node: MeshInstance3D


func _ready() -> void:
	brain = BrainClient.new()
	add_child(brain)
	brain.decided.connect(_on_decided)
	brain.failed.connect(_on_brain_failed)
	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	_build_environment()
	# A museum behind the title screen, so it is not a black void.
	_new_round(1)
	_show_title()
	# For recording and testing: `godot -- --autostart` skips the title, shows
	# the mission for two seconds and starts the round; add --two for two thieves.
	if "--autostart" in OS.get_cmdline_user_args():
		if "--two" in OS.get_cmdline_user_args():
			players = 2
			_new_round(1)
		_show_mission()
		get_tree().create_timer(2.0).timeout.connect(_start_playing)


# --- Screens -----------------------------------------------------------------------

func _show_title() -> void:
	phase = "title"
	hud.show_menu([
		{"title": "¡APAGA LA LUZ\nQUE TE PILLO!", "size": 64},
		{"buttons": [
			{"icon": Hud.thief_icon([COLOURS.thief]), "call": _start.bind(1), "colour": COLOURS.thief},
			{"icon": Hud.thief_icon([COLOURS.thief, COLOURS.thief2]), "call": _start.bind(2), "colour": COLOURS.thief2},
		], "row": true},
		{"buttons": [
			{"text": "DIFICULTAD: %s" % DIFFICULTY_NAMES[Sim.difficulty], "call": _next_difficulty.bind("title"), "colour": _difficulty_colour()},
			{"text": "✦ SETTINGS", "call": _show_settings.bind("title")},
		]},
	])


## Easy, medium, hard, round again. Mid-round (from the pause) the guards'
## senses and pace change at once; the clock and the lock at the next museum.
func _next_difficulty(from: String) -> void:
	Sim.difficulty = {"easy": "medium", "medium": "hard", "hard": "easy"}[Sim.difficulty]
	if from == "title":
		_show_title()
	else:
		_show_settings(from)


func _difficulty_colour() -> Color:
	return {"easy": Hud.C.green, "medium": Hud.C.gold, "hard": Hud.C.alert}[Sim.difficulty]


func _start(n: int) -> void:
	players = n
	_new_round(1)
	_show_mission()


## Sound, the IA panel and the size of the museum. Opens from the title and
## from the pause; the size takes effect on the next museum built.
func _show_settings(from: String) -> void:
	settings_from = from
	phase = "settings"
	hud.show_menu([
		{"title": "SETTINGS", "size": 48},
		{"buttons": [
			{"text": "SONIDO: %s  (M)" % ("SÍ" if sound_on else "NO"), "call": _toggle_sound},
			{"text": "PANEL IA: %s" % ("SÍ" if show_ia else "NO"), "call": _toggle_ia},
			{"text": "DIFICULTAD: %s" % DIFFICULTY_NAMES[Sim.difficulty], "call": _next_difficulty.bind(from), "colour": _difficulty_colour()},
			{"text": "MUSEO: %s · %d %s" % [SIZE_NAMES[size], Sim.guard_count(size), "GUARDIA" if Sim.guard_count(size) == 1 else "GUARDIAS"], "call": _next_size},
			{"text": "◂ VOLVER", "call": _settings_back},
		]},
		{"text": "P1: WASD · C para ponerse a gatas" if players == 1 or from == "title" else "P1: WASD · C    P2: flechas · - o /"},
		{"text": "Con un solo jugador valen también las flechas y Shift."},
	])


func _toggle_sound() -> void:
	_set_sound(not sound_on)
	_show_settings(settings_from)


func _set_sound(on: bool) -> void:
	sound_on = on
	AudioServer.set_bus_mute(0, not on)


func _toggle_ia() -> void:
	show_ia = not show_ia
	_show_settings(settings_from)


func _next_size() -> void:
	size = {"small": "medium", "medium": "large", "large": "small"}[size]
	# A fresh museum behind the title shows the new size; mid-round, the
	# change waits for the next museum.
	if settings_from == "title":
		_new_round(1)
	_show_settings(settings_from)


func _settings_back() -> void:
	if settings_from == "paused":
		_pause()
	else:
		_show_title()


func _pause() -> void:
	phase = "paused"
	hud.show_menu([
		{"title": "PAUSA", "size": 56},
		{"buttons": [
			{"text": "▶ SEGUIR", "call": _start_playing},
			{"text": "✦ SETTINGS", "call": _show_settings.bind("paused")},
			{"text": "◂ MENÚ", "call": _show_title},
		]},
	])


func _show_mission() -> void:
	phase = "mission"
	# Little text: the piece, the map, and on the first level one line on how.
	# The map already says where you come in, where the piece is and the door.
	var lines := [Heist.first_upper(Heist.loot.name)]
	if level == 1:
		lines.append("Quieto %s ante la pieza · la alarma atrae guardias · sal por la puerta verde" % _seconds(Heist.loot.seconds))
	var items: Array = [{"title": "NIVEL %02d" % level, "size": 52}]
	for l in lines:
		items.append({"text": l})
	items.append({"picture": Hud.mission_map(guards)})
	items.append({"buttons": [{"text": "▶ EMPEZAR", "call": _start_playing}]})
	hud.show_menu(items)


func _show_end() -> void:
	var title := "TE HAN PILLADO"
	var colour: Color = Hud.C.alert
	var line := "Nivel %d: %s %s." % [level, Heist.loot.name, "vuelve a su vitrina" if Heist.taken else "sigue en su sitio"]
	if phase == "escaped":
		title = "¡GOLPE PERFECTO!"
		colour = Hud.C.safe
		line = "Nivel %d superado: %s ya es tuyo." % [level, Heist.loot.name]
	hud.show_menu([
		{"title": title, "colour": colour, "size": 52},
		{"text": line},
		{"buttons": [
			{"text": "▶ SIGUIENTE GOLPE" if phase == "escaped" else "▶ OTRA VEZ", "call": _again},
			{"text": "◂ MENÚ", "call": _show_title},
		]},
	])


func _again() -> void:
	_new_round(level + 1 if phase == "escaped" else level)
	_show_mission()


func _seconds(s: float) -> String:
	return ("%d segundos" % int(s)) if is_equal_approx(s, round(s)) else ("%s segundos" % str(s).replace(".", ","))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var key: int = event.keycode
	# Menus are buttons (mouse, arrows and Enter); these are the shortcuts.
	if key == KEY_M:
		_set_sound(not sound_on)
		if phase == "settings":
			_show_settings(settings_from)
		return
	match phase:
		"title":
			if key in [KEY_1, KEY_2]:
				_start(key - KEY_0)
		"mission":
			if key == KEY_SPACE:
				_start_playing()
			elif key == KEY_ESCAPE:
				_show_title()
		"playing":
			if key == KEY_ESCAPE or key == KEY_P:
				_pause()
		"paused":
			if key == KEY_ESCAPE or key == KEY_P:
				_start_playing()
		"settings":
			if key == KEY_ESCAPE:
				_settings_back()
		"caught", "escaped":
			if key == KEY_SPACE:
				_again()
			elif key == KEY_ESCAPE:
				_show_title()


func _start_playing() -> void:
	phase = "playing"
	hud.hide_panel()


# --- Rounds --------------------------------------------------------------------------

func _new_round(n: int) -> void:
	level = n
	Sim.new_map(randi() % 1000000000, size)
	thieves = [Sim.new_thief("p1")]
	if players == 2:
		thieves.append(Sim.new_thief("p2"))
	guards = Sim.new_guards(Sim.guard_count(size))
	Heist.plan_job(level)
	stride = [0.0, 0.0]
	last_think = 0.0
	think_tick = 0
	log_lines.clear()
	Sim.thoughts.clear()
	Sim.light_events.clear()
	_build_world()
	_snap_camera()


func _pressed_keys() -> Dictionary:
	var keys := {}
	for k in KEYS:
		if Input.is_physical_key_pressed(k):
			keys[KEYS[k]] = true
	return keys


# --- The loop ------------------------------------------------------------------------

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
		# On your own both pads drive you; with two, each pad is its own.
		var scheme := "solo" if thieves.size() == 1 else ("wasd" if i == 0 else "arrows")
		var step := Sim.step_thief(p, keys, dt, scheme)
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
			var what := "step" if noise.kind in ["walk", "sprint", "rustle"] else ("shelf" if noise.kind == "shelf" else "bump")
			sfx.at(what, _to_world(p.x, p.y), clampf(noise.loudness / 9.0, 0.15, 1.0))

	# The job: working the case (and its alarm), carrying, dropping, the door.
	var before_alarms := noises.size()
	var took := Heist.step(thieves, dt, now, noises)
	if noises.size() > before_alarms:
		if Heist.progress < 0.1:
			_log("¡Salta la alarma de la vitrina!")
		sfx.at("alarm", _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5), 0.8)
	match took:
		"stolen":
			sfx.ui("stolen")
			_log("Tienes %s: ahora, a la salida" % Heist.loot.name)
		"dropped":
			_log("%s ha caído al suelo" % Heist.first_upper(Heist.loot.name))
		"picked":
			sfx.ui("pick")

	Sim.tick_lights(dt)
	var saw_before := {}
	for g in guards:
		saw_before[g.id] = g.sees_player
	for g in guards:
		Sim.step_guard(g, thieves, noises, now, dt)
	for s in Sim.call_for_backup(saw_before, guards, now):
		sfx.at("shout", _to_world(s.x, s.y), 1.0 if s.first else 0.5)
		if s.first:
			var heard_by: Array = s.heard_by
			var heard: String = ("%s lo ha oído y viene" % " y ".join(heard_by)) if not heard_by.is_empty() else "nadie más lo ha oído"
			var ear := thieves[0]
			var angle := atan2(s.y - ear.y, s.x - ear.x)
			var d := Museum.dist(ear.x, ear.y, s.x, s.y)
			hud.shout(SHOUTS[randi() % SHOUTS.size()], "%s grita %s · %s" % [s.from, "a lo lejos" if d > 9 else "cerca", heard], angle)
			_log("%s: ¡Alto! — %s" % [s.from, heard])
	for w in Sim.warn_partners(guards, now):
		sfx.at("whisper", _to_world(w.x, w.y), 0.6)
		_log("%s avisa a %s en voz baja" % [w.from, w.to])
	for t in Sim.thoughts:
		_log("%s: %s" % [t.by, t.text])
	Sim.thoughts.clear()
	for e in Sim.light_events:
		var label := "la sala"
		for z in Museum.zones:
			if z.room == e.room:
				label = z.label
		var r: Museum.Room = Museum.rooms[e.room]
		sfx.at("lights", _to_world(r.switch_at.x + 0.5, r.switch_at.y + 0.5), 0.8)
		_log("%s enciende las luces de %s" % [e.by, label])
	Sim.light_events.clear()

	if now - last_spread > 500:
		last_spread = now
		Sim.keep_apart(guards)
	# Thinking. Only guards with a decision to make are asked, and everyone
	# every third time; without the brain, the fallback rules decide.
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
			sfx.ui("caught")
	# No clock: take as long as you like. Out of the door with the piece wins;
	# everyone caught loses.
	if took == "out":
		phase = "escaped"
		sfx.ui("escaped")
		_show_end()
	elif thieves.all(func(p): return p.out):
		phase = "caught"
		_show_end()


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

func _to_world(x: float, y: float, height: float = 0.0) -> Vector3:
	return MuseumView.to_world(x, y, height)


func _flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = COLOURS.night
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# The building is shut: what you see by is the torches, the room lights
	# once switched on, and this faint blue night.
	env.ambient_light_color = Color("#6f78a8")
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-60, 30, 0)
	moon.light_energy = 0.12
	add_child(moon)
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
		switch_marks.append(_switch(r))
		var wash := MeshInstance3D.new()
		var p := PlaneMesh.new()
		p.size = Vector2(r.rect.size.x, r.rect.size.y)
		wash.mesh = p
		var wm := _flat(Color(COLOURS.lit, 0.18))
		wm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		wash.material_override = wm
		wash.position = _to_world(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0, 0.02)
		wash.visible = false
		world.add_child(wash)
		lit_washes.append(wash)

	_build_job()

	for i in thieves.size():
		# Second pad, second colour: two teal figures would be one figure.
		var f := Figure.make("thief", COLOURS.thief if i == 0 else COLOURS.thief2, COLOURS.thief_dark if i == 0 else COLOURS.thief2_dark)
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
		var cm := _flat(Color(COLOURS.cone, 0.12))
		cm.cull_mode = BaseMaterial3D.CULL_DISABLED
		cone.material_override = cm
		world.add_child(cone)
		cones.append(cone)


## A light switch as mounted: a panel with a lever on the wall face, a conduit
## up to a junction box on the wall's cap, and the box's lamp — red while the
## room is dark, green once someone has thrown it. The lamp is what reads from
## the camera; it is what gets returned, to be recoloured.
func _switch(r: Museum.Room) -> MeshInstance3D:
	var s := r.switch_at
	var root := Node3D.new()
	root.position = _to_world(s.x + 0.5 + r.face.x * 0.5, s.y + 0.5 + r.face.y * 0.5)
	root.rotation.y = atan2(-r.face.x, -r.face.y)
	world.add_child(root)
	var part := func(size: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		m.material_override = MuseumView.toon(colour)
		m.position = at
		root.add_child(m)
		return m
	part.call(Vector3(0.24, 0.32, 0.04), COLOURS.ink, Vector3(0, 0.8, 0.02))
	part.call(Vector3(0.2, 0.28, 0.05), Color("#e8ddc0"), Vector3(0, 0.8, 0.04))
	part.call(Vector3(0.05, 0.12, 0.05), COLOURS.ink, Vector3(0, 0.82, 0.08)).rotation.x = 0.5
	part.call(Vector3(0.05, 0.3, 0.04), Color("#5a5560"), Vector3(0, 1.05, 0.03))
	part.call(Vector3(0.28, 0.1, 0.28), Color("#5a5560"), Vector3(0, MuseumView.WALL_HEIGHT + MuseumView.CAP_H + 0.05, -0.18))
	var lamp := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.07
	c.height = 0.05
	lamp.mesh = c
	lamp.material_override = _flat(COLOURS.switch_off)
	lamp.position = Vector3(0, MuseumView.WALL_HEIGHT + MuseumView.CAP_H + 0.12, -0.18)
	root.add_child(lamp)
	return lamp


## The piece, glowing over its case, and the door out: a frame in the outer
## wall with a green door, a light over it and SALIDA above.
func _build_job() -> void:
	var colour := Color(Heist.loot.colour)
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 1.4
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	loot_node = MeshInstance3D.new()
	loot_node.material_override = m
	world.add_child(loot_node)
	_loot_shape(loot_node, Heist.loot.shape, m)
	var glow := OmniLight3D.new()
	glow.light_color = colour
	glow.light_energy = 1.2
	glow.omni_range = 2.5
	loot_node.add_child(glow)

	var door := Node3D.new()
	door.position = _to_world(Heist.exit.x + 0.5 + Heist.exit_face.x * 0.5, Heist.exit.y + 0.5 + Heist.exit_face.y * 0.5)
	door.rotation.y = atan2(-Heist.exit_face.x, -Heist.exit_face.y)
	world.add_child(door)
	var box := func(size: Vector3, mat: Material, at: Vector3) -> void:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
		mi.material_override = mat
		mi.position = at
		door.add_child(mi)
	var frame := MuseumView.toon(Color("#1b1622"))
	box.call(Vector3(0.1, 1.3, 0.12), frame, Vector3(-0.42, 0.65, 0.04))
	box.call(Vector3(0.1, 1.3, 0.12), frame, Vector3(0.42, 0.65, 0.04))
	box.call(Vector3(0.94, 0.1, 0.12), frame, Vector3(0, 1.3, 0.04))
	var panel := StandardMaterial3D.new()
	panel.albedo_color = COLOURS.switch_on.darkened(0.3)
	panel.emission_enabled = true
	panel.emission = COLOURS.switch_on
	panel.emission_energy_multiplier = 0.6
	box.call(Vector3(0.74, 1.2, 0.04), panel, Vector3(0, 0.6, 0.02))
	box.call(Vector3(0.06, 0.06, 0.05), MuseumView.toon(Color("#f0c46a")), Vector3(0.26, 0.6, 0.06))
	var sign := Label3D.new()
	sign.text = "SALIDA"
	sign.font = Hud.ARCADE
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.modulate = COLOURS.switch_on
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.75, 0.1)
	door.add_child(sign)
	var exit_light := OmniLight3D.new()
	exit_light.light_color = COLOURS.switch_on
	exit_light.light_energy = 1.5
	exit_light.omni_range = 3.0
	exit_light.position = Vector3(0, 1.5, 0.5)
	door.add_child(exit_light)


## Each piece its own shape: a cut gem, an egg, a crown with points, a jade
## mask with eye holes, a pitted meteorite, an idol with a head.
func _loot_shape(node: MeshInstance3D, shape: String, mat: Material) -> void:
	var add := func(mesh: Mesh, at: Vector3, rot := Vector3.ZERO, colour := Color.TRANSPARENT) -> void:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = at
		mi.rotation = rot
		mi.material_override = mat if colour == Color.TRANSPARENT else _flat(colour)
		node.add_child(mi)
	match shape:
		"gem":
			var s := SphereMesh.new()
			s.radius = 0.15
			s.height = 0.34
			s.radial_segments = 6
			s.rings = 2
			node.mesh = s
		"egg":
			var s := SphereMesh.new()
			s.radius = 0.13
			s.height = 0.34
			node.mesh = s
		"crown":
			var t := CylinderMesh.new()
			t.top_radius = 0.16
			t.bottom_radius = 0.15
			t.height = 0.1
			node.mesh = t
			for i in 5:
				var a := i * TAU / 5
				var p := CylinderMesh.new()
				p.top_radius = 0.0
				p.bottom_radius = 0.035
				p.height = 0.1
				add.call(p, Vector3(cos(a) * 0.15, 0.1, sin(a) * 0.15))
				var g := SphereMesh.new()
				g.radius = 0.022
				g.height = 0.044
				add.call(g, Vector3(cos(a) * 0.155, 0.02, sin(a) * 0.155), Vector3.ZERO, Color("#c2185b"))
		"mask":
			var s := SphereMesh.new()
			s.radius = 0.16
			s.height = 0.34
			node.mesh = s
			node.scale = Vector3(1, 1, 0.45)
			for dx in [-0.06, 0.06]:
				var e := SphereMesh.new()
				e.radius = 0.035
				e.height = 0.05
				add.call(e, Vector3(dx, 0.04, 0.15), Vector3.ZERO, Color("#08070c"))
		"idol":
			var c := CapsuleMesh.new()
			c.radius = 0.08
			c.height = 0.3
			node.mesh = c
			var h := SphereMesh.new()
			h.radius = 0.08
			h.height = 0.16
			add.call(h, Vector3(0, 0.22, 0))
			for side in [-1, 1]:
				var a := CapsuleMesh.new()
				a.radius = 0.025
				a.height = 0.16
				add.call(a, Vector3(side * 0.1, 0.03, 0), Vector3(0, 0, side * 0.4))
		_:
			var s := SphereMesh.new()
			s.radius = 0.15
			s.height = 0.24
			s.radial_segments = 7
			s.rings = 4
			node.mesh = s


# --- Drawing -------------------------------------------------------------------------

func _draw_frame(dt: float) -> void:
	for i in thieves.size():
		var p := thieves[i]
		var f := thief_nodes[i]
		f.set_state(_to_world(p.x, p.y), p.dir, p.posture, dt)
		f.scale = Vector3.ONE * (0.75 if p.out else 1.0)
		# Seen through the cases: your colour while nobody sees you, the
		# alarm red the moment one does, all but gone once you are out.
		if p.out:
			f.set_ghost(COLOURS.ink, 0.35)
		elif p.hidden:
			f.set_ghost(COLOURS.thief if i == 0 else COLOURS.thief2, 0.75)
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
	_draw_room_lights()
	_draw_loot()
	_follow_camera(dt)
	_draw_hud()


func _draw_room_lights() -> void:
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


## The piece: turning over its case, on the thief's back, or on the floor.
func _draw_loot() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if Heist.carrier != "":
		var c: Thief = thieves[0]
		for p in thieves:
			if p.id == Heist.carrier:
				c = p
		loot_node.position = _to_world(c.x - cos(c.dir) * 0.2, c.y - sin(c.dir) * 0.2, 1.05 - c.posture * 0.5)
	elif Heist.dropped != Vector2.INF:
		loot_node.position = _to_world(Heist.dropped.x, Heist.dropped.y, 0.2)
	else:
		loot_node.position = _to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05 + sin(t * 2.0) * 0.05)
	loot_node.rotation.y = t * 1.2


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


func _draw_hud() -> void:
	if thieves.is_empty():
		return
	var ia := "IA: Laya %d ms" % brain.last_ms if brain.status == "laya" else "IA: reglas"
	var parts := PackedStringArray()
	for i in thieves.size():
		var p := thieves[i]
		var stance := "DE PIE"
		if p.crouched:
			stance = "A GATAS" if p.posture >= 1.0 else "BAJANDO"
		elif p.posture > 0:
			stance = "SUBIENDO"
		var state := "PILLADO" if p.out else ("A CUBIERTO" if p.hidden else "A LA VISTA")
		parts.append(("P%d " % (i + 1) if thieves.size() == 2 else "") + "%s · %s" % [state, stance])
	parts.append(ia)
	var any_seen := thieves.any(func(p): return not p.out and not p.hidden)
	# The arrow at the screen edge, from whoever is nearest: to the piece, or
	# to the door once someone has it.
	var goal := Heist.objective()
	var ref := thieves[0]
	for p in thieves:
		if not p.out and (ref.out or Museum.dist(p.x, p.y, goal.x, goal.y) < Museum.dist(ref.x, ref.y, goal.x, goal.y)):
			ref = p
	var d := Museum.dist(ref.x, ref.y, goal.x, goal.y)
	var angle := atan2(goal.y - ref.y, goal.x - ref.x) if d > 6 and phase == "playing" else NAN
	var job := {
		"working": Heist.by != "",
		"progress": Heist.progress,
		"verb": Heist.loot.verb,
		"carrying": Heist.carrier != "",
		"dropped": Heist.dropped != Vector2.INF,
		"name": Heist.loot.name,
	}
	if not hud.menu_open():
		hud.update_play("   ".join(parts), COLOURS.alert if any_seen else COLOURS.safe, log_lines, job, angle, COLOURS.switch_on if Heist.carrier != "" else Color(Heist.loot.colour))
	var cards: Array = []
	for g in guards:
		var card := {"name": g.name, "title": "Te ha visto" if g.sees_player else (g.decision.label if g.decision else "pensando…"), "colour": COLOURS.alert if g.sees_player else Hud.C.text}
		if g.decision and not g.sees_player:
			var opts: Array = []
			for k in g.decision.probabilities:
				opts.append([g.decision.labels.get(k, k), g.decision.probabilities[k]])
			opts.sort_custom(func(a, b): return a[1] > b[1])
			card.options = opts
			card.note = "ritmo %d%% · %s%s" % [roundi(g.decision.aggression * 100), Mind.LOOK_LABEL[g.decision.look], " · duda" if g.decision.torn else ""]
		cards.append(card)
	hud.set_ia(show_ia and phase == "playing", cards)
