class_name EnemyBase
extends CharacterBody3D
## Shared enemy behavior: groups, health, the hurt interface used by the bowling head, the defeat flow
## (paint splash, coin reward, knock-back fall), target highlight for aim assist and reset to the checkpoint snapshot.
## Every head hit flashes the model white for 0.07 s with a short hit stop (game-dev paint-splash "enemy tag");
## a defeated enemy is bowled over: thrown back along the head's roll, tipped onto its back, then it shrinks away.
## Concrete enemies (Crab, Bee, horde monsters, bosses) override the virtual hooks.

signal defeated(enemy: EnemyBase)
## Emitted when the enemy starts an attack wind-up (drives the first-wind-up guidance lines).
signal windup_started(enemy: EnemyBase)

@export_group("Enemy")
@export var max_health: int = 1
## 0 cyan, 1 coral, 2 yellow, 3 violet (PaintManager palette).
@export var paint_color_id: int = 0
## Collect-once coin id given when this enemy is defeated (empty = no reward).
@export var reward_coin_id: String = ""
@export var respawn_on_reset: bool = true
@export var gravity_scale: float = 1.0
@export_group("Hit reaction")
@export var flash_time: float = 0.07
@export var hit_stop_time: float = 0.045
@export var knock_distance: float = 2.2
@export var knock_height: float = 0.8
@export var knock_time: float = 0.42
@export var knock_tilt_deg: float = 100.0
@export var fallen_hold: float = 0.45
@export var vanish_time: float = 0.25
@export_group("Crowd")
## Collision mask while alive: the world (1) and other enemies (4), so crowded enemies push each other aside
## instead of overlapping. Arena monsters set their own mask (their director spaces the horde).
@export_flags_3d_physics var alive_mask: int = 5
## The model stops rendering beyond this distance from the camera (0 = always drawn).
@export var render_distance: float = 70.0

@onready var _hurtbox: EnemyHurtbox = $Hurtbox
@onready var _model: Node3D = $Model

var health: int = 1
var alive: bool = true
var home_xf: Transform3D
var _model_yaw: float = 0.0
var _gravity: float = 20.0
var _anim: AnimationPlayer
var _anim_name: String = ""
var _player: Player
var _death_tween: Tween
var _model_scale0: Vector3 = Vector3.ONE
var _flash_meshes: Array[GeometryInstance3D] = []
var _flash_left: float = 0.0
## Sleeping (far from the robot): no AI and no animation. The level director wakes enemies as the robot nears.
var dormant: bool = false

const FLASH_MAT: Material = preload("res://resources/materials/hit_flash.tres")
## Real-time end of the current hit stop (shared by every enemy so a chain is one stop, not a stutter).
static var _hit_stop_until: int = 0


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"resettable")
	home_xf = global_transform
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0)) * gravity_scale
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_model_scale0 = _model.scale
	exempt_from_paint(_model)
	for g in _model.find_children("*", "GeometryInstance3D", true, false):
		_flash_meshes.append(g as GeometryInstance3D)
		if render_distance > 0.0:
			(g as GeometryInstance3D).visibility_range_end = render_distance
	collision_mask = alive_mask
	_setup()


func _process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)


## Virtual: subclass setup after the base is ready.
func _setup() -> void:
	pass


## Puts the enemy to sleep (no AI, no animation) or wakes it. Called by the level director's crowd pass.
func set_dormant(on: bool) -> void:
	if on == dormant:
		return
	dormant = on
	set_physics_process(not on)
	if _anim:
		_anim.active = not on


## Characters live on their own visual layer so paint decals never tint them.
func exempt_from_paint(root: Node) -> void:
	for v in root.find_children("*", "VisualInstance3D", true, false):
		(v as VisualInstance3D).layers = 1 << 19


func get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


func is_targetable() -> bool:
	return alive


func set_targeted(on: bool) -> void:
	var ring := get_node_or_null("TargetRing") as Node3D
	if ring:
		ring.visible = on and alive


## Called through the EnemyHurtbox. Returns true when this contact was accepted.
func take_head_hit(head: Node) -> bool:
	if not alive:
		return false
	health -= 1
	_last_hit_dir = _hit_direction(head)
	_on_hit(head)
	if health <= 0:
		_defeat(head)
	return true


## The roll direction of the head (falls back to head-to-enemy when the head is nearly still).
func _hit_direction(head: Node) -> Vector3:
	var d := Vector3.ZERO
	if head is RigidBody3D:
		d = (head as RigidBody3D).linear_velocity
	d.y = 0.0
	if d.length() < 1.0 and head is Node3D:
		d = global_position - (head as Node3D).global_position
		d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else Vector3.ZERO


func _on_hit(_head: Node) -> void:
	flash_white()
	hit_stop()
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"enemy_hit", -4.0, randf_range(0.9, 1.1))


## White flash over every mesh of the model (an unshaded white overlay pass) for `flash_time` seconds.
func flash_white() -> void:
	_set_flash(true)
	_flash_left = flash_time


func _set_flash(on: bool) -> void:
	for g in _flash_meshes:
		if is_instance_valid(g):
			g.material_overlay = FLASH_MAT if on else null


## A brief freeze frame that sells the impact. Skipped when Reduced Motion is on; real-time, so it always ends.
func hit_stop() -> void:
	if hit_stop_time <= 0.0 or Campaign.reduced_motion:
		return
	var now := Time.get_ticks_msec()
	if now < _hit_stop_until or Engine.time_scale < 0.99:
		return
	_hit_stop_until = now + int(hit_stop_time * 1000.0) + 120
	var keep := Engine.time_scale
	Engine.time_scale = 0.05
	var t := get_tree().create_timer(hit_stop_time, true, false, true)
	t.timeout.connect(func() -> void: Engine.time_scale = keep)


