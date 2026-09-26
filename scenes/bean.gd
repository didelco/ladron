class_name Bean
extends Node3D
## Sketches for the jelly-bean figures (Fall Guys, Stumble Guys): blocky
## models built from primitives, one per style, to pick a look before modelling
## and rigging the real thing in Blender. Nothing moves yet.
##
## Styles:
##   bean   — one soft capsule for head and body, a face window, stubby limbs.
##   chibi  — a big round head on a small bean body (Stumble Guys).
##   animal — the bean as an animal: a raccoon thief and a bulldog guard.
##   visor  — a capsule with a glass visor across the face (Among Us).
##   crew   — the visor capsule, second pass: ninja thieves (the visor is the
##            slit in the hood) and guards with a face, a moustache and moods.
##
## Faces +Z, feet at y = 0, about 1.1 m tall like Figure.

const STYLES := ["bean", "chibi", "animal", "visor", "crew"]
## A guard's moods, as its face shows them.
const MOODS := ["calm", "suspicious", "alarmed", "angry", "sleepy"]
## Per mood: brow height and tilt (+ angry, - worried), an extra lift for the
## left brow, how open the eyes are, where the pupils look and how big they
## are, the mouth, and the extras.
const FACES := {
	"calm": {"brow_y": 0.0, "tilt": 0.0, "lift_l": 0.0, "open": 0.8, "look": Vector2.ZERO, "pupil": 1.0, "mouth": "smile"},
	"suspicious": {"brow_y": -0.01, "tilt": 0.3, "lift_l": 0.05, "open": 0.45, "look": Vector2(0.45, 0.0), "pupil": 0.85, "mouth": "flat"},
	"alarmed": {"brow_y": 0.05, "tilt": -0.45, "lift_l": 0.0, "open": 1.0, "look": Vector2.ZERO, "pupil": 0.55, "mouth": "o", "sweat": true},
	"angry": {"brow_y": -0.02, "tilt": 0.75, "lift_l": 0.0, "open": 0.65, "look": Vector2(0, -0.1), "pupil": 1.0, "mouth": "shout", "blush": true},
	"sleepy": {"brow_y": -0.01, "tilt": -0.1, "lift_l": 0.0, "open": 0.12, "look": Vector2(0, -0.3), "pupil": 1.0, "mouth": "yawn"},
	"determined": {"brow_y": -0.01, "tilt": 0.45, "lift_l": 0.0, "open": 0.75, "look": Vector2.ZERO, "pupil": 1.0, "mouth": ""},
	"sneaky": {"brow_y": -0.005, "tilt": 0.2, "lift_l": 0.03, "open": 0.45, "look": Vector2(-0.6, 0.0), "pupil": 0.9, "mouth": ""},
	"surprised": {"brow_y": 0.03, "tilt": -0.35, "lift_l": 0.0, "open": 1.0, "look": Vector2.ZERO, "pupil": 0.6, "mouth": ""},
	"wink": {"brow_y": 0.0, "tilt": 0.1, "lift_l": -0.01, "open": 0.9, "look": Vector2(0.2, 0.1), "pupil": 1.0, "mouth": "", "wink": true},
}
const NINJA_MOODS := ["determined", "sneaky", "surprised", "wink"]

const MOUSTACHE := Color("#5a3a26")
const STEEL := Color("#c9ced8")
const BLUSH := Color("#ff7a7a")
const SWEAT := Color("#9fe0ff")
## The ninja suit: near black, the same for every player.
const SUIT := Color("#131217")

const SKIN := Color("#f3d2b3")
const FACE := Color("#fff1e0")
const DARK := Color("#1b1d26")
const NAVY := Color("#23304f")
const EYE := Color("#15131c")
const WHITE := Color("#fbfaff")
const GOLD := Color("#f5c451")
const BAG := Color("#c9b48a")
const GLASS := Color("#9fd8ff")
const LENS := Color("#ffe39a")
const RACCOON := Color("#8f94a3")
const RACCOON_DARK := Color("#3a3d48")
const BULLDOG := Color("#d4a676")
const BULLDOG_DARK := Color("#9b6f47")
const INK := Color("#08070c")
const INK_GROW := 0.008

