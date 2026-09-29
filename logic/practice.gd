class_name Practice
extends RefCounted
## The band's house as a place to be in (Den) and, in its dojo, to practise:
## no guards, a case that will not open, and nothing in it won or kept (no
## stars, no progress). What the dojo shows grows with the story: each thing
## to try comes into it when the night that teaches it is reached (ITEMS).
##
## The mode is still called "practica" (it began as one room), and its plan
## is built here in code, not read from a file: MapFile.list() only reads the
## challenges' folder anyway.

const MODE := "practica"

## What the dojo shows, and from which lesson (Story.LESSONS; the night that
## teaches it, Story.lesson_night, is the first with it): easy to add to. The
## band's furthest night (Story.unlocked, per size of band) opens it. What
## comes with which night, by zone (Den.DOJO_ZONES):
##   night 1 (heist)      exposicion  the sealed case
##   night 2 (guard)      pasillo     the corridor's scarecrow, at the end of the north arm
##   night 4 (torch)      escondites  the scarecrow that sweeps the hiding corner
##   night 6 (games)      exposicion  the pedestal; the bench's two lecterns (which test,
##                        how hard) and the lock pick as a test
##   night 8 (props)      ... the squeeze as a test (BENCH_KINDS)
##   night 11 (case_alarm) ... the cutters (wires) as a test
##   night 13 (two)       exposicion  the second case with its alarm panel; the
##                        suction cup (steady) as a test
##   night 8 (props)      patio       the bins; escondites the armours, the crate
##                        and the locker; exposicion the bust
##   night 11 (case_alarm) laberinto  the first maze scarecrow
##   night 13 (two)       laberinto   the second maze scarecrow
##   id       what it is (a key of the docs' and the tests')
##   lesson   the lesson that brings it
##   text     its name in words (a key into Text)
##   zone     where it stands (Den.DOJO_ZONES)
##   cover    tiles it stands on (they block the way)
##   plinth   a tile that is an empty pedestal to pose on (minigame "balance")
##   hide     tile and furniture (Hideouts.PIECES) to hide in
##   props    things to knock over, {kind, at}
##   scarecrows  a guard's scarecrow with a lantern, {at: its tile, dir: where it
##            looks, in radians on the plan (0 east, PI/2 south)}
##   case     the sealed case with the practice sock
##   game     a sign post (`sign`, a tile that blocks the way) where the dojo's game
##            of that id (DojoGames) is started
const ITEMS := [
	{"id": "case", "lesson": "heist", "zone": "exposicion", "text": "HIDEOUT_ITEM_CASE", "case": Vector2i(27, 6)},
	{"id": "dummy", "lesson": "guard", "zone": "pasillo", "text": "HIDEOUT_ITEM_DUMMY",
		"scarecrows": [{"at": Vector2i(38, 1), "dir": PI / 2}]},
	{"id": "dummy_back", "lesson": "torch", "zone": "escondites", "text": "HIDEOUT_ITEM_DUMMY_BACK",
		"scarecrows": [{"at": Vector2i(57, 3), "dir": PI}]},
	{"id": "pedestal", "lesson": "games", "zone": "exposicion", "text": "HIDEOUT_ITEM_PEDESTAL", "plinth": Vector2i(23, 4)},
	{"id": "bins", "lesson": "props", "zone": "patio", "text": "HIDEOUT_ITEM_BINS",
		"props": [{"kind": "bin", "at": Vector2i(53, 9)}, {"kind": "bin", "at": Vector2i(56, 12)}]},
	{"id": "armour", "lesson": "props", "zone": "escondites", "text": "HIDEOUT_ITEM_ARMOUR",
		"props": [{"kind": "armour", "at": Vector2i(53, 2)}, {"kind": "armour", "at": Vector2i(53, 5)}]},
	{"id": "bust", "lesson": "props", "zone": "exposicion", "text": "HIDEOUT_ITEM_BUST", "props": [{"kind": "bust", "at": Vector2i(30, 11)}]},
	{"id": "crate", "lesson": "props", "zone": "escondites", "text": "HIDEOUT_ITEM_CRATE", "hide": {"tile": Vector2i(49, 4), "piece": "box"}},
	{"id": "locker", "lesson": "props", "zone": "escondites", "text": "HIDEOUT_ITEM_LOCKER", "hide": {"tile": Vector2i(46, 2), "piece": "fridge"}},
	{"id": "bench_kinds", "lesson": "games", "zone": "exposicion", "text": "HIDEOUT_ITEM_BENCH",
		"cover": [Vector2i(27, 2), Vector2i(29, 2)]},
	{"id": "bench_alarm", "lesson": "two", "zone": "exposicion", "text": "HIDEOUT_ITEM_BENCH_ALARM",
		"cover": [Vector2i(29, 6)]},
	{"id": "maze_a", "lesson": "case_alarm", "zone": "laberinto", "text": "HIDEOUT_ITEM_MAZE_A",
		"scarecrows": [{"at": Vector2i(47, 12), "dir": -PI / 2}]},
	{"id": "maze_b", "lesson": "two", "zone": "laberinto", "text": "HIDEOUT_ITEM_MAZE_B",
		"scarecrows": [{"at": Vector2i(50, 12), "dir": -PI / 2}]},
	# The sign posts of the dojo's games (DojoGames). AGUANTA ESCONDIDO brings its
	# own box to hide in (the crate and the locker come later, with the props).
	{"id": "game_atrapa", "lesson": "games", "zone": "exposicion", "text": "HIDEOUT_GAME_ATRAPA", "game": "atrapa", "sign": Vector2i(22, 12)},
	{"id": "game_pedestal", "lesson": "games", "zone": "exposicion", "text": "HIDEOUT_GAME_PEDESTAL", "game": "pedestal", "sign": Vector2i(24, 2)},
	{"id": "game_bolos", "lesson": "props", "zone": "patio", "text": "HIDEOUT_GAME_BOLOS", "game": "bolos", "sign": Vector2i(52, 13)},
	{"id": "game_aguanta", "lesson": "torch", "zone": "escondites", "text": "HIDEOUT_GAME_AGUANTA", "game": "aguanta", "sign": Vector2i(44, 5),
		"hide": {"tile": Vector2i(47, 5), "piece": "box"}},
]


