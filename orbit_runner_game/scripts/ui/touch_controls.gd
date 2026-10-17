class_name TouchControls
extends Control
## Multi-touch controls. Feeds the SAME InputMap actions as keyboard/gamepad
## through Input.action_press/action_release, so gameplay has one input path.
##
## Left: floating analog joystick (appears where the thumb lands inside the
## zone). Right: jump (primary), yo-yo and slide/dash buttons. Dragging on free
## space on the right nudges the camera. Mirrored in left-handed mode.

signal camera_drag(pixels: float)

const JOY_RADIUS := 105.0
const DEAD_ZONE := 0.12
const MOVE_ACTIONS := [&"move_left", &"move_right", &"move_forward", &"move_back"]

var player: Player

var _scale := 1.0
var _opacity := 0.65
var _left_handed := false
var _joy_finger := -1
var _joy_center := Vector2.ZERO
var _joy_rest := Vector2.ZERO
var _joy_vector := Vector2.ZERO
var _cam_finger := -1
var _cam_last := Vector2.ZERO
## name -> {action, center, radius, icon, finger, color}
var _buttons: Dictionary = {}
var _glyphs: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons = {
		"jump": {"action": &"jump", "radius": 88.0, "icon": IconGlyph.Icon.JUMP, "color": UiKit.ORANGE, "finger": -1},
		"yoyo": {"action": &"yoyo", "radius": 64.0, "icon": IconGlyph.Icon.YOYO, "color": UiKit.CYAN, "finger": -1},
		"action": {"action": &"action", "radius": 60.0, "icon": IconGlyph.Icon.ACTION, "color": Color(0.75, 0.82, 0.95), "finger": -1},
	}
	for key in _buttons:
		var g := IconGlyph.new()
		g.icon = _buttons[key]["icon"]
		add_child(g)
		_glyphs[key] = g
	Settings.changed.connect(_load_settings)
	resized.connect(_layout)
	_load_settings()


func _load_settings() -> void:
	_scale = float(Settings.get_value("touch_scale"))
	_opacity = float(Settings.get_value("touch_opacity"))
	_left_handed = bool(Settings.get_value("left_handed"))
	_layout()


func _layout() -> void:
	var safe := UiKit.safe_margins()
	var w := size.x
	var h := size.y
	var margin := 40.0
	_joy_rest = Vector2(safe.position.x + margin + JOY_RADIUS * _scale + 20.0, h - safe.size.y - margin - JOY_RADIUS * _scale - 10.0)
	var jump_r: float = _buttons["jump"]["radius"] * _scale
	var anchor := Vector2(w - safe.size.x - margin - jump_r, h - safe.size.y - margin - jump_r)
	_buttons["jump"]["center"] = anchor
	_buttons["yoyo"]["center"] = anchor + Vector2(-30.0, -(jump_r + 80.0 * _scale))
	_buttons["action"]["center"] = anchor + Vector2(-(jump_r + 78.0 * _scale), 10.0)
	if _left_handed:
		_joy_rest.x = w - _joy_rest.x
		for key in _buttons:
			var c: Vector2 = _buttons[key]["center"]
			_buttons[key]["center"] = Vector2(w - c.x, c.y)
	if _joy_finger < 0:
		_joy_center = _joy_rest
	for key in _buttons:
		var r: float = _buttons[key]["radius"] * _scale * 0.62
		var g: IconGlyph = _glyphs[key]
		g.size = Vector2(r * 2.0, r * 2.0)
		g.position = _buttons[key]["center"] - Vector2(r, r)
	queue_redraw()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Yo-yo button dims while the yo-yo is out / unavailable.
	var g: IconGlyph = _glyphs["yoyo"]
	var ready := player == null or (player.yoyo != null and player.yoyo.is_ready() and (player.is_on_floor() or player.yoyo_charges > 0))
	g.modulate.a = 1.0 if ready else 0.35
	var a: IconGlyph = _glyphs["action"]
	var action_ready := player == null or player.is_on_floor() or player.dash_available
	a.modulate.a = 1.0 if action_ready else 0.35
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_on_press(touch.index, touch.position)
		else:
			_on_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _joy_finger:
			_update_joystick(drag.position)
		elif drag.index == _cam_finger:
			camera_drag.emit(drag.position.x - _cam_last.x)
			_cam_last = drag.position


