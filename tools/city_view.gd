extends SceneTree
## The story's town (CityStage) seen whole, for working on it:
##
##   godot --path . --script tools/city_view.gd -- <out dir> [plan] [screens] [museos] [count] [all] [seed=N]
##
## plan: the whole town from above at the game's own angle (plan.png), with
## what the camera can ever see at each screen shape drawn over it (4:3,
## 16:10, 16:9, CityStage.WIDEST, 21:9, 32:9) and the safe margin (SAFE).
## screens: the town as the game shows it (Tour) in a window of each shape,
## looking at each museum (screen_<shape>_<museum>.png).
## museos: each MuseumBuilding on its own, the game's usual look at it
## (museo_<tema>.png) and a closer shot on its front for working on details
## like columns or windows (museo_<tema>_detalle.png).
## count: what is built and what is left out as never seen, printed.
## all: build everything, as before the cut (to compare).
## seed=N: the town's own seed (CityStage.town_seed); the game always uses 7,
## this is only to compare variants of the same rules.

const SHAPES := [[Vector2i(1024, 768), "4:3", Color("#ff5a5a")], [Vector2i(1280, 800), "16:10", Color("#ffa13a")],
	[Vector2i(1920, 1080), "16:9", Color("#ffe14a")], [Vector2i(2160, 1080), "2:1", Color("#5aff7a")],
	[Vector2i(2560, 1080), "21:9", Color("#5ad8ff")], [Vector2i(5120, 1440), "32:9", Color("#c77dff")]]
## The windows the screens are taken in: each shape, small enough for any
## monitor (only the shape changes what is seen, not the pixels).
const WINDOWS := {"4:3": Vector2i(1024, 768), "16:10": Vector2i(1280, 800), "16:9": Vector2i(1600, 900),
	"2:1": Vector2i(1600, 800), "21:9": Vector2i(1792, 768), "32:9": Vector2i(1920, 540)}
const PLAN_SIZE := Vector2i(2000, 1500)

var out := ""
var parts: Array = []
var town_seed := 7


func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	out = args.pop_front() if not args.is_empty() else "build/city_view"
	parts = args if not args.is_empty() else ["plan", "count"]
	for p in parts.duplicate():
		if String(p).begins_with("seed="):
			town_seed = int(String(p).substr(5))
			parts.erase(p)
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _stage(size: Vector2i) -> CityStage:
	var stage := CityStage.new()
	stage.size = size
	stage.hurry = true
	stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.cut = not "all" in parts
	stage.town_seed = town_seed
	root.add_child(stage)
	return stage


func _run() -> void:
	root.size = Vector2i(800, 600)
	if "plan" in parts or "count" in parts:
		var stage := _stage(PLAN_SIZE)
		stage.transparent_bg = false
		var t0 := Time.get_ticks_msec()
		stage.build(Story.MUSEUMS.size() - 1, 0)
		print("built in %d ms" % (Time.get_ticks_msec() - t0))
		if "count" in parts:
			_count(stage)
		if "plan" in parts:
			await _plan(stage)
		stage.queue_free()
		await process_frame
	if "screens" in parts:
		# The town as the game shows it (Tour: the signs, the fade at the
		# sides), in a window of each shape; its own settings and progress.
		DirAccess.make_dir_recursive_absolute("user://city_view")
		Settings.path = "user://city_view/settings.cfg"
		Story.save = "user://city_view/progress.cfg"
		var st := Settings.DEFAULTS.duplicate()
		st.fullscreen = false
		st.sound = false
		st.music = false
		Settings.write(st)
		Story.unlock(Story.count(), 1)
		for shape in SHAPES:
			var size: Vector2i = WINDOWS[shape[1]]
			root.size = size
			root.content_scale_size = Vector2i(1280, 720)
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
			var tour := Tour.new()
			root.add_child(tour)
			tour.stage.hurry = true
			tour.stage.cut = not "all" in parts
			tour.open_city(1, 0)
			for m in Story.MUSEUMS.size():
				tour._pick_museum(m)
				for i in 6:
					await process_frame
				await RenderingServer.frame_post_draw
				var path := "%s/screen_%s_%d.png" % [out, String(shape[1]).replace(":", "x"), m + 1]
				root.get_texture().get_image().save_png(path)
				print("saved " + path)
			tour.queue_free()
			await process_frame
	if "museos" in parts:
		# Each MuseumBuilding on its own: the game's usual look at it, and a
		# closer shot (half the camera's size, so ~4x closer) for working on
		# details like columns or windows.
		DirAccess.make_dir_recursive_absolute("user://city_view")
		Settings.path = "user://city_view/settings.cfg"
		Story.save = "user://city_view/progress.cfg"
		var st := Settings.DEFAULTS.duplicate()
		st.fullscreen = false
		st.sound = false
		st.music = false
		Settings.write(st)
		Story.unlock(Story.count(), 1)
		root.size = Vector2i(1600, 900)
		root.content_scale_size = Vector2i(1280, 720)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		var tour := Tour.new()
		root.add_child(tour)
		tour.stage.hurry = true
		tour.stage.cut = not "all" in parts
		tour.open_city(1, 0)
		for m in Story.MUSEUMS.size():
			tour._pick_museum(m)
			for i in 6:
				await process_frame
			var tema := String(Story.MUSEUMS[m].theme)
			var full := tour.stage.view
			await RenderingServer.frame_post_draw
			var path := "%s/museo_%s.png" % [out, tema]
			root.get_texture().get_image().save_png(path)
			print("saved " + path)
			# view drives the camera's size every frame (CityStage._process),
			# so the zoom has to go through it, not the camera directly.
			tour.stage.view = full * 0.25
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var close := "%s/museo_%s_detalle.png" % [out, tema]
			root.get_texture().get_image().save_png(close)
			print("saved " + close)
			tour.stage.view = full
		tour.queue_free()
		await process_frame
	quit()


