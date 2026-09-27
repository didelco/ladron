class_name WiresGame
extends Minigame
## The alarm panel: a row of wires, three to six by the level; over the next
## one to cut, an arrow shows which way to pull the cutters: press that
## direction. The wrong way sparks, and the hands jump off it a moment.
## Shaking hands take longer to steady on the next wire.

## The wrong way on a wire: a spark, and the hands off it this long.
const SPARK_S := 0.6
## At full tremble, how long the cutters take to steady on the next wire.
const STEADY_S := 0.3
## How many wires a panel has, by level.
const WIRES_LEVEL := [3, 4, 6]

## The way to pull each wire (an index into DIRS).
var ways: Array[int] = []


func _setup(_steps: int) -> void:
	# As many as the level says, each its own way to pull.
	steps = WIRES_LEVEL[level]
	for i in steps:
		ways.append(_rng.randi() % DIRS.size())


## The next wire's way, or -1 while the cutters steady (or it is all done).
func way() -> int:
	if done or step >= ways.size() or lock > 0.0:
		return -1
	return ways[step]


func _play(_input: Dictionary, press: Dictionary, _dt: float) -> String:
	var dir := pressed_dir(press)
	if dir >= 0 and lock <= 0.0:
		if dir == ways[step]:
			step += 1
			events.append("snip")
			lock = STEADY_S * tremble
		else:
			lock = SPARK_S
			events.append("spark")
	return "done" if step >= steps else ""
