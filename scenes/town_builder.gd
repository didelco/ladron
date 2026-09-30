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
	return Vector2(p.dot(along), p.dot(up))


## The point of the plan at s along and q up.
func point(s: float, q: float) -> Vector2:
	return along * s + up * q


## How far up the middle of the river is, at s along it.
func river_at(s: float) -> float:
	return MEANDER * sin(s * TAU / MEANDER_LENGTH + 0.8)


## How far a point is from the middle of the river, across it: negative on
## the near bank, positive on the far one.
func across(p: Vector2) -> float:
	var f := frame(p)
	var slope := MEANDER * TAU / MEANDER_LENGTH * cos(f.x * TAU / MEANDER_LENGTH + 0.8)
	return (f.y - river_at(f.x)) / sqrt(1.0 + slope * slope)


## How high the ground is at a point: the river's bed below it all, level
## on the near bank, up the slope to RISE on the far one and rolling on up
## from there (_upland); the rocky outcrops' own rise on top (_crags).
func ground(p: Vector2) -> float:
	var d := across(p)
	var half := RIVER_WIDTH * 0.5
	if absf(d) < half + 0.3:
		return lerpf(-0.55, 0.0, smoothstep(half - 0.6, half + 0.3, absf(d)))
	if d < 0.0:
		return _crags(p)
	return RISE * smoothstep(half + 0.3, half + SLOPE, d) + _upland(p, d) + _crags(p)


## How much higher than RISE the high bank is at p, d across from the
## river: rising towards the back, in low hills, nothing at the top of the
## slope.
func _upland(p: Vector2, d: float) -> float:
	var top := RIVER_WIDTH * 0.5 + SLOPE
	var fade := smoothstep(top, top + UPLAND_FADE, d)
	if fade <= 0.0:
		return 0.0
	var back := UPLAND_RISE * clampf((d - top) / UPLAND_DEPTH, 0.0, 1.0)
	return fade * (back + HILLS * (_hills.get_noise_2dv(p) + 0.35))


## How far into a rocky outcrop a point is (the one it is furthest into):
## 0 outside, 1 at its top.
func _rocky(p: Vector2) -> float:
	var f := frame(p)
	var k := 0.0
	for o in OUTCROPS.size():
		k = maxf(k, _outcrop(o, f))
	return k


## The ground's rise under the outcrops.
func _crags(p: Vector2) -> float:
	var f := frame(p)
	var h := 0.0
	for o in OUTCROPS.size():
		var k := _outcrop(o, f)
		if k > 0.0:
			h += float(OUTCROPS[o][2]) * k
	return h


## Where outcrop o's middle is on the plan.
func _outcrop_at(o: int) -> Vector2:
	var at: Vector2 = OUTCROPS[o][0]
	return point(at.x, river_at(at.x) + at.y)


## How far into outcrop o a point (s along, q up: f) is: 0 outside, 1 at
## its top; its edge wavers so it is no circle.
func _outcrop(o: int, f: Vector2) -> float:
	var at: Vector2 = OUTCROPS[o][0]
	var off := f - Vector2(at.x, river_at(at.x) + at.y)
	var r: float = OUTCROPS[o][1]
	if off.length() > r * 1.4:
		return 0.0
	var a := atan2(off.y, off.x)
	var wobble := 1.0 + 0.22 * sin(a * 3.0 + 1.3 + o * 2.1) + 0.12 * sin(a * 7.0 + o)
	return smoothstep(1.0, 0.35, off.length() / (r * wobble))


## On the sports ground: along its stretch of the near bank, back from the
## water.
func _in_sports(p: Vector2) -> bool:
	var s := frame(p).x
	var d := across(p)
	return s > SPORTS.x and s < SPORTS.y and d < -RIVER_WIDTH * 0.5 and d > -SPORTS_DEPTH


## The way the river runs at s along it, and the way across it (towards
## the far bank).
func _tangent(s: float) -> Vector2:
	var slope := MEANDER * TAU / MEANDER_LENGTH * cos(s * TAU / MEANDER_LENGTH + 0.8)
	return (along + up * slope).normalized()


func _across_dir(s: float) -> Vector2:
	var slope := MEANDER * TAU / MEANDER_LENGTH * cos(s * TAU / MEANDER_LENGTH + 0.8)
	return (up - along * slope).normalized()


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

## The ground as one mesh, following ground(): grass everywhere, darker
## meadow here and there, the river's banks and bed.
func _terrain() -> void:
	var step := 0.8
	var n := int((REACH + 8.0) * 2.0 / step)
	var lo := -(REACH + 8.0)
	var heights := PackedFloat32Array()
	var colours := PackedColorArray()
	heights.resize((n + 1) * (n + 1))
	colours.resize((n + 1) * (n + 1))
	# Only the squares ever seen, looked at in patches of TERRAIN_PATCH a side;
	# the ground worked out only at their corners.
	var patches := ceili(float(n) / TERRAIN_PATCH)
	var kept := PackedByteArray()
	kept.resize(patches * patches)
	var needed := PackedByteArray()
	needed.resize((n + 1) * (n + 1))
	for pj in patches:
		for pi in patches:
			var mid := Vector3(lo + (pi + 0.5) * TERRAIN_PATCH * step, 0.0, lo + (pj + 0.5) * TERRAIN_PATCH * step)
			mid.y = ground(Vector2(mid.x, mid.z))
			if not _shown(mid, TERRAIN_PATCH * step * 0.71 + RISE * 0.5, "ground"):
				continue
			kept[pj * patches + pi] = 1
			for j in range(pj * TERRAIN_PATCH, mini((pj + 1) * TERRAIN_PATCH, n) + 1):
				for i in range(pi * TERRAIN_PATCH, mini((pi + 1) * TERRAIN_PATCH, n) + 1):
					needed[j * (n + 1) + i] = 1
	var half := RIVER_WIDTH * 0.5
	for j in n + 1:
		for i in n + 1:
			var k := j * (n + 1) + i
			if not needed[k]:
				continue
			var p := Vector2(lo + i * step, lo + j * step)
			heights[k] = ground(p)
			var d := absf(across(p))
			var c := PARK.lerp(MEADOW, 0.5 + 0.5 * sin(p.x * 0.31 + sin(p.y * 0.23) * 2.0))
			if d < half + 0.4:
				c = RIVERBED.lerp(BANK, smoothstep(half - 0.5, half + 0.4, d))
			colours[k] = c
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			if not kept[(j / TERRAIN_PATCH) * patches + i / TERRAIN_PATCH]:
				continue
			var quad := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for v in quad:
				var k: int = v.y * (n + 1) + v.x
				st.set_color(colours[k])
				st.add_vertex(Vector3(lo + v.x * step, heights[k], lo + v.y * step))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	mi.material_override = m
	root.add_child(mi)


