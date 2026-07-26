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
const REFLECT_CHING_SFX: AudioStream = preload("res://sounds/sfx/player/reflect.wav")
const CURSOR_NORMAL_TEXTURE: Texture2D = preload("res://sprites/crosshairs/White/crosshair038.png")
const CURSOR_PRESSED_TEXTURE: Texture2D = preload("res://sprites/crosshairs/White/crosshair037.png")
const CURSOR_SIZE: int = 64

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
@export var reflect_hitstop_frames: int = 3
@export var reflect_hitstop_seconds: float = 0.5
@export var reflect_flash_alpha: float = 0.42
@export var reflect_flash_fade_seconds: float = 0.12
@export var reflect_star_outer_radius: float = 22.0
@export var reflect_star_inner_radius: float = 8.0
@export var reflect_star_ray_count: int = 8
@export var reflect_spark_count: int = 4
@export var reflect_spark_min_length: float = 10.0
@export var reflect_spark_max_length: float = 24.0
@export var reflect_spark_width: float = 2.0
@export var debug_sword_front_half_offset: float = 8.0
@export var confine_mouse_to_window: bool = true
@export var show_aim_crosshair: bool = true
@export var hide_system_cursor_inside_viewport: bool = true
@export var crosshair_size_px: int = CURSOR_SIZE
@export var allow_outside_viewport_mouse_attack: bool = true

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
var _reflect_hitstop_active: bool = false
var _reflect_local_flash_timer: float = 0.0
var _reflect_vfx_world_position: Vector2 = Vector2.ZERO
var _reflect_star_rotation: float = 0.0
var _reflect_spark_angles: PackedFloat32Array = PackedFloat32Array()
var _reflect_spark_lengths: PackedFloat32Array = PackedFloat32Array()
var _reflect_music_pause_count: int = 0
var _music_bus_was_muted_before_reflect: bool = false
var _aim_world_position: Vector2 = Vector2.ZERO
var _aim_screen_position: Vector2 = Vector2.ZERO
var _aim_crosshair: TextureRect = null
var _aim_cursor_normal: ImageTexture = null
var _aim_cursor_pressed: ImageTexture = null
var _aim_mouse_pressed: bool = false
var _attack_mouse_was_pressed: bool = false
var _current_mouse_mode: int = -1
var _pause_menu_open: bool = false
var _pause_menu_root: Control = null


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
	_setup_mouse_aim_support()
	_setup_pause_menu()
 

func _setup_mouse_aim_support() -> void:
	if confine_mouse_to_window:
		_set_mouse_mode(Input.MOUSE_MODE_CONFINED)
	else:
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_aim_target()
	if not show_aim_crosshair:
		return
	var timer_layer := get_node_or_null("TimerLayer") as CanvasLayer
	if timer_layer == null:
		return
	_aim_cursor_normal = _make_cursor_texture(CURSOR_NORMAL_TEXTURE, max(crosshair_size_px, 8))
	_aim_cursor_pressed = _make_cursor_texture(CURSOR_PRESSED_TEXTURE, max(crosshair_size_px, 8))
	_aim_crosshair = TextureRect.new()
	_aim_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aim_crosshair.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_aim_crosshair.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_aim_crosshair.size = Vector2(maxf(float(crosshair_size_px), 8.0), maxf(float(crosshair_size_px), 8.0))
	_aim_crosshair.z_index = 10
	timer_layer.add_child(_aim_crosshair)
	_update_crosshair_texture()


func _setup_pause_menu() -> void:
	var timer_layer := get_node_or_null("TimerLayer") as CanvasLayer
	if timer_layer == null:
		return

	var root := Control.new()
	root.visible = false
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 0.0
	root.offset_top = 0.0
	root.offset_right = 0.0
	root.offset_bottom = 0.0
	root.z_index = 200
	timer_layer.add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 0.0
	dim.offset_top = 0.0
	dim.offset_right = 0.0
	dim.offset_bottom = 0.0
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.custom_minimum_size = Vector2(280.0, 130.0)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -140.0
	panel.offset_right = 140.0
	panel.offset_top = -65.0
	panel.offset_bottom = 65.0
	root.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	layout.offset_left = 16.0
	layout.offset_top = 16.0
	layout.offset_right = -16.0
	layout.offset_bottom = -16.0
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(layout)

	var title := Label.new()
	title.text = "TIME MARCHES ON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title)

	var resume_button := Button.new()
	resume_button.text = "Resume"
	resume_button.pressed.connect(func() -> void:
		_set_pause_menu_open(false)
	)
	layout.add_child(resume_button)

	_pause_menu_root = root


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_set_pause_menu_open(not _pause_menu_open)
		get_viewport().set_input_as_handled()


