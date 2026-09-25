class_name Story
extends RefCounted
## The story mode: twenty nights, each a fixed museum and a fixed piece,
## from an empty little museum to four wide-awake guards in a big one. Now
## and then a night teaches one new thing, and is built around it; the ones
## in between practise it, each a little harder than the last.
##
## The tale, for kids: the Banda del Calcetín only steals what was stolen
## first. The Barón Von Bostezo, director of the Museo de Cosas Rarísimas,
## has taken twenty things from the town and put them in glass cases; one
## a night, the gang takes them back.

const PROLOGUE := "STORY_PROLOGUE"

const ENDING := "STORY_ENDING"

## Each night: museum size and shape, how many guards, their senses and pace
## (Sim.tuning keys), what is switched on yet (props, lights, the case's
## alarm: Sim.feature), a guard's post if the lesson needs one, the one
## thing it teaches (LESSONS), and the piece. Easy to hard, one new thing
## at a time.
const LEVELS := [
	{"size": "small", "shape": "rect", "guards": 0, "view": 0.45, "hearing": 0.2, "speed": 0.4, "calm_after": 5.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "heist",
		"loot": {"name": "NIGHT_01_NAME", "blurb": "NIGHT_01_BLURB", "verb": "NIGHT_01_VERB", "seconds": 1.5, "colour": "#f4f1e6", "shape": "teeth",
			"story": "NIGHT_01_TALE"}},
	{"size": "small", "shape": "L", "guards": 1, "view": 0.45, "hearing": 0.2, "speed": 0.4, "calm_after": 5.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "guard",
		"loot": {"name": "NIGHT_02_NAME", "blurb": "NIGHT_02_BLURB", "verb": "NIGHT_02_VERB", "seconds": 2.0, "colour": "#ffd43b", "shape": "duck",
			"story": "NIGHT_02_TALE"}},
	{"size": "small", "shape": "T", "guards": 1, "view": 0.5, "hearing": 0.25, "speed": 0.45, "calm_after": 5.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "",
		"loot": {"name": "NIGHT_03_NAME", "blurb": "NIGHT_03_BLURB", "verb": "NIGHT_03_VERB", "seconds": 2.0, "colour": "#ff6b6b", "shape": "sock",
			"story": "NIGHT_03_TALE"}},
	{"size": "small", "shape": "rect", "guards": 1, "post": "route", "view": 0.95, "hearing": 0.25, "speed": 0.45, "calm_after": 6.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "torch",
		"loot": {"name": "NIGHT_04_NAME", "blurb": "NIGHT_04_BLURB", "verb": "NIGHT_04_VERB", "seconds": 2.5, "colour": "#dee2e6", "shape": "sock",
			"story": "NIGHT_04_TALE"}},
	{"size": "small", "shape": "U", "guards": 1, "view": 0.6, "hearing": 0.3, "speed": 0.5, "calm_after": 6.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "",
		"loot": {"name": "NIGHT_05_NAME", "blurb": "NIGHT_05_BLURB", "verb": "NIGHT_05_VERB", "seconds": 2.5, "colour": "#e03131", "shape": "idol",
			"story": "NIGHT_05_TALE"}},
	{"size": "small", "shape": "L", "guards": 1, "post": "quiet", "view": 0.6, "hearing": 0.8, "speed": 0.5, "calm_after": 6.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "noise",
		"loot": {"name": "NIGHT_06_NAME", "blurb": "NIGHT_06_BLURB", "verb": "NIGHT_06_VERB", "seconds": 3.0, "colour": "#d4a15a", "shape": "toast",
			"story": "NIGHT_06_TALE"}},
	{"size": "small", "shape": "notched", "guards": 1, "view": 0.65, "hearing": 0.85, "speed": 0.55, "calm_after": 7.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "",
		"loot": {"name": "NIGHT_07_NAME", "blurb": "NIGHT_07_BLURB", "verb": "NIGHT_07_VERB", "seconds": 3.0, "colour": "#f783ac", "shape": "rock",
			"story": "NIGHT_07_TALE"}},
	{"size": "small", "shape": "rect", "guards": 1, "post": "case", "view": 0.7, "hearing": 0.85, "speed": 0.55, "calm_after": 7.0, "alarms": 3, "props": true, "lights": false, "case_alarm": false, "teach": "props",
		"loot": {"name": "NIGHT_08_NAME", "blurb": "NIGHT_08_BLURB", "verb": "NIGHT_08_VERB", "seconds": 3.5, "colour": "#7bc043", "shape": "crown",
			"story": "NIGHT_08_TALE"}},
	{"size": "medium", "shape": "U", "guards": 1, "view": 0.68, "hearing": 0.9, "speed": 0.6, "calm_after": 7.0, "alarms": 3, "props": true, "lights": false, "case_alarm": false, "teach": "",
		"loot": {"name": "NIGHT_09_NAME", "blurb": "NIGHT_09_BLURB", "verb": "NIGHT_09_VERB", "seconds": 3.5, "colour": "#fcc419", "shape": "idol",
			"story": "NIGHT_09_TALE"}},
	{"size": "medium", "shape": "L", "guards": 1, "view": 0.72, "hearing": 0.9, "speed": 0.62, "calm_after": 8.0, "alarms": 3, "props": true, "lights": false, "case_alarm": false, "teach": "",
		"loot": {"name": "NIGHT_10_NAME", "blurb": "NIGHT_10_BLURB", "verb": "NIGHT_10_VERB", "seconds": 4.0, "colour": "#ffe066", "shape": "rock",
			"story": "NIGHT_10_TALE"}},
	{"size": "medium", "shape": "T", "guards": 1, "view": 0.72, "hearing": 0.9, "speed": 0.62, "calm_after": 8.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "case_alarm",
		"loot": {"name": "NIGHT_11_NAME", "blurb": "NIGHT_11_BLURB", "verb": "NIGHT_11_VERB", "seconds": 4.0, "colour": "#2b8a3e", "shape": "mask",
			"story": "NIGHT_11_TALE"}},
	{"size": "medium", "shape": "notched", "guards": 1, "view": 0.78, "hearing": 0.95, "speed": 0.68, "calm_after": 8.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "",
		"loot": {"name": "NIGHT_12_NAME", "blurb": "NIGHT_12_BLURB", "verb": "NIGHT_12_VERB", "seconds": 4.5, "colour": "#9b5de5", "shape": "mask",
			"story": "NIGHT_12_TALE"}},
	{"size": "medium", "shape": "cross", "guards": 2, "view": 0.72, "hearing": 0.95, "speed": 0.65, "calm_after": 9.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "two",
		"loot": {"name": "NIGHT_13_NAME", "blurb": "NIGHT_13_BLURB", "verb": "NIGHT_13_VERB", "seconds": 4.5, "colour": "#e8590c", "shape": "clock",
			"story": "NIGHT_13_TALE"}},
	{"size": "medium", "shape": "U", "guards": 2, "view": 0.78, "hearing": 1.0, "speed": 0.7, "calm_after": 9.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "",
		"loot": {"name": "NIGHT_14_NAME", "blurb": "NIGHT_14_BLURB", "verb": "NIGHT_14_VERB", "seconds": 5.0, "colour": "#4dabf7", "shape": "clock",
			"story": "NIGHT_14_TALE"}},
	{"size": "medium", "shape": "L", "guards": 2, "view": 0.8, "hearing": 1.0, "speed": 0.72, "calm_after": 10.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "lights",
		"loot": {"name": "NIGHT_15_NAME", "blurb": "NIGHT_15_BLURB", "verb": "NIGHT_15_VERB", "seconds": 5.0, "colour": "#8b5a2b", "shape": "egg",
			"story": "NIGHT_15_TALE"}},
	{"size": "medium", "shape": "T", "guards": 2, "view": 0.85, "hearing": 1.0, "speed": 0.78, "calm_after": 10.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "",
		"loot": {"name": "NIGHT_16_NAME", "blurb": "NIGHT_16_BLURB", "verb": "NIGHT_16_VERB", "seconds": 5.5, "colour": "#e8c89a", "shape": "egg",
			"story": "NIGHT_16_TALE"}},
	{"size": "large", "shape": "U", "guards": 2, "view": 0.82, "hearing": 1.0, "speed": 0.75, "calm_after": 11.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "big",
		"loot": {"name": "NIGHT_17_NAME", "blurb": "NIGHT_17_BLURB", "verb": "NIGHT_17_VERB", "seconds": 5.5, "colour": "#ffd43b", "shape": "teeth",
			"story": "NIGHT_17_TALE"}},
	{"size": "large", "shape": "notched", "guards": 3, "view": 0.9, "hearing": 1.05, "speed": 0.85, "calm_after": 12.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "",
		"loot": {"name": "NIGHT_18_NAME", "blurb": "NIGHT_18_BLURB", "verb": "NIGHT_18_VERB", "seconds": 6.0, "colour": "#339af0", "shape": "duck",
			"story": "NIGHT_18_TALE"}},
	{"size": "large", "shape": "T", "guards": 3, "view": 0.95, "hearing": 1.1, "speed": 0.92, "calm_after": 13.0, "alarms": 1, "props": true, "lights": true, "case_alarm": true, "teach": "",
		"loot": {"name": "NIGHT_19_NAME", "blurb": "NIGHT_19_BLURB", "verb": "NIGHT_19_VERB", "seconds": 6.5, "colour": "#ffec99", "shape": "gem",
			"story": "NIGHT_19_TALE"}},
	{"size": "large", "shape": "cross", "guards": 4, "view": 1.05, "hearing": 1.15, "speed": 1.0, "calm_after": 14.0, "alarms": 1, "props": true, "lights": true, "case_alarm": true, "teach": "finale",
		"loot": {"name": "NIGHT_20_NAME", "blurb": "NIGHT_20_BLURB", "verb": "NIGHT_20_VERB", "seconds": 7.0, "colour": "#74c0fc", "shape": "gem",
			"story": "NIGHT_20_TALE"}},
]

