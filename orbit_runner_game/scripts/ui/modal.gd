class_name Modal
extends CanvasLayer
## Centred dialog above every screen (also over a paused level). Build it, add
## buttons, then `await modal.run()` for the value of the pressed button.
## The Android back button closes the top modal with `cancel_value`.

signal chosen(value: int)

const CANCEL := -1

static var _stack: Array[Modal] = []

var content: VBoxContainer
var buttons: HBoxContainer
var cancel_value := CANCEL
var _panel: PanelContainer


func _init(title := "", body := "", width := 720.0) -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UiKit.dim_background())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	_panel = UiKit.panel()
	_panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(_panel)
	content = UiKit.vbox(14)
	_panel.add_child(content)
	if title != "":
		content.add_child(UiKit.title(title, 40))
	if body != "":
		var label := UiKit.label(body, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(label)
	buttons = UiKit.hbox(14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER


## Top modal on screen, if any (the scene router sends the back button to it).
static func top() -> Modal:
	return _stack.back() if not _stack.is_empty() else null


func add_button(text: String, value: int, icon := IconGlyph.Icon.NONE, accent := false) -> Button:
	var b := UiKit.button(text, func(): close(value), icon)
	if accent:
		# The theme resolves once the button is in the tree.
		b.ready.connect(func(): UiKit.accent(b))
	buttons.add_child(b)
	return b


## Shows the dialog and waits for a button (or back) to close it.
func run() -> int:
	if buttons.get_parent() == null:
		content.add_child(buttons)
	(Engine.get_main_loop() as SceneTree).root.add_child(self)
	_stack.append(self)
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.15)
	UiKit.focus_first(buttons)
	return await chosen


func close(value: int) -> void:
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_stack.erase(self)
	queue_free()
	chosen.emit(value)


func handle_back() -> void:
	close(cancel_value)


## Scene changes cancel every open dialog (they live above the scenes).
static func close_all() -> void:
	for m in _stack.duplicate():
		m.close(m.cancel_value)


## One-call message or question: returns the index of the pressed option.
static func ask(title: String, body: String, options: PackedStringArray, accent := 0) -> int:
	var m := Modal.new(title, body)
	for i in options.size():
		m.add_button(options[i], i, IconGlyph.Icon.NONE, i == accent)
	return await m.run()
