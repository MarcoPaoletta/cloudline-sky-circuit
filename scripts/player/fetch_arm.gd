class_name FetchArm
extends Node3D
## One forearm/hand launches at a valid target within 10 m (GDD 6). Light collectibles come straight back to the
## hand (one at a time); heavy crates are pulled along an authored lane at 2 m/s only while the robot stands
## on the matching anchor tile. F again cancels; the body is never moved by the tether and the arm never
## damages anything. The highlighted target is exactly what will be fetched.

signal fetch_started(target: Node)
signal fetch_completed(target: Node)
signal fetch_cancelled
signal rejected

enum State { IDLE, OUT, GRAB, BACK, PULL, CANCEL }

@export var reach: float = 10.0
@export var cone_deg: float = 12.0
@export var out_speed: float = 24.0
@export var back_speed: float = 12.0
@export var pull_speed: float = 2.0
@export var grab_time: float = 0.12

@onready var _player: Player = get_parent() as Player
@onready var _rig: Node3D = $Rig
@onready var _tether: MeshInstance3D = $Tether

var state: int = State.IDLE
var _target: Node
var _candidate: Node
var _t: float = 0.0
var _skeleton: Skeleton3D
var _shoulder_bone: int = -1
var _palm_bone: int = -1
var _hide_hand: Node3D
var _hide_arm: Node3D
var _carrying: bool = false


func _ready() -> void:
	var robot := _player.get_node("Model/Robot") as Node3D
	_skeleton = robot.get_node("RobotArmature/Skeleton3D") as Skeleton3D
	_shoulder_bone = _skeleton.find_bone("UpperArm.R")
	_palm_bone = _skeleton.find_bone("Palm2.R")
	_hide_hand = _skeleton.get_node("Hand_R") as Node3D
	_hide_arm = _skeleton.get_node("Arm_R") as Node3D
	_rig.top_level = true
	_tether.top_level = true
	_rig.visible = false
	_tether.visible = false
	_player.mode_changed.connect(func(_m: int) -> void: cancel_now())
	_player.died.connect(cancel_now)


func is_busy() -> bool:
	return state != State.IDLE


func get_state() -> int:
	return state


func target_node() -> Node:
	return _target


func _bone_origin(idx: int, fallback: Vector3) -> Vector3:
	if idx < 0:
		return fallback
	return (_skeleton.global_transform * _skeleton.get_bone_global_pose(idx)).origin


func shoulder_pos() -> Vector3:
	return _bone_origin(_shoulder_bone, _player.global_position + Vector3.UP * 1.1)


func hand_pos() -> Vector3:
	return _bone_origin(_palm_bone, _player.global_position + Vector3.UP * 0.8)


func _hud() -> Node:
	return get_tree().get_first_node_in_group(&"hud")


func _sfx(id: StringName, db: float = 0.0) -> void:
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(id, db)


func _physics_process(delta: float) -> void:
	if _player.mode == Player.Mode.DEAD:
		return
	var was_busy := state != State.IDLE
	match state:
		State.IDLE:
			if _player.input_enabled:
				_update_candidate()
				if Input.is_action_just_pressed(&"fetch"):
					_try_fetch()
			else:
				_set_candidate(null)
		State.OUT:
			_do_out(delta)
		State.GRAB:
			_t += delta
			_aim_rig(_target_pos() - _rig.global_position)
			if _t >= grab_time:
				_after_grab()
		State.BACK:
			_do_back(delta)
		State.PULL:
			_do_pull(delta)
		State.CANCEL:
			_do_cancel(delta)
	if was_busy and state != State.IDLE and _player.input_enabled and Input.is_action_just_pressed(&"fetch") and state != State.CANCEL:
		_begin_cancel()
	_update_tether()


# ---------------------------------------------------------------- target choice

func _update_candidate() -> void:
	var cam := _player.camera_rig()
	var from := cam.aim_origin()
	var dir := cam.aim_direction()
	var origin := shoulder_pos()
	var best: Node = null
	var best_dot := cos(deg_to_rad(cone_deg))
	for n in get_tree().get_nodes_in_group(&"fetchable"):
		if not (n is Node3D) or not n.has_method(&"is_fetchable") or not n.is_fetchable(_player):
			continue
		var tp: Vector3 = n.fetch_point()
		var d := origin.distance_to(tp)
		if d > reach:
			continue
		var to := (tp - from).normalized()
		var dot := dir.dot(to)
		if dot < best_dot:
			continue
		if not _line_clear(origin, tp, n):
			continue
		best_dot = dot
		best = n
	_set_candidate(best)


func _line_clear(a: Vector3, b: Vector3, target: Node) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return true
	# The target's own body (a crate) does not block the line to itself.
	var c: Object = hit.get("collider")
	return c == target or (c is Node and target.is_ancestor_of(c))


func _set_candidate(n: Node) -> void:
	if n == _candidate:
		return
	if _candidate and is_instance_valid(_candidate) and _candidate.has_method(&"set_highlight"):
		_candidate.set_highlight(false)
	_candidate = n
	var hud := _hud()
	if n:
		if n.has_method(&"set_highlight"):
			n.set_highlight(true)
		var heavy: bool = n.fetch_kind() == &"heavy"
		if hud:
			hud.set_prompt(&"fetch", "F", "Pull the crate" if heavy else "Fetch")
		get_tree().call_group(&"dialogue_panel", "say", &"cargo_hint" if heavy else &"fetch_hint")
	elif hud:
		hud.clear_prompt(&"fetch")


