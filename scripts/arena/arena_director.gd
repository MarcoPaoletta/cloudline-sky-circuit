class_name ArenaDirector
extends Node3D
## One circular arena finale (GDD 20, 21). Coordinates the ready beat, three gradual portal waves, summons,
## bosses, victory and defeat. Enemies are NEVER released as a batch: births are metered in small staggered
## groups (at most `max_per_tick` per `spawn_tick`), every portal warms for 0.4 s and marks its landing, nothing
## spawns within `safe_radius` of the player, and births pause while the active cap is reached then catch up
## gradually. Boss death cancels its future summons; only already-born monsters remain.

signal wave_started(index: int, total: int)
signal counts_changed(alive: int, unreleased: int)
signal chain_changed(chain: int)
signal victory_reached
signal defeat_reached

const ENEMY_PATHS: Array[String] = [
	"res://scenes/enemies/cactus_horde.tscn",
	"res://scenes/enemies/mushroom_horde.tscn",
	"res://scenes/enemies/alien_horde.tscn",
	"res://scenes/enemies/cyclops_horde.tscn",
]
const RESULTS_SCENE := "res://scenes/ui/level_results.tscn"

@export_group("Arena")
@export var arena_number: int = 1
@export var arena_title: String = "Opening Burst"
@export var arena_subtitle: String = "THREE QUICK WAVES"
@export var ready_time: float = 1.0
@export var framing_distance: float = 6.8
@export var framing_fov: float = 65.0
@export var framing_height: float = 1.4
@export_group("Waves")
@export var wave_counts: PackedInt32Array = PackedInt32Array([60, 60, 60])
@export var wave_starts: PackedFloat32Array = PackedFloat32Array([0.0, 11.0, 22.0])
@export var wave_durations: PackedFloat32Array = PackedFloat32Array([9.0, 9.0, 9.0])
@export var active_cap: int = 80
@export var spawn_tick: float = 0.3
@export var max_per_tick: int = 3
@export var safe_radius: float = 6.0
## Horde monsters never leave this radius (a metre inside the floor rim; set per arena).
@export var horde_radius: float = 23.0
@export var summon_speed_scale: float = 1.0
@export_group("Crowd")
## Ground distance below which two monsters are pushed apart, so no body ever clips another.
@export var separation_distance: float = 1.75
## Horde monsters keep this distance from a boss's centre; the two bosses keep `boss_separation` from each other.
@export var boss_clearance: float = 3.3
@export var boss_separation: float = 3.6
## Largest correction applied to one body per physics frame (keeps the relaxation smooth).
@export var max_push_per_frame: float = 0.3
@export_group("Assists")
## One pip returns after this many seconds without taking damage.
@export var regen_seconds: float = 8.0
## A bowling chain this long restores one pip (once per `chain_heal_cooldown`).
@export var chain_heal_at: int = 10
@export var chain_heal_cooldown: float = 6.0

@onready var _horde: Node3D = %Horde
@onready var _player: Player = %Player
@onready var _hud: ArenaHud = %ArenaHud
@onready var _spawn: Marker3D = %PlayerSpawn

enum Phase { READY, FIGHT, VICTORY, DEFEAT }

var phase: int = Phase.READY
var alive_count: int = 0
var pending_births: int = 0
var peak_alive: int = 0
var total_born: int = 0
var fight_time: float = 0.0
var best_chain: int = 0
var boss_list: Array[YetiBoss] = []
var bosses_alive: int = 0
var released: PackedInt32Array = PackedInt32Array()
var kills: int = 0

var _packed: Array[PackedScene] = []
var _clock: float = 0.0
var _tick: float = 0.0
var _portal_cursor: int = 0
var _summon_backlog: int = 0
var _started_waves: int = 0
var _announced: Dictionary = {}
var _chain_hold: float = 0.0
var _chain: int = 0
var _wave_shift: float = 0.0
var _boss_started: bool = false
var _since_hurt: float = 0.0
var _chain_heal_cd: float = 0.0


