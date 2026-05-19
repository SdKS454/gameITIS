extends Node
class_name SaveManager

const SAVE_PATH := "user://savegame.json"
const RESULT_PATH := "user://battle_result.json"
const MIN_MISSION_ID := 1
const MAX_MISSION_ID := 5

static func normalize_mission_id(raw_value: Variant) -> int:
	var mission_id := int(raw_value)
	if mission_id < MIN_MISSION_ID:
		return MIN_MISSION_ID
	if mission_id > MAX_MISSION_ID:
		return MAX_MISSION_ID
	return mission_id

static func load_savegame() -> Dictionary:
	var result := {"mission_id": MIN_MISSION_ID}
	if not FileAccess.file_exists(SAVE_PATH):
		return result
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return result
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return result
	result["mission_id"] = normalize_mission_id(parsed.get("mission_id", MIN_MISSION_ID))
	return result

static func save_savegame(mission_id: int) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"mission_id": normalize_mission_id(mission_id)}))
	return true

static func load_battle_result() -> Dictionary:
	var fallback := {"won": false, "reason": "", "mission_id": MIN_MISSION_ID}
	if not FileAccess.file_exists(RESULT_PATH):
		return fallback
	var f := FileAccess.open(RESULT_PATH, FileAccess.READ)
	if f == null:
		return fallback
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback
	return {
		"won": bool(parsed.get("won", false)),
		"reason": str(parsed.get("reason", "")),
		"mission_id": normalize_mission_id(parsed.get("mission_id", MIN_MISSION_ID))
	}

static func save_battle_result(won: bool, reason: String, mission_id: int) -> bool:
	var f := FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({
		"won": won,
		"reason": reason,
		"mission_id": normalize_mission_id(mission_id)
	}))
	return true
