class_name LightingPreset
extends Resource
## Per-scene sun settings saved by the F2 lighting lab (res://resources/lighting/<scene file name>.tres).
## The scene's own Sun values are the fallback; when a preset exists, the scene root applies it in _ready, in every
## build (the lab itself is development-only). Environment and toon material tweaks are saved straight into their
## shared .tres files, so they need no preset.

const DIR := "res://resources/lighting/"

@export var light_color: Color = Color.WHITE
@export var light_energy: float = 1.7
@export var rotation_degrees: Vector3 = Vector3(-40.0, 30.0, 0.0)
@export_range(0.0, 1.0) var shadow_opacity: float = 0.45


static func path_for(scene: Node) -> String:
	return DIR + scene.scene_file_path.get_file().get_basename() + ".tres"


## Applies the saved preset (if any) to the scene's root-level node named "Sun".
static func apply_to(scene: Node) -> void:
	if scene == null or scene.scene_file_path == "":
		return
	var path := path_for(scene)
	if not ResourceLoader.exists(path):
		return
	var preset := load(path) as LightingPreset
	var sun := scene.get_node_or_null("Sun") as DirectionalLight3D
	if preset and sun:
		preset.apply_sun(sun)


func apply_sun(sun: DirectionalLight3D) -> void:
	sun.light_color = light_color
	sun.light_energy = light_energy
	sun.rotation_degrees = rotation_degrees
	sun.shadow_opacity = shadow_opacity


func capture_sun(sun: DirectionalLight3D) -> void:
	light_color = sun.light_color
	light_energy = sun.light_energy
	rotation_degrees = sun.rotation_degrees
	shadow_opacity = sun.shadow_opacity
