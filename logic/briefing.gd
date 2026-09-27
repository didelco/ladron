class_name Briefing
extends RefCounted
## The rules on the plan screen before a heist, worked out from the night
## itself — how many guards and what they are like (Sim.tuning), what is
## switched on (Sim.feature), the job (Heist) and what lies about to knock
## over (Props) — so the same rules serve a story night, a generated museum
## and a saved map.
##
## The rules for the rules:
##   - At most MOST lines, aiming at AIM: the lines that must be said
##     (MUST) always go, up to MOST; the rest (NICE) only fill up to AIM.
##   - A short line each (at most WORDS words): what is so, then what to do.
##   - What is normal is not said: a case without an alarm, guards as the
##     game has them.
##   - The guards in a single line: how many, what stands out about them
##     (two traits at most) and what to do about the first.
##   - A mechanic (MECHANICS) is told in the story twice: on the night that
##     teaches it, on the "what's new" page (Story.news), and the night
##     after, here; after that it is known and goes unsaid. Out of the
##     story (no night to go by) it is said whenever the museum has it.
##     A gang's shared job counts as one, taught on the first night.
##   - A museum's big job (Story's "boss") says what makes it one, in its
##     own line ("tip"), right under the guards.
##   - In this order: the guards, the big job, the job, the museum.

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
## The most lines on screen, and how many to aim at.
const MOST := 5
const AIM := 3
## The longest a line may be, in words (the tests hold every night to it).
const WORDS := 14

## The mechanics and the story lesson (Story.LESSONS) that teaches each,
## most urgent first: key -> lesson.
const MECHANICS := {
	"case_alarm": "case_alarm", "lights": "lights", "two": "two", "props": "props",
	"noise": "noise", "torch": "torch", "map": "big",
}


## The rules for the night laid out, most urgent first. night: the story
## night (1-based) it is, or 0 out of the story.
static func tips(guards: Array[Guard], night := 0) -> Array[String]:
	var n := guards.size()
	var must: Array[String] = [_guards_line(n)]
	var nice: Array[String] = []
	# A museum's big job: what makes it one, in a line of its own.
	if night > 0 and String(Story.LEVELS[night - 1].get("tip", "")) != "":
		must.append(Text.t(Story.LEVELS[night - 1].tip))
	# The job: a gang shares it out, and all of them have to get out; told
	# like a mechanic (the first night's lesson).
	if Heist.team and (night <= 0 or night == Story.lesson_night("heist") + 1):
		must.append(Text.t("BRIEF_TEAM_TWO_PANELS" if Heist.panel2.x >= 0 else ("BRIEF_TEAM_TWO_LOCKS" if Heist.hands > 1 else "BRIEF_TEAM_ONE_LOCK")))
		must.append(Text.t("BRIEF_TEAM_ALL_OUT"))
	if n > 0:
		if int(Sim.tuning("alarms")) <= 1:
			must.append(Text.t("TIP_JUMPY"))
		elif Sim.tuning("calm_after") >= GRUDGE:
			nice.append(_by(n, "TIP_GRUDGE"))
		if guards.any(func(g: Guard) -> bool: return g.post.x >= 0):
			nice.append(Text.t("TIP_POST"))
	# The museum: its mechanics, while they are still news.
	for m in MECHANICS:
		if _has(m, n) and _worth_saying(m, night):
			must.append(_by(n, "TIP_LIGHTS") if m == "lights" else Text.t(_key(m)))
	var out: Array[String] = must.slice(0, MOST)
	for line in nice:
		if out.size() >= AIM:
			break
		out.append(line)
	return out


## Whether tonight's museum has mechanic m at all.
static func _has(m: String, guards: int) -> bool:
	match m:
		"case_alarm", "lights": return Sim.feature(m)
		"props": return not Props.list.is_empty()
		"two": return guards >= 2
		"noise", "torch": return guards > 0
		"map": return Museum.size_name == "large"
	return false


## In the story, only the night after the one that teaches it; out of it,
## always but the basics every guard comes with (the torch and the noise,
## which the guards' line already covers).
static func _worth_saying(m: String, night: int) -> bool:
	if night <= 0:
		return m not in ["noise", "torch"]
	return night == Story.lesson_night(MECHANICS[m]) + 1


static func _key(m: String) -> String:
	return {"case_alarm": "TIP_CASE_ALARM", "props": "BRIEF_PROPS", "two": "TIP_TWO",
		"noise": "TIP_NOISE", "torch": "TIP_TORCH", "map": "TIP_MAP"}[m]


## How many guards, what stands out about them and what to do about it:
## "2 guardias lentos y medio sordos: puedes correr, pero que no te vean."
static func _guards_line(n: int) -> String:
	if n == 0:
		return Text.t("TIP_GUARDS_NONE")
	# Most urgent first: the first one's advice is the line's.
	var traits: Array[String] = []
	var hearing := Sim.tuning("hearing")
	var view := Sim.tuning("view")
	var speed := Sim.tuning("speed")
	if hearing >= SHARP_EARS:
		traits.append("SHARP_EARS")
	if speed >= FAST:
		traits.append("FAST")
	if view >= FAR_EYES:
		traits.append("FAR_EYES")
	if hearing < DULL_EARS:
		traits.append("DULL_EARS")
	if view < SHORT_EYES:
		traits.append("SHORT_EYES")
	if speed < SLOW:
		traits.append("SLOW")
	traits = traits.slice(0, 2)
	var who := Text.t("TIP_GUARDS_ONE") if n == 1 else Text.t("TIP_GUARDS_MANY") % n
	var words: Array[String] = []
	for t in traits:
		words.append(_by(n, "TIP_TRAIT_" + t))
	if not words.is_empty():
		who += " " + (" %s " % Text.t("TIP_AND")).join(words)
	var advice := _by(n, "TIP_ADVICE_" + (traits[0] if not traits.is_empty() else "NORMAL"))
	return "%s: %s." % [who, advice]


## A line in the singular for one guard, in the plural for more (KEY_ONE, KEY_MANY).
static func _by(n: int, key: String) -> String:
	return Text.t(key + ("_ONE" if n == 1 else "_MANY"))