## The water: a sheet over the river's bed, and the moon on it in strips
## along the bends.
func _water() -> void:
	var span := (REACH + 8.0) * 2.0
	_box(Vector3(span, 0.02, span), WATER, Vector3(0, -0.22, 0), Basis.IDENTITY, false)
	var s := -REACH * 1.5
	while s < REACH * 1.5:
		s += _rng.randf_range(0.8, 2.2)
		var at := point(s, river_at(s) + _rng.randf_range(-0.9, 0.9))
		if absf(at.x) > REACH + 6.0 or absf(at.y) > REACH + 6.0:
			continue
		var dir := _tangent(s)
		_box(Vector3(0.05, 0.02, _rng.randf_range(0.3, 0.9)), WATER_GLINT, Vector3(at.x, -0.2, at.y), Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP), false)


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

## A tree at `at`: in town (a garden, a yard, a park) mostly the kit's, now
## and then a birch, an oak or a flowering bush; out in the wild, whatever
## grows there (_kind_at).
func _tree(at: Vector3, wild := false) -> void:
	var kind := _kind_at(Vector2(at.x, at.z)) if wild else _pick({"kit": 6.0, "oak": 1.5, "birch": 1.0, "autumn": 0.4, "bloom": 0.8})
	if kind == "kit":
		var path := "suburbios/tree-large.glb" if _rng.randf() < 0.6 else "suburbios/tree-small.glb"
		_add(path, at, _rng.randf() * TAU, TILE * _rng.randf_range(1.5, 2.1), _own(0.0))
	else:
		_plant(kind, at)


## What grows at p out in the wild, by the lie of the land and its patches:
## pines up the slope and in their stands, poplars by the water, birch
## groves and autumn copses, oaks and the kit's trees everywhere else,
## a bush now and then.
func _kind_at(p: Vector2) -> String:
	var d := across(p)
	var conifer := _conifers.get_noise_2dv(p) * 0.5 + 0.5
	var grove := _groves.get_noise_2dv(p)
	var on_slope := d > RIVER_WIDTH * 0.5 and d < RIVER_WIDTH * 0.5 + SLOPE + 1.0
	return _pick({
		"kit": 1.5,
		"oak": 2.2 * (1.0 - conifer),
		"pine": 4.0 * conifer * conifer + (2.5 if on_slope else 0.0),
		"birch": 4.0 * maxf(0.0, grove - 0.1),
		"autumn": 4.0 * maxf(0.0, -grove - 0.25),
		"poplar": 3.0 if absf(d) < RIVER_WIDTH * 0.5 + 3.0 else 0.15,
		"bush": 0.7,
	})


## One of the keys, each as likely as its weight.
func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := _rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return String(k)
	return String(weights.keys()[0])


## A plant of a kind made here, standing at `at`: its own size, width, turn
## and tint (autumn's leaves anything from gold to red).
func _plant(kind: String, at: Vector3) -> void:
	var sizes := {"pine": Vector2(1.7, 2.8), "oak": Vector2(1.3, 2.0), "birch": Vector2(1.4, 2.2), "poplar": Vector2(2.0, 3.0),
		"autumn": Vector2(1.3, 2.0), "bush": Vector2(0.5, 0.9), "bloom": Vector2(0.5, 0.8)}
	var span: Vector2 = sizes[kind]
	var size := _rng.randf_range(span.x, span.y)
	if not _shown(at, size, kind):
		return
	var wide := size * _rng.randf_range(0.85, 1.15)
	var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(wide, size, wide))
	var v := _rng.randf_range(0.85, 1.12)
	var tint := Color(v * _rng.randf_range(0.95, 1.05), v, v * _rng.randf_range(0.95, 1.05))
	if kind == "autumn":
		var hues := [Color(1, 1, 1), Color(1.15, 1.1, 0.6), Color(1.05, 0.72, 0.7)]
		tint *= hues[_rng.randi() % hues.size()] as Color
	if not _plants.has(kind):
		_plants[kind] = []
	(_plants[kind] as Array).append([Transform3D(basis, at), tint])


## A hedge from a to b, `tall` high, on the ground between them.
func _hedge(a: Vector3, b: Vector3, tall := 0.34) -> void:
	var run := Vector3(b.x - a.x, 0, b.z - a.z)
	if run.length() < 0.05:
		return
	var mid := (a + b) * 0.5
	if not _shown(mid, run.length() * 0.5 + 0.3, "hedge"):
		return
	var basis := Basis.looking_at(run.normalized(), Vector3.UP) * Basis.from_scale(Vector3(_rng.randf_range(0.9, 1.1), tall * _rng.randf_range(0.85, 1.15), run.length() + 0.06))
	var v := _rng.randf_range(0.88, 1.1)
	if not _plants.has("hedge"):
		_plants["hedge"] = []
	(_plants["hedge"] as Array).append([Transform3D(basis, mid), Color(v, v, v)])


