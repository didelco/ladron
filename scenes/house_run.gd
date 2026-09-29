class_name HouseRun
extends RefCounted
## The band's house, played: the rooms in sight and the doors, the scarecrows and their
## alarm, and the dojo's trials (DojoTrials). The world is built by Game, the house's
## picture by DenView; this steps them each frame.
## Nothing here counts for the story: no stars, no progress.

var host: Game

## In the band's house: the room the first thief is in (to say its name as
## one walks in) and whether the way out has been taken.
var home_room := ""
var home_leaving := false

# --- The dojo's trials -----------------------------------------------------------------------
## The start points of the house (DojoTrials.TABLE, Practice.trial_starts) start the
## dojo's trials (DojoTrial): the four games, the four tests of the bench and the
## circuit, all the same way. One is begun with the action key next to its object
## (Game._action_for, {"do": "trial"}) or, for the pedestals and the armours, by getting
## onto or into one (trial_poll); it is stepped here with the band's bodies (trial_tick)
## and seen by TrialView (the world's marks, the HUD and, at the end, the panel).
## Nothing in it counts for the story: only the best mark of each difficulty and size
## of band is kept (DojoTrials.settle, section [dojo]). Tab or the pause leave a trial;
## at its end the panel (TrialMenu) takes the keys: SEGUIR to the next difficulty,
## OTRA VEZ, SALIR.
var trial: DojoTrial
var trial_view: TrialView

## the lantern's scarecrow of AGUANTA ESCONDIDO (a guard's coat on its cross)
var trial_lantern: Figure

## thief index -> fell off the pedestal this frame (the balance minigame's word)
var trial_fell := {}

## seconds after leaving a trial in which no start point starts another
var trial_lock := 0.0
## who has got onto a pedestal or into an armour (DojoWatch)
var trial_watch := DojoWatch.new()

## The circuit's scarecrows (see Scenery._practice_ground), the time of their
## sweeps, and the alarm they share (Practice.alert_step).
var mannequins: Array[Figure] = []
var scarecrow_list: Array = []
var scarecrow_alert := Practice.alert_new()
var scarecrow_time := 0.0
## how much faster than in the free practice they sweep (the circuit's difficulty)
var scarecrow_speed := 1.0

## The lights of the tests' objects (Practice.lamps_new): which are signalling.
var lamps := Practice.lamps_new()


func _init(game: Game) -> void:
	host = game


## In the house: the rooms in sight (Den.visible_rooms: those with one of the
## band in, and those seen through the doors that are open) drawn and the
## rest dark, and what stands in the dark hidden: the dojo's things that
## fall (Props), the dummies and the sealed case's sock. snap: no fading
## (as a round begins). Nothing to do out of the house.
func home_sight(snap := false) -> void:
	if host.mode != Practice.MODE or host.den_view == null or not is_instance_valid(host.den_view):
		return
	var rooms: Array[String] = []
	for p in host.thieves:
		if not p.out:
			rooms.append_array(Den.rooms_at(p.x, p.y))
	if not rooms.is_empty():
		host.den_view.set_visible_rooms(Den.visible_rooms(Den.open_doors(), rooms), snap)
	if host.props_view != null and is_instance_valid(host.props_view):
		host.props_view.show_where(host.den_view.shows_at)
	for d in mannequins:
		d.visible = host.den_view.shows_at(d.position.x + Museum.w / 2.0, d.position.z + Museum.h / 2.0)


