class_name DojoWatch
extends RefCounted
## Which of the band has just got onto a start point that is not started with the
## action key next to it: climbed one of EQUILIBRIO's pedestals or hidden in one of
## AGUANTA ESCONDIDO's armours (the `via` "plinth" and "armour" of DojoTrials.TABLE; the
## others are started with the action key: Practice.start_at). Asked once a frame with
## the band; it remembers who was on one the last time, so that it answers only for
## those that have got on since (one that stays on after leaving a trial does not start
## it again until it gets off and on).

var _on := {}


## The start point somebody has just got onto, or {}: {id, tier, by (the index of the
## thief in `thieves`)}.
func poll(thieves: Array, players := 1) -> Dictionary:
	var now := {}
	var found := {}
	for i in thieves.size():
		var at := _under(thieves[i], players)
		if at.is_empty():
			continue
		var key := "%s:%d" % [at.id, at.tier]
		now[i] = key
		if _on.get(i, "") != key:
			found = {"id": at.id, "tier": at.tier, "by": i}
	_on = now
	return found


## The start point a thief is on ({id, tier}) or {}.
func _under(p, players: int) -> Dictionary:
	if p.out:
		return {}
	var via := ""
	var tile := Vector2i(-1, -1)
	if p.posing:
		via = "plinth"
		tile = p.perch
	elif p.hiding and p.hideout != null and p.hideout.kind == "armour" and not p.hideout.tiles.is_empty():
		via = "armour"
		tile = p.hideout.tiles[0]
	if via == "":
		return {}
	for row in DojoTrials.by_via(via):
		var tier := Practice.start_tier(String(row.id), tile, players)
		if tier >= 0:
			return {"id": row.id, "tier": tier}
	return {}
