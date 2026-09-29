class_name Practice
extends RefCounted
## The band's house as a place to be in (Den) and, in its dojo, to practise:
## no guards, and nothing in it won or kept (no stars, no progress). What the
## dojo shows grows with the story: each thing to try comes into it when the
## job that teaches it is reached (ITEMS).
##
## The mode is still called "practica" (it began as one room), and its plan
## is built here in code, not read from a file: MapFile.list() only reads the
## challenges' folder anyway.

const MODE := "practica"

## What the dojo shows, and from which lesson (Story.LESSONS; the job that
## teaches it, Story.lesson_night, is the first with it): easy to add to. The
## band's furthest job (Story.unlocked, per size of band) opens it. Jobs are
## numbered 1-25: museum (n - 1) / 5 + 1, test (n - 1) % 5 + 1. What comes
## with which lesson, by zone (Den.DOJO_ZONES):
##   guard (museum 1 · test 2)   pasillo     the corridor's scarecrow, at the end of the north arm
##   torch (museum 1 · test 4)   escondites  the scarecrow that sweeps the hiding corner;
##                               AGUANTA ESCONDIDO's three armours
##   games (museum 2 · test 1)   exposicion  the GANZÚA cases; escondites the three
##                               pedestals of EQUILIBRIO and the three of PILLA EL CALCETÍN
##   props (museum 2 · test 3)   patio       the bins and BOLOS's three circles; escondites the
##                               crate and the locker; exposicion the bust and the ESCONDITE cases
##   case_alarm (museum 3 · 1)   laberinto   the first maze scarecrow; exposicion the CABLES cases
##   two (museum 3 · test 3)     laberinto   the second maze scarecrow; exposicion the PULSO cases
##   id       what it is (a key of the docs' and the tests')
##   lesson   the lesson that brings it
##   text     its name in words (a key into Text)
##   zone     where it stands (Den.DOJO_ZONES)
##   hide     tile and furniture (Hideouts.PIECES) to hide in
##   props    things to knock over, {kind, at}
##   scarecrows  a guard's scarecrow with a lantern, {at: its tile, dir: where it
##            looks, in radians on the plan (0 east, PI/2 south)}
##   bench    a kind of test of the bench of cases (BENCH_TESTS): its three cases, one
##            for each difficulty (bench_case)
##   game     one of the dojo's games (DojoGames) and, in `starts`, its three start
##            points, easy, medium and hard, that `via` says how to start: "sock" (a
##            pedestal with a sock on it: the action key takes it), "ring" (a circle
##            on the floor: the action key on it), "plinth" (a pedestal: climb it) or
##            "armour" (a suit of armour: hide in it)
const ITEMS := [
	{"id": "dummy", "lesson": "guard", "zone": "pasillo", "text": "HIDEOUT_ITEM_DUMMY",
		"scarecrows": [{"at": Vector2i(38, 1), "dir": PI / 2}]},
	{"id": "dummy_back", "lesson": "torch", "zone": "escondites", "text": "HIDEOUT_ITEM_DUMMY_BACK",
		"scarecrows": [{"at": Vector2i(57, 3), "dir": PI}]},
	{"id": "game_aguanta", "lesson": "torch", "zone": "escondites", "text": "HIDEOUT_GAME_AGUANTA", "game": "aguanta", "via": "armour",
		"starts": [Vector2i(53, 2), Vector2i(53, 4), Vector2i(53, 6)]},
	{"id": "game_pedestal", "lesson": "games", "zone": "escondites", "text": "HIDEOUT_GAME_PEDESTAL", "game": "pedestal", "via": "plinth",
		"starts": [Vector2i(44, 3), Vector2i(47, 3), Vector2i(50, 3)]},
	{"id": "game_atrapa", "lesson": "games", "zone": "escondites", "text": "HIDEOUT_GAME_ATRAPA", "game": "atrapa", "via": "sock",
		"starts": [Vector2i(47, 1), Vector2i(49, 1), Vector2i(51, 1)]},
	{"id": "bench_lockpick", "lesson": "games", "zone": "exposicion", "text": "HIDEOUT_BENCH_KIND_LOCKPICK", "bench": "lockpick"},
	{"id": "bins", "lesson": "props", "zone": "patio", "text": "HIDEOUT_ITEM_BINS",
		"props": [{"kind": "bin", "at": Vector2i(53, 9)}, {"kind": "bin", "at": Vector2i(56, 12)}]},
	{"id": "bust", "lesson": "props", "zone": "exposicion", "text": "HIDEOUT_ITEM_BUST", "props": [{"kind": "bust", "at": Vector2i(30, 9)}]},
	{"id": "crate", "lesson": "props", "zone": "escondites", "text": "HIDEOUT_ITEM_CRATE", "hide": {"tile": Vector2i(49, 4), "piece": "box"}},
	{"id": "locker", "lesson": "props", "zone": "escondites", "text": "HIDEOUT_ITEM_LOCKER", "hide": {"tile": Vector2i(46, 2), "piece": "fridge"}},
	{"id": "game_bolos", "lesson": "props", "zone": "patio", "text": "HIDEOUT_GAME_BOLOS", "game": "bolos", "via": "ring",
		"starts": [Vector2i(54, 10), Vector2i(56, 10), Vector2i(54, 12)]},
	{"id": "bench_squeeze", "lesson": "props", "zone": "exposicion", "text": "HIDEOUT_BENCH_KIND_SQUEEZE", "bench": "squeeze"},
	{"id": "maze_a", "lesson": "case_alarm", "zone": "laberinto", "text": "HIDEOUT_ITEM_MAZE_A",
		"scarecrows": [{"at": Vector2i(47, 12), "dir": -PI / 2}]},
	{"id": "bench_wires", "lesson": "case_alarm", "zone": "exposicion", "text": "HIDEOUT_BENCH_KIND_WIRES", "bench": "wires"},
	{"id": "maze_b", "lesson": "two", "zone": "laberinto", "text": "HIDEOUT_ITEM_MAZE_B",
		"scarecrows": [{"at": Vector2i(50, 12), "dir": -PI / 2}]},
	{"id": "bench_steady", "lesson": "two", "zone": "exposicion", "text": "HIDEOUT_BENCH_KIND_STEADY", "bench": "steady"},
]


