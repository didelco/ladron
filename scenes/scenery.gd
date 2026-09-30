class_name Scenery
extends RefCounted
## The 3D world of a round: built once from the museum and the gang (build), then drawn each frame
## (draw_figures, draw_room_lights, draw_loot). The figures and their torches and cones, the
## room lights and switches, the piece and its case, the exit door and the alarm panels.
## The floor, the walls and the cases are MuseumView's (DenView's, in the band's house).

## A fixed handful of room lights, handed to the lit rooms nearest the camera.
const ROOM_LIGHT_POOL := 4
const CONE_RAYS := 40

## The floor cone's dim throw, as a share of its bright pool.
const CONE_DIM := 0.4

## How soft the cone's edges are: between the two bands and at the far rim
## (metres), and at the sides (share of the cone's width on each side).
const CONE_BAND_FEATHER := 0.7
const CONE_RIM_FEATHER := 1.8
const CONE_SIDE_FEATHER := 0.2
const TORCH_FOG := 12.0
const ROOM_FOG := 4.0

## The torch is the hero light: a crisp near-white beam that owns the dark,
## brighter when its guard is on the hunt. Its colour is warmer than the moon
## and cooler than the lamps, so it never reads as either.
const TORCH_COLOUR := Color("#fff1d8")
const TORCH_ENERGY := 9.0
const TORCH_ENERGY_ALERT := 13.0

## A torch is alive, not a lamp on a pole: its strength breathes by up to
## this share either way, slowly (two waves, radians a second, so it never
## looks like a loop), and at its dimmest it goes a touch warmer. Too little
## to read as a flicker, or to change what the beam shows.
const TORCH_BREATH := 0.045
const TORCH_BREATH_SPEED := Vector2(1.7, 4.3)
const TORCH_WARM := Color("#ffdcae")

## The sack the piece goes in, on the carrier's back: big enough to read from
## the camera up high.
const SACK_SCALE := 1.4

## Lit rooms glow warm, like a hotel lobby with the chandeliers on.
const ROOM_LIGHT_COLOUR := Color("#ffc47e")
const ROOM_LIGHT_ENERGY := 1.4

## How much the flat wash over a lit room adds: the room must read as lit at
## a glance, but through the tonemapper a strong wash burns it to cream.
const ROOM_WASH := 0.07

## The colour of each level of suspicion: a hunch, alert, after you.
const SUSPICION_COLOURS := [Color.TRANSPARENT, Color("#ffd43b"), Color("#ff922b"), Color("#ff3048")]

## The bar under the marks, in this many steps: redrawn only on a change.
const SUSPICION_STEPS := 24

## What a guard that saw you get in shows beside its marks: the thing you
## are in (Guard.knows_kind), by its icon in the editor's catalogue.
const HIDEOUT_ICONS := {"plinth": "exhibit_plinth", "sarcophagus": "big_sarcophagus", "armour": "prop_armour",
	"trojan_horse": "big_trojan_horse", "mammoth": "big_mammoth", "log": "big_log", "car": "big_car",
	"fridge": "exhibit_fridge", "box": "exhibit_box", "legionary": "exhibit_legionary", "confessional": "exhibit_confessional",
	"chest": "exhibit_chest", "egg": "exhibit_egg", "shell": "exhibit_shell"}

## How big the icon is, in the marks' pixels.
const HIDEOUT_ICON_PX := 22

var host: Game
var thief_nodes: Array[Figure] = []
var guard_nodes: Array[Figure] = []
var torches: Array[SpotLight3D] = []
var room_lights: Array[OmniLight3D] = []
var cones: Array[MeshInstance3D] = []

## over each guard's head: its suspicion, and what was last drawn there
var suspicion_marks: Array[Sprite3D] = []
var suspicion_keys: Array[String] = []
var switch_marks: Array[MeshInstance3D] = []
var lit_washes: Array[MeshInstance3D] = []
var loot_node: Node3D

## Once stolen the piece goes in this sack: on the carrier's back, or on the
## floor where it was dropped.
var sack_node: Node3D

