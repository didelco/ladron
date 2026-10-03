class_name PhoneIcon
extends Control
## A telephone's handset, drawn in code, shaking and with its little ring
## marks flickering while it rings (PhoneCall).

const RED := Color("#d0263e")
const INK := Color("#2a150c")

var ringing := true
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)


func _process(dt: float) -> void:
	_time += dt
	queue_redraw()


func _draw() -> void:
	var s := minf(size.x, size.y) / 100.0
	var shake := sin(_time * 38.0) * 0.14 if ringing and fmod(_time, 1.4) < 0.9 else 0.0
	draw_set_transform(Vector2(50, 55) * s, shake, Vector2(s, s))
	var c := Vector2.ZERO
	# the handset: an arch with an earpiece and a mouthpiece at its ends
	draw_arc(c, 28.0, PI * 1.12, PI * 1.88, 24, INK, 20.0)
	draw_arc(c, 28.0, PI * 1.12, PI * 1.88, 24, RED, 14.0)
	for a in [PI * 1.12, PI * 1.88]:
		var at := Vector2(cos(a), sin(a)) * 28.0
		draw_circle(at + Vector2(0, 5), 13.0, INK)
		draw_circle(at + Vector2(0, 5), 11.0, RED.darkened(0.15))
	if ringing:
		var on := int(_time * 8.0) % 2 == 0
		for k in 2:
			var r := 42.0 + k * 9.0
			var col := Color(Hud.C.gold, 1.0 if on else 0.35)
			draw_arc(c, r, PI * 1.3, PI * 1.45, 6, col, 3.0)
			draw_arc(c, r, PI * 1.55, PI * 1.7, 6, col, 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
