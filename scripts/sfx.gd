extends Node
## "Sfx" autoload — procedurally synthesized sounds (no audio
## files: the WAV samples are generated in code at startup).
## Played as positional 3D, attenuated with distance.

var _explosion: AudioStreamWAV
var _gunshot: AudioStreamWAV
var _acid: AudioStreamWAV
var _click: AudioStreamWAV
var _laser: AudioStreamWAV


func _ready() -> void:
	_explosion = _make_explosion()
	_gunshot = _make_gunshot()
	_acid = _make_acid()
	_click = _make_click()
	_laser = _make_laser()


## Laser shot: descending zap + lingering beam hum.
func play_laser(pos: Vector3) -> void:
	_play_at(_laser, pos, 12.0, true)


## Mechanical click (fire selector): non-positional, played "in
## the player's ear".
func play_click() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _click
	p.volume_db = -6.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Explosion / destruction: sharp noise + descending low thump.
func play_explosion(pos: Vector3) -> void:
	_play_at(_explosion, pos, 14.0)


## Gunshot: short crack. Played for every bullet; the rate of
## 9/s plus random pitch variation produce the machine-gun sound.
func play_gunshot(pos: Vector3) -> void:
	_play_at(_gunshot, pos, 10.0, true)


## Acid spit: wet descending "gloop" with vibrato.
func play_acid(pos: Vector3) -> void:
	_play_at(_acid, pos, 10.0, true)


func _play_at(stream: AudioStream, pos: Vector3, unit_size: float, vary_pitch := false) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.unit_size = unit_size
	p.max_db = 3.0
	if vary_pitch:
		p.pitch_scale = randf_range(0.92, 1.08)
	get_tree().current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func _make_explosion() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.55
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var phase := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 8.0)
		# Blast: softened white noise (crude low-pass filter)
		var noise := lerpf(prev, rng.randf_range(-1.0, 1.0), 0.35)
		prev = noise
		# Low thump whose frequency drops
		var freq := 140.0 * exp(-t * 3.5) + 40.0
		phase += TAU * freq / rate
		var s := (noise * 0.5 + sin(phase) * 0.7) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _make_gunshot() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.14
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var phase := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 42.0)
		# Crack: sharp noise (lightly filtered) + short low punch
		var noise := lerpf(prev, rng.randf_range(-1.0, 1.0), 0.6)
		prev = noise
		var freq := 230.0 * exp(-t * 20.0) + 60.0
		phase += TAU * freq / rate
		var s := (noise * 0.85 + sin(phase) * 0.45) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _make_acid() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.3
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var phase := 0.0
	for i in n:
		var t := float(i) / rate
		# Fast attack then decay: "spit" envelope
		var env := (1.0 - exp(-t * 90.0)) * exp(-t * 9.0)
		# Wet hiss: descending glissando with vibrato
		var freq := 160.0 + 560.0 * exp(-t * 9.0)
		freq *= 1.0 + 0.14 * sin(t * 70.0)
		phase += TAU * freq / rate
		var s := (sin(phase) * 0.7 + rng.randf_range(-1.0, 1.0) * 0.18) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _make_click() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.06
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in n:
		var t := float(i) / rate
		# Two very short impulses: the "click-clack" of a selector
		var s := sin(TAU * 2400.0 * t) * exp(-t * 320.0) * 0.8
		if t > 0.025:
			s += sin(TAU * 1700.0 * (t - 0.025)) * exp(-(t - 0.025) * 380.0) * 0.55
		s += rng.randf_range(-1.0, 1.0) * exp(-t * 400.0) * 0.25
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _make_laser() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.8
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var phase2 := 0.0
	for i in n:
		var t := float(i) / rate
		# Zap: fast downward sweep, softened square wave
		var f1 := 250.0 + 1150.0 * exp(-t * 14.0)
		phase += TAU * f1 / rate
		var zap := (signf(sin(phase)) * 0.5 + sin(phase) * 0.3) * exp(-t * 7.0)
		# Beam hum: vibrated low frequency, sustained then faded
		var f2 := 160.0 * (1.0 + 0.06 * sin(t * 55.0))
		phase2 += TAU * f2 / rate
		var hum := sin(phase2) * 0.35 * clampf(t * 30.0, 0.0, 1.0) * exp(-t * 4.0)
		var s := zap * 0.7 + hum
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