## the spotlight straight down on the piece's case, museum style
var loot_spot: SpotLight3D

## the alarm panel, two thieves only: its lamp and glow, red till held
## each alarm panel's lamp and its glow (two for a gang of four)
var panel_mats: Array[StandardMaterial3D] = []
var panel_glows: Array[OmniLight3D] = []
static var hideout_icons := {}


func _init(game: Game) -> void:
	host = game


func flat(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if colour.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## The world of a round, new: the old one goes, and the museum (or the house), its props,
## the switches, the piece and the door, the gang, the lights and the guards are made.
func build() -> void:
	if host.world:
		host.world.queue_free()
	host.world = Node3D.new()
	host.add_child(host.world)
	_forget()
	_view()
	_props()
	_rooms()
	build_job()
	_thieves()
	_practice_ground()
	for _g in host.guards:
		_guard()


## Nothing of the last world is kept.
func _forget() -> void:
	thief_nodes.clear()
	guard_nodes.clear()
	torches.clear()
	room_lights.clear()
	cones.clear()
	suspicion_marks.clear()
	suspicion_keys.clear()
	switch_marks.clear()
	lit_washes.clear()


## Floor, walls, cases and emergency lights: built once, never touched again.
## The band's house is built by its own view (DenView), a MuseumView all the same.
func _view() -> void:
	var home := host.mode == Practice.MODE
	var view: MuseumView
	if home:
		DenView.players = host.players
		view = DenView.new()
	else:
		view = MuseumView.new()
	host.nightenv.set_mood(home)
	# The house begins with every door shut (the lounge is where the band is),
	# on the plan too; the view draws them as they are.
	host.den_view = null
	host.museum_view = null
	if home:
		Den.reset_doors()
		Den.apply_doors()
	view.build()
	host.world.add_child(view)
	if home:
		host.den_view = view as DenView
	else:
		host.museum_view = view
	# (The world is new: what the last one held of a game went with it.)
	host.house.trial = null
	host.house.trial_lantern = null
	host.house.trial_view = null
	if home:
		host.house.trial_view = TrialView.new()
		host.world.add_child(host.house.trial_view)
		host.house.trial_view.setup(host.camera)
		host.house.trial_view.picked.connect(host.house.choose)
		host.house.trial_view.moved.connect(func() -> void: host.sfx.ui("nav", 0.6))


## The dust in the air and the things that fall over.
func _props() -> void:
	Fx.dust_field(host.world)
	host.props_view = PropsView.new()
	host.world.add_child(host.props_view)
	host.props_view.build()
	host.props_view.set_thieves(host.thieves.size())
	host.props_view.tipped.connect(host.loop.on_prop_tipped)
	host.props_view.kicked.connect(host.loop.on_prop_kicked)


## Switches, and the white wash that fills a lit room.
func _rooms() -> void:
	for r in Museum.rooms:
		switch_marks.append(switch_mount(r))
		var wash := MeshInstance3D.new()
		var p := PlaneMesh.new()
		p.size = Vector2(r.rect.size.x, r.rect.size.y)
		wash.mesh = p
		var wm := flat(Color(ROOM_LIGHT_COLOUR, ROOM_WASH))
		wm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		wash.material_override = wm
		wash.position = host._to_world(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0, 0.02)
		wash.visible = false
		host.world.add_child(wash)
		lit_washes.append(wash)


## The gang's figures, and the few lights handed to the lit rooms nearest the camera.
func _thieves() -> void:
	for i in host.thieves.size():
		# Second pad, second colour: two teal figures would be one figure.
		var f := Figure.make("thief", host._thief_colours()[i], host._thief_darks()[i])
		host.world.add_child(f)
		thief_nodes.append(f)
	for i in ROOM_LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = ROOM_LIGHT_COLOUR
		l.light_energy = 0.0
		l.omni_attenuation = 0.8
		l.light_specular = 0.6
		l.light_volumetric_fog_energy = ROOM_FOG
		host.world.add_child(l)
		room_lights.append(l)


## The practice ground has no guards, only scarecrows in a guard's coat
## (Practice.scarecrows) where the lessons put them, each with a torch:
## standing still, to sneak round. DenView dresses them with their cross.
func _practice_ground() -> void:
	host.house.mannequins.clear()
	host.house.scarecrow_list.clear()
	host.house.scarecrow_alert = Practice.alert_new()
	host.house.lamps = Practice.lamps_new()
	host.house.scarecrow_time = 0.0
	host.house.trial_end()
	if host.mode != Practice.MODE:
		return
	for sc in Practice.scarecrows(host.players):
		var dummy := Figure.make("guard", Game.COLOURS.guard, Game.COLOURS.guard_dark)
		host.world.add_child(dummy)
		dummy.set_state(host._to_world(sc.at.x + 0.5, sc.at.y + 0.5), sc.dir, 0.0, 0.0)
		dummy.set_meta("dir", sc.dir)
		host.house.mannequins.append(dummy)
		host.house.scarecrow_list.append(sc)


## One guard: its figure, the marks over its head, its torch and its view cone.
func _guard() -> void:
	var f := Figure.make("guard", Game.COLOURS.guard, Game.COLOURS.guard_dark)
	host.world.add_child(f)
	guard_nodes.append(f)
	# Over its head: how much it suspects (!, !!, !!!) and a bar for how
	# long until it calms down a step. Seen through walls, always.
	var mark := Sprite3D.new()
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.no_depth_test = true
	mark.shaded = false
	mark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mark.pixel_size = 0.05
	mark.render_priority = 10
	mark.position = Vector3(0, 2.9, 0)
	mark.visible = false
	f.add_child(mark)
	suspicion_marks.append(mark)
	suspicion_keys.append("")
	torches.append(_torch(f))
	var cone := MeshInstance3D.new()
	cone.mesh = ImmediateMesh.new()
	# White: the colour and the fades ride on the vertices.
	var cm := flat(Color(1, 1, 1, 0.99))
	cm.vertex_color_use_as_albedo = true
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone.material_override = cm
	host.world.add_child(cone)
	cones.append(cone)


## A torch, not a bulb: narrow cone, soft edge, pointed where it looks.
## Bright hotspot, a quick falloff to the rim, and crisp shadows so the
## cases and figures it sweeps throw long ones across the floor.
func _torch(f: Figure) -> SpotLight3D:
	var torch := SpotLight3D.new()
	torch.set_meta(Fx.LIGHTS_DUST, true)
	torch.light_color = TORCH_COLOUR
	# Falls off with distance quicker than a bulb, so the pool near the
	# guard is bright and the throw beyond it dim; and a low angle exponent
	# for a wide penumbra instead of a hard rim.
	torch.spot_attenuation = 1.0
	torch.spot_angle_attenuation = 0.5
	torch.light_specular = 1.0
	torch.shadow_enabled = true
	torch.shadow_bias = 0.04
	torch.shadow_normal_bias = 0.8
	torch.shadow_blur = 0.6
	torch.light_volumetric_fog_energy = TORCH_FOG
	f.add_child(torch)
	# Just ahead of the cap's peak (inside it, the shadowed head swallows the
	# beam), and turned round: a spot shines down its -Z, a figure faces +Z.
	torch.position = Vector3(0, 1.15, 0.3)
	torch.rotation = Vector3(-0.35, PI, 0)
	return torch


## A light switch as mounted: a panel with a lever on the wall face, a conduit
## up to a junction box on the wall's cap, and the box's lamp — red while the
## room is dark, green once someone has thrown it. The lamp is what reads from
## the camera; it is what gets returned, to be recoloured.
func switch_mount(r: Museum.Room) -> MeshInstance3D:
	var s := r.switch_at
	var root := Node3D.new()
	root.position = host._to_world(s.x + 0.5 + r.face.x * 0.5, s.y + 0.5 + r.face.y * 0.5)
	root.rotation.y = atan2(-r.face.x, -r.face.y)
	host.world.add_child(root)
	var part := func(size: Vector3, colour: Color, at: Vector3) -> MeshInstance3D:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = size
		m.mesh = b
		m.material_override = MuseumView.toon(colour)
		m.position = at
		root.add_child(m)
		return m
	part.call(Vector3(0.24, 0.32, 0.04), Game.COLOURS.ink, Vector3(0, 0.8, 0.02))
	part.call(Vector3(0.2, 0.28, 0.05), Color("#e8ddc0"), Vector3(0, 0.8, 0.04))
	part.call(Vector3(0.05, 0.12, 0.05), Game.COLOURS.ink, Vector3(0, 0.82, 0.08)).rotation.x = 0.5
	part.call(Vector3(0.05, 0.3, 0.04), Color("#5a5560"), Vector3(0, 1.05, 0.03))
	part.call(Vector3(0.28, 0.1, 0.28), Color("#5a5560"), Vector3(0, MuseumView.WALL_HEIGHT + MuseumView.CAP_H + 0.05, -0.18))
	var lamp := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.07
	c.bottom_radius = 0.07
	c.height = 0.05
	lamp.mesh = c
	lamp.material_override = flat(Game.COLOURS.switch_off)
	lamp.position = Vector3(0, MuseumView.WALL_HEIGHT + MuseumView.CAP_H + 0.12, -0.18)
	root.add_child(lamp)
	return lamp


## The piece, glowing over its case (with the spotlight from the ceiling, and
## the sack it will go in), and the way out.
func build_job() -> void:
	var colour := Color(Heist.loot.colour)
	loot_node = LootModels.build(Heist.loot.shape, colour)
	host.world.add_child(loot_node)
	sack_node = LootModels.sack()
	sack_node.scale = Vector3.ONE * SACK_SCALE
	sack_node.visible = false
	host.world.add_child(sack_node)
	# The star of the collection gets a spotlight from the ceiling: a cone of
	# warm white straight down on its case, its beam showing in the dust.
	# (The band's house has neither the spotlight nor the door of a heist:
	# its own front door is DenView's.)
	var home := host.mode == Practice.MODE
	loot_spot = null
	if not home:
		loot_spot = SpotLight3D.new()
		loot_spot.position = host._to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 4.2)
		loot_spot.rotation = Vector3(-PI / 2, 0, 0)
		loot_spot.light_color = Color("#fff0d6")
		loot_spot.light_energy = 14.0
		loot_spot.spot_range = 6.0
		loot_spot.spot_angle = 17.0
		loot_spot.spot_angle_attenuation = 0.6
		loot_spot.shadow_enabled = true
		loot_spot.light_volumetric_fog_energy = 6.0
		host.world.add_child(loot_spot)
	var glow := OmniLight3D.new()
	glow.light_color = colour
	glow.light_energy = 1.2
	glow.omni_range = 2.5
	loot_node.add_child(glow)
	panel_mats.clear()
	panel_glows.clear()
	if not home:
		_exit_door()


