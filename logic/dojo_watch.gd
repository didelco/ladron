class_name DojoWatch
extends RefCounted
## Which of the band has just got onto a start point of a dojo game that is
## not a button: climbed one of EQUILIBRIO's pedestals or hidden in one of
## AGUANTA ESCONDIDO's armours (the others, the sock on its pedestal and the
## circles of BOLOS, are started with the action key: Practice.game_at). Asked
## once a frame with the band; it remembers who was on one the last time, so
## that it answers only for those that have got on since (one that stays on
## after leaving a game does not start it again until it gets off and on).

var _on := {}


## The start point somebody has just got onto, or {}: {game, tier, by (the
## index of the thief in `thieves`)}.
func poll(thieves: Array, players := 1) -> Dictionary:
	var now := {}
	var found := {}
	for i in thieves.size():
		var at := _under(thieves[i], players)
		if at.is_empty():
			continue
		var key := "%s:%d" % [at.game, at.tier]
		now[i] = key
		if _on.get(i, "") != key:
			found = {"game": at.game, "tier": at.tier, "by": i}
	_on = now
	return found


## The start point a thief is on ({game, tier}) or {}.
func _under(p, players: int) -> Dictionary:
	if p.out:
		return {}
	var game := ""
	var tile := Vector2i(-1, -1)
	if p.posing:
		game = "pedestal"
		tile = p.perch
	elif p.hiding and p.hideout != null and p.hideout.kind == "armour" and not p.hideout.tiles.is_empty():
		game = "aguanta"
		tile = p.hideout.tiles[0]
	if game == "":
		return {}
	var tier := Practice.start_tier(game, tile, players)
	return {} if tier < 0 else {"game": game, "tier": tier}
