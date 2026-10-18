class_name SkyGlow
extends Node3D
## Sunrise glow and sun disc painted on the sky: two unshaded additive quads that stay at a fixed direction from
## the active camera (like a skybox element), so the sun never parallaxes. `toward_sun` and the tints are set per
## level in the Inspector (each world has its own time of day); the DirectionalLight stays the gameplay light.

@export var toward_sun: Vector3 = Vector3(-0.57, 0.31, -0.76)
@export var distance: float = 1200.0
@export var glow_size: float = 1100.0
@export var disc_size: float = 95.0
@export var glow_color: Color = Color(0.95, 0.817, 0.551, 0.95)
@export var disc_color: Color = Color(1.0, 1.0, 1.0, 1.0)

@onready var _glow: MeshInstance3D = $Glow
@onready var _disc: MeshInstance3D = $Disc


func _ready() -> void:
	_glow.scale = Vector3.ONE * glow_size
	_disc.scale = Vector3.ONE * disc_size
	_tint(_glow, glow_color)
	_tint(_disc, disc_color)
	top_level = true


func _tint(quad: MeshInstance3D, c: Color) -> void:
	var m := quad.material_override as StandardMaterial3D
	if m == null:
		return
	m = m.duplicate() as StandardMaterial3D
	m.albedo_color = c
	quad.material_override = m


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dir := toward_sun.normalized()
	global_position = cam.global_position + dir * distance
	look_at(cam.global_position, Vector3.UP)