## The way out: a frame in the outer wall with a green door, a light over it and
## SALIDA above, and the alarm panels of a gang.
func _exit_door() -> void:
	var door := Node3D.new()
	door.position = host._to_world(Heist.exit.x + 0.5 + Heist.exit_face.x * 0.5, Heist.exit.y + 0.5 + Heist.exit_face.y * 0.5)
	door.rotation.y = atan2(-Heist.exit_face.x, -Heist.exit_face.y)
	host.world.add_child(door)
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
	panel.albedo_color = Game.COLOURS.switch_on.darkened(0.3)
	panel.emission_enabled = true
	panel.emission = Game.COLOURS.switch_on
	panel.emission_energy_multiplier = 0.6
	box.call(Vector3(0.74, 1.2, 0.04), panel, Vector3(0, 0.6, 0.02))
	box.call(Vector3(0.06, 0.06, 0.05), MuseumView.toon(Color("#f0c46a")), Vector3(0.26, 0.6, 0.06))
	var sign := Label3D.new()
	sign.text = Text.t("HUD_SIGN_EXIT")
	sign.font = Hud.ARCADE
	sign.font_size = 48
	sign.pixel_size = 0.004
	sign.modulate = Game.COLOURS.switch_on
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.75, 0.1)
	door.add_child(sign)
	if Heist.team:
		build_panel(Heist.panel, Heist.panel_face)
	if Heist.team and Heist.panel2.x >= 0:
		build_panel(Heist.panel2, Heist.panel2_face)
	var exit_light := OmniLight3D.new()
	exit_light.light_color = Game.COLOURS.switch_on
	exit_light.light_energy = 1.5
	exit_light.omni_range = 3.0
	exit_light.position = Vector3(0, 1.5, 0.5)
	door.add_child(exit_light)


