class_name TownBuilder
extends RefCounted
## The town round the museums (CityStage), far bigger than the screen, the
## camera gliding over it from one museum to the next. Not one grid: a
## river crosses it on the slant, winding in wide bends (river_at), and
## splits it into districts, two on either bank, each cut into patches
## (District), each its own grid of streets: the museum's patch square to
## its district, the next turned a little, the one past that square again,
## meeting on roads at an angle with small squares between; between them and along the water, woods
## and grass, and houses and chalets of their own, each its own way (loose
## houses). The far bank stands higher (RISE), up a wooded slope from the
## water, and rolls on up in low hills, its blocks on terraces; to the north
## rises a hill of great rocks the districts go round, and there are more
## rocky outcrops about (OUTCROPS); a couple of bridges (bridges) are the
## only ways across. Along the near bank, a riverside walk with its lamps and benches,
## and a sports ground (pitches and courts under their floodlights).
##
## Night light, cheap: no lights at all but the stage's own; every lamp,
## lit house, pool and floodlight casts a pool of light on the ground drawn
## as a flat quad added onto whatever is under it (POOL_SHADER), all of
## them one MultiMesh.
##
## Inside a district: streets with their pavements and crossings, and
## between them blocks of buildings from Kenney's city kits (CC0: City Kit
## Commercial, Suburban and Roads, in assets/models/ciudad): shops and
## offices round the museums, tall ones at the back of the high town,
## houses with gardens further out, a park now and then, street lamps at
## the corners. All at night: the kits' own colours in the violet of the
## town at night, the windows lit warm here and there, the lamps glowing
## (NIGHT_SHADER). Everything of one model goes in one MultiMesh, so the
## whole town is a few dozen draws.
##
## The plan: x across, z towards the viewer, in the town's units (TILE a
## tile, a road's width). A district's grid is in tiles: a street every
## PITCH tiles each way, BLOCK tiles of block between. The river and the
## districts are laid out along `along` (the way the river runs) and `up`
## (towards the far, high bank): s along, q up (frame()).

const KITS := "res://assets/models/ciudad/"
## A tile, in the town's units; a street every PITCH tiles, BLOCK of block.
const TILE := 1.4
const PITCH := 5
const BLOCK := 4
## How far the town goes from its middle each way: the camera never sees
## past it, up to 21:9 and the safe margin (tools/city_view.gd checks it);
## of all this only what can be seen is built (seen).
const REACH := 76.0
## The ground is kept or left out (seen) in square patches this many of its
## squares a side.
const TERRAIN_PATCH := 4

## The river: how wide the water, how wide and how long its bends (their
## sideways reach, and the length of one full bend along it).
const RIVER_WIDTH := 3.0
const MEANDER := 5.0
const MEANDER_LENGTH := 50.0
## The far bank (the north): how much higher the town stands there, and how wide the
## wooded slope up to it from the water.
const RISE := 8.5
const SLOPE := 7.0
## Up on the far bank the land is no table: it keeps rising towards the back
## (UPLAND_RISE more, UPLAND_DEPTH in from the top of the slope) and rolls
## in low hills (HILLS high, their size HILLS_FREQ), rising in from the top
## of the slope over UPLAND_FADE. The high districts follow it: each block a
## terrace at its own height on a stone plinth, the streets tilted with it.
const UPLAND_RISE := 4.0
const UPLAND_DEPTH := 45.0
const UPLAND_FADE := 6.0
const HILLS := 2.0
const HILLS_FREQ := 0.022
## The plinth under a terrace: the colour of its retaining wall.
const TERRACE_WALL := Color("#4a4260")
## Land kept clear of blocks: along the near bank, and either side of the
## line between two districts of one bank.
const BANK_CLEAR := 1.0
const SPLIT_CLEAR := 2.6
## No district is one grid: each is cut into patches, each its own grid of
## streets. The cuts (PATCH_CUTS, for each district) run along streets of
## its own grid, the one round its museum's block (block (0, 0)): [0, n,
## side] the street between its blocks n - 1 and n across x, [1, n, side]
## across z; side, which way of it (+1 past n, -1 before) is cut off. The
## patch its museum is on keeps the district's own grid; one past a cut
## turns TWIST degrees (give or take TWIST_SPREAD), about the corner where
## the cuts cross, each cut its own way; past both, it squares up to the
## district's own again. PATCH_CLEAR past a cut is left clear: the streets
## of the next patch meet the museum's across it on roads at an angle (up
## to JOIN_ROADS between two patches, from crossings no further apart than
## JOIN_REACH), and the wedges of land left between the grids are gardens.
const PATCH_CUTS := [
	[[0, 1, 1], [1, 4, 1]],
	[[0, 3, 1], [1, 2, 1]],
	[[0, -5, -1], [1, 3, 1]],
	[[1, -3, -1]],
]
const TWIST := 13.0
const TWIST_SPREAD := 4.0
const PATCH_CLEAR := 1.6
const JOIN_ROADS := 4
const JOIN_REACH := 11.0
## The small squares between patches: how far across, and how far apart.
const PLAZA := 2.4
const PLAZA_GAP := 12.0
## The bridges, where they cross (s along the river).
const BRIDGES := [-6.0, 17.5]
## Trees in the woods: one every WOOD_STEP or so, where there is room.
const WOOD_STEP := 1.25
## The rocks: how many rough shapes (a MultiMesh each), about one heap for
## every ROCK_HEAP rocks of an outcrop, and how close two may stand (their
## reaches added, times this: under 1 they lean into each other).
const ROCK_KINDS := 8
const ROCK_HEAP := 12
const ROCK_SPACING := 0.38
## The rocky outcrops: where (s along, q up from the river), how wide, how
## high the ground rises under them, how many rocks on them and how big the
## biggest, and one in how many a crag standing up. The great hill of rocks
## to the north between the high districts and a spur of it down towards
## the road between them; three on the wooded slope over the water, and a
## small one out on the near bank: all on land no district builds on.
const OUTCROPS := [
	[Vector2(4.0, 40.0), 14.5, 5.0, 150, 5.6, 0.3],
	[Vector2(-1.0, 26.0), 5.5, 3.0, 36, 3.4, 0.35],
	[Vector2(30.0, 6.0), 4.5, 2.4, 40, 3.4, 0.3],
	[Vector2(-30.0, 6.0), 4.5, 2.2, 40, 3.2, 0.35],
	[Vector2(-50.0, 6.5), 4.0, 1.8, 28, 2.8, 0.3],
	[Vector2(-44.0, -7.5), 3.0, 1.2, 16, 2.0, 0.2],
]
## Loose houses among the trees: one tried every HOUSE_STEP, kept one in
## HOUSE_SHARE; one in POOL_SHARE with a lit pool.
const HOUSE_STEP := 3.6
const HOUSE_SHARE := 0.42
const POOL_SHARE := 0.25
## The riverside walk: how far from the water's edge, how wide, a lamp every
## so often along it.
const WALK_OFF := 0.9
const WALK_WIDTH := 0.8
const WALK_LAMP := 4.0
## The sports ground on the near bank: from s to s along the river, and how
## far back from the water it goes.
const SPORTS := Vector2(6.0, 15.0)
const SPORTS_DEPTH := 11.0
## Out of town, the fields: how far apart their hedges, and a hedge's step.
const FIELD := 7.5
const HEDGE_STEP := 0.8
## The mall and the big park: how far round each keeps clear.
const MALL_REACH := 6.0
const BIG_PARK_REACH := 5.0

## The town's own colours at night: all here, to change in one place.
const PAVEMENT := Color("#443c58")
const PAVEMENT_EDGE := Color("#2f2940")
const GARDEN := Color("#34503f")
const PARK := Color("#2f4a3a")
const MEADOW := Color("#2b4436")
const PATH := Color("#6d6070")
const ROAD := Color("#48425a")
const WATER := Color("#27407a")
const WATER_GLINT := Color("#4b6fc0")
const BANK := Color("#3b3350")
const RIVERBED := Color("#1c2238")
const RAIL := Color("#8a7a9a")
const STONE := Color("#6a5f7e")
const LAMP := Color("#ffd479")
const ROCK := Color("#4f4964")
const ROCK_LIGHT := Color("#7d7590")
const PITCH_GRASS := Color("#2f6b45")
const COURT := Color("#b8643a")
const TENNIS := Color("#3f6e8a")
const LINE := Color("#e8e4f0")
const POOL_WATER := Color("#5fe0ff")
## The plants made here (_plant_mesh).
const TRUNK := Color("#5a3b36")
const PINE_GREEN := Color("#23594f")
const OAK_GREEN := Color("#3a6a42")
const BIRCH_BARK := Color("#d9d2c4")
const BIRCH_GREEN := Color("#6f9a55")
const POPLAR_GREEN := Color("#467a48")
const AUTUMN_LEAVES := Color("#c26e36")
const BUSH_GREEN := Color("#335d3d")
const BLOSSOM := Color("#e27cb2")
const HEDGE_GREEN := Color("#2c5738")
## The mall: its walls, its roof, its sign; the cars parked before it.
const MALL_WALL := Color("#cbbfe0")
const MALL_WING := Color("#b3a6d4")
const MALL_ROOF := Color("#6f6590")
const MALL_SIGN := Color("#ff5fa8")
const CARS := [Color("#d94f5c"), Color("#4f7fd9"), Color("#e8c24f"), Color("#e8e4f0"), Color("#3a3550"), Color("#5fbf8f")]
const CAR_GLASS := Color("#2b2f4a")
## The pools of light: a street lamp's, a lit house's, a floodlight's.
const GLOW_LAMP := Color(1.0, 0.72, 0.38, 0.42)
const GLOW_HOUSE := Color(1.0, 0.66, 0.34, 0.26)
const GLOW_FLOOD := Color(0.85, 0.9, 1.0, 0.3)
const GLOW_POOL := Color(0.35, 0.85, 1.0, 0.35)

