class_name Decision
extends RefCounted
## What a guard set out to do: a plan, where it leads, and how to go about it.
## Made by Laya from a menu of options (Mind), or by the fallback rules.

## One line on a guard's menu: what it would do, where, and how it reads.
class Option:
	var key: String
	## chase, cut_off, follow, search, check_zone, cover, patrol, watch
	var plan: String
	var target: Vector2i
	## what Laya reads
	var text: String
	## what the HUD shows
	var label: String

var id: String
var plan := "patrol"
## which option was taken
var option := "patrol"
var label := ""
var target := Vector2i.ZERO
## how the torch is held: sweep, ahead or clue
var look := "ahead"
## Laya's probabilities over the options, and their labels, for the HUD
var probabilities := {}
var labels := {}
var confidence := 0.5
## the two best plans were neck and neck: the guard hesitates
var torn := false
## 0..1, how hard the guard commits: drives speed
var aggression := 0.2
## P(the thief is still close to the clue): how tight the search is
var near := 0.5
## P(the thief is hiding rather than running): where the search looks
var hiding := 0.5
var ms := 0
