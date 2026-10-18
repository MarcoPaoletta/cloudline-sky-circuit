class_name SettingsPanel
extends Control
## Settings screen (GDD 14), shared by the title screen and the pause menu. Every control is authored in the
## scene; this script binds each one to its Campaign value and writes changes straight back (saved at once).
## Remappable keys live in the Keys list: one `Row_<action>` per rebindable action.

signal closed

const SLIDERS := {
	&"MasterSlider": &"vol_master", &"SfxSlider": &"vol_sfx", &"UiSlider": &"vol_ui",
	&"AmbienceSlider": &"vol_ambience", &"MusicSlider": &"vol_music", &"SensitivitySlider": &"mouse_sensitivity",
	&"TextScaleSlider": &"text_scale", &"ShakeSlider": &"shake_scale",
}
const TOGGLES := {
	&"InvertYToggle": &"invert_y", &"AimAssistToggle": &"aim_assist", &"HoldAimToggle": &"hold_to_aim",
	&"HoldBowlToggle": &"hold_to_bowl", &"InstantTextToggle": &"instant_text", &"TouchToggle": &"touch_always",
	&"ReducedMotionToggle": &"reduced_motion", &"ReducedFlashToggle": &"reduced_flash",
	&"NoRecoilToggle": &"no_recoil",
}

@onready var _keys: Control = %Keys
@onready var _back: Button = %BackButton
@onready var _reset_keys: Button = %ResetKeysButton
@onready var _scroll: ScrollContainer = %Scroll

var _rebinding: StringName = &""
var _rebind_button: Button
var _loading: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for slider_name in SLIDERS:
		var s := get_node("%" + String(slider_name)) as HSlider
		s.value_changed.connect(_on_slider_changed.bind(slider_name))
		s.drag_ended.connect(_on_slider_released.bind(slider_name))
	for toggle_name in TOGGLES:
		var b := get_node("%" + String(toggle_name)) as Button
		b.toggled.connect(_on_toggled.bind(toggle_name))
	for row in _keys.get_children():
		var action := StringName(String(row.name).trim_prefix("Row_"))
		(row.get_node("Name") as Label).text = Campaign.ACTION_LABELS.get(action, String(action))
		(row.get_node("Bind") as Button).pressed.connect(_begin_rebind.bind(action, row.get_node("Bind")))
	_back.pressed.connect(close)
	_reset_keys.pressed.connect(_on_reset_keys)
	refresh()


## Re-reads every value from Campaign (called whenever the panel opens).
func refresh() -> void:
	_loading = true
	for slider_name in SLIDERS:
		var s := get_node("%" + String(slider_name)) as HSlider
		s.value = float(Campaign.get(SLIDERS[slider_name]))
		_update_value_label(slider_name, s.value)
	for toggle_name in TOGGLES:
		var b := get_node("%" + String(toggle_name)) as Button
		b.button_pressed = bool(Campaign.get(TOGGLES[toggle_name]))
		_update_toggle_text(b)
	_refresh_keys()
	_loading = false


func open() -> void:
	refresh()
	visible = true
	_scroll.scroll_vertical = 0
	(get_node("%MasterSlider") as Control).grab_focus()


func close() -> void:
	_cancel_rebind()
	visible = false
	closed.emit()


func is_rebinding() -> bool:
	return _rebinding != &""


func _on_slider_changed(value: float, slider_name: StringName) -> void:
	_update_value_label(slider_name, value)
	if _loading:
		return
	Campaign.set(SLIDERS[slider_name], value)
	Campaign.notify_settings_changed()


func _on_slider_released(changed: bool, slider_name: StringName) -> void:
	if changed and slider_name in [&"MasterSlider", &"SfxSlider", &"UiSlider"]:
		var audio := get_node_or_null("/root/Audio")
		if audio:
			audio.play_ui(&"ui_select", -4.0)


func _update_value_label(slider_name: StringName, value: float) -> void:
	var label := get_node_or_null("%" + String(slider_name).trim_suffix("Slider") + "Value") as Label
	if label == null:
		return
	if slider_name == &"SensitivitySlider":
		label.text = "%.2fx" % value
	else:
		label.text = "%d%%" % int(round(value * 100.0))


func _on_toggled(pressed: bool, toggle_name: StringName) -> void:
	var b := get_node("%" + String(toggle_name)) as Button
	_update_toggle_text(b)
	if _loading:
		return
	Campaign.set(TOGGLES[toggle_name], pressed)
	Campaign.notify_settings_changed()
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui(&"ui_select", -6.0, 1.15 if pressed else 0.9)


func _update_toggle_text(b: Button) -> void:
	b.text = "On" if b.button_pressed else "Off"


# ---------------- Key remapping ----------------

func _refresh_keys() -> void:
	for row in _keys.get_children():
		var action := StringName(String(row.name).trim_prefix("Row_"))
		var btn := row.get_node("Bind") as Button
		btn.text = "Press a key..." if action == _rebinding else Campaign.key_text(action)


func _begin_rebind(action: StringName, button: Button) -> void:
	_cancel_rebind()
	_rebinding = action
	_rebind_button = button
	button.text = "Press a key..."
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui(&"ui_select", -4.0)


func _cancel_rebind() -> void:
	_rebinding = &""
	_rebind_button = null
	_refresh_keys()


func _input(event: InputEvent) -> void:
	if _rebinding == &"" or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if (event as InputEventKey).physical_keycode == KEY_ESCAPE:
			_cancel_rebind()
			return
		_finish_rebind(event)
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			get_viewport().set_input_as_handled()
			_finish_rebind(event)


func _finish_rebind(event: InputEvent) -> void:
	var action := _rebinding
	var swapped := Campaign.set_binding(action, event)
	_rebinding = &""
	_rebind_button = null
	_refresh_keys()
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_ui(&"checkpoint", -8.0, 1.2)
	if swapped != &"":
		var row := _keys.get_node_or_null("Row_" + String(swapped))
		if row:
			var tw := create_tween()
			var btn := row.get_node("Bind") as Control
			btn.pivot_offset = btn.size * 0.5
			tw.tween_property(btn, "scale", Vector2(1.12, 1.12), 0.1)
			tw.tween_property(btn, "scale", Vector2.ONE, 0.2)


func _on_reset_keys() -> void:
	_cancel_rebind()
	Campaign.reset_bindings()
	_refresh_keys()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _rebinding != &"":
		return
	if event.is_action_pressed(&"ui_cancel") or (event.is_action_pressed(&"pause") and not event.is_echo()):
		get_viewport().set_input_as_handled()
		close()
