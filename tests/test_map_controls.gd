extends SceneTree
## Map geometry at every offered window/UI scale, with 1–4 thieves; the
## controls table is checked against input polled by Hands, not key labels alone.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var hud: Hud
var hands: Hands

func frames(n := 3) -> void:
	for i in n:
		await process_frame

func press_key(k: Key, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.keycode = k
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func check_layout(view: Vector2) -> void:
	var bounds := Rect2(Vector2.ZERO, view)
	qa.check_quiet(bounds.encloses(hud._map_picture.get_global_rect()), "map picture stays inside viewport")
	qa.check_quiet(hud._map_picture.size.y > 100, "map retains usable height")
	qa.check_quiet(not hud._gang.is_visible_in_tree(), "portraits do not cover open map")
	for row in hud._map_legend.get_children():
		qa.check_quiet(bounds.encloses(row.get_global_rect()), "legend and close hint stay inside viewport")
		if row is HFlowContainer:
			for entry in row.get_children():
				qa.check_quiet(bounds.encloses(entry.get_global_rect()), "every legend entry stays inside viewport")
	qa.check_quiet(hud._map_picture.get_global_rect().end.y <= hud._map_legend.get_global_rect().position.y, "map and legend never overlap")

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var host := Game.new()
	hands = Hands.new(host)
	var rows: Array = SettingsScreens.new(host).controls_table().table
	var smoke: Array = rows.filter(func(r): return r[0] == "HUMO")[0]
	qa.check(smoke == ["HUMO", "F", Hands.key_label(KEY_COMMA), "Y"], "smoke row names both keyboard halves and pad north button")
	for pair in [["kb_left", KEY_F], ["kb_right", KEY_COMMA]]:
		press_key(pair[1], true)
		await frames(1)
		qa.check(hands.seat_input(pair[0], false)[8], "%s polls its documented smoke key" % pair[0])
		qa.check(not hands.seat_input("kb_right" if pair[0] == "kb_left" else "kb_left", false)[8], "smoke key belongs only to its keyboard half")
		qa.check(not hands.seat_input(pair[0], true)[8], "held smoke is ignored on resume")
		press_key(pair[1], false)
		hands.seat_input(pair[0], false)
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = JOY_BUTTON_Y
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	await frames(1)
	qa.check(hands.seat_input("pad:0", false)[8], "pad Y polls smoke")
	e.pressed = false
	Input.parse_input_event(e)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	hud = Hud.new()
	viewport.add_child(hud)
	await frames()
	Heist.loot = Heist.loot_for(1)
	Heist.taken = false
	# The longest legend: doors, panel and four thief icons.
	Museum.doors = [Vector2i(1, 1)]
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for gang in range(1, 5):
		var colours: Array = []
		var darks: Array = []
		for i in gang:
			colours.append(Color.WHITE)
			darks.append(Color.GRAY)
		hud.set_gang(colours, darks, Heist.loot)
		Heist.team = gang > 1
		for window in Settings.WINDOW_SIZES:
			for scale in range(Settings.UI_SCALE_MIN, Settings.UI_SCALE_MAX + 1, 10):
				# canvas_items scales the 1280×720 design by content_scale_factor;
				# every offered window is 16:9, hence the same logical bounds.
				var view := Vector2i(Vector2(1280, 720) / (scale / 100.0))
				viewport.size = view
				hud.show_map(image, colours)
				await frames()
				check_layout(Vector2(view))
				hud.hide_map()
				qa.check_quiet(hud._gang.visible, "closing map restores portraits")
	hud._gang.visible = false
	hud.show_map(image, [Color.WHITE])
	hud.show_map(image, [Color.WHITE])
	hud.hide_panel()
	qa.check(not hud._gang.visible, "returning to play keeps portraits hidden while map is open")
	hud.hide_map()
	qa.check(not hud._gang.visible, "closing map preserves portraits previously hidden")
	print("Checked 216 combinations of window, UI scale and player count")
	viewport.queue_free()
	host.free()
	await frames()
	quit(qa.summary())
