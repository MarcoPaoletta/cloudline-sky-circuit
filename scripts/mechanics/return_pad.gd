class_name ReturnPad
extends Area3D
## "Return lift" (GDD 9): a cyan lift pad that, once its checkpoint has been reached, carries the robot back to an
## earlier hub through the level's fade (a late shortcut that turns the world into a loop). Locked and dim until the
## named checkpoint is active; stepping on it and settling grounded for a moment rides it.

signal used

@export var unlock_checkpoint: StringName = &"approach"
@export_node_path("Node3D") var target_path: NodePath
@export var settle_time: float = 0.6
@export var mat_locked: Material
@export var mat_ready: Material

@onready var _ring: MeshInstance3D = $Ring
@onready var _beam: MeshInstance3D = $Beam

var unlocked: bool = false
var _timer: float = 0.0
var _busy: bool = false
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"safe_zone")
	add_to_group(&"return_pad")
	_refresh()
	# The director joins the "level" group in its own _ready, which runs after this one.
	_connect_level.call_deferred()


func _connect_level() -> void:
	var level := get_tree().get_first_node_in_group(&"level")
	if level == null or not level.has_signal(&"checkpoint_reached"):
		return
	level.checkpoint_reached.connect(_on_checkpoint)
	if level.get_checkpoint_id() == unlock_checkpoint:
		unlocked = true
		_refresh()


func _on_checkpoint(id: StringName) -> void:
	if id == unlock_checkpoint and not unlocked:
		unlocked = true
		_refresh()
		get_tree().call_group(&"dialogue_panel", "say", &"return_lift")
		var a := get_node_or_null("/root/Audio")
		if a:
			a.play_sfx(&"checkpoint", -4.0, 1.2)


func _refresh() -> void:
	_ring.material_override = mat_ready if unlocked else mat_locked
	_beam.visible = unlocked


func _process(delta: float) -> void:
	_t += delta
	if unlocked:
		_ring.rotation.y += delta * 0.8
		_beam.scale.x = 1.0 + sin(_t * 2.0) * 0.06
		_beam.scale.z = _beam.scale.x


func _physics_process(delta: float) -> void:
	if _busy or not unlocked:
		return
	var inside := false
	for b in get_overlapping_bodies():
		if b is Player and (b as Player).is_on_floor() and (b as Player).is_alive() and (b as Player).mode == Player.Mode.EXPLORE:
			inside = true
	_timer = _timer + delta if inside else 0.0
	if _timer >= settle_time:
		_ride()


func _ride() -> void:
	var target := get_node_or_null(target_path) as Node3D
	var level := get_tree().get_first_node_in_group(&"level")
	if target == null or level == null or not level.has_method(&"travel_to"):
		return
	_busy = true
	_timer = 0.0
	used.emit()
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"console_enter", -2.0)
	await level.travel_to(target.global_transform)
	_busy = false
