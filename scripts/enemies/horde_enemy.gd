class_name HordeEnemy
extends EnemyBase
## Ordinary arena monster (GDD 20.5): one light chase/contact behavior with modest speed differences, 1 health,
## dies to a bowling contact. Spawned gradually by the ArenaDirector from a saved scene. Mushroom has only an
## Idle clip, so `hop` gives it an authored hop/squash locomotion instead of a walk clip.

@export_group("Horde")
@export var move_speed: float = 2.0
@export var contact_radius: float = 0.95
## A touch only lands after this long in contact (a readable window to slip away).
@export var touch_time: float = 0.3
@export var walk_clip: String = "MonsterArmature|Walk"
@export var idle_clip: String = "MonsterArmature|Idle"
@export var hop: bool = false
@export var arena_radius: float = 23.0
@export var pop_in_time: float = 0.28

var active: bool = false
var _t: float = 0.0
var _touch: float = 0.0
var _hop_phase: float = 0.0
var _unit_scale: Vector3 = Vector3.ONE


func _setup() -> void:
	_unit_scale = _model.scale
	set_loop([walk_clip, idle_clip])
	_hurtbox.set_enabled(false)
	visible = false
	set_physics_process(false)
	_hop_phase = randf() * TAU


## Brings a pooled/instanced monster into play at a portal landing.
func activate(pos: Vector3, face: Vector3) -> void:
	global_position = pos
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	alive = true
	health = max_health
	active = true
	visible = true
	collision_layer = 4
	collision_mask = 1
	_hurtbox.set_enabled(true)
	_t = 0.0
	var flat := Vector3(face.x, 0.0, face.z)
	if flat.length() > 0.01:
		_model_yaw = atan2(flat.x, flat.z)
		_model.rotation = Vector3(0.0, _model_yaw, 0.0)
	_model.transform.basis = Basis(Vector3.UP, _model_yaw) * Basis.from_scale(_unit_scale * 0.05)
	var tw := create_tween()
	tw.tween_property(_model, "scale", _unit_scale, pop_in_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if not hop:
		play_anim(walk_clip, 1.0 + randf() * 0.2, 0.0)
	else:
		play_anim(idle_clip, 1.0, 0.0)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_t += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	var p := get_player()
	if p and p.is_alive() and _t > pop_in_time * 0.6:
		var to := p.global_position - global_position
		to.y = 0.0
		var d := to.length()
		var dir := to / d if d > 0.01 else Vector3.ZERO
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		face_toward(dir, delta, 9.0)
		if d < contact_radius and absf(p.global_position.y - global_position.y) < 1.6:
			_touch += delta
			if _touch >= touch_time and p.take_damage(1, global_position):
				_touch = 0.0
		else:
			_touch = maxf(_touch - delta * 2.0, 0.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	if hop:
		_hop_phase += delta * 7.0
		var h := absf(sin(_hop_phase))
		_model.position.y = h * 0.28
		var sq := 1.0 + 0.1 * cos(_hop_phase * 2.0)
		_model.scale = Vector3(_unit_scale.x * (2.0 - sq), _unit_scale.y * sq, _unit_scale.z * (2.0 - sq))
	move_and_slide()
	# Stay inside the arena.
	var flat_pos := Vector2(global_position.x, global_position.z)
	if flat_pos.length() > arena_radius:
		var c := flat_pos.normalized() * arena_radius
		global_position.x = c.x
		global_position.z = c.y


func _play_defeat() -> void:
	active = false
	set_physics_process(false)
	_model.position.y = 0.0
	# Bowled over like a pin (the paint mark and burst are already out), then freed.
	knockback_fall(_last_hit_dir)


func _after_fall() -> void:
	queue_free()


func reset_to_checkpoint() -> void:
	pass