# --- The bench of cases ---------------------------------------------------------------------
## Things to practise on, as often as one likes. Each test (BENCH_TESTS, taught
## by its lesson) has three, one for each difficulty (level 0 easy, 1 medium,
## 2 hard), each test with its own kind of thing (BENCH_OBJECTS; DenView dresses
## it with BenchProps): GANZÚA (`lockpick`) an empty glass case, ESCONDITE
## (`squeeze`) a hideout (a fridge, a box, a chest: tighter each), CABLES
## (`wires`) an alarm box on the wall with 3 to 6 wires by the level, PULSO
## (`steady`) an alarm box on the wall with a glass to hold the suction cup on.
## Where they stand is BENCH_AT. The tests are the same games as in a heist
## (Minigame) at that level. A "case" (the word stays) is `slot` = test * 3 +
## level. Done, it signals (a green light, the glass up, the lever down),
## stays so BENCH_OPEN_S, goes back over BENCH_REARM_S and is armed again.
## Nothing here is a heist: no stars, no progress, no noise, nobody comes, and
## no sock (that is PILLA EL CALCETÍN's).
const BENCH_TESTS := ["lockpick", "squeeze", "wires", "steady"]
## The three tiles of each test, easy to hard: the glass cases and the hideouts
## in a column each, the alarm boxes on a wall each (CABLES the east wall of the
## exposicion, PULSO its west one, between the two doors).
const BENCH_AT := {
	"lockpick": [Vector2i(24, 3), Vector2i(24, 7), Vector2i(24, 11)],
	"squeeze": [Vector2i(27, 3), Vector2i(27, 7), Vector2i(27, 11)],
	"wires": [Vector2i(30, 3), Vector2i(30, 7), Vector2i(30, 11)],
	"steady": [Vector2i(21, 5), Vector2i(21, 7), Vector2i(21, 9)],
}
const BENCH_OPEN_S := 3.5
const BENCH_REARM_S := 0.6
## As close as a heist asks to work a case (Heist.REACH).
const BENCH_REACH := 1.5
## What each test's things are (the one place to change one): `object` is the
## model BenchProps builds; `solid` if it stands on a cover tile (a wall of the
## plan the feet go round) and not on the floor; `wall` the side of the tile it
## is hung on (a step on the plan), none if it stands free; `pieces` (a hideout)
## which of Hideouts.PIECES, by difficulty; `reach` how close to be to it
## (default BENCH_REACH).
const BENCH_OBJECTS := {
	"lockpick": {"object": "vitrine", "solid": true},
	"squeeze": {"object": "hideout", "solid": true, "pieces": ["fridge", "box", "chest"]},
	"wires": {"object": "alarm_wires", "solid": false, "wall": Vector2i(1, 0)},
	"steady": {"object": "alarm_glass", "solid": false, "wall": Vector2i(-1, 0)},
}
## How close to a sock on its pedestal, or to the middle of a circle, to take it.
const SOCK_REACH := 1.3
const RING_REACH := 0.6
## The lantern of AGUANTA ESCONDIDO: the post it stands on (only while the game
## is on), and where its swing is centred (radians on the plan, 0 east).
const LANTERN_AT := Vector2i(52, 3)
const LANTERN_DIR := PI


