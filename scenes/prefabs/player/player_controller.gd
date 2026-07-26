extends CharacterBody2D

signal game_over_requested(reason: String)

const SpellDefinition = preload("res://scripts/spells/spell_definition.gd")
const SWORD_SFX_OPTIONS: Array[AudioStream] = [
	preload("res://sounds/sfx/player/sword1.wav"),
	preload("res://sounds/sfx/player/sword2.wav"),
	preload("res://sounds/sfx/player/sword3.wav"),
]
const FIREBALL_SFX_OPTIONS: Array[AudioStream] = [
	preload("res://sounds/sfx/player/fireball1.wav"),
	preload("res://sounds/sfx/player/fireball2.wav"),
	preload("res://sounds/sfx/player/fireball3.wav"),
]

@export var move_speed: float = 260.0
@export var ground_accel: float = 2200.0
@export var air_accel: float = 1400.0
@export var friction: float = 2600.0
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1100.0
@export var jump_velocity: float = -600.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10
@export var jump_cut_multiplier: float = 0.45
@export var wall_slide_gravity: float = 420.0
@export var wall_slide_max_fall_speed: float = 180.0
@export var wall_jump_horizontal_speed: float = 420.0
@export var wall_jump_lock_time: float = 0.12
@export var wall_coyote_time: float = 0.10
@export var time_limit_seconds: float = 10.0
@export var damage_penalty_seconds: float = 5.0
@export var iframes_duration: float = 1.5
@export var flash_interval: float = 0.1
@export var sword_duration: float = 0.18
@export var walk_animation_fps: float = 8.0
@export var attack_animation_fps: float = 12.0
@export var attack_visual_offset_px: float = 12.0
@export var jump_spin_degrees_per_second: float = 1080.0
@export var equipped_spell: SpellDefinition

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0
var wall_jump_direction: float = 0.0
var wall_coyote_timer: float = 0.0
var last_wall_normal_x: float = 0.0
var is_game_over: bool = false
var iframes_timer: float = 0.0
var flash_timer: float = 0.0
var sword_timer: float = 0.0
var spell_cooldown_timer: float = 0.0
var _facing: float = 1.0
var _rng := RandomNumberGenerator.new()
var input_locked: bool = false
var _sprite_inverted: bool = false


@onready var countdown = $TimerLayer/Countdown
@onready var sword_hitbox: Area2D = $SwordHitbox
@onready var death_sound: AudioStreamPlayer2D = $DeathSound
@onready var hero_sprite: AnimatedSprite2D = $HeroSprite


