class_name Text
extends RefCounted
## All the words the player sees live in locale/texts.csv, a column per
## language: a key (MENU_*, HUD_*, NIGHT_01_NAME...) and its text in each.
## Godot imports the CSV into a translation per column (texts.<locale>.
## translation, next to it); setup() loads ours and makes it the one in use.
##
## Code asks for Text.t("KEY"), and fills in the blanks with % as usual:
## Text.t("MENU_NIGHT_PIECE") % [n, name]. Data tables (Story, Heist.LOOT,
## Props.NAMES, Museum.GALLERIES, Mind's labels) hold keys, translated where
## they are read. A new language is a new column, and LOCALE pointing at it.

const LOCALE := "es"
const FOLDER := "res://locale/texts.%s.translation"

static var _loaded := false


## Load the language and switch to it: before anything builds any text. Also
## done by itself on the first t(), so scripts without the game (the tests)
## get words too. Only the first call does anything.
static func setup() -> void:
	if _loaded:
		return
	_loaded = true
	var tr_res := load(FOLDER % LOCALE) as Translation
	if tr_res == null:
		push_error("Text: no translation for %s" % LOCALE)
		return
	TranslationServer.add_translation(tr_res)
	TranslationServer.set_locale(LOCALE)


## The words for a key, in the language in use (the key itself if missing).
static func t(key: String) -> String:
	if not _loaded:
		setup()
	return String(TranslationServer.translate(key))


## A copy of a dictionary with these fields (keys into Text) in words.
static func fields(d: Dictionary, which: Array) -> Dictionary:
	var out := d.duplicate()
	for f in which:
		if out.has(f):
			out[f] = t(out[f])
	return out
