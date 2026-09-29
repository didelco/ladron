class_name Sfx
extends Node3D
## All the sound in the game, synthesised at start: no audio files, like the
## web version.
##
## Effects: footsteps and knocks are filtered noise bursts, bells are sums of
## decaying partials, the yell and the sad trombone are gliding saws. Sounds
## from the world play where they happen (a guard on your left is heard on
## the left) through a bus with the reverb of a big empty gallery.
##
## Music: a mystery piece in D minor, rendered once on a worker thread in two
## layers of the same length that loop together. The calm one creeps — a
## drone, a tiptoeing pizzicato bass, a music box echoing down the halls,
## wind. The tense one is a pulse of low strings, timpani and a trembling
## high cluster. The game sets the tension and the layers crossfade.
##
## The band's house has a music of its own (HOME_BPM): slow and warm, a lo-fi
## piece in C major, made the same way on a worker thread of its own. Inside
## the house (home) it fades in over the two above, which fade out; out of
## it, the other way about.

const RATE := 22050
const BPM := 90.0
const BARS := 8
## Sounds from the world that can ring at once; one more steals the oldest.
const VOICES := 16
## A noise this loud (Hearing's reach, in tiles) plays at full volume; the
## loudest crashes go up to MAX_GAIN above it.
const LOUD_REF := 14.0
const MAX_GAIN := 2.0
## the music bus sits a little under the effects, at full volume
const MUSIC_DB := -5.0
## The house's music: slow, and a little quieter than the museum's (it is the
## same bus), and how long the change between the two takes.
const HOME_BPM := 72.0
const HOUSE_GAIN := 0.9
const HOUSE_FADE_S := 1.5

var _streams := {}
## el volumen de la música bus sin bajar, y lo que la baja la megafonía
var _music_db := MUSIC_DB
var _duck_db := 0.0
var _duck_tween: Tween
## Players for world sounds, reused: footsteps alone start several a
## second. The least recently started first.
var _voices: Array[AudioStreamPlayer3D] = []
## Interface sounds all go through one polyphonic player.
var _ui: AudioStreamPlayer
var _ui_playback: AudioStreamPlaybackPolyphonic

var _calm: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _music_task := -1
var _music_data: Array = []
## the house's music: its player, the task that writes it and what it wrote
var _house: AudioStreamPlayer
var _house_task := -1
var _house_wav: AudioStreamWAV
## 0 the museums' music .. 1 the house's, eased towards the target
var _house_mix := 0.0
var _house_target := 0.0
## 0 calm .. 1 chase, eased towards the target
var _tension := 0.0
var _target := 0.0
var _level := 0.6


