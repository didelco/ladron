class_name Hands
extends RefCounted
## Who plays with what: the player-select screen (a seat a thief, Mario Kart style), each seat's
## keys and pad read every frame (seat_input), the hints' names and glyphs of them, the
## shaking of the pads and the pads that drop out and come back. Game keeps the seats
## themselves (seats, pads_lost); this reads them.

## The keys on each side of a shared keyboard: pressing any of them on the
## player-select screen takes that side (Shift by which of the two it is).
## Not its B (Space, Enter: KB_BACK): as on a pad, that one gives it up.
## One keyboard seats two at most; a third and fourth thief join with a pad.
## KEY_SLASH is where the key is, not what it says: the one right of the
## full stop ("/" on a US keyboard, "-" on a Spanish one).
const KB_LEFT := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_C, KEY_E, KEY_Q, KEY_F, KEY_TAB]
const KB_RIGHT := [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SLASH, KEY_PERIOD, KEY_COMMA]
const KB_BACK := {KEY_SPACE: "kb_left", KEY_ENTER: "kb_right", KEY_KP_ENTER: "kb_right"}

var host: Game

## the seats taken so far on the player-select screen, and for which mode
var joining: Array[String] = []
var join_for := "story"

## when the last seat was taken (ms): one press may arrive twice — a pad
## that shows up as two devices, or one that also sends a key — and must
## not take both seats
var joined_at := -INF

## how many seats the player-select screen is filling
var join_count := 2

## The physics frame _pressed_keys last ran on: a gap means play (re)started.
var pad_frame := -1

## Crouch, action and roll keys and buttons held over from a menu, ignored
## until released (_fresh).
var pad_stale := {}

## each thief's controls as last read (_seat_input), for the prompts to see
## a press as it happens
var seat_now: Array = []

## Which Shift keys are down, by key and KeyLocation. Polling cannot
## tell the left one (P1's) from the right one (P2's), so their key events
## keep this up to date.
var mod_down := {}

## The last thing touched was a pad (for the hints of a thief on "any"),
## and which one.
var last_pad := false
var last_pad_device := 0

## Each pad's guid while plugged in (device -> guid): once it is gone the
## system no longer says, and a lost seat waits for that pad by it.
var pad_guids := {}


func _init(game: Game) -> void:
	host = game


## Player select, like Mario Kart 64: a seat a thief, each taken by whoever
## presses a button on their pad or a key on their part of the keyboard.
## P1 is always teal, P2 orange and P3 purple; the first to press is P1.
func show_join(which: String, count := 2) -> void:
	host.phase = "join"
	join_for = which
	join_count = count
	joining.clear()
	joined_at = -INF
	draw_join()


func draw_join() -> void:
	var cards: Array = []
	for i in join_count:
		var seat: String = joining[i] if i < joining.size() else ""
		cards.append({"title": Text.t("JOIN_PLAYER") % (i + 1), "text": seat_label(seat) if seat != "" else Text.t("JOIN_PRESS"),
			"stage": MenuStage.make("seat:%d" % (i + 1)), "colour": host._thief_colours()[i],
			"selected": seat != "", "static": true, "animate": seat != "", "dim": seat == "", "title_size": 12})
	var items: Array = [
		{"title": Text.t("JOIN_TITLE"), "size": 40},
		{"cards": cards, "width": 200},
		{"text": Text.t("JOIN_KEYBOARD_LEFT"), "size": 16},
		{"text": Text.t("JOIN_KEYBOARD_RIGHT") % key_label(KEY_PERIOD), "size": 16},
		{"text": Text.t("JOIN_PAD"), "size": 16},
		{"text": Text.t("JOIN_UNDO"), "size": 16, "colour": Hud.C.dim},
	]
	if join_count > 2:
		items.append({"text": Text.t("JOIN_EXTRA_PADS"), "size": 16, "colour": Hud.C.gold})
	if joining.size() == join_count:
		items.append({"text": Text.t("JOIN_READY"), "size": 16, "colour": Hud.C.gold})
	host.hud.show_menu(items, "join")


func seat_label(seat: String) -> String:
	match seat:
		"kb_left": return Text.t("SEAT_KB_LEFT")
		"kb_right": return Text.t("SEAT_KB_RIGHT")
		"any": return Text.t("SEAT_ANY")
	var pad := int(seat.substr(4))
	return Text.t("SEAT_PAD") % [pad + 1, Input.get_joy_name(pad).left(18)]


