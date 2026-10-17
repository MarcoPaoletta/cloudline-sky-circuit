class_name AnchorTile
extends Area3D
## Marked tile the robot must stand on for a heavy pull (GDD 6). `player_on` is the single source of truth.

@export var mat_idle: Material
@export var mat_active: Material

@onready var _glow: MeshInstance3D = $Glow

var player_on: bool = false


func _ready() -> void:
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	_refresh()


func _on_enter(b: Node3D) -> void:
	if b is Player:
		player_on = true
		_refresh()


func _on_exit(b: Node3D) -> void:
	if b is Player:
		player_on = false
		_refresh()


func _refresh() -> void:
	_glow.material_override = mat_active if player_on else mat_idle
