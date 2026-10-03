class_name NightAlert
extends RefCounted
## The night as the guards live it together, above what each one suspects
## (Guard.suspicion, still what shows over its head, and still its own):
##   calm      nobody suspects a thing;
##   suspect   someone is on ! or !! over something heard or seen (a noise,
##             something knocked over, smoke, a light): it comes from the
##             guards, as it always has (Sim.step_guard), nothing here;
##   intruder  a guard has seen one of the gang, or the alarm has gone off:
##             every guard on alert (!!, Guard.alert, the alert it already
##             has: no extra eyes, ears or pace) until INTRUDER_HOLD_S go by
##             with nobody seen and no siren; then each comes down a step at
##             a time on its own (Sim.step_guard);
##   robbed    a guard has seen the empty case (find_chance): till the end
##             of the night nobody comes down below ROBBED_FLOOR, they search
##             everywhere (Mind.fallback) and now and then one goes to keep
##             an eye on the way out (the "door" errand, DOOR_*).
## Robbed is a background for good; intruder may come and go on top of it.
##
## The alarm (trip): set off by the pick or the suction cup going red
## (Minigame.hook_colour, Heist.step). It rings ALARM_S, and another red
## while it rings starts the count again. While it rings the guards hear it
## (a noise every ALARM_NOISE_EVERY_S where it went off), the night is in
## intruder, and the guards' attention to an empty case is at its highest.
## It does not give the theft away by itself.
##
## None of this is on the HUD: it is the game's own business. What happens
## in a frame (events) is picked up by NightLoop for the log, the sound and
## the loudspeaker. Back to nothing every round (reset: Heist.plan_job and
## Game._new_round).

## How long the alarm rings, and how often the guards hear it meanwhile.
const ALARM_S := 20.0
const ALARM_NOISE_EVERY_S := 1.5
## Intruder lasts this long with nobody seen and the siren quiet.
const INTRUDER_HOLD_S := 45.0
## The lowest each guard's suspicion goes in intruder (on alert) and once
## the theft is found (a hunch, but for good).
const INTRUDER_FLOOR := 2
const ROBBED_FLOOR := 1

## Finding the empty case: once a guard's look falls on it (in its cone,
## within what it sees right now, nothing in the way), FIND_FIRST_MS later
## a roll, and another every FIND_EVERY_MS while it keeps looking; each roll
## finds it with FIND_BASE × attention × closeness (find_chance).
const FIND_BASE := 0.25
const FIND_FIRST_MS := 200.0
const FIND_EVERY_MS := 500.0
## What the state of things does to a guard's attention: calm, a hunch (!),
## on alert or in intruder, and the alarm ringing.
const ATTENTION_CALM := 1.0
const ATTENTION_SUSPECT := 1.5
const ATTENTION_ALERT := 2.0
const ATTENTION_ALARM := 2.5

## The theft found, one guard goes to watch the way out every DOOR_EVERY_S,
## stands DOOR_STAND_S at DOOR_NEAR..DOOR_FAR tiles from it, and gives up if
## it is not there in DOOR_WALK_S.
const DOOR_EVERY_S := 60.0
const DOOR_STAND_S := 20.0
const DOOR_NEAR := 3.0
const DOOR_FAR := 4.0
const DOOR_WALK_S := 30.0

## seconds the alarm has left to ring (0: quiet), and where it went off
static var alarm_left := 0.0
static var alarm_at := Vector2.INF
## how many times it went off tonight
static var alarms := 0
## intruder on, and seconds since anyone was seen with the siren quiet
static var intruder := false
static var quiet := 0.0
## the theft found, and by whom
static var robbed := false
static var found_by := ""
## The way out watched: who is on it (a guard id, or ""), where it stands,
## seconds since the last one was sent, and seconds of standing it has left
## (-1 until it gets there).
static var door_guard := ""
static var door_spot := Vector2i(-1, -1)
static var door_clock := 0.0
static var door_left := -1.0
## The night's own clock (ms, from step's dt): the pause does not run it.
static var clock := 0.0
## guard id -> when its next roll at the empty case is due (clock ms), for
## the guards looking at it right now
static var aims := {}
## rolls made tonight (the tests count them)
static var rolls := 0
## What happened since NightLoop last looked: "alarm", "alarm_off",
## "intruder", "intruder_off", "robbed".
static var events: Array[String] = []
static var _noise_in := 0.0
## Its own dice: nothing here touches the global random numbers the museum
## and the job are laid out with.
static var rng := RandomNumberGenerator.new()


