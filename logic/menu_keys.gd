class_name MenuKeys
extends RefCounted
## What a press means on a menu, the same on every screen. A accepts (E for
## the left-hand player, the full stop for the right-hand one, or Space and
## Enter, either hand: MENU_ACCEPT_KEYS); B goes back, and so does Escape,
## Backspace or the mouse's right button. Tab and Start skip, LB and RB flick
## between tabs, View is the map.
##
## Godot's own buttons press themselves on ui_accept: project.godot has in it
## exactly ACCEPT_KEYS and A, never Space, Enter, Backspace or a mouse
## button. ui_cancel stays Escape and B (Space and Enter would close the
## editor's fields and panels); MENU_ACCEPT_KEYS, Backspace and the mouse's
## right button are read only here, by Main (its menus) and Tour (the town)
## — never by a native Godot button, and never by Hands: playing, Space and
## Enter still roll (Hands.KB_BACK), same as always, unrelated to this.

const ACCEPT_KEYS: Array[Key] = [KEY_E, KEY_PERIOD]
const BACK_KEYS: Array[Key] = [KEY_ESCAPE]
## Accept too, but only in MenuKeys.of() — not a native ui_accept key, and
## not what Hands reads while playing (there, these two still roll).
const MENU_ACCEPT_KEYS: Array[Key] = [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]


## A press as "accept", "back", "skip", "prev", "next", "map", or "" for
## anything else (the arrows and the rest are each screen's own). Backspace
## and the mouse's right button also go back, on top of BACK_KEYS: they are
## not in it, as gameplay reads its own keys (Hands.KB_BACK) and never
## learned either of these two.
static func of(event: InputEvent) -> String:
	if event is InputEventKey:
		if not event.pressed or event.echo:
			return ""
		if event.keycode in ACCEPT_KEYS or event.keycode in MENU_ACCEPT_KEYS:
			return "accept"
		if event.keycode in BACK_KEYS or event.keycode == KEY_BACKSPACE:
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
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		return "back"
	return ""
