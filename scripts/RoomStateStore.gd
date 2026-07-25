extends Node

## Stores changes from each room's authored default layout.
## This is intentionally independent of loaded room instances, so backtracking works.
var rooms: Dictionary = {}


func get_entity_state(room_id: String, state_id: String) -> Dictionary:
	return rooms.get(room_id, {}).get(state_id, {})


func set_entity_state(room_id: String, state_id: String, state: Dictionary) -> void:
	if not rooms.has(room_id):
		rooms[room_id] = {}
	rooms[room_id][state_id] = state.duplicate(true)


func save_to_disk() -> Error:
	# Intentionally disabled: state should not persist across app relaunches.
	# We still keep `rooms` in memory for the current run.
	return OK


func load_from_disk() -> Error:
	# Always start fresh each launch.
	rooms = {}
	return OK
