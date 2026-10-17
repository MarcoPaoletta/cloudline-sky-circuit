class_name GroundConsole
extends Area3D
## Ground pad that rearranges ONE route group (GDD 8). Stepping on it and settling for 0.35 s (low speed, grounded)
## enters console mode automatically; the existing PERSPECTIVE camera eases over 0.65 s to the saved
## `OverviewPose` (FOV 32, pitch about 50, yaw about 45). Left/Right select the adjacent authored state, E or
## Escape returns. Entry is suppressed until the robot leaves the pad, the exit needs a fresh press, and nothing
## can leave input locked: a respawn or mode change always unwinds the console.

signal entered
signal exited
signal stepped(direction: int, accepted: bool)

@export var group_path: NodePath
@export var settle_time: float = 0.35
@export var max_enter_speed: float = 2.0
@export var mat_idle: Material
@export var mat_active: Material
@export var mat_blocked: Material

@onready var _pose: Camera3D = $OverviewPose
@onready var _ring: MeshInstance3D = $Ring
@onready var _lever_anim: AnimationPlayer = $Visual/Lever.find_child("AnimationPlayer", true, false) as AnimationPlayer

var active: bool = false
var steps_taken: int = 0
var _armed: bool = true
var _timer: float = 0.0
var _enter_frame: int = -100
var _player: Player
var _group: ConsoleGroup


func _ready() -> void:
	add_to_group(&"console")
	add_to_group(&"safe_zone")
	_group = get_node_or_null(group_path) as ConsoleGroup
	if _group:
		_group.rejected.connect(_on_group_rejected)
	_set_ring(mat_idle)


func is_active() -> bool:
	return active


func get_group() -> ConsoleGroup:
	return _group


func _hud() -> Node:
	return get_tree().get_first_node_in_group(&"hud")


func _sfx(id: StringName, db: float = 0.0) -> void:
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(id, db)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
		if _player == null:
			return
	if active:
		# Unwind on respawn / death / forced mode change so input can never stay locked.
		if _player.mode != Player.Mode.CONSOLE:
			_unwind()
		return
	var on_pad := overlaps_body(_player)
	if not on_pad:
		_armed = true
		_timer = 0.0
		return
	if not _armed or not _player.is_alive() or _player.mode != Player.Mode.EXPLORE:
		return
	var speed := Vector2(_player.velocity.x, _player.velocity.z).length()
	if _player.is_on_floor() and speed <= max_enter_speed:
		_timer += delta
		_ring.scale = Vector3.ONE * (1.0 + 0.12 * (_timer / settle_time))
		if _timer >= settle_time:
			_enter()
	else:
		_timer = 0.0
		_ring.scale = Vector3.ONE


func _enter() -> void:
	if _group == null or _group.is_busy():
		return
	active = true
	_armed = false
	_timer = 0.0
	steps_taken = 0
	_enter_frame = Engine.get_physics_frames()
	_player.get_node("FetchArm").cancel_now()
	_player.velocity = Vector3.ZERO
	_player.set_mode(Player.Mode.CONSOLE)
	_player.camera_rig().begin_overview(_pose)
	_set_ring(mat_active)
	_ring.scale = Vector3.ONE * 1.25
	create_tween().tween_property(_ring, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _lever_anim and _lever_anim.has_animation("Lever_On"):
		_lever_anim.play("Lever_On")
	var hud := _hud()
	if hud:
		hud.show_console_strip(true)
	get_tree().call_group(&"dialogue_panel", "set_suppressed", true)
	_sfx(&"console_enter", -2.0)
	entered.emit()


func _exit() -> void:
	if not active:
		return
	_unwind()
	if steps_taken > 0:
		get_tree().call_group(&"dialogue_panel", "say", &"console_done")


func _unwind() -> void:
	active = false
	_timer = 0.0
	_player.camera_rig().end_overview()
	if _player.mode == Player.Mode.CONSOLE:
		_player.set_mode(Player.Mode.EXPLORE)
	_set_ring(mat_idle)
	if _lever_anim and _lever_anim.has_animation("Lever_Off"):
		_lever_anim.play("Lever_Off")
	var hud := _hud()
	if hud:
		hud.show_console_strip(false)
	get_tree().call_group(&"dialogue_panel", "set_suppressed", false)
	_sfx(&"console_exit", -4.0)
	exited.emit()


func _input(event: InputEvent) -> void:
	if not active or event.is_echo():
		return
	var hud := _hud()
	if event.is_action_pressed(&"console_exit"):
		# Fresh press only: holding E through entry never exits immediately; Escape is consumed before pause.
		if Engine.get_physics_frames() - _enter_frame > 14:
			get_viewport().set_input_as_handled()
			_exit()
		else:
			get_viewport().set_input_as_handled()
		return
	var dir := 0
	if event.is_action_pressed(&"console_left"):
		dir = -1
	elif event.is_action_pressed(&"console_right"):
		dir = 1
	elif event.is_action_pressed(&"reset_local"):
		get_viewport().set_input_as_handled()
		if _group:
			_group.reset_to_default()
		return
	if dir == 0:
		return
	get_viewport().set_input_as_handled()
	if _group == null:
		return
	var accepted := _group.step(dir)
	stepped.emit(dir, accepted)
	if accepted:
		steps_taken += 1
		_sfx(&"console_step", -2.0)
		if hud:
			hud.console_pulse_key(&"left" if dir < 0 else &"right")
	else:
		var reason := _last_reason()
		_reject_feedback(reason, dir)


var _reason: StringName = &""


func _last_reason() -> StringName:
	return _reason


func _on_group_rejected(r: StringName) -> void:
	_reason = r


func _reject_feedback(reason: StringName, dir: int) -> void:
	var hud := _hud()
	_sfx(&"console_blocked", -4.0)
	match reason:
		&"occupied":
			if hud:
				hud.console_message("Clear the platform first.")
		&"endpoint":
			if hud:
				hud.console_pulse_key(&"left" if dir < 0 else &"right", true)
		_:
			if hud:
				hud.console_pulse_key(&"busy", true)
	_set_ring(mat_blocked)
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if active:
			_set_ring(mat_active))


func _set_ring(m: Material) -> void:
	if m:
		_ring.material_override = m


func reset_to_checkpoint() -> void:
	pass
