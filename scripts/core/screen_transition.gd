extends CanvasLayer
## Global screen fade with ONE owner (scene: res://scenes/core/screen_transition.tscn, autoload ScreenTransition).
##
## Falls, checkpoint recovery and scene changes all ask this layer for a fade, so two fades can never stack.
## Pattern from game-dev/screen-fade-transition: cancellation serial, observable phases, mouse blocked while
## black, failure reverts to the old scene, threaded preload of the next scene, ALWAYS process mode.

signal phase_changed(phase: StringName)
signal transition_finished(path: String)
signal transition_failed(path: String)

@export var default_fade_out: float = 0.30
@export var default_fade_in: float = 0.35

@onready var _fade: ColorRect = %Fade
@onready var _caption: Label = %Caption
@onready var _sub_caption: Label = %SubCaption

var _serial: int = 0
var _phase: StringName = &"idle"
var _tween: Tween
var _caption_tween: Tween
var _loaded: Dictionary = {}
var _requested: Array[String] = []
var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	_sub_caption.modulate.a = 0.0


func is_transitioning() -> bool:
	return _phase != &"idle"


func get_phase() -> StringName:
	return _phase


func get_fade_alpha() -> float:
	return _fade.modulate.a


func is_black() -> bool:
	return _fade.modulate.a > 0.99


## Starts loading a scene on a worker thread so the later change is not a blocking load.
func preload_scene(path: String) -> void:
	if _loaded.has(path) or _requested.has(path):
		return
	if ResourceLoader.load_threaded_request(path) == OK:
		_requested.append(path)


func fade_out(duration: float = -1.0, caption: String = "", sub_caption: String = "") -> void:
	var d := default_fade_out if duration < 0.0 else duration
	if caption != "":
		_show_caption(caption, sub_caption, d)
	await _tween_alpha(1.0, d)


func fade_in(duration: float = -1.0) -> void:
	var d := default_fade_in if duration < 0.0 else duration
	_hide_caption(d)
	await _tween_alpha(0.0, d)


## Fade to black, swap the scene while black, fade back in. Returns false when refused or failed.
func change_scene(path: String, caption: String = "", sub_caption: String = "", hold: float = 0.0, out_time: float = -1.0, in_time: float = -1.0) -> bool:
	if _busy:
		return false
	_busy = true
	_set_phase(&"hold")
	await fade_out(out_time, caption, sub_caption)
	_set_phase(&"scene_change")
	var packed := await _get_packed(path)
	var err: int = ERR_CANT_OPEN
	if packed != null:
		get_tree().paused = false
		err = get_tree().change_scene_to_packed(packed)
	if err != OK:
		push_warning("ScreenTransition: could not open %s (error %d)" % [path, err])
		_set_phase(&"fade_in")
		await fade_in(in_time)
		_set_phase(&"idle")
		_busy = false
		transition_failed.emit(path)
		return false
	await get_tree().process_frame
	await get_tree().process_frame
	if hold > 0.0:
		await get_tree().create_timer(hold, true, false, true).timeout
	_set_phase(&"fade_in")
	await fade_in(in_time)
	_set_phase(&"idle")
	_busy = false
	transition_finished.emit(path)
	return true


func _get_packed(path: String) -> PackedScene:
	if _loaded.has(path):
		return _loaded[path]
	if not _requested.has(path):
		preload_scene(path)
	if _requested.has(path):
		var guard := 0
		while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS and guard < 1200:
			await get_tree().process_frame
			guard += 1
		var res := ResourceLoader.load_threaded_get(path)
		_requested.erase(path)
		if res is PackedScene:
			_loaded[path] = res
			return res
	var direct := load(path)
	return direct as PackedScene


func _tween_alpha(target: float, duration: float) -> bool:
	_serial += 1
	var mine := _serial
	if _tween and _tween.is_valid():
		_tween.kill()
	if target > 0.001 or _fade.modulate.a > 0.001:
		_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if duration <= 0.0:
		_fade.modulate.a = target
	else:
		_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(_fade, "modulate:a", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# A timer always fires, even if a newer request kills this tween, so no await can hang.
		await get_tree().create_timer(duration, true, false, true).timeout
	if mine != _serial:
		return false
	_fade.modulate.a = target
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE if target <= 0.001 else Control.MOUSE_FILTER_STOP
	return true


func _show_caption(text: String, sub: String, duration: float) -> void:
	_caption.text = text
	_sub_caption.text = sub
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_caption_tween.tween_property(_caption, "modulate:a", 1.0, maxf(duration, 0.2)).set_delay(duration * 0.5)
	_caption_tween.tween_property(_sub_caption, "modulate:a", 1.0 if sub != "" else 0.0, maxf(duration, 0.2)).set_delay(duration * 0.6)


func _hide_caption(duration: float) -> void:
	if _caption_tween and _caption_tween.is_valid():
		_caption_tween.kill()
	_caption_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_caption_tween.tween_property(_caption, "modulate:a", 0.0, maxf(duration * 0.6, 0.1))
	_caption_tween.tween_property(_sub_caption, "modulate:a", 0.0, maxf(duration * 0.6, 0.1))


func _set_phase(phase: StringName) -> void:
	_phase = phase
	phase_changed.emit(phase)


func _exit_tree() -> void:
	_busy = false
