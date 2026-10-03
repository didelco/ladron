class_name PhoneCall
extends Node
## The missions' phone call (Missions): in the band's house (any of its
## spaces), a while after arriving (DELAY), the telephone rings once per visit
## if the story has opened a mission that has not rung before. It is a menu of
## the HUD (Hud.show_menu) over the game, the phone and two choices, COGER and
## NO COGER; the game stands still (the tree is paused, phase "call") while it
## is up. As it rings the mission is "called" (Missions.mark_called): from then
## on it is in the Missions menu, picked up or not, and does not ring again.
## NO COGER, or letting it ring out (GIVE_UP), is back to the house. COGER shows
## the caller's face and name, what to steal, the tale and the gift, with
## ACEPTAR (the robbery begins with the band as it is) and DEJAR PARA DESPUÉS
## (back to the house).

## seconds in the house, playing, before the phone rings
const DELAY := 10.0
## seconds between two rings, and how long it rings before it is given up
const RING_EVERY := 1.9
const GIVE_UP := 12.0

var host: Game
## "idle", "ringing" or "offer"
var state := "idle"
## the mission that rings
var mission: MapFile
## the mission that will ring this visit, whether it has rung already, and
## the seconds of the visit spent playing in the house
var next_call: MapFile
var rung := false
var clock := 0.0
var _ring_time := 0.0
var _ringing_for := 0.0


func _init(game: Game) -> void:
	host = game


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## A visit to the house begins (Game._dojo_start): the clock and the one call
## start over, and what rings is chosen.
func begin_visit() -> void:
	clock = 0.0
	rung = false
	state = "idle"
	next_call = Missions.pending_call()


## Whether the phone may ring now: the band playing in the house, with no
## game of the dojo (nor its panel) and no map open.
func can_ring() -> bool:
	return host.mode == Practice.MODE and host.phase == "playing" and not host.thieves.is_empty() \
		and not host.map_open and not host.house.trial_active() and not host.house.home_leaving \
		and not host.challenges.testing


func _process(dt: float) -> void:
	step(dt)


func step(dt: float) -> void:
	match state:
		"idle":
			if rung or next_call == null or host.mode != Practice.MODE or host.phase != "playing":
				return
			clock += dt
			if clock >= DELAY and can_ring():
				ring()
		"ringing":
			_ring_time += dt
			_ringing_for += dt
			if _ringing_for >= GIVE_UP:
				decline()
			elif _ring_time >= RING_EVERY:
				_ring_time = 0.0
				host.sfx.ui("phone", 0.8)


## The phone starts ringing: the mission is called, the game stops and the
## menu comes up.
func ring() -> void:
	rung = true
	mission = next_call
	Missions.mark_called(mission)
	_ring_time = 0.0
	_ringing_for = 0.0
	state = "ringing"
	host.get_tree().paused = true
	host.sfx.ui("phone", 0.8)
	host.hud.hide_gameplay()
	host.phase = "call"
	host.hud.show_menu([
		{"title": Text.t("PHONE_RING"), "colour": Hud.C.gold, "size": 52},
		{"node": PhoneIcon.new()},
		{"text": Text.t("PHONE_RING_TEXT"), "size": 20},
		{"buttons": [
			{"text": Text.t("PHONE_ANSWER"), "call": answer},
			{"text": Text.t("PHONE_IGNORE"), "call": decline},
		], "row": true},
	], "phone")


## COGER: the caller's page comes up.
func answer() -> void:
	if state != "ringing":
		return
	state = "offer"
	host.sfx.ui("ok", 0.6)
	var caller := Missions.caller_of(mission)
	var words: Array = []
	if String(caller.get("line", "")) != "":
		words.append({"text": "«%s»" % caller.line, "size": 17, "wrap": true, "width": 500, "align": "left", "colour": Color("#f6e7c8")})
	words.append({"text": Text.t("MISSION_STEAL") % Missions.piece_name(mission), "size": 19, "wrap": true, "width": 500, "align": "left", "colour": Hud.C.gold})
	if Missions.story_of(mission) != "":
		words.append({"text": Missions.story_of(mission), "size": 16, "wrap": true, "width": 500, "align": "left"})
	if Missions.has_gift(mission):
		words.append({"text": Text.t("MISSION_GIFT") % Missions.gift_of(mission).name, "size": 19, "wrap": true, "width": 500, "align": "left", "colour": Hud.C.safe})
	host.hud.show_menu([
		{"title": String(caller.get("name", "?")), "colour": Hud.C.gold, "size": 40},
		{"columns": [
			{"items": [{"node": CallerFace.new(caller.get("face", {}))}]},
			{"items": words, "width": 500},
		], "separation": 30},
		{"buttons": [
			{"text": Text.t("PHONE_ACCEPT"), "call": accept},
			{"text": Text.t("PHONE_LATER"), "call": later},
		], "row": true},
	], "phone_offer")


## NO COGER, or the phone left to ring: back to the house. The mission is in
## the Missions menu all the same.
func decline() -> void:
	if state != "ringing":
		return
	host.sfx.ui("back", 0.6)
	_close()


## DEJAR PARA DESPUÉS: back to the house.
func later() -> void:
	if state != "offer":
		return
	host.sfx.ui("back", 0.6)
	_close()


## Back (Escape, B): the same as the choice that gives it up.
func back() -> void:
	if state == "ringing":
		decline()
	elif state == "offer":
		later()


## ACEPTAR: the robbery of the mission, with the band as it is (its controls
## are the house's already, so no asking who is who again).
func accept() -> void:
	if state != "offer":
		return
	var m := mission
	state = "idle"
	host.sfx.ui("ok", 0.6)
	host.challenges.challenge_map = m
	host.challenges.challenge_at = "map:" + m.path
	host._start("challenge", host.players, true)


func _close() -> void:
	state = "idle"
	host._start_playing()


## Every line of text on the menu, for whoever wants to read it.
func texts() -> Array[String]:
	var out: Array[String] = []
	for n in host.hud._panel_box.find_children("*", "Label", true, false):
		out.append((n as Label).text)
	return out
