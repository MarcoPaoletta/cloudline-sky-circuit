extends Node
## Audio autoload (scene: res://scenes/core/audio.tscn).
##
## Installed FIRST in the project: the game boots with the Master bus MUTED (Marco, 2026-10-05) and the
## `toggle_mute` action (M) flips it on every screen, including while the tree is paused. Nothing about the
## mute state is persisted. One-shots come from voices authored in the scene (no runtime node creation).
## The speaker + "M" badge lives in this scene so every screen shows why it is silent.

signal mute_changed(is_muted: bool)

const SFX_DIR := "res://assets/cloudline/audio/sfx/%s.wav"
## Sounds that were imported before the sfx folder existed.
const LEGACY := {
	&"jump": "res://assets/cloudline/audio/Jumping and Landing/sfx_movement_jump1.wav",
	&"land": "res://assets/cloudline/audio/Jumping and Landing/sfx_movement_jump10_landing.wav",
	&"coin": "res://assets/cloudline/audio/Coins/sfx_coin_single1.wav",
	&"checkpoint": "res://assets/cloudline/audio/Positive Sounds/sfx_sounds_powerup1.wav",
	&"step": "res://assets/cloudline/audio/Footsteps/sfx_movement_footsteps1a.wav",
	&"ui_select": "res://assets/cloudline/audio/Menu Sounds/sfx_menu_select1.wav",
}

@export_group("Voices")
## Minimum seconds between two starts of the same sound id.
@export var min_interval: float = 0.045
## Max simultaneous voices playing the same sound id.
@export var max_same_voices: int = 3
@export_group("Mute badge")
@export var badge_muted_alpha: float = 1.0
@export var badge_unmuted_alpha: float = 0.55

@onready var _voices: Array[Node] = $Voices.get_children()
@onready var _ui_voices: Array[Node] = $UiVoices.get_children()
@onready var _badge: Control = %Badge
@onready var _wave_a: CanvasItem = %WaveA
@onready var _wave_b: CanvasItem = %WaveB
@onready var _slash: CanvasItem = %MuteSlash

var _streams: Dictionary = {}
var _missing: Dictionary = {}
var _last_start: Dictionary = {}
var _last_variant: Dictionary = {}
var _badge_tween: Tween
var _master_idx: int = 0
## Authored bus offsets (default_bus_layout.tres); the settings sliders scale around them.
var _base_db: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_master_idx = AudioServer.get_bus_index(&"Master")
	for i in AudioServer.bus_count:
		_base_db[AudioServer.get_bus_name(i)] = AudioServer.get_bus_volume_db(i)
	# Step 2b of the build order: mute before any sound can exist.
	AudioServer.set_bus_mute(_master_idx, true)
	_refresh_badge(false)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_mute") and not event.is_echo():
		toggle_mute()
		get_viewport().set_input_as_handled()


## True while the Master bus is muted.
func is_muted() -> bool:
	return AudioServer.is_bus_mute(_master_idx)


func set_muted(value: bool) -> void:
	AudioServer.set_bus_mute(_master_idx, value)
	_refresh_badge(true)
	mute_changed.emit(value)


func toggle_mute() -> void:
	set_muted(not is_muted())


## Linear 0..1 volume for a bus by name (Master, SFX, UI, Ambience).
func set_bus_linear(bus: StringName, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, float(_base_db.get(String(bus), 0.0)) + linear_to_db(clampf(value, 0.0001, 1.0)))


func get_bus_linear(bus: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus)
	return db_to_linear(AudioServer.get_bus_volume_db(idx) - float(_base_db.get(String(bus), 0.0))) if idx >= 0 else 1.0


## Plays a one-shot on the SFX bus. Returns the player used (or null when rate limited / missing).
func play_sfx(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	return _play(id, volume_db, pitch, _voices, &"SFX")


## Plays a one-shot on the UI bus.
func play_ui(id: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	return _play(id, volume_db, pitch, _ui_voices, &"UI")


## Picks one of several ids at random, never the same twice in a row (wet splats, hit variants).
func play_variant(group: StringName, ids: Array, volume_db: float = 0.0, pitch_jitter: float = 0.08) -> AudioStreamPlayer:
	if ids.is_empty():
		return null
	var pick: int = randi() % ids.size()
	if ids.size() > 1 and pick == int(_last_variant.get(group, -1)):
		pick = (pick + 1 + randi() % (ids.size() - 1)) % ids.size()
	_last_variant[group] = pick
	return play_sfx(ids[pick], volume_db, 1.0 + randf_range(-pitch_jitter, pitch_jitter))


func _play(id: StringName, volume_db: float, pitch: float, pool: Array[Node], bus: StringName) -> AudioStreamPlayer:
	var stream := _get_stream(id)
	if stream == null:
		return null
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_last_start.get(id, -10.0)) < min_interval:
		return null
	var same := 0
	var free_voice: AudioStreamPlayer = null
	var oldest: AudioStreamPlayer = null
	for n in pool:
		var p := n as AudioStreamPlayer
		if p.playing:
			if p.stream == stream:
				same += 1
			if oldest == null or p.get_playback_position() > oldest.get_playback_position():
				oldest = p
		elif free_voice == null:
			free_voice = p
	if same >= max_same_voices:
		return null
	var voice := free_voice if free_voice != null else oldest
	if voice == null:
		return null
	_last_start[id] = now
	voice.stream = stream
	voice.bus = bus
	voice.volume_db = volume_db
	voice.pitch_scale = pitch
	voice.play()
	return voice


func _get_stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	if _missing.has(id):
		return null
	var path: String = LEGACY.get(id, SFX_DIR % id)
	var stream: AudioStream = null
	if ResourceLoader.exists(path):
		stream = load(path) as AudioStream
	if stream == null:
		_missing[id] = true
		push_warning("Audio: no sound file for '%s' (%s)" % [id, path])
		return null
	_streams[id] = stream
	return stream


func _refresh_badge(animate: bool) -> void:
	var muted := is_muted()
	_slash.visible = muted
	_wave_a.visible = not muted
	_wave_b.visible = not muted
	var target_alpha := badge_muted_alpha if muted else badge_unmuted_alpha
	if _badge_tween:
		_badge_tween.kill()
	if animate:
		_badge.pivot_offset = _badge.size * 0.5
		_badge_tween = create_tween().set_parallel(true)
		_badge_tween.tween_property(_badge, "scale", Vector2.ONE, 0.22).from(Vector2(1.14, 1.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_badge_tween.tween_property(_badge, "modulate:a", target_alpha, 0.2)
	else:
		_badge.modulate.a = target_alpha