# --- The bench of cases ---------------------------------------------------------------------
## Cases to practise opening, as often as one likes: the sealed case of the
## first lesson (Den.CASE_AT) is the first, and with the lesson on the alarm
## panel a second one, that will not give while its panel is armed. Each test
## is a way of opening (the same games as a heist, Minigame), taught by its
## lesson; two lecterns pick which and how hard (level 0 easy .. 2 hard).
## Opened, a case shows the sock, stays open BENCH_OPEN_S, closes over
## BENCH_REARM_S and is armed again. Nothing here is a heist: no stars, no
## progress, no noise, nobody comes.
const BENCH_KINDS := [
	{"id": "hold", "lesson": "heist", "text": "HIDEOUT_BENCH_KIND_HOLD"},
	{"id": "lockpick", "lesson": "games", "text": "HIDEOUT_BENCH_KIND_LOCKPICK"},
	{"id": "squeeze", "lesson": "props", "text": "HIDEOUT_BENCH_KIND_SQUEEZE"},
	{"id": "wires", "lesson": "case_alarm", "text": "HIDEOUT_BENCH_KIND_WIRES"},
	{"id": "steady", "lesson": "two", "text": "HIDEOUT_BENCH_KIND_STEADY"},
]
## Standing still by the case this long opens it (the first test).
const BENCH_HOLD_S := 3.0
const BENCH_OPEN_S := 3.5
const BENCH_REARM_S := 0.6
## As close as a heist asks to work a case (Heist.REACH).
const BENCH_REACH := 1.5
const BENCH_ALARM_CASE := Vector2i(29, 6)
## The alarm case's panel: on the north wall, and how close to work it.
const BENCH_PANEL := Vector2(30.5, 1.5)
const BENCH_PANEL_REACH := 1.1
## The lecterns: which test, and how hard.
const BENCH_LECTERN_KIND := Vector2i(27, 2)
const BENCH_LECTERN_LEVEL := Vector2i(29, 2)
const BENCH_LECTERN_REACH := 1.3
## How close to a game's sign post to start it.
const SIGN_REACH := 1.3
## The lantern of AGUANTA ESCONDIDO: the post it stands on (only while the game
## is on), and where its swing is centred (radians on the plan, 0 east).
const LANTERN_AT := Vector2i(52, 3)
const LANTERN_DIR := PI


