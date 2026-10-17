class_name OrbitGroup
extends ConsoleGroup
## Four discrete 90 degree orbit states around the vertical axis through this node (the hub centre). The arm
## (visual + collision children) rotates with the body. Occupancy: a box over the arm footprint is tested at
## the current, intermediate and target yaws.

## Footprint of the swinging arm in local space (centre offset along +X from the pivot, and its half extents).
@export var arm_center: Vector3 = Vector3(5.0, 0.0, 0.0)
@export var arm_half: Vector3 = Vector3(5.2, 1.5, 1.7)
@export var base_yaw_deg: float = 0.0

var _from_yaw: float = 0.0
var _to_yaw: float = 0.0


func state_count() -> int:
	return 4


func wraps() -> bool:
	return true


func _yaw_of(s: int) -> float:
	return deg_to_rad(base_yaw_deg) + float(s) * PI * 0.5


func _begin_travel(from_state: int, to_state: int) -> void:
	_from_yaw = _yaw_of(from_state)
	# Take the short way: +/-90 degrees, never 270.
	var d := wrapf(_yaw_of(to_state) - _from_yaw, -PI, PI)
	_to_yaw = _from_yaw + d


func _set_travel(t: float) -> void:
	rotation.y = lerpf(_from_yaw, _to_yaw, t)


func _apply_state_immediately(s: int) -> void:
	rotation.y = _yaw_of(s)


func find_occupant(from_state: int, to_state: int) -> Node:
	var a := _yaw_of(from_state)
	var d := wrapf(_yaw_of(to_state) - a, -PI, PI)
	for i in range(0, 6):
		var yaw := a + d * float(i) / 5.0
		var basis := Basis(Vector3.UP, yaw)
		var xf := Transform3D(basis, global_position + global_basis.orthonormalized() * Vector3.ZERO + basis * arm_center)
		var hit := query_box(xf, arm_half)
		if hit != null:
			return hit
	return null
