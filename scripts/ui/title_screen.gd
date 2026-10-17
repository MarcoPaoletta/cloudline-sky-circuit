class_name TitleScreen
extends Node3D
## Title screen: a living diorama of the opening vista with slow camera cuts, and the menu on top.
## Continue resumes the pending arena (with a ready screen) or the next unfinished world; New Game asks before
## erasing; Worlds lists the records and replays any unlocked world; Settings is the shared panel.
## Mouse, keyboard and pad all drive the same focusable buttons. Boots muted like every screen (M toggles).

@export var cut_seconds: float = 8.5
@export var drift_meters: float = 2.4
@export var cut_dip_out: float = 0.28
@export var cut_dip_in: float = 0.4

@onready var _camera: Camera3D = %Camera
@onready var _poses: Array[Node] = %CameraPoses.get_children()
@onready var _shade: ColorRect = %Shade
@onready var _main: Control = %MainPanel
@onready var _worlds: Control = %WorldsPanel
@onready var _settings: SettingsPanel = %Settings
@onready var _confirm: Control = %ConfirmPanel
@onready var _ready_panel: Control = %ReadyPanel
@onready var _complete: Control = %CompletePanel
@onready var _continue: Button = %ContinueButton
@onready var _continue_sub: Label = %ContinueSub
@onready var _new_game: Button = %NewGameButton
@onready var _worlds_btn: Button = %WorldsButton
@onready var _settings_btn: Button = %SettingsButton
@onready var _quit: Button = %QuitButton
@onready var _world_cards: Control = %WorldCards
@onready var _worlds_back: Button = %WorldsBackButton
@onready var _confirm_yes: Button = %ConfirmYesButton
@onready var _confirm_no: Button = %ConfirmNoButton
@onready var _ready_title: Label = %ReadyTitle
@onready var _ready_body: Label = %ReadyBody
@onready var _ready_go: Button = %ReadyGoButton
@onready var _ready_back: Button = %ReadyBackButton
@onready var _complete_stats: Label = %CompleteStats
@onready var _complete_worlds: Button = %CompleteWorldsButton
@onready var _complete_main: Button = %CompleteMainButton
@onready var _footer: Label = %Footer

var _pose_idx: int = 0
var _pose_age: float = 0.0
var _cutting: bool = false
var _busy: bool = false
var _current_panel: Control
var _panel_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_shade.modulate.a = 0.0
	_continue.pressed.connect(_on_continue)
	_new_game.pressed.connect(_on_new_game)
	_worlds_btn.pressed.connect(func() -> void: _show_panel(_worlds))
	_settings_btn.pressed.connect(func() -> void: _show_panel(_settings))
	_quit.pressed.connect(func() -> void: get_tree().quit())
	_worlds_back.pressed.connect(func() -> void: _show_panel(_main))
	_settings.closed.connect(func() -> void: _show_panel(_main))
	_confirm_yes.pressed.connect(_on_confirm_new_game)
	_confirm_no.pressed.connect(func() -> void: _show_panel(_main))
	_ready_go.pressed.connect(_on_ready_go)
	_ready_back.pressed.connect(func() -> void: _show_panel(_main))
	_complete_worlds.pressed.connect(func() -> void: _show_panel(_worlds))
	_complete_main.pressed.connect(func() -> void: _show_panel(_main))
	for n in range(1, Campaign.LEVEL_COUNT + 1):
		var play := _world_cards.get_node("Card%d/Box/PlayButton" % n) as Button
		play.pressed.connect(_start_level.bind(n))
	_quit.visible = not OS.has_feature("web") and not OS.has_feature("ios")
	_place_camera()
	_refresh_all()
	var first: Control = _main
	if Campaign.title_view == &"complete":
		first = _complete
	Campaign.title_view = &""
	_show_panel(first, true)


func _process(delta: float) -> void:
	_pose_age += delta
	_place_camera()
	if _pose_age >= cut_seconds and not _cutting:
		_next_pose()


func _place_camera() -> void:
	if _poses.is_empty():
		return
	var pose := _poses[_pose_idx] as Camera3D
	var t := clampf(_pose_age / cut_seconds, 0.0, 1.0)
	var drift := 0.0 if Campaign.reduced_motion else drift_meters
	_camera.global_transform = pose.global_transform
	_camera.global_position += pose.global_basis * Vector3(lerpf(-0.5, 0.5, t) * (0.0 if Campaign.reduced_motion else 1.0), 0.0, -drift * t)
	_camera.fov = pose.fov


func _next_pose() -> void:
	_cutting = true
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_shade, "modulate:a", 1.0, cut_dip_out)
	tw.tween_callback(func() -> void:
		_pose_idx = (_pose_idx + 1) % _poses.size()
		_pose_age = 0.0
		_place_camera())
	tw.tween_property(_shade, "modulate:a", 0.0, cut_dip_in)
	tw.tween_callback(func() -> void: _cutting = false)


# ---------------- Panels ----------------

