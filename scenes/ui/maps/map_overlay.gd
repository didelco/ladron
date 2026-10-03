class_name MapOverlay
extends RefCounted
## Presenta el mapa plegado y su leyenda, conservando los mismos nodos y foco.

var host: Hud

func _init(owner: Hud) -> void:
	host = owner

## Take the map out (or put it away) during play: it unfolds as it comes.
func show_map(plan: Image, thief_colours: Array = []) -> void:
	if not host._map.visible:
		host._map_gang_visible = host._gang.visible
	for c in host._map_legend.get_children():
		host._map_legend.remove_child(c)
		c.queue_free()
	var keys := ["thief", "gem", "exit", "prop"]
	if Hud.home_map:
		keys = ["thief", "exit", "door", "fog"]
	elif not Museum.doors.is_empty():
		keys.append("door")
	if Heist.team and not Heist.taken and not Hud.home_map:
		keys.append("panel")
	legend_row(host._map_legend, keys, thief_colours, Color(Heist.loot.colour), true)
	var hint := host._label(12, Hud.C.dim, host._map_legend)
	hint.text = Text.t("HUD_MAP_HIDE")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	host._map_stage.print_plan(plan)
	host._map_stage.process_mode = Node.PROCESS_MODE_INHERIT
	host._map_stage.unfold()
	host._map.visible = true
	host._gang.visible = false

func update_map(plan: Image) -> void:
	host._map_stage.print_plan(plan)

## Which way the controls push while the map is out, for it to lean.
func push_map(v: Vector2) -> void:
	host._map_stage.push(v)

func hide_map() -> void:
	if host._map.visible:
		host._gang.visible = host._map_gang_visible
	host._map.visible = false
	host._map_stage.process_mode = Node.PROCESS_MODE_DISABLED

## The legend as a row: each entry its icon and its words. thief_colours
## paints the thieves' icon, loot_colour the gem.
func legend_row(parent: Node, keys: Array, thief_colours: Array, loot_colour: Color, wrap := false) -> Container:
	var row: Container = HFlowContainer.new() if wrap else HBoxContainer.new()
	if wrap:
		(row as HFlowContainer).alignment = FlowContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("h_separation", 22)
		row.add_theme_constant_override("v_separation", 6)
	else:
		(row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	for key in keys:
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 4)
		row.add_child(entry)
		var icons: Array = thief_colours if key == "thief" else [loot_colour if key == "gem" else Color.WHITE]
		for colour in icons:
			var r := TextureRect.new()
			r.texture = Hud.legend_icon(key, colour)
			r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			r.custom_minimum_size = Vector2(r.texture.get_width(), r.texture.get_height()) * 0.8
			entry.add_child(r)
		var l := host._label(14, Color("#e8d6b4"), entry)
		l.text = Text.t(Hud.LEGEND[key])
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return row
