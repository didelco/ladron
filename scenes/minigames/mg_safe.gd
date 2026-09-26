class_name MgSafe
extends Minigame
## The safe: a dial with forty numbers and a combination of one to three.
## Turn it (left and right: a tap is one number, held it runs), listening:
## the nearer the dial to the number, the louder the tumbler's tick in your
## ear (and in the pad); on it, a sharp click. Press there and that number
## is in; press anywhere else and the dial jumps and you lose a moment. You
## cannot fail — you just take longer, standing there. With the guards on
## alert your hands shake: the dial will not sit still.

const NUMBERS := 40
## Numbers a second, held down: slow at first, faster the longer.
const TURN_SLOW := 6.0
const TURN_FAST := 22.0
const ACCEL_S := 0.7
## Close enough to press: within this much of the number.
const ON := 0.55
## Heard from this far off.
const HEAR := 4.0

var combo: Array[int] = []
var got := 0
var dial := 0.0
var _held := 0.0
var _wobble := 0.0
var _jam := 0.0


## count: how many numbers (1-3); more is a harder safe.
func _init(count := 3) -> void:
	super()
	kind = "action"
	combo.resize(clampi(count, 1, 3))


func _begin() -> void:
	dial = float(rng.randi_range(0, NUMBERS - 1))
	for i in combo.size():
		# Never right where the dial is, nor the one before.
		var n := rng.randi_range(0, NUMBERS - 1)
		while absf(_diff(n, dial if i == 0 else float(combo[i - 1]))) < 8:
			n = rng.randi_range(0, NUMBERS - 1)
		combo[i] = n


func title() -> String:
	return Text.t("MG_SAFE")


func help() -> String:
	return Text.t("MG_SAFE_HELP")


## The shortest way round from a to b, in numbers (-20..20).
static func _diff(a: float, b: float) -> float:
	return wrapf(a - b, -NUMBERS / 2.0, NUMBERS / 2.0)


## Where the dial reads now, shaking hands and all.
func reading() -> float:
	return wrapf(dial + _wobble, 0.0, NUMBERS)


func _step(input: Dictionary, dt: float) -> void:
	if _jam > 0.0:
		_jam -= dt
		return
	var tap: Vector2i = input.get("tap", Vector2i.ZERO)
	var hold: Vector2 = input.get("hold", Vector2.ZERO)
	if tap.x != 0:
		dial = wrapf(dial + tap.x, 0.0, NUMBERS)
		_held = 0.0
	elif hold.x != 0.0:
		_held += dt
		var speed := lerpf(TURN_SLOW, TURN_FAST, clampf((_held - 0.15) / ACCEL_S, 0.0, 1.0))
		if _held > 0.15:
			dial = wrapf(dial + signf(hold.x) * speed * dt, 0.0, NUMBERS)
	else:
		_held = 0.0
		# Let go, it settles on the nearest number.
		dial = wrapf(lerpf(dial, roundf(dial), minf(1.0, dt * 12.0)), 0.0, NUMBERS)
	# Shaking hands: a drift that will not keep still.
	_wobble = sin(elapsed * 7.3) * 0.6 * pressure + sin(elapsed * 12.1 + 1.3) * 0.35 * pressure
	var near := _closeness()
	if near > 0.0:
		feel.emit(near * near * 0.35)
	if input.get("act", false):
		if absf(_diff(reading(), combo[got])) <= ON:
			got += 1
			feel.emit(0.8)
			_blink(GOOD)
			progress = float(got) / combo.size()
			if got >= combo.size():
				_done()
		else:
			# The dial jumps off: a moment to steady it again.
			_slip()
			_jam = 0.35
			dial = wrapf(dial + rng.randf_range(-3.0, 3.0), 0.0, NUMBERS)


## 0 far off .. 1 right on the number to find.
func _closeness() -> float:
	if got >= combo.size():
		return 0.0
	return clampf(1.0 - absf(_diff(reading(), combo[got])) / HEAR, 0.0, 1.0)


func _draw_game(area: Rect2) -> void:
	var c := Vector2(area.position.x + area.size.y / 2.0 + 4, area.get_center().y)
	var r := area.size.y / 2.0 - 2.0
	# The door and the dial.
	draw_circle(c, r + 4, Color("#3a3f4a"))
	draw_circle(c, r, Color("#20242c"))
	for k in NUMBERS:
		var a := TAU * (k - reading()) / NUMBERS - PI / 2.0
		var big := k % 5 == 0
		var from := c + Vector2(cos(a), sin(a)) * (r - (8.0 if big else 4.0))
		draw_line(from, c + Vector2(cos(a), sin(a)) * (r - 1.0), CREAM if big else DIM, 2.0 if big else 1.0)
		if k % 10 == 0:
			var at := c + Vector2(cos(a), sin(a)) * (r - 16.0)
			draw_string(FONT, at + Vector2(-5, 3), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, CREAM)
	draw_circle(c, r * 0.3, Color("#8a8f9c"))
	draw_circle(c, r * 0.22, Color("#5c6370"))
	# The mark it is read against.
	draw_colored_polygon(PackedVector2Array([c + Vector2(-5, -r - 7), c + Vector2(5, -r - 7), c + Vector2(0, -r + 1)]), GOLD)
	# Right of it: the numbers found (stars for the rest), and the stethoscope:
	# rings that grow and quicken as you close in.
	var x := c.x + r + 12
	for i in combo.size():
		var box := Rect2(Vector2(x + i * 24, area.position.y + 4), Vector2(21, 18))
		draw_rect(box, Color(1, 1, 1, 0.08))
		draw_rect(box, GOOD if i < got else (GOLD if i == got else DIM), false, 1.5)
		draw_string(FONT, box.position + Vector2(3, 13), ("%02d" % combo[i]) if i < got else "··", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, GOOD if i < got else CREAM)
	var near := _closeness()
	var ear := Vector2(x + 34, area.end.y - 28)
	draw_circle(ear, 7, CREAM)
	draw_circle(ear, 3, INK)
	for k in 3:
		var phase := fmod(elapsed * (1.0 + near * 5.0) + k / 3.0, 1.0)
		var ring := 8.0 + phase * 26.0
		draw_arc(ear, ring, -0.9, 0.9, 12, Color(GOLD, (1.0 - phase) * near), 2.0)
		draw_arc(ear, ring, PI - 0.9, PI + 0.9, 12, Color(GOLD, (1.0 - phase) * near), 2.0)
	if near > 0.85:
		draw_string(FONT, ear + Vector2(-20, -26), "CLIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, GOLD)
