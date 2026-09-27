class_name StarSlots
extends RefCounted
## The stars won on each heist as they show on the way in to one (Tour):
## over each museum in the town, over each room inside it, and the night's
## goals on the plan, the ones already won ticked. What they are and how
## they are won is Story's (stars, star_mask, stars_in, goals); this only
## words them.

const FULL := "★"
const EMPTY := "☆"


## A room's stars as they show: "★★☆"; "" for a room not reached yet.
static func room_line(n: int, players: int) -> String:
	if n > Story.unlocked(players):
		return ""
	var got := Story.stars(n, players)
	return FULL.repeat(got) + EMPTY.repeat(maxi(0, Story.STARS_EACH - got))


## A museum's stars as they show: "★ 7/15".
static func museum_line(m: int, players: int) -> String:
	return "%s %d/%d" % [FULL, Story.stars_in(m, players), Story.STARS_EACH * Story.ROOMS]


## Heist n's goals, in Story.STARS order, each [words, won already].
static func goals(n: int, players: int) -> Array:
	var mask := Story.star_mask(n, players)
	var words := Story.goals(n, players)
	var out: Array = []
	for i in words.size():
		out.append([words[i], bool(mask & Story.STARS[i])])
	return out
