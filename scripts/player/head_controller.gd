class_name HeadController
extends Node
## Owns the head's states for the Player (GDD 5 and 20.2):
##   ATTACHED -> GRABBING (hand reaches, lifts) -> ROLLING (physical bowling ball) -> RETURNING -> RECOVER -> ATTACHED
##   ATTACHED -> GRABBING -> ROLLING -> SEATED (caught by a Receiver socket) -> RETURNING (recall)
## Left mouse bowls, Q sends the head to the targeted Receiver (a validated physical lob) or recalls.
## Never a lost head: recall is always available, falls/respawns restore exactly one attached head.

signal head_launched(deploy: bool)
signal head_returned
signal head_seated(receiver: Node)
signal enemy_hit(enemy: Node, chain: int)
signal rejected(reason: StringName)
signal state_changed(state: int)

enum State { ATTACHED, GRABBING, ROLLING, SEATED, RETURNING, RECOVER }

@export_group("Bowl")
@export var hide_head_time: float = 0.08
@export var release_delay: float = 0.30
@export var recover_time: float = 0.1
@export var launch_height: float = 0.55
@export_group("Aim assist")
@export var assist_range: float = 24.0
@export var assist_cone_deg: float = 22.0
@export_group("Deploy to receiver")
@export var deploy_range: float = 12.0
@export var view_cone_deg: float = 60.0
@export var max_lob_speed: float = 24.0
@export var lob_times: PackedFloat32Array = PackedFloat32Array([0.45, 0.55, 0.65, 0.75, 0.9, 1.05, 1.2, 1.4])

@onready var _player: Player = get_parent() as Player
@onready var _head: DetachedHead = $"../DetachedHead"
@onready var _dots: Array[Node] = $ArcDots.get_children()

var state: int = State.ATTACHED
var _t: float = 0.0
var _gravity: float = 20.0
var _aim_dir: Vector3 = Vector3.FORWARD
var _deploy_velocity: Vector3 = Vector3.ZERO
var _is_deploy: bool = false
var _launched: bool = false
var _hidden_done: bool = false
var _target_receiver: Node
var _target_enemy: Node
var _seated_receiver: Node
var _attached_node: Node3D
var _skeleton: Skeleton3D
var _palm_bone: int = -1
var _first_hit_said: bool = false
var _prompt_owner := &"head"


func _ready() -> void:
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0))
	# Children _ready before their parent, so read the robot nodes directly (Player caches them later).
	var robot := _player.get_node("Model/Robot") as Node3D
	_attached_node = robot.get_node("RobotArmature/Skeleton3D/Head2") as Node3D
	_skeleton = robot.get_node("RobotArmature/Skeleton3D") as Skeleton3D
	_palm_bone = _skeleton.find_bone("Palm2.R")
	_head.returned.connect(_on_head_returned)
	_head.seated.connect(_on_head_seated)
	_head.enemy_hit.connect(_on_enemy_hit)
	_head.returned_auto_requested.connect(recall)
	_head.top_level = true
	for d in _dots:
		(d as Node3D).visible = false
		(d as Node3D).top_level = true


func is_attached() -> bool:
	return state == State.ATTACHED


func get_state() -> int:
	return state


func head_node() -> DetachedHead:
	return _head


func seated_receiver() -> Node:
	return _seated_receiver


func neck_position() -> Vector3:
	return _attached_node.global_position


func _hand_xf() -> Transform3D:
	if _palm_bone >= 0:
		return Transform3D(Basis.IDENTITY, (_skeleton.global_transform * _skeleton.get_bone_global_pose(_palm_bone)).origin)
	return Transform3D(Basis.IDENTITY, _player.global_position + Vector3.UP * 1.0)


func _set_state(s: int) -> void:
	state = s
	state_changed.emit(s)


func _hud() -> Node:
	return get_tree().get_first_node_in_group(&"hud")


func _say(id: StringName) -> void:
	get_tree().call_group(&"dialogue_panel", "say", id)


func _sfx(id: StringName, db: float = 0.0) -> void:
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(id, db)