func _set_pause_menu_open(open: bool) -> void:
	_pause_menu_open = open
	if _pause_menu_root != null:
		_pause_menu_root.visible = open
	if _aim_crosshair != null:
		_aim_crosshair.visible = not open
	if open:
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		_update_mouse_cursor_mode(true)


func _physics_process(delta: float) -> void:
	_update_aim_target()
	_update_crosshair_texture()
	_update_crosshair_position()

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
	if _reflect_local_flash_timer > 0.0:
		_reflect_local_flash_timer = maxf(_reflect_local_flash_timer - delta, 0.0)

	var attack_pressed := (not _pause_menu_open) and Input.is_action_just_pressed("attack")
	if allow_outside_viewport_mouse_attack and not _pause_menu_open:
		var left_mouse_pressed := _is_left_mouse_pressed_anywhere() and _is_game_window_focused()
		attack_pressed = attack_pressed or (left_mouse_pressed and not _attack_mouse_was_pressed)
		_attack_mouse_was_pressed = left_mouse_pressed
	elif _pause_menu_open:
		_attack_mouse_was_pressed = _is_left_mouse_pressed_anywhere() and _is_game_window_focused()
	if attack_pressed and sword_timer <= 0.0:
		_swing_sword()
	if not _pause_menu_open and Input.is_action_just_pressed("cast_spell"):
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
	queue_redraw()


func _draw() -> void:
	if _reflect_local_flash_timer > 0.0:
		var flash_total := maxf(reflect_hitstop_seconds + reflect_flash_fade_seconds, 0.01)
		var flash_alpha := clampf(reflect_flash_alpha * (_reflect_local_flash_timer / flash_total), 0.0, 1.0)
		_draw_reflect_star(to_local(_reflect_vfx_world_position), flash_alpha)


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
	sword_hitbox.position.x = (42.0 + maxf(debug_sword_front_half_offset, 0.0)) * _facing - (16.0 * _facing)
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
	var aim_direction := global_position.direction_to(_aim_world_position)
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
	if area == null:
		return
	var target: Node = area
	if not target.has_method("reflect_from_player") and not target.has_method("die") and not target.is_in_group("enemy"):
		target = area.get_parent()
	if target == null:
		return

	if target.has_method("reflect_from_player"):
		target.reflect_from_player(global_position, _aim_world_position)
		_show_reflect_flash(area.global_position)
		_play_reflect_sfx_with_music_pause()
		_trigger_reflect_hitstop()
		return
	if target.is_in_group("enemy") and target.has_method("die"):
		target.die()
		kill_enemy()


func _trigger_reflect_hitstop() -> void:
	if _reflect_hitstop_active:
		return
	_reflect_hitstop_active = true
	var tree := get_tree()
	if tree == null:
		_reflect_hitstop_active = false
		return
	var previous_time_scale := Engine.time_scale
	Engine.time_scale = 0.0
	var freeze_seconds := maxf(reflect_hitstop_seconds, 0.01)
	await tree.create_timer(freeze_seconds, true, false, true).timeout
	Engine.time_scale = previous_time_scale
	_reflect_hitstop_active = false


func _show_reflect_flash(world_position: Vector2) -> void:
	_reflect_vfx_world_position = world_position
	_reflect_star_rotation = _rng.randf_range(0.0, TAU)
	_reflect_spark_angles.clear()
	_reflect_spark_lengths.clear()
	var spark_count := maxi(reflect_spark_count, 0)
	for _i in range(spark_count):
		_reflect_spark_angles.append(_rng.randf_range(0.0, TAU))
		_reflect_spark_lengths.append(_rng.randf_range(maxf(reflect_spark_min_length, 1.0), maxf(reflect_spark_max_length, reflect_spark_min_length + 1.0)))
	_reflect_local_flash_timer = maxf(reflect_hitstop_seconds + reflect_flash_fade_seconds, 0.01)
	queue_redraw()


