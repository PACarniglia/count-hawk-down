extends Control

signal new_game_requested(start_room_id: String, start_entry_id: String)
signal settings_requested
signal credits_requested

const LEVEL_OPTIONS := [
	{"label": "01 - Entry", "room_id": "entry", "entry_id": "EntryPointLeft"},
	{"label": "02 - Movement", "room_id": "movement", "entry_id": "EntryPointLeft"},
	{"label": "03 - Melee", "room_id": "melee", "entry_id": "EntryPointLeft"},
	{"label": "04 - Ranged", "room_id": "ranged", "entry_id": "EntryPointLeft"},
	{"label": "05 - Reflect Lane", "room_id": "reflect_lane", "entry_id": "EntryPointLeft"},
	{"label": "06 - Reflect Arena", "room_id": "reflect_arena", "entry_id": "EntryPointLeft"},
	{"label": "07 - Zig Zag", "room_id": "zig_zag", "entry_id": "EntryPointLeft"},
	{"label": "08 - Reign Of Fire", "room_id": "reign_of_fire", "entry_id": "EntryPointLeft"},
	{"label": "09 - Boss", "room_id": "boss", "entry_id": "EntryPointLeft"},
]

@onready var level_select: OptionButton = $MenuButtons/LevelSelect


func _ready() -> void:
	level_select.clear()
	for option in LEVEL_OPTIONS:
		level_select.add_item(option.label)
	level_select.select(0)

func _on_play_button_pressed() -> void:
	var selected_index := clampi(level_select.selected, 0, LEVEL_OPTIONS.size() - 1)
	var selected_option: Dictionary = LEVEL_OPTIONS[selected_index]
	new_game_requested.emit(selected_option.room_id, selected_option.entry_id)

func _on_settings_button_pressed() -> void:
	settings_requested.emit()

func _on_credits_button_pressed() -> void:
	credits_requested.emit()
