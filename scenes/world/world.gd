extends Node2D

signal game_over_requested(reason: String)

const MAIN_MENU_SCENE_PATH := "res://scenes/MainMenu.tscn"
const BOSS_SCRIPT_PATH := "res://scenes/prefabs/enemy/boss.gd"

@onready var player: CharacterBody2D = $Player
@onready var victory_overlay: Control = $CanvasLayer/VictoryOverlay
@onready var victory_time_label: Label = $CanvasLayer/VictoryOverlay/Panel/VBoxContainer/TimeRemainingLabel
@onready var main_menu_button: Button = $CanvasLayer/VictoryOverlay/Panel/VBoxContainer/MainMenuButton
@onready var game_over_overlay: Control = $CanvasLayer/GameOverOverlay
@onready var game_over_main_menu_button: Button = $CanvasLayer/GameOverOverlay/Panel/VBoxContainer/MainMenuButton
@onready var gameplay_music: AudioStreamPlayer = $GameplayMusic
@onready var game_over_music: AudioStreamPlayer = $GameOverMusic

var _boss_seen := false
var _end_screen_shown := false


func _ready() -> void:
	player.game_over_requested.connect(_on_player_game_over_requested)
	victory_overlay.visible = false
	game_over_overlay.visible = false
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	game_over_main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	gameplay_music.bus = AudioSettings.MUSIC_BUS
	game_over_music.bus = AudioSettings.MUSIC_BUS
	gameplay_music.stream.loop = true
	game_over_music.stream.loop = true
	gameplay_music.play()


func _process(_delta: float) -> void:
	if _end_screen_shown:
		return
	var boss := _find_alive_boss()
	if boss != null:
		_boss_seen = true
		return
	if _boss_seen:
		_show_victory()


func _on_player_game_over_requested(reason: String) -> void:
	_end_screen_shown = true
	RoomStateStore.save_to_disk()
	if gameplay_music.playing:
		gameplay_music.stop()
	if not game_over_music.playing:
		game_over_music.play()
	game_over_overlay.visible = true
	game_over_requested.emit(reason)


func _find_alive_boss() -> Node:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == null:
			continue
		var enemy_script := enemy.get_script() as Script
		if enemy_script != null and enemy_script.resource_path == BOSS_SCRIPT_PATH:
			return enemy
	return null


func _show_victory() -> void:
	_end_screen_shown = true
	RoomStateStore.save_to_disk()
	if player.has_method("trigger_victory"):
		player.trigger_victory()
	if game_over_music.playing:
		game_over_music.stop()
	if not gameplay_music.playing:
		gameplay_music.play()
	var time_remaining := 0.0
	if player.has_method("get_time_remaining"):
		time_remaining = player.get_time_remaining()
	victory_time_label.text = "Time Remaining: %.1fs" % time_remaining
	victory_overlay.visible = true


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)
