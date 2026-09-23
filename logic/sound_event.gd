class_name SoundEvent
extends RefCounted
## A sound in the museum: where it happened and how far it carries in open
## space, in tiles. Walls take their share off that on the way (Hearing).

var x: float
var y: float
var loudness: float
## walk, sprint, rustle, bump, shelf, shout, whisper, alarm
var kind: String


static func make(px: float, py: float, what: String, how_loud: float = -1.0) -> SoundEvent:
	var n := SoundEvent.new()
	n.x = px
	n.y = py
	n.kind = what
	n.loudness = how_loud if how_loud >= 0 else float(Hearing.LOUDNESS[what])
	return n
