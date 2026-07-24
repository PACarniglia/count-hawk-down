extends Area2D

@export var speed: float = 220.0
@export var turn_speed: float = 2.8
@export var lifetime: float = 4.0

var _velocity: Vector2 = Vector2.ZERO
var _lifetime_timer: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	_player = _find_player()
	# Launch straight up, let homing steer it toward the player
	_velocity = Vector2.UP * speed
	rotation = Vector2.UP.angle()
	# Defer connection one frame so spawner's collision shape doesn't fire immediately
	call_deferred("_connect_signal")


func _connect_signal() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()
		return

	if is_instance_valid(_player):
		var desired := global_position.direction_to(_player.global_position) * speed
		_velocity = _velocity.move_toward(desired, turn_speed * speed * delta)

	global_position += _velocity * delta

	# Rotate sprite to face movement direction
	rotation = _velocity.angle()


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage()
	queue_free()


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null
