class_name Watch
extends RefCounted
## What a guard has had a look at: its picture of the museum. Port of watch.ts.
##
## Every walkable tile carries the last time this guard had it in its cone
## (Sim writes it every frame). A zone is controlled once most of it has been
## seen since a given moment — "I have been over the east gallery since I
## heard that, and there is nobody there".

## A zone counts as looked over once this share of its floor has been seen.
const CONTROLLED_SHARE := 0.75
## Looks taken within this long of a clue do not count towards clearing it:
## what the guard saw as it lost the thief is where the thief *was*.
const CLEAR_GRACE_MS := 1500.0


static func blank_sight() -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(Museum.w * Museum.h)
	return a


static func seen_share(g: Guard, zone: Museum.Zone, since: float) -> float:
	if zone.tiles.is_empty():
		return 1.0
	var n := 0
	for t in zone.tiles:
		if g.seen_at[t.y * Museum.w + t.x] >= since:
			n += 1
	return float(n) / zone.tiles.size()


static func controlled(g: Guard, zone: Museum.Zone, since: float) -> bool:
	return seen_share(g, zone, since) >= CONTROLLED_SHARE


## How long since the guard last had a proper look at a zone, in ms (INF: never).
static func since_looked(g: Guard, zone: Museum.Zone, now: float) -> float:
	var times: Array[float] = []
	for t in zone.tiles:
		times.append(g.seen_at[t.y * Museum.w + t.x])
	times.sort()
	times.reverse()
	if times.is_empty():
		return INF
	var at := times[int(floor((times.size() - 1) * CONTROLLED_SHARE))]
	return now - at if at > 0 else INF


## Has this guard looked over the zone its clue points at, since the clue?
static func clue_cleared(g: Guard) -> bool:
	if g.memory == null:
		return false
	var z := Museum.zone_at(g.memory.x, g.memory.y)
	return z != null and controlled(g, z, g.memory.at + CLEAR_GRACE_MS)


static func controlled_zones(g: Guard, since: float) -> Array[Museum.Zone]:
	var out: Array[Museum.Zone] = []
	for z in Museum.zones:
		if controlled(g, z, since):
			out.append(z)
	return out
