class_name Sim
extends RefCounted
## The rules of the game: port of the web version's sim.ts.
##
## Thieves and guards are moved in place. What guards perceive and the rules
## they cannot break — chase what they see, yell, warn a colleague, switch on
## the lights, calm down — live here; the choices with room for judgement come
## from Laya (Mind), or from the fallback rules while it is not there.

## How far and how wide a guard looks: a calm guard ambles with the torch at
## its feet, an alert one sweeps the beam wide and far.
const VIEW := {
	"calm": {"range": 5.5, "half": PI / 4.2},
	"alert": {"range": 9.0, "half": PI / 2.8},
}
## In a lit room there is no torch to run out of: anything in line is seen.
const LIT_RANGE := 40.0
## How long room lights stay on once switched, in ms.
const LIGHT_MS := 35000.0
## Past this, a clue no longer says where the thief is *now*.
const LOST_MS := 1500.0
## A zone looked over within this long does not need its lights on.
const RECHECK_MS := 15000.0
## Close enough to say it quietly.
const WARN_RANGE := 1.3
## An alarm raised only by sounds wears off after this long without another.
const CALM_AFTER_S := 10.0
## The sound that alarms a guard this many times is no longer a creak.
const ALARMS_TO_STAY := 3
const CATCH_RANGE := 0.75
## Nearer than this, a chasing guard goes straight for you.
const LUNGE_RANGE := 1.8
## Nearer than this, a guard notices you whichever way it faces.
const TOUCH_RANGE := 1.1
## How long a guard keeps working a clue before giving up on it.
const MEMORY_MS := 14000.0
## How long a heard spot is kept before a new noise may move it.
const NOISE_REFRESH_MS := 1200.0
## Nobody stands at one junction longer than this.
const MAX_WATCH := 6.0
## Two idle guards closer than this are wasting a guard.
const TOO_CLOSE := 6.0

## Movement builds up: tapping creeps, holding winds up to a run.
const CREEP := 1.5
const TOP_SPEED := 5.4
const ACCEL := 2.6
const DECEL := 7.0
const RUN_THRESHOLD := 3.6
## Getting down on all fours, or back up, takes this long.
const CROUCH_SECONDS := 1.5
const CROUCH_SPEED := 0.8
## How far down counts as hidden behind a case: all the way.
const DOWN := 0.95

const BODY := 0.3
const ASSIST_REACH := 0.62
const SIGHT_RAYS := 21
## A guard that yelled this recently is still on the same chase.
const FRESH_YELL_MS := 6000.0
## How often a guard with eyes on the thief yells again.
const CALL_REFRESH_MS := 1500.0

const GUARD_NAMES: Array[String] = ["Vela", "Rook", "Mora", "Quill", "Brasa", "Tejo", "Nube", "Sable"]

## Which keys drive which thief. On your own the arrows work too.
const SCHEMES := {
	"solo": {"up": ["w", "up"], "down": ["s", "down"], "left": ["a", "left"], "right": ["d", "right"], "crouch": ["c", "shift"]},
	"wasd": {"up": ["w"], "down": ["s"], "left": ["a"], "right": ["d"], "crouch": ["c"]},
	"arrows": {"up": ["up"], "down": ["down"], "left": ["left"], "right": ["right"], "crouch": ["minus", "slash"]},
}

## How hard the night is. Medium is the game as designed; easy and hard scale
## what the guards can do and how long you have. Every rule reads it through
## the functions below, so the numbers live in one place.
const DIFFICULTIES := {
	# Easy: one slow guard, whatever the size of the museum, and the piece
	# comes out of its case in a moment.
	# alarms: how many sounds it takes to put a guard on alert for good.
	"easy": {"view": 0.8, "hearing": 0.8, "speed": 0.7, "lock": 0.35, "calm_after": 7.0, "alarms": 3, "guards": 1},
	"medium": {"view": 1.0, "hearing": 1.0, "speed": 1.0, "lock": 1.0, "calm_after": 10.0, "alarms": 2, "guards": 0},
	"hard": {"view": 1.15, "hearing": 1.2, "speed": 1.1, "lock": 1.3, "calm_after": 14.0, "alarms": 1, "guards": 0},
}
static var difficulty := "medium"
## The story mode's night, when it sets its own: overrides the difficulty
## key by key. Empty in the generative mode.
static var custom := {}


static func tuning(key: String) -> float:
	if custom.has(key):
		return float(custom[key])
	return float(DIFFICULTIES[difficulty][key])


