class_name MgPose
extends Minigame
## Holding a pose in a diorama, among the figures: keep your balance. A
## needle sways — pushed about by a steady drift and sudden wobbles — and
## you keep it in the middle with left and right. Out of the safe zone too
## long and you wobble, and the guards hear something move where nothing
## should. Harder with a guard near or the room lit (pressure). It lasts as
## long as you hold it.

## How loud a wobble is (Hearing's tiles).
const WOBBLE := 7.0
## The thief posing as a statue: stone grey, so it reads on the dark box.
const STATUE := Color("#b8b4c4")
## How far the needle may go (-1..1) and for how long out of the zone.
const ZONE := 0.45
const GRACE_S := 0.55
## Your push, and the world's.
const PUSH := 2.4
const DRIFT := 0.35
const GUST := 1.3

var needle := 0.0
var _vel := 0.0
var _drift := 0.0
var _out := 0.0
var _next_gust := 1.0


func _init() -> void:
	super()
	kind = "endurance"


func _begin() -> void:
	_drift = rng.randf_range(-1.0, 1.0)


func title() -> String:
	return Text.t("MG_POSE")


func help() -> String:
	return Text.t("MG_POSE_HELP")


func zone() -> float:
	return ZONE * (1.0 - pressure * 0.4)


func _step(input: Dictionary, dt: float) -> void:
	var hold: Vector2 = input.get("hold", Vector2.ZERO)
	# The drift wanders, and gusts shove the needle now and then.
	_drift = clampf(_drift + rng.randf_range(-1.0, 1.0) * dt * 2.0, -1.0, 1.0)
	_next_gust -= dt
	if _next_gust <= 0.0:
		_vel += rng.randf_range(-1.0, 1.0) * GUST * (1.0 + pressure)
		_next_gust = rng.randf_range(0.7, 1.8) / (1.0 + pressure)
	_vel += (_drift * DRIFT * (1.0 + pressure * 1.5) + hold.x * PUSH) * dt
	_vel *= pow(0.25, dt)
	needle = clampf(needle + _vel * dt, -1.0, 1.0)
	if absf(needle) > zone():
		_out += dt
		feel.emit(0.3)
		if _out >= GRACE_S:
			_fail(WOBBLE)
	else:
		_out = maxf(0.0, _out - dt * 2.0)


func _draw_game(area: Rect2) -> void:
	var base := Vector2(area.get_center().x, area.end.y - 6)
	# The figure on its plinth, leaning as the needle does.
	var lean := needle * 0.5
	draw_rect(Rect2(base + Vector2(-26, -8), Vector2(52, 8)), Color("#4a3a52"))
	var hip := base + Vector2(0, -34)
	var top := hip + Vector2(sin(lean), -cos(lean)) * 34
	draw_line(base + Vector2(-8, -8), hip, STATUE, 6.0)
	draw_line(base + Vector2(8, -8), hip, STATUE, 6.0)
	draw_line(hip, top, STATUE, 10.0)
	draw_circle(top + Vector2(sin(lean), -cos(lean)) * 12, 12, STATUE)
	# One arm out, as a statue's.
	draw_line(hip + (top - hip) * 0.8, hip + (top - hip) * 0.8 + Vector2(cos(lean), sin(lean)) * 26, STATUE, 5.0)
	# The gauge: the safe zone lit, the needle, red while it is out.
	var g := Rect2(Vector2(area.position.x + 6, area.position.y + 2), Vector2(area.size.x - 12, 12))
	draw_rect(g, Color(1, 1, 1, 0.1))
	var z := zone()
	draw_rect(Rect2(Vector2(g.get_center().x - z * g.size.x / 2.0, g.position.y), Vector2(z * g.size.x, g.size.y)), Color(GOOD, 0.3))
	var nx := g.get_center().x + needle * g.size.x / 2.0
	draw_rect(Rect2(Vector2(nx - 2, g.position.y - 3), Vector2(4, g.size.y + 6)), BAD if absf(needle) > z else GOLD)
	if over and not left:
		draw_string(FONT, top + Vector2(-30, -30), "¡UY!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BAD)
