class_name Player
extends CharacterBody3D
## The yellow robot. Body motion, health, animation and the public state other systems query.
## The head (HeadController) and the arm (FetchArm) are separate child scenes with their own behavior.
##
## Metrics follow GDD 4: run 6 m/s, accel 24 m/s2, air control 60 %, coyote 0.12 s, jump buffer 0.12 s,
## jump launch 8.5 m/s with 20 m/s2 gravity (about 1.8 m peak).

signal jumped
signal landed(fall_speed: float)
signal health_changed(health: int, max_health: int)
signal hurt(health: int)
signal died
signal fell
signal respawned
signal mode_changed(mode: int)

enum Mode { EXPLORE, CONSOLE, LOCKED, DEAD }

const CLIP := "RobotArmature|Robot_%s"

@export_group("Movement")
@export var run_speed: float = 6.0
@export var ground_accel: float = 24.0
@export var ground_decel: float = 30.0
@export var turn_accel: float = 42.0
@export_range(0.0, 1.0) var air_control: float = 0.6
@export var coyote_time: float = 0.12
@export var jump_buffer_time: float = 0.12
@export var jump_velocity: float = 8.5
@export var max_fall_speed: float = 38.0
@export var turn_rate: float = 16.0
@export_group("Health")
@export var max_health: int = 3
@export var invulnerable_time: float = 1.2
@export var recoil_speed: float = 5.5
@export_group("Safety")
@export var kill_plane_y: float = -60.0
@export_group("Animation blends (seconds)")
@export var blend_locomotion: float = 0.5
@export var blend_jump_in: float = 0.25
@export var blend_jump_out: float = 0.5
@export var blend_action_in: float = 0.2
@export var blend_action_out: float = 0.5

var mode: int = Mode.EXPLORE
var health: int = 3
var move_input: Vector2 = Vector2.ZERO
var input_enabled: bool = true
## Dev panel (F1) only: ignore all damage.
var debug_invulnerable: bool = false

var _gravity: float = 20.0
var _coyote: float = 0.0
var _jump_buffer: float = 0.0
var _last_wish: Vector3 = Vector3.ZERO
## Yaw of the model is OWNED here and written as a full euler triple, never read back from the basis.
var _model_yaw: float = 0.0
var _face_override: float = NAN
var _was_grounded: bool = true
var _invuln: float = 0.0
var _step_accum: float = 0.0
var _clip: String = ""
var _squash_tween: Tween
var _fell_emitted: bool = false

@onready var _model: Node3D = $Model
@onready var _robot: Node3D = $Model/Robot
@onready var _anim: AnimationPlayer = $Model/Robot/AnimationPlayer
@onready var _camera: PlayerCamera = $CameraRig


func _ready() -> void:
	add_to_group(&"player")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0))
	health = max_health
	# Characters live on their own visual layer so paint decals never tint them (enemies do the same).
	for v in _model.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = 1 << 19
	# Imported clips do not loop; locomotion clips must.
	for n in ["Idle", "Running", "Walking"]:
		var a := _anim.get_animation(CLIP % n)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_play("Idle", blend_locomotion)
	health_changed.emit(health, max_health)


func camera_rig() -> PlayerCamera:
	return _camera


func model_node() -> Node3D:
	return _model


func robot_node() -> Node3D:
	return _robot


func animation_player() -> AnimationPlayer:
	return _anim


func is_invulnerable() -> bool:
	return _invuln > 0.0


func is_alive() -> bool:
	return mode != Mode.DEAD


func facing_yaw() -> float:
	return _model_yaw


## Forward direction of the body on the ground plane (the robot faces local +Z).
func facing_dir() -> Vector3:
	return Vector3(sin(_model_yaw), 0.0, cos(_model_yaw))


## Places the player (physics body NEVER rotates; yaw lives on the model).
func teleport_to(xf: Transform3D, yaw: float = NAN) -> void:
	global_position = xf.origin
	rotation = Vector3.ZERO
	velocity = Vector3.ZERO
	_model_yaw = xf.basis.get_euler().y if is_nan(yaw) else yaw
	_model.rotation = Vector3(0.0, _model_yaw, 0.0)
	reset_physics_interpolation()
	_fell_emitted = false
	_camera.snap_behind(_model_yaw)


