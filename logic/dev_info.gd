class_name DevInfo
extends RefCounted
## Dev mode: what a guard is made of right now, read from the same functions
## and constants the simulation runs on (Sim.view_of, Sim.pace_of, Hearing.
## state_factor, NightAlert.attention_state, NightAlert.find_chance...), so
## what is shown can never drift from what happens. Read-only: it changes
## nothing. The format is `effective (base ×modifier)`; r = the guard's own
## trait, d = the night's dial (difficulty), the last factor the state's.

## The numbers behind a guard's text, by magnitude.
static func values(g: Guard, now: float) -> Dictionary:
	var dec := g.decision if g.decision else Sim._default_decision(g)
	var view := Sim.view_of(g)
	var pace := Sim.pace_of(g, dec.aggression, g.alert)
	var ear_state := Hearing.state_factor(g)
	var ear_dial := Sim.tuning("hearing")
	var theft := Heist.taken and Sim.feature("case") and not NightAlert.robbed
	var chance := NightAlert.find_chance(g, now) if theft else 0.0
	return {
		"attention": NightAlert.attention(g),
		"attention_trait": g.attention_scale,
		"attention_state": NightAlert.attention_state(g),
		"speed": pace.speed,
		"stride": pace.stride,
		"speed_dial": pace.dial,
		"speed_trait": pace.trait,
		"aggression": dec.aggression,
		"view_range": view.range,
		"view_near": view.near,
		"view_half": view.half,
		"view_trait": g.view_scale,
		"view_dial": Sim.tuning("view"),
		"view_state": float((Sim.VIEW.alert if g.alert else Sim.VIEW.calm).range),
		"hearing": ear_state * ear_dial * g.hearing_scale,
		"hearing_trait": g.hearing_scale,
		"hearing_dial": ear_dial,
		"hearing_state": ear_state,
		"suspicion": g.suspicion,
		"drop_in": Sim.drop_in_s(g, now),
		"theft_chance": chance,
		"theft_closeness": NightAlert.closeness(g, now) if theft else 0.0,
	}


## What it is doing: its errand, post or plan.
static func doing(g: Guard) -> String:
	var dec := g.decision if g.decision else Sim._default_decision(g)
	if g.sees_player:
		return "persigue (ve ladron)"
	match g.errand:
		"lights":
			return "recado: luces"
		"warn":
			return "recado: avisar"
		"door":
			return "vigila la salida"
	if g.knows != "":
		return "saca a un ladron (%s)" % g.knows_kind
	if g.post.x >= 0 and g.suspicion == 0:
		return "puesto (%s)" % (g.watch if g.watch != "" else "barrido")
	if g.sweep > 0.0:
		return "mira alrededor (plan %s)" % dec.plan
	match dec.plan:
		"patrol":
			return "ronda"
		"search", "check_zone":
			return "busca (%s)" % dec.plan
		_:
			return "plan %s" % dec.plan


## How long (s) before the guard's level changes, in words: the seconds left
## to drop a step, "fija" while it is held (chasing, or the night's floor) and
## "-" with nothing to drop from.
static func change_in(g: Guard, now: float) -> String:
	var drop: float = Sim.drop_in_s(g, now)
	if drop != INF:
		return "%.0fs" % drop
	return "fija" if g.suspicion > 0 else "-"


## The big line over a guard's head: what matters at a glance — suspicion,
## attention, pace, and the time left before its level changes.
static func guard_head(g: Guard, now: float) -> String:
	var v := values(g, now)
	return "Sos:%d  Aten:%.1f  Vel:%.1f  T:%s" % [g.suspicion, v.attention, v.speed, change_in(g, now)]


## The small block under it, one magnitude a line: where each number comes from.
static func guard_text(g: Guard, now: float) -> String:
	var v := values(g, now)
	var lines: Array[String] = []
	lines.append("%s: %s" % [g.name, doing(g)])
	var drop: float = v.drop_in
	var sus := "Sosp %d%s%s" % [g.suspicion, " ALERTA" if g.alert else "", " baja %.0fs" % drop if drop != INF else (" fija" if g.suspicion > 0 else "")]
	lines.append(sus + (" VE LADRON" if g.sees_player else ""))
	lines.append("Aten %.2f (%.2f ×%.1f)" % [v.attention, v.attention_trait, v.attention_state])
	lines.append("Vel %.2f (r%.2f ×d%.2f ×paso %.2f)" % [v.speed, v.speed_trait, v.speed_dial, v.stride])
	lines.append("Vista %.1f %d° (r%.2f ×d%.2f ×%.1f)  Oido ×%.2f (r%.2f ×d%.2f ×%.2f)" % [v.view_range, roundi(rad_to_deg(v.view_half) * 2.0), v.view_trait, v.view_dial, v.view_state, v.hearing, v.hearing_trait, v.hearing_dial, v.hearing_state])
	if v.theft_chance > 0.0:
		lines.append("Vitrina vacia: %.1f%%/tirada" % (float(v.theft_chance) * 100.0))
	return "\n".join(lines)


## The night's own line (the dev overlay): mode, siren, intruder, theft.
static func night_text(guards: Array[Guard]) -> String:
	var parts: Array[String] = ["Noche: %s" % NightAlert.mode(guards)]
	if NightAlert.ringing():
		parts.append("ALARMA suena %.1fs" % NightAlert.alarm_left)
	else:
		parts.append("alarma callada")
	if NightAlert.intruder:
		if NightAlert.ringing():
			parts.append("intruso (cuenta parada)")
		else:
			parts.append("intruso %.0fs" % maxf(0.0, NightAlert.INTRUDER_HOLD_S - NightAlert.quiet))
	if NightAlert.robbed:
		parts.append("ROBO DESCUBIERTO por %s" % NightAlert.found_by)
	elif Heist.taken:
		parts.append("pieza cogida, aun no lo saben")
	return " | ".join(parts)
