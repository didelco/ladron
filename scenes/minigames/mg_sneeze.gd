class_name MgSneeze
extends Minigame
## Hiding somewhere dusty: don't sneeze. The tickle in your nose creeps up,
## in fits, faster the longer you have been in there (the dust builds up).
## Hold the action button to pinch your nose and it goes down — but you are
## not breathing: let go before your breath runs out. Sneeze, or gasp for
## air, and the guards hear it. It lasts as long as you stay hidden.
##
## pressure: how dusty the place is to start with.

## How loud a sneeze and a gasp are (Hearing's tiles): a sneeze carries.
const SNEEZE := 11.0
const GASP := 5.0
## The tickle: a slow creep, fits on top, and the dust making both worse.
const CREEP := 0.07
const DUST := 0.012
const FIT := 0.35
## Pinching: how fast the tickle goes down, and the breath you have.
const PINCH := 0.55
const BREATH_S := 2.4

var tickle := 0.0
var breath := 1.0
var _fit := 0.0
var _next_fit := 1.5


func _init() -> void:
	super()
	kind = "endurance"


func _begin() -> void:
	_next_fit = rng.randf_range(0.8, 2.0)


func title() -> String:
	return Text.t("MG_SNEEZE")


func help() -> String:
	return Text.t("MG_SNEEZE_HELP")


func dust() -> float:
	return pressure + elapsed * DUST


func _step(input: Dictionary, dt: float) -> void:
	_next_fit -= dt
	if _next_fit <= 0.0:
		_fit = rng.randf_range(0.4, 0.9)
		_next_fit = rng.randf_range(1.0, 2.6) / (1.0 + dust())
	var rise := CREEP * (1.0 + dust() * 2.0)
	if _fit > 0.0:
		rise += FIT * (1.0 + dust())
		_fit -= dt
	if input.get("act_held", false):
		tickle = maxf(0.0, tickle - PINCH * dt)
		breath = maxf(0.0, breath - dt / BREATH_S)
		if breath <= 0.0:
			_fail(GASP)
			return
	else:
		tickle = minf(1.0, tickle + rise * dt)
		breath = minf(1.0, breath + dt / (BREATH_S * 0.8))
	if tickle > 0.7:
		feel.emit((tickle - 0.7) / 0.3 * 0.5)
	if tickle >= 1.0:
		_fail(SNEEZE)


func _draw_game(area: Rect2) -> void:
	# A face, its nose going red and its eyes squeezing as the tickle grows.
	var c := Vector2(area.position.x + 50, area.get_center().y)
	# The ninja's hood, and the slit its eyes look out of.
	draw_circle(c, 37, Color("#5a5a66"))
	draw_circle(c, 35, Color("#2a2a33"))
	draw_rect(Rect2(c + Vector2(-26, -18), Vector2(52, 20)), Color("#e2262f"))
	var squeeze := clampf((tickle - 0.4) / 0.6, 0.0, 1.0)
	for s in [-1, 1]:
		var e := c + Vector2(s * 13, -8)
		draw_rect(Rect2(e - Vector2(7, 7 * (1.0 - squeeze * 0.8)), Vector2(14, 14 * (1.0 - squeeze * 0.8))), CREAM)
	var nose := Color("#f7b98e").lerp(Color("#ff4d4d"), tickle)
	draw_circle(c + Vector2(0, 8), 8 + tickle * 3, nose)
	if over and not left:
		draw_string(FONT, c + Vector2(-34, -44), "¡ACHÍS!" if breath > 0.0 else "¡AAAH!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, BAD)
	# Right: the tickle and the breath, as two bars.
	var x := area.position.x + 110
	for k in 2:
		var v := tickle if k == 0 else breath
		var col := (BAD.lerp(GOLD, 1.0 - tickle) if k == 0 else Color("#7ad6ff"))
		var bar := Rect2(Vector2(x + k * 50, area.position.y + 14), Vector2(18, area.size.y - 22))
		draw_rect(bar, Color(1, 1, 1, 0.1))
		draw_rect(Rect2(Vector2(bar.position.x, bar.end.y - bar.size.y * v), Vector2(bar.size.x, bar.size.y * v)), col)
		draw_rect(bar, DIM, false, 1.0)
		draw_string(FONT, Vector2(bar.position.x - 10, area.position.y + 8), Text.t("MG_SNEEZE_TICKLE" if k == 0 else "MG_SNEEZE_BREATH"), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, DIM)
