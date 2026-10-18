extends CanvasLayer
## Development-only F2 lighting lab (game-dev concept-match): the concept image on the left, the live game on the
## right (a second camera in the same world, so the HUD stays out of the frame), and live controls for the
## Environment, the sky, the Sun and the main toon materials of the current scene. Hidden at boot and removed in
## release exports, like the F1 panel.
##
## Rows are authored in the scene: each `R_<target>__<property>` row holds a Slider (or a Pick colour button) and a
## Value label. Targets: env, sky, sun (plus the virtual sun properties elevation / azimuth), grass, rock, bush,
## cloud. Save to project writes the Environment and the touched toon materials into their .tres files and the Sun
## into res://resources/lighting/<scene>.tres (a LightingPreset the scene applies on load in every build).

@onready var _concept_view: TextureRect = %ConceptView
@onready var _concept_title: Label = %ConceptTitle
@onready var _game_title: Label = %GameTitle
@onready var _lab_cam: Camera3D = %LabCam
@onready var _cols: Control = %Cols
@onready var _status: Label = %LabStatus
@onready var _cam_button: Button = %ConceptCamButton
@onready var _freeze_button: Button = %FreezeButton

const CONCEPT_DIR := "res://docs/concepts/"
## Default concept for each scene (file name prefix).
const SCENE_CONCEPT := {
	"title_screen": "01-", "level_1": "02-", "level_2": "03-", "level_3": "04-",
	"arena_1": "14-", "arena_2": "15-", "arena_3": "16-",
}

var _open: bool = false
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE
var _was_paused: bool = false
var _concepts: PackedStringArray = []
var _concept_idx: int = 0
## scene path -> {row key: original value} captured the first time the lab opens in that scene.
var _snapshots: Dictionary = {}
var _touched: Dictionary = {}
var _rows: Array[Control] = []


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	for col in _cols.get_children():
		for row in col.get_children():
			if String(row.name).begins_with("R_"):
				_rows.append(row as Control)
				var slider := row.get_node_or_null("Slider") as Range
				var pick := row.get_node_or_null("Pick") as ColorPickerButton
				if slider:
					slider.value_changed.connect(_on_slider.bind(row))
				if pick:
					pick.color_changed.connect(_on_pick.bind(row))
	(%PrevConcept as Button).pressed.connect(_step_concept.bind(-1))
	(%NextConcept as Button).pressed.connect(_step_concept.bind(1))
	_cam_button.toggled.connect(func(_on: bool) -> void: _update_cam())
	_freeze_button.toggled.connect(func(on: bool) -> void: get_tree().paused = on)
	(%ResetButton as Button).pressed.connect(_on_reset)
	(%CopyButton as Button).pressed.connect(_on_copy)
	(%SaveButton as Button).pressed.connect(_on_save)
	(%CloseLabButton as Button).pressed.connect(close)
	for f in DirAccess.get_files_at(CONCEPT_DIR):
		if f.ends_with(".png.import"):
			_concepts.append(f.trim_suffix(".import"))
	_concepts.sort()


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"lighting_lab") and not event.is_echo():
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	var scene := get_tree().current_scene
	if scene == null or _env() == null:
		return
	_open = true
	visible = true
	_prev_mouse = Input.mouse_mode
	_was_paused = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_freeze_button.set_pressed_no_signal(get_tree().paused)
	var key := scene.scene_file_path.get_file().get_basename()
	_concept_idx = 0
	for i in _concepts.size():
		if _concepts[i].begins_with(String(SCENE_CONCEPT.get(key, "01-"))):
			_concept_idx = i
	_show_concept()
	_cam_button.disabled = _concept_cam() == null
	_cam_button.set_pressed_no_signal(false)
	if not _snapshots.has(scene.scene_file_path):
		var snap := {}
		for row in _rows:
			snap[row.name] = _read(row)
		_snapshots[scene.scene_file_path] = snap
	_refresh_rows()
	var env := _env()
	_game_title.text = "GAME (live)  |  %s  |  sky: %s" % [key, env.resource_path.get_file()]
	_say("F2 closes. Drag the sliders; the right view updates live. Save to project keeps the result.")


