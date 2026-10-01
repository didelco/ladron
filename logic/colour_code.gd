class_name ColourCode
extends RefCounted
## The colour code of a hideout: the one puzzle of getting into one, in a
## heist (Hideouts.start, Minigame "squeeze") and at the dojo's ESCONDITE
## (BenchTrial), the same whichever way it is launched. A code of colours is
## shown in order (target); the same colours sit under it in a row, out of
## order (balls); a ball is picked and another picked after it to change the
## two of place (pick, swap), never their colour, until the row reads as the
## code (solved). Nothing to lose but time: every swap is out in the open.
##
## By difficulty: more balls, and more swaps the start is from the answer at
## the least (BALLS_LEVEL, SWAPS_LEVEL; a tight piece asks one swap more).
## The start is never the answer already (make): the row is dealt until it
## is at least that many swaps away, or, failing the dice, turned round by
## one place, which is as far as a row can get.

## The colours the balls come in, in the order a code may use them (a code
## of n balls uses the first n): told apart by hue and by lightness both.
const COLOURS: Array[Color] = [
	Color("#e5484d"), # red
	Color("#f5d547"), # yellow
	Color("#4c8dff"), # blue
	Color("#4ade80"), # green
	Color("#f08c2e"), # orange
	Color("#b57bee"), # violet
]
## How many balls a code has at each level (0 easy .. 2 hard), and how
## many swaps at the least the start is from the answer.
const BALLS_LEVEL := [3, 4, 5]
const SWAPS_LEVEL := [1, 2, 3]
## Deals of the dice before the row is turned round by hand instead.
const DEALS := 64

## The code to make, as indices into COLOURS, in order.
var target: Array[int] = []
## The balls as they sit now, slot by slot (the same indices).
var balls: Array[int] = []
## The slot of the ball picked for a swap, or -1.
var picked := -1
## Swaps made.
var swaps := 0


## A code of this many balls, dealt so that the start is at least `min_swaps`
## swaps from the answer (1 at the least, n - 1 at the most) with these dice.
static func make(n: int, min_swaps: int, rng: RandomNumberGenerator) -> ColourCode:
	var c := ColourCode.new()
	n = clampi(n, 2, COLOURS.size())
	min_swaps = clampi(min_swaps, 1, n - 1)
	var order: Array[int] = []
	for i in n:
		order.append(i)
	c.target = _dealt(order, rng)
	for deal in DEALS:
		c.balls = _dealt(c.target, rng)
		if c.distance() >= min_swaps:
			return c
	# The dice would not: the code turned round by one place, every ball
	# out of place and n - 1 swaps from the answer.
	c.balls.clear()
	for i in n:
		c.balls.append(c.target[(i + 1) % n])
	return c


## How many balls a code has at a level, with a tight piece or not.
static func balls_for(level: int) -> int:
	return BALLS_LEVEL[clampi(level, 0, 2)]


## How many swaps at the least the start is from the answer at a level, one
## more for a tight piece (never more than the balls allow: balls - 1).
static func swaps_for(level: int, tight: int) -> int:
	return mini(SWAPS_LEVEL[clampi(level, 0, 2)] + clampi(tight, 0, 1), balls_for(level) - 1)


## Pick the ball at a slot: the first pick holds it, the same slot again
## lets it go, another slot swaps the two. True when a swap was made.
func pick(slot: int) -> bool:
	if slot < 0 or slot >= balls.size():
		return false
	if picked < 0:
		picked = slot
		return false
	if picked == slot:
		picked = -1
		return false
	swap(picked, slot)
	picked = -1
	return true


## Change the balls at two slots of place.
func swap(a: int, b: int) -> void:
	if a == b or a < 0 or b < 0 or a >= balls.size() or b >= balls.size():
		return
	var t: int = balls[a]
	balls[a] = balls[b]
	balls[b] = t
	swaps += 1


## The row reads as the code.
func solved() -> bool:
	return balls == target


## How many balls sit where the code says.
func matched() -> int:
	var n := 0
	for i in balls.size():
		if balls[i] == target[i]:
			n += 1
	return n


## The swaps from the answer at the least: the balls less the cycles of the
## row as a permutation of the code (a ball in its place is a cycle of one).
func distance() -> int:
	var where := {}
	for i in target.size():
		where[target[i]] = i
	var seen := {}
	var cycles := 0
	for i in balls.size():
		if seen.has(i):
			continue
		cycles += 1
		var j := i
		while not seen.has(j):
			seen[j] = true
			j = where[balls[j]]
	return balls.size() - cycles


## The colour of a ball (an index into COLOURS).
static func colour(ball: int) -> Color:
	return COLOURS[clampi(ball, 0, COLOURS.size() - 1)]


## A copy of these dealt by the dice (Fisher-Yates).
static func _dealt(of: Array[int], rng: RandomNumberGenerator) -> Array[int]:
	var out := of.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: int = out[i]
		out[i] = out[j]
		out[j] = t
	return out
