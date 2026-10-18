extends CanvasLayer
## Development-only F1 panel (GDD 16): +100 / +1000 coins, jump to any world or arena, teleport to the next safe
## checkpoint, reset the nearby puzzle, return both parts, invulnerability, unlock all progression, 1x / 2x / 4x
## local test speed and Erase Save / Start Over with a confirmation. Hidden at boot, themed like the game, and
## removed entirely in release exports. Every grant uses the normal HUD feedback.
## v2: fly mode (no collision; Jump rises, C or Ctrl sinks, Sprint flies fast), Go to flag (lands the robot a few
## metres from the world's flag, facing it), Complete arena (clears the running arena through its normal victory)
## and a shortcut to the F2 lighting lab.

@export var puzzle_reset_radius: float = 45.0

@onready var _status: Label = %Status
@onready var _confirm_row: Control = %ConfirmRow
@onready var _invuln: Button = %InvulnButton
@onready var _unlock: Button = %UnlockButton
@onready var _speed_buttons: Array[Node] = %SpeedRow.get_children()
@onready var _goto_row: Control = %GotoRow
@onready var _fly: Button = %FlyButton

var _open: bool = false
var _prev_mouse: int = Input.MOUSE_MODE_VISIBLE
var _checkpoint_idx: int = 0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_confirm_row.visible = false
	(%Coins100 as Button).pressed.connect(func() -> void: _grant(100))
	(%Coins1000 as Button).pressed.connect(func() -> void: _grant(1000))
	for b in _goto_row.get_children():
		(b as Button).pressed.connect(_on_goto.bind(String(b.name)))
	(%CheckpointButton as Button).pressed.connect(_on_checkpoint)
	(%ResetPuzzleButton as Button).pressed.connect(_on_reset_puzzle)
	(%ReturnPartsButton as Button).pressed.connect(_on_return_parts)
	_invuln.toggled.connect(_on_invuln)
	_fly.toggled.connect(_on_fly)
	(%FlagButton as Button).pressed.connect(_on_flag)
	(%ArenaWinButton as Button).pressed.connect(_on_arena_win)
	(%LabButton as Button).pressed.connect(_on_lab)
	_unlock.toggled.connect(_on_unlock)
	for b in _speed_buttons:
		(b as Button).pressed.connect(_on_speed.bind(float(String(b.name).trim_prefix("Speed"))))
	(%EraseButton as Button).pressed.connect(func() -> void: _confirm_row.visible = true)
	(%EraseYes as Button).pressed.connect(_on_erase_yes)
	(%EraseNo as Button).pressed.connect(func() -> void: _confirm_row.visible = false)
	(%CloseButton as Button).pressed.connect(close)


func is_open() -> bool:
	return _open


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_panel") and not event.is_echo():
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_open = true
	visible = true
	_confirm_row.visible = false
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_invuln.set_pressed_no_signal(_player_flag())
	var pl := _player()
	_fly.set_pressed_no_signal(pl != null and pl.debug_fly)
	_unlock.set_pressed_no_signal(Campaign.debug_unlocked)
	_refresh_speed()
	_say("Dev panel. F1 closes it.")


func close() -> void:
	_open = false
	visible = false
	_confirm_row.visible = false
	if _prev_mouse == Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _say(text: String) -> void:
	_status.text = text


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _player_flag() -> bool:
	var p := _player()
	return p != null and p.debug_invulnerable


func _sfx(id: StringName) -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio:
		audio.play_sfx(id, -4.0)


func _grant(amount: int) -> void:
	Campaign.grant_coins(amount)
	_sfx(&"coin")
	_say("+%d coins (run total %d)" % [amount, Campaign.run_coins])


func _on_goto(node_name: String) -> void:
	var kind := node_name.substr(0, 1)
	var n := int(node_name.substr(1))
	var path := String(Campaign.LEVEL_SCENES.get(n, "")) if kind == "W" else String(Campaign.ARENA_SCENES.get(n, ""))
	if path == "" or not ResourceLoader.exists(path):
		_say("%s is not available yet." % node_name)
		return
	close()
	get_tree().paused = false
	Engine.time_scale = 1.0
	var caption := ("World %d" % n) if kind == "W" else ("Arena %d" % n)
	var sub := String(Campaign.LEVEL_NAMES[n]) if kind == "W" else String(Campaign.ARENA_NAMES[n])
	ScreenTransition.change_scene(path, caption, sub, 0.3)


