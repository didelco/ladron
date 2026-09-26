class_name Heist
extends RefCounted
## The job: every level there is one thing to take and one door to leave by.
## Port of the web version's heist.ts.
##
## The piece sits in a case deep in the museum; you take it by standing
## next to it, still, for as long as the lock takes — step away and you start
## again — and forcing it sets its alarm off. The way out is a service door in
## the outer wall, far from the piece and never where you came in, so the job
## is always a crossing and never a there-and-back.
##
## With two thieves the job takes both: the case only gives while the other
## one holds the alarm panel, a box on a wall a good walk from it. Held, the
## case opens in silence; let go, the work stops where it was. Only if the
## partner is caught does the one left force it alone, alarm and all.

## The words of a piece, as keys into Text.
const TEXT_FIELDS := ["name", "blurb", "verb", "story"]

## Close enough to the case to work on it: next to it, diagonals too. Which
## way you face does not matter.
const REACH := 1.5
## Close enough to the alarm panel to hold it: on its tile or the next one.
const PANEL_REACH := 1.1
## Near enough to pick up a piece dropped on the floor.
const PICK_UP := 0.7
## Near enough to the door to be through it.
const DOOR := 0.8
## The case's alarm rings this often while someone is forcing it.
const ALARM_EVERY_MS := 900.0

# The job for the current level.
static var level := 1
static var loot: Dictionary = {}
## the case tile
static var at := Vector2i.ZERO
static var start := Vector2i.ONE
## floor tile in front of the door, and from it to the wall the door is in
static var exit := Vector2i.ONE
static var exit_face := Vector2i(-1, 0)
## start -> piece -> door, tile by tile, for the map on the mission screen
static var route: Array[Vector2i] = []
## the plan in three lines: [title, text]
static var plan: Array = []

# The take, frame by frame.
## 0..1 of the lock worked through; back to 0 the moment nobody is at it
static var progress := 0.0
## who is at the case, who has the piece ("" for nobody)
static var by := ""
static var carrier := ""
## where it lies on the floor after its carrier was caught, or INF
static var dropped := Vector2.INF
static var taken := false
static var _last_alarm := 0.0

# Two thieves: the alarm panel.
static var team := false
## floor tile where you stand to hold it, and from it to the wall it is on
static var panel := Vector2i(-1, -1)
static var panel_face := Vector2i(0, -1)
## who is holding it ("" for nobody)
static var panel_by := ""
## Four thieves: a second panel, far from the first, and both must be held.
static var panel2 := Vector2i(-1, -1)
static var panel2_face := Vector2i(0, -1)
static var panel2_by := ""
## someone is at the case, waiting for the panel
static var waiting := false
## Three thieves: the case has two locks, worked by two at once while the
## third holds the panel; short_hand while only one is at it.
static var hands := 1
static var short_hand := false

## The case is opened by a minigame (MgSafe), not by standing still for the
## piece's seconds: the game plays it and reports how far along each thief
## is (0..1, by thief id); at 1 the piece is out. Off, the old timer.
static var by_game := false
static var game_progress := {}


## The piece for night n (1-based) of a run nobody wrote: made up from the
## heist's seed (LootGen), a little slower each night.
static func loot_for(n: int, seed := 0) -> Dictionary:
	var l := LootGen.make(seed, n)
	# Harder locks on a harder night, in half seconds.
	l.seconds = maxf(0.5, snappedf(l.seconds * Sim.tuning("lock"), 0.5))
	return l


## A story night's piece with its words translated.
static func translated(piece: Dictionary) -> Dictionary:
	return Text.fields(piece, TEXT_FIELDS)


