class_name DojoTrials
extends RefCounted
## The dojo's trials: THE list of them (TABLE), how to make one, and the best mark
## of each at each difficulty for each size of band, kept in the progress beside
## the story's, section [dojo]. Adding a trial to the dojo is a row here, its logic
## (a DojoTrial) and its object (the `via`): nothing else has to know (README,
## «Cómo añadir una prueba al dojo»).
##
##   atrapa    PILLA EL CALCETÍN  (CatchGame)       game    a sock on a pedestal
##   pedestal  EQUILIBRIO         (PedestalGame)    game    a pedestal to climb
##   bolos     BOLOS              (BowlingGame)     game    a circle on the floor
##   aguanta   AGUANTA ESCONDIDO  (HideGame)        game    an armour to hide in
##   lockpick  GANZÚA             (BenchTrial)      bench   a glass case
##   squeeze   ESCONDITE          (BenchTrial)      bench   a piece of furniture
##   wires     CABLES             (BenchTrial)      bench   an alarm box on the wall
##   steady    PULSO              (BenchTrial)      bench   an alarm box with a glass
##   circuit   CIRCUITO           (CircuitTrial)    circuit a ring at the stealth circuit
## (TABLE is a static var: a const cannot hold the classes.) Every row:
##   id        what the tests, the docs and the progress call it
##   kind      "game" (rounds, record: the level), "bench" (one attempt at a minigame of
##             a heist, record: the time) or "circuit" (record: the time)
##   cls       its DojoTrial
##   name      its name in words (a key of Text), and `start_text` what the action key
##             says at its start point («COGER EL CALCETÍN (FÁCIL)»; "" when it is not
##             started with the action key)
##   hint      what the "¿LISTOS?" says under it (a key of Text)
##   lesson    the lesson (Story.LESSONS) whose job brings it: with it, its three start
##             points, one for each of the TIERS
##   zone      where it lives (Den.DOJO_ZONES, a zone of its own)
##   via       what its start point is (Practice.VIAS): "sock", "ring", "plinth",
##             "armour", "vitrine", "hideout", "alarm_wires", "alarm_glass"
##   starts    the tile of each of the three start points, easy to hard
##   wall      (a wall box) the side of its tile the wall is at
##   goal      (circuit) the tile to get to, `speed` how much faster the scarecrows sweep at each
##             difficulty, `limit` the seconds, `scarecrows` the guards' coats that sweep
##             their torch: {at, dir (the middle of the sweep), turn: {amp, speed, phase}}
##   minigame  (bench) the Minigame it is, `steps` how many steps at each difficulty
##             and `limit` the seconds it may take (over them it is lost)
## The difficulties are the same for all: DojoTrials.TIERS.

