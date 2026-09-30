class_name Den
extends RefCounted
## The band's house (El Escondite del Calcetin): not a level but a place to
## be at home in, four rooms side by side that one walks from one to the
## next with the game's own camera:
##
##   the lounge (SALON), where one turns up and where the front door is:
##     sofas, a rug, a telly, a fridge and a little bar with stools;
##   the trophy room (TROFEOS), a little museum of the band's own: 25 empty
##     stands, one for each heist of the story, five to a museum, which fill
##     with the piece as it is stolen (STANDS, filled; DenView draws it);
##   the dojo (DOJO), the practice ground (Practice): nine bays in three rows
##     (41 x 28 tiles, DOJO_PLAN), one for each trial of the dojo (DojoTrials) with
##     room for its three start points, with what has been unlocked to try in each;
##   the bathroom (ASEO), for looks only, for now (BATH_GAG), south of the dojo.
##
## This is the plan as data: the walls, the doors between rooms, the way
## out and the furniture with the tiles it blocks. Pure logic, like Sim:
## DenView draws it. The furniture models are Kenney's Furniture Kit
## (assets/models/casa, CC0); the plan is in tiles, a model's size is scaled
## (SCALE) to the ninjas' (a thief is 1.1 tall, a tile is 1).

const W := 63
const H := 38
## Kenney's furniture is a little under life size for our chibi ninjas: this
## much bigger, unless an entry says otherwise.
const SCALE := 1.8

## The rooms' floors (interior, in tiles: x, y, width, height), and the
## order they are told in.
const ROOMS := {
	"salon": [1, 10, 19, 13],
	"trofeos": [1, 1, 19, 8],
	"dojo": [21, 1, 41, 28],
	"aseo": [21, 30, 9, 7],
}
const ORDER := ["salon", "trofeos", "dojo", "aseo"]
## The doors between rooms: gaps in the walls (rect: x, y, width, height, in
## tiles) that join two rooms (a, b). They open and close (DOOR_* below): a
## shut one is wall for the feet; and what one sees follows what is open
## (visible_rooms). Easy to move or add: the plan (rows) and the rest follow.
const DOORS := [
	{"id": "salon_trofeos", "rect": [9, 9, 2, 1], "a": "salon", "b": "trofeos"},
	{"id": "salon_dojo", "rect": [20, 11, 1, 2], "a": "salon", "b": "dojo"},
	{"id": "trofeos_dojo", "rect": [20, 3, 1, 2], "a": "trofeos", "b": "dojo"},
	{"id": "dojo_aseo", "rect": [27, 29, 2, 1], "a": "dojo", "b": "aseo"},
]
## How long a door takes to swing (DenView), in seconds.
const DOOR_SECONDS := 0.3
## A door cannot be shut with someone this close to (inside) its tiles, in
## tiles: the body's radius, so nobody is caught in the doorway.
const DOOR_CLEAR := 0.3
## The house's front door: two leaves in the south wall of the lounge. To
## cross it (the floor in front of it) is to go out to the town.
const FRONT_DOOR := [9, 23, 2, 1]
const EXIT := Vector2i(9, 22)
## Where the band turns up.
const SPAWN := Vector2i(9, 19)
## The bathroom, for looks only. Something funny for it later: a duck to
## squeak, a tap to run, a shower to sing in... For now DenView only dresses
## it. Nothing here is played; when it is, this is where it goes.
const BATH_GAG := ""
## How far south of where the plan was first drawn the bathroom's furniture stands
## (the bathroom moved below the dojo, when the dojo grew).
const BATH_DY := 15

## The tile of the practice map's piece: a heist needs a case to be reached (the
## map's rules), and this is one of the dojo's low cabinets, sealed and empty
## (nothing is shown in it). The trials' things are in DojoTrials.TABLE.
const CASE_AT := Vector2i(23, 8)

## The lounge's arcade machine (the same one as the modern gallery's, Arcades):
## against the north wall, its screen looking south. Standing in front of it,
## the action key plays its pong, with nothing to win.
const ARCADE_AT := Vector2i(2, 10)
const ARCADE_FRONT := Vector2i(0, 1)

