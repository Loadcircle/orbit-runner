class_name SettingsPanel
extends Control
## Options screen, usable from the main menu and the pause menu.

signal closed

var _content: VBoxContainer
var _tabs: TabBar
var _pages: Array[Control] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UiKit.dim_background())
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var panel := UiKit.panel()
	margin.add_child(panel)
	_content = UiKit.vbox(12)
	panel.add_child(_content)
	var header := UiKit.hbox(16)
	_content.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, close, 64))
	header.add_child(UiKit.label(tr("SETTINGS_TITLE"), 40))
	_tabs = TabBar.new()
	_tabs.add_theme_font_size_override("font_size", 26)
	for key in ["SETTINGS_TAB_AUDIO", "SETTINGS_TAB_CONTROLS", "SETTINGS_TAB_GAME"]:
		_tabs.add_tab(tr(key))
	_tabs.tab_changed.connect(_show_page)
	header.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var stack := UiKit.vbox(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	_pages = [_audio_page(), _controls_page(), _game_page()]
	for page in _pages:
		stack.add_child(page)
	_show_page(0)
	UiKit.focus_first(self)


func close() -> void:
	closed.emit()
	queue_free()


func handle_back() -> void:
	close()


func _show_page(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index


func _audio_page() -> Control:
	var page := UiKit.vbox(18)
	page.add_child(_slider("SETTINGS_MASTER", "master_volume", 0.0, 1.0, 0.05))
	page.add_child(_slider("SETTINGS_MUSIC", "music_volume", 0.0, 1.0, 0.05))
	page.add_child(_slider("SETTINGS_SFX", "sfx_volume", 0.0, 1.0, 0.05))
	page.add_child(_toggle("SETTINGS_VIBRATION", "vibration"))
	return page


func _controls_page() -> Control:
	var page := UiKit.vbox(18)
	page.add_child(_slider("SETTINGS_TOUCH_SIZE", "touch_scale", 0.7, 1.4, 0.05))
	page.add_child(_slider("SETTINGS_TOUCH_OPACITY", "touch_opacity", 0.2, 1.0, 0.05))
	page.add_child(_toggle("SETTINGS_LEFT_HANDED", "left_handed"))
	page.add_child(_slider("SETTINGS_CAMERA_SENS", "camera_sensitivity", 0.4, 2.0, 0.1))
	var keys := UiKit.label(tr("SETTINGS_KEYS_HELP"), 22, UiKit.DIM)
	keys.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(keys)
	return page


func _game_page() -> Control:
	var page := UiKit.vbox(18)
	page.add_child(_options("SETTINGS_LANGUAGE", "language", ["", "es", "en"],
			[tr("SETTINGS_LANG_AUTO"), "Español", "English"]))
	page.add_child(_options("SETTINGS_QUALITY", "quality", [0, 1, 2],
			[tr("SETTINGS_Q_LOW"), tr("SETTINGS_Q_MEDIUM"), tr("SETTINGS_Q_HIGH")]))
	page.add_child(_options("SETTINGS_FPS", "max_fps", [30, 60, 120], ["30", "60", "120"]))
	page.add_child(_toggle("SETTINGS_SHAKE", "screen_shake"))
	page.add_child(_toggle("SETTINGS_TIMER", "show_timer"))
	var note := UiKit.label(tr("SETTINGS_QUALITY_NOTE"), 20, UiKit.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(note)
	return page


func _row(label_key: String) -> HBoxContainer:
	var row := UiKit.hbox(20)
	var l := UiKit.label(tr(label_key), 28)
	l.custom_minimum_size.x = 380
	row.add_child(l)
	return row


func _slider(label_key: String, key: String, min_value: float, max_value: float, step: float) -> Control:
	var row := _row(label_key)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(Settings.get_value(key))
	slider.custom_minimum_size = Vector2(420, 48)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var value_label := UiKit.label("%d%%" % roundi(slider.value * 100.0) if max_value <= 2.0 else str(slider.value), 24, UiKit.DIM)
	value_label.custom_minimum_size.x = 90
	slider.value_changed.connect(func(v: float):
		Settings.set_value(key, v)
		value_label.text = "%d%%" % roundi(v * 100.0)
		if key == "sfx_volume":
			AudioDirector.play_sfx(&"ui_click", -2.0))
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _toggle(label_key: String, key: String) -> Control:
	var row := _row(label_key)
	var check := CheckButton.new()
	check.button_pressed = bool(Settings.get_value(key))
	check.custom_minimum_size = Vector2(120, 56)
	check.toggled.connect(func(on: bool):
		AudioDirector.play_sfx(&"ui_click", -4.0)
		Settings.set_value(key, on))
	row.add_child(check)
	return row


func _options(label_key: String, key: String, values: Array, labels: Array) -> Control:
	var row := _row(label_key)
	var group := ButtonGroup.new()
	var current: Variant = Settings.get_value(key)
	for i in values.size():
		var b := Button.new()
		b.text = labels[i]
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(150, 60)
		b.button_pressed = str(values[i]) == str(current)
		var value: Variant = values[i]
		b.pressed.connect(func():
			AudioDirector.play_sfx(&"ui_click", -4.0)
			Settings.set_value(key, value)
			if key == "language":
				_rebuild())
		row.add_child(b)
	return row


func _rebuild() -> void:
	# Re-create the panel so every label picks up the new language.
	var parent := get_parent()
	var replacement := SettingsPanel.new()
	replacement.closed.connect(func(): closed.emit())
	parent.add_child(replacement)
	queue_free()
