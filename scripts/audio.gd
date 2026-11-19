class_name Audio
extends Node
## Sound effects and music, synthesized in code (baked once into assets/audio/sounds.res).
## Two buses, "SFX" and "Music", so the settings screen can set their volumes.
## play("hit") plays a short effect; music("calm" / "boss") switches the background loop.

const RATE := 22050
const MUSIC_RATE := 16000
const POOL := 12
## Pre-generated sounds + music (tools/bake_audio.gd); synthesized at start-up only if missing.
const BANK := "res://assets/audio/sounds.res"

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}
var _music_player: AudioStreamPlayer
var _tracks := {}
var _want_track := ""
var _thread: Thread


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("SFX")
	_ensure_bus("Music")
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	_music_player.volume_db = -6.0
	add_child(_music_player)
	# Load the pre-baked sound bank (instant). Only if it is missing, synthesize everything.
	var bank: SoundBank = load(BANK) as SoundBank if ResourceLoader.exists(BANK) else null
	if bank and not bank.sounds.is_empty():
		_sounds = bank.sounds.duplicate()
		_tracks = bank.music.duplicate()
		return
	_build_sounds()
	# Music takes a moment to synthesize, so do it off the main thread.
	_thread = Thread.new()
	_thread.start(_build_music)


func _exit_tree() -> void:
	if _thread and _thread.is_started():
		_thread.wait_to_finish()


static func set_volumes(master: float, sfx: float, music_vol: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master, 0.0001)))
	for pair in [["SFX", sfx], ["Music", music_vol]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(pair[1], 0.0001)))


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")


