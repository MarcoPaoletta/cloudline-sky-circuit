class_name DialoguePanel
extends Control
## Bottom-center robot dialogue (GDD 12, docs/DIALOGUE.md). Non-blocking: lines fade in over safe ground,
## type out at 38 chars/s (optional), and auto-dismiss after a readable time. E completes the current line;
## a separate new E press dismisses it. Queue priority: safety, tutorial, objective, flavor.

signal line_started(id: StringName)
signal line_finished(id: StringName)

@export var chars_per_second: float = 38.0
@export var min_seconds: float = 3.0
@export var seconds_per_char: float = 0.04
@export var fade_time: float = 0.22
@export var max_queue: int = 3
@export var base_font_size: int = 32

@onready var _panel: PanelContainer = %Panel
@onready var _text: Label = %Text
@onready var _key_hint: Control = %KeyHint

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _reveal: float = 0.0
var _typing: bool = false
var _hold: float = 0.0
var _suppressed: bool = false
var _tween: Tween
var _eaten_frame: int = -10


func _ready() -> void:
	add_to_group(&"dialogue_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.modulate.a = 0.0
	_panel.visible = false


func is_open() -> bool:
	return not _current.is_empty()


func is_typewriting() -> bool:
	return _typing


func current_id() -> StringName:
	return _current.get("id", &"")


func get_displayed_text() -> String:
	return _text.text.substr(0, _text.visible_characters) if _text.visible_characters >= 0 else _text.text


func get_full_text() -> String:
	return _current.get("text", "")


func get_panel_alpha() -> float:
	return _panel.modulate.a


func interact_consumed_this_frame() -> bool:
	return _eaten_frame == Engine.get_process_frames()


## Queue a line from DialogueData by id. Once-lines never replay after they were shown in this run.
func say(id: StringName, force: bool = false) -> void:
	var data := DialogueData.get_line(id)
	if data.is_empty():
		return
	var repeatable: bool = bool(data.get("repeat", false))
	if not repeatable and Campaign.has_seen(id) and not force:
		return
	if _current.get("id", &"") == id:
		return
	for q in _queue:
		if q["id"] == id:
			return
	var text: String = data["text"]
	var entry := {
		"id": id, "text": text, "priority": int(data.get("priority", 3)),
		"duration": float(data.get("duration", maxf(min_seconds, text.length() * seconds_per_char + 1.2))),
	}
	_enqueue(entry)


## Ad-hoc line (not in the table).
func say_text(id: StringName, text: String, priority: int = 2, duration: float = 3.5) -> void:
	_enqueue({"id": id, "text": text, "priority": priority, "duration": duration})


func dismiss(id: StringName = &"") -> void:
	if id == &"" or _current.get("id", &"") == id:
		if not _current.is_empty():
			_finish_current()
	else:
		for i in range(_queue.size() - 1, -1, -1):
			if _queue[i]["id"] == id:
				_queue.remove_at(i)


func clear_all() -> void:
	_queue.clear()
	if not _current.is_empty():
		_finish_current()


## Hides the panel (console strip, cutscenes) without losing the queue.
func set_suppressed(value: bool) -> void:
	if _suppressed == value:
		return
	_suppressed = value
	if value:
		_fade(0.0)
	elif not _current.is_empty():
		_fade(1.0)


func _enqueue(entry: Dictionary) -> void:
	if _current.is_empty():
		_start(entry)
		return
	if entry["priority"] < int(_current["priority"]) and int(_current["priority"]) >= DialogueData.OBJECTIVE:
		# Safety / tutorial interrupts objective and flavor lines; the interrupted line is dropped.
		_current.clear()
		_start(entry)
		return
	_queue.append(entry)
	_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["priority"] < b["priority"])
	while _queue.size() > max_queue:
		_queue.pop_back()


func _start(entry: Dictionary) -> void:
	_current = entry
	Campaign.mark_dialogue(entry["id"], entry["text"])
	var size_px := int(round(base_font_size * Campaign.text_scale))
	_text.add_theme_font_size_override("font_size", size_px)
	_text.text = entry["text"]
	_hold = float(entry["duration"])
	if Campaign.instant_text:
		_text.visible_characters = -1
		_typing = false
	else:
		_text.visible_characters = 0
		_reveal = 0.0
		_typing = true
	_panel.visible = true
	if not _suppressed:
		_fade(1.0)
	line_started.emit(entry["id"])
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui(&"dialog_open", -8.0)


func _finish_current() -> void:
	var id: StringName = _current.get("id", &"")
	_current = {}
	_typing = false
	line_finished.emit(id)
	if _queue.is_empty():
		_fade(0.0)
	else:
		var next: Dictionary = _queue.pop_front()
		_start(next)


func _fade(target: float) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_panel, "modulate:a", target, fade_time).set_trans(Tween.TRANS_SINE)
	if target > 0.5:
		# Pop in from the bottom edge (scale, never position: the panel is anchored).
		_panel.pivot_offset = Vector2(_panel.size.x * 0.5, _panel.size.y)
		_panel.scale = Vector2(0.94, 0.94)
		_tween.tween_property(_panel, "scale", Vector2.ONE, fade_time + 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if target <= 0.0:
		_tween.chain().tween_callback(func() -> void:
			if _current.is_empty():
				_panel.visible = false)


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	if _typing:
		_reveal += chars_per_second * delta
		var n := int(_reveal)
		if n >= _text.text.length():
			_text.visible_characters = -1
			_typing = false
		else:
			_text.visible_characters = n
		return
	# Timed hints never disappear before they were readable (timer starts once fully typed).
	if not _suppressed:
		_hold -= delta
		if _hold <= 0.0:
			_finish_current()
	_key_hint.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _current.is_empty() or _suppressed or not event.is_action_pressed(&"interact") or event.is_echo():
		return
	_eaten_frame = Engine.get_process_frames()
	get_viewport().set_input_as_handled()
	if _typing:
		_text.visible_characters = -1
		_typing = false
	else:
		_finish_current()
