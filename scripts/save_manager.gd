class_name SaveManager
extends RefCounted
## Save slots stored as JSON in user:// (works on PC, Android, iOS and web).
## A slot holds one run: class, depth, gold, kills and player stats. The game saves
## automatically at the start of every floor. When the hero dies the run ends
## (alive = false) but the slot keeps the class and the best depth reached.

const SLOT_COUNT := 3
static var prefix := "user://save_"


static func path(slot: int) -> String:
	return "%s%d.json" % [prefix, slot]


static func load_slot(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path(slot)):
		return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


static func save_slot(slot: int, data: Dictionary) -> void:
	data["updated"] = Time.get_datetime_string_from_system(false, true)
	var f := FileAccess.open(path(slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


static func delete_slot(slot: int) -> void:
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))
