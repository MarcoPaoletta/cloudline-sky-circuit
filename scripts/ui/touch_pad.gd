class_name TouchPad
extends Control
## v3 on-screen controls for phones and tablets (autoload scene res://scenes/core/touch_controls.tscn).
## Shown in gameplay when the device has a touchscreen (or Settings > Always show touch controls). Multi-touch:
## each finger is tracked by index, so the robot can run with the left thumb while the right thumb jumps or
## bowls. Left side: a floating stick (it appears where the thumb lands) drives the move actions with analog
## strength; pushing it to its rim sprints (a thumb cannot hold a Run button and steer at once). Right side:
## dragging anywhere that is not a button turns the camera. Buttons are authored child
## Controls named Btn*; each sends real InputEventActions, so polled actions and event-driven UI (dialogue,
## pause) both see them. While touch mode is on, the mouse-button bindings of the bowl / aim actions are
## lifted so the mouse a tap emulates never bowls by itself. Three fingers at once toggle the F1 dev panel in
## debug builds. Everything sits inside the device safe area (notch, home indicator).

## Action sent by each button node.
const ACTIONS := {
	"BtnJump": &"jump", "BtnBowl": &"head_attack", "BtnHead": &"head_deploy", "BtnFetch": &"fetch",
	"BtnUse": &"interact", "BtnLeft": &"console_left", "BtnRight": &"console_right",
	"BtnExit": &"console_exit", "BtnPause": &"pause",
}
## What prompts and the controls list show for an action while touch mode is on.
const LABELS := {
	&"jump": "JUMP", &"head_attack": "BOWL", &"head_deploy": "HEAD", &"fetch": "FETCH", &"interact": "USE",
	&"sprint": "STICK EDGE", &"console_left": "◀", &"console_right": "▶", &"console_exit": "EXIT", &"pause": "II",
	&"move_forward": "STICK", &"move_back": "STICK", &"move_left": "STICK", &"move_right": "STICK",
	&"aim_assist": "AUTO", &"reset_local": "MENU", &"objective_help": "MENU",
}
const CONSOLE_BUTTONS := ["BtnLeft", "BtnRight", "BtnExit"]
const PLAY_BUTTONS := ["BtnJump", "BtnBowl", "BtnHead", "BtnFetch", "BtnUse"]
const LIFTED_MOUSE_ACTIONS: Array[StringName] = [&"head_attack", &"aim_assist"]

## True while the on-screen controls are in charge (read by the camera, Campaign.key_text and the HUD).
static var touch_mode: bool = false

@export var stick_radius: float = 115.0
@export var dead_zone: float = 0.16
## Stick tilt (0..1) from which the robot sprints.
@export var sprint_tilt: float = 0.92
## Camera turn per dragged pixel (canvas units), in degrees.
@export var look_degrees_per_px: float = 0.16
## Share of the screen width (from the left) where a new touch grabs the stick.
@export var stick_zone: float = 0.42
@export var base_color: Color = Color(0.06, 0.09, 0.16, 0.38)
@export var ring_color: Color = Color(1, 1, 1, 0.55)
@export var pressed_color: Color = Color(1.0, 0.82, 0.25, 0.75)

@onready var _stick: Control = $Stick
@onready var _knob: Control = $Stick/Knob

var _buttons: Dictionary = {}       # name -> Control
var _btn_finger: Dictionary = {}    # finger index -> button name
var _held: Dictionary = {}          # button name -> true
var _stick_finger: int = -1
var _stick_off: Vector4
var _sprinting: bool = false
var _stick_center: Vector2
var _look_finger: int = -1
var _move: Vector2 = Vector2.ZERO
var _fingers: Dictionary = {}       # finger index -> true (for the three-finger gesture)
var _lifted: Dictionary = {}        # action -> Array of lifted mouse events
var _shown: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in get_children():
		if ACTIONS.has(String(c.name)):
			_buttons[String(c.name)] = c
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_off = Vector4(_stick.offset_left, _stick.offset_top, _stick.offset_right, _stick.offset_bottom)
	get_viewport().size_changed.connect(apply_safe_area)
	apply_safe_area()
	_set_shown(false)


## Touch controls are wanted on touchscreen devices, or always when the player asks for it in Settings.
static func wanted() -> bool:
	return DisplayServer.is_touchscreen_available() or bool(Campaign.get("touch_always"))


