class_name DojoField
extends RefCounted
## The dojo as ground for its games (DojoGames): which tiles can be walked,
## which are good places to put something on (an object, a pin, a
## pedestal's round), how far each is on foot from another, and what zone and
## what door lies between. Pure logic, no nodes; the games ask it for spots.
##
## A valid spot is floor with all eight neighbours free of wall and cover
## (nothing hides it, nobody gets stuck round it), and at least MIN_AWAY tiles
## from where the last one was. `from_den` reads the real dojo (Den), as far
## as Den says what its zones and doors are; `from_map` takes any map, and
## the tests a made-up one.

## A spot is at least this far (a straight line, in tiles) from the last one.
const MIN_AWAY := 2.0
## A maze spot has a way at least this many times its straight line.
const MAZE_RATIO := 1.6
## The zone that stands for the whole dojo when Den does not name its zones,
## and the zones that count as it when it does (the mats are the first room).
const DEFAULT_ZONE := "tatami"
const ALIASES := {"tatami": ["tatami", "exposicion"]}
## Spots avoided keep this far (a chessboard distance) from a new one.
const AVOID := 3
## Tries a pick may take, from the exact ask to anything at all.
const LADDER := 7
## A scarecrow sees like Practice's (its numbers are the default of a scarecrow
## given without them): this far, this much either side of where it looks,
## from its torch, which is this far in front of its post.
const SC_RANGE := 5.5
const SC_ANGLE := 0.42
const SC_TORCH := 0.55

var w := 0
var h := 0
var region := Rect2i()
## 1 where there is floor in the region
var floor_tiles := PackedByteArray()
## 1 where a spot may be
var clear := PackedByteArray()
## the zone of each tile of the region ("" outside)
var zones := PackedStringArray()
## the doors that shut: [{id: String, rect: Rect2i}]
var gates: Array[Dictionary] = []
## the guards' scarecrows: [{id, tile, facing, range, angle}] (set_scarecrows)
var scarecrows: Array[Dictionary] = []
var _cache := {}
var _cones := {}


## The field of a map: the floor inside `region`, its zones (zone_at: a
## Callable(Vector2i) -> String; invalid: all DEFAULT_ZONE) and the doors that
## can be shut (gates: [{id, rect}], a rect being a Rect2i or [x, y, w, h]).
static func from_map(m: MapFile, region_: Rect2i, zone_at: Callable, gates_: Array) -> DojoField:
	var f := DojoField.new()
	f.w = m.w
	f.h = m.h
	f.region = region_
	f.floor_tiles.resize(f.w * f.h)
	f.clear.resize(f.w * f.h)
	f.zones.resize(f.w * f.h)
	for y in f.h:
		for x in f.w:
			var t := Vector2i(x, y)
			if not region_.has_point(t) or m.at(t) != Tiles.FLOOR:
				continue
			var i := y * f.w + x
			f.floor_tiles[i] = 1
			var z := DEFAULT_ZONE
			if zone_at.is_valid():
				z = String(zone_at.call(t))
				if z == "":
					z = DEFAULT_ZONE
			f.zones[i] = z
			var ok := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var n := m.at(t + Vector2i(dx, dy))
					if n == Tiles.WALL or n == Tiles.COVER:
						ok = false
			f.clear[i] = 1 if ok else 0
	for g in gates_:
		var r := _rect_of(g.get("rect", g) if g is Dictionary else g)
		var id := String(g.get("id", "gate%d" % f.gates.size())) if g is Dictionary else "gate%d" % f.gates.size()
		if r.size.x > 0 and r.size.y > 0:
			f.gates.append({"id": id, "rect": r})
	return f


static func _rect_of(v: Variant) -> Rect2i:
	if v is Rect2i:
		return v
	if v is Rect2:
		return Rect2i(v)
	if v is Array and v.size() >= 4:
		return Rect2i(int(v[0]), int(v[1]), int(v[2]), int(v[3]))
	return Rect2i()


## The band's dojo, as Den has it today: its zones (Den.dojo_zone_at, or
## Den.DOJO_ZONES, or the whole dojo as mats) and its doors that shut
## (Den.dojo_gates, or none). Everything asked with care: Den is changing.
static func from_den(m: MapFile) -> DojoField:
	var region_ := _den_region()
	var zone_at := Callable()
	if _den_has("dojo_zone_at"):
		var den: Object = Den
		zone_at = Callable(den, "dojo_zone_at")
	else:
		var consts := (Den as GDScript).get_script_constant_map()
		if consts.has("DOJO_ZONES"):
			zone_at = func(t: Vector2i) -> String:
				var named: Dictionary = consts["DOJO_ZONES"]
				for id in named:
					var r: Array = named[id]
					if Rect2i(r[0], r[1], r[2], r[3]).has_point(t):
						return String(id)
				return DEFAULT_ZONE
	var gates_: Array = []
	if _den_has("dojo_gates"):
		var den2: Object = Den
		gates_ = den2.call("dojo_gates")
	return from_map(m, region_, zone_at, gates_)