var guard := false
var style := "bean"
var mood := "calm"
## Parts built while this is on are cloth: matte, with a weave.
var _cloth := false
var _colour: Color
var _accent: Color
var _materials := {}


static func make(style_name: String, kind: String, colour: Color, accent: Color, mood_name := "calm") -> Bean:
	var b := Bean.new()
	b.style = style_name
	b.mood = mood_name
	if style_name == "crew" and kind != "guard" and not NINJA_MOODS.has(mood_name):
		b.mood = "determined"
	b.guard = kind == "guard"
	b._colour = colour
	b._accent = accent
	match style_name:
		"bean": b._bean()
		"chibi": b._chibi()
		"animal": b._animal()
		"visor": b._visor()
		"crew": b._ninja() if not b.guard else b._watchman()
	return b


# --- Styles -----------------------------------------------------------------------

## Fall Guys: head and body one capsule, the face a pale window on the front.
func _bean() -> void:
	_legs(0.12, 0.08, 0.1, DARK if not guard else NAVY)
	_part(self, _capsule(0.3, 0.38), _colour, Vector3(0, 0.65, 0))
	_face_window(0.78, 0.3)
	if guard:
		_eyes(0.8, 0.3, 0.075, 0.05)
		_part(self, _capsule(0.022, 0.07), Color("#4a3226"), Vector3(0, 0.7, 0.31), Vector3(1, 0.5, 0.5), Vector3(0, 0, PI / 2), true)
		_peaked_cap(1.03, 0.25)
		_belt(0.4, 0.302)
		_part(self, _star(0.045), GOLD, Vector3(-0.15, 0.52, 0.27), Vector3.ONE, Vector3(-PI / 2 + 0.3, -0.5, 0), true)
	else:
		_stripes([0.34, 0.45, 0.56], 0.302)
		_beanie(0.9, 0.3)
		_mask(0.79, 0.3)
		_loot_bag(Vector3(0, 0.62, -0.33), 0.2)
	_arms(0.3, 0.58, 0.065, 0.16, _colour, SKIN if guard else DARK)


## Stumble Guys: a big round head on a small body; more of a person.
func _chibi() -> void:
	_legs(0.1, 0.075, 0.1, DARK if not guard else NAVY)
	_part(self, _capsule(0.21, 0.12), _colour, Vector3(0, 0.43, 0))
	_part(self, _sphere(0.29), SKIN, Vector3(0, 0.92, 0))
	_part(self, _sphere(0.035), Color("#e6a88a"), Vector3(0, 0.86, 0.285), Vector3.ONE, Vector3.ZERO, true)
	if guard:
		_eyes(0.95, 0.265, 0.09, 0.06)
		_part(self, _capsule(0.024, 0.08), Color("#4a3226"), Vector3(0, 0.8, 0.265), Vector3(1, 0.5, 0.5), Vector3(0, 0, PI / 2), true)
		_peaked_cap(1.1, 0.25)
		_belt(0.36, 0.212)
		_part(self, _star(0.04), GOLD, Vector3(-0.1, 0.47, 0.18), Vector3.ONE, Vector3(-PI / 2 + 0.3, -0.5, 0), true)
	else:
		_stripes([0.38, 0.48], 0.212)
		_beanie(1.0, 0.29)
		_mask(0.94, 0.29)
		_loot_bag(Vector3(0, 0.48, -0.25), 0.17)
	_arms(0.22, 0.54, 0.06, 0.16, _colour, SKIN if guard else DARK)


