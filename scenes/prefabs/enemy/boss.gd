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

@export var state_id: String

var _hop_timer: float = 0.0
var _missile_timer: float = 0.0
var _player: Node2D = null
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("room_persistent")
	_player = _find_player()
	_hop_timer = hop_cooldown
	_missile_timer = missile_barrage_cooldown
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()

	_hop_timer -= delta
	_missile_timer -= delta

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
	_update_facing()


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


func _update_facing() -> void:
	var visual := get_node_or_null("Polygon2D") as Polygon2D
	if visual == null:
		return
	if velocity.x > 6.0:
		visual.scale.x = 1.0
	elif velocity.x < -6.0:
		visual.scale.x = -1.0


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
