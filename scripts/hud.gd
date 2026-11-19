class_name HUD
extends CanvasLayer
## In-game UI: health, charges, dodge, depth, gold, minimap, boss bar, banners,
## and the upgrade / dialog (trader, shrine) / pause / game-over panels.
## Built in code so it scales with the window on both PC and mobile.

signal upgrade_chosen(id: String)
signal dialog_chosen(id: String)
signal pause_pressed
signal save_quit_requested
signal abandon_requested
signal retry_requested
signal menu_requested
signal settings_requested

const HP_BAR_WIDTH := 110.0
const MAX_PIPS := 6

var player: Player
var boss: Enemy
var minimap: Minimap

var _pips: Array[ColorRect] = []
var _dodge_fill: ColorRect
var _weapon_label: Label
var _hp_fill: ColorRect
var _hp_label: Label
var _depth_label: Label
var _gold_label: Label
var _banner: Label
var _banner_time := 0.0
var _boss_box: Control
var _boss_fill: ColorRect
var _boss_label: Label
var _overlay: ColorRect
var _upgrade_panel: Control
var _upgrade_title: Label
var _upgrade_row: HBoxContainer
var _dialog_panel: Control
var _dialog_title: Label
var _dialog_text: Label
var _dialog_buttons: VBoxContainer
## Slot machine reels shown inside the dialog for the Cursed Idol.
var reels: SlotReels
var _gameover_panel: Control
var _gameover_label: Label
var _gameover_title: Label
var _retry_button: Button
var _pause_panel: Control
var _ability_bar: AbilityBar
var _hint_box: PanelContainer
var _hint_label: Label
var _fps_label: Label


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Top-left stats ---
	var stats := VBoxContainer.new()
	stats.position = Vector2(10, 8)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_theme_constant_override("separation", 2)
	root.add_child(stats)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(0, 0, 0, 0.6)
	bar_bg.custom_minimum_size = Vector2(HP_BAR_WIDTH + 4, 12)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(bar_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.86, 0.2, 0.27)
	_hp_fill.position = Vector2(2, 2)
	_hp_fill.size = Vector2(HP_BAR_WIDTH, 8)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.add_child(_hp_fill)
	_hp_label = _label(11)
	_hp_label.position = Vector2(HP_BAR_WIDTH + 10, -3)
	bar_bg.add_child(_hp_label)

	var combat_row := HBoxContainer.new()
	combat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_row.add_theme_constant_override("separation", 3)
	stats.add_child(combat_row)
	for i in MAX_PIPS:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(10, 6)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		combat_row.add_child(pip)
		_pips.append(pip)
	var dodge_bg := ColorRect.new()
	dodge_bg.color = Color(0, 0, 0, 0.6)
	dodge_bg.custom_minimum_size = Vector2(28, 6)
	dodge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_row.add_child(dodge_bg)
	_dodge_fill = ColorRect.new()
	_dodge_fill.size = Vector2(28, 6)
	_dodge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dodge_bg.add_child(_dodge_fill)
	_weapon_label = _label(10)
	combat_row.add_child(_weapon_label)

	_depth_label = _label(13)
	stats.add_child(_depth_label)
	_gold_label = _label(11)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	stats.add_child(_gold_label)
	# Devoured powers: 4 active slots (with key + cooldown) and 4 passive slots.
	_ability_bar = AbilityBar.new()
	_ability_bar.custom_minimum_size = Vector2(190, 44)
	_ability_bar.hud = self
	stats.add_child(_ability_bar)

	_fps_label = _label(10)
	_fps_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_fps_label.offset_top = -16
	_fps_label.offset_left = 4
	root.add_child(_fps_label)

	# Tutorial hint box (top centre, below the banner area).
	_hint_box = make_panel_box(VBoxContainer.new())
	_hint_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_box.offset_top = -92
	_hint_box.offset_bottom = -60
	_hint_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label = _label(12)
	_hint_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
	_hint_box.get_child(0).add_child(_hint_label)
	_hint_box.visible = false
	root.add_child(_hint_box)

	# --- Pause button + minimap (top-right) ---
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.focus_mode = Control.FOCUS_NONE
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -44
	pause_btn.offset_top = 8
	pause_btn.offset_right = -8
	pause_btn.offset_bottom = 40
	pause_btn.pressed.connect(func() -> void: pause_pressed.emit())
	root.add_child(pause_btn)

	minimap = Minimap.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -170
	minimap.offset_top = 8
	minimap.offset_right = -52
	minimap.offset_bottom = 84
	root.add_child(minimap)

	# --- Boss bar (bottom centre) ---
	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_boss_box.offset_left = -130
	_boss_box.offset_right = 130
	_boss_box.offset_top = -42
	_boss_box.offset_bottom = -10
	_boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_boss_box)
	_boss_label = _label(12)
	_boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_label)
	var boss_bg := ColorRect.new()
	boss_bg.color = Color(0, 0, 0, 0.7)
	boss_bg.custom_minimum_size = Vector2(260, 9)
	boss_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_box.add_child(boss_bg)
	_boss_fill = ColorRect.new()
	_boss_fill.color = Color(0.85, 0.2, 0.3)
	_boss_fill.position = Vector2(2, 2)
	_boss_fill.size = Vector2(256, 5)
	_boss_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bg.add_child(_boss_fill)

	# --- Banner ---
	_banner = _label(18)
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 92
	_banner.offset_bottom = 124
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner.modulate.a = 0.0
	root.add_child(_banner)

	# --- Modal panels ---
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0.55)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_overlay)

	# Upgrades
	var up_box := VBoxContainer.new()
	up_box.add_theme_constant_override("separation", 10)
	_upgrade_title = _label(18)
	_upgrade_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_box.add_child(_upgrade_title)
	_upgrade_row = HBoxContainer.new()
	_upgrade_row.add_theme_constant_override("separation", 8)
	up_box.add_child(_upgrade_row)
	_upgrade_panel = _make_panel(up_box)

	# Generic dialog (trader, shrine...)
	var dlg := VBoxContainer.new()
	dlg.add_theme_constant_override("separation", 6)
	_dialog_title = _label(18)
	_dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dialog_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	dlg.add_child(_dialog_title)
	reels = SlotReels.new()
	reels.visible = false
	reels.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dlg.add_child(reels)
	_dialog_text = _label(12)
	_dialog_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg.add_child(_dialog_text)
	_dialog_buttons = VBoxContainer.new()
	_dialog_buttons.add_theme_constant_override("separation", 4)
	dlg.add_child(_dialog_buttons)
	_dialog_panel = _make_panel(dlg)

	# Game over
	var go_box := VBoxContainer.new()
	go_box.add_theme_constant_override("separation", 8)
	_gameover_title = _label(26)
	_gameover_title.text = "YOU DIED"
	_gameover_title.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
	_gameover_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_box.add_child(_gameover_title)
	_gameover_label = _label(13)
	_gameover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_box.add_child(_gameover_label)
	_retry_button = _button("Try again", func() -> void: retry_requested.emit())
	go_box.add_child(_retry_button)
	go_box.add_child(_button("Main menu", func() -> void: menu_requested.emit()))
	_gameover_panel = _make_panel(go_box)

	# Pause
	var pause_box := VBoxContainer.new()
	pause_box.add_theme_constant_override("separation", 8)
	var p_title := _label(22)
	p_title.text = "Paused"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_box.add_child(p_title)
	pause_box.add_child(_button("Resume", func() -> void: pause_pressed.emit()))
	pause_box.add_child(_button("Settings", func() -> void: settings_requested.emit()))
	pause_box.add_child(_button("Save & quit", func() -> void: save_quit_requested.emit()))
	pause_box.add_child(_button("Abandon run", func() -> void: abandon_requested.emit()))
	_pause_panel = _make_panel(pause_box)

	hide_all()