func _ready() -> void:
	add_to_group(&"arena_director")
	LightingPreset.apply_to(self)
	var music := get_node_or_null("/root/Audio")
	if music:
		music.play_music(&"arena")
	process_mode = Node.PROCESS_MODE_PAUSABLE
	for path in ENEMY_PATHS:
		_packed.append(load(path) as PackedScene)
	released.resize(wave_counts.size())
	for b in get_tree().get_nodes_in_group(&"boss"):
		if b is YetiBoss:
			boss_list.append(b as YetiBoss)
	bosses_alive = boss_list.size()
	_player.teleport_to(_spawn.global_transform)
	_player.camera_rig().set_framing(framing_distance, framing_fov, framing_height)
	_player.camera_rig().snap_behind(_player.facing_yaw())
	_player.camera_rig().set_capture(true)
	_player.died.connect(_on_player_died)
	_player.hurt.connect(func(_h: int) -> void: _since_hurt = 0.0)
	_player.get_node("HeadController").enemy_hit.connect(_on_head_hit)
	_player.get_node("HeadController").head_launched.connect(func(_d: bool) -> void: _end_chain_soon())
	Campaign.current_level = arena_number
	Campaign.run_time = 0.0
	_hud.configure(self)
	for b in boss_list:
		_hud.add_boss(b)
	_hud.show_banner(arena_subtitle, arena_title, ready_time + 1.0)
	get_tree().call_group(&"dialogue_panel", "say", StringName("arena%d_ready" % arena_number) if arena_number == 1 else (&"boss1_ready" if arena_number == 2 else &"boss2_ready"))
	if Campaign.arena_retry_pending:
		Campaign.arena_retry_pending = false
		get_tree().call_group(&"dialogue_panel", "say", &"arena_retry", true)
	counts_changed.emit(0, _total_unreleased())


## True once the arena is decided (victory or defeat): the pause menu stays closed behind the results.
func is_over() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT


func total_planned() -> int:
	var t := 0
	for c in wave_counts:
		t += c
	return t


func _total_unreleased() -> int:
	var t := 0
	for i in wave_counts.size():
		t += wave_counts[i] - released[i]
	return t


func current_wave_number() -> int:
	return clampi(_started_waves, 1, wave_counts.size())


func _physics_process(delta: float) -> void:
	match phase:
		Phase.READY:
			_clock += delta
			if _clock >= ready_time:
				_begin_fight()
		Phase.FIGHT:
			_run_fight(delta)


func _begin_fight() -> void:
	phase = Phase.FIGHT
	_clock = 0.0
	fight_time = 0.0
	if not _boss_started:
		_boss_started = true
		for b in boss_list:
			b.start_fight()


func _run_fight(delta: float) -> void:
	_clock += delta
	fight_time += delta
	Campaign.run_time = fight_time
	_since_hurt += delta
	_chain_heal_cd = maxf(_chain_heal_cd - delta, 0.0)
	_separate_horde()
	if _since_hurt >= regen_seconds and _player.heal(1):
		_since_hurt = 0.0
	# Early start of the next wave when the field is empty (never sooner than 2 s after the last release).
	for w in range(1, wave_counts.size()):
		var started := _clock >= wave_starts[w] - _wave_shift
		if not started and released[w - 1] >= wave_counts[w - 1] and alive_count == 0 and pending_births == 0:
			_wave_shift = maxf(_wave_shift, wave_starts[w] - _clock)
	_tick += delta
	if _tick >= spawn_tick:
		_tick = 0.0
		_release_tick()
	_chain_hold = maxf(_chain_hold - delta, 0.0)
	if _chain_hold <= 0.0 and _chain > 0:
		_chain = 0
		chain_changed.emit(0)
	if _all_released() and alive_count == 0 and pending_births == 0 and bosses_alive == 0 and _summon_backlog == 0:
		_victory()


