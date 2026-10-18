class_name ParentalGate
extends RefCounted
## Adult check before purchases and before sharing outside the game, as the
## Google Play Families policy asks of games whose audience includes children:
## a multiplication typed as a number.


static func check() -> bool:
	var a := randi_range(6, 9)
	var b := randi_range(6, 9)
	var m := Modal.new(TranslationServer.translate("GATE_TITLE"),
			TranslationServer.translate("GATE_BODY") % [a, b], 640.0)
	var field := LineEdit.new()
	field.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	field.max_length = 3
	field.custom_minimum_size = Vector2(220, 72)
	field.add_theme_font_size_override("font_size", 36)
	var row := CenterContainer.new()
	row.add_child(field)
	m.content.add_child(row)
	m.add_button(TranslationServer.translate("WORD_CANCEL"), 0)
	m.add_button(TranslationServer.translate("WORD_OK"), 1, IconGlyph.Icon.CHECK, true)
	field.text_submitted.connect(func(_t: String): m.close(1))
	m.ready.connect(func(): field.grab_focus.call_deferred())
	if await m.run() != 1:
		return false
	if field.text.strip_edges() == str(a * b):
		return true
	await Modal.ask(TranslationServer.translate("GATE_TITLE"), TranslationServer.translate("GATE_WRONG"),
			PackedStringArray([TranslationServer.translate("WORD_OK")]))
	return false
