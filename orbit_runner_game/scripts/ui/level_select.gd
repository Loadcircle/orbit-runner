extends Control
## Level select: every level in one horizontal strip, grouped by world. Drag or
## swipe to browse; the world tabs and the arrows jump between worlds.

## Pointer travel that turns a press into a drag (a drag never opens a level).
const DRAG_THRESHOLD := 24.0
## Fling speed decay per second after a swipe.
const FLING_DAMPING := 5.0
const CARD_GAP := 18
const WORLD_GAP := 64

var _world := 0
var _offset := 0.0
var _velocity := 0.0
var _press_pos := Vector2.ZERO
var _pressing := false
var _dragged := false
var _tween: Tween
var _view: Control
var _strip: HBoxContainer
var _world_tabs: HBoxContainer
var _sections: Array[Control] = []


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

	var nav := UiKit.hbox(12)
	box.add_child(nav)
	nav.add_child(UiKit.icon_button(IconGlyph.Icon.ARROW_LEFT, func(): _select_world(_world - 1), 64))
	_world_tabs = UiKit.hbox(12)
	nav.add_child(_world_tabs)
	var catalog := Progress.LEVEL_CATALOG
	for i in catalog.world_title_keys.size():
		var world_index := i
		var b := UiKit.button(tr(catalog.world_title_keys[i]), func(): _select_world(world_index))
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(240, 64)
		_world_tabs.add_child(b)
	nav.add_child(UiKit.icon_button(IconGlyph.Icon.ARROW_RIGHT, func(): _select_world(_world + 1), 64))

	# Clipped viewport with a strip moved by hand: drags work over the cards too.
	_view = Control.new()
	_view.clip_contents = true
	_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_view)
	_strip = UiKit.hbox(WORLD_GAP)
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.add_child(_strip)
	_build_strip()
	_view.resized.connect(func(): _set_offset(_offset))
	_set_offset(0.0)
	await get_tree().process_frame
	_set_offset(_world_offset(_world))
	_update_tabs()
	UiKit.focus_first(_sections[_world] if _world < _sections.size() else _strip)


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _default_world() -> int:
	var next := Progress.levels()[Progress.next_level_index()]
	return next.world_index


func _build_strip() -> void:
	var levels := Progress.levels()
	var catalog := Progress.LEVEL_CATALOG
	for w in catalog.world_title_keys.size():
		var section := UiKit.vbox(10)
		section.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_strip.add_child(section)
		_sections.append(section)
		var world_mastery := Progress.world_mastery(w)
		var title := UiKit.hbox(10)
		title.alignment = BoxContainer.ALIGNMENT_BEGIN
		section.add_child(title)
		title.add_child(UiKit.label(tr(catalog.world_title_keys[w]), 30, UiKit.CYAN))
		var star := UiKit.glyph(IconGlyph.Icon.STAR, UiKit.GOLD, 26)
		star.filled = true
		title.add_child(star)
		title.add_child(UiKit.label("%d/%d" % [world_mastery.x, world_mastery.y], 24, UiKit.DIM))
		var row := UiKit.hbox(CARD_GAP)
		section.add_child(row)
		for i in levels.size():
			if levels[i].world_index == w:
				row.add_child(_card(i, levels[i]))


func _select_world(index: int) -> void:
	_world = clampi(index, 0, _sections.size() - 1)
	_velocity = 0.0
	_update_tabs()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_offset, _offset, _world_offset(_world), 0.35) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_tabs() -> void:
	for i in _world_tabs.get_child_count():
		(_world_tabs.get_child(i) as Button).set_pressed_no_signal(i == _world)


## Scroll that puts the start of a world at the left edge.
func _world_offset(index: int) -> float:
	if index <= 0 or index >= _sections.size():
		return 0.0
	return _sections[index].position.x


func _max_offset() -> float:
	return maxf(_strip.get_combined_minimum_size().x - _view.size.x, 0.0)


func _set_offset(value: float) -> void:
	_offset = clampf(value, 0.0, _max_offset())
	_strip.position = Vector2(-_offset, 0.0)
	_strip.size = Vector2(_strip.get_combined_minimum_size().x, _view.size.y)


## Highlights the world that fills most of the view after a drag.
func _sync_world_from_offset() -> void:
	var centre := _offset + _view.size.x * 0.5
	for i in _sections.size():
		var s := _sections[i]
		if centre >= s.position.x - WORLD_GAP * 0.5 and centre <= s.position.x + s.size.x + WORLD_GAP * 0.5:
			_world = i
	if _offset >= _max_offset() - 1.0:
		_world = _sections.size() - 1
	elif _offset <= 1.0:
		_world = 0
	_update_tabs()


func _process(delta: float) -> void:
	if _pressing or absf(_velocity) < 5.0:
		return
	_set_offset(_offset - _velocity * delta)
	_velocity = move_toward(_velocity, 0.0, absf(_velocity) * FLING_DAMPING * delta + 20.0 * delta)
	_sync_world_from_offset()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var pos := Vector2.ZERO
	var pressed := false
	var released := false
	var moved := Vector2.ZERO
	if event is InputEventScreenTouch and event.index == 0:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if _view.get_global_rect().has_point(event.position):
			_select_world(_world + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1))
		return
	elif event is InputEventScreenDrag and event.index == 0:
		pos = event.position
		moved = event.relative
	elif event is InputEventMouseMotion and _pressing and not DisplayServer.is_touchscreen_available():
		pos = event.position
		moved = event.relative
	else:
		return
	if pressed:
		_pressing = _view.get_global_rect().has_point(pos)
		_press_pos = pos
		_dragged = false
		_velocity = 0.0
		if _pressing and _tween:
			_tween.kill()
	elif released:
		if _pressing and _dragged:
			_sync_world_from_offset()
			# Swallow the release so the card under the finger does not open.
			get_viewport().set_input_as_handled()
		_pressing = false
	elif _pressing and moved != Vector2.ZERO:
		if not _dragged and pos.distance_to(_press_pos) > DRAG_THRESHOLD:
			_dragged = true
		if _dragged:
			_set_offset(_offset - moved.x)
			var dt := maxf(get_process_delta_time(), 1.0 / 120.0)
			_velocity = lerpf(_velocity, moved.x / dt, 0.5)
			_sync_world_from_offset()


func _scroll_into_view(control: Control) -> void:
	var left := control.get_global_rect().position.x - _strip.global_position.x
	var right := left + control.size.x
	if left < _offset:
		_set_offset(left - CARD_GAP)
	elif right > _offset + _view.size.x:
		_set_offset(right - _view.size.x + CARD_GAP)
	_sync_world_from_offset()


func _card(index: int, info: LevelInfo) -> Button:
	var unlocked := Progress.is_unlocked(index)
	var rec := Progress.record(info.id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(320, 210)
	card.disabled = not unlocked
	card.focus_mode = Control.FOCUS_ALL
	card.focus_entered.connect(func(): _scroll_into_view(card))
	card.pressed.connect(func():
		if _dragged:
			return
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
	if unlocked and not info.is_tutorial and bool(rec["completed"]):
		# Mastery: gold, 3 gems, every spark, no falls.
		var stars := UiKit.hbox(2)
		for star in Progress.mastery(info):
			var g := UiKit.glyph(IconGlyph.Icon.STAR, UiKit.GOLD if star else Color(1, 1, 1, 0.35), 22)
			g.filled = star
			stars.add_child(g)
		inner.add_child(stars)
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