## Each night's museum is always the same one — one for a thief on their
## own and another for two, with the same piece to take back.
const SEED_BASE := 424242
const SEED_TEAM := 104729
## How many museums a lesson night may look through for one that forces its
## lesson (Sim.assign_posts); each is SEED_STEP on from the last.
const LESSON_TRIES := 60
const SEED_STEP := 7777

## What each night teaches, one thing a night, the night built around it:
## a title, a line on how it works and its own little scene acting it out
## (LessonStage). The
## words here, like the pieces' and the tale's, are keys into Text.
const LESSONS := {
	"heist": {"title": "LESSON_HEIST_TITLE", "stage": "lesson:heist",
		"text": "LESSON_HEIST_TEXT"},
	# The same first lesson for a gang, with the gang's own jobs.
	"heist2": {"title": "LESSON_HEIST2_TITLE", "stage": "lesson:heist2",
		"text": "LESSON_HEIST2_TEXT"},
	"heist3": {"title": "LESSON_HEIST3_TITLE", "stage": "lesson:heist3",
		"text": "LESSON_HEIST3_TEXT"},
	"heist4": {"title": "LESSON_HEIST4_TITLE", "stage": "lesson:heist4",
		"text": "LESSON_HEIST4_TEXT"},
	"guard": {"title": "LESSON_GUARD_TITLE", "stage": "lesson:guard",
		"text": "LESSON_GUARD_TEXT"},
	"torch": {"title": "LESSON_TORCH_TITLE", "stage": "lesson:torch",
		"text": "LESSON_TORCH_TEXT"},
	"noise": {"title": "LESSON_NOISE_TITLE", "stage": "lesson:noise",
		"text": "LESSON_NOISE_TEXT"},
	"props": {"title": "LESSON_PROPS_TITLE", "stage": "lesson:props",
		"text": "LESSON_PROPS_TEXT"},
	"case_alarm": {"title": "LESSON_CASE_ALARM_TITLE", "stage": "lesson:case_alarm",
		"text": "LESSON_CASE_ALARM_TEXT"},
	"two": {"title": "LESSON_TWO_TITLE", "stage": "lesson:two",
		"text": "LESSON_TWO_TEXT"},
	"lights": {"title": "LESSON_LIGHTS_TITLE", "stage": "lesson:lights",
		"text": "LESSON_LIGHTS_TEXT"},
	"big": {"title": "LESSON_BIG_TITLE", "stage": "lesson:big",
		"text": "LESSON_BIG_TEXT"},
	"finale": {"title": "LESSON_FINALE_TITLE", "stage": "lesson:finale",
		"text": "LESSON_FINALE_TEXT"},
}

