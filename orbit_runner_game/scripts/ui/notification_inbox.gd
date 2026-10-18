class_name NotificationInbox
extends RefCounted
## In-game list of reminders and messages (newest first).


static func open() -> void:
	var center := Services.notifications
	var m := Modal.new(TranslationServer.translate("INBOX_TITLE"), "", 820.0)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	m.content.add_child(scroll)
	var list := UiKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	if center.inbox().is_empty():
		list.add_child(UiKit.label(TranslationServer.translate("INBOX_EMPTY"), 24, UiKit.DIM, HORIZONTAL_ALIGNMENT_CENTER))
	for message in center.inbox():
		var row := UiKit.hbox(12)
		list.add_child(row)
		row.add_child(UiKit.glyph(IconGlyph.Icon.BELL, UiKit.GOLD if not message["read"] else UiKit.DIM, 34))
		var col := UiKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(UiKit.label(NotificationCenter.title_of(message), 24, Color.WHITE if not message["read"] else UiKit.DIM))
		var body := UiKit.label(NotificationCenter.body_of(message), 20, UiKit.DIM)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(body)
		var ago := maxi(GameClock.now() - int(message["at"]), 0)
		row.add_child(UiKit.label(TranslationServer.translate("TIME_AGO") % GameClock.format_duration(ago), 18, UiKit.DIM))
	m.add_button(TranslationServer.translate("WORD_CLOSE"), 0, IconGlyph.Icon.CHECK)
	await m.run()
	center.mark_all_read()
