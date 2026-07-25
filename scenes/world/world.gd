extends Node2D

signal game_over_requested(reason: String)

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	player.game_over_requested.connect(_on_player_game_over_requested)


func _on_player_game_over_requested(reason: String) -> void:
	RoomStateStore.save_to_disk()
	game_over_requested.emit(reason)
