class_name EnergyChip
extends HBoxContainer
## Energy counter for menus: bolt, amount, time to the next point and a
## button to get more.

## False on the shop screen itself.
var show_shop := true

var _amount: Label
var _timer: Label
var _elapsed := 1.0


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	alignment = BoxContainer.ALIGNMENT_END
	var bolt := UiKit.glyph(IconGlyph.Icon.BOLT, UiKit.GOLD, 36)
	bolt.filled = true
	add_child(bolt)
	_amount = UiKit.label("", 28)
	add_child(_amount)
	_timer = UiKit.label("", 20, UiKit.DIM)
	_timer.custom_minimum_size.x = 70
	add_child(_timer)
	if show_shop:
		add_child(UiKit.icon_button(IconGlyph.Icon.CART, func(): SceneRouter.go_to(SceneRouter.STORE), 56))
	Services.energy.changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.5:
		_refresh()


func _refresh() -> void:
	_elapsed = 0.0
	var energy := Services.energy
	if energy.is_unlimited():
		_amount.text = tr("ENERGY_UNLIMITED")
		_timer.text = GameClock.format_duration(energy.unlimited_seconds_left())
		return
	_amount.text = "%d/%d" % [energy.amount(), energy.maximum()]
	_timer.text = GameClock.format_duration(energy.seconds_to_next()) if energy.amount() < energy.maximum() else ""
