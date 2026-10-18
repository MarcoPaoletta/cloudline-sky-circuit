extends Node
## Campaign autoload: settings, progress and the save file (user://cloudline_save.json).
##
## One small state holder, no event bus. Flag progress and arena progress are separate fields
## (GDD 20.1) so a flag can never be farmed twice and Retry Arena never touches the platform world.
## Mute is deliberately NOT stored here: every launch boots muted.

signal settings_changed
signal coins_changed(total_run: int)
signal progress_changed

const SAVE_PATH := "user://cloudline_save.json"
const LEVEL_COUNT := 3
const LEVEL_SCENES := {
	1: "res://scenes/levels/level_1.tscn",
	2: "res://scenes/levels/level_2.tscn",
	3: "res://scenes/levels/level_3.tscn",
}
const ARENA_SCENES := {
	1: "res://scenes/arenas/arena_1.tscn",
	2: "res://scenes/arenas/arena_2.tscn",
	3: "res://scenes/arenas/arena_3.tscn",
}
const LEVEL_NAMES := {1: "Sunrise Junction", 2: "Cargo Gardens", 3: "Crown Circuit"}
const ARENA_NAMES := {1: "Opening Burst", 2: "The Summoner", 3: "Twin Paintstorm"}
const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
## Actions the player may remap (keyboard / mouse). Pause, mute and the debug panel stay fixed.
const REBINDABLE: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"head_deploy", &"head_attack",
	&"aim_assist", &"fetch", &"interact", &"console_left", &"console_right",
]
const ACTION_LABELS := {
	&"move_forward": "Move forward", &"move_back": "Move back", &"move_left": "Move left", &"move_right": "Move right",
	&"jump": "Jump", &"sprint": "Sprint (hold)", &"head_deploy": "Send / recall head", &"head_attack": "Bowl head", &"aim_assist": "Aim assist (hold)",
	&"fetch": "Fetch arm", &"interact": "Interact / dialogue", &"console_left": "Console: step left",
	&"console_right": "Console: step right",
}

# --- Settings (persisted) ---
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var aim_assist: bool = true
var hold_to_aim: bool = true
## Comfort: holding the bowl button repeats the throw on each reattachment (each roll keeps its full gesture).
var hold_to_bowl: bool = true
var text_scale: float = 1.0
var instant_text: bool = false
## Show the on-screen touch controls even without a touchscreen (v3; they always show on touch devices).
var touch_always: bool = false
var reduced_motion: bool = false
var reduced_flash: bool = false
var shake_scale: float = 1.0
var no_recoil: bool = false
var vol_master: float = 0.9
var vol_sfx: float = 1.0
var vol_ui: float = 1.0
var vol_ambience: float = 1.0
var vol_music: float = 1.0
## action name -> {"t": "key" | "mouse", "c": physical keycode | button index}. Only overrides are stored.
var bindings: Dictionary = {}

# --- Progress (persisted) ---
## level -> {flag: bool, arena: bool, best_time: float, coins: Array[String], gems: Array[String]}
var levels: Dictionary = {}
## 0 = none; otherwise the arena that is waiting to be played (flag already captured).
var pending_arena: int = 0
var campaign_complete: bool = false
var last_level: int = 1

# --- Run state (volatile) ---
var current_level: int = 1
var run_coins: int = 0
var run_gems: int = 0
var run_time: float = 0.0
var checkpoint_id: StringName = &""
var seen_dialogue: Dictionary = {}
## Ids collected during THIS run (a fresh run restores every pickup; records keep the union).
var run_collected: Dictionary = {}
var debug_unlocked: bool = false
## Set by Retry Arena so the retried arena says its line (never restarts the platform world).
var arena_retry_pending: bool = false
## One-shot hint for the title screen: which panel to open first ("complete" after the final results).
var title_view: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	apply_audio_settings()
	apply_bindings()


## Bank progress when the window closes or the app goes to the background (tablets can kill a backgrounded app).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_game()


func _level(n: int) -> Dictionary:
	if not levels.has(n):
		levels[n] = {"flag": false, "arena": false, "best_time": 0.0, "coins": [], "gems": []}
	return levels[n]


# ---------------- Progress queries ----------------

