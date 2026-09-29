class_name Arcades
extends RefCounted
## The arcade machines standing tonight (the modern gallery's
## "temas/moderna/recreativa", where MuseumView puts one). In front of one,
## the action key starts a game of pong on it (Minigame "arcade",
## ArcadeGame): a joke, with nothing to win, that keeps you standing there
## playing while the guards go by. Any number of thieves can play, one
## machine each; like every minigame, not before the nights have them.

## Closer than this to one (to its edge) to play.
const REACH := 0.9
const MODEL := "temas/moderna/recreativa"

## The tiles with a machine on them.
static var list: Array[Vector2i] = []
## The way a machine's screen looks, where it is not the free floor beside it
## (front_of): the band's house sets its own (Den.ARCADE_FRONT).
static var fronts := {}


## Find tonight's machines: where the museum's collection has one (Collection,
## which MuseumView draws too), set by hand or by the gallery's theme — once
## the job's case, the pedestals and the hideouts are placed.
static func find() -> void:
	Collection.ensure()
	list = Collection.tiles_of(MODEL)
	fronts = {}


## The band's house: its machine in the lounge and nothing else (there is no
## collection there). Playing it is the same pong; nothing is won or kept.
static func find_home() -> void:
	list = [Den.ARCADE_AT]
	fronts = {Den.ARCADE_AT: Den.ARCADE_FRONT}


## The machine thief p stands in front of (on the side its screen faces,
## MuseumView.front_of), with nobody else playing at it; else (-1, -1).
## Only on its feet and free, and only on the nights with minigames
## (Heist.minigames): none in the story's first museum.
static func within_reach(p: Thief, thieves: Array[Thief]) -> Vector2i:
	if not Heist.minigames() or p.out or p.game or p.posing or p.hiding or p.rolling or p.dizzy > 0.0:
		return Vector2i(-1, -1)
	for t in list:
		var front: Vector2i = fronts.get(t, MuseumView.front_of(t))
		var middle := Vector2(t) + Vector2(0.5, 0.5)
		var off := Vector2(p.x, p.y) - middle
		if off.dot(Vector2(front)) < 0.3:
			continue
		var rect := Rect2(Vector2(t), Vector2.ONE)
		var edge := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
		if edge.distance_to(Vector2(p.x, p.y)) > REACH:
			continue
		if thieves.any(func(o: Thief) -> bool: return o != p and o.game is ArcadeGame and o.arcade == t):
			continue
		return t
	return Vector2i(-1, -1)
