extends Node3D
## The game: screens, the loop, and drawing the world each frame.
##
## Two modes. The story: ten fixed nights, easy to hard, with a tale (Story).
## The generative: a new museum every time, at the difficulty and size you
## pick. Either with one thief or two; with two, the job takes both (Heist).
##
## Screens: title (pick the mode) → the mode's menu (players, and the night or
## the difficulty) → [prologue] → loot (the piece and its story) → mission
## (the plan, a map) → countdown → playing ⇄ paused → caught, or escaped with the piece (next level). No
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

## "story" or "generative"
var mode := "story"
## the story night picked on its menu
var story_pick := 1
var size := "small"
## one thief or two on the same keyboard
var players := 1
var sound_on := true
var music_on := true
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
var props_view: PropsView
## the alarm panel, two thieves only: its lamp and glow, red till held
var panel_mat: StandardMaterial3D
var panel_glow: OmniLight3D
## the piece turning on its own stand, on the loot screen
var preview: SubViewport
var preview_pivot: Node3D
var preview_spot: OmniLight3D


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
	# --menu=story|generative|settings: open a menu straight away, to look at it.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):
			match arg.substr(7):
				"story": _show_story_menu()
				"generative": _show_generative_menu()
				"settings": _show_settings("title")
	# --intro: the piece, then the countdown, for checking the way in.
	if "--intro" in OS.get_cmdline_user_args():
		_start("generative" if "--gen" in OS.get_cmdline_user_args() else "story", 2 if "--two" in OS.get_cmdline_user_args() else 1)
		get_tree().create_timer(1.5).timeout.connect(_start_countdown)
	if "--autostart" in OS.get_cmdline_user_args():
		if "--two" in OS.get_cmdline_user_args():
			players = 2
			_new_round(1)
		_show_mission()
		get_tree().create_timer(2.0).timeout.connect(_start_playing)


# --- Screens -----------------------------------------------------------------------

func _show_title() -> void:
	phase = "title"
	_drop_preview()
	hud.show_menu([
		{"title": "¡APAGA LA LUZ\nQUE TE PILLO!", "size": 64},
		{"cards": [
			{"title": "HISTORIA", "text": "Diez noches con la Banda del Calcetín", "stage": MenuStage.make("story"), "call": _show_story_menu, "colour": Hud.C.safe},
			{"title": "GENERATIVO", "text": "Un museo nuevo cada vez", "stage": MenuStage.make("generative"), "call": _show_generative_menu, "colour": Hud.C.gold},
		], "width": 340},
		{"buttons": [{"text": "✦ SETTINGS", "call": _show_settings.bind("title"), "colour": Hud.C.dim}]},
	])


## The story: the path of nights (any reached so far can be picked), the
## piece of the night picked turning under a light, and one thief or two.
func _show_story_menu() -> void:
	phase = "menu"
	story_pick = clampi(story_pick, 1, Story.unlocked())
	var nights: Array = []
	for n in range(1, Story.count() + 1):
		nights.append({"n": n, "colour": Color(Story.level(n).loot.colour), "locked": n > Story.unlocked(), "selected": n == story_pick, "call": _pick_night.bind(n)})
	var loot: Dictionary = Story.level(story_pick).loot
	_build_preview(loot)
	hud.show_menu([
		{"title": "MODO HISTORIA", "size": 44},
		{"text": "La Banda del Calcetín contra el Barón Von Bostezo", "colour": Hud.C.gold, "size": 17},
		{"nights": nights},
		{"picture": preview.get_texture(), "smooth": true, "height": 130},
		{"text": "NOCHE %d · %s" % [story_pick, loot.name.to_upper()], "colour": Color(loot.colour), "size": 17, "id": "night"},
		{"cards": [
			{"title": "1 LADRÓN", "text": "Tú solo contra el museo", "stage": MenuStage.make("players:1"), "call": _start.bind("story", 1), "colour": COLOURS.thief},
			{"title": "2 LADRONES", "text": "Uno sujeta la alarma, otro abre", "stage": MenuStage.make("players:2"), "call": _start.bind("story", 2), "colour": COLOURS.thief2},
		], "width": 250},
		{"buttons": [{"text": "◂ VOLVER", "call": _show_title, "colour": Hud.C.dim}], "row": true},
	])


