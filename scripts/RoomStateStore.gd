extends Node

## Stores changes from each room's authored default layout.
## This is intentionally independent of loaded room instances, so backtracking works.
var rooms: Dictionary = {}
var _start_room_override: String = ""
var _start_entry_override: String = ""


func get_entity_state(room_id: String, state_id: String) -> Dictionary:
	return rooms.get(room_id, {}).get(state_id, {})


func set_entity_state(room_id: String, state_id: String, state: Dictionary) -> void:
	if not rooms.has(room_id):
		rooms[room_id] = {}
	rooms[room_id][state_id] = state.duplicate(true)


func set_start_override(room_id: String, entry_id: String) -> void:
	_start_room_override = room_id
	_start_entry_override = entry_id


func consume_start_override() -> Dictionary:
	if _start_room_override.is_empty():
		return {}
	var override := {
		"room_id": _start_room_override,
		"entry_id": _start_entry_override,
	}
	clear_start_override()
	return override


func clear_start_override() -> void:
	_start_room_override = ""
	_start_entry_override = ""


func save_to_disk() -> Error:
	# Intentionally disabled: state should not persist across app relaunches.
	# We still keep `rooms` in memory for the current run.
	return OK


func load_from_disk() -> Error:
	# Always start fresh each launch.
	rooms = {}
	return OK
