extends CharacterBody2D

const StreamedRoom = preload("res://scenes/world/Room.gd")

signal player_killed

const SFX_CANTLOSE: AudioStream = preload("res://sounds/sfx/boss/cantlose.wav")
const SFX_HYA: AudioStream = preload("res://sounds/sfx/boss/hya.wav")
const MISSILE_SFX_OPTIONS: Array[AudioStream] = [
	preload("res://sounds/sfx/boss/dinner.wav"),
	preload("res://sounds/sfx/boss/hammers.wav"),
	preload("res://sounds/sfx/boss/ticktok.wav"),
	preload("res://sounds/sfx/boss/timesup.wav"),
]

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
@export var max_health: int = 8
@export var hit_flash_duration: float = 0.16
@export var iframes_duration: float = 0.5
@export var hp_bar_width: float = 420.0
@export var hp_bar_height: float = 20.0

@export var state_id: String

var _hop_timer: float = 0.0
var _missile_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _player: Node2D = null
var _rng := RandomNumberGenerator.new()
var _health: int = 1
var _hit_flash_timer: float = 0.0
var _iframes_timer: float = 0.0
@onready var _sprite := get_node_or_null("Sprite2D") as Sprite2D
var _sprite_base_position: Vector2 = Vector2.ZERO
var _hp_ui_root: Control = null
var _hp_bar_fill: ColorRect = null


func _ready() -> void:
	_player = _find_player()
	_hop_timer = hop_cooldown
	_missile_timer = missile_barrage_cooldown
	_rng.randomize()
	_health = maxi(max_health, 1)
	if _sprite != null:
		_sprite_base_position = _sprite.position
		_set_frame(0)
	_setup_hp_bar_ui()
	_update_hp_bar_ui()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = _find_player()

	_hop_timer -= delta
	_missile_timer -= delta
	_shoot_anim_timer = maxf(_shoot_anim_timer - delta, 0.0)
	_hit_flash_timer = maxf(_hit_flash_timer - delta, 0.0)
	_iframes_timer = maxf(_iframes_timer - delta, 0.0)
	if _sprite != null:
		_sprite.modulate = Color(1.0, 0.35, 0.35, 1.0) if _hit_flash_timer > 0.0 else Color.WHITE

	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
		if _hop_timer <= 0.0:
			_perform_hop()
			_hop_timer = _get_hop_cooldown()

	if _missile_timer <= 0.0:
		_fire_missile_barrage()
		_missile_timer = _get_missile_cooldown()

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
	if _rng.randi_range(1, 3) == 1:
		_play_sfx_detached(SFX_HYA)


func _fire_missile_barrage() -> void:
	if missile_scene == null:
		return
	_shoot_anim_timer = shoot_frame_hold_time
	if not MISSILE_SFX_OPTIONS.is_empty():
		var missile_sfx := MISSILE_SFX_OPTIONS[_rng.randi_range(0, MISSILE_SFX_OPTIONS.size() - 1)]
		_play_sfx_detached(missile_sfx)
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
		missile.global_position = global_position + Vector2(lerp(-missile_spread * 0.5, missile_spread * 0.5, t), missile_spawn_height)
		get_tree().current_scene.add_child(missile)


func _update_animation() -> void:
	if _sprite == null:
		return

	if _shoot_anim_timer > 0.0 or _hit_flash_timer > 0.0:
		_set_frame(3)
		if _shoot_anim_timer > 0.0:
			var shake := Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * shoot_shake_amplitude
			_sprite.position = _sprite_base_position + shake
		else:
			_sprite.position = _sprite_base_position
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


func take_damage(amount: int = 1) -> void:
	if amount <= 0:
		return
	if _iframes_timer > 0.0:
		return
	_health = max(_health - amount, 0)
	_hit_flash_timer = maxf(hit_flash_duration, 0.01)
	_iframes_timer = iframes_duration
	_update_hp_bar_ui()
	if _health <= 0:
		die()


func die() -> void:
	_play_sfx_detached(SFX_CANTLOSE)
	_cleanup_hp_bar_ui()
	queue_free()


func _get_hop_cooldown() -> float:
	var base_cooldown := hop_cooldown
	if _is_phase_two():
		return base_cooldown * 0.6
	return base_cooldown


func _get_missile_cooldown() -> float:
	var base_cooldown := missile_barrage_cooldown
	if _is_phase_two():
		return base_cooldown * 0.6
	return base_cooldown


func _is_phase_two() -> bool:
	var safe_max_health := maxi(max_health, 1)
	return _health <= safe_max_health / 2


func _exit_tree() -> void:
	_cleanup_hp_bar_ui()


func _play_sfx_detached(stream: AudioStream) -> void:
	if stream == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	player.bus = AudioSettings.SFX_BUS
	player.global_position = global_position
	scene.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _find_player() -> Node2D:
	var players := get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Node2D
	return null


func _setup_hp_bar_ui() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ui_layer := scene.get_node_or_null("CanvasLayer") as CanvasLayer
	if ui_layer == null:
		return

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.0
	root.anchor_bottom = 0.0
	root.offset_left = -hp_bar_width * 0.5
	root.offset_right = hp_bar_width * 0.5
	root.offset_top = 0.0
	root.offset_bottom = hp_bar_height
	root.z_index = 220
	ui_layer.add_child(root)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0.84, 0.14, 0.14, 1.0)
	bar_bg.anchor_left = 0.0
	bar_bg.anchor_right = 1.0
	bar_bg.anchor_top = 0.0
	bar_bg.anchor_bottom = 1.0
	root.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.color = Color(0.14, 0.82, 0.23, 1.0)
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_right = 0.0
	bar_fill.anchor_top = 0.0
	bar_fill.anchor_bottom = 1.0
	bar_fill.offset_right = hp_bar_width
	root.add_child(bar_fill)

	_hp_ui_root = root
	_hp_bar_fill = bar_fill


func _update_hp_bar_ui() -> void:
	if _hp_bar_fill == null:
		return
	var safe_max_health := maxi(max_health, 1)
	var health_ratio := clampf(float(_health) / float(safe_max_health), 0.0, 1.0)
	_hp_bar_fill.offset_right = hp_bar_width * health_ratio


func _cleanup_hp_bar_ui() -> void:
	if _hp_ui_root != null and is_instance_valid(_hp_ui_root):
		_hp_ui_root.queue_free()
	_hp_ui_root = null
	_hp_bar_fill = null