func _ready() -> void:
	_buses()
	_streams.step = _noise(0.05, 700.0, 0.35)
	# A shoulder into a wall: short, low and dry, no ring to it.
	_streams.bump = _mix(_noise(0.045, 220.0, 0.7), _thump(0.09, 120.0, 60.0, 0.7))
	_streams.shelf = _mix(_noise(0.3, 2600.0, 0.6), _bells([[1350.0, 0.0], [1720.0, 0.05], [2240.0, 0.11]], 0.35, 0.12))
	_streams.alarm = _electric_bell(0.75)
	# The dojo's alarm when a scarecrow's torch finds somebody: a siren.
	_streams.siren = _siren(3.0)
	_streams.shout = _mix(_tones([[420.0, 0.0, 0.16], [300.0, 0.18, 0.28]], "saw", 0.4, 0.72, 6.0), _noise(0.4, 1800.0, 0.12))
	_streams.whisper = _noise(0.35, 3200.0, 0.15)
	_streams.lights = _mix(_noise(0.06, 400.0, 0.9), _buzz(0.55, 0.09))
	_streams.stolen = _bells([[587.3, 0.0], [740.0, 0.09], [880.0, 0.18], [1174.7, 0.27]], 1.2, 0.22)
	_streams.pick = _mix(_noise(0.03, 4000.0, 0.25), _bells([[1760.0, 0.0]], 0.4, 0.12))
	_streams.caught = _trombone()
	_streams.escaped = _mix(_tones([[587.3, 0.0, 0.12], [740.0, 0.12, 0.12], [880.0, 0.24, 0.12], [1174.7, 0.36, 0.5]], "square", 0.22),
		_tones([[293.7, 0.36, 0.6], [440.0, 0.36, 0.6]], "saw", 0.12))
	# A sneeze held in too long: a sharp hiss and a nasal yelp. ACHOO!
	_streams.sneeze = _mix(_noise(0.28, 3800.0, 0.9), _tones([[640.0, 0.0, 0.2]], "saw", 0.35, 0.55))
	# The arcade machine's pong: square bleeps, a jingle up for a point won
	# and down for one lost.
	_streams.pong_hit = _tones([[880.0, 0.0, 0.05]], "square", 0.2)
	_streams.pong_wall = _tones([[440.0, 0.0, 0.04]], "square", 0.16)
	_streams.pong_score = _tones([[660.0, 0.0, 0.07], [880.0, 0.07, 0.07], [1320.0, 0.14, 0.12]], "square", 0.18)
	_streams.pong_miss = _tones([[330.0, 0.0, 0.1], [220.0, 0.1, 0.22]], "square", 0.18)
	_streams.tick = _mix(_bells([[880.0, 0.0]], 0.25, 0.3), _noise(0.02, 3000.0, 0.3))
	_streams.go = _mix(_bells([[587.3, 0.0], [740.0, 0.0], [880.0, 0.0], [1174.7, 0.0]], 0.9, 0.2), _thump(0.5, 110.0, 55.0, 0.6))
	# A smoke bomb: a soft, deep pop and the long hiss of the cloud rushing out.
	_streams.smoke = _mix(_mix(_thump(0.35, 140.0, 45.0, 0.9), _noise(0.05, 5000.0, 0.7)), _noise(1.4, 1200.0, 0.35))
	_streams.sting = _mix(_thump(0.9, 70.0, 38.0, 0.8), _tremolo_cluster(1.3, [1108.7, 1174.7, 1244.5], 0.06))
	# Knocked over. Metal rings: the tin bin clangs, bounces and rattles to
	# a stop. Stone and wood are dry: the bust cracks and smashes into a
	# spray of chips, the panel slaps flat with a knock from its stand. The
	# armour is a heavy crash of steel, then its pieces clanking all about.
	_streams.bin = _mix(_mix(
		_clang([[0.0, 1.0], [0.16, 0.55], [0.27, 0.35], [0.35, 0.22], [0.41, 0.14], [0.45, 0.09]], [612.0, 1587.0, 2291.0, 3413.0], 0.35, 0.5),
		_debris(0.5, 14, 6000.0, 0.25, 1.0)), _thump(0.12, 170.0, 90.0, 0.4))
	_streams.bust = _mix(_mix(_mix(
		_thump(0.22, 110.0, 45.0, 1.0), _noise(0.07, 7000.0, 1.0)),
		_debris(0.55, 26, 5000.0, 0.45, 0.8)), _debris(0.2, 6, 900.0, 0.8, 0.5))
	_streams.panel = _mix(_mix(
		_noise(0.06, 1600.0, 1.0), _thump(0.12, 150.0, 70.0, 0.9)),
		_debris(0.18, 2, 1200.0, 0.6, 0.25))
	_streams.armour = _mix(_mix(_mix(
		_thump(0.2, 120.0, 55.0, 0.9),
		_clang([[0.0, 1.0], [0.09, 0.7], [0.2, 0.5], [0.28, 0.45], [0.37, 0.3], [0.5, 0.22], [0.58, 0.12]], [431.0, 1123.0, 1874.0, 2710.0], 0.3, 0.45)),
		_clang([[0.05, 0.6], [0.14, 0.4], [0.33, 0.35], [0.44, 0.2], [0.66, 0.1]], [789.0, 2040.0, 3150.0], 0.22, 0.3)),
		_debris(0.7, 18, 4200.0, 0.3, 0.6))
	# The same, knocked about once they are down: smaller, but a noise.
	_streams.kick_metal = _clang([[0.0, 0.7], [0.1, 0.3], [0.16, 0.15]], [612.0, 1587.0, 2291.0], 0.2, 0.4)
	_streams.kick_dry = _mix(_noise(0.04, 1400.0, 0.8), _debris(0.15, 4, 3000.0, 0.4, 0.2))
	# Rolling (Roll): the soft rush of a body tumbling over the marble, and
	# the whole of it into a wall, a deep dull thump with plaster pattering.
	_streams.roll = _mix(_noise(0.35, 500.0, 0.3), _thump(0.3, 70.0, 50.0, 0.15))
	_streams.roll_bump = _mix(_mix(_thump(0.32, 95.0, 38.0, 1.0), _noise(0.09, 320.0, 1.0)),
		_debris(0.35, 8, 2200.0, 0.3, 0.7))
	# A door of the band's house sliding: wood on its runner, a dull rumble and
	# a soft knock as it starts.
	_streams.door = _mix(_mix(_noise(0.26, 380.0, 0.22), _thump(0.1, 130.0, 65.0, 0.45)), _thump(0.05, 200.0, 110.0, 0.3))
	# A guard's boot on the marble: heavier and lower than a thief's step.
	_streams.boot = _mix(_thump(0.14, 150.0, 70.0, 0.55), _noise(0.09, 520.0, 0.55))
	# Minigames (Minigame): a pin setting in the lock is a bright little
	# click; the pick slipping, a dry scrape. The cutters: a snip, and the
	# wrong wire, a crackle of sparks.
	_streams.pin = _mix(_noise(0.015, 6000.0, 0.5), _bells([[2637.0, 0.0]], 0.12, 0.14))
	_streams.slip = _noise(0.12, 2200.0, 0.3)
	_streams.snip = _mix(_noise(0.03, 5000.0, 0.6), _thump(0.05, 900.0, 400.0, 0.3))
	_streams.spark = _mix(_buzz(0.25, 0.12), _debris(0.25, 10, 7000.0, 0.2, 0.5))
	# The menus: a soft wooden tick moving about, a two-note chime choosing,
	# a falling blip going back.
	_streams.nav = _mix(_bells([[1568.0, 0.0]], 0.12, 0.08), _noise(0.02, 2500.0, 0.2))
	_streams.ok = _bells([[1046.5, 0.0], [1568.0, 0.07]], 0.35, 0.16)
	_streams.back = _tones([[784.0, 0.0, 0.07], [523.3, 0.07, 0.12]], "sine", 0.22)
	# Every stream is built as samples, then packed once for the engine.
	for k in _streams.keys():
		_streams[k] = _wav(_streams[k])
	_music_task = WorkerThreadPool.add_task(_render_music)
	_house_task = WorkerThreadPool.add_task(_render_house)