static func _den_has(method: String) -> bool:
	for d in (Den as GDScript).get_script_method_list():
		if d.name == method:
			return true
	return false


## The dojo's rect: Den.dojo_rect() if there is one, else the union of its
## zones, else its room.
static func _den_region() -> Rect2i:
	if _den_has("dojo_rect"):
		var den: Object = Den
		return Rect2i(den.call("dojo_rect"))
	var consts := (Den as GDScript).get_script_constant_map()
	if consts.has("DOJO_ZONES"):
		var all := Rect2i()
		var first := true
		for id in consts["DOJO_ZONES"]:
			var r: Array = consts["DOJO_ZONES"][id]
			var rr := Rect2i(r[0], r[1], r[2], r[3])
			all = rr if first else all.merge(rr)
			first = false
		if not first:
			return all
	return Den.rect("dojo")


# --- Ground ---------------------------------------------------------------------------------

func has_floor(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < w and t.y < h and floor_tiles[t.y * w + t.x] == 1


func is_clear(t: Vector2i) -> bool:
	return has_floor(t) and clear[t.y * w + t.x] == 1


func zone_of(t: Vector2i) -> String:
	if not has_floor(t):
		return ""
	return zones[t.y * w + t.x]


## The centre of a tile, in tiles.
static func center(t: Vector2i) -> Vector2:
	return Vector2(t.x + 0.5, t.y + 0.5)


static func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x)), int(floor(p.y)))


## The gate with this id, or {}.
func gate(id: String) -> Dictionary:
	for g in gates:
		if g.id == id:
			return g
	return {}


## The floor tile nearest to t (t itself if it is floor), or t if there is none.
func nearest_floor(t: Vector2i) -> Vector2i:
	if has_floor(t):
		return t
	for r in range(1, maxi(w, h)):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := t + Vector2i(dx, dy)
				if has_floor(n):
					return n
	return t


## Steps on foot from a tile to every floor tile of the region, over floor
## only, four ways; -1 where there is no way. `shut`: ids of doors taken as
## wall (or ["*"] for all); `dodge`: ids of scarecrows whose cones are taken
## as wall too (["*"] for all), except the tile it starts on. Kept: the games
## ask it over and over.
func dist(from: Vector2i, shut: Array = [], dodge: Array = []) -> PackedInt32Array:
	var key := "%d,%d|%s|%s" % [from.x, from.y, ",".join(PackedStringArray(shut.map(func(s): return String(s)))),
		",".join(PackedStringArray(dodge.map(func(s): return String(s))))]
	if _cache.has(key):
		return _cache[key]
	if _cache.size() > 160:
		_cache.clear()
	var blocked := PackedByteArray()
	blocked.resize(w * h)
	for g in gates:
		if shut.has("*") or shut.has(g.id):
			var r: Rect2i = g.rect
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if x >= 0 and y >= 0 and x < w and y < h:
						blocked[y * w + x] = 1
	for sc in scarecrows:
		if dodge.has("*") or dodge.has(sc.id):
			var cone_ := cone(sc.id)
			for i in blocked.size():
				if cone_[i] == 1:
					blocked[i] = 1
	var d := PackedInt32Array()
	d.resize(w * h)
	d.fill(-1)
	var start := nearest_floor(from)
	if has_floor(start):
		blocked[start.y * w + start.x] = 0
		d[start.y * w + start.x] = 0
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var c := queue[head]
			head += 1
			for dir in MapFile.DIRS:
				var n := c + dir
				if not has_floor(n):
					continue
				var i := n.y * w + n.x
				if d[i] >= 0 or blocked[i] == 1:
					continue
				d[i] = d[c.y * w + c.x] + 1
				queue.append(n)
	_cache[key] = d
	return d


## The tiles to walk from one tile to another (not the first, the last being
## `to`), over floor, the shortest way; empty if there is none or it is the same.
func path(from: Vector2i, to: Vector2i, shut: Array = []) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var d := dist(to, shut)
	var c := nearest_floor(from)
	if d[c.y * w + c.x] < 0:
		return out
	while d[c.y * w + c.x] > 0:
		var best := c
		for dir in MapFile.DIRS:
			var n := c + dir
			if has_floor(n) and d[n.y * w + n.x] >= 0 and d[n.y * w + n.x] < d[best.y * w + best.x]:
				best = n
		if best == c:
			break
		c = best
		out.append(c)
	return out


