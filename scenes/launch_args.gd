class_name LaunchArgs
extends RefCounted
## The command-line options for recording and testing: `godot -- --menu=story`, --autostart...
## Read once, when the game opens, and turned into the same calls a player's clicks make.

var host: Game


func _init(game: Game) -> void:
	host = game


## Every option, in the order they can depend on each other.
func apply() -> void:
	# For recording and testing: `godot -- --autostart` skips the title, shows
	# the mission for two seconds and starts the round; add --two for two thieves.
	# --menu=story|generative|settings: open a menu straight away, to look at it.
	# --pick=N first: the story's heist N picked (map and museum open on its).
	# --save=PATH: the progress kept there instead (Story.save), for
	# looking at the screens without touching the player's own; and with it
	# --reached=N: as far as heist N there.
	_progress()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--menu="):
			_menu(arg)
	_plan()
	_acts()
	_brief()
	_intro()
	_autostart()


## Where the progress is kept, how many thieves, how far they got, the night picked.
func _progress() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--save="):
			Story.save = arg.substr(7)
		if arg.begins_with("--gang="):
			host.players = clampi(int(arg.substr(7)), 1, 4)
		elif arg == "--two":
			host.players = 2
	for arg in OS.get_cmdline_user_args():
		# Never in the player's own progress.
		if arg.begins_with("--reached=") and Story.save != Story.SAVE:
			Story.unlock(clampi(int(arg.substr(10)), 1, Story.count()), host.players)
	host.story_pick = Story.unlocked(host.players)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pick="):
			host.story_pick = clampi(int(arg.substr(7)), 1, Story.count())


## --menu=X: that screen straight away.
func _menu(arg: String) -> void:
	match arg.substr(7):
		"story": host._show_title("story")
		# The way in (Tour): the town, or inside the museum of --pick=N
		# with that room picked.
		# (--opened=M: as just after the big job before museum M).
		"map", "city":
			var fresh := -1
			for a in OS.get_cmdline_user_args():
				if a.begins_with("--opened="):
					fresh = clampi(int(a.substr(9)) - 1, 0, Story.MUSEUMS.size() - 1)
			host._show_city(fresh, fresh)
		"museum": host._show_museum_tour(host.story_pick)
		# The hideout's practice room, straight in (--gang=N, --two).
		"practica":
			host.mode = Practice.MODE
			host.pads_lost.clear()
			host._new_round(1)
			host._start_countdown(0.0)
		"generative": host._show_generative_menu()
		"challenges": host.challenges.show_menu()
		"editor": host.challenges.show_editor(MapFile.generated(4242, "small"))
		"settings": host.options.show("title")
		"pads": host.options.show("title", "pads")
		"input": host.hands.show_join("generative")
		# The ends of a night and the pause, to look at them: --pick=N
		# for the story's heist, --gen for the generative, --two or
		# --gang=N for more thieves.
		"end", "caught", "escaped":
			look_at_end("escaped" if arg == "--menu=escaped" else "caught")
		"paused":
			look_at_pause()


## --plan=N: heist N's plan out of its room, told from the start (with
## --explore, as if told before: straight to looking round it).
func _plan() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			var n := clampi(int(arg.substr(7)), 1, Story.count())
			if Story.save != Story.SAVE:
				Story.unlock(n, host.players)
			n = mini(n, Story.unlocked(host.players))
			if "--explore" in OS.get_cmdline_user_args():
				host.told_now[[n, host.players]] = true
			host._show_museum_tour(n)
			host._tour_room(n)


## --acts=right,accept,...: presses for the way in, one every 1.2 s, to
## record it going (Tour.act: left, right, up, down, accept, back, skip).
func _acts() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--acts="):
			var acts := arg.substr(7).split(",")
			for i in acts.size():
				host.get_tree().create_timer(1.2 * (i + 1)).timeout.connect(func() -> void:
					if host.tour:
						host.tour.act(acts[i]))


## --brief=N:P: the story's night N, briefing page P (0-based), to look at it
## (--gen: the generative's level N instead).
func _brief() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--brief="):
			var bits := arg.substr(8).split(":")
			host.mode = "generative" if "--gen" in OS.get_cmdline_user_args() else "story"
			host._new_round(int(bits[0]))
			host.briefing.show(int(bits[1]) if bits.size() > 1 else 0)


