extends SceneTree
## Asks the brain service for real decisions and prints them. Needs the
## service running (see README); fails if it cannot be reached.
##   godot --headless --script tests/test_brain.gd

var client: BrainClient
var started := 0.0


func _initialize() -> void:
	Sim.new_map(12345, "medium")
	var guards := Sim.new_guards(3)
	var now := Sim.now_ms()
	# One guard calm, one that heard something, one told by a colleague.
	guards[1].alert = true
	guards[1].calm_in = 8.0
	var m := Guard.Memory.new()
	m.x = Museum.open_tiles[40].x + 0.5
	m.y = Museum.open_tiles[40].y + 0.5
	m.kind = "noise"
	m.at = now - 2000
	guards[1].memory = m
	guards[2].alert = true
	var c := m.copy()
	c.kind = "called"
	c.at = now - 1000
	guards[2].memory = c
	client = BrainClient.new()
	root.add_child(client)
	client.decided.connect(_on_decided.bind(guards))
	client.failed.connect(_on_failed)
	started = Time.get_ticks_msec()
	client.ask.call_deferred(guards, guards, now)


func _on_decided(decisions: Dictionary, ms: int, guards: Array[Guard]) -> void:
	print("Laya respondió en %d ms" % ms)
	for g in guards:
		var d: Decision = decisions[g.id]
		var probs := PackedStringArray()
		for k in d.probabilities:
			probs.append("%s %d%%" % [d.labels.get(k, k), roundi(float(d.probabilities[k]) * 100)])
		print("  %s (%s): %s → %s | ritmo %d%% | %s | cerca %d%%" % [g.name, "alerta" if g.alert else "tranquilo", d.label, Museum.zone_label(d.target.x + 0.5, d.target.y + 0.5), roundi(d.aggression * 100), Mind.LOOK_LABEL[d.look], roundi(d.near * 100)])
		print("      opciones: %s" % ", ".join(probs))
	print("OK: decisiones de Laya leídas")
	quit(0)


func _on_failed(reason: String) -> void:
	printerr("sin Laya: %s" % reason)
	quit(1)


func _process(_dt: float) -> bool:
	return Time.get_ticks_msec() - started > 15000
