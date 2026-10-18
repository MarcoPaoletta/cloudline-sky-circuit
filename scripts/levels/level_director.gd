class_name LevelDirector
extends Node3D
## Coordinates ONE platform world: spawn, checkpoints, falls and the flag. It owns no gameplay nodes;
## every element (player, islands, mechanics, enemies, HUD) is an instance of its own saved scene.
##
## Recovery follows GDD 10: fall below the kill plane or reach zero health -> fade out 0.2 s, return the
## parts, reset volatile enemy/puzzle state, respawn at the last safe checkpoint with full health, fade in
## 0.3 s. Only ScreenTransition owns the fade, so repeated requests cannot stack two fades.

signal level_ready
signal checkpoint_reached(id: StringName)
signal flag_captured(first_time: bool)
signal respawn_started
signal respawn_finished

@export_group("Level")
@export var level_number: int = 1
@export var level_title: String = "Sunrise Junction"
## Scene that follows the flag (the circular arena for this world).
@export_file("*.tscn") var arena_scene: String = ""
@export var kill_plane_y: float = -45.0
@export_group("Recovery")
@export var recovery_fade_out: float = 0.2
@export var recovery_fade_in: float = 0.3
@export_group("Flag")
@export var capture_celebration: float = 1.2
@export_group("Guidance")
## Seconds on safe ground with no route progress before the robot points at the beam again.
@export var lost_hint_after: float = 20.0
@export var lost_hint_cooldown: float = 45.0
## Getting this much closer to the flag counts as progress.
@export var progress_distance: float = 4.0
@export_group("Enemy crowd")
## Enemies farther than this from the robot sleep (no AI, no animation) and wake as it comes near. Worlds carry
## hundreds of enemies (5 to 20 per island), so only the nearby ones think.
@export var enemy_wake_radius: float = 32.0
## Enemies examined per frame (round robin), so a big crowd costs a few distance checks a frame.
@export var enemy_checks_per_frame: int = 90

@onready var _player: Player = %Player
@onready var _spawn: Marker3D = %Spawn

var _respawn_xform: Transform3D
var _checkpoint_id: StringName = &""
var _respawning: bool = false
var _captured: bool = false
var _first_fall_done: bool = false
var _since_progress: float = 0.0
var _best_goal_dist: float = INF
var _lost_cooldown: float = 0.0
var _seen_windup: Dictionary = {}
var _crowd: Array[EnemyBase] = []
var _crowd_i: int = 0


func _ready() -> void:
	add_to_group(&"level")
	LightingPreset.apply_to(self)
	var music := get_node_or_null("/root/Audio")
	if music:
		music.play_music(&"platform")
	Campaign.begin_run(level_number)
	_player.kill_plane_y = kill_plane_y
	_respawn_xform = _spawn.global_transform
	_player.fell.connect(_on_player_fell)
	_player.died.connect(_on_player_died)
	for cp in get_tree().get_nodes_in_group(&"checkpoint"):
		if cp.has_signal(&"activated"):
			cp.activated.connect(_on_checkpoint_activated)
	_player.teleport_to(_spawn.global_transform)
	_player.camera_rig().set_capture(true)
	for e in get_tree().get_nodes_in_group(&"enemy"):
		if e.has_signal(&"windup_started"):
			e.windup_started.connect(_on_enemy_windup)
		if e is EnemyBase:
			_crowd.append(e as EnemyBase)
	if OS.has_feature("mobile"):
		enemy_wake_radius *= 0.75
	_update_crowd(_crowd.size())
	Campaign.coins_changed.connect(func(_t: int) -> void: _since_progress = 0.0)
	Campaign.progress_changed.connect(func() -> void: _since_progress = 0.0)
	level_ready.emit()
	var intro := StringName("level%d_intro" % level_number)
	if DialogueData.has_line(intro):
		_say(intro)


func _process(delta: float) -> void:
	_update_crowd(enemy_checks_per_frame)
	if _captured:
		return
	Campaign.run_time += delta
	if _respawning:
		return
	_lost_cooldown = maxf(_lost_cooldown - delta, 0.0)
	var goal := get_tree().get_first_node_in_group(&"goal_target") as Node3D
	if goal != null:
		var d := Vector2(_player.global_position.x - goal.global_position.x, _player.global_position.z - goal.global_position.z).length()
		d += absf(_player.global_position.y - goal.global_position.y) * 0.5
		if d < _best_goal_dist - progress_distance:
			_best_goal_dist = d
			_since_progress = 0.0
	_since_progress += delta
	if _since_progress >= lost_hint_after and _lost_cooldown <= 0.0 and _player.mode == Player.Mode.EXPLORE and _player.is_on_floor():
		var hud := get_tree().get_first_node_in_group(&"hud")
		if hud != null and not hud.dialogue().is_open():
			_say(&"lost_hint")
			_lost_cooldown = lost_hint_cooldown
			_since_progress = 0.0


