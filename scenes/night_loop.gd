class_name NightLoop
extends RefCounted
## The loop of a night, one physics frame at a time (tick): the thieves and their noise, the
## job and its alarm, the guards, the yell, the warning, keeping apart, the lights, thinking
## (Laya through BrainClient, or the fallback rules), hidden, caught, escaped. It is the web
## version's Game.tsx tick. Game calls it while the phase is "playing" and draws the result.

var host: Game

## each guard's position last frame and the distance walked since its last step
var guard_steps: Array = []

## Noises the physics made since the last frame, for the next tick.
var prop_noises: Array[SoundEvent] = []


func _init(game: Game) -> void:
	host = game


## A prop leaned past falling in the physics: if nobody pushed it on
## purpose, it was walked into — the crash, the rumble, the log.
func on_prop_tipped(id: int, dir: float, at: Vector2, strength: float) -> void:
	var p: Props.Prop = Props.list[id]
	p.x = at.x
	p.y = at.y
	if p.fallen:
		return
	p.fallen = true
	p.fall_dir = dir
	p.fallen_at = Sim.now_ms()
	prop_noises.append(SoundEvent.make(p.x, p.y, p.kind, Props.crash_loudness(p.kind, strength)))
	prop_fell(p, strength)


## The crash of one going over, whoever did it.
func prop_fell(p: Props.Prop, strength := 0.6) -> void:
	if host.phase == "playing":
		HeistStats.add("knocked")
	var loud := Props.crash_loudness(p.kind, strength)
	host.sfx.noise(p.kind, host._to_world(p.x, p.y), loud)
	host.hands.rumble(0.3 + 0.5 * strength, 0.4 * strength, 0.15 + 0.2 * strength, Vector2(p.x, p.y))
	host.rig.shake((0.45 if p.kind in ["bust", "armour"] else 0.25) * (0.6 + 0.8 * strength))
	host._log((Text.t("LOG_CRASH_EVERYWHERE") % Heist.first_upper(Props.name_of(p.kind))) if Props.heard_everywhere(loud) else Text.t("LOG_KNOCKED") % Props.name_of(p.kind))
	host.loudspeaker.say("knocked")
	if host.phase == "playing":
		host.loudspeaker.act("knock_" + p.kind)


## Something already down, sent rolling or rustling by a thief's feet: a
## smaller noise, but a noise — the tin bin clatters, paper whispers.
func on_prop_kicked(kind: String, at: Vector2, strength: float) -> void:
	var loud: float = {"bin": 7.5, "bust": 6.0, "panel": 5.0, "armour": 7.0, "paper": 2.5}.get(kind, 4.0) * (0.5 + 0.5 * strength)
	prop_noises.append(SoundEvent.make(at.x, at.y, "kick", loud))
	# The tin and the steel ring, the rubble and the board knock dry, the
	# paper whispers.
	var sound: String = {"bin": "kick_metal", "armour": "kick_metal", "paper": "whisper"}.get(kind, "kick_dry")
	host.sfx.noise(sound, host._to_world(at.x, at.y), loud)


## The little sounds of a job in hand, heard close by (the guards do not:
## picking a lock is silent, the case's alarm aside).
func game_sounds(p: Thief) -> void:
	var at := host._to_world(p.x, p.y, 1.0)
	for e in p.game.events:
		match e:
			"pin": host.sfx.at("pin", at, 0.7, 2.0)
			"slip": host.sfx.at("slip", at, 0.6, 2.0)
			"snip": host.sfx.at("snip", at, 0.7, 2.0)
			"spark": host.sfx.at("spark", at, 0.6, 2.0)
			# The arcade machine's pong (ArcadeGame): its bleeps.
			"bounce": host.sfx.at("pong_hit", at, 0.35, 2.0)
			"wall": host.sfx.at("pong_wall", at, 0.25, 2.0)
			"score": host.sfx.at("pong_score", at, 0.35, 2.0)
			"miss": host.sfx.at("pong_miss", at, 0.35, 2.0)
			"done": host.hands.rumble(0.3, 0.2, 0.12, Vector2(p.x, p.y))


