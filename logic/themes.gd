class_name Themes
extends RefCounted
## The collection by themes. Each gallery of a museum takes one theme (or a
## whole museum just one, only), and what stands and hangs in it comes from
## that theme: what goes in the glass cases, what stands on a plinth, what
## stands on the floor, which paintings, and the big piece it would rather
## have. Corridors show a little of everything.
##
## The glass cases show nothing detailed: bright, simple things in the
## theme's colours ("@colours": MuseumView._colours), that read from the
## camera as spots of colour; the detailed pieces stand out in the open, on
## plinths and on the floor, so the two never look alike.
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
		"case": ["@colours"],
		"plinth": ["temas/antiguo/busto_faraon", "temas/antiguo/gato_bastet", "temas/antiguo/obelisco", "@amphora", "@statue",
			"temas/antiguo/escarabajo", "temas/antiguo/canopos", "temas/antiguo/amuletos", "temas/antiguo/papiro"],
		# Gold, turquoise, lapis lazuli, terracotta; linen under them.
		"colours": ["#e8b53a", "#2ec4b6", "#2f5fd0", "#d2643c"],
		"cloth": "#e6dcc2",
		"floor": ["temas/antiguo/anubis", "temas/antiguo/barca"],
		"paintings": ["pyramids", "hieroglyphs", "nile"],
		"big": ["sarcophagus", "trojan_horse"],
	},
	"edad_media": {
		"gallery": ["the medieval hall", "GALLERY_MEDIEVAL"],
		# Castles and knights, the gothic, the Renaissance and Leonardo's inventions.
		"case": ["@colours"],
		"plinth": ["temas/edad_media/yelmo", "temas/edad_media/escudo", "temas/edad_media/castillo", "temas/edad_media/gargola",
			"temas/edad_media/carro_blindado", "temas/edad_media/corona", "temas/edad_media/caliz", "temas/edad_media/manuscrito",
			"temas/edad_media/llave_sello", "temas/edad_media/codice_leonardo", "temas/edad_media/astrolabio"],
		# Ruby, gold, silver, emerald; on crimson velvet.
		"colours": ["#d0263e", "#e8b53a", "#d6dbe4", "#23a861"],
		"cloth": "#6a1f2e",
		"floor": ["temas/edad_media/espada_piedra", "temas/edad_media/trono", "temas/edad_media/maquina_voladora", "temas/edad_media/vidriera"],
		"paintings": ["castle", "dragon", "tapestry", "gioconda", "vitruvian"],
	},
	"prehistoria": {
		"gallery": ["the prehistory gallery", "GALLERY_PREHISTORY"],
		"case": ["@colours", "@minerals"],
		"plinth": ["@skull", "@ammonite", "@meteorite"],
		# Ochre, bone, amber, flint; on sand.
		"colours": ["#d08a3a", "#efe3c8", "#f4a81c", "#4a4452"],
		"cloth": "#b89a6a",
		"floor": [],
		"paintings": ["landscape"],
		"big": ["dinosaur", "mammoth"],
	},
	# Animals, plants and trees, and life under water.
	"naturaleza": {
		"gallery": ["the natural history gallery", "GALLERY_NATURE"],
		"case": ["@colours", "@butterflies"],
		"plinth": [],
		# Leaf, blossom, sky, sunflower; on moss.
		"colours": ["#5cc85c", "#ff6fa8", "#5ac8fa", "#ffd23f"],
		"cloth": "#2e4a2a",
		"floor": ["@diorama"],
		"paintings": ["wildlife"],
		"big": ["bear", "log"],
	},
	"moderna": {
		"gallery": ["the modern age gallery", "GALLERY_MODERN"],
		"case": ["@colours"],
		"plinth": ["@lego_skull", "temas/moderna/tele", "temas/moderna/tostadora", "temas/moderna/rubik", "temas/moderna/perro_globo"],
		# Pop: pink, cyan, yellow, violet; on white.
		"colours": ["#ff4f9a", "#00c2d8", "#ffd400", "#8a4dff"],
		"cloth": "#f2f2f2",
		"floor": ["@globe", "@totem", "temas/moderna/recreativa", "temas/moderna/movil_calder", "temas/moderna/semaforo"],
		"paintings": ["abstract", "pipe", "banana", "ice_cream", "portrait"],
		"big": ["car"],
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


## The column (MapFile.columns, MuseumView's exempt pillar) a theme's gallery
## stands: the ancient world's fluted "dorica", the middle ages' compound
## "gotica", prehistory's squared brown megalith ("piedra", in the same
## ochre-and-flint browns as Themes.ALL.prehistoria's own palette), nature's
## wooden post ("madera" — a trunk fits its groves and dioramas). The modern
## age keeps the bare-concrete "moderno" (a raw Ando-style tube reads fine
## as "no style at all" there), and so does no theme at all (a corridor, or
## the band's house, Den, which is wood throughout already).
const COLUMN_STYLES := {"antiguo": "dorica", "edad_media": "gotica", "naturaleza": "madera", "prehistoria": "piedra"}


## The column style (MuseumView._column's looks) a gallery of this theme
## stands ("" for a corridor or the band's house: the plain one, "moderno").
static func column_style(theme: String) -> String:
	return COLUMN_STYLES.get(theme, "moderno")


## The theme that wants this big piece ("dinosaur", "sarcophagus"), or "".
static func for_big(kind: String) -> String:
	for id in ALL:
		if kind in ALL[id].get("big", []):
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


# --- How many of a piece one museum shows (Collection) ----------------------------

## The icons: a museum has one at most, as a second would be a copy. Big
## pieces by their kind (BigPieces.SIZES), the rest by their model. Every piece
## not here nor in VARIANTS may stand any number of times.
const UNIQUE := ["dinosaur", "trojan_horse", "temas/edad_media/espada_piedra", "temas/edad_media/trono",
	"temas/edad_media/maquina_voladora"]
## The pieces where every copy is really something different: several may
## stand in one museum, each a different variant, never the same one twice;
## once they are all out, the place gets another piece. The arcade machine,
## one game each (MuseumView.ARCADE_GAMES has how each looks; you play pong
## on all of them, Arcades).
const VARIANTS := {"temas/moderna/recreativa": ["tenis", "invasores", "comecocos", "bloques", "serpiente", "carreras"]}


static func is_unique(piece: String) -> bool:
	return piece in UNIQUE


## A piece's variants, or none.
static func variants(piece: String) -> Array:
	return VARIANTS.get(piece, [])


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


## The kinds of piece, as the editor filters them: in a glass case, small
## (on a plinth), big (on the floor, or on a block of cases), what the
## thieves knock over, and what they hide in (Hideouts.PIECES).
const TYPES := ["case", "small", "big", "prop", "hide"]


## Every piece there is, in order, as the editor's tools name them —
## "exhibit:<MuseumView's own>", "exhibit:<model path>", "big:<kind>",
## "prop:<kind>" — each with the themes it belongs to and its type (TYPES):
## [[tool, [themes], type]].
static func catalogue() -> Array:
	var out: Array = [["case", [], "case"]]
	var type_of := {"case": "case", "plinth": "small", "floor": "big"}
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
					out.append([tool, [id], type_of[where]])
	# The empty pedestal a thief poses on (Plinths): no theme's, any gallery's.
	out.append(["exhibit:plinth", [], "small"])
	# The furniture a thief hides in (Hideouts), each its theme's.
	for kind in Hideouts.PIECES:
		out.append(["exhibit:" + kind, [Hideouts.PIECES[kind].theme], "hide"])
	for kind in BigPieces.SIZES:
		var theme := for_big(kind)
		out.append(["big:" + kind, [theme] if theme != "" else [], "big"])
	for kind in PROP_THEMES:
		out.append(["prop:" + kind, [PROP_THEMES[kind]] if PROP_THEMES[kind] != "" else [], "prop"])
	return out


## Whether a map may stand this on a case: one of MuseumView's own pieces or
## a theme's model.
static func is_piece(kind: String) -> bool:
	if MuseumView.EXHIBITS.has(kind) or Hideouts.PIECES.has(kind):
		return true
	for s in ALL.values():
		for where in ["case", "plinth", "floor"]:
			if (s[where] as Array).has(kind):
				return true
	return false


## Where a theme's model stands: "case", "plinth" or "floor".
## The floor pieces with a front that must not face a wall: a screen, a
## seat, a face. MuseumView turns them to the free floor beside them, and a
## place with none gets another piece.
const FRONTED := ["temas/moderna/recreativa", "temas/edad_media/trono", "temas/antiguo/anubis"]


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
