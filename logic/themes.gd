class_name Themes
extends RefCounted
## The collection by themes. Each gallery of a museum takes one theme (or a
## whole museum just one, only), and what stands and hangs in it comes from
## that theme: what goes in the glass cases, what stands on a plinth, what
## stands on the floor, which paintings, and the big piece it would rather
## have. Corridors show a little of everything.
##
## A piece is a model under assets/models/ ("temas/antiguo/escarabajo",
## modelled by art/temas/*.py) or, with an @, one of the pieces MuseumView
## builds itself ("@butterflies": MuseumView.EXHIBITS). Paintings are kinds
## of canvas (Canvases).
##
## Five themes, and no more: the ancient world (Egypt, Greece and Rome), the
## middle ages (with the gothic, the Renaissance and Leonardo), prehistory (dinosaurs and early people), nature (animals,
## plants and trees, life under water) and the modern age — contemporary art
## and everyday things of today shown as museum pieces: a telly, a toaster.

const ALL := {
	"antiguo": {
		"gallery": ["the ancient world gallery", "GALLERY_ANCIENT"],
		"case": ["temas/antiguo/escarabajo", "temas/antiguo/canopos", "temas/antiguo/amuletos", "temas/antiguo/papiro"],
		"plinth": ["temas/antiguo/busto_faraon", "temas/antiguo/gato_bastet", "temas/antiguo/obelisco", "@amphora", "@statue"],
		"floor": ["temas/antiguo/anubis", "temas/antiguo/barca"],
		"paintings": ["pyramids", "hieroglyphs", "nile"],
		"big": "sarcophagus",
	},
	"edad_media": {
		"gallery": ["the medieval hall", "GALLERY_MEDIEVAL"],
		# Castles and knights, the gothic, the Renaissance and Leonardo's inventions.
		"case": ["temas/edad_media/corona", "temas/edad_media/caliz", "temas/edad_media/manuscrito", "temas/edad_media/llave_sello",
			"temas/edad_media/codice_leonardo", "temas/edad_media/astrolabio"],
		"plinth": ["temas/edad_media/yelmo", "temas/edad_media/escudo", "temas/edad_media/castillo", "temas/edad_media/gargola",
			"temas/edad_media/carro_blindado"],
		"floor": ["temas/edad_media/espada_piedra", "temas/edad_media/trono", "temas/edad_media/maquina_voladora", "temas/edad_media/vidriera"],
		"paintings": ["castle", "dragon", "tapestry", "gioconda", "vitruvian"],
	},
	"prehistoria": {
		"gallery": ["the prehistory gallery", "GALLERY_PREHISTORY"],
		"case": ["@ammonite", "@minerals", "@meteorite"],
		"plinth": ["@skull"],
		"floor": [],
		"paintings": ["landscape"],
		"big": "dinosaur",
	},
	# Animals, plants and trees, and life under water.
	"naturaleza": {
		"gallery": ["the natural history gallery", "GALLERY_NATURE"],
		"case": ["@butterflies"],
		"plinth": ["@bear"],
		"floor": ["@diorama"],
		"paintings": ["landscape"],
	},
	"moderna": {
		"gallery": ["the modern age gallery", "GALLERY_MODERN"],
		"case": [],
		"plinth": ["@lego_skull"],
		"floor": ["@globe", "@totem"],
		"paintings": ["abstract", "pipe", "banana", "ice_cream", "portrait"],
	},
}

## Of what stands on a case in a themed gallery, this much is in a glass
## case, this much on a plinth; the rest on the floor.
const CASE_SHARE := 0.45
const PLINTH_SHARE := 0.35


## The themes in their order.
static func ids() -> Array:
	return ALL.keys()


## The gallery's name for a theme: [English, key into Text].
static func gallery(theme: String) -> Array:
	return ALL[theme].gallery


