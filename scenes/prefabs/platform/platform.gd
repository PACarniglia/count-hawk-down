@tool
extends StaticBody2D

var _platform_size: Vector2 = Vector2(256.0, 48.0)
var _platform_color: Color = Color(0.14902, 0.172549, 0.239216, 1.0)

@export var platform_size: Vector2:
	get:
		return _platform_size
	set(value):
		_platform_size = Vector2(max(value.x, 1.0), max(value.y, 1.0))
		_update_visual_and_collision()

@export var platform_color: Color:
	get:
		return _platform_color
	set(value):
		_platform_color = value
		_update_visual_and_collision()


func _ready() -> void:
	_update_visual_and_collision()


func _update_visual_and_collision() -> void:
	var collision := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null:
		var rect_shape := collision.shape as RectangleShape2D
		if rect_shape == null:
			rect_shape = RectangleShape2D.new()
			rect_shape.resource_local_to_scene = true
			collision.shape = rect_shape
		elif not rect_shape.resource_local_to_scene:
			rect_shape = rect_shape.duplicate()
			rect_shape.resource_local_to_scene = true
			collision.shape = rect_shape
		rect_shape.size = _platform_size

	var visual := get_node_or_null("Polygon2D") as Polygon2D
	if visual != null:
		var half_width := _platform_size.x * 0.5
		var half_height := _platform_size.y * 0.5
		visual.polygon = PackedVector2Array([
			Vector2(-half_width, -half_height),
			Vector2(half_width, -half_height),
			Vector2(half_width, half_height),
			Vector2(-half_width, half_height),
		])
		visual.color = _platform_color
