class_name PauseMenu
extends CanvasLayer
## Pause overlay: resume, restart, options and safe exit.

signal resume_requested
signal restart_requested
signal quit_requested

var _root: Control
var _settings: SettingsPanel


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UiKit.dim_background())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var box := UiKit.vbox(16)
	panel.add_child(box)
	box.add_child(UiKit.title(tr("PAUSE_TITLE"), 52))
	box.add_child(UiKit.button(tr("PAUSE_RESUME"), func(): resume_requested.emit(), IconGlyph.Icon.PLAY, 420))
	box.add_child(UiKit.button(tr("PAUSE_RESTART"), func(): restart_requested.emit(), IconGlyph.Icon.RESTART, 420))
	box.add_child(UiKit.button(tr("MENU_SETTINGS"), _open_settings, IconGlyph.Icon.GEAR, 420))
	var level := get_parent() as Level
	var tower := level != null and level.mode == LevelSpec.Mode.TOWER
	box.add_child(UiKit.button(tr("PAUSE_END_RUN" if tower else "PAUSE_QUIT"), func(): quit_requested.emit(),
			IconGlyph.Icon.HOME, 420))
	visible = false


func open() -> void:
	visible = true
	var hud := get_parent().get("hud") as Hud
	if hud:
		hud.set_paused_visuals(true)
	UiKit.focus_first(_root)


func close() -> void:
	if _settings:
		_settings.queue_free()
		_settings = null
	visible = false
	var hud := get_parent().get("hud") as Hud
	if hud:
		hud.set_paused_visuals(false)


func handle_back() -> void:
	if _settings:
		_settings.close()
	else:
		resume_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		handle_back()


func _open_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.closed.connect(func():
		_settings = null
		UiKit.focus_first(_root))
	_root.add_child(_settings)
