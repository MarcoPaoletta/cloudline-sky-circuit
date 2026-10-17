class_name MovingPlatform
extends AnimatableBody3D
## Horizontal shuttle or vertical lift (GDD 10): authored stops, simple kinematic motion in the physics step,
## pause at each stop (0.8 s). The player rides through platform velocity (no reparenting). Authored travel is
## the Inspector value `travel` (local offset from the authored position). Optional channel: only moves while
## powered (receivers/consoles); with no channel it runs continuously.

@export var travel: Vector3 = Vector3(0, 0, 10)
@export var speed: float = 2.0
@export var pause_time: float = 0.8
@export var start_delay: float = 0.0
## Empty = always running.
@export var channel: StringName = &""
@export var ping_pong: bool = true

var powered: bool = true
var _a: Vector3
var _b: Vector3
var _to_b: bool = true
var _pause: float = 0.0
var _delay: float = 0.0


func _ready() -> void:
	sync_to_physics = true
	_a = position
	_b = position + travel
	_delay = start_delay
	if channel != &"":
		powered = false
		add_to_group("power_" + String(channel))
	add_to_group(&"resettable")


func set_powered(on: bool) -> void:
	powered = on


func _physics_process(delta: float) -> void:
	if not powered:
		return
	if _delay > 0.0:
		_delay -= delta
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var target := _b if _to_b else _a
	position = position.move_toward(target, speed * delta)
	if position.is_equal_approx(target):
		_to_b = not _to_b
		_pause = pause_time


func reset_to_checkpoint() -> void:
	pass