## The alarm panel: a grey box on the wall with a big lamp, orange while it
## waits, green while someone holds it.
func build_panel(at: Vector2i, face: Vector2i) -> void:
	var node := Node3D.new()
	node.position = host._to_world(at.x + 0.5 + face.x * 0.5, at.y + 0.5 + face.y * 0.5)
	node.rotation.y = atan2(-face.x, -face.y)
	host.world.add_child(node)
	var box := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 0.6, 0.14)
	box.mesh = b
	box.material_override = MuseumView.toon(Color("#5c6370"))
	box.position = Vector3(0, 1.0, 0.07)
	node.add_child(box)
	var panel_mat := StandardMaterial3D.new()
	panel_mat.emission_enabled = true
	panel_mat.emission_energy_multiplier = 2.0
	panel_mats.append(panel_mat)
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
	var panel_glow := OmniLight3D.new()
	panel_glows.append(panel_glow)
	panel_glow.light_energy = 1.2
	panel_glow.omni_range = 2.5
	panel_glow.position = Vector3(0, 1.1, 0.5)
	node.add_child(panel_glow)
	var sign := Label3D.new()
	sign.text = Text.t("HUD_SIGN_ALARM")
	sign.font = Hud.ARCADE
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.modulate = Color("#ff922b")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 1.55, 0.1)
	node.add_child(sign)


