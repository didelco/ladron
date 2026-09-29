class_name HouseRun
extends RefCounted
## The band's house, played: the rooms in sight and the doors, the scarecrows and their
## alarm, the bench of practice cases, and the dojo's games (DojoGames). The world is built
## by Game, the house's picture by DenView; this steps them each frame.
## Nothing here counts for the story: no stars, no progress.

var host: Game

## In the band's house: the room the first thief is in (to say its name as
## one walks in) and whether the way out has been taken.
var home_room := ""
var home_leaving := false

# --- The dojo's games -----------------------------------------------------------------------
## The start points of the house (Practice.ITEMS with `game`) start the dojo's
## games (DojoGames): a game on the band's own field, stepped here with the
## band's bodies, seen by DojoGamesView. Nothing in it counts for the story:
## only the best level of each difficulty and size of band is kept
## (DojoGames.settle, section [dojo]). The sock and the circles are started with
## the action key (Game._action_for), the pedestals and the armours by getting
## onto them (dojo_poll). Tab or the pause leave a game; at its end the panel
## takes the keys.
var dojo_game: DojoGame
var dojo_view: DojoGamesView

## the lantern's scarecrow of AGUANTA ESCONDIDO (a guard's coat on its cross)
var dojo_lantern: Figure

## thief index -> fell off the pedestal this frame (the balance minigame's word)
var dojo_fell := {}

## seconds after leaving a game in which no start point starts another
var dojo_lock := 0.0
## who has got onto a pedestal or into an armour (DojoWatch)
var dojo_watch := DojoWatch.new()

## The practice ground's scarecrows (see _build_world), and the alarm they
## share (Practice.alert_step).
var mannequins: Array[Figure] = []
var scarecrow_list: Array = []
var scarecrow_alert := Practice.alert_new()

## The bench of practice cases (Practice.bench_new), who is standing still at
## one (thief id -> {i, t}) and what each game running on the bench is for
## (thief id -> the action it began from).
var bench := Practice.bench_new()
var bench_hold := {}
var bench_target := {}


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
	var seen := false
	for p in host.thieves:
		if p.out:
			continue
		for sc in scarecrow_list:
			if Practice.scarecrow_sees(sc, Vector2(p.x, p.y), p.hiding or p.posing, p.posture < Sim.DOWN):
				seen = true
	var was: bool = scarecrow_alert.active
	scarecrow_alert = Practice.alert_step(scarecrow_alert, dt, seen)
	if scarecrow_alert.active != was:
		host.den_view.set_alert(scarecrow_alert.active)
		if scarecrow_alert.active and host.den_view.shows("dojo"):
			var r := Den.rect("dojo")
			host.sfx.at("siren", host._to_world(r.position.x + r.size.x / 2.0, r.position.y + r.size.y / 2.0, 1.0), 0.5, 14.0)


## The bench of practice cases (Practice.bench_*): a case is opened by its own
## test, standing still or with the same minigame as in a heist, at its own
## difficulty. All of it a game and nothing else: no stars, no progress, no
## noise, no megaphone.
func bench_act(t: Thief, i: int, what: Dictionary, keys: Dictionary) -> void:
	var c := Practice.bench_case(int(what.i))
	var game := Practice.bench_game(c.kind, c.level, host._game_input(i, keys))
	t.dir = atan2(c.at.y + 0.5 - t.y, c.at.x + 0.5 - t.x)
	if game == null:
		bench_hold[t.id] = {"i": what.i, "t": 0.0}
	else:
		t.game = game
		bench_target[t.id] = what
		t.moving = false
		t.speed = 0.0
		t.sprinting = false
	if host.den_view != null and is_instance_valid(host.den_view):
		host.den_view.set_bench(bench)


func bench_open(c: int) -> void:
	Practice.bench_open(bench, c)
	host.sfx.ui("stolen")
	var at: Vector2i = Practice.bench_case(c).at
	Fx.sparkle(host.world, host._to_world(at.x + 0.5, at.y + 0.5, 1.05), Color("#e2262f"))