func _physics_process(delta: float) -> void:
	if _player.mode == Player.Mode.DEAD:
		return
	var enabled := _player.input_enabled
	match state:
		State.ATTACHED:
			if enabled:
				_update_targeting()
				if Input.is_action_just_pressed(&"head_attack") or (Campaign.hold_to_bowl and Input.is_action_pressed(&"head_attack")):
					_begin_bowl(false)
				elif Input.is_action_just_pressed(&"head_deploy"):
					_try_deploy()
			else:
				_clear_targeting()
		State.GRABBING:
			_process_grab(delta)
		State.ROLLING:
			_hide_prompt_if_needed()
			if enabled and Input.is_action_just_pressed(&"head_deploy"):
				recall()
			elif enabled and Input.is_action_just_pressed(&"head_attack"):
				pass
		State.SEATED:
			if enabled and Input.is_action_just_pressed(&"head_attack"):
				_say(&"attack_seated")
				if is_instance_valid(_seated_receiver) and _seated_receiver.has_method(&"pulse"):
					_seated_receiver.pulse()
				_sfx(&"invalid", -4.0)
				var h := _hud()
				if h:
					h.set_tool_state("Recall your head first")
					get_tree().create_timer(1.5).timeout.connect(func() -> void:
						if is_instance_valid(h) and state == State.SEATED:
							h.set_tool_state(""))
			elif enabled and Input.is_action_just_pressed(&"head_deploy"):
				recall()
		State.RECOVER:
			_t -= delta
			if _t <= 0.0:
				_set_state(State.ATTACHED)


# ---------------------------------------------------------------- targeting

func _cam_forward() -> Vector3:
	return _player.camera_rig().ground_forward()


func _update_targeting() -> void:
	var hud := _hud()
	var cam := _player.camera_rig()
	var fwd := _cam_forward()
	# Receiver for Q.
	var best_recv: Node = null
	var best_score := -1.0
	var best_sol: Dictionary = {}
	var origin := neck_position()
	for r in get_tree().get_nodes_in_group(&"receiver"):
		if not r.has_method(&"get_catch_point") or not r.is_available():
			continue
		var cp: Vector3 = r.get_catch_point()
		var to := cp - origin
		var dist := to.length()
		if dist > deploy_range:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var dot := fwd.dot(flat.normalized()) if flat.length() > 0.2 else 1.0
		if dot < cos(deg_to_rad(view_cone_deg)):
			continue
		var score := dot - dist * 0.01
		if score > best_score:
			var sol := _solve_lob(origin, cp)
			if sol.is_empty():
				continue
			best_score = score
			best_recv = r
			best_sol = sol
	if best_recv != _target_receiver:
		if _target_receiver and is_instance_valid(_target_receiver):
			_target_receiver.set_highlight(false)
		_target_receiver = best_recv
		if best_recv:
			best_recv.set_highlight(true)
			_say(&"relay_hint")
	if _target_receiver:
		_deploy_velocity = best_sol["v"] if not best_sol.is_empty() else _deploy_velocity
		if not best_sol.is_empty():
			_show_arc(origin, best_sol["v"], best_sol["T"])
		if hud:
			hud.set_prompt(_prompt_owner, Campaign.key_text(&"head_deploy"), "Send head to the socket")
	else:
		_hide_arc()
		if hud and state == State.ATTACHED:
			hud.clear_prompt(_prompt_owner)
	# Aim assist target for bowling (hold aim_assist).
	var want_assist := Campaign.aim_assist and Input.is_action_pressed(&"aim_assist")
	var enemy := _find_enemy(origin, fwd) if want_assist else null
	if enemy != _target_enemy:
		if _target_enemy and is_instance_valid(_target_enemy) and _target_enemy.has_method(&"set_targeted"):
			_target_enemy.set_targeted(false)
		_target_enemy = enemy
		if enemy and enemy.has_method(&"set_targeted"):
			enemy.set_targeted(true)
	if hud:
		hud.set_tool_state("Bowl" if want_assist else "")
	if cam:
		pass


func _clear_targeting() -> void:
	if _target_receiver and is_instance_valid(_target_receiver):
		_target_receiver.set_highlight(false)
	_target_receiver = null
	_hide_arc()
	if _target_enemy and is_instance_valid(_target_enemy) and _target_enemy.has_method(&"set_targeted"):
		_target_enemy.set_targeted(false)
	_target_enemy = null
	var hud := _hud()
	if hud:
		hud.clear_prompt(_prompt_owner)


func _find_enemy(origin: Vector3, fwd: Vector3) -> Node:
	var best: Node = null
	var best_dot := cos(deg_to_rad(assist_cone_deg))
	for e in get_tree().get_nodes_in_group(&"enemy"):
		if not (e is Node3D) or not e.has_method(&"is_targetable") or not e.is_targetable():
			continue
		var to := (e as Node3D).global_position - origin
		to.y = 0.0
		var d := to.length()
		if d > assist_range or d < 1.0:
			continue
		var dot := fwd.dot(to / d)
		if dot > best_dot:
			best_dot = dot
			best = e
	return best


func _hide_prompt_if_needed() -> void:
	var hud := _hud()
	if hud:
		hud.set_prompt(_prompt_owner, Campaign.key_text(&"head_deploy"), "Recall your head")


# ---------------------------------------------------------------- lob solver