func _on_press(finger: int, pos: Vector2) -> void:
	for key in _buttons:
		var b: Dictionary = _buttons[key]
		if b["finger"] < 0 and pos.distance_to(b["center"]) <= b["radius"] * _scale * 1.25:
			b["finger"] = finger
			Input.action_press(b["action"])
			return
	var in_joy_zone := pos.x < size.x * 0.45 if not _left_handed else pos.x > size.x * 0.55
	if _joy_finger < 0 and in_joy_zone and pos.y > size.y * 0.3:
		_joy_finger = finger
		_joy_center = pos
		_update_joystick(pos)
		return
	if _cam_finger < 0 and pos.y > size.y * 0.15:
		_cam_finger = finger
		_cam_last = pos


func _on_release(finger: int) -> void:
	for key in _buttons:
		var b: Dictionary = _buttons[key]
		if b["finger"] == finger:
			b["finger"] = -1
			Input.action_release(b["action"])
	if finger == _joy_finger:
		_joy_finger = -1
		_joy_vector = Vector2.ZERO
		_joy_center = _joy_rest
		_apply_joystick()
	if finger == _cam_finger:
		_cam_finger = -1


func _update_joystick(pos: Vector2) -> void:
	var r := JOY_RADIUS * _scale
	var offset := pos - _joy_center
	# Let the base follow the thumb when it goes past the edge.
	if offset.length() > r * 1.3:
		_joy_center = pos - offset.normalized() * r * 1.3
		offset = pos - _joy_center
	_joy_vector = (offset / r).limit_length(1.0)
	_apply_joystick()


func _apply_joystick() -> void:
	var v := _joy_vector
	if v.length() < DEAD_ZONE:
		v = Vector2.ZERO
	else:
		v = v.normalized() * inverse_lerp(DEAD_ZONE, 1.0, minf(v.length(), 1.0))
	_set_axis(&"move_left", &"move_right", v.x)
	_set_axis(&"move_forward", &"move_back", v.y)


func _set_axis(negative: StringName, positive: StringName, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative, -value)
		Input.action_release(positive)
	elif value > 0.0:
		Input.action_press(positive, value)
		Input.action_release(negative)
	else:
		Input.action_release(negative)
		Input.action_release(positive)


## Releases every action (called on pause, hide and scene exit).
func release_all() -> void:
	for key in _buttons:
		_buttons[key]["finger"] = -1
		Input.action_release(_buttons[key]["action"])
	_joy_finger = -1
	_cam_finger = -1
	_joy_vector = Vector2.ZERO
	_joy_center = _joy_rest
	for action in MOVE_ACTIONS:
		Input.action_release(action)
	queue_redraw()


func _exit_tree() -> void:
	release_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not visible:
		release_all()


func _draw() -> void:
	var a := _opacity
	var r := JOY_RADIUS * _scale
	draw_circle(_joy_center, r, Color(1, 1, 1, 0.12 * a + 0.05))
	draw_arc(_joy_center, r, 0, TAU, 48, Color(1, 1, 1, 0.55 * a), 4.0)
	# Direction ticks make the joystick readable even when idle.
	for i in 4:
		var dir := Vector2.from_angle(i * PI / 2.0)
		draw_line(_joy_center + dir * r * 0.72, _joy_center + dir * r * 0.88, Color(1, 1, 1, 0.5 * a), 4.0)
	var knob := _joy_center + _joy_vector * r
	draw_circle(knob, r * 0.42, Color(1, 1, 1, 0.45 * a + 0.1))
	draw_arc(knob, r * 0.42, 0, TAU, 32, Color(UiKit.DARK, 0.5 * a), 3.0)
	for key in _buttons:
		var b: Dictionary = _buttons[key]
		var c: Vector2 = b["center"]
		var br: float = b["radius"] * _scale
		var pressed: bool = b["finger"] >= 0
		var col: Color = b["color"]
		draw_circle(c, br, Color(col.darkened(0.45), (0.55 if pressed else 0.35) * a + 0.1))
		draw_arc(c, br, 0, TAU, 48, Color(col, 0.9 * a + 0.1), 6.0 if key == "jump" else 4.0)
		if pressed:
			draw_circle(c, br * 0.9, Color(col, 0.35))
