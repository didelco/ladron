class_name Sfx
extends Node3D
## All the sound in the game, synthesised once at start: no audio files, like
## the web version. Footsteps and knocks are filtered noise bursts, the alarm
## and the yell are tones. Sounds from the world play where they happen, so
## a guard walking past on your left is heard on the left.

const RATE := 22050

var _streams := {}


func _ready() -> void:
	_streams.step = _noise(0.06, 900.0, 0.5)
	_streams.bump = _noise(0.12, 300.0, 0.9)
	_streams.shelf = _mix(_noise(0.25, 2600.0, 0.7), _tones([[1350.0, 0.0, 0.18], [1720.0, 0.05, 0.14]], "square", 0.12))
	_streams.alarm = _tones([[1480.0, 0.0, 0.12], [1180.0, 0.14, 0.12]], "square", 0.35)
	_streams.shout = _tones([[420.0, 0.0, 0.16], [300.0, 0.18, 0.26]], "saw", 0.45, 0.72)
	_streams.whisper = _noise(0.35, 3200.0, 0.15)
	_streams.lights = _mix(_noise(0.05, 1800.0, 0.6), _tones([[100.0, 0.08, 0.5]], "square", 0.12))
	_streams.stolen = _tones([[880.0, 0.0, 0.1], [1320.0, 0.1, 0.18]], "sine", 0.4)
	_streams.pick = _noise(0.03, 4000.0, 0.25)
	_streams.caught = _tones([[392.0, 0.0, 0.25], [330.0, 0.25, 0.25], [262.0, 0.5, 0.5]], "square", 0.3)
	_streams.escaped = _tones([[523.0, 0.0, 0.14], [659.0, 0.14, 0.14], [784.0, 0.28, 0.3]], "square", 0.3)
	# Every stream is built as samples, then packed once for the engine.
	for k in _streams.keys():
		_streams[k] = _wav(_streams[k])


## Play a sound where it happens in the world. volume 0..1.
func at(sound: String, pos: Vector3, volume := 1.0) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(maxf(volume, 0.01))
	p.unit_size = 6.0
	p.position = pos
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


# --- Synthesis ---------------------------------------------------------------------

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
## down to that fraction of its pitch, like a name yelled down a gallery.
func _tones(notes: Array, wave: String, gain: float, glide := 1.0) -> PackedFloat32Array:
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
			phase += f / RATE
			var s: float
			match wave:
				"square": s = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
				"saw": s = fmod(phase, 1.0) * 2.0 - 1.0
				_: s = sin(phase * TAU)
			var env := minf(1.0, i / (RATE * 0.01)) * (1.0 - t)
			out[start + i] += s * env * gain
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
