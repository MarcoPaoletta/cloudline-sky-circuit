class_name JumpPad
extends Area3D
## Spring pad: a fresh grounded contact launches at 14 m/s (about 4.9 m rise). Air steering stays available.
## Distinct from receivers (stone socket) and console pads (lever + arrows): spring silhouette, UP arrow, cyan rim.

@export var launch_speed: float = 14.0
@export var cooldown: float = 0.5

@onready var _anim: AnimationPlayer = $Visual/Bouncer.find_child("AnimationPlayer", true, false) as AnimationPlayer
@onready var _rim: MeshInstance3D = $Rim

var _cool: float = 0.0
var _squash: Tween


func _ready() -> void:
	if _anim and _anim.has_animation("Bouncer_Idle"):
		_anim.get_animation("Bouncer_Idle").loop_mode = Animation.LOOP_LINEAR
		_anim.play("Bouncer_Idle")


func _physics_process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if _cool > 0.0:
		return
	for b in get_overlapping_bodies():
		if b is Player:
			var p := b as Player
			# Fresh grounded contact only (not every overlap frame, never from below).
			if p.is_on_floor() and p.velocity.y <= 0.5 and p.global_position.y >= global_position.y - 0.1:
				_launch(p)
				return


func _launch(p: Player) -> void:
	_cool = cooldown
	p.velocity.y = launch_speed
	p.global_position.y += 0.05
	if _anim and _anim.has_animation("Bouncer_Bounce"):
		_anim.play("Bouncer_Bounce")
	if _squash and _squash.is_valid():
		_squash.kill()
	_rim.scale = Vector3(1.25, 1.0, 1.25)
	_squash = create_tween()
	_squash.tween_property(_rim, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"bounce_pad", -2.0)
	p.camera_rig().add_trauma(0.12)