func _process(delta: float) -> void:
	if is_instance_valid(player):
		for i in MAX_PIPS:
			var pip := _pips[i]
			pip.visible = i < player.max_charges
			if i < player.charges:
				pip.color = Color(0.75, 0.85, 1.0)
			elif i == player.charges:
				pip.color = Color(0.3, 0.35, 0.5).lerp(Color(0.6, 0.7, 0.9), player.reload_t)
			else:
				pip.color = Color(0.15, 0.15, 0.2)
			if player.no_ammo_flash > 0.0:
				pip.color = pip.color.lerp(Color(1, 0.25, 0.25), 0.7)
		var ready := player.dodge_ready()
		_dodge_fill.size.x = 28.0 * ready
		_dodge_fill.color = Color(0.65, 0.5, 1.0) if ready >= 1.0 else Color(0.35, 0.28, 0.55)
		_weapon_label.text = " " + String(player.weapon_def()["name"])
	_fps_label.visible = GameSettings.values["show_fps"]
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	_ability_bar.queue_redraw()
	_boss_box.visible = is_instance_valid(boss) and not boss.dying and boss.aggro
	if _boss_box.visible:
		_boss_label.text = boss.title
		_boss_fill.size.x = 256.0 * clampf(boss.hp / boss.max_hp, 0.0, 1.0)
	if _banner_time > 0.0:
		_banner_time -= delta
		_banner.modulate.a = clampf(_banner_time / 0.6, 0.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Number keys pick an upgrade / dialog option on PC.
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var idx: int = event.physical_keycode - KEY_1
	var row: Node = null
	if _upgrade_panel.visible:
		row = _upgrade_row
	elif _dialog_panel.visible:
		row = _dialog_buttons
	if row and idx >= 0 and idx < row.get_child_count():
		var b := row.get_child(idx) as Button
		if b and not b.disabled:
			b.pressed.emit()
			get_viewport().set_input_as_handled()


func show_hint(text: String) -> void:
	_hint_box.visible = text != ""
	_hint_label.text = text


func refresh(hp: int, max_hp: int, depth: int, biome_name: String, gold: int, kills: int, modifier := "", parts := 0) -> void:
	_hp_fill.size.x = HP_BAR_WIDTH * clampf(float(hp) / max_hp, 0.0, 1.0)
	_hp_label.text = "%d / %d" % [hp, max_hp]
	_depth_label.text = "Depth %d  |  %s" % [depth, biome_name] + ("  |  " + modifier if modifier != "" else "")
	_gold_label.text = "Gold %d    Kills %d" % [gold, kills] + ("    Parts %d" % parts if parts > 0 else "")


func show_banner(text: String, duration := 2.8) -> void:
	_banner.text = text
	_banner_time = duration
	_banner.modulate.a = 1.0


func hide_all() -> void:
	_overlay.visible = false
	_upgrade_panel.visible = false
	_dialog_panel.visible = false
	_gameover_panel.visible = false
	_pause_panel.visible = false


func show_upgrades(options: Array, title := "The stairs grant you a blessing") -> void:
	hide_all()
	_upgrade_title.text = title
	for c in _upgrade_row.get_children():
		c.queue_free()
	var buttons: Array[Button] = []
	for i in options.size():
		var opt: Dictionary = options[i]
		var id: String = opt["id"]
		var b := _button("%d. %s\n%s" % [i + 1, opt["name"], opt["desc"]], func() -> void: upgrade_chosen.emit(id))
		b.custom_minimum_size = Vector2(160 if options.size() <= 3 else 136, 64)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = true # brief delay so a held attack button can't pick by accident
		_upgrade_row.add_child(b)
		buttons.append(b)
	_overlay.visible = true
	_upgrade_panel.visible = true
	await _enable_after(buttons)


## options: [{"id", "label", "disabled" (optional)}]
func show_dialog(title: String, text: String, options: Array, with_reels := false) -> void:
	hide_all()
	_dialog_title.text = title
	reels.visible = with_reels
	_dialog_text.text = text
	for c in _dialog_buttons.get_children():
		_dialog_buttons.remove_child(c)
		c.queue_free()
	var buttons: Array[Button] = []
	for i in options.size():
		var opt: Dictionary = options[i]
		var id: String = opt["id"]
		var b := _button("%d. %s" % [i + 1, opt["label"]], func() -> void: dialog_chosen.emit(id))
		b.custom_minimum_size = Vector2(300, 30)
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = true
		b.set_meta("locked", opt.get("disabled", false))
		_dialog_buttons.add_child(b)
		buttons.append(b)
	_overlay.visible = true
	_dialog_panel.visible = true
	await _enable_after(buttons)


func _enable_after(buttons: Array[Button]) -> void:
	await get_tree().create_timer(0.35).timeout
	for b in buttons:
		if is_instance_valid(b):
			b.disabled = b.get_meta("locked", false)
	# Keyboard focus only for gamepads; otherwise Space (attack) would press the focused button.
	if Input.get_connected_joypads().size() > 0:
		for b in buttons:
			if is_instance_valid(b) and not b.disabled and b.is_visible_in_tree():
				b.grab_focus()
				break


func show_game_over(depth: int, gold: int, kills: int, best: int, shards := 0, extracted := false, parts_line := "") -> void:
	hide_all()
	_gameover_title.text = "EXTRACTED!" if extracted else "YOU DIED"
	_gameover_title.add_theme_color_override("font_color", Color(0.45, 0.95, 0.55) if extracted else Color(0.95, 0.3, 0.3))
	_retry_button.text = "New run" if extracted else "Try again"
	var text := "Reached depth %d   (best %d)\nGold %d   Kills %d\n+%d Soul Shards" % [depth, best, gold, kills, shards]
	if parts_line != "":
		text += "\n" + parts_line
	_gameover_label.text = text
	_overlay.visible = true
	_gameover_panel.visible = true


func set_paused(paused: bool) -> void:
	hide_all()
	_overlay.visible = paused
	_pause_panel.visible = paused


func _make_panel(content: Control) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(make_panel_box(content))
	_overlay.get_parent().add_child(center)
	return center


static func make_panel_box(content: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.07, 0.11, 0.95)
	sb.border_color = Color(0.65, 0.52, 0.3)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(content)
	return panel


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 32)
	b.pressed.connect(on_press)
	return b


static func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