static func _item(id: String) -> Dictionary:
	for i in ITEMS:
		if i.id == id:
			return i
	return {}


## The bench as it starts: the first test, the easy level, none opened.
static func bench_new() -> Dictionary:
	return {"kind": "hold", "level": 0, "opened": 0, "panel_off": false,
		"cases": [{"state": "closed", "t": 0.0}, {"state": "closed", "t": 0.0}]}


## The cases there are for a band this size: [{at, alarm}].
static func bench_cases(players := 1) -> Array:
	var out: Array = [{"at": Den.CASE_AT, "alarm": false}]
	if is_open(_item("bench_alarm"), players):
		out.append({"at": BENCH_ALARM_CASE, "alarm": true})
	return out


## Whether the lecterns are up (the tests to pick from come with the pick).
static func bench_lecterns(players := 1) -> bool:
	return is_open(_item("bench_kinds"), players)


## The tests taught so far, in the order the lectern goes through them.
static func bench_kinds(players := 1) -> Array[String]:
	var out: Array[String] = []
	var reach := reached(players)
	for k in BENCH_KINDS:
		if reach >= maxi(1, Story.lesson_night(k.lesson)):
			out.append(String(k.id))
	return out


## The lectern's next test (or the first one, if the one picked is not taught).
static func bench_cycle_kind(state: Dictionary, players := 1) -> void:
	var kinds := bench_kinds(players)
	var at := kinds.find(state.kind)
	state.kind = kinds[(at + 1) % kinds.size()] if at >= 0 else kinds[0]


static func bench_cycle_level(state: Dictionary) -> void:
	state.level = (int(state.level) + 1) % 3


## The name of a test (a key of Text).
static func bench_kind_text(id: String) -> String:
	for k in BENCH_KINDS:
		if k.id == id:
			return k.text
	return ""


## The bench case a point is beside (its index into bench_cases), the nearest
## within reach, or -1.
static func bench_case_at(pos: Vector2, players := 1) -> int:
	var best := -1
	var best_d := BENCH_REACH
	var cases := bench_cases(players)
	for i in cases.size():
		var c: Vector2i = cases[i].at
		var d := pos.distance_to(Vector2(c) + Vector2(0.5, 0.5))
		if d <= best_d:
			best_d = d
			best = i
	return best


## What the action key does for someone at a point: {what: "case" (i) |
## "need_panel" (the alarm case is still armed) | "panel" | "kind" | "level"},
## or empty for nothing. The nearest of them.
static func bench_action(pos: Vector2, state: Dictionary, players := 1) -> Dictionary:
	# Every thing to do in reach: [distance, what].
	var found: Array = []
	var cases := bench_cases(players)
	for i in cases.size():
		var c: Vector2i = cases[i].at
		if state.cases[i].state != "closed":
			continue
		var armed: bool = cases[i].alarm and not state.panel_off
		found.append([pos.distance_to(Vector2(c) + Vector2(0.5, 0.5)) - BENCH_REACH,
			{"what": "need_panel" if armed else "case", "i": i}])
	if cases.size() > 1 and not state.panel_off and state.cases[1].state == "closed":
		found.append([pos.distance_to(BENCH_PANEL) - BENCH_PANEL_REACH, {"what": "panel"}])
	if bench_lecterns(players):
		found.append([pos.distance_to(Vector2(BENCH_LECTERN_KIND) + Vector2(0.5, 0.5)) - BENCH_LECTERN_REACH, {"what": "kind"}])
		found.append([pos.distance_to(Vector2(BENCH_LECTERN_LEVEL) + Vector2(0.5, 0.5)) - BENCH_LECTERN_REACH, {"what": "level"}])
	# (Negative: in reach; the one deepest in it wins.)
	var best: Dictionary = {}
	var best_d := 0.0
	for f in found:
		if f[0] <= 0.0 and (best.is_empty() or f[0] < best_d):
			best_d = f[0]
			best = f[1]
	return best


