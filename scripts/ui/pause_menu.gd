class_name PauseMenu
extends CanvasLayer
## Pause (GDD 12): Resume, Controls, Hint Log, Restart Checkpoint, Restart Level, Settings, Return to Title.
## Arena scenes use the same scene with `arena_mode` on: Retry Arena replaces the two restart buttons and the
## platform world is never touched. Escape opens it only when no modal interaction is active (never inside a
## console, a fade, a respawn or the results screen). M keeps working because Audio is always-processing.

signal opened
signal closed

@export var arena_mode: bool = false

@onready var _dim: ColorRect = %Dim
@onready var _main: Control = %MainPanel
@onready var _controls: Control = %ControlsPanel
@onready var _hints: Control = %HintPanel
@onready var _settings: SettingsPanel = %Settings
@onready var _resume: Button = %ResumeButton
@onready var _btn_controls: Button = %ControlsButton
@onready var _btn_hints: Button = %HintsButton
@onready var _btn_checkpoint: Button = %RestartCheckpointButton
@onready var _btn_level: Button = %RestartLevelButton
@onready var _btn_settings: Button = %SettingsButton
@onready var _btn_title: Button = %TitleButton
@onready var _controls_back: Button = %ControlsBackButton
@onready var _hints_back: Button = %HintsBackButton
@onready var _hint_text: Label = %HintText
@onready var _rows: Control = %ControlRows

var _is_open: bool = false
var _player: Player
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"pause_menu")
	visible = false
	_resume.pressed.connect(close)
	_btn_controls.pressed.connect(_show_controls)
	_btn_hints.pressed.connect(_show_hints)
	_btn_checkpoint.pressed.connect(_on_restart_checkpoint)
	_btn_level.pressed.connect(_on_restart_level)
	_btn_settings.pressed.connect(_show_settings)
	_btn_title.pressed.connect(_on_title)
	_controls_back.pressed.connect(_show_main)
	_hints_back.pressed.connect(_show_main)
	_settings.closed.connect(_on_settings_closed)
	if arena_mode:
		_btn_checkpoint.visible = false
		_btn_hints.visible = false
		_btn_level.text = "Retry arena"


func is_open() -> bool:
	return _is_open


func can_open() -> bool:
	if _is_open or _busy or ScreenTransition.is_transitioning():
		return false
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null and _player.mode != Player.Mode.EXPLORE:
		return false
	var level := get_tree().get_first_node_in_group(&"level")
	if level != null and (level.is_respawning() or level.is_captured()):
		return false
	var arena := get_tree().get_first_node_in_group(&"arena_director")
	if arena != null and arena.has_method(&"is_over") and arena.is_over():
		return false
	return true


func open() -> void:
	if _is_open:
		return
	_is_open = true
	_player = get_tree().get_first_node_in_group(&"player") as Player
	if _player != null:
		var arm := _player.get_node_or_null("FetchArm")
		if arm != null and arm.has_method(&"cancel_now"):
			arm.cancel_now()
		_player.camera_rig().set_capture(false)
	visible = true
	_show_main()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui(&"ui_select", -4.0, 0.9)
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	_settings.visible = false
	get_tree().paused = false
	if _player != null and is_instance_valid(_player):
		_player.camera_rig().set_capture(true)
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui(&"ui_select", -4.0, 1.1)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"pause") or event.is_echo():
		return
	if _is_open:
		if _main.visible:
			close()
		else:
			_show_main()
		get_viewport().set_input_as_handled()
	elif can_open():
		open()
		get_viewport().set_input_as_handled()


func _show_only(panel: Control) -> void:
	for p in [_main, _controls, _hints, _settings]:
		(p as Control).visible = p == panel
	_dim.visible = panel != _settings


func _show_main() -> void:
	_show_only(_main)
	_resume.grab_focus()


func _show_controls() -> void:
	_refresh_controls()
	_show_only(_controls)
	_controls_back.grab_focus()


func _show_hints() -> void:
	var lines: PackedStringArray = []
	for id in Campaign.seen_dialogue:
		var t := String(Campaign.seen_dialogue[id])
		if t != "":
			lines.append(t)
	_hint_text.text = "Guidance you have seen on this run collects here.\nNothing yet." if lines.is_empty() else "\n\n".join(lines)
	_show_only(_hints)
	_hints_back.grab_focus()


func _show_settings() -> void:
	_show_only(_settings)
	_settings.open()


func _on_settings_closed() -> void:
	if _is_open:
		_show_main()


func _refresh_controls() -> void:
	for row in _rows.get_children():
		var key := row.get_node_or_null("Key") as Label
		var nm := row.get_node_or_null("Name") as Label
		if key == null:
			continue
		var action := StringName(String(row.name).trim_prefix("Row_"))
		match action:
			&"move":
				key.text = " ".join([Campaign.key_text(&"move_forward"), Campaign.key_text(&"move_left"), Campaign.key_text(&"move_back"), Campaign.key_text(&"move_right")])
			&"look":
				key.text = "Mouse"
			&"pause":
				key.text = "Esc"
			&"console_exit":
				key.text = "%s / Esc" % Campaign.key_text(&"interact")
			&"console_step":
				key.text = "%s / %s" % [Campaign.key_text(&"console_left"), Campaign.key_text(&"console_right")]
			_:
				key.text = Campaign.key_text(action)
		if nm != null and Campaign.ACTION_LABELS.has(action):
			nm.text = Campaign.ACTION_LABELS[action]


func _current_scene_path() -> String:
	var scene := get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


func _on_restart_checkpoint() -> void:
	var level := get_tree().get_first_node_in_group(&"level")
	close()
	if level != null and level.has_method(&"respawn"):
		level.respawn()


func _on_restart_level() -> void:
	if _busy:
		return
	_busy = true
	var path := _current_scene_path()
	var sub := "Retry" if arena_mode else "Fresh run"
	var caption := ""
	if arena_mode:
		var arena := get_tree().get_first_node_in_group(&"arena_director")
		var n: int = arena.arena_number if arena != null else 1
		caption = "Arena %d" % n
		sub = Campaign.ARENA_NAMES.get(n, "")
		Campaign.arena_retry_pending = true
	else:
		caption = String(Campaign.LEVEL_NAMES.get(Campaign.current_level, ""))
	_is_open = false
	visible = false
	ScreenTransition.change_scene(path, caption, sub, 0.3)


func _on_title() -> void:
	if _busy:
		return
	_busy = true
	Campaign.save_game()
	_is_open = false
	visible = false
	ScreenTransition.change_scene(Campaign.TITLE_SCENE, "", "", 0.1, 0.25, 0.4)