## Lay the job out on the museum just generated. The piece: a case in a
## gallery, among the furthest from the entrance. The door: on the outer
## wall, far from the piece and not beside the entrance. Both at random among
## the good candidates, so two museums that look alike do not play alike.
## fixed: what a saved map (MapFile.job) has already decided — "at", the
## case, and "exit", the floor tile before the door.
static func plan_job(n: int, piece: Dictionary = {}, gang: int = 1, fixed: Dictionary = {}) -> void:
	level = n
	# No piece given: one made up from the museum's seed, so the same
	# museum always hides the same thing.
	loot = loot_for(n, Museum.seed_used) if piece.is_empty() else piece.duplicate()
	team = gang >= 2
	hands = 2 if gang >= 3 else 1
	panel2 = Vector2i(-1, -1)
	panel2_by = ""
	short_hand = false
	panel = Vector2i(-1, -1)
	panel_by = ""
	waiting = false
	game_progress.clear()
	start = Museum.spawn
	progress = 0.0
	by = ""
	carrier = ""
	dropped = Vector2.INF
	taken = false
	_last_alarm = 0.0
	var from_start := _distances(start)
	var reach := func(t: Vector2i) -> int: return from_start[t.y * Museum.w + t.x]

	var cases: Array = []
	for t in Museum.cover_tiles:
		# The piece to steal is in a case of its own, never on a big piece.
		if not Museum.big_piece_at(t).is_empty():
			continue
		var stands := _stand_tiles(t).filter(func(s): return reach.call(s) >= 0)
		if stands.is_empty():
			continue
		var d := 1 << 30
		for s in stands:
			d = mini(d, reach.call(s))
		# A gallery piece is worth more than one in a corridor: count it further.
		cases.append([t, d * (1.0 if Museum.room_at(t.x + 0.5, t.y + 0.5) else 0.6)])
	cases.sort_custom(func(a, b): return a[1] > b[1])
	var top := cases.slice(0, maxi(1, ceili(cases.size() / 4.0)))
	at = top[randi() % top.size()][0] if not top.is_empty() else Vector2i.ONE
	at = fixed.get("at", at)

	# The tile you will stand on: the nearest to the entrance.
	var stand := start
	var best := 1 << 30
	for s in _stand_tiles(at):
		var d: int = reach.call(s)
		if d >= 0 and d < best:
			best = d
			stand = s
	var from_loot := _distances(stand)

	# Doors: a floor tile against the outer wall, whatever the building's shape.
	var doors: Array = []
	for t in Museum.open_tiles:
		if Museum.grid[t.y * Museum.w + t.x] != Tiles.FLOOR:
			continue
		var dl := from_loot[t.y * Museum.w + t.x]
		var ds := from_start[t.y * Museum.w + t.x]
		if dl < 0 or ds < 0:
			continue
		# Not the way in: out the same door is not a plan, it is a retreat.
		if ds < 7:
			continue
		for d in Museum.DIRS:
			var wall := t + d
			if Museum.tile_at(wall.x + 0.5, wall.y + 0.5) != Tiles.WALL:
				continue
			if not Museum.is_outside(wall.x + d.x, wall.y + d.y):
				continue
			doors.append([t, d, dl + ds * 0.5])
	doors.sort_custom(func(a, b): return a[2] > b[2])
	var good := doors.slice(0, maxi(1, ceili(doors.size() / 5.0)))
	if fixed.has("exit"):
		exit = fixed.exit
		for d in Museum.DIRS:
			if Museum.is_wall(exit.x + d.x + 0.5, exit.y + d.y + 0.5) and Museum.is_outside(exit.x + d.x * 2, exit.y + d.y * 2):
				exit_face = d
	elif good.is_empty():
		exit = start
		exit_face = Vector2i(-1, 0)
	else:
		var door: Array = good[randi() % good.size()]
		exit = door[0]
		exit_face = door[1]

	if team:
		_place_panel(stand, from_start)
	if team and gang >= 4:
		_place_panel(stand, from_start, true)

	route = _walk(start, stand)
	var out := _walk(stand, exit)
	out.remove_at(0)
	route.append_array(out)
	plan = [
		[Text.t("PLAN_ENTRY"), first_upper(Museum.zone_label(start.x + 0.5, start.y + 0.5))],
		[Text.t("PLAN_PIECE"), first_upper(Museum.zone_label(at.x + 0.5, at.y + 0.5))],
		[Text.t("PLAN_EXIT"), Text.t(_side(exit_face)) % Museum.zone_label(exit.x + 0.5, exit.y + 0.5)],
	]


