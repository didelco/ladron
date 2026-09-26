class_name MgGrate
extends Minigame
## The grate: four screws to undo, one after the other. Turn the
## screwdriver left, right, left, right — each change of hand is a bit of a
## turn; the same side twice turns nothing. You cannot fail. With the guards
## on alert your hand shakes and now and then the screwdriver slips a bit
## back.

## Changes of hand to undo one screw.
const TURNS := 6

var screws := 4
var done := 0
var turned := 0
var _last := 0
var _spin := 0.0


func _init(count := 4) -> void:
	super()
	kind = "action"
	screws = clampi(count, 1, 4)


func title() -> String:
	return Text.t("MG_GRATE")


func help() -> String:
	return Text.t("MG_GRATE_HELP")


func _step(input: Dictionary, dt: float) -> void:
	var tap: Vector2i = input.get("tap", Vector2i.ZERO)
	_spin = maxf(0.0, _spin - dt * 4.0)
	if tap.x == 0 or tap.x == _last:
		return
	_last = tap.x
	# Shaking hands: a slip now and then.
	if pressure > 0.0 and rng.randf() < pressure * 0.2:
		turned = maxi(0, turned - 1)
		_slip()
		return
	turned += 1
	_spin = 1.0
	feel.emit(0.15)
	if turned >= TURNS:
		turned = 0
		done += 1
		_blink(GOOD)
		feel.emit(0.5)
	progress = (done + float(turned) / TURNS) / screws
	if done >= screws:
		_done()


func _draw_game(area: Rect2) -> void:
	# The grate: bars, and a screw in each corner (the undone ones out).
	var g := Rect2(area.position + Vector2(area.size.x * 0.15, 2), Vector2(area.size.x * 0.7, area.size.y - 4))
	draw_rect(g, Color("#2a2433"))
	for k in 7:
		var x := g.position.x + g.size.x * (k + 1) / 8.0
		draw_line(Vector2(x, g.position.y + 8), Vector2(x, g.end.y - 8), Color("#8a8f9c"), 3.0)
	draw_rect(g, Color("#8a8f9c"), false, 3.0)
	var corners := [g.position + Vector2(10, 10), Vector2(g.end.x - 10, g.position.y + 10), Vector2(g.position.x + 10, g.end.y - 10), g.end - Vector2(10, 10)]
	for i in screws:
		var c: Vector2 = corners[i]
		if i < done:
			draw_circle(c, 5, Color(0, 0, 0, 0.6))
			continue
		draw_circle(c, 7, GOLD if i == done else CREAM)
		var a := (turned * TAU / TURNS if i == done else 0.0) + (_spin * 0.4 if i == done else 0.0)
		draw_line(c + Vector2(cos(a), sin(a)) * 6, c - Vector2(cos(a), sin(a)) * 6, INK, 2.0)
	# Which side next: an arrow under the grate.
	var arrow := "<" if _last > 0 else ">"
	draw_string(FONT, Vector2(area.get_center().x - 6, area.end.y + 4), arrow, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, GOLD)