func draw_panel() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in panel_mats.size():
		var held := (Heist.panel_by if i == 0 else Heist.panel2_by) != "" or (Heist.panel_off if i == 0 else Heist.panel2_off)
		var c := Game.COLOURS.switch_on if held else Color("#ff922b")
		panel_mats[i].albedo_color = c
		panel_mats[i].emission = c
		panel_glows[i].light_color = c
		# Blinks while someone waits at the case for it.
		panel_glows[i].light_energy = 1.2 if held or not Heist.waiting else (0.4 + 1.2 * absf(sin(t * 6.0)))


## The ears, the thieves, the guards (their marks, torches and cones) and the scarecrows.
func draw_figures(dt: float) -> void:
	# The ears between the thieves still in, facing the way the camera does
	# (so left on screen is left in the ear).
	if host.ear and host.camera:
		var at := Vector3.ZERO
		var n := 0
		for t in host.thieves:
			if not t.out:
				at += host._to_world(t.x, t.y, 1.2)
				n += 1
		host.ear.global_transform = Transform3D(host.camera.global_basis, at / n if n > 0 else host.camera.global_position)
	for i in host.thieves.size():
		var p := host.thieves[i]
		var f := thief_nodes[i]
		f.set_state(host._to_world(p.x, p.y, Plinths.HEIGHT if p.posing else 0.0), p.dir, p.posture, dt, host._pose_of(p))
		# On one foot on a pedestal, the statue sways as its balance does.
		f.set_lean((p.game as BalanceGame).lean if p.posing and p.game is BalanceGame else 0.0)
		# Gone out of the door: not in the museum any more.
		f.visible = not p.safe and not p.hiding
		f.scale = Vector3.ONE * (0.75 if p.out else 1.0)
		# Seen through the cases: your colour while nobody sees you, the
		# alarm red the moment one does, all but gone once you are out.
		if p.out:
			f.set_ghost(Game.COLOURS.ink, 0.35)
		elif p.hidden:
			f.set_ghost(host._thief_colours()[i], 0.75)
		else:
			f.set_ghost(Game.COLOURS.alert, 1.0)
	for i in host.guards.size():
		var g := host.guards[i]
		var f := guard_nodes[i]
		f.set_state(host._to_world(g.x, g.y), g.dir, 0.0, dt)
		f.set_ghost(Game.COLOURS.alert if g.sees_player else Game.COLOURS.guard, 0.75)
		draw_suspicion(i, g)
		var view := Sim.view_of(g)
		var torch := torches[i]
		var breath := torch_breath(i)
		torch.light_color = Game.COLOURS.alert if g.sees_player else TORCH_COLOUR.lerp(TORCH_WARM, maxf(0.0, -breath) * 0.5)
		# A touch wider than the cone: the soft rim spends the edge fading out.
		torch.spot_angle = rad_to_deg(view.half) * 1.1
		torch.spot_range = view.range + 1.0
		# Under the ceiling lights a torch is pointless, and switched off.
		# A harder night hands them stronger torches.
		var power := Sim.torch_power()
		torch.light_energy = 0.0 if Museum.is_lit(g.x, g.y) else (TORCH_ENERGY_ALERT if g.alert else TORCH_ENERGY) * power * power * (1.0 + TORCH_BREATH * breath)
		draw_cone(g, cones[i])
	for d in host.house.mannequins:
		d.set_state(d.position, float(d.get_meta("dir", PI)), 0.0, dt)


