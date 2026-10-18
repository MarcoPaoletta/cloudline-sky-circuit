class_name ArenaPortal
extends Node3D
## Rim portal (GDD 20.3, 21.1): a stone arch with a coloured glowing ring and a spiral energy vortex, a warm-up of 0.4 s that
## marks the safe landing, then the director releases a small staggered group. Saved scene, simple geometry, a procedural
## vortex shader and spark particles (no external portal pack).

@export var warm_time: float = 0.4
@export var mat_idle: Material
@export var mat_hot: Material

@onready var _ring: MeshInstance3D = $Ring
@onready var _landing: Marker3D = $Landing
@onready var _glow_floor: MeshInstance3D = $LandingMark
@onready var _sparks: CPUParticles3D = $Sparks
@onready var _vortex: MeshInstance3D = $Vortex
@onready var _keystone: MeshInstance3D = $Keystone

var _tween: Tween
var hot: bool = false


func _ready() -> void:
	add_to_group(&"portal")
	# The vortex takes the colour of this portal's ring (each portal has its own).
	var tint := Color(0.3, 0.8, 1.0)
	if mat_hot is BaseMaterial3D:
		tint = (mat_hot as BaseMaterial3D).emission
	_vortex.set_instance_shader_parameter(&"tint", tint)
	_set_hot(false)


func landing_position() -> Vector3:
	return _landing.global_position


func landing_forward() -> Vector3:
	# Arrival positions face inward (toward the arena centre).
	return -global_basis.z


## Marks the landing and glows; the director spawns after `warm_time`.
func warm() -> void:
	_set_hot(true)
	if _tween and _tween.is_valid():
		_tween.kill()
	_ring.scale = Vector3.ONE * 1.15
	_tween = create_tween()
	_tween.tween_property(_ring, "scale", Vector3.ONE, warm_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_method(_set_energy, 2.2, 1.0, warm_time + 0.25)
	_tween.tween_interval(0.25)
	_tween.tween_callback(func() -> void: _set_hot(false))
	_sparks.restart()
	_sparks.emitting = true


func _set_energy(v: float) -> void:
	_vortex.set_instance_shader_parameter(&"energy", v)


func _set_hot(on: bool) -> void:
	hot = on
	_ring.material_override = mat_hot if on else mat_idle
	_keystone.material_override = mat_hot if on else mat_idle
	_set_energy(2.2 if on else 0.8)
	_glow_floor.visible = on