static func _item(id: String) -> Dictionary:
	for i in ITEMS:
		if i.id == id:
			return i
	return {}


## The bench as it starts: every case closed, none opened.
static func bench_new() -> Dictionary:
	var cases: Array = []
	for i in BENCH_TESTS.size() * 3:
		cases.append({"state": "closed", "t": 0.0})
	return {"opened": 0, "cases": cases}


## Case `slot`: {slot, kind (of BENCH_TESTS), level (0..2), at (its tile)}.
static func bench_case(slot: int) -> Dictionary:
	var k := slot / 3
	var level := slot % 3
	return {"slot": slot, "kind": BENCH_TESTS[k], "level": level, "at": BENCH_AT[BENCH_TESTS[k]][level]}


## The slot of the bench case that stands on a tile, or -1 (whether or not it is open).
static func bench_slot_of(tile: Vector2i) -> int:
	for k in BENCH_TESTS.size():
		var level: int = BENCH_AT[BENCH_TESTS[k]].find(tile)
		if level >= 0:
			return k * 3 + level
	return -1


## The cases there are for a band this size, in slot order: [{slot, kind, level, at}].
static func bench_cases(players := 1) -> Array:
	var out: Array = []
	var kinds := bench_kinds(players)
	for slot in BENCH_TESTS.size() * 3:
		if kinds.has(BENCH_TESTS[slot / 3]):
			out.append(bench_case(slot))
	return out


## The tests taught so far, in the order of BENCH_TESTS.
static func bench_kinds(players := 1) -> Array[String]:
	var out: Array[String] = []
	for i in open_items(players):
		if i.has("bench"):
			out.append(String(i.bench))
	return out


## The name of a test (a key of Text).
static func bench_kind_text(kind: String) -> String:
	for i in ITEMS:
		if i.get("bench", "") == kind:
			return i.text
	return ""


## How close one has to be to a case (BENCH_OBJECTS).
static func bench_reach(c: Dictionary) -> float:
	return float(BENCH_OBJECTS[c.kind].get("reach", BENCH_REACH))


## What a test's things are: an entry of BENCH_OBJECTS.
static func bench_object(kind: String) -> Dictionary:
	return BENCH_OBJECTS[kind]


## The bench case a point is beside (its slot), the nearest within reach, or -1.
static func bench_case_at(pos: Vector2, players := 1) -> int:
	var best := -1
	var best_d := INF
	for c in bench_cases(players):
		var d := pos.distance_to(Vector2(c.at) + Vector2(0.5, 0.5))
		if d <= bench_reach(c) and d < best_d:
			best_d = d
			best = c.slot
	return best


## What the action key does for someone at a point: {what: "case", i: slot} for
## the nearest closed case in reach, or empty for nothing.
static func bench_action(pos: Vector2, state: Dictionary, players := 1) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for c in bench_cases(players):
		if state.cases[c.slot].state != "closed":
			continue
		var d := pos.distance_to(Vector2(c.at) + Vector2(0.5, 0.5))
		if d <= bench_reach(c) and d < best_d:
			best_d = d
			best = {"what": "case", "i": c.slot}
	return best


## The game a test is: the same Minigame as in a heist, at the difficulty of
## the case; input is the keys held. The hideout's fit (SqueezeGame's `steps`)
## is the tightness of its piece (Hideouts.TIGHT).
static func bench_game(kind: String, level: int, input: Dictionary) -> Minigame:
	var steps: int = {"lockpick": 1 + level, "squeeze": Hideouts.TIGHT.get(bench_piece(level), 0), "wires": 3, "steady": 4 + level * 2}.get(kind, 2)
	return Minigame.make(kind, "bench", steps, input, 0, level)