const SECTION := "dojo"
const MAX_LEVEL := 99
## Whether a trial is done by one thief alone, the rest of the band standing
## by (PARTY_SOLO: the same trial whatever the band's size, nothing exclusive,
## no marks to fuse between sizes of band) or by several at once, really
## together (PARTY_GROUP: its score depends on how many play, and it may only
## exist for one size of band). Every row of TABLE says which (`party`); the
## nine here are all PARTY_SOLO (PILLA EL CALCETÍN, EQUILIBRIO, BOLOS, AGUANTA
## ESCONDIDO, GANZÚA, ESCONDITE, CABLES, PULSO, CIRCUITO: one at a time at its
## pedestal, vitrine, bench or ring, the kind of game or minigame it is does
## not change with the band). A PARTY_GROUP trial, when there is one, lives in
## the dojo's wings (Den.ROOMS "dojo2".."dojo4", DOORS "min_players") and
## fixes a number or a range of thieves of its own — propuesta_progreso_por_banda.md.
const PARTY_SOLO := "solo"
const PARTY_GROUP := "group"
## The difficulties. A game begun at one starts at `from` and is won by doing `to`
## (the ten levels of the games); the other trials read the index. `color` is the
## difficulty's own colour, the same in the nine bays' pedestals, vitrines and
## circles, on their boards and on the trial's result panel (green, orange, red):
## one code, everywhere a difficulty is picked or shown.
const TIERS := [
	{"id": "easy", "from": 1, "to": 3, "text": "HIDEOUT_TIER_EASY", "color": Color("#3f8f4f")},
	{"id": "medium", "from": 4, "to": 6, "text": "HIDEOUT_TIER_MEDIUM", "color": Color("#e0a030")},
	{"id": "hard", "from": 7, "to": 10, "text": "HIDEOUT_TIER_HARD", "color": Color("#c1272d")},
]
static var TABLE: Array = [
	{"id": "atrapa", "kind": "game", "party": PARTY_SOLO, "cls": CatchGame, "name": "HIDEOUT_TRIAL_NAME_ATRAPA", "start_text": "HIDEOUT_TRIAL_START_ATRAPA",
		"hint": "HIDEOUT_TRIAL_HINT_ATRAPA", "lesson": "games", "zone": "atrapa", "via": "sock",
		"starts": [Vector2i(24, 15), Vector2i(27, 15), Vector2i(30, 15)]},
	{"id": "pedestal", "kind": "game", "party": PARTY_SOLO, "cls": PedestalGame, "name": "HIDEOUT_TRIAL_NAME_PEDESTAL", "start_text": "",
		"hint": "HIDEOUT_TRIAL_HINT_PEDESTAL", "lesson": "games", "zone": "pedestal", "via": "plinth",
		"starts": [Vector2i(38, 15), Vector2i(41, 15), Vector2i(44, 15)]},
	{"id": "bolos", "kind": "game", "party": PARTY_SOLO, "cls": BowlingGame, "name": "HIDEOUT_TRIAL_NAME_BOLOS", "start_text": "HIDEOUT_TRIAL_START_BOLOS",
		"hint": "HIDEOUT_TRIAL_HINT_BOLOS", "lesson": "props", "zone": "bolos", "via": "ring",
		"starts": [Vector2i(52, 14), Vector2i(55, 14), Vector2i(58, 14)]},
	{"id": "aguanta", "kind": "game", "party": PARTY_SOLO, "cls": HideGame, "name": "HIDEOUT_TRIAL_NAME_AGUANTA", "start_text": "",
		"hint": "HIDEOUT_TRIAL_HINT_AGUANTA", "lesson": "torch", "zone": "aguanta", "via": "armour",
		"starts": [Vector2i(59, 21), Vector2i(59, 23), Vector2i(59, 25)]},
	{"id": "lockpick", "kind": "bench", "party": PARTY_SOLO, "cls": BenchTrial, "name": "HIDEOUT_TRIAL_NAME_LOCKPICK", "start_text": "HIDEOUT_TRIAL_START_LOCKPICK",
		"hint": "HIDEOUT_TRIAL_HINT_LOCKPICK", "lesson": "games", "zone": "lockpick", "via": "vitrine",
		"starts": [Vector2i(24, 5), Vector2i(27, 5), Vector2i(30, 5)],
		"minigame": "lockpick", "steps": [1, 2, 3], "limit": [30.0, 40.0, 50.0]},
	{"id": "squeeze", "kind": "bench", "party": PARTY_SOLO, "cls": BenchTrial, "name": "HIDEOUT_TRIAL_NAME_SQUEEZE", "start_text": "HIDEOUT_TRIAL_START_SQUEEZE",
		"hint": "HIDEOUT_TRIAL_HINT_SQUEEZE", "lesson": "props", "zone": "squeeze", "via": "hideout",
		"starts": [Vector2i(38, 23), Vector2i(41, 23), Vector2i(44, 23)], "pieces": ["fridge", "box", "chest"],
		"minigame": "squeeze", "steps": [0, 0, 0], "limit": [30.0, 40.0, 50.0]},
	{"id": "wires", "kind": "bench", "party": PARTY_SOLO, "cls": BenchTrial, "name": "HIDEOUT_TRIAL_NAME_WIRES", "start_text": "HIDEOUT_TRIAL_START_WIRES",
		"hint": "HIDEOUT_TRIAL_HINT_WIRES", "lesson": "case_alarm", "zone": "wires", "via": "alarm_wires",
		"starts": [Vector2i(37, 1), Vector2i(41, 1), Vector2i(45, 1)], "wall": Vector2i(0, -1),
		"minigame": "wires", "steps": [3, 3, 3], "limit": [30.0, 40.0, 50.0]},
	{"id": "steady", "kind": "bench", "party": PARTY_SOLO, "cls": BenchTrial, "name": "HIDEOUT_TRIAL_NAME_STEADY", "start_text": "HIDEOUT_TRIAL_START_STEADY",
		"hint": "HIDEOUT_TRIAL_HINT_STEADY", "lesson": "two", "zone": "steady", "via": "alarm_glass",
		"starts": [Vector2i(51, 1), Vector2i(55, 1), Vector2i(59, 1)], "wall": Vector2i(0, -1),
		"minigame": "steady", "steps": [4, 6, 8], "limit": [30.0, 40.0, 50.0]},
	{"id": "circuit", "kind": "circuit", "party": PARTY_SOLO, "cls": CircuitTrial, "name": "HIDEOUT_TRIAL_NAME_CIRCUIT", "start_text": "HIDEOUT_TRIAL_START_CIRCUIT",
		"hint": "HIDEOUT_TRIAL_HINT_CIRCUIT", "lesson": "guard", "zone": "circuit", "via": "ring",
		"starts": [Vector2i(21, 20), Vector2i(23, 20), Vector2i(25, 20)], "goal": Vector2i(33, 27),
		"speed": [0.7, 1.0, 1.4], "limit": [90.0, 75.0, 60.0],
		"scarecrows": [
			{"at": Vector2i(33, 19), "dir": PI, "turn": {"amp": 0.8, "speed": 0.9, "phase": 0.0}},
			{"at": Vector2i(21, 23), "dir": 0.0, "turn": {"amp": 0.7, "speed": 1.1, "phase": 1.5}},
			{"at": Vector2i(31, 28), "dir": PI, "turn": {"amp": 0.8, "speed": 1.0, "phase": 0.7}},
		]},
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for g in TABLE:
		out.append(String(g.id))
	return out


static func info(id: String) -> Dictionary:
	for g in TABLE:
		if g.id == id:
			return g
	return {}


## The rows of a kind, in TABLE order.
static func of_kind(kind: String) -> Array:
	return TABLE.filter(func(g: Dictionary) -> bool: return g.kind == kind)


## The row whose start point is of this kind of object (`via`), in TABLE order.
static func by_via(via: String) -> Array:
	return TABLE.filter(func(g: Dictionary) -> bool: return g.via == via)


## Whether a trial is PARTY_GROUP (several thieves together, the rest of the
## band not just stood by): false for an id there is not, and for every
## trial today (PARTY_SOLO).
static func is_group(id: String) -> bool:
	return info(id).get("party", PARTY_SOLO) == PARTY_GROUP


## A trial, not begun (start() begins it): for a band of `players` thieves, its dice
## from `seed_`, on the dojo's `field`, at difficulty `tier` (an index into TIERS), the
## first thing placed from `start` (the tile of its start point). Null for an id there
## is not.
static func make(id: String, players: int, seed_: int, field: DojoField, start: Vector2i, tier := 0) -> DojoTrial:
	var g := info(id)
	if g.is_empty():
		return null
	var trial: DojoTrial = g.cls.new()
	trial.id = id
	trial.setup(players, seed_, field, start, tier)
	trial.best = best(id, players, trial.tier)
	return trial


## Whether the band has got to the job that brings a trial's start points.
static func unlocked(id: String, players := 1) -> bool:
	var g := info(id)
	if g.is_empty():
		return false
	return Story.unlocked(players) >= maxi(1, Story.lesson_night(String(g.lesson)))


## What a start point asks of the action key: "COGER EL CALCETÍN (FÁCIL)".
static func start_label(id: String, tier: int) -> String:
	return "%s (%s)" % [Text.t(String(info(id).get("start_text", ""))), Text.t(TIERS[clampi(tier, 0, TIERS.size() - 1)].text)]


## What its record counts: "level" (more is better) or "time" (less is better).
static func record_kind(id: String) -> String:
	return "level" if info(id).get("kind", "game") == "game" else "time"


# --- The records ------------------------------------------------------------------------------
## "<id>_<tier>_best_<n>" the best level (games, capped at MAX_LEVEL), "<id>_<tier>_time_<n>" the
## best time in seconds (the rest), and "<id>_<tier>_won_<n>" whether it was ever passed;
## <tier> being easy, medium or hard and n the thieves. Only what beats the record is
## written, and the rest of the file is kept as it is.

static func _key(id: String, tier: int, what: String, players: int) -> String:
	return "%s_%s_%s_%d" % [id, TIERS[clampi(tier, 0, TIERS.size() - 1)].id, what, clampi(players, 1, 4)]


static func _mark_key(id: String) -> String:
	return "best" if record_kind(id) == "level" else "time"


## The best mark at a difficulty by a band of this size (0: never played): the level
## reached or the seconds of the best pass.
static func best(id: String, players := 1, tier := 0) -> float:
	var cfg := ConfigFile.new()
	if cfg.load(Story.save) != OK:
		return 0.0
	var v := float(cfg.get_value(SECTION, _key(id, tier, _mark_key(id), players), 0.0))
	return clampf(v, 0.0, MAX_LEVEL) if record_kind(id) == "level" else maxf(v, 0.0)


## Whether the band has ever passed it at a difficulty.
static func won(id: String, players := 1, tier := 0) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(Story.save) != OK:
		return false
	return bool(cfg.get_value(SECTION, _key(id, tier, "won", players), false))


## Whether `score` beats `record` (0: none) for a trial of this kind.
static func beats(id: String, score: float, record: float) -> bool:
	if record_kind(id) == "level":
		return score > record
	return record <= 0.0 or score < record


## Keep a trial's end: true if it is a record (beats the best). Writes only if it
## improves something. The time of a trial that was lost is no mark.
static func record(id: String, players: int, score: float, won_: bool, tier := 0) -> bool:
	if info(id).is_empty():
		return false
	var level_kind := record_kind(id) == "level"
	if not level_kind and not won_:
		return false
	score = clampf(score, 0.0, MAX_LEVEL) if level_kind else maxf(score, 0.01)
	var is_best := beats(id, score, best(id, players, tier))
	var is_won := won_ and not won(id, players, tier)
	if not is_best and not is_won:
		return false
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	if is_best:
		cfg.set_value(SECTION, _key(id, tier, _mark_key(id), players), int(score) if level_kind else snappedf(score, 0.01))
	if is_won:
		cfg.set_value(SECTION, _key(id, tier, "won", players), true)
	cfg.save(Story.save)
	return is_best


## Look at what a frame of a trial brought (its events, from step): when it ended,
## keep it (record) and mark the trial (best, new_record) for the panel. Once for each
## end. Returns true if a record was made.
static func settle(trial: DojoTrial, events: Array) -> bool:
	for e in events:
		if e.e == "lost" or e.e == "won":
			var fresh := record(trial.id, trial.players, float(e.get("score", trial.score())), e.e == "won", trial.tier)
			trial.new_record = fresh
			trial.best = best(trial.id, trial.players, trial.tier)
			return fresh
	return false
