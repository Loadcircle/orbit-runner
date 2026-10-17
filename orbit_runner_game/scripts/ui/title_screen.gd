extends Control
## Title screen: logo over the animated backdrop; any input continues.

var _hint: Label
var _time := 0.0
var _leaving := false


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var box := UiKit.vbox(6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(box)
	box.add_child(UiKit.spacer(Vector2(0, 40)))
	var logo := UiKit.title("ORBIT RUNNER", 104)
	logo.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	logo.add_theme_constant_override("outline_size", 22)
	box.add_child(logo)
	var tagline := UiKit.label(tr("TITLE_TAGLINE"), 30, UiKit.CYAN, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(tagline)
	box.add_child(UiKit.spacer(Vector2(0, 120)))
	_hint = UiKit.label(tr("TITLE_PRESS_TOUCH") if OS.has_feature("mobile") else tr("TITLE_PRESS_KEY"), 32,
			Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	box.add_child(UiKit.spacer(Vector2(0, 30)))
	var version := UiKit.label("v%s" % ProjectSettings.get_setting("application/config/version"), 18, UiKit.DIM)
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -120
	version.offset_top = -40
	add_child(version)


func _process(delta: float) -> void:
	_time += delta
	_hint.modulate.a = 0.55 + 0.45 * sin(_time * 3.0)


func _input(event: InputEvent) -> void:
	if _leaving or _time < 0.6:
		return
	var pressed: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo) \
		or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		_leaving = true
		AudioDirector.play_sfx(&"ui_confirm")
		SceneRouter.go_to(SceneRouter.MAIN_MENU)


func handle_back() -> void:
	get_tree().quit()
