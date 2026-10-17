class_name EnemyBase
extends CharacterBody3D
## Shared enemy behavior: groups, health, the hurt interface used by the bowling head, the defeat flow
## (paint splash, coin reward, pop out), target highlight for aim assist and reset to the checkpoint snapshot.
## Concrete enemies (Crab, Bee, horde monsters, bosses) override the virtual hooks.

signal defeated(enemy: EnemyBase)

@export_group("Enemy")
@export var max_health: int = 1
## 0 cyan, 1 coral, 2 yellow, 3 violet (PaintManager palette).
@export var paint_color_id: int = 0
## Collect-once coin id given when this enemy is defeated (empty = no reward).
@export var reward_coin_id: String = ""
@export var respawn_on_reset: bool = true
@export var gravity_scale: float = 1.0

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


func _ready() -> void:
	add_to_group(&"enemy")
	add_to_group(&"resettable")
	home_xf = global_transform
	health = max_health
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0)) * gravity_scale
	_anim = _model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_player = get_tree().get_first_node_in_group(&"player") as Player
	exempt_from_paint(_model)
	_setup()


## Virtual: subclass setup after the base is ready.
func _setup() -> void:
	pass


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
	_on_hit(head)
	if health <= 0:
		_defeat(head)
	return true


func _on_hit(_head: Node) -> void:
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"enemy_hit", -4.0, randf_range(0.9, 1.1))


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


## Virtual: override for bespoke death. Default scales the model out.
func _play_defeat() -> void:
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_property(_model, "scale", Vector3.ONE * 0.01, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_death_tween.tween_callback(func() -> void: visible = false)


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
	_model.scale = Vector3.ONE
	collision_layer = 4
	collision_mask = 1
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
