extends Area2D

const MISSILE_LAUNCH_SFX: AudioStream = preload("res://sounds/sfx/enemies/missilelaunch.wav")
const FIREBALL_SHEET: Texture2D = preload("res://sprites/hero/fireball_spritesheet.png")
const BOSS_SCRIPT_PATH := "res://scenes/prefabs/enemy/boss.gd"

@export var speed: float = 220.0
@export var turn_speed: float = 2.8
@export var lifetime: float = 4.0
@export var launch_direction: Vector2 = Vector2.UP
@export var reflected_speed_multiplier: float = 1.8

var _velocity: Vector2 = Vector2.ZERO
var _lifetime_timer: float = 0.0
var _player: Node2D = null
var _is_reflected: bool = false


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

	if not _is_reflected and is_instance_valid(_player):
		var desired := global_position.direction_to(_player.global_position) * speed
		_velocity = _velocity.move_toward(desired, turn_speed * speed * delta)

	global_position += _velocity * delta

	# Rotate sprite to face movement direction
	rotation = _velocity.angle() + PI


func reflect_from_player(player_position: Vector2, mouse_position: Vector2) -> void:
	_is_reflected = true
	var reflected_direction := player_position.direction_to(mouse_position)
	if reflected_direction == Vector2.ZERO:
		reflected_direction = _velocity.normalized()
	if reflected_direction == Vector2.ZERO:
		reflected_direction = Vector2.RIGHT
	_velocity = reflected_direction * speed * reflected_speed_multiplier


func _on_body_entered(body: Node) -> void:
	if _is_reflected:
		if body.is_in_group("enemy"):
			var is_boss := _is_boss(body)
			if body.has_method("take_damage"):
				body.take_damage(2 if is_boss else 1)
			elif body.has_method("die"):
				body.die()
			if body is Node and (body as Node).is_queued_for_deletion():
				_award_reflect_kill_time()
			if is_boss:
				_spawn_boss_reflect_explosion(global_position)
			queue_free()
			return
		if body.is_in_group("player"):
			return
		queue_free()
		return

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


func _is_boss(node: Node) -> bool:
	if node == null:
		return false
	var script := node.get_script() as Script
	return script != null and script.resource_path == BOSS_SCRIPT_PATH


func _spawn_boss_reflect_explosion(at_position: Vector2) -> void:
	if FIREBALL_SHEET == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	var atlas_a := AtlasTexture.new()
	atlas_a.atlas = FIREBALL_SHEET
	atlas_a.region = Rect2(0, 0, 32, 32)
	var atlas_b := AtlasTexture.new()
	atlas_b.atlas = FIREBALL_SHEET
	atlas_b.region = Rect2(32, 0, 32, 32)

	var frames := SpriteFrames.new()
	frames.add_animation("explode")
	frames.set_animation_loop("explode", true)
	frames.set_animation_speed("explode", 14.0)
	frames.add_frame("explode", atlas_a)
	frames.add_frame("explode", atlas_b)

	var explosion := AnimatedSprite2D.new()
	explosion.sprite_frames = frames
	explosion.animation = &"explode"
	explosion.global_position = at_position
	explosion.scale = Vector2(2.2, 2.2)
	explosion.modulate = Color(1.0, 0.2, 0.2, 0.95)
	scene.add_child(explosion)
	explosion.play()

	var tween := explosion.create_tween()
	tween.set_parallel(true)
	tween.tween_property(explosion, "scale", Vector2(3.2, 3.2), 0.18)
	tween.tween_property(explosion, "modulate:a", 0.0, 0.18)
	tween.finished.connect(explosion.queue_free)


func _award_reflect_kill_time() -> void:
	if not is_instance_valid(_player):
		_player = _find_player()
	if _player != null and _player.has_method("kill_enemy"):
		_player.kill_enemy()