## Two buses with reverb, one for the music and one for sounds in the museum,
## and a dry one for the interface.
func _buses() -> void:
	for bus in ["Music", "World"]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, bus)
		AudioServer.set_bus_send(i, "Master")
		var reverb := AudioEffectReverb.new()
		if bus == "Music":
			reverb.room_size = 0.85
			reverb.wet = 0.3
			AudioServer.set_bus_volume_db(i, MUSIC_DB)
		else:
			reverb.room_size = 0.7
			reverb.damping = 0.35
			reverb.wet = 0.25
		AudioServer.add_bus_effect(i, reverb)
	# The interface's sounds: no reverb, but the effects volume like the rest.
	if AudioServer.get_bus_index("Effects") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Effects")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# La voz de la megafonía (MegaVoice): sin reverb (el audio ya la trae),
	# con el volumen de los efectos.
	if AudioServer.get_bus_index("Voice") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Voice")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	child_entered_tree.connect(_route)


## Players left on Master (ui() does not pick a bus) go through Effects, so
## "effects" means every sound but the music.
func _route(node: Node) -> void:
	if node is AudioStreamPlayer and (node as AudioStreamPlayer).bus == &"Master":
		(node as AudioStreamPlayer).bus = &"Effects"


## The music and the effects volumes, 0..1 each. Squared, so the steps sound
## even: halfway is clearly half as loud, not a barely quieter -6 dB.
func set_volumes(music: float, effects: float) -> void:
	_music_db = MUSIC_DB + _db(music)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _music_db + _duck_db)
	for bus in ["World", "Effects", "Voice"]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), _db(effects))


## La música baja `db` (negativo) mientras habla la megafonía; 0.0 la devuelve.
func duck(db: float) -> void:
	if _duck_tween:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck_db, db, 0.3)


func _set_duck(db: float) -> void:
	_duck_db = db
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _music_db + _duck_db)


func _db(level: float) -> float:
	return -80.0 if level <= 0.0 else linear_to_db(level * level)


## Play a sound where it happens in the world. volume 0..1.
## unit is how far (in metres from the listener, which sits on the thief)
## the sound keeps its full volume: small for footsteps, so they swell as a
## guard comes near and die away as it goes.
func at(sound: String, pos: Vector3, volume := 1.0, unit := 6.0) -> void:
	var p := _voice()
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(maxf(volume, 0.01))
	p.unit_size = unit
	p.position = pos
	# No two footsteps quite alike.
	p.pitch_scale = randf_range(0.85, 1.15) if sound in ["step", "bump", "boot", "roll", "roll_bump"] else (randf_range(0.93, 1.07) if sound in ["bin", "bust", "panel", "armour", "kick_metal", "kick_dry", "door"] else 1.0)
	p.play()


## A noise the guards can hear, played as loud as it carries. Its loudness
## is its reach in tiles (Hearing); a sound that reaches twice as far is
## twice as loud here too, so what you hear is what they hear: a creeping
## step is a whisper, a smashed bust is deafening.
func noise(sound: String, pos: Vector3, loudness: float) -> void:
	at(sound, pos, clampf(loudness / LOUD_REF, 0.03, MAX_GAIN), maxf(1.5, loudness * 0.4))


