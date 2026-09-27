extends MinigameView
## The balance (BalanceGame): the thief itself, in its colours and its
## statue pose on its pedestal, swaying as it sways in the museum.

var _statue: Figure


func framing() -> Dictionary:
	# Straight on: the sway reads left and right.
	return {"span": 1.95, "look": 0.9, "angle": Vector3(-8, 0, 0)}


func build() -> void:
	# The pedestal: a low stone block on a walnut base.
	box(Vector3(0.62, 0.08, 0.42), WOOD, Vector3(0, 0.04, 0))
	box(Vector3(0.5, 0.3, 0.34), CREAM, Vector3(0, 0.23, 0))
	_statue = Figure.make("thief", colour, colour.darkened(0.5))
	_statue.set_rim(0.2)
	add_child(_statue)


func pose(dt: float) -> void:
	# Facing the camera, as it does on the museum's pedestals.
	_statue.set_state(Vector3(0, 0.38, 0), PI / 2, 0.0, dt, "statue")
	_statue.set_lean((game as BalanceGame).lean)
