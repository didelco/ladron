class_name DojoGames
extends RefCounted
## The dojo's games, the ones of the house's start points (Practice.ITEMS with
## `game`): the list of them, how to make one, and the best level of each at
## each difficulty for each size of band, kept in the progress beside the
## story's, section [dojo]: "<id>_<tier>_best_<n>" (the best level reached, capped
## at MAX_LEVEL) and "<id>_<tier>_won_<n>" (whether the stretch was ever done),
## <tier> being easy, medium or hard and n the thieves. Only what beats the
## record is written, and the rest of the file is kept as it is.
##
##   atrapa    PILLA EL CALCETÍN  (CatchGame)
##   bolos     BOLOS              (BowlingGame)
##   pedestal  EQUILIBRIO         (PedestalGame)
##   aguanta   AGUANTA ESCONDIDO  (HideGame)
## (GAMES is a static var: a const cannot hold the classes.) `lesson` is the
## lesson (Story.LESSONS) whose job brings the game's three start points, one
## for each of the TIERS.

const SECTION := "dojo"
const MAX_LEVEL := 99
## The difficulties: each a stretch of the games' ten levels. A game begun at
## one starts at `from` and is won by doing `to`.
const TIERS := [
	{"id": "easy", "from": 1, "to": 3, "text": "HIDEOUT_TIER_EASY"},
	{"id": "medium", "from": 4, "to": 6, "text": "HIDEOUT_TIER_MEDIUM"},
	{"id": "hard", "from": 7, "to": 10, "text": "HIDEOUT_TIER_HARD"},
]
static var GAMES: Array = [
	{"id": "atrapa", "name_key": "HIDEOUT_GAME_ATRAPA", "start_key": "HIDEOUT_GAME_START_ATRAPA", "lesson": "games", "cls": CatchGame},
	{"id": "bolos", "name_key": "HIDEOUT_GAME_BOLOS", "start_key": "HIDEOUT_GAME_START_BOLOS", "lesson": "props", "cls": BowlingGame},
	{"id": "pedestal", "name_key": "HIDEOUT_GAME_PEDESTAL", "start_key": "", "lesson": "games", "cls": PedestalGame},
	{"id": "aguanta", "name_key": "HIDEOUT_GAME_AGUANTA", "start_key": "", "lesson": "torch", "cls": HideGame},
]


static func ids() -> Array[String]:
	var out: Array[String] = []
	for g in GAMES:
		out.append(String(g.id))
	return out


static func info(id: String) -> Dictionary:
	for g in GAMES:
		if g.id == id:
			return g
	return {}


## A game, not begun (start() begins it): for a band of `players` thieves, its
## dice from `seed_`, on the dojo's `field`, at difficulty `tier` (an index
## into TIERS), the first thing placed from `start` (the tile of its start
## point). Null for an id there is not.
static func make(id: String, players: int, seed_: int, field: DojoField, start: Vector2i, tier := 0) -> DojoGame:
	var g := info(id)
	if g.is_empty():
		return null
	var game: DojoGame = g.cls.new()
	game.setup(players, seed_, field, start, tier)
	game.best = best(id, players, game.tier)
	return game


## Whether the band has got to the job that brings a game's start points.
static func unlocked(id: String, players := 1) -> bool:
	var g := info(id)
	if g.is_empty():
		return false
	return Story.unlocked(players) >= maxi(1, Story.lesson_night(String(g.lesson)))


## What a start point asks of the action key: "COGER EL CALCETÍN (FÁCIL)".
static func start_label(id: String, tier: int) -> String:
	return "%s (%s)" % [Text.t(String(info(id).get("start_key", ""))), Text.t(TIERS[clampi(tier, 0, TIERS.size() - 1)].text)]


static func _key(id: String, tier: int, what: String, players: int) -> String:
	return "%s_%s_%s_%d" % [id, TIERS[clampi(tier, 0, TIERS.size() - 1)].id, what, clampi(players, 1, 4)]


## The best level reached at a difficulty by a band of this size (0: never played).
static func best(id: String, players := 1, tier := 0) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(Story.save) != OK:
		return 0
	return clampi(int(cfg.get_value(SECTION, _key(id, tier, "best", players), 0)), 0, MAX_LEVEL)


## Whether the band has ever won at a difficulty (done the stretch's last level).
static func won(id: String, players := 1, tier := 0) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(Story.save) != OK:
		return false
	return bool(cfg.get_value(SECTION, _key(id, tier, "won", players), false))


## Keep a game's end: true if it is a record (beats the best). Writes only if
## it improves something.
static func record(id: String, players: int, level: int, won_: bool, tier := 0) -> bool:
	if info(id).is_empty():
		return false
	level = clampi(level, 0, MAX_LEVEL)
	var is_best := level > best(id, players, tier)
	var is_won := won_ and not won(id, players, tier)
	if not is_best and not is_won:
		return false
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	if is_best:
		cfg.set_value(SECTION, _key(id, tier, "best", players), level)
	if is_won:
		cfg.set_value(SECTION, _key(id, tier, "won", players), true)
	cfg.save(Story.save)
	return is_best


## Look at what a frame of a game brought (its events, from step): when it
## ended, keep it (record) and mark the game (best, new_record) for the
## screen at the end. Once for each end. Returns true if a record was made.
static func settle(game: DojoGame, events: Array) -> bool:
	for e in events:
		if e.e == "lost" or e.e == "won":
			var level: int = int(e.level)
			var fresh := record(game.id, game.players, level, e.e == "won", game.tier)
			game.new_record = fresh
			game.best = best(game.id, game.players, game.tier)
			return fresh
	return false