func close() -> void:
	_open = false
	visible = false
	get_tree().paused = _was_paused and _freeze_button.button_pressed
	if _prev_mouse == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if _open:
		_update_cam()


func _update_cam() -> void:
	var src: Camera3D = _concept_cam() if _cam_button.button_pressed else get_tree().root.get_camera_3d()
	if src == null or src == _lab_cam:
		return
	_lab_cam.global_transform = src.global_transform
	_lab_cam.fov = src.fov
	_lab_cam.near = src.near
	_lab_cam.far = src.far
	_lab_cam.cull_mask = src.cull_mask
	_lab_cam.environment = src.environment
	_lab_cam.attributes = src.attributes


func _concept_cam() -> Camera3D:
	var scene := get_tree().current_scene
	var cams := scene.get_node_or_null("ConceptCams") if scene else null
	if cams:
		for c in cams.get_children():
			if c is Camera3D:
				return c
	return null


func _step_concept(d: int) -> void:
	if _concepts.is_empty():
		return
	_concept_idx = posmod(_concept_idx + d, _concepts.size())
	_show_concept()


func _show_concept() -> void:
	if _concepts.is_empty():
		_concept_title.text = "CONCEPT (none found)"
		return
	var f := _concepts[_concept_idx]
	_concept_view.texture = load(CONCEPT_DIR + f) as Texture2D
	_concept_title.text = "CONCEPT  |  %s  (%d / %d)" % [f.get_basename(), _concept_idx + 1, _concepts.size()]


func _say(text: String) -> void:
	_status.text = text


# ---------------------------------------------------------------- targets

func _env() -> Environment:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	for we in scene.find_children("*", "WorldEnvironment", true, false):
		return (we as WorldEnvironment).environment
	return null


func _sun() -> DirectionalLight3D:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Sun") as DirectionalLight3D if scene else null


func _material(target: String) -> ShaderMaterial:
	var scene := get_tree().current_scene
	var arena := scene != null and scene.scene_file_path.contains("/arenas/")
	match target:
		"grass":
			return load("res://resources/materials/toon/%s.tres" % ("grass_arena" if arena else "grass")) as ShaderMaterial
		"rock", "bush":
			return load("res://resources/materials/toon/%s.tres" % target) as ShaderMaterial
		"cloud":
			for g in scene.find_children("*", "GeometryInstance3D", true, false):
				var m := (g as GeometryInstance3D).material_override
				if m is ShaderMaterial and m.resource_path.contains("/toon/cloud"):
					return m
			return load("res://resources/materials/toon/cloud_day.tres") as ShaderMaterial
	return null


func _split(row: Node) -> PackedStringArray:
	return String(row.name).trim_prefix("R_").split("__")


func _read(row: Node) -> Variant:
	var kp := _split(row)
	var target := kp[0]
	var prop := kp[1]
	match target:
		"env":
			return _env().get(prop)
		"sky":
			var sky := _env().sky
			return sky.sky_material.get(prop) if sky and sky.sky_material else null
		"sun":
			var sun := _sun()
			if sun == null:
				return null
			if prop == "elevation":
				return -sun.rotation_degrees.x
			if prop == "azimuth":
				return sun.rotation_degrees.y
			return sun.get(prop)
		_:
			var m := _material(target)
			if m == null:
				return null
			var v: Variant = m.get_shader_parameter(prop)
			if v is Vector3:
				return Color(v.x, v.y, v.z)
			return v


func _write(row: Node, value: Variant) -> void:
	var kp := _split(row)
	var target := kp[0]
	var prop := kp[1]
	match target:
		"env":
			_env().set(prop, value)
			_touched["env"] = _env()
		"sky":
			var sky := _env().sky
			if sky and sky.sky_material:
				sky.sky_material.set(prop, value)
				_touched["env"] = _env()
				_touched["sky"] = sky.sky_material
		"sun":
			var sun := _sun()
			if sun == null:
				return
			if prop == "elevation":
				sun.rotation_degrees.x = -float(value)
			elif prop == "azimuth":
				sun.rotation_degrees.y = float(value)
			else:
				sun.set(prop, value)
			_touched["sun"] = sun
		_:
			var m := _material(target)
			if m:
				m.set_shader_parameter(prop, value)
				_touched[target] = m