## A world player to use: an idle one, a new one while there are few, or
## else the one that started longest ago. It goes to the back of the queue.
func _voice() -> AudioStreamPlayer3D:
	var p: AudioStreamPlayer3D = null
	for v in _voices:
		if not v.playing:
			p = v
			break
	if p == null and _voices.size() < VOICES:
		p = AudioStreamPlayer3D.new()
		p.unit_size = 6.0
		p.bus = "World"
		add_child(p)
	elif p == null:
		p = _voices[0]
	_voices.erase(p)
	_voices.append(p)
	return p


## Every sound there is, by name (the assets screen lists them).
func sound_names() -> Array:
	var out := _streams.keys()
	out.sort()
	return out


## Play a sound with no place: the interface, the end of a round.
func ui(sound: String, volume := 1.0) -> void:
	if _ui == null:
		_ui = AudioStreamPlayer.new()
		var poly := AudioStreamPolyphonic.new()
		poly.polyphony = 16
		_ui.stream = poly
		add_child(_ui)
		_ui.play()
		_ui_playback = _ui.get_stream_playback()
	_ui_playback.play_stream(_streams[sound], 0.0, linear_to_db(maxf(volume, 0.01)))


## How tense the music is (0 creeping .. 1 chase) and how loud (0..1).
func mood(tension: float, level: float) -> void:
	_target = clampf(tension, 0.0, 1.0)
	_level = level


## In the house (true) or out of it: which of the two musics is heard.
func home(on: bool) -> void:
	_house_target = 1.0 if on else 0.0


## Which is heard: 0 the museums', 1 the house's.
func house_mix() -> float:
	return _house_mix


func set_music(on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)


func _process(dt: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_start_music()
	if _house_task >= 0 and WorkerThreadPool.is_task_completed(_house_task):
		WorkerThreadPool.wait_for_task_completion(_house_task)
		_house_task = -1
		_house = AudioStreamPlayer.new()
		_house.stream = _house_wav
		_house.bus = "Music"
		_house.volume_db = -80.0
		add_child(_house)
		_house.play()
	# A second and a half from one music to the other.
	_house_mix = move_toward(_house_mix, _house_target, dt / HOUSE_FADE_S)
	if _house:
		_house.volume_db = linear_to_db(maxf(0.001, _level * _house_mix * HOUSE_GAIN))
	if _calm == null:
		return
	# Tension comes on fast and goes slowly.
	_tension = move_toward(_tension, _target, dt * (1.2 if _target > _tension else 0.2))
	var museum := 1.0 - _house_mix
	_calm.volume_db = linear_to_db(maxf(0.001, _level * (1.0 - 0.55 * _tension) * museum))
	_tense.volume_db = linear_to_db(maxf(0.001, _level * _tension * museum))


## Closing while the music is still being written: wait for the worker, or
## it carries on into a freed node.
func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
	if _house_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_house_task)
		_house_task = -1


func _start_music() -> void:
	var players: Array[AudioStreamPlayer] = []
	for data in _music_data:
		var w := _wav(data)
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = (data as PackedFloat32Array).size()
		var p := AudioStreamPlayer.new()
		p.stream = w
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		players.append(p)
	_calm = players[0]
	_tense = players[1]
	# Started together, and the same length: they stay in step for ever.
	_calm.play()
	_tense.play()
	_music_data.clear()


# --- Music -------------------------------------------------------------------------