func set_input_enabled(value: bool) -> void:
	input_enabled = value
	if not value:
		move_input = Vector2.ZERO


func set_mode(new_mode: int) -> void:
	if mode == new_mode:
		return
	mode = new_mode
	set_input_enabled(new_mode == Mode.EXPLORE)
	mode_changed.emit(mode)


## Forces the model to face a world yaw (throws, console entry). NAN releases the override.
func face_yaw(yaw: float) -> void:
	_face_override = yaw


func restore_health() -> void:
	health = max_health
	health_changed.emit(health, max_health)


## Restores health pips (arena regen / chain reward). Returns true when something was restored.
func heal(amount: int = 1) -> bool:
	if mode == Mode.DEAD or health >= max_health:
		return false
	health = mini(health + amount, max_health)
	health_changed.emit(health, max_health)
	return true


func revive() -> void:
	mode = Mode.EXPLORE
	input_enabled = true
	_invuln = 1.0
	restore_health()
	respawned.emit()


## Returns true when damage was accepted. One accepted contact removes one pip.
func take_damage(amount: int = 1, from_pos: Vector3 = Vector3.INF) -> bool:
	if debug_invulnerable or _invuln > 0.0 or mode == Mode.DEAD or mode == Mode.CONSOLE:
		return false
	health = maxi(health - amount, 0)
	_invuln = invulnerable_time
	health_changed.emit(health, max_health)
	hurt.emit(health)
	_play_squash(Vector3(1.18, 0.82, 1.18))
	_camera.add_trauma(0.35)
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_sfx(&"hurt", -2.0)
	if health <= 0:
		mode = Mode.DEAD
		input_enabled = false
		_play("Death", blend_action_in)
		died.emit()
		return true
	if from_pos != Vector3.INF and not Campaign.no_recoil:
		_apply_recoil(from_pos)
	return true


func _apply_recoil(from_pos: Vector3) -> void:
	var away := global_position - from_pos
	away.y = 0.0
	if away.length_squared() < 0.0001:
		return
	away = away.normalized()
	# Only recoil toward safe ground: never shove the robot into a pit.
	var probe := global_position + away * 0.6 + Vector3(0.0, 0.5, 0.0)
	var q := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 2.0, 1)
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return
	velocity.x = away.x * recoil_speed
	velocity.z = away.z * recoil_speed


func _physics_process(delta: float) -> void:
	_coyote = maxf(0.0, _coyote - delta)
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_invuln = maxf(0.0, _invuln - delta)

	if input_enabled:
		move_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
		if Input.is_action_just_pressed(&"jump"):
			_jump_buffer = jump_buffer_time
	else:
		move_input = Vector2.ZERO

	var grounded := is_on_floor()
	if grounded:
		_coyote = coyote_time

	# Jump (one jump, coyote time and buffer).
	if _jump_buffer > 0.0 and (grounded or _coyote > 0.0) and input_enabled:
		velocity.y = maxf(velocity.y, jump_velocity)
		_jump_buffer = 0.0
		_coyote = 0.0
		grounded = false
		jumped.emit()
		_play_squash(Vector3(0.88, 1.16, 0.88))
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_sfx(&"jump", -4.0)

	# Gravity.
	if not grounded or velocity.y > 0.0:
		velocity.y = maxf(velocity.y - _gravity * delta, -max_fall_speed)

	# Horizontal.
	var wish := _wish_dir()
	_last_wish = wish
	var target := wish * run_speed
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var accel: float
	if wish.length_squared() > 0.001:
		var turning: bool = horiz.length() > 0.5 and horiz.normalized().dot(wish.normalized()) < -0.1
		accel = turn_accel if turning else ground_accel
	else:
		accel = ground_decel
	if not grounded:
		accel *= air_control
	horiz = horiz.move_toward(target, accel * delta)
	velocity.x = horiz.x
	velocity.z = horiz.z

	var vy_before := velocity.y
	move_and_slide()
	grounded = is_on_floor()
	if grounded and not _was_grounded:
		_on_landed(absf(vy_before))
	_was_grounded = grounded

	_face(delta)
	_animate(horiz, grounded, delta)
	_footsteps(horiz, grounded, delta)
	_update_flash()

	if global_position.y < kill_plane_y and not _fell_emitted and mode != Mode.DEAD:
		_fell_emitted = true
		fell.emit()


