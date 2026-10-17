class_name ResultsScreen
extends CanvasLayer
## End-of-level summary: time, medal, gems, sparks, records and rewards.

var _level: Level
var _root: Control


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func open(level: Level, summary: Dictionary) -> void:
	_level = level
	visible = true
	_build(summary)


func handle_back() -> void:
	_go_select()


func _build(summary: Dictionary) -> void:
	if _root:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UiKit.dim_background())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := UiKit.panel()
	panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(panel)
	var box := UiKit.vbox(12)
	panel.add_child(box)
	var info := _level.info
	box.add_child(UiKit.title(tr("RESULTS_TITLE"), 48))
	if info:
		box.add_child(UiKit.label(tr(info.title_key), 28, UiKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER))

	var stats := UiKit.hbox(40)
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(stats)
	# Medal
	var medal: int = summary.get("medal", 0)
	if info and not info.is_tutorial:
		var medal_box := UiKit.vbox(4)
		var medal_glyph := UiKit.glyph(IconGlyph.Icon.MEDAL, UiKit.medal_color(medal), 110)
		medal_box.add_child(medal_glyph)
		medal_box.add_child(UiKit.label(tr(["", "MEDAL_BRONZE", "MEDAL_SILVER", "MEDAL_GOLD"][medal]), 24,
				UiKit.medal_color(medal), HORIZONTAL_ALIGNMENT_CENTER))
		stats.add_child(medal_box)
		medal_glyph.pivot_offset = Vector2(55, 55)
		medal_glyph.scale = Vector2(0.2, 0.2)
		create_tween().tween_property(medal_glyph, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.2)
		AudioDirector.play_sfx(&"medal")
	# Time and records
	var times := UiKit.vbox(6)
	stats.add_child(times)
	var time_row := UiKit.hbox(8)
	time_row.add_child(UiKit.glyph(IconGlyph.Icon.CLOCK, UiKit.ORANGE, 34))
	time_row.add_child(UiKit.label(UiKit.format_time(_level.elapsed), 40))
	times.add_child(time_row)
	if summary.get("new_best", false) and not summary.get("first_clear", false):
		times.add_child(UiKit.label(tr("RESULTS_NEW_BEST"), 24, UiKit.GOLD))
	elif info:
		times.add_child(UiKit.label("%s %s" % [tr("RESULTS_BEST"), UiKit.format_time(Progress.record(info.id)["best_time"])],
				22, UiKit.DIM))
	if info and not info.is_tutorial:
		times.add_child(UiKit.label("%s %s   %s %s" % [tr("MEDAL_GOLD"), UiKit.format_time(info.gold_time),
				tr("MEDAL_SILVER"), UiKit.format_time(info.silver_time)], 20, UiKit.DIM))
	# Collectibles
	var collect := UiKit.vbox(6)
	stats.add_child(collect)
	var gem_row := UiKit.hbox(6)
	for i in 3:
		var got: bool = _level.gems[i] or _level.gem_already_owned(i)
		var g := UiKit.glyph(IconGlyph.Icon.GEM, UiKit.GEM if got else Color(1, 1, 1, 0.5), 38)
		g.filled = got
		gem_row.add_child(g)
	collect.add_child(gem_row)
	var spark_row := UiKit.hbox(6)
	spark_row.add_child(UiKit.glyph(IconGlyph.Icon.SPARK, UiKit.GOLD, 32))
	spark_row.add_child(UiKit.label("%d/%d" % [_level.sparks, _level.sparks_total], 28))
	collect.add_child(spark_row)
	if _level.respawns == 0:
		collect.add_child(UiKit.label(tr("RESULTS_FLAWLESS"), 20, UiKit.CYAN))

	# Rewards
	var rewards: Array = []
	if summary.get("sparks_earned", 0) > 0:
		rewards.append("+%d %s" % [summary["sparks_earned"], tr("WORD_SPARKS")])
	if summary.get("new_gems", 0) > 0:
		rewards.append("+%d %s" % [summary["new_gems"], tr("WORD_GEMS")])
	for a in summary.get("achievements", []):
		if a:
			rewards.append("%s: %s" % [tr("WORD_ACHIEVEMENT"), tr(a.title_key)])
	for c in summary.get("cosmetics", []):
		if c:
			rewards.append("%s: %s" % [tr("WORD_UNLOCKED"), tr(c.title_key)])
	if summary.get("first_clear", false) and SceneRouter.has_next_level():
		rewards.append(tr("RESULTS_NEXT_UNLOCKED"))
	if not rewards.is_empty():
		var reward_label := UiKit.label("\n".join(rewards), 22, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(reward_label)

	var buttons := UiKit.hbox(14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	buttons.add_child(UiKit.button(tr("RESULTS_RETRY"), func(): SceneRouter.play_level(SceneRouter.current_level_index),
			IconGlyph.Icon.RESTART))
	buttons.add_child(UiKit.button(tr("RESULTS_LEVELS"), _go_select, IconGlyph.Icon.HOME))
	if SceneRouter.has_next_level():
		var next := UiKit.button(tr("RESULTS_NEXT"), func(): SceneRouter.play_level(SceneRouter.current_level_index + 1),
				IconGlyph.Icon.PLAY)
		buttons.add_child(next)
		next.grab_focus.call_deferred()
	else:
		var end := UiKit.button(tr("RESULTS_FINALE"), func(): SceneRouter.go_to("res://scenes/ui/credits_screen.tscn"),
				IconGlyph.Icon.TROPHY)
		buttons.add_child(end)
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = Vector2(380, 250)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _go_select() -> void:
	SceneRouter.go_to(SceneRouter.LEVEL_SELECT, {"world": _level.info.world_index if _level.info else 0})
