class_name Canvases
extends RefCounted
## The paintings on the walls, by kind (Themes lists which hang in which
## gallery): little pixel pictures, 48 × 36, drawn here from a seed so no two
## of a kind are quite the same. The old ones (landscape, portrait, abstract,
## pipe, banana, ice cream) are MuseumView's.

const W := 48
const H := 36
const OLD := ["landscape", "portrait", "abstract", "pipe", "banana", "ice_cream"]


static func paint(kind: String, seed: int) -> ImageTexture:
	if kind in OLD:
		return MuseumView._canvas(seed, OLD.find(kind))
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	var r := func(k: int) -> float: return MuseumView._hash01(seed, k, 71)
	match kind:
		"pyramids": _pyramids(img, r)
		"hieroglyphs": _hieroglyphs(img, r)
		"nile": _nile(img, r)
		"castle": _castle(img, r)
		"dragon": _dragon(img, r)
		"tapestry": _tapestry(img, r)
		_: img.fill(Color("#3a2618"))
	return ImageTexture.create_from_image(img)


static func _sky(img: Image, top: Color, bottom: Color, to: int) -> void:
	for y in to:
		img.fill_rect(Rect2i(0, y, W, 1), top.lerp(bottom, float(y) / to))


static func _disc(img: Image, cx: int, cy: int, rad: int, c: Color) -> void:
	for y in range(-rad, rad + 1):
		for x in range(-rad, rad + 1):
			if x * x + y * y <= rad * rad:
				_dot(img, cx + x, cy + y, c)


