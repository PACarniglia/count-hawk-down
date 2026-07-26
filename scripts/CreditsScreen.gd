extends Control

signal back_requested


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()


func _on_back_button_pressed() -> void:
	back_requested.emit()
