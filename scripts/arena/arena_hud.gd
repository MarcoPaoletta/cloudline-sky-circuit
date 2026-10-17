class_name ArenaHud
extends CanvasLayer
## Compact arena HUD: wave counter, remaining monsters, bowling chain, boss bars (top centre, never covering the
## player or the head), start/clear banners and the Retry Arena defeat panel. Reads the director's signals.

@onready var _wave: Label = %WaveLabel
@onready var _remaining: Label = %RemainingLabel
@onready var _chain: Label = %ChainLabel
@onready var _bars: VBoxContainer = %BossBars
@onready var _banner: Control = %Banner
@onready var _banner_title: Label = %BannerTitle
@onready var _banner_sub: Label = %BannerSub
@onready var _defeat: Control = %DefeatPanel
@onready var _retry: Button = %RetryButton
@onready var _title_btn: Button = %TitleButton
@onready var _bar_template: Control = %BossBarTemplate

var _director: ArenaDirector
var _chain_tween: Tween
var _banner_tween: Tween
var _bars_by_boss: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_banner.modulate.a = 0.0
	_defeat.visible = false
	_chain.modulate.a = 0.0
	_bar_template.visible = false
	_wave.text = ""
	_retry.pressed.connect(func() -> void:
		_defeat.visible = false
		if _director:
			_director.retry_arena())
	_title_btn.pressed.connect(func() -> void:
		get_tree().paused = false
		ScreenTransition.change_scene("res://scenes/ui/title_screen.tscn", "", "", 0.1))


func configure(d: ArenaDirector) -> void:
	_director = d
	d.wave_started.connect(func(i: int, n: int) -> void: show_wave(i, n))
	d.counts_changed.connect(_on_counts)
	d.chain_changed.connect(_on_chain)
	_wave.text = "WAVE 1 / %d" % d.wave_counts.size()


func show_wave(i: int, n: int) -> void:
	_wave.text = "WAVE %d / %d" % [i, n]
	_wave.pivot_offset = _wave.size * 0.5
	var tw := create_tween()
	tw.tween_property(_wave, "scale", Vector2.ONE, 0.3).from(Vector2(1.35, 1.35)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if i > 1 or n > 1:
		show_banner("WAVE %d" % i, "More coming through the portals!", 1.4)


func _on_counts(alive: int, unreleased: int) -> void:
	_remaining.text = "%d to clear" % (alive + unreleased)


func _on_chain(n: int) -> void:
	if _chain_tween and _chain_tween.is_valid():
		_chain_tween.kill()
	if n <= 1:
		_chain_tween = create_tween()
		_chain_tween.tween_property(_chain, "modulate:a", 0.0, 0.3)
		return
	_chain.text = "x%d" % n
	_chain.pivot_offset = _chain.size * 0.5
	_chain.modulate.a = 1.0
	_chain_tween = create_tween()
	_chain_tween.tween_property(_chain, "scale", Vector2.ONE, 0.25).from(Vector2(1.5, 1.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_banner(title: String, sub: String, seconds: float = 2.0) -> void:
	_banner_title.text = title
	_banner_sub.text = sub
	if _banner_tween and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.pivot_offset = _banner.size * 0.5
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "modulate:a", 1.0, 0.18)
	_banner_tween.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.35).from(Vector2(0.85, 0.85)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)


func add_boss(b: YetiBoss) -> void:
	var bar := _bar_template.duplicate() as Control
	bar.visible = true
	bar.name = "Bar_" + b.boss_name
	_bars.add_child(bar)
	(bar.get_node("Row/Name") as Label).text = b.boss_name
	(bar.get_node("Row/Name") as Label).add_theme_color_override("font_color", b.accent_color)
	var pb := bar.get_node("Row/Health") as ProgressBar
	pb.max_value = b.max_health
	pb.value = b.max_health
	(bar.get_node("Row/Icon") as CanvasItem).modulate = b.accent_color
	_bars_by_boss[b] = pb
	b.health_changed.connect(func(h: int, m: int) -> void:
		var tw := create_tween()
		tw.tween_property(pb, "value", float(h), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		bar.pivot_offset = bar.size * 0.5
		var pop := create_tween()
		pop.tween_property(bar, "scale", Vector2.ONE, 0.25).from(Vector2(1.06, 1.06)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if h <= 0:
			var fade := create_tween()
			fade.tween_interval(1.0)
			fade.tween_property(bar, "modulate:a", 0.0, 0.6))


func boss_bar_value(b: YetiBoss) -> float:
	var pb := _bars_by_boss.get(b) as ProgressBar
	return pb.value if pb else -1.0


func show_defeat(d: ArenaDirector) -> void:
	_director = d
	_defeat.visible = true
	_defeat.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_defeat, "modulate:a", 1.0, 0.3)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_retry.grab_focus()
