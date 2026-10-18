extends Control
## Season: its levels, the time left and the standings against friends and
## everyone. Between seasons it shows the next start and the last result.

const COLUMNS := 5
## Rows shown around the player when they are outside the top of the board.
const TOP_ROWS := 25

var _season: Dictionary
var _board: VBoxContainer
var _tabs: TabBar
var _countdown: Label
var _countdown_target := 0
var _countdown_key := ""


func _ready() -> void:
	Services.refresh()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.17, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var box := UiKit.vbox(12)
	margin.add_child(box)
	_season = Season.current()
	var header := UiKit.hbox(16)
	box.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, handle_back, 70))
	header.add_child(UiKit.label(Season.title(_season) if not _season.is_empty() else tr("MENU_SEASON"), 42))
	header.add_child(UiKit.spacer())
	header.add_child(EnergyChip.new())
	if _season.is_empty():
		_build_waiting(box)
	else:
		_build_live(box)


func _process(_delta: float) -> void:
	if _countdown and _countdown_target > 0:
		_countdown.text = tr(_countdown_key) % GameClock.format_duration(_countdown_target - GameClock.now())
		if GameClock.now() >= _countdown_target:
			_countdown_target = 0
			SceneRouter.go_to(SceneRouter.SEASON)


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _build_live(box: VBoxContainer) -> void:
	var info := UiKit.hbox(18)
	box.add_child(info)
	info.add_child(UiKit.label(tr(LevelSpec.DIFFICULTY_KEYS[int(_season.get("difficulty", 1))]), 24, UiKit.CYAN))
	_countdown = UiKit.label("", 24, UiKit.GOLD)
	info.add_child(_countdown)
	_countdown_target = Season.ends_at(_season)
	_countdown_key = "SEASON_ENDS_IN"
	info.add_child(UiKit.spacer())
	var totals := Progress.season_totals(String(_season["id"]))
	var rank := Leaderboard.player_rank(_season, GameClock.now())
	info.add_child(UiKit.label(tr("SEASON_YOUR_SCORE") % [int(totals["points"]), rank.x, rank.y], 24))

	var body := UiKit.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	body.add_child(grid)
	for i in Season.level_count(_season):
		grid.add_child(_level_card(i))
	body.add_child(_board_panel())
	_fill_board()
	UiKit.focus_first(grid)


