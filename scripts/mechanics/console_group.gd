class_name ConsoleGroup
extends AnimatableBody3D
## Base of an authored route group that ONE ground console controls on ONE axis (GDD 8): an Orbit group has
## four 90 degree states, a Slide group has three positions. Left/Right selects the adjacent state; one press
## queues at most one movement; presses during travel give a busy pulse; endpoints reject with a tick. The state
## commits when travel settles. No move happens if a player, crate, deployed head or enemy occupies the group's
## platform or swept volume (never crushes or teleports occupants).

signal state_changed(state: int)
signal moved(state: int)
signal rejected(reason: StringName)
signal travel_started(direction: int)

@export var travel_time: float = 0.8
@export var start_state: int = 0
@export var mat_idle: Material
@export var mat_blocked: Material

@onready var _marker: MeshInstance3D = get_node_or_null("StateMarker") as MeshInstance3D

var state: int = 0
var busy: bool = false
var _tween: Tween
var _blocked_node: Node


func _ready() -> void:
	sync_to_physics = true
	state = start_state
	add_to_group(&"console_group")
	add_to_group(&"resettable")
	_apply_state_immediately(state)


func state_count() -> int:
	return 3


func is_busy() -> bool:
	return busy


func get_state() -> int:
	return state


func get_blocking_node() -> Node:
	return _blocked_node


## direction: -1 (Left) or +1 (Right). Returns true when a movement started.
func step(direction: int) -> bool:
	if busy:
		rejected.emit(&"busy")
		return false
	var target := state + direction
	if target < 0 or target >= state_count():
		if wraps():
			target = posmod(target, state_count())
		else:
			rejected.emit(&"endpoint")
			return false
	var blocker := find_occupant(state, target)
	if blocker != null:
		_blocked_node = blocker
		rejected.emit(&"occupied")
		return false
	_blocked_node = null
	busy = true
	travel_started.emit(direction)
	_travel(state, target)
	return true


func reset_to_default() -> void:
	if busy or state == start_state:
		return
	if find_occupant(state, start_state) != null:
		rejected.emit(&"occupied")
		return
	busy = true
	_travel(state, start_state)


func reset_to_checkpoint() -> void:
	pass


func wraps() -> bool:
	return false


func _travel(from_state: int, to_state: int) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_travel, 0.0, 1.0, travel_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void: _settle(to_state))
	_begin_travel(from_state, to_state)


func _settle(to_state: int) -> void:
	state = to_state
	_apply_state_immediately(to_state)
	busy = false
	state_changed.emit(state)
	moved.emit(state)


## Virtual: remember endpoints for the interpolation.
func _begin_travel(_from_state: int, _to_state: int) -> void:
	pass


## Virtual: apply interpolation t (0..1) between the remembered endpoints.
func _set_travel(_t: float) -> void:
	pass


## Virtual: snap to a state's pose.
func _apply_state_immediately(_s: int) -> void:
	pass


## Virtual: returns the first occupant (player, crate, head, enemy) in the swept volume, or null.
func find_occupant(_from_state: int, _to_state: int) -> Node:
	return null


## Shared occupancy query: a box at `xf` with half-size `half` against the player, cargo and head layers.
## Enemies do not block a move (v2: worlds carry hundreds of them, and a wandering crab must never lock a
## puzzle); a swinging part simply shoves them aside.
func query_box(xf: Transform3D, half: Vector3) -> Node:
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	var p := PhysicsShapeQueryParameters3D.new()
	p.shape = shape
	p.transform = xf
	p.collision_mask = 2 | 16 | 128
	p.collide_with_bodies = true
	p.collide_with_areas = false
	p.exclude = [get_rid()]
	var hits := get_world_3d().direct_space_state.intersect_shape(p, 4)
	for h in hits:
		var c := h["collider"] as Node
		if c == null:
			continue
		if c is DetachedHead and not (c as DetachedHead).is_rolling() and not (c as DetachedHead).is_seated():
			continue
		return c
	return null