## The piece of furniture (Hideouts.PIECES) of the ESCONDITE case of a level.
static func bench_piece(level: int) -> String:
	return BENCH_OBJECTS.squeeze.pieces[level]


## Case i is done: it signals, and the count goes up.
static func bench_open(state: Dictionary, i: int) -> void:
	state.cases[i].state = "open"
	state.cases[i].t = 0.0
	state.opened = int(state.opened) + 1


## Time passes on the bench: an open case closes, then arms again.
static func bench_step(state: Dictionary, dt: float) -> void:
	for c in state.cases:
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


# --- The games' start points ----------------------------------------------------------------

## The start points of the games the band has got to: [{game, tier (0..2), at
## (tile), via, text (the game's name)}], game by game and easy to hard.
static func game_starts(players := 1) -> Array:
	var out: Array = []
	for i in open_items(players):
		if i.has("game"):
			for t in 3:
				out.append({"game": i.game, "tier": t, "at": i.starts[t], "via": i.via, "text": i.text})
	return out


## The start point one presses the action key at (a sock on its pedestal, a
## circle): {id, tier} of the game it starts, or empty. The nearest within reach.
static func game_at(pos: Vector2, players := 1) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for s in game_starts(players):
		var reach := SOCK_REACH if s.via == "sock" else (RING_REACH if s.via == "ring" else 0.0)
		var d := pos.distance_to(Vector2(s.at) + Vector2(0.5, 0.5))
		if d <= reach and d < best_d:
			best_d = d
			best = {"id": s.game, "tier": s.tier}
	return best


## The tile of a game's start point at a difficulty (0..2).
static func start_of(game: String, tier: int, _players := 1) -> Vector2i:
	return _item("game_" + game).starts[clampi(tier, 0, 2)]


## The difficulty (0..2) of the start point of a game at a tile, or -1 if none is.
static func start_tier(game: String, tile: Vector2i, players := 1) -> int:
	for s in game_starts(players):
		if s.game == game and s.at == tile:
			return s.tier
	return -1


## The tiles of the hideouts the band has got to: the crate and the locker, and
## the armours of AGUANTA ESCONDIDO.
static func hide_tiles(players := 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in open_items(players):
		if i.has("hide"):
			out.append(i.hide.tile)
		elif i.get("via", "") == "armour":
			for t in i.starts:
				out.append(t)
	return out


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
## (the round dresses them, see Main._build_world).
static func map(players := 1) -> MapFile:
	var items := open_items(players)
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
	for i in items:
		# What stands (not marked on the floor or hung on a wall) is cover to go round.
		if i.has("bench") and BENCH_OBJECTS[i.bench].solid:
			for level in 3:
				cover.append(bench_case(BENCH_TESTS.find(i.bench) * 3 + level).at)
		if i.has("game"):
			match i.via:
				"sock":
					for t in i.starts:
						cover.append(t)
				"plinth":
					for t in i.starts:
						cover.append(t)
						m.exhibits[t] = "plinth"
				"armour":
					for t in i.starts:
						m.props.append({"kind": "armour", "at": t})
		if i.has("hide"):
			cover.append(i.hide.tile)
			m.exhibits[i.hide.tile] = i.hide.piece
		for p in i.get("props", []):
			m.props.append(p.duplicate())
		for sc in i.get("scarecrows", []):
			cover.append(sc.at)
	var rows := Den.rows(cover)
	m._resize_plan(Den.W, Den.H)
	for y in Den.H:
		for x in Den.W:
			var c := rows[y][x]
			m.grid[y * Den.W + x] = Tiles.FLOOR if c == "." else (Tiles.COVER if c == "o" else Tiles.WALL)
	return m


## The dojo's settings, for Sim.custom: no guards, no case to rob, and
## everything else on for the feet to try (the bombs, the pick, the props,
## the places to hide are the dojo's, whatever it shows).
static func tuning() -> Dictionary:
	return {"guards": 0, "case": false, "case_alarm": false, "props": false, "lights": false, "lockpick": true,
		"plinths": false, "hideouts": false, "theme": "", "lock": 1.0, "game_level": 0}
