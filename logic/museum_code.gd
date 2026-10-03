class_name MuseumCode
extends RefCounted
## The Atraco Sorpresa museum's shareable code: one plain run of letters and
## digits (base 36), seed and size and theme folded into the same number —
## shorter to type or read aloud than a seed plus two words. Difficulty and
## the number of thieves stay out: they do not change the museum itself
## (Game._lay_out calls Sim.new_map before either of them is looked at),
## only what is layered on top of it.
##
## Four characters, on purpose: size and theme already make each seed a
## different museum, so the code does not need a huge seed range on top —
## a million and a half codes (36^4) is plenty. Game._lay_out's own
## generative seed is drawn from MAX_SEED + 1, not a bigger range, so every
## seed it ever picks always has a code (Main.gd, the "else" of _new_round).

## Game.SIZE_NAMES' and Game.THEME_NAMES' own keys, in their order.
const SIZES := ["small", "medium", "large"]
const THEMES := ["", "antiguo", "edad_media", "prehistoria", "naturaleza", "moderna"]
const COMBO_COUNT := 18 # SIZES.size() * THEMES.size(), a const needs the literal

const BASE36 := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
const CODE_DIGITS := 4
## floor((36^CODE_DIGITS - 1 - (COMBO_COUNT - 1)) / COMBO_COUNT): the
## biggest seed whose combo still fits under 36^CODE_DIGITS. A literal
## because consts can't call pow() here.
const MAX_SEED := 93311


## The code for a museum, e.g. "7K3F". "" if size or theme is not one of
## Game's own keys.
static func encode(map_seed: int, size: String, theme: String) -> String:
	var size_i := SIZES.find(size)
	var theme_i := THEMES.find(theme)
	if size_i < 0 or theme_i < 0:
		return ""
	var combo := theme_i * SIZES.size() + size_i
	var n := clampi(map_seed, 0, MAX_SEED) * COMBO_COUNT + combo
	return _to_base36(n)


## The museum a code points to: {"seed": int, "size": String, "theme":
## String}, or {} if the code does not parse (letters outside A-Z0-9, or a
## number out of range).
static func decode(code: String) -> Dictionary:
	var digits := code.strip_edges().to_upper().replace("-", "")
	if digits.length() != CODE_DIGITS:
		return {}
	var n := _from_base36(digits)
	if n < 0:
		return {}
	var combo := n % COMBO_COUNT
	var map_seed := n / COMBO_COUNT
	if map_seed > MAX_SEED:
		return {}
	return {
		"seed": map_seed,
		"size": SIZES[combo % SIZES.size()],
		"theme": THEMES[combo / SIZES.size()],
	}


static func _to_base36(n: int) -> String:
	var out := "" if n > 0 else "0"
	while n > 0:
		out = BASE36[n % 36] + out
		n /= 36
	return out.lpad(CODE_DIGITS, "0")


## -1 for anything outside A-Z0-9 (not a digit of base36).
static func _from_base36(s: String) -> int:
	var n := 0
	for c in s:
		var digit := BASE36.find(c)
		if digit < 0:
			return -1
		n = n * 36 + digit
	return n
