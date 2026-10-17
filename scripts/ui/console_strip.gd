class_name ConsoleStrip
extends Control
## Compact Left / Right / E strip that REPLACES the dialogue panel while a console is active (GDD 8, 12).

@onready var _panel: PanelContainer = %Panel
@onready var _left: Control = %KeyLeft
@onready var _right: Control = %KeyRight
@onready var _exit: Control = %KeyExit
@onready var _message: Label = %Message

var _tween: Tween
var _msg_tween: Tween
var shown: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.modulate.a = 0.0
	_panel.visible = false
	_message.modulate.a = 0.0


func show_strip(on: bool) -> void:
	shown = on
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	if on:
		_panel.visible = true
		_panel.pivot_offset = Vector2(_panel.size.x * 0.5, _panel.size.y)
		_panel.scale = Vector2(0.94, 0.94)
		_tween.set_parallel(true)
		_tween.tween_property(_panel, "modulate:a", 1.0, 0.2)
		_tween.tween_property(_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(_panel, "modulate:a", 0.0, 0.18)
		_tween.tween_callback(func() -> void:
			if not shown:
				_panel.visible = false)
		_message.modulate.a = 0.0


func pulse_key(which: StringName, reject: bool = false) -> void:
	var k: Control = _left
	match which:
		&"right":
			k = _right
		&"busy":
			k = _panel
		_:
			k = _left
	k.pivot_offset = k.size * 0.5
	var tw := create_tween()
	var peak := Vector2(0.88, 0.88) if reject else Vector2(1.2, 1.2)
	tw.tween_property(k, "scale", peak, 0.07)
	tw.tween_property(k, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_message(text: String, seconds: float = 2.2) -> void:
	_message.text = text
	if _msg_tween and _msg_tween.is_valid():
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(_message, "modulate:a", 1.0, 0.12)
	_msg_tween.tween_interval(seconds)
	_msg_tween.tween_property(_message, "modulate:a", 0.0, 0.3)
