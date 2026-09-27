class_name ArcadeGame
extends Minigame
## The modern gallery's arcade machine (Arcades): a game of pong against the
## machine, up and down to move your paddle. It is a joke: there is nothing
## to win, it never ends, and you only leave it by letting go — meanwhile
## you stand there playing, in plain sight, while the guards walk their
## rounds. The score is only for pride.
##
## The court: x from -HALF_W (your side) to HALF_W (the machine's), y from
## -HALF_H to HALF_H, up positive.

const HALF_W := 0.8
const HALF_H := 0.5
## Where the paddles stand, and half their height.
const PADDLE_X := 0.7
const PADDLE_H := 0.13
## The ball's half size.
const BALL := 0.03
## Speeds, in court units a second: yours, the machine's (slower, so it can
## be beaten), and the ball's, from its serve up to its fastest.
const MY_SPEED := 1.7
const CPU_SPEED := 0.8
const SERVE := 0.8
const FASTEST := 1.8
## Each hit off a paddle, this much faster.
const SPEED_UP := 1.07
## The steepest the ball leaves a paddle, off its very edge, in radians.
const STEEPEST := 1.0
## Where on its paddle the machine means to take the ball, anywhere up to
## this many half paddles from its middle: past one and a bit it misses,
## now and then.
const SLOPPY := 1.4
## After a point, the ball waits this long in the middle.
const PAUSE_S := 0.7

var me := 0.0
var cpu := 0.0
var ball := Vector2.ZERO
var velocity := Vector2.ZERO
## points: yours and the machine's
var mine := 0
var theirs := 0
## seconds until the next serve
var wait := PAUSE_S
## where the machine means to take the ball, off its paddle's middle
var aim := 0.0


func _setup(_steps: int) -> void:
	_serve(-1 if _rng.randf() < 0.5 else 1)


## Nothing to finish: there is no progress to show.
func progress() -> float:
	return 0.0


## Letting go is the same key as ever, told as what it is.
func let_go() -> String:
	return "GAME_LET_GO_ARCADE"


func _play(input: Dictionary, _press: Dictionary, dt: float) -> String:
	me = clampf(me + push_of(input).y * -MY_SPEED * dt, -HALF_H + PADDLE_H, HALF_H - PADDLE_H)
	# The machine goes after the ball when it comes its way, else back to the
	# middle, never quicker than CPU_SPEED.
	var want := ball.y - aim if velocity.x > 0.0 else 0.0
	cpu = clampf(cpu + clampf(want - cpu, -CPU_SPEED * dt, CPU_SPEED * dt), -HALF_H + PADDLE_H, HALF_H - PADDLE_H)
	if wait > 0.0:
		wait -= dt
		return ""
	ball += velocity * dt
	# Off the top and the bottom.
	if absf(ball.y) > HALF_H - BALL:
		ball.y = signf(ball.y) * (HALF_H - BALL)
		velocity.y = -velocity.y
		events.append("wall")
	# Off a paddle, steeper the further from its middle it hits.
	if velocity.x < 0.0 and _hits(-PADDLE_X, me):
		_bounce(me, 1)
	elif velocity.x > 0.0 and _hits(PADDLE_X, cpu):
		_bounce(cpu, -1)
	# Past a paddle: a point, and a serve to whoever lost it.
	if ball.x < -HALF_W:
		theirs += 1
		events.append("miss")
		_serve(-1)
	elif ball.x > HALF_W:
		mine += 1
		events.append("score")
		_serve(1)
	return ""


func _hits(x: float, paddle: float) -> bool:
	return absf(ball.x - x) <= BALL + 0.02 and absf(ball.y - paddle) <= PADDLE_H + BALL


## Back the other way (way: +1 right, -1 left), a little faster.
func _bounce(paddle: float, way: int) -> void:
	var speed := minf(velocity.length() * SPEED_UP, FASTEST)
	var angle := clampf((ball.y - paddle) / PADDLE_H, -1.0, 1.0) * STEEPEST
	velocity = Vector2(way * cos(angle), sin(angle)) * speed
	aim = _rng.randf_range(-SLOPPY, SLOPPY) * PADDLE_H
	ball.x = (-PADDLE_X if way > 0 else PADDLE_X) + way * (BALL + 0.021)
	events.append("bounce")


## The ball to the middle, to set off towards `way` (-1 you, +1 the machine)
## once the pause is over, a little up or down.
func _serve(way: int) -> void:
	ball = Vector2.ZERO
	var angle := _rng.randf_range(-0.45, 0.45)
	velocity = Vector2(way * cos(angle), sin(angle)) * SERVE
	aim = _rng.randf_range(-SLOPPY, SLOPPY) * PADDLE_H
	wait = PAUSE_S