func _defeat(head: Node) -> void:
	alive = false
	_hurtbox.set_enabled(false)
	collision_layer = 0
	collision_mask = 0
	set_targeted(false)
	velocity = Vector3.ZERO
	var hit_dir := Vector3.ZERO
	if head is Node3D:
		hit_dir = (global_position - (head as Node3D).global_position)
	get_tree().call_group(&"paint_manager", "enemy_splash", global_position, paint_color_id, 1.0, hit_dir)
	if reward_coin_id != "":
		var lvl := get_tree().get_first_node_in_group(&"level") as LevelDirector
		var n := lvl.level_number if lvl else Campaign.current_level
		if Campaign.add_coin(n, reward_coin_id, 1):
			var a := get_node_or_null("/root/Audio")
			if a:
				a.play_sfx(&"coin", -2.0)
	defeated.emit(self)
	_play_defeat()


## Virtual: override for bespoke death. Default is the bowled-over fall.
func _play_defeat() -> void:
	knockback_fall(_last_hit_dir)


var _last_hit_dir: Vector3 = Vector3.ZERO
var _kb_start: Vector3
var _kb_end: Vector3
var _kb_land_y: float
var _kb_axis: Vector3
var _kb_base: Basis


## Thrown back along `dir` with a small arc, tipped over onto its back (it faces the hit as it falls), lands on
## the floor below the end point (or keeps falling off an edge), lies there for `fallen_hold`, then shrinks away
## evenly (never squashed). Calls `_after_fall()` at the end.
func knockback_fall(dir: Vector3) -> void:
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = -Vector3(sin(_model_yaw), 0.0, cos(_model_yaw))
	flat = flat.normalized()
	_kb_start = global_position
	_kb_end = _kb_start + flat * knock_distance
	var q := PhysicsRayQueryParameters3D.create(_kb_end + Vector3.UP * 1.5, _kb_end + Vector3.DOWN * 6.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	_kb_land_y = (hit["position"] as Vector3).y if not hit.is_empty() else _kb_start.y - 9.0
	_kb_axis = Vector3.UP.cross(flat).normalized()
	_model_yaw = atan2(-flat.x, -flat.z)
	_kb_base = Basis(Vector3.UP, _model_yaw)
	# Recoil pose while it flies back (pack clips are "HitRecieve" or "MonsterArmature|HitRecieve").
	play_anim("HitRecieve", 1.0, 0.05)
	play_anim("MonsterArmature|HitRecieve", 1.0, 0.05)
	_death_tween = create_tween()
	_death_tween.tween_method(_knock_step, 0.0, 1.0, knock_time)
	_death_tween.tween_interval(fallen_hold)
	_death_tween.tween_property(_model, "scale", _model_scale0 * 0.01, vanish_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_death_tween.tween_callback(_after_fall)


func _knock_step(t: float) -> void:
	var e := 1.0 - (1.0 - t) * (1.0 - t)
	var p := _kb_start.lerp(_kb_end, e)
	p.y = lerpf(_kb_start.y, _kb_land_y, t * t) + sin(t * PI) * knock_height
	global_position = p
	var tilt := deg_to_rad(knock_tilt_deg) * minf(t * 1.25, 1.0)
	_model.transform.basis = Basis(_kb_axis, tilt) * _kb_base * Basis.from_scale(_model_scale0)


## Virtual: what happens once the fall is over (platform enemies hide until a checkpoint reset).
func _after_fall() -> void:
	visible = false


func reset_to_checkpoint() -> void:
	if respawn_on_reset or alive:
		revive()


func revive() -> void:
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	alive = true
	health = max_health
	visible = true
	global_transform = home_xf
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	_model.transform.basis = Basis(Vector3.UP, _model_yaw) * Basis.from_scale(_model_scale0)
	_set_flash(false)
	_flash_left = 0.0
	collision_layer = 4
	collision_mask = alive_mask
	_hurtbox.set_enabled(true)
	_on_revive()


func _on_revive() -> void:
	pass


func play_anim(clip: String, speed: float = 1.0, blend: float = 0.2) -> void:
	if _anim == null or not _anim.has_animation(clip):
		return
	_anim_name = clip
	_anim.play(clip, blend, speed)


func set_loop(clips: Array) -> void:
	if _anim == null:
		return
	for c in clips:
		if _anim.has_animation(c):
			_anim.get_animation(c).loop_mode = Animation.LOOP_LINEAR


func face_toward(dir: Vector3, delta: float, rate: float = 10.0) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	var target := atan2(flat.x, flat.z)
	_model_yaw = lerp_angle(_model_yaw, target, 1.0 - exp(-rate * delta))
	_model.rotation = Vector3(0.0, _model_yaw, 0.0)


func floor_ahead(dir: Vector3, probe: float) -> bool:
	var from := global_position + dir * probe + Vector3.UP * 0.8
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 3.2, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func line_of_sight_to_player(max_range: float) -> bool:
	var p := get_player()
	if p == null or not p.is_alive():
		return false
	var a := global_position + Vector3.UP * 0.7
	var b := p.global_position + Vector3.UP * 0.9
	if a.distance_to(b) > max_range:
		return false
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()
