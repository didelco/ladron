class_name PlayerInteractions
extends RefCounted
## Decide qué acción tiene prioridad junto a un ninja y presenta la misma
## decisión en sus ayudas. Game conserva las entradas públicas para NightLoop.
## Los nodos de ayuda se crean cuando hacen falta y se reutilizan.

var host: Game

func _init(game: Game) -> void:
	host = game


## Each thief's minigame box, beside it on screen.
var game_boxes: Array[MinigameBox] = []


func draw_game_boxes() -> void:
	while game_boxes.size() < host.thieves.size():
		var box := MinigameBox.new()
		host.hud.add_child(box)
		game_boxes.append(box)
	for i in game_boxes.size():
		var p: Thief = host.thieves[i] if i < host.thieves.size() else null
		var g: Minigame = p.game if p and host.phase in ["playing", "paused"] else null
		var head := host.camera.unproject_position(host._to_world(p.x, p.y, 1.6)) if g else Vector2.ZERO
		var controls := host.hands.controls(i)
		controls.glyphs = {"action": host.hands.glyph(i, "action"), "cancel": host.hands.glyph(i, "roll"), "move": host.hands.glyph(i, "move")}
		controls.glyphs.lr = controls.glyphs.move if controls.glyphs.move.kind == "stick" else host.hands.glyph(i, "lr")
		controls.glyphs.ud = controls.glyphs.move if controls.glyphs.move.kind == "stick" else host.hands.glyph(i, "ud")
		game_boxes[i].follow(g, head, host._thief_colours()[i], controls)


# --- Prompts: what each thief can do, over its head ------------------------------

## Each thief's bubble of what it can do now (Prompt).
var prompts: Array[Prompt] = []
## what each thief held last frame, to see a press begin
var seat_before: Array = []
## the inputs by their place in _seat_input's answer
const INPUT_AT := {"move": [0, 1, 2, 3], "crouch": [4], "action": [5], "roll": [6]}


func draw_prompts(dt: float) -> void:
	while prompts.size() < host.thieves.size():
		var p := Prompt.new()
		host.hud.add_child(p)
		prompts.append(p)
	for i in prompts.size():
		var p: Thief = host.thieves[i] if i < host.thieves.size() else null
		var rows := prompt_rows(i) if p else []
		var head := host.camera.unproject_position(host._to_world(p.x, p.y, 1.9)) if p else Vector2.ZERO
		prompts[i].show_rows(rows, head, host._thief_colours()[i], dt)
		# A press on this thief's controls sinks the glyph for it.
		if i < host.hands.seat_now.size():
			var was: Array = seat_before[i] if i < seat_before.size() else []
			for input in INPUT_AT:
				for k in INPUT_AT[input]:
					if host.hands.seat_now[i][k] and not (k < was.size() and was[k]):
						prompts[i].press(input)
	seat_before = host.hands.seat_now.duplicate(true)


## What the action key would do for thief t where it stands, the first of
## these there is (the bubble says the same, _prompt_rows): a minigame at
## the case or the alarm panel ("job"), a pedestal ("plinth"), a hideout
## ("hide"), an arcade machine ("arcade"), a room's switch ("switch"), a
## prop to push over ("push"). In the band's house, a door next to one
## ("door": open it, or shut it if no one is in its way) comes before all but
## the job; a challenge's own door ("map_door", Museum.doors) the same, in a
## museum. While a trial is on in the house (HouseRun.trial_active) only what
## the trial itself needs is offered. {do, at}, or empty for nothing.
func action_for(t: Thief) -> Dictionary:
	# A trial on in the house: only what it needs (HouseRun.trial_action).
	if host.mode == Practice.MODE and host.house.trial_active():
		return host.house.trial_action(t)
	var job := Heist.game_for(t)
	if not job.is_empty():
		return {"do": "job", "at": job}
	if host.mode == Practice.MODE:
		var door := Den.door_near(Vector2i(int(floor(t.x)), int(floor(t.y))))
		if door != "" and Den.can_toggle(door, host.house.band_points(), host.players):
			return {"do": "door", "at": door}
		# The start point of a trial next to it (the games, the bench's tests, the circuit).
		if Den.ROOMS.has("dojo") and host.house.trial_lock <= 0.0:
			var start := Practice.start_at(Vector2(t.x, t.y), host.players)
			if not start.is_empty():
				return {"do": "trial", "id": start.id, "tier": start.tier}
	elif not Museum.doors.is_empty():
		var map_door := Museum.door_near(Vector2i(int(floor(t.x)), int(floor(t.y))))
		if map_door != MapFile.NONE and Museum.can_toggle_door(map_door, host.house.band_points()):
			return {"do": "map_door", "at": map_door}
	var plinth = Plinths.within_reach(t, host.thieves)
	if plinth != null:
		return {"do": "plinth", "at": plinth}
	var spot := Hideouts.within_reach(t, host.thieves)
	if spot:
		return {"do": "hide", "at": spot}
	var arcade := Arcades.within_reach(t, host.thieves)
	if arcade.x >= 0:
		return {"do": "arcade", "at": arcade}
	var room := Sim.switch_within_reach(t)
	if room:
		return {"do": "switch", "at": room}
	var prop := Props.within_reach(t)
	if prop:
		return {"do": "push", "at": prop}
	return {}


