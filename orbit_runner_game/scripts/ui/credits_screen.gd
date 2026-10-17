extends Control
## Credits and third-party licence notices (scrolling).

var _scroll: ScrollContainer
var _auto := true
var _celebrate := false


func _ready() -> void:
	_celebrate = Progress.campaign_levels_completed() >= Progress.campaign_level_count()
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.17, 0.55)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var box := UiKit.vbox(10)
	margin.add_child(box)
	var header := UiKit.hbox(16)
	box.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, handle_back, 70))
	header.add_child(UiKit.label(tr("MENU_CREDITS"), 42))
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.gui_input.connect(func(_e): _auto = false)
	box.add_child(_scroll)
	var col := UiKit.vbox(10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(col)
	col.add_child(UiKit.spacer(Vector2(0, 260), false))
	if _celebrate:
		col.add_child(UiKit.title(tr("CREDITS_THANKS"), 48))
		col.add_child(UiKit.spacer(Vector2(0, 30), false))
		var bg_node := get_node_or_null("MenuBackground")
		if bg_node:
			bg_node.call("play_celebration")
	col.add_child(UiKit.title("ORBIT RUNNER", 64))
	for section in [["CREDITS_DESIGN", "CREDITS_TEAM"], ["CREDITS_ART", "CREDITS_ART_BODY"],
			["CREDITS_AUDIO", "CREDITS_AUDIO_BODY"], ["CREDITS_TOOLS", "CREDITS_TOOLS_BODY"]]:
		col.add_child(UiKit.spacer(Vector2(0, 20), false))
		col.add_child(UiKit.label(tr(section[0]), 30, UiKit.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
		var body := UiKit.label(tr(section[1]), 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(body)
	col.add_child(UiKit.spacer(Vector2(0, 30), false))
	col.add_child(UiKit.label(tr("CREDITS_LICENSES"), 30, UiKit.ORANGE, HORIZONTAL_ALIGNMENT_CENTER))
	var godot := UiKit.label(Engine.get_license_text(), 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	godot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(godot)
	var components := PackedStringArray()
	for info in Engine.get_copyright_info():
		var parts: Array = info["parts"]
		var license := ""
		if not parts.is_empty():
			license = str(parts[0].get("license", ""))
		components.append("%s — %s" % [info["name"], license])
	var comp_label := UiKit.label("\n".join(components), 16, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	comp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(comp_label)
	col.add_child(UiKit.spacer(Vector2(0, 300), false))


func _process(delta: float) -> void:
	if _auto:
		_scroll.scroll_vertical += int(ceil(40.0 * delta))


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)
