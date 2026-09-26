class_name Minigame
extends Control
## A minigame: a little framed box beside a thief, as in Among Us, played
## while the museum carries on around it (nothing pauses). Each one is its
## own element (the files next to this one); the game opens one where it
## needs it, feeds it the thief's controls every frame and reads what came
## of it.
##
## Two kinds:
##   "action"    (the safe, the lock, the alarm's wires, the grate): you do
##               not fail, you take as long as your hands let you — and the
##               longer, the longer you stand there exposed. progress 0..1;
##               done when it reaches 1.
##   "endurance" (not sneezing in a hiding place, holding a pose): you can
##               fail, and failing makes a noise (the `noise` signal) — it
##               does not get you caught there and then, it brings a guard.
##               It lasts as long as you stay; failing ends it.
##
## pressure (0..1) is what makes it harder, set by whoever opens it: the
## alert for the action ones (shaking hands), the guard's nearness and the
## light for the pose, the dust for the sneeze (which also builds on its own).
##
## Controls, for a pad or a few keys (a shared keyboard has no mouse): the
## four directions, `act` (E, or X on the pad) and `leave` (C, or A/B).
## feed() takes them as {"hold": Vector2, "tap": Vector2i, "act": bool
## (pressed this frame), "act_held": bool, "leave": bool}.

## Done: ok for an action one finished, not ok for an endurance one failed
## (or either left before the end, with ok false and `left` true).
signal finished(ok: bool)
## A slip heard by the guards: how far it carries (Hearing's tiles).
signal noise(loudness: float)
## Something to feel in the hands (a pad's rumble): 0..1.
signal feel(strength: float)

## The box's size on screen.
const SIZE := Vector2(236, 176)
const PAD := 10.0
const FONT := preload("res://assets/fonts/PressStart2P-Regular.ttf")
const CREAM := Color("#f1dfbd")
const INK := Color("#1a120c")
const DIM := Color("#9aa0c8")
const GOOD := Color("#4ade80")
const BAD := Color("#ff3d6e")
const GOLD := Color("#ffe066")
const BACK := Color("#140d18", 0.94)

var kind := "action"
var pressure := 0.0
## the player's colour: the frame
var colour := Color("#2ec4a6")
var progress := 0.0
var elapsed := 0.0
var over := false
var left := false
## a shake of the box, after a slip or a wrong move (seconds left)
var _shake := 0.0
var _flash := 0.0
var _flash_colour := GOOD
var rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Start it: a seed, so a test can play the same one twice.
func setup(seed: int, how_hard := 0.0) -> Minigame:
	rng.seed = seed
	pressure = how_hard
	_begin()
	return self


func _begin() -> void:
	pass


## Its name, in the box's title.
func title() -> String:
	return ""


## The controls, on the box's bottom line.
func help() -> String:
	return ""


## One frame of it.
func feed(input: Dictionary, dt: float) -> void:
	if over:
		return
	elapsed += dt
	_shake = maxf(0.0, _shake - dt)
	_flash = maxf(0.0, _flash - dt)
	if input.get("leave", false):
		over = true
		left = true
		finished.emit(false)
		return
	_step(input, dt)
	queue_redraw()


func _step(_input: Dictionary, _dt: float) -> void:
	pass


## An action one done.
func _done() -> void:
	progress = 1.0
	over = true
	_blink(GOOD)
	finished.emit(true)


## An endurance one failed, with its noise.
func _fail(loudness: float) -> void:
	over = true
	_blink(BAD)
	_shake = 0.4
	noise.emit(loudness)
	feel.emit(1.0)
	finished.emit(false)


## A wrong move in an action one: no failing, just a moment lost.
func _slip() -> void:
	_shake = 0.25
	_blink(BAD)
	feel.emit(0.4)


func _blink(c: Color) -> void:
	_flash = 0.25
	_flash_colour = c


# --- Drawing ------------------------------------------------------------------------

func _draw() -> void:
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(sin(elapsed * 90.0), cos(elapsed * 70.0)) * 4.0 * (_shake / 0.4)
	var box := Rect2(off, SIZE)
	var st := StyleBoxFlat.new()
	st.bg_color = BACK
	st.border_color = _flash_colour if _flash > 0.0 else colour
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.shadow_color = Color(0, 0, 0, 0.55)
	st.shadow_size = 8
	draw_style_box(st, box)
	draw_string(FONT, box.position + Vector2(PAD, PAD + 9), title(), HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - PAD * 2, 9, GOLD)
	draw_string(FONT, box.position + Vector2(PAD, SIZE.y - PAD + 1), help(), HORIZONTAL_ALIGNMENT_LEFT, SIZE.x - PAD * 2, 6, DIM)
	if kind == "action":
		# How far along, as a thin bar under the title.
		var bar := Rect2(box.position + Vector2(PAD, PAD + 16), Vector2(SIZE.x - PAD * 2, 4))
		draw_rect(bar, Color(1, 1, 1, 0.12))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * progress, bar.size.y)), GOOD)
	_draw_game(Rect2(box.position + Vector2(PAD, PAD + 26), Vector2(SIZE.x - PAD * 2, SIZE.y - PAD * 2 - 38)))


## The game itself, in the middle of the box.
func _draw_game(_area: Rect2) -> void:
	pass


## Where to put the box beside a thief at screen point `at`: up and to its
## right, or wherever it fits, never over the thief itself.
static func place(box: Control, at: Vector2, screen: Vector2) -> void:
	var gap := Vector2(46, 20)
	var pos := at + Vector2(gap.x, -SIZE.y - gap.y)
	if pos.x + SIZE.x > screen.x - 8:
		pos.x = at.x - gap.x - SIZE.x
	if pos.y < 8:
		pos.y = at.y + gap.y + 24
	pos.x = clampf(pos.x, 8, screen.x - SIZE.x - 8)
	pos.y = clampf(pos.y, 8, screen.y - SIZE.y - 8)
	box.position = pos
