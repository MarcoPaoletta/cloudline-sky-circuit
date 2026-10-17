class_name DetachedHead
extends RigidBody3D
## The robot's head as a physical bowling ball (GDD 20.2). Gravity-driven, swept by continuous collision,
## it rolls THROUGH ordinary enemies (they are hurt areas, not solid blockers) and defeats every ordinary
## enemy it touches; bosses accept one hit per boss per launch. It returns on recall, after 2.5 s, 36 m of
## travel, a stall, or a fall, and can be caught by a Receiver socket. The return is a collision-free
## visual homing state that never damages anything.

signal returned
signal seated(receiver: Node)
signal enemy_hit(enemy: Node, chain: int)
signal state_changed(state: int)
## Asks the controller to start the return (time, distance, stall or fall limit reached).
signal returned_auto_requested

enum State { STOWED, HELD, ROLLING, SEATED, RETURNING }

@export_group("Roll (GDD 20.2)")
@export var launch_speed: float = 18.0
@export var launch_lift: float = 2.5
@export var max_time: float = 2.5
@export var max_distance: float = 36.0
@export var stall_speed: float = 1.0
@export var stall_time: float = 0.4
@export var recovery_below_origin: float = 24.0
@export_group("Return")
@export var return_time: float = 0.42
@export var seat_time: float = 0.22

@onready var _collision: CollisionShape3D = $Collision
@onready var _hit_area: Area3D = $HitArea
@onready var _trail: GPUParticles3D = $Trail

var state: int = State.STOWED
var chain: int = 0
var damage_enabled: bool = true

var _origin: Vector3 = Vector3.ZERO
var _travel: float = 0.0
var _clock: float = 0.0
var _stall: float = 0.0
var _last_pos: Vector3 = Vector3.ZERO
var _hit_ids: Dictionary = {}
var _tween: Tween
var _ret_target: Node3D
var _ret_from: Vector3
var _ret_t: float = 0.0
var _ret_from_basis: Basis
var _ret_to_basis: Basis = Basis.IDENTITY
var _seat_xf: Transform3D
var _seat_receiver: Node


func _ready() -> void:
	add_to_group(&"head")
	continuous_cd = true
	stow()


func is_rolling() -> bool:
	return state == State.ROLLING


func is_seated() -> bool:
	return state == State.SEATED


func current_speed() -> float:
	return linear_velocity.length() if state == State.ROLLING else 0.0


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


## Hidden and frozen at the neck: the head is attached to the body.
func stow() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	visible = false
	_collision.set_deferred("disabled", true)
	_hit_area.set_deferred("monitoring", false)
	_trail.emitting = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_seat_receiver = null
	_set_state(State.STOWED)


## Visible in the hand during the grab and lift; the controller moves it each frame.
func hold(xf: Transform3D) -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_collision.set_deferred("disabled", true)
	_hit_area.set_deferred("monitoring", false)
	global_transform = xf
	reset_physics_interpolation()
	visible = true
	_trail.emitting = false
	_set_state(State.HELD)


func move_held(xf: Transform3D) -> void:
	global_transform = xf
	reset_physics_interpolation()


## Launches the physical ball. `face_dir` orients the face (eyes) along the roll.
func launch(pos: Vector3, velocity: Vector3, face_dir: Vector3, with_damage: bool = true) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	freeze = false
	_collision.set_deferred("disabled", false)
	var flat := Vector3(face_dir.x, 0.0, face_dir.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	global_transform = Transform3D(Basis(Vector3.UP, atan2(flat.x, flat.z)), pos)
	reset_physics_interpolation()
	linear_velocity = velocity
	# Start rolling without slipping: omega = (up x v) / r.
	var radius := (_collision.shape as SphereShape3D).radius
	angular_velocity = Vector3.UP.cross(Vector3(velocity.x, 0.0, velocity.z)) / maxf(radius, 0.05)
	_origin = pos
	_last_pos = pos
	_travel = 0.0
	_clock = 0.0
	_stall = 0.0
	chain = 0
	_hit_ids.clear()
	damage_enabled = with_damage
	visible = true
	_hit_area.set_deferred("monitoring", with_damage)
	_trail.emitting = true
	_set_state(State.ROLLING)


## Collision-free homing back to `target` (the neck). It never damages anything.
func begin_return(target: Node3D, target_basis: Basis = Basis.IDENTITY) -> void:
	if state == State.STOWED or state == State.RETURNING:
		return
	_ret_target = target
	_ret_from = global_position
	_ret_from_basis = global_basis.orthonormalized()
	_ret_to_basis = target_basis
	_ret_t = 0.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_collision.set_deferred("disabled", true)
	_hit_area.set_deferred("monitoring", false)
	_trail.emitting = true
	_seat_receiver = null
	_set_state(State.RETURNING)


## Called by a Receiver when the head rolls or lands in its catch funnel.
func seat_at(xf: Transform3D, receiver: Node) -> void:
	if state != State.ROLLING:
		return
	_seat_receiver = receiver
	_seat_xf = xf
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	freeze = true
	_collision.set_deferred("disabled", true)
	_hit_area.set_deferred("monitoring", false)
	_trail.emitting = false
	_ret_from = global_position
	_ret_from_basis = global_basis.orthonormalized()
	_ret_t = 0.0
	_set_state(State.SEATED)
	seated.emit(receiver)


func get_seat_receiver() -> Node:
	return _seat_receiver


func _physics_process(delta: float) -> void:
	match state:
		State.ROLLING:
			_process_rolling(delta)
		State.RETURNING:
			_process_return(delta)
		State.SEATED:
			_process_seating(delta)


func _process_rolling(delta: float) -> void:
	_clock += delta
	_travel += global_position.distance_to(_last_pos)
	_last_pos = global_position
	_check_hits()
	if linear_velocity.length() < stall_speed:
		_stall += delta
	else:
		_stall = 0.0
	var fell := global_position.y < _origin.y - recovery_below_origin
	if _clock >= max_time or _travel >= max_distance or _stall >= stall_time or fell:
		returned_auto_requested.emit()



func _check_hits() -> void:
	if not damage_enabled:
		return
	for a in _hit_area.get_overlapping_areas():
		var id := a.get_instance_id()
		if _hit_ids.has(id) or not a.has_method(&"receive_head_hit"):
			continue
		# Dedupe ACCEPTED hits only: a boss in its cooldown may accept the next contact.
		if a.receive_head_hit(self):
			_hit_ids[id] = true
			chain += 1
			enemy_hit.emit(a.get_parent(), chain)


func _process_return(delta: float) -> void:
	_ret_t = minf(_ret_t + delta / maxf(return_time, 0.05), 1.0)
	var e := 1.0 - pow(1.0 - _ret_t, 3.0)
	var target := _ret_target.global_position if is_instance_valid(_ret_target) else _ret_from
	var arc := Vector3.UP * sin(_ret_t * PI) * 0.6
	global_position = _ret_from.lerp(target, e) + arc
	global_basis = _ret_from_basis.slerp(_ret_to_basis, e)
	reset_physics_interpolation()
	if _ret_t >= 1.0:
		stow()
		returned.emit()


func _process_seating(delta: float) -> void:
	if _ret_t < 1.0:
		_ret_t = minf(_ret_t + delta / maxf(seat_time, 0.05), 1.0)
		var e := 1.0 - pow(1.0 - _ret_t, 3.0)
		global_position = _ret_from.lerp(_seat_xf.origin, e)
		global_basis = _ret_from_basis.slerp(_seat_xf.basis.orthonormalized(), e)
		reset_physics_interpolation()
	elif is_instance_valid(_seat_receiver):
		global_transform = _seat_xf
