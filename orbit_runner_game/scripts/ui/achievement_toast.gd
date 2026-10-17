class_name AchievementToast
extends CanvasLayer
## Queued pop-up shown whenever an achievement or reward unlocks, on any screen.

var _queue: Array[Dictionary] = []
var _showing := false
var _panel: PanelContainer
var _icon: IconGlyph
var _title: Label
var _body: Label


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var row := UiKit.hbox(14)
	_panel.add_child(row)
	_icon = UiKit.glyph(IconGlyph.Icon.TROPHY, UiKit.GOLD, 54)
	row.add_child(_icon)
	var col := UiKit.vbox(2)
	row.add_child(col)
	_title = UiKit.label("", 22, UiKit.GOLD)
	col.add_child(_title)
	_body = UiKit.label("", 28)
	col.add_child(_body)
	Progress.achievement_unlocked.connect(func(a: AchievementInfo):
		_push(IconGlyph.Icon.TROPHY, tr("TOAST_ACHIEVEMENT"), tr(a.title_key)))
	Progress.cosmetic_unlocked.connect(func(c: CosmeticInfo):
		if c.unlock != CosmeticInfo.Unlock.DEFAULT and c.unlock != CosmeticInfo.Unlock.SPARKS:
			_push(IconGlyph.Icon.SHIRT, tr("TOAST_REWARD"), tr(c.title_key)))


func _push(icon: IconGlyph.Icon, heading: String, text: String) -> void:
	_queue.append({"icon": icon, "heading": heading, "text": text})
	if not _showing:
		_next()


func _next() -> void:
	if _queue.is_empty():
		_showing = false
		_panel.visible = false
		return
	_showing = true
	var item: Dictionary = _queue.pop_front()
	_icon.icon = item["icon"]
	_title.text = item["heading"]
	_body.text = item["text"]
	_panel.visible = true
	_panel.reset_size()
	_panel.position.y = -140.0
	AudioDirector.play_sfx(&"achievement")
	var tween := create_tween()
	tween.tween_property(_panel, "position:y", 96.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(2.4)
	tween.tween_property(_panel, "position:y", -140.0, 0.3).set_ease(Tween.EASE_IN)
	tween.tween_callback(_next)