## The scarecrows look for the band (Practice.scarecrow_sees, the guards' rule
## with their own numbers): one sees a thief and the whole dojo goes red with
## a siren for a few seconds (DenView.set_alert), then not again for a moment.
## Only the dojo: nobody is caught, nothing is counted, no megaphone speaks.
func scarecrow_tick(dt: float) -> void:
	if scarecrow_list.is_empty() or host.den_view == null or not is_instance_valid(host.den_view):
		return
	scarecrow_time += dt * scarecrow_speed
	for i in scarecrow_list.size():
		var facing := Practice.scarecrow_facing(scarecrow_list[i], scarecrow_time)
		if i < mannequins.size():
			var d := mannequins[i]
			d.set_state(d.position, facing, 0.0, 0.0)
		host.den_view.pose_scarecrow(i, facing)
	var seen := false
	for p in host.thieves:
		if p.out:
			continue
		for sc in scarecrow_list:
			if Practice.scarecrow_sees(sc, Vector2(p.x, p.y), p.hiding or p.posing, p.posture < Sim.DOWN, Callable(), scarecrow_time):
				seen = true
	var was: bool = scarecrow_alert.active
	scarecrow_alert = Practice.alert_step(scarecrow_alert, dt, seen)
	if scarecrow_alert.active != was:
		host.den_view.set_alert(scarecrow_alert.active)
		if scarecrow_alert.active and host.den_view.shows("dojo"):
			var r := Den.rect("dojo")
			host.sfx.at("siren", host._to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0, 1.0), 0.5, 14.0)


## The lights of the tests' objects go on and off (Practice.lamps_step).
func lamps_tick(dt: float) -> void:
	if lamps.is_empty():
		return
	var before := lamps.duplicate(true)
	Practice.lamps_step(lamps, dt)
	if lamps != before and host.den_view != null and is_instance_valid(host.den_view):
		host.den_view.set_lamps(lamps)


## Whether a trial is on (until its panel is accepted or left). While it is, nothing
## else in the house answers the action key (trial_action): the start points of the
## other trials, the props, the hideouts, the doors, and nothing tips over.
func trial_active() -> bool:
	return trial != null


## Whether the panel at the end of a trial is up: the band stands still and the keys
## are the panel's.
func panel_open() -> bool:
	return trial != null and trial.finished()


## What the action key does for thief t while a trial is on: only what the trial
## itself needs, {} for the rest. Today that is AGUANTA ESCONDIDO's hideouts (the ones
## open this round); every other trial asks nothing of the objects.
func trial_action(t: Thief) -> Dictionary:
	if trial is HideGame and not trial.finished():
		var open: Array[Vector2i] = (trial as HideGame).open_hides
		var spot := Hideouts.within_reach(t, host.thieves, func(s: Hideouts.Spot) -> bool: return s.tiles.any(func(k: Vector2i) -> bool: return open.has(k)))
		if spot:
			return {"do": "hide", "at": spot}
	return {}


## Who has just got onto a start point (one of the band, now), starts its trial.
func trial_poll() -> void:
	if host.mode != Practice.MODE:
		return
	var s := trial_watch.poll(host.thieves, host.players)
	if not s.is_empty() and not trial_active() and trial_lock <= 0.0:
		trial_start(String(s.id), int(s.tier), int(s.by))


## Begin a trial (its id) at a difficulty (0 easy, 1 medium, 2 hard) for the band,
## from the start point of that difficulty; `by` is the thief that started it (an
## index of thieves), or -1 for the first; keys are the frame's, for the minigame a
## test puts in the hands of `by`.
func trial_start(id: String, tier := 0, by := -1, keys := {}) -> void:
	if trial_view == null or not is_instance_valid(trial_view) or host.thieves.is_empty() or trial != null:
		return
	if by < 0:
		by = 0
	var t := _make(id, tier, by, Practice.start_of(id, tier, host.players))
	if t == null:
		return
	trial = t
	trial_fell.clear()
	_prepare(keys)
	trial.start()
	host.sfx.ui("go")


## A trial made, not begun: on the band's own field, from a tile, for a thief.
func _make(id: String, tier: int, by: int, start: Vector2i) -> DojoTrial:
	var field := DojoField.from_den(host.saved_map if host.saved_map != null else Practice.map(host.players))
	field.set_scarecrows(Practice.scarecrows(host.players))
	var t := DojoTrials.make(id, host.players, randi(), field, start, tier)
	if t == null:
		return null
	t.starter = by
	# Sight is the scarecrows' own (Practice), not the field's.
	t.seen = func(sc: Dictionary, pos: Vector2, hidden: bool) -> bool:
		return Practice.scarecrow_sees({"at": sc.tile, "dir": sc.facing}, pos, hidden)
	if t is CircuitTrial:
		(t as CircuitTrial).guards = Practice.scarecrows(host.players)
		(t as CircuitTrial).clock = func() -> float: return scarecrow_time
	for i in host.thieves.size():
		t.names.append(Text.t("JOIN_PLAYER") % (i + 1))
	if t is HideGame:
		(t as HideGame).set_hideouts(Practice.hide_tiles(host.players))
		(t as HideGame).set_lantern(Practice.LANTERN_AT, Practice.LANTERN_DIR)
	return t


