class_name PaintSplat
extends MeshInstance3D
## One pooled flat paint puddle (v2): the six splat shapes on a quad laid flat on level ground, toon-lit and
## tinted per instance (paint_splat.gdshader). PaintManager uses it wherever the ground under the splat is flat,
## because the Mobile renderer gives each mesh at most 8 decals (the arena floors already carry 14 dirt decals).
## Same life as PaintDecal: 0.22 s eased pop (peak about 1.15), vivid for 4.1 s, desaturates for 1.5 s, dissolves
## in 0.4 s. Lives on the exempt render layer, so no decal (dirt or paint) tints it. Never a collider.

const SPLAT_COUNT := 6
const CLAY := Color("#b9a58d")

@export var hold_time: float = 4.1
@export var desaturate_time: float = 1.5
@export var fade_time: float = 0.4
@export var pop_time: float = 0.22
## Height above the surface (no z-fighting with the floor, still under grass tufts and flowers).
@export var lift: float = 0.014

var in_use: bool = false
var age: float = 0.0
var base_size: float = 1.0
var peak_scale_seen: float = 0.0
var _color: Color = Color.WHITE
var _carrier: Node3D
var _local_xf: Transform3D
var _xf: Transform3D


func _ready() -> void:
	visible = false
	set_process(false)
	layers = 1 << 19
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func activate(point: Vector3, normal: Vector3, color: Color, radius: float, seed_value: int, carrier: Node3D = null) -> void:
	in_use = true
	age = 0.0
	peak_scale_seen = 0.0
	_color = color
	set_instance_shader_parameter(&"splat_idx", float(absi(seed_value) % SPLAT_COUNT))
	set_instance_shader_parameter(&"tint", color)
	base_size = radius * 2.8
	var n := normal.normalized()
	var ref := Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := ref.cross(n).normalized()
	var z := x.cross(n).normalized()
	var spin := Basis(n, float(seed_value % 628) / 100.0)
	_xf = Transform3D(spin * Basis(x, n, z), point + n * lift)
	_carrier = carrier
	if carrier:
		_local_xf = carrier.global_transform.affine_inverse() * _xf
	_apply(0.25)
	reset_physics_interpolation()
	visible = true
	set_process(true)


func deactivate() -> void:
	in_use = false
	visible = false
	set_process(false)
	_carrier = null


func _apply(k: float) -> void:
	var s := base_size * k
	global_transform = Transform3D(_xf.basis * Basis.from_scale(Vector3(s, 1.0, s)), _xf.origin)


func _process(delta: float) -> void:
	age += delta
	if _carrier and is_instance_valid(_carrier):
		_xf = _carrier.global_transform * _local_xf
	var k := 1.0
	if age < pop_time:
		var t := age / pop_time
		if t < 0.6:
			k = lerpf(0.25, 1.05, PaintDecal._back_out(t / 0.6))
		else:
			k = lerpf(1.05, 1.0, (t - 0.6) / 0.4)
		peak_scale_seen = maxf(peak_scale_seen, k)
	_apply(k)
	var c := _color
	if age > hold_time:
		c = _color.lerp(CLAY, clampf((age - hold_time) / desaturate_time, 0.0, 1.0) * 0.55)
	if age > hold_time + desaturate_time:
		c.a = 1.0 - clampf((age - hold_time - desaturate_time) / fade_time, 0.0, 1.0)
	set_instance_shader_parameter(&"tint", c)
	if age >= hold_time + desaturate_time + fade_time:
		deactivate()
