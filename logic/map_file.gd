class_name MapFile
extends RefCounted
## A museum drawn by hand (or generated and touched up in the editor) and
## saved to disk, for the challenges: the plan tile by tile, its galleries,
## where the thieves come in, the piece, the door, the guards, the things to
## knock over, and how hard the night is.
##
## On disk it is JSON with the plan as rows of characters (CHARS), so a map
## reads — and diffs — like a picture. check() says what would make it
## unplayable; apply() builds the live museum from it (Museum.load_grid), the
## same way the generator's museums are built.
##
## What is left unset — the piece, the door (NONE), the number of guards (0)
## — the job picks the way it does in a generated museum.

## The player's maps, and the ones that come with the game.
const FOLDER := "user://maps"
const BUILT_IN := "res://maps"
const FORMAT := 1
## A tile as a character; a space is no building at all.
const CHARS := {Tiles.FLOOR: ".", Tiles.WALL: "#", Tiles.COVER: "o"}
const OUT := " "
## No building, for put().
const OUT_TILE := -1
const NONE := Vector2i(-1, -1)
const MIN_SIDE := 9
const MAX_W := 61
const MAX_H := 45
const MAX_GUARDS := 5
## Out of the door you came in by is not a job: the door keeps this far off
## (as Heist does when it picks one).
const DOOR_FROM_START := 7
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The pieces a map can have stolen (LootModels.build).
const LOOT_SHAPES := ["gem", "teeth", "duck", "sock", "toast", "crown", "rock", "mask", "clock", "egg", "idol"]

var name := ""
var w := 23
var h := 17
## the museum's look (MuseumView's theme, the paintings) and its props
var seed := 0
## its floor and its walls (MuseumView.looks()); -1: from the seed
var floor_look := -1
var wall_look := -1
## a key of Sim.DIFFICULTIES
var difficulty := "medium"
## guards on the night; 0: one for each placed, or as the size says
var guard_count := 0
var grid := PackedInt32Array()
## 1 where there is no building
var outside := PackedByteArray()
## galleries: they get a light, a switch and a name
var rooms: Array[Rect2i] = []
## {"kind": a key of MapGen.BIG, "rect": Rect2i}, on case tiles
var big: Array[Dictionary] = []
var spawn := Vector2i(1, 1)
## the case with the piece in it, and the floor tile in front of the door
var piece := NONE
var exit := NONE
## what is stolen, and why, as its maker wrote it: shape (a LootModels
## shape), colour (hex), name, blurb, story, seconds to force the case.
## Empty: the job picks a piece, as in a generated museum.
var loot := {}
## what stands on a case, where chosen by hand: tile to a piece (Themes.is_piece:
## one of MuseumView.EXHIBITS or a theme's model)
var exhibits := {}
## where each guard starts, in order
var guards: Array[Vector2i] = []
## things to knock over, stood by hand: {"kind": a Props.KINDS, "at": Vector2i};
## none, and the game stands its own
var props: Array[Dictionary] = []
## where it was read from ("" if never saved), and whether it came with the game
var path := ""
var built_in := false


## An empty building: an outer wall round one big hall.
static func blank(width: int, height: int) -> MapFile:
	var m := MapFile.new()
	m.seed = randi() % 1000000
	m._resize_plan(width, height)
	for y in height:
		for x in width:
			var edge := x == 0 or y == 0 or x == width - 1 or y == height - 1
			m.grid[y * width + x] = Tiles.WALL if edge else Tiles.FLOOR
	m.spawn = Vector2i(1, height / 2)
	return m


## What the generator makes from this seed, as Museum.regenerate would build
## it (the same outline from the same seed), to play or to touch up.
static func generated(seed_: int, size: String = "small", outline: String = "") -> MapFile:
	var dims: Dictionary = Museum.SIZES[size]
	var rand := Mulberry32.new(seed_ ^ 0x5bd1e995)
	var shape := outline if outline != "" else MapGen.SHAPES[rand.below(MapGen.SHAPES.size())]
	var made := MapGen.generate(seed_, dims.w, dims.h, shape)
	var m := MapFile.new()
	m.seed = seed_
	m.w = made.w
	m.h = made.h
	m.grid = made.grid.duplicate()
	m.outside = made.outside.duplicate()
	m.rooms = made.rooms.duplicate()
	m.big = made.big.duplicate(true)
	m.spawn = made.spawn
	return m