## The trophy room's gallery: a section for each museum, side by side along
## the room (SECTION_X0 + m * SECTION_STEP, SECTION_WIDTH tiles wide). In each,
## the first three heists have a niche on the north wall (one tile each) and
## the last two a glass case on the floor, a little way in (CASE_Y), at the
## section's first and third tile. Between the two, and in front, one walks.
const SECTION_X0 := 1
const SECTION_STEP := 4
const SECTION_WIDTH := 3
const NICHES_Y := 1
const CASE_Y := 5
## How many of a museum's heists are niches on the wall (the rest, cases).
const NICHES := 3
## The bench in the middle of the gallery, to sit and look.
const BENCH := [9, 6, 2, 1]

## The dojo's inside walls, row by row (x from DOJO_X, y from DOJO_Y; "#" is
## wall, "." floor). Nine bays (DOJO_ZONES; DojoTrials.TABLE), one per trial and its
## three start points, in three rows: the top and bottom rows keep a bay to a room,
## joined by doorways three wide in the walls between them; the middle row's three
## (the games of skill, all a pedestal or a mark to stand on) share one open room,
## its three bays' things all in sight of each other, with no inside wall at all:
##
##            x 21-34             x 35-48             x 49-61
##   y 1-9    GANZÚA  (vitrines)  CABLES  (alarm)     PULSO   (alarm)     alarm and cases
##   y 10-18  CALCETÍN (pedestals) EQUILIBRIO (plinths) BOLOS  (circles)   games of skill (one room)
##   y 19-28  CIRCUITO (guards)   ESCONDITE (furniture) AGUANTA (armours)  stealth
##
## The trophy room's door lands in GANZÚA, the lounge's in CALCETÍN, and the bathroom's
## (south of the dojo, x 27-28) in CIRCUITO, whose two lanes are walled inside.
const DOJO_X := 21
const DOJO_Y := 1
const DOJO_PLAN := [
	".............#.............#.............",
	".............#.............#.............",
	".............#.............#.............",
	".........................................",
	".........................................",
	".........................................",
	".............#.............#.............",
	".............#.............#.............",
	"#####...###########...###########...#####",
	".........................................",
	".........................................",
	".........................................",
	".........................................",
	".........................................",
	".........................................",
	".........................................",
	".........................................",
	"#####...###########...###########...#####",
	".............#.............#.............",
	".............#.............#.............",
	"##########...#.............#.............",
	".........................................",
	".........................................",
	".........................................",
	"...###########.............#.............",
	".............#.............#.............",
	".............#.............#.............",
	".............#.............#.............",
]
## The zones' names (rects x, y, w, h in tiles; together they cover the dojo, walls
## between bays included), for the tests and the docs: the bay of each trial, named
## by its id (DojoTrials.TABLE).
const DOJO_ZONES := {
	"lockpick": [21, 1, 14, 9],
	"wires": [35, 1, 14, 9],
	"steady": [49, 1, 13, 9],
	"atrapa": [21, 10, 14, 9],
	"pedestal": [35, 10, 14, 9],
	"bolos": [49, 10, 13, 9],
	"circuit": [21, 19, 14, 10],
	"squeeze": [35, 19, 14, 10],
	"aguanta": [49, 19, 13, 10],
}

static var _stands: Array = []
static var _furniture: Array = []


## The room a point is in ("" in a doorway or outside).
static func room_at(x: float, y: float) -> String:
	var tx := int(floor(x))
	var ty := int(floor(y))
	for id in ORDER:
		var r: Array = ROOMS[id]
		if tx >= r[0] and ty >= r[1] and tx < r[0] + r[2] and ty < r[1] + r[3]:
			return id
	return ""


## The rect of a room, in tiles.
static func rect(id: String) -> Rect2i:
	var r: Array = ROOMS[id]
	return Rect2i(r[0], r[1], r[2], r[3])


## Whether a point is at the front door, on the floor in front of it: to go
## out. Anyone of the band crossing it takes the whole band out (the town
## is a single screen, like the pause).
static func at_door(x: float, y: float) -> bool:
	return y >= EXIT.y + 0.05 and x >= EXIT.x + 0.1 and x <= EXIT.x + 1.9


# --- The doors between rooms ------------------------------------------------------

## Which doors are open (id -> true). A round begins with all of them shut
## (reset_doors): the band turns up in the lounge, seeing only the lounge.
## Nothing of this is kept: every visit begins the same.
static var _open := {}


