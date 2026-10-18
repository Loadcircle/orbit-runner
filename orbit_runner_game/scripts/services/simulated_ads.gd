class_name SimulatedAds
extends AdsProvider
## Stand-in for rewarded ads: a short countdown screen. Closing it early gives
## no reward, like a real rewarded ad.

var seconds := 5.0


func _init(duration: float) -> void:
	seconds = duration


func is_available() -> bool:
	return true


func show_rewarded(_placement: StringName) -> bool:
	var m := Modal.new(tr("AD_SIM_TITLE"), tr("AD_SIM_BODY"))
	var countdown := UiKit.label("", 30, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	m.content.add_child(countdown)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = seconds
	m.content.add_child(bar)
	m.add_button(tr("AD_CLOSE"), 0, IconGlyph.Icon.BACK)
	var claim := m.add_button(tr("AD_CLAIM"), 1, IconGlyph.Icon.BOLT, true)
	claim.disabled = true
	m.ready.connect(func():
		m.create_tween().tween_method(func(t: float):
			bar.value = t
			countdown.text = tr("AD_SIM_LEFT") % ceili(seconds - t)
			if t >= seconds:
				claim.disabled = false
				countdown.text = tr("AD_SIM_DONE"), 0.0, seconds, seconds))
	return await m.run() == 1