## Every plant made here as one MultiMesh a kind, each in its own tint.
func _flush_plants() -> void:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.85
	m.rim_enabled = true
	m.rim = 0.3
	for kind in _plants:
		var list: Array = _plants[kind]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _plant_mesh(String(kind))
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i][0])
			mm.set_instance_color(i, list[i][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		if kind in ["bush", "bloom"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)
	_plants.clear()


## A kind of plant, a metre or so high (a hedge a metre long), low and
## flat-faced like the kits': a trunk and a crown of cones or balls.
func _plant_mesh(kind: String) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"pine":
			_shape(st, _cone(0.05, 0.075, 0.16), Vector3(0, 0.08, 0), TRUNK.darkened(0.1))
			_shape(st, _cone(0.055, 0.07, 0.22), Vector3(0, 0.24, 0), TRUNK)
			for k in 4:
				_shape(st, _cone(0.0, 0.32 - k * 0.07, 0.34), Vector3(0, 0.38 + k * 0.165, 0), PINE_GREEN.lightened(k * 0.05))
		"oak", "autumn":
			var leaves := OAK_GREEN if kind == "oak" else AUTUMN_LEAVES
			_shape(st, _cone(0.05, 0.07, 0.45), Vector3(0, 0.22, 0), TRUNK)
			_shape(st, _ball(0.3), Vector3(0, 0.62, 0), leaves)
			_shape(st, _ball(0.24), Vector3(0.17, 0.78, 0.07), leaves.lightened(0.08))
			_shape(st, _ball(0.22), Vector3(-0.15, 0.74, -0.11), leaves.darkened(0.08))
			_shape(st, _ball(0.16), Vector3(0.02, 0.9, -0.12), leaves.lightened(0.14))
			_shape(st, _ball(0.14), Vector3(-0.2, 0.58, 0.16), leaves.darkened(0.04))
		"birch":
			_shape(st, _cone(0.03, 0.04, 0.8), Vector3(0, 0.4, 0), BIRCH_BARK)
			_shape(st, _ball(0.19), Vector3(0, 0.68, 0), BIRCH_GREEN, Vector3(1, 1.3, 1))
			_shape(st, _ball(0.14), Vector3(0.12, 0.86, 0.05), BIRCH_GREEN.lightened(0.08), Vector3(1, 1.2, 1))
			_shape(st, _ball(0.12), Vector3(-0.11, 0.8, -0.08), BIRCH_GREEN.darkened(0.06), Vector3(1, 1.2, 1))
		"poplar":
			_shape(st, _cone(0.04, 0.05, 0.3), Vector3(0, 0.15, 0), TRUNK)
			_shape(st, _ball(0.15), Vector3(0, 0.44, 0), POPLAR_GREEN.darkened(0.04), Vector3(1, 1.4, 1))
			_shape(st, _ball(0.165), Vector3(0, 0.68, 0), POPLAR_GREEN, Vector3(1, 1.5, 1))
			_shape(st, _ball(0.13), Vector3(0, 0.92, 0), POPLAR_GREEN.lightened(0.08), Vector3(1, 1.3, 1))
		"bush", "bloom":
			_shape(st, _ball(0.46), Vector3(0, 0.24, 0), BUSH_GREEN, Vector3(1, 0.66, 1))
			_shape(st, _ball(0.3), Vector3(0.27, 0.2, 0.1), BUSH_GREEN.lightened(0.07), Vector3(1, 0.72, 1))
			_shape(st, _ball(0.24), Vector3(-0.22, 0.16, -0.16), BUSH_GREEN.darkened(0.05), Vector3(1, 0.7, 1))
			if kind == "bloom":
				for k in 6:
					var a := k * TAU / 6.0 + 0.4
					_shape(st, _ball(0.09), Vector3(cos(a) * 0.36, 0.34 + 0.08 * sin(a * 3.0), sin(a) * 0.36), BLOSSOM)
		"hedge":
			# A base block, clipped square, with a row of smaller lobes along
			# the top so it reads as trimmed foliage, not a smooth slab.
			_shape(st, BoxMesh.new(), Vector3(0, 0.36, 0), HEDGE_GREEN, Vector3(0.34, 0.72, 1.0))
			for k in 5:
				var z := -0.42 + k * 0.21
				var h := 0.1 if k % 2 == 0 else 0.06
				_shape(st, _ball(0.18), Vector3(0, 0.72 + h, z), HEDGE_GREEN.lightened(0.05 + 0.03 * (k % 2)), Vector3(1.0, 0.62, 1.15))
	st.generate_normals()
	return st.commit()


## A primitive's triangles into st, each corner its own (flat faces),
## stretched and moved, in one colour.
func _shape(st: SurfaceTool, mesh: PrimitiveMesh, at: Vector3, colour: Color, stretch := Vector3.ONE) -> void:
	var arrays := mesh.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	st.set_color(colour)
	for i in index:
		st.add_vertex(verts[i] * stretch + at)


func _cone(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 6
	c.rings = 0
	return c


func _ball(r: float) -> SphereMesh:
	var b := SphereMesh.new()
	b.radius = r
	b.height = r * 2.0
	b.radial_segments = 6
	b.rings = 3
	return b


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

## Trees wherever there is land and nothing built: along the river, up the
## slope, between the districts and out past them. Thicker on the slope,
## a lone one here and there in the fields, bushes under them; each what
## grows there (_kind_at).
func _woods() -> void:
	var y := -(REACH + 6.0)
	while y < REACH + 6.0:
		var x := -(REACH + 6.0)
		while x < REACH + 6.0:
			var p := Vector2(x + _rng.randf_range(-0.5, 0.5) * WOOD_STEP, y + _rng.randf_range(-0.5, 0.5) * WOOD_STEP)
			x += WOOD_STEP
			if seen.is_valid() and not seen.call(Vector3(p.x, ground(p), p.y), TILE * 2.0):
				continue
			var d := across(p)
			if absf(d) < RIVER_WIDTH * 0.5 + 0.5:
				continue
			var on_slope := d > 0.0 and d < RIVER_WIDTH * 0.5 + SLOPE
			var share := 0.85 if on_slope else 0.55
			if _farmland(p):
				share = 0.05
			if _rng.randf() > share:
				continue
			if _built(p) or _on_road(p) or _near_taken(p) or _rocky(p) > 0.55 or _on_walk(p):
				continue
			var at := Vector3(p.x, ground(p) - 0.02, p.y)
			if _rng.randf() < 0.15:
				_plant("bush", at)
			else:
				_tree(at, true)
		y += WOOD_STEP


## Out of town, where the fields are (_fields): open land clear of the
## water and the slope, the rocks, the pitches and the districts.
func _farmland(p: Vector2) -> bool:
	if _fields.get_noise_2dv(p) < -0.05:
		return false
	var d := across(p)
	if d > -(RIVER_WIDTH * 0.5 + WALK_OFF + WALK_WIDTH + 1.5) and d < RIVER_WIDTH * 0.5 + SLOPE + 0.5:
		return false
	return _rocky(p) == 0.0 and not _in_sports(p) and not _built(p, 1.0)


## Hedges round the fields: lines along the river's bends and across them,
## FIELD or so apart, a gap for a gate now and then, a tree in them here
## and there; not over a road nor into a house's garden.
func _hedgerows() -> void:
	for across_lines in [false, true]:
		var line := -REACH * 1.2 + _rng.randf() * FIELD
		while line < REACH * 1.2:
			var t := -REACH * 1.2
			var prev := Vector3.INF
			while t < REACH * 1.2:
				var f := Vector2(line, t) if across_lines else Vector2(t, line)
				var p := point(f.x, river_at(f.x) + f.y)
				t += HEDGE_STEP
				var ok := absf(p.x) < REACH and absf(p.y) < REACH and _rng.randf() > 0.015
				if ok and seen.is_valid():
					ok = seen.call(Vector3(p.x, 0, p.y), 1.0)
				if not ok or not _farmland(p) or _on_road(p) or _near_taken(p, 0.3):
					prev = Vector3.INF
					continue
				var here := Vector3(p.x, ground(p), p.y)
				if prev != Vector3.INF:
					_hedge(prev, here)
				prev = here
				if _rng.randf() < 0.07:
					_tree(here, true)
			line += FIELD * _rng.randf_range(0.75, 1.3)


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

## Rocks on each outcrop (OUTCROPS), never in rows: a few heaps spread over
## it (a Poisson spread, the most near its top), each a great rock or a crag
## in the middle and smaller ones leaning in round it, and strays down its
## sides, every one kept its own room from the rest (ROCK_SPACING). Each
## stone one of ROCK_KINDS rough shapes, never the same as a neighbour's,
## stretched its own way and tipped over on all three axes, sat into the
## ground so no edge floats: one MultiMesh a shape, for all the outcrops.
func _rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var at: Array = []
	for k in ROCK_KINDS:
		at.append([])
	# every rock laid: Vector4(x, z, its reach, its shape)
	var laid: Array[Vector4] = []
	for o in OUTCROPS.size():
		var c := _outcrop_at(o)
		var r: float = OUTCROPS[o][1]
		var count: int = OUTCROPS[o][3]
		var big: float = OUTCROPS[o][4]
		var crag: float = OUTCROPS[o][5]
		# The heaps' middles: darts thrown at the outcrop, the nearer its top
		# the likelier, none too near another.
		var want := clampi(count / ROCK_HEAP, 1, 12)
		var gap := r * 1.3 / sqrt(float(want))
		var heaps: Array[Vector2] = []
		var tries := 0
		while heaps.size() < want and tries < want * 60:
			tries += 1
			var p := c + Vector2.from_angle(rng.randf() * TAU) * sqrt(rng.randf()) * r
			if rng.randf() > pow(_rocky(p), 1.5) or heaps.any(func(h: Vector2) -> bool: return h.distance_to(p) < gap):
				continue
			heaps.append(p)
		var placed := 0
		# A great one in the middle of each heap, then smaller ones round it.
		for h in heaps:
			var k := _rocky(h)
			var core := lerpf(1.0, big, k) * rng.randf_range(0.85, 1.25)
			var reach := _lay_rock(rng, h, core, crag * 1.5, laid, at)
			if reach <= 0.0:
				continue
			placed += 1
			var ring := rng.randi_range(6, 11)
			var heaped := 0
			for j in ring * 4:
				if heaped >= ring or placed >= count:
					break
				var size := core * rng.randf_range(0.35, 0.8)
				var p := h + Vector2.from_angle(rng.randf() * TAU) * (reach + size * 0.5) * rng.randf_range(0.45, 1.3)
				if _lay_rock(rng, p, size, crag * 0.5, laid, at) > 0.0:
					placed += 1
					heaped += 1
		# Strays: whatever is left, smaller, anywhere on it.
		tries = 0
		while placed < count and tries < count * 30:
			tries += 1
			var p := c + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * r * 1.25
			var k := _rocky(p)
			var size := lerpf(0.3, big * 0.35, k) * rng.randf_range(0.5, 1.2)
			if _lay_rock(rng, p, size, crag * 0.3, laid, at) > 0.0:
				placed += 1
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	m.rim_enabled = true
	m.rim = 0.3
	for i in at.size():
		if (at[i] as Array).is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _rock_mesh(i + 1)
		mm.instance_count = at[i].size()
		for j in at[i].size():
			mm.set_instance_transform(j, at[i][j][0])
			mm.set_instance_color(j, at[i][j][1])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		root.add_child(mmi)


## One rock `size` across at p, if there is room for it (on its outcrop,
## clear of what is built and of every rock laid: ROCK_SPACING); a crag
## standing up one in `crag`. Its reach round p, or 0 if not laid.
func _lay_rock(rng: RandomNumberGenerator, p: Vector2, size: float, crag: float, laid: Array[Vector4], at: Array) -> float:
	var k := _rocky(p)
	if k <= 0.05 or _built(p) or _on_road(p) or _near_bridge(p, TILE * 2.0) or absf(across(p)) < RIVER_WIDTH * 0.5 + 0.6:
		return 0.0
	# Squat boulders, slabs and, now and then, a crag, each its own stretch.
	var dims := Vector3(rng.randf_range(0.7, 1.6), rng.randf_range(0.5, 0.9), rng.randf_range(0.6, 1.3)) * size
	var tip := 0.3
	if rng.randf() < crag:
		dims = Vector3(rng.randf_range(0.6, 1.0), rng.randf_range(1.3, 1.9 + 0.8 * k), rng.randf_range(0.5, 0.9)) * size * 0.8
		tip = 0.25
	var reach := maxf(dims.x, dims.z) * 0.5
	var near: Array[int] = []
	for q in laid:
		var dd := Vector2(q.x, q.y).distance_to(p)
		if dd < (q.z + reach) * ROCK_SPACING:
			return 0.0
		if dd < (q.z + reach) * 1.8:
			near.append(int(q.w))
	# A shape none of its neighbours has.
	var kinds: Array[int] = []
	for i in ROCK_KINDS:
		if not i in near:
			kinds.append(i)
	var kind: int = kinds[rng.randi() % kinds.size()] if not kinds.is_empty() else rng.randi() % ROCK_KINDS
	var tx := rng.randf_range(-tip, tip)
	var tz := rng.randf_range(-tip, tip)
	var basis := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, tx) * Basis(Vector3.BACK, tz) * Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(dims)
	# Sat down on the lowest ground under it, and in as far as it is tipped.
	var low := ground(p)
	for e in 6:
		low = minf(low, ground(p + Vector2.from_angle(e * TAU / 6.0) * reach * 0.8))
	var sink := sin(maxf(absf(tx), absf(tz))) * reach * 0.5
	var rock := [Transform3D(basis, Vector3(p.x, low + dims.y * 0.12 - sink, p.y)), ROCK.lerp(ROCK_LIGHT, rng.randf())]
	laid.append(Vector4(p.x, p.y, reach, kind))
	_take(p, reach * 1.1)
	if _shown(rock[0].origin, maxf(reach, dims.y) * 1.5, "rock"):
		(at[kind] as Array).append(rock)
	return reach


## A rough stone of its own (seed): a ball of few faces, more or fewer by
## its seed, each corner pushed in or out, its foot cut flat; one in four a
## slab, its top cut flat too.
func _rock_mesh(seed: int) -> ArrayMesh:
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	ball.radial_segments = 5 + seed % 3
	ball.rings = 3 + (seed / 3) % 2
	var arrays := ball.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var spread := 0.45 + 0.1 * (seed % 4)
	var top := 0.4 if seed % 4 == 0 else 1.0
	# The same push for the same corner, seams and all.
	var push := func(v: Vector3) -> Vector3:
		var h := sin(roundf(v.x * 40.0) * 12.9898 + roundf(v.y * 40.0) * 78.233 + roundf(v.z * 40.0) * 37.719 + seed * 4.1) * 43758.5453
		return v * (1.0 - spread * 0.5 + spread * (h - floorf(h)))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in index:
		var v: Vector3 = push.call(verts[i])
		st.add_vertex(Vector3(v.x, clampf(v.y, -0.3, top), v.z))
	st.generate_normals()
	return st.commit()


# --- Loose houses, the walk and the sports ground ------------------------------------

## Houses and chalets out among the trees, each on a garden of its own and
## turned its own way (a little off the way the river runs): on flat land,
## clear of the districts, the roads, the rocks and the water; some with a
## lit pool; windows lit, a pool of light at the door.
func _loose_houses() -> void:
	var letters := "abcdefghijklmnopqrstu"
	var y := -REACH
	while y < REACH:
		var x := -REACH
		while x < REACH:
			var p := Vector2(x, y) + Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * HOUSE_STEP * 0.35
			x += HOUSE_STEP
			if _rng.randf() > HOUSE_SHARE:
				continue
			if seen.is_valid() and not seen.call(Vector3(p.x, ground(p), p.y), TILE * 3.0):
				continue
			var d := across(p)
			if d > -(RIVER_WIDTH * 0.5 + WALK_OFF + WALK_WIDTH + 0.8) and d < RIVER_WIDTH * 0.5 + SLOPE + 0.4:
				continue
			if _rocky(p) > 0.0 or _in_sports(p) or _built(p, 1.8) or _on_road(p) or _near_taken(p, 1.2):
				continue
			var turn := atan2(along.x, along.y) + _rng.randf_range(-0.6, 0.6) + (PI if _rng.randf() < 0.5 else 0.0)
			var basis := Basis(Vector3.UP, turn)
			var chalet := _rng.randf() < 0.45
			var lot := 2.9 if chalet else 2.3
			# Its garden level, at the highest ground under it, on a plinth
			# down to the lowest.
			var h := -INF
			var low := INF
			for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2.ZERO]:
				var w := basis * Vector3(c.x * lot * 0.5, 0, c.y * lot * 0.5)
				var g := ground(p + Vector2(w.x, w.z))
				h = maxf(h, g)
				low = minf(low, g)
			var at := Vector3(p.x, h, p.y)
			if h - low > 0.04:
				var drop := h - low + 0.2
				_box(Vector3(lot, drop, lot), TERRACE_WALL, at + Vector3(0, -drop * 0.5, 0), basis)
			_box(Vector3(lot, 0.05, lot), GARDEN, at + Vector3(0, 0.02, 0), basis)
			var path := "suburbios/building-type-%s.glb" % letters[_rng.randi() % letters.length()]
			_add(path, at + basis * Vector3(0, 0.05, -0.2), turn, _fit(path, lot * (0.62 if chalet else 0.72)), _own(1.0))
			_pool(at + basis * Vector3(0, 0, 0.9), 1.4, GLOW_HOUSE)
			if chalet and _rng.randf() < POOL_SHARE / 0.45:
				var water := basis * Vector3(0.75, 0.06, 0.95) + at
				_box(Vector3(0.8, 0.04, 0.5), POOL_WATER, water, basis, true, _glow(POOL_WATER, 1.4))
				_pool(water, 1.5, GLOW_POOL)
			if _rng.randf() < 0.7:
				_tree(at + basis * Vector3(-lot * 0.4, 0, lot * 0.35))
			_take(p, lot * 0.75)
		y += HOUSE_STEP


## The riverside walk: a paved path along the near bank, following the
## bends, with a lamp and a bench every so often; not where something is
## built on the bank (a museum by the water) nor across a bridge's foot.
func _walk() -> void:
	var s := -REACH * 1.4
	var step := 0.9
	var next_lamp := 0.0
	var prev := Vector3.INF
	while s < REACH * 1.4:
		var dir := _across_dir(s)
		var mid := point(s, river_at(s)) - dir * (RIVER_WIDTH * 0.5 + WALK_OFF)
		s += step
		if absf(mid.x) > REACH + 4.0 or absf(mid.y) > REACH + 4.0 or _built(mid, 0.2) or _near_bridge(mid, 1.6):
			prev = Vector3.INF
			continue
		var here := Vector3(mid.x, 0.03, mid.y)
		if prev != Vector3.INF:
			_beam(prev, here, WALK_WIDTH, 0.04, PATH)
		prev = here
		next_lamp -= step
		if next_lamp <= 0.0:
			next_lamp = WALK_LAMP
			var side := Vector3(-dir.x, 0, -dir.y) * (WALK_WIDTH * 0.5 + 0.25)
			_lamp(here + side, atan2(dir.x, dir.y))
			# A bench facing the water, between two lamps.
			var bench := here + side - Vector3(_tangent(s).x, 0, _tangent(s).y) * WALK_LAMP * 0.5
			_box(Vector3(0.5, 0.12, 0.16), Color("#6b4a3a"), bench + Vector3(0, 0.08, 0), Basis(Vector3.UP, atan2(dir.x, dir.y)))


## The sports ground on the near bank: a football pitch, a basketball court
## and a tennis court, each on its own ground with its white lines and a
## fence, under floodlights (pools of cool light); not in a row, each a
## little off and turned its own way.
func _sports() -> void:
	var s := (SPORTS.x + SPORTS.y) * 0.5
	var dir := _tangent(s)
	var across_dir := _across_dir(s)
	var back := -(RIVER_WIDTH * 0.5 + WALK_OFF + WALK_WIDTH + 1.0)
	var base := point(s, river_at(s)) + across_dir * back
	# Pitch, court, court: along the bank, the pitch nearest the water; where
	# each is, how big, its colour, and how far it is turned.
	var fields := [
		[Vector2(-0.4, -2.7), Vector2(7.0, 4.4), PITCH_GRASS, "pitch", 0.1],
		[Vector2(-2.7, -7.6), Vector2(3.2, 2.2), COURT, "basket", -0.3],
		[Vector2(2.6, -7.0), Vector2(3.4, 1.9), TENNIS, "tennis", 0.22],
	]
	for f in fields:
		var off: Vector2 = f[0] + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.25, 0.25))
		var size: Vector2 = f[1]
		var basis := Basis(Vector3.UP, atan2(dir.x, dir.y) + float(f[4]) + _rng.randf_range(-0.06, 0.06))
		var c2: Vector2 = base + dir * off.x + across_dir * off.y
		var c := Vector3(c2.x, 0.0, c2.y)
		# The ground and its lines: the edge, the halfway line, a circle.
		_box(Vector3(size.y + 0.4, 0.05, size.x + 0.4), PATH.darkened(0.3), c + Vector3(0, 0.02, 0), basis)
		_box(Vector3(size.y, 0.06, size.x), f[2], c + Vector3(0, 0.03, 0), basis)
		for sgn in [-1, 1]:
			_box(Vector3(0.05, 0.07, size.x), LINE, c + basis * Vector3(sgn * size.y * 0.5, 0.035, 0), basis)
			_box(Vector3(size.y, 0.07, 0.05), LINE, c + basis * Vector3(0, 0.035, sgn * size.x * 0.5), basis)
		_box(Vector3(size.y, 0.07, 0.05), LINE, c + Vector3(0, 0.035, 0), basis)
		if f[3] == "pitch":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.55
			torus.outer_radius = 0.6
			ring.mesh = torus
			ring.scale = Vector3(1, 0.1, 1)
			ring.material_override = MenuStage._material(LINE)
			ring.position = c + Vector3(0, 0.07, 0)
			root.add_child(ring)
			for sgn in [-1, 1]:
				_box(Vector3(0.9, 0.35, 0.06), LINE, c + basis * Vector3(0, 0.2, sgn * size.x * 0.5), basis)
		else:
			# A low fence round the court.
			for sgn in [-1, 1]:
				_box(Vector3(0.03, 0.4, size.x + 0.4), RAIL, c + basis * Vector3(sgn * (size.y * 0.5 + 0.2), 0.2, 0), basis)
				_box(Vector3(size.y + 0.4, 0.4, 0.03), RAIL, c + basis * Vector3(0, 0.2, sgn * (size.x * 0.5 + 0.2)), basis)
		# Floodlights at the corners, and their light.
		for sx in [-1, 1]:
			for sz in [-1, 1]:
				var post := c + basis * Vector3(sx * (size.y * 0.5 + 0.35), 0, sz * (size.x * 0.5 + 0.35))
				_box(Vector3(0.06, 1.6, 0.06), RAIL, post + Vector3(0, 0.8, 0))
				_box(Vector3(0.22, 0.1, 0.1), LINE, post + Vector3(0, 1.62, 0), basis, true, _glow(Color(0.9, 0.95, 1.0), 2.5))
		_pool(c, maxf(size.x, size.y) * 0.75, GLOW_FLOOD)
		var span := maxf(size.x, size.y) * 0.6 + 0.6
		_take(c2, span)