func _render_music() -> void:
	var beat := 60.0 / BPM
	var n := int(BARS * 4 * beat * RATE)
	var loop_s := float(n) / RATE
	var eighth := int(beat / 2.0 * RATE)
	var calm := PackedFloat32Array()
	calm.resize(n)
	var tense := PackedFloat32Array()
	tense.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	# Frequencies nudged to whole cycles per loop, so the seam is silent.
	var fit := func(f: float) -> float: return roundf(f * loop_s) / loop_s

	# Calm: a low drone on D and A that swells and ebbs twice a loop.
	var d1: float = fit.call(73.42)
	var a1: float = fit.call(110.0)
	var d2: float = fit.call(146.83)
	var swell_f: float = 2.0 / loop_s
	for i in n:
		var t := float(i) / RATE
		var swell := 0.55 + 0.45 * sin(TAU * swell_f * t)
		calm[i] = (sin(TAU * d1 * t) + 0.55 * sin(TAU * a1 * t) + 0.2 * sin(TAU * d2 * t)) * 0.045 * swell

	# Wind: noise through a slowly opening and closing filter, the tail
	# folded onto the head so it loops.
	var fold := int(0.8 * RATE)
	var wind := PackedFloat32Array()
	wind.resize(n + fold)
	var y := 0.0
	for i in n + fold:
		var t := float(i) / RATE
		var cut := 260.0 + 130.0 * sin(TAU * t / 5.3) + 60.0 * sin(TAU * t / 2.1)
		var a := 1.0 - exp(-TAU * cut / RATE)
		y += a * (rng.randf() * 2.0 - 1.0 - y)
		wind[i] = y * 0.09
	for i in n:
		var v := wind[i]
		if i < fold:
			var k := float(i) / fold
			v = v * k + wind[n + i] * (1.0 - k)
		calm[i] += v

	# Pizzicato bass, tiptoeing: eighths from D2, -1 a rest.
	var bars := [
		[0, -1, 3, -1, 7, -1, 6, -1],
		[5, -1, 3, -1, 1, -1, 0, -1],
		[0, -1, 3, -1, 7, -1, 8, 7],
		[10, -1, 8, -1, 7, -1, 6, 5],
	]
	var order := [0, 1, 0, 2, 0, 1, 0, 3]
	for b in BARS:
		var pattern: Array = bars[order[b]]
		for e in 8:
			var note: int = pattern[e]
			if note < 0:
				continue
			_pluck(calm, (b * 8 + e) * eighth, 73.42 * pow(2.0, note / 12.0), 0.2 if e % 2 == 0 else 0.13)

	# A music box somewhere down the halls: a few notes every two bars, in
	# D minor, each echoing.
	var box := [587.3, 698.5, 784.0, 880.0, 1046.5, 1174.7, 1108.7]
	for phrase in BARS / 2:
		var start := phrase * 16 + 2 + rng.randi_range(0, 3)
		var notes := rng.randi_range(2, 4)
		for k in notes:
			var at := (start + k * rng.randi_range(1, 2)) * eighth
			var f: float = box[rng.randi_range(0, box.size() - 1)]
			for echo in [[0, 0.06], [int(0.45 * RATE), 0.022], [int(0.9 * RATE), 0.009]]:
				_bell(calm, at + echo[0], f, 2.2, echo[1])

	# Tense: low strings pulsing on D, stepping up to E-flat, with the timpani
	# on the strong beats and a trembling cluster high above.
	var pulse := [0, 0, 0, 1, 0, 0, 0, 1]
	for b in BARS:
		for e in 8:
			var f := 73.42 * pow(2.0, pulse[e] / 12.0)
			_bowed(tense, (b * 8 + e) * eighth, f, 0.2, 0.13 if e == 0 else 0.09)
			_bowed(tense, (b * 8 + e) * eighth, f * 2.0, 0.2, 0.04)
		_timpani(tense, b * 8 * eighth, 0.35)
		_timpani(tense, (b * 8 + 4) * eighth, 0.2)
	var trem: float = fit.call(7.5)
	var high_a: float = fit.call(880.0)
	var high_b: float = fit.call(932.3)
	for i in n:
		var t := float(i) / RATE
		var shiver := 0.5 + 0.5 * sin(TAU * trem * t)
		tense[i] += (sin(TAU * high_a * t) + sin(TAU * high_b * t)) * 0.018 * shiver

	_music_data = [calm, tense]


## A plucked string: bright attack, quick fall. Writes round the loop.
func _pluck(buf: PackedFloat32Array, start: int, f: float, gain: float) -> void:
	var n := buf.size()
	var len := int(0.5 * RATE)
	for i in len:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * exp(-t * 8.0)
		buf[(start + i) % n] += (sin(TAU * f * t) + 0.35 * sin(TAU * 2.0 * f * t) + 0.1 * sin(TAU * 3.0 * f * t)) * env * gain


## A bell or music-box tine: inharmonic partials, a long ring.
func _bell(buf: PackedFloat32Array, start: int, f: float, seconds: float, gain: float) -> void:
	var n := buf.size()
	var len := int(seconds * RATE)
	for i in len:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.002) * exp(-t * 3.0 / seconds * 2.0)
		var v := sin(TAU * f * t) + 0.3 * sin(TAU * 2.76 * f * t) * exp(-t * 4.0) + 0.12 * sin(TAU * 5.4 * f * t) * exp(-t * 8.0)
		buf[(start + i) % n] += v * env * gain


## A short bowed note: a filtered saw, swelling in and cut off.
func _bowed(buf: PackedFloat32Array, start: int, f: float, seconds: float, gain: float) -> void:
	var n := buf.size()
	var len := int(seconds * RATE)
	var phase := 0.0
	var y := 0.0
	var a := 1.0 - exp(-TAU * 900.0 / RATE)
	for i in len:
		var t := float(i) / RATE
		phase += f / RATE
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		y += a * (saw - y)
		var env := minf(1.0, t / 0.02) * (1.0 - t / seconds)
		buf[(start + i) % n] += y * env * gain


## A timpani hit: a sine dropping in pitch, a soft skin noise.
func _timpani(buf: PackedFloat32Array, start: int, gain: float) -> void:
	var n := buf.size()
	var len := int(0.7 * RATE)
	var phase := 0.0
	for i in len:
		var t := float(i) / RATE
		phase += (62.0 + 30.0 * exp(-t * 20.0)) / RATE
		var env := minf(1.0, t / 0.003) * exp(-t * 5.0)
		buf[(start + i) % n] += sin(TAU * phase) * env * gain