## In a hideout, with the minigames on, a sneeze comes on after a while
## (SneezeGame): it is held in until the thief gets out, whichever way.
func sneeze_coming(p: Thief, i: int, keys: Dictionary, dt: float) -> void:
	# In a game of the dojo the sneeze is the game's own (HideGame).
	if host.house.dojo_game != null:
		if p.game is SneezeGame:
			p.game = null
		p.hidden_for = 0.0
		return
	if not p.hiding:
		p.hidden_for = 0.0
		if p.game is SneezeGame:
			p.game = null
		return
	p.hidden_for += dt
	if p.game == null and Heist.minigames() and p.hidden_for >= SneezeGame.CALM_S:
		p.game = Minigame.make("sneeze", "hideout", 1, host._game_input(i, keys))


## ACHOO! Out of the hideout, stunned a moment, and heard all round.
func sneeze(p: Thief, noises: Array[SoundEvent]) -> void:
	HeistStats.add("sneezes")
	p.game = null
	Hideouts.tip_out(p)
	p.dizzy = SneezeGame.STUN_S
	noises.append(SoundEvent.make(p.x, p.y, "sneeze"))
	host.sfx.noise("sneeze", host._to_world(p.x, p.y, 1.0), Hearing.LOUDNESS["sneeze"])
	host.hands.rumble(0.5, 0.7, 0.25, Vector2(p.x, p.y))
	host.rig.shake(0.25)
	host._log(Text.t("LOG_SNEEZE"))
	host.loudspeaker.say("sneeze")
	host.loudspeaker.act("sneeze", host.thieves.find(p))


## A frame of a thief wriggling into a hideout (Hideouts.squeeze): in once
## it is done, or let go if the hideout went meanwhile.
func squeeze(p: Thief, done: bool) -> void:
	var spot := p.hide_target
	match Hideouts.squeeze(p, host.guards, host.thieves, done):
		"in":
			p.game = null
			hid(p, spot)
		"lost":
			p.game = null


## In: the lid's thud, and whether anyone saw it.
func hid(p: Thief, spot: Hideouts.Spot) -> void:
	HeistStats.add("hides")
	host.sfx.at("roll", host._to_world(p.x, p.y), 0.3, 2.0)
	host._log(Text.t("LOG_HIDE_BLOWN") if p.hide_blown else Text.t("LOG_HIDE_IN") % Hideouts.name_of(spot.kind))
	host.loudspeaker.say("hide")
	host.loudspeaker.act("hide_seen" if p.hide_blown else ("hide_armour" if spot.kind == "armour" else "hide_other"), host.thieves.find(p))


## Each guard's boots, a step every stride: heard from where they are, so
## louder the nearer (the listener rides on the thief), harder when on alert.
func guard_footsteps() -> void:
	if guard_steps.size() != host.guards.size():
		guard_steps = host.guards.map(func(g): return [Vector2(g.x, g.y), 0.0])
	for i in host.guards.size():
		var g := host.guards[i]
		var here := Vector2(g.x, g.y)
		var entry: Array = guard_steps[i]
		entry[1] += here.distance_to(entry[0])
		entry[0] = here
		var stride := 0.62 if g.alert else 0.55
		if entry[1] >= stride:
			entry[1] = 0.0
			host.sfx.at("boot", host._to_world(g.x, g.y), 1.0 if g.alert else 0.75, 2.2)


## One frame of the night: the map or the thieves, what they do, the job, the guards, the
## sight of them, and how the night ends.
func tick(dt: float) -> void:
	HeistStats.time += dt
	if host.mode == Practice.MODE:
		host.house.dojo_lock = maxf(0.0, host.house.dojo_lock - dt)
		host.house.scarecrow_tick(dt)
		host.house.bench_tick(dt)
	if host.mode == Practice.MODE and host.house.home_tick():
		return
	var now := Sim.now_ms()
	var keys := _read_keys()
	var noises: Array[SoundEvent] = []
	_move_thieves(dt, keys, noises)
	_props_and_actions(now, keys, noises)
	_smoke(now, keys, noises)
	if host.house.dojo_game != null:
		host.house.dojo_tick(dt, keys)
	_job(dt, now, noises)
	_guards(dt, now, noises)
	_light_events()
	_think(now)
	_sight_and_capture()
	_exits()
	host.loudspeaker.tick(dt)
	# No clock: take as long as you like. The whole gang out of the door
	# with the piece wins; one of you caught ends the night.
	# The night stops there (phase "over"), a moment (Hud.HOLD_S) to see it
	# end before its page comes up; nothing pressed meanwhile counts.
	if host.thieves.any(func(p): return p.out and not p.safe):
		night_over("caught")
	elif host.thieves.all(func(p): return p.safe):
		host.sfx.ui("escaped")
		night_over("escaped")