## On clear land, as near the museums as there is room for: the mall, then
## the big park.
func _places() -> void:
	var at := _clear_spot(MALL_REACH)
	if at != Vector2.INF:
		_mall(at)
		_take(at, MALL_REACH)
	# The park a little smaller if that is all there is room for.
	var r := BIG_PARK_REACH
	while r >= BIG_PARK_REACH * 0.7:
		at = _clear_spot(r)
		if at != Vector2.INF:
			_big_park(at, r)
			_take(at, r)
			break
		r -= 0.5


## The clear round of land r across nearest a museum (Vector2.INF if none).
func _clear_spot(r: float) -> Vector2:
	var best := Vector2.INF
	var best_d := INF
	var y := -REACH
	while y < REACH:
		var x := -REACH
		while x < REACH:
			var p := Vector2(x, y)
			x += 2.0
			var dd := INF
			for m in museums:
				dd = minf(dd, m.distance_to(p))
			if dd < best_d and _clear(p, r):
				best_d = dd
				best = p
		y += 2.0
	return best


## Land round p, r across, that can be seen, flat and all on one bank, with
## nothing on it: no block, road, walk, rock, pitch or loose house.
func _clear(p: Vector2, r: float) -> bool:
	if seen.is_valid() and not seen.call(Vector3(p.x, ground(p), p.y), 0.0):
		return false
	var bank := signf(across(p))
	var g0 := ground(p)
	for k in 9:
		var q := p if k == 8 else p + Vector2.from_angle(k * TAU / 8.0) * r
		var d := across(q)
		var flat := d < -(RIVER_WIDTH * 0.5 + WALK_OFF + WALK_WIDTH + 0.6) or d > RIVER_WIDTH * 0.5 + SLOPE + 0.6
		if not flat or signf(d) != bank or absf(q.x) > REACH or absf(q.y) > REACH:
			return false
		if _rocky(q) > 0.0 or _in_sports(q) or _built(q, 0.6) or _on_road(q) or _near_taken(q):
			return false
		if absf(ground(q) - g0) > 0.25:
			return false
	return true