static func reset_doors() -> void:
	_open.clear()


## A door open or shut, without asking (apply_doors after, for the plan).
static func set_open(id: String, on: bool) -> void:
	if on:
		_open[id] = true
	else:
		_open.erase(id)


static func is_open(id: String) -> bool:
	return _open.has(id)


## The ids of the doors that are open, in the order of DOORS.
static func open_doors() -> Array[String]:
	var out: Array[String] = []
	for d in DOORS:
		if _open.has(d.id):
			out.append(String(d.id))
	return out


## A door's data (id, rect, a, b), or empty if there is none by that id.
static func door(id: String) -> Dictionary:
	for d in DOORS:
		if d.id == id:
			return d
	return {}


## The tiles a door takes.
static func door_rect(id: String) -> Rect2i:
	var r: Array = door(id).get("rect", [0, 0, 0, 0])
	return Rect2i(r[0], r[1], r[2], r[3])


## The room a tile is in ("" in a doorway or a wall).
static func tile_room(t: Vector2i) -> String:
	return room_at(t.x + 0.5, t.y + 0.5)


## The rooms a point is in: its room; both sides of the door if it stands in
## a doorway; none in a wall or outside.
static func rooms_at(x: float, y: float) -> Array[String]:
	var out: Array[String] = []
	var room := room_at(x, y)
	if room != "":
		out.append(room)
		return out
	var t := Vector2i(int(floor(x)), int(floor(y)))
	for d in DOORS:
		if door_rect(d.id).has_point(t):
			out.append(String(d.a))
			out.append(String(d.b))
	return out


## The door a tile is next to (or in): one step from its tiles, not across
## a corner. Its id, or "" for none.
static func door_near(t: Vector2i) -> String:
	for d in DOORS:
		var r := door_rect(d.id)
		var dx := maxi(maxi(r.position.x - t.x, t.x - (r.end.x - 1)), 0)
		var dy := maxi(maxi(r.position.y - t.y, t.y - (r.end.y - 1)), 0)
		if dx + dy <= 1:
			return String(d.id)
	return ""


## Whether anyone (points: Vector2 positions in tiles) is in a door's way:
## on its tiles or with their body touching them (DOOR_CLEAR).
static func in_the_way(id: String, points: Array) -> bool:
	var r := door_rect(id)
	var box := Rect2(Vector2(r.position), Vector2(r.size)).grow(DOOR_CLEAR)
	for p in points:
		if box.has_point(p):
			return true
	return false


## Whether the door can be worked now: opened always; shut only with no one
## in its way.
static func can_toggle(id: String, points: Array) -> bool:
	if door(id).is_empty():
		return false
	return not is_open(id) or not in_the_way(id, points)


## Open a shut door or shut an open one (and the plan follows,
## apply_doors). False if it could not be (can_toggle).
static func toggle_door(id: String, points: Array) -> bool:
	if not can_toggle(id, points):
		return false
	if is_open(id):
		_open.erase(id)
	else:
		_open[id] = true
	apply_doors()
	return true


## The doors' state on the round's plan (Museum.grid): a shut door is wall,
## an open one floor. Cheap; called after the round is laid out and at every
## change.
static func apply_doors() -> void:
	if Museum.w != W or Museum.h != H or Museum.grid.size() != W * H:
		return
	for d in DOORS:
		var tile: int = Tiles.FLOOR if _open.has(d.id) else Tiles.WALL
		var r := door_rect(d.id)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				Museum.grid[y * W + x] = tile


## The rooms one sees: those with someone in (thief_rooms: room ids, "" for
## none) and, through every open door (open_doors: ids), the room on the
## other side of a room that is seen, and so on.
static func visible_rooms(open_ids: Array, thief_rooms: Array) -> Array[String]:
	var seen := {}
	for r in thief_rooms:
		if String(r) != "" and ROOMS.has(String(r)):
			seen[String(r)] = true
	var grew := true
	while grew:
		grew = false
		for d in DOORS:
			if not open_ids.has(d.id):
				continue
			if seen.has(d.a) != seen.has(d.b):
				seen[d.a] = true
				seen[d.b] = true
				grew = true
	var out: Array[String] = []
	for id in ORDER:
		if seen.has(id):
			out.append(id)
	return out