func is_level_unlocked(n: int) -> bool:
	if n <= 1 or debug_unlocked:
		return true
	return bool(_level(n - 1)["flag"]) and bool(_level(n - 1)["arena"])


func has_flag(n: int) -> bool:
	return bool(_level(n)["flag"])


func has_arena_cleared(n: int) -> bool:
	return bool(_level(n)["arena"])


func best_time(n: int) -> float:
	return float(_level(n)["best_time"])


func has_collected(n: int, id: String) -> bool:
	return run_collected.has("%d:%s" % [n, id])


## Total banked coins across levels.
func banked_coins() -> int:
	var t := 0
	for n in levels:
		t += (levels[n]["coins"] as Array).size()
	return t


func banked_gems() -> int:
	var t := 0
	for n in levels:
		t += (levels[n]["gems"] as Array).size()
	return t


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## True once any flag was captured, any arena cleared or an arena is waiting (the title shows Continue / Worlds).
func has_progress() -> bool:
	if pending_arena > 0 or campaign_complete:
		return true
	for n in levels:
		if bool(levels[n]["flag"]) or bool(levels[n]["arena"]):
			return true
	return false


## Where "Continue" should go: the pending arena, or the first level whose flag is not captured.
func continue_target() -> Dictionary:
	if pending_arena > 0:
		return {"kind": "arena", "n": pending_arena}
	for n in range(1, LEVEL_COUNT + 1):
		if not has_flag(n):
			return {"kind": "level", "n": n}
	return {"kind": "level", "n": clampi(last_level, 1, LEVEL_COUNT)}


# ---------------- Run mutations ----------------

func begin_run(level: int) -> void:
	current_level = level
	last_level = level
	run_coins = 0
	run_gems = 0
	run_time = 0.0
	checkpoint_id = &""
	seen_dialogue.clear()
	run_collected.clear()


func add_coin(level: int, id: String, value: int = 1) -> bool:
	var key := "%d:%s" % [level, id]
	if run_collected.has(key):
		return false
	run_collected[key] = true
	var d := _level(level)
	if not d["coins"].has(id):
		d["coins"].append(id)
	run_coins += value
	coins_changed.emit(run_coins)
	return true


func add_gem(level: int, id: String) -> bool:
	var key := "%d:%s" % [level, id]
	if run_collected.has(key):
		return false
	run_collected[key] = true
	var d := _level(level)
	if not d["gems"].has(id):
		d["gems"].append(id)
	run_gems += 1
	progress_changed.emit()
	return true


## Debug / reward grant: raises the run total with normal HUD feedback but records no collectible id.
func grant_coins(amount: int) -> void:
	run_coins += amount
	coins_changed.emit(run_coins)


## Banks the flag result. Returns true when this was the first capture (reward is not repeatable).
func capture_flag(level: int, time_s: float) -> bool:
	var d := _level(level)
	var first: bool = not bool(d["flag"])
	d["flag"] = true
	var best: float = float(d["best_time"])
	if best <= 0.0 or time_s < best:
		d["best_time"] = time_s
	if not bool(d["arena"]):
		pending_arena = level
	last_level = level
	save_game()
	progress_changed.emit()
	return first


func clear_arena(level: int) -> void:
	var d := _level(level)
	d["arena"] = true
	if pending_arena == level:
		pending_arena = 0
	if level >= LEVEL_COUNT:
		campaign_complete = true
	else:
		last_level = level + 1
	save_game()
	progress_changed.emit()


func mark_dialogue(id: StringName, text: String = "") -> void:
	seen_dialogue[id] = text


func has_seen(id: StringName) -> bool:
	return seen_dialogue.has(id)


# ---------------- Settings ----------------

func apply_audio_settings() -> void:
	var audio := get_node_or_null("/root/Audio")
	if audio == null:
		return
	audio.set_bus_linear(&"Master", vol_master)
	audio.set_bus_linear(&"SFX", vol_sfx)
	audio.set_bus_linear(&"UI", vol_ui)
	audio.set_bus_linear(&"Ambience", vol_ambience)
	audio.set_bus_linear(&"Music", vol_music)


func notify_settings_changed() -> void:
	apply_audio_settings()
	settings_changed.emit()
	save_game()


