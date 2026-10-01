extends SceneTree
## Menu clarity and reachability at high UI scale; selector lifecycle on focus.
const Support := preload("res://tests/support.gd")
var qa := Support.new()
var game: Game


func frames(n := 8) -> void:
	for i in n:
		await process_frame


func visible(control: Control) -> bool:
	var area := Rect2(Vector2.ZERO, root.size)
	var rect := control.get_global_rect()
	return area.encloses(rect)


func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless" and "--render" in OS.get_cmdline_user_args():
		await create_timer(0.45).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/ninja-n6-n8-" + name + ".png")


func settings_layout() -> void:
	for page in ["screen", "options", "pads"]:
		game.options.show("title", page)
		await frames()
		var scroll := game.hud._panel_box.get_parent() as ScrollContainer
		qa.check(scroll != null and Rect2(Vector2.ZERO, root.size).encloses(scroll.get_global_rect()), page + ": contenedor cabe con interfaz 150%")
		var buttons := game.hud._panel_box.find_children("*", "Button", true, false)
		for b: Button in buttons:
			b.grab_focus()
			await frames(4)
			qa.check(visible(b), page + ": foco visible en " + b.text)
		await capture(page + "-last")
		scroll.scroll_vertical = 0
		buttons[0].grab_focus()
		await frames()
		await capture(page)


func theme_stages(node: Node) -> int:
	var count := 1 if node is MenuStage and node.kind.begins_with("theme:") else 0
	for child in node.get_children():
		count += theme_stages(child)
	return count

func picture(node: Node) -> TextureRect:
	for child in node.get_children():
		if child is TextureRect:
			return child
		var found := picture(child)
		if found:
			return found
	return null


func theme_icons() -> void:
	game.theme = ""
	game._show_generative_menu("theme")
	await frames()
	await capture("theme-random")
	for selected in Game.THEME_NAMES:
		game._pick_setting("theme")
		await frames()
		var keys := Game.THEME_NAMES.keys()
		qa.check(game.hud._bubble_buttons.size() == 6, "selector has random and five static themes")
		for i in keys.size():
			var icon := picture(game.hud._bubble_buttons[i])
			qa.check(icon and icon.texture == Game._theme_picture(keys[i]), "choice uses static icon: " + keys[i])
		qa.check(theme_stages(game.hud) == 0, "theme selector creates no 3D theme stage")
		game.hud._bubble_buttons[keys.find(selected)].pressed.emit()
		await frames()
		qa.check(game.theme == selected and game.phase == "generative", "choice sets selected theme: " + selected)
		var card_icon := picture(game.hud._cards.theme)
		qa.check(card_icon.texture == Game._theme_picture(selected) and card_icon.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR, "card updates static image with smooth filter: " + selected)
		qa.check(theme_stages(game.hud) == 0, "updated card creates no theme stage")
	var collage := Game._theme_picture("")
	var image := collage.get_image()
	qa.check(collage == Game._theme_picture("") and image.get_size() == Vector2i(512, 342), "random collage is cached and matches theme dimensions")
	qa.check(image.get_pixel(0, 0).a == 0 and not image.is_invisible(), "random collage has transparent space and visible icons")


func selectors() -> void:
	game._show_generative_menu()
	await frames()
	await capture("generative")
	for which in ["difficulty", "size", "theme", "players"]:
		if which == "players":
			game._pick_generative_players()
		else:
			game._pick_setting(which)
		await frames()
		qa.check(visible(game.hud._bubble_box), which + ": selector cabe en ventana pequeña")
		await capture(which)
		game.hud.close_bubble(true)
		await frames()
		qa.check(game.phase == "generative" and game.hud._cards[which].has_focus(), which + ": cerrar recupera tarjeta")
	game.size = "small"
	# Regression: opening focus may replace the menu while _bubble_open resumes.
	game._pick_setting("size")
	game.hud._bubble_buttons[0].focus_entered.connect(game._show_title, CONNECT_ONE_SHOT)
	await frames()
	qa.check(not game.hud.bubble_open() and game.phase == "title", "cierre durante foco no deja selector huérfano")
	game._show_generative_menu()
	await frames()
	game._pick_setting("size")
	await frames()
	qa.check(game.hud.bubble_open() and game.hud.bubble_focus() >= 0, "se puede reabrir después del cierre durante foco")
	game.hud.close_bubble(true)


func _init() -> void:
	Settings.path = "user://test_menu_clarity_settings.cfg"
	Story.save = "user://test_menu_clarity.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await frames()
	for child in game.get_children():
		if child is TitleScreen:
			child.queue_free()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(960, 540)
	game.ui_scale = 150
	root.content_scale_factor = 1.5
	await frames()
	await settings_layout()
	await selectors()
	await theme_icons()
	root.content_scale_factor = 1.0
	root.size = Vector2i(1280, 720)
	game.challenges.show_menu()
	await frames()
	var longest := 1
	for n in range(1, Story.count() + 1):
		if game.challenges.night_name(n).length() > game.challenges.night_name(longest).length():
			longest = n
	game.challenges.land_night(longest)
	await frames()
	var name_label: Label = game.hud._named.pick_name
	qa.check(name_label.text == game.challenges.night_name(longest) and name_label.autowrap_mode != TextServer.AUTOWRAP_OFF, "Retos mantiene nombre completo en detalle")
	await capture("challenges")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Story.save))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	quit(qa.summary())
