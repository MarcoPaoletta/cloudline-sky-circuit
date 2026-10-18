class_name PlayerCamera
extends Node3D
## Third-person camera rig: CameraRig (top_level pivot) -> Arm (SpringArm3D) -> ArmEnd -> Camera3D.
##
## Position follow is RIGID on the interpolated body transform (an exponential lerp trails by speed/k metres).
## Smoothness lives in rotation, FOV, spring length, shake and punch. Camera roll is always zero.
## Console overview: the same perspective camera blends position, quaternion and FOV to a saved pose.

signal overview_entered
signal overview_exited

@export_group("Follow")
@export var follow_height: float = 1.2
@export var distance: float = 6.5
@export var fov: float = 60.0
@export var pitch_default_deg: float = -14.0
@export var pitch_min_deg: float = -55.0
@export var pitch_max_deg: float = 40.0
@export var shoulder_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
@export_group("Smoothing")
@export var distance_response: float = 5.0
@export var fov_response: float = 6.0
## Extra FOV while the robot sprints (none with Reduced Motion).
@export var sprint_fov_kick: float = 6.0
@export_group("Overview")
@export var overview_time: float = 0.65
@export var reduced_motion_time: float = 0.15

var yaw: float = 0.0
var pitch_deg: float = -14.0
var capture_enabled: bool = false

var _trauma: float = 0.0
var _punch: float = 0.0
var _noise_t: float = 0.0
var _want_distance: float = 6.5
var _want_fov: float = 60.0
var _overview_pose: Node3D
var _overview_fov: float = 32.0
var _overview_w: float = 0.0
var _overview_tween: Tween
var _in_overview: bool = false
var _look_locked: bool = false
var follow_fov_cache: float = 60.0

@onready var _player: Player = get_parent() as Player
@onready var _spring: SpringArm3D = $Arm
@onready var _arm_end: Node3D = $Arm/ArmEnd
@onready var _cam: Camera3D = $Arm/ArmEnd/Camera3D


func _ready() -> void:
	top_level = true
	_want_distance = distance
	_want_fov = fov
	_spring.spring_length = distance
	_cam.fov = fov
	pitch_deg = pitch_default_deg
	_noise_t = randf() * 100.0


func camera() -> Camera3D:
	return _cam


func yaw_basis() -> Basis:
	return Basis(Vector3.UP, yaw)


## Camera forward on the ground plane (what W moves along).
func ground_forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func aim_origin() -> Vector3:
	return _cam.global_position


func aim_direction() -> Vector3:
	return -_cam.global_basis.z


func is_in_overview() -> bool:
	return _in_overview or _overview_w > 0.001


func get_overview_weight() -> float:
	return _overview_w


## Smoothly change follow distance / FOV (arena framing).
func set_framing(new_distance: float, new_fov: float, new_follow_height: float = -1.0) -> void:
	_want_distance = new_distance
	_want_fov = new_fov
	if new_follow_height > 0.0:
		follow_height = new_follow_height


func snap_behind(model_yaw: float) -> void:
	yaw = model_yaw + PI
	pitch_deg = pitch_default_deg
	if _player:
		global_position = _player.global_position + Vector3(0.0, follow_height, 0.0)
	rotation = Vector3(deg_to_rad(pitch_deg), yaw, 0.0)
	reset_physics_interpolation()


func set_capture(value: bool) -> void:
	capture_enabled = value
	# Touch mode (v3) never captures the mouse: taps emulate the mouse and must stay free for the UI.
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value and not TouchPad.touch_mode else Input.MOUSE_MODE_VISIBLE


## Camera turn from a finger dragged on the right side of the screen (degrees, already scaled by the pad).
func apply_touch_look(deg: Vector2) -> void:
	if not capture_enabled or _look_locked or is_in_overview():
		return
	yaw -= deg_to_rad(deg.x * Campaign.mouse_sensitivity)
	var inv := -1.0 if Campaign.invert_y else 1.0
	pitch_deg = clampf(pitch_deg - deg.y * Campaign.mouse_sensitivity * inv, pitch_min_deg, pitch_max_deg)


func lock_look(value: bool) -> void:
	_look_locked = value


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount * Campaign.shake_scale * (0.35 if Campaign.reduced_motion else 1.0), 0.0, 1.0)


func punch(amount: float) -> void:
	_punch = clampf(_punch + amount * Campaign.shake_scale, -0.5, 0.5)


