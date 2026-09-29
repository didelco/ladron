class_name TrialMenu
extends RefCounted
## The choices at the end of a trial of the dojo (DojoTrial), the same as every
## menu of the game: a few buttons in a row, ONE of them selected (lit with the
## warm glow), left and right (the arrows, A and D, the cross, the stick; up and
## down too, and the shoulders) move the selection round the ends, accept (E, the
## full stop, A) does the selected, back (Esc, Space, Enter, B) and Tab or Start
## leave, and the mouse selects what it is over and picks with a click.
##
## The choice a panel opens on is the one that goes on: SEGUIR after a win (the
## next difficulty, when there is one), OTRA VEZ after a loss. And the press
## that ended the trial (the action key of the last catch, a key held on) does
## not pick it: for GUARD_S seconds after the panel opens accept and back are
## ignored (the moving is not), so a held or a doubled press cannot choose, or
## leave, for the player.
##
## Pure logic, no nodes: TrialView draws it, HouseRun gives it the keys.

const NEXT := "next"
const AGAIN := "again"
const EXIT := "exit"
## Seconds after opening in which accept and back do nothing.
const GUARD_S := 0.4

var options: Array[String] = []
var selected := 0
## seconds since it opened
var age := 0.0
## the last thing touched was a pad (for the help line under the choices)
var pad := false
## the stick's pushes, per axis (0 x, 1 y): -1, 0 or 1 while it is pushed, so a
## push moves once and moves again only after the stick has come back
var _stick := {0: 0, 1: 0}


## The choices for a result: SEGUIR (only after a win with a harder difficulty
## to go on to), OTRA VEZ, SALIR.
static func options_for(won: bool, has_next: bool) -> Array[String]:
	var out: Array[String] = []
	if won and has_next:
		out.append(NEXT)
	out.append(AGAIN)
	out.append(EXIT)
	return out


## The choice a result opens on: SEGUIR on a win with somewhere to go, else OTRA VEZ.
static func default_for(won: bool, has_next: bool) -> String:
	return NEXT if won and has_next else AGAIN


## Open with these choices and the one selected by default.
func open(list: Array[String], default_id: String) -> void:
	options = list.duplicate()
	selected = maxi(0, options.find(default_id))
	age = 0.0


func close() -> void:
	options = []
	selected = 0


func is_open() -> bool:
	return not options.is_empty()


func tick(dt: float) -> void:
	age += dt


## Whether accept and back are heard yet.
func armed() -> bool:
	return age >= GUARD_S


## The selected choice ("" if closed).
func current() -> String:
	if options.is_empty():
		return ""
	return options[clampi(selected, 0, options.size() - 1)]


## Select the choice with this id (the mouse over it); true if it moved.
func select(id: String) -> bool:
	var i := options.find(id)
	if i < 0 or i == selected:
		return false
	selected = i
	return true


## The selection dir places along (-1 left, +1 right), round the ends.
func move(dir: int) -> void:
	if options.is_empty():
		return
	selected = posmod(selected + dir, options.size())


## What a press does: {"move": true} the selection went along, {"pick": id} the
## selected choice was accepted, {"pick": EXIT} back or Tab or Start, or {} for
## a press that is none of these (or that came too soon).
func input(event: InputEvent) -> Dictionary:
	if options.is_empty():
		return {}
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false
	if event is InputEventJoypadMotion:
		return _stick_move(event)
	var what := MenuKeys.of(event)
	match what:
		"accept":
			return {"pick": current()} if armed() else {}
		"back", "skip":
			return {"pick": EXIT} if armed() else {}
		"prev":
			move(-1)
			return {"move": true}
		"next":
			move(1)
			return {"move": true}
	for a in ["ui_left", "ui_up", "ui_right", "ui_down"]:
		if event.is_action_pressed(a, false):
			move(-1 if a in ["ui_left", "ui_up"] else 1)
			return {"move": true}
	return {}


## The stick pushed along the choices: once for each push past STICK_ON, and
## again only after it has come back under STICK_OFF (the cross and the keys
## press once by themselves).
const STICK_ON := 0.6
const STICK_OFF := 0.3


func _stick_move(event: InputEventJoypadMotion) -> Dictionary:
	var axis := int(event.axis)
	if not Pads.real(event.device) or not _stick.has(axis):
		return {}
	var v := event.axis_value
	if absf(v) < STICK_OFF:
		_stick[axis] = 0
		return {}
	if int(_stick[axis]) == 0 and absf(v) >= STICK_ON:
		_stick[axis] = 1 if v > 0.0 else -1
		move(int(_stick[axis]))
		return {"move": true}
	return {}