func _say(id: StringName) -> void:
	get_tree().call_group(&"dialogue_panel", "say", id)


## First wind-up of each enemy kind teaches the matching line (never repeated in a run).
## Wakes the enemies near the robot and puts far ones to sleep, `count` enemies per call (round robin).
func _update_crowd(count: int) -> void:
	var n := _crowd.size()
	if n == 0:
		return
	var pp := _player.global_position
	var r2 := enemy_wake_radius * enemy_wake_radius
	for k in mini(count, n):
		var e := _crowd[_crowd_i]
		_crowd_i = (_crowd_i + 1) % n
		if is_instance_valid(e):
			e.set_dormant(e.global_position.distance_squared_to(pp) > r2)


func _on_enemy_windup(enemy: Node) -> void:
	var key: StringName = &"bee_hint" if enemy.is_in_group(&"bee") or enemy is BeeEnemy else &"combat_hint"
	if _seen_windup.has(key):
		return
	_seen_windup[key] = true
	_say(key)


func get_player() -> Player:
	return _player


func get_respawn_transform() -> Transform3D:
	return _respawn_xform


func get_checkpoint_id() -> StringName:
	return _checkpoint_id


func is_respawning() -> bool:
	return _respawning


func is_captured() -> bool:
	return _captured


func _on_checkpoint_activated(cp: Node) -> void:
	_respawn_xform = cp.get_respawn_transform()
	_checkpoint_id = cp.checkpoint_id
	Campaign.checkpoint_id = _checkpoint_id
	Campaign.save_game()
	checkpoint_reached.emit(_checkpoint_id)


func _on_player_fell() -> void:
	respawn()


func _on_player_died() -> void:
	respawn()


## Public: fade out, reset, respawn at the last checkpoint, fade in. Safe to call repeatedly.
func respawn() -> void:
	if _respawning or _captured:
		return
	_respawning = true
	respawn_started.emit()
	_player.set_input_enabled(false)
	_return_parts()
	await ScreenTransition.fade_out(recovery_fade_out)
	for node in get_tree().get_nodes_in_group(&"resettable"):
		if node.has_method(&"reset_to_checkpoint"):
			node.reset_to_checkpoint()
	_player.teleport_to(_respawn_xform)
	_player.revive()
	_player.set_mode(Player.Mode.EXPLORE)
	await ScreenTransition.fade_in(recovery_fade_in)
	_respawning = false
	_since_progress = 0.0
	if not _first_fall_done:
		_say(&"fall_return")
	_first_fall_done = true
	respawn_finished.emit()


## Head back on the body and the arm retracted (respawn, return lift, flag capture).
func _return_parts() -> void:
	var head := _player.get_node_or_null("HeadController")
	if head != null and head.has_method(&"reset_to_attached"):
		head.reset_to_attached()
	var arm := _player.get_node_or_null("FetchArm")
	if arm != null and arm.has_method(&"cancel_now"):
		arm.cancel_now()


## Fade-carried trip to another place in the same world (return lift): parts return, the unsafe puzzle state resets,
## health is kept. Only ScreenTransition fades, so this can never stack a second fade.
func travel_to(xf: Transform3D) -> void:
	if _respawning or _captured or _player.mode != Player.Mode.EXPLORE:
		return
	_respawning = true
	_player.set_input_enabled(false)
	_return_parts()
	await ScreenTransition.fade_out(0.25)
	_player.teleport_to(xf)
	_player.set_mode(Player.Mode.EXPLORE)
	_player.set_input_enabled(true)
	_player.camera_rig().snap_behind(_player.facing_yaw())
	await ScreenTransition.fade_in(0.35)
	_respawning = false
	_since_progress = 0.0
	# A hit that landed while the fade was running was ignored by respawn(); honour it now.
	if _player.mode == Player.Mode.DEAD:
		respawn()


## Called by the finish flag. Banks the result and moves to the arena through the transition owner.
func capture_flag() -> void:
	if _captured:
		return
	_captured = true
	_player.set_input_enabled(false)
	_player.set_mode(Player.Mode.LOCKED)
	_return_parts()
	_player.play_action("ThumbsUp", 1.0, capture_celebration)
	_say(&"final_capture" if level_number >= Campaign.LEVEL_COUNT else &"flag_capture")
	var first := Campaign.capture_flag(level_number, Campaign.run_time)
	flag_captured.emit(first)
	if arena_scene == "":
		return
	await get_tree().create_timer(capture_celebration, true, false, true).timeout
	var arena_n := level_number
	ScreenTransition.change_scene(arena_scene, "Arena %d" % arena_n, Campaign.ARENA_NAMES.get(arena_n, ""), 0.5, 0.30, 0.35)
