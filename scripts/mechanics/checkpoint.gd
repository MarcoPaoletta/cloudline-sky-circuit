class_name Checkpoint
extends Area3D
## Low cyan/white beacon with a diamond marker (distinct from the tall golden flag beam). Activates once when
## the player stands on it grounded. Enemies keep 3 m away (group `safe_zone`).

signal activated(cp: Checkpoint)

@export var checkpoint_id: StringName = &"cp_1"
@export var mat_off: Material
@export var mat_on: Material
@export var toast_text: String = "Checkpoint"

@onready var _spawn: Marker3D = $SpawnPoint
@onready var _diamond: MeshInstance3D = $Diamond
@onready var _ring: MeshInstance3D = $Ring

var is_active: bool = false
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"checkpoint")
	add_to_group(&"safe_zone")
	body_entered.connect(_on_body_entered)
	_apply_state()


func get_respawn_transform() -> Transform3D:
	return _spawn.global_transform


func _process(delta: float) -> void:
	_t += delta
	_diamond.rotation.y += delta * (2.4 if is_active else 0.9)
	_diamond.position.y = 1.1 + sin(_t * 2.0) * 0.08


func _physics_process(_delta: float) -> void:
	if is_active:
		return
	for b in get_overlapping_bodies():
		if b is Player and (b as Player).is_on_floor():
			_activate()
			return


func _on_body_entered(_body: Node3D) -> void:
	pass


func _activate() -> void:
	if is_active:
		return
	is_active = true
	_apply_state()
	activated.emit(self)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"checkpoint", -3.0)
	var hud := get_tree().get_first_node_in_group(&"hud")
	if hud:
		hud.toast(toast_text, Color("#7fe6ff"))
	get_tree().call_group(&"dialogue_panel", "say", &"checkpoint")
	var tw := create_tween()
	_diamond.scale = Vector3.ONE * 1.5
	tw.tween_property(_diamond, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_state() -> void:
	var m := mat_on if is_active else mat_off
	if m:
		_diamond.material_override = m
		_ring.material_override = m
