extends Node
## Scene changes with a fade, the level being played, and Android back/focus
## handling. Screens may implement `handle_back() -> void`.

const TITLE := "res://scenes/ui/title_screen.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const LEVEL_SELECT := "res://scenes/ui/level_select.tscn"
const CHALLENGES := "res://scenes/ui/challenges_screen.tscn"
const FADE_TIME := 0.25

## Index in Progress.levels() of the level being loaded or played.
var current_level_index := 0
## Optional data handed to the next screen (for example the world tab to open).
var payload: Dictionary = {}
## Spec of the generated level being played (daily, tower); null in the campaign.
var current_spec: LevelSpec

var _layer: CanvasLayer
var _fade: ColorRect
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.get_window().go_back_requested.connect(_on_back_requested)
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.06, 0.1, 0.2, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_fade)
	add_child(AchievementToast.new())


func go_to(path: String, data: Dictionary = {}) -> void:
	await _change(func() -> Error: return get_tree().change_scene_to_file(path), path, data)


## Builds a level on the device (behind the fade) and plays it.
func play_generated(spec: LevelSpec, key: String) -> void:
	current_spec = spec
	await _change(func() -> Error: return get_tree().change_scene_to_node(GeneratedRun.build(spec, key)),
			"generated %s" % spec.key(), {})


func _change(change: Callable, label: String, data: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	payload = data
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await tween.finished
	get_tree().paused = false
	var err: Error = change.call()
	if err != OK:
		push_error("SceneRouter: cannot load %s (%s)" % [label, err])
	await get_tree().process_frame
	await get_tree().process_frame
	tween = create_tween()
	tween.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await tween.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func play_level(index: int) -> void:
	var levels := Progress.levels()
	index = clampi(index, 0, levels.size() - 1)
	current_level_index = index
	current_spec = null
	go_to(levels[index].scene_path)


func current_level() -> LevelInfo:
	return Progress.levels()[current_level_index]


func has_next_level() -> bool:
	return current_level_index + 1 < Progress.levels().size()


func is_busy() -> bool:
	return _busy


func _on_back_requested() -> void:
	_dispatch_back()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop equivalent of the Android back button. Levels consume "pause"
	# first (the current scene receives unhandled input before autoloads).
	if event.is_action_pressed("ui_cancel"):
		_dispatch_back()
		get_viewport().set_input_as_handled()


func _dispatch_back() -> void:
	if _busy:
		return
	var scene := get_tree().current_scene
	if scene and scene.has_method("handle_back"):
		scene.handle_back()