## Safe-area insets (notch, rounded corners, home indicator) in canvas units: left, top, right, bottom.
static func safe_insets(vp: Viewport) -> Vector4:
	if not OS.has_feature("mobile"):
		return Vector4.ZERO
	var win := Vector2(DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if win.x < 1.0 or safe.size.x <= 0 or safe.size.x > win.x + 1.0:
		return Vector4.ZERO
	var k := vp.get_visible_rect().size / win
	return Vector4(safe.position.x * k.x, safe.position.y * k.y, (win.x - safe.end.x) * k.x, (win.y - safe.end.y) * k.y)


func apply_safe_area() -> void:
	var s := safe_insets(get_viewport())
	offset_left = s.x
	offset_top = s.y
	offset_right = -s.z
	offset_bottom = -s.w


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _process(_delta: float) -> void:
	_set_touch_mode(wanted())
	var p := _player()
	var want := wanted() and p != null and not get_tree().paused and p.is_alive()
	if want != _shown:
		_set_shown(want)
	if not _shown:
		return
	var console := p.mode == Player.Mode.CONSOLE
	for n in _buttons:
		var b: Control = _buttons[n]
		if n in CONSOLE_BUTTONS:
			b.visible = console
		elif n in PLAY_BUTTONS:
			b.visible = not console or n == "BtnUse"
	_stick.visible = not console
	queue_redraw()


func _set_shown(on: bool) -> void:
	_shown = on
	visible = on
	if not on:
		_release_all()


func _set_touch_mode(on: bool) -> void:
	if on == touch_mode:
		return
	touch_mode = on
	for a in LIFTED_MOUSE_ACTIONS:
		if not InputMap.has_action(a):
			continue
		if on:
			var lifted := []
			for ev in InputMap.action_get_events(a):
				if ev is InputEventMouseButton:
					lifted.append(ev)
					InputMap.action_erase_event(a, ev)
			_lifted[a] = lifted
		else:
			for ev in _lifted.get(a, []):
				InputMap.action_add_event(a, ev)
			_lifted.erase(a)
	var p := _player()
	if p:
		p.camera_rig().set_capture(p.camera_rig().capture_enabled)


func _input(event: InputEvent) -> void:
	if not _shown:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_fingers[t.index] = true
			if _fingers.size() >= 3 and OS.is_debug_build():
				_fingers.clear()
				var dp := get_node_or_null("/root/DebugPanel")
				if dp and dp.is_open():
					dp.close()
				elif dp:
					dp.open()
				return
			_touch_down(t.index, t.position)
		else:
			_fingers.erase(t.index)
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			_stick_to(d.position)
		elif d.index == _look_finger:
			var p := _player()
			if p:
				p.camera_rig().apply_touch_look(d.relative * look_degrees_per_px)


func _touch_down(index: int, pos: Vector2) -> void:
	for n in _buttons:
		var b: Control = _buttons[n]
		if not b.is_visible_in_tree():
			continue
		var r := b.get_global_rect()
		if r.get_center().distance_to(pos) <= maxf(r.size.x, r.size.y) * 0.62:
			_btn_finger[index] = n
			_held[n] = true
			_send(ACTIONS[n], true)
			return
	var local := pos - global_position
	if _stick.visible and _stick_finger < 0 and local.x < size.x * stick_zone:
		_stick_finger = index
		_stick_center = pos
		_stick.global_position = pos - _stick.size * 0.5
		_stick_to(pos)
		return
	if _look_finger < 0:
		_look_finger = index


func _touch_up(index: int) -> void:
	if _btn_finger.has(index):
		var n: String = _btn_finger[index]
		_btn_finger.erase(index)
		_held.erase(n)
		_send(ACTIONS[n], false)
	elif index == _stick_finger:
		_stick_finger = -1
		_set_sprint(false)
		_set_move(Vector2.ZERO)
		_stick.offset_left = _stick_off.x
		_stick.offset_top = _stick_off.y
		_stick.offset_right = _stick_off.z
		_stick.offset_bottom = _stick_off.w
		_knob.position = (_stick.size - _knob.size) * 0.5
	elif index == _look_finger:
		_look_finger = -1


func _stick_to(pos: Vector2) -> void:
	var v := (pos - _stick_center) / stick_radius
	if v.length() > 1.0:
		v = v.normalized()
	_knob.position = (_stick.size - _knob.size) * 0.5 + v * stick_radius
	var mag := v.length()
	_set_move(Vector2.ZERO if mag < dead_zone else v.normalized() * ((mag - dead_zone) / (1.0 - dead_zone)))
	_set_sprint(mag >= sprint_tilt)


func _set_sprint(on: bool) -> void:
	if on != _sprinting:
		_sprinting = on
		_send(&"sprint", on)


func _set_move(v: Vector2) -> void:
	if v == _move:
		return
	_move = v
	_axis(&"move_left", maxf(-v.x, 0.0))
	_axis(&"move_right", maxf(v.x, 0.0))
	_axis(&"move_forward", maxf(-v.y, 0.0))
	_axis(&"move_back", maxf(v.y, 0.0))


func _axis(action: StringName, strength: float) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = strength > 0.0
	e.strength = strength
	Input.parse_input_event(e)


func _send(action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _release_all() -> void:
	for f in _btn_finger.keys():
		_touch_up(f)
	if _stick_finger >= 0:
		_touch_up(_stick_finger)
	_look_finger = -1
	_fingers.clear()


func _draw() -> void:
	if _stick.visible:
		var c := _stick.position + _stick.size * 0.5
		draw_circle(c, stick_radius + 22.0, base_color)
		draw_arc(c, stick_radius + 22.0, 0.0, TAU, 48, ring_color, 4.0, true)
		draw_circle(_stick.position + _knob.position + _knob.size * 0.5, _knob.size.x * 0.5, ring_color)
	for n in _buttons:
		var b: Control = _buttons[n]
		if not b.visible:
			continue
		var r := Rect2(b.position, b.size)
		var rad := minf(r.size.x, r.size.y) * 0.5
		draw_circle(r.get_center(), rad, pressed_color if _held.has(n) else base_color)
		draw_arc(r.get_center(), rad, 0.0, TAU, 40, ring_color, 3.0, true)
