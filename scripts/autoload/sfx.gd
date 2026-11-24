extends Node
## Procedural audio: sound effects are synthesised at startup; the gamelan-style music loop
## is generated offline by tools/gen_music.py. Autoloaded as `Sfx`.

const RATE := 22050

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.volume_db = -9.0
	add_child(_music)
	_sounds["coin"] = _tones([[1318.5, 0.0, 0.07], [1975.5, 0.05, 0.12]], 0.35, 6.0)
	_sounds["perfect"] = _tones([[784.0, 0.0, 0.12], [987.8, 0.07, 0.12], [1174.7, 0.14, 0.25]], 0.4, 5.0)
	_sounds["island"] = _tones([[523.3, 0.0, 0.9], [659.3, 0.08, 0.9], [784.0, 0.16, 0.9], [1046.5, 0.3, 1.0]], 0.3, 2.2)
	_sounds["click"] = _tones([[660.0, 0.0, 0.04]], 0.3, 25.0)
	_sounds["buy"] = _tones([[659.3, 0.0, 0.1], [880.0, 0.08, 0.1], [1318.5, 0.16, 0.3]], 0.35, 5.0)
	_sounds["bonk"] = _tones([[150.0, 0.0, 0.18]], 0.5, 12.0)
	_sounds["splash"] = _noise(0.35, 0.4)
	_sounds["whoosh"] = _noise(0.25, 0.18)
	_sounds["fizz"] = _noise(0.5, 0.12)
	_sounds["surge"] = _noise(0.7, 0.35)
	_sounds["blub"] = _tones([[220.0, 0.0, 0.12], [300.0, 0.14, 0.12], [250.0, 0.3, 0.14], [320.0, 0.46, 0.16]], 0.45, 14.0)
	_sounds["chomp"] = _tones([[110.0, 0.0, 0.25], [82.0, 0.08, 0.3], [1900.0, 0.0, 0.05], [2400.0, 0.03, 0.04]], 0.55, 9.0)
	var music: AudioStreamOggVorbis = load("res://assets/audio/gamelan_loop.ogg")
	music.loop = true
	_music_ready(music)
	Game.settings_changed.connect(_apply_settings)


func play(name: String, pitch: float = 1.0) -> void:
	if not Game.sound_on or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.pitch_scale = pitch
	p.play()


func _apply_settings() -> void:
	if Game.music_on and _music.stream and not _music.playing:
		_music.play()
	elif not Game.music_on:
		_music.stop()


# ---------------------------------------------------------------- synthesis

func _to_wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## notes: [[freq, start_sec, length_sec], ...]
func _tones(notes: Array, vol: float, decay: float) -> AudioStreamWAV:
	var total := 0.0
	for n in notes:
		total = maxf(total, float(n[1]) + float(n[2]))
	var s := PackedFloat32Array()
	s.resize(int(total * RATE) + 1)
	for n in notes:
		var f: float = n[0]
		var st := int(float(n[1]) * RATE)
		var ln := int(float(n[2]) * RATE)
		for i in ln:
			var t := float(i) / RATE
			var env := exp(-t * decay) * minf(1.0, t * 400.0)
			s[st + i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t)) * env * vol
	return _to_wav(s)


func _noise(length: float, vol: float) -> AudioStreamWAV:
	var s := PackedFloat32Array()
	s.resize(int(length * RATE))
	var last := 0.0
	for i in s.size():
		var t := float(i) / s.size()
		last = lerpf(last, randf_range(-1.0, 1.0), 0.35)
		s[i] = last * vol * sin(PI * t)
	return _to_wav(s)


func _music_ready(stream: AudioStream) -> void:
	_music.stream = stream
	if Game.music_on:
		_music.play()