static func _dot(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


## A triangle standing on its base: apex (x, top), half-width at the base.
static func _peak(img: Image, x: int, top: int, base: int, half: int, lit: Color, shade: Color) -> void:
	for y in range(top, base):
		var w := int(float(y - top) / (base - top) * half)
		img.fill_rect(Rect2i(x - w, y, w, 1), lit)
		img.fill_rect(Rect2i(x, y, w + 1, 1), shade)


# --- The ancient world -------------------------------------------------------------

## Three pyramids on the dunes under a big low sun.
static func _pyramids(img: Image, r: Callable) -> void:
	var dusk: bool = r.call(2) > 0.5
	_sky(img, Color("#2a3a8a") if dusk else Color("#3a8ad0"), Color("#f09a4a") if dusk else Color("#bfe4f0"), 26)
	_disc(img, 10 + int(r.call(3) * 26), 9, 4, Color("#ffd86a") if dusk else Color("#fff6c8"))
	img.fill_rect(Rect2i(0, 26, W, H - 26), Color("#d9b77a"))
	for x in W:
		var y := 25 + int(sin(x * 0.2 + r.call(4) * 5) * 1.5)
		img.fill_rect(Rect2i(x, y, 1, 2), Color("#c9a060"))
	var at := 8 + int(r.call(5) * 6)
	_peak(img, at, 12, 27, 11, Color("#e8c890"), Color("#b08a50"))
	_peak(img, at + 17, 15, 27, 9, Color("#e2c088"), Color("#a8844e"))
	_peak(img, at + 29, 19, 27, 6, Color("#dcba82"), Color("#a07e48"))
	# A camel's silhouette on the dunes, now and then.
	if r.call(6) > 0.4:
		var cx := 36 + int(r.call(7) * 6)
		img.fill_rect(Rect2i(cx, 29, 6, 2), Color("#5a3a1e"))
		img.fill_rect(Rect2i(cx + 1, 28, 2, 1), Color("#5a3a1e"))
		img.fill_rect(Rect2i(cx + 6, 26, 1, 4), Color("#5a3a1e"))
		img.fill_rect(Rect2i(cx + 6, 26, 2, 1), Color("#5a3a1e"))
		for k in 4:
			img.fill_rect(Rect2i(cx + k * 2 - (k / 2), 31, 1, 3), Color("#5a3a1e"))


## A wall of hieroglyphs: sandstone, columns of signs in blue, red and black,
## and a figure in profile.
static func _hieroglyphs(img: Image, r: Callable) -> void:
	img.fill(Color("#e0c48a"))
	img.fill_rect(Rect2i(0, 0, W, 2), Color("#2a4fb0"))
	img.fill_rect(Rect2i(0, H - 2, W, 2), Color("#2a4fb0"))
	var inks := [Color("#2a4fb0"), Color("#b0402a"), Color("#1c1b22"), Color("#2f8a78")]
	for col in 8:
		var x := 2 + col * 6
		if col == 3 or col == 4:
			continue
		img.fill_rect(Rect2i(x + 4, 3, 1, H - 6), Color("#b89a60"))
		var y := 4
		var k := 0
		while y < H - 6:
			var c: Color = inks[int(r.call(10 + col * 9 + k) * inks.size())]
			match int(r.call(40 + col * 9 + k) * 4):
				0: _disc(img, x + 2, y + 1, 1, c)
				1: img.fill_rect(Rect2i(x, y, 4, 2), c)
				2: img.fill_rect(Rect2i(x + 1, y - 1, 2, 4), c)
				_:
					img.fill_rect(Rect2i(x, y + 1, 4, 1), c)
					img.fill_rect(Rect2i(x + 1, y - 1, 1, 2), c)
			y += 5
			k += 1
	# The figure: head in profile, eye, collar, kilt.
	var fx := 22
	img.fill_rect(Rect2i(fx, 6, 4, 4), Color("#1c1b22"))
	img.fill_rect(Rect2i(fx + 1, 8, 4, 3), Color("#b0703c"))
	img.set_pixel(fx + 3, 9, Color("#1c1b22"))
	img.fill_rect(Rect2i(fx, 11, 5, 2), Color("#2f8a78"))
	img.fill_rect(Rect2i(fx, 13, 4, 7), Color("#b0703c"))
	img.fill_rect(Rect2i(fx - 1, 20, 6, 5), Color("#f4f0e6"))
	img.fill_rect(Rect2i(fx, 25, 1, 6), Color("#b0703c"))
	img.fill_rect(Rect2i(fx + 3, 25, 1, 6), Color("#b0703c"))
	img.fill_rect(Rect2i(fx + 4, 13, 4, 1), Color("#b0703c"))


## The Nile: palms on the banks, a reed boat with its sail.
static func _nile(img: Image, r: Callable) -> void:
	_sky(img, Color("#4a9ad8"), Color("#d8ecf0"), 18)
	img.fill_rect(Rect2i(0, 18, W, 5), Color("#c9b070"))
	for y in range(23, H):
		img.fill_rect(Rect2i(0, y, W, 1), Color("#2a7ab0").lerp(Color("#1a4a80"), float(y - 23) / (H - 23)))
	for k in 6:
		img.fill_rect(Rect2i(int(r.call(20 + k) * 44), 26 + int(r.call(30 + k) * 8), 3, 1), Color("#8ac8f0"))
	for k in 3:
		var px := 3 + k * 7 + int(r.call(40 + k) * 3)
		img.fill_rect(Rect2i(px, 9, 1, 11), Color("#6a4a2a"))
		for d in [-3, -2, -1, 1, 2, 3]:
			_dot(img, px + d, 9 + absi(d) / 2, Color("#2f7a3a"))
			_dot(img, px + d, 10 + absi(d) / 2, Color("#3e9a4a"))
	var bx := 26 + int(r.call(5) * 8)
	for x in range(-7, 8):
		var lift := int(absf(x) * absf(x) / 12.0)
		img.fill_rect(Rect2i(bx + x, 25 - lift, 1, 2), Color("#c9a060"))
	img.fill_rect(Rect2i(bx, 13, 1, 12), Color("#5a3a1e"))
	for y in range(14, 23):
		img.fill_rect(Rect2i(bx + 1, y, int((y - 13) * 0.6) + 1, 1), Color("#f4ecd8"))


# --- The middle ages ---------------------------------------------------------------

## A castle on its hill, a road winding up to the gate, pennants flying.
static func _castle(img: Image, r: Callable) -> void:
	var night: bool = r.call(2) > 0.6
	_sky(img, Color("#1a1f4a") if night else Color("#5a9ad8"), Color("#4a3a6a") if night else Color("#cfe6f0"), 24)
	if night:
		_disc(img, 38, 7, 3, Color("#f4ecc8"))
	for x in W:
		var top := 22 + int(sin(x * 0.12 + 1.0) * 3.0)
		img.fill_rect(Rect2i(x, top, 1, H - top), Color("#3e7a3a") if not night else Color("#2a4a30"))
	var cx := 16 + int(r.call(3) * 12)
	var stone := Color("#9a9aa2") if not night else Color("#6a6a78")
	img.fill_rect(Rect2i(cx - 10, 13, 20, 9), stone)
	for k in 5:
		img.fill_rect(Rect2i(cx - 10 + k * 4, 11, 2, 2), stone)
	for s in [-1, 1]:
		var tx: int = cx + s * 11
		img.fill_rect(Rect2i(tx - 2, 8, 5, 14), stone.darkened(0.15))
		_peak(img, tx, 3, 8, 3, Color("#3f5fa8"), Color("#2f4a88"))
		img.fill_rect(Rect2i(tx, 1, 1, 3), Color("#4a2c16"))
		img.fill_rect(Rect2i(tx + 1, 1, 3, 1), Color("#d0263e"))
	img.fill_rect(Rect2i(cx - 3, 5, 6, 8), stone.lightened(0.05))
	_peak(img, cx, 0, 5, 4, Color("#3f5fa8"), Color("#2f4a88"))
	img.fill_rect(Rect2i(cx - 2, 17, 4, 5), Color("#4a2c16"))
	for k in 3:
		img.fill_rect(Rect2i(cx - 6 + k * 5, 15, 1, 2), Color("#ffd479") if night else Color("#2a2a36"))
	for y in range(22, H):
		var x := cx + int(sin((y - 22) * 0.5) * (y - 22) * 0.6)
		img.fill_rect(Rect2i(x - 1, y, 3, 1), Color("#c9a870"))


## A knight on a white horse and a red dragon breathing fire, as on a page of
## a book of hours.
static func _dragon(img: Image, r: Callable) -> void:
	img.fill(Color("#2a4fa0"))
	for k in 14:
		_dot(img, int(r.call(10 + k) * W), int(r.call(30 + k) * 20), Color("#f0c46a"))
	img.fill_rect(Rect2i(0, 28, W, H - 28), Color("#3e7a3a"))
	img.fill_rect(Rect2i(0, 0, W, 1), Color("#f0c46a"))
	img.fill_rect(Rect2i(0, H - 1, W, 1), Color("#f0c46a"))
	img.fill_rect(Rect2i(0, 0, 1, H), Color("#f0c46a"))
	img.fill_rect(Rect2i(W - 1, 0, 1, H), Color("#f0c46a"))
	# The dragon, right: body, neck, head, wings, tail.
	var red := Color("#c0263a")
	img.fill_rect(Rect2i(30, 20, 12, 7), red)
	img.fill_rect(Rect2i(28, 14, 4, 7), red)
	img.fill_rect(Rect2i(24, 13, 6, 3), red)
	_dot(img, 25, 13, Color("#f0c46a"))
	_peak(img, 36, 10, 20, 5, red.lightened(0.15), red.darkened(0.2))
	for x in range(42, 47):
		img.fill_rect(Rect2i(x, 24 - (x - 42), 1, 2), red)
	for k in 4:
		img.fill_rect(Rect2i(31 + k * 3, 27, 1, 2), red.darkened(0.3))
	# Its fire.
	for x in range(14, 24):
		var spread := (24 - x) / 3
		img.fill_rect(Rect2i(x, 14 - spread / 2, 1, spread + 1), Color("#ff9a2a") if x % 2 else Color("#ffd23f"))
	# The knight on horseback, left, the lance levelled.
	var white := Color("#f0ece0")
	img.fill_rect(Rect2i(4, 20, 9, 5), white)
	img.fill_rect(Rect2i(11, 17, 3, 5), white)
	for k in 4:
		img.fill_rect(Rect2i(4 + k * 3, 25, 1, 4), white.darkened(0.2))
	img.fill_rect(Rect2i(6, 14, 4, 6), Color("#c9ced8"))
	img.fill_rect(Rect2i(6, 11, 4, 3), Color("#c9ced8"))
	img.fill_rect(Rect2i(5, 17, 3, 4), Color("#d0263e"))
	img.fill_rect(Rect2i(9, 15, 12, 1), Color("#8a5a32"))


## A tapestry: a millefleur field, a border, and a lion rampant in the middle.
static func _tapestry(img: Image, r: Callable) -> void:
	var field := Color("#6a1f2e") if r.call(2) > 0.5 else Color("#1f3a5a")
	img.fill(field)
	for k in 40:
		var c: Color = [Color("#f0c46a"), Color("#e8e0d0"), Color("#5a9a5a"), Color("#d86a7a")][k % 4]
		_dot(img, int(r.call(10 + k) * W), int(r.call(60 + k) * H), c)
	for x in W:
		for y in [0, 1, H - 2, H - 1]:
			img.set_pixel(x, y, Color("#c9a060") if (x / 2) % 2 == 0 else Color("#8a6a30"))
	for y in H:
		for x in [0, 1, W - 2, W - 1]:
			img.set_pixel(x, y, Color("#c9a060") if (y / 2) % 2 == 0 else Color("#8a6a30"))
	# The lion, gold: body, head and mane, raised paws, tail.
	var gold := Color("#f0c46a")
	img.fill_rect(Rect2i(20, 14, 8, 10), gold)
	_disc(img, 25, 10, 4, gold.darkened(0.15))
	_disc(img, 26, 10, 2, gold)
	img.fill_rect(Rect2i(28, 12, 4, 2), gold)
	img.fill_rect(Rect2i(28, 16, 4, 2), gold)
	img.fill_rect(Rect2i(20, 24, 2, 6), gold)
	img.fill_rect(Rect2i(26, 24, 2, 6), gold)
	for y in range(14, 22):
		_dot(img, 18 - (y - 14) / 3, y, gold)
	_dot(img, 27, 9, Color("#1c1b22"))
