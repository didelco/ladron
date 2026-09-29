class_name PedestalGame
extends DojoGame
## «EQUILIBRIO» (pedestal): hold the statue's pose on a pedestal (Plinths) for
## so many seconds. It begins the moment a thief climbs one of the three
## pedestals of the game (easy, medium, hard: its start points), and that thief
## is the holder, up on the same pedestal for every round; each round is longer
## than the last. Fall off (or step down) and it is lost; the level is the
## rounds held. (Named PedestalGame because BalanceGame is already the
## minigame of the same pose on one foot, logic/minigames/balance.gd.)
##
## The balance is not this game's: the Minigame "balance" keeps the pose (the
## host gives it the difficulty of the pedestal's tier) and the body of the
## holder says `fell` (and its `lean`, for the picture); this only counts the
## time and the rounds.
##
## Events: spawn {tile, pos, level, hold}, tick {left}, fall {by}, clear, level,
## alarm, lost {why: "fall"|"down"}, won.

## hold: seconds to hold
const LEVELS := [
	{"hold": 4.0}, {"hold": 5.0}, {"hold": 6.0}, {"hold": 8.0}, {"hold": 10.0},
	{"hold": 12.0}, {"hold": 15.0}, {"hold": 18.0}, {"hold": 22.0}, {"hold": 26.0},
]

var holder := -1
var hold_left := 0.0
## the holder's lean, as the minigame says it
var lean := 0.0


static func params(lv: int) -> Dictionary:
	return level_row(LEVELS, lv)


func _init() -> void:
	id = "pedestal"


func _reset() -> void:
	holder = starter
	lean = 0.0


func _begin_level() -> void:
	hold_left = float(params(level).hold)
	lean = 0.0
	_emit({"e": "spawn", "tile": start_tile, "pos": DojoField.center(start_tile), "level": level, "hold": hold_left})


func _play(dt: float, bodies: Array[Dictionary]) -> void:
	var me := {}
	for b in bodies:
		if int(b.id) == holder:
			me = b
	if me.is_empty() or me.get("out", false) or not me.get("posing", me.get("hidden", false)):
		if not me.is_empty() and me.get("fell", false):
			_fall()
		else:
			_lose("down")
		return
	lean = float(me.get("lean", lean))
	if me.get("fell", false):
		_fall()
		return
	hold_left -= dt
	if hold_left <= 0.0:
		hold_left = 0.0
		_credit(holder)
		_clear_level()
		return
	_tick(hold_left)


func _fall() -> void:
	_emit({"e": "fall", "by": holder})
	_lose("fall")


func _penalize(seconds: float) -> void:
	# Here a slip of the clock is a longer hold.
	hold_left += seconds


func _view() -> Dictionary:
	var p := params(level)
	return {"objects": [{"kind": "pedestal", "pos": DojoField.center(start_tile), "ring": -1.0}],
		"timer": {"left": hold_left, "max": float(p.hold), "kind": "hold"}, "lean": lean, "fall": BalanceGame.FALL}
