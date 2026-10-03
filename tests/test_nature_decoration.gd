extends SceneTree
## Compara geometría, instancias, colores y consumo RNG antes/después de separar.
## El fixture se capturó de MuseumBuilding antes de extraer su decoración.
const Support := preload("res://tests/support.gd")
const FIXTURE := "res://tests/fixtures/nature_decoration.json"
var qa := Support.new("  ")

func collect(node: Node, data: Array) -> void:
	data.append(node.get_class())
	if node is Node3D:
		data.append(node.transform)
	if node is MeshInstance3D:
		for surface in node.mesh.get_surface_count():
			data.append(node.mesh.surface_get_arrays(surface))
		if node.material_override is BaseMaterial3D:
			var material := node.material_override as BaseMaterial3D
			data.append([material.albedo_color, material.shading_mode, material.roughness,
				material.vertex_color_use_as_albedo, material.vertex_color_is_srgb])
	if node is MultiMeshInstance3D:
		var multi := node.multimesh as MultiMesh
		for surface in multi.mesh.get_surface_count():
			data.append(multi.mesh.surface_get_arrays(surface))
		for instance in multi.instance_count:
			data.append([multi.get_instance_transform(instance), multi.get_instance_color(instance)])
	for child in node.get_children():
		collect(child, data)

func checksum(node: Node) -> String:
	var data: Array = []
	collect(node, data)
	return var_to_bytes(data).hex_encode().sha256_text()

func snapshots() -> Dictionary:
	var result := {}
	var nature := Story.MUSEUMS.find(Story.MUSEUMS.filter(func(m): return m.theme == "naturaleza")[0])
	for opened in [false, true]:
		var building := MuseumBuilding.new()
		building.build(nature, opened)
		result["building/%s" % opened] = checksum(building)
		building.free()
		for seed_value in [1, 7127, 424242]:
			building = MuseumBuilding.new()
			building.open = opened
			building._colour = Color(Story.MUSEUMS[nature].colour)
			building._n_body = MuseumBuilding.NMesh.new()
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			# La MISMA instancia pasa por todas las llamadas; ninguna se reseedea.
			building._n_planter(Transform3D.IDENTITY, 0.2, 1.0, 0.9, 0.5, rng, true, false)
			building._n_niche(Transform3D.IDENTITY, -0.3, 1.4, 0.9, 0.4, Vector2(0.5, 0.4), rng)
			building._n_square(rng)
			building._n_bed(Vector3(1.0, 0, 1.0), Vector2(0.6, 0.9))
			building._n_roof(3.5, rng)
			building._n_ladybird(Transform3D.IDENTITY)
			building._n_waterfall(rng)
			building._n_snail(Transform3D.IDENTITY)
			building._n_plant("autumn", Vector3(1.0, 0, 1.0), 0.7, rng)
			var body := MeshInstance3D.new()
			body.mesh = building._n_body.commit()
			building.add_child(body)
			building._n_flush_plants()
			result["parts/%s/%d" % [opened, seed_value]] = {"mesh": checksum(building), "rng": str(rng.state)}
			building.free()
	return result

func _init() -> void:
	var actual := snapshots()
	if "--record-baseline" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute("res://tests/fixtures")
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t") + "\n")
		print("OK: baseline capturado antes de extraer decoración")
		quit()
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for key in expected:
		qa.check(actual[key] == expected[key], "%s: mallas, transformaciones, colores y RNG idénticos" % key)
	quit(qa.summary())
