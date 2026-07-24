extends Node2D

signal game_over_requested(reason: String)

@onready var player: CharacterBody2D = $Player


func _ready() -> void:
	if player != null and player.has_signal("game_over_requested"):
		player.game_over_requested.connect(_on_player_game_over_requested)


func _on_player_game_over_requested(reason: String) -> void:
	game_over_requested.emit(reason)
	push_warning("Game over requested: %s" % reason)