## What the trial asks of the thief that begins it before it does: a pedestal to be up
## on (and the balance of the tier), an armour to be in, a minigame in the hands (held off
## until "go"), the thief facing its object and still.
func _prepare(keys: Dictionary) -> void:
	var by := trial.starter
	var p := host.thieves[by]
	var row := DojoTrials.info(trial.id)
	match String(row.via):
		"plinth":
			if not p.posing:
				Plinths.climb(p, trial.start_tile, [])
				p.game = Minigame.make("balance", "plinth", 1, host._game_input(by, keys))
			if p.game is BalanceGame:
				p.game.level = trial.tier
		"armour":
			if not p.hiding:
				var suits := Hideouts.all().filter(func(q: Hideouts.Spot) -> bool: return q.kind == "armour" and q.tiles[0] == trial.start_tile)
				if not suits.is_empty():
					Hideouts.get_in(p, suits[0], [])
		_:
			if trial is BenchTrial:
				p.dir = atan2(trial.start_tile.y + 0.5 - p.y, trial.start_tile.x + 0.5 - p.x)
				p.moving = false
				p.speed = 0.0
				p.sprinting = false
				p.game = (trial as BenchTrial).minigame(host._game_input(by, keys))
	if trial is HideGame:
		lantern_show(true, Practice.LANTERN_DIR)


## The lantern's scarecrow, up or down, looking where `angle` says.
func lantern_show(on: bool, angle: float) -> void:
	if host.den_view != null and is_instance_valid(host.den_view):
		host.den_view.set_lantern(on, angle)
	if on and trial_lantern == null:
		trial_lantern = Figure.make("guard", Game.COLOURS.guard, Game.COLOURS.guard_dark)
		host.world.add_child(trial_lantern)
	if trial_lantern != null:
		trial_lantern.visible = on
		var at := Practice.LANTERN_AT
		trial_lantern.set_state(host._to_world(at.x + 0.5, at.y + 0.5), angle, 0.0, 0.0)


## Leave the trial, from wherever, with nothing kept; the view and the lantern go, and
## the minigame of a test with them.
func trial_end() -> void:
	if trial == null:
		return
	trial.abort()
	trial = null
	scarecrow_speed = 1.0
	for p in host.thieves:
		if p.game != null and p.game.what == "bench":
			p.game = null
	if trial_view != null and is_instance_valid(trial_view):
		trial_view.show_view({})
	lantern_show(false, 0.0)
	trial_lock = 0.5


## Keys for a trial on: Tab leaves it; at its end the panel (TrialMenu) takes the
## keys. True if taken.
func trial_input(event: InputEvent) -> bool:
	if trial == null or trial_view == null or not is_instance_valid(trial_view):
		return false
	if not trial.finished():
		if event is InputEventKey and MenuKeys.of(event) == "skip":
			host.sfx.ui("back")
			trial_end()
			return true
		return false
	var r := trial_view.menu.input(event)
	trial_view.refresh()
	if r.has("move"):
		host.sfx.ui("nav", 0.6)
		return true
	if r.has("pick"):
		choose(String(r.pick))
		return true
	# A press of accept or back that came too soon (the panel is deaf a moment,
	# TrialMenu.GUARD_S) is taken all the same: it is not the house's.
	return MenuKeys.of(event) != ""


## A choice of the panel made (by the keys, the pad or the mouse): SEGUIR (the next
## difficulty, from the same start point), OTRA VEZ, or SALIR.
func choose(what: String) -> void:
	if not panel_open():
		return
	match what:
		TrialMenu.NEXT, TrialMenu.AGAIN:
			var tier := trial.tier + (1 if what == TrialMenu.NEXT and trial.tier < DojoTrials.TIERS.size() - 1 else 0)
			var next := _make(trial.id, tier, trial.starter, trial.start_tile)
			for p in host.thieves:
				if p.game != null and p.game.what == "bench":
					p.game = null
			trial = next
			trial_fell.clear()
			_prepare({})
			trial.start()
			host.sfx.ui("go")
		_:
			host.sfx.ui("back")
			trial_end()