## A press on the player-select screen: it takes a seat; Esc or Backspace
## frees the last one, B (Space, Enter on the keyboard) its own — or goes
## back when none is taken.
func join_input(event: InputEvent) -> void:
	var seat := ""
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_BACKSPACE]:
			unjoin()
			return
		if KB_BACK.has(event.keycode):
			leave_seat(KB_BACK[event.keycode])
			return
		if event.keycode == KEY_SHIFT:
			seat = "kb_right" if event.location == KEY_LOCATION_RIGHT else "kb_left"
		elif event.physical_keycode in KB_LEFT or event.keycode in KB_LEFT:
			seat = "kb_left"
		elif event.physical_keycode in KB_RIGHT or event.keycode in KB_RIGHT:
			seat = "kb_right"
	elif event is InputEventJoypadButton and event.pressed:
		if not Pads.real(event.device):
			return
		if event.button_index == JOY_BUTTON_B:
			leave_seat("pad:%d" % event.device)
			return
		seat = "pad:%d" % event.device
	if seat == "" or seat in joining or joining.size() >= join_count:
		return
	var now := Time.get_ticks_msec()
	if now - joined_at < 450:
		return
	joined_at = now
	joining.append(seat)
	host.sfx.ui("ok")
	rumble_pad(seat, 0.3, 0.15)
	draw_join()
	if joining.size() == join_count:
		host.get_tree().create_timer(0.8).timeout.connect(func() -> void:
			if host.phase == "join" and joining.size() == join_count:
				host.seats.assign(joining)
				host.pads_lost.clear()
				if join_for == "story":
					# The story's gang goes on to the town, to pick a night.
					host._story_gang(join_count)
				elif join_for == "dojo":
					host._dojo_start(join_count, true)
				else:
					host._start(join_for, join_count, true))


## B takes its own thief off (a pad's, or a keyboard side's), or with nobody
## in, goes back: never somebody else's seat.
func leave_seat(mine: String) -> void:
	if mine in joining:
		host.sfx.ui("back")
		joining.erase(mine)
		draw_join()
	elif joining.is_empty():
		unjoin()


func unjoin() -> void:
	host.sfx.ui("back")
	if joining.is_empty():
		if join_for == "story":
			host._show_title("story")
		elif join_for == "dojo":
			host._show_title("dojo")
		elif join_for == "challenge":
			host.challenges.show_map(host.challenges.challenge_map)
		else:
			host._show_generative_menu()
		return
	joining.pop_back()
	draw_join()


func pressed_keys() -> Dictionary:
	var keys := {}
	# A, B, E, Space and Enter also press and back out of menus: one still held
	# from there when the play starts (or resumes) does nothing until let go.
	var resumed := Engine.get_physics_frames() != pad_frame + 1
	pad_frame = Engine.get_physics_frames()
	# Each thief's controls, as the key names Sim reads for that thief. P3's
	# and P4's are only names now: they play with a pad, never those keys.
	var names := [["w", "s", "a", "d", "c", "e", "space", "lalt", "f"], ["up", "down", "left", "right", "minus", "period", "enter", "ralt", "comma"], ["i", "k", "j", "l", "u", "o", "y", "h", "n"], ["kp8", "kp5", "kp4", "kp6", "kp0", "kpadd", "kpmul", "kpsub", "kpdot"]]
	seat_now.resize(mini(host.seats.size(), host.thieves.size()))
	for i in mini(host.seats.size(), host.thieves.size()):
		var got := seat_input(host.seats[i], resumed)
		seat_now[i] = got
		for k in 9:
			if got[k]:
				keys[names[i][k]] = true
	return keys


## The names of a thief's controls, for the hints: the directions ("move"),
## left and right ("lr"), up and down ("ud"), the action key and the one to
## let go ("cancel") — its keyboard side's keys, or its pad's.
func controls(i: int) -> Dictionary:
	var seat: String = host.seats[i] if i < host.seats.size() else "any"
	var pad := seat.begins_with("pad:") or (seat == "any" and last_pad)
	if pad:
		return {"move": Text.t("KEY_STICK"), "lr": "◀ ▶", "ud": "▲ ▼", "action": "A", "cancel": "B"}
	if seat == "kb_right":
		return {"move": "← ↑ → ↓", "lr": "← →", "ud": "↑ ↓", "action": key_label(KEY_PERIOD), "cancel": Text.t("KEY_ENTER")}
	return {"move": "WASD", "lr": "A D", "ud": "W S", "action": "E", "cancel": Text.t("KEY_SPACE")}


## What the key in that place says on this keyboard: "-" for KEY_SLASH on a
## Spanish one, "/" on a US one.
static func key_label(physical: Key) -> String:
	var label := physical
	if DisplayServer.get_name() != "headless":
		label = DisplayServer.keyboard_get_label_from_physical(physical)
	# A printable key is its character; the rest go by name.
	if label > 32 and label < KEY_SPECIAL:
		return char(label).to_upper()
	return OS.get_keycode_string(label)