## A pool of light: a round glow, strongest in the middle, fading to
## nothing at the edge, added to what is under it. Unshaded, no shadows, no
## depth written: as cheap as light gets.
const POOL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
varying vec4 tint;
void vertex() {
	tint = INSTANCE_CUSTOM;
}
void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float k = clamp(1.0 - r, 0.0, 1.0);
	ALBEDO = tint.rgb * k * k * tint.a;
}
"""
## The kits' faces, lit by the town at night: how much of the day's colour
## is left, the windows lit (one in LIT_SHARE), the lamps' glow.
const NIGHT := Color("#b9b0e0")
const WINDOW_LIT := Color("#ffc86a")
const LIT_SHARE := 0.55
## Walls and roofs a little different house to house, picked by each
## building's own number.
const WALLS := [Color("#f3e6ff"), Color("#ffe7d6"), Color("#e2f0ff"), Color("#f5f0e0"), Color("#ffd9e4")]
const ROOFS := [Color("#7a4a6e"), Color("#4f5f8a"), Color("#8a4f4a"), Color("#4a6e62"), Color("#6a4a8a")]

const NIGHT_SHADER := """
shader_type spatial;
uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform vec3 night : source_color = vec3(0.73, 0.69, 0.88);
uniform vec3 window_lit : source_color = vec3(1.0, 0.78, 0.42);
uniform float lit_share = 0.55;
uniform float windows = 1.0;
uniform float lamps = 0.0;
uniform vec3 walls[5];
uniform vec3 roofs[5];
uniform vec3 asphalt : source_color = vec3(0.4, 0.42, 0.5);
// Close on a museum's room (see_through): what stands between the camera
// and the window, round the line from it towards the camera (cut_to) as far
// as cut_r out, seen through (a screen door), so the window always shows.
uniform vec3 cut_at = vec3(0.0);
uniform vec3 cut_to = vec3(0.0, 1.0, 0.0);
uniform float cut_r = 0.0;
varying vec3 world;
varying vec4 own;
float hash(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	own = INSTANCE_CUSTOM;
}
void fragment() {
	if (cut_r > 0.0) {
		vec3 d = world - cut_at;
		float ahead = dot(d, cut_to);
		float side = length(d - cut_to * ahead);
		float gone = smoothstep(0.3, 1.0, ahead) * (1.0 - smoothstep(cut_r * 0.6, cut_r, side));
		if (hash(vec3(floor(FRAGCOORD.xy), 0.0)) < gone * 0.88) {
			discard;
		}
	}
	vec3 c = texture(colormap, UV).rgb;
	int k = int(own.r * 4.99);
	// A street's white lines gone into its tarmac, but where it is marked
	// to keep them (own.a: a zebra crossing, a lamp).
	c = mix(c, asphalt, lamps * (1.0 - own.a) * step(0.45, min(c.r, min(c.g, c.b))));
	// Glass: the kits' blues. Lit or not, window by window.
	float glass = windows * step(0.28, c.b - c.r) * step(c.r, c.g);
	float on = step(hash(floor(world * 2.2) + own.g * 17.0), lit_share);
	// White walls take the house's own tint; green roofs its roof.
	float white = step(0.86, min(c.r, min(c.g, c.b)));
	float green = step(0.12, c.g - c.r) * step(c.b, c.g) * (1.0 - glass);
	c = mix(c, walls[k], white * 0.85);
	c = mix(c, roofs[k] * (0.7 + c.g * 0.5), green * own.b);
	// The lamps' warm heads.
	float bulb = lamps * step(0.9, c.r) * step(0.6, c.g) * step(c.b, 0.45);
	vec3 base = c * night;
	ALBEDO = mix(base, mix(vec3(0.12, 0.13, 0.25), window_lit, on), glass);
	EMISSION = window_lit * glass * on * 1.6 + window_lit * bulb * 3.0;
	ROUGHNESS = 0.6;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
"""


## One patch of a district (PATCH_CUTS): a grid of streets turned `angle`
## about its `origin`, on one bank (`high`: the far one, RISE up).
class District:
	## which of the four it is part of (two a bank), and which patch of it
	## (PATCH_CUTS: a bit for each cut it is past)
	var group := 0
	var patch := 0
	var angle := 0.0
	var origin := Vector2.ZERO
	var high := false
	## the blocks built on: block -> what goes on it ("" until build)
	var blocks := {}
	## the street tiles round them: tile -> true
	var tiles := {}
	## on the high bank, each block's terrace: block -> Vector2(its level,
	## the lowest ground under it)
	var levels := {}

	func basis() -> Basis:
		return Basis(Vector3.UP, angle)

	func height() -> float:
		return TownBuilder.RISE if high else 0.0

	## A point of the district's own plan (tiles' units) on the town's plan.
	func world(local: Vector3) -> Vector3:
		return Vector3(origin.x, height(), origin.y) + basis() * local

	## A point of the town's plan in the district's own plan.
	func local(p: Vector2) -> Vector3:
		return basis().inverse() * Vector3(p.x - origin.x, 0, p.y - origin.y)

	func centre(b: Vector2i) -> Vector3:
		return world(Vector3((b.x * PITCH + PITCH * 0.5) * TILE, 0, (b.y * PITCH + PITCH * 0.5) * TILE))

	func tile(t: int, u: int) -> Vector3:
		return world(Vector3(t * TILE, 0, u * TILE))


## Stateless helpers share this builder's caches and RNG via their context argument.
var _terrain_parts := TownTerrain.new()
var _vegetation_parts := TownVegetation.new()
var _places_parts := TownPlaces.new()

var root: Node3D
## what each model is made of, and where each copy of it goes:
## path -> {"mesh", "inner": Transform3D, "at": [Transform3D], "own": [Color]}
var _batches := {}
## the plain boxes (_box), by [material, shadow]: their transforms
var _boxes := {}
var _materials := {}
var _rng := RandomNumberGenerator.new()
## the way the river runs and the way up to the far bank, on the plan
var along := Vector2(1, 0)
var up := Vector2(0, -1)
## where the districts of each bank meet (s along the river)
var split_low := 0.0
var split_high := 6.0
## the districts' patches, each its own grid (every patch of every
## district, in order)
var districts: Array[District] = []
## which of them is patch k of district g: Vector2i(g, k) -> its index
var _patches := {}
## the blocks taken by something else (the museums, the hideout), built as
## bare pavement: Vector3i(district, x, y) -> true
var skip := {}
## the museums' lots on the plan: round them, shops
var museums: Array[Vector2] = []
## the bridges: [low end, high end] on the plan, at their heights
var bridges: Array = []
## the streets as a graph, for the way between two places (route): node ->
## Vector3 where, and node -> {node: length}
var _nodes := {}
var _links := {}
## the roads laid outside the districts (to the bridges, between
## districts): [from, to], kept clear of trees
var _roads: Array = []
## the pools of light: [where, radius, colour (alpha: strength)]
var _pools: Array = []
## the loose houses, the rocks, the sports ground's pitches: where they
## stand (x, z) and how far round them to keep clear, by cells of TAKEN_CELL
var _taken := {}
const TAKEN_CELL := 4.0
## the plants made here (_plant), by kind: [transform, tint] each
var _plants := {}
## patches of the wild, slow noise over the plan: pines or broadleaves,
## birch groves or autumn copses, fields or woods
var _conifers := FastNoiseLite.new()
var _groves := FastNoiseLite.new()
var _fields := FastNoiseLite.new()
## the high bank's rolling hills
var _hills := FastNoiseLite.new()
## Whether something at a point of the plan, r round it, can ever be seen
## (CityStage.sight): what cannot is never built. Unset, everything is.
var seen := Callable()
## What was built and what was left out as never seen, by kind (the models'
## kits, "box", "pool", "rock", "ground"): for the tools to count.
var made := {}
var unseen := {}


## The town's seed: always 7 in the game, so it is always the same town; the
## tools may pass another to compare variants of the same rules.
func _init(parent: Node3D, town_seed := 7) -> void:
	root = parent
	_rng.seed = town_seed
	_conifers.seed = town_seed + 11
	_conifers.frequency = 0.035
	_groves.seed = town_seed + 23
	_groves.frequency = 0.07
	_fields.seed = town_seed + 5
	_fields.frequency = 0.045
	_hills.seed = town_seed + 31
	_hills.frequency = HILLS_FREQ


## A block's size inside its streets, in the town's units.
static func block_size() -> float:
	return BLOCK * TILE


# --- The districts on the land -------------------------------------------------------

## How high the streets of district d are at p: on the high bank, the
## ground's own height.
func street_y(d: District, p: Vector2) -> float:
	return ground(p) if d.high else 0.0


## Street tile (t, u) of district d, at its street's height.
func _tile_at(d: District, t: int, u: int) -> Vector3:
	var at := d.tile(t, u)
	at.y = street_y(d, Vector2(at.x, at.z))
	return at


## Which way and how steeply the ground runs under a street of district d
## at `at`: the rise for each unit across x and across z (flat off the high
## bank).
func _slope(d: District, at: Vector3) -> Vector2:
	if not d.high:
		return Vector2.ZERO
	var h := TILE * 0.5
	var p := Vector2(at.x, at.z)
	return Vector2(ground(p + Vector2(h, 0)) - ground(p - Vector2(h, 0)), ground(p + Vector2(0, h)) - ground(p - Vector2(0, h))) / (2.0 * h)


## Block b of district d's terrace: its level (just over the highest ground
## under it and the near halves of its streets, so no street ever runs
## above it) and the lowest ground under it (where its plinth goes down to).
## Level on the near bank.
func _terrace(d: District, b: Vector2i) -> Vector2:
	if not d.high:
		return Vector2.ZERO
	if d.levels.has(b):
		return d.levels[b]
	var c := d.centre(b)
	var h := block_size() * 0.5 + TILE * 0.5
	var top := -INF
	var low := INF
	for sx in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for sz in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			var w := c + d.basis() * Vector3(sx * h, 0, sz * h)
			var g := ground(Vector2(w.x, w.z))
			top = maxf(top, g)
			low = minf(low, g)
	d.levels[b] = Vector2(top + 0.03, low)
	return d.levels[b]


## The middle of block b of district d, at its terrace's level.
func _centre(d: District, b: Vector2i) -> Vector3:
	var c := d.centre(b)
	c.y = _terrace(d, b).x
	return c


## The middle of block b of district i, at its level: where a museum or the
## hideout stands on it.
func block_top(i: int, b: Vector2i) -> Vector3:
	return _centre(districts[i], b)


# --- The lie of the land ------------------------------------------------------------

## s along the river and q up towards the far bank, of a point of the plan.
func frame(p: Vector2) -> Vector2:
	return _terrain_parts.frame(self, p)


## The point of the plan at s along and q up.
func point(s: float, q: float) -> Vector2:
	return _terrain_parts.point(self, s, q)


## How far up the middle of the river is, at s along it.
func river_at(s: float) -> float:
	return _terrain_parts.river_at(self, s)


## How far a point is from the middle of the river, across it: negative on
## the near bank, positive on the far one.
func across(p: Vector2) -> float:
	return _terrain_parts.across(self, p)


## How high the ground is at a point: the river's bed below it all, level
## on the near bank, up the slope to RISE on the far one and rolling on up
## from there (_upland); the rocky outcrops' own rise on top (_crags).
func ground(p: Vector2) -> float:
	return _terrain_parts.ground(self, p)


func _upland(p: Vector2, d: float) -> float:
	return _terrain_parts.upland(self, p, d)


func _rocky(p: Vector2) -> float:
	return _terrain_parts.rocky(self, p)


func _crags(p: Vector2) -> float:
	return _terrain_parts.crags(self, p)


func _outcrop_at(o: int) -> Vector2:
	return _terrain_parts.outcrop_at(self, o)


func _outcrop(o: int, f: Vector2) -> float:
	return _terrain_parts.outcrop(self, o, f)


func _in_sports(p: Vector2) -> bool:
	return _terrain_parts.in_sports(self, p)


func _tangent(s: float) -> Vector2:
	return _terrain_parts.tangent(self, s)


func _across_dir(s: float) -> Vector2:
	return _terrain_parts.across_dir(self, s)


## The district a point belongs to, or -1: on a bank clear of the water and
## the slope, and clear of the line between the two districts of its bank.
func district_of(p: Vector2) -> int:
	var g := _land_of(p)
	return -1 if g < 0 else _patch_at(g, p, PATCH_CLEAR)


## Which of the four districts' land a point is on (0, 1 on the near bank,
## 2, 3 on the high one), whatever its patch; -1 off them all.
func _land_of(p: Vector2) -> int:
	if absf(p.x) > REACH or absf(p.y) > REACH:
		return -1
	if _rocky(p) > 0.0 or _in_sports(p):
		return -1
	var d := across(p)
	var s := frame(p).x
	var half := RIVER_WIDTH * 0.5
	var g := 0
	if d < 0.0:
		if d > -(half + BANK_CLEAR) or absf(s - split_low) < SPLIT_CLEAR:
			return -1
		g = 0 if s < split_low else 1
	else:
		if d < half + SLOPE + 0.3 or absf(s - split_high) < SPLIT_CLEAR:
			return -1
		g = 2 if s < split_high else 3
	return g


## The patch of district g a point is on (its index in districts): by which
## side of each of the district's cuts it is; -1 if not yet planned, or
## past a cut by less than `clear`.
func _patch_at(g: int, p: Vector2, clear := 0.0) -> int:
	var home: int = _patches.get(Vector2i(g, 0), -1)
	if home < 0:
		return -1
	var l := districts[home].local(p) / (PITCH * TILE)
	var k := 0
	var cuts: Array = PATCH_CUTS[g]
	for j in cuts.size():
		var cut: Array = cuts[j]
		var past := ((l.x if cut[0] == 0 else l.z) - float(cut[1])) * float(cut[2]) * PITCH * TILE
		# (A hair over the line is on it: a block of its own up to it.)
		if past > 0.01:
			if past < clear:
				return -1
			k |= 1 << j
	return _patches.get(Vector2i(g, k), -1)


# --- Laying it out ------------------------------------------------------------------

## The districts and which of their blocks are built on: every block whose
## whole square (streets and all) falls in its district. Angles: each its own.
func plan(angles: Array, origins: Array[Vector2]) -> void:
	districts.clear()
	_patches.clear()
	for g in 4:
		var cuts: Array = PATCH_CUTS[g]
		var home: District = null
		for k in 1 << cuts.size():
			var d := District.new()
			d.group = g
			d.patch = k
			d.high = g >= 2
			d.angle = deg_to_rad(float(angles[g]) + _twist(g, k))
			d.origin = origins[g]
			if k == 0:
				home = d
			else:
				# From the corner where the cuts cross, PATCH_CLEAR past each
				# cut it is past.
				var at := Vector3.ZERO
				for j in cuts.size():
					var cut: Array = cuts[j]
					var axis := Vector3.RIGHT if cut[0] == 0 else Vector3.BACK
					at += axis * float(cut[1]) * PITCH * TILE
					if k & (1 << j):
						at += axis * float(cut[2]) * PATCH_CLEAR
				var w := home.world(at)
				d.origin = Vector2(w.x, w.z)
			_patches[Vector2i(g, k)] = districts.size()
			districts.append(d)
	var r := int(REACH * 2.0 / (PITCH * TILE)) + 2
	for i in districts.size():
		var d := districts[i]
		d.blocks = _fill(i, d, Vector2i(-r, -r), Vector2i(r, r))
		# A patch off its museum's: its grid slid two tiles at a time, each way,
		# to where the most blocks fit (its streets meet the next patch's at
		# an angle anyway).
		if d.patch != 0 and not d.blocks.is_empty():
			var lo := Vector2i(r, r)
			var hi := Vector2i(-r, -r)
			for b in d.blocks:
				lo = lo.min(b)
				hi = hi.max(b)
			var base := d.origin
			var best := [d.blocks, base]
			for sx in range(0, PITCH, 2):
				for sz in range(0, PITCH, 2):
					if sx == 0 and sz == 0:
						continue
					var slide := d.basis() * Vector3(sx, 0, sz) * TILE
					d.origin = base + Vector2(slide.x, slide.z)
					var got := _fill(i, d, lo - Vector2i(2, 2), hi + Vector2i(2, 2))
					if got.size() > (best[0] as Dictionary).size():
						best = [got, d.origin]
			d.blocks = best[0]
			d.origin = best[1]
		for b in d.blocks:
			_ring_of(d, b)


## The blocks of district i (d) from block lo to hi whose whole square
## (streets and all) falls in it.
func _fill(i: int, d: District, lo: Vector2i, hi: Vector2i) -> Dictionary:
	var blocks := {}
	for bx in range(lo.x, hi.x):
		for bz in range(lo.y, hi.y):
			var b := Vector2i(bx, bz)
			var inside := true
			for c in [Vector2(0.5, 0.5), Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1), Vector2(0.5, 0), Vector2(0, 0.5), Vector2(1, 0.5), Vector2(0.5, 1)]:
				var w := d.world(Vector3((b.x + c.x) * PITCH * TILE, 0, (b.y + c.y) * PITCH * TILE))
				if district_of(Vector2(w.x, w.z)) != i:
					inside = false
					break
			if inside:
				blocks[b] = ""
	return blocks


## How far (degrees) patch k of district g turns from the district's own
## grid (k: a bit for each cut it is past): past one cut, TWIST one way or
## the other; past two, square again.
func _twist(g: int, k: int) -> float:
	var n := 0
	for j in 8:
		n += (k >> j) & 1
	if n % 2 == 0:
		return 0.0
	var sgn := 1.0 if (k + g) % 2 == 0 else -1.0
	var spread := TWIST_SPREAD * (float(posmod(g * 7 + k * 3, 5)) / 2.0 - 1.0)
	return sgn * (TWIST + spread)


## The street tiles round block b.
func _ring_of(d: District, b: Vector2i) -> void:
	for k in PITCH + 1:
		for tu in [Vector2i(b.x * PITCH + k, b.y * PITCH), Vector2i(b.x * PITCH + k, (b.y + 1) * PITCH),
				Vector2i(b.x * PITCH, b.y * PITCH + k), Vector2i((b.x + 1) * PITCH, b.y * PITCH + k)]:
			d.tiles[tu] = true


## The district patch a point is on, by its bank, its side of the line between
## the two of that bank and of its cuts, however close to the water or a line.
func bank_of(p: Vector2) -> int:
	var s := frame(p).x
	var g := 0
	if across(p) < 0.0:
		g = 0 if s < split_low else 1
	else:
		g = 2 if s < split_high else 3
	return _patch_at(g, p)


## The block of district i under a point, built on from now on (and kept
## for whoever asked, as skip) even if it reaches a little into the clear
## land by the water or between districts: a museum by the river.
func claim(i: int, p: Vector2) -> Vector2i:
	var d := districts[i]
	var l := d.local(p)
	var b := Vector2i(floori(l.x / (PITCH * TILE)), floori(l.z / (PITCH * TILE)))
	if not d.blocks.has(b):
		d.blocks[b] = ""
		_ring_of(d, b)
	skip[Vector3i(i, b.x, b.y)] = true
	return b


## The whole town: the ground and the river, the districts, the bridges and
## the roads to them, and the woods in between.
func build() -> void:
	_prune()
	_terrain()
	_water()
	for i in districts.size():
		_district(i)
	_bridges()
	_join_districts()
	_walk()
	_sports()
	_rocks()
	_places()
	_plazas()
	_loose_houses()
	_hedgerows()
	_woods()
	_flush()
	_flush_boxes()
	_flush_plants()
	_light_pools()


## The blocks never seen (seen), gone before anything is built on them,
## and their streets with them: not the museums' and the hideout's (skip).
func _prune() -> void:
	if not seen.is_valid():
		return
	for i in districts.size():
		var d := districts[i]
		var gone := d.blocks.keys().filter(func(b: Vector2i) -> bool:
			return not skip.has(Vector3i(i, b.x, b.y)) and not seen.call(_centre(d, b), PITCH * TILE * 0.71))
		if gone.is_empty():
			continue
		for b in gone:
			d.blocks.erase(b)
		unseen["block"] = unseen.get("block", 0) + gone.size()
		d.tiles.clear()
		for b in d.blocks:
			_ring_of(d, b)


# --- The ground and the water --------------------------------------------------------

func _terrain() -> void:
	_terrain_parts.terrain(self)


func _water() -> void:
	_terrain_parts.water(self)


# --- The districts ------------------------------------------------------------------

func _district(i: int) -> void:
	var d := districts[i]
	_streets(d)
	for b in d.blocks:
		if skip.has(Vector3i(i, b.x, b.y)):
			_pavement(d, b, PAVEMENT)
			continue
		_block(d, b)
	# The streets as a graph: a node at every crossing, linked along each
	# street to the next.
	for tu in d.tiles:
		if posmod(tu.x, PITCH) != 0 or posmod(tu.y, PITCH) != 0:
			continue
		var at := _tile_at(d, tu.x, tu.y)
		_node(Vector3i(i, tu.x, tu.y), at)
		for step in [Vector2i(PITCH, 0), Vector2i(0, PITCH)]:
			var to: Vector2i = tu + step
			var ok := true
			for k in range(1, PITCH + 1):
				if not d.tiles.has(tu + step / PITCH * k):
					ok = false
					break
			if ok:
				_node(Vector3i(i, to.x, to.y), _tile_at(d, to.x, to.y))
				_link(Vector3i(i, tu.x, tu.y), Vector3i(i, to.x, to.y))


## The streets of a district: a road tile on every street tile, crossings
## where two meet (with a zebra crossing on each side). On the high bank
## each tile at the ground's height and tilted with it, so they run on
## from one to the next up and down the hills.
func _streets(d: District) -> void:
	var lift := Vector3(0, 0.03 if d.high else 0.005, 0)
	for tu in d.tiles:
		var t: int = tu.x
		var u: int = tu.y
		var along_x := posmod(u, PITCH) == 0
		var along_z := posmod(t, PITCH) == 0
		var at := _tile_at(d, t, u) + lift
		var tilt := _slope(d, at)
		if along_x and along_z:
			_add("calles/road-crossroad.glb", at, d.angle, TILE, PLAIN, tilt)
		elif along_x:
			var k := posmod(t, PITCH)
			var near := (k == 1 and _zebra(d, Vector2i(t - 1, u))) or (k == PITCH - 1 and _zebra(d, Vector2i(t + 1, u)))
			_add("calles/road-crossing.glb" if near else "calles/road-straight.glb", at, d.angle + PI / 2, TILE, Color(0, 0, 0, 1) if near else PLAIN, tilt)
		else:
			var k := posmod(u, PITCH)
			var near := (k == 1 and _zebra(d, Vector2i(t, u - 1))) or (k == PITCH - 1 and _zebra(d, Vector2i(t, u + 1)))
			_add("calles/road-crossing.glb" if near else "calles/road-straight.glb", at, d.angle, TILE, Color(0, 0, 0, 1) if near else PLAIN, tilt)


## A street tile without its white lines (NIGHT_SHADER: own.a).
const PLAIN := Color(0, 0, 0, 0)


## Whether the crossing at street tile c has zebra crossings round it: the
## ones by a museum's door, and one crossing in nine or so elsewhere.
func _zebra(d: District, c: Vector2i) -> bool:
	var at := d.tile(c.x, c.y)
	if museums.any(func(m: Vector2) -> bool: return m.distance_to(Vector2(at.x, at.z)) < 4.5):
		return true
	return posmod(c.x * 7 + c.y * 13 + int(d.angle * 10.0), 9) == 0


## A block's pavement: a slab a step up from the street; on the high bank,
## on its terrace's plinth, a stone wall down to the lowest ground round it.
func _pavement(d: District, b: Vector2i, colour: Color) -> void:
	var c := _centre(d, b)
	var s := block_size()
	if d.high:
		var drop := c.y - _terrace(d, b).y + 0.3
		_box(Vector3(s + 0.02, drop, s + 0.02), TERRACE_WALL, c + Vector3(0, 0.02 - drop * 0.5, 0), d.basis())
	_box(Vector3(s + 0.02, 0.08, s + 0.02), PAVEMENT_EDGE, c + Vector3(0, 0.03, 0), d.basis())
	_box(Vector3(s - 0.1, 0.08, s - 0.1), colour, c + Vector3(0, 0.05, 0), d.basis())


## What goes on block b: at the back of the high town, the tall buildings,
## their lights on the skyline; round the museums, shops; further out,
## houses; now and then a park. Lamps at its corners.
func _block(d: District, b: Vector2i) -> void:
	var c := _centre(d, b)
	var near := museums.any(func(m: Vector2) -> bool: return m.distance_to(Vector2(c.x, c.z)) < 12.0)
	var kind := "houses"
	if d.high and frame(Vector2(c.x, c.z)).y - river_at(frame(Vector2(c.x, c.z)).x) > 26.0 and posmod(b.x + b.y * 3, 3) != 0:
		kind = "tall"
	elif near and posmod(b.x + b.y, 2) == 0:
		kind = "shops"
	if posmod(b.x * 7 + b.y * 13, 9) == 0:
		kind = "park"
	d.blocks[b] = kind
	match kind:
		"park": _park(d, b)
		"houses": _houses(d, b)
		_: _shops(d, b, kind == "tall")
	_corner_lamps(d, b)


## A block of shops and offices: a building on every lot round its edge,
## each facing its street, a yard with trees in the middle.
func _shops(d: District, b: Vector2i, tall: bool) -> void:
	_pavement(d, b, PAVEMENT)
	var c := _centre(d, b)
	var names := ["a", "b", "c", "d", "f", "g", "h"]
	var big := ["i", "l", "m", "skyscraper-a", "skyscraper-b", "skyscraper-c", "skyscraper-d", "skyscraper-e"]
	for i in BLOCK:
		for j in BLOCK:
			var edge := i == 0 or j == 0 or i == BLOCK - 1 or j == BLOCK - 1
			var at := c + d.basis() * Vector3((i - (BLOCK - 1) * 0.5) * TILE, 0.09, (j - (BLOCK - 1) * 0.5) * TILE)
			if not edge:
				if _rng.randf() < 0.7:
					_tree(at + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.3, 0.3)))
				continue
			# Facing the street it is on: +z the front, -z the back, then the sides.
			var turn := 0.0
			if j == BLOCK - 1:
				turn = 0.0
			elif j == 0:
				turn = PI
			elif i == 0:
				turn = -PI / 2
			else:
				turn = PI / 2
			# Not every lot built on: a gap here and there for air and trees.
			var corner := (i == 0 or i == BLOCK - 1) and (j == 0 or j == BLOCK - 1)
			if not corner and not tall and _rng.randf() < 0.3:
				_tree(at)
				continue
			var name: String = names[_rng.randi() % names.size()]
			if tall and _rng.randf() < 0.55:
				name = big[_rng.randi() % big.size()]
			var path := "comercial/building-%s.glb" % name
			var k := _fit(path, TILE * 0.98)
			_add(path, at, d.angle + turn, k, _own(0.0))


## A block of houses: four, one a corner, each on its garden facing its
## street, with a tree or two and a hedge.
func _houses(d: District, b: Vector2i) -> void:
	_pavement(d, b, PAVEMENT)
	var c := _centre(d, b)
	var s := block_size()
	_box(Vector3(s - 0.5, 0.06, s - 0.5), GARDEN, c + Vector3(0, 0.1, 0), d.basis())
	# Hedges between the gardens, open in the middle: both ways, or one.
	var h := s * 0.5 - 0.4
	var ways := _rng.randi() % 3
	for sgn in [-1, 1]:
		if ways != 1:
			_hedge(c + d.basis() * Vector3(sgn * 0.45, 0.12, 0), c + d.basis() * Vector3(sgn * h, 0.12, 0), 0.22)
		if ways != 2:
			_hedge(c + d.basis() * Vector3(0, 0.12, sgn * 0.45), c + d.basis() * Vector3(0, 0.12, sgn * h), 0.22)
	var letters := "abcdefghijklmnopqrstu"
	for qx in [-1, 1]:
		for qz in [-1, 1]:
			var at := c + d.basis() * Vector3(qx * s * 0.25, 0.12, qz * s * 0.25)
			var turn := 0.0 if qz > 0 else PI
			var path := "suburbios/building-type-%s.glb" % letters[_rng.randi() % letters.length()]
			_add(path, at, d.angle + turn, _fit(path, s * 0.36), _own(1.0))
			if _rng.randf() < 0.6:
				_pool(at + d.basis() * Vector3(0, 0, 0.9 if qz > 0 else -0.9), 1.3, GLOW_HOUSE)
			_tree(at + d.basis() * Vector3(qx * s * 0.2, 0, -qz * s * 0.16))
			if _rng.randf() < 0.5:
				_tree(at + d.basis() * Vector3(-qx * s * 0.18, 0, -qz * s * 0.18))


## A park: grass, a path across it, trees all round.
func _park(d: District, b: Vector2i) -> void:
	_pavement(d, b, PAVEMENT)
	var c := _centre(d, b)
	var s := block_size()
	_box(Vector3(s - 0.4, 0.06, s - 0.4), PARK, c + Vector3(0, 0.1, 0), d.basis())
	_box(Vector3(s - 0.4, 0.07, 0.35), PATH, c + Vector3(0, 0.105, 0), d.basis())
	_box(Vector3(0.35, 0.07, s - 0.4), PATH, c + Vector3(0, 0.105, 0), d.basis())
	# A hedge all round, open where the paths come in.
	var e := s * 0.5 - 0.3
	for sgn in [-1, 1]:
		for half in [-1, 1]:
			_hedge(c + d.basis() * Vector3(half * 0.4, 0.12, sgn * e), c + d.basis() * Vector3(half * e, 0.12, sgn * e), 0.26)
			_hedge(c + d.basis() * Vector3(sgn * e, 0.12, half * 0.4), c + d.basis() * Vector3(sgn * e, 0.12, half * e), 0.26)
	for k in 14:
		var off := Vector3(_rng.randf_range(-s * 0.38, s * 0.38), 0.13, _rng.randf_range(-s * 0.38, s * 0.38))
		if absf(off.x) < 0.4 or absf(off.z) < 0.4:
			continue
		_tree(c + d.basis() * off)


## A street lamp at each corner of block b, turned over the street.
func _corner_lamps(d: District, b: Vector2i) -> void:
	var c := _centre(d, b)
	var h := block_size() * 0.5 - 0.12
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var at := c + d.basis() * Vector3(sx * h, 0.09, sz * h)
			_lamp(at, d.angle + atan2(float(sx), float(sz)) + PI)


# --- Plants ------------------------------------------------------------------------

func _tree(at: Vector3, wild := false) -> void:
	_vegetation_parts.tree(self, at, wild)


func _kind_at(p: Vector2) -> String:
	return _vegetation_parts.kind_at(self, p)


func _pick(weights: Dictionary) -> String:
	return _vegetation_parts.pick(self, weights)


func _plant(kind: String, at: Vector3) -> void:
	_vegetation_parts.plant(self, kind, at)


func _hedge(a: Vector3, b: Vector3, tall := 0.34) -> void:
	_vegetation_parts.hedge(self, a, b, tall)


func _flush_plants() -> void:
	_vegetation_parts.flush_plants(self)


func _plant_mesh(kind: String) -> ArrayMesh:
	return _vegetation_parts.plant_mesh(self, kind)


func _shape(st: SurfaceTool, mesh: PrimitiveMesh, at: Vector3, colour: Color, stretch := Vector3.ONE) -> void:
	_vegetation_parts.shape(self, st, mesh, at, colour, stretch)


func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	return _vegetation_parts.cone(self, top, bottom, h)


func _ball(r: float) -> SphereMesh:
	return _vegetation_parts.ball(self, r)


# --- Crossing and joining ------------------------------------------------------------

## The bridges: from the near bank, over the water and up the slope to the
## high town, a stone deck on piers with a rail each side, lamps at the
## ends; a road on to the nearest crossing of each bank. Straight up from
## the water, but never into the slope: where the slope rises over the
## straight way, the deck runs on up over the ground.
func _bridges() -> void:
	bridges.clear()
	for s in BRIDGES:
		var mid := point(s, river_at(s))
		var dir := _across_dir(s)
		var half := RIVER_WIDTH * 0.5
		var low2 := mid - dir * (half + 0.9)
		var high2 := mid + dir * (half + SLOPE + 0.4)
		var low := Vector3(low2.x, 0.0, low2.y)
		var high := Vector3(high2.x, ground(high2), high2.y)
		var deck := low + Vector3(0, 0.12, 0)
		var top := high + Vector3(0, 0.12, 0)
		# The deck, a piece a tile or so long: over the straight way up or
		# the ground, whichever is higher.
		var way: Array[Vector3] = [deck]
		var n := ceili(low2.distance_to(high2) / TILE)
		for j in range(1, n):
			var at := deck.lerp(top, float(j) / n)
			at.y = maxf(at.y, ground(Vector2(at.x, at.z)) + 0.12)
			way.append(at)
		way.append(top)
		bridges.append([low, high, way])
		var side := Vector3(-dir.y, 0, dir.x) * TILE * 0.5
		for j in way.size() - 1:
			_beam(way[j], way[j + 1], TILE * 1.05, 0.14, STONE)
			_beam(way[j] + Vector3(0, 0.02, 0), way[j + 1] + Vector3(0, 0.02, 0), TILE * 0.8, 0.14, ROAD)
			for sgn in [-1, 1]:
				_beam(way[j] + side * sgn + Vector3(0, 0.2, 0), way[j + 1] + side * sgn + Vector3(0, 0.2, 0), 0.07, 0.1, RAIL)
		for sgn in [-1, 1]:
			for e in [deck, top]:
				_lamp(e + side * sgn * 1.15 - Vector3(0, 0.1, 0), atan2(dir.x, dir.y))
		# Piers in the water.
		for k in [0.3, 0.55]:
			var at := deck.lerp(top, k)
			_box(Vector3(TILE * 0.9, at.y + 0.3, 0.35), STONE.darkened(0.25), Vector3(at.x, (at.y - 0.3) * 0.5 - 0.15, at.z), Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP))
		var low_id := Vector3i(-1, bridges.size(), 0)
		var high_id := Vector3i(-1, bridges.size(), 1)
		_node(low_id, deck)
		_node(high_id, top)
		_link(low_id, high_id)
		_road_to_nearest(low_id, deck, false)
		_road_to_nearest(high_id, top, true)


## The patches of each bank joined where they meet: between facing
## crossings of two patches, roads across the clear land at whatever angle
## it takes (up to JOIN_ROADS, spread out, none over a block); the
## museums' patches of each bank's two districts joined between their
## nearest crossings (the way from one museum to the next); then, while a
## bank is in pieces, the nearest two crossings of two pieces joined.
func _join_districts() -> void:
	var by := {}
	for k in _nodes:
		if k.x >= 0:
			if not by.has(k.x):
				by[k.x] = []
			(by[k.x] as Array).append(k)
	for a in by:
		for b in by:
			if a < b and districts[a].high == districts[b].high:
				_join(by[a], by[b])
	# The two museums' patches of each bank joined straight, as the way
	# from one museum to the next.
	for pair in [[0, 1], [2, 3]]:
		var best := []
		var best_d := INF
		for a in by.get(_patches.get(Vector2i(pair[0], 0), -1), []):
			for b in by.get(_patches.get(Vector2i(pair[1], 0), -1), []):
				var dd: float = (_nodes[a] as Vector3).distance_to(_nodes[b])
				if dd < best_d:
					best_d = dd
					best = [a, b]
		if not best.is_empty() and not (_links[best[0]] as Dictionary).has(best[1]):
			_road(best[0], best[1])
	for high in [false, true]:
		_one_bank(high)


## Roads between facing crossings of two patches (their nodes a and b).
func _join(a: Array, b: Array) -> void:
	var pairs := []
	for from in [a, b]:
		var to: Array = b if from == a else a
		for ka in from:
			var pa: Vector3 = _nodes[ka]
			var best = null
			var best_d := JOIN_REACH
			for kb in to:
				var dd := Vector2(pa.x, pa.z).distance_to(Vector2((_nodes[kb] as Vector3).x, (_nodes[kb] as Vector3).z))
				if dd < best_d:
					best_d = dd
					best = kb
			if best != null:
				pairs.append([best_d, ka, best])
	pairs.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var used := {}
	var mids: Array[Vector2] = []
	for pr in pairs:
		if mids.size() >= JOIN_ROADS:
			break
		if used.has(pr[1]) or used.has(pr[2]) or (_links[pr[1]] as Dictionary).has(pr[2]):
			continue
		var pa: Vector3 = _nodes[pr[1]]
		var pb: Vector3 = _nodes[pr[2]]
		var mid := Vector2(pa.x + pb.x, pa.z + pb.z) * 0.5
		if mids.any(func(m: Vector2) -> bool: return m.distance_to(mid) < PITCH * TILE * 1.2):
			continue
		if not _clear_way(Vector2(pa.x, pa.z), Vector2(pb.x, pb.z)):
			continue
		used[pr[1]] = true
		used[pr[2]] = true
		mids.append(mid)
		_road(pr[1], pr[2])


## Whether a road from a to b keeps off every block (it may run along a
## street at either end).
func _clear_way(a: Vector2, b: Vector2) -> bool:
	var n := maxi(2, ceili(a.distance_to(b) / (TILE * 0.5)))
	for j in range(1, n):
		var p := a.lerp(b, float(j) / n)
		for d in districts:
			var l := d.local(p)
			var cell := PITCH * TILE
			var bl := Vector2i(floori(l.x / cell), floori(l.z / cell))
			if not d.blocks.has(bl):
				continue
			var inx := l.x - bl.x * cell
			var inz := l.z - bl.y * cell
			var e := TILE * 0.75
			if inx > e and inx < cell - e and inz > e and inz < cell - e:
				return false
	return true


## The crossings of one bank all reachable from one another: while not,
## a road between the nearest two crossings of two pieces.
func _one_bank(high: bool) -> void:
	var all := _nodes.keys().filter(func(k: Vector3i) -> bool: return k.x >= 0 and districts[k.x].high == high)
	for guard in 40:
		var piece := {}
		var pieces := 0
		for start in all:
			if piece.has(start):
				continue
			piece[start] = pieces
			var todo: Array = [start]
			while not todo.is_empty():
				var k = todo.pop_back()
				for n in _links[k]:
					if not piece.has(n) and n.x >= 0:
						piece[n] = pieces
						todo.append(n)
			pieces += 1
		if pieces <= 1:
			return
		var best := []
		var best_d := INF
		for a in all:
			var pa: Vector3 = _nodes[a]
			for b in all:
				if piece[a] >= piece[b]:
					continue
				var dd := pa.distance_to(_nodes[b])
				if dd < best_d:
					best_d = dd
					best = [a, b]
		_road(best[0], best[1])


## Small squares in the wedges of clear land where one patch meets the
## next (PLAZA across): along each cut, on its far side, wherever there is
## room clear of blocks and roads; no two too near.
func _plazas() -> void:
	var placed: Array[Vector2] = []
	for g in PATCH_CUTS.size():
		var home: int = _patches.get(Vector2i(g, 0), -1)
		if home < 0:
			continue
		var d := districts[home]
		for cut in PATCH_CUTS[g]:
			var axis := Vector3.RIGHT if cut[0] == 0 else Vector3.BACK
			var run := Vector3.BACK if cut[0] == 0 else Vector3.RIGHT
			var t := -10.0 * PITCH * TILE
			while t < 10.0 * PITCH * TILE:
				t += TILE
				var local := axis * (float(cut[1]) * PITCH * TILE + float(cut[2]) * (PATCH_CLEAR * 0.5 + PLAZA * 0.75)) + run * t
				var w := d.world(local)
				var c := Vector2(w.x, w.z)
				if placed.any(func(q: Vector2) -> bool: return q.distance_to(c) < PLAZA_GAP):
					continue
				if _plaza_room(g, c):
					placed.append(c)
					_plaza(c, d.angle + deg_to_rad(float(_twist(g, 1))) * 0.5)


## Room for a square at c on district g's land: clear of blocks, roads,
## the rocks and anything else there (the mall, the park), flat enough, seen.
func _plaza_room(g: int, c: Vector2) -> bool:
	if seen.is_valid() and not seen.call(Vector3(c.x, ground(c), c.y), PLAZA):
		return false
	var g0 := ground(c)
	for k in 13:
		var q := c if k == 12 else c + Vector2.from_angle(k * TAU / 12.0 + 0.2) * PLAZA * (0.75 if k % 2 else 0.6)
		if _land_of(q) != g or _built(q, 0.35) or _on_road(q) or _near_taken(q) or absf(ground(q) - g0) > 0.6:
			return false
	return true


## A small square at c, turned `turn`: paved, on a plinth where the ground
## falls away, a fountain in the middle, a tree at each corner, lamps and
## benches between them.
func _plaza(c: Vector2, turn: float) -> void:
	var basis := Basis(Vector3.UP, turn)
	var top := -INF
	var low := INF
	for k in 9:
		var q := c if k == 8 else c + Vector2.from_angle(k * TAU / 8.0) * PLAZA
		top = maxf(top, ground(q))
		low = minf(low, ground(q))
	var o := Vector3(c.x, top + 0.03, c.y)
	var side := PLAZA * 1.5
	if top - low > 0.04:
		var drop := top - low + 0.3
		_box(Vector3(side + 0.1, drop, side + 0.1), TERRACE_WALL, o + Vector3(0, 0.02 - drop * 0.5, 0), basis)
	_box(Vector3(side + 0.1, 0.08, side + 0.1), PAVEMENT_EDGE, o + Vector3(0, 0.03, 0), basis)
	_box(Vector3(side - 0.1, 0.08, side - 0.1), PATH, o + Vector3(0, 0.05, 0), basis)
	# The fountain: a stone basin, its water lit.
	_box(Vector3(1.2, 0.22, 1.2), STONE, o + Vector3(0, 0.18, 0), basis)
	_box(Vector3(1.0, 0.04, 1.0), POOL_WATER, o + Vector3(0, 0.29, 0), basis, false, _glow(POOL_WATER, 0.9))
	_box(Vector3(0.18, 0.5, 0.18), STONE, o + Vector3(0, 0.45, 0), basis)
	_pool(o, 1.8, GLOW_POOL)
	var h := side * 0.5 - 0.45
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_tree(o + basis * Vector3(sx * h, 0.09, sz * h))
			var a := turn + atan2(float(sx), float(sz))
			_lamp(o + basis * Vector3(sx * h * 0.55, 0.09, sz * h * 1.05), a)
		_box(Vector3(0.16, 0.12, 0.6), Color("#6b4a3a"), o + basis * Vector3(sx * (h - 0.6), 0.16, 0), basis)
	_take(c, PLAZA * 1.2)


## A road from a place (a bridge's end) to the nearest crossing of the
## districts of its bank.
func _road_to_nearest(from: Vector3i, at: Vector3, high: bool) -> void:
	var best := Vector3i(-2, 0, 0)
	var best_d := INF
	for k in _nodes:
		if k.x < 0 or districts[k.x].high != high:
			continue
		var dd: float = (_nodes[k] as Vector3).distance_to(at)
		if dd < best_d:
			best_d = dd
			best = k
	if best.x >= 0:
		_road(from, best)


## A road laid over the ground between two nodes: tarmac on a kerb, lamps
## along it now and then, and a link in the graph.
func _road(a: Vector3i, b: Vector3i) -> void:
	var from: Vector3 = _nodes[a]
	var to: Vector3 = _nodes[b]
	_roads.append([Vector2(from.x, from.z), Vector2(to.x, to.z)])
	# Over the ground, up and down with it, a piece at a time.
	var pts: Array[Vector3] = [from]
	_over_ground(pts, from, to)
	var lift := Vector3(0, 0.02, 0)
	for i in pts.size() - 1:
		_beam(pts[i] + lift, pts[i + 1] + lift, TILE * 1.0, 0.05, PAVEMENT_EDGE)
		_beam(pts[i] + lift + Vector3(0, 0.01, 0), pts[i + 1] + lift + Vector3(0, 0.01, 0), TILE * 0.8, 0.05, ROAD)
	var length := Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	var dir := (to - from)
	dir.y = 0.0
	dir = dir.normalized()
	var side := Vector3(-dir.z, 0, dir.x) * TILE * 0.62
	var k := 3.0
	while k < length - 2.0:
		var at := from + dir * k + side
		at.y = ground(Vector2(at.x, at.z))
		_lamp(at, atan2(side.x, side.z) + PI)
		k += 5.0
	_link(a, b)


## The points from `from` (not added) to `to` (added), a tile or so apart,
## each at the ground's height under it and as far over it as the two ends
## are (a bridge's deck, a street's kerb), the one's share fading into the
## other's.
func _over_ground(pts: Array[Vector3], from: Vector3, to: Vector3) -> void:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var over_a := from.y - ground(a)
	var over_b := to.y - ground(b)
	var n := maxi(1, ceili(a.distance_to(b) / TILE))
	for j in range(1, n):
		var t := float(j) / n
		var p := a.lerp(b, t)
		pts.append(Vector3(p.x, ground(p) + lerpf(over_a, over_b, t), p.y))
	pts.append(to)


# --- The woods ----------------------------------------------------------------------

func _woods() -> void:
	_vegetation_parts.woods(self)


func _farmland(p: Vector2) -> bool:
	return _vegetation_parts.farmland(self, p)


func _hedgerows() -> void:
	_vegetation_parts.hedgerows(self)


## Something built there: a district's blocks or streets (or within `margin`
## tiles of them).
func _built(p: Vector2, margin := 0.8) -> bool:
	for d in districts:
		var l := d.local(p)
		var tx := l.x / TILE
		var tz := l.z / TILE
		for ox in [-margin, margin]:
			for oz in [-margin, margin]:
				var b := Vector2i(floori((tx + ox) / PITCH), floori((tz + oz) / PITCH))
				if d.blocks.has(b):
					return true
	return false


func _on_road(p: Vector2) -> bool:
	for r in _roads:
		if Geometry2D.get_closest_point_to_segment(p, r[0], r[1]).distance_to(p) < TILE * 1.1:
			return true
	for b in bridges:
		var a := Vector2(b[0].x, b[0].z)
		var c := Vector2(b[1].x, b[1].z)
		if Geometry2D.get_closest_point_to_segment(p, a, c).distance_to(p) < TILE * 1.2:
			return true
	return false


# --- The rocky outcrops --------------------------------------------------------------

func _rocks() -> void:
	_terrain_parts.rocks(self)


func _lay_rock(rng: RandomNumberGenerator, p: Vector2, size: float, crag: float, laid: Array[Vector4], at: Array) -> float:
	return _terrain_parts.lay_rock(self, rng, p, size, crag, laid, at)


func _rock_mesh(seed: int) -> ArrayMesh:
	return _terrain_parts.rock_mesh(self, seed)


# --- Loose houses, the walk and the sports ground ------------------------------------

func _loose_houses() -> void:
	_places_parts.loose_houses(self)


func _walk() -> void:
	_places_parts.walk(self)


func _sports() -> void:
	_places_parts.sports(self)


func _places() -> void:
	_places_parts.places(self)


func _clear_spot(r: float) -> Vector2:
	return _places_parts.clear_spot(self, r)


func _clear(p: Vector2, r: float) -> bool:
	return _places_parts.clear(self, p, r)


func _nearest_node(p: Vector2) -> Array:
	return _places_parts.nearest_node(self, p)


func _mall(c: Vector2) -> void:
	_places_parts.mall(self, c)


func _car(at: Vector3, basis: Basis) -> void:
	_places_parts.car(self, at, basis)


func _big_park(c: Vector2, r: float) -> void:
	_places_parts.big_park(self, c, r)


func _near_path(at: Vector3, paths: Array, r: float) -> bool:
	return _places_parts.near_path(self, at, paths, r)


func _disc(at: Vector3, r: float, h: float, colour: Color, material: Material = null) -> void:
	_places_parts.disc(self, at, r, h, colour, material)


func _near_bridge(p: Vector2, r: float) -> bool:
	for b in bridges:
		if Geometry2D.get_closest_point_to_segment(p, Vector2(b[0].x, b[0].z), Vector2(b[1].x, b[1].z)).distance_to(p) < r:
			return true
	return false


func _on_walk(p: Vector2) -> bool:
	var d := across(p)
	var mid := -(RIVER_WIDTH * 0.5 + WALK_OFF)
	return absf(d - mid) < WALK_WIDTH * 0.5 + 0.35


func _take(p: Vector2, r: float) -> void:
	var cell := Vector2i(floori(p.x / TAKEN_CELL), floori(p.y / TAKEN_CELL))
	if not _taken.has(cell):
		_taken[cell] = []
	_taken[cell].append(Vector3(p.x, p.y, r))


## Something (a loose house, a rock, a pitch) within its reach of p, and
## `extra` more.
func _near_taken(p: Vector2, extra := 0.0) -> bool:
	var cell := Vector2i(floori(p.x / TAKEN_CELL), floori(p.y / TAKEN_CELL))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			for t in _taken.get(cell + Vector2i(dx, dy), []):
				if Vector2(t.x, t.y).distance_to(p) < t.z + extra:
					return true
	return false


# --- Night light --------------------------------------------------------------------

## A street lamp, and its pool of light on the ground.
func _lamp(at: Vector3, turn: float) -> void:
	_add("calles/light-square.glb", at, turn, TILE * 1.1, _own(0.0))
	_pool(at + Vector3(sin(turn), 0, cos(turn)) * -0.35, 1.7, GLOW_LAMP)


func _pool(at: Vector3, radius: float, colour: Color) -> void:
	if _shown(at, radius, "pool"):
		_pools.append([at, radius, colour])


## Every pool of light, one MultiMesh of flat quads a hair above the ground.
func _light_pools() -> void:
	if _pools.is_empty():
		return
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = _pools.size()
	for i in _pools.size():
		var at: Vector3 = _pools[i][0]
		var r: float = _pools[i][1]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(r * 2.0, 1, r * 2.0)), at + Vector3(0, 0.16, 0)))
		mm.set_instance_custom_data(i, _pools[i][2])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = POOL_SHADER
	mmi.material_override = m
	root.add_child(mmi)


## Whether something at `at`, r round it, is built (seen), counted by kind.
func _shown(at: Vector3, r: float, kind: String) -> bool:
	var ok: bool = not seen.is_valid() or seen.call(at, r)
	var tally := made if ok else unseen
	tally[kind] = tally.get(kind, 0) + 1
	return ok


## A glowing material, one for each colour and energy (so its boxes batch).
func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var key := [colour, energy]
	if not _materials.has(key):
		var m := MenuStage._material(colour).duplicate() as StandardMaterial3D
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = energy
		_materials[key] = m
	return _materials[key]


# --- The way between two places ----------------------------------------------------

func _node(k: Vector3i, at: Vector3) -> void:
	_nodes[k] = at
	if not _links.has(k):
		_links[k] = {}


func _link(a: Vector3i, b: Vector3i) -> void:
	var dd: float = (_nodes[a] as Vector3).distance_to(_nodes[b])
	_links[a][b] = dd
	_links[b][a] = dd


## The crossing of district i's streets nearest the front of block b (the
## street on its near side), and where that front is.
func door(i: int, b: Vector2i) -> Array:
	var d := districts[i]
	var front := d.world(Vector3((b.x * PITCH + PITCH * 0.5) * TILE, 0, (b.y + 1) * PITCH * TILE))
	front.y = street_y(d, Vector2(front.x, front.z))
	var best := Vector3i(i, b.x * PITCH, (b.y + 1) * PITCH)
	var other := Vector3i(i, (b.x + 1) * PITCH, (b.y + 1) * PITCH)
	return [front, best, other]


## The way along the streets (and over a bridge, if it must) from the front
## of one block to the front of another: the points to go through.
func route(from: Array, to: Array) -> Array[Vector3]:
	var a: Array = door(from[0], from[1])
	var b: Array = door(to[0], to[1])
	var starts := [a[1], a[2]].filter(func(k): return _nodes.has(k))
	var goals := [b[1], b[2]].filter(func(k): return _nodes.has(k))
	var out: Array[Vector3] = [a[0]]
	if starts.is_empty() or goals.is_empty():
		out.append(b[0])
		return out
	# Dijkstra, small enough to do by hand.
	var dist := {}
	var prev := {}
	var open := []
	for k in starts:
		dist[k] = (a[0] as Vector3).distance_to(_nodes[k])
		open.append(k)
	var reached = null
	while not open.is_empty():
		var best_i := 0
		for j in open.size():
			if dist[open[j]] < dist[open[best_i]]:
				best_i = j
		var k = open[best_i]
		open.remove_at(best_i)
		if k in goals:
			reached = k
			break
		for n in _links[k]:
			var nd: float = dist[k] + _links[k][n]
			if nd < dist.get(n, INF):
				dist[n] = nd
				prev[n] = k
				if not n in open:
					open.append(n)
	if reached == null:
		out.append(b[0])
		return out
	var keys := []
	var k = reached
	while k != null:
		keys.push_front(k)
		k = prev.get(k, null)
	# Along the streets and roads, over the ground as it rises and falls;
	# straight over a bridge.
	_over_ground(out, a[0], _nodes[keys[0]])
	for j in range(1, keys.size()):
		var ka: Vector3i = keys[j - 1]
		var kb: Vector3i = keys[j]
		if ka.x == -1 and kb.x == -1:
			# Over a bridge: along its deck, over the road on it.
			var way: Array = bridges[ka.y - 1][2].duplicate()
			if ka.z == 1:
				way.reverse()
			out[out.size() - 1] = way[0] + Vector3(0, 0.18, 0)
			for w in range(1, way.size()):
				out.append((way[w] as Vector3) + Vector3(0, 0.18, 0))
		else:
			_over_ground(out, _nodes[ka], _nodes[kb])
	_over_ground(out, _nodes[keys[keys.size() - 1]], b[0])
	return out


# --- Making -----------------------------------------------------------------------

## A building's own look: its wall and roof tints (a number each), whether
## its roof takes the tint (1 for houses), its windows' own luck.
func _own(roof: float) -> Color:
	return Color(_rng.randf(), _rng.randf(), roof, 1.0)


## How much to scale a model for it to be `across` wide at most.
func _fit(path: String, wide: float) -> float:
	var batch := _batch(path)
	var size: Vector3 = batch.size
	return wide / maxf(size.x, size.z)


## One more of model `path`: at, turned (about y) and scaled; sheared up
## `tilt` (the rise for each unit across x and z) to lie on a slope.
func _add(path: String, at: Vector3, turn: float, k := TILE, own := Color(0, 0, 0, 1), tilt := Vector2.ZERO) -> void:
	var batch := _batch(path)
	if not _shown(at, (batch.size as Vector3).length() * k * 0.5, path.get_slice("/", 0)):
		return
	var xf := Transform3D(Basis(Vector3.UP, turn).scaled(Vector3.ONE * k), at)
	if tilt != Vector2.ZERO:
		xf.basis = Basis(Vector3(1, tilt.x, 0), Vector3.UP, Vector3(0, tilt.y, 1)) * xf.basis
	(batch.at as Array).append(xf * (batch.inner as Transform3D))
	(batch.own as Array).append(own)


func _batch(path: String) -> Dictionary:
	if not _batches.has(path):
		var scene: Node = (load(KITS + path) as PackedScene).instantiate()
		var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
		var inner := Transform3D.IDENTITY
		var n: Node = mi
		while n != scene:
			inner = (n as Node3D).transform * inner
			n = n.get_parent()
		var aabb := inner * mi.get_aabb()
		_batches[path] = {"mesh": mi.mesh, "inner": inner, "size": aabb.size, "at": [], "own": []}
		scene.free()
	return _batches[path]


## Every model's copies as one MultiMesh, in the night's colours.
func _flush() -> void:
	for path in _batches:
		var batch: Dictionary = _batches[path]
		var at: Array = batch.at
		if at.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = batch.mesh
		mm.instance_count = at.size()
		for i in at.size():
			mm.set_instance_transform(i, at[i])
			mm.set_instance_custom_data(i, batch.own[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _night(String(path).get_slice("/", 0))
		if String(path).begins_with("calles/road"):
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)


## What stands between the camera and `at` (from it towards the camera,
## `to`), as far as `r` round that line, seen through (NIGHT_SHADER); r 0,
## nothing is.
func see_through(at: Vector3, to: Vector3, r: float) -> void:
	for m in _materials.values():
		if m is ShaderMaterial:
			(m as ShaderMaterial).set_shader_parameter("cut_at", at)
			(m as ShaderMaterial).set_shader_parameter("cut_to", to)
			(m as ShaderMaterial).set_shader_parameter("cut_r", r)


## A kit's night material: its colour map, its windows lit (the buildings),
## its lamps glowing (the streets).
func _night(kit: String) -> ShaderMaterial:
	if not _materials.has(kit):
		var m := ShaderMaterial.new()
		m.shader = Shader.new()
		m.shader.code = NIGHT_SHADER
		m.set_shader_parameter("colormap", load(KITS + kit + "/Textures/colormap.png"))
		m.set_shader_parameter("night", Vector3(NIGHT.r, NIGHT.g, NIGHT.b))
		m.set_shader_parameter("window_lit", Vector3(WINDOW_LIT.r, WINDOW_LIT.g, WINDOW_LIT.b))
		m.set_shader_parameter("lit_share", LIT_SHARE)
		m.set_shader_parameter("windows", 0.0 if kit == "calles" else 1.0)
		m.set_shader_parameter("lamps", 1.0 if kit == "calles" else 0.0)
		m.set_shader_parameter("walls", PackedVector3Array(WALLS.map(func(c): return Vector3(c.r, c.g, c.b))))
		m.set_shader_parameter("roofs", PackedVector3Array(ROOFS.map(func(c): return Vector3(c.r, c.g, c.b))))
		_materials[kit] = m
	return _materials[kit]


## A box of size s: one unit box scaled, kept with every other of its
## material (and shadow) to be drawn as one MultiMesh (_flush_boxes).
## Never seen: not made at all.
func _box(s: Vector3, colour: Color, at: Vector3, turn := Basis.IDENTITY, shadow := true, material: Material = null) -> void:
	if not _shown(at, s.length() * 0.5, "box"):
		return
	var m: Material = material if material else MenuStage._material(colour)
	var key := [m, shadow]
	if not _boxes.has(key):
		_boxes[key] = []
	(_boxes[key] as Array).append(Transform3D(turn * Basis.from_scale(s), at))


## A box from a to b (their middles), w wide and h thick, tilted with the
## slope between them.
func _beam(a: Vector3, b: Vector3, w: float, h: float, colour: Color) -> void:
	var along := b - a
	var basis := Basis.looking_at(along.normalized(), Vector3.UP)
	_box(Vector3(w, h, along.length()), colour, (a + b) * 0.5, basis)


## Every box as one MultiMesh per material (and shadow).
func _flush_boxes() -> void:
	var unit := BoxMesh.new()
	for key in _boxes:
		var at: Array = _boxes[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = at.size()
		for i in at.size():
			mm.set_instance_transform(i, at[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = key[0]
		if not key[1]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	_boxes.clear()