## The keys of this frame. Reading the map, nobody moves (the pads are still read, to keep their
## held-button bookkeeping); every few frames it is redrawn.
func _read_keys() -> Dictionary:
	var keys := host.hands.pressed_keys()
	if host.map_open:
		# The controls lean the map instead of moving anyone.
		var push := Vector2.ZERO
		for pair in [["a", "d", "w", "s"], ["left", "right", "up", "down"]]:
			push += Vector2(float(keys.has(pair[1])) - float(keys.has(pair[0])), float(keys.has(pair[3])) - float(keys.has(pair[2])))
		host.hud.push_map(push)
		keys = {}
		if Engine.get_physics_frames() % 6 == 0:
			host.hud.update_map(host._live_map())
	return keys


## Each thief's frame: the minigame in hand, else a step, and the noise of it.
func _move_thieves(dt: float, keys: Dictionary, noises: Array[SoundEvent]) -> void:
	# Hands at a lock or a panel (Minigame) shake as the guards grow alarmed.
	var suspicion := 0
	for g in host.guards:
		suspicion = maxi(suspicion, g.suspicion)
	for i in host.thieves.size():
		var p := host.thieves[i]
		var px := p.x
		var py := p.y
		# On your own both pads drive you; with two, each pad is its own.
		var scheme: String = "solo" if host.thieves.size() == 1 else ["wasd", "arrows", "ijkl", "numpad"][i]
		sneeze_coming(p, i, keys, dt)
		host.busy[i] = p.game != null
		if p.game:
			_play_game(p, i, keys, dt, noises, suspicion)
		var step := Sim.step_thief(p, keys, dt, scheme)
		sneeze_coming(p, i, keys, 0.0)
		var noise := Hearing.thief_noise(px, py, p, step.entered_cover, step.bumped, Sim.TOP_SPEED)
		# Footsteps land once per stride; a bump is its own event.
		host.stride[i] += Museum.dist(px, py, p.x, p.y)
		if noise and (noise.kind == "walk" or noise.kind == "sprint"):
			if host.stride[i] < 0.45 + p.speed / Sim.TOP_SPEED * 0.5:
				noise = null
			else:
				host.stride[i] = 0.0
		# Off in a ball: a rush over the floor (the guards hear nothing of it).
		if step.roll == "start":
			HeistStats.add("rolls")
			host.loudspeaker.act("roll", i)
			host.sfx.at("roll", host._to_world(p.x, p.y), 0.7, 3.0)
		# Rolled into a wall: the thump, a puff of plaster, and it hurts.
		if step.bumped == "roll":
			HeistStats.add("bumps")
			Fx.puff(host.world, host._to_world(p.x + cos(p.dir) * Sim.BODY, p.y + sin(p.dir) * Sim.BODY), false)
			host.hands.rumble(0.6, 0.9, 0.3, Vector2(p.x, p.y))
			var case := Museum.is_cover(p.x + cos(p.dir) * (Sim.BODY + 0.1), p.y + sin(p.dir) * (Sim.BODY + 0.1))
			host._log(Text.t("LOG_ROLL_CASE" if case else "LOG_ROLL_WALL"))
			host.loudspeaker.act("roll_case" if case else "roll_wall", i)
		if noise and not p.out:
			noises.append(noise)
			var what := "step" if noise.kind in ["walk", "sprint", "rustle"] else (noise.kind if noise.kind in ["shelf", "roll_bump"] else "bump")
			# As loud as the guards hear it.
			host.sfx.noise(what, host._to_world(p.x, p.y), noise.loudness)


## A thief's minigame, a frame of it (hands shake as the guards grow alarmed).
func _play_game(p: Thief, i: int, keys: Dictionary, dt: float, noises: Array[SoundEvent], suspicion: int) -> void:
	p.game.tremble = Minigame.tremble_for(suspicion)
	p.game.pressure = Plinths.pressure(p, host.guards)
	var lean: float = (p.game as BalanceGame).lean if p.game is BalanceGame else 0.0
	var played := p.game.tick(host._game_input(i, keys), dt)
	match played:
		"quit":
			# Off the pedestal as well, if that is where it was.
			if p.game.kind == "balance":
				Plinths.get_down(p, lean)
			p.hide_target = null
			p.arcade = Vector2i(-1, -1)
			p.game = null
			# The roll key let go of it: it is not a roll as well.
			p.roll_key = true
		"fail" when p.game.kind == "sneeze":
			sneeze(p, noises)
		"fail":
			# Lost its balance: down it comes, and the guards hear it.
			host.house.dojo_fell[i] = true
			Plinths.fall(p, (p.game as BalanceGame).lean, noises)
			p.game = null
			host.sfx.noise("roll_bump", host._to_world(p.x, p.y), Hearing.LOUDNESS["tumble"])
			host.hands.rumble(0.5, 0.7, 0.25, Vector2(p.x, p.y))
			host.rig.shake(0.3)
			host._log(Text.t("LOG_PLINTH_FELL"))
			host.loudspeaker.say("dizzy")
			host.loudspeaker.act("plinth_fall", i)
		_:
			game_sounds(p)
			if p.game.kind == "squeeze":
				squeeze(p, played == "done")


