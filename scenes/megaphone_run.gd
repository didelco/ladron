class_name MegaphoneRun
extends RefCounted
## The museum's loudspeaker in play: a new one each round, what the gang does and what happens
## (act, say) offered to it, and each tick what the suspicion, the door and how long the gang
## has stood still make it say (Megaphone), as a notice and as a voice (MegaVoice) by the
## mode picked in the settings. Nothing of it in the band's house.

var host: Game
var mega: Megaphone
var mega_still := 0.0
var mega_suspicion := 0
var mega_exit_said := false


func _init(game: Game) -> void:
	host = game


## A new round: the loudspeaker starts from nothing, and welcomes the gang.
func start(n: int) -> void:
	mega = Megaphone.new(n if host.mode == "story" else 0, host.guards.size(), host.thieves.size(), Heist.loot.name, randi())
	mega_still = 0.0
	mega_suspicion = 0
	mega_exit_said = false
	host.hud.megaphone("")
	host.mega_voice.stop(true)
	say("start")


## A thief (who, or -1) did something the loudspeaker may remark on, some
## of the time (Megaphone.act): a roll, a crash, a bin over...
func act(what: String, who := -1) -> void:
	if host.megaphone_mode != "off" and mega and host.mode != "practica" and host.phase == "playing":
		mega.act(what, HeistStats.time, who)


## Something happened the loudspeaker may have a word about.
func say(kind: String) -> void:
	if host.megaphone_mode != "off" and mega and host.mode != "practica":
		mega.say(kind, HeistStats.time)


## Every tick: what the guards' suspicion and the door say, how long the
## gang has stood still, and the notice that comes of it, if any.
func tick(dt: float) -> void:
	if host.megaphone_mode == "off" or mega == null or host.mode == "practica":
		return
	var suspicion := 0
	for g in host.guards:
		suspicion = maxi(suspicion, g.suspicion)
	if suspicion > mega_suspicion and suspicion < 3:
		mega.say("suspect", HeistStats.time)
	if mega_suspicion >= 2 and suspicion == 0:
		act("phew")
	mega_suspicion = suspicion
	for i in host.thieves.size():
		var p := host.thieves[i]
		var going := p.speed > 0.05 and not p.out and not p.rolling and p.dizzy <= 0.0 and not p.hiding
		mega.hold("crawl", going and p.crouched and p.posture > 0.5, dt, HeistStats.time, i)
		mega.hold("run", going and p.sprinting, dt, HeistStats.time, i)
		mega.hold("sneak", going and p.slow, dt, HeistStats.time, i)
	var moving := false
	for p in host.thieves:
		if not p.out and (p.speed > 0.05 or p.game != null or p.hiding or p.posing):
			moving = true
	mega_still = 0.0 if moving else mega_still + dt
	if Heist.taken and not mega_exit_said:
		for p in host.thieves:
			if not p.out and Museum.dist(p.x, p.y, Heist.exit.x + 0.5, Heist.exit.y + 0.5) < 6.0:
				mega_exit_said = true
				mega.say("near_exit", HeistStats.time)
	var tense := suspicion > 0 or host.guards.any(func(g): return g.alert or g.sees_player)
	var told := mega.tick(HeistStats.time, mega_still, tense)
	if not told.is_empty():
		var secs := host.mega_voice.speak(told.key, host.megaphone_mode, host.mode)
		if Settings.megaphone_text(host.megaphone_mode):
			host.hud.megaphone(told.text, MegaVoice.hold_for(secs))
