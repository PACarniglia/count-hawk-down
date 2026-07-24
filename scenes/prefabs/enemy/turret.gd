extends StaticBody2D

@export var fire_interval: float = 2.5
@export var missile_scene: PackedScene
@export var spawn_offset: Vector2 = Vector2(0, -20)

var _fire_timer: float = 0.0


func _physics_process(delta: float) -> void:
	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_timer = 0.0
		_shoot()


func _shoot() -> void:
	if missile_scene == null:
		return
	var missile: Node = missile_scene.instantiate()
	get_tree().current_scene.add_child(missile)
	missile.global_position = global_position + spawn_offset


func die() -> void:
	queue_free()
