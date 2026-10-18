extends Control
## Shop: energy for ads, energy packs, unlimited energy, sparks and the
## season pass (coming later). Purchases go through the parental gate and the
## store provider (simulated until Google Play Billing is integrated).

var _cards: HBoxContainer
var _sparks: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.17, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var box := UiKit.vbox(16)
	margin.add_child(box)
	var header := UiKit.hbox(16)
	box.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, handle_back, 70))
	header.add_child(UiKit.label(tr("MENU_STORE"), 42))
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.glyph(IconGlyph.Icon.SPARK, UiKit.GOLD, 34))
	_sparks = UiKit.label(str(Progress.sparks()), 28)
	header.add_child(_sparks)
	var chip := EnergyChip.new()
	chip.show_shop = false
	header.add_child(chip)
	Progress.wallet_changed.connect(_on_wallet_changed)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_cards = UiKit.hbox(12)
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)
	_fill()
	var note := UiKit.label(tr("STORE_SIM_NOTE"), 18, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	UiKit.focus_first(_cards)


func _on_wallet_changed(value: int) -> void:
	_sparks.text = str(value)


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _fill() -> void:
	for child in _cards.get_children():
		child.queue_free()
	var left := Services.energy.ads_left_today()
	var ad := _card(IconGlyph.Icon.PLAY, tr("STORE_AD_TITLE") % Services.economy.ad_energy,
			tr("STORE_AD_DESC") % left, tr("STORE_WATCH"), func():
				await Services.watch_ad_for_energy()
				_fill())
	ad.get_meta("button").disabled = left <= 0 or not Services.ads.is_available()
	_cards.add_child(ad)
	for product in Services.economy.products:
		var p: StoreProduct = product
		var coming := p.kind == StoreProduct.Kind.SEASON_PASS
		var card := _card(_icon_for(p), tr(p.title_key), tr(p.desc_key),
				tr("STORE_SOON") if coming else Services.store.price(p), func():
					if await Services.buy(p):
						_fill(), p.featured)
		card.get_meta("button").disabled = coming or not Services.store.is_available()
		_cards.add_child(card)


func _card(icon: IconGlyph.Icon, title: String, desc: String, action: String, on_press: Callable,
		featured := false) -> PanelContainer:
	var card := UiKit.panel()
	card.custom_minimum_size = Vector2(220, 360)
	var col := UiKit.vbox(10)
	card.add_child(col)
	var glyph := UiKit.glyph(icon, UiKit.GOLD if featured else UiKit.CYAN, 80)
	glyph.filled = true
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(glyph)
	var t := UiKit.label(title, 26, UiKit.GOLD if featured else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(t)
	var d := UiKit.label(desc, 20, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(d)
	var b := UiKit.button(action, on_press)
	if featured:
		b.ready.connect(func(): UiKit.accent(b))
	col.add_child(b)
	card.set_meta("button", b)
	return card


func _icon_for(p: StoreProduct) -> IconGlyph.Icon:
	match p.kind:
		StoreProduct.Kind.SPARKS:
			return IconGlyph.Icon.SPARK
		StoreProduct.Kind.SEASON_PASS:
			return IconGlyph.Icon.FLAG
	return IconGlyph.Icon.BOLT