## Moving along the path picks the night: the piece and its name change in
## place, the menu stays as it is.
func _pick_night(n: int) -> void:
	if n == story_pick or preview == null:
		return
	story_pick = n
	var loot: Dictionary = Story.level(n).loot
	_preview_piece(loot)
	hud.set_text("night", "NOCHE %d · %s" % [n, loot.name.to_upper()], Color(loot.colour))


## The generative mode: difficulty and museum size as cards, then play with
## one thief or two.
func _show_generative_menu() -> void:
	phase = "menu"
	var levels: Array = []
	for k in ["easy", "medium", "hard"]:
		levels.append({"title": DIFFICULTY_NAMES[k], "stage": MenuStage.make("guards:" + k), "call": _pick_difficulty.bind(k),
			"colour": {"easy": Hud.C.green, "medium": Hud.C.gold, "hard": Hud.C.alert}[k], "selected": Sim.difficulty == k, "focus": Sim.difficulty == k, "title_size": 14})
	var sizes: Array = []
	for k in ["small", "medium", "large"]:
		sizes.append({"title": SIZE_NAMES[k], "stage": MenuStage.make("museum:" + k), "call": _pick_size.bind(k),
			"colour": Hud.C.safe, "selected": size == k, "title_size": 14})
	hud.show_menu([
		{"title": "MODO GENERATIVO", "size": 40},
		{"cards": levels, "width": 180},
		{"cards": sizes, "width": 180},
		{"cards": [
			{"title": "▶ 1 LADRÓN", "stage": MenuStage.make("players:1"), "call": _start.bind("generative", 1), "colour": COLOURS.thief, "title_size": 14},
			{"title": "▶ 2 LADRONES", "stage": MenuStage.make("players:2"), "call": _start.bind("generative", 2), "colour": COLOURS.thief2, "title_size": 14},
		], "width": 240},
		{"buttons": [{"text": "◂ VOLVER", "call": _show_title, "colour": Hud.C.dim}], "row": true},
	])


func _pick_difficulty(k: String) -> void:
	Sim.difficulty = k
	_show_generative_menu()


func _pick_size(k: String) -> void:
	size = k
	_show_generative_menu()


func _start(which: String, n: int) -> void:
	mode = which
	players = n
	if mode == "story":
		_new_round(story_pick)
		if story_pick == 1:
			_show_prologue()
			return
	else:
		_new_round(1)
	_show_loot()


func _show_prologue() -> void:
	phase = "prologue"
	hud.show_menu([
		{"title": "HABÍA UNA VEZ...", "size": 44},
		{"text": Story.PROLOGUE, "size": 18, "wrap": true},
		{"buttons": [{"text": "▶ ¡VAMOS!", "call": _show_loot}]},
	])


