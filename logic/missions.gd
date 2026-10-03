class_name Missions
extends RefCounted
## The missions: robberies the game itself proposes, written beforehand like
## the story and opening as the story goes (AFTER): each is one of the game's
## own maps (MapFile, res://maps) with its story, a piece to steal
## (MapFile.loot) and a gift (MapFile.gift). The gift is the player's the
## first time the piece is got away with, and goes to the inventory; doing the
## mission again gives nothing more.
##
## The maps the player makes, imports or downloads, and the surprise heists,
## are outside the story: they are not missions, have no story of their own
## and never give anything.
##
## A mission is offered by a phone call while the band is at home (PhoneCall):
## the first open one that has not rung yet rings. Once it has rung, whether it
## was picked up or not, it is "called": it is in the Missions menu (pending
## until it is done), to look at and play whenever one wants, and the phone
## does not ring for it again. The ones done before the calls existed count as
## called. In the developer's mode nothing rings and everything is listed.
##
## The inventory is kept with the rest of the progress (Story.save, section
## "missions"): the keys of the missions done, and the gifts won in the order
## they came, each {mission, name, shape, colour}. A mission's key is its
## map's file name.

const SECTION := "missions"

## The missions, by their map's file name, and the story's heist that has to
## be done for each to open (its museum's big job): the fossils after the
## first museum, the busts after the third, the Barón's cross after the fourth.
const AFTER := {"ala_de_los_fosiles": 5, "galeria_de_los_bustos": 15, "cruz_del_baron": 20}


## The key a mission is kept under: its map's file name, "" for a map that
## is not the game's own.
static func key_of(m: MapFile) -> String:
	return m.path.get_file().get_basename() if m.built_in and m.night == 0 else ""


## Whether the map is one of the missions, not a map of the player's.
static func is_mission(m: MapFile) -> bool:
	return AFTER.has(key_of(m))


## The story's heist that opens the mission (AFTER).
static func opens_after(m: MapFile) -> int:
	return int(AFTER.get(key_of(m), 0))


## Whether the mission is open: its heist of the story done, by a gang of any
## size (Story.unlocked is the next heist to do; the last one done counts by
## its stars).
static func is_open(m: MapFile) -> bool:
	var n := opens_after(m)
	for players in range(1, 5):
		if Story.unlocked(players) > n or Story.stars(n, players) > 0:
			return true
	return false


## Whether the mission has been done (the piece got away with) before.
static func is_done(m: MapFile) -> bool:
	return is_mission(m) and key_of(m) in _read("done", [])


## Whether the mission has rung (picked up or not) or been done.
static func is_called(m: MapFile) -> bool:
	return is_mission(m) and (key_of(m) in _read("called", []) or is_done(m))


## The mission's phone has rung: from now on it is listed, and it does not ring
## again. Nothing is kept in the developer's mode.
static func mark_called(m: MapFile) -> void:
	if Story.dev or not is_mission(m) or is_called(m):
		return
	var called: Array = _read("called", [])
	called.append(key_of(m))
	var cfg := ConfigFile.new()
	cfg.load(Story.save)
	cfg.set_value(SECTION, "called", called)
	cfg.save(Story.save)


## The mission that rings next: the first of AFTER's order that the story has
## opened and that has not rung; null when none (or in the developer's
## mode).
static func pending_call() -> MapFile:
	if Story.dev:
		return null
	for key in AFTER:
		var m := MapFile.read("res://maps/%s.json" % key)
		if m != null and is_mission(m) and is_open(m) and not is_called(m):
			return m
	return null


## Who offers the mission: {name, line, face}, empty when it says nobody.
static func caller_of(m: MapFile) -> Dictionary:
	return m.caller if is_mission(m) else {}


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


## The mission's story; none for a map that is not a mission.
static func story_of(m: MapFile) -> String:
	return String(m.loot.get("story", "")) if is_mission(m) else ""


## Whether the map gives a gift at all: only a mission, and one that says its
## gift by name (MapFile.gift). A map of the player's never gives one.
static func has_gift(m: MapFile) -> bool:
	return is_mission(m) and String(m.gift.get("name", "")) != ""


## The gift for the mission, or an empty dictionary when it has none.
static func gift_of(m: MapFile) -> Dictionary:
	if not has_gift(m):
		return {}
	var g: Dictionary = m.gift
	return {"mission": key_of(m), "name": String(g.name), "shape": String(g.get("shape", m.loot.get("shape", "gem"))), "colour": String(g.get("colour", m.loot.get("colour", "#f0c46a")))}


## The mission got away with: marked as done, and the gift if it has one and
## it is the first time (kept at once), else an empty dictionary.
static func complete(m: MapFile) -> Dictionary:
	# Dev mode (Story.dev) keeps nothing: no gift, shown or kept.
	if Story.dev or not is_mission(m) or is_done(m):
		return {}
	var gift := gift_of(m)
	var done: Array = _read("done", [])
	done.append(key_of(m))
	var gifts := inventory()
	if not gift.is_empty():
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
