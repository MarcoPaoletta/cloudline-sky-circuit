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

@onready var _player: Player = %Player
@onready var _spawn: Marker3D = %Spawn

var _respawn_xform: Transform3D
var _checkpoint_id: StringName = &""
var _respawning: bool = false
var _captured: bool = false
var _first_fall_done: bool = false


func _ready() -> void:
	add_to_group(&"level")
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
	level_ready.emit()


func _process(delta: float) -> void:
	if not _captured:
		Campaign.run_time += delta


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
	await ScreenTransition.fade_out(recovery_fade_out)
	for node in get_tree().get_nodes_in_group(&"resettable"):
		if node.has_method(&"reset_to_checkpoint"):
			node.reset_to_checkpoint()
	_player.teleport_to(_respawn_xform)
	_player.revive()
	_player.set_mode(Player.Mode.EXPLORE)
	await ScreenTransition.fade_in(recovery_fade_in)
	_respawning = false
	_first_fall_done = true
	respawn_finished.emit()


## Called by the finish flag. Banks the result and moves to the arena through the transition owner.
func capture_flag() -> void:
	if _captured:
		return
	_captured = true
	_player.set_input_enabled(false)
	var first := Campaign.capture_flag(level_number, Campaign.run_time)
	flag_captured.emit(first)
	if arena_scene == "":
		return
	await get_tree().create_timer(capture_celebration, true, false, true).timeout
	var arena_n := level_number
	ScreenTransition.change_scene(arena_scene, "Arena %d" % arena_n, Campaign.ARENA_NAMES.get(arena_n, ""), 0.5, 0.30, 0.35)