func _solve_lob(from: Vector3, to: Vector3) -> Dictionary:
	var best: Dictionary = {}
	for t in lob_times:
		var v := (to - from) / t + Vector3(0.0, 0.5 * _gravity * t, 0.0)
		if v.length() > max_lob_speed:
			continue
		if not _path_clear(from, v, t, to):
			continue
		if best.is_empty() or v.length() < (best["v"] as Vector3).length():
			best = {"v": v, "T": t}
	return best


func _path_clear(from: Vector3, v: Vector3, t_total: float, to: Vector3) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var prev := from
	var steps := 14
	for i in range(1, steps + 1):
		var tt := t_total * float(i) / float(steps)
		var p := from + v * tt + Vector3(0.0, -0.5 * _gravity * tt * tt, 0.0)
		# The last stretch ends inside the socket funnel, which is not an obstacle.
		if p.distance_to(to) < 1.1:
			break
		var q := PhysicsRayQueryParameters3D.create(prev, p, 1)
		if not space.intersect_ray(q).is_empty():
			return false
		prev = p
	return true


func _show_arc(from: Vector3, v: Vector3, t_total: float) -> void:
	var n := _dots.size()
	for i in n:
		var d := _dots[i] as Node3D
		var tt := t_total * float(i + 1) / float(n + 1)
		d.global_position = from + v * tt + Vector3(0.0, -0.5 * _gravity * tt * tt, 0.0)
		d.visible = true


func _hide_arc() -> void:
	for d in _dots:
		(d as Node3D).visible = false


# ---------------------------------------------------------------- bowling

func _try_deploy() -> void:
	if _target_receiver == null:
		rejected.emit(&"no_socket")
		_sfx(&"invalid", -3.0)
		var h := _hud()
		if h:
			h.toast("No socket in range", Color("#ffb347"))
		return
	_begin_bowl(true)


func _begin_bowl(deploy: bool) -> void:
	if _player.mode != Player.Mode.EXPLORE:
		return
	_is_deploy = deploy
	_launched = false
	_hidden_done = false
	_t = 0.0
	var fwd := _cam_forward()
	_aim_dir = fwd
	if deploy and _target_receiver:
		var to: Vector3 = _target_receiver.get_catch_point() - neck_position()
		to.y = 0.0
		if to.length() > 0.1:
			_aim_dir = to.normalized()
	elif _target_enemy and is_instance_valid(_target_enemy):
		var to2: Vector3 = (_target_enemy as Node3D).global_position - neck_position()
		to2.y = 0.0
		if to2.length() > 0.1:
			_aim_dir = to2.normalized()
	elif Campaign.aim_assist:
		_aim_dir = _assisted_direction(neck_position(), fwd)
	_player.face_yaw(atan2(_aim_dir.x, _aim_dir.z))
	_player.play_action("Punch", 1.55)
	_set_state(State.GRABBING)
	_sfx(&"head_grab", -4.0)
	var hud := _hud()
	if hud:
		hud.clear_prompt(_prompt_owner)
		hud.set_tool_state("")
	_clear_targeting_visuals_only()


func _clear_targeting_visuals_only() -> void:
	_hide_arc()
	if _target_receiver and is_instance_valid(_target_receiver) and not _is_deploy:
		_target_receiver.set_highlight(false)
	if _target_enemy and is_instance_valid(_target_enemy) and _target_enemy.has_method(&"set_targeted"):
		_target_enemy.set_targeted(false)
	_target_enemy = null


func _process_grab(delta: float) -> void:
	_t += delta
	_player.face_yaw(atan2(_aim_dir.x, _aim_dir.z))
	if not _hidden_done and _t >= hide_head_time:
		_hidden_done = true
		_attached_node.visible = false
		var hold_xf := Transform3D(Basis(Vector3.UP, atan2(_aim_dir.x, _aim_dir.z)), neck_position())
		_head.hold(hold_xf)
	if _hidden_done and not _launched:
		# Neck -> hand over the anticipation, then underarm release.
		var k := clampf((_t - hide_head_time) / maxf(release_delay - hide_head_time, 0.05), 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 2.0)
		var hand := _hand_xf().origin
		var low := _player.global_position + _aim_dir * 0.75 + Vector3.UP * launch_height
		var target_pos := hand.lerp(low, 0.55)
		var neck := neck_position()
		_head.move_held(Transform3D(Basis(Vector3.UP, atan2(_aim_dir.x, _aim_dir.z)), neck.lerp(target_pos, e)))
	if _t >= release_delay and not _launched:
		_launched = true
		_release()


