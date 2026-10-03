extends SceneTree
## Baseline captured from the original TownBuilder before splitting its helpers.
const Support := preload("res://tests/support.gd")
const FIXTURE := "res://tests/fixtures/town_components.json"
var qa := Support.new("  ")

func material_data(material: Material) -> Array:
	if material == null:
		return []
	var data: Array = [material.get_class()]
	for property in material.get_property_list():
		if not property.usage & PROPERTY_USAGE_STORAGE or property.name in ["resource_name", "resource_local_to_scene", "resource_scene_unique_id"]:
			continue
		var value: Variant = material.get(property.name)
		if value is Shader:
			value = value.code
		elif value is Resource:
			value = value.resource_path
		data.append([property.name, value])
	return data

func mesh_data(mesh: Mesh) -> Array:
	var data: Array = []
	for surface in mesh.get_surface_count():
		var primitive: int = mesh.surface_get_primitive_type(surface) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		data.append([primitive, mesh.surface_get_arrays(surface), material_data(mesh.surface_get_material(surface))])
	return data

func collect(node: Node, data: Array) -> void:
	data.append(node.get_class())
	if node is Node3D:
		data.append([node.transform, node.visible])
	if node is GeometryInstance3D:
		data.append([node.cast_shadow, material_data(node.material_override)])
	if node is MeshInstance3D:
		data.append(mesh_data(node.mesh))
	if node is MultiMeshInstance3D:
		var multi: MultiMesh = node.multimesh
		data.append([mesh_data(multi.mesh), multi.instance_count, multi.visible_instance_count, multi.use_colors, multi.use_custom_data])
		for instance in multi.instance_count:
			data.append([multi.get_instance_transform(instance), multi.get_instance_color(instance) if multi.use_colors else Color.WHITE, multi.get_instance_custom_data(instance) if multi.use_custom_data else Color.TRANSPARENT])
	for child in node.get_children():
		collect(child, data)

func checksum(value: Variant) -> String:
	return var_to_bytes(value).hex_encode().sha256_text()

func snapshots() -> Dictionary:
	var result := {}
	for seed_value in [7, 7127, 424242]:
		var scenery := Node3D.new()
		var town := TownBuilder.new(scenery, seed_value)
		var origins: Array[Vector2] = [Vector2(-18, 22), Vector2(22, 25), Vector2(-24, -28), Vector2(25, -30)]
		town.plan([-7.0, 9.0, -11.0, 14.0], origins)
		for i in 4:
			var lot := town.claim(i, origins[i])
			var at := town.block_top(i, lot)
			town.museums.append(Vector2(at.x, at.z))
		var samples: Array = []
		for p in [Vector2.ZERO, Vector2(-72, -65), Vector2(17, 5), Vector2(40, -25), Vector2(-28, 37), Vector2(60, -60)]:
			samples.append([town.frame(p), town.ground(p), town.across(p), town.district_of(p), town.bank_of(p)])
		for s in [-71.0, -17.0, 0.0, 23.0, 72.0]:
			samples.append([town.point(s, 5.0), town.river_at(s), town._tangent(s), town._across_dir(s)])
		town.build()
		var geometry: Array = []
		collect(scenery, geometry)
		var paths: Array = []
		for i in range(town.districts.size() - 1):
			if town.districts[i].blocks.is_empty() or town.districts[i + 1].blocks.is_empty():
				continue
			paths.append(town.route([i, town.districts[i].blocks.keys()[0]], [i + 1, town.districts[i + 1].blocks.keys()[0]]))
		result[str(seed_value)] = {"geometry": checksum(geometry), "terrain": checksum(samples), "layout": checksum([town._nodes, town._links, town._roads, town._taken, paths, town.bridges, town.made, town.unseen]), "rng": str(town._rng.state)}
		scenery.free()
	return result

func _init() -> void:
	var actual := snapshots()
	if "--record-baseline" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t") + "\n")
		print("OK: TownBuilder baseline captured before extraction")
		quit()
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for key in expected:
		for field in expected[key]:
			qa.check(actual[key][field] == expected[key][field], "seed %s: identical %s" % [key, field])
	quit(qa.summary())
