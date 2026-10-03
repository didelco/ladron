extends SceneTree
## Las recreativas comparten materiales sin contaminar los otros juegos.
## La textura conserva sus píxeles, orientación y filtro al usar la fachada.
const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")

func _init() -> void:
	for game in ArcadeAppearance.GAMES:
		var first := MuseumView.asset(Arcades.MODEL)
		var second := MuseumView.asset(Arcades.MODEL)
		MuseumView.arcade_game(first, game)
		ArcadeAppearance.apply(second, game)
		var screen := first.find_child("pantalla", true, false) as MeshInstance3D
		var other_screen := second.find_child("pantalla", true, false) as MeshInstance3D
		var side := first.find_child("mueble", true, false) as MeshInstance3D
		var other_side := second.find_child("mueble", true, false) as MeshInstance3D
		qa.check(side.get_active_material(0) == other_side.get_active_material(0), "%s: comparte el material del mueble" % game)
		var picture := screen.get_child(0) as MeshInstance3D
		var other_picture := other_screen.get_child(0) as MeshInstance3D
		var material := picture.material_override as StandardMaterial3D
		qa.check(material == other_picture.material_override, "%s: comparte textura y material de pantalla" % game)
		qa.check(picture.transform == other_picture.transform and picture.mesh.size == other_picture.mesh.size, "%s: fachada y componente colocan igual la pantalla" % game)
		qa.check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s: los píxeles conservan el filtro" % game)
		var image := material.albedo_texture.get_image()
		var look: Dictionary = ArcadeAppearance.GAMES[game]
		var matches := true
		for y in look.art.size():
			for x in look.art[y].length():
				var ink: String = look.art[y][x]
				var colour := Color(look.screen if ink == "." else look.ink[ink])
				matches = matches and image.get_pixel(x, y).is_equal_approx(colour)
		qa.check(matches, "%s: imagen coincide con el diseño completo" % game)
		first.free()
		second.free()
	var tennis := MuseumView.asset(Arcades.MODEL)
	var invaders := MuseumView.asset(Arcades.MODEL)
	ArcadeAppearance.apply(tennis, "tenis")
	ArcadeAppearance.apply(invaders, "invasores")
	var tennis_side := tennis.find_child("mueble", true, false) as MeshInstance3D
	var invaders_side := invaders.find_child("mueble", true, false) as MeshInstance3D
	qa.check(tennis_side.get_active_material(0) != invaders_side.get_active_material(0), "dos juegos distintos conservan materiales propios")
	qa.check((tennis_side.get_active_material(0) as BaseMaterial3D).albedo_color == Color("#7a3ce0"), "vestir otra máquina no recolorea la anterior")
	tennis.free()
	invaders.free()
	quit(qa.summary())