const SAVE := "user://progress.cfg"


static func count() -> int:
	return LEVELS.size()


## Night n (1-based), its piece in words on screen.
static func level(n: int) -> Dictionary:
	var l: Dictionary = LEVELS[clampi(n, 1, LEVELS.size()) - 1].duplicate(true)
	l.loot = Heist.translated(l.loot)
	return l


## The prologue, a paragraph a page.
static func prologue() -> PackedStringArray:
	return Text.t(PROLOGUE).split("\n\n")


static func ending() -> String:
	return Text.t(ENDING)


static func seed_for(n: int, players := 1) -> int:
	return SEED_BASE + n * 7919 + SEED_TEAM * (players - 1)


## What is new on night n, as cards: the one thing the night is built to
## teach. Empty if it teaches nothing new.
static func news(n: int, players := 1) -> Array:
	var teach: String = level(n).get("teach", "")
	if teach == "heist" and players >= 2:
		teach = "heist%d" % mini(players, 4)
	return [Text.fields(LESSONS[teach], ["title", "text"])] if teach != "" else []


## The senses and pace of the guards on night n, as Sim.custom.
static func tuning(n: int) -> Dictionary:
	var l := level(n)
	var out := {"lock": 1.0}
	for k in ["guards", "view", "hearing", "speed", "calm_after", "alarms", "props", "lights", "case_alarm", "post"]:
		if l.has(k):
			out[k] = l[k]
	return out


## The furthest night reached, saved between sessions.
static func unlocked() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE) != OK:
		return 1
	return clampi(int(cfg.get_value("story", "unlocked", 1)), 1, LEVELS.size())


static func unlock(n: int) -> void:
	if n <= unlocked():
		return
	var cfg := ConfigFile.new()
	cfg.load(SAVE)
	cfg.set_value("story", "unlocked", clampi(n, 1, LEVELS.size()))
	cfg.save(SAVE)
