extends Control

@export var bpm: float = 120.0
@export var beat_zoom: float = 0.025
@export var small_beat_zoom: float= 0.015
@export var zoom_return_speed: float = 0.8
@export var beat_offset_seconds: float = 0.0

@onready var beat_overlay: ColorRect = $BeatZoomOverlay
@onready var title_part_a: AudioStreamPlayer = $TitlePartA
@onready var title_part_b1: AudioStreamPlayer = $TitlePartB1
@onready var title_part_b2: AudioStreamPlayer = $TitlePartB2
@onready var menu_click_sound: AudioStreamPlayer = $MenuClickSound
@onready var screen_container: Control = $ScreenContainer
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var countdown = $Countdown

const CURSOR_NORMAL_PATH := "res://sprites/crosshairs/White/crosshair038.png"
const CURSOR_PRESSED_PATH := "res://sprites/crosshairs/White/crosshair037.png"
const CURSOR_NORMAL_TEXTURE: Texture2D = preload(CURSOR_NORMAL_PATH)
const CURSOR_PRESSED_TEXTURE: Texture2D = preload(CURSOR_PRESSED_PATH)
const CURSOR_SIZE := 64
const CURSOR_HOVER_SIZE := 76
const TITLE_VISUALIZER_BUS := &"TitleVisualizer"
var current_zoom := 0.0
var active_track: AudioStreamPlayer
var last_beat_index := -1
var current_screen: Control
var is_restarting := false
var has_started_part_b := false
var cursor_normal: ImageTexture
var cursor_hover: ImageTexture
var cursor_pressed: ImageTexture
var cursor_display: TextureRect
var hovered_interactable: Control
var mouse_is_pressed := false

const MAIN_MENU_SCREEN := preload("res://scenes/MainMenuScreen.tscn")
const SETTINGS_SCREEN := preload("res://scenes/SettingsScreen.tscn")
const WORLD_SCENE_PATH := "res://scenes/world/World.tscn"
const WORLD_BOSS_TEST_SCENE_PATH := "res://scenes/world/WorldBossTest.tscn"

func _ready() -> void:
	_setup_cursor()
	title_part_a.bus = AudioSettings.MUSIC_BUS
	title_part_b1.bus = AudioSettings.MUSIC_BUS
	title_part_b2.bus = TITLE_VISUALIZER_BUS
	menu_click_sound.bus = AudioSettings.SFX_BUS
	title_part_a.finished.connect(_start_title_part_b)
	title_part_b1.stream.loop = true
	title_part_b2.stream.loop = true
	active_track = title_part_a
	fade_overlay.modulate.a = 0.0
	countdown.expired.connect(restart_after_fade)
	title_part_a.play()
	show_main_menu()

func _process(delta: float) -> void:
	var is_left_mouse_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_is_pressed != is_left_mouse_pressed:
		mouse_is_pressed = is_left_mouse_pressed
		_update_cursor()
	_update_cursor_position()
	_update_beat_from_music()
	current_zoom = move_toward(current_zoom, 0.0, zoom_return_speed * delta)
	beat_overlay.material.set_shader_parameter("zoom_amount", current_zoom)
	var strongest_beat := maxf(beat_zoom, small_beat_zoom)
	beat_overlay.material.set_shader_parameter("pulse_strength", current_zoom / strongest_beat)

func _start_title_part_b() -> void:
	active_track = title_part_b1
	last_beat_index = -1
	has_started_part_b = true
	title_part_b1.play()
	title_part_b2.play()
	countdown.start()
	trigger_beat(0)

func _update_beat_from_music() -> void:
	if active_track == null or not active_track.playing:
		return

	var seconds_per_beat := 60.0 / bpm
	var song_time := maxf(active_track.get_playback_position() - beat_offset_seconds, 0.0)
	var beat_index := floori(song_time / seconds_per_beat)

	if beat_index != last_beat_index:
		last_beat_index = beat_index
		trigger_beat(beat_index)