## Party Animals: the same bean, but fur and ears; the costume in the player's
## colour. A raccoon wears its own robber's mask; a bulldog is born to guard.
func _animal() -> void:
	var fur := BULLDOG if guard else RACCOON
	var fur_dark := BULLDOG_DARK if guard else RACCOON_DARK
	_legs(0.12, 0.08, 0.1, fur_dark)
	_part(self, _capsule(0.3, 0.38), fur, Vector3(0, 0.65, 0))
	# The costume: a shirt in the player's colour over the lower body.
	_part(self, _capsule(0.305, 0.12), _colour, Vector3(0, 0.51, 0))
	if guard:
		# Jowls and a black nose, floppy ears, the uniform over the fur.
		_part(self, _sphere(0.2), FACE, Vector3(0, 0.78, 0.17), Vector3(1.3, 0.65, 0.75))
		_part(self, _sphere(0.045), EYE, Vector3(0, 0.84, 0.32), Vector3(1.3, 0.9, 0.9), Vector3.ZERO, true)
		for side in [-1, 1]:
			_part(self, _sphere(0.1), fur_dark, Vector3(side * 0.28, 0.96, 0.0), Vector3(0.45, 1.1, 0.8), Vector3(0, 0, side * 0.5))
		_eyes(0.93, 0.28, 0.085, 0.045)
		_belt(0.42, 0.308)
		_part(self, _star(0.045), GOLD, Vector3(-0.15, 0.56, 0.27), Vector3.ONE, Vector3(-PI / 2 + 0.3, -0.5, 0), true)
		_peaked_cap(1.05, 0.24)
	else:
		# Pointed ears, the dark band across the eyes, a striped tail behind.
		for side in [-1, 1]:
			_part(self, _cylinder(0.0, 0.09, 0.16), fur_dark, Vector3(side * 0.17, 1.1, 0), Vector3(1, 1, 0.6), Vector3(0, 0, -side * 0.35))
		_part(self, _sphere(0.2), FACE, Vector3(0, 0.76, 0.16), Vector3(1.2, 0.6, 0.8))
		_part(self, _sphere(0.04), EYE, Vector3(0, 0.79, 0.32), Vector3.ONE, Vector3.ZERO, true)
		_mask(0.9, 0.3, RACCOON_DARK)
		_part(self, _cylinder(0.31, 0.31, 0.04), _accent, Vector3(0, 0.64, 0), Vector3.ONE, Vector3.ZERO, true)
		var tail := _pivot(self, Vector3(0, 0.32, -0.26))
		tail.rotation.x = -1.2
		for i in 5:
			_part(tail, _sphere(0.1 - i * 0.008), fur if i % 2 == 0 else RACCOON_DARK, Vector3(0, i * 0.1, 0), Vector3(1, 0.9, 1))
		_loot_bag(Vector3(0.0, 0.7, -0.33), 0.17)
	_arms(0.3, 0.58, 0.065, 0.16, _colour, fur_dark)


## Among Us: a capsule with a big glass visor; the visor says which way.
func _visor() -> void:
	_legs(0.13, 0.1, 0.1, _accent)
	_part(self, _capsule(0.3, 0.36), _colour, Vector3(0, 0.66, 0), Vector3(1, 1, 0.92))
	var v := _part(self, _capsule(0.13, 0.2), GLASS, Vector3(0, 0.8, 0.22), Vector3(1, 1, 0.55), Vector3(0, 0, PI / 2))
	var shine := v.material_override as StandardMaterial3D
	shine.roughness = 0.08
	shine.metallic_specular = 1.0
	_part(self, _capsule(0.025, 0.1), WHITE, Vector3(0.06, 0.85, 0.29), Vector3(1, 1, 0.5), Vector3(0, 0, PI / 2), true, true)
	if guard:
		_peaked_cap(1.03, 0.25)
		_belt(0.42, 0.3)
		_part(self, _star(0.045), GOLD, Vector3(-0.15, 0.56, 0.25), Vector3.ONE, Vector3(-PI / 2 + 0.3, -0.5, 0), true)
	else:
		_beanie(0.92, 0.29)
		_loot_bag(Vector3(0, 0.62, -0.3), 0.22)
	_arms(0.29, 0.56, 0.06, 0.1, _colour, _accent)


