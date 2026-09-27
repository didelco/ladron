class_name Arcades
extends RefCounted
## The arcade machines standing tonight (the modern gallery's
## "temas/moderna/recreativa", where MuseumView puts one). In front of one,
## the action key starts a game of pong on it (Minigame "arcade",
## ArcadeGame): a joke, with nothing to win, that keeps you standing there
## playing while the guards go by. Any number of thieves can play, one
## machine each.

## Closer than this to one (to its edge) to play.
const REACH := 0.9
const MODEL := "temas/moderna/recreativa"

## The tiles with a machine on them.
static var list: Array[Vector2i] = []


## Find tonight's machines: the tiles MuseumView draws one on, from the same
## picks — once the job's case, the pedestals and the hideouts are placed.
static func find() -> void:
	list.clear()
	for t in Museum.cover_tiles:
		if t == Heist.at or MuseumView.exhibits.has(t) or not Museum.big_piece_at(t).is_empty():
			continue
		if Plinths.is_plinth(t) or Hideouts.pieces.has(t):
			continue
		var room := Museum.room_at(t.x + 0.5, t.y + 0.5)
		if MuseumView.theme_pick(room.theme if room else "", t)[1] == MODEL:
			list.append(t)


## The machine thief p stands in front of (on the side its screen faces,
## MuseumView.front_of), with nobody else playing at it; else (-1, -1).
static func within_reach(p: Thief, thieves: Array[Thief]) -> Vector2i:
	for t in list:
		var front := MuseumView.front_of(t)
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