## How many guards a museum of this size gets on this night.
static func guard_count(size: String) -> int:
	var fixed := int(tuning("guards"))
	return fixed if fixed > 0 else int(Museum.SIZES[size].guards)


## Things that happened this frame, for the game loop's log and sound.
static var thoughts: Array[Dictionary] = []
static var light_events: Array[Dictionary] = []
static var _said_clear := {}


## The time in ms the simulation runs on.
static func now_ms() -> float:
	return float(Time.get_ticks_msec())


static func view_of(g: Guard) -> Dictionary:
	var v: Dictionary = VIEW.alert if g.alert else VIEW.calm
	# Easier guards see less far; the width of the cone stays the same.
	return {"range": v.range * tuning("view"), "half": v.half}


static func _angle_diff(a: float) -> float:
	return wrapf(a, -PI, PI)


# --- A new round ---------------------------------------------------------------

## Build a museum and put the thief's start as far from the guards as it goes.
static func new_map(seed: int, size: String = "small", guards: int = -1, shape: String = "") -> void:
	if guards < 0:
		guards = guard_count(size)
	Museum.regenerate(seed, size, shape)
	Props.list.clear()
	var starts := _guard_starts(guards)
	var candidates: Array = []
	var furthest := 0.0
	for t in Museum.open_tiles:
		if not Museum.is_ring(t.x, t.y):
			continue
		var d := INF
		for s in starts:
			d = minf(d, Museum.dist(s.x, s.y, t.x, t.y))
		candidates.append([t, d])
		furthest = maxf(furthest, d)
	if candidates.is_empty():
		return
	# Anywhere comfortably far from the guards, at random.
	var good := candidates.filter(func(c): return c[1] >= furthest * 0.72)
	Museum.spawn = good[randi() % good.size()][0]


static func _start_stop(i: int, count: int) -> int:
	return (i * Museum.watchpoints.size() / count) % Museum.watchpoints.size()


