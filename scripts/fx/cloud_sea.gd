class_name CloudSea
extends Node3D
## Decorative cloud layer: gives every cloud mesh the toon cloud material (Inspector `material`) and switches off
## their shadows. The gentle bob and drift live in the material's vertex stage, so the layer costs no per-frame
## script work no matter how many puffs it holds. No collision, nothing gameplay.

@export var material: Material


func _ready() -> void:
	for c in find_children("*", "MeshInstance3D", true, false):
		(c as MeshInstance3D).material_override = material
		(c as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	set_process(false)
