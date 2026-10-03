class_name Practice
extends RefCounted
## The band's house as a place to be in (Den) and, in its dojo, to practise:
## no guards, and nothing in it won or kept but the marks of the trials (no stars, no
## progress). What the dojo shows grows with the story: each thing to try comes into
## it when the job that teaches it is reached.
##
## The mode is still called "practica" (it began as one room), and its plan
## comes from the active HomeSpace PackedScene. MapFile.list() only reads
## the challenges' folder.
##
## The dojo has a zone of its own for each trial (Den.DOJO_ZONES, DojoTrials.TABLE) and
## these two lists of what is in it:
##   DojoTrials.TABLE  the trials: each with its three start points (the object that
##                     starts it, VIAS), its lesson, its zone. THE list of what there is to
##                     try; the rest of the dojo only dresses it.
##   ITEMS             what is not a trial: things to knock over and hideouts to try.
## Jobs are numbered 1-25: museum (n - 1) / 5 + 1, test (n - 1) % 5 + 1. What comes
## with which lesson (Story.LESSONS; the job that teaches it, Story.lesson_night, is
## the first with it), by zone (Den.DOJO_ZONES):
##   guard (museum 1 · test 2)   circuit    the stealth circuit and its scarecrows
##   torch (museum 1 · test 4)   aguanta    the three armours of AGUANTA ESCONDIDO
##   games (museum 2 · test 1)   atrapa, pedestal   PILLA EL CALCETÍN and EQUILIBRIO;
##                               lockpick   the GANZÚA cases
##   props (museum 2 · test 3)   bolos      the circles of BOLOS; squeeze the ESCONDITE
##                               cases; aguanta the crate and the locker; the bins and the bust
##   case_alarm (museum 3 · 1)   wires      the CABLES boxes
##   two (museum 3 · test 3)     steady     the PULSO boxes
## The row of a thing of ITEMS:
##   id       what it is (a key of the docs' and the tests')
##   lesson   the lesson that brings it
##   text     its name in words (a key into Text)
##   zone     where it stands (Den.DOJO_ZONES)
##   hide     tile and furniture (Hideouts.PIECES) to hide in
##   props    things to knock over, {kind, at}

const MODE := "practica"

const ITEMS := [
	{"id": "bins", "lesson": "props", "zone": "bolos", "text": "HIDEOUT_ITEM_BINS",
		"props": [{"kind": "bin", "at": Vector2i(50, 16)}, {"kind": "bin", "at": Vector2i(60, 11)}]},
	{"id": "bust", "lesson": "props", "zone": "lockpick", "text": "HIDEOUT_ITEM_BUST", "props": [{"kind": "bust", "at": Vector2i(32, 2)}]},
	{"id": "crate", "lesson": "props", "zone": "aguanta", "text": "HIDEOUT_ITEM_CRATE", "hide": {"tile": Vector2i(57, 20), "piece": "box"}},
	{"id": "locker", "lesson": "props", "zone": "aguanta", "text": "HIDEOUT_ITEM_LOCKER", "hide": {"tile": Vector2i(57, 26), "piece": "fridge"}},
]

## What each kind of start point is (DojoTrials.TABLE's `via`): how it is started
## (`action`: the action key within `reach` of it; `enter`: getting onto it, or into
## it, with the action the thing already has), and how it stands in the plan (`solid`:
## it takes its tile as cover; `wall`: it hangs on the wall at the side of its tile that
## the row says).
const VIAS := {
	"sock": {"action": true, "reach": 1.3, "solid": true, "stand": Vector2(0.5, 1.5)},
	"ring": {"action": true, "reach": 0.6, "solid": false, "stand": Vector2(0.5, 0.5)},
	"plinth": {"action": false, "solid": true, "stand": Vector2(0.5, 1.5)},
	"armour": {"action": false, "solid": false, "stand": Vector2(0.5, 0.5)},
	"vitrine": {"action": true, "reach": 1.5, "solid": true, "stand": Vector2(0.5, 1.5)},
	"hideout": {"action": true, "reach": 1.5, "solid": true, "stand": Vector2(0.5, 1.5)},
	"alarm_wires": {"action": true, "reach": 1.5, "solid": false, "stand": Vector2(0.5, 0.5)},
	"alarm_glass": {"action": true, "reach": 1.5, "solid": false, "stand": Vector2(0.5, 0.5)},
}
## The lantern of AGUANTA ESCONDIDO: the post it stands on (only while the game
## is on), and where its swing is centred (radians on the plan, 0 east).
const LANTERN_AT := Vector2i(54, 23)
const LANTERN_DIR := 0.0
## An object of a test stays lit (a green light, the glass up) this long once it is done,
## goes back over LAMP_REARM_S and is armed again.
const LAMP_OPEN_S := 3.5
const LAMP_REARM_S := 0.6


