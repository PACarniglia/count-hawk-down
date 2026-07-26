extends CharacterBody2D

const StreamedRoom = preload("res://scenes/world/Room.gd")

signal player_killed

const ENEMY_DEATH_SFX_OPTIONS: Array[AudioStream] = [
	preload("res://sounds/sfx/enemies/enemydie1.wav"),
	preload("res://sounds/sfx/enemies/enemydie2.wav"),
	preload("res://sounds/sfx/enemies/enemydie3.wav"),
]

static var _death_sfx_rng := RandomNumberGenerator.new()
static var _death_sfx_rng_ready := false

@export var move_speed: float = 80.0
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1100.0
@export var state_id: String

var _direction: float = 1.0


func _ready() -> void:
	add_to_group("room_persistent")
	_ensure_death_sfx_rng()


func _physics_process(delta: float) -> void:
	velocity.x = _direction * move_speed
	velocity.y = min(velocity.y + gravity * delta, max_fall_speed)

	move_and_slide()

	# Flip at walls
	if is_on_wall():
		_direction *= -1.0
		return

	# Flip at platform edges — cast a short ray downward just ahead of the foot
	var space := get_world_2d().direct_space_state
	var half_w: float = 14.0
	var probe_x: float = global_position.x + _direction * half_w
	var probe_from := Vector2(probe_x, global_position.y + 16.0)
	var probe_to := Vector2(probe_x, global_position.y + 40.0)
	var query := PhysicsRayQueryParameters2D.create(probe_from, probe_to)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result.is_empty() and is_on_floor():
		_direction *= -1.0

	_update_facing()


func _update_facing() -> void:
	var visual := get_node_or_null("Polygon2D") as Polygon2D
	if visual != null:
		visual.scale.x = _direction


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage()
		player_killed.emit()


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
