extends Node
## Autoload "Sfx" — sons synthétisés procéduralement (aucun fichier
## audio : les échantillons WAV sont générés en code au démarrage).
## Joués en 3D positionnel, atténués avec la distance.

var _explosion: AudioStreamWAV
var _gunshot: AudioStreamWAV
var _acid: AudioStreamWAV
var _click: AudioStreamWAV


func _ready() -> void:
	_explosion = _make_explosion()
	_gunshot = _make_gunshot()
	_acid = _make_acid()
	_click = _make_click()


## Clic mécanique (sélecteur de tir) : non positionnel, joué "dans
## l'oreille" du joueur.
func play_click() -> void:
	var p := AudioStreamPlayer.new()
	p.stream = _click
	p.volume_db = -6.0
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


## Explosion / destruction : bruit sec + thump grave descendant.
func play_explosion(pos: Vector3) -> void:
	_play_at(_explosion, pos, 14.0)


## Coup de feu : claquement bref. Joué à chaque balle, la cadence de
## 9/s + la variation de pitch aléatoire donnent le son de mitraillette.
func play_gunshot(pos: Vector3) -> void:
	_play_at(_gunshot, pos, 10.0, true)


## Crachat d'acide : "gloub" humide descendant avec vibrato.
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
		# Souffle : bruit blanc adouci (filtre passe-bas grossier)
		var noise := lerpf(prev, rng.randf_range(-1.0, 1.0), 0.35)
		prev = noise
		# Thump grave dont la fréquence chute
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
		# Claquement : bruit vif (peu filtré) + punch grave court
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
		# Attaque rapide puis décroissance : enveloppe "crachat"
		var env := (1.0 - exp(-t * 90.0)) * exp(-t * 9.0)
		# Sifflement humide : glissando descendant avec vibrato
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
		# Deux impulsions très brèves : le "clic-clac" d'un sélecteur
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
