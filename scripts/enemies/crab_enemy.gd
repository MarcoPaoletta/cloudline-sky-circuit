class_name CrabEnemy
extends EnemyBase
## Readable ground guard (GDD 11): patrols a short authored strip at 1.6 m/s, detects within 5 m with line of
## sight, moves toward the player only while a tested floor exists at the projected next step, winds up for
## 0.65 s (warn mark + slowed claw), bites within 1.2 m, recovers 0.9 s. One head hit defeats it.

enum State { PATROL, CHASE, WINDUP, BITE, RECOVER, DEAD }

@export_group("Crab")
@export var patrol_speed: float = 1.6
@export var chase_speed: float = 2.3
## Half length of the patrol strip along the crab's local X axis.
@export var patrol_half_length: float = 3.0
@export var detect_range: float = 5.0
@export var windup_time: float = 0.65
@export var bite_reach: float = 1.2
@export var recover_time: float = 0.9
@export var edge_probe: float = 0.9
@export var attack_clear_zones: bool = true

@onready var _warn: Node3D = $WarnMark

var state: int = State.PATROL
var _t: float = 0.0
var _dir_sign: float = 1.0
var _blocked_cooldown: float = 0.0
var _bite_done: bool = false


func _setup() -> void:
	set_loop(["Walk", "Idle"])
	_warn.visible = false
	play_anim("Walk", 1.0, 0.0)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	_blocked_cooldown = maxf(_blocked_cooldown - delta, 0.0)
	var p := get_player()
	match state:
		State.PATROL:
			_do_patrol(delta, p)
		State.CHASE:
			_do_chase(delta, p)
		State.WINDUP:
			_t += delta
			velocity.x = 0.0
			velocity.z = 0.0
			if p:
				face_toward(p.global_position - global_position, delta, 14.0)
			_warn.visible = int(_t * 10.0) % 2 == 0 or _t > windup_time * 0.6
			if _t >= windup_time:
				_begin_bite()
		State.BITE:
			_t += delta
			velocity.x = 0.0
			velocity.z = 0.0
			if not _bite_done and _t >= 0.12:
				_bite_done = true
				_strike(p)
			if _t >= 0.55:
				state = State.RECOVER
				_t = 0.0
				play_anim("Idle", 1.0, 0.2)
		State.RECOVER:
			_t += delta
			velocity.x = 0.0
			velocity.z = 0.0
			if _t >= recover_time:
				state = State.PATROL
				play_anim("Walk", 1.0, 0.3)
	move_and_slide()


func _local_x() -> Vector3:
	return home_xf.basis.x.normalized()


func _do_patrol(delta: float, p: Player) -> void:
	var axis := _local_x()
	var rel := (global_position - home_xf.origin).dot(axis)
	if rel > patrol_half_length:
		_dir_sign = -1.0
	elif rel < -patrol_half_length:
		_dir_sign = 1.0
	var dir := axis * _dir_sign
	if not floor_ahead(dir, edge_probe):
		_dir_sign = -_dir_sign
		dir = -dir
	velocity.x = dir.x * patrol_speed
	velocity.z = dir.z * patrol_speed
	face_toward(dir, delta)
	if p and _can_notice(p):
		state = State.CHASE
		play_anim("Walk", 1.4, 0.2)


func _can_notice(p: Player) -> bool:
	if not p.is_alive() or _near_safe_zone(p):
		return false
	var d := global_position.distance_to(p.global_position)
	return d <= detect_range and absf(p.global_position.y - global_position.y) < 2.2 and line_of_sight_to_player(detect_range + 1.0)


## No enemy attacks within 3 m of checkpoints, console pads or tutorial anchors.
func _near_safe_zone(p: Player) -> bool:
	if not attack_clear_zones:
		return false
	for z in get_tree().get_nodes_in_group(&"safe_zone"):
		if z is Node3D and (z as Node3D).global_position.distance_to(p.global_position) < 3.0:
			return true
	return false


func _do_chase(delta: float, p: Player) -> void:
	if p == null or not _can_notice(p):
		state = State.PATROL
		play_anim("Walk", 1.0, 0.3)
		return
	var to := p.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var dir := to.normalized() if d > 0.01 else Vector3.ZERO
	face_toward(dir, delta, 12.0)
	if d <= bite_reach * 0.9:
		state = State.WINDUP
		_t = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		windup_started.emit(self)
		play_anim("Bite_InPlace", 0.45, 0.15)
		var a := get_node_or_null("/root/Audio")
		if a:
			a.play_sfx(&"enemy_windup", -6.0)
		return
	# Only step toward the player while a tested floor exists at the next step.
	if _blocked_cooldown <= 0.0 and not floor_ahead(dir, edge_probe):
		_blocked_cooldown = 0.35
	if _blocked_cooldown > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed


func _begin_bite() -> void:
	state = State.BITE
	_t = 0.0
	_bite_done = false
	_warn.visible = false
	play_anim("Bite_Front", 1.2, 0.05)


func _strike(p: Player) -> void:
	if p == null or not p.is_alive():
		return
	var fwd := Vector3(sin(_model_yaw), 0.0, cos(_model_yaw))
	var to := p.global_position - global_position
	to.y = 0.0
	if to.length() <= bite_reach + 0.5 and fwd.dot(to.normalized()) > 0.3:
		p.take_damage(1, global_position)


func _on_hit(head: Node) -> void:
	super._on_hit(head)
	_warn.visible = false


func _play_defeat() -> void:
	state = State.DEAD
	_warn.visible = false
	play_anim("Death", 1.6, 0.05)
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_interval(0.35)
	_death_tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_death_tween.tween_callback(func() -> void: visible = false)


func _on_revive() -> void:
	state = State.PATROL
	_warn.visible = false
	play_anim("Walk", 1.0, 0.0)