func _refresh_rows() -> void:
	for row in _rows:
		var v: Variant = _read(row)
		var slider := row.get_node_or_null("Slider") as Range
		var pick := row.get_node_or_null("Pick") as ColorPickerButton
		row.modulate.a = 1.0 if v != null else 0.35
		if v == null:
			continue
		if slider:
			slider.set_value_no_signal(float(v))
		elif pick and v is Color:
			pick.color = v
		_show_value(row, v)


func _show_value(row: Node, v: Variant) -> void:
	var lbl := row.get_node_or_null("Value") as Label
	if lbl == null:
		return
	if v is Color:
		lbl.text = "#" + (v as Color).to_html(false)
	elif v is float:
		lbl.text = ("%.4f" % v) if absf(v) < 0.05 and v != 0.0 else ("%.2f" % v)
	else:
		lbl.text = str(v)


func _on_slider(value: float, row: Node) -> void:
	_write(row, value)
	_show_value(row, value)


func _on_pick(color: Color, row: Node) -> void:
	_write(row, color)
	_show_value(row, color)


func _on_reset() -> void:
	var scene := get_tree().current_scene
	var snap: Dictionary = _snapshots.get(scene.scene_file_path, {})
	for row in _rows:
		if snap.has(row.name) and snap[row.name] != null:
			_write(row, snap[row.name])
	_refresh_rows()
	_say("Back to the values this scene loaded with (nothing saved).")


func _values_text() -> String:
	var scene := get_tree().current_scene
	var lines: PackedStringArray = ["Lighting lab values for %s" % scene.scene_file_path.get_file()]
	lines.append("environment: %s" % _env().resource_path)
	for row in _rows:
		var v: Variant = _read(row)
		if v == null:
			continue
		var kp := _split(row)
		var shown: String = ("Color(%.3f, %.3f, %.3f)" % [v.r, v.g, v.b]) if v is Color else str(snappedf(float(v), 0.0001))
		lines.append("%s.%s = %s" % [kp[0], kp[1], shown])
	return "\n".join(lines)


func _on_copy() -> void:
	DisplayServer.clipboard_set(_values_text())
	_say("Values copied to the clipboard (paste them in the chat to bake them in).")


func _on_save() -> void:
	var scene := get_tree().current_scene
	var saved: PackedStringArray = []
	for key in _touched:
		var obj: Object = _touched[key]
		if key == "sun":
			var preset := LightingPreset.new()
			preset.capture_sun(obj as DirectionalLight3D)
			DirAccess.make_dir_recursive_absolute(LightingPreset.DIR)
			var p := LightingPreset.path_for(scene)
			if _save_keeping_uid(preset, p):
				saved.append(p.get_file())
		elif obj is Resource:
			var r := obj as Resource
			if r.resource_path != "" and not r.resource_path.contains("::") and _save_keeping_uid(r, r.resource_path):
				saved.append(r.resource_path.get_file())
	DirAccess.make_dir_recursive_absolute("user://lighting_lab")
	var f := FileAccess.open("user://lighting_lab/%s.txt" % scene.scene_file_path.get_file().get_basename(), FileAccess.WRITE)
	if f:
		f.store_string(_values_text())
		f.close()
	_touched.clear()
	_say("Saved: %s" % (", ".join(saved) if not saved.is_empty() else "nothing changed"))


## A save from the running game writes the .tres without its `uid=` header (the editor's UID cache is not loaded),
## so the original first line is put back afterwards and scenes keep resolving the resource by UID.
func _save_keeping_uid(r: Resource, path: String) -> bool:
	var header := ""
	if FileAccess.file_exists(path):
		var rf := FileAccess.open(path, FileAccess.READ)
		header = rf.get_line()
		rf.close()
	if ResourceSaver.save(r, path) != OK:
		return false
	if header.contains(" uid="):
		var text := FileAccess.get_file_as_string(path)
		var nl := text.find("\n")
		var wf := FileAccess.open(path, FileAccess.WRITE)
		wf.store_string(header + (text.substr(nl) if nl >= 0 else "\n"))
		wf.close()
	return true
