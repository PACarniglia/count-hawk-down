extends Control

@export var bus_name := &"TitleVisualizer"
@export var point_count := 64
@export var bar_color := Color(0.55, 0.82, 1.0, 0.9)

var spectrum: AudioEffectSpectrumAnalyzerInstance
var point_levels: Array[float] = []

func _ready() -> void:
	point_levels.resize(point_count)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		spectrum = AudioServer.get_bus_effect_instance(bus_index, 0)

func _process(delta: float) -> void:
	for point in point_count:
		var target_level := _get_frequency_level(point) if spectrum else 0.0
		point_levels[point] = move_toward(point_levels[point], target_level, delta * 7.0)
	queue_redraw()

func _draw() -> void:
	for point in point_count:
		var left := size.x * float(point) / point_count
		var right := size.x * float(point + 1) / point_count
		var bar_height := size.y * point_levels[point]
		draw_rect(Rect2(left, size.y - bar_height, right - left, bar_height), bar_color)

func _get_frequency_level(point: int) -> float:
	var ratio_from := float(point) / point_count
	var ratio_to := float(point + 1) / point_count
	var from_hz := lerpf(40.0, 12000.0, ratio_from * ratio_from)
	var to_hz := lerpf(40.0, 12000.0, ratio_to * ratio_to)
	var magnitude := spectrum.get_magnitude_for_frequency_range(from_hz, to_hz).length()
	return clampf((linear_to_db(maxf(magnitude, 0.000001)) + 55.0) / 55.0, 0.0, 1.0)
