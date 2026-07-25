class_name SpellDefinition
extends Resource

## Data shared by spell implementations. New spells can reuse this resource and
## provide a different projectile scene, visuals, and balance values.
@export var spell_name: String = "Unnamed Spell"
@export var time_cost: float = 0.0
@export var cooldown: float = 0.0
@export var damage: float = 1.0
@export var area_of_effect: float = 0.0
@export var sprite: Texture2D
@export var projectile_scene: PackedScene
@export var projectile_speed: float = 520.0
@export var projectile_lifetime: float = 2.0