func _count(stage: CityStage) -> void:
	var b: TownBuilder = stage._builder
	var kinds := {}
	for k in b.made:
		kinds[k] = true
	for k in b.unseen:
		kinds[k] = true
	var made := 0
	var gone := 0
	for k in kinds:
		print("%-10s built %6d   left out %6d" % [k, b.made.get(k, 0), b.unseen.get(k, 0)])
		made += b.made.get(k, 0)
		gone += b.unseen.get(k, 0)
	print("%-10s built %6d   left out %6d  (%.0f%% left out)" % ["all", made, gone, 100.0 * gone / maxf(1, made + gone)])
	var nodes := stage._scenery.get_child_count()
	print("scenery nodes: %d" % nodes)
	# Does the land (as far as the woods go) cover all each screen shape sees?
	var edge := TownBuilder.REACH + 6.0
	var land := PackedVector2Array()
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		land.append(stage.on_plane(stage.town.transform * Vector3(c.x * edge, 0, c.y * edge)))
	for shape in SHAPES:
		var aspect: float = float(shape[0].x) / shape[0].y
		var out_of := 0
		for p in stage.sight(aspect):
			if not Geometry2D.is_point_in_polygon(p, land):
				out_of += 1
		print("%-6s sees past the land: %s" % [shape[1], "yes (%d corners)" % out_of if out_of else "no"])
	var safe := Array(stage.sight(CityStage.WIDEST, CityStage.SAFE)).filter(func(p): return not Geometry2D.is_point_in_polygon(p, land))
	print("safe margin past the land: %s" % ("yes (%d corners)" % safe.size() if safe else "no"))


## The whole town from above at the game's angle, and over it what each
## screen shape sees and the safe margin.
func _plan(stage: CityStage) -> void:
	var cam := stage.camera()
	var span := 125.0
	cam.size = span
	var centre := Vector3.ZERO
	for m in Story.MUSEUMS.size():
		centre += stage._look_at(m)
	centre /= Story.MUSEUMS.size()
	stage.focus = centre
	stage.picked = 2
	stage.view = span
	stage.set_process(false)
	# Keep it there: no gliding (set the camera by hand every frame).
	for i in 4:
		cam.size = span
		cam.position = centre + cam.basis.z * 80.0
		await process_frame
	await RenderingServer.frame_post_draw
	var img := stage.get_texture().get_image()
	var c0 := stage.on_plane(cam.position)
	var px := func(p: Vector2) -> Vector2:
		return Vector2(PLAN_SIZE.x * 0.5 + (p.x - c0.x) * PLAN_SIZE.y / span, PLAN_SIZE.y * 0.5 - (p.y - c0.y) * PLAN_SIZE.y / span)
	for shape in SHAPES:
		var aspect: float = float(shape[0].x) / shape[0].y
		_poly(img, Array(stage.sight(aspect)).map(px), shape[2], 3)
	_poly(img, Array(stage.sight(CityStage.WIDEST, CityStage.SAFE)).map(px), Color.WHITE, 2)
	# The museums' looks, a dot each.
	for m in Story.MUSEUMS.size():
		var p: Vector2 = px.call(stage.on_plane(stage._look_at(m)))
		img.fill_rect(Rect2i(Vector2i(p) - Vector2i(6, 6), Vector2i(12, 12)), Color(Story.MUSEUMS[m].colour))
	var hp: Vector2 = px.call(stage.on_plane(stage.town.transform * stage.hideout_spot))
	img.fill_rect(Rect2i(Vector2i(hp) - Vector2i(8, 8), Vector2i(16, 16)), Color("#e2262f"))
	img.save_png(out + "/plan.png")
	print("saved %s/plan.png" % out)


func _save(stage: CityStage, path: String) -> void:
	await RenderingServer.frame_post_draw
	stage.get_texture().get_image().save_png(path)
	print("saved " + path)


func _poly(img: Image, pts: Array, colour: Color, w: int) -> void:
	for i in pts.size():
		_line(img, pts[i], pts[(i + 1) % pts.size()], colour, w)


func _line(img: Image, a: Vector2, b: Vector2, colour: Color, w: int) -> void:
	var n := int(maxf(a.distance_to(b), 1.0))
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		var r := Rect2i(Vector2i(p) - Vector2i(w / 2, w / 2), Vector2i(w, w)).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.has_area():
			img.fill_rect(r, colour)