# ---------------- Key bindings ----------------

func apply_bindings() -> void:
	for a in bindings:
		var rec: Variant = bindings[a]
		if rec is Dictionary:
			_apply_binding(StringName(a), rec)
	_sync_console_exit()


## Console exit always follows the Interact key (plus Escape), so the console strip never lies.
func _sync_console_exit() -> void:
	var ie := primary_event(&"interact")
	if ie == null or not InputMap.has_action(&"console_exit"):
		return
	for ev in InputMap.action_get_events(&"console_exit"):
		if ev is InputEventKey or ev is InputEventMouseButton:
			InputMap.action_erase_event(&"console_exit", ev)
	InputMap.action_add_event(&"console_exit", ie.duplicate())
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	InputMap.action_add_event(&"console_exit", esc)


func _apply_binding(action: StringName, rec: Dictionary) -> void:
	if not InputMap.has_action(action):
		return
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			InputMap.action_erase_event(action, ev)
	var ne: InputEvent
	if String(rec.get("t", "key")) == "mouse":
		var m := InputEventMouseButton.new()
		m.button_index = int(rec.get("c", 1)) as MouseButton
		ne = m
	else:
		var k := InputEventKey.new()
		k.physical_keycode = int(rec.get("c", 0)) as Key
		ne = k
	InputMap.action_add_event(action, ne)


func _record_of(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"t": "key", "c": int((ev as InputEventKey).physical_keycode)}
	if ev is InputEventMouseButton:
		return {"t": "mouse", "c": int((ev as InputEventMouseButton).button_index)}
	return {}


## The keyboard / mouse event currently bound to the action (null when none).
func primary_event(action: StringName) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey or ev is InputEventMouseButton:
			return ev
	return null


