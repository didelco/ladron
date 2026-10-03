class_name Pads
extends RefCounted
## The pads that count. A device could call itself a pad and not be one, so
## FAKE lists the (vendor, product) pairs to ignore everywhere: joining,
## playing, menus and rumble (PadFilter drops their events before anything
## sees them). It is empty on purpose: on macOS Godot names every pad
## "HID" 05ac:0004 (an Apple id), so that pair is a real pad, and ignoring it
## left a Mac with no pad at all. SDL_JOYSTICK_IGNORE_DEVICES=0x05ac/0x0004
## (CLAUDE.md) is for tests and screenshot runs only: it hides the real pad too.
##
## And the pads that went: a pad that drops out mid-game (a wireless one
## asleep, flat batteries) leaves its thief without hands (lost); the same
## pad coming back, or a press on any pad that is nobody's, gives them back
## (Main._pad_changed, Main._reclaim_pad).

## (vendor, product) of the devices that are not pads.
const FAKE: Array[Vector2i] = []

## Pads whose Start and View (Back, Select) reach Godot the wrong way round:
## their guid, without its checksum (signature). Godot's own mapping for this
## Mac pad ("HID" 05ac:0004 with this layout) has the two swapped, so Start
## showed the map and nothing opened the pause. PadFilter puts them back
## before anything reads the press.
const SWAPPED_START: Array[String] = ["0500ac05000004000000ae796d04"]


## Where the pads come from: the minimum this file asks of the machine. The
## default one asks Input; a test puts its own in `source` (a subclass that
## says which pads are plugged in, and who they are) and so tries the rest
## with no hardware.
class Source:
	## The devices plugged in (Input.get_connected_joypads).
	func connected() -> Array[int]:
		return Input.get_connected_joypads()

	## What the system says of a device: "vendor_id", "product_id"
	## (Input.get_joy_info).
	func info(device: int) -> Dictionary:
		return Input.get_joy_info(device)

	## Its name (Input.get_joy_name).
	func joy_name(device: int) -> String:
		return Input.get_joy_name(device)

	## Its guid (Input.get_joy_guid).
	func guid(device: int) -> String:
		return Input.get_joy_guid(device)


static var source: Source = Source.new()


## A real pad, not one of FAKE.
static func real(device: int) -> bool:
	if device < 0:
		return true
	return id_of(device) not in FAKE


## A guid without its checksum (characters 4 to 7), which is the pad's own
## and not its kind's: what SWAPPED_START lists.
static func signature(guid: String) -> String:
	return guid.left(4) + guid.substr(8) if guid.length() > 8 else guid


## The button a press of this pad really is: Start and View changed over on
## the pads of SWAPPED_START, itself on any other.
static func button(device: int, index: JoyButton) -> JoyButton:
	if index in [JOY_BUTTON_START, JOY_BUTTON_BACK] and device >= 0 and signature(source.guid(device)) in SWAPPED_START:
		return JOY_BUTTON_BACK if index == JOY_BUTTON_START else JOY_BUTTON_START
	return index


## The real pads plugged in.
static func connected() -> Array[int]:
	var out: Array[int] = []
	for d in source.connected():
		if real(d):
			out.append(d)
	return out


## (vendor, product), or (-1, -1) when the system does not say.
static func id_of(device: int) -> Vector2i:
	var info := source.info(device)
	return Vector2i(int(info.get("vendor_id", -1)), int(info.get("product_id", -1)))


## For the pads' settings page: "1: Xbox Wireless Controller (045e:0b13)",
## and a word when it is one of those ignored.
static func describe(device: int) -> String:
	var id := id_of(device)
	var ids := " (%04x:%04x)" % [id.x, id.y] if id.x >= 0 else ""
	var line := "%d: %s%s" % [device + 1, source.joy_name(device).left(24), ids]
	return line if real(device) else line + " · " + Text.t("SETTINGS_PAD_IGNORED")


## The seat a pad that came back belongs to: the lost seat (seats index)
## whose pad had the same guid, or -1. lost: seat index -> the guid of the
## pad it had.
static func owner_back(lost: Dictionary, guid: String) -> int:
	for i in lost:
		if lost[i] == guid:
			return i
	return -1