static func _guard_starts(count: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in count:
		out.append(Museum.watchpoints[_start_stop(i, count)])
	return out


static func new_thief(id: String = "p1") -> Thief:
	var t := Thief.new()
	t.id = id
	var s := Museum.spawn if id == "p1" else _second_spawn()
	t.x = s.x + 0.5
	t.y = s.y + 0.5
	return t


## The nearest free tile to the spawn, so two thieves do not start inside each other.
static func _second_spawn() -> Vector2i:
	var best := Museum.spawn
	var best_d := INF
	for t in Museum.open_tiles:
		var d := Museum.dist(t.x, t.y, Museum.spawn.x, Museum.spawn.y)
		if d >= 1 and d <= 3 and d < best_d:
			best_d = d
			best = t
	return best


static func new_guards(count: int = 2) -> Array[Guard]:
	var out: Array[Guard] = []
	var n := mini(count, GUARD_NAMES.size())
	for i in n:
		var stop := _start_stop(i, n)
		var s := Museum.watchpoints[stop]
		var g := Guard.new()
		g.id = "g%d" % (i + 1)
		g.name = GUARD_NAMES[i]
		g.x = s.x + 0.5
		g.y = s.y + 0.5
		g.target = s
		g.stop = stop
		g.seen_at = Watch.blank_sight()
		out.append(g)
	return out


# --- Moving ----------------------------------------------------------------

## Push a circle out of every solid tile it overlaps: past the corner of a case
## it slides round instead of stopping dead. Returns [x, y, hit].
static func _resolve(x: float, y: float, r: float) -> Array:
	var hit := ""
	for pass_n in 2:
		for ty in range(int(floor(y - r)), int(floor(y + r)) + 1):
			for tx in range(int(floor(x - r)), int(floor(x + r)) + 1):
				if not Museum.blocks_move(tx + 0.5, ty + 0.5):
					continue
				var cx := maxf(tx, minf(x, tx + 1))
				var cy := maxf(ty, minf(y, ty + 1))
				var nx := x - cx
				var ny := y - cy
				var d := sqrt(nx * nx + ny * ny)
				if d >= r:
					continue
				if d < 1e-6:
					# Centre inside the tile: leave by the nearest face.
					var faces := [x - tx, tx + 1 - x, y - ty, ty + 1 - y]
					var i := faces.find(faces.min())
					nx = -1.0 if i == 0 else (1.0 if i == 1 else 0.0)
					ny = -1.0 if i == 2 else (1.0 if i == 3 else 0.0)
					x += nx * (faces[i] + r)
					y += ny * (faces[i] + r)
				else:
					x += nx / d * (r - d)
					y += ny / d * (r - d)
				# A case anywhere along the contact wins: it is the louder one.
				if Museum.is_cover(tx + 0.5, ty + 0.5):
					hit = "shelf"
				elif hit == "":
					hit = "wall"
	return [x, y, hit]


## Move a circle through the grid, sliding along walls. Long steps are split so
## a fast frame cannot tunnel through a partition. Returns [x, y, hit].
static func move_with_collision(x: float, y: float, dx: float, dy: float, r: float = BODY) -> Array:
	var steps := maxi(1, int(ceil(sqrt(dx * dx + dy * dy) / (r * 0.5))))
	var hit := ""
	for i in steps:
		var res := _resolve(x + dx / steps, y + dy / steps, r)
		x = res[0]
		y = res[1]
		if res[2] == "shelf" or hit == "":
			hit = res[2] if res[2] != "" else hit
	return [x, y, hit]


## Doorway assist: pushing straight at a wall with an opening just beside you
## steers you into it. Returns the sideways offset to the lane, or null.
static func _doorway_assist(x: float, y: float, dx: int, dy: int) -> Variant:
	if dx != 0 and dy != 0:
		return null
	var horizontal := dx != 0
	var along := signi(dx) if horizontal else signi(dy)
	var a := x if horizontal else y
	var b := y if horizontal else x
	var solid := func(aa: float, bb: float) -> bool:
		return Museum.blocks_move(aa, bb) if horizontal else Museum.blocks_move(bb, aa)
	var ahead := floorf(a) + along + 0.5
	var here := floorf(a) + 0.5
	var centre := floorf(b) + 0.5
	var candidates: Array[float] = []
	if not solid.call(ahead, centre):
		candidates.append(centre)
	for side in ([-1, 1] if b - centre < 0 else [1, -1]):
		var c: float = centre + side
		if not solid.call(ahead, c) and not solid.call(here, c):
			candidates.append(c)
	for c in candidates:
		if absf(c - b) <= ASSIST_REACH:
			var off := c - b
			if absf(off) < 0.02:
				return null
			return Vector2(0, off) if horizontal else Vector2(off, 0)
	return null


static func _pressed(keys: Dictionary, names: Array) -> bool:
	for k in names:
		if keys.has(k):
			return true
	return false


static func _touches_cover(x: float, y: float, r: float = 0.34) -> bool:
	return Museum.is_cover(x + r, y) or Museum.is_cover(x - r, y) or Museum.is_cover(x, y + r) or Museum.is_cover(x, y - r)


## Move a thief one frame. keys holds the pressed key names ("w", "up",
## "shift"...). Returns {"bumped": "", "wall" or "shelf", "entered_cover": bool}.
static func step_thief(p: Thief, keys: Dictionary, dt: float, scheme: String = "solo") -> Dictionary:
	var pad: Dictionary = SCHEMES[scheme]
	var dx := 0
	var dy := 0
	if not p.out:
		if _pressed(keys, pad.up): dy -= 1
		if _pressed(keys, pad.down): dy += 1
		if _pressed(keys, pad.left): dx -= 1
		if _pressed(keys, pad.right): dx += 1
	# The crouch key toggles, on the press.
	var crouch_key := not p.out and _pressed(keys, pad.crouch)
	if crouch_key and not p.crouch_key:
		p.crouched = not p.crouched
	p.crouch_key = crouch_key
	if p.crouched:
		p.posture = minf(1.0, p.posture + dt / CROUCH_SECONDS)
	else:
		p.posture = maxf(0.0, p.posture - dt / CROUCH_SECONDS)

	# Getting back up is all you do while you do it.
	var rising := not p.crouched and p.posture > 0
	var held := (dx != 0 or dy != 0) and not rising
	if not held:
		p.speed = maxf(0.0, p.speed - DECEL * dt)
		p.moving = false
		p.sprinting = false
		p.blocked = false
		return {"bumped": "", "entered_cover": false}
	p.speed = CROUCH_SPEED if p.crouched else minf(TOP_SPEED, maxf(CREEP, p.speed + ACCEL * dt))

	var len := sqrt(dx * dx + dy * dy)
	var px := p.x
	var py := p.y
	var moved := move_with_collision(px, py, dx / len * p.speed * dt, dy / len * p.speed * dt)
	var nx: float = moved[0]
	var ny: float = moved[1]
	var hit: String = moved[2]

	var wanted := p.speed * dt
	# Pushing into a wall with an opening beside it: sidestep into the opening.
	var lost := wanted - Museum.dist(px, py, nx, ny)
	var assisted := false
	if lost > wanted * 0.3:
		var side = _doorway_assist(nx, ny, dx, dy)
		if side != null:
			var k := minf(1.0, lost / (side as Vector2).length())
			var m := move_with_collision(nx, ny, side.x * k, side.y * k)
			nx = m[0]
			ny = m[1]
			assisted = true

	var got := Museum.dist(px, py, nx, ny)
	# Progress in the direction asked for: stopped dead, or sliding along a
	# wall on a diagonal, is a bump; brushing a door jamb is not.
	var forward := ((nx - px) * dx + (ny - py) * dy) / len
	var blocked := not assisted and forward < wanted * 0.6
	var bumped := ""
	if blocked and not p.blocked:
		bumped = hit if hit != "" else "wall"
	var entered := _touches_cover(nx, ny) and not _touches_cover(px, py)
	p.x = nx
	p.y = ny
	p.dir = atan2(dy, dx)
	p.moving = got > 0.0001
	p.sprinting = p.speed > RUN_THRESHOLD
	p.blocked = blocked
	return {"bumped": bumped, "entered_cover": entered}


# --- Seeing ------------------------------------------------------------------

## The nearest thief this guard can see, or null.
static func visible_to(g: Guard, thieves: Array[Thief]) -> Thief:
	var best: Thief = null
	var best_d := INF
	for p in thieves:
		if p.out or not can_see(g, p):
			continue
		var d := Museum.dist(g.x, g.y, p.x, p.y)
		if d < best_d:
			best_d = d
			best = p
	return best


static func can_see(g: Guard, p: Thief) -> bool:
	var d := Museum.dist(g.x, g.y, p.x, p.y)
	var view := view_of(g)
	# Under a lit ceiling you are visible from anywhere with a line to you.
	if d > (LIT_RANGE if Museum.is_lit(p.x, p.y) else view.range):
		return false
	# The cases are waist-high: all the way down behind one, you are hidden.
	var over_cover := p.posture < DOWN
	if d < TOUCH_RANGE:
		return Museum.has_line_of_sight(g.x, g.y, p.x, p.y, over_cover)
	if absf(_angle_diff(atan2(p.y - g.y, p.x - g.x) - g.dir)) > view.half:
		return false
	return Museum.has_line_of_sight(g.x, g.y, p.x, p.y, over_cover)


## A point in the guard's cone, in its torch's reach, nothing in the way.
static func in_view(g: Guard, x: float, y: float) -> bool:
	var view := view_of(g)
	var d := Museum.dist(g.x, g.y, x, y)
	if d > view.range:
		return false
	if d < TOUCH_RANGE:
		return true
	return absf(_angle_diff(atan2(y - g.y, x - g.x) - g.dir)) <= view.half \
		and Museum.has_line_of_sight(g.x, g.y, x, y)


## Write down what the guard can see right now: its picture of the museum.
static func _mark_seen(g: Guard, now: float) -> void:
	var view := view_of(g)
	var w := Museum.w
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			_see(g, g.x + dx, g.y + dy, now)
	for i in SIGHT_RAYS:
		var a: float = g.dir - view.half + 2.0 * view.half * i / (SIGHT_RAYS - 1)
		var far := Museum.cast_ray(g.x, g.y, a, LIT_RANGE)
		var d := 0.5
		while d < far:
			var x := g.x + cos(a) * d
			var y := g.y + sin(a) * d
			if d <= view.range or Museum.is_lit(x, y):
				_see(g, x, y, now)
			d += 0.5


static func _see(g: Guard, x: float, y: float, now: float) -> void:
	var cx := int(floor(x))
	var cy := int(floor(y))
	if cx >= 0 and cy >= 0 and cx < Museum.w and cy < Museum.h:
		g.seen_at[cy * Museum.w + cx] = now


static func is_hidden(guards: Array[Guard], p: Thief) -> bool:
	for g in guards:
		if can_see(g, p):
			return false
	return true


static func caught(guards: Array[Guard], p: Thief) -> bool:
	if p.out:
		return false
	for g in guards:
		if Museum.dist(g.x, g.y, p.x, p.y) < CATCH_RANGE:
			return true
	return false


# --- Guards --------------------------------------------------------------------

## In sight, or seen, heard or called out a moment ago: it knows where to go.
static func on_to(g: Guard, now: float) -> bool:
	return g.sees_player or (g.memory != null and now - g.memory.at < LOST_MS)


static func _situation_of(g: Guard) -> String:
	var at := g.memory.at if g.memory else 0.0
	var cleared := 1 if g.memory and g.memory.cleared else 0
	return "%d|%d|%d" % [int(at), cleared, 1 if g.alert else 0]


## A decision to make: no plan, done with it, or the facts changed.
static func needs_plan(g: Guard) -> bool:
	return g.decision == null or g.path.is_empty() or g.planned_for != _situation_of(g)


## What hearing something does to a guard's nerves: one more alarm from calm,
## for good at the third or on top of a sighting; otherwise the countdown back
## to calm restarts.
static func _alarm(g: Guard) -> void:
	if g.calm_in == INF:
		g.alert = true
		return
	if not g.alert:
		g.alarms += 1
	g.alert = true
	g.calm_in = INF if g.alarms >= int(tuning("alarms")) else tuning("calm_after")


## Set off on a decision. Errands are finished first; a guard on its way
## somewhere finishes the walk unless what it knows has changed — Laya still
## sets pace and torch. A decision it was torn over costs a moment's hesitation.
static func apply_decision(g: Guard, decision: Decision) -> void:
	if g.errand != "":
		g.decision = decision
		return
	var situation := _situation_of(g)
	if g.decision and g.planned_for == situation and not g.path.is_empty():
		g.decision.aggression = decision.aggression
		g.decision.look = decision.look
		g.decision.near = decision.near
		g.decision.hiding = decision.hiding
		g.decision.ms = decision.ms
		return
	var hesitate := decision.torn and (g.decision == null or decision.plan != g.decision.plan)
	if decision.plan != "search":
		g.search_spot = Vector2i(-1, -1)
	g.decision = decision
	g.planned_for = situation
	g.target = decision.target
	g.path = Museum.bfs_path(_tile(g), decision.target)
	g.sweep = 0.7 if hesitate else 0.0


static func _tile(g: Guard) -> Vector2i:
	return Vector2i(int(floor(g.x)), int(floor(g.y)))


## A plain decision for a guard nobody has decided for yet.
static func _default_decision(g: Guard) -> Decision:
	var d := Decision.new()
	d.id = g.id
	d.plan = "patrol"
	d.look = "sweep" if g.alert else "ahead"
	d.aggression = 0.45 if g.alert else 0.2
	d.near = 0.6
	return d


## One frame of one guard.
static func step_guard(g: Guard, thieves: Array[Thief], noises: Array[SoundEvent], now: float, dt: float) -> void:
	var player := visible_to(g, thieves)
	g.sees_player = player != null
	_mark_seen(g, now)

	if player:
		g.search_spot = Vector2i(-1, -1)
		g.watching = 0
		# Seeing is believing: alert for the rest of the round.
		g.alert = true
		g.calm_in = INF
		var m := Guard.Memory.new()
		m.x = player.x
		m.y = player.y
		m.kind = "seen"
		m.at = now
		# The heading too: someone running off east is a better clue than a spot.
		m.has_heading = player.moving
		m.vx = cos(player.dir)
		m.vy = sin(player.dir)
		g.memory = m
		g.path = Museum.bfs_path(_tile(g), Vector2i(int(floor(player.x)), int(floor(player.y))))
	elif not noises.is_empty():
		# Footsteps come every stride: latch the heard spot and let it settle.
		var stale := g.memory == null or g.memory.kind != "noise" or now - g.memory.at > NOISE_REFRESH_MS
		if stale:
			# The nearer of several noises wins the ear.
			var spot = null
			var spot_d := INF
			for n in noises:
				var at = Hearing.heard_at(g, n)
				var d := Museum.dist(g.x, g.y, n.x, n.y)
				if at != null and d < spot_d:
					spot = at
					spot_d = d
			if spot != null:
				_alarm(g)
			# A fresh sighting, your own or yelled, beats a noise.
			var told := g.memory != null and (g.memory.kind == "seen" or g.memory.kind == "called") and now - g.memory.at <= 2000
			if spot != null and not told:
				var m := Guard.Memory.new()
				m.x = spot.x
				m.y = spot.y
				m.kind = "noise"
				m.at = now
				g.memory = m

	# Something knocked over that was standing before: somebody is about.
	# One more alarm, and the spot becomes the thing to check — unless it
	# has fresher news.
	if not player:
		var fallen := Props.spotted_by(g)
		if fallen:
			_alarm(g)
			var fresh := g.memory != null and g.memory.kind != "noise" and now - g.memory.at <= 2000
			if not fresh:
				var m := Guard.Memory.new()
				m.x = fallen.x
				m.y = fallen.y
				m.kind = "noise"
				m.at = now
				g.memory = m
				g.planned_for = ""
			thoughts.append({"by": g.name, "text": "¿Quién ha tirado %s?" % Props.NAMES[fallen.kind]})

	# Looked the clue's area over and nobody is there: noted, and the plan is
	# open again, so the next decision goes somewhere else.
	if g.memory and not g.memory.cleared and not g.sees_player and Watch.clue_cleared(g):
		g.memory.cleared = true
		g.search_spot = Vector2i(-1, -1)
		_think(g.name, Museum.zone_at(g.memory.x, g.memory.y), now)

	if g.memory and now - g.memory.at > MEMORY_MS:
		g.memory = null
		g.search_spot = Vector2i(-1, -1)

	# An alarm raised by sounds alone wears off.
	if g.alert and g.calm_in != INF:
		g.calm_in -= dt
		if g.calm_in <= 0:
			g.alert = false
			g.calm_in = 0
			g.memory = null
			g.search_spot = Vector2i(-1, -1)
			g.errand = ""

	var dec := g.decision if g.decision else _default_decision(g)
	var alert := g.alert

	# What comes first: going after the thief beats any errand; warning a
	# colleague (warn_partners) beats lights; lights come last.
	if on_to(g, now):
		g.errand = ""
	elif g.errand == "" and alert:
		var room := _switch_in_view(g, now)
		if room:
			g.errand = "lights"
			g.errand_room = room.id
			g.sweep = 0
			g.watching = 0
			g.target = room.switch_at
			g.path = Museum.bfs_path(_tile(g), room.switch_at)
	if g.errand == "lights":
		var room: Museum.Room = Museum.rooms[g.errand_room] if g.errand_room < Museum.rooms.size() else null
		if room == null or Museum.lights_left[room.id] > 0:
			g.errand = ""  # someone else got there first
		elif g.path.is_empty() and _tile(g) == room.switch_at:
			_switch_on(room.id, g.name)
			g.errand = ""
			# Turn round and take in the room it has just lit.
			g.dir = atan2(-room.face.y, -room.face.x)
			g.sweep = 1.2
			return
		elif g.path.is_empty():
			g.path = Museum.bfs_path(_tile(g), room.switch_at)
			if g.path.is_empty():
				g.errand = ""

	# Standing still, sweeping the galleries in view.
	if g.sweep > 0 and not g.sees_player:
		g.sweep -= dt
		g.dir += dt * (1.6 if alert else 0.7)
		g.watching += dt
		if g.watching > MAX_WATCH:
			g.watching = 0
			g.sweep = 0
			_next_stop(g)
		return

	# Calm is a stroll; alert is a brisk walk that becomes a run.
	var speed := ((2.3 + dec.aggression * 2.3) if alert else (1.0 + dec.aggression * 0.5)) * tuning("speed")

	# Close enough to lunge: go for the body, not the middle of its tile.
	if player and Museum.dist(g.x, g.y, player.x, player.y) < LUNGE_RANGE:
		var ddx := player.x - g.x
		var ddy := player.y - g.y
		var dd := sqrt(ddx * ddx + ddy * ddy)
		var mv := move_with_collision(g.x, g.y, ddx / dd * speed * dt, ddy / dd * speed * dt)
		g.x = mv[0]
		g.y = mv[1]
		g.watching = 0
		g.dir += _angle_diff(atan2(ddy, ddx) - g.dir) * minf(1.0, dt * 10)
		return

	if g.path.is_empty():
		if g.sees_player or g.errand != "":
			return
		# Reached the spot a clue pointed at and found nobody: comb the area,
		# as far out and where Laya's hunches say, until it has all been seen.
		var hunting := dec.plan in ["chase", "cut_off", "follow", "search"]
		if hunting and g.memory:
			var spot := Vector2i(-1, -1) if Watch.clue_cleared(g) else _search_spot_near(g, dec.near, dec.hiding)
			g.sweep = 1.2
			if spot.x >= 0:
				g.search_spot = spot
				g.target = spot
				g.path = Museum.bfs_path(_tile(g), spot)
			elif not g.memory.cleared:
				g.memory.cleared = true
				g.search_spot = Vector2i(-1, -1)
				_think(g.name, Museum.zone_at(g.memory.x, g.memory.y), now)
			return
		if g.watching > MAX_WATCH:
			g.watching = 0
			_next_stop(g)
			return
		# Bored guards barely stop; worried ones stand and look.
		if dec.plan == "watch" or dec.plan == "cover":
			g.sweep = 3.0 if alert else 1.5
		elif dec.plan == "check_zone":
			g.sweep = 1.8
		else:
			g.sweep = 1.5 if alert else 0.5
		if dec.plan == "patrol":
			_next_stop(g)
		return

	var step := g.path[0]
	var dx := step.x + 0.5 - g.x
	var dy := step.y + 0.5 - g.y
	var d := sqrt(dx * dx + dy * dy)
	if d < 0.12:
		g.path.remove_at(0)
		return
	var mv := move_with_collision(g.x, g.y, dx / d * speed * dt, dy / d * speed * dt)
	g.x = mv[0]
	g.y = mv[1]
	g.watching = 0
	# Where the torch points while walking is Laya's call.
	var desired := atan2(dy, dx)
	if not g.sees_player:
		if dec.look == "sweep":
			desired += sin(now / 420.0 + (0.0 if g.id == "g1" else 2.0)) * 0.7
		elif dec.look == "clue" and g.memory:
			var to_clue := atan2(g.memory.y - g.y, g.memory.x - g.x)
			# Not over its shoulder: it still has to see where it is going.
			if absf(_angle_diff(to_clue - desired)) < 1.7:
				desired = to_clue
	g.dir += _angle_diff(desired - g.dir) * minf(1.0, dt * 7)


static func _next_stop(g: Guard) -> void:
	g.stop = (g.stop + 1) % Museum.watchpoints.size()
	g.target = Museum.watchpoints[g.stop]
	g.path = Museum.bfs_path(_tile(g), g.target)


## Somewhere worth checking near a clue, or (-1, -1) when everything in reach
## has been seen since. near sets the radius; hiding picks tucked-in spots
## beside the cases over the ones that see furthest.
static func _search_spot_near(g: Guard, near: float, hiding: float) -> Vector2i:
	var m := g.memory
	var radius := 2.5 + (1 - near) * 4.5
	var ranked: Array = []
	for t in Museum.open_tiles:
		var d := Museum.dist(t.x + 0.5, t.y + 0.5, m.x, m.y)
		if d < 1.2 or d > radius:
			continue
		var seen := g.seen_at[t.y * Museum.w + t.x]
		if seen > 0 and seen >= m.at:
			continue
		var tucked := 0
		for dd in Museum.DIRS:
			if Museum.is_cover(t.x + dd.x + 0.5, t.y + dd.y + 0.5):
				tucked += 1
		ranked.append([t, hiding * tucked * 6 + (1 - hiding) * Museum.openness(t.x, t.y)])
	if ranked.is_empty():
		return Vector2i(-1, -1)
	ranked.sort_custom(func(a, b): return a[1] > b[1])
	# Among the best few, at random, so two guards do not comb the same tile.
	return ranked[randi() % mini(4, ranked.size())][0]


static func _think(by: String, zone: Museum.Zone, now: float) -> void:
	var key := "%s:%d" % [by, zone.id if zone else -1]
	if now - _said_clear.get(key, -INF) < 20000:
		return
	_said_clear[key] = now
	thoughts.append({"by": by, "text": "%s está despejada" % (zone.label if zone else "la zona")})


# --- Lights ------------------------------------------------------------------

## The nearest dark room whose switch this guard can see.
static func _switch_in_view(g: Guard, now: float) -> Museum.Room:
	var best: Museum.Room = null
	var best_d := INF
	for r in Museum.rooms:
		if Museum.lights_left[r.id] > 0:
			continue
		# No point lighting a gallery it has just looked over and found empty.
		var skip := false
		for z in Museum.zones:
			if z.room == r.id and Watch.controlled(g, z, now - RECHECK_MS):
				skip = true
		if skip:
			continue
		var sx := r.switch_at.x + 0.5
		var sy := r.switch_at.y + 0.5
		var d := Museum.dist(g.x, g.y, sx, sy)
		if d >= best_d or not in_view(g, sx, sy):
			continue
		best = r
		best_d = d
	return best


static func _switch_on(room: int, by: String) -> void:
	Museum.lights_left[room] = LIGHT_MS
	light_events.append({"room": room, "by": by})


static func tick_lights(dt: float) -> void:
	for i in Museum.lights_left.size():
		Museum.lights_left[i] = maxf(0.0, Museum.lights_left[i] - dt * 1000.0)


# --- Guards together -----------------------------------------------------------

## A guard who spots you yells, and the yell is a sound like any other: a
## colleague comes only if it carries that far, heading roughly for the yell.
## saw_before holds each guard's sees_player from the previous frame.
## Returns the shouts: {from, x, y, first, heard_by}.
static func call_for_backup(saw_before: Dictionary, guards: Array[Guard], now: float) -> Array[Dictionary]:
	var shouts: Array[Dictionary] = []
	for spotter in guards:
		if not spotter.sees_player or spotter.memory == null:
			continue
		# A new sighting, not the same chase blinking in and out of view.
		var first: bool = not saw_before.get(spotter.id, false) and now - spotter.shouted_at > FRESH_YELL_MS
		if not first and now - spotter.shouted_at < CALL_REFRESH_MS:
			continue
		var yell := SoundEvent.make(spotter.x, spotter.y, "shout")
		var heard_by: Array[String] = []
		spotter.shouted_at = now
		for g in guards:
			if g == spotter or g.sees_player:
				continue
			var spot = Hearing.heard_at(g, yell)
			if spot == null:
				continue
			heard_by.append(g.name)
			var m := Guard.Memory.new()
			m.x = spot.x
			m.y = spot.y
			m.kind = "called"
			m.at = now
			g.memory = m
			_alarm(g)
			g.errand = ""
			g.search_spot = Vector2i(-1, -1)
			g.sweep = 0
			g.watching = 0
			g.target = Museum.nearest_open(spot.x, spot.y)
			g.path = Museum.bfs_path(_tile(g), g.target)
		shouts.append({"from": spotter.name, "x": spotter.x, "y": spotter.y, "first": first, "heard_by": heard_by})
	return shouts


## An alert guard that sees a colleague who does not know yet walks over and
## tells it, quietly. More important than lights, less than chasing the thief.
## Returns the warnings given: {from, to, x, y}.
static func warn_partners(guards: Array[Guard], now: float) -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	for me in guards:
		var current: Guard = null
		if me.errand == "warn":
			for o in guards:
				if o.id == me.errand_partner:
					current = o
		var b := current
		if b == null:
			var best_d := INF
			for o in guards:
				if o == me or o.alert or not in_view(me, o.x, o.y):
					continue
				var d := Museum.dist(me.x, me.y, o.x, o.y)
				if d < best_d:
					best_d = d
					b = o
		if b == null:
			continue
		var busy := current != null
		if not me.alert or b.alert or on_to(me, now):
			if busy:
				me.errand = ""
			continue
		if not busy:
			me.errand = "warn"
			me.errand_partner = b.id
			me.sweep = 0
			me.watching = 0

		if Museum.dist(me.x, me.y, b.x, b.y) < WARN_RANGE:
			# As sure as the messenger was: told by one who saw you, for good.
			if me.calm_in == INF:
				b.alert = true
				b.calm_in = INF
			else:
				_alarm(b)
			if me.memory:
				b.memory = me.memory.copy()
				b.memory.kind = "called"
			b.sweep = 0
			b.watching = 0
			me.errand = ""
			me.dir = atan2(b.y - me.y, b.x - me.x)
			me.sweep = 0.8
			me.path.clear()
			b.dir = atan2(me.y - b.y, me.x - b.x)
			warnings.append({"from": me.name, "to": b.name, "x": me.x, "y": me.y})
			continue

		# Keep heading for where the colleague is now: it is walking too.
		var to := _tile(b)
		if not busy or me.target != to or me.path.is_empty():
			me.target = to
			me.path = Museum.bfs_path(_tile(me), to)
	return warnings


## Idle guards should not walk the same gallery: when two drift together, the
## later one goes to the stop furthest from all the others.
static func keep_apart(guards: Array[Guard]) -> void:
	var idle := func(g: Guard) -> bool:
		return not g.sees_player and g.memory == null and g.errand == ""
	for i in guards.size():
		for j in range(i + 1, guards.size()):
			var a := guards[i]
			var b := guards[j]
			if not idle.call(a) or not idle.call(b):
				continue
			if Museum.dist(a.x, a.y, b.x, b.y) > TOO_CLOSE:
				continue
			var best_index := b.stop
			var best_d := -1.0
			for k in Museum.watchpoints.size():
				var wp := Museum.watchpoints[k]
				var d := INF
				for o in guards:
					if o != b:
						d = minf(d, Museum.dist(wp.x + 0.5, wp.y + 0.5, o.x, o.y))
				if d > best_d:
					best_d = d
					best_index = k
			if best_index == b.stop:
				continue
			b.stop = best_index
			b.target = Museum.watchpoints[best_index]
			b.sweep = 0
			b.watching = 0
			b.path = Museum.bfs_path(_tile(b), b.target)
