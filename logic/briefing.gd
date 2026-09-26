class_name Briefing
extends RefCounted
## The tips on the screen before a heist, worked out from the night itself:
## how many guards and what they are like (Sim.tuning), what is switched on
## (Sim.feature), the job (Heist) and what lies about to knock over (Props).
## A short line each, for kids: what to watch out for, and what to do about it.

## Past these the guards' senses and pace are worth a word (Sim.tuning,
## gang ease included): medium is the game as designed, and says nothing.
const FAST := 1.05
const SLOW := 0.75
const SHARP_EARS := 1.1
const DULL_EARS := 0.6
const FAR_EYES := 1.1
const SHORT_EYES := 0.6
## calm_after, in seconds: slow to calm down from here up.
const GRUDGE := 12.0
## The most tips on screen: past this, the least urgent go.
const MOST := 7


## The tips for the night laid out, most urgent first.
static func tips(guards: Array[Guard]) -> Array[String]:
	var n := guards.size()
	var out: Array[String] = [_guards_line(n)]
	if n > 0:
		var hearing := Sim.tuning("hearing")
		if hearing >= SHARP_EARS:
			out.append(_by(n, "TIP_CROUCH_SHARP"))
		elif hearing < DULL_EARS:
			out.append(_by(n, "TIP_EARS_DULL"))
		else:
			out.append(Text.t("TIP_CROUCH"))
	# The case: two or more open it together, in silence; alone, its alarm rings.
	if Heist.team:
		out.append(Text.t("BRIEF_TEAM_TWO_PANELS" if Heist.panel2.x >= 0 else ("BRIEF_TEAM_TWO_LOCKS" if Heist.hands > 1 else "BRIEF_TEAM_ONE_LOCK")))
		out.append(Text.t("BRIEF_TEAM_ALL_OUT"))
	elif Sim.feature("case_alarm"):
		out.append(Text.t("TIP_CASE_ALARM"))
	else:
		out.append(Text.t("TIP_CASE_QUIET"))
	# Something to knock over: a way to send the guards elsewhere.
	if not Props.list.is_empty():
		out.append(Text.t("BRIEF_PROPS"))
	if n > 0:
		var view := Sim.tuning("view")
		if view >= FAR_EYES:
			out.append(_by(n, "TIP_EYES_FAR"))
		elif view < SHORT_EYES:
			out.append(_by(n, "TIP_EYES_SHORT"))
		var speed := Sim.tuning("speed")
		if speed >= FAST:
			out.append(_by(n, "TIP_FAST"))
		elif speed < SLOW:
			out.append(_by(n, "TIP_SLOW"))
		if guards.any(func(g: Guard) -> bool: return g.post.x >= 0):
			out.append(Text.t("TIP_POST"))
		if int(Sim.tuning("alarms")) <= 1:
			out.append(Text.t("TIP_JUMPY"))
		elif Sim.tuning("calm_after") >= GRUDGE:
			out.append(_by(n, "TIP_GRUDGE"))
		if Sim.feature("lights"):
			out.append(_by(n, "TIP_LIGHTS"))
	if Museum.size_name == "large":
		out.append(Text.t("TIP_MAP"))
	return out.slice(0, MOST)


## How many guards, and what stands out about them: "Hay 3 guardias: son
## rápidos y oyen muy bien."
static func _guards_line(n: int) -> String:
	if n == 0:
		return Text.t("TIP_GUARDS_NONE")
	var traits: Array[String] = []
	var speed := Sim.tuning("speed")
	if speed >= FAST:
		traits.append(_by(n, "TIP_TRAIT_FAST"))
	elif speed < SLOW:
		traits.append(_by(n, "TIP_TRAIT_SLOW"))
	var hearing := Sim.tuning("hearing")
	if hearing >= SHARP_EARS:
		traits.append(_by(n, "TIP_TRAIT_SHARP_EARS"))
	elif hearing < DULL_EARS:
		traits.append(_by(n, "TIP_TRAIT_DULL_EARS"))
	var view := Sim.tuning("view")
	if view >= FAR_EYES:
		traits.append(_by(n, "TIP_TRAIT_FAR_EYES"))
	elif view < SHORT_EYES:
		traits.append(_by(n, "TIP_TRAIT_SHORT_EYES"))
	if int(Sim.tuning("alarms")) <= 1 or Sim.tuning("calm_after") >= GRUDGE:
		traits.append(_by(n, "TIP_TRAIT_SMART"))
	var head := Text.t("TIP_GUARDS_ONE") if n == 1 else Text.t("TIP_GUARDS_MANY") % n
	if traits.is_empty():
		return head + "."
	var last: String = traits.pop_back()
	var list: String = last if traits.is_empty() else "%s %s %s" % [", ".join(traits), Text.t("TIP_AND"), last]
	return "%s: %s." % [head, list]


## A line in the singular for one guard, in the plural for more (KEY_ONE, KEY_MANY).
static func _by(n: int, key: String) -> String:
	return Text.t(key + ("_ONE" if n == 1 else "_MANY"))
