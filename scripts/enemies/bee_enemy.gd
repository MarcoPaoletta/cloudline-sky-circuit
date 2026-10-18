class_name BeeEnemy
extends EnemyBase
## Bounded air guard (GDD 11): flies a short local loop above a broad landing at 1.8 m/s, never camps a
## checkpoint or console, detects within 6 m, hovers with an amber wind-up for 0.8 s, makes a straight dive
## to the player's sampled chest height, then returns over 1.0 s. Never pursues beyond its encounter.
## v2: the loop sits `hover_height` above the floor under its placement (low enough for a rolling head to
## hit it, its hurtbox reaches down to the ground), and the dive really reaches the robot.

enum State { LOOP, WINDUP, DIVE, RETURN, RECOVER, DEAD }

@export_group("Bee")
@export var loop_radius: float = 2.5
@export var loop_speed: float = 1.8
@export var hover_height: float = 0.9
@export var detect_range: float = 6.0
@export var windup_time: float = 0.8
@export var dive_distance: float = 3.2
@export var dive_speed: float = 7.0
@export var return_time: float = 1.0
@export var recover_time: float = 0.6
@export var leash_radius: float = 8.0
## During the wind-up the bee drifts toward the robot (inside its leash) and stops this far away, so the dive
## connects unless the robot moves.
@export var approach_speed: float = 3.5
@export var approach_standoff: float = 2.2

@onready var _warn: Node3D = $WarnMark

var state: int = State.LOOP
var _t: float = 0.0
var _angle: float = 0.0
var _anchor: Vector3
var _dive_from: Vector3
var _dive_to: Vector3
var _ret_from: Vector3
var _dive_hit: bool = false
var _floor_y: float = 0.0
var _anchored: bool = false


func _setup() -> void:
	set_loop(["Flying"])
	play_anim("Flying", 1.0, 0.0)
	_warn.visible = false
	_anchor = home_xf.origin
	_angle = randf() * TAU
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not _anchored:
		# Resolved on the first physics frame, once the islands are in the physics space.
		_anchored = true
		_anchor = _hover_anchor(home_xf.origin)
		global_position = _anchor + Vector3(cos(_angle) * loop_radius, 0.0, sin(_angle) * loop_radius)
		reset_physics_interpolation()
	var p := get_player()
	match state:
		State.LOOP:
			_angle += (loop_speed / maxf(loop_radius, 0.5)) * delta
			var target := _anchor + Vector3(cos(_angle) * loop_radius, sin(_angle * 2.0) * 0.18, sin(_angle) * loop_radius)
			var tangent := Vector3(-sin(_angle), 0.0, cos(_angle))
			global_position = global_position.lerp(target, 1.0 - exp(-6.0 * delta))
			face_toward(tangent, delta, 6.0)
			if p and _can_notice(p):
				state = State.WINDUP
				_t = 0.0
				windup_started.emit(self)
				var a := get_node_or_null("/root/Audio")
				if a:
					a.play_sfx(&"enemy_windup", -6.0)
		State.WINDUP:
			_t += delta
			if p:
				face_toward(p.global_position - global_position, delta, 12.0)
				_approach(p, delta)
			# Hover bob + amber warning (blink slows into a steady mark: readable, never a strobe).
			global_position.y += sin(_t * 18.0) * 0.004
			_warn.visible = int(_t * 8.0) % 2 == 0 or _t > windup_time * 0.55
			if _t >= windup_time:
				_begin_dive(p)
		State.DIVE:
			_t += delta
			var k := clampf(_t * dive_speed / maxf(_dive_from.distance_to(_dive_to), 0.1), 0.0, 1.0)
			global_position = _dive_from.lerp(_dive_to, k)
			if not _dive_hit and p and p.is_alive() and (global_position + Vector3.UP * 0.4).distance_to(p.global_position + Vector3.UP * 0.9) < 1.15:
				_dive_hit = true
				p.take_damage(1, global_position)
			if k >= 1.0:
				state = State.RETURN
				_t = 0.0
				_ret_from = global_position
				play_anim("Flying", 1.0, 0.2)
		State.RETURN:
			_t += delta
			var k2 := clampf(_t / return_time, 0.0, 1.0)
			var e := k2 * k2 * (3.0 - 2.0 * k2)
			var home_pos := _anchor + Vector3(cos(_angle) * loop_radius, 0.0, sin(_angle) * loop_radius)
			global_position = _ret_from.lerp(home_pos, e)
			if k2 >= 1.0:
				state = State.RECOVER
				_t = 0.0
		State.RECOVER:
			_t += delta
			if _t >= recover_time:
				state = State.LOOP


func _approach(p: Player, delta: float) -> void:
	var to := p.global_position - global_position
	to.y = 0.0
	var dist := to.length()
	if dist <= approach_standoff:
		return
	var np := global_position + to / dist * minf(dist - approach_standoff, approach_speed * delta)
	if Vector2(np.x - _anchor.x, np.z - _anchor.z).length() <= leash_radius:
		global_position.x = np.x
		global_position.z = np.z


func _can_notice(p: Player) -> bool:
	if not p.is_alive():
		return false
	for z in get_tree().get_nodes_in_group(&"safe_zone"):
		if z is Node3D and (z as Node3D).global_position.distance_to(p.global_position) < 3.0:
			return false
	var flat := Vector2(p.global_position.x - _anchor.x, p.global_position.z - _anchor.z).length()
	if flat > leash_radius:
		return false
	return global_position.distance_to(p.global_position) <= detect_range and absf(p.global_position.y - _floor_y) < 2.5


func _begin_dive(p: Player) -> void:
	state = State.DIVE
	_t = 0.0
	_dive_hit = false
	_warn.visible = false
	play_anim("Bite_Front", 1.0, 0.1)
	_dive_from = global_position
	# Straight 2.5 m dive toward the player's sampled position (it never tracks during the dive).
	var sample := (p.global_position if p else global_position) + Vector3.UP * 0.8
	var dir := (sample - _dive_from)
	if dir.length() < 0.2:
		dir = Vector3(sin(_model_yaw), -0.2, cos(_model_yaw))
	_dive_to = _dive_from + dir.normalized() * minf(dive_distance, dir.length() + 0.8)
	# Never leave the encounter volume or dive into the floor.
	_dive_to.y = maxf(_dive_to.y, _floor_y + 0.35)


func _play_defeat() -> void:
	state = State.DEAD
	_warn.visible = false
	knockback_fall(_last_hit_dir)


## Loop centre: `hover_height` above the floor below the placement (placements are a few metres up).
func _hover_anchor(placed: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(placed + Vector3.UP * 0.5, placed + Vector3.DOWN * 8.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_floor_y = (hit["position"] as Vector3).y if not hit.is_empty() else placed.y - 1.4
	return Vector3(placed.x, _floor_y + hover_height, placed.z)


func _on_revive() -> void:
	_anchored = false
	state = State.LOOP
	_warn.visible = false
	play_anim("Flying", 1.0, 0.0)
