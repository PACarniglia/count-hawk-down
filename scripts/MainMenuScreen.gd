extends Control

signal settings_requested

func _on_settings_button_pressed() -> void:
	settings_requested.emit()