## The ninja (Stumble Guys): a black cloth suit for everyone; what tells the
## players apart is the mask — the band round the eye slit and its tails —
## and the belt, both in the player's colour. A head of its own, a little
## wider than tall, eyes big enough to act with.
func _ninja() -> void:
	_cloth = true
	var suit := SUIT
	var band := _colour
	# Legs and feet: short, the feet rounded and turned out a touch.
	for side in [-1, 1]:
		_part(self, _capsule(0.085, 0.1), suit, Vector3(side * 0.1, 0.16, 0))
		_part(self, _sphere(0.1), suit, Vector3(side * 0.11, 0.065, 0.04), Vector3(1, 0.65, 1.4), Vector3(0, side * 0.15, 0))
	# Body: a chunky torso, broader at the chest.
	_part(self, _capsule(0.2, 0.14), suit, Vector3(0, 0.47, 0), Vector3(1.12, 1, 0.9))
	# The belt, knotted at the front with its two tails hanging.
	_part(self, _cylinder(0.226, 0.23, 0.075), band, Vector3(0, 0.37, 0), Vector3(1.12, 1, 0.92))
	var knot := Vector3(0.1, 0.37, 0.2)
	_part(self, _sphere(0.045), band, knot, Vector3(1.1, 0.9, 0.7))
	for i in 2:
		var tail := _pivot(self, knot + Vector3(0, -0.02, 0.01))
		tail.rotation = Vector3(0.15, 0, 0.25 - i * 0.4)
		_part(tail, _box(0.05, 0.16, 0.015), band, Vector3(0, -0.08, 0))
	# Arms, and mitten fists in the same black.
	for side in [-1, 1]:
		var arm := _pivot(self, Vector3(side * 0.22, 0.62, 0))
		arm.rotation.z = side * 0.45
		_part(arm, _capsule(0.07, 0.12), suit, Vector3(0, -0.1, 0))
		_part(arm, _sphere(0.088), suit, Vector3(0, -0.23, 0.01), Vector3(1, 0.95, 1.05))
	# The head: its own piece, wider than tall, hooded.
	var head := _pivot(self, Vector3(0, 0.86, 0))
	_part(head, _sphere(0.28), suit, Vector3.ZERO, Vector3(1.1, 0.9, 1.0))
	# The eye slit: skin, framed by the mask in the player's colour.
	_part(head, _capsule(0.1, 0.2), band, Vector3(0, -0.01, 0.23), Vector3(1.05, 1.18, 0.62), Vector3(0, 0, PI / 2))
	_part(head, _capsule(0.082, 0.19), SKIN, Vector3(0, -0.012, 0.253), Vector3(1, 1.15, 0.58), Vector3(0, 0, PI / 2), true)
	_face(head, Vector3(0, -0.012, 0.29), 0.068, 0.046, EYE)
	# The headband over it, knotted behind, two long tails streaming back.
	_part(head, _torus(0.282, 0.04), band, Vector3(0, 0.1, -0.005), Vector3(1.08, 1.0, 1.0), Vector3(-0.14, 0, 0))
	_part(head, _sphere(0.05), band, Vector3(0, 0.12, -0.29), Vector3(1.2, 1, 0.8))
	for side in [-1, 1]:
		var tail := _pivot(head, Vector3(side * 0.03, 0.11, -0.31))
		tail.rotation = Vector3(-1.95, side * 0.35, 0)
		_part(tail, _box(0.065, 0.22, 0.015), band, Vector3(0, 0.1, 0))
		var tip := _pivot(tail, Vector3(0, 0.21, 0))
		tip.rotation.x = 0.35
		_part(tip, _box(0.06, 0.16, 0.015), band, Vector3(0, 0.07, 0))
	_cloth = false