## A new night: all quiet.
static func reset() -> void:
	alarm_left = 0.0
	alarm_at = Vector2.INF
	alarms = 0
	intruder = false
	quiet = 0.0
	robbed = false
	found_by = ""
	door_guard = ""
	door_spot = Vector2i(-1, -1)
	door_clock = 0.0
	door_left = -1.0
	clock = 0.0
	aims.clear()
	rolls = 0
	events.clear()
	_noise_in = 0.0
	rng.randomize()


## The tests: the same dice every time.
static func seed_rng(s: int) -> void:
	rng.seed = s


static func ringing() -> bool:
	return alarm_left > 0.0


## "calm", "suspect", "intruder" or "robbed" (intruder over robbed, robbed
## over the guards' own suspicion).
static func mode(guards: Array[Guard]) -> String:
	if intruder:
		return "intruder"
	if robbed:
		return "robbed"
	for g in guards:
		if g.suspicion > 0:
			return "suspect"
	return "calm"


## The alarm goes off at `at` (the case, or a panel): it rings ALARM_S from
## now (again from the start if it already was), the guards hear it, and
## the night is in intruder.
static func trip(at: Vector2, noises: Array[SoundEvent]) -> void:
	alarm_left = ALARM_S
	alarm_at = at
	alarms += 1
	HeistStats.add("alarms")
	noises.append(SoundEvent.make(at.x, at.y, "alarm"))
	_noise_in = ALARM_NOISE_EVERY_S
	_hot()
	events.append("alarm")


## Someone seen, or the siren on: intruder, from the start.
static func _hot() -> void:
	if not intruder:
		events.append("intruder")
	intruder = true
	quiet = 0.0


## One frame of the night, before the guards' own (Sim.step_guard): the
## siren, intruder coming and going, the floors it puts under each guard's
## suspicion, looking for the empty case, and the way out watched.
static func step(guards: Array[Guard], noises: Array[SoundEvent], now: float, dt: float) -> void:
	clock += dt * 1000.0
	if alarm_left > 0.0:
		alarm_left = maxf(0.0, alarm_left - dt)
		_noise_in -= dt
		if alarm_left <= 0.0:
			events.append("alarm_off")
		elif _noise_in <= 0.0:
			_noise_in = ALARM_NOISE_EVERY_S
			noises.append(SoundEvent.make(alarm_at.x, alarm_at.y, "alarm"))
	if ringing() or guards.any(func(g: Guard) -> bool: return g.sees_player):
		_hot()
	elif intruder:
		quiet += dt
		if quiet >= INTRUDER_HOLD_S:
			intruder = false
			events.append("intruder_off")
	for g in guards:
		if intruder:
			_floor(g, INTRUDER_FLOOR, now)
		elif robbed:
			_floor(g, ROBBED_FLOOR, now)
	if not robbed and Heist.taken and Sim.feature("case"):
		_look_for_theft(guards, now)
	if robbed:
		_door_watch(guards, now, dt)


## Not below `level` while it lasts: raised to it, and held there (its
## clock back to calm starts over every frame).
static func _floor(g: Guard, level: int, now: float) -> void:
	if g.suspicion > level:
		return
	g.suspicion = level
	g.suspicion_at = now
	if level >= 2:
		g.alert = true


# --- The empty case ---------------------------------------------------------------

## A guard's attention right now: its own (Guard.attention_scale) times what
## the night does to it (ATTENTION_*).
static func attention(g: Guard) -> float:
	return g.attention_scale * attention_state(g)


## What the night does to a guard's attention right now (ATTENTION_*): the
## factor attention() multiplies its trait by.
static func attention_state(g: Guard) -> float:
	var k := ATTENTION_CALM
	if ringing():
		k = ATTENTION_ALARM
	elif g.alert or intruder:
		k = ATTENTION_ALERT
	elif g.suspicion >= 1:
		k = ATTENTION_SUSPECT
	return k


## The lowest suspicion the night lets a guard come down to now.
static func floor_level() -> int:
	if intruder:
		return INTRUDER_FLOOR
	return ROBBED_FLOOR if robbed else 0


## How well the case is in its look: (1 - d / reach)², reach being as far as
## it sees right now (Sim.view_of: its traits, the night, on alert or not;
## anything in line in a lit room); 0 out of its cone or its reach, or with
## a wall or smoke in the way. It looks over the other cases at it.
static func closeness(g: Guard, now := -1.0) -> float:
	var cx := Heist.at.x + 0.5
	var cy := Heist.at.y + 0.5
	var d := Museum.dist(g.x, g.y, cx, cy)
	var view := Sim.view_of(g)
	var reach: float = Sim.LIT_RANGE if Museum.is_lit(cx, cy) else float(view.range)
	if reach <= 0.0 or d > reach:
		return 0.0
	if d >= Sim.TOUCH_RANGE and absf(wrapf(atan2(cy - g.y, cx - g.x) - g.dir, -PI, PI)) > float(view.half):
		return 0.0
	if not Museum.has_line_of_sight(g.x, g.y, cx, cy, true):
		return 0.0
	if Smoke.blocks(g.x, g.y, cx, cy, now if now >= 0.0 else Sim.now_ms()):
		return 0.0
	var k := 1.0 - d / reach
	return k * k


