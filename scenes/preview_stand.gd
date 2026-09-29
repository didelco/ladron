class_name PreviewStand
extends RefCounted
## The little stand the menus show a piece on: a SubViewport with its own world, a camera,
## a light and a velvet base, turning as it is drawn (Game._physics_process). The loot screen,
## the briefing, the front page and the assets take its picture (preview.get_texture()).

var host: Game

## the piece turning on its own stand, on the loot screen
var preview: SubViewport
var preview_cam: Camera3D
var preview_pivot: Node3D
var preview_spot: OmniLight3D


func _init(game: Game) -> void:
	host = game


## Put any model on the preview's stand, lit in this colour, framed to span.
func put_node(node: Node3D, light: Color, span: float, lift: float) -> void:
	for c in preview_pivot.get_children():
		c.queue_free()
	preview_spot.light_color = light
	preview_cam.size = span
	preview_cam.position = preview_cam.basis.z * 10.0 + Vector3(0, lift, 0)
	node.position.y = -0.1
	preview_pivot.add_child(node)


func build(loot: Dictionary = Heist.loot) -> void:
	drop()
	preview = SubViewport.new()
	preview.size = Vector2i(480, 300)
	preview.own_world_3d = true
	preview.transparent_bg = true
	Quality.setup_viewport(preview)
	host.add_child(preview)
	# Axonometric, like every picture in the menus.
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-35.264, 45, 0)
	cam.position = cam.basis.z * 10.0 + Vector3(0, 0.08, 0)
	cam.size = 0.62
	preview.add_child(cam)
	preview_cam = cam
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	preview.add_child(sun)
	preview_spot = OmniLight3D.new()
	preview_spot.position = Vector3(0, 0.8, 0.4)
	preview_spot.light_energy = 1.5
	preview.add_child(preview_spot)
	# A velvet stand under it.
	var stand := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.25
	c.height = 0.08
	stand.mesh = c
	stand.material_override = MenuStage._material(MenuStage.VELVET)
	stand.position = Vector3(0, -0.12, 0)
	preview.add_child(stand)
	preview_pivot = Node3D.new()
	preview_pivot.position = Vector3(0, 0.1, 0)
	preview.add_child(preview_pivot)
	put_piece(loot)


## Swap the piece on the stand, keeping the stand, the camera and the picture.
func put_piece(loot: Dictionary) -> void:
	for c in preview_pivot.get_children():
		c.queue_free()
	preview_spot.light_color = Color(loot.colour)
	var piece := LootModels.build(loot.shape, Color(loot.colour))
	piece.position.y = -0.1
	preview_pivot.add_child(piece)


func drop() -> void:
	if preview:
		# Gone once the menu showing it has faded out, not before.
		var old := preview
		host.get_tree().create_timer(Hud.FADE_S + Hud.SWAP_S).timeout.connect(old.queue_free)
		preview = null
		preview_pivot = null
		preview_spot = null
