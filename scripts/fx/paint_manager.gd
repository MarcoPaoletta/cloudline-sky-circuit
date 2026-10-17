class_name PaintManager
extends Node3D
## Pooled paint service for a world or arena (group `paint_manager`). Keeps only the impact-to-surface-spawn
## path of the reference module: ray to the real floor/prop, droplet burst, eased splat pop, fade, wet sound.
## Pools: 96 live surface marks, 24 burst slots; the oldest mark is recycled when full (never fails silently).

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

@onready var _decals: Array[Node] = $Decals.get_children()
@onready var _bursts: Array[Node] = $Bursts.get_children()

var _next_decal: int = 0
var _next_burst: int = 0
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
	var d := _decals[_next_decal] as PaintDecal
	_next_decal = (_next_decal + 1) % _decals.size()
	var carrier := collider as Node3D if collider is AnimatableBody3D else null
	d.activate(point, normal, col, radius, randi(), carrier)
	live_marks = 0
	for x in _decals:
		if (x as PaintDecal).in_use:
			live_marks += 1
	peak_live = maxi(peak_live, live_marks)


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
