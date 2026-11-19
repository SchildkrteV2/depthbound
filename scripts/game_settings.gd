class_name GameSettings
extends RefCounted
## Player settings saved to user://settings.json.

const PATH := "user://settings.json"

static var values := {
	"master": 0.8,
	"sfx": 0.8,
	"music": 0.5,
	"button_scale": 1.0,
	"swap_sides": false, # move on the right, attack on the left
	"screen_shake": true,
	"show_fps": false,
	"tutorial": true,
}
static var path_override := ""


static func _path() -> String:
	return path_override if path_override != "" else PATH


static func load_settings() -> void:
	if FileAccess.file_exists(_path()):
		var f := FileAccess.open(_path(), FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			values.merge(d, true)
	apply()


static func save() -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(values, "\t"))
	apply()


static func apply() -> void:
	Audio.set_volumes(values["master"], values["sfx"], values["music"])


static func get_value(key: String):
	return values[key]
