extends StreamedRoom

@export var boss_scene: PackedScene
@export var boss_spawn_offset: Vector2 = Vector2(-2, -76)
@export var boss_state_id: String = "boss_01"

var _boss_spawned: bool = false


func set_active(active: bool) -> void:
	super.set_active(active)
	if active:
		_spawn_boss_if_needed()


func _spawn_boss_if_needed() -> void:
	if _boss_spawned:
		return
	if boss_scene == null:
		push_warning("Boss room has no boss_scene assigned.")
		return
	var boss := boss_scene.instantiate() as Node2D
	if boss == null:
		return
	boss.position = boss_spawn_offset
	if boss.has_method("set"):
		boss.set("state_id", boss_state_id)
	add_child(boss)
	_boss_spawned = true