func play(sound: String, pitch_var := 0.08, volume_db := 0.0) -> void:
	if not _sounds.has(sound):
		return
	# Don't stack the exact same sound many times in one instant (big crowds).
	var now := Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -1000)) < 35:
		return
	_last_played[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _sounds[sound]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = volume_db
	p.play()


func music(track: String) -> void:
	_want_track = track
	if _tracks.has(track):
		if _music_player.stream != _tracks[track] or not _music_player.playing:
			_music_player.stream = _tracks[track]
			_music_player.play()
	elif track == "":
		_music_player.stop()


# ------------------------------------------------------------------ synthesis

func _wav(samples: PackedFloat32Array, rate := RATE, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## One effect: tone (sine/square/saw/noise) with a pitch sweep and a decay envelope.
func _tone(dur: float, f0: float, f1: float, wave: String, vol := 0.5, attack := 0.005, noise_mix := 0.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var k := float(i) / n
		var f := lerpf(f0, f1, k)
		phase += f / RATE
		var x := 0.0
		match wave:
			"sine":
				x = sin(phase * TAU)
			"square":
				x = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"saw":
				x = fmod(phase, 1.0) * 2.0 - 1.0
			"noise":
				# Noise through a sweeping low-pass: f0/f1 act as cutoff.
				var a := clampf(f / RATE * 6.0, 0.01, 1.0)
				lp += (randf_range(-1.0, 1.0) - lp) * a
				x = lp * 2.0
		if noise_mix > 0.0:
			x = lerpf(x, randf_range(-1.0, 1.0), noise_mix)
		var env := minf(1.0, float(i) / maxf(1.0, attack * RATE)) * pow(1.0 - k, 2.0)
		out[i] = x * env * vol
	return out


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset := 0) -> PackedFloat32Array:
	var out := a.duplicate()
	if out.size() < b.size() + offset:
		out.resize(b.size() + offset)
	for i in b.size():
		out[i + offset] += b[i]
	return out


func _build_sounds() -> void:
	_sounds["swing"] = _wav(_tone(0.12, 3500.0, 700.0, "noise", 0.35))
	_sounds["hit"] = _wav(_mix(_tone(0.1, 140.0, 55.0, "sine", 0.7), _tone(0.06, 2500.0, 400.0, "noise", 0.3)))
	_sounds["crit"] = _wav(_mix(_sounds_data_hit(), _tone(0.18, 1400.0, 1300.0, "sine", 0.3)))
	_sounds["kill"] = _wav(_tone(0.16, 420.0, 110.0, "square", 0.22))
	_sounds["hurt"] = _wav(_tone(0.22, 260.0, 90.0, "saw", 0.4, 0.002, 0.2))
	_sounds["dodge"] = _wav(_tone(0.16, 600.0, 3000.0, "noise", 0.3, 0.03))
	_sounds["coin"] = _wav(_mix(_tone(0.09, 1320.0, 1320.0, "sine", 0.25), _tone(0.14, 1760.0, 1760.0, "sine", 0.25), int(0.05 * RATE)))
	_sounds["heart"] = _wav(_tone(0.2, 520.0, 980.0, "sine", 0.35, 0.01))
	_sounds["boom"] = _wav(_mix(_tone(0.45, 1200.0, 80.0, "noise", 0.6), _tone(0.3, 70.0, 40.0, "sine", 0.6)))
	_sounds["ability"] = _wav(_mix(_tone(0.28, 300.0, 1250.0, "sine", 0.3, 0.01), _tone(0.28, 600.0, 2500.0, "square", 0.06, 0.01)))
	_sounds["shoot"] = _wav(_tone(0.08, 900.0, 500.0, "square", 0.12))
	_sounds["click"] = _wav(_tone(0.035, 1100.0, 900.0, "square", 0.15))
	_sounds["stairs"] = _wav(_arpeggio([660.0, 523.0, 440.0, 330.0], 0.11, "sine", 0.3))
	_sounds["power"] = _wav(_arpeggio([330.0, 440.0, 523.0, 660.0, 880.0], 0.1, "square", 0.15))
	_sounds["boss"] = _wav(_mix(_tone(1.0, 75.0, 50.0, "saw", 0.45, 0.05, 0.15), _tone(1.0, 112.0, 70.0, "saw", 0.25, 0.1)))
	_sounds["no"] = _wav(_tone(0.12, 180.0, 150.0, "square", 0.15))


func _sounds_data_hit() -> PackedFloat32Array:
	return _mix(_tone(0.1, 160.0, 60.0, "sine", 0.8), _tone(0.07, 3000.0, 500.0, "noise", 0.35))


func _arpeggio(notes: Array, step: float, wave: String, vol: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in notes.size():
		out = _mix(out, _tone(step * 2.0, notes[i], notes[i], wave, vol), int(i * step * RATE))
	return out


## Background loops: a low drone with slow plucked notes from a minor scale.
## "boss" is faster and darker with a pulsing bass.
func _build_music() -> void:
	var calm := _music_loop(16.0, 55.0, [0, 3, 5, 7, 10, 12, 15], 0.9, false)
	var boss := _music_loop(8.0, 49.0, [0, 1, 5, 6, 8, 12, 13], 0.25, true)
	call_deferred("_music_ready", calm, boss)


func _music_ready(calm: AudioStreamWAV, boss: AudioStreamWAV) -> void:
	_tracks["calm"] = calm
	_tracks["boss"] = boss
	if _want_track != "":
		music(_want_track)


func _music_loop(length: float, root_hz: float, scale: Array, note_every: float, pulse: bool) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(root_hz * 1000) + scale.size()
	var n := int(length * MUSIC_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	# Pre-pick the melody.
	var notes := []
	var t := 0.5
	while t < length - 0.5:
		var semis: int = scale[rng.randi() % scale.size()] + 24
		notes.append([t, root_hz * pow(2.0, semis / 12.0)])
		t += note_every * rng.randi_range(1, 3)
	var p1 := 0.0
	var p2 := 0.0
	for i in n:
		var time := float(i) / MUSIC_RATE
		# Drone: two slightly detuned sines + fifth, slowly swelling (seamless over the loop).
		var swell := 0.75 + 0.25 * sin(time / length * TAU)
		p1 += root_hz / MUSIC_RATE
		p2 += root_hz * 1.005 / MUSIC_RATE
		var x := (sin(p1 * TAU) + sin(p2 * TAU) * 0.8 + sin(p1 * TAU * 1.5) * 0.35) * 0.12 * swell
		if pulse:
			var beat := fmod(time, 0.5) / 0.5
			x += sin(p1 * TAU * 0.5) * 0.25 * pow(1.0 - beat, 3.0)
		out[i] = x
	# Plucked notes.
	for nt in notes:
		var start := int(nt[0] * MUSIC_RATE)
		var f: float = nt[1]
		var dur := int(1.6 * MUSIC_RATE)
		for j in dur:
			if start + j >= n:
				break
			var k := float(j) / dur
			out[start + j] += sin(j * f / MUSIC_RATE * TAU) * 0.12 * pow(1.0 - k, 3.0)
	return _wav(out, MUSIC_RATE, true)