static func _item(id: String) -> Dictionary:
	for i in ITEMS:
		if i.id == id:
			return i
	return {}


# --- The trials' start points ---------------------------------------------------------------

## The trials the band of this size has got to, in TABLE order.
static func open_trials(players := 1) -> Array:
	return DojoTrials.TABLE.filter(func(t: Dictionary) -> bool: return DojoTrials.unlocked(String(t.id), players))


## The start points of the trials the band has got to: [{id, tier (0..2), at (tile),
## via, text (the trial's name), zone}], trial by trial and easy to hard.
static func trial_starts(players := 1) -> Array:
	var out: Array = []
	for t in open_trials(players):
		for tier in 3:
			out.append({"id": t.id, "tier": tier, "at": t.starts[tier], "via": t.via, "text": t.name, "zone": t.zone})
	return out


## The start point one presses the action key at (a sock on its pedestal, a circle, a
## case, a box on the wall): {id, tier} of the trial it starts, or empty. The nearest
## within reach of `pos` (tiles). Pedestals and armours are not started this way: one
## climbs onto them, or hides in them (DojoWatch).
static func start_at(pos: Vector2, players := 1) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for s in trial_starts(players):
		var v: Dictionary = VIAS[s.via]
		if not v.action:
			continue
		var d := pos.distance_to(Vector2(s.at) + Vector2(0.5, 0.5))
		if d <= float(v.reach) and d < best_d:
			best_d = d
			best = {"id": s.id, "tier": s.tier}
	return best


## The tile of a trial's start point at a difficulty (0..2).
static func start_of(id: String, tier: int, _players := 1) -> Vector2i:
	return DojoTrials.info(id).starts[clampi(tier, 0, 2)]


## Where to stand (tiles) to use the start point of a trial at a difficulty.
static func stand_of(id: String, tier: int) -> Vector2:
	return Vector2(start_of(id, tier)) + VIAS[DojoTrials.info(id).via].stand


## The difficulty (0..2) of the start point of a trial at a tile, or -1 if none is.
static func start_tier(id: String, tile: Vector2i, players := 1) -> int:
	for s in trial_starts(players):
		if s.id == id and s.at == tile:
			return s.tier
	return -1