func trigger_beat(beat_index: int) -> void:
	if has_started_part_b:
		current_zoom = beat_zoom if beat_index % 2 == 0 else small_beat_zoom

func show_main_menu() -> void:
	_show_screen(MAIN_MENU_SCREEN.instantiate())
	current_screen.connect(&"new_game_requested", start_new_game)
	current_screen.connect(&"settings_requested", show_settings)
	current_screen.connect(&"boss_test_requested", start_boss_room_test)

func start_new_game() -> void:
	call_deferred("_change_to_world")


func start_boss_room_test() -> void:
	call_deferred("_change_to_boss_test_world")

func _change_to_world() -> void:
	get_tree().change_scene_to_file(WORLD_SCENE_PATH)


func _change_to_boss_test_world() -> void:
	get_tree().change_scene_to_file(WORLD_BOSS_TEST_SCENE_PATH)

func show_settings() -> void:
	_show_screen(SETTINGS_SCREEN.instantiate())
	current_screen.connect(&"back_requested", show_main_menu)

func _show_screen(screen: Control) -> void:
	hovered_interactable = null
	if current_screen:
		current_screen.queue_free()
	screen_container.add_child(screen)
	current_screen = screen
	_register_interactable_controls(screen)
	_update_cursor()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_is_pressed = event.pressed
		_update_cursor()

func _setup_cursor() -> void:
	cursor_normal = _make_cursor(CURSOR_NORMAL_TEXTURE, CURSOR_SIZE)
	cursor_hover = _make_cursor(CURSOR_NORMAL_TEXTURE, CURSOR_HOVER_SIZE)
	cursor_pressed = _make_cursor(CURSOR_PRESSED_TEXTURE, CURSOR_SIZE)
	var cursor_layer := CanvasLayer.new()
	cursor_layer.layer = 128
	add_child(cursor_layer)
	cursor_display = TextureRect.new()
	cursor_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cursor_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cursor_layer.add_child(cursor_display)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_update_cursor()
	_update_cursor_position()

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _make_cursor(source_texture: Texture2D, size: int) -> ImageTexture:
	var image := source_texture.get_image()
	image.resize(size, size, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)

func _register_interactable_controls(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			if control is BaseButton or control is Slider:
				control.mouse_default_cursor_shape = Control.CURSOR_ARROW
				control.mouse_entered.connect(_on_interactable_mouse_entered.bind(control))
				control.mouse_exited.connect(_on_interactable_mouse_exited.bind(control))
				if control is BaseButton:
					(control as BaseButton).pressed.connect(_on_menu_button_pressed)
		_register_interactable_controls(child)

func _on_menu_button_pressed() -> void:
	if menu_click_sound.is_inside_tree():
		menu_click_sound.play()

func _on_interactable_mouse_entered(control: Control) -> void:
	hovered_interactable = control
	_update_cursor()

func _on_interactable_mouse_exited(control: Control) -> void:
	if hovered_interactable == control:
		hovered_interactable = null
		_update_cursor()

func _update_cursor() -> void:
	var texture := cursor_pressed if mouse_is_pressed else cursor_hover if hovered_interactable else cursor_normal
	if texture and cursor_display:
		var cursor_size := CURSOR_SIZE if texture != cursor_hover else CURSOR_HOVER_SIZE
		cursor_display.texture = texture
		cursor_display.size = Vector2.ONE * cursor_size
		_update_cursor_position()

func _update_cursor_position() -> void:
	if cursor_display:
		cursor_display.position = get_viewport().get_mouse_position() - cursor_display.size / 2.0

func restart_after_fade() -> void:
	if is_restarting:
		return
	is_restarting = true
	var fade_tween := create_tween()
	fade_tween.tween_property(fade_overlay, "modulate:a", 1.0, 5.0)
	fade_tween.tween_callback(get_tree().reload_current_scene)