func _release() -> void:
	var pos := _head.global_position
	# Keep the ball outside walls: if the start point is inside geometry, start from the chest.
	var space := _player.get_world_3d().direct_space_state
	var chest := _player.global_position + Vector3.UP * 0.9
	var q := PhysicsRayQueryParameters3D.create(chest, pos, 1)
	if not space.intersect_ray(q).is_empty():
		pos = chest
	var vel: Vector3
	if _is_deploy and _target_receiver and is_instance_valid(_target_receiver):
		var sol := _solve_lob(pos, _target_receiver.get_catch_point())
		vel = sol["v"] if not sol.is_empty() else _aim_dir * _head.launch_speed
	else:
		vel = _aim_dir * _head.launch_speed + Vector3.UP * _head.launch_lift
	_head.launch(pos, vel, _aim_dir, true)
	_set_state(State.ROLLING)
	_sfx(&"head_throw", -2.0)
	_player.camera_rig().punch(0.05)
	head_launched.emit(_is_deploy)
	_player.face_yaw(NAN)


## Corridor aim assist (never touches gravity or teleports the ball): nudges the INITIAL roll direction toward
## the densest line of enemies within +-assist_nudge_deg of where the camera points.
@export var assist_nudge_deg: float = 22.0
@export var assist_corridor_half_width: float = 1.4


func _assisted_direction(origin: Vector3, fwd: Vector3) -> Vector3:
	var enemies := get_tree().get_nodes_in_group(&"enemy")
	if enemies.is_empty():
		return fwd
	var base := atan2(fwd.x, fwd.z)
	var best_n := 0
	var best_a := base
	var steps := 11
	for i in steps:
		var off := deg_to_rad(lerpf(-assist_nudge_deg, assist_nudge_deg, float(i) / float(steps - 1)))
		var a := base + off
		var d := Vector3(sin(a), 0.0, cos(a))
		var n := 0
		for e in enemies:
			if not (e is Node3D) or not e.has_method(&"is_targetable") or not e.is_targetable():
				continue
			var rel: Vector3 = (e as Node3D).global_position - origin
			rel.y = 0.0
			var along: float = rel.dot(d)
			if along > 1.0 and along < 20.0 and (rel - d * along).length() < assist_corridor_half_width:
				n += 1
		# Prefer the direction nearest the camera when counts tie.
		if n > best_n or (n == best_n and n > 0 and absf(off) < absf(best_a - base)):
			best_n = n
			best_a = a
	if best_n >= 2:
		return Vector3(sin(best_a), 0.0, cos(best_a))
	return fwd


# ---------------------------------------------------------------- recall and return

func recall() -> void:
	if state != State.ROLLING and state != State.SEATED and state != State.GRABBING:
		return
	if state == State.GRABBING and not _hidden_done:
		_set_state(State.ATTACHED)
		_player.face_yaw(NAN)
		return
	var was_seated := state == State.SEATED
	if was_seated and is_instance_valid(_seated_receiver) and _seated_receiver.has_method(&"unseat"):
		_seated_receiver.unseat()
	_seated_receiver = null
	_set_state(State.RETURNING)
	_sfx(&"head_recall", -3.0)
	_head.begin_return(_attached_node, _player.model_node().global_basis.orthonormalized())
	var hud := _hud()
	if hud:
		hud.clear_prompt(_prompt_owner)
		hud.set_tool_state("")


func _on_head_returned() -> void:
	_attached_node.visible = true
	_player.face_yaw(NAN)
	_attached_node.scale = Vector3(1.25, 1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(_attached_node, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_set_state(State.RECOVER)
	_t = recover_time
	_sfx(&"head_reattach", -4.0)
	head_returned.emit()
	if _first_hit_said:
		_say(&"combat_done")


func _on_head_seated(receiver: Node) -> void:
	_seated_receiver = receiver
	_set_state(State.SEATED)
	_sfx(&"head_seat", -2.0)
	head_seated.emit(receiver)
	_say(&"relay_done")
	var hud := _hud()
	if hud:
		hud.set_prompt(_prompt_owner, Campaign.key_text(&"head_deploy"), "Recall your head")


func _on_enemy_hit(enemy: Node, chain: int) -> void:
	if not _first_hit_said:
		_first_hit_said = true
	enemy_hit.emit(enemy, chain)


## Hard reset used by respawn, level change and arena handoff: exactly one attached head.
func reset_to_attached() -> void:
	if _seated_receiver and is_instance_valid(_seated_receiver) and _seated_receiver.has_method(&"unseat"):
		_seated_receiver.unseat()
	_seated_receiver = null
	_head.stow()
	_attached_node.visible = true
	_attached_node.scale = Vector3.ONE
	_player.face_yaw(NAN)
	_clear_targeting()
	_set_state(State.ATTACHED)
	_launched = false