## The tiles of the hideouts the band has got to: the crate and the locker, and
## the armours of AGUANTA ESCONDIDO.
static func hide_tiles(players := 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in open_items(players):
		if i.has("hide"):
			out.append(i.hide.tile)
	for t in open_trials(players):
		if t.via == "armour":
			for s in t.starts:
				out.append(s)
	return out


## The rect (x, y, w, h in tiles) of the zone of a trial.
static func zone_rect(zone: String) -> Rect2i:
	var r: Array = Den.DOJO_ZONES[zone]
	return Rect2i(r[0], r[1], r[2], r[3])


# --- The lights of the tests' objects ------------------------------------------------------------
## Done, an object of a test signals (a green light, the glass up, the lever down), stays
## so LAMP_OPEN_S, goes back over LAMP_REARM_S and is armed again. Purely for the picture
## (DenView): the marks are kept by DojoTrials.

## The lights as they start: every object waiting. Keys "<trial>:<tier>".
static func lamps_new() -> Dictionary:
	return {}


static func lamp_key(id: String, tier: int) -> String:
	return "%s:%d" % [id, tier]


## The object of a trial at a difficulty is done: it signals.
static func lamp_open(state: Dictionary, id: String, tier: int) -> void:
	state[lamp_key(id, tier)] = {"state": "open", "t": 0.0}


## Whether the object of a trial at a difficulty is signalling.
static func lamp_is_open(state: Dictionary, id: String, tier: int) -> bool:
	return state.get(lamp_key(id, tier), {}).get("state", "") == "open"


## Time passes: an open object closes, then arms again.
static func lamps_step(state: Dictionary, dt: float) -> void:
	for k in state.keys():
		var c: Dictionary = state[k]
		c.t = float(c.t) + dt
		if c.state == "open" and c.t >= LAMP_OPEN_S:
			c.state = "rearming"
			c.t = 0.0
		elif c.state == "rearming" and c.t >= LAMP_REARM_S:
			state.erase(k)


# --- The scarecrows -------------------------------------------------------------------
## A guard's scarecrow: a coat on a cross with a torch taped to it. It sees like a
## guard, only less far and less wide: within SCARECROW_RANGE tiles of its torch,
## SCARECROW_ANGLE either side of where it looks, with nothing in the way (walls,
## furniture, shut doors, smoke), and not a thief hiding or posing as a statue. It
## looks where its row says (`dir`, radians on the plan), or, if it has a `turn`, it
## sweeps: dir + turn.amp * sin(t * turn.speed + turn.phase). The only ones in the
## dojo are the stealth circuit's (a row of DojoTrials.TABLE with `scarecrows`).
const SCARECROW_RANGE := 5.5
const SCARECROW_ANGLE := 0.42
## Its torch is this far in front of the post (outside the tile it takes).
const SCARECROW_TORCH := 0.55
## Seen, the dojo goes red with an alarm for ALERT_S seconds, and cannot
## again for ALERT_COOLDOWN_S more, whoever is still in sight.
const ALERT_S := 3.0
const ALERT_COOLDOWN_S := 1.5


## The scarecrows the band of this size has got to: [{id, at, dir, turn?}].
static func scarecrows(players := 1) -> Array:
	var out: Array = []
	for t in open_trials(players):
		for i in (t.get("scarecrows", []) as Array).size():
			var s: Dictionary = t.scarecrows[i]
			var sc := {"id": "%s_%d" % [t.id, i], "at": s.at, "dir": s.dir}
			if s.has("turn"):
				sc["turn"] = s.turn
			out.append(sc)
	return out


## Where a scarecrow looks at time t (seconds), radians on the plan.
static func scarecrow_facing(sc: Dictionary, t := 0.0) -> float:
	var turn: Dictionary = sc.get("turn", {})
	if turn.is_empty():
		return float(sc.dir)
	return float(sc.dir) + float(turn.amp) * sin(t * float(turn.speed) + float(turn.get("phase", 0.0)))


## Where its torch is, in tiles.
static func scarecrow_torch(sc: Dictionary, t := 0.0) -> Vector2:
	var at: Vector2i = sc.at
	return Vector2(at) + Vector2(0.5, 0.5) + Vector2.from_angle(scarecrow_facing(sc, t)) * SCARECROW_TORCH


## Whether the scarecrow sees a thief at a spot (tiles): the guard's rule
## (Sim.can_see) with its own numbers. hidden: in a hideout or posing on a
## pedestal; low: down on all fours (cases are waist-high). los: an optional
## line-of-sight check (from, to, low) -> bool, the plan's by default. t: the
## seconds of the sweep.
static func scarecrow_sees(sc: Dictionary, pos: Vector2, hidden: bool, low := false, los := Callable(), t := 0.0) -> bool:
	if hidden:
		return false
	var facing := scarecrow_facing(sc, t)
	var from := scarecrow_torch(sc, t)
	var d := from.distance_to(pos)
	if d > SCARECROW_RANGE:
		return false
	if d > 0.3 and absf(wrapf((pos - from).angle() - facing, -PI, PI)) > SCARECROW_ANGLE:
		return false
	if los.is_valid():
		return bool(los.call(from, pos, low))
	if Smoke.blocks(from.x, from.y, pos.x, pos.y, Sim.now_ms()):
		return false
	return Museum.has_line_of_sight(from.x, from.y, pos.x, pos.y, low)


## The alarm's state: {active, left_s (of the alarm), cooldown_s}.
static func alert_new() -> Dictionary:
	return {"active": false, "left_s": 0.0, "cooldown_s": 0.0}


## One step of the alarm: it goes off when somebody is seen and it is not
## cooling down; runs ALERT_S; then cools down for ALERT_COOLDOWN_S.
static func alert_step(state: Dictionary, dt: float, seen: bool) -> Dictionary:
	var s := state.duplicate()
	if s.active:
		s.left_s = maxf(0.0, float(s.left_s) - dt)
		if s.left_s <= 0.0:
			s.active = false
			s.cooldown_s = ALERT_COOLDOWN_S
	elif float(s.cooldown_s) > 0.0:
		s.cooldown_s = maxf(0.0, float(s.cooldown_s) - dt)
	elif seen:
		s.active = true
		s.left_s = ALERT_S
	return s


# --- What is open -------------------------------------------------------------------------

## The job the band has got to (each size of band has its own).
static func reached(players := 1) -> int:
	return Story.unlocked(players)


## The job an item comes with.
static func item_night(item: Dictionary) -> int:
	return maxi(1, Story.lesson_night(item.lesson))


## Whether the band of this size has got as far as an item.
static func is_open(item: Dictionary, players := 1) -> bool:
	return reached(players) >= item_night(item)


## The items the dojo shows for a band this size, in order.
static func open_items(players := 1) -> Array:
	return ITEMS.filter(func(i: Dictionary) -> bool: return is_open(i, players))


## The house as a map for a band of this size: the plan, the dojo's things
## that are open, the way in and the door. The first case's tile is always the
## sock's, and the scarecrows (scarecrows) stand on cover tiles of their own
## (the round dresses them, see Scenery.build).
static func map(players := 1) -> MapFile:
	var items := open_items(players) if Den.ROOMS.has("dojo") else []
	var trials := open_trials(players) if Den.ROOMS.has("dojo") else []
	var cover: Array[Vector2i] = []
	var m := MapFile.new()
	m.name = Text.t("HIDEOUT_NAME")
	m.seed = 4242
	m.difficulty = "easy"
	m.loot = {"shape": "gem", "colour": "#e2262f", "name": Text.t("HIDEOUT_PIECE"), "blurb": Text.t("HIDEOUT_PIECE_BLURB"),
		"story": "", "seconds": 3.0}
	m.spawn = Den.SPAWN
	m.exit = Den.EXIT
	m.piece = Den.CASE_AT
	for t in trials:
		# What stands (not marked on the floor or hung on a wall) is cover to go round.
		if VIAS[t.via].solid:
			for s in t.starts:
				cover.append(s)
				if t.via == "plinth":
					m.exhibits[s] = "plinth"
		elif t.via == "armour":
			for s in t.starts:
				m.props.append({"kind": "armour", "at": s})
		for s in t.get("scarecrows", []):
			cover.append(s.at)
	for i in items:
		if i.has("hide"):
			cover.append(i.hide.tile)
			m.exhibits[i.hide.tile] = i.hide.piece
		for p in i.get("props", []):
			m.props.append(p.duplicate())
	var rows := Den.rows(cover)
	m._resize_plan(Den.W, Den.H)
	for y in Den.H:
		for x in Den.W:
			var c := rows[y][x]
			m.grid[y * Den.W + x] = Tiles.FLOOR if c == "." else (Tiles.COVER if c == "o" else Tiles.WALL)
	# The house is not the whole plan: what is beyond its walls is outside (the front door
	# looks onto it).
	m.derive_outside()
	return m


## The dojo's settings, for Sim.custom: no guards, no case to rob, and
## everything else on for the feet to try (the bombs, the pick, the props,
## the places to hide are the dojo's, whatever it shows).
static func tuning() -> Dictionary:
	return {"guards": 0, "case": false, "case_alarm": false, "props": false, "lights": false, "lockpick": true,
		"plinths": false, "hideouts": false, "theme": "", "lock": 1.0, "game_level": 0}