## The theme that wants this big piece ("dinosaur", "sarcophagus"), or "".
static func for_big(kind: String) -> String:
	for id in ALL:
		if ALL[id].get("big", "") == kind:
			return id
	return ""


## What stands on a case in a gallery of this theme ("" for a corridor: a
## bit of everything), from two numbers in 0..1 (the tile's hashes):
## [where, piece] with where "case", "plinth" or "floor".
static func pick(theme: String, a: float, b: float) -> Array:
	var sets: Array = [ALL[theme]] if theme != "" else ALL.values()
	var case: Array = []
	var plinth: Array = []
	var floor_: Array = []
	for s in sets:
		case.append_array(s.case)
		plinth.append_array(s.plinth)
		floor_.append_array(s.floor)
	# The share of each place, among the places this theme has pieces for.
	var shares := [[CASE_SHARE, "case", case], [PLINTH_SHARE, "plinth", plinth], [1.0 - CASE_SHARE - PLINTH_SHARE, "floor", floor_]]
	shares = shares.filter(func(s): return not (s[2] as Array).is_empty())
	var total := 0.0
	for s in shares:
		total += s[0]
	var at := a * total
	for s in shares:
		if at < s[0] or s == shares[-1]:
			var list: Array = s[2]
			return [s[1], list[mini(int(b * list.size()), list.size() - 1)]]
		at -= s[0]
	return ["case", "@minerals"]


## A kind of painting for a wall of this theme's gallery ("" for a corridor).
static func painting(theme: String, a: float) -> String:
	var kinds: Array = []
	if theme != "":
		kinds = ALL[theme].paintings
	else:
		for s in ALL.values():
			kinds.append_array(s.paintings)
	return kinds[mini(int(a * kinds.size()), kinds.size() - 1)]


# --- The pieces one by one (the editor's catalogue) ------------------------------

## What the thieves knock over, and the big pieces, by theme ("" for none).
const PROP_THEMES := {"bust": "antiguo", "armour": "edad_media", "bin": "", "panel": ""}


## Every piece there is, in order, as the editor's tools name them —
## "exhibit:<MuseumView's own>", "exhibit:<model path>", "big:<kind>",
## "prop:<kind>" — each with the themes it belongs to: [[tool, [themes]]].
static func catalogue() -> Array:
	var out: Array = [["case", []]]
	var at := {}
	for id in ALL:
		var s: Dictionary = ALL[id]
		for where in ["case", "plinth", "floor"]:
			for piece in s[where]:
				var tool := "exhibit:" + String(piece).trim_prefix("@")
				if at.has(tool):
					(out[at[tool]][1] as Array).append(id)
				else:
					at[tool] = out.size()
					out.append([tool, [id]])
	for kind in MapGen.BIG:
		var theme := for_big(kind)
		out.append(["big:" + kind, [theme] if theme != "" else []])
	for kind in PROP_THEMES:
		out.append(["prop:" + kind, [PROP_THEMES[kind]] if PROP_THEMES[kind] != "" else []])
	return out


## Whether a map may stand this on a case: one of MuseumView's own pieces or
## a theme's model.
static func is_piece(kind: String) -> bool:
	if MuseumView.EXHIBITS.has(kind):
		return true
	for s in ALL.values():
		for where in ["case", "plinth", "floor"]:
			if (s[where] as Array).has(kind):
				return true
	return false


## Where a theme's model stands: "case", "plinth" or "floor".
static func where_of(path: String) -> String:
	for s in ALL.values():
		for where in ["case", "plinth", "floor"]:
			if (s[where] as Array).has(path):
				return where
	return "case"


## A piece's name on screen: MuseumView's own have theirs in the editor's
## words, a model's is PIECE_<its file name>.
static func label(kind: String) -> String:
	if "/" in kind:
		return Text.t("PIECE_" + kind.get_file().to_upper())
	return Text.t("EDITOR_TOOL_EXHIBIT_" + kind.to_upper())
