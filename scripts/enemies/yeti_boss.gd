class_name YetiBoss
extends EnemyBase
## Arena boss (GDD 20.5): about 3.2 m tall, 5 accepted roll hits (ONE per launch per boss through the head's
## accepted-hit dedupe, plus a short hit cooldown), always hittable otherwise. It telegraphs a summon for 0.8 s
## and births up to 6 enemies over 1.5 s every 8 s (max four summons = 24 extras), and makes a slow 1.0 s warned
## stomp with a visible ground ring (one damage in 3 m, 1.2 s recovery). Boss death cancels future summons.

signal health_changed(health: int, max_health: int)
signal boss_defeated(boss: YetiBoss)

enum State { ENTER, CHASE, SUMMON_TELL, SUMMONING, STOMP_TELL, RECOVER, DEAD }

@export_group("Boss")
@export var boss_name: String = "YETI"
@export var accent_color: Color = Color("#35d4f5")
@export var paint_color_for_summons: int = 0
@export var move_speed: float = 1.3
@export var first_summon_at: float = 2.0
@export var summon_interval: float = 8.0
@export var summon_telegraph: float = 0.8
@export var summon_duration: float = 1.5
@export var summons_per_cast: int = 6
@export var max_summons: int = 4
@export var stomp_telegraph: float = 1.0
@export var stomp_radius: float = 3.0
@export var stomp_recovery: float = 1.2
@export var stomp_cooldown: float = 5.5
@export var hit_cooldown: float = 0.35
@export var arena_radius: float = 21.0
@export var keep_distance: float = 5.0

@onready var _ring: MeshInstance3D = $StompRing
@onready var _tell: MeshInstance3D = $SummonTell
@onready var _accent: MeshInstance3D = $AccentRing

var state: int = State.ENTER
var _t: float = 0.0
var _clock: float = 0.0
var _next_summon: float = 0.0
var _summons_done: int = 0
var _born_this_cast: int = 0
var _stomp_cd: float = 3.0
var _hit_cd: float = 0.0
var _unit_scale: Vector3 = Vector3.ONE


func _setup() -> void:
	add_to_group(&"boss")
	_unit_scale = _model.scale
	set_loop(["MonsterArmature|Walk", "MonsterArmature|Idle"])
	play_anim("MonsterArmature|Idle", 1.0, 0.0)
	_ring.visible = false
	_tell.visible = false
	_next_summon = first_summon_at
	# Distinct cyan / coral accent (ring + icon colour), tinted on a private copy of the glow material.
	var am := (_accent.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
	am.albedo_color = accent_color
	am.emission = accent_color
	_accent.material_override = am
	health_changed.emit(health, max_health)
	set_physics_process(false)


func start_fight() -> void:
	set_physics_process(true)
	_clock = 0.0
	state = State.ENTER
	play_anim("MonsterArmature|Walk", 0.9, 0.2)
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_clock += delta
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	_stomp_cd = maxf(_stomp_cd - delta, 0.0)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	var p := get_player()
	match state:
		State.ENTER:
			_t += delta
			_walk_toward(Vector3.ZERO, delta, 0.9)
			if global_position.length() < arena_radius * 0.55 or _t > 3.5:
				state = State.CHASE
		State.CHASE:
			if p and p.is_alive():
				var to := p.global_position - global_position
				to.y = 0.0
				var d := to.length()
				face_toward(to, delta, 5.0)
				if d > keep_distance:
					_walk_toward(p.global_position, delta, 1.0)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
					velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
				if _summons_done < max_summons and _clock >= _next_summon:
					_begin_summon()
				elif d < stomp_radius + 2.2 and _stomp_cd <= 0.0:
					_begin_stomp()
		State.SUMMON_TELL:
			_t += delta
			_stop(delta)
			_tell.visible = true
			_tell.scale = Vector3.ONE * (1.0 + 0.2 * sin(_t * 14.0))
			if _t >= summon_telegraph:
				_tell.visible = false
				state = State.SUMMONING
				_t = 0.0
				_born_this_cast = 0
				play_anim("MonsterArmature|Yes", 1.2, 0.1)
		State.SUMMONING:
			_t += delta
			_stop(delta)
			var due := int(clampf(_t / summon_duration, 0.0, 1.0) * summons_per_cast + 0.999)
			while _born_this_cast < due and _born_this_cast < summons_per_cast:
				_born_this_cast += 1
				get_tree().call_group(&"arena_director", "request_summon", self)
			if _t >= summon_duration:
				_summons_done += 1
				_next_summon = _clock + summon_interval
				state = State.RECOVER
				_t = 0.0
				play_anim("MonsterArmature|Idle", 1.0, 0.2)
		State.STOMP_TELL:
			_t += delta
			_stop(delta)
			_ring.visible = true
			_ring.scale = Vector3.ONE * (0.4 + 0.6 * (_t / stomp_telegraph))
			if _t >= stomp_telegraph:
				_do_stomp(p)
		State.RECOVER:
			_t += delta
			_stop(delta)
			if _t >= stomp_recovery * (0.7 if _born_this_cast > 0 else 1.0):
				state = State.CHASE
				play_anim("MonsterArmature|Walk", 0.9, 0.3)
	move_and_slide()
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > arena_radius:
		var c := flat.normalized() * arena_radius
		global_position.x = c.x
		global_position.z = c.y


func _walk_toward(target: Vector3, delta: float, speed_scale: float) -> void:
	var to := target - global_position
	to.y = 0.0
	var dir := to.normalized() if to.length() > 0.05 else Vector3.ZERO
	velocity.x = dir.x * move_speed * speed_scale
	velocity.z = dir.z * move_speed * speed_scale
	face_toward(dir, delta, 4.0)


func _stop(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 14.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 14.0 * delta)


func _begin_summon() -> void:
	state = State.SUMMON_TELL
	_t = 0.0
	play_anim("MonsterArmature|No", 1.0, 0.1)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"boss_roar", -2.0)
		a.play_sfx(&"summon", -4.0)


