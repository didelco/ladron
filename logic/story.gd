class_name Story
extends RefCounted
## The story mode: five museums to rob, five heists in each, twenty-five in
## all. Each museum keeps to one theme (Themes) and its own look: every
## gallery shows that theme's pieces, and every piece taken fits it. The
## first four heists of a museum are its rooms, each a little harder than
## the last; the fifth is its big job (a boss): the museum's star piece,
## with a twist of its own made of what the game already has. Take all
## five and the next museum opens.
##
## Now and then a heist teaches one new thing, and is built around it; the
## ones in between practise it. The big jobs teach nothing: they test.
##
## The tale, for kids: the Banda del Calcetín only steals what was stolen
## first. The Barón Von Bostezo made the directors of the town's five
## museums yawn with his diamond until they signed them over to him; now he
## keeps them, and fills their cases with things nicked from the town (the
## grandad's dentures, the ketchup in Jake's fridge), labelled as treasures.
## Kids' humour: everyday things, a neighbour with a name, an absurd upshot
## in town; a piece fits its museum by the joke, not the history lesson.
## One a night, the gang takes them back, until the museums are
## everybody's again.

const PROLOGUE := "STORY_PROLOGUE"

const ENDING := "STORY_ENDING"

## Heists in a museum: four rooms and the big job, always the last.
const ROOMS := 5