## What thief i can do where it stands, one row each (Prompt): the action
## key for what it would do (_action_for), why it waits, or how the job goes.
func prompt_rows(i: int) -> Array:
	var p := host.thieves[i]
	if host.phase != "playing" or p.out or p.game or host.map_open:
		return []
	var row := func(input: String, verb: String) -> Dictionary:
		return {"input": input, "glyph": host.hands.glyph(i, input), "verb": verb}
	# At the case: how the job goes, or why it will not give.
	if Heist.by == p.id and not Heist.taken:
		if Heist.waiting:
			var two: bool = Heist.panel2.x >= 0
			if Heist.minigames():
				return [{"verb": Text.t("HUD_JOB_WAIT_CUTS" if two else "HUD_JOB_WAIT_CUT")}]
			return [{"verb": Text.t("HUD_JOB_WAIT_PANELS" if two else "HUD_JOB_WAIT_PANEL")}]
		if Heist.short_hand:
			return [{"verb": Text.t("HUD_JOB_TWO_LOCKS")}]
		return [{"verb": Heist.loot.verb, "progress": Heist.progress}]
	# Al cogerla ya no se nombra la pieza, solo adónde ir.
	if Heist.carrier == p.id:
		return [{"verb": Text.t("HUD_JOB_CARRYING")}]
	if p.posing:
		return [row.call("move", Text.t("HUD_PLINTH_DOWN"))]
	if p.hiding:
		return [row.call("move", Text.t("HUD_HIDE_OUT"))]
	# A trial on says how to leave it in its own HUD (TrialView), the same for all.
	if host.house.trial != null:
		return []
	var act := action_for(p)
	match act.get("do", ""):
		"trial": return [row.call("action", DojoTrials.start_label(act.id, act.tier))]
		"job": return [row.call("action", Text.t({"lockpick": "HUD_GAME_PICK_HINT", "steady": "HUD_GAME_STEADY_HINT"}.get(act.at.kind, "HUD_GAME_WIRES_HINT")))]
		"plinth": return [row.call("action", Text.t("HUD_PLINTH_HINT"))]
		"hide": return [row.call("action", Text.t("HUD_HIDE_HINT"))]
		"arcade": return [row.call("action", Text.t("HIDEOUT_ARCADE_PLAY" if host.mode == Practice.MODE else "HUD_ARCADE_HINT"))]
		"switch": return [row.call("action", Text.t("HUD_SWITCH_HINT"))]
		"push": return [row.call("action", Text.t("HUD_PUSH_HINT"))]
		"door": return [row.call("action", Text.t("HIDEOUT_DOOR_CLOSE" if Den.is_open(act.at) else "HIDEOUT_DOOR_OPEN"))]
		"map_door": return [row.call("action", Text.t("HIDEOUT_DOOR_CLOSE" if Museum.is_door_open(act.at) else "HIDEOUT_DOOR_OPEN"))]
	return []


