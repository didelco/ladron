class_name PaintingCanvas
extends RefCounted
## Genera las seis familias clásicas de cuadros con su semilla original.
## Primero consulta los assets dibujados de Canvases; solo genera si faltan.
## Comparte el hash visual de MuseumView para conservar cada píxel.

static func texture(seed: int, forced := -1) -> Texture2D:
	var r := func(k: int) -> float: return MuseumView._hash01(seed, k, 71)
	var kind := int(r.call(1) * 6) if forced < 0 else forced
	var ready := Canvases.drawn(Canvases.OLD[kind], seed)
	if ready:
		return ready
	var w := 48
	var h := 36
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	if kind == 3:
		_pipe(img, r)
		return ImageTexture.create_from_image(img)
	if kind == 4:
		_banana(img, r)
		return ImageTexture.create_from_image(img)
	if kind == 5:
		_ice_cream(img, r)
		return ImageTexture.create_from_image(img)
	if kind == 0:
		# Landscape: sky, a moon or low sun, hills in three planes.
		var dusk: bool = r.call(2) > 0.5
		var top := Color("#2a1f4d") if dusk else Color("#274b6e")
		var bottom := Color("#e07a5f") if dusk else Color("#a8d8e8")
		for yy in h:
			img.fill_rect(Rect2i(0, yy, w, 1), top.lerp(bottom, float(yy) / h))
		var sx := int(8 + r.call(3) * 30)
		var sy := int(8 + r.call(4) * 6)
		for yy in range(-3, 4):
			for xx in range(-3, 4):
				if xx * xx + yy * yy <= 9:
					img.set_pixel(clampi(sx + xx, 0, w - 1), clampi(sy + yy, 0, h - 1), Color("#ffd479") if dusk else Color("#fff4d0"))
		for plane in 3:
			var col: Color = [Color("#4a5d4f"), Color("#2f4a3a"), Color("#1b2c24")][plane]
			for xx in w:
				var top_y := int(20 + plane * 4 + sin(xx * 0.16 + r.call(5 + plane) * 6) * (4 - plane))
				img.fill_rect(Rect2i(xx, top_y, 1, h - top_y), col)
	elif kind == 1:
		# Portrait: a sitter in the dark, lit from one side.
		img.fill(Color("#1d120c"))
		img.fill_rect(Rect2i(8, 4, 32, 28), Color("#3a2618"))
		var coat := Color("#2a1a3a") if r.call(2) > 0.5 else Color("#3a1c1c")
		img.fill_rect(Rect2i(12, 26, 24, 10), coat)
		img.fill_rect(Rect2i(19, 10, 10, 14), Color("#d9b48f"))
		img.fill_rect(Rect2i(25, 10, 4, 14), Color("#a8805f"))
		img.fill_rect(Rect2i(18, 7, 12, 5), Color("#1a120c"))
	else:
		# Abstract: blocks of colour on cream, with black lines.
		img.fill(Color("#e8ddc0"))
		var cols := [Color("#9b2c3f"), Color("#7ad6ff"), Color("#f0c46a"), Color("#1b2433")]
		for j in 4:
			img.fill_rect(Rect2i(int(r.call(10 + j) * 34), int(r.call(20 + j) * 24), 8 + int(r.call(30 + j) * 14), 6 + int(r.call(40 + j) * 12)), cols[(j + int(r.call(2) * 4)) % 4])
		for j in 3:
			var at := 6 + int(r.call(60 + j) * 36)
			if r.call(50 + j) > 0.5:
				img.fill_rect(Rect2i(clampi(at, 0, w - 2), 0, 2, h), Color("#141018"))
			else:
				img.fill_rect(Rect2i(0, clampi(at * h / w, 0, h - 2), w, 2), Color("#141018"))
	return ImageTexture.create_from_image(img)


