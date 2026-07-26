extends CharacterBody2D

signal player_killed

@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1200.0
@export var hop_cooldown: float = 2.2
@export var hop_vertical_velocity: float = -860.0
@export var hop_max_horizontal_speed: float = 380.0
@export var hop_target_air_time: float = 1.0
@export var ground_friction: float = 2200.0
@export var missile_scene: PackedScene
@export var missile_barrage_cooldown: float = 4.0
@export var missile_count: int = 7
@export var missile_spread: float = 320.0
@export var missile_spawn_height: float = -20.0
@export var missile_speed: float = 350.0
@export var missile_turn_speed: float = 1.0
@export var frame_size: Vector2i = Vector2i(64, 64)
@export var shoot_frame_hold_time: float = 1.0
@export var shoot_shake_amplitude: float = 2.0

@export var state_id: String

var _hop_timer: float = 0.0
var _missile_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _player: Node2D = null
var _rng := RandomNumberGenerator.new()
@onready var _sprite := get_node_or_null("Sprite2D") as Sprite2D
var _sprite_base_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("room_persistent")
	_player = _find_player()
	_hop_timer = hop_cooldown
	_missile_timer = missile_barrage_cooldown
	_rng.randomize()
	if _sprite != null:
		_sprite_base_position = _sprite.position
		_set_frame(0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()

	_hop_timer -= delta
	_missile_timer -= delta
	_shoot_anim_timer = maxf(_shoot_anim_timer - delta, 0.0)

	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		if _hop_timer <= 0.0:
			_perform_hop()
			_hop_timer = hop_cooldown

	if _missile_timer <= 0.0:
		_fire_missile_barrage()
		_missile_timer = missile_barrage_cooldown

	velocity.y = min(velocity.y + gravity * delta, max_fall_speed)
	move_and_slide()
	_update_animation()


func _perform_hop() -> void:
	var horizontal_speed := 0.0
	if is_instance_valid(_player):
		var delta_x := _player.global_position.x - global_position.x
		horizontal_speed = clampf(delta_x / maxf(hop_target_air_time, 0.1), -hop_max_horizontal_speed, hop_max_horizontal_speed)
	velocity.x = horizontal_speed
	velocity.y = hop_vertical_velocity


func _fire_missile_barrage() -> void:
	if missile_scene == null:
		return
	_shoot_anim_timer = shoot_frame_hold_time
	var n := maxi(missile_count, 1)
	for i in range(n):
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		# Fan from pointing full-left (-PI) to full-right (0) through the top semicircle
		var angle: float = lerp(-PI, 0.0, t)
		var dir := Vector2.from_angle(angle)
		var missile := missile_scene.instantiate()
		# Set properties BEFORE add_child so _ready() sees the correct values
		missile.set("launch_direction", dir)
		missile.set("speed", missile_speed)
		missile.set("turn_speed", missile_turn_speed)
		get_tree().current_scene.add_child(missile)
		missile.global_position = global_position + Vector2(lerp(-missile_spread * 0.5, missile_spread * 0.5, t), missile_spawn_height)


func _update_animation() -> void:
	if _sprite == null:
		return

	if _shoot_anim_timer > 0.0:
		_set_frame(3)
		var shake := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * shoot_shake_amplitude
		_sprite.position = _sprite_base_position + shake
		return

	_sprite.position = _sprite_base_position
	if velocity.y < -20.0:
		_set_frame(1)
	elif velocity.y > 20.0 and not is_on_floor():
		_set_frame(2)
	else:
		_set_frame(0)


func _set_frame(frame_index: int) -> void:
	if _sprite == null:
		return
	var frame_w := float(frame_size.x)
	var frame_h := float(frame_size.y)
	_sprite.region_rect = Rect2(frame_w * frame_index, 0.0, frame_w, frame_h)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage()
		player_killed.emit()


func die() -> void:
	_save_removed_state()
	queue_free()


func _save_removed_state() -> void:
	if state_id.is_empty():
		return
	var node: Node = get_parent()
	while node != null:
		if node is StreamedRoom:
			RoomStateStore.set_entity_state(node.room_id, state_id, {"removed": true})
			return
		node = node.get_parent()


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
