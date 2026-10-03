class_name EditorGuardPanel
extends RefCounted
## Panel de capacidades y posición del guardia. Edita el mismo GuardSpawn del mapa.

var host: MapEditor

func _init(owner: MapEditor) -> void:
	host = owner

func guard_panel() -> void:
	var g := host.selected_guard
	if g == null:
		host._open("")
		return
	host._guard_title.text = Text.t("EDITOR_TOOL_GUARD")

	for page in MapEditor.GUARD_PAGES:
		var b := host._button(Text.t("EDITOR_GUARD_TAB_" + page.to_upper()), func() -> void:
			host.guard_page = page
			host._open("guard"), host._guard_tabs, Hud.C.gold)
		b.custom_minimum_size = Vector2(0, 30)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_meta("guard_page", page)

	match host.guard_page:
		"capabilities":
			guard_capabilities_page(g)
		"position":
			guard_position_page(g)

## The archetype (its dropdown seeds the three sliders below), the sliders
## themselves — drawn as a little bar chart, like a volume meter, the stat's
## name at its top right — and the line of traits they add up to.
func guard_capabilities_page(g: GuardSpawn) -> void:
	host._label(Text.t("EDITOR_GUARD_ARCHETYPE"), 8, Hud.C.dim, host._guard_sub, true)
	var arch := host._dropdown(host._guard_sub)
	var arch_keys := GuardSpawn.ARCHETYPES.keys()
	for i in arch_keys.size():
		arch.add_item(Text.t(GuardSpawn.ARCHETYPES[arch_keys[i]].label), i)
	arch.select(maxi(0, arch_keys.find(g.archetype)))
	arch.item_selected.connect(func(i: int) -> void: pick_archetype(arch_keys[i]))

	for stat in GuardSpawn.STATS:
		level_row(stat, "EDITOR_GUARD_STAT_" + stat.to_upper())
	var desc := host._label(guard_description(g), 11, Hud.CREAM, host._guard_sub)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.set_meta("guard_desc", true)

