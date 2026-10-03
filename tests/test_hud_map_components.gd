extends SceneTree
## Equivalencia de planos y leyendas capturada antes de separar el HUD.
const Support := preload("res://tests/support.gd")
const FIXTURE := "res://tests/fixtures/hud_maps.json"
var qa := Support.new("  ")

func digest(image: Image) -> String:
	return image.get_data().hex_encode().sha256_text()

func snapshots() -> Dictionary:
	var results := {}
	var colours: Array = [Color("#2ec4a6"), Color("#f0a13a")]
	for size in ["small", "medium", "large"]:
		seed(4242)
		var map := MapFile.generated(4242, size)
		map.apply()
		Heist.plan_job(3, {}, 2, map.job())
		Props.place(4242, [Heist.at, Heist.exit, Heist.start])
		var thieves: Array[Thief] = [Sim.new_thief("p1"), Sim.new_thief("p2")]
		var guard := Guard.new()
		guard.x = Heist.start.x + 1.5
		guard.y = Heist.start.y + 1.5
		var guards: Array[Guard] = [guard]
		Hud.home_map = false
		results[size + "/live"] = digest(Hud.live_map(thieves, colours))
		Heist.carrier = "p1"
		Heist.taken = true
		results[size + "/carrying"] = digest(Hud.live_map(thieves, colours))
		Heist.taken = false
		Heist.carrier = ""
		results[size + "/plan"] = digest(Hud.plan_map(guards, colours))
		results[size + "/pins"] = digest(Hud.plan_map(guards, colours, true, Vector2(Heist.at)))
		results[size + "/mission"] = digest(Hud.mission_map(guards).get_image())
	var home := load("res://scenes/home/dojo.tscn").instantiate() as HomeSpace
	home.configure()
	Practice.map(4).apply()
	Heist.plan_job(1, {}, 4, {})
	Props.list.clear()
	Hud.home_map = true
	Hud.dark_rooms = ["aseo", "dojo2"]
	results["home/dark"] = digest(Hud.live_map([Sim.new_thief("p1")] as Array[Thief], [colours[0]]))
	home.free()
	Hud.home_map = false
	Hud.dark_rooms = []
	for key in Hud.LEGEND:
		results["legend/" + key] = digest(Hud.legend_icon(key, Color("#2ec4a6")).get_image())
	return results

func _init() -> void:
	var actual := snapshots()
	if "--record-baseline" in OS.get_cmdline_user_args():
		var file := FileAccess.open(FIXTURE, FileAccess.WRITE)
		file.store_string(JSON.stringify(actual, "\t") + "\n")
		print("OK: planos antes de separar el HUD")
		quit()
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	for key in expected:
		qa.check(actual[key] == expected[key], key + ": mismos píxeles")
	quit(qa.summary())
