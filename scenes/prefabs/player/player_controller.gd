extends CharacterBody2D

signal game_over_requested(reason: String)

@export var move_speed: float = 260.0
@export var ground_accel: float = 2200.0
@export var air_accel: float = 1400.0
@export var friction: float = 2600.0
@export var gravity: float = 1800.0
@export var max_fall_speed: float = 1100.0
@export var jump_velocity: float = -560.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10
@export var jump_cut_multiplier: float = 0.45
@export var wall_slide_gravity: float = 420.0
@export var wall_slide_max_fall_speed: float = 180.0
@export var wall_jump_horizontal_speed: float = 420.0
@export var wall_jump_lock_time: float = 0.12
@export var wall_coyote_time: float = 0.08
@export var time_limit_seconds: float = 10.0
@export var damage_penalty_seconds: float = 5.0
@export var iframes_duration: float = 1.5
@export var flash_interval: float = 0.1
@export var sword_duration: float = 0.18

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var wall_jump_lock_timer: float = 0.0
var wall_jump_direction: float = 0.0
var wall_coyote_timer: float = 0.0
var last_wall_normal_x: float = 0.0
var remaining_time: float = 0.0
var is_game_over: bool = false
var iframes_timer: float = 0.0
var flash_timer: float = 0.0
var sword_timer: float = 0.0
var _facing: float = 1.0


@onready var timer_label: Label = $TimerLabel
@onready var sword_hitbox: Area2D = $SwordHitbox


func _ready() -> void:
	remaining_time = time_limit_seconds
	_update_timer_label()


func _physics_process(delta: float) -> void:
	if is_game_over:
		velocity = Vector2.ZERO
		return

	remaining_time = max(remaining_time - delta, 0.0)
	_update_timer_label()
	if remaining_time <= 0.0:
		_trigger_game_over("time_up")
		return

	if iframes_timer > 0.0:
		iframes_timer = max(iframes_timer - delta, 0.0)
		flash_timer -= delta
		if flash_timer <= 0.0:
			flash_timer = flash_interval
			_set_visible(not _get_visual_visible())
		if iframes_timer <= 0.0:
			_set_visible(true)

	if Input.is_action_just_pressed("attack") and sword_timer <= 0.0:
		_swing_sword()

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


func _update_timer_label() -> void:
	if timer_label == null:
		return
	timer_label.text = "%.1f" % remaining_time


func take_damage() -> void:
	if iframes_timer > 0.0 or is_game_over:
		return
	remaining_time = max(remaining_time - damage_penalty_seconds, 0.0)
	_update_timer_label()
	if remaining_time <= 0.0:
		_trigger_game_over("time_up")
		return
	iframes_timer = iframes_duration
	flash_timer = flash_interval


func _set_visible(v: bool) -> void:
	var poly := get_node_or_null("Polygon2D") as Polygon2D
	if poly:
		poly.visible = v


func _get_visual_visible() -> bool:
	var poly := get_node_or_null("Polygon2D") as Polygon2D
	return poly.visible if poly else true


func _swing_sword() -> void:
	if sword_hitbox == null:
		return
	sword_timer = sword_duration
	sword_hitbox.position.x = 28.0 * _facing
	var vis := sword_hitbox.get_node_or_null("SwordVisual") as Polygon2D
	if vis:
		vis.visible = true
	sword_hitbox.monitoring = true


func _end_swing() -> void:
	if sword_hitbox == null:
		return
	sword_hitbox.monitoring = false
	var vis := sword_hitbox.get_node_or_null("SwordVisual") as Polygon2D
	if vis:
		vis.visible = false


func kill_enemy() -> void:
	remaining_time += RandomNumberGenerator.new().randf_range(3.0, 10.0)
	_update_timer_label()


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
	remaining_time = 0.0
	_update_timer_label()
	game_over_requested.emit(reason)