## Eyes and brows that act: big whites, pupils that look, lids that close,
## thick brows that tilt. centre is between the eyes; r the eye size.
func _face(parent: Node3D, centre: Vector3, apart: float, r: float, brow_colour: Color) -> void:
	var f: Dictionary = FACES[mood]
	for side in [-1, 1]:
		var at := centre + Vector3(side * apart, 0, 0)
		var shut: bool = f.open < 0.2 or (f.get("wink", false) and side < 0)
		if shut:
			# A closed eye: two strokes, ^ for a wink, a sagging u asleep.
			var up := 1.0 if f.get("wink", false) else -1.0
			for half in [-1, 1]:
				_part(parent, _capsule(r * 0.16, r * 0.55), EYE, at + Vector3(half * r * 0.32, up * -r * 0.05, r * 0.35), Vector3(1, 1, 0.6), Vector3(0, 0, PI / 2 - half * up * 0.55), true)
		else:
			var h: float = 1.18 * maxf(f.open, 0.35)
			_part(parent, _sphere(r), WHITE, at, Vector3(0.88, h, 0.55), Vector3.ZERO, true)
			var look: Vector2 = f.look
			var pupil := at + Vector3(look.x * r * 0.42, look.y * r * 0.4 * h, r * 0.42)
			_part(parent, _sphere(r * 0.55 * f.pupil), EYE, pupil, Vector3(1, minf(1.15, h), 0.5), Vector3.ZERO, true)
			_part(parent, _sphere(r * 0.17), WHITE, pupil + Vector3(r * 0.15, r * 0.2 * h, r * 0.22), Vector3.ONE, Vector3.ZERO, true, true)
			if f.open < 0.95:
				_part(parent, _capsule(r * 0.24, r * 1.3), EYE, at + Vector3(0, r * h * 0.9, r * 0.28), Vector3(1, 1, 0.6), Vector3(0, 0, PI / 2), true)
		var lift: float = f.brow_y + (f.lift_l if side < 0 else 0.0)
		_part(parent, _capsule(r * 0.36, r * 1.3), brow_colour, at + Vector3(0, r * 1.45 + lift, r * 0.3), Vector3(1, 1, 0.7), Vector3(0, 0, PI / 2 + side * f.tilt), true)


