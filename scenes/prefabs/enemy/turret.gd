extends StaticBody2D

const StreamedRoom = preload("res://scenes/world/Room.gd")

const ENEMY_DEATH_SFX_OPTIONS: Array[AudioStream] = [
	preload("res://sounds/sfx/enemies/enemydie1.wav"),
	preload("res://sounds/sfx/enemies/enemydie2.wav"),
	preload("res://sounds/sfx/enemies/enemydie3.wav"),
]

static var _death_sfx_rng := RandomNumberGenerator.new()
static var _death_sfx_rng_ready := false

@export var fire_interval: float = 2.5
@export var missile_scene: PackedScene
@export var spawn_offset: Vector2 = Vector2(0, -20)
@export var missile_launch_direction: Vector2 = Vector2.UP
@export var state_id: String

var _fire_timer: float = 0.0


func _ready() -> void:
	add_to_group("room_persistent")
	_ensure_death_sfx_rng()


func _physics_process(delta: float) -> void:
	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_timer = 0.0
		_shoot()


func _shoot() -> void:
	if missile_scene == null:
		return
	var missile: Node = missile_scene.instantiate()
	missile.set("launch_direction", missile_launch_direction)
	missile.global_position = global_position + spawn_offset
	get_tree().current_scene.add_child(missile)


func die() -> void:
	if not ENEMY_DEATH_SFX_OPTIONS.is_empty():
		var death_sfx := ENEMY_DEATH_SFX_OPTIONS[_death_sfx_rng.randi_range(0, ENEMY_DEATH_SFX_OPTIONS.size() - 1)]
		_play_sfx_detached(death_sfx)
	_save_removed_state()
	queue_free()


func _ensure_death_sfx_rng() -> void:
	if _death_sfx_rng_ready:
		return
	_death_sfx_rng.randomize()
	_death_sfx_rng_ready = true


func _play_sfx_detached(stream: AudioStream) -> void:
	if stream == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio_player := AudioStreamPlayer2D.new()
	audio_player.stream = stream
	audio_player.bus = AudioSettings.SFX_BUS
	audio_player.global_position = global_position
	scene.add_child(audio_player)
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()


func _save_removed_state() -> void:
	if state_id.is_empty():
		return
	var node: Node = get_parent()
	while node != null:
		if node is StreamedRoom:
			RoomStateStore.set_entity_state(node.room_id, state_id, {"removed": true})
			return
		node = node.get_parent()