## Crowd relaxation on the ground plane: a spatial hash finds every pair closer than `separation_distance` and pushes both
## apart; bosses act as larger discs. Positions only move in x/z, so floor contact and the arena clamp are unaffected.
func _separate_horde() -> void:
	var mons: Array[HordeEnemy] = []
	for c in _horde.get_children():
		var e := c as HordeEnemy
		if e != null and e.active and e.alive:
			mons.append(e)
	var n := mons.size()
	var pos := PackedVector2Array()
	pos.resize(n)
	var push := PackedVector2Array()
	push.resize(n)
	var cell := separation_distance
	var grid := {}
	for i in n:
		var g := mons[i].global_position
		pos[i] = Vector2(g.x, g.z)
		var key := Vector2i(floori(g.x / cell), floori(g.z / cell))
		if grid.has(key):
			(grid[key] as Array).append(i)
		else:
			grid[key] = [i]
	for key: Vector2i in grid:
		var mine: Array = grid[key]
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var nk := Vector2i(key.x + dx, key.y + dz)
				if not grid.has(nk):
					continue
				var theirs: Array = grid[nk]
				for a in mine:
					for b in theirs:
						if b <= a:
							continue
						var d := pos[a] - pos[b]
						var l := d.length()
						if l >= separation_distance:
							continue
						var dir := d / l if l > 0.001 else Vector2.from_angle(float((a * 37 + b * 91) % 360) * 0.0174533)
						var half := (separation_distance - l) * 0.5
						push[a] += dir * half
						push[b] -= dir * half
	for bs in boss_list:
		if not is_instance_valid(bs) or not bs.alive:
			continue
		var bp := Vector2(bs.global_position.x, bs.global_position.z)
		for i in n:
			var d := pos[i] - bp
			var l := d.length()
			if l < boss_clearance:
				push[i] += (d / l if l > 0.001 else Vector2.RIGHT) * (boss_clearance - l)
	for i in n:
		var p := push[i]
		if p.length_squared() > 0.000001:
			p = p.limit_length(max_push_per_frame)
			mons[i].global_position += Vector3(p.x, 0.0, p.y)
	if boss_list.size() == 2 and is_instance_valid(boss_list[0]) and is_instance_valid(boss_list[1]):
		var b0 := boss_list[0]
		var b1 := boss_list[1]
		var d := Vector2(b0.global_position.x - b1.global_position.x, b0.global_position.z - b1.global_position.z)
		var l := d.length()
		if l < boss_separation and b0.alive and b1.alive:
			var dir := d / l if l > 0.001 else Vector2.RIGHT
			var half := minf((boss_separation - l) * 0.5, 0.2)
			b0.global_position += Vector3(dir.x, 0.0, dir.y) * half
			b1.global_position -= Vector3(dir.x, 0.0, dir.y) * half


func _all_released() -> bool:
	return _total_unreleased() == 0


func _release_tick() -> void:
	var budget := max_per_tick
	# Pending boss summons share the same cap and cadence (never a burst).
	while _summon_backlog > 0 and budget > 0 and alive_count + pending_births < active_cap:
		_summon_backlog -= 1
		budget -= 1
		_spawn_summon_now()
	for w in wave_counts.size():
		var start := wave_starts[w] - _wave_shift
		if _clock < start:
			continue
		if not _announced.has(w):
			_announced[w] = true
			_started_waves = w + 1
			wave_started.emit(w + 1, wave_counts.size())
			if w > 0:
				get_tree().call_group(&"dialogue_panel", "say", &"wave_start", true)
		var target := int(clampf((_clock - start) / maxf(wave_durations[w], 0.1), 0.0, 1.0) * float(wave_counts[w]) + 0.0001)
		if _clock - start >= wave_durations[w]:
			target = wave_counts[w]
		while released[w] < target and budget > 0 and alive_count + pending_births < active_cap:
			released[w] += 1
			budget -= 1
			_queue_portal_birth()
	counts_changed.emit(alive_count + pending_births, _total_unreleased())


func _pick_portal() -> ArenaPortal:
	var portals := get_tree().get_nodes_in_group(&"portal")
	if portals.is_empty():
		return null
	for i in portals.size():
		var idx := (_portal_cursor + i) % portals.size()
		var pt := portals[idx] as ArenaPortal
		if pt.landing_position().distance_to(_player.global_position) >= safe_radius:
			_portal_cursor = idx + 1
			return pt
	return portals[_portal_cursor % portals.size()] as ArenaPortal


func _queue_portal_birth() -> void:
	var pt := _pick_portal()
	if pt == null:
		return
	pending_births += 1
	pt.warm()
	get_tree().create_timer(pt.warm_time).timeout.connect(func() -> void:
		pending_births = maxi(pending_births - 1, 0)
		if phase == Phase.FIGHT or phase == Phase.READY:
			_spawn_enemy(pt.landing_position(), pt.landing_forward()))