## Is this side's Shift held? A key event that never said which
## side counts for both; and with none down at all (let go in another
## window), none is.
func mod_held(key: Key, side: KeyLocation) -> bool:
	if not Input.is_physical_key_pressed(key):
		for k in mod_down.keys():
			if k[0] == key:
				mod_down.erase(k)
		return false
	return mod_down.get([key, side], false) or mod_down.get([key, KEY_LOCATION_UNSPECIFIED], false)


## Is this key or button down, and not still held over from a menu (E and
## A accept there; Space, Enter and B back out)? One held when the play starts or
## resumes counts once it has been let go.
func fresh(id: String, held: bool, resumed: bool) -> bool:
	if held and resumed:
		pad_stale[id] = true
	elif not held:
		pad_stale.erase(id)
	return held and not pad_stale.has(id)


## One seat's controls this frame: [up, down, left, right, crouch, push, roll,
## slow, smoke], the way most PC games have them. P1: WASD, E the action,
## Space the roll, C to crouch, left Shift held to walk slowly, F a smoke
## bomb. P2 the same round the arrows: the full stop, Enter, the key after
## the full stop (KEY_SLASH), right Shift and the comma. No Ctrl: on a Mac,
## Ctrl and Space change the keyboard's language and Ctrl and an arrow the
## desktop.
func seat_input(seat: String, resumed: bool) -> Array:
	var out := [false, false, false, false, false, false, false, false, false]
	if seat == "any" or seat == "kb_left":
		for pair in [[0, KEY_W], [1, KEY_S], [2, KEY_A], [3, KEY_D], [4, KEY_C], [5, KEY_E], [6, KEY_SPACE], [8, KEY_F]]:
			var held := Input.is_physical_key_pressed(pair[1])
			if held if pair[0] < 4 else fresh("key:%d" % pair[1], held, resumed):
				out[pair[0]] = true
		out[7] = mod_held(KEY_SHIFT, KEY_LOCATION_LEFT)
	if seat == "any" or seat == "kb_right":
		for pair in [[0, KEY_UP], [1, KEY_DOWN], [2, KEY_LEFT], [3, KEY_RIGHT], [4, KEY_SLASH], [5, KEY_PERIOD], [6, KEY_ENTER], [6, KEY_KP_ENTER], [8, KEY_COMMA]]:
			var held := Input.is_physical_key_pressed(pair[1])
			if held if pair[0] < 4 else fresh("key:%d" % pair[1], held, resumed):
				out[pair[0]] = true
		out[7] = out[7] or mod_held(KEY_SHIFT, KEY_LOCATION_RIGHT)
	var pads: Array = Pads.connected() if seat == "any" else ([int(seat.substr(4))] if seat.begins_with("pad:") else [])
	var dz := host.deadzone / 100.0
	for pad in pads:
		var x := Input.get_joy_axis(pad, JOY_AXIS_LEFT_X)
		var y := Input.get_joy_axis(pad, JOY_AXIS_LEFT_Y)
		out[0] = out[0] or y < -dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_UP)
		out[1] = out[1] or y > dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_DOWN)
		out[2] = out[2] or x < -dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_LEFT)
		out[3] = out[3] or x > dz or Input.is_joy_button_pressed(pad, JOY_BUTTON_DPAD_RIGHT)
		# As most pads have it: A (south) the action, as it accepts in the
		# menus; B (east) the roll, the way out, as it backs out of them; X
		# (west) or a click of the left stick crouches; Y (north) throws a smoke
		# bomb. Each is ignored while still held over from a menu.
		for pair in [[5, JOY_BUTTON_A], [6, JOY_BUTTON_B], [4, JOY_BUTTON_X], [4, JOY_BUTTON_LEFT_STICK], [8, JOY_BUTTON_Y]]:
			if fresh("pad:%d:%d" % [pad, pair[1]], Input.is_joy_button_pressed(pad, pair[1]), resumed):
				out[pair[0]] = true
		# LB held walks slowly; so does the stick past the dead zone but short
		# of halfway from there to the rim (the cross has no half measures).
		var tilt := Vector2(x, y).length()
		var nudged := (absf(x) > dz or absf(y) > dz) and tilt < dz + (1.0 - dz) * 0.5
		out[7] = out[7] or Input.is_joy_button_pressed(pad, JOY_BUTTON_LEFT_SHOULDER) or nudged
	return out


