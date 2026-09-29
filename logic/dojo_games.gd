class_name DojoGames
extends RefCounted
## The dojo's games, the ones of the house's sign posts (Practice.ITEMS with
## `game`): the list of them, how to make one, and the best level of each for
## each size of band, kept in the progress beside the story's, section [dojo]:
## "<id>_best_<n>" (the best level reached, capped at MAX_LEVEL) and
## "<id>_won_<n>" (whether the tenth was ever done), n being the thieves. Only
## what beats the record is written, and the rest of the file is kept as it is.
##
##   atrapa    PILLA EL CALCETÍN  (CatchGame)
##   bolos     BOLOS              (BowlingGame)
##   pedestal  EQUILIBRIO         (PedestalGame)
##   aguanta   AGUANTA ESCONDIDO  (HideGame)
## (GAMES is a static var: a const cannot hold the classes.) `lesson` is the lesson (Story.LESSONS) whose night brings the sign post.

const SECTION := "dojo"
const MAX_LEVEL := 99
static var GAMES: Array = [
	{"id": "atrapa", "name_key": "HIDEOUT_GAME_ATRAPA", "blurb_key": "HIDEOUT_GAME_ATRAPA_BLURB", "lesson": "games", "cls": CatchGame},
	{"id": "bolos", "name_key": "HIDEOUT_GAME_BOLOS", "blurb_key": "HIDEOUT_GAME_BOLOS_BLURB", "lesson": "props", "cls": BowlingGame},
	{"id": "pedestal", "name_key": "HIDEOUT_GAME_PEDESTAL", "blurb_key": "HIDEOUT_GAME_PEDESTAL_BLURB", "lesson": "games", "cls": PedestalGame},
	{"id": "aguanta", "name_key": "HIDEOUT_GAME_AGUANTA", "blurb_key": "HIDEOUT_GAME_AGUANTA_BLURB", "lesson": "torch", "cls": HideGame},
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


## A game, not begun (start() begins it): for a band of `players` thieves,
## its dice from `seed_`, on the dojo's `field`, the first thing placed from
## `start` (a tile). Null for an id there is not.
static func make(id: String, players: int, seed_: int, field: DojoField, start: Vector2i) -> DojoGame:
	var g := info(id)
	if g.is_empty():
		return null
	var game: DojoGame = g.cls.new()
	game.setup(players, seed_, field, start)
	game.best = best(id, players)
	return game


## Whether the band has got to the night that brings a game's sign post.
static func unlocked(id: String, players := 1) -> bool:
	var g := info(id)
	if g.is_empty():
		return false
	return Story.unlocked(players) >= maxi(1, Story.lesson_night(String(g.lesson)))


static func _key(id: String, what: String, players: int) -> String:
	return "%s_%s_%d" % [id, what, clampi(players, 1, 4)]


## The best level reached by a band of this size (0: never played).
static func best(id: String, players := 1) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(Story.save) != OK:
		return 0
	return clampi(int(cfg.get_value(SECTION, _key(id, "best", players), 0)), 0, MAX_LEVEL)


## Whether the band has ever won (done the tenth level).
static func won(id: String, players := 1) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(Story.save) != OK:
		return false
	return bool(cfg.get_value(SECTION, _key(id, "won", players), false))


## Keep a game's end: true if it is a record (beats the best). Writes only if
## it improves something.
static func record(id: String, players: int, level: int, won_: bool) -> bool:
	if info(id).is_empty():
		return false
	level = clampi(level, 0, MAX_LEVEL)
	var is_best := level > best(id, players)
	var is_won := won_ and not won(id, players)
	if not is_best and not is_won:
		return false
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	if is_best:
		cfg.set_value(SECTION, _key(id, "best", players), level)
	if is_won:
		cfg.set_value(SECTION, _key(id, "won", players), true)
	cfg.save(Story.save)
	return is_best


## Look at what a frame of a game brought (its events, from step): when it
## ended, keep it (record) and mark the game (best, new_record) for the
## screen at the end. Once for each end. Returns true if a record was made.
static func settle(game: DojoGame, events: Array) -> bool:
	for e in events:
		if e.e == "lost" or e.e == "won":
			var level: int = int(e.level)
			var fresh := record(game.id, game.players, level, e.e == "won")
			game.new_record = fresh
			game.best = best(game.id, game.players)
			return fresh
	return false