## -1..1: where torch i is in its breathing (TORCH_BREATH), two slow waves,
## each guard's out of step with the others'.
func torch_breath(i: int) -> float:
	var t := Time.get_ticks_msec() / 1000.0
	return 0.65 * sin(t * TORCH_BREATH_SPEED.x + i * 2.1) + 0.35 * sin(t * TORCH_BREATH_SPEED.y + i * 0.9)


## The piece is in the sack: its carrier jumps for joy (Figure.pop) and the
## sack pops onto its back, from small to a touch too big and settling.
func pop_steal() -> void:
	for i in host.thieves.size():
		if host.thieves[i].id == Heist.carrier and i < thief_nodes.size():
			thief_nodes[i].pop()
	var rest := Vector3.ONE * SACK_SCALE
	sack_node.scale = rest * 0.6
	var tw := sack_node.create_tween()
	tw.tween_property(sack_node, "scale", rest * 1.15, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sack_node, "scale", rest, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func draw_room_lights() -> void:
	var lit: Array = []
	for r in Museum.rooms:
		var on := Museum.lights_left[r.id] > 0
		switch_marks[r.id].material_override.albedo_color = Game.COLOURS.switch_on if on else Game.COLOURS.switch_off
		lit_washes[r.id].visible = on
		if on:
			var c := host._to_world(r.rect.position.x + r.rect.size.x / 2.0, r.rect.position.y + r.rect.size.y / 2.0, 2.6)
			lit.append([c, c.distance_to(host.camera.position), Vector2(r.rect.size).length()])
	lit.sort_custom(func(a, b): return a[1] < b[1])
	for i in room_lights.size():
		var l := room_lights[i]
		if i < lit.size():
			l.position = lit[i][0]
			l.omni_range = lit[i][2] / 2.0 + 3.0
			l.light_energy = ROOM_LIGHT_ENERGY
		else:
			l.light_energy = 0.0


## The piece: turning over its case, on the thief's back, or on the floor.
func draw_loot() -> void:
	# Once the piece is gone the spotlight has nothing to show: it dims.
	if loot_spot:
		loot_spot.light_energy = move_toward(loot_spot.light_energy, 0.0 if Heist.taken else 14.0, 0.2)
	draw_panel()
	var t := Time.get_ticks_msec() / 1000.0
	# The piece shows only on its case; taken, it is in the sack.
	# (The house has no piece to show: no sock over the bench.)
	loot_node.visible = host.mode != Practice.MODE and not Heist.taken and host.house.home_shows(Heist.at.x + 0.5, Heist.at.y + 0.5)
	loot_node.position = host._to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05 + sin(t * 2.0) * 0.05)
	loot_node.rotation.y = t * 1.2
	sack_node.visible = false
	if Heist.carrier != "":
		var c: Thief = host.thieves[0]
		for p in host.thieves:
			if p.id == Heist.carrier:
				c = p
		# Out of the door with it: gone with them.
		if not c.safe and not c.hiding:
			sack_node.visible = true
			# Slung on the back, lower when down on all fours.
			sack_node.position = host._to_world(c.x - cos(c.dir) * 0.32, c.y - sin(c.dir) * 0.32, 0.45 - c.posture * 0.2 + (Plinths.HEIGHT if c.posing else 0.0))
			sack_node.rotation = Vector3(0, -c.dir + PI / 2, 0)
	elif Heist.dropped != Vector2.INF:
		sack_node.visible = true
		sack_node.position = host._to_world(Heist.dropped.x, Heist.dropped.y, 0.0)
		sack_node.rotation = Vector3.ZERO