## Each heist: museum size and shape, how many guards, their senses and pace
## (Sim.tuning keys), what is switched on yet (props, lights, the case's
## alarm: Sim.feature), a guard's post if the lesson or the big job needs
## one, the one thing it teaches (LESSONS), and the piece. A big job says
## so ("boss") and has a line of its own for the plan ("tip"). Easy to
## hard, one new thing at a time; each museum's pieces fit its theme.
## "reseed" (optional) builds the night's museum from that many seeds on
## (seed_for), for a museum that suits it better than the first. "par": the
## time for the fast star (stars), in seconds.
const LEVELS := [
	# --- El Museo de la Prehistoria: prehistory. Small museums, one guard at most.
	{"size": "small", "shape": "rect", "guards": 0, "view": 0.45, "hearing": 0.2, "speed": 0.4, "calm_after": 5.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "heist", "par": 30,
		"loot": {"name": "NIGHT_01_NAME", "blurb": "NIGHT_01_BLURB", "verb": "NIGHT_01_VERB", "seconds": 1.5, "colour": "#f4f1e6", "shape": "teeth",
			"story": "NIGHT_01_TALE"}},
	{"size": "small", "shape": "L", "guards": 1, "view": 0.45, "hearing": 0.2, "speed": 0.4, "calm_after": 5.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "guard", "par": 25,
		"loot": {"name": "NIGHT_02_NAME", "blurb": "NIGHT_02_BLURB", "verb": "NIGHT_02_VERB", "seconds": 2.0, "colour": "#dee2e6", "shape": "sock",
			"story": "NIGHT_02_TALE"}},
	{"size": "small", "shape": "T", "guards": 1, "view": 0.5, "hearing": 0.25, "speed": 0.45, "calm_after": 5.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "", "par": 25,
		"loot": {"name": "NIGHT_03_NAME", "blurb": "NIGHT_03_BLURB", "verb": "NIGHT_03_VERB", "seconds": 2.0, "colour": "#d9261c", "shape": "ketchup",
			"story": "NIGHT_03_TALE"}},
	{"size": "small", "shape": "rect", "guards": 1, "post": "route", "view": 0.95, "hearing": 0.25, "speed": 0.45, "calm_after": 6.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "torch", "par": 25,
		"loot": {"name": "NIGHT_04_NAME", "blurb": "NIGHT_04_BLURB", "verb": "NIGHT_04_VERB", "seconds": 2.5, "colour": "#e03131", "shape": "idol",
			"story": "NIGHT_04_TALE"}},
	# The big job: the cave's keeper, alone, far-sighted and quick, in the
	# first bigger museum, walking across your way: hard of hearing, but not
	# so deaf you can run past it. Seen, you lose it and hide (a mammoth, an
	# egg).
	{"size": "medium", "shape": "L", "reseed": 2, "guards": 1, "view": 1.12, "hearing": 0.4, "speed": 1.05, "calm_after": 8.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "", "par": 45,
		"boss": true, "tip": "NIGHT_05_TIP",
		"loot": {"name": "NIGHT_05_NAME", "blurb": "NIGHT_05_BLURB", "verb": "NIGHT_05_VERB", "seconds": 3.0, "colour": "#e8c89a", "shape": "egg",
			"story": "NIGHT_05_TALE"}},
	# --- El Museo de Ciencias Naturales: nature. The minigames (LOCKPICK_NIGHT), the
	# noise, then things to knock over. From here the case is picked: its
	# seconds are the pick's pins (Minigame.pins_for), one on the first nights.
	{"size": "small", "shape": "notched", "guards": 1, "view": 0.6, "hearing": 0.4, "speed": 0.5, "calm_after": 6.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "games", "par": 25,
		"loot": {"name": "NIGHT_06_NAME", "blurb": "NIGHT_06_BLURB", "verb": "NIGHT_06_VERB", "seconds": 3.0, "colour": "#7bc043", "shape": "crown",
			"story": "NIGHT_06_TALE"}},
	{"size": "small", "shape": "L", "guards": 1, "post": "quiet", "view": 0.65, "hearing": 0.85, "speed": 0.55, "calm_after": 7.0, "alarms": 3, "props": false, "lights": false, "case_alarm": false, "teach": "noise", "par": 25,
		"loot": {"name": "NIGHT_07_NAME", "blurb": "NIGHT_07_BLURB", "verb": "NIGHT_07_VERB", "seconds": 3.0, "colour": "#ff6b6b", "shape": "sock",
			"story": "NIGHT_07_TALE"}},
	{"size": "small", "shape": "rect", "guards": 1, "post": "case", "view": 0.7, "hearing": 0.85, "speed": 0.55, "calm_after": 7.0, "alarms": 3, "props": true, "lights": false, "case_alarm": false, "teach": "props", "par": 40,
		"loot": {"name": "NIGHT_08_NAME", "blurb": "NIGHT_08_BLURB", "verb": "NIGHT_08_VERB", "seconds": 3.5, "colour": "#9b5de5", "shape": "mask",
			"story": "NIGHT_08_TALE"}},
	{"size": "medium", "shape": "L", "reseed": 3, "guards": 1, "view": 0.72, "hearing": 1.0, "speed": 0.65, "calm_after": 7.0, "alarms": 3, "props": true, "lights": false, "case_alarm": false, "teach": "", "par": 40,
		"loot": {"name": "NIGHT_09_NAME", "blurb": "NIGHT_09_BLURB", "verb": "NIGHT_09_VERB", "seconds": 3.5, "colour": "#e8a860", "shape": "gum",
			"story": "NIGHT_09_TALE"}},
	# The big job: a guard that never leaves the duck, sharp-eared and
	# jumpy, a long way from the door. One lure to move it, and only one:
	# after that it is on alert.
	{"size": "medium", "shape": "L", "guards": 1, "post": "case", "view": 0.8, "hearing": 1.15, "speed": 0.65, "calm_after": 9.0, "alarms": 1, "props": true, "lights": false, "case_alarm": false, "teach": "", "par": 65,
		"boss": true, "tip": "NIGHT_10_TIP",
		"loot": {"name": "NIGHT_10_NAME", "blurb": "NIGHT_10_BLURB", "verb": "NIGHT_10_VERB", "seconds": 4.0, "colour": "#ffd43b", "shape": "duck",
			"story": "NIGHT_10_TALE"}},
	# --- La Villa de las Antigüedades: the ancient world. The case's alarm, then
	# two guards. The alarm's night, a museum where the guard walks within
	# earshot of the case now and then: pick it while it is away.
	{"size": "medium", "shape": "L", "reseed": 2, "guards": 1, "view": 0.72, "hearing": 1.0, "speed": 0.62, "calm_after": 8.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "case_alarm", "par": 35,
		"loot": {"name": "NIGHT_11_NAME", "blurb": "NIGHT_11_BLURB", "verb": "NIGHT_11_VERB", "seconds": 4.0, "colour": "#e8b53a", "shape": "idol",
			"story": "NIGHT_11_TALE"}},
	{"size": "medium", "shape": "notched", "reseed": 1, "guards": 1, "view": 0.8, "hearing": 1.05, "speed": 0.68, "calm_after": 8.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "", "par": 40,
		"loot": {"name": "NIGHT_12_NAME", "blurb": "NIGHT_12_BLURB", "verb": "NIGHT_12_VERB", "seconds": 4.5, "colour": "#2ec4b6", "shape": "clock",
			"story": "NIGHT_12_TALE"}},
	{"size": "medium", "shape": "cross", "guards": 2, "view": 0.72, "hearing": 0.95, "speed": 0.65, "calm_after": 9.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "two", "par": 45,
		"loot": {"name": "NIGHT_13_NAME", "blurb": "NIGHT_13_BLURB", "verb": "NIGHT_13_VERB", "seconds": 4.5, "colour": "#4dabf7", "shape": "duck",
			"story": "NIGHT_13_TALE"}},
	{"size": "medium", "shape": "T", "guards": 2, "view": 0.78, "hearing": 1.0, "speed": 0.7, "calm_after": 9.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "", "par": 60,
		"loot": {"name": "NIGHT_14_NAME", "blurb": "NIGHT_14_BLURB", "verb": "NIGHT_14_VERB", "seconds": 5.0, "colour": "#f4f1e6", "shape": "egg",
			"story": "NIGHT_14_TALE"}},
	# The big job: three guards for the first time, one of them standing by
	# the way in: past it on all fours, while the other two walk their rounds.
	{"size": "medium", "shape": "T", "guards": 3, "post": "route", "view": 0.9, "hearing": 1.0, "speed": 0.75, "calm_after": 10.0, "alarms": 2, "props": true, "lights": false, "case_alarm": true, "teach": "", "par": 90,
		"boss": true, "tip": "NIGHT_15_TIP",
		"loot": {"name": "NIGHT_15_NAME", "blurb": "NIGHT_15_BLURB", "verb": "NIGHT_15_VERB", "seconds": 5.5, "colour": "#12b886", "shape": "gem",
			"story": "NIGHT_15_TALE"}},
	# --- El Museo del Castillo: the middle ages. The lights: on their
	# night the guards hear the case's alarm often (four times in ten), and
	# on alert they light the rooms, so the lights are seen being used.
	{"size": "medium", "shape": "rect", "guards": 2, "view": 0.8, "hearing": 1.05, "speed": 0.72, "calm_after": 10.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "lights", "par": 30,
		"loot": {"name": "NIGHT_16_NAME", "blurb": "NIGHT_16_BLURB", "verb": "NIGHT_16_VERB", "seconds": 5.0, "colour": "#e8590c", "shape": "clock",
			"story": "NIGHT_16_TALE"}},
	{"size": "medium", "shape": "T", "guards": 2, "view": 0.85, "hearing": 1.0, "speed": 0.78, "calm_after": 10.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "", "par": 50,
		"loot": {"name": "NIGHT_17_NAME", "blurb": "NIGHT_17_BLURB", "verb": "NIGHT_17_VERB", "seconds": 5.5, "colour": "#8b5a2b", "shape": "rock",
			"story": "NIGHT_17_TALE"}},
	{"size": "medium", "shape": "L", "guards": 2, "view": 0.88, "hearing": 1.0, "speed": 0.8, "calm_after": 11.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "", "par": 55,
		"loot": {"name": "NIGHT_18_NAME", "blurb": "NIGHT_18_BLURB", "verb": "NIGHT_18_VERB", "seconds": 5.0, "colour": "#b197fc", "shape": "gum",
			"story": "NIGHT_18_TALE"}},
	{"size": "medium", "shape": "T", "guards": 2, "view": 0.9, "hearing": 1.05, "speed": 0.82, "calm_after": 11.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "", "par": 65,
		"loot": {"name": "NIGHT_19_NAME", "blurb": "NIGHT_19_BLURB", "verb": "NIGHT_19_VERB", "seconds": 5.5, "colour": "#40c057", "shape": "mask",
			"story": "NIGHT_19_TALE"}},
	# The big job: the throne room. Three guards slow to calm down, one of
	# them standing with its back to the way, all ears: not a step running.
	# Far enough from the case not to hear its alarm: no lure needed.
	{"size": "medium", "shape": "T", "guards": 3, "post": "quiet", "view": 0.9, "hearing": 1.15, "speed": 0.85, "calm_after": 13.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "", "par": 120,
		"boss": true, "tip": "NIGHT_20_TIP",
		"loot": {"name": "NIGHT_20_NAME", "blurb": "NIGHT_20_BLURB", "verb": "NIGHT_20_VERB", "seconds": 5.0, "colour": "#f0c46a", "shape": "crown",
			"story": "NIGHT_20_TALE"}},
	# --- El Museo de Arte Contemporáneo: the modern age. Big museums, and the end: more
	# guards than anywhere, so they are not lost in so much museum.
	{"size": "large", "shape": "U", "reseed": 1, "guards": 3, "view": 0.82, "hearing": 1.0, "speed": 0.75, "calm_after": 11.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "big", "par": 60,
		"loot": {"name": "NIGHT_21_NAME", "blurb": "NIGHT_21_BLURB", "verb": "NIGHT_21_VERB", "seconds": 5.0, "colour": "#e0b060", "shape": "toast",
			"story": "NIGHT_21_TALE"}},
	{"size": "large", "shape": "T", "guards": 4, "view": 0.9, "hearing": 1.05, "speed": 0.85, "calm_after": 12.0, "alarms": 2, "props": true, "lights": true, "case_alarm": true, "teach": "", "par": 75,
		"loot": {"name": "NIGHT_22_NAME", "blurb": "NIGHT_22_BLURB", "verb": "NIGHT_22_VERB", "seconds": 5.0, "colour": "#f783ac", "shape": "gum",
			"story": "NIGHT_22_TALE"}},
	{"size": "large", "shape": "T", "guards": 4, "view": 0.95, "hearing": 1.1, "speed": 0.92, "calm_after": 13.0, "alarms": 1, "props": true, "lights": true, "case_alarm": true, "teach": "", "par": 100,
		"loot": {"name": "NIGHT_23_NAME", "blurb": "NIGHT_23_BLURB", "verb": "NIGHT_23_VERB", "seconds": 5.5, "colour": "#f4f1e6", "shape": "teeth",
			"story": "NIGHT_23_TALE"}},
	{"size": "large", "shape": "U", "guards": 4, "view": 1.0, "hearing": 1.1, "speed": 0.95, "calm_after": 13.0, "alarms": 1, "props": true, "lights": true, "case_alarm": true, "teach": "", "par": 110,
		"loot": {"name": "NIGHT_24_NAME", "blurb": "NIGHT_24_BLURB", "verb": "NIGHT_24_VERB", "seconds": 6.0, "colour": "#dee2e6", "shape": "sock",
			"story": "NIGHT_24_TALE"}},
	# The last big job: the Barón's own diamond, five guards wide awake, and
	# the longest way in the story.
	{"size": "large", "shape": "U", "guards": 5, "view": 1.05, "hearing": 1.15, "speed": 1.0, "calm_after": 14.0, "alarms": 1, "props": true, "lights": true, "case_alarm": true, "teach": "finale", "par": 145,
		"boss": true, "tip": "NIGHT_25_TIP",
		"loot": {"name": "NIGHT_25_NAME", "blurb": "NIGHT_25_BLURB", "verb": "NIGHT_25_VERB", "seconds": 6.5, "colour": "#74c0fc", "shape": "gem",
			"story": "NIGHT_25_TALE"}},
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
	"heist3": {"title": "LESSON_HEIST2_TITLE", "stage": "lesson:heist3",
		"text": "LESSON_HEIST3_TEXT"},
	"heist4": {"title": "LESSON_HEIST2_TITLE", "stage": "lesson:heist4",
		"text": "LESSON_HEIST4_TEXT"},
	"guard": {"title": "LESSON_GUARD_TITLE", "stage": "lesson:guard",
		"text": "LESSON_GUARD_TEXT"},
	"torch": {"title": "LESSON_TORCH_TITLE", "stage": "lesson:torch",
		"text": "LESSON_TORCH_TEXT"},
	"noise": {"title": "LESSON_NOISE_TITLE", "stage": "lesson:noise",
		"text": "LESSON_NOISE_TEXT"},
	"props": {"title": "LESSON_PROPS_TITLE", "stage": "lesson:props",
		"text": "LESSON_PROPS_TEXT"},
	# The minigames: the pick at the case, and the knack the rest ask for.
	"games": {"title": "LESSON_GAMES_TITLE", "stage": "lesson:games",
		"text": "LESSON_GAMES_TEXT"},
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

## From this night on, the first in the second museum, there are minigames
## (Minigame, Heist.minigames): the case is picked, the alarm panel's glass
## cut with the suction cup, the pose on a pedestal held on one foot, the
## way into a hideout wriggled and the sneeze in there held in, and the
## arcade machine plays pong. Before it, in the whole first museum, none of
## them: you stand still at the case and hold the panel, and are up on a
## pedestal or in a hideout at once. Its lesson ("games") is the one new
## thing of its night.
const LOCKPICK_NIGHT := 6

## The minigames' level (Minigame.level_now) in each museum, in its rooms
## and on its big job: none in the first (LOCKPICK_NIGHT), then easy, and a
## step harder every museum or so, the big jobs a step ahead of their rooms.
const GAME_LEVEL := [[0, 0], [0, 1], [1, 1], [1, 2], [2, 2]]

const SAVE := "user://progress.cfg"
## where the progress is kept: SAVE, but the tests keep theirs apart
static var save := SAVE

## The town's museums, each a stop on the city map with ROOMS heists
## inside, in order, the last its big job. Each shows one theme (Themes):
## its galleries, its corridors and its pieces. Each has its own floor and
## walls (MuseumView.THEMES keys) to match, and a colour for its stop on
## the map. In the order of time, from the dinosaurs to today: prehistory,
## nature (the living world, still in the old natural-history style), the
## ancient world, the middle ages, and the modern age, the Barón's own tower.
const MUSEUMS := [
	# El Museo de la Prehistoria: rough ochre stone underfoot, clay walls, dark rock below.
	{"name": "MUSEUM_1_NAME", "text": "MUSEUM_1_TEXT", "theme": "prehistoria", "colour": "#d08a3a",
		"palette": {"floor": 0, "stone": Color("#4a3624"), "stone2": Color("#56402a"), "joint": Color("#1e140c"), "gloss": 0.55,
			"paper": Color("#6b3f1f"), "paper2": Color("#7a4a25"), "wallpaper": 0, "wainscot": Color("#3a2a1c"), "dado": 0.4,
			"cap": Color("#6a5a48"), "trim": Color("#c9853a"), "skirt": Color("#120c08")}},
	# El Museo de Ciencias Naturales: oak boards, leafy green damask, like an old
	# natural-history museum.
	{"name": "MUSEUM_2_NAME", "text": "MUSEUM_2_TEXT", "theme": "naturaleza", "colour": "#5cc85c",
		"palette": {"floor": 2, "stone": Color("#3a2a18"), "stone2": Color("#4a3520"), "joint": Color("#120c06"), "gloss": 0.4,
			"paper": Color("#1e4a2c"), "paper2": Color("#285c38"), "wallpaper": 1, "wainscot": Color("#2e2418"), "dado": 0.5,
			"cap": Color("#5a6a4a"), "trim": Color("#c9a34a"), "skirt": Color("#0e1611")}},
	# La Villa de las Antigüedades: sandstone slabs, lapis and gold stripes over
	# terracotta.
	{"name": "MUSEUM_3_NAME", "text": "MUSEUM_3_TEXT", "theme": "antiguo", "colour": "#e8b53a",
		"palette": {"floor": 0, "stone": Color("#6a5638"), "stone2": Color("#78623f"), "joint": Color("#2a200f"), "gloss": 0.35,
			"paper": Color("#1f3a6e"), "paper2": Color("#8a6a2a"), "wallpaper": 2, "wainscot": Color("#7a3a1e"), "dado": 0.45,
			"cap": Color("#8a7650"), "trim": Color("#e8b53a"), "skirt": Color("#1a1208")}},
	# El Museo del Castillo: grey flagstones, crimson tapestry damask,
	# dark oak.
	{"name": "MUSEUM_4_NAME", "text": "MUSEUM_4_TEXT", "theme": "edad_media", "colour": "#d0263e",
		"palette": {"floor": 0, "stone": Color("#3a3a40"), "stone2": Color("#46464e"), "joint": Color("#16161a"), "gloss": 0.4,
			"paper": Color("#5e1222"), "paper2": Color("#74182c"), "wallpaper": 1, "wainscot": Color("#2a1a10"), "dado": 0.55,
			"cap": Color("#6a6470"), "trim": Color("#b08d4a"), "skirt": Color("#0a0808")}},
	# El Museo de Arte Contemporáneo: polished concrete, violet stripes, a pink trim.
	{"name": "MUSEUM_5_NAME", "text": "MUSEUM_5_TEXT", "theme": "moderna", "colour": "#ff4f9a",
		"palette": {"floor": 1, "stone": Color("#3c3c46"), "stone2": Color("#44444f"), "joint": Color("#1c1c22"), "gloss": 0.25,
			"paper": Color("#4a2a5e"), "paper2": Color("#5a3470"), "wallpaper": 2, "wainscot": Color("#1c1c22"), "dado": 0.0,
			"cap": Color("#56534f"), "trim": Color("#ff4f9a"), "skirt": Color("#08070c")}},
]


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
	var reseed := int(LEVELS[clampi(n, 1, LEVELS.size()) - 1].get("reseed", 0))
	return SEED_BASE + n * 7919 + SEED_TEAM * (players - 1) + reseed * SEED_STEP


## The night (1-based) that teaches lesson (LESSONS key), or -1 if none does.
static func lesson_night(lesson: String) -> int:
	for i in LEVELS.size():
		if LEVELS[i].get("teach", "") == lesson:
			return i + 1
	return -1


## What is new on night n, as cards: the one thing the night is built to
## teach. Empty if it teaches nothing new.
static func news(n: int, players := 1) -> Array:
	var teach: String = level(n).get("teach", "")
	if teach == "heist" and players >= 2:
		teach = "heist%d" % mini(players, 4)
	return [Text.fields(LESSONS[teach], ["title", "text"])] if teach != "" else []


## The senses and pace of the guards on night n, as Sim.custom, and the
## theme its museum shows.
static func tuning(n: int) -> Dictionary:
	var l := level(n)
	var game: int = GAME_LEVEL[museum_of(n)][1 if is_boss(n) else 0]
	var out := {"lock": 1.0, "lockpick": n >= LOCKPICK_NIGHT, "game_level": game,
		"theme": MUSEUMS[museum_of(n)].theme}
	for k in ["guards", "view", "hearing", "speed", "calm_after", "alarms", "props", "lights", "case_alarm", "post"]:
		if l.has(k):
			out[k] = l[k]
	return out


## The furthest night reached, saved between sessions: each size of gang
## has its own, since a night done alone is not a night done as four.
## Kept as "robo_<gang>". A save from the story of twenty nights (four to a
## museum, "unlocked_<gang>", and before gangs just "unlocked", the lone
## thief's) is read through from_old: nothing done is lost.
static func unlocked(players := 1) -> int:
	var cfg := ConfigFile.new()
	if cfg.load(save) != OK:
		return 1
	if cfg.has_section_key("story", _key(players)):
		return clampi(int(cfg.get_value("story", _key(players))), 1, LEVELS.size())
	var old: int = cfg.get_value("story", "unlocked", 1) if players == 1 else 1
	old = int(cfg.get_value("story", "unlocked_%d" % clampi(players, 1, 4), old))
	return from_old(old)


static func unlock(n: int, players := 1) -> void:
	if n <= unlocked(players):
		return
	var cfg := ConfigFile.new()
	cfg.load(save)
	cfg.set_value("story", _key(players), clampi(n, 1, LEVELS.size()))
	cfg.save(save)


static func _key(players: int) -> String:
	return "robo_%d" % clampi(players, 1, 4)


## The old story's furthest night (twenty, four to a museum) as a heist of
## this one: every museum done there is a museum done here, and the nights
## done in the one under way are as many rooms done in its match. Night 5
## (the first museum done) is heist 6; night 20 (three done in the last)
## is heist 24.
static func from_old(night: int) -> int:
	var done := clampi(night, 1, 20) - 1
	return mini((done / 4) * ROOMS + done % 4 + 1, LEVELS.size())


# --- Stars -----------------------------------------------------------------------

## Each heist of the story gives up to three stars, Overcooked style, each
## its own goal, as bits of a mask:
##   STAR_TAKEN   out of the door with the piece: the heist done;
##   STAR_UNSEEN  no guard saw anyone of the gang, the whole night through
##                (HeistStats "seen" at 0: heard is fine, seen is not);
##   STAR_FAST    out under the heist's par (par): its "par" in LEVELS, a
##                gang's a little longer (GANG_PAR).
## A star once won stays won: the best is kept for each heist and each size
## of gang, as a mask, so a worse go never takes one away, and two goes can
## win two different stars (keep_stars). Only the story has them; nothing
## waits on them: the next museum opens with the big job, as ever.
##
## For the screens:
##   Story.stars(7)          -> 2      the best of heist 7, alone, as a count
##   Story.star_mask(7)      -> 0b011  and which (STAR_TAKEN | STAR_UNSEEN)
##   Story.stars_in(1, 2)    -> 11     museum 2 (0-based m = 1), for two
##   Story.STARS_EACH * Story.ROOMS    the most a museum gives (15)
##   Story.par(7)            -> 25.0   seconds for the fast star, alone
##   Story.goals(7)          -> ["Roba la pieza", "Sin que te vean",
##                               "En menos de 0:25"]   (STARS order)
## And after a go, what it won and what was new: HeistStats.rate (the
## paper's stars, EndPages.newspaper).
const STAR_TAKEN := 1
const STAR_UNSEEN := 2
const STAR_FAST := 4
## The three, in the order they are shown.
const STARS := [STAR_TAKEN, STAR_UNSEEN, STAR_FAST]
const STARS_EACH := 3
## How much longer a gang has for the fast star: everyone has to get out,
## and a gang shares out the job (the alarm panel).
const GANG_PAR := {1: 1.0, 2: 1.2, 3: 1.35, 4: 1.5}


## The seconds heist n has for the fast star, for this many thieves: its
## "par", measured with a bot on the game itself (tools: tiempos.gd, the
## quickest way past the guards, times 1.75, rounded up to 5 s); a gang's,
## GANG_PAR times that, rounded up to 5 s too.
static func par(n: int, players := 1) -> float:
	var base := float(LEVELS[clampi(n, 1, LEVELS.size()) - 1].par)
	return ceilf(base * GANG_PAR[clampi(players, 1, 4)] / 5.0) * 5.0


## The stars a go at heist n wins (a STARS mask): escaped, seen (how many
## times a guard spotted the gang, HeistStats "seen") and how long it took.
## Caught, none: the other two only count with the piece out.
static func earned(n: int, escaped: bool, seen: int, seconds: float, players := 1) -> int:
	if not escaped:
		return 0
	var mask := STAR_TAKEN
	if seen == 0:
		mask |= STAR_UNSEEN
	if seconds <= par(n, players):
		mask |= STAR_FAST
	return mask


## How many stars there are in a mask.
static func count_stars(mask: int) -> int:
	var k := 0
	for s in STARS:
		if mask & s:
			k += 1
	return k


## The best of heist n for this many thieves, as a mask (STARS): every star
## ever won there. 0 if never done.
static func star_mask(n: int, players := 1) -> int:
	var all := _star_masks(players)
	return all[n - 1] if n >= 1 and n <= all.size() else 0


## The best of heist n for this many thieves: 0 to 3 stars.
static func stars(n: int, players := 1) -> int:
	return count_stars(star_mask(n, players))


## The stars won in museum m (0-based), for this many thieves: 0 to 15.
static func stars_in(m: int, players := 1) -> int:
	var total := 0
	for n in nights_in(clampi(m, 0, MUSEUMS.size() - 1)):
		total += stars(n, players)
	return total


## Keeps the stars a go at heist n won (mask) with the ones won before: a
## star once won is never lost. Returns the ones that are new.
static func keep_stars(n: int, players: int, mask: int) -> int:
	if n < 1 or n > LEVELS.size():
		return 0
	var all := _star_masks(players)
	var fresh := mask & ~all[n - 1]
	if fresh == 0:
		return 0
	all[n - 1] |= mask
	var cfg := ConfigFile.new()
	cfg.load(save)
	cfg.set_value("stars", _key(players), all)
	cfg.save(save)
	return fresh


## The three goals of heist n, short, for the screen before it, in STARS
## order: "Roba la pieza", "Sin que te vean", "En menos de 1:30".
static func goals(n: int, players := 1) -> Array[String]:
	var many := "_MANY" if players > 1 else "_ONE"
	var secs := int(par(n, players))
	return [Text.t("STAR_GOAL_TAKEN" + many), Text.t("STAR_GOAL_UNSEEN" + many),
		Text.t("STAR_GOAL_FAST") % ("%d:%02d" % [secs / 60, secs % 60])]


## Every heist's best mask for this many thieves, kept in the progress
## beside how far it got ("stars", "robo_<gang>"): one a heist, 0 for none.
static func _star_masks(players: int) -> Array[int]:
	var out: Array[int] = []
	out.resize(LEVELS.size())
	out.fill(0)
	var cfg := ConfigFile.new()
	if cfg.load(save) != OK:
		return out
	var kept: Variant = cfg.get_value("stars", _key(players), [])
	if kept is Array or kept is PackedInt32Array or kept is PackedInt64Array:
		for i in mini(kept.size(), out.size()):
			out[i] = int(kept[i]) & (STAR_TAKEN | STAR_UNSEEN | STAR_FAST)
	return out


# --- Museums ---------------------------------------------------------------------

## The museum (0-based, MUSEUMS) night n is in.
static func museum_of(n: int) -> int:
	return clampi((n - 1) / ROOMS, 0, MUSEUMS.size() - 1)


## Night n's room in its museum, 1 to ROOMS (the last, the big job).
static func room_of(n: int) -> int:
	return (clampi(n, 1, LEVELS.size()) - 1) % ROOMS + 1


## Whether night n is its museum's big job, the last of its rooms.
static func is_boss(n: int) -> bool:
	return bool(LEVELS[clampi(n, 1, LEVELS.size()) - 1].get("boss", false))


## The nights (1-based) inside museum m, in order.
static func nights_in(m: int) -> Array[int]:
	var out: Array[int] = []
	for n in range(m * ROOMS + 1, m * ROOMS + ROOMS + 1):
		out.append(n)
	return out


## Museum m, its name and blurb in words.
static func museum(m: int) -> Dictionary:
	return Text.fields(MUSEUMS[clampi(m, 0, MUSEUMS.size() - 1)], ["name", "text"])


## Museum m's name as it goes after "en" or "de": "el Museo de la Prehistoria".
static func museum_in(m: int) -> String:
	var name: String = museum(m).name
	return name.left(1).to_lower() + name.substr(1)


## The floor and walls of night n's museum (MuseumView.THEMES keys).
static func palette(n: int) -> Dictionary:
	return MUSEUMS[museum_of(n)].palette


## The theme (Themes) night n's museum shows, in every gallery.
static func theme(n: int) -> String:
	return MUSEUMS[museum_of(n)].theme
