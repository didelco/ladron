class_name Art
extends RefCounted
## Pixel illustrations for the menus, drawn into images at start: the cover
## of each mode, the guards of each difficulty, a floor plan for each museum
## size. Small canvases scaled up with nearest filtering, in the same chunky
## pixels as the title's font.

const INK := Color("#0b0820")
const NIGHT_TOP := Color("#07061a")
const NIGHT_LOW := Color("#2a1f5c")
const STONE := Color("#3b3470")
const STONE_LIT := Color("#5a4fa0")
const GOLD := Color("#ffe066")
const MOON := Color("#f4ecc8")
const GUARD := Color("#9b2c3f")
const GUARD_DARK := Color("#5e1826")
const SKIN := Color("#f0c9a0")
const THIEF := Color("#2ec4a6")
const THIEF2 := Color("#f0a13a")


static func _canvas(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _texture(img: Image, scale: int) -> ImageTexture:
	img.resize(img.get_width() * scale, img.get_height() * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)


## Night sky from top to bottom, with a fixed scatter of stars.
static func _sky(img: Image, seed: int) -> void:
	var h := img.get_height()
	for y in h:
		var c := NIGHT_TOP.lerp(NIGHT_LOW, float(y) / h)
		img.fill_rect(Rect2i(0, y, img.get_width(), 1), c)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 26:
		var x := rng.randi_range(0, img.get_width() - 1)
		var y := rng.randi_range(0, h * 2 / 3)
		img.set_pixel(x, y, Color(1, 1, 1, rng.randf_range(0.35, 1.0)))


static func _disc(img: Image, cx: int, cy: int, r: int, c: Color) -> void:
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if x * x + y * y <= r * r:
				var px := cx + x
				var py := cy + y
				if px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height():
					img.set_pixel(px, py, c)


## A thief in pixels, the title's hooded figure: 10 by 14.
static func _thief(img: Image, x0: int, y0: int, c: Color) -> void:
	for r in [[3, 0, 4, 1], [2, 1, 6, 3], [2, 5, 6, 4], [1, 6, 1, 3], [8, 6, 1, 3], [2, 10, 2, 4], [6, 10, 2, 4]]:
		img.fill_rect(Rect2i(x0 + r[0], y0 + r[1], r[2], r[3]), c)
	img.fill_rect(Rect2i(x0 + 3, y0 + 2, 4, 1), INK)


## A guard: peaked cap, face, red coat, torch in hand. 12 by 18.
## mood: "sleepy" (eyes shut), "awake", "angry" (brows, eyes red).
static func _guard(img: Image, x0: int, y0: int, mood: String) -> void:
	img.fill_rect(Rect2i(x0 + 2, y0, 7, 2), GUARD_DARK)          # cap
	img.fill_rect(Rect2i(x0 + 1, y0 + 2, 9, 1), INK)              # peak
	img.fill_rect(Rect2i(x0 + 3, y0 + 3, 5, 4), SKIN)             # face
	match mood:
		"sleepy":
			img.fill_rect(Rect2i(x0 + 4, y0 + 5, 1, 1), INK)
			img.fill_rect(Rect2i(x0 + 6, y0 + 5, 1, 1), INK)
		"angry":
			img.fill_rect(Rect2i(x0 + 3, y0 + 3, 2, 1), INK)
			img.fill_rect(Rect2i(x0 + 6, y0 + 3, 2, 1), INK)
			img.set_pixel(x0 + 4, y0 + 4, Color("#ff3d6e"))
			img.set_pixel(x0 + 6, y0 + 4, Color("#ff3d6e"))
		_:
			img.set_pixel(x0 + 4, y0 + 4, INK)
			img.set_pixel(x0 + 6, y0 + 4, INK)
	img.fill_rect(Rect2i(x0 + 2, y0 + 7, 7, 6), GUARD)            # coat
	img.fill_rect(Rect2i(x0 + 5, y0 + 8, 1, 4), GOLD)             # buttons
	img.fill_rect(Rect2i(x0 + 1, y0 + 8, 1, 4), GUARD)            # arms
	img.fill_rect(Rect2i(x0 + 9, y0 + 8, 1, 3), GUARD)
	img.fill_rect(Rect2i(x0 + 9, y0 + 11, 2, 1), Color("#5c6370"))  # torch
	img.fill_rect(Rect2i(x0 + 3, y0 + 13, 2, 5), INK)             # legs
	img.fill_rect(Rect2i(x0 + 6, y0 + 13, 2, 5), INK)


## Story cover: the museum at night under the moon, a thief on the steps.
static func story_cover() -> ImageTexture:
	var img := _canvas(96, 60)
	_sky(img, 3)
	_disc(img, 76, 13, 8, MOON)
	_disc(img, 79, 11, 2, MOON.darkened(0.12))
	_disc(img, 73, 16, 1, MOON.darkened(0.12))
	# Pediment, frieze, columns, steps.
	for i in 12:
		img.fill_rect(Rect2i(20 + i * 2, 24 - i, 56 - i * 4, 1), STONE_LIT)
	img.fill_rect(Rect2i(18, 25, 60, 3), STONE_LIT)
	img.fill_rect(Rect2i(20, 28, 56, 20), STONE)
	for k in 6:
		img.fill_rect(Rect2i(22 + k * 10, 28, 4, 20), STONE_LIT)
	# One window lit: someone is awake.
	img.fill_rect(Rect2i(45, 33, 5, 7), GOLD)
	img.fill_rect(Rect2i(47, 33, 1, 7), STONE)
	for s in 3:
		img.fill_rect(Rect2i(16 - s * 2, 48 + s * 2, 64 + s * 4, 2), STONE_LIT.darkened(0.15 * s))
	img.fill_rect(Rect2i(0, 54, 96, 6), Color("#120e2a"))
	_thief(img, 8, 40, THIEF)
	return _texture(img, 4)


## Generative cover: a floor plan being drawn, a pair of dice on top.
static func generative_cover() -> ImageTexture:
	var img := _canvas(96, 60)
	img.fill(Color("#0f1c3a"))
	# Blueprint grid.
	for x in range(0, 96, 6):
		img.fill_rect(Rect2i(x, 0, 1, 60), Color("#17305c"))
	for y in range(0, 60, 6):
		img.fill_rect(Rect2i(0, y, 96, 1), Color("#17305c"))
	var plan := MapGen.generate(20260924, 31, 19, "L")
	for y in plan.h:
		for x in plan.w:
			if plan.at(x, y) == Tiles.WALL and plan.outside[y * plan.w + x] == 0:
				img.fill_rect(Rect2i(2 + x * 3, 2 + y * 3, 3, 3), Color("#7fb3ff"))
	# Two dice.
	for d in [[62, 30, [[1, 1], [3, 3], [5, 5]]], [76, 40, [[1, 1], [5, 1], [1, 5], [5, 5]]]]:
		img.fill_rect(Rect2i(d[0], d[1], 13, 13), INK)
		img.fill_rect(Rect2i(d[0] + 1, d[1] + 1, 11, 11), Color("#fff4d6"))
		for pip in d[2]:
			img.fill_rect(Rect2i(d[0] + 2 + pip[0], d[1] + 2 + pip[1], 2, 2), Color("#c2185b"))
	return _texture(img, 4)


## The players: one thief or two, on a spotlight.
static func players(n: int) -> ImageTexture:
	var img := _canvas(40, 20)
	for y in 6:
		var w := 30 - y * 2
		img.fill_rect(Rect2i(20 - w / 2, 14 + y, w, 1), Color(1, 0.9, 0.5, 0.25 - y * 0.035))
	if n == 1:
		_thief(img, 15, 2, THIEF)
	else:
		_thief(img, 8, 2, THIEF)
		_thief(img, 22, 2, THIEF2)
	return _texture(img, 5)


## A difficulty: how many guards, and in what mood.
static func guards(level: String) -> ImageTexture:
	var img := _canvas(44, 26)
	match level:
		"easy":
			_guard(img, 16, 6, "sleepy")
			# Zzz.
			for z in [[29, 5], [33, 1]]:
				img.fill_rect(Rect2i(z[0], z[1], 3, 1), Color("#9aa0c8"))
				img.set_pixel(z[0] + 1, z[1] + 1, Color("#9aa0c8"))
				img.fill_rect(Rect2i(z[0], z[1] + 2, 3, 1), Color("#9aa0c8"))
		"medium":
			_guard(img, 8, 6, "awake")
			_guard(img, 24, 6, "awake")
		_:
			_guard(img, 1, 7, "angry")
			_guard(img, 16, 5, "angry")
			_guard(img, 31, 7, "angry")
	return _texture(img, 5)


## A museum size: a real floor plan, drawn to scale against the others.
static func museum(size: String) -> ImageTexture:
	var dims: Dictionary = Museum.SIZES[size]
	var img := _canvas(52, 38)
	var plan := MapGen.generate(777, dims.w, dims.h, "rect")
	var ox := (52 - plan.w) / 2
	var oy := (38 - plan.h) / 2
	for y in plan.h:
		for x in plan.w:
			var t := plan.at(x, y)
			img.set_pixel(ox + x, oy + y, Color("#2a2550") if t != Tiles.WALL else Color("#8a80d0"))
	return _texture(img, 4)
