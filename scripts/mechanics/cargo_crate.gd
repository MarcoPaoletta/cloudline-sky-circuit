class_name CargoCrate
extends AnimatableBody3D
## Heavy cargo (GDD 6 and 7). Moves ONLY when the arm pulls it, and only while the robot stands on the matching
## anchor tile; it follows a straight authored lane at 2 m/s toward the receiving tray and docks there. Walking
## off the anchor stops the crate on the lane and returns the arm. Kinematic: never dragged through walls.

signal docked(crate: CargoCrate)

@export var anchor_path: NodePath
@export var tray_path: NodePath
@export var weight: float = 1.5

@onready var _ring: Node3D = get_node_or_null("HighlightRing") as Node3D

var is_docked: bool = false
var pulling: bool = false
var _start: Vector3
var _tray: Node
var _anchor: Node


func _ready() -> void:
	sync_to_physics = true
	add_to_group(&"fetchable")
	add_to_group(&"resettable")
	add_to_group(&"cargo")
	_start = global_position
	_tray = get_node_or_null(tray_path)
	_anchor = get_node_or_null(anchor_path)
	if _ring:
		_ring.visible = false


func fetch_kind() -> StringName:
	return &"heavy"


func is_fetchable(_player: Player) -> bool:
	return not is_docked and _anchor != null and _anchor.player_on


func fetch_point() -> Vector3:
	return global_position + Vector3.UP * 0.3


func set_highlight(on: bool) -> void:
	if _ring:
		_ring.visible = on and not is_docked


func begin_pull(_player: Player) -> bool:
	if is_docked or _tray == null or _anchor == null or not _anchor.player_on:
		return false
	pulling = true
	return true


func end_pull() -> void:
	pulling = false


func release_fetch() -> void:
	pulling = false


## 0 = still moving, 1 = docked, 2 = abort (player left the anchor).
func pull_step(delta: float, speed: float, _player: Player) -> int:
	if not pulling:
		return 2
	if _anchor == null or not _anchor.player_on:
		pulling = false
		return 2
	var dest: Vector3 = _tray.dock_point()
	global_position = global_position.move_toward(dest, speed * delta)
	if global_position.distance_to(dest) < 0.02:
		_dock()
		return 1
	return 0


func _dock() -> void:
	pulling = false
	is_docked = true
	if _ring:
		_ring.visible = false
	var slot: Node3D = _tray.dock_slot()
	if slot:
		reparent(slot, true)
		position = Vector3.ZERO
		rotation = Vector3.ZERO
	_tray.on_docked(self)
	docked.emit(self)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"crate_dock", -2.0)
	get_tree().call_group(&"dialogue_panel", "say", &"balance_hint")


func reset_to_checkpoint() -> void:
	if is_docked or pulling:
		pulling = false
		return
	global_position = _start
	reset_physics_interpolation()