func _wish_dir() -> Vector3:
	if move_input.length_squared() < 0.0001:
		return Vector3.ZERO
	var dir: Vector3 = _camera.yaw_basis() * Vector3(move_input.x, 0.0, move_input.y)
	dir.y = 0.0
	return dir.normalized() * minf(1.0, move_input.length())


func _on_landed(fall_speed: float) -> void:
	landed.emit(fall_speed)
	if fall_speed > 3.0:
		var amount := clampf(0.08 + fall_speed * 0.01, 0.08, 0.28)
		_play_squash(Vector3(1.0 + amount, 1.0 - amount, 1.0 + amount))
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_sfx(&"land", -6.0)
		if fall_speed > 14.0:
			_camera.add_trauma(0.2)


func _face(delta: float) -> void:
	var target_yaw := NAN
	if not is_nan(_face_override):
		target_yaw = _face_override
	elif _last_wish.length_squared() > 0.01:
		# Face the steering INPUT, not the velocity (velocity trails by the whole accel ramp).
		target_yaw = atan2(_last_wish.x, _last_wish.z)
	if is_nan(target_yaw):
		return
	var k := 1.0 - exp(-turn_rate * delta)
	_model_yaw = lerp_angle(_model_yaw, target_yaw, k)
	_model.rotation = Vector3(0.0, _model_yaw, 0.0)


func _animate(horiz: Vector3, grounded: bool, _delta: float) -> void:
	if mode == Mode.DEAD:
		return
	if _action_playing():
		return
	var speed := horiz.length()
	if not grounded:
		if _clip != "Jump":
			_play("Jump", blend_jump_in)
	elif speed > 0.6:
		var clip := "Running"
		if _clip != clip:
			_play(clip, blend_jump_out if _clip == "Jump" else blend_locomotion)
		_anim.speed_scale = clampf(speed / run_speed, 0.6, 1.25)
	else:
		if _clip != "Idle":
			_play("Idle", blend_jump_out if _clip == "Jump" else blend_locomotion)
		_anim.speed_scale = 1.0


var _action_until: float = 0.0


func _action_playing() -> bool:
	return Time.get_ticks_msec() * 0.001 < _action_until


## Plays a one-shot gesture clip (Punch, Wave, Dance...) blending in/out. Returns the clip length.
func play_action(clip_name: String, speed: float = 1.0, hold_after: float = 0.0) -> float:
	var full := CLIP % clip_name
	if not _anim.has_animation(full):
		return 0.0
	var a := _anim.get_animation(full)
	_clip = clip_name
	_anim.play(full, blend_action_in, speed)
	var length := a.length / maxf(speed, 0.01)
	_action_until = Time.get_ticks_msec() * 0.001 + length + hold_after
	return length


func end_action() -> void:
	_action_until = 0.0
	_clip = ""


func _play(clip_name: String, blend: float) -> void:
	var full := CLIP % clip_name
	if not _anim.has_animation(full):
		return
	_clip = clip_name
	_anim.speed_scale = 1.0
	_anim.play(full, blend)


func _footsteps(horiz: Vector3, grounded: bool, delta: float) -> void:
	if not grounded or horiz.length() < 1.0:
		_step_accum = 0.0
		return
	_step_accum += horiz.length() * delta
	if _step_accum >= 2.3:
		_step_accum = 0.0
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_sfx(&"step", -14.0, randf_range(0.92, 1.08))


func _play_squash(target: Vector3) -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_model.scale = target
	_squash_tween = create_tween()
	_squash_tween.tween_property(_model, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _update_flash() -> void:
	# Readable damage invulnerability: slow pulse (never rapid strobing); calmer in reduced-flash mode.
	if _invuln > 0.0 and mode != Mode.DEAD:
		var hz := 3.0 if Campaign.reduced_flash else 7.0
		_robot.visible = int(_invuln * hz * 2.0) % 2 == 0 or _invuln < 0.05
	else:
		_robot.visible = true