func _try_fetch() -> void:
	if _candidate == null:
		rejected.emit()
		_sfx(&"invalid", -4.0)
		var hud := _hud()
		if hud:
			hud.toast("Nothing in reach", Color("#ffb347"))
		return
	_target = _candidate
	var hud2 := _hud()
	if hud2:
		hud2.clear_prompt(&"fetch")
	if _target.has_method(&"set_highlight"):
		_target.set_highlight(false)
	_candidate = null
	state = State.OUT
	_rig.global_position = shoulder_pos()
	_rig.visible = true
	_tether.visible = true
	_hide_attached(true)
	_sfx(&"fetch_launch", -3.0)
	fetch_started.emit(_target)


func _target_pos() -> Vector3:
	if _target and is_instance_valid(_target):
		return _target.fetch_point()
	return _rig.global_position


# ---------------------------------------------------------------- flight

func _do_out(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_begin_cancel()
		return
	var tp := _target_pos()
	var pos := _rig.global_position
	var step := out_speed * delta
	var dir := tp - pos
	if dir.length() <= step + 0.2:
		_rig.global_position = tp
		state = State.GRAB
		_t = 0.0
		return
	_rig.global_position = pos + dir.normalized() * step
	_aim_rig(dir)


func _aim_rig(dir: Vector3) -> void:
	# The hand's fingers point along the rig's +Z, so look the opposite way.
	if dir.length() < 0.01:
		return
	var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.RIGHT
	_rig.global_basis = Basis.looking_at(-dir.normalized(), up)


func _after_grab() -> void:
	if _target == null or not is_instance_valid(_target):
		_begin_cancel()
		return
	if _target.fetch_kind() == &"heavy":
		if _target.has_method(&"begin_pull") and _target.begin_pull(_player):
			state = State.PULL
			return
		_begin_cancel()
		return
	state = State.BACK
	_carrying = true


func _do_back(delta: float) -> void:
	var home := hand_pos()
	var pos := _rig.global_position
	var step := back_speed * delta
	var to_home := home - pos
	if _target and is_instance_valid(_target) and _target.has_method(&"hold_at"):
		_target.hold_at(pos + _rig.global_basis.z * 0.3)
	_aim_rig(-to_home)
	if to_home.length() <= step + 0.15:
		_finish_light()
		return
	_rig.global_position = pos + to_home.normalized() * step


func _finish_light() -> void:
	var t := _target
	_target = null
	_carrying = false
	_end_visual()
	if t and is_instance_valid(t):
		if t.has_method(&"collect"):
			t.collect(_player)
		fetch_completed.emit(t)
	state = State.IDLE
	_sfx(&"fetch_return", -4.0)


func _do_pull(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_begin_cancel()
		return
	var status: int = _target.pull_step(delta, pull_speed, _player)
	_rig.global_position = _target.fetch_point()
	_aim_rig(_target.fetch_point() - shoulder_pos())
	if status == 1:
		var t := _target
		_target = null
		_end_visual()
		state = State.IDLE
		fetch_completed.emit(t)
	elif status == 2:
		_begin_cancel()


func _begin_cancel() -> void:
	if _target and is_instance_valid(_target):
		if _target.has_method(&"end_pull"):
			_target.end_pull()
		if _target.has_method(&"release_fetch"):
			_target.release_fetch()
	_target = null
	_carrying = false
	state = State.CANCEL
	fetch_cancelled.emit()


func _do_cancel(delta: float) -> void:
	var home := hand_pos()
	var pos := _rig.global_position
	var step := back_speed * 1.6 * delta
	var to_home := home - pos
	_aim_rig(-to_home)
	if to_home.length() <= step + 0.15:
		_end_visual()
		state = State.IDLE
		return
	_rig.global_position = pos + to_home.normalized() * step


## Immediate safe stop (pause, dialogue, console entry, respawn).
func cancel_now() -> void:
	if state == State.IDLE:
		return
	if _target and is_instance_valid(_target):
		if _target.has_method(&"end_pull"):
			_target.end_pull()
		if _target.has_method(&"release_fetch"):
			_target.release_fetch()
	_target = null
	_carrying = false
	_end_visual()
	state = State.IDLE


func _end_visual() -> void:
	_rig.visible = false
	_tether.visible = false
	_hide_attached(false)


func _hide_attached(hidden: bool) -> void:
	if _hide_hand:
		_hide_hand.visible = not hidden
	if _hide_arm:
		_hide_arm.visible = not hidden


func _update_tether() -> void:
	if not _tether.visible:
		return
	var a := shoulder_pos()
	var b := _rig.global_position
	var d := b - a
	var dist := d.length()
	if dist < 0.05:
		return
	var up := d / dist
	var ref := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.95 else Vector3.FORWARD
	var x := ref.cross(up).normalized()
	var z := x.cross(up).normalized()
	_tether.global_transform = Transform3D(Basis(x, up * dist, z), a + d * 0.5)