## The plan as rows of MapFile characters: walls, floor, and the furniture
## and the dojo's things as cover ("o").
static func rows(extra_cover: Array[Vector2i] = []) -> Array[String]:
	var g: Array = []
	for y in H:
		var row := []
		for x in W:
			row.append("#")
		g.append(row)
	for id in ORDER:
		var r := rect(id)
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				g[y][x] = "."
	# The dojo's inside walls (DOJO_PLAN).
	for j in DOJO_PLAN.size():
		for i in DOJO_PLAN[j].length():
			if DOJO_PLAN[j][i] == "#":
				g[DOJO_Y + j][DOJO_X + i] = "#"
	# The plan has every door open (the map is walkable end to end); a round
	# shuts them on Museum.grid (apply_doors).
	for d in DOORS:
		var o: Array = d.rect
		for y in range(o[1], o[1] + o[3]):
			for x in range(o[0], o[0] + o[2]):
				g[y][x] = "."
	for f in furniture():
		var b: Array = f.get("block", [])
		if b.is_empty():
			continue
		for y in range(b[1], b[1] + b[3]):
			for x in range(b[0], b[0] + b[2]):
				g[y][x] = "o"
	for t in extra_cover:
		g[t.y][t.x] = "o"
	var out: Array[String] = []
	for row in g:
		out.append("".join(row))
	return out


static func _f(model: String, x: float, y: float, face = 0.0, block: Array = [], scale := SCALE, lift := 0.0, extra := {}) -> Dictionary:
	# `face` is a yaw in degrees, or the side the front should look at (a
	# COMPASS key): then the yaw is worked out from the model's own front.
	var yaw: float = yaw_for(model, face) if face is String else float(face)
	var d := {"m": model, "at": Vector2(x, y), "yaw": yaw, "s": scale, "block": block, "lift": lift,
		"wall": "", "corner": "", "to": Vector2.ZERO}
	d.merge(extra, true)
	return d


## A piece against a wall (N, S, E or W: the side its back is to), its front
## looking into the room.
static func _w(model: String, x: float, y: float, wall: String, block: Array = [], scale := SCALE, lift := 0.0, extra := {}) -> Dictionary:
	var e := {"wall": wall}
	e.merge(extra, true)
	return _f(model, x, y, OPPOSITE[wall], block, scale, lift, e)


## A block of tiles that is cover but has nothing to draw (its pieces are
## drawn on top of it).
static func _cover(block: Array) -> Dictionary:
	return {"m": "", "at": Vector2(block[0] + block[2] / 2.0, block[1] + block[3] / 2.0), "yaw": 0.0, "s": 1, "block": block, "lift": 0.0,
		"wall": "", "corner": "", "to": Vector2.ZERO}


# --- Which way a piece looks -------------------------------------------------------------
## The compass, on the plan: x runs east, y runs south.
const COMPASS := {"N": Vector2(0, -1), "S": Vector2(0, 1), "E": Vector2(1, 0), "W": Vector2(-1, 0),
	"NE": Vector2(1, -1), "NW": Vector2(-1, -1), "SE": Vector2(1, 1), "SW": Vector2(-1, 1)}
const OPPOSITE := {"N": "S", "S": "N", "E": "W", "W": "E", "NE": "SW", "SW": "NE", "NW": "SE", "SE": "NW"}
## Where each model's front looks at yaw 0, seen on the plan. Kenney's
## furniture looks to +Z (south) but for the corner pieces, whose front is the
## diagonal the corner opens onto: the corner sofa's seat opens to the south
## east, the round shower's glass arc to the south west (its two walls are at
## the north east: the corner of the square is at +X, -Z of the model).
const FRONT := {"showerRound": "SW", "loungeSofaCorner": "SE"}
## The models that have a front worth checking (Den.audit): the rest (rugs,
## plants, lamps, stools, boxes...) look the same from every side.
const FRONTED := ["loungeSofa", "loungeSofaCorner", "loungeChair", "loungeChairRelax", "cabinetTelevisionDoors",
	"televisionModern", "kitchenCabinet", "kitchenSink", "kitchenStove", "kitchenFridge", "kitchenBar",
	"bookcaseOpen", "bookcaseOpenLow", "bookcaseClosedWide", "bathtub", "bathroomSink", "bathroomMirror",
	"bathroomCabinet", "toilet", "showerRound", "benchCushion", "coatRack", "temas/moderna/recreativa"]


