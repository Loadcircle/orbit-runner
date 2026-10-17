extends Control
## Rewards screen: outfits and yo-yo styles. Buy with sparks, unlock with gems,
## gold medals or achievements, preview and equip.

const CHARACTER := preload("res://art/models/CHR_Adventurer.glb")
const YOYO := preload("res://art/models/PROP_YoyoDisc.glb")

var _kind := CosmeticInfo.Kind.OUTFIT
var _list: VBoxContainer
var _wallet: Label
var _preview_root: Node3D
var _preview_character: Node3D
var _preview_disc: Node3D
var _preview_item: CosmeticInfo
var _tabs: TabBar


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.07, 0.17, 0.55)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24.0)
	var box := UiKit.vbox(12)
	margin.add_child(box)
	var header := UiKit.hbox(16)
	box.add_child(header)
	header.add_child(UiKit.icon_button(IconGlyph.Icon.BACK, handle_back, 70))
	header.add_child(UiKit.label(tr("MENU_REWARDS"), 42))
	_tabs = TabBar.new()
	_tabs.add_theme_font_size_override("font_size", 26)
	_tabs.clip_tabs = false
	_tabs.add_tab(tr("WARDROBE_OUTFITS"))
	_tabs.add_tab(tr("WARDROBE_YOYOS"))
	_tabs.tab_changed.connect(func(i: int):
		_kind = CosmeticInfo.Kind.OUTFIT if i == 0 else CosmeticInfo.Kind.YOYO
		_refresh())
	header.add_child(_tabs)
	header.add_child(UiKit.spacer())
	header.add_child(UiKit.glyph(IconGlyph.Icon.SPARK, UiKit.GOLD, 38))
	_wallet = UiKit.label("", 32)
	header.add_child(_wallet)

	var body := UiKit.hbox(18)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var preview_panel := UiKit.panel()
	preview_panel.custom_minimum_size = Vector2(420, 0)
	body.add_child(preview_panel)
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_child(container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	container.add_child(viewport)
	_build_preview(viewport)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = UiKit.vbox(12)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_refresh()


func handle_back() -> void:
	SceneRouter.go_to(SceneRouter.MAIN_MENU)


func _process(delta: float) -> void:
	if _preview_root:
		_preview_root.rotation.y = sin(Time.get_ticks_msec() * 0.0008) * 0.9


func _build_preview(viewport: SubViewport) -> void:
	_preview_root = Node3D.new()
	viewport.add_child(_preview_root)
	_preview_character = CHARACTER.instantiate()
	_preview_character.rotation.y = PI  # face the preview camera
	_preview_root.add_child(_preview_character)
	var anim := _preview_character.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("Idle"):
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle")
	_preview_disc = YOYO.instantiate()
	_preview_disc.position = Vector3(0, 0.02, 0)
	_preview_disc.scale = Vector3.ONE * 0.7
	_preview_root.add_child(_preview_disc)
	var camera := Camera3D.new()
	camera.fov = 35
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.4, 4.6), Vector3(0, 0.8, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 30, 0)
	light.light_energy = 1.3
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.8, 1.0)
	env.environment.ambient_light_energy = 0.8
	viewport.add_child(env)
	_apply_preview()


func _apply_preview() -> void:
	var outfit := Progress.equipped(CosmeticInfo.Kind.OUTFIT)
	var yoyo := Progress.equipped(CosmeticInfo.Kind.YOYO)
	if _preview_item:
		if _preview_item.kind == CosmeticInfo.Kind.OUTFIT:
			outfit = _preview_item
		else:
			yoyo = _preview_item
	# Reset to the base colours, then apply.
	for node in _preview_root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, null)
	PlayerVisual.recolor(_preview_character, outfit.colors)
	PlayerVisual.recolor(_preview_character, yoyo.colors)
	PlayerVisual.recolor(_preview_disc, yoyo.colors)


func _refresh() -> void:
	_wallet.text = str(Progress.sparks())
	for child in _list.get_children():
		child.queue_free()
	for item in Progress.COSMETIC_CATALOG.of_kind(_kind):
		_list.add_child(_item_row(item))
	_apply_preview()


func _item_row(item: CosmeticInfo) -> Control:
	var panel := UiKit.panel()
	var row := UiKit.hbox(14)
	panel.add_child(row)
	var swatches := UiKit.hbox(4)
	row.add_child(swatches)
	var shown := 0
	for key in item.colors:
		if shown >= 3:
			break
		var sw := ColorRect.new()
		sw.color = item.colors[key]
		sw.custom_minimum_size = Vector2(28, 56)
		swatches.add_child(sw)
		shown += 1
	var col := UiKit.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	col.add_child(UiKit.label(tr(item.title_key), 28))
	var owned := Progress.owns(item.id)
	var equipped := Progress.equipped(item.kind) == item
	var status: String
	if equipped:
		status = tr("WARDROBE_EQUIPPED")
	elif owned:
		status = tr("WARDROBE_OWNED")
	else:
		var p := Progress.unlock_progress(item)
		match item.unlock:
			CosmeticInfo.Unlock.SPARKS:
				status = tr("WARDROBE_COST") % item.cost
			CosmeticInfo.Unlock.GEMS:
				status = tr("WARDROBE_NEED_GEMS") % [p.x, p.y]
			CosmeticInfo.Unlock.GOLD_MEDALS:
				status = tr("WARDROBE_NEED_GOLD") % [p.x, p.y]
			CosmeticInfo.Unlock.MASTERY:
				status = tr("WARDROBE_NEED_MASTERY") % [tr(Progress.LEVEL_CATALOG.world_title_keys[item.cost]), p.x, p.y]
			CosmeticInfo.Unlock.ACHIEVEMENT:
				var a := Progress.ACHIEVEMENT_CATALOG.get_achievement(item.achievement_id)
				status = tr("WARDROBE_NEED_ACH") % (tr(a.title_key) if a else "?")
	col.add_child(UiKit.label(status, 20, UiKit.GOLD if equipped else UiKit.DIM))
	var preview := UiKit.button(tr("WARDROBE_PREVIEW"), func():
		_preview_item = item
		_apply_preview())
	row.add_child(preview)
	if owned and not equipped:
		row.add_child(UiKit.button(tr("WARDROBE_EQUIP"), func():
			Progress.equip(item)
			_preview_item = null
			_refresh(), IconGlyph.Icon.CHECK))
	elif not owned and item.unlock == CosmeticInfo.Unlock.SPARKS:
		var buy := UiKit.button(tr("WARDROBE_BUY"), func():
			if Progress.buy(item):
				AudioDirector.play_sfx(&"purchase")
				Progress.equip(item)
				_preview_item = null
				_refresh(), IconGlyph.Icon.SPARK)
		buy.disabled = not Progress.can_buy(item)
		row.add_child(buy)
	elif not owned:
		row.add_child(UiKit.glyph(IconGlyph.Icon.LOCK, Color(0.75, 0.8, 0.9), 44))
	return panel
