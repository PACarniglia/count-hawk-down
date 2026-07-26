extends Area2D

const MISSILE_LAUNCH_SFX: AudioStream = preload("res://sounds/sfx/enemies/missilelaunch.wav")

@export var speed: float = 220.0
@export var turn_speed: float = 2.8
@export var lifetime: float = 4.0
@export var launch_direction: Vector2 = Vector2.UP

var _velocity: Vector2 = Vector2.ZERO
var _lifetime_timer: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	_player = _find_player()
	call_deferred("_play_spawn_sfx")
	# Launch in given direction; homing steers from there
	_velocity = launch_direction.normalized() * speed
	rotation = _velocity.angle() + PI
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
	rotation = _velocity.angle() + PI


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage()
	if not body.is_in_group("enemy"):
		queue_free()


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _play_spawn_sfx() -> void:
	if MISSILE_LAUNCH_SFX == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var audio_player := AudioStreamPlayer2D.new()
	audio_player.stream = MISSILE_LAUNCH_SFX
	audio_player.bus = AudioSettings.SFX_BUS
	audio_player.global_position = global_position
	scene.add_child(audio_player)
	audio_player.finished.connect(audio_player.queue_free)
	audio_player.play()
