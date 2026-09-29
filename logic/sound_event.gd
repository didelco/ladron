class_name SoundEvent
extends RefCounted
## A sound in the museum: where it happened and how far it carries in open
## space, in tiles. Walls take their share off that on the way (Hearing).

## How far each kind of noise carries, in tiles, before walls are taken into
## account (Hearing.LOUDNESS is this same table).
const LOUDNESS := {
	"walk": 5.0,
	## things knocked over (Props), at their gentlest: the tin bin clangs,
	## the bust smashes, the panel slaps flat, the armour falls to pieces. A
	## proper crash carries much further (Props.crash_loudness).
	"bin": 16.0,
	"bust": 20.0,
	"panel": 14.0,
	"armour": 22.0,
	"sprint": 9.5,
	## pushing through past a case at a run
	"rustle": 7.0,
	## walking into a wall in the dark: a dull, dry knock
	"bump": 3.0,
	## knocking a case: the loudest thing you can do
	"shelf": 13.0,
	## a whole thief, curled in a ball, into a wall or a case (Roll): as loud
	## as a suit of armour going over, and as sure a sign someone is about
	"roll_bump": 22.0,
	## one guard telling another, under its breath
	"whisper": 2.5,
	## a guard yelling "stop!"
	"shout": 30.0,
	"alarm": 14.0,
	## a thief flipping a light switch: a small, dry click
	"switch": 2.5,
	## a statue losing its balance and landing on the floor (Plinths.fall)
	"tumble": 12.0,
	## a thief sneezing its way out of a hideout (SneezeGame)
	"sneeze": 15.0,
	## a smoke bomb going off (Smoke): a soft pop, heard close by
	"smoke": 4.0,
}

var x: float
var y: float
var loudness: float
## walk, sprint, rustle, bump, shelf, roll_bump, shout, whisper, alarm, switch
var kind: String


static func make(px: float, py: float, what: String, how_loud: float = -1.0) -> SoundEvent:
	var n := SoundEvent.new()
	n.x = px
	n.y = py
	n.kind = what
	n.loudness = how_loud if how_loud >= 0 else float(LOUDNESS[what])
	return n