## The alarm panel: against an inside wall, a fair walk from the case (so
## the one holding it is somewhere else, keeping watch alone) but not across
## the whole museum, and out of the case's gallery.
## second: the other panel of a gang of four, well away from the first.
static func _place_panel(stand: Vector2i, from_start: PackedInt32Array, second := false) -> void:
	var from_case := _distances(stand)
	var case_room := Museum.room_at(at.x + 0.5, at.y + 0.5)
	var far := 0
	for t in Museum.open_tiles:
		far = maxi(far, from_case[t.y * Museum.w + t.x])
	var lo := clampi(far / 4, 6, 12)
	var hi := maxi(lo + 6, far / 2)
	var good: Array = []
	var any: Array = []
	for t in Museum.open_tiles:
		if Museum.grid[t.y * Museum.w + t.x] != Tiles.FLOOR:
			continue
		var d := from_case[t.y * Museum.w + t.x]
		if d < 4 or from_start[t.y * Museum.w + t.x] < 0 or t == exit or t == start:
			continue
		if case_room and Museum.room_at(t.x + 0.5, t.y + 0.5) == case_room:
			continue
		if second and Museum.dist(t.x, t.y, panel.x, panel.y) < 8:
			continue
		for f in Museum.DIRS:
			var wall := t + f
			if Museum.tile_at(wall.x + 0.5, wall.y + 0.5) != Tiles.WALL or Museum.is_outside(wall.x + f.x, wall.y + f.y):
				continue
			any.append([t, f])
			if d >= lo and d <= hi:
				good.append([t, f])
			break
	var pool := good if not good.is_empty() else any
	if pool.is_empty():
		team = false
		return
	var pick: Array = pool[randi() % pool.size()]
	if second:
		panel2 = pick[0]
		panel2_face = pick[1]
		return
	panel = pick[0]
	panel_face = pick[1]


static func at_panel(p: Thief) -> bool:
	return not p.out and Museum.dist(p.x, p.y, panel.x + 0.5, panel.y + 0.5) < PANEL_REACH


static func at_panel2(p: Thief) -> bool:
	return panel2.x >= 0 and not p.out and Museum.dist(p.x, p.y, panel2.x + 0.5, panel2.y + 0.5) < PANEL_REACH


## The alarm is off: its panel held — both of them, for a gang of four.
static func panels_held() -> bool:
	return panel_by != "" and (panel2.x < 0 or (panel2_by != "" and panel2_by != panel_by))


## "el pasillo" -> "El pasillo". GDScript's capitalize() does every word.
static func first_upper(s: String) -> String:
	return s.substr(0, 1).to_upper() + s.substr(1)


## The door's line on the plan, by the wall it is in: a key into Text.
static func _side(face: Vector2i) -> String:
	match face:
		Vector2i(-1, 0): return "PLAN_DOOR_WEST"
		Vector2i(1, 0): return "PLAN_DOOR_EAST"
		Vector2i(0, -1): return "PLAN_DOOR_NORTH"
		_: return "PLAN_DOOR_SOUTH"


## Walking distance from a tile to every floor tile; -1 unreachable.
static func _distances(from: Vector2i) -> PackedInt32Array:
	var w := Museum.w
	var d := PackedInt32Array()
	d.resize(w * Museum.h)
	d.fill(-1)
	d[from.y * w + from.x] = 0
	var queue := PackedInt32Array([from.y * w + from.x])
	var q := 0
	while q < queue.size():
		var cur := queue[q]
		q += 1
		for dd in Museum.DIRS:
			var nx := cur % w + dd.x
			var ny := cur / w + dd.y
			if nx < 0 or ny < 0 or nx >= w or ny >= Museum.h or Museum.grid[ny * w + nx] != Tiles.FLOOR:
				continue
			var k := ny * w + nx
			if d[k] >= 0:
				continue
			d[k] = d[cur] + 1
			queue.append(k)
	return d


