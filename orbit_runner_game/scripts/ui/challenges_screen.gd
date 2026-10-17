extends Control
## Challenges: the daily Orbital Challenge, the weekly Wind Tower and the
## daily and weekly missions.

var _missions_box: VBoxContainer
var _mission_tabs: TabBar
var _next_label: Label
var _sparks_label: Label


func _ready() -> void:
	Progress.refresh_missions()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.17, 0.5)
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
	header.add_child(UiKit.label(tr("MENU_CHALLENGES"), 42))
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.glyph(IconGlyph.Icon.SPARK, UiKit.GOLD, 34))
	_sparks_label = UiKit.label(str(Progress.sparks()), 28)
	header.add_child(_sparks_label)

	var body := UiKit.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var cards := UiKit.vbox(14)
	cards.custom_minimum_size.x = 520
	body.add_child(cards)
	cards.add_child(_daily_card())
	cards.add_child(_tower_card())

	var missions := UiKit.panel()
	missions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	missions.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(missions)
	var col := UiKit.vbox(10)
	missions.add_child(col)
	var top := UiKit.hbox(12)
	col.add_child(top)
	top.add_child(UiKit.label(tr("CH_MISSIONS"), 30, UiKit.ORANGE))
	_mission_tabs = TabBar.new()
	_mission_tabs.add_theme_font_size_override("font_size", 24)
	_mission_tabs.clip_tabs = false
	_mission_tabs.add_tab(tr("CH_DAILY_MISSIONS"))
	_mission_tabs.add_tab(tr("CH_WEEKLY_MISSIONS"))
	_mission_tabs.tab_changed.connect(func(_i: int): _fill_missions())
	top.add_child(_mission_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_missions_box = UiKit.vbox(8)
	_missions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_missions_box)
	_fill_missions()
	UiKit.focus_first(cards)


func _process(_delta: float) -> void:
	if _next_label:
		var left := DailyChallenge.seconds_until_tomorrow()
		_next_label.text = tr("CH_DAILY_NEXT") % ("%02d:%02d:%02d" % [left / 3600, (left / 60) % 60, left % 60])


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _daily_card() -> Control:
	var key := DailyChallenge.today_key()
	var spec := DailyChallenge.spec_for(key)
	var rec := Progress.daily_record(key)
	var card := UiKit.panel()
	var col := UiKit.vbox(8)
	card.add_child(col)
	var title := UiKit.hbox(10)
	col.add_child(title)
	title.add_child(UiKit.glyph(IconGlyph.Icon.STAR, UiKit.ORANGE, 40))
	title.add_child(UiKit.label(tr("MODE_DAILY"), 32))
	title.add_child(UiKit.spacer())
	title.add_child(UiKit.label(key, 22, UiKit.DIM))
	var info := UiKit.label("%s · %s" % [tr(LevelSpec.DIFFICULTY_KEYS[spec.difficulty]),
			tr(Progress.LEVEL_CATALOG.world_title_keys[LevelSpec.BIOMES.find(spec.biome)])], 24, UiKit.CYAN)
	col.add_child(info)
	var desc := UiKit.label(tr("CH_DAILY_DESC"), 20, UiKit.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	var row := UiKit.hbox(10)
	col.add_child(row)
	if bool(rec["completed"]):
		row.add_child(UiKit.glyph(IconGlyph.Icon.MEDAL, UiKit.medal_color(int(rec["medal"])), 34))
		row.add_child(UiKit.label(tr("CH_BEST") % UiKit.format_time(float(rec["best_time"])), 24))
	else:
		row.add_child(UiKit.label(tr("CH_NOT_PLAYED"), 22, UiKit.DIM))
	row.add_child(UiKit.spacer())
	if Progress.daily_streak() > 1:
		row.add_child(UiKit.label(tr("CH_STREAK") % Progress.daily_streak(), 20, UiKit.GOLD))
	var bottom := UiKit.hbox(10)
	col.add_child(bottom)
	_next_label = UiKit.label("", 20, UiKit.DIM)
	bottom.add_child(_next_label)
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("CH_PLAY"), func(): SceneRouter.play_generated(spec, key), IconGlyph.Icon.PLAY))
	return card


func _tower_card() -> Control:
	var week := DailyChallenge.week_key()
	var rec := Progress.tower_record(week)
	var card := UiKit.panel()
	var col := UiKit.vbox(8)
	card.add_child(col)
	var title := UiKit.hbox(10)
	col.add_child(title)
	title.add_child(UiKit.glyph(IconGlyph.Icon.TROPHY, UiKit.CYAN, 40))
	title.add_child(UiKit.label(tr("MODE_TOWER"), 32))
	var desc := UiKit.label(tr("CH_TOWER_DESC"), 20, UiKit.DIM)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(desc)
	col.add_child(UiKit.label(tr("CH_TOWER_WEEK") % int(rec["best_floor"]), 24))
	var bottom := UiKit.hbox(10)
	col.add_child(bottom)
	bottom.add_child(UiKit.label(tr("CH_TOWER_EVER") % Progress.tower_best_ever(), 20, UiKit.DIM))
	bottom.add_child(UiKit.spacer())
	bottom.add_child(UiKit.button(tr("CH_PLAY"), func(): SceneRouter.play_generated(DailyChallenge.tower_spec(), week),
			IconGlyph.Icon.PLAY))
	return card


func _fill_missions() -> void:
	for child in _missions_box.get_children():
		child.queue_free()
	var kind := "daily" if _mission_tabs.current_tab == 0 else "weekly"
	var list: Array = Progress.missions.missions(kind)
	for i in list.size():
		_missions_box.add_child(_mission_row(kind, i, list[i]))
	_sparks_label.text = str(Progress.sparks())


func _mission_row(kind: String, index: int, m: Dictionary) -> Control:
	var row := UiKit.hbox(12)
	var col := UiKit.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	var text := UiKit.label(tr("MISSION_" + String(m["id"]).to_upper()) % int(m["target"]), 22,
			UiKit.GOLD if m["done"] else Color.WHITE)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(text)
	var bar := ProgressBar.new()
	bar.max_value = int(m["target"])
	bar.value = int(m["progress"])
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	col.add_child(bar)
	row.add_child(UiKit.label("%d/%d" % [m["progress"], m["target"]], 20, UiKit.DIM))
	if m["claimed"]:
		row.add_child(UiKit.label(tr("CH_CLAIMED"), 20, UiKit.CYAN))
	else:
		var claim := UiKit.button("%s +%d" % [tr("CH_CLAIM"), int(m["reward"])], func():
			if Progress.claim_mission(kind, index) > 0:
				AudioDirector.play_sfx(&"purchase")
			_fill_missions(), IconGlyph.Icon.SPARK)
		claim.disabled = not m["done"]
		row.add_child(claim)
	return row