static func compass(face: String) -> Vector2:
	return (COMPASS[face] as Vector2).normalized()


## The yaw, in degrees, that a model at rest looks at when its front goes to
## `face`.
static func yaw_for(model: String, face: String) -> float:
	var want: Vector2 = compass(face)
	var have: Vector2 = compass(FRONT.get(model, "S"))
	return wrapf(rad_to_deg(atan2(want.x, want.y) - atan2(have.x, have.y)), -180.0, 180.0)


## The way a model turned by `yaw` degrees looks on the plan (a unit vector).
static func facing(model: String, yaw: float) -> Vector2:
	var d: Vector2 = compass(FRONT.get(model, "S"))
	var a := deg_to_rad(yaw)
	return Vector2(d.x * cos(a) + d.y * sin(a), -d.x * sin(a) + d.y * cos(a)).normalized()


## How far a point is from the edge of its room, along a direction.
static func room_reach(at: Vector2, dir: Vector2) -> float:
	var id := room_at(at.x, at.y)
	if id == "":
		return 0.0
	var r := Rect2(rect(id))
	var t := INF
	if dir.x > 0.01:
		t = minf(t, (r.end.x - at.x) / dir.x)
	elif dir.x < -0.01:
		t = minf(t, (r.position.x - at.x) / dir.x)
	if dir.y > 0.01:
		t = minf(t, (r.end.y - at.y) / dir.y)
	elif dir.y < -0.01:
		t = minf(t, (r.position.y - at.y) / dir.y)
	return t


## The gap between a point and the wall of its room on one side (N, S, E, W).
static func wall_gap(at: Vector2, side: String) -> float:
	var id := room_at(at.x, at.y)
	if id == "":
		return 0.0
	var r := Rect2(rect(id))
	match side:
		"N": return at.y - r.position.y
		"S": return r.end.y - at.y
		"E": return r.end.x - at.x
		_: return at.x - r.position.x


## What is wrong with the way the furniture looks, one line each (empty when
## all is well): a front to a wall, a back not to the wall it says, a corner
## piece not in its corner, a seat not looking at the telly.
static func audit() -> Array[String]:
	var out: Array[String] = []
	for f in furniture():
		var model: String = f.m
		if not FRONTED.has(model):
			continue
		var at: Vector2 = f.at
		var dir := facing(model, f.yaw)
		var what := "%s en %s" % [model, at]
		if room_at(at.x, at.y) == "":
			out.append("%s: fuera de toda sala" % what)
			continue
		if room_reach(at, dir) < 0.9:
			out.append("%s: mira a la pared" % what)
		var wall: String = f.wall
		if wall != "":
			if dir.distance_to(-compass(wall)) > 0.01:
				out.append("%s: la espalda no está a la pared %s" % [what, wall])
			if wall_gap(at, wall) > 1.0:
				out.append("%s: lejos de la pared %s (%.2f)" % [what, wall, wall_gap(at, wall)])
		var corner: String = f.corner
		if corner != "":
			if dir.distance_to(-compass(corner)) > 0.01:
				out.append("%s: la esquina %s no está atrás" % [what, corner])
			for side in corner.split(""):
				if wall_gap(at, side) > 1.6:
					out.append("%s: lejos de la pared %s" % [what, side])
		var to: Vector2 = f.to
		if to != Vector2.ZERO and dir.dot((to - at).normalized()) < 0.7:
			out.append("%s: no mira a %s" % [what, to])
	return out