## A frame of the trial on: the band's bodies in, its events out (sounds, the red of
## the alarm, the records), the picture and the doors it shuts.
func trial_tick(dt: float, keys: Dictionary) -> void:
	var bodies: Array[Dictionary] = []
	for i in host.thieves.size():
		var p := host.thieves[i]
		var input := host._game_input(i, keys)
		bodies.append({"id": i, "pos": Vector2(p.x, p.y), "rolling": p.rolling, "speed": p.speed, "out": p.out,
			"hidden": p.hiding or p.posing, "posing": p.posing, "low": p.posture < Sim.DOWN,
			"hold": input.action, "fell": trial_fell.get(i, false), "game": p.game,
			"lean": (p.game as BalanceGame).lean if p.game is BalanceGame else 0.0})
	trial_fell.clear()
	var was_finished := trial.finished()
	scarecrow_speed = (trial as CircuitTrial).speed() if trial is CircuitTrial and not trial.finished() else 1.0
	var events := trial.step(dt, bodies)
	if trial_view != null and is_instance_valid(trial_view):
		trial_view.menu.tick(dt)
	var settled := DojoTrials.settle(trial, events)
	for e in events:
		match e.e:
			"go":
				# The minigame of a test is free.
				var g: Minigame = host.thieves[trial.starter].game
				if g != null and g.what == "bench":
					g.blocked = ""
			"left":
				# Let go of the minigame: out of the trial, with nothing kept.
				trial_end()
				return
			"alarm":
				if host.den_view != null and is_instance_valid(host.den_view):
					var was: bool = scarecrow_alert.active
					scarecrow_alert = Practice.alert_step(scarecrow_alert, 0.0, true)
					if scarecrow_alert.active and not was:
						host.den_view.set_alert(true)
			"won":
				if trial is BenchTrial:
					Practice.lamp_open(lamps, trial.id, maxi(0, Practice.start_tier(trial.id, trial.start_tile, host.players)))
					if host.den_view != null and is_instance_valid(host.den_view):
						host.den_view.set_lamps(lamps)
	if trial.finished():
		# The test's minigame closes with the end of the trial.
		for p in host.thieves:
			if p.game != null and p.game.what == "bench":
				p.game = null
	if settled or (trial.finished() and not was_finished):
		if host.den_view != null and is_instance_valid(host.den_view):
			host.den_view.refresh_signs()
	var view := trial.view()
	if trial is HideGame:
		lantern_show(true, (trial as HideGame).lantern_angle)
	if trial_view != null and is_instance_valid(trial_view):
		trial_view.react(events, host.sfx, host.world)
		trial_view.show_view(view)


## Whether something at a spot of the plan (tiles) is drawn: everywhere but
## in one of the house's dark rooms.
func home_shows(x: float, y: float) -> bool:
	return host.mode != Practice.MODE or host.den_view == null or not is_instance_valid(host.den_view) or host.den_view.shows_at(x, y)


## Where the band stands, in tiles, for what needs to know who is in the way.
func band_points() -> Array:
	var out: Array = []
	for p in host.thieves:
		if not p.out:
			out.append(Vector2(p.x, p.y))
	return out


## The house's own goings-on each tick (true: the band has left). Crossing the
## front door with any of the band takes them all out, the way the pause does
## (the town is one screen); walking into a room names it; the bombs are
## never short.
func home_tick() -> bool:
	if home_leaving or host.thieves.is_empty():
		return home_leaving
	for p in host.thieves:
		if not p.out and Den.at_door(p.x, p.y):
			home_leaving = true
			host._quit_to_title()
			return true
	var room := Den.room_at(host.thieves[0].x, host.thieves[0].y)
	if room != "" and room != home_room:
		home_room = room
		host.hud.room_name(Text.t("HIDEOUT_ROOM_" + room.to_upper()))
	for p in host.thieves:
		Smoke.left[p.id] = Smoke.PER_THIEF
	home_sight()
	return false
