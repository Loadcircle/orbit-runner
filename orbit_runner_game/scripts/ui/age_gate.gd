class_name AgeGate
extends RefCounted
## Neutral age screen shown once: the player picks a birth year without any
## hint of the "right" answer (the counter starts at the current year, no age
## is suggested). Only the resulting group is saved.


static func run() -> void:
	var current_year := int(Time.get_date_dict_from_system()["year"])
	var year := [current_year]
	var m := Modal.new(TranslationServer.translate("AGE_TITLE"), TranslationServer.translate("AGE_BODY"), 680.0)
	var row := UiKit.hbox(18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.content.add_child(row)
	var label := UiKit.label(str(year[0]), 48, UiKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	# Created first: lambdas capture locals by value.
	var ok := m.add_button(TranslationServer.translate("WORD_OK"), 1, IconGlyph.Icon.CHECK, true)
	ok.disabled = true
	label.custom_minimum_size.x = 180
	var step := func(delta: int):
		year[0] = clampi(year[0] + delta, current_year - 100, current_year)
		label.text = str(year[0])
		ok.disabled = year[0] == current_year
	for delta in [-10, -1]:
		row.add_child(UiKit.button("%d" % delta, func(): step.call(delta), IconGlyph.Icon.NONE, 96))
	row.add_child(label)
	for delta in [1, 10]:
		row.add_child(UiKit.button("+%d" % delta, func(): step.call(delta), IconGlyph.Icon.NONE, 96))
	# Back counts as "not answered": treated as a child until answered.
	m.cancel_value = 0
	if await m.run() != 1:
		return
	# Whoever turns 13 this year may still be 12: count them as children.
	var group := Services.AgeGroup.TEEN_OR_ADULT if current_year - year[0] > 13 else Services.AgeGroup.CHILD
	Services.set_age_group(group)
