extends MinigameView
## The arcade machine (ArcadeGame): its screen, face on, in a pop violet
## bezel — black glass, a dashed line down the middle, two glowing paddles
## (yours in your colours) and the ball, and the score in big pips over
## each half.

const BEZEL := Color("#8a4dff")
const SCREEN := Color("#0b0a14")
const PHOSPHOR := Color("#e8fff4")
## The court, drawn a little smaller than the screen.
const K := 0.9
## The most pips a score shows: past it, it starts again.
const PIPS := 9

var _me: MeshInstance3D
var _cpu: MeshInstance3D
var _ball: MeshInstance3D
var _pips: Array = [[], []]


func framing() -> Dictionary:
	return {"span": 1.35, "look": 0.02, "angle": Vector3(-6, 8, 0)}


func build() -> void:
	var w := ArcadeGame.HALF_W * 2.0 * K
	var h := ArcadeGame.HALF_H * 2.0 * K
	box(Vector3(w + 0.22, h + 0.26, 0.1), BEZEL, Vector3(0, 0.02, -0.08))
	box(Vector3(w + 0.06, h + 0.06, 0.04), SCREEN, Vector3(0, 0, -0.02))
	var dim := glowing(PHOSPHOR, 0.6)
	# Down the middle, under the score.
	for i in 8:
		var dash := box(Vector3(0.018, 0.05, 0.01), PHOSPHOR, Vector3(0, (i - 4.5) * h / 9.5, 0.01))
		dash.material_override = dim
	var paddle := Vector3(0.035, ArcadeGame.PADDLE_H * 2.0 * K, 0.02)
	_me = box(paddle, colour, Vector3.ZERO)
	_me.material_override = glowing(colour, 2.2)
	_cpu = box(paddle, PHOSPHOR, Vector3.ZERO)
	_cpu.material_override = glowing(PHOSPHOR, 1.6)
	var b := ArcadeGame.BALL * 2.0 * K
	_ball = box(Vector3(b, b, 0.02), PHOSPHOR, Vector3.ZERO)
	_ball.material_override = glowing(PHOSPHOR, 2.5)
	# The score: a row of pips over each half, from the middle outwards.
	for side in 2:
		var c: Color = colour if side == 0 else PHOSPHOR
		for i in PIPS:
			var pip := box(Vector3(0.028, 0.028, 0.01), c, Vector3((i * 0.042 + 0.06) * (-1 if side == 0 else 1), h * 0.5 - 0.05, 0.01))
			pip.material_override = glowing(c, 1.8)
			_pips[side].append(pip)


func pose(_dt: float) -> void:
	var g := game as ArcadeGame
	_me.position = Vector3(-ArcadeGame.PADDLE_X * K, g.me * K, 0.02)
	_cpu.position = Vector3(ArcadeGame.PADDLE_X * K, g.cpu * K, 0.02)
	_ball.position = Vector3(g.ball.x * K, g.ball.y * K, 0.02)
	# Waiting to serve, the ball blinks in the middle.
	_ball.visible = g.wait <= 0.0 or fmod(t, 0.3) < 0.15
	var scores := [g.mine % (PIPS + 1), g.theirs % (PIPS + 1)]
	for side in 2:
		for i in PIPS:
			_pips[side][i].visible = i < scores[side]