func _show_panel(panel: Control, instant: bool = false) -> void:
	if _busy:
		return
	_refresh_all()
	for p in [_main, _worlds, _settings, _confirm, _ready_panel, _complete]:
		(p as Control).visible = p == panel
	_current_panel = panel
	if _panel_tween and _panel_tween.is_valid():
		_panel_tween.kill()
	panel.modulate.a = 1.0 if instant else 0.0
	if not instant:
		_panel_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_panel_tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	_footer.visible = panel == _main
	if panel == _main:
		_continue.grab_focus()
	elif panel == _worlds:
		_worlds_back.grab_focus()
	elif panel == _settings:
		_settings.open()
	elif panel == _confirm:
		_confirm_no.grab_focus()
	elif panel == _ready_panel:
		_ready_go.grab_focus()
	elif panel == _complete:
		_complete_main.grab_focus()


func _refresh_all() -> void:
	var progress := Campaign.has_progress()
	_continue.text = "Continue" if progress else "Play"
	_new_game.visible = progress
	_worlds_btn.visible = progress or Campaign.debug_unlocked
	var t := Campaign.continue_target()
	if t["kind"] == "arena":
		_continue_sub.text = "Arena %d  ·  %s" % [t["n"], Campaign.ARENA_NAMES[t["n"]]]
	else:
		var n: int = t["n"]
		var verb := "Replay " if Campaign.campaign_complete else ""
		_continue_sub.text = "%sWorld %d  ·  %s" % [verb, n, Campaign.LEVEL_NAMES[n]]
	_continue_sub.visible = true
	for n in range(1, Campaign.LEVEL_COUNT + 1):
		_refresh_card(n)
	_complete_stats.text = _complete_text()


func _refresh_card(n: int) -> void:
	var card := _world_cards.get_node("Card%d/Box" % n)
	var unlocked := Campaign.is_level_unlocked(n)
	var lv: Dictionary = Campaign._level(n)
	(card.get_node("Name") as Label).text = "World %d  ·  %s" % [n, Campaign.LEVEL_NAMES[n]]
	var lines: PackedStringArray = []
	if not unlocked:
		lines.append("Locked. Finish the arena in world %d first." % (n - 1))
	else:
		lines.append("Flag: %s     Arena: %s" % ["captured" if lv["flag"] else "not yet", "cleared" if lv["arena"] else "not yet"])
		var best := float(lv["best_time"])
		var gem_total: int = 3 if n == 1 else 4 if n == 2 else 5
		lines.append("Best flag time: %s" % (("%d:%02d" % [int(best / 60.0), int(best) % 60]) if best > 0.0 else "-"))
		lines.append("Coins banked: %d     Gems: %d / %d" % [(lv["coins"] as Array).size(), (lv["gems"] as Array).size(), gem_total])
	(card.get_node("Stats") as Label).text = "\n".join(lines)
	var play := card.get_node("PlayButton") as Button
	play.disabled = not unlocked
	play.text = "Play" if unlocked else "Locked"
	var arena_btn := card.get_node_or_null("ArenaButton") as Button
	if arena_btn != null:
		arena_btn.visible = unlocked and bool(lv["flag"])


func _complete_text() -> String:
	var total_time := 0.0
	var arenas := 0
	for n in range(1, Campaign.LEVEL_COUNT + 1):
		total_time += Campaign.best_time(n)
		if Campaign.has_arena_cleared(n):
			arenas += 1
	return "All three flags and %d / 3 arenas.\nBest flag times total %d:%02d.\nCoins banked: %d     Gems: %d / 12" % [arenas, int(total_time / 60.0), int(total_time) % 60, Campaign.banked_coins(), Campaign.banked_gems()]


# ---------------- Actions ----------------

func _on_continue() -> void:
	var t := Campaign.continue_target()
	if t["kind"] == "arena":
		var n: int = t["n"]
		_ready_title.text = "Arena %d  ·  %s" % [n, Campaign.ARENA_NAMES[n]]
		_ready_body.text = "Your flag in %s is already banked.\nOnly the arena is left: three quick waves." % Campaign.LEVEL_NAMES[n]
		_ready_go.text = "Enter arena"
		_show_panel(_ready_panel)
	else:
		_start_level(t["n"])


func _on_ready_go() -> void:
	var t := Campaign.continue_target()
	if t["kind"] == "arena":
		_start_arena(t["n"])


func _on_new_game() -> void:
	if Campaign.has_progress():
		_show_panel(_confirm)
	else:
		_on_confirm_new_game()


func _on_confirm_new_game() -> void:
	Campaign.erase_progress()
	_start_level(1)


func _start_level(n: int) -> void:
	if _busy or not Campaign.is_level_unlocked(n) or not ResourceLoader.exists(Campaign.LEVEL_SCENES[n]):
		return
	_busy = true
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui(&"ui_select", -2.0)
	await ScreenTransition.change_scene(Campaign.LEVEL_SCENES[n], Campaign.LEVEL_NAMES[n], "World %d" % n, 0.5)
	_busy = false


func _start_arena(n: int) -> void:
	if _busy or not ResourceLoader.exists(Campaign.ARENA_SCENES[n]):
		return
	_busy = true
	await ScreenTransition.change_scene(Campaign.ARENA_SCENES[n], "Arena %d" % n, Campaign.ARENA_NAMES[n], 0.5)
	_busy = false


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")) and not event.is_echo():
		if _current_panel != null and _current_panel != _main and _current_panel != _settings:
			get_viewport().set_input_as_handled()
			_show_panel(_main)
