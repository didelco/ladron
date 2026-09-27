class_name HeistStats
extends RefCounted
## What an attempt at a night came to, for the paper the morning after
## (EndPages.newspaper, "EL GOLPE, EN CIFRAS"): how long it took, how often
## a guard spotted the gang, and what it got up to on the way. Back to
## nothing at the start of every attempt (reset); the game counts each
## thing where it happens (add), and the clock as it plays (time).

## What is counted: "seen" (a guard spotted someone and called out),
## "hides" (into a hideout), "sneezes", "smoke" (bombs gone off), "knocked"
## (things sent over, on purpose or not), "lights" (switches flipped by the
## gang), "rolls" and "bumps" (rolled into a wall or a case).
const KINDS := ["seen", "hides", "sneezes", "smoke", "knocked", "lights", "rolls", "bumps"]
## After the time and "seen", which always show (none seen is a boast),
## the others that happened, most telling first.
const ORDER := ["smoke", "hides", "knocked", "sneezes", "lights", "bumps", "rolls"]
## How many figures the paper has room for, the time among them.
const SHOWN := 4

## seconds played
static var time := 0.0
static var counts := {}


static func reset() -> void:
	time = 0.0
	counts.clear()
	for k in KINDS:
		counts[k] = 0


static func add(kind: String, n := 1) -> void:
	counts[kind] = count(kind) + n


static func count(kind: String) -> int:
	return int(counts.get(kind, 0))


## What the paper shows, [kind, number] each, at most SHOWN: the time,
## "seen", then what else happened in ORDER.
static func highlights() -> Array:
	var out: Array = [["time", int(time)], ["seen", count("seen")]]
	for k in ORDER:
		if out.size() >= SHOWN:
			break
		if count(k) > 0:
			out.append([k, count(k)])
	return out


## The time as the paper prints it: "1:42".
static func clock(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]
