class_name MinigameView
extends Node3D
## How a minigame (Minigame) looks, in the little 3D scene of its box
## (MinigameStage): one script per kind in scenes/minigame_views/, named as
## the kind, extending this. The stage gives it its lights and camera; the
## view builds its pieces once (build) and moves them every frame (pose),
## in the menus' toy style (MenuStage): soft plastic in the night museum's
## colours, no words.

const SCRIPTS := "res://scenes/minigame_views/%s.gd"

const CREAM := MenuStage.CREAM
const INK := MenuStage.INK
const GOLD := MenuStage.GOLD
const WOOD := MenuStage.WOOD
const STEEL := Color("#b8bcc8")
const GREEN := Color("#4ade80")
const RED := Color("#ff3d6e")
const ORANGE := Color("#ff922b")
## A hook's colour (Minigame.hook_colour): green, orange, red.
const HOOK_COLOURS := [GREEN, ORANGE, RED]

var game: Minigame
## the thief's colour, for whatever wears it
var colour := Color("#2ec4a6")
## 0..1 flashes, fading: a success, a miss (the stage sets them)
var good := 0.0
var bad := 0.0
## seconds since it was built
var t := 0.0


## The view of this kind of minigame (MinigameView itself, empty, if the kind
## has none).
static func make(kind: String) -> MinigameView:
	var path := SCRIPTS % kind
	return load(path).new() if ResourceLoader.exists(path) else MinigameView.new()


# --- For each kind to fill in --------------------------------------------------

## How the camera looks at it: how much of the scene, top to bottom, fills
## the box (span), the height it looks at (look) and the camera's turn in
## degrees (angle: a little above and to the side, nearly face on).
func framing() -> Dictionary:
	return {"span": 1.3, "look": 0.0, "angle": Vector3(-12, 14, 0)}


## Build its pieces, once: game is set, and steps is how many it has.
func build() -> void:
	pass


## Move its pieces to how the game is now.
func pose(_dt: float) -> void:
	pass


# --- Helpers ------------------------------------------------------------------

func box(s: Vector3, c: Color, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = s
	mi.mesh = mesh
	mi.material_override = MenuStage._material(c)
	mi.position = at
	add_child(mi)
	return mi


func cylinder(top: float, bottom: float, h: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = top
	cyl.bottom_radius = bottom
	cyl.height = h
	cyl.radial_segments = 24
	mi.mesh = cyl
	mi.material_override = MenuStage._material(c)
	add_child(mi)
	return mi


## A glowing arrow in the view's plane, pointing up: a shaft and a head.
func arrow(c: Color, energy := 2.5) -> Node3D:
	var a := Node3D.new()
	add_child(a)
	var glow := glowing(c, energy)
	var shaft := MeshInstance3D.new()
	shaft.mesh = MuseumView._box(Vector3(0.07, 0.2, 0.05))
	shaft.material_override = glow
	shaft.position = Vector3(0, -0.06, 0)
	a.add_child(shaft)
	var head := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.12
	cone.height = 0.16
	cone.radial_segments = 3
	head.mesh = cone
	head.material_override = glow
	head.position = Vector3(0, 0.1, 0)
	head.scale = Vector3(1, 1, 0.4)
	a.add_child(head)
	return a


static func cylinder_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	return c


static func glowing(c: Color, energy: float) -> StandardMaterial3D:
	var m := MenuStage._material(c).duplicate() as StandardMaterial3D
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m
