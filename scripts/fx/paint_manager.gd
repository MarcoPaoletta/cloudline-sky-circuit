class_name PaintManager
extends Node3D
## Pooled paint service for a world or arena (group `paint_manager`). Keeps only the impact-to-surface-spawn
## path of the reference module: ray to the real floor/prop, droplet burst, eased splat pop, fade, wet sound.
## Pools: 96 decal marks, 96 flat splats, 24 burst slots; the oldest mark is recycled when full (never fails silently).
## v2: flat ground gets a flat splat quad (PaintSplat) instead of a Decal. The Mobile renderer applies at most 8
## decals to one mesh, and an arena floor is one mesh carrying 14 dirt decals, so arena paint never showed. Slopes
## and island edges (where a quad would hang in the air) still get the wrapping Decal.

const PALETTE: Array[Color] = [
	Color("#22d3ee"), # 0 cyan
	Color("#ff5d73"), # 1 coral
	Color("#ffd23f"), # 2 yellow
	Color("#b36bff"), # 3 violet
]
const WET := [&"splat_1", &"splat_2", &"splat_3"]

@export var min_radius: float = 0.65
@export var max_radius: float = 0.9
@export var boss_radius: float = 2.0
@export var sfx_interval: float = 0.045
## > 0 overrides how long a mark stays vivid (arenas keep their paint longer so the floor fills with color).
@export var mark_hold_time: float = 0.0

@onready var _decals: Array[Node] = $Decals.get_children()
@onready var _bursts: Array[Node] = $Bursts.get_children()
@onready var _splats: Array[Node] = $Splats.get_children()

var _next_decal: int = 0
var _next_burst: int = 0
var _next_splat: int = 0
var flat_marks: int = 0
var _last_sfx: float = 0.0
var live_marks: int = 0
var total_splashes: int = 0
var peak_live: int = 0


func _ready() -> void:
	add_to_group(&"paint_manager")


func palette_color(id: int) -> Color:
	return PALETTE[posmod(id, PALETTE.size())]


## Defeat splash at a world position. Finds the real floor/prop beneath (world-only ray), spawns the burst,
## the surface mark and the wet sound. With no surface below it plays an air burst only (no floating stain).
func enemy_splash(pos: Vector3, color_id: int, size_scale: float = 1.0, _dir: Vector3 = Vector3.ZERO) -> void:
	var col := palette_color(color_id)
	var hit := _surface_below(pos)
	total_splashes += 1
	if hit.is_empty():
		_burst(pos, Vector3.UP, col, 0.6)
		_wet(0.6)
		return
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	_burst(point, normal, col, 1.0)
	_mark(point, normal, col, randf_range(min_radius, max_radius) * size_scale, hit.get("collider"))
	_wet(1.0)


## Larger authored boss splash (radius 2 m, slower pop is handled by the larger size).
func boss_splash(pos: Vector3, color_id: int) -> void:
	var col := palette_color(color_id)
	var hit := _surface_below(pos)
	if hit.is_empty():
		return
	var point: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]
	for i in 3:
		_burst(point + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)), normal, col, 1.0)
	_mark(point, normal, col, boss_radius, hit.get("collider"))
	_wet(1.0)
	_wet(1.0)


func _surface_below(pos: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.6, pos + Vector3.DOWN * 4.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(q)


func _mark(point: Vector3, normal: Vector3, col: Color, radius: float, collider: Object) -> void:
	var carrier := collider as Node3D if collider is AnimatableBody3D else null
	if _is_flat(point, normal, radius * 1.4):
		var sp := _splats[_next_splat] as PaintSplat
		_next_splat = (_next_splat + 1) % _splats.size()
		if mark_hold_time > 0.0:
			sp.hold_time = mark_hold_time
		sp.activate(point, normal, col, radius, randi(), carrier)
		flat_marks += 1
	else:
		var d := _decals[_next_decal] as PaintDecal
		_next_decal = (_next_decal + 1) % _decals.size()
		if mark_hold_time > 0.0:
			d.hold_time = mark_hold_time
		d.activate(point, normal, col, radius, randi(), carrier)
	live_marks = 0
	for x in _decals:
		if (x as PaintDecal).in_use:
			live_marks += 1
	for x in _splats:
		if (x as PaintSplat).in_use:
			live_marks += 1
	peak_live = maxi(peak_live, live_marks)


## True when the ground is level under the whole splat: an upward normal and four rim rays that land within
## 6 cm of the centre height (a rim ray that misses means an island edge, where only a Decal can wrap).
func _is_flat(point: Vector3, normal: Vector3, half: float) -> bool:
	if normal.y < 0.94:
		return false
	var space := get_world_3d().direct_space_state
	for o in [Vector3(half, 0, 0), Vector3(-half, 0, 0), Vector3(0, 0, half), Vector3(0, 0, -half)]:
		var q := PhysicsRayQueryParameters3D.create(point + o + Vector3.UP * 0.5, point + o + Vector3.DOWN * 0.5, 1)
		var hit := space.intersect_ray(q)
		if hit.is_empty() or absf((hit["position"] as Vector3).y - point.y) > 0.06:
			return false
	return true


func _burst(point: Vector3, normal: Vector3, col: Color, ratio: float) -> void:
	var b := _bursts[_next_burst] as PaintBurst
	_next_burst = (_next_burst + 1) % _bursts.size()
	b.play_at(point, normal, col, ratio)


func _wet(volume_scale: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - _last_sfx < sfx_interval:
		return
	_last_sfx = now
	var a := get_node_or_null("/root/Audio")
	if a:
		a.play_variant(&"wet", WET, -5.0 - (1.0 - volume_scale) * 6.0, 0.08)