## The crossing of the streets of p's bank nearest p, and its key.
func _nearest_node(p: Vector2) -> Array:
	var high := across(p) > 0.0
	var best := Vector3i(-2, 0, 0)
	var best_d := INF
	for k in _nodes:
		if k.x < 0 or districts[k.x].high != high:
			continue
		var n: Vector3 = _nodes[k]
		var dd := Vector2(n.x, n.z).distance_to(p)
		if dd < best_d:
			best_d = dd
			best = k
	return [best, _nodes.get(best, Vector3(p.x, 0, p.y))]


## The mall: a long low hall with a glass front and a taller wing, its sign
## lit on the roof; before it a big car park, bays in rows, cars in half of
## them, lamps over the aisles, bushes round it; a road from its gate to
## the nearest street. Facing that street.
func _mall(c: Vector2) -> void:
	var near: Array = _nearest_node(c)
	var goal: Vector3 = near[1]
	var fwd := (Vector2(goal.x, goal.z) - c).normalized()
	var basis := Basis(Vector3.UP, atan2(fwd.x, fwd.y))
	var o := Vector3(c.x, ground(c), c.y)
	# The car park: a kerb, the tarmac, three rows of fourteen bays.
	_box(Vector3(9.4, 0.06, 5.9), PAVEMENT_EDGE, o + basis * Vector3(0, 0.03, 1.9), basis)
	_box(Vector3(9.0, 0.06, 5.5), ROAD, o + basis * Vector3(0, 0.05, 1.9), basis)
	for row in [[0.1, 1], [2.2, -1], [3.1, 1]]:
		var z: float = row[0]
		var x := -4.2
		while x < 4.3:
			_box(Vector3(0.03, 0.02, 0.85), LINE, o + basis * Vector3(x, 0.085, z), basis)
			if x < 4.0 and _rng.randf() < 0.55:
				_car(o + basis * Vector3(x + 0.3, 0.08, z), basis * Basis(Vector3.UP, (0.0 if int(row[1]) > 0 else PI) + _rng.randf_range(-0.06, 0.06)))
			x += 0.6
	# Lamps over the aisles.
	for z in [1.15, 4.1]:
		for x in [-3.0, 0.0, 3.0]:
			_lamp(o + basis * Vector3(x, 0.08, z), atan2(fwd.x, fwd.y))
	# The hall and its wing, the roof, the glass front and the way in, the signs.
	_box(Vector3(6.8, 1.2, 2.8), MALL_WALL, o + basis * Vector3(0.8, 0.6, -2.6), basis)
	_box(Vector3(7.0, 0.08, 3.0), MALL_ROOF, o + basis * Vector3(0.8, 1.24, -2.6), basis)
	_box(Vector3(2.4, 1.7, 3.2), MALL_WING, o + basis * Vector3(-3.8, 0.85, -2.5), basis)
	_box(Vector3(2.6, 0.08, 3.4), MALL_ROOF, o + basis * Vector3(-3.8, 1.74, -2.5), basis)
	_box(Vector3(5.6, 0.5, 0.04), WINDOW_LIT, o + basis * Vector3(1.0, 0.45, -1.19), basis, false, _glow(WINDOW_LIT, 1.1))
	_box(Vector3(2.0, 0.08, 0.8), MALL_SIGN, o + basis * Vector3(1.0, 0.82, -0.85), basis)
	_box(Vector3(3.0, 0.42, 0.1), MALL_SIGN, o + basis * Vector3(1.0, 1.55, -1.25), basis, false, _glow(MALL_SIGN, 2.6))
	_box(Vector3(1.3, 0.36, 0.1), MALL_SIGN, o + basis * Vector3(-3.8, 1.45, -0.88), basis, false, _glow(MALL_SIGN, 2.2))
	for k in 4:
		_box(Vector3(0.5, 0.25, 0.4), RAIL, o + basis * Vector3(-1.6 + k * 1.2, 1.4, -3.3 + (k % 2) * 0.6), basis)
	_pool(o + basis * Vector3(1.0, 0, -0.6), 2.2, GLOW_HOUSE)
	# Bushes and trees round the car park.
	for sx in [-1, 1]:
		for z in [-0.4, 0.7, 1.8, 2.9, 4.0]:
			_plant("bush" if _rng.randf() < 0.6 else "bloom", o + basis * Vector3(sx * 4.8, 0.02, z + _rng.randf_range(-0.2, 0.2)))
		_tree(o + basis * Vector3(sx * 4.8, 0.02, 4.8))
	# The road from the gate.
	var gate := o + basis * Vector3(0, 0.02, 4.9)
	_node(Vector3i(-3, 0, 0), gate)
	_road_to_nearest(Vector3i(-3, 0, 0), gate, across(c) > 0.0)