## Every piece of furniture: {m: the model in assets/models/casa, at: its
## middle in tiles, yaw: degrees (0 faces south, 90 east, 180 north, -90
## west; worked out from the side it looks at, `_f`), s: scale, lift: up, in
## the model's scaled units, block: [x, y, w, h] of the tiles it takes
## (cover), none for what one walks through or hangs on the wall; wall: the
## side of the room its back is to, corner: the corner its back is in, to:
## a spot its front looks at (all three checked by `audit`)}.
static func furniture() -> Array:
	if not _furniture.is_empty():
		return _furniture
	var f: Array = []
	# --- The lounge -----------------------------------------------------------
	# North wall: the arcade machine, the telly on its cabinet with a speaker at
	# one side, the way to the trophies and the kitchen. The sofa looks at the
	# telly over a rug and a coffee table, an armchair on each side.
	f.append(_w(Arcades.MODEL, 2.5, 10.5, "N", [2, 10, 1, 1], 1.05, 0.0, {"kind": "arcade"}))
	f.append(_f("pottedPlant", 1.5, 10.7, 0.0, [1, 10, 1, 1]))
	f.append(_w("cabinetTelevisionDoors", 5.5, 10.6, "N", [4, 10, 3, 1]))
	f.append(_w("televisionModern", 5.5, 10.6, "N", [], SCALE, 0.56))
	f.append(_f("speaker", 8.4, 10.6, "S"))
	f.append(_f("rugRectangle", 5.5, 14.5, 0, [], 2.7))
	f.append(_f("tableCoffee", 5.5, 14.5, 0, [4, 14, 3, 1]))
	f.append(_f("loungeSofa", 5.5, 17.4, "N", [4, 17, 3, 1], 2.0, 0.0, {"to": Vector2(5.5, 10.6)}))
	f.append(_f("pillow", 4.7, 17.45, "N", [], 1.8, 0.42))
	f.append(_f("pillowBlue", 6.3, 17.45, "N", [], 1.8, 0.42))
	f.append(_f("loungeChairRelax", 8.8, 14.5, "W", [8, 14, 1, 1], SCALE, 0.0, {"to": Vector2(5.5, 14.5)}))
	f.append(_f("loungeChair", 1.9, 14.5, "E", [1, 14, 1, 1], 2.0, 0.0, {"to": Vector2(5.5, 14.5)}))
	f.append(_f("lampRoundFloor", 2.0, 17.2))
	f.append(_f("sideTable", 8.6, 17.4, "N", [8, 17, 1, 1]))
	f.append(_f("lampSquareTable", 8.6, 17.4, 0, [], SCALE, 0.68))
	# West wall: a table with a lamp, a window with curtains (DenView), a
	# bookshelf wall.
	f.append(_f("sideTable", 1.32, 11.9, "E", [1, 11, 1, 2]))
	f.append(_f("lampRoundTable", 1.32, 11.9, 0, [], SCALE, 0.68))
	for i in 3:
		f.append(_w("bookcaseOpen", 1.32, 19.5 + i * 0.95, "W", [], 1.75))
	f.append(_cover([1, 19, 1, 3]))
	f.append(_f("books", 1.4, 22.4, 90, [], 2.4, 0.0))
	# The kitchen along the north wall: a run of units and the fridge.
	f.append(_w("kitchenCabinet", 11.5, 10.55, "N", [11, 10, 1, 1], 1.85))
	f.append(_w("kitchenSink", 12.5, 10.55, "N", [12, 10, 1, 1], 1.85))
	f.append(_w("kitchenCabinet", 13.5, 10.55, "N", [13, 10, 1, 1], 1.85))
	f.append(_w("kitchenStove", 14.5, 10.55, "N", [14, 10, 1, 1], 1.85))
	f.append(_w("kitchenCabinet", 15.5, 10.55, "N", [15, 10, 1, 1], 1.85))
	f.append(_w("kitchenCabinet", 16.5, 10.55, "N", [16, 10, 1, 1], 1.85))
	f.append(_w("kitchenFridge", 17.5, 10.6, "N", [17, 10, 1, 1], 1.85))
	f.append(_f("kitchenCoffeeMachine", 13.5, 10.5, "S", [], 1.85, 0.83))
	f.append(_f("toaster", 15.5, 10.5, "S", [], 1.85, 0.83))
	f.append(_f("kitchenMicrowave", 16.5, 10.5, "S", [], 1.85, 0.83))
	f.append(_f("pottedPlant", 18.7, 10.8))
	# The little bar, its cupboards to the cook and its stools to the lounge.
	for i in 4:
		f.append(_f("kitchenBar", 12.5 + i, 14.1, "N", [], 1.85))
	f.append(_f("kitchenBarEnd", 12.05, 14.1, "N", [], 1.85))
	f.append(_f("kitchenBarEnd", 16.5, 14.1, "N", [], 1.85))
	f.append(_cover([12, 14, 4, 1]))
	f.append(_f("radio", 15.3, 14.1, "S", [], 1.85, 0.78))
	for i in 4:
		f.append(_f("stoolBar", 12.5 + i, 15.2, 0, [], 1.85))
	f.append(_cover([12, 15, 4, 1]))
	# A second corner to lounge in, to the east.
	f.append(_f("rugRound", 17.5, 17.3, 0, [], 2.3))
	f.append(_f("loungeSofaCorner", 18.6, 21.6, "NW", [17, 20, 3, 3], 2.0, 0.0, {"corner": "SE"}))
	f.append(_f("tableCoffee", 16.3, 17.3, 0, [], 1.8))
	f.append(_f("pottedPlant", 18.9, 13.3, 0.0, [], 2.4))
	f.append(_w("bookcaseClosedWide", 19.7, 15.0, "E", [19, 14, 1, 2], 1.5))
	f.append(_f("cardboardBoxClosed", 12.2, 21.7, 20, [12, 21, 1, 1], 1.8))
	f.append(_f("cardboardBoxOpen", 13.2, 21.8, -15, [13, 21, 1, 1], 1.8))
	# The way in: a mat, a coat stand, a bench, a shoe rack and a plant.
	f.append(_f("rugDoormat", 10.0, 22.35, 0, [], 3.4))
	f.append(_f("coatRackStanding", 7.6, 22.2, 0, [], 2.0))
	f.append(_w("benchCushion", 6.3, 22.65, "S", [5, 22, 2, 1], 2.0))
	f.append(_w("bookcaseOpenLow", 12.5, 22.68, "S", [12, 22, 1, 1], 1.8))
	f.append(_f("pottedPlant", 14.6, 22.5))
	# --- The dojo -------------------------------------------------------------------
	# A home dojo: a shelf of practice kit, a bench, low cabinets to go round, a
	# punchbag and a few boxes. (The rest of what is in it, DojoTrials.TABLE and
	# Practice.ITEMS, comes with the lessons; the walls, DenView._dojo_walls.)
	f.append(_w("bookcaseOpen", 22.4, 1.3, "N", [], 1.6))
	f.append(_w("bookcaseOpen", 23.3, 1.3, "N", [], 1.6))
	f.append(_cover([22, 1, 2, 1]))
	f.append(_f("benchCushion", 23.0, 17.65, "N", [22, 17, 2, 1], 2.6))
	for i in 3:
		f.append(_f("bookcaseOpenLow", 22.5 + i, 8.5, "S", [], 1.8))
	f.append(_cover([22, 8, 3, 1]))
	f.append({"m": "", "at": Vector2(22.5, 10.5), "yaw": 0.0, "s": 1, "block": [22, 10, 1, 1], "lift": 0.0,
		"wall": "", "corner": "", "to": Vector2.ZERO, "kind": "sandbag"})
	f.append(_f("cardboardBoxClosed", 60.5, 11.6, -30, [60, 11, 1, 1], 1.6))
	f.append(_f("cardboardBoxClosed", 50.5, 16.5, 15, [50, 16, 1, 1], 1.7))
	f.append(_f("cardboardBoxOpen", 60.5, 16.5, -15, [60, 16, 1, 1], 1.7))
	f.append(_f("cardboardBoxClosed", 60.4, 16.5, 40, [], 1.4, 0.45))
	# The crates of the stealth circuit (to hide behind the torches' light).
	f.append(_f("cardboardBoxClosed", 27.5, 23.5, 20, [27, 23, 1, 1], 1.7))
	f.append(_f("cardboardBoxOpen", 25.5, 27.5, -25, [25, 27, 1, 1], 1.7))
	f.append(_f("cardboardBoxClosed", 30.5, 26.5, 35, [30, 26, 1, 1], 1.7))
	# --- The bathroom (south of the dojo, BATH_DY tiles below where it began) ------
	# A small room: the bath along the north wall on the west, the basin and
	# its mirror, the toilet in the north-east corner, the shower in the
	# south-east one with its glass arc to the room and its two walls to the
	# corner. The door (north, x 27-28) stays clear.
	var dy := float(BATH_DY)
	var iy := BATH_DY
	f.append(_w("bathtub", 22.5, 15.7 + dy, "N", [21, 15 + iy, 3, 2], 1.8))
	f.append(_w("bathroomSink", 25.7, 15.45 + dy, "N", [25, 15 + iy, 1, 1], 1.9))
	f.append(_w("bathroomMirror", 25.7, 15.2 + dy, "N", [], 2.0, 0.6))
	f.append(_w("toilet", 29.5, 15.8 + dy, "N", [29, 15 + iy, 1, 1], 1.8))
	f.append(_f("showerRound", 28.8, 20.8 + dy, "NW", [28, 20 + iy, 2, 2], 1.8, 0.0, {"corner": "SE"}))
	f.append(_f("rugRectangle", 24.5, 18.6 + dy, 0, [], 2.4))
	f.append(_f("rugDoormat", 22.3, 19.0 + dy, 0, [], 2.2))
	f.append(_f("trashcan", 26.7, 15.65 + dy, 0, [], 1.6))
	f.append(_w("coatRack", 21.12, 17.4 + dy, "W", [], 2.0, 0.55))
	f.append(_f("cardboardBoxOpen", 29.3, 18.0 + dy, 10, [], 1.5))
	f.append(_f("plantSmall1", 21.9, 21.5 + dy, 0, [], 3.0))
	f.append(_f("plantSmall2", 26.4, 21.5 + dy, 0, [], 3.0))
	f.append(_w("bathroomCabinet", 24.0, 21.68 + dy, "S", [], 2.0))
	# --- The trophy room: the stands (DenView draws them) and a little more ------
	for st in stands():
		f.append({"m": "", "at": Vector2(st.tile.x + 0.5, st.tile.y + 0.5), "yaw": 0.0, "s": 1, "lift": 0.0,
			"block": [st.tile.x, st.tile.y, 1, 1], "wall": "", "corner": "", "to": Vector2.ZERO})
	f.append(_f("benchCushion", 10.0, 6.5, "N", BENCH, 2.0))
	f.append(_f("benchCushion", 6.5, 7.5, "N", [6, 7, 1, 1], 2.4))
	f.append(_f("benchCushion", 14.5, 7.5, "N", [14, 7, 1, 1], 2.4))
	f.append(_f("lampRoundFloor", 4.0, 7.4))
	f.append(_f("lampRoundFloor", 16.0, 7.4))
	f.append(_f("pottedPlant", 1.7, 7.4))
	f.append(_f("pottedPlant", 18.4, 7.4))
	f.append(_f("rugDoormat", 10.0, 8.4, 0, [], 3.4))
	f.append(_f("rugDoormat", 19.55, 3.5, 90, [], 3.4))
	f.append(_w("sideTable", 19.4, 6.6, "E", [19, 6, 1, 1], 1.8))
	f.append(_f("lampRoundTable", 19.4, 6.6, 0, [], SCALE, 0.68))
	_furniture = f
	return _furniture


