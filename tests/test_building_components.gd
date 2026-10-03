extends SceneTree
## Compara geometría, instancias, colores y consumo RNG antes/después de separar.
## Fixture capturado antes de separar los constructores por estilo.
const Support := preload("res://tests/support.gd")
const FIXTURE := "res://tests/fixtures/building_components.json"
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
				material.vertex_color_use_as_albedo, material.vertex_color_is_srgb, material.emission_enabled, material.emission, material.emission_energy_multiplier, material.transparency, material.cull_mode])
	if node is MultiMeshInstance3D:
		var multi := node.multimesh as MultiMesh
		for surface in multi.mesh.get_surface_count():
			data.append(multi.mesh.surface_get_arrays(surface))
		for instance in multi.instance_count:
			data.append([multi.get_instance_transform(instance), multi.get_instance_color(instance) if multi.use_colors else null])
	if node is GeometryInstance3D and node.material_override is BaseMaterial3D:
		var material := node.material_override as BaseMaterial3D
		data.append([material.albedo_color, material.emission, material.emission_energy_multiplier, material.emission_enabled])
		if material.albedo_texture != null:
			data.append(material.albedo_texture.get_image().get_data())
	for child in node.get_children():
		collect(child, data)

func checksum(node: Node) -> String:
	var data: Array = []
	collect(node, data)
	return var_to_bytes(data).hex_encode().sha256_text()

func snapshots() -> Dictionary:
	var result := {}
	for museum in Story.MUSEUMS.size():
		for opened in [false, true]:
			for progress in [false, true]:
				var rooms: Array = []
				if progress:
					for i in 5:
						rooms.append({"n": i + 1, "boss": i == 4, "open": i % 2 == 0, "shape": "vase", "colour": "#abcdef"})
				var building := MuseumBuilding.new()
				building.build(museum, opened, rooms)
				var key := "%d/%s/%s" % [museum, opened, progress]
				result[key] = {"mesh": checksum(building), "windows": window_state(building), "camera": [str(building.front_z), str(building.look_y), str(building.top), str(building.view)]}
				building.pick(2)
				building._process(0.125)
				result[key + "/picked"] = {"mesh": checksum(building), "windows": window_state(building)}
				building.free()
	return result

func window_state(building: MuseumBuilding) -> Array:
	var result: Array = []
	for window in building.windows:
		result.append([window.boss, window.open, str(window.size), str(window.face), window.arch, window.has("volume")])
	return result

func _init() -> void:
	var actual := snapshots()
	if "--record-baseline" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t") + "\n")
		print("OK: baseline de edificios capturado antes de extraer estilos")
		quit()
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for key in expected:
		qa.check(actual[key] == expected[key], "%s: geometría, ventanas, cámara y animación idénticas" % key)
	quit(qa.summary())