# --- The scarecrows ----------------------------------------------------------------------

## The dojo's scarecrows: [{id, tile (or at), facing (or dir; radians on the
## plan, 0 east, PI/2 south), range, angle}]. The ones Practice.scarecrows has
## open, or made-up ones in the tests. What they see is worked out on the
## field's own floor (sees), or by the rule the games are given (DojoGame.seen).
func set_scarecrows(list: Array) -> void:
	scarecrows.clear()
	_cones.clear()
	_cache.clear()
	for s in list:
		var d: Dictionary = s
		var at: Vector2i = d.get("tile", d.get("at", Vector2i.ZERO))
		scarecrows.append({"id": String(d.get("id", "sc%d" % scarecrows.size())), "tile": at,
			"facing": float(d.get("facing", d.get("dir", 0.0))), "range": float(d.get("range", SC_RANGE)),
			"angle": float(d.get("angle", SC_ANGLE))})


func scarecrow(id: String) -> Dictionary:
	for s in scarecrows:
		if s.id == id:
			return s
	return {}


## Where its torch is, in tiles.
static func torch_of(sc: Dictionary) -> Vector2:
	return center(sc.tile) + Vector2.from_angle(float(sc.facing)) * SC_TORCH


## The default rule of sight: within its range and its angle either side of
## where it looks, with only floor in between; not a thief hiding.
func sees(sc: Dictionary, pos: Vector2, hidden := false) -> bool:
	if hidden:
		return false
	var from := torch_of(sc)
	var dist_ := from.distance_to(pos)
	if dist_ > float(sc.range):
		return false
	if dist_ > 0.3 and absf(wrapf((pos - from).angle() - float(sc.facing), -PI, PI)) > float(sc.angle):
		return false
	var steps := int(ceil(dist_ / 0.25))
	for i in range(1, steps + 1):
		if not has_floor(tile_of(from.lerp(pos, float(i) / steps))):
			return false
	return true


## The tiles a scarecrow sees (1 where it does; its centre of the tile).
func cone(id: String) -> PackedByteArray:
	if _cones.has(id):
		return _cones[id]
	var mask := PackedByteArray()
	mask.resize(w * h)
	var sc := scarecrow(id)
	if not sc.is_empty():
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				var t := Vector2i(x, y)
				if has_floor(t) and sees(sc, center(t)):
					mask[y * w + x] = 1
	_cones[id] = mask
	return mask


## The ids of the scarecrows that see a tile, in order.
func watchers(t: Vector2i) -> Array[String]:
	var out: Array[String] = []
	if not has_floor(t):
		return out
	for sc in scarecrows:
		if cone(sc.id)[t.y * w + t.x] == 1:
			out.append(sc.id)
	return out


## Whether a scarecrow sees the tile: the id of the first that does, or "".
func watched_by(t: Vector2i) -> String:
	var found := watchers(t)
	return found[0] if not found.is_empty() else ""


## The scarecrows whose cones a way (tiles, as `path` gives it) crosses.
func crossed(way: Array[Vector2i]) -> Array[String]:
	var out: Array[String] = []
	for t in way:
		for id in watchers(t):
			if not out.has(id):
				out.append(id)
	return out


func _zone_ok(z: String, want: Array) -> bool:
	if want.is_empty():
		return true
	for name in want:
		if z == name or (ALIASES.has(name) and ALIASES[name].has(z)):
			return true
	return false