## Shakes the pads: every one, or with `at` only the pad of the thief nearest
## to it (pad 0 is P1, pad 1 is P2). On your own any pad may be the one in
## your hands, so all of them shake.
func rumble(weak: float, strong: float, secs: float, at := Vector2.INF) -> void:
	var who := -1
	if host.thieves.size() >= 2 and at != Vector2.INF:
		var best := INF
		for i in host.thieves.size():
			var d := Museum.dist(host.thieves[i].x, host.thieves[i].y, at.x, at.y)
			if d < best:
				best = d
				who = i
	for i in host.seats.size():
		if who < 0 or i == who:
			rumble_pad(host.seats[i], weak, secs, strong)


## Shake one seat's pad (every pad for "any"; keyboards do not shake).
func rumble_pad(seat: String, weak: float, secs: float, strong := -1.0) -> void:
	if not host.rumble or host.rumble_strength == 0:
		return
	if strong < 0.0:
		strong = weak
	var k := host.rumble_strength / 100.0
	var pads: Array = Pads.connected() if seat == "any" else ([int(seat.substr(4))] if seat.begins_with("pad:") else [])
	for pad in pads:
		Input.start_joy_vibration(pad, weak * k, strong * k, secs)


## A pad plugged in or out. Out: the thief it was has no hands (its seat is
## "lost") and a game in play pauses. In: if it is the pad a thief lost,
## back it goes to that thief.
func pad_changed(device: int, connected: bool) -> void:
	if connected:
		pad_guids[device] = Input.get_joy_guid(device)
		var i := Pads.owner_back(host.pads_lost, pad_guids[device])
		if i >= 0 and Pads.real(device) and not ("pad:%d" % device) in host.seats:
			give_pad(i, device)
		return
	var seat := "pad:%d" % device
	if host.phase == "join" and seat in joining:
		joining.erase(seat)
		draw_join()
	for i in host.seats.size():
		if host.seats[i] == seat:
			host.seats[i] = "lost"
			host.pads_lost[i] = pad_guids.get(device, "")
	pad_guids.erase(device)
	if not host.pads_lost.is_empty():
		if host.phase == "playing":
			host._pause()
		elif host.phase == "paused":
			host._pause()


## A press on a pad while a thief has none: if the pad is nobody's, it is
## the first such thief's now.
func reclaim_pad(device: int) -> void:
	if ("pad:%d" % device) in host.seats:
		return
	var first := -1
	for i in host.pads_lost:
		if first < 0 or i < first:
			first = i
	give_pad(first, device)


func give_pad(i: int, device: int) -> void:
	host.seats[i] = "pad:%d" % device
	host.pads_lost.erase(i)
	host.sfx.ui("ok")
	rumble_pad(host.seats[i], 0.3, 0.15)
	host._log(Text.t("LOG_PAD_BACK") % (i + 1))
	if host.phase == "paused":
		host._pause()


## The glyph (Glyph spec) for one of thief i's inputs, on whatever it plays
## with: its keyboard half, or its pad drawn as that pad's maker draws it.
func glyph(i: int, input: String) -> Dictionary:
	var seat: String = host.seats[i] if i < host.seats.size() else "any"
	var pad := seat.begins_with("pad:") or (seat == "any" and last_pad)
	if pad:
		if input == "move":
			return {"kind": "stick"}
		var device := int(seat.substr(4)) if seat.begins_with("pad:") else last_pad_device
		var place: String = {"action": "south", "crouch": "west", "roll": "east"}.get(input, "south")
		return {"kind": "pad", "pos": place, "family": pad_family(device)}
	# The four to move, where the hand finds them; left-right and up-down,
	# the same four with the other two dimmed.
	var four = "arrows" if seat == "kb_right" else ["W", "A", "S", "D"]
	match input:
		"move": return {"kind": "keys4", "labels": four}
		"lr": return {"kind": "keys4", "labels": four, "lit": [false, true, false, true]}
		"ud": return {"kind": "keys4", "labels": four, "lit": [true, false, true, false]}
	var keys := controls(i)
	var label: String = {"move": keys.move, "action": keys.action, "roll": keys.cancel,
		"crouch": key_label(KEY_SLASH) if seat == "kb_right" else "C"}.get(input, "?")
	return {"kind": "key", "label": label}


## Whose pad it is, by its name: PlayStation and Nintendo draw their buttons
## their own way; anything else, the Xbox way (as most pads do).
static func pad_family(device: int) -> String:
	var name := Input.get_joy_name(device).to_lower()
	for mark in ["playstation", "dualsense", "dualshock", "ps3", "ps4", "ps5", "sony"]:
		if name.contains(mark):
			return "ps"
	for mark in ["nintendo", "switch", "joy-con", "pro controller"]:
		if name.contains(mark):
			return "nintendo"
	return "xbox"