func _spawn_enemy(pos: Vector3, face: Vector3) -> HordeEnemy:
	var idx := randi() % _packed.size()
	var e := _packed[idx].instantiate() as HordeEnemy
	e.arena_radius = horde_radius
	_horde.add_child(e)
	e.activate(pos, face)
	alive_count += 1
	total_born += 1
	peak_alive = maxi(peak_alive, alive_count)
	e.defeated.connect(_on_enemy_defeated)
	return e


func _on_enemy_defeated(_e: EnemyBase) -> void:
	alive_count = maxi(alive_count - 1, 0)
	kills += 1
	counts_changed.emit(alive_count + pending_births, _total_unreleased())


## Called by a boss (group call) for each monster of a summon cast.
func request_summon(_boss: YetiBoss) -> void:
	_summon_backlog += 1
	_last_summoner = _boss


var _last_summoner: YetiBoss


func _spawn_summon_now() -> void:
	var b := _last_summoner
	if b == null or not is_instance_valid(b):
		return
	var ang := randf() * TAU
	var pos := b.global_position + Vector3(cos(ang), 0.0, sin(ang)) * 2.8
	pos.y = 0.1
	if Vector2(pos.x, pos.z).length() > 22.0:
		pos = Vector3(pos.x, 0.1, pos.z) * (22.0 / maxf(Vector2(pos.x, pos.z).length(), 0.1))
	var face := (_player.global_position - pos)
	_spawn_enemy(pos, face)
	get_tree().call_group(&"paint_manager", "enemy_splash", pos, 3, 0.55, Vector3.ZERO)


func boss_down(_boss: YetiBoss) -> void:
	bosses_alive = maxi(bosses_alive - 1, 0)
	_summon_backlog = 0
	counts_changed.emit(alive_count + pending_births, _total_unreleased())


func _on_head_hit(_enemy: Node, chain: int) -> void:
	_chain = chain
	best_chain = maxi(best_chain, chain)
	_chain_hold = 2.2
	chain_changed.emit(chain)
	if chain >= chain_heal_at and _chain_heal_cd <= 0.0 and _player.heal(1):
		_chain_heal_cd = chain_heal_cooldown
		_hud.show_banner("CHAIN x%d" % chain, "A pip restored", 1.2)


func _end_chain_soon() -> void:
	_chain_hold = 0.0


func _victory() -> void:
	if phase != Phase.FIGHT:
		return
	phase = Phase.VICTORY
	victory_reached.emit()
	Campaign.clear_arena(arena_number)
	get_tree().call_group(&"dialogue_panel", "say", &"arena_victory", true)
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_sfx(&"arena_victory", -1.0)
	_hud.show_banner("CLEAN SWEEP", "%d monsters, best chain x%d" % [kills, best_chain], 2.4)
	_player.get_node("HeadController").recall()
	await get_tree().create_timer(2.2, true, false, true).timeout
	_player.set_input_enabled(false)
	_player.camera_rig().set_capture(false)
	var results := (load(RESULTS_SCENE) as PackedScene).instantiate()
	_hud.add_child(results)
	results.show_arena_results(self)


func _on_player_died() -> void:
	if phase == Phase.DEFEAT or phase == Phase.VICTORY:
		return
	phase = Phase.DEFEAT
	defeat_reached.emit()
	_player.camera_rig().set_capture(false)
	_hud.show_defeat(self)


## Dev panel (F1) only: every wave counts as released, every monster and boss on the field is defeated (normal
## splash and fall), and the normal victory flow runs (clear saved, banner, results).
func debug_complete() -> bool:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT:
		return false
	if phase == Phase.READY:
		_begin_fight()
	for w in released.size():
		released[w] = wave_counts[w]
	pending_births = 0
	_summon_backlog = 0
	for c in _horde.get_children():
		var e := c as HordeEnemy
		if e != null and e.alive:
			e.take_head_hit(null)
	for b in boss_list:
		if is_instance_valid(b) and b.alive:
			b.health = 1
			b._hit_cd = 0.0
			b.take_head_hit(null)
	bosses_alive = 0
	alive_count = 0
	_victory()
	return true


## Retry Arena restarts THIS arena only; the platform world and its flag are untouched.
func retry_arena() -> void:
	Campaign.arena_retry_pending = true
	ScreenTransition.change_scene(scene_file_path, arena_subtitle, arena_title, 0.2, 0.25, 0.3)
