class_name Pickup
extends Area3D
## Coin or blue gem. Collected exactly once per run even if the body touches it during a fetch (GDD 6): the
## collected id is checked before banking. The arm can also fetch it (group `fetchable`, light kind).

signal collected(pickup: Pickup)

enum Kind { COIN, GEM }

@export var kind: Kind = Kind.COIN
@export var pickup_id: String = "c00"
@export var value: int = 1
@export var spin_speed: float = 2.4
@export var bob_height: float = 0.12

@onready var _visual: Node3D = $Visual
@onready var _ring: Node3D = get_node_or_null("HighlightRing") as Node3D

var is_collected: bool = false
var being_fetched: bool = false
var _t: float = 0.0
var _base_y: float = 0.0
var _flying: bool = false


func _ready() -> void:
	add_to_group(&"fetchable")
	add_to_group(&"pickup")
	_base_y = _visual.position.y
	_t = randf() * TAU
	body_entered.connect(_on_body_entered)
	if _ring:
		_ring.visible = false


func _process(delta: float) -> void:
	if is_collected or _flying:
		return
	_t += delta
	_visual.rotation.y += spin_speed * delta
	_visual.position.y = _base_y + sin(_t * 2.2) * bob_height


func fetch_kind() -> StringName:
	return &"light"


func is_fetchable(_player: Player) -> bool:
	return not is_collected and not being_fetched


func fetch_point() -> Vector3:
	return global_position


func set_highlight(on: bool) -> void:
	if _ring:
		_ring.visible = on and not is_collected


## The arm moves the pickup while retrieving it.
func hold_at(pos: Vector3) -> void:
	being_fetched = true
	global_position = pos


func release_fetch() -> void:
	being_fetched = false


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		collect(body as Player)


## Banks the pickup. Safe to call from both touch and fetch: only the first call counts.
func collect(p: Player) -> bool:
	if is_collected:
		return false
	var lvl := get_tree().get_first_node_in_group(&"level") as LevelDirector
	var n := lvl.level_number if lvl else Campaign.current_level
	var ok := false
	if kind == Kind.COIN:
		ok = Campaign.add_coin(n, pickup_id, value)
	else:
		ok = Campaign.add_gem(n, pickup_id)
	if not ok:
		is_collected = true
		queue_free()
		return false
	is_collected = true
	set_deferred("monitoring", false)
	if _ring:
		_ring.visible = false
	collected.emit(self)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"coin" if kind == Kind.COIN else &"gem", -2.0, randf_range(0.95, 1.08))
	_fly_to_hud(p)
	return true


func _fly_to_hud(_p: Player) -> void:
	# Pop, then travel toward the HUD coin counter and shrink away.
	_flying = true
	var cam := get_viewport().get_camera_3d()
	var tw := create_tween()
	tw.tween_property(_visual, "scale", _visual.scale * 1.5, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if cam:
		var target := cam.project_position(Vector2(110, 60), 2.2)
		tw.tween_property(self, "global_position", target, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_visual, "scale", Vector3.ONE * 0.05, 0.42)
	tw.tween_callback(queue_free)
