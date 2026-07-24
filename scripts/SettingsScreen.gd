extends Control

signal back_requested

@onready var master_slider: HSlider = %MasterSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var sound_effects_slider: HSlider = %SoundEffectsSlider

func _ready() -> void:
	master_slider.value = AudioSettings.master_volume
	music_slider.value = AudioSettings.music_volume
	sound_effects_slider.value = AudioSettings.sound_effects_volume

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

func _on_master_slider_value_changed(value: float) -> void:
	AudioSettings.set_master_volume(value)

func _on_music_slider_value_changed(value: float) -> void:
	AudioSettings.set_music_volume(value)

func _on_sound_effects_slider_value_changed(value: float) -> void:
	AudioSettings.set_sound_effects_volume(value)

func _on_back_button_pressed() -> void:
	back_requested.emit()
