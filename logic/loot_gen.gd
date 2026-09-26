class_name LootGen
extends RefCounted
## A piece and its tale for a night nobody wrote: the generative mode, or a
## saved map that leaves the piece to the game. Like the story's, it is
## something the Barón Von Bostezo took from someone in town, and the Banda
## del Calcetín takes it back.
##
## Put together from parts, all keys into Text: a thing (one of LootModels'
## shapes, with its names, blurbs, verb and funny details), whose it was
## (OWNERS), and a tale in three lines — how the Barón took it (HOW), what
## has gone wrong since (SINCE) and the detail. The same seed, the same piece.

## Per shape: how many nouns, blurbs and details it has in Text
## (GEN_<SHAPE>_NOUN_1...), the colours it comes in and how long its lock
## takes on a first night.
const PIECES := {
	"teeth": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 2.5, "colours": ["#f4f1e6", "#ffd43b", "#ffc9c9"]},
	"duck": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 2.5, "colours": ["#ffd43b", "#339af0", "#ff8787"]},
	"sock": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.0, "colours": ["#ff6b6b", "#dee2e6", "#74c0fc", "#b197fc"]},
	"toast": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 2.5, "colours": ["#d4a15a", "#e8b86d"]},
	"crown": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.5, "colours": ["#f0c46a", "#7bc043", "#fcc419"]},
	"rock": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.5, "colours": ["#ffe066", "#f783ac", "#9aa3b5"]},
	"mask": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.5, "colours": ["#3ddc84", "#9b5de5", "#e03131"]},
	"clock": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.0, "colours": ["#e8590c", "#4dabf7", "#ffd43b"]},
	"egg": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.0, "colours": ["#e8c89a", "#8b5a2b", "#fcc419", "#63e6be"]},
	"gem": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.5, "colours": ["#5b8cff", "#ff6b6b", "#63e6be", "#ffec99"]},
	"idol": {"nouns": 3, "blurbs": 2, "details": 2, "seconds": 3.5, "colours": ["#b07cff", "#fcc419", "#e03131"]},
}

## How many owners (GEN_OWNER_n_WHO, "la abuela Remedios", and _OF, "de la
## abuela Remedios"), and how many of each line of the tale.
const OWNERS := 12
const HOW := 6
const SINCE := 6

## A run of heists gets slower locks: this much more each night, up to MAX_EXTRA.
const STEP := 0.5
const MAX_EXTRA := 3.0


## The piece for a heist: from its seed, on night n of a run (1-based).
## shape: that one, instead of the seed's.
static func make(seed: int, n := 1, shape := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed)
	var shapes: Array = PIECES.keys()
	var pick: String = shapes[rng.randi_range(0, shapes.size() - 1)]
	if shape != "":
		pick = shape
	var p: Dictionary = PIECES[pick]
	var key := "GEN_" + pick.to_upper()
	var owner := rng.randi_range(1, OWNERS)
	var thing := Text.t("%s_NOUN_%d" % [key, rng.randi_range(1, p.nouns)])
	var name := "%s %s" % [thing, Text.t("GEN_OWNER_%d_OF" % owner)]
	# The name already says whose it is: the tale names the owner and the thing apart.
	var words := {"thing": thing, "who": Text.t("GEN_OWNER_%d_WHO" % owner)}
	var tale := [
		Text.t("GEN_HOW_%d" % rng.randi_range(1, HOW)).format(words),
		Text.t("GEN_SINCE_%d" % rng.randi_range(1, SINCE)).format(words),
		Text.t("%s_DETAIL_%d" % [key, rng.randi_range(1, p.details)]),
	]
	var colours: Array = p.colours
	return {
		"name": name,
		"blurb": Text.t("%s_BLURB_%d" % [key, rng.randi_range(1, p.blurbs)]),
		"verb": Text.t(key + "_VERB"),
		"seconds": p.seconds + minf((n - 1) * STEP, MAX_EXTRA),
		"colour": colours[rng.randi_range(0, colours.size() - 1)],
		"shape": pick,
		"story": " ".join(tale),
	}


## One piece of every shape, to look at (the assets screen).
static func samples() -> Array:
	var out: Array = []
	for k in PIECES.size():
		out.append(make(k, 1, PIECES.keys()[k]))
	return out
