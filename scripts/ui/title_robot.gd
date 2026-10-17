class_name TitleRobot
extends Node3D
## The title screen's robot: loops Idle and waves now and then. Visual only; it is the same Robot.fbx wrapper
## the player uses, scaled to the approved 1.7 m.

@export var idle_clip: String = "RobotArmature|Robot_Idle"
@export var gesture_clips: PackedStringArray = ["RobotArmature|Robot_Wave", "RobotArmature|Robot_ThumbsUp", "RobotArmature|Robot_Yes"]
@export var gesture_every: Vector2 = Vector2(5.0, 9.0)

@onready var _anim: AnimationPlayer = $Robot/AnimationPlayer

var _timer: float = 3.0
var _gesture_idx: int = 0


func _ready() -> void:
	for clip in [idle_clip] + Array(gesture_clips):
		var a := _anim.get_animation(clip)
		if a:
			a.loop_mode = Animation.LOOP_NONE
	var idle := _anim.get_animation(idle_clip)
	if idle:
		idle.loop_mode = Animation.LOOP_LINEAR
	_anim.play(idle_clip)
	_anim.animation_finished.connect(_on_finished)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0 and _anim.current_animation == idle_clip:
		var clip := gesture_clips[_gesture_idx % gesture_clips.size()]
		_gesture_idx += 1
		_anim.play(clip, 0.25)
		_timer = randf_range(gesture_every.x, gesture_every.y)


func _on_finished(anim_name: StringName) -> void:
	if String(anim_name) != idle_clip:
		_anim.play(idle_clip, 0.3)
