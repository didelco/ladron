class_name Collection
extends RefCounted
## What stands on each case of the museum tonight, decided once for the
## whole museum: the view draws it (MuseumView._exhibits) and the arcade
## machines are found in it (Arcades), so the two never disagree.
##
## A tile's piece comes from its gallery's theme and a hash of its
## coordinates (Themes.pick), so the same museum always looks the same; and
## the museum keeps count of what it has put, tile by tile in order, so that
##   an icon (Themes.UNIQUE) stands once at most,
##   a piece with variants (Themes.VARIANTS, the arcade machine) is a
##     different one each time, and with none left the place gets another,
##   a piece with a front (Themes.FRONTED) only goes where there is floor
##     for it to face.
## What a saved map stood by hand (MuseumView.exhibits) is kept as it is,
## and counted first: the rest only adds to it.
##
## Not here: the empty pedestals (Plinths), the furniture to hide in
## (Hideouts), the big pieces, and the job's case, which stands empty.

## How many picks a tile gets before it settles for a case of colours.
const TRIES := 8

## tile -> [where, piece, variant]: where is "case", "plinth" or "floor"
## (Themes.pick), piece a theme's (a model's path or an "@" one of
## MuseumView's own) or, set by hand, one of MuseumView.EXHIBITS; variant
## "" for a piece with none.
static var picks := {}
## What picks was laid out from (_inputs), so a museum is laid out once.
static var _made_from := 0


## Lay the museum out, unless it already is as it stands now (the museum,
## the job's case, the pedestals, the furniture, the pieces set by hand).
static func ensure() -> void:
	if _inputs() != _made_from or picks.is_empty():
		lay_out()


## Decide what stands on every case left: the ones set by hand first, then
## each gallery's by its theme.
static func lay_out() -> void:
	_made_from = _inputs()
	picks.clear()
	var count := {}
	var used := {}
	var themed: Array[Vector2i] = []
	for t in Museum.cover_tiles:
		if not Museum.big_piece_at(t).is_empty() or Plinths.is_plinth(t) or Hideouts.pieces.has(t):
			continue
		var hand: String = MuseumView.exhibits.get(t, "")
		if hand == "plinth" or Hideouts.PIECES.has(hand):
			continue
		if hand == "":
			themed.append(t)
			continue
		# By hand: as it is, even a second icon; a variant each, round again
		# if there are more than variants.
		var where := Themes.where_of(hand) if "/" in hand else "case"
		var all := Themes.variants(hand)
		var variant := ""
		if not all.is_empty():
			var left := all.filter(func(v): return not v in used.get(hand, []))
			variant = _choose(left if not left.is_empty() else all, t)
		_count(hand, variant, count, used)
		picks[t] = [where, hand, variant]
	for t in themed:
		var room := Museum.room_at(t.x + 0.5, t.y + 0.5)
		var pick := _pick(room.theme if room else "", t, count, used)
		_count(pick[1], pick[2], count, used)
		picks[t] = pick
	# The job's case stands empty, whatever it would have shown: the rest of
	# the museum looks the same wherever tonight's piece is.
	picks.erase(Heist.at)


## What stands on tile t: [where, piece, variant], or [] if nothing of the
## collection does (a pedestal, a hideout, a big piece, the job's case).
static func at(t: Vector2i) -> Array:
	return picks.get(t, [])


## The variant of what stands on tile t (Themes.VARIANTS), or "".
static func variant_at(t: Vector2i) -> String:
	var pick := at(t)
	return pick[2] if not pick.is_empty() else ""


## The tiles a piece stands on, in order.
static func tiles_of(piece: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for t in picks:
		if picks[t][1] == piece:
			out.append(t)
	out.sort()
	return out


## A tile's piece: the first of its picks (Themes.pick, from its hashes)
## that fits — an icon not out yet, a variant still left, a front with floor
## to face — or in the end a case of colours.
static func _pick(theme: String, t: Vector2i, count: Dictionary, used: Dictionary) -> Array:
	for k in TRIES:
		var pick := Themes.pick(theme, MuseumView._hash01(t.x, t.y, 41 + k * 101), MuseumView._hash01(t.x, t.y, 29 + k * 101))
		var piece: String = pick[1]
		if piece in Themes.FRONTED and MuseumView.front_of(t) == Vector2i.ZERO:
			continue
		if Themes.is_unique(piece) and count.has(piece):
			continue
		var variant := ""
		var all := Themes.variants(piece)
		if not all.is_empty():
			var left := all.filter(func(v): return not v in used.get(piece, []))
			if left.is_empty():
				continue
			variant = _choose(left, t)
		return [pick[0], piece, variant]
	return ["case", "@colours", ""]


## One of these, from the tile's hash.
static func _choose(from: Array, t: Vector2i) -> String:
	return from[mini(int(MuseumView._hash01(t.x, t.y, 53) * from.size()), from.size() - 1)]


static func _count(piece: String, variant: String, count: Dictionary, used: Dictionary) -> void:
	count[piece] = count.get(piece, 0) + 1
	if variant != "":
		if not used.has(piece):
			used[piece] = []
		used[piece].append(variant)


## All that what stands on the cases depends on, as one number.
static func _inputs() -> int:
	return hash([Museum.version, Museum.w, Museum.h, Heist.at, Plinths.list, Hideouts.pieces, MuseumView.exhibits])