func bench_tick(dt: float) -> void:
	var before := bench.duplicate(true)
	Practice.bench_step(bench, dt)
	for p in host.thieves:
		if bench_hold.has(p.id):
			var h: Dictionary = bench_hold[p.id]
			var still: bool = not p.out and not p.moving and p.speed < 0.2 and Practice.bench_case_at(Vector2(p.x, p.y), host.players) == int(h.i) and bench.cases[h.i].state == "closed"
			h.t = Practice.bench_hold_step(float(h.t), still, dt)
			if not still:
				bench_hold.erase(p.id)
			elif h.t >= Practice.bench_hold_s(int(h.i)):
				bench_hold.erase(p.id)
				bench_open(int(h.i))
		if bench_target.has(p.id):
			if p.game == null:
				bench_target.erase(p.id)
			elif p.game.what == "bench" and p.game.done:
				var what: Dictionary = bench_target[p.id]
				bench_target.erase(p.id)
				p.game = null
				bench_open(int(what.i))
	if bench != before and host.den_view != null and is_instance_valid(host.den_view):
		host.den_view.set_bench(bench)


## Whether a test is on: a game of the dojo (until its panel is accepted or left)
## or a case of the bench being worked (standing still, or its minigame). While
## it is, nothing else in the house answers the action key (trial_action), the
## start points of the other games included, and nothing tips over.
func trial_active() -> bool:
	if dojo_game != null or not bench_hold.is_empty():
		return true
	return host.thieves.any(func(p: Thief) -> bool: return p.game != null and p.game.what == "bench")


## What the action key does for thief t while a test is on: only what the test
## itself needs, {} for the rest. Today that is AGUANTA ESCONDIDO's hideouts
## (the ones open this round); every other test asks nothing of the objects.
func trial_action(t: Thief) -> Dictionary:
	if dojo_game is HideGame and not dojo_game.finished():
		var open: Array[Vector2i] = (dojo_game as HideGame).open_hides
		var spot := Hideouts.within_reach(t, host.thieves, func(s: Hideouts.Spot) -> bool: return s.tiles.any(func(k: Vector2i) -> bool: return open.has(k)))
		if spot:
			return {"do": "hide", "at": spot}
	return {}


## Who has just got onto a start point of a game (one of the band, now), starts it.
func dojo_poll() -> void:
	if host.mode != Practice.MODE:
		return
	var s := dojo_watch.poll(host.thieves, host.players)
	if not s.is_empty() and not trial_active() and dojo_lock <= 0.0:
		dojo_start(String(s.game), int(s.tier), int(s.by))


## Begin a game (its id) at a difficulty (0 easy, 1 medium, 2 hard) for the band,
## from the start point of that difficulty; `by` is the thief that started it
## (an index of thieves), or -1 for whoever is nearest.
func dojo_start(id: String, tier := 0, by := -1) -> void:
	if dojo_view == null or not is_instance_valid(dojo_view) or host.thieves.is_empty() or dojo_game != null:
		return
	var field := DojoField.from_den(host.saved_map if host.saved_map != null else Practice.map(host.players))
	field.set_scarecrows(Practice.scarecrows(host.players))
	var start := Practice.start_of(id, tier, host.players)
	var game := DojoGames.make(id, host.players, randi(), field, start, tier)
	if game == null:
		return
	game.starter = by
	# Sight is the scarecrows' own (Practice), not the field's.
	game.seen = func(sc: Dictionary, pos: Vector2, hidden: bool) -> bool:
		return Practice.scarecrow_sees({"at": sc.tile, "dir": sc.facing}, pos, hidden)
	for i in host.thieves.size():
		game.names.append(Text.t("JOIN_PLAYER") % (i + 1))
	if game is PedestalGame:
		# The pedestal's tier is the balance minigame's level.
		if by >= 0 and host.thieves[by].game is BalanceGame:
			host.thieves[by].game.level = tier
	elif game is HideGame:
		(game as HideGame).set_hideouts(Practice.hide_tiles(host.players))
		(game as HideGame).set_lantern(Practice.LANTERN_AT, Practice.LANTERN_DIR)
		lantern_show(true, Practice.LANTERN_DIR)
	dojo_game = game
	dojo_fell.clear()
	game.start()
	host.sfx.ui("go")