## The game a test is (null for the first, standing still): the same
## Minigame as in a heist, at the level picked; input is the keys held.
static func bench_game(kind: String, level: int, input: Dictionary) -> Minigame:
	if kind == "hold":
		return null
	var steps: int = {"lockpick": 1 + level, "squeeze": 0, "wires": 3, "steady": 4 + level * 2}.get(kind, 2)
	return Minigame.make(kind, "bench", steps, input, 0, level)


## Case i is opened: the sock shows, and the count goes up.
static func bench_open(state: Dictionary, i: int) -> void:
	state.cases[i].state = "open"
	state.cases[i].t = 0.0
	state.opened = int(state.opened) + 1


## Time passes on the bench: an open case closes, then arms again (and with
## the alarm case, its panel).
static func bench_step(state: Dictionary, dt: float) -> void:
	for i in state.cases.size():
		var c: Dictionary = state.cases[i]
		if c.state == "open":
			c.t = float(c.t) + dt
			if c.t >= BENCH_OPEN_S:
				c.state = "rearming"
				c.t = 0.0
		elif c.state == "rearming":
			c.t = float(c.t) + dt
			if c.t >= BENCH_REARM_S:
				c.state = "closed"
				c.t = 0.0
				if i == 1:
					state.panel_off = false


## Standing still by a case, second by second: the progress (seconds) after
## dt, back to 0 the moment the thief moves off or stirs.
static func bench_hold_step(held: float, still_at_case: bool, dt: float) -> float:
	return held + dt if still_at_case else 0.0

# --- The scarecrows -------------------------------------------------------------------
## A guard's scarecrow: a coat on a cross with a torch taped to it. It stands
## still and sees like a guard, only less far and less wide: within
## SCARECROW_RANGE tiles of its torch, SCARECROW_ANGLE either side of where it
## looks, with nothing in the way (walls, furniture, shut doors, smoke), and not
## a thief hiding or posing as a statue.
const SCARECROW_RANGE := 5.5
const SCARECROW_ANGLE := 0.42
## Its torch is this far in front of the post (outside the tile it takes).
const SCARECROW_TORCH := 0.55
## Seen, the dojo goes red with an alarm for ALERT_S seconds, and cannot
## again for ALERT_COOLDOWN_S more, whoever is still in sight.
const ALERT_S := 3.0
const ALERT_COOLDOWN_S := 1.5


## The scarecrows the band of this size has got to: [{id, at, dir}].
static func scarecrows(players := 1) -> Array:
	var out: Array = []
	for i in open_items(players):
		for s in i.get("scarecrows", []):
			out.append({"id": i.id, "at": s.at, "dir": s.dir})
	return out


## Where a scarecrow's torch is, in tiles.
static func scarecrow_torch(sc: Dictionary) -> Vector2:
	var at: Vector2i = sc.at
	return Vector2(at) + Vector2(0.5, 0.5) + Vector2.from_angle(sc.dir) * SCARECROW_TORCH


## Whether the scarecrow sees a thief at a spot (tiles): the guard's rule
## (Sim.can_see) with its own numbers. hidden: in a hideout or posing on a
## pedestal; low: down on all fours (cases are waist-high). los: an optional
## line-of-sight check (from, to, low) -> bool, the plan's by default.
static func scarecrow_sees(sc: Dictionary, pos: Vector2, hidden: bool, low := false, los := Callable()) -> bool:
	if hidden:
		return false
	var from := scarecrow_torch(sc)
	var d := from.distance_to(pos)
	if d > SCARECROW_RANGE:
		return false
	if d > 0.3 and absf(wrapf((pos - from).angle() - float(sc.dir), -PI, PI)) > SCARECROW_ANGLE:
		return false
	if los.is_valid():
		return bool(los.call(from, pos, low))
	if Smoke.blocks(from.x, from.y, pos.x, pos.y, Sim.now_ms()):
		return false
	return Museum.has_line_of_sight(from.x, from.y, pos.x, pos.y, low)


