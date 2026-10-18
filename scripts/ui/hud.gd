class_name Hud
extends CanvasLayer
## Minimal in-game HUD (GDD 12): three health pips + coin count top-left, speaker/M badge top-right (Audio scene),
## reticle with tool state, one context prompt, toasts, and the goal marker. The world already shows everything
## else, so there is no permanent four-mechanic checklist.

signal prompt_changed(owner_id: StringName)

@export var pip_full_color: Color = Color("#ff6b5a")
@export var pip_empty_color: Color = Color(0.2, 0.28, 0.38, 0.9)
@export var toast_seconds: float = 2.2

@onready var _pips: Array[Node] = %Pips.get_children()
@onready var _coin_label: Label = %CoinLabel
@onready var _coin_icon: Control = %CoinIcon
@onready var _reticle: Control = %Reticle
@onready var _tool_label: Label = %ToolLabel
@onready var _prompt_box: PanelContainer = %PromptBox
@onready var _prompt_key: Label = %PromptKey
@onready var _prompt_text: Label = %PromptText
@onready var _toast: Label = %Toast
@onready var _goal: Control = %GoalMarker
@onready var _dialogue: DialoguePanel = %Dialogue
@onready var _console_strip: ConsoleStrip = %ConsoleStrip

var _player: Player
var _prompts: Dictionary = {}
var _toast_tween: Tween
var _coin_tween: Tween
var _pip_tweens: Dictionary = {}
var _last_health: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"hud")
	_prompt_box.modulate.a = 0.0
	_prompt_box.visible = false
	_toast.modulate.a = 0.0
	_tool_label.modulate.a = 0.0
	_reticle.modulate.a = 0.45
	Campaign.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Campaign.run_coins)
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p:
		bind_player(p)


func dialogue() -> DialoguePanel:
	return _dialogue


func goal_marker() -> Control:
	return _goal


func bind_player(p: Player) -> void:
	if _player and _player.health_changed.is_connected(_on_health_changed):
		_player.health_changed.disconnect(_on_health_changed)
	_player = p
	_player.health_changed.connect(_on_health_changed)
	_on_health_changed(p.health, p.max_health)


func _on_health_changed(health: int, max_health: int) -> void:
	for i in _pips.size():
		var pip := _pips[i] as Control
		pip.visible = i < max_health
		var full := i < health
		var target := pip_full_color if full else pip_empty_color
		pip.pivot_offset = pip.size * 0.5
		if _last_health >= 0 and full != (i < _last_health):
			if _pip_tweens.has(i) and (_pip_tweens[i] as Tween).is_valid():
				(_pip_tweens[i] as Tween).kill()
			var tw := create_tween().set_parallel(true)
			_pip_tweens[i] = tw
			tw.tween_property(pip, "modulate", target, 0.18)
			tw.tween_property(pip, "scale", Vector2.ONE, 0.3).from(Vector2(1.5, 1.5) if full else Vector2(0.6, 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			pip.modulate = target
	_last_health = health


func _on_coins_changed(total: int) -> void:
	_coin_label.text = str(total)
	if _coin_tween and _coin_tween.is_valid():
		_coin_tween.kill()
	_coin_icon.pivot_offset = _coin_icon.size * 0.5
	_coin_tween = create_tween()
	_coin_tween.tween_property(_coin_icon, "scale", Vector2.ONE, 0.25).from(Vector2(1.35, 1.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## One context prompt at a time, most recently set wins; each owner clears its own.
func set_prompt(owner_id: StringName, key: String, text: String) -> void:
	_prompts[owner_id] = {"key": key, "text": text}
	_refresh_prompt()
	prompt_changed.emit(owner_id)


func clear_prompt(owner_id: StringName) -> void:
	if _prompts.erase(owner_id):
		_refresh_prompt()
		prompt_changed.emit(owner_id)


func get_prompt_text() -> String:
	return _prompt_text.text if _prompt_box.visible and _prompt_box.modulate.a > 0.1 else ""


func _refresh_prompt() -> void:
	var has_prompt := not _prompts.is_empty()
	if has_prompt:
		var last: Dictionary = _prompts[_prompts.keys().back()]
		_prompt_key.text = last["key"]
		_prompt_text.text = last["text"]
		_prompt_box.visible = true
	var tw := create_tween()
	tw.tween_property(_prompt_box, "modulate:a", 1.0 if has_prompt else 0.0, 0.18)
	if not has_prompt:
		tw.tween_callback(func() -> void:
			if _prompts.is_empty():
				_prompt_box.visible = false)


func toast(text: String, color: Color = Color.WHITE) -> void:
	_toast.text = text
	_toast.add_theme_color_override("font_color", color)
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.pivot_offset = _toast.size * 0.5
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.parallel().tween_property(_toast, "scale", Vector2.ONE, 0.3).from(Vector2(1.2, 1.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(toast_seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


## Tool state beside the reticle while aiming (e.g. "Bowl", "Recall your head first").
func set_tool_state(text: String) -> void:
	_tool_label.text = text
	var tw := create_tween()
	tw.tween_property(_tool_label, "modulate:a", 1.0 if text != "" else 0.0, 0.12)
	_reticle.modulate.a = 0.95 if text != "" else 0.45


func set_reticle_visible(value: bool) -> void:
	_reticle.visible = value


## Console mode: the Left / Right / E strip replaces the dialogue panel.
func show_console_strip(on: bool) -> void:
	_console_strip.show_strip(on)
	_prompt_box.visible = not on and not _prompts.is_empty()


func console_pulse_key(which: StringName, reject: bool = false) -> void:
	_console_strip.pulse_key(which, reject)


func console_message(text: String) -> void:
	_console_strip.show_message(text)


func is_console_strip_shown() -> bool:
	return _console_strip.shown
