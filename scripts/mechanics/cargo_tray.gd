class_name CargoTray
extends Node3D
## Marked receiving tray (GDD 6, 7). Lights up when a crate docks; the owning island/puzzle reads `crate`.

signal crate_docked(tray: CargoTray, crate: CargoCrate)

@export var mat_idle: Material
@export var mat_docked: Material

@onready var _slot: Node3D = $DockSlot
@onready var _lamp: MeshInstance3D = $Lamp

var crate: CargoCrate = null


func _ready() -> void:
	add_to_group(&"resettable")
	_lamp.material_override = mat_idle


func dock_point() -> Vector3:
	return _slot.global_position


func dock_slot() -> Node3D:
	return _slot


func is_occupied() -> bool:
	return crate != null


func on_docked(c: CargoCrate) -> void:
	crate = c
	_lamp.material_override = mat_docked
	crate_docked.emit(self, c)


func weight() -> float:
	return crate.weight if crate else 0.0


func reset_to_checkpoint() -> void:
	pass
