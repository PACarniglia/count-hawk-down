extends Control

signal new_game_requested
signal settings_requested

func _on_play_button_pressed() -> void:
	new_game_requested.emit()

func _on_settings_button_pressed() -> void:
	settings_requested.emit()