# --- The house's music --------------------------------------------------------------

## The chords of the house's eight bars, as MIDI notes: a bass note and four
## above. C major, gently: Fmaj7, Em7, Dm7, G7 / Cmaj7, Am7, Dm7, G7sus4.
const HOUSE_CHORDS := [
	[41, [53, 57, 60, 64]], [40, [52, 55, 59, 62]], [38, [50, 53, 57, 60]], [43, [55, 59, 62, 65]],
	[36, [52, 55, 59, 64]], [45, [57, 60, 64, 67]], [38, [50, 53, 57, 60]], [43, [55, 60, 62, 65]],
]
## The little tune's notes (C pentatonic, MIDI).
const HOUSE_TUNE := [72, 74, 76, 79, 81, 84]


static func _mtof(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## A lo-fi piece for the house, rendered once: an electric piano comping soft
## chords, a round bass, a lazy beat with a swing to it, a little tune now
## and then and the crackle of a record. Eight bars that loop.
func _render_house() -> void:
	var beat := 60.0 / HOME_BPM
	var bars := 8
	var n := int(bars * 4 * beat * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var at := func(b: float) -> int: return int(b * beat * RATE)
	# The swing: the off-beat eighths a little late.
	var swing := func(b: float) -> float: return b + (0.14 if fmod(b, 1.0) >= 0.4 else 0.0)
	for bar in bars:
		var chord: Array = HOUSE_CHORDS[bar]
		var base := bar * 4.0
		# The piano: a rolled chord on the one, a shorter one on the "and" of two.
		for hit in [[0.0, 1.7, 0.075], [1.5, 0.9, 0.05]]:
			var start: int = at.call(swing.call(base + hit[0]))
			for k in 4:
				_keys(buf, start + int(k * 0.018 * RATE), _mtof(chord[1][k]), hit[1] * beat, hit[2])
		# The bass: the root, and its fifth on the three-and.
		_soft_bass(buf, at.call(base), _mtof(chord[0]), 1.3 * beat, 0.24)
		_soft_bass(buf, at.call(swing.call(base + 2.5)), _mtof(chord[0] + (7 if bar % 2 == 0 else 0)), 0.8 * beat, 0.17)
		# The beat: kick on the one and the three-and, snare on two and four,
		# a hat on every eighth, the off-beats softer.
		_kick(buf, at.call(base), 0.32)
		_kick(buf, at.call(swing.call(base + 2.5)), 0.24)
		_snare(buf, at.call(base + 1.0), 0.16, rng)
		_snare(buf, at.call(base + 3.0), 0.16, rng)
		for e in 8:
			var b: float = base + e * 0.5
			_hat(buf, at.call(swing.call(b)), 0.045 if e % 2 == 0 else 0.028, rng)
	# A little tune every two bars: three or four notes of the pentatonic
	# scale, each with its echo.
	for phrase in bars / 2:
		var start_b: float = phrase * 8.0 + 1.0 + rng.randi_range(0, 2)
		var b := start_b
		for k in rng.randi_range(3, 4):
			var note: int = HOUSE_TUNE[rng.randi_range(0, HOUSE_TUNE.size() - 1)]
			var s: int = at.call(swing.call(b))
			for echo in [[0, 0.055], [int(beat * 0.75 * RATE), 0.024], [int(beat * 1.5 * RATE), 0.01]]:
				_tine(buf, s + echo[0], _mtof(note), echo[1])
			b += [0.5, 1.0, 1.5][rng.randi_range(0, 2)]
	# The record: a soft hiss and the odd pop.
	var pop := 0
	for i in n:
		buf[i] += (rng.randf() * 2.0 - 1.0) * 0.0035
		if rng.randf() < 1.0 / 9000.0:
			pop = 60
		if pop > 0:
			buf[i] += (rng.randf() * 2.0 - 1.0) * 0.05 * pop / 60.0
			pop -= 1
	# Level it, so it sits alongside the museum's music.
	var peak := 0.0
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var k := 0.62 / maxf(peak, 0.001)
	for i in n:
		buf[i] *= k
	_house_wav = _wav(buf)
	_house_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_house_wav.loop_begin = 0
	_house_wav.loop_end = n


## An electric piano's note: a tine with a soft bell on top, falling away.
func _keys(buf: PackedFloat32Array, start: int, f: float, seconds: float, gain: float) -> void:
	var n := buf.size()
	var len := int(seconds * RATE)
	for i in len:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.008) * exp(-t * 2.4) * minf(1.0, (seconds - t) / 0.12)
		var th := TAU * f * t
		var v := sin(th + 1.1 * exp(-t * 7.0) * sin(th)) + 0.16 * sin(2.0 * th) * exp(-t * 3.0)
		buf[(start + i) % n] += v * env * gain


## A round bass: a sine with a whisper of its octave.
func _soft_bass(buf: PackedFloat32Array, start: int, f: float, seconds: float, gain: float) -> void:
	var n := buf.size()
	var len := int(seconds * RATE)
	for i in len:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.01) * exp(-t * 2.2) * minf(1.0, (seconds - t) / 0.08)
		buf[(start + i) % n] += (sin(TAU * f * t) + 0.25 * sin(TAU * 2.0 * f * t)) * env * gain


