class_name StreamedRoom
extends Node2D

@export var room_id: String

@onready var camera_anchor: Marker2D = $CameraAnchor


func set_active(active: bool) -> void:
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED


func get_entry(entry_id: String) -> Marker2D:
	return get_node_or_null(entry_id) as Marker2D


func apply_saved_state() -> void:
	for node in get_tree().get_nodes_in_group("room_persistent"):
		if not is_ancestor_of(node):
			continue
		var state_id := str(node.get("state_id"))
		if state_id.is_empty():
			continue
		var state := RoomStateStore.get_entity_state(room_id, state_id)
		if state.get("removed", false):
			node.queue_free()


func _ready() -> void:
	apply_saved_state()
