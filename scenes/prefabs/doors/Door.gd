class_name RoomDoor
extends Area2D

@export var target_room_id: String
@export var target_entry_id: String

var _used: bool = false


func _on_body_entered(body: Node2D) -> void:
	if _used or not body.is_in_group("player"):
		return
	var manager := get_tree().get_first_node_in_group("room_manager") as RoomManager
	if manager == null:
		push_warning("Room door has no RoomManager.")
		return
	_used = true
	manager.transition_requested.connect(_reset_after_transition, CONNECT_ONE_SHOT)
	manager.request_transition(target_room_id, target_entry_id)


func _reset_after_transition() -> void:
	_used = false