## A music-box tine for the tune.
func _tine(buf: PackedFloat32Array, start: int, f: float, gain: float) -> void:
	var n := buf.size()
	var len := int(1.1 * RATE)
	for i in len:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.003) * exp(-t * 4.5)
		buf[(start + i) % n] += (sin(TAU * f * t) + 0.2 * sin(TAU * 3.0 * f * t) * exp(-t * 6.0)) * env * gain


func _kick(buf: PackedFloat32Array, start: int, gain: float) -> void:
	var n := buf.size()
	var len := int(0.32 * RATE)
	var phase := 0.0
	for i in len:
		var t := float(i) / RATE
		phase += (48.0 + 70.0 * exp(-t * 26.0)) / RATE
		buf[(start + i) % n] += sin(TAU * phase) * minf(1.0, t / 0.002) * exp(-t * 11.0) * gain


func _snare(buf: PackedFloat32Array, start: int, gain: float, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var len := int(0.2 * RATE)
	var y := 0.0
	var a := 1.0 - exp(-TAU * 2600.0 / RATE)
	for i in len:
		var t := float(i) / RATE
		y += a * (rng.randf() * 2.0 - 1.0 - y)
		buf[(start + i) % n] += (y * 1.6 * exp(-t * 20.0) + sin(TAU * 185.0 * t) * 0.5 * exp(-t * 30.0)) * gain


func _hat(buf: PackedFloat32Array, start: int, gain: float, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var len := int(0.05 * RATE)
	var y := 0.0
	var a := 1.0 - exp(-TAU * 7000.0 / RATE)
	for i in len:
		var t := float(i) / RATE
		var x := rng.randf() * 2.0 - 1.0
		y += a * (x - y)
		buf[(start + i) % n] += (x - y) * exp(-t * 90.0) * gain


# --- Effects -----------------------------------------------------------------------

## A burst of low-passed noise with a fast attack and an exponential tail.
func _noise(seconds: float, cutoff: float, gain: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	var y := 0.0
	for i in n:
		y += a * (randf() * 2.0 - 1.0 - y)
		var env := minf(1.0, i / (RATE * 0.004)) * exp(-5.0 * i / n)
		out[i] = y * env * gain * 2.0
	return out


## A few notes: [frequency, start, length] each; glide < 1 bends each note
## down to that fraction of its pitch, like a name yelled down a gallery;
## vibrato in Hz wobbles it.
func _tones(notes: Array, wave: String, gain: float, glide := 1.0, vibrato := 0.0) -> PackedFloat32Array:
	var total := 0.0
	for note in notes:
		total = maxf(total, note[1] + note[2])
	var out := PackedFloat32Array()
	out.resize(int(total * RATE) + 1)
	for note in notes:
		var start := int(note[1] * RATE)
		var n := int(note[2] * RATE)
		var phase := 0.0
		for i in n:
			var t := float(i) / n
			var f: float = note[0] * lerpf(1.0, glide, t)
			if vibrato > 0:
				f *= 1.0 + 0.02 * sin(TAU * vibrato * i / RATE)
			phase += f / RATE
			var s: float
			match wave:
				"square": s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"saw": s = fmod(phase, 1.0) * 2.0 - 1.0
				_: s = sin(phase * TAU)
			var env := minf(1.0, i / (RATE * 0.01)) * (1.0 - t)
			out[start + i] += s * env * gain
	return out


## Bells struck one after another: [frequency, start] each.
func _bells(notes: Array, seconds: float, gain: float) -> PackedFloat32Array:
	var total := 0.0
	for note in notes:
		total = maxf(total, note[1] + seconds)
	var out := PackedFloat32Array()
	out.resize(int(total * RATE) + 1)
	for note in notes:
		_bell(out, int(note[1] * RATE), note[0], seconds, gain)
	return out


## A low thud, its pitch falling from `from` to `to` Hz.
func _thump(seconds: float, from: float, to: float, gain: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += lerpf(to, from, exp(-t * 18.0)) / RATE
		out[i] = sin(TAU * phase) * minf(1.0, t / 0.003) * exp(-t * 6.0 / seconds) * gain
	return out


## An old museum's electric bell: two metal partials hammered sixteen
## times a second.
func _electric_bell(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var strike := fmod(t * 16.0, 1.0)
		var hammer := exp(-strike * 5.0)
		var v := sin(TAU * 1150.0 * t) + 0.6 * sin(TAU * 2650.0 * t) + 0.3 * sin(TAU * 3910.0 * t)
		out[i] = v * hammer * (1.0 - t / seconds) * 0.28
	return out


## A siren going up and down twice a second, softened at the ends.
func _siren(seconds: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += (760.0 + 240.0 * sin(TAU * 1.6 * t)) / RATE
		var v := sin(TAU * phase) + 0.35 * sin(TAU * phase * 2.0)
		out[i] = v * minf(1.0, t / 0.05) * minf(1.0, (seconds - t) / 0.25) * 0.16
	return out


## Fluorescent tubes flickering on: a mains buzz that stutters, then holds.
func _buzz(seconds: float, gain: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += 100.0 / RATE
		var on := 1.0 if t > 0.3 or fmod(t * 23.0, 1.0) < 0.45 else 0.0
		var s := 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		out[i] = s * on * gain * minf(1.0, t / 0.05) * (1.0 - t / seconds)
	return out


## Caught: the sad trombone, wah wah wah waaah.
func _trombone() -> PackedFloat32Array:
	var notes := [[196.0, 0.0, 0.32], [185.0, 0.34, 0.32], [174.6, 0.68, 0.32], [164.8, 1.02, 0.9]]
	var out := PackedFloat32Array()
	out.resize(int(2.0 * RATE))
	for note in notes:
		var start := int(note[1] * RATE)
		var dur: float = note[2]
		var len := int(dur * RATE)
		var phase := 0.0
		var y := 0.0
		for i in len:
			var t := float(i) / RATE
			var last := dur > 0.5
			var f: float = note[0] * (1.0 + (0.025 * sin(TAU * 6.0 * t) if last and t > 0.2 else 0.0))
			phase += f / RATE
			var saw := fmod(phase, 1.0) * 2.0 - 1.0
			# The mute opening and closing: the wah.
			var cut := 500.0 + 1300.0 * sin(PI * minf(1.0, t / dur))
			y += (1.0 - exp(-TAU * cut / RATE)) * (saw - y)
			var env := minf(1.0, t / 0.03) * (1.0 - t / dur)
			out[start + i] += y * env * 0.4
	return out


## A high cluster trembling and dying away: the "you have been seen" sting.
func _tremolo_cluster(seconds: float, freqs: Array, gain: float) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * f * t)
		out[i] = v * gain * (0.5 + 0.5 * sin(TAU * 11.0 * t)) * exp(-t * 2.5)
	return out


## Metal struck and bouncing: every hit ([time, gain]) rings the same
## inharmonic partials, the higher ones dying quickest, over a click.
func _clang(hits: Array, partials: Array, ring: float, gain: float) -> PackedFloat32Array:
	var total := 0.0
	for h in hits:
		total = maxf(total, h[0] + ring)
	var out := PackedFloat32Array()
	out.resize(int(total * RATE) + 1)
	for h in hits:
		var start := int(h[0] * RATE)
		var n := int(ring * RATE)
		var f_jitter := randf_range(0.98, 1.02)
		for i in n:
			var t := float(i) / RATE
			var v := 0.0
			for k in partials.size():
				v += sin(TAU * partials[k] * f_jitter * t) * exp(-t * (6.0 + 5.0 * k) / ring) / (1.0 + 0.6 * k)
			var click := (randf() * 2.0 - 1.0) * exp(-t * 900.0)
			out[start + i] += (v * minf(1.0, t / 0.0015) + click) * h[1] * gain
	return out


## Dry debris: `count` tiny clicks of filtered noise scattered over the
## first `seconds`, thinning out and dying away.
func _debris(seconds: float, count: int, cutoff: float, gain: float, spread: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(int(seconds * RATE) + int(0.03 * RATE))
	var a := 1.0 - exp(-TAU * cutoff / RATE)
	for c in count:
		# Bunched up at the start, like chips landing.
		var at := pow(randf(), 1.8) * seconds * spread
		var start := int(at * RATE)
		var len := int(randf_range(0.006, 0.02) * RATE)
		var g := gain * randf_range(0.4, 1.0) * (1.0 - at / seconds * 0.7)
		var y := 0.0
		for i in len:
			y += a * (randf() * 2.0 - 1.0 - y)
			if start + i < out.size():
				out[start + i] += y * exp(-6.0 * i / len) * g * 2.0
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var out := a.duplicate() if a.size() >= b.size() else b.duplicate()
	var other := b if a.size() >= b.size() else a
	for i in other.size():
		out[i] += other[i]
	return out


## Samples to a 16-bit wave the engine can play.
func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
