class_name ArenaPortal
extends Node3D
## Rim portal (GDD 20.3, 21.1): a stone arch with a coloured glowing ring, a warm-up of 0.4 s that marks the
## safe landing, then the director releases a small staggered group. Saved scene, simple ring geometry and
## a spark particle effect (no external portal pack).

@export var warm_time: float = 0.4
@export var mat_idle: Material
@export var mat_hot: Material

@onready var _ring: MeshInstance3D = $Ring
@onready var _landing: Marker3D = $Landing
@onready var _glow_floor: MeshInstance3D = $LandingMark
@onready var _sparks: CPUParticles3D = $Sparks

var _tween: Tween
var hot: bool = false


func _ready() -> void:
	add_to_group(&"portal")
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
	_tween.tween_interval(0.25)
	_tween.tween_callback(func() -> void: _set_hot(false))
	_sparks.restart()
	_sparks.emitting = true


func _set_hot(on: bool) -> void:
	hot = on
	_ring.material_override = mat_hot if on else mat_idle
	_glow_floor.visible = on