## The watchman: the same capsule, a face in the window with room for every
## mood, a moustache you could hang a lamp on, and a cap whose peak points.
func _watchman() -> void:
	var f: Dictionary = FACES[mood]
	for side in [-1, 1]:
		_part(self, _capsule(0.1, 0.1), NAVY, Vector3(side * 0.13, 0.15, 0.0))
		_part(self, _sphere(0.11), DARK, Vector3(side * 0.13, 0.07, 0.05), Vector3(1, 0.7, 1.35))
	_part(self, _capsule(0.3, 0.36), _colour, Vector3(0, 0.66, 0), Vector3(1, 1, 0.92))
	# The face: a big skin window.
	_part(self, _capsule(0.16, 0.2), SKIN, Vector3(0, 0.78, 0.19), Vector3(1, 1, 0.6), Vector3(0, 0, PI / 2))
	_face(self, Vector3(0, 0.83, 0.272), 0.078, 0.05, MOUSTACHE)
	# Nose: a round bulb.
	_part(self, _sphere(0.045), SKIN.darkened(0.12), Vector3(0, 0.765, 0.3), Vector3.ONE, Vector3.ZERO, true)
	# Mouth, under where the moustache will go.
	match f.mouth:
		"o": _part(self, _sphere(0.03), Color("#5a1f2a"), Vector3(0, 0.67, 0.285), Vector3(0.8, 1.2, 0.4), Vector3.ZERO, true)
		"shout": _part(self, _sphere(0.045), Color("#5a1f2a"), Vector3(0, 0.67, 0.28), Vector3(1.3, 0.8, 0.4), Vector3.ZERO, true)
		"yawn": _part(self, _sphere(0.04), Color("#5a1f2a"), Vector3(0, 0.665, 0.282), Vector3(0.9, 1.3, 0.4), Vector3.ZERO, true)
		"smile": _part(self, _torus(0.03, 0.007), Color("#5a1f2a"), Vector3(0, 0.685, 0.29), Vector3(1, 1, 0.5), Vector3(PI / 2, 0, PI), true)
		"flat": _part(self, _capsule(0.007, 0.04), Color("#5a1f2a"), Vector3(0.01, 0.68, 0.295), Vector3.ONE, Vector3(0, 0, PI / 2 + 0.15), true)
	# The handlebar moustache: two sweeps and curled tips.
	for side in [-1, 1]:
		_part(self, _capsule(0.03, 0.075), MOUSTACHE, Vector3(side * 0.052, 0.72, 0.3), Vector3(1, 1, 0.7), Vector3(0, 0, PI / 2 - side * 0.35), true)
		_part(self, _sphere(0.024), MOUSTACHE, Vector3(side * 0.112, 0.742, 0.29), Vector3.ONE, Vector3.ZERO, true)
	if f.get("sweat", false):
		_part(self, _sphere(0.03), SWEAT, Vector3(0.18, 0.88, 0.26), Vector3(0.8, 1.3, 0.6), Vector3.ZERO, true, true)
	if f.get("blush", false):
		for side in [-1, 1]:
			_part(self, _sphere(0.03), BLUSH, Vector3(side * 0.14, 0.76, 0.26), Vector3(1.2, 0.7, 0.3), Vector3.ZERO, true)
	# The cap, peak well out in front: from above it is the arrow.
	var y := 1.06
	var r := 0.25
	_part(self, _cylinder(r * 0.95, r, 0.1), NAVY, Vector3(0, y, 0))
	_part(self, _cylinder(r * 1.12, r * 0.95, 0.07), NAVY, Vector3(0, y + 0.075, -0.02))
	_part(self, _cylinder(r * 1.005, r * 1.005, 0.035), GOLD.darkened(0.2), Vector3(0, y - 0.03, 0), Vector3.ONE, Vector3.ZERO, true)
	# The peak, gold-rimmed so it shows on a dark floor.
	var peak := _pivot(self, Vector3(0, y - 0.04, r * 1.0))
	peak.rotation.x = 0.12
	_part(peak, _cylinder(r * 0.84, r * 0.84, 0.02), GOLD, Vector3(0, -0.006, 0.01), Vector3.ONE, Vector3.ZERO, true)
	_part(peak, _cylinder(r * 0.8, r * 0.8, 0.03), DARK, Vector3.ZERO)
	_part(self, _star(0.04), GOLD, Vector3(0, y + 0.02, r * 0.99), Vector3.ONE, Vector3(PI / 2, 0, 0), true)
	# Uniform: belt, badge, a radio on the back, a truncheon on the hip.
	_belt(0.42, 0.3)
	_part(self, _star(0.045), GOLD, Vector3(-0.15, 0.56, 0.25), Vector3.ONE, Vector3(-PI / 2 + 0.3, -0.5, 0), true)
	_part(self, _box(0.16, 0.2, 0.08), DARK, Vector3(0, 0.62, -0.29))
	_part(self, _cylinder(0.01, 0.01, 0.2, 6), DARK, Vector3(0.05, 0.8, -0.3), Vector3.ONE, Vector3.ZERO, true)
	_part(self, _capsule(0.03, 0.25), DARK, Vector3(-0.29, 0.34, 0.05), Vector3.ONE, Vector3(0.25, 0, 0.12))
	_arms(0.29, 0.56, 0.06, 0.1, _colour, SKIN)


# --- Pieces ---------------------------------------------------------------------

func _legs(apart: float, r: float, length: float, colour: Color) -> void:
	for side in [-1, 1]:
		_part(self, _capsule(r, length), colour, Vector3(side * apart, r + length / 2, 0.02))
		_part(self, _sphere(r * 1.1), DARK, Vector3(side * apart, r * 0.8, 0.06), Vector3(1, 0.7, 1.35))


