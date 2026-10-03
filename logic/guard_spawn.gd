## A guard as the map editor places it: where it starts, which way it
## looks, how it behaves and what it is like. Design-time data, not the
## runtime AI in Guard.
class_name GuardSpawn
extends RefCounted

var at := Vector2i.ZERO
var dir := PI
## "round" (patrols Museum.watchpoints like any other) or "post" (stands
## guard at `at`, never leaving unless it gives chase).
var stance := "round"
## Only with stance == "post": "" (a plain sweep), "room" (a wide one, the
## whole room) or "piece" (faces the loot instead of `dir`).
var watch := ""
## The archetype last picked, only so the editor's drop-down shows it
## marked; the three levels below are what actually count from then on.
var archetype := ""
## How far it sees, how far it hears, how fast it moves, how attentive it
## is (whether it notices an emptied case, NightAlert): 0 the worst, 4 the
## best, 2 a plain guard like any other — one slider each, not a grab-bag
## of tags, so "sees badly but hears well" is just two numbers apart.
var view_level := 2
var hearing_level := 2
var speed_level := 2
var attention_level := 2

## An archetype: a label, and the levels it starts a guard at.
const ARCHETYPES := {
	"": {"label": "EDITOR_GUARD_ARCH_STANDARD", "view": 2, "hearing": 2, "speed": 2, "attention": 2},
	"vigia": {"label": "EDITOR_GUARD_ARCH_WATCHER", "view": 4, "hearing": 2, "speed": 2, "attention": 3},
	"sabueso": {"label": "EDITOR_GUARD_ARCH_HOUND", "view": 2, "hearing": 4, "speed": 2, "attention": 2},
	"dormilon": {"label": "EDITOR_GUARD_ARCH_SLEEPY", "view": 2, "hearing": 1, "speed": 0, "attention": 0},
	"veterano": {"label": "EDITOR_GUARD_ARCH_VETERAN", "view": 3, "hearing": 3, "speed": 2, "attention": 3},
}
## The sliders, in the order the editor shows them.
const STATS := ["view", "hearing", "speed", "attention"]
## The multiplier each level of each slider stands for; 2 (the middle one)
## is always 1.0, so a plain guard never nudges the difficulty dials.
const LEVELS := {
	"view": [0.6, 0.8, 1.0, 1.2, 1.4],
	"hearing": [0.6, 0.8, 1.0, 1.2, 1.4],
	"speed": [0.7, 0.85, 1.0, 1.15, 1.3],
	"attention": [0.5, 0.75, 1.0, 1.25, 1.5],
}
## What each level of each slider is called, worst to best.
const LEVEL_LABELS := {
	"view": ["EDITOR_GUARD_VIEW_0", "EDITOR_GUARD_VIEW_1", "EDITOR_GUARD_VIEW_2", "EDITOR_GUARD_VIEW_3", "EDITOR_GUARD_VIEW_4"],
	"hearing": ["EDITOR_GUARD_HEARING_0", "EDITOR_GUARD_HEARING_1", "EDITOR_GUARD_HEARING_2", "EDITOR_GUARD_HEARING_3", "EDITOR_GUARD_HEARING_4"],
	"speed": ["EDITOR_GUARD_SPEED_0", "EDITOR_GUARD_SPEED_1", "EDITOR_GUARD_SPEED_2", "EDITOR_GUARD_SPEED_3", "EDITOR_GUARD_SPEED_4"],
	"attention": ["EDITOR_GUARD_ATTENTION_0", "EDITOR_GUARD_ATTENTION_1", "EDITOR_GUARD_ATTENTION_2", "EDITOR_GUARD_ATTENTION_3", "EDITOR_GUARD_ATTENTION_4"],
}


func duplicate() -> GuardSpawn:
	var g := GuardSpawn.new()
	g.at = at
	g.dir = dir
	g.stance = stance
	g.watch = watch
	g.archetype = archetype
	g.view_level = view_level
	g.hearing_level = hearing_level
	g.speed_level = speed_level
	g.attention_level = attention_level
	return g


func level(stat: String) -> int:
	match stat:
		"view": return view_level
		"hearing": return hearing_level
		"speed": return speed_level
		"attention": return attention_level
	return 2


func set_level(stat: String, v: int) -> void:
	match stat:
		"view": view_level = v
		"hearing": hearing_level = v
		"speed": speed_level = v
		"attention": attention_level = v


## The multiplier for "view", "hearing", "speed" or "attention" this
## guard's slider is set to.
func scale(stat: String) -> float:
	return LEVELS[stat][level(stat)]