func _on_checkpoint() -> void:
	var p := _player()
	var cps := get_tree().get_nodes_in_group(&"checkpoint")
	if p == null or cps.is_empty():
		_say("No checkpoints in this scene.")
		return
	_checkpoint_idx = (_checkpoint_idx + 1) % cps.size()
	var cp := cps[_checkpoint_idx]
	p.teleport_to(cp.get_respawn_transform())
	p.set_mode(Player.Mode.EXPLORE)
	_say("Teleported to %s" % String(cp.get("checkpoint_id")))


func _on_reset_puzzle() -> void:
	var p := _player()
	var count := 0
	for n in get_tree().get_nodes_in_group(&"resettable"):
		if not n.has_method(&"reset_to_checkpoint"):
			continue
		var n3 := n as Node3D
		if p != null and n3 != null and n3.global_position.distance_to(p.global_position) > puzzle_reset_radius:
			continue
		n.reset_to_checkpoint()
		count += 1
	_say("Reset %d nearby puzzle parts." % count)


func _on_return_parts() -> void:
	var p := _player()
	if p == null:
		return
	var head := p.get_node_or_null("HeadController")
	if head != null and head.has_method(&"reset_to_attached"):
		head.reset_to_attached()
	var arm := p.get_node_or_null("FetchArm")
	if arm != null and arm.has_method(&"cancel_now"):
		arm.cancel_now()
	_say("Head and arm returned.")


func _on_invuln(on: bool) -> void:
	var p := _player()
	if p != null:
		p.debug_invulnerable = on
	_say("Invulnerable: %s" % ("on" if on else "off"))


func _on_fly(on: bool) -> void:
	var p := _player()
	if p == null:
		_fly.set_pressed_no_signal(false)
		_say("No robot in this scene.")
		return
	p.set_debug_fly(on)
	_say("Fly mode: %s (Jump rises, C / Ctrl sinks, Sprint is fast)" % ("on" if on else "off"))


## Lands the robot on solid ground a few metres from the flag, facing it (tries eight directions around it).
func _on_flag() -> void:
	var p := _player()
	var flag: FinishFlag = null
	for n in get_tree().get_nodes_in_group(&"goal_target"):
		if n is FinishFlag:
			flag = n
	if p == null or flag == null:
		_say("No flag in this scene (worlds only).")
		return
	var fpos := flag.global_position
	var away := p.global_position - fpos
	away.y = 0.0
	var start_ang := atan2(away.x, away.z) if away.length() > 0.1 else 0.0
	var space := flag.get_world_3d().direct_space_state
	for i in 8:
		for dist: float in [5.0, 3.5]:
			var a := start_ang + i * TAU / 8.0
			var spot := fpos + Vector3(sin(a), 0.0, cos(a)) * dist
			var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 4.0, spot + Vector3.DOWN * 6.0, 1)
			var hit := space.intersect_ray(q)
			if hit.is_empty() or absf((hit["position"] as Vector3).y - fpos.y) > 1.5:
				continue
			var land: Vector3 = hit["position"]
			var to_flag := fpos - land
			p.set_debug_fly(false)
			_fly.set_pressed_no_signal(false)
			p.teleport_to(Transform3D(Basis(), land + Vector3.UP * 0.1), atan2(to_flag.x, to_flag.z))
			p.set_mode(Player.Mode.EXPLORE)
			close()
			_say("Next to the flag.")
			return
	p.teleport_to(Transform3D(Basis(), fpos + Vector3.UP * 0.5))
	close()


func _on_arena_win() -> void:
	var ad := get_tree().get_first_node_in_group(&"arena_director")
	if ad == null:
		_say("Not in an arena.")
		return
	if ad.debug_complete():
		close()
	else:
		_say("This arena is already over.")


func _on_lab() -> void:
	close()
	var lab := get_node_or_null("/root/LightingLab")
	if lab and lab.has_method(&"open"):
		lab.open()
	else:
		_say("Lighting lab not available.")


func _on_unlock(on: bool) -> void:
	Campaign.debug_unlocked = on
	Campaign.progress_changed.emit()
	_say("All worlds unlocked: %s" % ("on" if on else "off"))


func _on_speed(factor: float) -> void:
	Engine.time_scale = factor
	_refresh_speed()
	_say("Local speed %dx" % int(factor))


func _refresh_speed() -> void:
	for b in _speed_buttons:
		(b as Button).set_pressed_no_signal(is_equal_approx(float(String(b.name).trim_prefix("Speed")), Engine.time_scale))


func _on_erase_yes() -> void:
	_confirm_row.visible = false
	Campaign.erase_progress()
	Campaign.debug_unlocked = false
	Engine.time_scale = 1.0
	_say("Save erased.")
	close()
	get_tree().paused = false
	ScreenTransition.change_scene(Campaign.TITLE_SCENE, "", "", 0.1, 0.25, 0.4)