func _draw_reflect_star(center: Vector2, alpha: float) -> void:
	var outer_radius := maxf(reflect_star_outer_radius, 1.0)
	var inner_radius := clampf(reflect_star_inner_radius, 1.0, outer_radius - 0.5)
	var ray_count := maxi(reflect_star_ray_count, 4)
	var star_points: PackedVector2Array = PackedVector2Array()
	for i in range(ray_count * 2):
		var t := float(i) / float(ray_count * 2)
		var angle := TAU * t - PI * 0.5 + _reflect_star_rotation
		var radius := outer_radius if i % 2 == 0 else inner_radius
		star_points.append(center + Vector2.from_angle(angle) * radius)
	draw_colored_polygon(star_points, Color(1.0, 0.93, 0.2, alpha))
	draw_circle(center, inner_radius * 0.6, Color(1.0, 1.0, 0.75, alpha * 0.9))
	var spark_width := maxf(reflect_spark_width, 1.0)
	for i in range(mini(_reflect_spark_angles.size(), _reflect_spark_lengths.size())):
		var dir := Vector2.from_angle(_reflect_spark_angles[i])
		var start := center + dir * (inner_radius * 0.4)
		var end := center + dir * _reflect_spark_lengths[i]
		draw_line(start, end, Color(1.0, 0.97, 0.5, alpha), spark_width, true)


func _play_reflect_sfx_with_music_pause() -> void:
	if REFLECT_CHING_SFX == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return

	var music_bus_index := AudioServer.get_bus_index(AudioSettings.MUSIC_BUS)
	if music_bus_index >= 0:
		if _reflect_music_pause_count == 0:
			_music_bus_was_muted_before_reflect = AudioServer.is_bus_mute(music_bus_index)
		if not AudioServer.is_bus_mute(music_bus_index):
			AudioServer.set_bus_mute(music_bus_index, true)
		_reflect_music_pause_count += 1

	var audio_player := AudioStreamPlayer2D.new()
	audio_player.stream = REFLECT_CHING_SFX
	audio_player.bus = AudioSettings.SFX_BUS
	audio_player.global_position = global_position
	scene.add_child(audio_player)
	audio_player.finished.connect(func() -> void:
		if music_bus_index >= 0 and _reflect_music_pause_count > 0:
			_reflect_music_pause_count -= 1
			if _reflect_music_pause_count == 0:
				AudioServer.set_bus_mute(music_bus_index, _music_bus_was_muted_before_reflect)
		audio_player.queue_free()
	)
	audio_player.play()


func _update_aim_target() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_rect := viewport.get_visible_rect()
	var viewport_size := viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var raw_mouse := DisplayServer.mouse_get_position() - DisplayServer.window_get_position()
	var clamped_mouse := Vector2(
		clampf(raw_mouse.x, 0.0, viewport_size.x),
		clampf(raw_mouse.y, 0.0, viewport_size.y)
	)
	_aim_screen_position = clamped_mouse
	var mouse_inside := _is_mouse_inside_window(raw_mouse, viewport_size)
	_update_mouse_cursor_mode(mouse_inside)

	if mouse_inside:
		_aim_world_position = get_global_mouse_position()


func _is_mouse_inside_window(local_mouse: Vector2, viewport_size: Vector2) -> bool:
	return local_mouse.x >= 0.0 \
		and local_mouse.y >= 0.0 \
		and local_mouse.x <= viewport_size.x \
		and local_mouse.y <= viewport_size.y


func _update_mouse_cursor_mode(mouse_inside: bool) -> void:
	if _pause_menu_open:
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return
	if confine_mouse_to_window:
		if hide_system_cursor_inside_viewport and mouse_inside:
			_set_mouse_mode(Input.MOUSE_MODE_CONFINED_HIDDEN)
		else:
			_set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		return
	if hide_system_cursor_inside_viewport and mouse_inside:
		_set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _set_mouse_mode(mode: int) -> void:
	if _current_mouse_mode == mode:
		return
	_current_mouse_mode = mode
	Input.mouse_mode = mode


func _update_crosshair_position() -> void:
	if _aim_crosshair == null:
		return
	_aim_crosshair.position = _aim_screen_position - (_aim_crosshair.size * 0.5)


func _update_crosshair_texture() -> void:
	if _aim_crosshair == null:
		return
	var pressed_now := _is_left_mouse_pressed_anywhere()
	if pressed_now == _aim_mouse_pressed and _aim_crosshair.texture != null:
		return
	_aim_mouse_pressed = pressed_now
	_aim_crosshair.texture = _aim_cursor_pressed if _aim_mouse_pressed else _aim_cursor_normal


func _is_left_mouse_pressed_anywhere() -> bool:
	return (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT) != 0


func _is_game_window_focused() -> bool:
	var window := get_window()
	return window != null and window.has_focus()


func _make_cursor_texture(source_texture: Texture2D, size: int) -> ImageTexture:
	var image := source_texture.get_image()
	image.resize(size, size, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


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
