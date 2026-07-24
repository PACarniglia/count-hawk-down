extends Node

## Runtime-wide audio controls. New sound effects should use the SFX bus.
const MASTER_BUS := &"Master"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const BUS_LAYOUT: AudioBusLayout = preload("res://config/default_bus_layout.tres")

var master_volume := 1.0
var music_volume := 1.0
var sound_effects_volume := 1.0

func _enter_tree() -> void:
	AudioServer.set_bus_layout(BUS_LAYOUT)

func _ready() -> void:
	_apply_volume(MASTER_BUS, master_volume)
	_apply_volume(MUSIC_BUS, music_volume)
	_apply_volume(SFX_BUS, sound_effects_volume)

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	_apply_volume(MASTER_BUS, master_volume)

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_volume(MUSIC_BUS, music_volume)

func set_sound_effects_volume(value: float) -> void:
	sound_effects_volume = clampf(value, 0.0, 1.0)
	_apply_volume(SFX_BUS, sound_effects_volume)

func _apply_volume(bus_name: StringName, volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("Audio bus '%s' is missing." % bus_name)
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(bus_index, is_zero_approx(volume))
