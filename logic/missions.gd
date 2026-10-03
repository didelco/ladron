class_name Missions
extends RefCounted
## The missions: each challenge map (MapFile) proposes a robbery with its own
## story, a piece to steal (MapFile.loot) and a gift (MapFile.gift). The gift
## is the player's the first time the piece is got away with, and goes to the
## inventory; doing the mission again gives nothing more.
##
## The inventory is kept with the rest of the progress (Story.save, section
## "missions"): the keys of the missions done, and the gifts won in the order
## they came, each {mission, name, shape, colour}. A mission's key is its
## name's slug (MapFile.slug), so it is the same for a map's file and the
## player's copy of it.

const SECTION := "missions"


## The key a mission is kept under.
static func key_of(m: MapFile) -> String:
	return MapFile.slug(m.name)


## Whether the mission has been done (the piece got away with) before.
static func is_done(m: MapFile) -> bool:
	return key_of(m) in _read("done", [])


## The gifts in the inventory: [{mission, name, shape, colour}].
static func inventory() -> Array:
	var out: Array = []
	for g in _read("gifts", []):
		if g is Dictionary:
			out.append(g)
	return out


## The mission's piece in words: what its maker called it, or its shape's name.
static func piece_name(m: MapFile) -> String:
	return String(m.loot_piece().get("name", "")) if not m.loot.is_empty() else Text.t("MISSION_PIECE_ANY")


## The mission's story: its maker's, or the plain one.
static func story_of(m: MapFile) -> String:
	var s := String(m.loot.get("story", ""))
	return s if s != "" else Text.t("MISSION_STORY_DEFAULT") % m.name


## The gift for the mission: its maker's, or a replica of the piece.
static func gift_of(m: MapFile) -> Dictionary:
	var g: Dictionary = m.gift
	var shape := String(g.get("shape", m.loot.get("shape", "gem")))
	var name_ := String(g.get("name", ""))
	if name_ == "":
		name_ = Text.t("MISSION_GIFT_DEFAULT") % piece_name(m)
	return {"mission": key_of(m), "name": name_, "shape": shape, "colour": String(g.get("colour", m.loot.get("colour", "#f0c46a")))}


## The mission got away with: the gift if it is the first time (kept at once),
## else an empty dictionary.
static func complete(m: MapFile) -> Dictionary:
	if is_done(m):
		return {}
	var gift := gift_of(m)
	var done: Array = _read("done", [])
	done.append(key_of(m))
	var gifts := inventory()
	gifts.append(gift)
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	cfg.set_value(SECTION, "done", done)
	cfg.set_value(SECTION, "gifts", gifts)
	cfg.save(Story.save)
	return gift


static func _read(what: String, fallback: Variant) -> Variant:
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	var v: Variant = cfg.get_value(SECTION, what, fallback)
	return v if v is Array else fallback