## Sound, the IA panel and the size of the museum. Opens from the title and
## from the pause; the size takes effect on the next museum built.
func _show_settings(from: String) -> void:
	settings_from = from
	phase = "settings"
	hud.show_menu([
		{"title": "SETTINGS", "size": 48},
		{"buttons": [
			{"text": "SONIDO: %s  (M)" % ("SÍ" if sound_on else "NO"), "call": _toggle_sound},
			{"text": "MÚSICA: %s" % ("SÍ" if music_on else "NO"), "call": _toggle_music},
			{"text": "PANEL IA: %s" % ("SÍ" if show_ia else "NO"), "call": _toggle_ia},
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


func _toggle_music() -> void:
	music_on = not music_on
	sfx.set_music(music_on)
	_show_settings(settings_from)


func _toggle_ia() -> void:
	show_ia = not show_ia
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


## First the piece: turning under a light, its name, and the story of why
## someone wants it.
func _show_loot() -> void:
	phase = "loot"
	_build_preview()
	hud.show_menu([
		{"title": ("NOCHE %d DE %d" % [level, Story.count()]) if mode == "story" else ("NIVEL %02d" % level), "size": 40},
		{"text": "ESTA NOCHE HAY QUE RECUPERAR" if mode == "story" else "ESTA NOCHE VAS A ROBAR", "size": 16, "colour": Hud.C.dim},
		{"picture": preview.get_texture(), "smooth": true, "height": 250},
		{"title": Heist.loot.name.to_upper(), "size": 30, "colour": Color(Heist.loot.colour)},
		{"text": Heist.loot.blurb, "colour": Hud.C.gold},
		{"text": Heist.loot.story, "size": 17, "wrap": true},
		{"buttons": [{"text": "▶ VER EL PLAN", "call": _show_mission}]},
	])


func _build_preview(loot: Dictionary = Heist.loot) -> void:
	_drop_preview()
	preview = SubViewport.new()
	preview.size = Vector2i(480, 300)
	preview.own_world_3d = true
	preview.transparent_bg = true
	preview.msaa_3d = Viewport.MSAA_4X
	add_child(preview)
	# Axonometric, like every picture in the menus.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = cam.basis.z * 10.0 + Vector3(0, 0.08, 0)
	cam.size = 0.62
	preview.add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	preview.add_child(sun)
	preview_spot = OmniLight3D.new()
	preview_spot.position = Vector3(0, 0.8, 0.4)
	preview_spot.light_energy = 1.5
	preview.add_child(preview_spot)
	# A velvet stand under it.
	var stand := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.25
	c.height = 0.08
	stand.mesh = c
	stand.material_override = MuseumView.toon(Color("#4a1d3a"))
	stand.position = Vector3(0, -0.12, 0)
	preview.add_child(stand)
	preview_pivot = Node3D.new()
	preview_pivot.position = Vector3(0, 0.1, 0)
	preview.add_child(preview_pivot)
	_preview_piece(loot)


## Swap the piece on the stand, keeping the stand, the camera and the picture.
func _preview_piece(loot: Dictionary) -> void:
	for c in preview_pivot.get_children():
		c.queue_free()
	preview_spot.light_color = Color(loot.colour)
	var colour := Color(loot.colour)
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = 0.5
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	var piece := MeshInstance3D.new()
	piece.material_override = m
	preview_pivot.add_child(piece)
	_loot_shape(piece, loot.shape, m)


func _drop_preview() -> void:
	if preview:
		preview.queue_free()
		preview = null
		preview_pivot = null
		preview_spot = null


func _show_mission() -> void:
	phase = "mission"
	# Little text: the piece, the map, and on the first level one line on how.
	# The map already says where you come in, where the piece is and the door.
	var lines := [Heist.first_upper(Heist.loot.name)]
	if Heist.team:
		lines.append("Uno sujeta el cuadro de la alarma (naranja) mientras el otro abre la vitrina")
	elif level == 1:
		lines.append("Quieto %s ante la pieza · la alarma atrae guardias · sal por la puerta verde" % _seconds(Heist.loot.seconds))
	var items: Array = [{"title": "EL PLAN", "size": 52}]
	for l in lines:
		items.append({"text": l})
	items.append({"picture": Hud.mission_map(guards)})
	items.append({"buttons": [{"text": "▶ EMPEZAR", "call": _start_countdown}]})
	hud.show_menu(items)


func _show_end() -> void:
	var title := "TE HAN PILLADO"
	var colour: Color = Hud.C.alert
	var line := "%s %s." % [Heist.first_upper(Heist.loot.name), "vuelve a su vitrina" if Heist.taken else "sigue en su sitio"]
	var next := "▶ OTRA VEZ"
	if phase == "escaped":
		title = "¡GOLPE PERFECTO!"
		colour = Hud.C.safe
		line = "%s vuelve a casa." % Heist.first_upper(Heist.loot.name) if mode == "story" else "Nivel %d superado: %s ya es tuyo." % [level, Heist.loot.name]
		next = "▶ SIGUIENTE NOCHE" if mode == "story" else "▶ SIGUIENTE GOLPE"
		if mode == "story":
			Story.unlock(level + 1)
			story_pick = mini(level + 1, Story.count())
			if level >= Story.count():
				_show_ending()
				return
	var picture: Dictionary = {"stage": MenuStage.make("guards:hard"), "height": 170}
	if phase == "escaped":
		_build_preview()
		picture = {"picture": preview.get_texture(), "smooth": true, "height": 170}
	hud.show_menu([
		{"title": title, "colour": colour, "size": 52},
		picture,
		{"text": line},
		{"buttons": [
			{"text": next, "call": _again, "colour": colour},
			{"text": "◂ MENÚ", "call": _show_title, "colour": Hud.C.dim},
		], "row": true},
	])


func _show_ending() -> void:
	phase = "ending"
	sfx.ui("escaped")
	hud.show_menu([
		{"title": "¡OPERACIÓN\nDEVOLVERLO TODO!", "colour": Hud.C.safe, "size": 48},
		{"text": Story.ENDING, "size": 18, "wrap": true},
		{"buttons": [{"text": "◂ MENÚ", "call": _show_title}]},
	])


func _again() -> void:
	_new_round(level + 1 if phase == "escaped" else level)
	_show_loot()


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
		"menu":
			if key == KEY_ESCAPE:
				_show_title()
		"prologue":
			if key == KEY_SPACE:
				_show_loot()
			elif key == KEY_ESCAPE:
				_show_title()
		"ending":
			if key == KEY_ESCAPE or key == KEY_SPACE:
				_show_title()
		"loot":
			if key == KEY_SPACE:
				_show_mission()
			elif key == KEY_ESCAPE:
				_show_title()
		"mission":
			if key == KEY_SPACE:
				_start_countdown()
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


## 3, 2, 1, GO! over the museum, everyone frozen in place until it is over.
func _start_countdown() -> void:
	phase = "countdown"
	_drop_preview()
	hud.hide_panel()
	hud.countdown(_count_beep, _start_playing)


func _count_beep(i: int) -> void:
	sfx.ui("go" if i == 3 else "tick")


func _start_playing() -> void:
	phase = "playing"
	_drop_preview()
	hud.hide_panel()


# --- Rounds --------------------------------------------------------------------------

func _new_round(n: int) -> void:
	if mode == "story":
		n = clampi(n, 1, Story.count())
	level = n
	if mode == "story":
		var night := Story.level(n)
		Sim.custom = Story.tuning(n)
		Sim.new_map(Story.seed_for(n), night.size, -1, night.shape)
	else:
		Sim.custom = {}
		Sim.new_map(randi() % 1000000000, size)
	thieves = [Sim.new_thief("p1")]
	if players == 2:
		thieves.append(Sim.new_thief("p2"))
	guards = Sim.new_guards(Sim.guard_count(Museum.size_name))
	Heist.plan_job(level, Story.level(n).loot if mode == "story" else {}, players == 2)
	# Things to knock over: never on the tiles the job needs clear.
	var stand := Heist.route[0]
	for t in Heist.route:
		if Museum.dist(t.x + 0.5, t.y + 0.5, Heist.at.x + 0.5, Heist.at.y + 0.5) < 1.1:
			stand = t
			break
	Props.place(Story.seed_for(n) if mode == "story" else randi(), [Heist.exit, Heist.panel, stand, Heist.start])
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
	if preview_pivot:
		preview_pivot.rotate_y(dt * 0.9)
	_music_mood()
	if phase == "playing":
		_tick(dt)
	_draw_frame(dt)


## The music follows the guards: creeping while they are calm, a pulse
## once any is on alert, all of it while one can see you. Softer in menus.
func _music_mood() -> void:
	var tension := 0.0
	var in_game := phase in ["playing", "countdown", "paused"]
	if in_game:
		for g in guards:
			if g.sees_player:
				tension = 1.0
			elif g.alert:
				tension = maxf(tension, 0.55)
	sfx.mood(tension, 0.8 if in_game else 0.5)


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

	# Walking into things: over they go, with a crash.
	Props.step(thieves, now, noises)
	for p in Props.knocked:
		props_view.knock(p)
		sfx.at(p.kind, _to_world(p.x, p.y), 1.0)
		_log("¡Has tirado %s!" % Props.NAMES[p.kind])

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
			sfx.ui("sting", 0.7)
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
	props_view = PropsView.new()
	world.add_child(props_view)
	props_view.build()

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
	panel_mat = null
	panel_glow = null
	if Heist.team:
		_build_panel()
	var exit_light := OmniLight3D.new()
	exit_light.light_color = COLOURS.switch_on
	exit_light.light_energy = 1.5
	exit_light.omni_range = 3.0
	exit_light.position = Vector3(0, 1.5, 0.5)
	door.add_child(exit_light)


## The alarm panel: a grey box on the wall with a big lamp, orange while it
## waits, green while someone holds it.
func _build_panel() -> void:
	var node := Node3D.new()
	node.position = _to_world(Heist.panel.x + 0.5 + Heist.panel_face.x * 0.5, Heist.panel.y + 0.5 + Heist.panel_face.y * 0.5)
	node.rotation.y = atan2(-Heist.panel_face.x, -Heist.panel_face.y)
	world.add_child(node)
	var box := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.6, 0.14)
	box.mesh = b
	box.material_override = MuseumView.toon(Color("#5c6370"))
	box.position = Vector3(0, 1.0, 0.07)
	node.add_child(box)
	panel_mat = StandardMaterial3D.new()
	panel_mat.emission_enabled = true
	panel_mat.emission_energy_multiplier = 2.0
	var lamp := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.2
	lamp.mesh = s
	lamp.material_override = panel_mat
	lamp.position = Vector3(0, 1.1, 0.16)
	node.add_child(lamp)
	var lever := MeshInstance3D.new()
	var l := BoxMesh.new()
	l.size = Vector3(0.06, 0.2, 0.06)
	lever.mesh = l
	lever.material_override = MuseumView.toon(Color("#e03131"))
	lever.position = Vector3(0.14, 0.88, 0.17)
	node.add_child(lever)
	panel_glow = OmniLight3D.new()
	panel_glow.light_energy = 1.2
	panel_glow.omni_range = 2.5
	panel_glow.position = Vector3(0, 1.1, 0.5)
	node.add_child(panel_glow)
	var sign := Label3D.new()
	sign.text = "ALARMA"
	sign.font = Hud.ARCADE
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.modulate = Color("#ff922b")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.55, 0.1)
	node.add_child(sign)


func _draw_panel() -> void:
	if panel_mat == null:
		return
	var held := Heist.panel_by != ""
	var t := Time.get_ticks_msec() / 1000.0
	var c := COLOURS.switch_on if held else Color("#ff922b")
	panel_mat.albedo_color = c
	panel_mat.emission = c
	panel_glow.light_color = c
	# Blinks while someone waits at the case for it.
	panel_glow.light_energy = 1.2 if held or not Heist.waiting else (0.4 + 1.2 * absf(sin(t * 6.0)))


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
		"teeth":
			# Pink gums, a row of white teeth on top and one below.
			var gum := CapsuleMesh.new()
			gum.radius = 0.05
			gum.height = 0.3
			node.mesh = gum
			node.rotation = Vector3(0, 0, PI / 2)
			for row in [-1, 1]:
				for k in 6:
					var tooth := BoxMesh.new()
					tooth.size = Vector3(0.035, 0.035, 0.04)
					add.call(tooth, Vector3(row * 0.045, -0.1 + k * 0.04, 0.02), Vector3.ZERO, Color("#fffdf5"))
		"duck":
			var body := SphereMesh.new()
			body.radius = 0.14
			body.height = 0.2
			node.mesh = body
			var head := SphereMesh.new()
			head.radius = 0.08
			head.height = 0.16
			add.call(head, Vector3(0.07, 0.14, 0))
			var beak := CylinderMesh.new()
			beak.top_radius = 0.0
			beak.bottom_radius = 0.035
			beak.height = 0.08
			add.call(beak, Vector3(0.17, 0.13, 0), Vector3(0, 0, -PI / 2), Color("#ff8c1a"))
			for dz in [-0.035, 0.035]:
				var eye := SphereMesh.new()
				eye.radius = 0.015
				eye.height = 0.03
				add.call(eye, Vector3(0.12, 0.17, dz), Vector3.ZERO, Color("#08070c"))
		"sock":
			var leg := CapsuleMesh.new()
			leg.radius = 0.07
			leg.height = 0.32
			node.mesh = leg
			node.position.y += 0.06
			var foot := CapsuleMesh.new()
			foot.radius = 0.07
			foot.height = 0.24
			add.call(foot, Vector3(0.07, -0.13, 0), Vector3(0, 0, PI / 2))
			for k in 2:
				var stripe := CylinderMesh.new()
				stripe.top_radius = 0.073
				stripe.bottom_radius = 0.073
				stripe.height = 0.025
				add.call(stripe, Vector3(0, 0.1 - k * 0.05, 0), Vector3.ZERO, Color("#e03131"))
		"toast":
			var bread := BoxMesh.new()
			bread.size = Vector3(0.28, 0.3, 0.05)
			node.mesh = bread
			var crumb := BoxMesh.new()
			crumb.size = Vector3(0.22, 0.24, 0.02)
			add.call(crumb, Vector3(0, -0.01, 0.02), Vector3.ZERO, Color("#f3d9a4"))
			# The Barón's face: two eyes and a moustache, in burn.
			for dx in [-0.05, 0.05]:
				var eye := SphereMesh.new()
				eye.radius = 0.018
				eye.height = 0.02
				add.call(eye, Vector3(dx, 0.04, 0.035), Vector3.ZERO, Color("#6b3d12"))
			var tache := CapsuleMesh.new()
			tache.radius = 0.015
			tache.height = 0.14
			add.call(tache, Vector3(0, -0.03, 0.035), Vector3(0, 0, PI / 2), Color("#6b3d12"))
		"clock":
			var face := CylinderMesh.new()
			face.top_radius = 0.15
			face.bottom_radius = 0.15
			face.height = 0.05
			node.mesh = face
			node.rotation = Vector3(PI / 2, 0, 0)
			var dial := CylinderMesh.new()
			dial.top_radius = 0.125
			dial.bottom_radius = 0.125
			dial.height = 0.01
			add.call(dial, Vector3(0, 0.026, 0), Vector3.ZERO, Color("#f8f9fa"))
			for hand in [[0.09, 0.3], [0.06, 2.1]]:
				var bar := BoxMesh.new()
				bar.size = Vector3(0.012, 0.012, hand[0])
				var a: float = hand[1]
				add.call(bar, Vector3(sin(a) * hand[0] / 2, 0.034, cos(a) * hand[0] / 2), Vector3(0, a, 0), Color("#08070c"))
			for side in [-1, 1]:
				var bell := SphereMesh.new()
				bell.radius = 0.045
				bell.height = 0.05
				add.call(bell, Vector3(side * 0.1, 0, -0.13), Vector3.ZERO, Color("#f0c46a"))
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
	_draw_panel()
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
		"waiting": Heist.waiting,
		"panel": Heist.panel_by != "" and not Heist.taken,
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
