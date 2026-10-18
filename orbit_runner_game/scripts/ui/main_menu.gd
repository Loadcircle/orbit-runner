extends Control
## Main menu: continue the campaign, season, level select, challenges,
## rewards, options and credits; energy, shop, friends, inbox and achievements.

var _overlay: Control
var _unread: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 28.0)
	var layout := UiKit.hbox(0)
	margin.add_child(layout)

	var left := UiKit.vbox(8)
	left.custom_minimum_size.x = 470
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(left)
	var logo := UiKit.title("ORBIT RUNNER", 64)
	logo.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	left.add_child(logo)
	left.add_child(UiKit.spacer(Vector2(0, 6), false))
	var next_index := Progress.next_level_index()
	var levels := Progress.levels()
	var play_text := tr("MENU_PLAY") if next_index == 0 and not Progress.is_completed(levels[0].id) \
		else "%s: %s" % [tr("MENU_CONTINUE"), tr(levels[next_index].title_key)]
	var play := UiKit.button(play_text, func(): SceneRouter.play_level(next_index), IconGlyph.Icon.PLAY, 460)
	play.add_theme_stylebox_override("normal", _accent_style())
	left.add_child(play)
	var season := Season.current()
	var season_text := tr("MENU_SEASON")
	if not season.is_empty():
		season_text = Season.title(season)
	left.add_child(UiKit.button(season_text, func(): SceneRouter.go_to(SceneRouter.SEASON), IconGlyph.Icon.FLAG, 460))
	left.add_child(UiKit.button(tr("MENU_LEVELS"), func(): SceneRouter.go_to(SceneRouter.LEVEL_SELECT), IconGlyph.Icon.STAR, 460))
	var challenges := UiKit.button(tr("MENU_CHALLENGES"), func(): SceneRouter.go_to(SceneRouter.CHALLENGES),
			IconGlyph.Icon.CLOCK, 460)
	if Progress.missions.claimable_count() > 0:
		challenges.text += "  (%d)" % Progress.missions.claimable_count()
	left.add_child(challenges)
	left.add_child(UiKit.button(tr("MENU_REWARDS"), func(): SceneRouter.go_to("res://scenes/ui/wardrobe_screen.tscn"),
			IconGlyph.Icon.SHIRT, 460))
	var row := UiKit.hbox(12)
	left.add_child(row)
	var settings := UiKit.button(tr("MENU_SETTINGS"), _open_settings, IconGlyph.Icon.GEAR)
	settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(settings)
	var credits := UiKit.button(tr("MENU_CREDITS"), func(): SceneRouter.go_to("res://scenes/ui/credits_screen.tscn"))
	credits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(credits)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		left.add_child(UiKit.button(tr("MENU_QUIT"), func(): get_tree().quit(), IconGlyph.Icon.BACK, 460))

	layout.add_child(UiKit.spacer())
	var right := UiKit.vbox(10)
	layout.add_child(right)
	right.add_child(EnergyChip.new())
	var shortcuts := UiKit.hbox(10)
	shortcuts.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(shortcuts)
	shortcuts.add_child(UiKit.icon_button(IconGlyph.Icon.PEOPLE, func(): SceneRouter.go_to(SceneRouter.FRIENDS), 70))
	shortcuts.add_child(UiKit.icon_button(IconGlyph.Icon.TROPHY,
			func(): SceneRouter.go_to("res://scenes/ui/achievements_screen.tscn"), 70))
	var bell := UiKit.icon_button(IconGlyph.Icon.BELL, _open_inbox, 70)
	shortcuts.add_child(bell)
	_unread = UiKit.label("", 20, UiKit.ORANGE)
	_unread.position = Vector2(48, -6)
	bell.add_child(_unread)
	Services.notifications.inbox_changed.connect(_update_unread)
	_update_unread()
	var wallet := UiKit.panel()
	right.add_child(wallet)
	var stats := UiKit.vbox(6)
	wallet.add_child(stats)
	stats.add_child(_stat_row(IconGlyph.Icon.SPARK, UiKit.GOLD, str(Progress.sparks())))
	stats.add_child(_stat_row(IconGlyph.Icon.GEM, UiKit.GEM, "%d/%d" % [Progress.gems_collected(), Progress.gems_available()]))
	stats.add_child(_stat_row(IconGlyph.Icon.MEDAL, UiKit.GOLD, "%d/%d" % [Progress.medal_count(Progress.Medal.GOLD),
			Progress.campaign_level_count()]))
	stats.add_child(_stat_row(IconGlyph.Icon.TROPHY, UiKit.ORANGE, "%d/%d" % [Progress.achievements_unlocked_count(),
			Progress.ACHIEVEMENT_CATALOG.achievements.size()]))
	UiKit.focus_first(left)
	if Services.age_group() == Services.AgeGroup.UNKNOWN:
		_ask_age.call_deferred()


func _ask_age() -> void:
	await AgeGate.run()
	Services.notifications.request_permission()


func _open_inbox() -> void:
	await NotificationInbox.open()
	_update_unread()


func _update_unread() -> void:
	var count := Services.notifications.unread_count()
	_unread.text = str(count) if count > 0 else ""


func handle_back() -> void:
	if _overlay:
		_overlay.call("close")
	else:
		SceneRouter.go_to(SceneRouter.TITLE)


func _open_settings() -> void:
	var panel := SettingsPanel.new()
	_overlay = panel
	panel.closed.connect(func():
		_overlay = null
		# Rebuild to refresh texts after a language change.
		SceneRouter.go_to(SceneRouter.MAIN_MENU))
	add_child(panel)


func _stat_row(icon: IconGlyph.Icon, color: Color, text: String) -> HBoxContainer:
	var row := UiKit.hbox(10)
	row.add_child(UiKit.glyph(icon, color, 34))
	var l := UiKit.label(text, 28)
	l.custom_minimum_size.x = 110
	row.add_child(l)
	return row


func _accent_style() -> StyleBoxFlat:
	var style := (get_theme_stylebox("normal", "Button") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = Color(0.95, 0.5, 0.12)
	style.border_color = Color(0.62, 0.3, 0.05)
	return style
