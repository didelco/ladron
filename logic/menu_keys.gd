class_name MenuKeys
extends RefCounted
## What a press means on a menu, the same on every screen and the same as
## in the game: each half of the keyboard is a pad. A accepts, as it is the
## action (E for the left-hand player, the full stop for the right-hand
## one); B goes back, as it rolls and lets go of a minigame (Space on the
## left, Enter on the right), and so does Escape. So no key ever takes you
## in on one screen and out on another. Tab and Start skip, LB and RB flick
## between tabs, View is the map.
##
## Godot's own buttons press themselves on ui_accept: project.godot has in it
## exactly ACCEPT_KEYS and A, never Space or Enter. ui_cancel stays Escape and
## B (Space and Enter would close the editor's fields and panels); the rest
## of BACK_KEYS is read here, by Main (its menus) and Tour (the town).

const ACCEPT_KEYS: Array[Key] = [KEY_E, KEY_PERIOD]
const BACK_KEYS: Array[Key] = [KEY_ESCAPE, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]


## A press as "accept", "back", "skip", "prev", "next", "map", or "" for
## anything else (the arrows and the rest are each screen's own).
static func of(event: InputEvent) -> String:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return ""
		if event.keycode in ACCEPT_KEYS:
			return "accept"
		if event.keycode in BACK_KEYS:
			return "back"
		if event.keycode == KEY_TAB:
			return "skip"
	elif event is InputEventJoypadButton and event.pressed:
		if not Pads.real(event.device):
			return ""
		match event.button_index:
			JOY_BUTTON_A: return "accept"
			JOY_BUTTON_B: return "back"
			JOY_BUTTON_START: return "skip"
			JOY_BUTTON_LEFT_SHOULDER: return "prev"
			JOY_BUTTON_RIGHT_SHOULDER: return "next"
			JOY_BUTTON_BACK: return "map"
	return ""
