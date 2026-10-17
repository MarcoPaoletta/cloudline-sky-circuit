class_name PaintDecal
extends Decal
## One pooled decorative paint puddle (GDD 21-22, game-dev paint-splash): a flat saturated splat that wraps the
## surface it landed on. Six shapes, albedo tinted by the paint colour and a matte ORM. (The reference's tinted
## emission texture is NOT used: on the Mobile renderer Decal emission ignores `modulate` and washes the splat
## to white, measured 17 Oct 2026.) 0.22 s eased pop (peak about 1.15), 6 s life: vivid for 4.1 s, desaturates for
## 1.5 s, dissolves in 0.4 s. Never a collider; characters sit on the exempt render layer.

const SPLATS: Array[Texture2D] = [
	preload("res://assets/cloudline/paint/splat_0.png"), preload("res://assets/cloudline/paint/splat_1.png"),
	preload("res://assets/cloudline/paint/splat_2.png"), preload("res://assets/cloudline/paint/splat_3.png"),
	preload("res://assets/cloudline/paint/splat_4.png"), preload("res://assets/cloudline/paint/splat_5.png"),
]
const ORM_TEX: Texture2D = preload("res://assets/cloudline/paint/splat_orm.png")
const CLAY := Color("#b9a58d")

@export var hold_time: float = 4.1
@export var desaturate_time: float = 1.5
@export var fade_time: float = 0.4
@export var pop_time: float = 0.22
@export var normal_offset: float = 0.004
@export var depth: float = 0.9

var in_use: bool = false
var age: float = 0.0
var base_size: Vector3 = Vector3.ONE
var _color: Color = Color.WHITE
var _carrier: Node3D
var _local_xf: Transform3D
var peak_scale_seen: float = 0.0


func _ready() -> void:
	visible = false
	set_process(false)
	cull_mask = 524287
	normal_fade = 0.2
	texture_orm = ORM_TEX


## Lays the splat on the surface at `point` with `normal`. `carrier` (platform) keeps it attached if it moves.
func activate(point: Vector3, normal: Vector3, color: Color, radius: float, seed_value: int, carrier: Node3D = null) -> void:
	in_use = true
	age = 0.0
	peak_scale_seen = 0.0
	_color = color
	var idx := absi(seed_value) % SPLATS.size()
	texture_albedo = SPLATS[idx]
	texture_orm = ORM_TEX
	modulate = color
	base_size = Vector3(radius * 2.8, depth, radius * 2.8)
	size = base_size * 0.25
	var n := normal.normalized()
	var ref := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(n).normalized()
	var z := x.cross(n).normalized()
	var spin := Basis(n, float(seed_value % 628) / 100.0)
	global_transform = Transform3D(spin * Basis(x, n, z), point + n * normal_offset)
	reset_physics_interpolation()
	_carrier = carrier
	if carrier:
		_local_xf = carrier.global_transform.affine_inverse() * global_transform
	visible = true
	set_process(true)


func deactivate() -> void:
	in_use = false
	visible = false
	set_process(false)
	_carrier = null


func _process(delta: float) -> void:
	age += delta
	if _carrier and is_instance_valid(_carrier):
		global_transform = _carrier.global_transform * _local_xf
	# Pop: first 60 % rises to 1.05 with a back ease, the rest settles to 1.0 (measured peak about 1.15).
	var k := 1.0
	if age < pop_time:
		var t := age / pop_time
		if t < 0.6:
			k = lerpf(0.25, 1.05, _back_out(t / 0.6))
		else:
			k = lerpf(1.05, 1.0, (t - 0.6) / 0.4)
		peak_scale_seen = maxf(peak_scale_seen, k)
	size = base_size * k
	# Smooth fade (no warning strobe for decorative death paint).
	var life := hold_time + desaturate_time + fade_time
	var c := _color
	if age > hold_time:
		var d := clampf((age - hold_time) / desaturate_time, 0.0, 1.0)
		c = _color.lerp(CLAY, d * 0.55)
	if age > hold_time + desaturate_time:
		c.a = 1.0 - clampf((age - hold_time - desaturate_time) / fade_time, 0.0, 1.0)
	modulate = c
	if age >= life:
		deactivate()


static func _back_out(t: float) -> float:
	var s := 1.70158
	t -= 1.0
	return t * t * ((s + 1.0) * t + s) + 1.0