## "This is not a pipe": a brown pipe on cream, and a line of writing under it.
static func _pipe(img: Image, r: Callable) -> void:
	img.fill(Color("#e8dcc0"))
	var wood := Color("#6b3a1e")
	var dark := Color("#3a1e0e")
	# The bowl, the shank and the stem, curving down to the mouthpiece.
	img.fill_rect(Rect2i(30, 8, 9, 12), wood)
	img.fill_rect(Rect2i(29, 9, 1, 10), dark)
	img.fill_rect(Rect2i(31, 8, 7, 2), dark)
	img.fill_rect(Rect2i(32, 18, 6, 3), wood)
	for x in range(9, 31):
		var y := 17 + int(2.0 * sin((x - 9) / 22.0 * PI))
		img.fill_rect(Rect2i(x, y, 1, 3), wood)
		img.set_pixel(x, y + 2, dark)
	img.fill_rect(Rect2i(6, 16, 4, 2), Color("#1a1210"))
	img.fill_rect(Rect2i(33, 11, 2, 5), Color("#8a5a32"))
	# The caption, in a copperplate of dots.
	var x := 10
	while x < 38:
		var word := 2 + int(r.call(80 + x) * 4)
		img.fill_rect(Rect2i(x, 28, word, 1), Color("#2a1e14"))
		img.set_pixel(x, 27, Color("#2a1e14"))
		x += word + 2


## A pop-art banana: yellow, curved, on white, with its brown tips.
static func _banana(img: Image, r: Callable) -> void:
	img.fill(Color("#f7f3ea") if r.call(3) > 0.3 else Color("#ff9ec7"))
	var yellow := Color("#ffd23f")
	var shade := Color("#e0a800")
	for i in 60:
		var t := i / 59.0
		var a := lerpf(PI * 1.15, PI * 1.85, t)
		var cx := 24.0 + cos(a) * 18.0
		var cy := 6.0 - sin(a) * 18.0
		var thick := 2.0 + sin(t * PI) * 3.5
		for k in int(thick * 2):
			var y := int(cy - thick + k)
			img.set_pixel(clampi(int(cx), 0, 47), clampi(y, 0, 35), shade if k < 2 else yellow)
		img.set_pixel(clampi(int(cx), 0, 47), clampi(int(cy + thick), 0, 35), Color("#1a1a1a"))
	img.fill_rect(Rect2i(4, 12, 3, 3), Color("#5a3a1a"))
	img.fill_rect(Rect2i(41, 12, 3, 2), Color("#5a3a1a"))
	img.fill_rect(Rect2i(34, 31, 10, 1), Color("#1a1a1a"))


## An ice cream: a crosshatched cone, three scoops and a cherry.
static func _ice_cream(img: Image, r: Callable) -> void:
	img.fill(Color("#a8e0f0") if r.call(4) > 0.5 else Color("#ffd6e8"))
	var cone := Color("#d9954a")
	for y in range(18, 34):
		var half := int((34 - y) * 0.45)
		img.fill_rect(Rect2i(24 - half, y, half * 2 + 1, 1), cone)
		for x in range(24 - half, 25 + half):
			if (x + y) % 4 == 0 or (x - y) % 4 == 0:
				img.set_pixel(x, y, Color("#a8662a"))
	var scoops := [Color("#ff8ab5"), Color("#8fe0b0"), Color("#6b3a2a")]
	var at := [Vector2i(19, 16), Vector2i(29, 16), Vector2i(24, 10)]
	for k in 3:
		for dy in range(-6, 7):
			for dx in range(-6, 7):
				if dx * dx + dy * dy <= 30:
					img.set_pixel(at[k].x + dx, at[k].y + dy, (scoops[k] as Color).lightened(0.25) if dx < -2 and dy < -2 else scoops[k])
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if dx * dx + dy * dy <= 4:
				img.set_pixel(24 + dx, 3 + dy, Color("#d62839"))
	img.fill_rect(Rect2i(25, 0, 1, 2), Color("#3a6a2a"))


