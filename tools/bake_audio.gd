extends SceneTree
## Bakes the synthesized sounds and music into res://assets/audio/sounds.res.
## Run again after changing the sounds in scripts/audio.gd:
##   godot --headless --path . -s res://tools/bake_audio.gd
func _initialize() -> void:
	var a := Audio.new()
	a._build_sounds()
	var bank := SoundBank.new()
	bank.sounds = a._sounds.duplicate()
	bank.music = {
		"calm": a._music_loop(16.0, 55.0, [0, 3, 5, 7, 10, 12, 15], 0.9, false),
		"boss": a._music_loop(8.0, 49.0, [0, 1, 5, 6, 8, 12, 13], 0.25, true),
	}
	var err := ResourceSaver.save(bank, Audio.BANK)
	print("baked %d sounds + %d music loops -> %s (%s)" % [bank.sounds.size(), bank.music.size(), Audio.BANK, error_string(err)])
	a.free()
	quit()
