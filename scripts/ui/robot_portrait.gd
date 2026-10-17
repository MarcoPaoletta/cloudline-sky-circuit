extends SubViewportContainer
## Live 3D portrait of the robot's face for the dialogue panel (renders in its own world).

@export var clip: String = "RobotArmature|Robot_Idle"

@onready var _anim: AnimationPlayer = $Viewport/Robot/AnimationPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := _anim.get_animation(clip)
	if a:
		a.loop_mode = Animation.LOOP_LINEAR
		_anim.play(clip)
