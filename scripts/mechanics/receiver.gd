class_name Receiver
extends Node3D
## Head socket (GDD 5 and 20.2). The physical bowling head is CAUGHT here and parked until recalled.
## While seated it powers every device on the same `channel` (PowerBridge, PowerGate, lifts...).
## Distinct from jump pads and console pads: a stone pedestal with a cup and a cyan ring.

signal powered_changed(on: bool)

@export var channel: StringName = &"relay_a"
@export var mat_idle: Material
@export var mat_highlight: Material
@export var mat_powered: Material

@onready var _catch: Area3D = $CatchArea
@onready var _socket: Marker3D = $Socket
@onready var _ring: MeshInstance3D = $Base/Ring
@onready var _beam: MeshInstance3D = $Beam

var powered: bool = false
var _highlight: bool = false
var _pulse_tween: Tween


func _ready() -> void:
	add_to_group(&"receiver")
	add_to_group(&"resettable")
	_catch.body_entered.connect(_on_body_entered)
	_refresh()


func is_available() -> bool:
	return not powered


func get_catch_point() -> Vector3:
	return _socket.global_position


func get_socket_transform() -> Transform3D:
	return _socket.global_transform


func set_highlight(on: bool) -> void:
	if _highlight == on:
		return
	_highlight = on
	_refresh()


## Visible rejection feedback (a combat press while the head sits here).
func pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_ring.scale = Vector3(1.18, 1.0, 1.18)
	_pulse_tween.tween_property(_ring, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_body_entered(body: Node3D) -> void:
	if powered or not (body is DetachedHead):
		return
	var head := body as DetachedHead
	if not head.is_rolling():
		return
	head.seat_at(_socket.global_transform, self)
	_set_powered(true)


func unseat() -> void:
	_set_powered(false)


func reset_to_checkpoint() -> void:
	_set_powered(false)


func _set_powered(on: bool) -> void:
	if powered == on:
		return
	powered = on
	get_tree().call_group("power_" + String(channel), "set_powered", on)
	powered_changed.emit(on)
	_refresh()
	pulse()


func _refresh() -> void:
	if powered:
		_ring.material_override = mat_powered
	elif _highlight:
		_ring.material_override = mat_highlight
	else:
		_ring.material_override = mat_idle
	_beam.visible = powered or _highlight
	_beam.material_override = mat_powered if powered else mat_highlight