## The sign posts of the games the band has got to: [{id (of the game), at (tile)}].
static func game_signs(players := 1) -> Array:
	var out: Array = []
	for i in open_items(players):
		if i.has("game"):
			out.append({"id": i.game, "at": i.sign, "text": i.text})
	return out


## The sign post a point is beside (within SIGN_REACH of its middle): its
## game's id, or "".
static func game_at(pos: Vector2, players := 1) -> String:
	var best := ""
	var best_d := SIGN_REACH
	for s in game_signs(players):
		var d := pos.distance_to(Vector2(s.at) + Vector2(0.5, 0.5))
		if d <= best_d:
			best_d = d
			best = s.id
	return best


## The tiles of the hideouts (`hide`) the band has got to.
static func hide_tiles(players := 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in open_items(players):
		if i.has("hide"):
			out.append(i.hide.tile)
	return out


## ... and of the pedestals (`plinth`).
static func plinth_tiles(players := 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in open_items(players):
		if i.has("plinth"):
			out.append(i.plinth)
	return out


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

## Not yet: a bench for the lock pick (the case opening on the pick and giving
## the sock back), the alarm panel (lesson "two"), the light switches
## (lesson "lights"), the big pieces (lesson "big"). Each would be one more
## line in ITEMS once the round can take it.

static var _cache := {}


## The night the band has got to (each size of band has its own).
static func reached(players := 1) -> int:
	return Story.unlocked(players)


## The night an item comes with.
static func item_night(item: Dictionary) -> int:
	return maxi(1, Story.lesson_night(item.lesson))


## Whether the band of this size has got as far as an item.
static func is_open(item: Dictionary, players := 1) -> bool:
	return reached(players) >= item_night(item)


## The items the dojo shows for a band this size, in order.
static func open_items(players := 1) -> Array:
	return ITEMS.filter(func(i: Dictionary) -> bool: return is_open(i, players))


## The house as a map for a band of this size: the plan, the dojo's things
## that are open, the way in and the door. The case's tile is always the
## sock's, and the scarecrows (scarecrows) stand on cover tiles of their own
## (the round dresses them, see Main._build_world).
static func map(players := 1) -> MapFile:
	var items := open_items(players)
	var cover: Array[Vector2i] = []
	var m := MapFile.new()
	m.name = Text.t("HIDEOUT_NAME")
	m.seed = 4242
	m.difficulty = "easy"
	m.loot = {"shape": "sock", "colour": "#e2262f", "name": Text.t("HIDEOUT_SOCK"), "blurb": Text.t("HIDEOUT_SOCK_BLURB"),
		"story": "", "seconds": 3.0}
	m.spawn = Den.SPAWN
	m.exit = Den.EXIT
	m.piece = Den.CASE_AT
	for i in items:
		if i.has("case"):
			cover.append(i.case)
		if i.has("plinth"):
			cover.append(i.plinth)
			m.exhibits[i.plinth] = "plinth"
		if i.has("sign"):
			cover.append(i.sign)
		if i.has("hide"):
			cover.append(i.hide.tile)
			m.exhibits[i.hide.tile] = i.hide.piece
		for p in i.get("props", []):
			m.props.append(p.duplicate())
		for sc in i.get("scarecrows", []):
			cover.append(sc.at)
		for c in i.get("cover", []):
			cover.append(c)
	var rows := Den.rows(cover)
	m._resize_plan(Den.W, Den.H)
	for y in Den.H:
		for x in Den.W:
			var c := rows[y][x]
			m.grid[y * Den.W + x] = Tiles.FLOOR if c == "." else (Tiles.COVER if c == "o" else Tiles.WALL)
	return m


## The night's settings, for Sim.custom: no guards, the case sealed, and
## everything else on for the feet to try (the bombs, the pick, the props,
## the places to hide are the dojo's, whatever it shows).
static func tuning() -> Dictionary:
	return {"guards": 0, "case": false, "case_alarm": false, "props": false, "lights": false, "lockpick": true,
		"plinths": false, "hideouts": false, "theme": "", "lock": 1.0, "game_level": 0}
