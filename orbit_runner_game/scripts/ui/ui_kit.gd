class_name UiKit
extends RefCounted
## Small factory for consistently styled UI pieces built in code.

const ORANGE := Color(1.0, 0.6, 0.18)
const CYAN := Color(0.13, 0.83, 0.93)
const GOLD := Color(1.0, 0.8, 0.25)
const SILVER := Color(0.82, 0.86, 0.92)
const BRONZE := Color(0.85, 0.52, 0.28)
const DIM := Color(0.62, 0.7, 0.82)
const GEM := Color(0.44, 0.86, 1.0)
const DARK := Color(0.05, 0.1, 0.22)


static func label(text: String, font_size := 26, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func title(text: String, font_size := 54) -> Label:
	var l := label(text, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.16, 0.38))
	return l


static func button(text: String, on_press: Callable, icon := IconGlyph.Icon.NONE, min_width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, 72)
	b.focus_mode = Control.FOCUS_ALL
	if icon != IconGlyph.Icon.NONE:
		var glyph := IconGlyph.new()
		glyph.icon = icon
		glyph.custom_minimum_size = Vector2(40, 40)
		glyph.set_anchors_preset(Control.PRESET_CENTER_LEFT)
		glyph.position = Vector2(14, -20)
		b.add_child(glyph)
		b.text = "      " + text
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if min_width > 0.0 else HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(func():
		AudioDirector.play_sfx(&"ui_click", -4.0)
		on_press.call())
	return b


static func icon_button(icon: IconGlyph.Icon, on_press: Callable, size_px := 76.0) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(size_px, size_px)
	b.focus_mode = Control.FOCUS_ALL
	var glyph := IconGlyph.new()
	glyph.icon = icon
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glyph.offset_left = 14
	glyph.offset_top = 14
	glyph.offset_right = -14
	glyph.offset_bottom = -14
	b.add_child(glyph)
	b.pressed.connect(func():
		AudioDirector.play_sfx(&"ui_click", -4.0)
		on_press.call())
	return b


static func glyph(icon: IconGlyph.Icon, color := Color.WHITE, size_px := 36.0) -> IconGlyph:
	var g := IconGlyph.new()
	g.icon = icon
	g.color = color
	g.custom_minimum_size = Vector2(size_px, size_px)
	return g


static func panel() -> PanelContainer:
	return PanelContainer.new()


static func vbox(separation := 14) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation := 14) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func spacer(min_size := Vector2(0, 0), expand := true) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func dim_background() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.06, 0.15, 0.6)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r


static func medal_color(medal: int) -> Color:
	match medal:
		Progress.Medal.GOLD:
			return GOLD
		Progress.Medal.SILVER:
			return SILVER
		Progress.Medal.BRONZE:
			return BRONZE
	return Color(0.35, 0.4, 0.5)


static func format_time(seconds: float) -> String:
	if seconds <= 0.0:
		return "--:--.--"
	var minutes := int(seconds) / 60
	var secs := fmod(seconds, 60.0)
	return "%02d:%05.2f" % [minutes, secs]


## Applies safe-area margins (notches, rounded corners) to a full-rect control.
static func apply_safe_area(control: Control, extra := 16.0) -> void:
	var margins := safe_margins()
	control.offset_left = margins.position.x + extra
	control.offset_top = margins.position.y + extra
	control.offset_right = -(margins.size.x + extra)
	control.offset_bottom = -(margins.size.y + extra)


## Returns (left, top) in position and (right, bottom) in size, in UI units.
static func safe_margins() -> Rect2:
	var window_size := Vector2(DisplayServer.window_get_size())
	var safe := Rect2(DisplayServer.get_display_safe_area())
	if window_size.x <= 0 or safe.size.x <= 0 or not OS.has_feature("mobile"):
		return Rect2()
	var tree := Engine.get_main_loop() as SceneTree
	var ui_size := tree.root.get_visible_rect().size
	var k := ui_size.x / window_size.x
	var left := safe.position.x * k
	var top := safe.position.y * k
	var right := (window_size.x - safe.end.x) * k
	var bottom := (window_size.y - safe.end.y) * k
	return Rect2(maxf(left, 0.0), maxf(top, 0.0), maxf(right, 0.0), maxf(bottom, 0.0))


## Focus the first button for keyboard/gamepad navigation on PC.
static func focus_first(root: Node) -> void:
	if OS.has_feature("mobile"):
		return
	for node in root.find_children("*", "Button", true, false):
		var b := node as Button
		if b.is_visible_in_tree() and not b.disabled:
			b.grab_focus.call_deferred()
			return
