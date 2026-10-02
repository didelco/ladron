extends SceneTree
## La calidad gráfica (Alta/Baja): por defecto Alta, lo guardado que no vale
## vuelve a lo de siempre, Baja apaga SSR, SSIL, SSAO, la niebla volumétrica y
## el humo, acorta las sombras y baja el MSAA, y Alta lo deja como estaba.
## Sobre la escena principal.
## godot --headless --script tests/test_calidad.gd
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var m


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func frames(n := 1) -> void:
	for i in n:
		await process_frame


func particles_of(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is GPUParticles3D: n += 1
	return n


func viewports(node: Node) -> Array:
	var out: Array = [node] if node is Viewport else []
	for c in node.get_children():
		out.append_array(viewports(c))
	return out


func _init() -> void:
	Settings.path = "user://test_calidad.cfg"
	Story.save = "user://test_calidad_story.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))

	# --- Por defecto y validación --------------------------------------------------------
	var s := Settings.read()
	check(s.quality == "high", "sin fichero: calidad Alta")
	check(Settings.DEFAULTS.quality == "high", "DEFAULTS: Alta")
	Settings.write({"quality": "low"})
	s = Settings.read()
	check(s.quality == "low", "se guarda y se lee: Baja")
	Settings.write({"quality": "ultra"})
	check(Settings.read().quality == "high", "una calidad que no existe vuelve a Alta")
	check(Quality.valid_level(5) == "high", "un tipo que no es: Alta")

	# --- Efectos del entorno -------------------------------------------------------------
	Quality.set_state("high")
	var env := Environment.new()
	Quality.apply_environment(env)
	check(env.ssr_enabled and env.ssil_enabled and env.ssao_enabled and env.volumetric_fog_enabled, "Alta: SSR, SSIL, SSAO y niebla volumétrica encendidos")
	var moon := DirectionalLight3D.new()
	Quality.apply_light(moon)
	check(moon.directional_shadow_max_distance == 35.0 and moon.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "Alta: sombras a 35 m en 2 cortes")
	var vp := SubViewport.new()
	Quality.setup_viewport(vp)
	check(vp.msaa_3d == Viewport.MSAA_4X, "Alta: MSAA 4x")
	check(Quality.smoke_particles(), "Alta: hay partículas de humo")

	Quality.set_state("low")
	Quality.apply_environment(env)
	check(not env.ssr_enabled and not env.ssil_enabled and not env.ssao_enabled and not env.volumetric_fog_enabled, "Baja: SSR, SSIL, SSAO y niebla volumétrica apagados")
	Quality.apply_light(moon)
	check(moon.directional_shadow_max_distance < 35.0 and moon.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "Baja: sombras más cortas y en un corte")
	Quality.setup_viewport(vp)
	check(vp.msaa_3d == Viewport.MSAA_2X, "Baja: MSAA 2x")
	check(not Quality.smoke_particles(), "Baja: sin partículas de humo")
	Quality.set_state("high")
	Quality.apply_environment(env)
	Quality.apply_light(moon)
	check(env.ssr_enabled and env.ssil_enabled and env.ssao_enabled and env.volumetric_fog_enabled and moon.directional_shadow_max_distance == 35.0, "volver a Alta lo deja como estaba")

	# --- La noche y los ajustes, en la escena principal ---------------------------------------
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await frames(3)
	for c in m.get_children():
		if c is TitleScreen:
			c.queue_free()
	await frames(2)
	# Detrás del hub se arranca ahora en la guarida (DenView), que de
	# propósito apaga ssr/ssil por su ambiente cálido (DenView.mood). Para
	# probar que la calidad por defecto enciende los efectos de verdad (lo
	# que comprueba esto), una noche de historia, sin ese ajuste propio.
	m.mode = "story"
	m._new_round(1)
	await frames(2)
	var w: Environment = m.nightenv.world_env
	check(w.ssr_enabled and w.ssil_enabled and w.ssao_enabled and w.volumetric_fog_enabled, "la noche por defecto: efectos encendidos")
	check(m.nightenv.moon.directional_shadow_max_distance == 35.0, "la noche por defecto: sombras a 35 m")
	check(m.options.text_of("quality").contains(Text.t("SETTINGS_QUALITY_HIGH")), "el ajuste dice ALTA")
	m.options.step(0, "quality")
	check(Quality.is_low() and not w.ssr_enabled and not w.ssao_enabled and not w.ssil_enabled and not w.volumetric_fog_enabled, "ajuste Calidad: Baja apaga los efectos de la noche")
	check(m.nightenv.moon.directional_shadow_max_distance < 35.0, "ajuste Calidad: Baja acorta las sombras de la noche")
	check(m.options.text_of("quality").contains(Text.t("SETTINGS_QUALITY_LOW")), "el ajuste dice BAJA")
	check(Settings.read().quality == "low", "Baja se guarda")
	var stage_ok := true
	var n := 0
	for v in viewports(root):
		n += 1
		if v != root and v.msaa_3d != Viewport.MSAA_2X:
			stage_ok = false
	check(n > 1 and stage_ok, "los visores 3D de menús y ciudad siguen la calidad (%d)" % n)

	var puff := SmokeFx.burst(m, Vector3.ZERO)
	await frames(2)
	check(particles_of(puff) == 0, "Baja: la bomba de humo no saca partículas (%d)" % particles_of(puff))
	puff.queue_free()
	m.options.step(0, "quality")
	check(not Quality.is_low() and w.ssr_enabled and w.volumetric_fog_enabled, "Alta otra vez: todo como estaba")
	puff = SmokeFx.burst(m, Vector3.ZERO)
	await frames(2)
	check(particles_of(puff) > 0, "Alta: la bomba de humo saca partículas (%d)" % particles_of(puff))

	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	quit(qa.summary())
