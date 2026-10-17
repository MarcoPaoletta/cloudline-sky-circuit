class_name GoalMarker
extends Control
## Restrained golden diamond over the flag; when the target is behind the camera or off screen it becomes an
## edge arrow that still points at the real world position (never a wrong height). Distance only while the
## objective-help action is held.

@export var margin: float = 64.0
@export var hover_height: float = 1.4
@export var target_group: StringName = &"goal_target"

@onready var _icon: Control = %Icon
@onready var _diamond: CanvasItem = %Diamond
@onready var _arrow: CanvasItem = %Arrow
@onready var _distance: Label = %Distance

var _target: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_distance.modulate.a = 0.0


func set_target(node: Node3D) -> void:
	_target = node
	visible = node != null


func _process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(target_group) as Node3D
		if _target == null:
			visible = false
			return
		visible = true
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var world := _target.global_position + Vector3(0.0, hover_height, 0.0)
	var vp := get_viewport_rect().size
	var behind := cam.is_position_behind(world)
	var screen := cam.unproject_position(world)
	var inside := not behind and screen.x > margin and screen.x < vp.x - margin and screen.y > margin and screen.y < vp.y - margin
	var center := vp * 0.5
	if inside:
		_icon.position = screen
		_icon.rotation = 0.0
		_diamond.visible = true
		_arrow.visible = false
	else:
		var dir := screen - center
		if behind:
			dir = -dir
		if dir.length_squared() < 1.0:
			dir = Vector2.UP
		dir = dir.normalized()
		var scale_x := (vp.x * 0.5 - margin) / maxf(absf(dir.x), 0.0001)
		var scale_y := (vp.y * 0.5 - margin) / maxf(absf(dir.y), 0.0001)
		_icon.position = center + dir * minf(scale_x, scale_y)
		_icon.rotation = dir.angle()
		_diamond.visible = false
		_arrow.visible = true
	var show_dist := Input.is_action_pressed(&"objective_help")
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if show_dist and player:
		_distance.text = "%d m" % int(round(player.global_position.distance_to(_target.global_position)))
	_distance.modulate.a = lerpf(_distance.modulate.a, 1.0 if show_dist else 0.0, 1.0 - exp(-12.0 * delta))
	_distance.position = _icon.position + Vector2(-_distance.size.x * 0.5, 34.0)