func _resize_plan(width: int, height: int) -> void:
	w = width
	h = height
	grid = PackedInt32Array()
	grid.resize(w * h)
	grid.fill(Tiles.WALL)
	outside = PackedByteArray()
	outside.resize(w * h)


## The same map, as a new one (nothing about it is shared).
func copy() -> MapFile:
	var m := MapFile.from_dict(to_dict())
	m.path = path
	m.built_in = built_in
	return m


## The same map on a plan of another size: what fits inside the new outer
## wall stays, the rest goes.
func resized(width: int, height: int) -> MapFile:
	var m := MapFile.blank(width, height)
	m.name = name
	m.seed = seed
	m.difficulty = difficulty
	m.guard_count = guard_count
	m.floor_look = floor_look
	m.wall_look = wall_look
	m.path = path
	m.built_in = built_in
	var keep := Rect2i(1, 1, width - 2, height - 2)
	for y in range(1, mini(h, height - 1)):
		for x in range(1, mini(w, width - 1)):
			m.grid[y * width + x] = grid[y * w + x]
			m.outside[y * width + x] = outside[y * w + x]
	for r in rooms:
		var cut := r.intersection(keep)
		if cut.has_area():
			m.rooms.append(cut)
	for b in big:
		if keep.encloses(b.rect):
			m.big.append(b.duplicate())
	m.spawn = spawn if keep.has_point(spawn) else m.spawn
	m.piece = piece if keep.has_point(piece) else NONE
	m.exit = exit if keep.has_point(exit) else NONE
	for g in guards:
		if keep.has_point(g):
			m.guards.append(g)
	for p in props:
		if keep.has_point(p.at):
			m.props.append(p.duplicate())
	for t in exhibits:
		if keep.has_point(t):
			m.exhibits[t] = exhibits[t]
	return m


# --- Tiles -------------------------------------------------------------------