## What the physics knocked over, what the thieves do on purpose (the action key), and
## what falls of it.
func _props_and_actions(now: float, keys: Dictionary, noises: Array[SoundEvent]) -> void:
	# Walking into things: over they go, with a crash.
	# Things knocked over: the physics decides (PropsView pushes them with
	# the thieves' bodies and tells us what fell or got kicked about), and
	# what it heard since last frame joins this frame's noises.
	Props.knocked.clear()
	noises.append_array(prop_noises)
	prop_noises.clear()
	# On purpose: E (P2: . , P3: O), or X on the pad, next to one — over it goes,
	# and the guards come to see. At a room's switch the same key flips it.
	for i in host.thieves.size():
		var t := host.thieves[i]
		var pressed: bool = keys.has(["e", "period", "o", "kpadd"][i]) or (host.thieves.size() == 1 and keys.has("period"))
		# Not from inside a hideout, and not the press that just ended a
		# minigame (the sneeze let out, the balance lost): that one was the game's.
		var act := host._action_for(t) if pressed and not host.push_held[i] and not t.game and not host.busy[i] and not t.hiding else {}
		_do_action(t, i, act, keys, now, noises)
		host.push_held[i] = pressed
	for p in Props.knocked:
		host.props_view.shove(p)
		prop_fell(p)
	# A suit of armour gone over with someone inside: out they tumble.
	for t in host.thieves:
		if t.hiding and t.hideout.prop and t.hideout.prop.fallen:
			Hideouts.tip_out(t)
			t.dizzy = Plinths.FALL_DOWN_S
			t.posture = 1.0
			host._log(Text.t("LOG_HIDE_TIPPED"))


## What the action key does for thief t: the first of what it can reach (Game._action_for).
func _do_action(t: Thief, i: int, act: Dictionary, keys: Dictionary, now: float, noises: Array[SoundEvent]) -> void:
	match act.get("do", ""):
		"job":
			Heist.start_game(t, act.at, host._game_input(i, keys))
			if act.at.what == "case":
				host.loudspeaker.act("case", i)
			host.sfx.at("pick", host._to_world(t.x, t.y), 0.5, 2.0)
		"plinth":
			Plinths.climb(t, act.at, host.guards)
			host.loudspeaker.act("plinth", i)
			# With minigames the pose is held on one foot (Minigame "balance").
			if Heist.minigames():
				t.game = Minigame.make("balance", "plinth", 1, host._game_input(i, keys))
			host.sfx.at("roll", host._to_world(t.x, t.y), 0.4, 2.0)
			host._log(Text.t("LOG_PLINTH_BLOWN" if t.pose_blown else "LOG_PLINTH_UP"))
		"hide":
			# In with a moment's wriggling (Minigame "squeeze", _squeeze);
			# before the nights have minigames, in at once.
			if Heist.minigames():
				Hideouts.start(t, act.at, host._game_input(i, keys))
			else:
				Hideouts.get_in(t, act.at, host.guards)
				hid(t, act.at)
		"arcade":
			# A game of pong, facing the screen: nothing to win (ArcadeGame).
			var arcade: Vector2i = act.at
			t.game = Minigame.make("arcade", "arcade", 1, host._game_input(i, keys))
			t.arcade = arcade
			host.loudspeaker.act("arcade", i)
			t.dir = atan2(arcade.y + 0.5 - t.y, arcade.x + 0.5 - t.x)
			host.sfx.at("pong_score", host._to_world(t.x, t.y, 1.0), 0.4, 2.0)
			host._log(Text.t("LOG_ARCADE"))
		"bench":
			host.house.bench_act(t, i, act.at, keys)
		"game":
			host.house.dojo_start(String(act.id))
		"switch":
			Sim.flip_switch(act.at, t, host.guards, now, noises)
		"push":
			Props.push(act.at, t, now, noises)
		"door":
			# Open or shut (it was checked no one is in the way): the plan
			# follows, the leaves slide, and what is seen is worked out again.
			if Den.toggle_door(act.at, host.house.band_points()):
				if host.den_view != null and is_instance_valid(host.den_view):
					host.den_view.set_door(act.at, Den.is_open(act.at))
				host.sfx.at("door", host._to_world(t.x, t.y, 0.5), 0.6, 4.0)
				host.house.home_sight()


