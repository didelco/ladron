class_name Smoke
extends RefCounted
## Smoke bombs: each thief carries a couple. Dropped at your feet with a
## soft pop, one throws up a cloud that hides whoever is in it for a few
## seconds — no guard sees into it, through it, or out of it — so it is the
## way out of a chase: a guard that was on your heels loses you in it, and
## no longer knows which way you went.
##
## But a cloud of smoke in a museum is a thing to look at: a guard that sees
## one goes to find out what is going on (one more alarm, as a knocked-over
## bust is), so it buys you seconds, not safety.
##
## Pure logic, like Sim: SmokeFx draws each one.

const PER_THIEF := 2
## How far the cloud reaches, in tiles, once it has billowed out, and how
## long it takes to do so.
const RADIUS := 2.2
const GROW_S := 0.9
## How long it hides; then it thins out (SmokeFx) and hides no more.
const SECONDS := 6.0
## The pop of it going off: a soft thud, heard close by (Hearing.LOUDNESS).
const POP := "smoke"


class Cloud:
	var id: int
	var x: float
	var y: float
	## Sim.now_ms() when it went off
	var at: float
	var by := "p1"
	## the guards that have seen it (they come once, not every frame)
	var noticed := {}


static var list: Array[Cloud] = []
## how many each thief has in hand, by thief id
static var left := {}
## the ones that went off this frame, for whoever draws and plays them
static var fresh: Array[Cloud] = []
static var _next_id := 0


## A new night: no smoke, the bombs in hand. per: how many each (0 for a
## night without them).
static func reset(thieves: Array[Thief], per := PER_THIEF) -> void:
	list.clear()
	fresh.clear()
	left.clear()
	for t in thieves:
		left[t.id] = per


static func count(t: Thief) -> int:
	return int(left.get(t.id, 0))


## One goes off at the thief's feet. Null with none left (or out).
static func drop(t: Thief, now: float, noises: Array[SoundEvent]) -> Cloud:
	if t.out or t.safe or count(t) <= 0:
		return null
	left[t.id] = count(t) - 1
	var c := Cloud.new()
	c.id = _next_id
	_next_id += 1
	c.x = t.x
	c.y = t.y
	c.at = now
	c.by = t.id
	list.append(c)
	fresh.append(c)
	noises.append(SoundEvent.make(c.x, c.y, POP))
	return c


## How far a cloud reaches now: billowing out, then its full size while it
## hides, then nothing.
static func reach(c: Cloud, now: float) -> float:
	var age := (now - c.at) / 1000.0
	if age < 0.0 or age > SECONDS:
		return 0.0
	var k := clampf(age / GROW_S, 0.0, 1.0)
	return RADIUS * lerpf(0.35, 1.0, 1.0 - pow(1.0 - k, 3.0))


## Gone ones out of the list.
static func step(now: float) -> void:
	list = list.filter(func(c: Cloud) -> bool: return (now - c.at) / 1000.0 <= SECONDS)


## After the frame's news is read.
static func clear_fresh() -> void:
	fresh.clear()


## Inside a cloud that still hides?
static func covers(x: float, y: float, now: float) -> bool:
	for c in list:
		if Museum.dist(x, y, c.x, c.y) < reach(c, now):
			return true
	return false


## Does smoke stand between two points? A line of sight into, out of or
## through a cloud is cut.
static func blocks(ax: float, ay: float, bx: float, by: float, now: float) -> bool:
	for c in list:
		var r := reach(c, now)
		if r <= 0.0:
			continue
		if _segment_dist(ax, ay, bx, by, c.x, c.y) < r:
			return true
	return false


## A cloud this guard can see and has not come to look at yet, or null.
## Seen from outside it: a guard inside one sees nothing, smoke included.
static func spotted_by(g: Guard, now: float) -> Cloud:
	for c in list:
		if c.noticed.has(g.id) or reach(c, now) <= 0.0:
			continue
		if Museum.dist(g.x, g.y, c.x, c.y) < reach(c, now):
			continue
		if Sim.in_view(g, c.x, c.y, true) or _edge_in_view(g, c, now):
			c.noticed[g.id] = true
			return c
	return null


## A big cloud catches the eye before its middle is in the torch: the side
## nearest the guard will do.
static func _edge_in_view(g: Guard, c: Cloud, now: float) -> bool:
	var d := Museum.dist(g.x, g.y, c.x, c.y)
	if d <= 0.001:
		return false
	var k := maxf(0.0, d - reach(c, now) * 0.8) / d
	return Sim.in_view(g, g.x + (c.x - g.x) * k, g.y + (c.y - g.y) * k, true)


static func _segment_dist(ax: float, ay: float, bx: float, by: float, px: float, py: float) -> float:
	var dx := bx - ax
	var dy := by - ay
	var len2 := dx * dx + dy * dy
	var t := 0.0 if len2 <= 0.0 else clampf(((px - ax) * dx + (py - ay) * dy) / len2, 0.0, 1.0)
	return Museum.dist(ax + dx * t, ay + dy * t, px, py)
