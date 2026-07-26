extends Area2D

var definition: SpellDefinition
var direction := Vector2.RIGHT
var lifetime := 0.0
var hit_targets: Array[Node2D] = []


func launch(spell_definition: SpellDefinition, launch_direction: Vector2) -> void:
	definition = spell_definition
	direction = launch_direction.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	if definition == null:
		queue_free()
		return
	lifetime += delta
	if lifetime >= definition.projectile_lifetime:
		queue_free()
		return
	var next_position := global_position + direction * definition.projectile_speed * delta
	if _check_for_body_impact(global_position, next_position):
		return
	global_position = next_position


func _check_for_body_impact(from: Vector2, to: Vector2) -> bool:
	var excluded_rids: Array[RID] = [get_rid()]
	for player in get_tree().get_nodes_in_group("player"):
		var collision_object := player as CollisionObject2D
		if collision_object != null:
			excluded_rids.append(collision_object.get_rid())
	var query := PhysicsRayQueryParameters2D.create(from, to, collision_mask, excluded_rids)
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	global_position = result.position
	_on_body_entered(result.collider as Node2D)
	return true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		return
	if body.is_in_group("enemy"):
		_damage_enemy(body)
	_apply_area_damage()
	queue_free()


func _apply_area_damage() -> void:
	var targets := get_tree().get_nodes_in_group("enemy")
	for target in targets:
		var enemy := target as Node2D
		if enemy == null or not is_instance_valid(enemy) or hit_targets.has(enemy):
			continue
		if enemy.global_position.distance_to(global_position) > definition.area_of_effect:
			continue
		_damage_enemy(enemy)


func _damage_enemy(enemy: Node2D) -> void:
	if hit_targets.has(enemy):
		return
	hit_targets.append(enemy)
	if enemy.has_method("take_damage"):
		enemy.take_damage(definition.damage)
	elif enemy.has_method("die"):
		enemy.die()
	if enemy is Node and (enemy as Node).is_queued_for_deletion():
		_award_fireball_kill_time(enemy)


func _award_fireball_kill_time(enemy: Node) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player := node as Node
		if player != null and player.has_method("kill_enemy"):
			player.kill_enemy(enemy)
			return