## Smoke bombs: F (P2 the comma), or Y on the pad, at your feet.
func _smoke(now: float, keys: Dictionary, noises: Array[SoundEvent]) -> void:
	for i in host.thieves.size():
		var pressed: bool = keys.has(["f", "comma", "n", "kpdot"][i])
		if pressed and not host.smoke_held[i]:
			if Smoke.drop(host.thieves[i], now, noises) == null and not host.thieves[i].out:
				host.sfx.ui("back", 0.5)
				host.loudspeaker.act("smoke_empty", i)
		host.smoke_held[i] = pressed
	Smoke.step(now)
	for c in Smoke.fresh:
		HeistStats.add("smoke")
		SmokeFx.burst(host.world, host._to_world(c.x, c.y), Smoke.RADIUS * 1.15, Smoke.SECONDS)
		host.sfx.at("smoke", host._to_world(c.x, c.y, 0.5), 0.9, 6.0)
		host.hands.rumble(0.3, 0.5, 0.3, Vector2(c.x, c.y))
		host._log(Text.t("LOG_SMOKE"))
		host.loudspeaker.say("smoke")
		var by := host.thieves.find_custom(func(t): return t.id == c.by)
		host.loudspeaker.act("smoke_last" if by >= 0 and Smoke.count(host.thieves[by]) == 0 else "smoke", by)
	Smoke.clear_fresh()


## The job: working the case (and its alarm), carrying, dropping, the door.
func _job(dt: float, now: float, noises: Array[SoundEvent]) -> void:
	var before_alarms := noises.size()
	var cut_before := [Heist.panel_off, Heist.panel2_off]
	var took := Heist.step(host.thieves, dt, now, noises)
	if [Heist.panel_off, Heist.panel2_off] != cut_before:
		host.sfx.ui("ok")
		host._log(Text.t("LOG_PANEL_CUT"))
		host.loudspeaker.say("panel")
		host.loudspeaker.act("panel")
	if noises.size() > before_alarms:
		if Heist.progress < 0.1:
			host._log(Text.t("LOG_CASE_ALARM"))
			host.loudspeaker.say("alarm")
		host.sfx.at("alarm", host._to_world(Heist.at.x + 0.5, Heist.at.y + 0.5), 0.8)
	match took:
		"stolen":
			host.sfx.ui("stolen")
			Fx.sparkle(host.world, host._to_world(Heist.at.x + 0.5, Heist.at.y + 0.5, 1.05), Color(Heist.loot.colour))
			host.rig.punch_in()
			host._log(Text.t("LOG_GOT_IT_TEAM" if host.thieves.size() > 1 else "LOG_GOT_IT") % Heist.loot.name)
			host.loudspeaker.say("stolen")
		"dropped":
			host._log(Text.t("LOG_DROPPED") % Heist.first_upper(Heist.loot.name))
		"picked":
			host.sfx.ui("pick")


## The guards: the lights, their steps and looks, the yell for backup, the warnings.
func _guards(dt: float, now: float, noises: Array[SoundEvent]) -> void:
	Sim.tick_lights(dt)
	var saw_before := {}
	for g in host.guards:
		saw_before[g.id] = g.sees_player
	for g in host.guards:
		Sim.step_guard(g, host.thieves, noises, now, dt)
	guard_footsteps()
	for s in Sim.call_for_backup(saw_before, host.guards, now):
		host.sfx.at("shout", host._to_world(s.x, s.y), 1.0 if s.first else 0.5)
		if s.first:
			_first_yell(s)
	for w in Sim.warn_partners(host.guards, now):
		host.sfx.at("whisper", host._to_world(w.x, w.y), 0.6)
		host._log(Text.t("LOG_WARN") % [w.from, w.to])


