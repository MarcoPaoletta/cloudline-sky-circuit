class_name PaintBurst
extends CPUParticles3D
## Pooled droplet burst on the impact frame: 16 droplets, 0.55 s, explosiveness 0.95, 62 degree spread, velocity
## 2 to 5, gravity, shrink to zero. Oriented to the surface normal; a miss plays the same burst at 30 %.

var in_use: bool = false
## Droplets of a full burst (the scene's authored amount).
var full_amount: int = 16


func _ready() -> void:
	emitting = false
	one_shot = true
	full_amount = amount


func play_at(point: Vector3, normal: Vector3, paint: Color, ratio: float = 1.0) -> void:
	emitting = false
	in_use = true
	var n := normal.normalized()
	var ref := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(n).normalized()
	var z := x.cross(n).normalized()
	global_transform = Transform3D(Basis(x, n, z), point + n * 0.06)
	reset_physics_interpolation()
	color = paint
	amount = maxi(1, int(round(float(full_amount) * clampf(ratio, 0.05, 1.0))))
	restart()
	emitting = true
	get_tree().create_timer(lifetime + 0.15).timeout.connect(func() -> void:
		in_use = false)
