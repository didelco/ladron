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

const RATE := 22050
const BPM := 90.0
const BARS := 8

var _streams := {}
var _calm: AudioStreamPlayer
var _tense: AudioStreamPlayer
var _music_task := -1
var _music_data: Array = []
## 0 calm .. 1 chase, eased towards the target
var _tension := 0.0
var _target := 0.0
var _level := 0.6


func _ready() -> void:
	_buses()
	_streams.step = _noise(0.05, 700.0, 0.35)
	_streams.bump = _mix(_noise(0.14, 250.0, 0.8), _thump(0.25, 90.0, 50.0, 0.5))
	_streams.shelf = _mix(_noise(0.3, 2600.0, 0.6), _bells([[1350.0, 0.0], [1720.0, 0.05], [2240.0, 0.11]], 0.35, 0.12))
	_streams.alarm = _electric_bell(0.75)
	_streams.shout = _mix(_tones([[420.0, 0.0, 0.16], [300.0, 0.18, 0.28]], "saw", 0.4, 0.72, 6.0), _noise(0.4, 1800.0, 0.12))
	_streams.whisper = _noise(0.35, 3200.0, 0.15)
	_streams.lights = _mix(_noise(0.06, 400.0, 0.9), _buzz(0.55, 0.09))
	_streams.stolen = _bells([[587.3, 0.0], [740.0, 0.09], [880.0, 0.18], [1174.7, 0.27]], 1.2, 0.22)
	_streams.pick = _mix(_noise(0.03, 4000.0, 0.25), _bells([[1760.0, 0.0]], 0.4, 0.12))
	_streams.caught = _trombone()
	_streams.escaped = _mix(_tones([[587.3, 0.0, 0.12], [740.0, 0.12, 0.12], [880.0, 0.24, 0.12], [1174.7, 0.36, 0.5]], "square", 0.22),
		_tones([[293.7, 0.36, 0.6], [440.0, 0.36, 0.6]], "saw", 0.12))
	_streams.tick = _mix(_bells([[880.0, 0.0]], 0.25, 0.3), _noise(0.02, 3000.0, 0.3))
	_streams.go = _mix(_bells([[587.3, 0.0], [740.0, 0.0], [880.0, 0.0], [1174.7, 0.0]], 0.9, 0.2), _thump(0.5, 110.0, 55.0, 0.6))
	_streams.sting = _mix(_thump(0.9, 70.0, 38.0, 0.8), _tremolo_cluster(1.3, [1108.7, 1174.7, 1244.5], 0.06))
	# Knocked over: a tin bin clattering and rolling, a bust smashing, a
	# panel slapping flat on the floor.
	_streams.bin = _mix(_mix(_noise(0.5, 3000.0, 0.55), _bells([[523.0, 0.0], [611.0, 0.12], [587.0, 0.26], [640.0, 0.38]], 0.3, 0.12)), _thump(0.3, 140.0, 70.0, 0.4))
	_streams.bust = _mix(_mix(_thump(0.6, 90.0, 40.0, 0.9), _noise(0.7, 5000.0, 0.7)), _bells([[2637.0, 0.05], [3136.0, 0.09], [2349.0, 0.14], [3520.0, 0.2]], 0.25, 0.1))
	_streams.panel = _mix(_thump(0.35, 180.0, 70.0, 0.8), _noise(0.25, 900.0, 0.8))
	# Every stream is built as samples, then packed once for the engine.
	for k in _streams.keys():
		_streams[k] = _wav(_streams[k])
	_music_task = WorkerThreadPool.add_task(_render_music)


## Two buses with reverb: one for the music, one for sounds in the museum.
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
			AudioServer.set_bus_volume_db(i, -5.0)
		else:
			reverb.room_size = 0.7
			reverb.damping = 0.35
			reverb.wet = 0.25
		AudioServer.add_bus_effect(i, reverb)


## Play a sound where it happens in the world. volume 0..1.
func at(sound: String, pos: Vector3, volume := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(maxf(volume, 0.01))
	p.unit_size = 6.0
	p.position = pos
	p.bus = "World"
	# No two footsteps quite alike.
	if sound == "step" or sound == "bump":
		p.pitch_scale = randf_range(0.85, 1.15)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Play a sound with no place: the interface, the end of a round.
func ui(sound: String, volume := 1.0) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(maxf(volume, 0.01))
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## How tense the music is (0 creeping .. 1 chase) and how loud (0..1).
func mood(tension: float, level: float) -> void:
	_target = clampf(tension, 0.0, 1.0)
	_level = level


func set_music(on: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)


func _process(dt: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_start_music()
	if _calm == null:
		return
	# Tension comes on fast and goes slowly.
	_tension = move_toward(_tension, _target, dt * (1.2 if _target > _tension else 0.2))
	_calm.volume_db = linear_to_db(maxf(0.001, _level * (1.0 - 0.55 * _tension)))
	_tense.volume_db = linear_to_db(maxf(0.001, _level * _tension))


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
