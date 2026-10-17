class_name CloudSea
extends Node3D
## Decorative cloud layer: gives every cloud mesh a soft white-pink material (the glTF shading reads blue under the
## sky ambient) and drifts the puffs gently so the world is never frozen. No collision, nothing gameplay.

@export var material: Material
@export var bob_amount: float = 0.45
@export var bob_speed: float = 0.18
@export var drift_amount: float = 1.2

var _t: float = 0.0
var _base: Dictionary = {}


func _ready() -> void:
	for c in get_children():
		if c is Node3D:
			_base[c] = (c as Node3D).position
			for mi in c.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_override = material
				(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_t = randf() * 20.0


func _process(delta: float) -> void:
	_t += delta
	var i := 0
	for c in _base:
		if not is_instance_valid(c):
			continue
		var b: Vector3 = _base[c]
		var ph := float(i) * 1.7
		(c as Node3D).position = b + Vector3(sin(_t * bob_speed * 0.6 + ph) * drift_amount, sin(_t * bob_speed + ph) * bob_amount, cos(_t * bob_speed * 0.5 + ph) * drift_amount)
		i += 1
