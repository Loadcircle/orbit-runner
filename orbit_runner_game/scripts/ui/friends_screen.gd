extends Control
## Account and friends: player name, Google/Facebook sign-in (not for children),
## friends who play and invitation codes.

var _account_box: VBoxContainer
var _friends_box: VBoxContainer


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
	var box := UiKit.vbox(14)
	margin.add_child(box)
	var header := UiKit.hbox(16)
	box.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, handle_back, 70))
	header.add_child(UiKit.label(tr("MENU_FRIENDS"), 42))
	var body := UiKit.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var left := UiKit.panel()
	left.custom_minimum_size.x = 600
	body.add_child(left)
	_account_box = UiKit.vbox(12)
	left.add_child(_account_box)
	var right := UiKit.panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_friends_box = UiKit.vbox(10)
	_friends_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_friends_box)
	Services.account_changed.connect(_refresh)
	_refresh()
	UiKit.focus_first(_account_box)


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _refresh() -> void:
	_fill_account()
	_fill_friends()


func _fill_account() -> void:
	for child in _account_box.get_children():
		child.queue_free()
	_account_box.add_child(UiKit.label(tr("FRIENDS_YOUR_NAME"), 24, UiKit.ORANGE))
	var name_row := UiKit.hbox(10)
	_account_box.add_child(name_row)
	if Services.is_child():
		name_row.add_child(UiKit.label(Services.display_name(), 30))
		name_row.add_child(UiKit.spacer())
		name_row.add_child(UiKit.button(tr("FRIENDS_NEW_NAME"), func():
			Services.set_display_name(Services.random_safe_name(str(randi())), true), IconGlyph.Icon.RESTART))
	else:
		var field := LineEdit.new()
		field.text = Services.display_name()
		field.max_length = 16
		field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		field.add_theme_font_size_override("font_size", 28)
		field.text_submitted.connect(func(t: String): Services.set_display_name(t, false))
		field.focus_exited.connect(func(): Services.set_display_name(field.text, false))
		name_row.add_child(field)

	_account_box.add_child(UiKit.label(tr("FRIENDS_ACCOUNT"), 24, UiKit.ORANGE))
	if Services.is_child():
		var note := UiKit.label(tr("FRIENDS_CHILD_NOTE"), 20, UiKit.DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_account_box.add_child(note)
	elif Services.auth.is_signed_in():
		var provider := tr("PROVIDER_" + String(Services.auth.provider()).to_upper())
		_account_box.add_child(UiKit.label(tr("FRIENDS_LINKED") % provider, 24))
		_account_box.add_child(UiKit.button(tr("FRIENDS_SIGN_OUT"), func(): Services.sign_out(), IconGlyph.Icon.BACK))
	else:
		for provider in AuthProvider.PROVIDERS:
			var which: StringName = provider
			_account_box.add_child(UiKit.button(tr("FRIENDS_CONNECT") % tr("PROVIDER_" + String(which).to_upper()),
					func(): await Services.sign_in(which), IconGlyph.Icon.PEOPLE, 540))

	_account_box.add_child(UiKit.label(tr("FRIENDS_INVITE"), 24, UiKit.ORANGE))
	var code_row := UiKit.hbox(10)
	_account_box.add_child(code_row)
	code_row.add_child(UiKit.label(Services.social.invite_code(), 30, UiKit.GOLD))
	code_row.add_child(UiKit.spacer())
	code_row.add_child(UiKit.button(tr("FRIENDS_COPY_INVITE"), _copy_invite, IconGlyph.Icon.CHECK))
	var redeem_row := UiKit.hbox(10)
	_account_box.add_child(redeem_row)
	var code := LineEdit.new()
	code.placeholder_text = "ORB-XXXX"
	code.max_length = 10
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code.add_theme_font_size_override("font_size", 26)
	redeem_row.add_child(code)
	redeem_row.add_child(UiKit.button(tr("FRIENDS_ADD"), func(): _redeem(code.text), IconGlyph.Icon.PEOPLE))


func _fill_friends() -> void:
	for child in _friends_box.get_children():
		child.queue_free()
	_friends_box.add_child(UiKit.label(tr("FRIENDS_LIST"), 28, UiKit.ORANGE))
	var friends := Services.social.friends()
	if friends.is_empty():
		var hint := UiKit.label(tr("FRIENDS_EMPTY"), 22, UiKit.DIM)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_friends_box.add_child(hint)
		return
	var now := GameClock.now()
	var season := Season.current()
	for f in friends:
		var row := UiKit.hbox(12)
		_friends_box.add_child(row)
		var index := int(f["rival"])
		var playing := RivalRoster.is_playing(index, now)
		var dot := UiKit.glyph(IconGlyph.Icon.PEOPLE, UiKit.CYAN if playing else UiKit.DIM, 34)
		dot.filled = true
		row.add_child(dot)
		var col := UiKit.vbox(2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var name_line := UiKit.hbox(6)
		col.add_child(name_line)
		name_line.add_child(UiKit.label(String(f["name"]), 26))
		name_line.add_child(UiKit.glyph(IconGlyph.Icon.GEM, UiKit.DIM, 18))
		var status := tr("FRIENDS_PLAYING") if playing \
			else tr("FRIENDS_SEEN") % RivalRoster.hours_since_played(index, now)
		col.add_child(UiKit.label(status, 20, UiKit.CYAN if playing else UiKit.DIM))
		if not season.is_empty():
			var r := RivalRoster.season_result(index, season, now)
			row.add_child(UiKit.label(tr("SEASON_POINTS_SHORT") % int(r["points"]), 22, UiKit.GOLD))
	var note := UiKit.label(tr("FRIENDS_SIMULATED_NOTE"), 18, UiKit.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_friends_box.add_child(note)


func _copy_invite() -> void:
	if Services.is_child() and not await ParentalGate.check():
		return
	DisplayServer.clipboard_set(Services.social.invite_text())
	AchievementToast.show_message(IconGlyph.Icon.PEOPLE, tr("MENU_FRIENDS"), tr("FRIENDS_COPIED"))


func _redeem(code: String) -> void:
	if Services.is_child() and not await ParentalGate.check():
		return
	var friend := Services.social.redeem(code)
	if friend.is_empty():
		AchievementToast.show_message(IconGlyph.Icon.PEOPLE, tr("MENU_FRIENDS"), tr("FRIENDS_CODE_INVALID"))
		return
	AchievementToast.show_message(IconGlyph.Icon.PEOPLE, tr("MENU_FRIENDS"), tr("FRIENDS_ADDED") % friend["name"])
	_fill_friends()