## The x of the first tile of museum m's section of the gallery.
static func section_x(m: int) -> int:
	return SECTION_X0 + m * SECTION_STEP


## Every stand of the gallery, heist by heist (25 of them, n = 1..25): {n: the
## heist, museum: 0-based, k: which of its five, kind: "niche" or "case",
## tile: where it stands}.
static func stands() -> Array:
	if not _stands.is_empty():
		return _stands
	for m in Story.MUSEUMS.size():
		for k in Story.ROOMS:
			var niche := k < NICHES
			var x := section_x(m) + (k if niche else (k - NICHES) * 2)
			_stands.append({"n": m * Story.ROOMS + k + 1, "museum": m, "k": k, "kind": "niche" if niche else "case",
				"tile": Vector2i(x, NICHES_Y if niche else CASE_Y)})
	return _stands


## Whether the piece of heist n is in its stand: the heist done with the piece
## out of the door (the star of taking it, STAR_TAKEN), for a band this size.
static func is_filled(n: int, players := 1) -> bool:
	return (Story.star_mask(n, players) & Story.STAR_TAKEN) != 0


## The heists whose stands are full, for a band this size (n, in order).
static func filled(players := 1) -> Array[int]:
	var out: Array[int] = []
	for st in stands():
		if is_filled(st.n, players):
			out.append(st.n)
	return out
