extends Control
## Achievements with progress, plus a progress/statistics page.

const STAT_ROWS := [
	["STAT_JUMPS", &"jumps"], ["STAT_YOYO_BOUNCES", &"yoyo_bounces"], ["STAT_DASHES", &"dashes"],
	["STAT_SLIDES", &"slides"], ["STAT_LONG_JUMPS", &"long_jumps"], ["STAT_TRAMPOLINES", &"trampolines"],
	["STAT_RESPAWNS", &"respawns"], ["STAT_SPARKS_TOTAL", &"sparks_total"], ["STAT_LEVELS_FINISHED", &"levels_finished"],
]

var _pages: Array[Control] = []
var _tabs: TabBar


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.17, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var box := UiKit.vbox(12)
	margin.add_child(box)
	var header := UiKit.hbox(16)
	box.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, handle_back, 70))
	header.add_child(UiKit.label(tr("MENU_ACHIEVEMENTS"), 42))
	_tabs = TabBar.new()
	_tabs.add_theme_font_size_override("font_size", 26)
	_tabs.clip_tabs = false
	_tabs.add_tab(tr("ACH_TAB_LIST"))
	_tabs.add_tab(tr("ACH_TAB_PROGRESS"))
	_tabs.tab_changed.connect(_show)
	header.add_child(_tabs)
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.label("%d/%d" % [Progress.achievements_unlocked_count(),
			Progress.ACHIEVEMENT_CATALOG.achievements.size()], 30, UiKit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var stack := UiKit.vbox(0)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stack)
	_pages = [_list_page(), _progress_page()]
	for page in _pages:
		stack.add_child(page)
	_show(0)


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _show(index: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == index


func _list_page() -> Control:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for a in Progress.ACHIEVEMENT_CATALOG.achievements:
		var done := Progress.is_achieved(a.id)
		var p := Progress.achievement_progress(a)
		var card := UiKit.panel()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if not done:
			card.modulate = Color(0.78, 0.82, 0.9)
		var row := UiKit.hbox(14)
		card.add_child(row)
		row.add_child(UiKit.glyph(IconGlyph.Icon.TROPHY if done else IconGlyph.Icon.LOCK,
				UiKit.GOLD if done else Color(0.6, 0.66, 0.78), 56))
		var col := UiKit.vbox(4)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UiKit.label(tr(a.title_key), 26, UiKit.GOLD if done else Color.WHITE))
		var desc := UiKit.label(tr(a.description_key), 20, UiKit.DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(desc)
		var bar := ProgressBar.new()
		bar.max_value = p.y
		bar.value = p.x
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 12)
		col.add_child(bar)
		var footer := UiKit.hbox(8)
		col.add_child(footer)
		footer.add_child(UiKit.label("%d/%d" % [p.x, p.y], 18, UiKit.DIM))
		if a.reward_sparks > 0:
			footer.add_child(UiKit.spacer())
			footer.add_child(UiKit.glyph(IconGlyph.Icon.SPARK, UiKit.GOLD, 22))
			footer.add_child(UiKit.label("+%d" % a.reward_sparks, 18, UiKit.GOLD))
		grid.add_child(card)
	return grid


func _progress_page() -> Control:
	var box := UiKit.vbox(12)
	var summary := UiKit.hbox(18)
	box.add_child(summary)
	summary.add_child(_big_stat(IconGlyph.Icon.STAR, UiKit.ORANGE, "%d/%d" % [Progress.campaign_levels_completed(),
			Progress.campaign_level_count()], tr("PROGRESS_LEVELS")))
	summary.add_child(_big_stat(IconGlyph.Icon.GEM, UiKit.GEM, "%d/%d" % [Progress.gems_collected(), Progress.gems_available()],
			tr("WORD_GEMS")))
	summary.add_child(_big_stat(IconGlyph.Icon.MEDAL, UiKit.GOLD, str(Progress.medal_count(Progress.Medal.GOLD)), tr("MEDAL_GOLD")))
	summary.add_child(_big_stat(IconGlyph.Icon.MEDAL, UiKit.SILVER, str(Progress.medal_count(Progress.Medal.SILVER)),
			tr("PROGRESS_SILVER_PLUS")))
	summary.add_child(_big_stat(IconGlyph.Icon.SPARK, UiKit.GOLD, str(Progress.sparks()), tr("WORD_SPARKS")))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for row in STAT_ROWS:
		var l := UiKit.label("%s: %d" % [tr(row[0]), Progress.stat(row[1])], 24)
		l.custom_minimum_size.x = 340
		grid.add_child(l)
	var reset := UiKit.button(tr("PROGRESS_RESET"), _confirm_reset)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	box.add_child(UiKit.spacer(Vector2(0, 20), false))
	box.add_child(reset)
	return box


func _big_stat(icon: IconGlyph.Icon, color: Color, value: String, caption: String) -> Control:
	var panel := UiKit.panel()
	var col := UiKit.vbox(2)
	panel.add_child(col)
	var row := UiKit.hbox(8)
	col.add_child(row)
	row.add_child(UiKit.glyph(icon, color, 40))
	row.add_child(UiKit.label(value, 34))
	col.add_child(UiKit.label(caption, 20, UiKit.DIM))
	return panel


func _confirm_reset() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = tr("PROGRESS_RESET")
	dialog.dialog_text = tr("PROGRESS_RESET_CONFIRM")
	dialog.ok_button_text = tr("WORD_YES")
	dialog.cancel_button_text = tr("WORD_NO")
	dialog.confirmed.connect(func():
		Progress.reset_all()
		SceneRouter.go_to(SceneRouter.TITLE))
	add_child(dialog)
	dialog.popup_centered()
