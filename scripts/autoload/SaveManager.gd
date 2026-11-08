extends Node
## Persistence for the city, quests and user settings.

const SAVE_PATH := "user://horizon_city_save.json"
const SETTINGS_PATH := "user://horizon_city_settings.json"

var music_volume: float = 0.68
var sfx_volume: float = 0.85
var shadows: bool = true
var quality: int = 1
var show_tips: bool = true


func _ready() -> void:
	load_settings()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var payload := {
		"version": Cfg.SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"city": GameState.to_dict(),
		"quests": QuestManager.to_dict(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Could not open save file for writing")
		return false
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	return true


func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file is corrupt")
		return {}
	return parsed


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	music_volume = clampf(float(parsed.get("music", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(parsed.get("sfx", sfx_volume)), 0.0, 1.0)
	shadows = bool(parsed.get("shadows", shadows))
	quality = int(parsed.get("quality", quality))
	show_tips = bool(parsed.get("show_tips", show_tips))


func save_settings() -> void:
	var payload := {
		"music": music_volume,
		"sfx": sfx_volume,
		"shadows": shadows,
		"quality": quality,
		"show_tips": show_tips,
	}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()