func _begin_stomp() -> void:
	state = State.STOMP_TELL
	_t = 0.0
	play_anim("MonsterArmature|Bite_InPlace", 0.55, 0.1)


func _do_stomp(p: Player) -> void:
	_ring.visible = false
	state = State.RECOVER
	_t = 0.0
	_born_this_cast = 0
	_stomp_cd = stomp_cooldown
	play_anim("MonsterArmature|Idle", 1.0, 0.2)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"boss_stomp", -1.0)
	if p and p.is_alive():
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d <= stomp_radius and p.is_on_floor():
			p.take_damage(1, global_position)
		p.camera_rig().add_trauma(0.4)


## Accepts at most one hit per hit-cooldown window; the head dedupes accepted contacts per launch.
func take_head_hit(head: Node) -> bool:
	if not alive or _hit_cd > 0.0:
		return false
	health -= 1
	_hit_cd = hit_cooldown
	health_changed.emit(maxi(health, 0), max_health)
	_flash()
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"enemy_hit", 0.0, 0.7)
	get_player().camera_rig().add_trauma(0.3)
	if health <= 0:
		_defeat(head)
	return true


func _flash() -> void:
	var tw := create_tween()
	_model.scale = _unit_scale * 1.1
	tw.tween_property(_model, "scale", _unit_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _defeat(_head: Node) -> void:
	state = State.DEAD
	alive = false
	_hurtbox.set_enabled(false)
	collision_layer = 0
	collision_mask = 0
	_ring.visible = false
	_tell.visible = false
	set_targeted(false)
	get_tree().call_group(&"paint_manager", "boss_splash", global_position, paint_color_for_summons)
	get_tree().call_group(&"arena_director", "boss_down", self)
	boss_defeated.emit(self)
	defeated.emit(self)
	play_anim("MonsterArmature|Death", 0.8, 0.05)
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = create_tween()
	_death_tween.tween_interval(1.1)
	_death_tween.tween_property(_model, "scale", _unit_scale * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_death_tween.tween_callback(queue_free)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"boss_roar", 0.0, 0.7)


func summons_remaining() -> int:
	return max_summons - _summons_done


func reset_to_checkpoint() -> void:
	pass
