class_name RoomManager
extends Node

const StreamedRoom = preload("res://scenes/world/Room.gd")

signal transition_requested

const ROOM_DATA := {
	"entry": {
		"path": "res://scenes/Rooms/01_entry_room.tscn",
		"position": Vector2(0, 0),
		"neighbors": ["movement"],
	},
	"movement": {
		"path": "res://scenes/Rooms/02_movement_explination.tscn",
		"position": Vector2(1280, 0),
		"neighbors": ["entry", "melee"],
	},
	"melee": {
		"path": "res://scenes/Rooms/03_basic_melee_combat.tscn",
		"position": Vector2(2560, 0),
		"neighbors": ["movement", "ranged"],
	},
	"ranged": {
		"path": "res://scenes/Rooms/04_basic_range_combat.tscn",
		"position": Vector2(3840, 0),
		"neighbors": ["melee", "reflect_lane"],
	},
	"reflect_lane": {
		"path": "res://scenes/Rooms/05_reflect_lane.tscn",
		"position": Vector2(5120, 0),
		"neighbors": ["ranged", "reflect_arena"],
	},
	"reflect_arena": {
		"path": "res://scenes/Rooms/06_reflect_arena.tscn",
		"position": Vector2(6400, 0),
		"neighbors": ["reflect_lane", "zig_zag"],
	},
	"zig_zag": {
		"path": "res://scenes/Rooms/05_zig_zag_room.tscn",
		"position": Vector2(7680, 0),
		"neighbors": ["reflect_arena", "reign_of_fire"],
	},
	"reign_of_fire": {
		"path": "res://scenes/Rooms/06_reign_of_fire.tscn",
		"position": Vector2(8960, 0),
		"neighbors": ["zig_zag", "boss"],
	},
	"boss": {
		"path": "res://scenes/Rooms/05_boss_room.tscn",
		"position": Vector2(10240, 0),
		"neighbors": ["reign_of_fire"],
	},
}

@export var starting_room_id := "entry"
@export var starting_entry_id := "EntryPointLeft"
@export var transition_duration := 0.55
@export var door_retrigger_lockout := 0.2

var current_room_id := ""
var loaded_rooms: Dictionary = {}
var is_transitioning := false
var _door_retrigger_locked := false

@onready var world := get_parent() as Node2D
@onready var loaded_rooms_root := world.get_node("LoadedRooms") as Node2D
@onready var player := world.get_node("Player") as CharacterBody2D
@onready var camera := world.get_node("Camera2D") as Camera2D


func _ready() -> void:
	add_to_group("room_manager")
	call_deferred("_start")


func _start() -> void:
	RoomStateStore.load_from_disk()
	var selected_start_room_id := starting_room_id
	var selected_start_entry_id := starting_entry_id
	var start_override := RoomStateStore.consume_start_override()
	if not start_override.is_empty():
		var override_room_id := str(start_override.get("room_id", ""))
		if ROOM_DATA.has(override_room_id):
			selected_start_room_id = override_room_id
			selected_start_entry_id = str(start_override.get("entry_id", starting_entry_id))

	var room := load_room(selected_start_room_id)
	var entry := room.get_entry(selected_start_entry_id)
	if entry == null:
		entry = room.get_entry("EntryPointLeft")
	if entry == null:
		entry = room.get_entry("EntryPointRight")
	if entry == null:
		push_error("Missing entry '%s' in room '%s'." % [selected_start_entry_id, selected_start_room_id])
		return
	current_room_id = selected_start_room_id
	room.set_active(true)
	player.global_position = entry.global_position
	camera.global_position = room.camera_anchor.global_position
	load_neighbors(current_room_id)
	update_room_activity()


func request_transition(target_room_id: String, target_entry_id: String) -> bool:
	if is_transitioning or _door_retrigger_locked or target_room_id == current_room_id:
		return false
	transition_to(target_room_id, target_entry_id)
	return true


func transition_to(target_room_id: String, target_entry_id: String) -> void:
	if not ROOM_DATA.has(target_room_id):
		push_error("Unknown room ID: %s" % target_room_id)
		return
	is_transitioning = true
	player.set("input_locked", true)

	var target_room := load_room(target_room_id)
	var target_entry := target_room.get_entry(target_entry_id)
	if target_entry == null:
		push_error("Missing entry '%s' in room '%s'." % [target_entry_id, target_room_id])
		player.set("input_locked", false)
		is_transitioning = false
		return

	var tween := create_tween().set_parallel(true)
	tween.tween_property(camera, "global_position", target_room.camera_anchor.global_position, transition_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player, "global_position", target_entry.global_position, transition_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

	current_room_id = target_room_id
	load_neighbors(current_room_id)
	unload_distant_rooms()
	update_room_activity()
	player.set("input_locked", false)
	is_transitioning = false
	transition_requested.emit()
	if door_retrigger_lockout > 0.0:
		_door_retrigger_locked = true
		await get_tree().create_timer(door_retrigger_lockout).timeout
		_door_retrigger_locked = false


func load_room(room_id: String) -> StreamedRoom:
	if loaded_rooms.has(room_id):
		return loaded_rooms[room_id] as StreamedRoom
	var data: Dictionary = ROOM_DATA[room_id]
	var scene := load(data.path) as PackedScene
	if scene == null:
		push_error("Could not load room scene: %s" % data.path)
		return null
	var room := scene.instantiate() as StreamedRoom
	loaded_rooms_root.add_child(room)
	room.global_position = data.position
	loaded_rooms[room_id] = room
	room.set_active(room_id == current_room_id)
	return room


func load_neighbors(room_id: String) -> void:
	for neighbor_id in ROOM_DATA[room_id].neighbors:
		load_room(neighbor_id)


func unload_distant_rooms() -> void:
	var keep: Array = [current_room_id]
	keep.append_array(ROOM_DATA[current_room_id].neighbors)
	for room_id in loaded_rooms.keys():
		if room_id in keep:
			continue
		var room := loaded_rooms[room_id] as StreamedRoom
		room.queue_free()
		loaded_rooms.erase(room_id)


func update_room_activity() -> void:
	for room_id in loaded_rooms.keys():
		var room := loaded_rooms[room_id] as StreamedRoom
		if room == null:
			continue
		room.set_active(room_id == current_room_id)