## Perspective overview: blends to the saved pose (a Camera3D or Node3D) over `overview_time`.
func begin_overview(pose: Node3D, duration: float = -1.0) -> void:
	_overview_pose = pose
	_overview_fov = (pose as Camera3D).fov if pose is Camera3D else 32.0
	var t := (reduced_motion_time if Campaign.reduced_motion else overview_time) if duration < 0.0 else duration
	_in_overview = true
	_tween_overview(1.0, t)
	overview_entered.emit()


func end_overview(duration: float = -1.0) -> void:
	var t := (reduced_motion_time if Campaign.reduced_motion else overview_time) if duration < 0.0 else duration
	_in_overview = false
	_tween_overview(0.0, t)


func _tween_overview(target: float, duration: float) -> void:
	if _overview_tween and _overview_tween.is_valid():
		_overview_tween.kill()
	_overview_tween = create_tween()
	_overview_tween.tween_property(self, "_overview_w", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if target <= 0.0:
		_overview_tween.tween_callback(func() -> void: overview_exited.emit())


func _unhandled_input(event: InputEvent) -> void:
	if not capture_enabled or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _look_locked or is_in_overview():
		return
	if event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		# One angular rate on both axes (0.1375 deg/px at sensitivity 1.0); screen_relative is stretch independent.
		var sens := 0.1375 * Campaign.mouse_sensitivity
		yaw -= deg_to_rad(m.screen_relative.x * sens)
		var inv := -1.0 if Campaign.invert_y else 1.0
		pitch_deg = clampf(pitch_deg - m.screen_relative.y * sens * inv, pitch_min_deg, pitch_max_deg)


func _process(delta: float) -> void:
	if _player == null:
		return
	if capture_enabled and not _look_locked and not is_in_overview():
		var look := Vector2(
			Input.get_action_strength(&"look_right") - Input.get_action_strength(&"look_left"),
			Input.get_action_strength(&"look_down") - Input.get_action_strength(&"look_up"))
		if look.length_squared() > 0.02:
			var rate := 150.0 * Campaign.mouse_sensitivity
			yaw -= deg_to_rad(look.x * rate * delta)
			var inv := -1.0 if Campaign.invert_y else 1.0
			pitch_deg = clampf(pitch_deg - look.y * rate * 0.6 * inv * delta, pitch_min_deg, pitch_max_deg)

	# Rigid follow on the interpolated body transform; zero roll.
	var body_pos := _player.get_global_transform_interpolated().origin
	global_position = body_pos + Vector3(0.0, follow_height, 0.0)
	rotation = Vector3(deg_to_rad(pitch_deg), yaw, 0.0)

	var kd := 1.0 - exp(-distance_response * delta)
	_spring.spring_length = lerpf(_spring.spring_length, _want_distance, kd)
	var kf := 1.0 - exp(-fov_response * delta)
	var want_fov := _want_fov
	if _player.sprinting and not Campaign.reduced_motion:
		want_fov += sprint_fov_kick
	var follow_fov := lerpf(_cam.fov if _overview_w < 0.001 else follow_fov_cache, want_fov, kf)
	follow_fov_cache = follow_fov

	# Trauma shake (quadratic) and punch.
	_trauma = maxf(0.0, _trauma - 1.6 * delta)
	var shake := _trauma * _trauma
	_noise_t += delta * 30.0
	var shake_rot := Vector3.ZERO
	if shake > 0.0001:
		shake_rot = Vector3(sin(_noise_t * 1.13) * cos(_noise_t * 0.71), sin(_noise_t * 0.97 + 4.0) * cos(_noise_t * 1.31), 0.0) * shake * 0.05
	_punch = lerpf(_punch, 0.0, 1.0 - exp(-9.0 * delta))
	var local_offset := shoulder_offset + Vector3(0.0, 0.0, _punch)

	if _overview_w > 0.001 and _overview_pose != null:
		var follow_xf := _arm_end.global_transform * Transform3D(Basis.from_euler(shake_rot), local_offset)
		var target_xf := _overview_pose.global_transform
		var qa := follow_xf.basis.get_rotation_quaternion()
		var qb := target_xf.basis.get_rotation_quaternion()
		var w := _overview_w
		_cam.top_level = true
		_cam.global_transform = Transform3D(Basis(qa.slerp(qb, w)), follow_xf.origin.lerp(target_xf.origin, w))
		_cam.fov = lerpf(follow_fov, _overview_fov, w)
	else:
		if _cam.top_level:
			_cam.top_level = false
		_cam.transform = Transform3D(Basis.from_euler(shake_rot), local_offset)
		_cam.fov = follow_fov

