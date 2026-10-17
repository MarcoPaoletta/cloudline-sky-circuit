class_name SlideGroup
extends ConsoleGroup
## Three discrete positions on ONE horizontal OR vertical rail. `stops` are local offsets from the authored
## (stop 0) position, so the Inspector value stays authoritative. Occupancy: a box over the platform footprint
## along the path from the current to the target stop.

## Stop n sits at the authored position + n * step_offset (three stops by default).
@export var step_offset: Vector3 = Vector3(0, 0, 8)
@export var stop_count: int = 3
@export var footprint_half: Vector3 = Vector3(3.2, 1.6, 3.2)

var _origin: Vector3
var _from_pos: Vector3
var _to_pos: Vector3


func _ready() -> void:
	_origin = position
	super._ready()


func state_count() -> int:
	return stop_count


func _pos_of(s: int) -> Vector3:
	return _origin + step_offset * float(clampi(s, 0, stop_count - 1))


func _begin_travel(from_state: int, to_state: int) -> void:
	_from_pos = _pos_of(from_state)
	_to_pos = _pos_of(to_state)


func _set_travel(t: float) -> void:
	position = _from_pos.lerp(_to_pos, t)


func _apply_state_immediately(s: int) -> void:
	position = _pos_of(s)


func find_occupant(from_state: int, to_state: int) -> Node:
	var parent := get_parent() as Node3D
	var a := _pos_of(from_state)
	var b := _pos_of(to_state)
	for i in range(0, 6):
		var local := a.lerp(b, float(i) / 5.0) + Vector3(0, footprint_half.y - 0.8, 0)
		var world := parent.to_global(local) if parent else local
		var hit := query_box(Transform3D(global_basis.orthonormalized(), world), footprint_half)
		if hit != null:
			return hit
	return null