## The spots where something may go, for something that was at `from`:
## [{tile, zone, gate, path, time_path, watchers, cross, forced}] in the reading
## order of the plan.
##   zones  the zones allowed (empty: any); "tatami" is also the exposicion
##   dmin, dmax  steps on foot from `from` (path) it may be
##   opts   maze: the way at least MAZE_RATIO times the straight line;
##          gate: only spots that a shut door cuts off from `from`
##          (reachable with the plan open, not with that door shut);
##          watched: only spots seen by a scarecrow, or whose shortest way
##          crosses a cone; watched_min: how many different scarecrows it must
##          be seen by or cross (default 1);
##          avoid: tiles to keep AVOID from; shut: doors taken as shut for
##          the way there (ids)
## `gate` is the id of the door that cuts it off ("" for none); `watchers` the
## scarecrows that see the spot itself; `cross` those it has (the spot's or
## its shortest way's); `time_path` the steps to count the time by: the
## shortest way that keeps out of every cone in `cross`, or, when there is
## none (`forced`: the spot is in a cone, or behind one with no way round), the
## shortest way.
func candidates(from: Vector2i, zones_: Array, dmin: float, dmax: float, opts: Dictionary = {}) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var start := nearest_floor(from)
	var shut: Array = opts.get("shut", [])
	var d := dist(start, shut)
	var cut := {}
	for g in gates:
		cut[g.id] = dist(start, [g.id])
	var avoid: Array = opts.get("avoid", [])
	var want_watch: bool = opts.get("watched", false)
	var min_watch := int(opts.get("watched_min", 1))
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var t := Vector2i(x, y)
			if not has_floor(t):
				continue
			var i := y * w + x
			if clear[i] == 0 or d[i] < 0:
				continue
			var p: int = d[i]
			if p < dmin or p > dmax:
				continue
			if Vector2(start).distance_to(Vector2(t)) < MIN_AWAY:
				continue
			var z := zones[i]
			if not _zone_ok(z, zones_):
				continue
			if opts.get("maze", false) and float(p) < MAZE_RATIO * Vector2(start).distance_to(Vector2(t)):
				continue
			var near := false
			for a in avoid:
				if maxi(absi(a.x - x), absi(a.y - y)) < AVOID:
					near = true
					break
			if near:
				continue
			var gid := ""
			for g in gates:
				if cut[g.id][i] < 0:
					gid = g.id
					break
			if opts.get("gate", false) and gid == "":
				continue
			var inside := watchers(t)
			var cross_: Array[String] = []
			var forced := false
			var tp := p
			if want_watch:
				if scarecrows.is_empty():
					continue
				cross_ = inside.duplicate()
				for id in crossed(path(start, t, shut)):
					if not cross_.has(id):
						cross_.append(id)
				if cross_.size() < min_watch:
					continue
				if inside.is_empty():
					var round_ := dist(start, shut, cross_)[i]
					if round_ >= 0:
						tp = round_
					else:
						forced = true
				else:
					forced = true
			out.append({"tile": t, "zone": z, "gate": gid, "path": p, "time_path": tp, "watchers": inside,
				"cross": cross_, "forced": forced})
	return out


## One of them, chosen with `rng` (Mulberry32), easing the ask when there is
## none: without keeping off scarecrows used last (opts.prefer_not: ids, a
## preference, not a rule), without the door, with only one scarecrow, without
## scarecrows, without the maze, any zone, a wider reach, any reach, without
## keeping off `avoid`, and at last any floor at all. The result has
## "relaxed": how many easings it took (0: as asked). Empty only if the field
## has no floor.
func pick(from: Vector2i, zones_: Array, dmin: float, dmax: float, opts: Dictionary, rng: Mulberry32) -> Dictionary:
	var o := opts.duplicate()
	var tries: Array = [[zones_, dmin, dmax, o.duplicate()]]
	if o.has("prefer_not"):
		o.erase("prefer_not")
		tries.append([zones_, dmin, dmax, o.duplicate()])
	if o.has("gate"):
		o.erase("gate")
		tries.append([zones_, dmin, dmax, o.duplicate()])
	if o.get("watched_min", 1) > 1:
		o["watched_min"] = 1
		tries.append([zones_, dmin, dmax, o.duplicate()])
	if o.has("watched"):
		o.erase("watched")
		o.erase("watched_min")
		tries.append([zones_, dmin, dmax, o.duplicate()])
	if o.has("maze"):
		o.erase("maze")
		tries.append([zones_, dmin, dmax, o.duplicate()])
	tries.append([[], dmin, dmax, o.duplicate()])
	tries.append([[], minf(dmin, 2.0), dmax * 1.5 + 2.0, o.duplicate()])
	tries.append([[], 0.0, 9999.0, o.duplicate()])
	var o4 := o.duplicate()
	o4.erase("avoid")
	tries.append([[], 0.0, 9999.0, o4])
	for i in tries.size():
		var t: Array = tries[i]
		var list := candidates(from, t[0], t[1], t[2], t[3])
		if t[3].has("prefer_not"):
			var fresh := list.filter(func(c: Dictionary) -> bool:
				return not (t[3].prefer_not as Array).any(func(id) -> bool: return c.cross.has(id) or c.watchers.has(id)))
			if not fresh.is_empty():
				list = fresh
		if not list.is_empty():
			var c: Dictionary = list[rng.below(list.size())].duplicate()
			c["relaxed"] = i
			return c
	# No spot with room round it: any floor away from where it was.
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if has_floor(Vector2i(x, y)) and Vector2(x, y).distance_to(Vector2(from)) >= MIN_AWAY:
				var pp := maxi(0, dist(from)[y * w + x])
				return {"tile": Vector2i(x, y), "zone": zones[y * w + x], "gate": "", "path": pp, "time_path": pp,
					"watchers": [], "cross": [], "forced": false, "relaxed": tries.size()}
	return {}


## Every spot of the field (clear tiles), for the tests.
func all_clear() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if is_clear(Vector2i(x, y)):
				out.append(Vector2i(x, y))
	return out
