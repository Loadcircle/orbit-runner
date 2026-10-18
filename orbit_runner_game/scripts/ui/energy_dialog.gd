class_name EnergyDialog
extends RefCounted
## Shown when an attempt needs more energy: time to the next point, a rewarded
## ad, or the shop.

enum Choice { CLOSE, AD, SHOP }

static var _open := false


static func open() -> void:
	if _open:
		return
	_open = true
	var energy := Services.energy
	var m := Modal.new(TranslationServer.translate("ENERGY_EMPTY_TITLE"), "")
	var row := UiKit.hbox(12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.content.add_child(row)
	row.add_child(UiKit.glyph(IconGlyph.Icon.BOLT, UiKit.GOLD, 56))
	row.add_child(UiKit.label("%d/%d" % [energy.amount(), energy.maximum()], 44))
	var next := UiKit.label("", 24, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	m.content.add_child(next)
	var update := func():
		next.text = TranslationServer.translate("ENERGY_NEXT_IN") % GameClock.format_duration(energy.seconds_to_next())
	update.call()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(update)
	m.add_child(timer)
	m.add_button(TranslationServer.translate("WORD_CLOSE"), Choice.CLOSE)
	var ads_left := energy.ads_left_today()
	var ad := m.add_button(TranslationServer.translate("ENERGY_WATCH_AD") % [Services.economy.ad_energy, ads_left],
			Choice.AD, IconGlyph.Icon.PLAY, true)
	ad.disabled = ads_left <= 0 or not Services.ads.is_available()
	m.add_button(TranslationServer.translate("MENU_STORE"), Choice.SHOP, IconGlyph.Icon.CART)
	var choice := await m.run()
	_open = false
	match choice:
		Choice.AD:
			await Services.watch_ad_for_energy()
		Choice.SHOP:
			SceneRouter.go_to(SceneRouter.STORE)