func _build_waiting(box: VBoxContainer) -> void:
	var next := Season.upcoming()
	var col := UiKit.vbox(14)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(col)
	if next.is_empty():
		col.add_child(UiKit.label(tr("SEASON_NONE"), 28, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		col.add_child(UiKit.label(tr("SEASON_NEXT") % [Season.title(next), Season.level_count(next)], 30,
				Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		_countdown = UiKit.label("", 34, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(_countdown)
		_countdown_target = Season.starts_at(next)
		_countdown_key = "SEASON_STARTS_IN"
	var last: Array = Season.finished()
	if not last.is_empty():
		var s: Dictionary = last[0]
		var state := Progress.season_state(String(s["id"]))
		var text := tr("SEASON_LAST_RESULT") % [Season.title(s), int(state["final_rank"]), int(state["final_size"])] \
			if int(state["final_rank"]) > 0 else tr("SEASON_LAST_MISSED") % Season.title(s)
		col.add_child(UiKit.label(text, 24, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))


func _level_card(index: int) -> Button:
	var key := Season.run_key(_season, index)
	var rec := Progress.season_record(key)
	var unlocked := Progress.season_level_unlocked(_season, index)
	var card := Button.new()
	card.custom_minimum_size = Vector2(150, 112)
	card.disabled = not unlocked
	card.focus_mode = Control.FOCUS_ALL
	card.pressed.connect(func():
		AudioDirector.play_sfx(&"ui_confirm")
		SceneRouter.play_generated(Season.level_spec(_season, index), key))
	var inner := UiKit.vbox(2)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 12
	inner.offset_top = 8
	inner.offset_right = -12
	inner.offset_bottom = -8
	card.add_child(inner)
	var top := UiKit.hbox(6)
	inner.add_child(top)
	top.add_child(UiKit.label(str(index + 1), 32, UiKit.ORANGE))
	top.add_child(UiKit.spacer())
	if not unlocked:
		top.add_child(UiKit.glyph(IconGlyph.Icon.LOCK, Color(0.85, 0.88, 0.95), 30))
	elif bool(rec["completed"]):
		top.add_child(UiKit.glyph(IconGlyph.Icon.MEDAL, UiKit.medal_color(int(rec["medal"])), 32))
	inner.add_child(UiKit.spacer())
	if bool(rec["completed"]):
		inner.add_child(UiKit.label(tr("SEASON_POINTS_SHORT") % int(rec["best_points"]), 20, UiKit.GOLD))
		inner.add_child(UiKit.label(UiKit.format_time(float(rec["best_time"])), 18, UiKit.DIM))
	for node in card.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _board_panel() -> Control:
	var panel := UiKit.panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := UiKit.vbox(8)
	panel.add_child(col)
	var top := UiKit.hbox(12)
	col.add_child(top)
	top.add_child(UiKit.label(tr("SEASON_STANDINGS"), 28, UiKit.ORANGE))
	_tabs = TabBar.new()
	_tabs.add_theme_font_size_override("font_size", 24)
	_tabs.clip_tabs = false
	_tabs.add_tab(tr("SEASON_TAB_FRIENDS"))
	_tabs.add_tab(tr("SEASON_TAB_GLOBAL"))
	_tabs.current_tab = 0 if not Services.social.friends().is_empty() else 1
	_tabs.tab_changed.connect(func(_i: int): _fill_board())
	top.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_board = UiKit.vbox(4)
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_board)
	var note := UiKit.label(tr("SEASON_SIMULATED_NOTE"), 18, UiKit.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(note)
	return panel


func _fill_board() -> void:
	for child in _board.get_children():
		child.queue_free()
	var friends_only := _tabs.current_tab == 0
	var now := GameClock.now()
	var entries := Leaderboard.build(_season, now, friends_only)
	if friends_only and entries.size() <= 1:
		var hint := UiKit.label(tr("SEASON_NO_FRIENDS"), 22, UiKit.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_board.add_child(hint)
		_board.add_child(UiKit.button(tr("MENU_FRIENDS"), func(): SceneRouter.go_to(SceneRouter.FRIENDS),
				IconGlyph.Icon.PEOPLE))
		_board.add_child(UiKit.label(tr("SEASON_NEARBY"), 24, UiKit.ORANGE))
		entries = _around_player(Leaderboard.build(_season, now, false), 3)
	else:
		entries = _trim(entries)
	var last_rank := 0
	for e in entries:
		if last_rank > 0 and int(e["rank"]) > last_rank + 1:
			_board.add_child(UiKit.label("···", 22, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
		last_rank = int(e["rank"])
		_board.add_child(_row(e))


func _trim(entries: Array[Dictionary]) -> Array[Dictionary]:
	if entries.size() <= TOP_ROWS:
		return entries
	var result: Array[Dictionary] = entries.slice(0, TOP_ROWS)
	for e in _around_player(entries, 2):
		if int(e["rank"]) > TOP_ROWS:
			result.append(e)
	return result


func _around_player(entries: Array[Dictionary], span: int) -> Array[Dictionary]:
	for i in entries.size():
		if entries[i]["is_player"]:
			return entries.slice(maxi(i - span, 0), mini(i + span + 1, entries.size()))
	return []


func _row(e: Dictionary) -> Control:
	var row := UiKit.hbox(12)
	var colour := UiKit.GOLD if e["is_player"] else Color.WHITE
	var rank := UiKit.label("%d" % int(e["rank"]), 24, colour, HORIZONTAL_ALIGNMENT_RIGHT)
	rank.custom_minimum_size.x = 48
	row.add_child(rank)
	row.add_child(UiKit.label(String(e["name"]), 24, colour))
	if e["simulated"]:
		# Simulated runners are always marked (see SEASON_SIMULATED_NOTE).
		row.add_child(UiKit.glyph(IconGlyph.Icon.GEM, UiKit.DIM, 18))
	row.add_child(UiKit.spacer())
	row.add_child(UiKit.label("%d/%d" % [int(e["levels"]), Season.level_count(_season)], 20, UiKit.DIM))
	var pts := UiKit.label(str(int(e["points"])), 24, colour, HORIZONTAL_ALIGNMENT_RIGHT)
	pts.custom_minimum_size.x = 90
	row.add_child(pts)
	return row
