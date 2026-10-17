class_name SkyGlow
extends Node3D
## Sunrise glow and sun disc painted on the sky: two unshaded additive quads that stay at a fixed direction from
## the active camera (like a skybox element), so the sun never parallaxes. The direction matches the level's
## DirectionalLight (toward the sun), set once in the Inspector.

@export var toward_sun: Vector3 = Vector3(-0.57, 0.31, -0.76)
@export var distance: float = 1200.0
@export var glow_size: float = 1100.0
@export var disc_size: float = 95.0

@onready var _glow: Node3D = $Glow
@onready var _disc: Node3D = $Disc


func _ready() -> void:
	_glow.scale = Vector3.ONE * glow_size
	_disc.scale = Vector3.ONE * disc_size
	top_level = true


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dir := toward_sun.normalized()
	global_position = cam.global_position + dir * distance
	look_at(cam.global_position, Vector3.UP)