func _arms(out: float, y: float, r: float, length: float, colour: Color, hand: Color) -> void:
	for side in [-1, 1]:
		var arm := _pivot(self, Vector3(side * out, y, 0))
		arm.rotation.z = side * 0.35
		_part(arm, _capsule(r, length), colour, Vector3(0, -length / 2 - r * 0.3, 0))
		_part(arm, _sphere(r * 1.25), hand, Vector3(0, -length - r * 0.9, 0))
		if guard and side > 0:
			var torch := _pivot(arm, Vector3(0, -length - r, 0.05))
			torch.rotation.x = PI / 2 + 0.3
			_part(torch, _cylinder(0.035, 0.035, 0.18), DARK, Vector3(0, 0.03, 0))
			_part(torch, _cylinder(0.055, 0.04, 0.06), GOLD, Vector3(0, 0.15, 0))
			_part(torch, _cylinder(0.046, 0.046, 0.01), LENS, Vector3(0, 0.183, 0), Vector3.ONE, Vector3.ZERO, true, true)


func _face_window(y: float, r: float) -> void:
	_part(self, _sphere(0.22), FACE, Vector3(0, y, r - 0.1), Vector3(1.15, 0.8, 0.55))


func _eyes(y: float, z: float, apart: float, size: float) -> void:
	for side in [-1, 1]:
		_part(self, _sphere(size), EYE, Vector3(side * apart, y, z), Vector3(0.75, 1.1, 0.45), Vector3.ZERO, true)
		_part(self, _sphere(size * 0.32), WHITE, Vector3(side * apart + size * 0.2, y + size * 0.35, z + size * 0.2), Vector3.ONE, Vector3.ZERO, true, true)


## A black band across the eyes, white eyes through it, pupils looking ahead.
func _mask(y: float, r: float, colour := DARK) -> void:
	_part(self, _sphere(r * 0.8), colour, Vector3(0, y, r * 0.55), Vector3(1.45, 0.42, 0.72))
	for side in [-1, 1]:
		var at := Vector3(side * r * 0.3, y, r * 1.1)
		_part(self, _sphere(r * 0.15), WHITE, at, Vector3(1.1, 1, 0.5), Vector3.ZERO, true)
		_part(self, _sphere(r * 0.075), EYE, at + Vector3(0, 0, r * 0.06), Vector3(1, 1.2, 0.5), Vector3.ZERO, true)


## A police cap: crown, band and a peak that points where the guard looks.
func _peaked_cap(y: float, r: float) -> void:
	_part(self, _cylinder(r * 0.95, r, 0.1), NAVY, Vector3(0, y, 0))
	_part(self, _cylinder(r * 1.12, r * 0.95, 0.07), NAVY, Vector3(0, y + 0.075, -0.02))
	_part(self, _cylinder(r * 1.005, r * 1.005, 0.03), DARK, Vector3(0, y - 0.035, 0), Vector3.ONE, Vector3.ZERO, true)
	_part(self, _cylinder(r * 0.75, r * 0.75, 0.03), DARK, Vector3(0, y - 0.04, r * 0.9), Vector3(1, 1, 1.0), Vector3(0.18, 0, 0))
	_part(self, _star(0.035), GOLD, Vector3(0, y + 0.01, r * 0.97), Vector3.ONE, Vector3(PI / 2, 0, 0), true)


## A woolly hat: rolled brim and a bobble.
func _beanie(y: float, r: float) -> void:
	_part(self, _sphere(r * 1.04), _accent, Vector3(0, y, 0), Vector3(1, 0.85, 1))
	_part(self, _torus(r * 1.04, 0.04), _accent.darkened(0.25), Vector3(0, y, 0))
	_part(self, _sphere(0.065), _accent.lightened(0.35), Vector3(0, y + r * 0.9, -0.02))