## --intro: the piece, then the countdown, for checking the way in.
## --challenge: the first of the saved maps instead.
func _intro() -> void:
	if "--intro" in OS.get_cmdline_user_args():
		var which := "generative" if "--gen" in OS.get_cmdline_user_args() else "story"
		if "--challenge" in OS.get_cmdline_user_args() and not MapFile.list().is_empty():
			host.challenges.challenge_map = MapFile.list()[0]
			which = "challenge"
		host._start(which, 2 if "--two" in OS.get_cmdline_user_args() else 1)
		host.get_tree().create_timer(1.5).timeout.connect(host._start_countdown)


## --autostart: the brief for two seconds, then the round; with --smoke, --map
## and --hide, a thing or two to look at once it is going.
func _autostart() -> void:
	if not "--autostart" in OS.get_cmdline_user_args():
		return
	if "--two" in OS.get_cmdline_user_args():
		host.players = 2
		host._new_round(1)
	host.briefing.show(host.briefing.pages().size() - 1)
	host.get_tree().create_timer(2.0).timeout.connect(host._start_playing)
	# --smoke: and a smoke bomb goes off at P1's feet a moment in.
	if "--smoke" in OS.get_cmdline_user_args():
		host.get_tree().create_timer(3.5).timeout.connect(func() -> void:
			Smoke.drop(host.thieves[0], Sim.now_ms(), host.loop.prop_noises))
	# --map: and take the map out a moment later.
	if "--map" in OS.get_cmdline_user_args():
		host.get_tree().create_timer(3.0).timeout.connect(host._toggle_map)
	# --hide: and P1 starts a few steps from a place to hide in.
	if "--hide" in OS.get_cmdline_user_args():
		host.get_tree().create_timer(2.1).timeout.connect(near_hideout.bind(0))


## A night's end straight away (--menu=caught, --menu=escaped), for looking
## at it: the heist --pick=N (the story), or --gen's first; saves nothing.
func look_at_end(how: String) -> void:
	host.just_looking = true
	var args := OS.get_cmdline_user_args()
	if "--gen" in args:
		host.mode = "generative"
	host.players = 2 if "--two" in args else 1
	for arg in args:
		if arg.begins_with("--gang="):
			host.players = clampi(int(arg.substr(7)), 1, 4)
	host._new_round(host.story_pick if host.mode == "story" else 1)
	# Over the museum, as after a night: the wall, not the title's picture;
	# and some figures for the paper, as after a night.
	host.hud.backdrop(null)
	HeistStats.time = 102.0
	HeistStats.add("hides", 2)
	HeistStats.add("smoke")
	if how == "caught":
		host.caught_thief = 0
		host.caught_by = host.guards[0].name if not host.guards.is_empty() else ""
	host.phase = how
	host._show_end()


## The pause a moment into the night (--menu=paused), for looking at it;
## --lost: as if the first thief's pad had dropped out.
func look_at_pause() -> void:
	var args := OS.get_cmdline_user_args()
	if "--gen" in args:
		host.mode = "generative"
	if "--two" in args:
		host.players = 2
	host._new_round(host.story_pick if host.mode == "story" else 1)
	host.briefing.show(host.briefing.pages().size() - 1)
	host.get_tree().create_timer(1.0).timeout.connect(host._start_playing)
	host.get_tree().create_timer(2.5).timeout.connect(func() -> void:
		if "--lost" in args:
			host.pads_lost[0] = ""
		host._pause())


## For trying hiding out (--hide): thief i a few steps from a hideout,
## facing it, on the free floor it is got into from. Returns the way from
## the hideout to where it stands, or (0, 0) if there is none.
func near_hideout(i: int) -> Vector2i:
	var p := host.thieves[i]
	for s in Hideouts.all():
		for t in s.tiles:
			for d in Museum.DIRS:
				var n: Vector2i = t + d
				if n in s.tiles or Museum.tile_at(n.x + 0.5, n.y + 0.5) != Tiles.FLOOR:
					continue
				var far := n
				for k in 3:
					var m: Vector2i = far + d
					if Museum.tile_at(m.x + 0.5, m.y + 0.5) != Tiles.FLOOR:
						break
					far = m
				p.x = far.x + 0.5
				p.y = far.y + 0.5
				p.dir = atan2(-d.y, -d.x)
				return d
	return Vector2i.ZERO
