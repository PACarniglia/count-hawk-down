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
	var file := FileAccess.open("user://room_state.save", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(rooms, true)
	return OK


func load_from_disk() -> Error:
	if not FileAccess.file_exists("user://room_state.save"):
		return OK
	var file := FileAccess.open("user://room_state.save", FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var loaded: Variant = file.get_var(true)
	if loaded is Dictionary:
		rooms = loaded
	return OK