func _stripes(ys: Array, r: float) -> void:
	for y in ys:
		_part(self, _cylinder(r, r, 0.05), DARK, Vector3(0, y, 0), Vector3.ONE, Vector3.ZERO, true)


func _belt(y: float, r: float) -> void:
	_part(self, _cylinder(r, r, 0.06), DARK, Vector3(0, y, 0), Vector3.ONE, Vector3.ZERO, true)
	_part(self, _box(0.07, 0.05, 0.02), GOLD, Vector3(0, y, r), Vector3.ONE, Vector3.ZERO, true)


## The swag sack slung behind, tied at the neck, a gem showing.
func _loot_bag(at: Vector3, r: float) -> void:
	_part(self, _sphere(r), BAG, at, Vector3(1, 1.1, 0.85))
	_part(self, _torus(r * 0.3, 0.02), DARK, at + Vector3(0, r * 1.05, 0))
	_part(self, _sphere(r * 0.28), BAG, at + Vector3(0, r * 1.25, 0), Vector3(1, 0.8, 1))
	_part(self, _box(r * 0.5, 0.012, r * 0.35), BAG.darkened(0.3), at + Vector3(0, 0, -r * 0.84), Vector3.ONE, Vector3.ZERO, true)


# --- Parts and materials ----------------------------------------------------------

func _pivot(parent: Node3D, at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, colour: Color, at: Vector3, scale_by := Vector3.ONE, rot := Vector3.ZERO, detail := false, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	m.scale = scale_by
	m.rotation = rot
	m.material_override = _material(colour, detail, glow)
	parent.add_child(m)
	return m


## Soft glossy plastic: a broad highlight, a little clearcoat, the rim light,
## and a thin ink line so it still reads on a dark floor.
func _material(colour: Color, detail: bool, glow: bool) -> StandardMaterial3D:
	var cloth := _cloth and not detail and not glow
	var key := "%s|%s|%s|%s" % [colour.to_html(), detail, glow, cloth]
	if _materials.has(key) and colour != GLASS:
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	if glow:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif cloth:
		# Cloth: no shine, a soft sheen at the edges (the rim, well tinted)
		# and a fine weave in the normals.
		m.roughness = 1.0
		m.metallic_specular = 0.15
		m.rim_enabled = true
		m.rim = 0.4
		m.rim_tint = 0.6
		m.normal_enabled = true
		m.normal_texture = _weave()
		m.normal_scale = 0.8
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * 9.0
	else:
		m.roughness = 0.45
		m.metallic_specular = 0.45
		m.clearcoat_enabled = true
		m.clearcoat = 0.25
		m.clearcoat_roughness = 0.25
		m.rim_enabled = true
		m.rim = 0.5
		m.rim_tint = 0.4
	if not detail:
		var ink := StandardMaterial3D.new()
		ink.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ink.albedo_color = INK
		ink.cull_mode = BaseMaterial3D.CULL_FRONT
		ink.grow = true
		ink.grow_amount = INK_GROW
		m.next_pass = ink
	_materials[key] = m
	return m


static var _weave_tex: NoiseTexture2D

## A knit-like bump: fine stretched cells, tiled.
static func _weave() -> NoiseTexture2D:
	if _weave_tex:
		return _weave_tex
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.09
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 3.0
	t.noise = n
	_weave_tex = t
	return t


func _capsule(r: float, length: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = length + 2 * r
	c.radial_segments = 32
	c.rings = 12
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = 2 * r
	s.radial_segments = 32
	s.rings = 16
	return s


func _cylinder(top: float, bottom: float, h: float, segments := 32) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c


func _star(r: float) -> CylinderMesh:
	var s := _cylinder(r, r, 0.015, 5)
	return s


func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


func _torus(r: float, tube: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - tube
	t.outer_radius = r + tube
	t.rings = 32
	t.ring_segments = 12
	return t
