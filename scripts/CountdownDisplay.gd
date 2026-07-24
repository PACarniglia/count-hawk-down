class_name CountdownDisplay
extends Control

const DIGIT_LIFETIME := 0.85
const DIGIT_GRAVITY := 900.0

signal expired

@export var minimum_start_seconds := 101
@export var maximum_start_seconds := 999
@export var randomize_on_ready := true
@export var display_above_parent := false

@export var value := 0.0:
	set(new_value):
		value = maxf(new_value, 0.0)
		if is_node_ready():
			_update_display()

@onready var hundreds_label: Label = $NumberRow/Hundreds
@onready var tens_label: Label = $NumberRow/Tens
@onready var ones_label: Label = $NumberRow/Ones
@onready var tenths_label: Label = $NumberRow/Tenths
@onready var number_row: HBoxContainer = $NumberRow
@onready var particle_layer: Control = $ParticleLayer

var displayed_tenths := -1
var is_running := false
var has_expired := false

class DigitParticle extends Label:
	var velocity := Vector2.ZERO
	var angular_velocity := 0.0
	var age := 0.0

	func _process(delta: float) -> void:
		age += delta
		velocity.y += DIGIT_GRAVITY * delta
		position += velocity * delta
		rotation += angular_velocity * delta
		modulate.a = maxf(1.0 - age / DIGIT_LIFETIME, 0.0)
		if age >= DIGIT_LIFETIME:
			queue_free()

func _ready() -> void:
	if display_above_parent:
		_configure_world_space_display()
	if randomize_on_ready:
		reset()
	_update_display()

func _configure_world_space_display() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(-62.0, -90.0)
	size = Vector2(124.0, 52.0)
	number_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	number_row.position = Vector2.ZERO
	number_row.size = size

func _process(delta: float) -> void:
	if not is_running or has_expired:
		return
	value = maxf(value - delta, 0.0)
	if is_zero_approx(value):
		has_expired = true
		is_running = false
		expired.emit()

func reset() -> void:
	var minimum := mini(minimum_start_seconds, maximum_start_seconds)
	var maximum := maxi(minimum_start_seconds, maximum_start_seconds)
	value = randi_range(minimum, maximum)
	is_running = false
	has_expired = false

func start() -> void:
	if not has_expired:
		is_running = true

func stop() -> void:
	is_running = false

func _update_display() -> void:
	if hundreds_label == null or tens_label == null or ones_label == null or tenths_label == null:
		return
	var value_in_tenths := maxi(floori(value * 10.0 + 0.0001), 0)
	if value_in_tenths == displayed_tenths:
		return
	var previous_tenths := displayed_tenths
	displayed_tenths = value_in_tenths
	var whole_seconds_text := "%03d" % floori(value_in_tenths / 10.0)
	hundreds_label.text = whole_seconds_text[0]
	tens_label.text = whole_seconds_text[1]
	ones_label.text = whole_seconds_text[2]
	tenths_label.text = str(value_in_tenths % 10)
	if previous_tenths >= 0 and value_in_tenths < previous_tenths and value_in_tenths % 10 == 0:
		_spawn_departing_digit(str(floori(previous_tenths / 10.0) % 10))

func _spawn_departing_digit(digit: String) -> void:
	if ones_label == null or particle_layer == null:
		return
	var font := ones_label.get_theme_font(&"font")
	var font_size := ones_label.get_theme_font_size(&"font_size")
	var digit_size := font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var ones_rect := ones_label.get_global_rect()
	var particle := DigitParticle.new()
	particle.text = digit
	particle.size = digit_size
	particle.pivot_offset = digit_size / 2.0
	particle.position = particle_layer.get_global_transform().affine_inverse() * (
		ones_rect.position + (ones_rect.size - digit_size) / 2.0
	)
	particle.add_theme_font_override(&"font", font)
	particle.add_theme_font_size_override(&"font_size", font_size)
	particle.add_theme_color_override(&"font_color", ones_label.get_theme_color(&"font_color"))
	particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	particle.velocity = Vector2.from_angle(randf_range(0.0, TAU)) * randf_range(260.0, 390.0)
	particle.angular_velocity = randf_range(-7.0, 7.0)
	particle_layer.add_child(particle)
