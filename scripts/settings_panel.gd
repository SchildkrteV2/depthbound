class_name SettingsPanel
extends CenterContainer
## Settings screen, used from the home screen and the pause menu.

signal closed

var _fps_toggle: CheckButton


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var title := HUD._label(20)
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	_slider(v, "Master volume", "master", 0.0, 1.0, 0.05)
	_slider(v, "Effects volume", "sfx", 0.0, 1.0, 0.05)
	_slider(v, "Music volume", "music", 0.0, 1.0, 0.05)
	_slider(v, "Touch button size", "button_scale", 0.7, 1.5, 0.1)
	_toggle(v, "Swap touch sides (move right, attack left)", "swap_sides")
	_toggle(v, "Screen shake", "screen_shake")
	_toggle(v, "Show FPS", "show_fps")
	_toggle(v, "Tutorial hints", "tutorial")
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size = Vector2(120, 30)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back)
	v.add_child(back)
	add_child(HUD.make_panel_box(v))


func _on_back() -> void:
	GameSettings.save()
	closed.emit()


func _on_slider(val: float, key: String) -> void:
	GameSettings.values[key] = val
	GameSettings.apply()


func _slider(parent: Control, text: String, key: String, lo: float, hi: float, step: float) -> void:
	var h := HBoxContainer.new()
	var l := HUD._label(11)
	l.text = text
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = GameSettings.values[key]
	s.custom_minimum_size = Vector2(160, 22)
	s.value_changed.connect(_on_slider.bind(key))
	h.add_child(s)
	parent.add_child(h)


func _toggle(parent: Control, text: String, key: String) -> void:
	var c := CheckButton.new()
	c.text = text
	c.add_theme_font_size_override("font_size", 11)
	c.button_pressed = GameSettings.values[key]
	c.toggled.connect(func(on: bool) -> void: GameSettings.values[key] = on)
	parent.add_child(c)