## How it moves (round/post) and, posted, what it watches: icon buttons —
## their words are long, and full-width ones would spill past the sidebar —
## and which way it looks at the start (‹ › in steps of 45°, an arrow icon
## turned to match, like _seconds_slider).
func guard_position_page(g: GuardSpawn) -> void:
	host._label(Text.t("EDITOR_GUARD_STANCE"), 8, Hud.C.dim, host._guard_sub, true)
	var stance_row := HBoxContainer.new()
	stance_row.add_theme_constant_override("separation", 6)
	host._guard_sub.add_child(stance_row)
	for s in ["round", "post"]:
		var b := host._icon_button("stance_" + s, "EDITOR_GUARD_STANCE_" + s.to_upper(), pick_stance.bind(s), stance_row, Hud.C.safe)
		b.set_meta("guard_stance", s)

	if g.stance == "post":
		# Some missions ask for exactly this: a guard that never leaves its
		# post, whichever way you set it to look.
		host._label(Text.t("EDITOR_GUARD_WATCH"), 8, Hud.C.dim, host._guard_sub, true)
		var watch_row := HBoxContainer.new()
		watch_row.add_theme_constant_override("separation", 6)
		host._guard_sub.add_child(watch_row)
		var watch_icons := {"": "watch_none", "room": "room", "piece": "piece"}
		for w in ["", "room", "piece"]:
			var b := host._icon_button(watch_icons[w], "EDITOR_GUARD_WATCH_" + (w if w != "" else "none").to_upper(), pick_watch.bind(w), watch_row, Hud.C.safe)
			b.set_meta("guard_watch", w)

	host._label(Text.t("EDITOR_GUARD_FACING"), 8, Hud.C.dim, host._guard_sub, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	host._guard_sub.add_child(row)
	var less := host._button("‹", step_dir.bind(-1), row, Hud.C.safe)
	var idx := nearest_dir(g.dir)
	var bar := host._button(MapEditor.GUARD_DIR_KEYS[idx], step_dir.bind(0), row, Hud.C.safe, false, host._dir_arrow_texture(MapEditor.GUARD_DIRS[idx]))
	bar.tooltip_text = Text.t("EDITOR_GUARD_" + MapEditor.GUARD_DIR_KEYS[idx])
	bar.add_theme_constant_override("icon_max_width", 28)
	var more := host._button("›", step_dir.bind(1), row, Hud.C.safe)
	for b in [less, more]:
		b.custom_minimum_size = Vector2(38, 38)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.custom_minimum_size = Vector2(176, 38)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar.set_meta("guard_dir", true)
	bar.gui_input.connect(func(e: InputEvent) -> void:
		for pair in [["ui_left", -1], ["ui_right", 1]]:
			if e.is_action_pressed(pair[0], true):
				step_dir(pair[1])
				bar.accept_event())

## One stat, its name at the top right (like a volume setting's); the bars
## below stand for the five levels, lit up to the one in force. A click on
## the middle settles it back on the plain middle level (2), the arrows
## step it.
func level_row(stat: String, title_key: String) -> void:
	var head := HBoxContainer.new()
	host._guard_sub.add_child(head)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	host._label(Text.t(title_key), 8, Hud.C.dim, head, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	host._guard_sub.add_child(row)
	var less := host._button("‹", step_level.bind(stat, -1), row, Hud.C.safe)
	var level := host.selected_guard.level(stat)
	var bar := host._button("", step_level.bind(stat, 0), row, Hud.C.safe, false, host._level_bars_texture(level))
	bar.tooltip_text = Text.t(GuardSpawn.LEVEL_LABELS[stat][level])
	bar.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.add_theme_constant_override("icon_max_width", 150)
	var more := host._button("›", step_level.bind(stat, 1), row, Hud.C.safe)
	for b in [less, more]:
		b.custom_minimum_size = Vector2(38, 38)
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bar.custom_minimum_size = Vector2(176, 38)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.autowrap_mode = TextServer.AUTOWRAP_OFF
	bar.set_meta("guard_level", stat)
	bar.gui_input.connect(func(e: InputEvent) -> void:
		for pair in [["ui_left", -1], ["ui_right", 1]]:
			if e.is_action_pressed(pair[0], true):
				step_level(stat, pair[1])
				bar.accept_event())

## What the sliders say it is like, in words: the ones off the plain middle
## strung together, or a line saying it is nothing out of the ordinary.
func guard_description(g: GuardSpawn) -> String:
	var parts: Array[String] = []
	for stat in GuardSpawn.STATS:
		var lvl := g.level(stat)
		if lvl != 2:
			parts.append(Text.t(GuardSpawn.LEVEL_LABELS[stat][lvl]))
	if parts.is_empty():
		return Text.t("EDITOR_GUARD_NO_TRAITS")
	return ", ".join(parts)

## The closest of the eight GUARD_DIRS to an angle.
func nearest_dir(dir: float) -> int:
	var best := 0
	var best_diff := INF
	for i in MapEditor.GUARD_DIRS.size():
		var diff := absf(wrapf(MapEditor.GUARD_DIRS[i] - dir, -PI, PI))
		if diff < best_diff:
			best_diff = diff
			best = i
	return best

## One step round (-1/1), or 0 to just settle it on the nearest of the eight.
func step_dir(step: int) -> void:
	if host.selected_guard == null:
		return
	var i := (nearest_dir(host.selected_guard.dir) + step) % MapEditor.GUARD_DIRS.size()
	if i < 0:
		i += MapEditor.GUARD_DIRS.size()
	host.selected_guard.dir = MapEditor.GUARD_DIRS[i]
	host.dirty = true
	host._refresh()

func remove_selected_guard() -> void:
	if host.selected_guard == null:
		return
	host._remember()
	host.map.guards = host.map.guards.filter(func(g): return g != host.selected_guard)
	host.selected_guard = null
	host._open("")

## An archetype loads its sliders fresh (the "default values"
## moment); from then on they are free to move one at a time without it
## snapping back.
func pick_archetype(key: String) -> void:
	if host.selected_guard == null:
		return
	host.selected_guard.archetype = key
	var preset: Dictionary = GuardSpawn.ARCHETYPES[key]
	host.selected_guard.view_level = int(preset.view)
	host.selected_guard.hearing_level = int(preset.hearing)
	host.selected_guard.speed_level = int(preset.speed)
	host.selected_guard.attention_level = int(preset.get("attention", 2))
	host.dirty = true
	host._open("guard")

## -1/1 to step a slider, or 0 to settle it back on the plain middle (2).
func step_level(stat: String, step: int) -> void:
	if host.selected_guard == null:
		return
	var next := 2 if step == 0 else clampi(host.selected_guard.level(stat) + step, 0, 4)
	host.selected_guard.set_level(stat, next)
	host.dirty = true
	host._refresh()

## Whether it patrols or stands guard: the "watch" row only makes sense
## posted, so this rebuilds the panel instead of just refreshing it.
func pick_stance(s: String) -> void:
	if host.selected_guard == null:
		return
	host.selected_guard.stance = s
	if s != "post":
		host.selected_guard.watch = ""
	host.dirty = true
	host._open("guard")

func pick_watch(w: String) -> void:
	if host.selected_guard == null:
		return
	host.selected_guard.watch = w
	host.dirty = true
	host._refresh()
