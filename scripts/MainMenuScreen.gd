extends Control

signal new_game_requested
signal settings_requested
signal boss_test_requested

func _on_play_button_pressed() -> void:
	new_game_requested.emit()

func _on_settings_button_pressed() -> void:
	settings_requested.emit()


func _on_boss_test_button_pressed() -> void:
	boss_test_requested.emit()
