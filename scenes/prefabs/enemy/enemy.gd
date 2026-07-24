extends CharacterBody2D

signal player_killed

@export var move_speed: float = 80.0
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1100.0

var _direction: float = 1.0


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
	queue_free()
