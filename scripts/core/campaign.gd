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

# --- Settings (persisted) ---
var mouse_sensitivity: float = 1.0
var invert_y: bool = false
var aim_assist: bool = true
var hold_to_aim: bool = true
var text_scale: float = 1.0
var instant_text: bool = false
var reduced_motion: bool = false
var reduced_flash: bool = false
var shake_scale: float = 1.0
var no_recoil: bool = false
var vol_master: float = 0.9
var vol_sfx: float = 1.0
var vol_ui: float = 1.0
var vol_ambience: float = 1.0

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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()
	apply_audio_settings()


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


## Banks the flag result. Returns true when this was the first capture (reward is not repeatable).
func capture_flag(level: int, time_s: float) -> bool:
	var d := _level(level)
	var first: bool = not bool(d["flag"])
	d["flag"] = true
	var best: float = float(d["best_time"])
	if best <= 0.0 or time_s < best:
		d["best_time"] = time_s
	pending_arena = level if not bool(d["arena"]) else 0
	last_level = level
	save_game()
	progress_changed.emit()
	return first


func clear_arena(level: int) -> void:
	var d := _level(level)
	d["arena"] = true
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


func notify_settings_changed() -> void:
	apply_audio_settings()
	settings_changed.emit()
	save_game()


# ---------------- Save / load ----------------

func save_game() -> void:
	var data := {
		"version": 1,
		"settings": {
			"mouse_sensitivity": mouse_sensitivity, "invert_y": invert_y, "aim_assist": aim_assist,
			"hold_to_aim": hold_to_aim, "text_scale": text_scale, "instant_text": instant_text,
			"reduced_motion": reduced_motion, "reduced_flash": reduced_flash, "shake_scale": shake_scale,
			"no_recoil": no_recoil, "vol_master": vol_master, "vol_sfx": vol_sfx, "vol_ui": vol_ui,
			"vol_ambience": vol_ambience,
		},
		"levels": levels,
		"pending_arena": pending_arena,
		"campaign_complete": campaign_complete,
		"last_level": last_level,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Campaign: cannot write %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Campaign: save file is corrupt, starting fresh")
		return
	var data: Dictionary = parsed
	var s: Dictionary = data.get("settings", {})
	mouse_sensitivity = float(s.get("mouse_sensitivity", mouse_sensitivity))
	invert_y = bool(s.get("invert_y", invert_y))
	aim_assist = bool(s.get("aim_assist", aim_assist))
	hold_to_aim = bool(s.get("hold_to_aim", hold_to_aim))
	text_scale = float(s.get("text_scale", text_scale))
	instant_text = bool(s.get("instant_text", instant_text))
	reduced_motion = bool(s.get("reduced_motion", reduced_motion))
	reduced_flash = bool(s.get("reduced_flash", reduced_flash))
	shake_scale = float(s.get("shake_scale", shake_scale))
	no_recoil = bool(s.get("no_recoil", no_recoil))
	vol_master = float(s.get("vol_master", vol_master))
	vol_sfx = float(s.get("vol_sfx", vol_sfx))
	vol_ui = float(s.get("vol_ui", vol_ui))
	vol_ambience = float(s.get("vol_ambience", vol_ambience))
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
	pending_arena = int(data.get("pending_arena", 0))
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
