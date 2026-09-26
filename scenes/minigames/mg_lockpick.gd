class_name MgLockpick
extends Minigame
## The lock: a row of pins, one at a time. Hold the action button and the
## pick pushes the pin up; let go with it in the shear line (the lit band)
## and it sets, then on to the next; let go anywhere else and it drops back
## down. You cannot fail. With the guards on alert your hand shakes: the pin
## will not rise smoothly, and the band is narrower.

## How fast a pin rises, held (of its travel, per second).
const RISE := 0.75
const BAND := 0.2

var pins := 4
var done := 0
var height := 0.0
var bands: Array[float] = []


func _init(count := 4) -> void:
	super()
	kind = "action"
	pins = clampi(count, 2, 6)


func _begin() -> void:
	bands.clear()
	for i in pins:
		bands.append(rng.randf_range(0.35, 0.8))


func title() -> String:
	return Text.t("MG_LOCK")


func help() -> String:
	return Text.t("MG_LOCK_HELP")


func band() -> float:
	return BAND * (1.0 - pressure * 0.45)


func _step(input: Dictionary, dt: float) -> void:
	if input.get("act_held", false):
		var shake := sin(elapsed * 23.0) * 0.9 * pressure
		height = clampf(height + (RISE + shake) * dt, 0.0, 1.0)
		if height >= 1.0:
			# Pushed too far: it jams at the top and drops.
			height = 0.0
			_slip()
	elif height > 0.0:
		if absf(height - bands[done]) <= band() / 2.0:
			done += 1
			feel.emit(0.6)
			_blink(GOOD)
			progress = float(done) / pins
			height = 0.0
			if done >= pins:
				_done()
		else:
			height = 0.0
			_slip()


func _draw_game(area: Rect2) -> void:
	var w := area.size.x / pins
	for i in pins:
		var x := area.position.x + w * (i + 0.5)
		var top := area.position.y + 4
		var bottom := area.end.y - 18
		var span := bottom - top
		# The chamber, and its shear line.
		draw_rect(Rect2(Vector2(x - 9, top), Vector2(18, span)), Color("#2a2433"))
		var b := bands[i]
		var bh := band() * span
		var by := bottom - b * span - bh / 2.0
		draw_rect(Rect2(Vector2(x - 11, by), Vector2(22, bh)), Color(GOLD, 0.35 if i == done else 0.12))
		# The pin: set ones sit on the line; the current one where it is pushed.
		var h := b if i < done else (height if i == done else 0.0)
		var py := bottom - h * span
		draw_rect(Rect2(Vector2(x - 6, py - 22), Vector2(12, 22)), GOOD if i < done else (CREAM if i == done else DIM))
		draw_rect(Rect2(Vector2(x - 6, py - 22), Vector2(12, 22)), INK, false, 1.0)
		# The pick under the pin being worked.
		if i == done:
			draw_line(Vector2(area.position.x, bottom + 10), Vector2(x, py + 2), Color("#c9ced8"), 3.0)
