class_name CounterweightIsland
extends AnimatableBody3D
## Kinematic balancing island (GDD 7). It tilts about ONE authored axis (local X) driven by weighted torque:
## the robot counts 1 unit, a docked crate 1.5, measured along local Z from the pivot. The tilt is clamped to
## +-12 degrees with a damped response (about 0.7 s to settle). When the tilt sits within tolerance of the
## authored target and the player reaches the exit landing, a clamp latches the alignment so the way out never
## disappears behind them. The camera horizon is never touched.

signal tilt_changed(deg: float)
signal aligned_changed(aligned: bool)
signal latched_changed

@export var max_tilt_deg: float = 12.0
@export var player_weight: float = 1.0
## Degrees of tilt per (weight x metre along Z).
@export var gain_deg: float = 1.2
@export var target_tilt_deg: float = 10.0
@export var tolerance_deg: float = 1.5
@export var settle_time: float = 0.7
## Power channel opened when the alignment latches (the exit gate listens on it).
@export var channel: StringName = &"balance_a"
@export var mat_open: Material
@export var mat_aligned: Material
@export var mat_latched: Material

@onready var _ride: Area3D = $RideArea
@onready var _exit_latch: Area3D = $ExitLatch
@onready var _clamp_l: MeshInstance3D = $Clamp/ClampL
@onready var _clamp_r: MeshInstance3D = $Clamp/ClampR
@onready var _trays: Array[Node] = $Trays.get_children()

var tilt_deg: float = 0.0
var aligned: bool = false
var latched: bool = false
var _player: Player
var _hold: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	add_to_group(&"resettable")
	_refresh_clamp()


func torque_target_deg() -> float:
	var sum := 0.0
	if _player and _player_on():
		var lp := to_local(_player.global_position)
		sum += player_weight * lp.z
	for t in _trays:
		if t.has_method(&"is_occupied") and t.is_occupied():
			sum += t.weight() * to_local((t as Node3D).global_position).z
	return clampf(sum * gain_deg, -max_tilt_deg, max_tilt_deg)


func _player_on() -> bool:
	return _ride.overlaps_body(_player) and _player.is_on_floor()


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	var target := target_tilt_deg if latched else torque_target_deg()
	var k := 1.0 - exp(-delta * 4.6 / maxf(settle_time, 0.05))
	var prev := tilt_deg
	tilt_deg = lerpf(tilt_deg, target, k)
	rotation.x = deg_to_rad(tilt_deg)
	if absf(tilt_deg - prev) > 0.0005:
		tilt_changed.emit(tilt_deg)
	var now_aligned := absf(tilt_deg - target_tilt_deg) <= tolerance_deg
	if now_aligned:
		_hold += delta
	else:
		_hold = 0.0
	var stable := _hold >= 0.25 or latched
	if stable != aligned:
		aligned = stable
		_refresh_clamp()
		aligned_changed.emit(aligned)
	_try_latch()


func _try_latch() -> void:
	if latched or not aligned or _player == null:
		return
	# The robot must be in the exit zone while the alignment holds (checked each physics frame).
	if _exit_latch.overlaps_body(_player):
		latched = true
		_refresh_clamp()
		latched_changed.emit()
		get_tree().call_group("power_" + String(channel), "set_powered", true)
		get_tree().call_group(&"dialogue_panel", "say", &"balance_done")
		var a := get_node_or_null("/root/Audio")
		if a:
			a.play_sfx(&"latch", -1.0)


func _refresh_clamp() -> void:
	var m: Material = mat_latched if latched else (mat_aligned if aligned else mat_open)
	if m:
		_clamp_l.material_override = m
		_clamp_r.material_override = m
	var gap := 0.0 if latched else 0.35
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_clamp_l, "position:x", -0.5 - gap, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_clamp_r, "position:x", 0.5 + gap, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Local puzzle reset (pause menu / respawn): unlatches and levels the island, crates are reset by their own scripts.
func reset_puzzle() -> void:
	latched = false
	_hold = 0.0
	_refresh_clamp()


func reset_to_checkpoint() -> void:
	pass