## The chance each roll finds the case empty: FIND_BASE × attention ×
## closeness, between 0 and 1.
static func find_chance(g: Guard, now := -1.0) -> float:
	return clampf(FIND_BASE * attention(g) * closeness(g, now), 0.0, 1.0)


## Whoever has the empty case in its look rolls for it: FIND_FIRST_MS after
## the look falls on it, then every FIND_EVERY_MS while it stays there.
## Nobody goes to look at that case on purpose: there are many.
static func _look_for_theft(guards: Array[Guard], now: float) -> void:
	for g in guards:
		var p := find_chance(g, now)
		if p <= 0.0:
			aims.erase(g.id)
			continue
		if not aims.has(g.id):
			aims[g.id] = clock + FIND_FIRST_MS
			continue
		if clock < float(aims[g.id]):
			continue
		aims[g.id] = clock + FIND_EVERY_MS
		rolls += 1
		if rng.randf() < p:
			_found(g, now)
			return


## The theft is found: for good. Whoever found it is on alert (an empty
## case is no creak); the way out gets its first watcher at once.
static func _found(g: Guard, now: float) -> void:
	robbed = true
	found_by = g.name
	aims.clear()
	events.append("robbed")
	Sim._alarm(g, now, true)
	door_clock = DOOR_EVERY_S


# --- The way out watched ------------------------------------------------------------

## Every DOOR_EVERY_S the free guard nearest the way out goes to stand by it
## (the "door" errand, Sim.step_guard) for DOOR_STAND_S; a chase or a
## warning takes it off the job, and the next goes at the next turn.
static func _door_watch(guards: Array[Guard], now: float, dt: float) -> void:
	if guards.is_empty():
		return
	if door_spot.x < 0:
		door_spot = door_spot_for(Heist.exit)
		if door_spot.x < 0:
			return
	door_clock += dt
	var watcher: Guard = null
	for g in guards:
		if g.id == door_guard:
			watcher = g
	if watcher != null and watcher.errand == "door":
		if Museum.dist(watcher.x, watcher.y, door_spot.x + 0.5, door_spot.y + 0.5) < 0.6:
			if door_left < 0.0:
				door_left = DOOR_STAND_S
			door_left -= dt
			if door_left <= 0.0:
				watcher.errand = ""
				door_guard = ""
		elif door_left < 0.0 and door_clock > DOOR_WALK_S:
			watcher.errand = ""
			door_guard = ""
	elif door_guard != "":
		door_guard = ""
	if door_guard == "" and door_clock >= DOOR_EVERY_S:
		var pick := _door_pick(guards, now)
		if pick != null:
			pick.errand = "door"
			pick.errand_at = door_spot
			pick.target = door_spot
			pick.path = Museum.bfs_path(Vector2i(int(floor(pick.x)), int(floor(pick.y))), door_spot)
			pick.sweep = 0.0
			pick.watching = 0.0
			pick.search_spot = Vector2i(-1, -1)
			door_guard = pick.id
			door_clock = 0.0
			door_left = -1.0


## The free guard nearest the way out: not chasing anyone, not on an errand.
static func _door_pick(guards: Array[Guard], now: float) -> Guard:
	var best: Guard = null
	var best_d := INF
	for g in guards:
		if g.sees_player or Sim.on_to(g, now) or g.errand != "" or g.suspicion >= 3:
			continue
		var d := Museum.dist(g.x, g.y, door_spot.x + 0.5, door_spot.y + 0.5)
		if d < best_d:
			best_d = d
			best = g
	return best


## Where to watch the way out from: a floor tile DOOR_NEAR..DOOR_FAR from it
## with it in sight, in the middle of that band and as open as can be; or
## (-1, -1) if there is none.
static func door_spot_for(exit: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_k := INF
	var ex := exit.x + 0.5
	var ey := exit.y + 0.5
	for t in Museum.open_tiles:
		if Museum.tile_at(t.x + 0.5, t.y + 0.5) != Tiles.FLOOR:
			continue
		var d := Museum.dist(t.x + 0.5, t.y + 0.5, ex, ey)
		if d < DOOR_NEAR or d > DOOR_FAR:
			continue
		if not Museum.has_line_of_sight(t.x + 0.5, t.y + 0.5, ex, ey):
			continue
		var k := absf(d - (DOOR_NEAR + DOOR_FAR) / 2.0) - float(Museum.openness(t.x, t.y)) * 0.01
		if k < best_k:
			best_k = k
			best = t
	return best
