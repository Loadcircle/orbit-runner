extends Control
## Level select by world: unlocked levels, medals, gems and best times.

var _world := 0
var _grid: GridContainer
var _world_title: Label
var _world_tabs: HBoxContainer


func _ready() -> void:
	_world = int(SceneRouter.payload.get("world", _default_world()))
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.17, 0.45)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var box := UiKit.vbox(14)
	margin.add_child(box)
	var header := UiKit.hbox(16)
	box.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, handle_back, 70))
	header.add_child(UiKit.label(tr("MENU_LEVELS"), 42))
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.glyph(IconGlyph.Icon.GEM, UiKit.GEM, 34))
	header.add_child(UiKit.label("%d/%d" % [Progress.gems_collected(), Progress.gems_available()], 28))
	header.add_child(UiKit.glyph(IconGlyph.Icon.SPARK, UiKit.GOLD, 34))
	header.add_child(UiKit.label(str(Progress.sparks()), 28))

	_world_tabs = UiKit.hbox(12)
	box.add_child(_world_tabs)
	var catalog := Progress.LEVEL_CATALOG
	for i in catalog.world_title_keys.size():
		var world_index := i
		var b := UiKit.button(tr(catalog.world_title_keys[i]), func(): _select_world(world_index))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(260, 64)
		_world_tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 18)
	center.add_child(_grid)
	_select_world(_world)


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _default_world() -> int:
	var next := Progress.levels()[Progress.next_level_index()]
	return next.world_index


func _select_world(index: int) -> void:
	_world = index
	for i in _world_tabs.get_child_count():
		(_world_tabs.get_child(i) as Button).set_pressed_no_signal(i == index)
	for child in _grid.get_children():
		child.queue_free()
	var levels := Progress.levels()
	var first: Button
	for i in levels.size():
		if levels[i].world_index != index:
			continue
		var card := _card(i, levels[i])
		_grid.add_child(card)
		if first == null and not card.disabled:
			first = card
	if first:
		UiKit.focus_first(_grid)


func _card(index: int, info: LevelInfo) -> Button:
	var unlocked := Progress.is_unlocked(index)
	var rec := Progress.record(info.id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(340, 200)
	card.disabled = not unlocked
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(func():
		AudioDirector.play_sfx(&"ui_confirm")
		SceneRouter.play_level(index))
	var inner := UiKit.vbox(6)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 18
	inner.offset_top = 14
	inner.offset_right = -18
	inner.offset_bottom = -14
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)
	var top := UiKit.hbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(top)
	var number := tr("LEVEL_TUTORIAL_SHORT") if info.is_tutorial else str(_campaign_number(index))
	top.add_child(UiKit.label(number, 40, UiKit.ORANGE))
	top.add_child(UiKit.spacer())
	if not unlocked:
		top.add_child(UiKit.glyph(IconGlyph.Icon.LOCK, Color(0.85, 0.88, 0.95), 40))
	elif not info.is_tutorial:
		top.add_child(UiKit.glyph(IconGlyph.Icon.MEDAL, UiKit.medal_color(int(rec["medal"])), 44))
	elif bool(rec["completed"]):
		top.add_child(UiKit.glyph(IconGlyph.Icon.CHECK, UiKit.CYAN, 40))
	var name_label := UiKit.label(tr(info.title_key), 26)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(name_label)
	inner.add_child(UiKit.spacer())
	var bottom := UiKit.hbox(6)
	inner.add_child(bottom)
	if unlocked and not info.is_tutorial:
		var gems: Array = rec["gems"]
		for g in 3:
			var got := g < gems.size() and bool(gems[g])
			var glyph := UiKit.glyph(IconGlyph.Icon.GEM, UiKit.GEM if got else Color(1, 1, 1, 0.45), 28)
			glyph.filled = got
			bottom.add_child(glyph)
		bottom.add_child(UiKit.spacer())
		bottom.add_child(UiKit.label(UiKit.format_time(float(rec["best_time"])), 22, UiKit.DIM))
	elif not unlocked:
		bottom.add_child(UiKit.label(tr("LEVEL_LOCKED_HINT"), 20, UiKit.DIM))
	else:
		bottom.add_child(UiKit.label(tr(info.hint_key), 20, UiKit.DIM))
	for node in card.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _campaign_number(index: int) -> int:
	var n := 0
	var levels := Progress.levels()
	for i in index + 1:
		if not levels[i].is_tutorial:
			n += 1
	return n