## A guard sees a thief for the first time: the yell, the sting, the shake, the words.
func _first_yell(s: Dictionary) -> void:
	HeistStats.add("seen")
	host.sfx.ui("sting", 0.7)
	host.hands.rumble(0.4, 0.8, 0.4)
	host.rig.shake(0.6)
	var heard_by: Array = s.heard_by
	var heard: String = (Text.t("LOG_HEARD_BY") % Text.t("LOG_AND").join(heard_by)) if not heard_by.is_empty() else Text.t("LOG_NOBODY_HEARD")
	var ear := host.thieves[0]
	var angle := atan2(s.y - ear.y, s.x - ear.x)
	var d := Museum.dist(ear.x, ear.y, s.x, s.y)
	host.hud.shout(Text.t(Game.SHOUTS[randi() % Game.SHOUTS.size()]), Text.t("HUD_SHOUT_FAR" if d > 9 else "HUD_SHOUT_NEAR") % [s.from, heard], angle)
	host._log(Text.t("LOG_SHOUT") % [s.from, heard])
	host.loudspeaker.say("seen")


## The lights thrown this frame, by a guard or by a thief.
func _light_events() -> void:
	Sim.thoughts.clear()
	for e in Sim.light_events:
		var label := Text.t("LOG_THE_ROOM_OF")
		for z in Museum.zones:
			if z.room == e.room:
				label = z.label_of
		var r: Museum.Room = Museum.rooms[e.room]
		host.sfx.at("lights", host._to_world(r.switch_at.x + 0.5, r.switch_at.y + 0.5), 0.8)
		if e.thief:
			HeistStats.add("lights")
			host.loudspeaker.act("switch")
			host._log(Text.t("LOG_YOU_LIGHTS_ON" if e.on else "LOG_YOU_LIGHTS_OFF") % label)
			host.loudspeaker.say("lights_on" if e.on else "lights_off")
		else:
			host._log(Text.t("LOG_LIGHTS") % [e.by, label])
			host.loudspeaker.say("lights_on" if e.on else "lights_off")
	Sim.light_events.clear()


## The guards keep apart and think: only those with a decision to make are asked, and
## everyone every third time; without the brain, the fallback rules decide.
func _think(now: float) -> void:
	if now - host.last_spread > 500:
		host.last_spread = now
		Sim.keep_apart(host.guards)
	if now - host.last_think > Game.THINK_EVERY_MS:
		host.last_think = now
		host.think_tick += 1
		var everyone := host.think_tick % 3 == 0
		var asking: Array[Guard] = host.guards.filter(func(g): return not g.sees_player and (everyone or Sim.needs_plan(g)))
		if not host.brain.ask(asking, host.guards, now) and not host.brain.busy:
			for g in asking:
				if Sim.needs_plan(g):
					var others: Array[Guard] = host.guards.filter(func(o): return o != g)
					Sim.apply_decision(g, Mind.fallback(g, others, now))


## Who is hidden, who is seen wobbling on a pedestal, who is caught.
func _sight_and_capture() -> void:
	for p in host.thieves:
		p.hidden = Sim.is_hidden(host.guards, p)
		# Seen wobbling on one foot: whoever sees it knows, and comes for it.
		if p.posing and not p.hidden and p.game and p.game.wobbling():
			p.pose_blown = true
			for g in Sim.witnesses(host.guards, p):
				Sim.learn(g, p)
		if Sim.caught(host.guards, p):
			p.out = true
			p.speed = 0
			host.sfx.ui("caught")
			if host.caught_thief < 0:
				host.caught_thief = host.thieves.find(p)
				host.caught_by = nearest_guard(p)


## Once the piece is taken, whoever reaches the door slips out and is safe: out of sight,
## out of reach, waiting for the rest.
func _exits() -> void:
	if Heist.taken:
		for p in host.thieves:
			if not p.out and Heist.at_door(p):
				p.out = true
				p.safe = true
				p.speed = 0
				if host.thieves.size() > 1 and not host.thieves.all(func(o): return o.safe):
					host._log(Text.t("LOG_OUT_WAITING") % ("P%d" % (host.thieves.find(p) + 1)))
					host.loudspeaker.say("waiting")


func night_over(how: String) -> void:
	host.phase = "over"
	host.mega_voice.stop()
	host._close_map()
	host.get_tree().create_timer(Hud.HOLD_S).timeout.connect(func() -> void:
		if host.phase == "over":
			host.phase = how
			host._show_end())


## The name of the guard nearest thief p: the one that caught it.
func nearest_guard(p: Thief) -> String:
	var best: Guard = null
	for g in host.guards:
		if best == null or Museum.dist(g.x, g.y, p.x, p.y) < Museum.dist(best.x, best.y, p.x, p.y):
			best = g
	return best.name if best else ""