## What a guard's head says: nothing when it suspects nothing; else its
## marks and, under them, how much is left before it calms down a step —
## full and still for a guard that is sure, or giving chase.
func draw_suspicion(i: int, g: Guard) -> void:
	var mark := suspicion_marks[i]
	if g.suspicion <= 0:
		mark.visible = false
		suspicion_keys[i] = ""
		return
	var now := Sim.now_ms()
	var left := 1.0
	if g.suspicion == 1:
		left = 1.0 - (now - g.suspicion_at) / (Sim.tuning("calm_after") * 1000.0)
	elif g.suspicion == 2 and g.calm_in != INF:
		left = 1.0 - (now - g.suspicion_at) / Sim.ALERT_HOLD_MS
	var step := clampi(ceili(clampf(left, 0.0, 1.0) * SUSPICION_STEPS), 0, SUSPICION_STEPS)
	var key := "%d:%d:%s" % [g.suspicion, step, g.knows_kind]
	if key == suspicion_keys[i]:
		return
	var was := suspicion_keys[i]
	var rose := was == "" or int(was.get_slice(":", 0)) < g.suspicion or (g.knows_kind != "" and was.get_slice(":", 2) != g.knows_kind)
	suspicion_keys[i] = key
	mark.texture = ImageTexture.create_from_image(suspicion_image(g.suspicion, float(step) / SUSPICION_STEPS, g.knows_kind))
	mark.visible = true
	# Going up a level, or finding out where you are: a pop, so you notice.
	if rose:
		mark.scale = Vector3.ONE * 1.8
		host.create_tween().tween_property(mark, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The marks (as many as the level) over a bar filled to `fill`, in pixels
## with a dark outline so they read on floor, wall or torch light alike;
## and, for a guard that knows where you are hiding, the icon of it.
static func suspicion_image(level: int, fill: float, hideout := "") -> Image:
	var marks := marks_image(level, fill)
	if hideout == "" or not HIDEOUT_ICONS.has(hideout):
		return marks
	if not hideout_icons.has(hideout):
		var icon: Image = load("res://assets/icons/objects/%s.png" % HIDEOUT_ICONS[hideout]).get_image()
		icon.convert(Image.FORMAT_RGBA8)
		icon.resize(HIDEOUT_ICON_PX, HIDEOUT_ICON_PX, Image.INTERPOLATE_LANCZOS)
		hideout_icons[hideout] = icon
	var icon: Image = hideout_icons[hideout]
	# Side by side, the icon on the right; mirrored room on the left so the
	# marks stay centred over the guard's head.
	var w := marks.get_width() + 2 * (HIDEOUT_ICON_PX + 1)
	var h := maxi(marks.get_height(), HIDEOUT_ICON_PX)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.blit_rect(marks, Rect2i(Vector2i.ZERO, marks.get_size()), Vector2i(HIDEOUT_ICON_PX + 1, 0))
	img.blend_rect(icon, Rect2i(Vector2i.ZERO, icon.get_size()), Vector2i(HIDEOUT_ICON_PX + 1 + marks.get_width() + 1, 0))
	return img


static func marks_image(level: int, fill: float) -> Image:
	var w := 34
	var h := 22
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var ink := Color("#1c1210")
	var colour: Color = SUSPICION_COLOURS[level]
	# "!": a 3-wide stroke over a dot, 5 apart.
	var x0 := w / 2 - (level * 5 - 2) / 2
	for k in level:
		var x := x0 + k * 5
		img.fill_rect(Rect2i(x - 1, 0, 5, 9), ink)
		img.fill_rect(Rect2i(x - 1, 10, 5, 5), ink)
		img.fill_rect(Rect2i(x, 1, 3, 7), colour)
		img.fill_rect(Rect2i(x, 11, 3, 3), colour)
	# The bar: how long before it calms down a step.
	img.fill_rect(Rect2i(1, 16, w - 2, 5), ink)
	img.fill_rect(Rect2i(2, 17, w - 4, 3), Color("#3a2a30"))
	img.fill_rect(Rect2i(2, 17, int(round((w - 4) * fill)), 3), colour)
	return img


## The view cone, rebuilt from rays every frame so it stops at the walls.
## Two bands, like the torch: the bright pool that sees you however low you
## are, and the dim throw beyond it that only catches you standing. Every
## edge is feathered — between the bands, at the far rim and at the sides —
## so it reads as light on the floor, not a cut-out.
func draw_cone(g: Guard, node: MeshInstance3D) -> void:
	var im: ImmediateMesh = node.mesh
	im.clear_surfaces()
	var view := Sim.view_of(g)
	var colour: Color = Game.COLOURS.alert if g.sees_player else (Game.COLOURS.cone_alert if g.alert else Game.COLOURS.cone)
	# Faint: the torch's beam in the fog does most of the showing, this just
	# marks what the guard sees.
	var bright: float = (0.2 if g.sees_player else (0.13 if g.alert else 0.09)) * clampf(Sim.torch_power(), 0.7, 1.4)
	var dim := bright * CONE_DIM
	var near: float = view.near
	var reach: float = view.range
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev: Array = []
	for i in CONE_RAYS:
		var t := float(i) / (CONE_RAYS - 1)
		var a: float = g.dir - view.half + 2.0 * view.half * t
		# Soft sides: the light thins out towards the edge of the beam.
		var side := smoothstep(0.0, CONE_SIDE_FEATHER, t) * smoothstep(1.0, 1.0 - CONE_SIDE_FEATHER, t)
		# Painted over the cases: this is where someone standing is seen.
		var far := Museum.cast_ray(g.x, g.y, a, Sim.LIT_RANGE, true)
		var ex: float = g.x + cos(a) * reach
		var ey: float = g.y + sin(a) * reach
		var lit_beyond: bool = far > reach and Museum.is_lit(ex, ey)
		var d: float = far if lit_beyond else minf(far, reach)
		# (distance, alpha) from the guard out: bright pool, blend, dim throw,
		# and a fade to nothing at the rim unless a lit room carries it on.
		var rings := [
			[0.0, bright],
			[near - CONE_BAND_FEATHER, bright],
			[near + CONE_BAND_FEATHER, dim],
			[reach - CONE_RIM_FEATHER, dim],
			[d if lit_beyond else reach, dim if lit_beyond else 0.0],
		]
		var ray: Array = []
		for r in rings:
			var at := clampf(r[0], 0.0, d)
			ray.append([host._to_world(g.x + cos(a) * at, g.y + sin(a) * at, 0.03), Color(colour, r[1] * side)])
		if i > 0:
			for k in ray.size() - 1:
				cone_tri(im, prev[k], prev[k + 1], ray[k])
				cone_tri(im, ray[k], prev[k + 1], ray[k + 1])
		prev = ray
	im.surface_end()


func cone_tri(im: ImmediateMesh, a: Array, b: Array, c: Array) -> void:
	for v in [a, b, c]:
		im.surface_set_color(v[1])
		im.surface_add_vertex(v[0])
