class_name Pads
extends RefCounted
## The pads that count. Some devices call themselves pads and are not: on
## some Macs an Apple one (05ac:0004) shows up with its stick stuck to the
## left, and echoes the presses of the real pads — so a gang could end up
## with a thief taking orders from every pad at once, or menus paging on
## their own. Those are ignored everywhere: joining, playing, menus and
## rumble (PadFilter drops their events before anything sees them).
##
## And the pads that went: a pad that drops out mid-game (a wireless one
## asleep, flat batteries) leaves its thief without hands (lost); the same
## pad coming back, or a press on any pad that is nobody's, gives them back
## (Main._pad_changed, Main._reclaim_pad).

## (vendor, product) of the devices that are not pads.
const FAKE := [Vector2i(0x05ac, 0x0004)]


## A real pad, not one of FAKE.
static func real(device: int) -> bool:
	if device < 0:
		return true
	return id_of(device) not in FAKE


## The real pads plugged in.
static func connected() -> Array[int]:
	var out: Array[int] = []
	for d in Input.get_connected_joypads():
		if real(d):
			out.append(d)
	return out


## (vendor, product), or (-1, -1) when the system does not say.
static func id_of(device: int) -> Vector2i:
	var info := Input.get_joy_info(device)
	return Vector2i(int(info.get("vendor_id", -1)), int(info.get("product_id", -1)))


## For the pads' settings page: "1: Xbox Wireless Controller (045e:0b13)",
## and a word when it is one of those ignored.
static func describe(device: int) -> String:
	var id := id_of(device)
	var ids := " (%04x:%04x)" % [id.x, id.y] if id.x >= 0 else ""
	var line := "%d: %s%s" % [device + 1, Input.get_joy_name(device).left(24), ids]
	return line if real(device) else line + " · " + Text.t("SETTINGS_PAD_IGNORED")


## The seat a pad that came back belongs to: the lost seat (seats index)
## whose pad had the same guid, or -1. lost: seat index -> the guid of the
## pad it had.
static func owner_back(lost: Dictionary, guid: String) -> int:
	for i in lost:
		if lost[i] == guid:
			return i
	return -1