## A parked car: its body in one of the cars' colours, a dark cabin on it.
func _car(at: Vector3, basis: Basis) -> void:
	_box(Vector3(0.32, 0.13, 0.62), CARS[_rng.randi() % CARS.size()], at + Vector3(0, 0.09, 0), basis)
	_box(Vector3(0.27, 0.11, 0.32), CAR_GLASS, at + basis * Vector3(0, 0.2, -0.04), basis)


## The big park, r round: a round lawn with a hedge round it, a fountain in the
## middle ringed by a path with benches and lamps, winding paths out to the
## edge, a kiosk, flower beds, and trees of every kind round it all.
func _big_park(c: Vector2, r: float) -> void:
	var o := Vector3(c.x, ground(c), c.y)
	_disc(o + Vector3(0, 0.03, 0), r, 0.06, PARK)
	var paths: Array = []
	# The ring round the fountain.
	for k in 16:
		var a := k * TAU / 16.0
		var b := (k + 1) * TAU / 16.0
		paths.append([o + Vector3(cos(a), 0, sin(a)) * 2.0, o + Vector3(cos(b), 0, sin(b)) * 2.0])
	# Winding ways out, and where they leave the park.
	var exits: Array[float] = []
	var first := _rng.randf() * TAU
	for k in 4:
		var a := first + k * TAU / 4.0 + _rng.randf_range(-0.3, 0.3)
		exits.append(a)
		var bend := _rng.randf_range(-0.5, 0.5)
		var prev := o + Vector3(cos(a), 0, sin(a)) * 2.0
		for j in range(1, 6):
			var t := j / 5.0
			var aa := a + bend * sin(t * PI)
			var here := o + Vector3(cos(aa), 0, sin(aa)) * lerpf(2.0, r - 0.1, t)
			paths.append([prev, here])
			prev = here
	for seg in paths:
		_beam((seg[0] as Vector3) + Vector3(0, 0.07, 0), (seg[1] as Vector3) + Vector3(0, 0.07, 0), 0.5, 0.04, PATH)
	# The fountain: a stone basin, its water lit, a column and a bowl.
	_disc(o + Vector3(0, 0.14, 0), 1.0, 0.24, STONE)
	_disc(o + Vector3(0, 0.27, 0), 0.88, 0.04, POOL_WATER, _glow(POOL_WATER, 0.9))
	_disc(o + Vector3(0, 0.55, 0), 0.12, 0.6, STONE)
	_disc(o + Vector3(0, 0.86, 0), 0.4, 0.08, STONE)
	_disc(o + Vector3(0, 0.91, 0), 0.34, 0.03, POOL_WATER, _glow(POOL_WATER, 1.4))
	_pool(o, 2.4, GLOW_POOL)
	# Benches facing it and lamps between them.
	for k in 6:
		var a := k * TAU / 6.0 + TAU / 12.0
		var at := o + Vector3(cos(a), 0, sin(a)) * 2.55
		_box(Vector3(0.5, 0.12, 0.16), Color("#6b4a3a"), at + Vector3(0, 0.12, 0), Basis(Vector3.UP, -a + PI / 2))
		var lamp_a := a + TAU / 12.0
		_lamp(o + Vector3(cos(lamp_a) * 2.6, 0.06, sin(lamp_a) * 2.6), -lamp_a + PI / 2)
	# A kiosk by the ring, its roof pink.
	var ka := first + TAU / 8.0
	var kiosk := o + Vector3(cos(ka), 0, sin(ka)) * 3.4
	_box(Vector3(0.7, 0.5, 0.7), MALL_WALL, kiosk + Vector3(0, 0.3, 0), Basis(Vector3.UP, ka))
	_box(Vector3(0.95, 0.1, 0.95), MALL_SIGN, kiosk + Vector3(0, 0.6, 0), Basis(Vector3.UP, ka))
	_pool(kiosk, 1.2, GLOW_HOUSE)
	# The hedge round it, open where the paths leave.
	for k in 40:
		var a := k * TAU / 40.0
		var b := (k + 1) * TAU / 40.0
		var gap := false
		for e in exits:
			if absf(angle_difference(e, (a + b) * 0.5)) < 0.22:
				gap = true
		if not gap:
			_hedge(o + Vector3(cos(a), 0.06, sin(a)) * (r - 0.15), o + Vector3(cos(b), 0.06, sin(b)) * (r - 0.15), 0.3)
	# Flower beds and trees, clear of the paths and the kiosk.
	for k in 90:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf_range(0.1, 1.0)) * (r - 0.6)
		var at := o + Vector3(cos(a) * d, 0.06, sin(a) * d)
		if d < 1.3 or at.distance_to(kiosk) < 0.9 or _near_path(at, paths, 0.45):
			continue
		if d < 3.0:
			_plant("bloom" if _rng.randf() < 0.7 else "bush", at)
		elif _rng.randf() < 0.75:
			_tree(at, _rng.randf() < 0.6)


func _near_path(at: Vector3, paths: Array, r: float) -> bool:
	var p := Vector2(at.x, at.z)
	for seg in paths:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		if Geometry2D.get_closest_point_to_segment(p, Vector2(a.x, a.z), Vector2(b.x, b.z)).distance_to(p) < r:
			return true
	return false


## A round slab, r across and h high, its middle at `at`.
func _disc(at: Vector3, r: float, h: float, colour: Color, material: Material = null) -> void:
	if not _shown(at, r, "disc"):
		return
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 24
	c.rings = 0
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = material if material else MenuStage._material(colour)
	mi.position = at
	root.add_child(mi)


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
