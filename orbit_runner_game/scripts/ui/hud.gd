class_name Hud
extends CanvasLayer
## In-level heads-up display: time, route progress, gems, sparks, pause button,
## contextual prompts and the touch controls.

const PORTRAIT := preload("res://art/ui/portrait.png")

var _level: Level
var _touch_mode := false

var _time_label: Label
var _progress: ProgressBar
var _gem_glyphs: Array[IconGlyph] = []
var _spark_label: Label
var _message: Label
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _flash: ColorRect
var _touch: TouchControls
var _root: Control
var _medal_hint: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_touch_mode = OS.has_feature("mobile")
	_set_touch_visible(_touch_mode)
	Settings.changed.connect(_on_settings_changed)
	_on_settings_changed()


func setup(level: Level) -> void:
	_level = level
	_touch.player = level.player
	_touch.camera_drag.connect(func(px: float): level.camera_rig.add_manual_yaw(-px * 0.006))
	level.gems_changed.connect(_on_gems_changed)
	level.sparks_changed.connect(_on_sparks_changed)
	_on_sparks_changed(0, level.sparks_total)
	_on_gems_changed(level.gems)
	if level.info and not level.info.is_tutorial:
		_medal_hint.text = "%s %s" % [tr("HUD_GOLD"), UiKit.format_time(level.info.gold_time)]


func is_touch_mode() -> bool:
	return _touch_mode


func _process(_delta: float) -> void:
	if _level == null:
		return
	_time_label.text = UiKit.format_time(_level.elapsed) if _level.elapsed > 0.0 else "00:00.00"
	_progress.value = _level.route_progress() * 100.0
	if _level.info and not _level.info.is_tutorial:
		_medal_hint.modulate = UiKit.GOLD if _level.elapsed <= _level.info.gold_time else UiKit.DIM


func _input(event: InputEvent) -> void:
	# Switch prompts/controls between touch and keyboard/gamepad on the fly.
	if event is InputEventScreenTouch and not _touch_mode:
		_touch_mode = true
		_set_touch_visible(true)
	elif (event is InputEventKey or event is InputEventJoypadButton) and _touch_mode and not OS.has_feature("mobile"):
		_touch_mode = false
		_set_touch_visible(false)


func on_finished() -> void:
	_touch.release_all()
	_touch.visible = false
	hide_prompt()
	flash_message(tr("HUD_GOAL"))


func flash_message(text: String) -> void:
	_message.text = text
	_message.modulate.a = 1.0
	_message.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.tween_property(_message, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)
	tween.tween_property(_message, "modulate:a", 0.0, 0.4)


func show_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_panel.visible = true
	_prompt_panel.modulate.a = 0.0
	create_tween().tween_property(_prompt_panel, "modulate:a", 1.0, 0.2)


func hide_prompt() -> void:
	_prompt_panel.visible = false


func fade_flash() -> void:
	_flash.color.a = 0.0
	var tween := create_tween()
	tween.tween_property(_flash, "color:a", 0.7, 0.25)
	tween.tween_property(_flash, "color:a", 0.0, 0.35)


func set_paused_visuals(paused: bool) -> void:
	if paused:
		_touch.release_all()
	_touch.visible = _touch_mode and not paused


func _set_touch_visible(value: bool) -> void:
	_touch.visible = value and not get_tree().paused


func _on_settings_changed() -> void:
	_time_label.get_parent().visible = bool(Settings.get_value("show_timer"))
	_touch.modulate.a = 1.0


func _on_gems_changed(collected: Array[bool]) -> void:
	for i in _gem_glyphs.size():
		var got := i < collected.size() and collected[i]
		_gem_glyphs[i].filled = got
		_gem_glyphs[i].color = UiKit.GEM if got else Color(1, 1, 1, 0.8)
		if got and _gem_glyphs[i].scale == Vector2.ONE:
			_gem_glyphs[i].pivot_offset = _gem_glyphs[i].size * 0.5
			_gem_glyphs[i].scale = Vector2(1.6, 1.6)
			create_tween().tween_property(_gem_glyphs[i], "scale", Vector2(1.01, 1.01), 0.3).set_trans(Tween.TRANS_BACK)


func _on_sparks_changed(collected: int, total: int) -> void:
	_spark_label.text = "%d/%d" % [collected, total]


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	UiKit.apply_safe_area(_root, 14.0)

	_touch = TouchControls.new()
	add_child(_touch)
	move_child(_touch, 0)

	# Top-left: portrait, timer, route progress.
	var info_panel := PanelContainer.new()
	info_panel.position = Vector2.ZERO
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(info_panel)
	var row := UiKit.hbox(12)
	info_panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = PORTRAIT
	portrait.custom_minimum_size = Vector2(68, 68)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var col := UiKit.vbox(4)
	row.add_child(col)
	var time_row := UiKit.hbox(8)
	col.add_child(time_row)
	time_row.add_child(UiKit.glyph(IconGlyph.Icon.CLOCK, UiKit.ORANGE, 30))
	_time_label = UiKit.label("00:00.00", 32)
	_time_label.custom_minimum_size.x = 150
	time_row.add_child(_time_label)
	_medal_hint = UiKit.label("", 18, UiKit.DIM)
	col.add_child(_medal_hint)
	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(210, 14)
	_progress.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.08, 0.2)
	bg.set_corner_radius_all(7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiKit.ORANGE
	fill.set_corner_radius_all(7)
	_progress.add_theme_stylebox_override("background", bg)
	_progress.add_theme_stylebox_override("fill", fill)
	col.add_child(_progress)

	# Top-centre: gems and sparks.
	var center := HBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 10)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(center)
	for i in 3:
		var g := UiKit.glyph(IconGlyph.Icon.GEM, Color(1, 1, 1, 0.8), 40)
		g.filled = false
		center.add_child(g)
		_gem_glyphs.append(g)
	center.add_child(UiKit.spacer(Vector2(18, 0), false))
	center.add_child(UiKit.glyph(IconGlyph.Icon.SPARK, UiKit.GOLD, 36))
	_spark_label = UiKit.label("0/0", 30)
	center.add_child(_spark_label)

	# Top-right: pause.
	var pause_button := UiKit.icon_button(IconGlyph.Icon.PAUSE, func(): if _level: _level.pause(), 78)
	pause_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_button.offset_left = -78.0
	pause_button.offset_right = 0.0
	pause_button.offset_top = 0.0
	pause_button.offset_bottom = 78.0
	pause_button.focus_mode = Control.FOCUS_NONE
	_root.add_child(pause_button)

	_message = UiKit.title("", 56)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.position.y = 120
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.modulate.a = 0.0
	_root.add_child(_message)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.position.y = 190
	_prompt_panel.visible = false
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_prompt_panel)
	_prompt_label = UiKit.label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_label.custom_minimum_size = Vector2(560, 0)
	_prompt_panel.add_child(_prompt_label)

	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
