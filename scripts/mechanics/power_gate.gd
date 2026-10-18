class_name PowerGate
extends AnimatableBody3D
## A door that rises while its channel is powered (relay head, balance island latch...). The leaf is the
## Door mesh of Door.gltf; collision is removed once it is mostly open, and it never closes on someone standing
## in the doorway.

signal opened_changed(is_open: bool)
signal latched_changed

@export var channel: StringName = &"gate_a"
@export var rise: float = 3.5
@export var move_time: float = 0.9

@onready var _blocker: CollisionShape3D = $Blocker
@onready var _sensor: Area3D = $Doorway
@onready var _leaf: Node3D = $Visual.find_child("Door", true, false) as Node3D

var powered: bool = false
var is_open: bool = false
var progress: float = 0.0
## Optional: a `LatchArea` child (Area3D) beyond the door holds it open once the player has passed, so the
## head can be recalled for a fight without trapping anyone (GDD 5: safe latch before recall).
var latched: bool = false
var _leaf_rest: Vector3
var _tween: Tween


func _ready() -> void:
	sync_to_physics = true
	add_to_group("power_" + String(channel))
	if _leaf:
		_leaf_rest = _leaf.position
	var latch := get_node_or_null("LatchArea") as Area3D
	if latch != null:
		latch.body_entered.connect(_on_latch_entered)
		# Only relay doors reset with the head; a balance island's exit gate follows its latched island.
		add_to_group(&"resettable")


func set_powered(on: bool) -> void:
	powered = on
	if on and not is_open:
		is_open = true
		_go(1.0, Tween.TRANS_BACK)
		opened_changed.emit(true)
		var a := get_node_or_null("/root/Audio")
		if a:
			a.play_sfx(&"bridge_rise", -4.0)
	elif not on and is_open and not latched:
		_try_close()


func _on_latch_entered(body: Node3D) -> void:
	if latched or not is_open or not (body is Player):
		return
	latched = true
	latched_changed.emit()
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"latch", -2.0)


## A latched door is a safe shortcut and stays open; an unlatched one follows the (reset) head.
func reset_to_checkpoint() -> void:
	if not latched:
		powered = false
		if is_open:
			_try_close()


func _try_close() -> void:
	while _sensor.has_overlapping_bodies() and is_inside_tree():
		await get_tree().create_timer(0.3).timeout
		if powered or latched:
			return
	if not powered and not latched:
		is_open = false
		_go(0.0, Tween.TRANS_SINE)
		opened_changed.emit(false)


func _go(target: float, trans: int) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_progress, progress, target, move_time).set_trans(trans).set_ease(Tween.EASE_OUT)


func _set_progress(p: float) -> void:
	progress = p
	if _leaf:
		_leaf.position = _leaf_rest + Vector3.UP * rise * clampf(p, 0.0, 1.05)
	_blocker.set_deferred("disabled", p > 0.45)
