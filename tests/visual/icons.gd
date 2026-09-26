extends Node
## Takes the editor's pictures of the objects and of the pieces to steal:
## each one, built the way the
## museum builds it, turned three-quarters under a warm light on a clear
## background, saved to assets/icons/objects/<tool>.png. Run it again after
## a model changes:
##   godot --path . tests/visual/icons.tscn

const SIZE := 128
const OUT := "res://assets/icons/objects/"


func _ready() -> void:
	var view := MuseumView.new()
	add_child(view)
	var items := {
		"case": func(p: Node3D) -> void:
			view._base(p)
			view._vitrine(p, null),
		"big_dinosaur": func(p: Node3D) -> void: p.add_child(MuseumView.asset("dinosaurio")),
		"big_sarcophagus": func(p: Node3D) -> void: p.add_child(MuseumView.asset("sarcofago")),
	}
	for e in MuseumView.EXHIBITS:
		items["exhibit_" + e] = func(p: Node3D) -> void:
			view._base(p)
			view._exhibit(p, e, Vector2i(3, 4), 0.5)
	# The small ones on their own, without the glass or the plinth: in the
	# case they would be a speck.
	items["exhibit_butterflies"] = func(p: Node3D) -> void: p.add_child(view._butterflies(3))
	items["exhibit_minerals"] = func(p: Node3D) -> void: p.add_child(view._minerals(5))
	items["exhibit_ammonite"] = func(p: Node3D) -> void: p.add_child(view._ammonite())
	items["exhibit_meteorite"] = func(p: Node3D) -> void: p.add_child(view._rock())
	items["exhibit_skull"] = func(p: Node3D) -> void: view._skull(p, 0.5)
	items["exhibit_lego_skull"] = func(p: Node3D) -> void: view._skull(p, 0.5, true)
	# The themes' models, on their own (MapEditor's catalogue).
	for entry in Themes.catalogue():
		var tool: String = entry[0]
		var what := tool.trim_prefix("exhibit:")
		if "/" in what:
			items["exhibit_" + what.replace("/", "_")] = func(p: Node3D) -> void: p.add_child(MuseumView.asset(what))
	# The pieces to steal, in the gold the editor starts them in.
	for shape in ["teeth", "duck", "sock", "toast", "crown", "rock", "mask", "clock", "egg", "idol", "gem"]:
		items["loot_" + shape] = func(p: Node3D) -> void: p.add_child(LootModels.build(shape, Color("#f0c46a")))
	for k in ["bust", "bin", "panel", "armour"]:
		items["prop_" + k] = func(p: Node3D) -> void: p.add_child(PropsView.model(k))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for name in items:
		await _shoot(name, items[name])
	print("icons: ", items.size())
	get_tree().quit()


func _shoot(name: String, build: Callable) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#b8b4d8")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, 35, 0)
	key.light_color = Color("#fff1d8")
	key.light_energy = 1.1
	vp.add_child(key)
	var root := Node3D.new()
	vp.add_child(root)
	build.call(root)
	await get_tree().process_frame
	# Frame it: the whole piece, a little margin, from three-quarters above.
	var box := AABB()
	var first := true
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var b: AABB = (n as VisualInstance3D).global_transform * (n as VisualInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	vp.add_child(cam)
	var centre := box.get_center()
	var dir := Vector3(0.75, 0.75, 1.0).normalized()
	cam.look_at_from_position(centre + dir * (box.size.length() + 2.0), centre)
	cam.size = maxf(box.size.length(), 0.3) * 0.9
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(OUT + name + ".png")
	vp.queue_free()
