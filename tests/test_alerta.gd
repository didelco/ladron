extends SceneTree
## La alerta de los guardias baja sola si el ladron no vuelve a dar señales,
## y los guardias no se la pasan unos a otros en bucle.
## godot --headless --script tests/test_alerta.gd

const Support := preload("res://tests/support.gd")
var qa := Support.new("  ")
var clock := 1000.0
const DT := 1.0 / 60
## Tope para que todos vuelvan a la calma tras perder al ladron:
## persecucion (!!!) + alerta (!!) + pista (!), con margen.
const TOPE_S := 60.0 + 30.0 + 10.0 + 20.0


func check(ok: bool, what: String) -> void:
	qa.check(ok, what)


func open_room() -> void:
	Museum.regenerate(1, "small", "rect")
	var w := Museum.w
	var h := Museum.h
	for y in h:
		for x in w:
			Museum.grid[y * w + x] = Tiles.WALL if (x == 0 or y == 0 or x == w - 1 or y == h - 1) else Tiles.FLOOR


## Two guards held in place, facing each other, just within warning range.
func pair() -> Array[Guard]:
	open_room()
	var gs := Sim.new_guards(2)
	gs[0].x = 5.5
	gs[0].y = 5.5
	gs[0].dir = 0.0
	gs[1].x = 6.7
	gs[1].y = 5.5
	gs[1].dir = PI
	for g in gs:
		g.path.clear()
		g.post = Vector2i(-1, -1)
	return gs


## Runs the guards for this many seconds with nobody about. Returns the
## seconds until every guard is calm (suspicion 0), or -1 if never.
func run(gs: Array[Guard], seconds: float, thieves: Array[Thief] = []) -> float:
	var start := clock
	var calm_at := -1.0
	for f in int(seconds * 60):
		clock += 1000.0 * DT
		for g in gs:
			Sim.step_guard(g, thieves, [] as Array[SoundEvent], clock, DT)
		Sim.call_for_backup({}, gs, clock)
		Sim.warn_partners(gs, clock)
		# Held where they are (facing each other) so they keep seeing each other.
		gs[0].x = 5.5
		gs[0].y = 5.5
		gs[0].dir = 0.0
		gs[1].x = 6.7
		gs[1].y = 5.5
		gs[1].dir = PI
		var all_calm := true
		for g in gs:
			if g.suspicion != 0 or g.alert:
				all_calm = false
		if all_calm and thieves.is_empty():
			calm_at = (clock - start) / 1000.0
			break
	return calm_at


func _init() -> void:
	print("Alerta que baja")
	# One guard sees the thief for a second, then the thief is gone.
	var gs := pair()
	var thief := Sim.new_thief()
	thief.x = 6.5
	thief.y = 5.5
	var seen: Array[Thief] = [thief]
	for f in 60:
		clock += 1000.0 * DT
		Sim.step_guard(gs[0], seen, [] as Array[SoundEvent], clock, DT)
	check(gs[0].suspicion == 3, "lo ve: !!! (%d)" % gs[0].suspicion)
	var t := run(gs, 400.0)
	check(t >= 0.0 and t <= TOPE_S, "tras perderlo, todos vuelven a la calma en %.0f s (tope %.0f)" % [t, TOPE_S])

	print("Alerta sin pista no se contagia en bucle")
	gs = pair()
	gs[0].suspicion = 2
	gs[0].alert = true
	gs[0].suspicion_at = clock
	t = run(gs, 400.0)
	check(t >= 0.0 and t <= 30.0 + 10.0 + 20.0, "!! sin ladron ni pista: calma en %.0f s (tope 60)" % t)

	print("Alerta para siempre (avisada) tambien baja")
	gs = pair()
	gs[1].suspicion = 2
	gs[1].alert = true
	gs[1].calm_in = INF
	gs[1].suspicion_at = clock
	t = run(gs, 400.0)
	check(t >= 0.0 and t <= 60.0, "!! por seguro sin ladron: calma en %.0f s (tope 60)" % t)

	quit(qa.summary())