## The lantern's scarecrow, up or down, looking where `angle` says.
func lantern_show(on: bool, angle: float) -> void:
	if host.den_view != null and is_instance_valid(host.den_view):
		host.den_view.set_lantern(on, angle)
	if on and dojo_lantern == null:
		dojo_lantern = Figure.make("guard", Game.COLOURS.guard, Game.COLOURS.guard_dark)
		host.world.add_child(dojo_lantern)
	if dojo_lantern != null:
		dojo_lantern.visible = on
		var at := Practice.LANTERN_AT
		dojo_lantern.set_state(host._to_world(at.x + 0.5, at.y + 0.5), angle, 0.0, 0.0)


## Leave the game, from wherever, with nothing kept; the view and the lantern go.
func dojo_end() -> void:
	if dojo_game == null:
		return
	dojo_game.abort()
	dojo_game = null
	if dojo_view != null and is_instance_valid(dojo_view):
		dojo_view.show_view({})
	lantern_show(false, 0.0)
	dojo_lock = 0.5


## Keys for a game on: Tab leaves it; at its end accept picks (again, out),
## back leaves, and the arrows move along the panel. True if taken.
func dojo_input(event: InputEvent) -> bool:
	if dojo_view == null or not is_instance_valid(dojo_view):
		return false
	if not dojo_game.finished():
		if event is InputEventKey and MenuKeys.of(event) == "skip":
			host.sfx.ui("back")
			dojo_end()
			return true
		return false
	var what := MenuKeys.of(event)
	if what == "accept":
		match dojo_view.accept():
			"again":
				dojo_fell.clear()
				dojo_game.start()
				host.sfx.ui("go")
			_:
				host.sfx.ui("back")
				dojo_end()
		return true
	if what == "back":
		host.sfx.ui("back")
		dojo_end()
		return true
	for a in ["ui_up", "ui_left", "ui_down", "ui_right"]:
		if event.is_action_pressed(a, false):
			host.sfx.ui("nav", 0.6)
			dojo_view.move(-1 if a in ["ui_up", "ui_left"] else 1)
			return true
	return false


## A frame of the game on: the band's bodies in, its events out (sounds, the
## red of the alarm, the records), the picture and the doors it shuts.
func dojo_tick(dt: float, keys: Dictionary) -> void:
	var bodies: Array[Dictionary] = []
	for i in host.thieves.size():
		var p := host.thieves[i]
		var input := host._game_input(i, keys)
		bodies.append({"id": i, "pos": Vector2(p.x, p.y), "rolling": p.rolling, "speed": p.speed, "out": p.out,
			"hidden": p.hiding or p.posing, "posing": p.posing,
			"hold": input.action, "fell": dojo_fell.get(i, false),
			"lean": (p.game as BalanceGame).lean if p.game is BalanceGame else 0.0})
	dojo_fell.clear()
	var was_finished := dojo_game.finished()
	var events := dojo_game.step(dt, bodies)
	if DojoGames.settle(dojo_game, events) or (dojo_game.finished() and not was_finished):
		if host.den_view != null and is_instance_valid(host.den_view):
			host.den_view.refresh_signs()
	for e in events:
		if e.e == "alarm" and host.den_view != null and is_instance_valid(host.den_view):
			var was: bool = scarecrow_alert.active
			scarecrow_alert = Practice.alert_step(scarecrow_alert, 0.0, true)
			if scarecrow_alert.active and not was:
				host.den_view.set_alert(true)
	var view := dojo_game.view()
	for id in view.get("gates_closed", []):
		if not Den.door(String(id)).is_empty() and Den.is_open(String(id)):
			Den.set_open(String(id), false)
			Den.apply_doors()
			if host.den_view != null and is_instance_valid(host.den_view):
				host.den_view.set_door(String(id), false)
	if dojo_game is HideGame:
		lantern_show(true, (dojo_game as HideGame).lantern_angle)
	if dojo_view != null and is_instance_valid(dojo_view):
		dojo_view.react(events, host.sfx, host.world)
		dojo_view.show_view(view)


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
