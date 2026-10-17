class_name FinishFlag
extends Area3D
## The level's one real flag (GDD 3, 12). Grounded contact inside the 2 m capture area for 0.4 s starts the
## capture: the golden beam fades, the robot celebrates, parts return, the result banks and the world fades
## into the arena. Tall emissive beam (not a spotlight); the diamond marker lives in the HUD GoalMarker.

signal captured

@export var hold_time: float = 0.4
@export var beam_height: float = 42.0

@onready var _beam: MeshInstance3D = $Beam
@onready var _ring: MeshInstance3D = $BaseRing

var done: bool = false
var _inside_t: float = 0.0
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"goal_target")
	add_to_group(&"safe_zone")


func _process(delta: float) -> void:
	_t += delta
	if not done:
		_beam.scale.x = 1.0 + sin(_t * 1.7) * 0.08
		_beam.scale.z = _beam.scale.x
		_ring.rotation.y += delta * 0.5


func _physics_process(delta: float) -> void:
	if done:
		return
	var inside := false
	for b in get_overlapping_bodies():
		if b is Player and (b as Player).is_on_floor() and (b as Player).is_alive():
			inside = true
	_inside_t = _inside_t + delta if inside else 0.0
	if _inside_t >= hold_time:
		_capture()


func _capture() -> void:
	done = true
	captured.emit()
	var tw := create_tween()
	tw.tween_property(_beam, "scale", Vector3(0.1, 1.0, 0.1), 1.0).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(_beam, "transparency", 1.0, 1.0)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"flag_capture", -1.0)
	var lvl := get_tree().get_first_node_in_group(&"level") as LevelDirector
	if lvl:
		lvl.capture_flag()