## Shortest walk between two floor tiles, both ends included.
static func _walk(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var d := _distances(to)
	var out: Array[Vector2i] = [from]
	var c := from
	if d[c.y * Museum.w + c.x] < 0:
		return out
	while d[c.y * Museum.w + c.x] > 0:
		for dd in Museum.DIRS:
			var n := c + dd
			if n.x < 0 or n.y < 0 or n.x >= Museum.w or n.y >= Museum.h:
				continue
			var v := d[n.y * Museum.w + n.x]
			if v >= 0 and v == d[c.y * Museum.w + c.x] - 1:
				c = n
				break
		out.append(c)
	return out


## The floor tiles beside a case: where you stand to take what is in it.
static func _stand_tiles(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in Museum.DIRS:
		var n := t + d
		if Museum.tile_at(n.x + 0.5, n.y + 0.5) == Tiles.FLOOR:
			out.append(n)
	return out


## Standing still next to the case?
static func at_case(p: Thief) -> bool:
	if p.out or p.moving or p.speed > 0.2:
		return false
	return Museum.dist(p.x, p.y, at.x + 0.5, at.y + 0.5) <= REACH


static func at_door(p: Thief) -> bool:
	return Museum.dist(p.x, p.y, exit.x + 0.5, exit.y + 0.5) < DOOR


## One frame of the job: working the lock (and its alarm), carrying, dropping,
## picking up, leaving. Returns "", "stolen", "dropped", "picked" or "out";
## an alarm going off this frame is appended to noises.
static func step(thieves: Array[Thief], dt: float, now: float, noises: Array[SoundEvent]) -> String:
	# The panel: whoever stands at it holds it.
	panel_by = ""
	panel2_by = ""
	waiting = false
	short_hand = false
	if team:
		for p in thieves:
			if at_panel(p):
				panel_by = p.id
			elif at_panel2(p):
				panel2_by = p.id
	if not taken:
		var worker: Thief = null
		for p in thieves:
			if at_case(p):
				worker = p
				break
		if worker == null:
			progress = 0.0
			by = ""
			_last_alarm = 0.0
			return ""
		# Two thieves: nothing gives until the other one holds the panel,
		# and then it gives without a sound. Alone (the partner caught), it
		# is forced the loud way.
		var partner_in := team and thieves.any(func(p): return p != worker and not p.out)
		if partner_in and (not panels_held() or worker.id in [panel_by, panel2_by]):
			waiting = true
			by = worker.id
			return ""
		# Two locks: nothing gives until a second pair of hands is at the case.
		if partner_in and hands > 1:
			var at_it := thieves.filter(func(p): return at_case(p) and not p.id in [panel_by, panel2_by])
			if at_it.size() < hands:
				short_hand = true
				by = worker.id
				return ""
		var silent := partner_in
		# Forcing the case sets its alarm off, and a guard hears it like any
		# other sound: the job is a race against whoever is in earshot.
		if not silent and Sim.feature("case_alarm") and now - _last_alarm > ALARM_EVERY_MS:
			_last_alarm = now
			noises.append(SoundEvent.make(at.x + 0.5, at.y + 0.5, "alarm"))
		# Swapping who is at it is stepping away.
		if by_game:
			progress = float(game_progress.get(worker.id, 0.0))
		else:
			progress = (progress if worker.id == by else 0.0) + dt / float(loot.seconds)
		by = worker.id
		if progress >= 1.0:
			progress = 1.0
			by = ""
			carrier = worker.id
			taken = true
			return "stolen"
		return ""
	if carrier != "":
		var c: Thief = null
		for p in thieves:
			if p.id == carrier:
				c = p
		# Caught with it, it drops; walked out with it, it is gone for good.
		if c == null or (c.out and not c.safe):
			carrier = ""
			dropped = Vector2(c.x, c.y) if c else Vector2.INF
			return "dropped"
		return "out" if at_door(c) else ""
	if dropped != Vector2.INF:
		for p in thieves:
			if not p.out and Museum.dist(p.x, p.y, dropped.x, dropped.y) < PICK_UP:
				carrier = p.id
				dropped = Vector2.INF
				return "picked"
	return ""


## Where the piece is right now, for the arrow at the edge of the screen.
static func objective() -> Vector2:
	if carrier != "":
		return Vector2(exit.x + 0.5, exit.y + 0.5)
	if dropped != Vector2.INF:
		return dropped
	return Vector2(at.x + 0.5, at.y + 0.5)


## The combination's length for the piece: a quick case a number, a slow
## one three (the piece's seconds stand for how hard its case is).
static func safe_numbers() -> int:
	var sec := float(loot.seconds)
	return 1 if sec <= 2.0 else (2 if sec <= 4.0 else 3)
