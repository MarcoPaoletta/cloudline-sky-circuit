class_name PowerBridge
extends AnimatableBody3D
## A bridge that rises into place while its Receiver channel is powered (GDD 5 and 9).
## Safety: collision is never withdrawn beneath a player (it warns, then waits until the deck is clear), and a
## far-end LatchArea holds the bridge extended after the player crosses, so the head can be recalled safely.

signal extended_changed(extended: bool)
signal latched_changed

@export var channel: StringName = &"relay_a"
@export var sink_depth: float = 3.4
@export var move_time: float = 0.9
@export var warn_time: float = 1.2
@export var mat_off: Material
@export var mat_on: Material
@export var mat_warn: Material
@export var mat_latched: Material

@onready var _sensor: Area3D = $DeckSensor
@onready var _latch_area: Area3D = $LatchArea
@onready var _lamp: MeshInstance3D = $Lamp

var powered: bool = false
var latched: bool = false
var extended: bool = false
var progress: float = 0.0

var _rest: Vector3
var _tween: Tween
var _waiting: bool = false
## Collision shapes must be DIRECT children of the body to register with physics.
var _shapes: Array[CollisionShape3D] = []


func _ready() -> void:
	add_to_group("power_" + String(channel))
	add_to_group(&"resettable")
	sync_to_physics = true
	for c in get_children():
		if c is CollisionShape3D:
			_shapes.append(c as CollisionShape3D)
	_rest = position
	position = _rest + Vector3.DOWN * sink_depth
	_latch_area.body_entered.connect(_on_latch_entered)
	_apply_collision()
	_refresh_lamp(mat_off)


func is_extended() -> bool:
	return extended


func set_powered(on: bool) -> void:
	powered = on
	_evaluate()


func _evaluate() -> void:
	var want := powered or latched
	if want and not extended:
		_extend()
	elif not want and extended:
		_try_retract()


func _extend() -> void:
	extended = true
	_waiting = false
	_move_to(1.0, move_time, Tween.TRANS_BACK)
	_refresh_lamp(mat_latched if latched else mat_on)
	extended_changed.emit(true)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"bridge_rise", -2.0)


func _try_retract() -> void:
	if _sensor.has_overlapping_bodies():
		# Never pull the deck out from under someone: warn, then wait until it is clear.
		if not _waiting:
			_waiting = true
			_refresh_lamp(mat_warn)
			_wait_clear()
		return
	_retract()


func _wait_clear() -> void:
	await get_tree().create_timer(warn_time).timeout
	while _waiting and is_inside_tree():
		if powered or latched:
			_waiting = false
			_refresh_lamp(mat_latched if latched else mat_on)
			return
		if not _sensor.has_overlapping_bodies():
			_waiting = false
			_retract()
			return
		await get_tree().create_timer(0.2).timeout


func _retract() -> void:
	extended = false
	_move_to(0.0, move_time, Tween.TRANS_SINE)
	_refresh_lamp(mat_off)
	extended_changed.emit(false)


func _move_to(target: float, time: float, trans: int) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_progress, progress, target, time).set_trans(trans).set_ease(Tween.EASE_OUT if target > progress else Tween.EASE_IN_OUT)


func _set_progress(p: float) -> void:
	progress = p
	position = (_rest + Vector3.DOWN * sink_depth).lerp(_rest, clampf(p, 0.0, 1.05))
	_apply_collision()


func _apply_collision() -> void:
	var solid := progress > 0.9
	for s in _shapes:
		s.set_deferred("disabled", not solid)


func _on_latch_entered(body: Node3D) -> void:
	if latched or not extended or not (body is Player):
		return
	latched = true
	_refresh_lamp(mat_latched)
	latched_changed.emit()
	get_tree().call_group(&"dialogue_panel", "say", &"recall_hint")
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"latch", -2.0)


func reset_to_checkpoint() -> void:
	# A latched bridge is a safe shortcut and stays; an unlatched one follows the (reset) head.
	if not latched:
		powered = false
		_waiting = false
		if extended:
			_retract()


func _refresh_lamp(m: Material) -> void:
	if m:
		_lamp.material_override = m
