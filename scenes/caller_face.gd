class_name CallerFace
extends Control
## The face of whoever phones (MapFile.caller.face), drawn in code: there is no
## art for portraits, so each caller is a round face on a coloured sticker,
## told apart by skin and hair, a hat (style "cap", "bun", "tuft", "bald") and
## glasses or a moustache. Drawn in a 100 x 100 square scaled to the control.

const INK := Color("#2a150c")

var face := {}


func _init(look := {}) -> void:
	face = look
	custom_minimum_size = Vector2(150, 150)


func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
	var bg := Color(String(face.get("bg", "#9cc7e8")))
	var skin := Color(String(face.get("skin", "#f1c7a0")))
	var hair := Color(String(face.get("hair", "#4a3426")))
	var style := String(face.get("style", "bald"))
	# the sticker: a rounded square with a white edge
	draw_rect(Rect2(0, 0, 100, 100), Color.WHITE)
	draw_rect(Rect2(3, 3, 94, 94), bg)
	# shoulders (clipped by the sticker: drawn as a wide low ellipse)
	var shirt := bg.darkened(0.35)
	var shoulders := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		shoulders.append(Vector2(50 + cos(a) * 40, 97 + sin(a) * 26))
	draw_colored_polygon(shoulders, shirt)
	draw_rect(Rect2(43, 66, 14, 14), skin.darkened(0.12))
	# hair behind the head
	if style == "curls":
		for i in 7:
			_disc(Vector2(27 + i * 7.7, 26 + 7.0 * absf(i - 3) * 0.6), 9.0, hair)
	if style in ["bun", "tuft", "cap"]:
		_disc(Vector2(50, 46), 28.0, hair)
	if style == "bun":
		_disc(Vector2(50, 15), 9.0, hair)
	# ears and head
	_disc(Vector2(24, 50), 6.0, skin)
	_disc(Vector2(76, 50), 6.0, skin)
	_disc(Vector2(50, 47), 26.0, skin)
	# hat or hair over the forehead
	match style:
		"cap":
			var dome := PackedVector2Array()
			for i in 21:
				var a := PI + PI * i / 20.0
				dome.append(Vector2(50 + cos(a) * 27, 40 + sin(a) * 25))
			draw_colored_polygon(dome, bg.darkened(0.55))
			draw_rect(Rect2(20, 38, 60, 6), bg.darkened(0.7))
			draw_rect(Rect2(50, 38, 38, 5), bg.darkened(0.7))
		"tuft":
			draw_colored_polygon(PackedVector2Array([Vector2(36, 26), Vector2(44, 10), Vector2(50, 24), Vector2(56, 8), Vector2(64, 26)]), hair)
		"bun":
			draw_colored_polygon(PackedVector2Array([Vector2(26, 42), Vector2(32, 26), Vector2(50, 21), Vector2(68, 26), Vector2(74, 42), Vector2(62, 32), Vector2(38, 32)]), hair)
	# eyes
	for x in [40.0, 60.0]:
		_disc(Vector2(x, 49), 4.6, Color.WHITE)
		draw_circle(Vector2(x + 0.8, 50), 2.2, INK)
		draw_line(Vector2(x - 5, 41), Vector2(x + 5, 42 if x < 50.0 else 40), INK, 1.8)
	if bool(face.get("glasses", false)):
		for x in [40.0, 60.0]:
			draw_arc(Vector2(x, 49), 8.0, 0.0, TAU, 24, INK, 2.0)
		draw_line(Vector2(48, 49), Vector2(52, 49), INK, 2.0)
	# nose, moustache, mouth
	draw_circle(Vector2(50, 57), 3.4, skin.darkened(0.18))
	if bool(face.get("moustache", false)):
		draw_colored_polygon(PackedVector2Array([Vector2(50, 61), Vector2(38, 60), Vector2(33, 66), Vector2(42, 65), Vector2(50, 64)]), hair)
		draw_colored_polygon(PackedVector2Array([Vector2(50, 61), Vector2(62, 60), Vector2(67, 66), Vector2(58, 65), Vector2(50, 64)]), hair)
	draw_arc(Vector2(50, 66), 8.0, 0.2 * PI, 0.8 * PI, 12, INK, 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _disc(at: Vector2, r: float, colour: Color) -> void:
	draw_circle(at, r + 1.8, INK)
	draw_circle(at, r, colour)
