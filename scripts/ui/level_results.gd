class_name LevelResults
extends Control
## Results after an arena victory (GDD 20.1): shows the world's records, then continues to the next platform
## world, or to the campaign-complete screen after arena three. Replay starts a fresh run; the best record is
## kept separately in Campaign.

@onready var _title: Label = %Title
@onready var _stats: Label = %Stats
@onready var _continue: Button = %ContinueButton
@onready var _replay: Button = %ReplayButton
@onready var _title_btn: Button = %TitleButton
@onready var _panel: Control = %Panel

var _level: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.modulate.a = 0.0
	_continue.pressed.connect(_on_continue)
	_replay.pressed.connect(_on_replay)
	_title_btn.pressed.connect(_on_title)


func show_arena_results(d: ArenaDirector) -> void:
	_level = d.arena_number
	var last := _level >= Campaign.LEVEL_COUNT
	_title.text = "ALL THREE FLAGS" if last else "%s CLEARED" % String(Campaign.LEVEL_NAMES[_level]).to_upper()
	var lv: Dictionary = Campaign._level(_level)
	var t := float(lv["best_time"])
	var minutes := int(t) / 60
	var secs := int(t) % 60
	var arena_s := d.fight_time
	var lines: PackedStringArray = []
	lines.append("Flag reached in %d:%02d" % [minutes, secs])
	lines.append("Arena %d clear in %.0f s  ·  %d monsters  ·  best chain x%d" % [_level, arena_s, d.kills, d.best_chain])
	lines.append("Coins banked: %d     Gems: %d / %d" % [(lv["coins"] as Array).size(), (lv["gems"] as Array).size(), 3 + (1 if _level == 2 else 2 if _level == 3 else 0)])
	_stats.text = "\n".join(lines)
	_continue.text = "Finish" if last else "Next world"
	visible = true
	var tw := create_tween()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.35)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"results", -2.0)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue.grab_focus()


func _on_continue() -> void:
	if _level >= Campaign.LEVEL_COUNT:
		Campaign.title_view = &"complete"
		ScreenTransition.change_scene(Campaign.TITLE_SCENE, "CLOUDLINE", "The sky is reconnected", 0.4)
	else:
		var n := _level + 1
		ScreenTransition.change_scene(Campaign.LEVEL_SCENES[n], Campaign.LEVEL_NAMES[n], "World %d" % n, 0.4)


func _on_replay() -> void:
	ScreenTransition.change_scene(Campaign.LEVEL_SCENES[_level], Campaign.LEVEL_NAMES[_level], "Replay", 0.3)


func _on_title() -> void:
	ScreenTransition.change_scene(Campaign.TITLE_SCENE, "", "", 0.2)