## Short readable name of the action's key, for prompts, dialogue and the controls list.
func key_text(action: StringName) -> String:
	if TouchPad.touch_mode and TouchPad.LABELS.has(action):
		return String(TouchPad.LABELS[action])
	var ev := primary_event(action)
	if ev is InputEventKey:
		var code: Key = (ev as InputEventKey).physical_keycode
		# The editor-embedded display server has no keyboard layout lookup (it errors on every call).
		var kc: Key = KEY_NONE
		if DisplayServer.get_name() != "embedded" and DisplayServer.get_name() != "headless":
			kc = DisplayServer.keyboard_get_keycode_from_physical(code)
		var t := OS.get_keycode_string(kc if kc != KEY_NONE else code)
		return t if t != "" else "?"
	if ev is InputEventMouseButton:
		match (ev as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				return "LMB"
			MOUSE_BUTTON_RIGHT:
				return "RMB"
			MOUSE_BUTTON_MIDDLE:
				return "MMB"
		return "Mouse %d" % (ev as InputEventMouseButton).button_index
	return "-"


## Rebinds an action to a key / mouse button. A key already used by another rebindable action is swapped so
## no two actions ever share one key. Returns the other action that was swapped, or &"".
func set_binding(action: StringName, event: InputEvent) -> StringName:
	var rec := _record_of(event)
	if rec.is_empty() or not REBINDABLE.has(action):
		return &""
	var swapped: StringName = &""
	var old := primary_event(action)
	for other in REBINDABLE:
		if other == action:
			continue
		var oe := primary_event(other)
		if oe != null and _record_of(oe) == rec:
			swapped = other
			if old != null:
				var old_rec := _record_of(old)
				bindings[String(other)] = old_rec
				_apply_binding(other, old_rec)
			break
	bindings[String(action)] = rec
	_apply_binding(action, rec)
	_sync_console_exit()
	save_game()
	settings_changed.emit()
	return swapped


func reset_bindings() -> void:
	bindings.clear()
	InputMap.load_from_project_settings()
	save_game()
	settings_changed.emit()


# ---------------- Save / load ----------------

func save_game() -> void:
	var data := {
		"version": 1,
		"settings": {
			"mouse_sensitivity": mouse_sensitivity, "invert_y": invert_y, "aim_assist": aim_assist,
			"hold_to_aim": hold_to_aim, "hold_to_bowl": hold_to_bowl, "text_scale": text_scale, "instant_text": instant_text, "touch_always": touch_always,
			"reduced_motion": reduced_motion, "reduced_flash": reduced_flash, "shake_scale": shake_scale,
			"no_recoil": no_recoil, "vol_master": vol_master, "vol_sfx": vol_sfx, "vol_ui": vol_ui,
			"vol_ambience": vol_ambience, "vol_music": vol_music,
		},
		"bindings": bindings,
		"levels": levels,
		"pending_arena": pending_arena,
		"campaign_complete": campaign_complete,
		"last_level": last_level,
	}
	# Write a temp file first and swap it in, so a kill mid-write can never leave a truncated save; keep one backup.
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Campaign: cannot write %s (error %d)" % [tmp, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.copy_absolute(SAVE_PATH, SAVE_PATH + ".bak")
		DirAccess.remove_absolute(SAVE_PATH)
	if DirAccess.rename_absolute(tmp, SAVE_PATH) != OK:
		push_warning("Campaign: could not replace %s" % SAVE_PATH)


func _read_save(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func load_game() -> void:
	var parsed: Variant = _read_save(SAVE_PATH)
	if typeof(parsed) != TYPE_DICTIONARY:
		parsed = _read_save(SAVE_PATH + ".bak")
		if typeof(parsed) == TYPE_DICTIONARY:
			push_warning("Campaign: save file was unreadable, restored the backup")
	if typeof(parsed) != TYPE_DICTIONARY:
		if FileAccess.file_exists(SAVE_PATH):
			push_warning("Campaign: save file is corrupt, starting fresh")
		return
	var data: Dictionary = parsed
	var s: Dictionary = data.get("settings", {})
	mouse_sensitivity = float(s.get("mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(s.get("invert_y", invert_y))
	aim_assist = bool(s.get("aim_assist", aim_assist))
	hold_to_aim = bool(s.get("hold_to_aim", hold_to_aim))
	hold_to_bowl = bool(s.get("hold_to_bowl", hold_to_bowl))
	text_scale = float(s.get("text_scale", text_scale))
	instant_text = bool(s.get("instant_text", instant_text))
	touch_always = bool(s.get("touch_always", touch_always))
	reduced_motion = bool(s.get("reduced_motion", reduced_motion))
	reduced_flash = bool(s.get("reduced_flash", reduced_flash))
	shake_scale = float(s.get("shake_scale", shake_scale))
	no_recoil = bool(s.get("no_recoil", no_recoil))
	vol_master = float(s.get("vol_master", vol_master))
	vol_sfx = float(s.get("vol_sfx", vol_sfx))
	vol_ui = float(s.get("vol_ui", vol_ui))
	vol_ambience = float(s.get("vol_ambience", vol_ambience))
	vol_music = float(s.get("vol_music", vol_music))
	bindings.clear()
	var bd: Variant = data.get("bindings", {})
	if bd is Dictionary:
		for a in bd:
			if bd[a] is Dictionary and REBINDABLE.has(StringName(a)):
				bindings[String(a)] = {"t": String(bd[a].get("t", "key")), "c": int(bd[a].get("c", 0))}
	levels.clear()
	var lv: Dictionary = data.get("levels", {})
	for key in lv:
		var n := int(key)
		var d: Dictionary = lv[key]
		levels[n] = {
			"flag": bool(d.get("flag", false)), "arena": bool(d.get("arena", false)),
			"best_time": float(d.get("best_time", 0.0)),
			"coins": Array(d.get("coins", [])), "gems": Array(d.get("gems", [])),
		}
	var pa := int(data.get("pending_arena", 0))
	pending_arena = pa if pa >= 1 and pa <= LEVEL_COUNT else 0
	campaign_complete = bool(data.get("campaign_complete", false))
	last_level = clampi(int(data.get("last_level", 1)), 1, LEVEL_COUNT)


## Erase Save / Start Over: clears progress but keeps comfort settings.
func erase_progress() -> void:
	levels.clear()
	pending_arena = 0
	campaign_complete = false
	last_level = 1
	run_coins = 0
	seen_dialogue.clear()
	save_game()
	progress_changed.emit()
	coins_changed.emit(0)
