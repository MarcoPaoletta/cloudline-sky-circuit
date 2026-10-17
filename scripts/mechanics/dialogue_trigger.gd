class_name DialogueTrigger
extends Area3D
## Semantic trigger volume: when the player enters (and the guard allows), asks the dialogue panel for one line.
## Never fires during a required jump or enemy wind-up, and a finished once-line never replays.

@export var dialogue_id: StringName = &"welcome"
@export var require_grounded: bool = true
## Delay after entering before the line is requested (lets the player settle).
@export var delay: float = 0.6

var _inside: float = 0.0
var _fired: bool = false


func _physics_process(delta: float) -> void:
	if _fired:
		return
	var p: Player = null
	for b in get_overlapping_bodies():
		if b is Player:
			p = b as Player
	if p == null:
		_inside = 0.0
		return
	if require_grounded and not p.is_on_floor():
		return
	_inside += delta
	if _inside >= delay:
		_fired = true
		get_tree().call_group(&"dialogue_panel", "say", dialogue_id)