func _ready() -> void:
	countdown.value = time_limit_seconds
	countdown.expired.connect(_on_countdown_expired)
	countdown.start()
	if hero_sprite and hero_sprite.sprite_frames:
		hero_sprite.sprite_frames.set_animation_speed("walk", walk_animation_fps)
		hero_sprite.sprite_frames.set_animation_speed("attack", attack_animation_fps)
	_set_sprite_inverted(false)
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if is_game_over:
		velocity = Vector2.ZERO
		return
	if input_locked:
		velocity = Vector2.ZERO
		return

	if iframes_timer > 0.0:
		iframes_timer = max(iframes_timer - delta, 0.0)
		flash_timer -= delta
		if flash_timer <= 0.0:
			flash_timer = flash_interval
			_set_sprite_inverted(not _sprite_inverted)
		if iframes_timer <= 0.0:
			_set_sprite_inverted(false)

	spell_cooldown_timer = maxf(spell_cooldown_timer - delta, 0.0)

	if Input.is_action_just_pressed("attack") and sword_timer <= 0.0:
		_swing_sword()
	if Input.is_action_just_pressed("cast_spell"):
		_cast_spell()

	if sword_timer > 0.0:
		sword_timer = max(sword_timer - delta, 0.0)
		if sword_timer <= 0.0:
			_end_swing()

	var input_axis := Input.get_axis("move_left", "move_right")
	if input_axis != 0.0:
		_facing = signf(input_axis)
	var on_floor := is_on_floor()
	var on_wall := is_on_wall_only() and not on_floor
	var wall_normal := get_wall_normal() if on_wall else Vector2.ZERO
	var pressing_into_wall := on_wall and input_axis != 0.0 and signf(input_axis) == -signf(wall_normal.x)

	if wall_jump_lock_timer > 0.0:
		wall_jump_lock_timer = max(wall_jump_lock_timer - delta, 0.0)
		velocity.x = move_toward(velocity.x, wall_jump_direction * wall_jump_horizontal_speed, air_accel * 1.5 * delta)
	else:
		var target_speed := input_axis * move_speed
		var accel := ground_accel if on_floor else air_accel

		if input_axis != 0.0:
			velocity.x = move_toward(velocity.x, target_speed, accel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	if on_floor:
		coyote_timer = coyote_time
	else:
		coyote_timer = max(coyote_timer - delta, 0.0)

	if on_wall:
		wall_coyote_timer = wall_coyote_time
		last_wall_normal_x = wall_normal.x
	else:
		wall_coyote_timer = max(wall_coyote_timer - delta, 0.0)

	if Input.is_action_just_pressed("move_jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if jump_buffer_timer > 0.0:
		if coyote_timer > 0.0:
			velocity.y = jump_velocity
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
		elif on_wall or wall_coyote_timer > 0.0:
			var wall_normal_x := wall_normal.x if on_wall else last_wall_normal_x
			if wall_normal_x == 0.0:
				wall_normal_x = -signf(velocity.x)
			velocity.y = jump_velocity
			wall_jump_direction = signf(wall_normal_x)
			velocity.x = wall_jump_direction * wall_jump_horizontal_speed
			wall_jump_lock_timer = wall_jump_lock_time
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			wall_coyote_timer = 0.0

	if Input.is_action_just_released("move_jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier

	var current_gravity := gravity
	var current_max_fall_speed := max_fall_speed
	if pressing_into_wall and velocity.y > 0.0:
		current_gravity = wall_slide_gravity
		current_max_fall_speed = wall_slide_max_fall_speed

	velocity.y = min(velocity.y + current_gravity * delta, current_max_fall_speed)

	move_and_slide()
	var grounded_now := is_on_floor()
	var on_wall_now := is_on_wall_only() and not grounded_now
	var wall_normal_now := get_wall_normal() if on_wall_now else Vector2.ZERO
	var wall_sliding_now := on_wall_now and input_axis != 0.0 and signf(input_axis) == -signf(wall_normal_now.x) and velocity.y > 0.0
	var is_attacking_now := sword_timer > 0.0
	_update_hero_sprite_visuals(grounded_now, wall_sliding_now, is_attacking_now, delta)


func take_damage() -> void:
	if iframes_timer > 0.0 or is_game_over:
		return
	countdown.value = maxf(countdown.value - damage_penalty_seconds, 0.0)
	if is_zero_approx(countdown.value):
		_trigger_game_over("time_up")
		return
	iframes_timer = iframes_duration
	flash_timer = flash_interval


func _set_sprite_inverted(inverted: bool) -> void:
	_sprite_inverted = inverted
	if hero_sprite == null:
		return
	var shader_material := hero_sprite.material as ShaderMaterial
	if shader_material:
		shader_material.set_shader_parameter("invert_enabled", inverted)


func _update_hero_sprite_visuals(on_floor: bool, wall_sliding: bool, is_attacking: bool, delta: float) -> void:
	if hero_sprite == null:
		return

	hero_sprite.flip_h = _facing < 0.0
	if is_attacking:
		hero_sprite.rotation = 0.0
		hero_sprite.offset = Vector2(attack_visual_offset_px * _facing, 0.0)
		if hero_sprite.animation != &"attack":
			hero_sprite.play("attack")
		elif not hero_sprite.is_playing():
			hero_sprite.play("attack")
		return
	hero_sprite.offset = Vector2.ZERO

	if wall_sliding:
		if hero_sprite.animation != &"wall_slide":
			hero_sprite.animation = &"wall_slide"
		hero_sprite.stop()
		hero_sprite.frame = 0
		hero_sprite.rotation = 0.0
		return

	if not on_floor:
		if hero_sprite.animation != &"jump":
			hero_sprite.animation = &"jump"
		hero_sprite.stop()
		hero_sprite.frame = 0
		var spin_direction := _facing
		if is_zero_approx(spin_direction):
			spin_direction = 1.0
		hero_sprite.rotation_degrees = wrapf(
			hero_sprite.rotation_degrees + jump_spin_degrees_per_second * spin_direction * delta,
			-180.0,
			180.0
		)
		return

	hero_sprite.rotation = 0.0
	if absf(velocity.x) > 8.0:
		if hero_sprite.animation != &"walk" or not hero_sprite.is_playing():
			hero_sprite.play("walk")
	else:
		if hero_sprite.animation != &"walk":
			hero_sprite.animation = &"walk"
		hero_sprite.stop()
		hero_sprite.frame = 0


func _swing_sword() -> void:
	if sword_hitbox == null:
		return
	sword_timer = sword_duration
	if not SWORD_SFX_OPTIONS.is_empty():
		var sword_sfx := SWORD_SFX_OPTIONS[_rng.randi_range(0, SWORD_SFX_OPTIONS.size() - 1)]
		_play_sfx_detached(sword_sfx)
	sword_hitbox.position.x = 42.0 * _facing
	sword_hitbox.monitoring = true


func _end_swing() -> void:
	if sword_hitbox == null:
		return
	sword_hitbox.monitoring = false


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


func _cast_spell() -> void:
	if equipped_spell == null or equipped_spell.projectile_scene == null:
		return
	if spell_cooldown_timer > 0.0 or countdown.value < equipped_spell.time_cost:
		return

	countdown.value -= equipped_spell.time_cost
	spell_cooldown_timer = equipped_spell.cooldown
	if not FIREBALL_SFX_OPTIONS.is_empty():
		var fireball_sfx := FIREBALL_SFX_OPTIONS[_rng.randi_range(0, FIREBALL_SFX_OPTIONS.size() - 1)]
		_play_sfx_detached(fireball_sfx)
	var projectile := equipped_spell.projectile_scene.instantiate()
	get_tree().current_scene.add_child(projectile)
	var aim_direction := global_position.direction_to(get_global_mouse_position())
	if aim_direction == Vector2.ZERO:
		aim_direction = Vector2(_facing, 0.0)
	projectile.global_position = global_position + aim_direction * 36.0
	projectile.launch(equipped_spell, aim_direction)


func kill_enemy() -> void:
	countdown.value += RandomNumberGenerator.new().randf_range(3.0, 10.0)


func get_time_remaining() -> float:
	return countdown.value


func trigger_victory() -> void:
	if is_game_over:
		return
	is_game_over = true
	input_locked = true
	countdown.stop()
	_end_swing()
	_set_sprite_inverted(false)


func _on_sword_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent == null:
		return
	if parent.is_in_group("enemy") and parent.has_method("die"):
		parent.die()
		kill_enemy()


func _trigger_game_over(reason: String) -> void:
	if is_game_over:
		return
	is_game_over = true
	_set_sprite_inverted(false)
	death_sound.play()
	countdown.stop()
	countdown.value = 0.0
	game_over_requested.emit(reason)


func _on_countdown_expired() -> void:
	_trigger_game_over("time_up")
