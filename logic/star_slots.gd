class_name StarSlots
extends RefCounted
## Where the stars won on each heist show up on the way in to one (Tour):
## over each museum in the town, over each room inside it, and the night's
## goals on the plan. The stars themselves are Story's (stars, stars_in, par,
## goals); until Story has them, every one of these is empty and nothing
## shows.
##
## TODO(estrellas): once Story has stars(n, players), stars_in(m, players),
## par(n) and goals(n), check that their meaning is the one assumed here
## (stars(n) the best of heist n, 0..MOST, or -1 never played; stars_in(m)
## the museum's sum; goals(n) a line of words each) and drop the has_method
## guards.

## The most a heist gives.
const MOST := 3
const FULL := "★"
const EMPTY := "☆"


## Whether Story counts stars yet.
static func counted() -> bool:
	return _has("stars")


## Whether Story has this, and what it says (Story itself, as an object: its
## functions may not be there yet).
static func _has(what: String) -> bool:
	var story: Object = Story
	return story.has_method(what)


static func _ask(what: String, args: Array) -> Variant:
	var story: Object = Story
	return story.callv(what, args)


## Heist n's best, 0..MOST; -1 if not played or not counted.
static func of(n: int, players: int) -> int:
	if not counted():
		return -1
	return int(_ask("stars", [n, players]))


## Museum m's stars, all its heists together; -1 if not counted.
static func in_museum(m: int, players: int) -> int:
	if not _has("stars_in"):
		return -1
	return int(_ask("stars_in", [m, players]))


## What heist n asks for its stars, a line each; empty if not counted.
static func goals(n: int) -> Array:
	if not _has("goals"):
		return []
	var out: Variant = _ask("goals", [n])
	return out if out is Array else []


## A room's stars as they show: "★★☆"; "" if there are none to show.
static func room_line(n: int, players: int) -> String:
	var got := of(n, players)
	if got < 0:
		return ""
	return FULL.repeat(got) + EMPTY.repeat(maxi(0, MOST - got))


## A museum's stars as they show: "★ 7/15"; "" if not counted.
static func museum_line(m: int, players: int) -> String:
	var got := in_museum(m, players)
	if got < 0:
		return ""
	return "%s %d/%d" % [FULL, got, MOST * Story.ROOMS]