func inside(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < w and t.y < h


## Off the plan counts as wall.
func at(t: Vector2i) -> int:
	return grid[t.y * w + t.x] if inside(t) else Tiles.WALL


## Off the plan counts as outside too.
func is_out(t: Vector2i) -> bool:
	return not inside(t) or outside[t.y * w + t.x] == 1


## Put a tile down; OUT_TILE for no building. Whatever stood on it that no
## longer fits goes: a big piece off its cases, the piece off its case, a
## guard or a prop off the floor.
func put(t: Vector2i, tile: int) -> void:
	if not inside(t):
		return
	var i := t.y * w + t.x
	outside[i] = 1 if tile == OUT_TILE else 0
	grid[i] = Tiles.WALL if tile == OUT_TILE else tile
	if grid[i] != Tiles.COVER:
		exhibits.erase(t)
		big = big.filter(func(b): return not (b.rect as Rect2i).has_point(t))
		if piece == t:
			piece = NONE
	if grid[i] != Tiles.FLOOR:
		guards = guards.filter(func(g): return g != t)
		props = props.filter(func(p): return p.at != t)
		if exit == t:
			exit = NONE


## Where there is no building, worked out from the walls: wall that reaches
## the edge of the plan with no floor or case beside it (diagonals too). The
## wall a room touches is the building's; the mass beyond it is outside. So
## the editor only draws wall and floor, and the outline follows.
func derive_outside() -> void:
	outside.fill(0)
	var todo: Array[Vector2i] = []
	for y in h:
		for x in w:
			if x == 0 or y == 0 or x == w - 1 or y == h - 1:
				todo.append(Vector2i(x, y))
	while not todo.is_empty():
		var t: Vector2i = todo.pop_back()
		if not inside(t) or outside[t.y * w + t.x] == 1 or not _bare_wall(t):
			continue
		outside[t.y * w + t.x] = 1
		for d in DIRS:
			todo.append(t + d)


## Wall with nothing but wall (or the plan's edge) all round it.
func _bare_wall(t: Vector2i) -> bool:
	if at(t) != Tiles.WALL:
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if at(t + Vector2i(dx, dy)) != Tiles.WALL:
				return false
	return true


## Stamp a ready-made room down, its top left corner at `corner`: rows of
## characters as on disk, and 'D' and 'S' for the dinosaur's and the
## sarcophagus' cases, 'b' for a bust on its pedestal. Whatever was under it
## goes; the plan's own edge stays as it was. gallery: its inside is a room
## (a light, a switch, a name), not corridor.
func stamp(rows: Array, corner: Vector2i, gallery: bool) -> void:
	var area := Rect2i(corner, Vector2i(String(rows[0]).length(), rows.size()))
	var inner := area.grow(-1)
	rooms = rooms.filter(func(r): return not r.intersects(area))
	big = big.filter(func(b): return not (b.rect as Rect2i).intersects(area))
	props = props.filter(func(p): return not area.has_point(p.at))
	guards = guards.filter(func(g): return not area.has_point(g))
	for t in exhibits.keys():
		if area.has_point(t):
			exhibits.erase(t)
	var blocks := {}
	for y in area.size.y:
		for x in area.size.x:
			var t := corner + Vector2i(x, y)
			if t.x < 1 or t.y < 1 or t.x >= w - 1 or t.y >= h - 1:
				continue
			var c: String = String(rows[y])[x]
			match c:
				"#":
					put(t, Tiles.WALL)
				"o":
					put(t, Tiles.COVER)
				"D", "S":
					put(t, Tiles.COVER)
					var kind := "dinosaur" if c == "D" else "sarcophagus"
					blocks[kind] = (blocks[kind] as Rect2i).merge(Rect2i(t, Vector2i.ONE)) if blocks.has(kind) else Rect2i(t, Vector2i.ONE)
				"b":
					put(t, Tiles.FLOOR)
					props.append({"kind": "bust", "at": t})
				_:
					# A door in its border against the outer wall leads nowhere.
					var out := Vector2i(-1 if x == 0 else (1 if x == area.size.x - 1 else 0), -1 if y == 0 else (1 if y == area.size.y - 1 else 0))
					var n := t + out
					var blind := out != Vector2i.ZERO and (n.x < 1 or n.y < 1 or n.x >= w - 1 or n.y >= h - 1)
					put(t, Tiles.WALL if blind else Tiles.FLOOR)
	# A big piece cut short by the edge is only cases.
	for kind in blocks:
		var r: Rect2i = blocks[kind]
		var size: Vector2i = MapGen.BIG[kind]
		if r.size == size or r.size == Vector2i(size.y, size.x):
			big.append({"kind": kind, "rect": r})
	var room := inner.intersection(Rect2i(1, 1, w - 2, h - 2))
	if gallery and room.has_area():
		rooms.append(room)
	# The way in, if the room went down on top of it, to the nearest floor.
	if at(spawn) != Tiles.FLOOR:
		var best := INF
		for y in h:
			for x in w:
				var d := Vector2(x - spawn.x, y - spawn.y).length()
				if grid[y * w + x] == Tiles.FLOOR and d < best:
					best = d
					spawn = Vector2i(x, y)


## A big piece (MapGen.BIG) on its block of cases, `rect` its tiles: what
## was there goes. False, and nothing changes, if it would touch the outer
## wall.
func place_big(kind: String, rect: Rect2i) -> bool:
	if not Rect2i(1, 1, w - 2, h - 2).encloses(rect):
		return false
	big = big.filter(func(b): return not (b.rect as Rect2i).intersects(rect))
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			put(Vector2i(x, y), Tiles.COVER)
			exhibits.erase(Vector2i(x, y))
	big.append({"kind": kind, "rect": rect})
	return true


## The big piece on this tile, or an empty dictionary.
func big_at(t: Vector2i) -> Dictionary:
	for b in big:
		if (b.rect as Rect2i).has_point(t):
			return b
	return {}


## From a floor tile, the way through the outer wall (a wall with no building
## beyond it), or ZERO when it is not against one.
func door_face(t: Vector2i) -> Vector2i:
	if at(t) != Tiles.FLOOR:
		return Vector2i.ZERO
	for d in DIRS:
		if at(t + d) == Tiles.WALL and is_out(t + d * 2):
			return d
	return Vector2i.ZERO


## Floor right against the outer wall, where you come in from outside: as
## MapGen marks it (next to a tile of the footprint's edge).
func ring() -> PackedByteArray:
	var r := PackedByteArray()
	r.resize(w * h)
	for y in h:
		for x in w:
			if grid[y * w + x] != Tiles.FLOOR:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if not _interior(Vector2i(x + dx, y + dy)):
						r[y * w + x] = 1
	return r


## In the building with the building all round it.
func _interior(t: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_out(t + Vector2i(dx, dy)):
				return false
	return true


## Steps from a tile to every floor tile, walking; -1 where it cannot go.
func distances(from: Vector2i) -> PackedInt32Array:
	var d := PackedInt32Array()
	d.resize(w * h)
	d.fill(-1)
	if at(from) != Tiles.FLOOR:
		return d
	d[from.y * w + from.x] = 0
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for dir in DIRS:
			var n := c + dir
			if at(n) != Tiles.FLOOR or d[n.y * w + n.x] >= 0:
				continue
			d[n.y * w + n.x] = d[c.y * w + c.x] + 1
			queue.append(n)
	return d


## Cases the piece can be in: its own (not under a big piece), with floor
## beside it you can walk to.
func piece_spots(reach: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			if at(t) != Tiles.COVER or not big_at(t).is_empty():
				continue
			for d in DIRS:
				var s := t + d
				if at(s) == Tiles.FLOOR and reach[s.y * w + s.x] >= 0:
					out.append(t)
					break
	return out


## Floor tiles in front of a possible door: against the outer wall, walkable,
## and a fair way from where the thieves come in.
func door_spots(reach: PackedInt32Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in h:
		for x in w:
			var t := Vector2i(x, y)
			if reach[y * w + x] >= DOOR_FROM_START and door_face(t) != Vector2i.ZERO:
				out.append(t)
	return out


## What stops this map being played, as keys into Text (EDITOR_ERR_*); none,
## and it can be.
func check() -> Array[String]:
	var errors: Array[String] = []
	if w < MIN_SIDE or h < MIN_SIDE or w > MAX_W or h > MAX_H or grid.size() != w * h or outside.size() != w * h:
		errors.append("EDITOR_ERR_SIZE")
		return errors
	# Shut in: no floor or case on the edge of the plan or next to the outside
	# (diagonals too, as the generator keeps it).
	var open := false
	for y in h:
		for x in w:
			if grid[y * w + x] != Tiles.WALL and not _interior(Vector2i(x, y)):
				open = true
	if open:
		errors.append("EDITOR_ERR_OPEN")
	if at(spawn) != Tiles.FLOOR:
		errors.append("EDITOR_ERR_SPAWN")
		return errors
	# No closed spaces: every bit of floor can be walked to from the way in.
	var reach := distances(spawn)
	for i in w * h:
		if grid[i] == Tiles.FLOOR and reach[i] < 0:
			errors.append("EDITOR_ERR_CLOSED")
			break
	var spots := piece_spots(reach)
	if (piece != NONE and not spots.has(piece)) or spots.is_empty():
		errors.append("EDITOR_ERR_PIECE")
	if exit != NONE:
		if door_face(exit) == Vector2i.ZERO or reach[exit.y * w + exit.x] < 0:
			errors.append("EDITOR_ERR_EXIT")
	elif door_spots(reach).is_empty():
		errors.append("EDITOR_ERR_EXIT")
	for g in guards:
		if at(g) != Tiles.FLOOR or reach[g.y * w + g.x] < 0:
			errors.append("EDITOR_ERR_GUARD")
			break
	if guards.size() > MAX_GUARDS or guard_count > MAX_GUARDS:
		errors.append("EDITOR_ERR_GUARDS")
	for b in big:
		var r: Rect2i = b.rect
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if at(Vector2i(x, y)) != Tiles.COVER and not errors.has("EDITOR_ERR_BIG"):
					errors.append("EDITOR_ERR_BIG")
	return errors


# --- Playing it ----------------------------------------------------------------

## The size it plays as, for what goes by size: the smallest it fits in.
func size_name() -> String:
	for k in ["small", "medium"]:
		if w * h <= int(Museum.SIZES[k].w) * int(Museum.SIZES[k].h):
			return k
	return "large"


## How many guards tonight: as set, else one for each placed, else what the
## difficulty or the size gives a generated museum.
func guards_tonight() -> int:
	if guard_count > 0:
		return guard_count
	if not guards.is_empty():
		return guards.size()
	var fixed := int(Sim.DIFFICULTIES[difficulty].guards)
	return fixed if fixed > 0 else int(Museum.SIZES[size_name()].guards)


## The night's settings, for Sim.custom: the difficulty, and the guards.
func tuning() -> Dictionary:
	var t: Dictionary = Sim.DIFFICULTIES[difficulty].duplicate()
	t.guards = guards_tonight()
	return t


## What the job keeps as the map says (Heist.plan_job): the piece and the door.
func job() -> Dictionary:
	var fixed := {}
	if piece != NONE:
		fixed.at = piece
	if exit != NONE:
		fixed.exit = exit
	return fixed


## Its floor and walls for MuseumView.palette; empty (from the seed) when
## neither is chosen, and the seed's style for the one that is not.
func palette() -> Dictionary:
	if floor_look < 0 and wall_look < 0:
		return {}
	var own := posmod(seed, MuseumView.THEMES.size())
	return MuseumView.mix(floor_look if floor_look >= 0 else own, wall_look if wall_look >= 0 else own)


## The piece for Heist.plan_job, as a story night's loot: what the maker
## wrote, with the words it did not; empty when it left it to the game.
func loot_piece() -> Dictionary:
	if loot.is_empty():
		return {}
	var name_: String = loot.name if loot.name != "" else Text.t("EDITOR_SHAPE_" + String(loot.shape).to_upper()).to_lower()
	return {"name": name_, "blurb": loot.blurb, "verb": Text.t("EDITOR_LOOT_VERB"), "seconds": loot.seconds,
		"colour": loot.colour, "shape": loot.shape, "story": loot.story}


## Make this the museum being played.
func apply() -> void:
	var rand := Mulberry32.new(seed ^ 0x5bd1e995)
	# Museum.regenerate draws the outline first: so do we, and a generated
	# map keeps its galleries' names.
	rand.next()
	Museum.shape = "custom"
	Museum.size_name = size_name()
	var big_copy: Array[Dictionary] = []
	for b in big:
		big_copy.append(b.duplicate())
	Museum.load_grid(seed, w, h, grid.duplicate(), outside.duplicate(), ring(), spawn, big_copy, rooms.duplicate(), rand)


## Stand the map's props, if it has any: true when it did.
func put_props() -> bool:
	if props.is_empty():
		return false
	Props.list.clear()
	Props.knocked.clear()
	for p in props:
		Props.put(p.kind, p.at)
	return true


# --- On disk -------------------------------------------------------------------

func to_dict() -> Dictionary:
	var rows: Array[String] = []
	for y in h:
		var row := ""
		for x in w:
			row += OUT if outside[y * w + x] == 1 else CHARS[grid[y * w + x]]
		rows.append(row)
	var pair := func(t: Vector2i) -> Array: return [t.x, t.y]
	var rect := func(r: Rect2i) -> Array: return [r.position.x, r.position.y, r.size.x, r.size.y]
	return {
		"format": FORMAT,
		"name": name,
		"seed": seed,
		"difficulty": difficulty,
		"guard_count": guard_count,
		"floor_look": floor_look,
		"wall_look": wall_look,
		"rows": rows,
		"rooms": rooms.map(rect),
		"big": big.map(func(b): return {"kind": b.kind, "rect": rect.call(b.rect)}),
		"spawn": pair.call(spawn),
		"piece": pair.call(piece),
		"exit": pair.call(exit),
		"guards": guards.map(pair),
		"props": props.map(func(p): return {"kind": p.kind, "at": pair.call(p.at)}),
		"loot": loot,
		"exhibits": exhibits.keys().map(func(t): return {"kind": exhibits[t], "at": pair.call(t)}),
	}


## A map from its JSON, or null if it is not one.
static func from_dict(d: Variant) -> MapFile:
	if not (d is Dictionary) or not (d.get("rows") is Array) or (d.rows as Array).is_empty():
		return null
	var rows: Array = d.rows
	var m := MapFile.new()
	m._resize_plan(String(rows[0]).length(), rows.size())
	for y in m.h:
		var row := String(rows[y])
		for x in m.w:
			var c := row[x] if x < row.length() else OUT
			m.outside[y * m.w + x] = 1 if c == OUT else 0
			m.grid[y * m.w + x] = Tiles.FLOOR if c == "." else (Tiles.COVER if c == "o" else Tiles.WALL)
	var pair := func(v: Variant) -> Vector2i:
		return Vector2i(int(v[0]), int(v[1])) if v is Array and (v as Array).size() == 2 else NONE
	var rect := func(v: Variant) -> Rect2i:
		return Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3])) if v is Array and (v as Array).size() == 4 else Rect2i()
	m.name = String(d.get("name", ""))
	m.seed = int(d.get("seed", 0))
	m.difficulty = String(d.get("difficulty", "medium"))
	if not Sim.DIFFICULTIES.has(m.difficulty):
		m.difficulty = "medium"
	m.guard_count = int(d.get("guard_count", 0))
	var n := MuseumView.looks().size()
	m.floor_look = clampi(int(d.get("floor_look", -1)), -1, n - 1)
	m.wall_look = clampi(int(d.get("wall_look", -1)), -1, n - 1)
	for r in d.get("rooms", []):
		m.rooms.append(rect.call(r))
	for b in d.get("big", []):
		if b is Dictionary and MapGen.BIG.has(b.get("kind", "")):
			m.big.append({"kind": String(b.kind), "rect": rect.call(b.get("rect"))})
	m.spawn = pair.call(d.get("spawn"))
	m.piece = pair.call(d.get("piece"))
	m.exit = pair.call(d.get("exit"))
	for g in d.get("guards", []):
		m.guards.append(pair.call(g))
	for p in d.get("props", []):
		if p is Dictionary and Props.KINDS.has(p.get("kind", "")):
			m.props.append({"kind": String(p.kind), "at": pair.call(p.get("at"))})
	var l: Variant = d.get("loot", {})
	if l is Dictionary and LOOT_SHAPES.has(l.get("shape", "")):
		m.loot = {"shape": String(l.shape), "colour": String(l.get("colour", "#f0c46a")), "name": String(l.get("name", "")),
			"blurb": String(l.get("blurb", "")), "story": String(l.get("story", "")), "seconds": clampf(float(l.get("seconds", 3.0)), 0.5, 10.0)}
	for e in d.get("exhibits", []):
		if e is Dictionary and Themes.is_piece(String(e.get("kind", ""))):
			var t: Vector2i = pair.call(e.get("at"))
			if m.inside(t) and m.at(t) == Tiles.COVER:
				m.exhibits[t] = String(e.kind)
	return m


static func read(file: String) -> MapFile:
	var m := from_dict(JSON.parse_string(FileAccess.get_file_as_string(file)))
	if m:
		m.path = file
		m.built_in = file.begins_with(BUILT_IN)
	return m


## A file name from the map's name: "La cripta" → la_cripta.
static func slug(text: String) -> String:
	var out := ""
	var plain := {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n", "ç": "c"}
	for c in text.to_lower().strip_edges():
		c = plain.get(c, c)
		out += c if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") else "_"
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.trim_prefix("_").trim_suffix("_")
	return out if out != "" else "mapa"


## Write it to the player's maps, under its name. A map from the game, once
## changed, is saved as the player's own.
func save() -> Error:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	var file := "%s/%s.json" % [FOLDER, slug(name)]
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(to_dict(), "\t"))
	f.close()
	# Renamed: the old file goes.
	if path != "" and path != file and not built_in:
		DirAccess.remove_absolute(path)
	path = file
	built_in = false
	return OK


## The maps there are: the game's first, then the player's, each by name.
static func list() -> Array[MapFile]:
	var out: Array[MapFile] = []
	for folder in [BUILT_IN, FOLDER]:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		var files := Array(DirAccess.get_files_at(folder))
		files.sort()
		for f in files:
			if f.ends_with(".json"):
				var m := read("%s/%s" % [folder, f])
				if m:
					out.append(m)
	return out


static func remove(m: MapFile) -> void:
	if m.path != "" and not m.built_in:
		DirAccess.remove_absolute(m.path)
