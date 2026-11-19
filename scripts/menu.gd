class_name Menu
extends CanvasLayer
## Home screen: 3 save slots (continue / new / delete), Daily Run, Soul Altar
## (spend Soul Shards on unlocks), Settings, and the class picker.

signal continue_requested(slot: int)
signal new_run_requested(slot: int, class_id: String, start_depth: int, daily: bool, look: Dictionary)
signal settings_requested

var main: Node
var _root: Control
var _slots_page: Control
var _class_page: Control
var _altar_page: Control
var _workshop_page: Control
var _creator_page: Control
var _creator_title: Label
var _creator_preview: HeroPreview
var _creator_class := "fighter"
var _creator_look := {}
var _name_edit: LineEdit
var _opt_widgets := {}
const CREATOR_OPTS := [["hat", "Hat"], ["ghost", "Ghost colour"], ["eyes", "Eye glow"]]
var _workshop_rows: VBoxContainer
var _stock_row: HFlowContainer
var _slot_rows: VBoxContainer
var _altar_rows: VBoxContainer
var _altar_shards: Label
var _class_title: Label
var _depth_btn: Button
var _daily_btn: Button
var _weekly_btn: Button
var _heat_btn: Button
var _heat_label: Label
var _bounty_page: Control
var _bounty_rows: VBoxContainer
var _codex_page: Control
var _codex_rows: VBoxContainer
var _class_weekly := false
var _shards_label: Label
var _class_slot := 0
var _class_daily := false
var _start_depth := 1
var _confirm := {} # button -> true while waiting for a second press


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var bg := Backdrop.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bg)

	# --- Slots page ---
	_slots_page = _page()
	var v := _slots_page.get_child(0) as VBoxContainer
	var title := HUD._label(32)
	title.text = "DEPTHBOUND"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 1.0))
	v.add_child(title)
	_shards_label = HUD._label(11)
	_shards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shards_label.add_theme_color_override("font_color", Color(0.75, 0.6, 1.0))
	v.add_child(_shards_label)
	_slot_rows = VBoxContainer.new()
	_slot_rows.add_theme_constant_override("separation", 4)
	v.add_child(_slot_rows)
	var modes := HBoxContainer.new()
	modes.alignment = BoxContainer.ALIGNMENT_CENTER
	modes.add_theme_constant_override("separation", 6)
	v.add_child(modes)
	_daily_btn = _btn("Daily Run", _on_daily)
	_daily_btn.custom_minimum_size = Vector2(200, 28)
	modes.add_child(_daily_btn)
	_weekly_btn = _btn("Weekly Run", _on_weekly)
	_weekly_btn.custom_minimum_size = Vector2(200, 28)
	modes.add_child(_weekly_btn)
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 5)
	v.add_child(bottom)
	for b in [["Soul Altar", show_altar], ["Workshop", show_workshop], ["Bounties", show_bounties],
			["Codex", show_codex], ["Settings", func() -> void: settings_requested.emit()]]:
		var bb := _btn(b[0], b[1])
		bb.custom_minimum_size = Vector2(98, 28)
		bottom.add_child(bb)

	# --- Class page ---
	_class_page = _page()
	var cv := _class_page.get_child(0) as VBoxContainer
	_class_title = HUD._label(18)
	cv.add_theme_constant_override("separation", 3)
	_class_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cv.add_child(_class_title)
	_heat_label = HUD._label(10)
	_heat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heat_label.custom_minimum_size = Vector2(560, 0)
	_heat_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.35))
	cv.add_child(_heat_label)
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 6)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(cards)
	for id in Classes.ORDER:
		cards.add_child(_class_card(id))
	var crow := HBoxContainer.new()
	crow.alignment = BoxContainer.ALIGNMENT_CENTER
	crow.add_theme_constant_override("separation", 8)
	cv.add_child(crow)
	_depth_btn = _btn("Start at depth 1", _cycle_depth)
	_depth_btn.custom_minimum_size = Vector2(160, 30)
	crow.add_child(_depth_btn)
	_heat_btn = _btn("Heat 0", _cycle_heat)
	_heat_btn.custom_minimum_size = Vector2(110, 30)
	crow.add_child(_heat_btn)
	crow.add_child(_btn("Back", show_slots))

	# --- Soul Altar page ---
	_altar_page = _page()
	var av := _altar_page.get_child(0) as VBoxContainer
	var at := HUD._label(22)
	at.text = "Soul Altar"
	at.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	av.add_child(at)
	_altar_shards = HUD._label(12)
	_altar_shards.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_altar_shards.add_theme_color_override("font_color", Color(0.75, 0.6, 1.0))
	av.add_child(_altar_shards)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	av.add_child(scroll)
	_altar_rows = VBoxContainer.new()
	_altar_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_altar_rows.add_theme_constant_override("separation", 3)
	scroll.add_child(_altar_rows)
	add_child(DragScroll.new(scroll))
	var ab := _btn("Back", show_slots)
	ab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	av.add_child(ab)

	# --- Workshop page: craft permanent upgrades from extracted monster parts ---
	_workshop_page = _page()
	var wv := _workshop_page.get_child(0) as VBoxContainer
	var wt := HUD._label(22)
	wt.text = "Workshop"
	wt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wv.add_child(wt)
	var wh := HUD._label(10)
	wh.text = "Monsters drop parts. Send them up on a Loot Lift (every 5th floor) to keep them."
	wh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wh.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	wv.add_child(wh)
	_stock_row = HFlowContainer.new()
	_stock_row.alignment = FlowContainer.ALIGNMENT_CENTER
	_stock_row.add_theme_constant_override("h_separation", 8)
	wv.add_child(_stock_row)
	var wscroll := ScrollContainer.new()
	wscroll.custom_minimum_size = Vector2(540, 200)
	wscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	wv.add_child(wscroll)
	_workshop_rows = VBoxContainer.new()
	_workshop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_workshop_rows.add_theme_constant_override("separation", 3)
	wscroll.add_child(_workshop_rows)
	add_child(DragScroll.new(wscroll))
	var wb := _btn("Back", show_slots)
	wb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	wv.add_child(wb)

	# --- Bounty Board: three rotating goals that pay out parts and shards ---
	_bounty_page = _page()
	var bv := _bounty_page.get_child(0) as VBoxContainer
	var bt := HUD._label(22)
	bt.text = "Bounty Board"
	bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bv.add_child(bt)
	var bh := HUD._label(10)
	bh.text = "Goals count across all your runs. Claim finished ones for parts and Soul Shards."
	bh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bh.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	bv.add_child(bh)
	_bounty_rows = VBoxContainer.new()
	_bounty_rows.add_theme_constant_override("separation", 4)
	bv.add_child(_bounty_rows)
	var bb2 := _btn("Back", show_slots)
	bb2.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bv.add_child(bb2)

	# --- Monster Codex: kill counts, mastery tiers and their rewards ---
	_codex_page = _page()
	var xv := _codex_page.get_child(0) as VBoxContainer
	var xt := HUD._label(22)
	xt.text = "Monster Codex"
	xt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xv.add_child(xt)
	var xh := HUD._label(10)
	xh.text = "Each mastery: +6% damage against that monster. II unlocks an eye glow, III a ghost colour."
	xh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xh.add_theme_color_override("font_color", Color(0.7, 0.7, 0.78))
	xv.add_child(xh)
	var xscroll := ScrollContainer.new()
	xscroll.custom_minimum_size = Vector2(540, 230)
	xscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	xv.add_child(xscroll)
	_codex_rows = VBoxContainer.new()
	_codex_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_codex_rows.add_theme_constant_override("separation", 2)
	xscroll.add_child(_codex_rows)
	add_child(DragScroll.new(xscroll))
	var xb := _btn("Back", show_slots)
	xb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	xv.add_child(xb)

	# --- Character creator page (after picking a class) ---
	_creator_page = _page()
	var crv := _creator_page.get_child(0) as VBoxContainer
	_creator_title = HUD._label(20)
	_creator_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crv.add_child(_creator_title)
	var crh := HBoxContainer.new()
	crh.add_theme_constant_override("separation", 14)
	crh.alignment = BoxContainer.ALIGNMENT_CENTER
	crv.add_child(crh)
	_creator_preview = HeroPreview.new()
	_creator_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_creator_preview.custom_minimum_size = Vector2(150, 190)
	crh.add_child(HUD.make_panel_box(_creator_preview))
	var opts := VBoxContainer.new()
	opts.add_theme_constant_override("separation", 2)
	crh.add_child(opts)
	var name_row := HBoxContainer.new()
	var nl := HUD._label(11)
	nl.text = "Name"
	nl.custom_minimum_size = Vector2(80, 0)
	name_row.add_child(nl)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 14
	_name_edit.custom_minimum_size = Vector2(170, 24)
	_name_edit.text_changed.connect(_on_name_changed)
	name_row.add_child(_name_edit)
	opts.add_child(name_row)
	for o in CREATOR_OPTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var l := HUD._label(11)
		l.text = o[1]
		l.custom_minimum_size = Vector2(80, 0)
		row.add_child(l)
		var prev := _btn("<", _cycle_opt.bind(o[0], -1))
		prev.custom_minimum_size = Vector2(26, 22)
		row.add_child(prev)
		var val := HBoxContainer.new()
		val.custom_minimum_size = Vector2(110, 22)
		val.alignment = BoxContainer.ALIGNMENT_CENTER
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(14, 14)
		sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		val.add_child(sw)
		var vl := HUD._label(11)
		val.add_child(vl)
		row.add_child(val)
		_opt_widgets[o[0]] = [sw, vl]
		var nxt := _btn(">", _cycle_opt.bind(o[0], 1))
		nxt.custom_minimum_size = Vector2(26, 22)
		row.add_child(nxt)
		opts.add_child(row)
	var crb := HBoxContainer.new()
	crb.alignment = BoxContainer.ALIGNMENT_CENTER
	crb.add_theme_constant_override("separation", 8)
	crv.add_child(crb)
	crb.add_child(_btn("Randomize", _randomize_look))
	crb.add_child(_btn("Back", _back_to_classes))
	var go := _btn("Start run", _start_with_look)
	go.custom_minimum_size = Vector2(120, 30)
	crb.add_child(go)

	show_slots()


func open() -> void:
	visible = true
	show_slots()


func close() -> void:
	visible = false


func _show_page(p: Control) -> void:
	for page in [_slots_page, _class_page, _altar_page, _workshop_page, _creator_page, _bounty_page, _codex_page]:
		page.visible = page == p
	_confirm.clear()


func show_slots() -> void:
	_show_page(_slots_page)
	_shards_label.text = "Soul Shards: %d     Deepest: %d" % [int(Profile.data.get("shards", 0)), int(Profile.data.get("best_depth", 0))]
	for c in _slot_rows.get_children():
		_slot_rows.remove_child(c)
		c.queue_free()
	for i in SaveManager.SLOT_COUNT:
		_slot_rows.add_child(_slot_row(i))
	var daily := SaveManager.load_slot(3)
	var resumable: bool = daily.get("alive", false) and daily.get("daily", "") == Profile.today()
	_daily_btn.text = ("Continue Daily (depth %d)" % int(daily.get("depth", 1))) if resumable else ("Daily Run  (best today: %d)" % Profile.daily_best())
	var weekly := SaveManager.load_slot(Grind.WEEKLY_SLOT)
	var w_resume: bool = weekly.get("alive", false) and int(weekly.get("weekly", -1)) == Grind.week_id()
	_weekly_btn.text = ("Continue Weekly (depth %d)" % int(weekly.get("depth", 1))) if w_resume else ("Weekly Run  (best: %d)" % Grind.weekly_best())
	_weekly_btn.tooltip_text = "This week: " + Grind.mutator_text(Grind.weekly_mutators())


func _slot_row(i: int) -> Control:
	var data := SaveManager.load_slot(i)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.custom_minimum_size = Vector2(520, 38)
	var info := HUD._label(12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(info)
	if data.is_empty():
		info.text = "Slot %d  -  empty" % (i + 1)
		info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		h.add_child(_btn("New game", _pick_class.bind(i, false)))
	else:
		var cls := Classes.get_def(String(data.get("class", "fighter")))
		var hero_name := String(data.get("player", {}).get("look", {}).get("name", ""))
		var who: String = ("%s the %s" % [hero_name, cls["name"]]) if hero_name != "" else String(cls["name"])
		var alive: bool = data.get("alive", false)
		var best := int(data.get("best_depth", 0))
		if alive:
			info.text = "Slot %d  -  %s, depth %d\nGold %d  Kills %d   (best %d)" % [i + 1, who, int(data.get("depth", 1)), int(data.get("gold", 0)), int(data.get("kills", 0)), best]
			h.add_child(_btn("Continue", func() -> void: continue_requested.emit(i)))
			h.add_child(_confirm_btn("New", _pick_class.bind(i, false)))
		else:
			var got_out: bool = data.get("extracted", false)
			info.text = "Slot %d  -  %s %s depth %d\n(best %d)" % [i + 1, who, "extracted at" if got_out else "fell on", int(data.get("depth", 1)), best]
			info.add_theme_color_override("font_color", Color(0.6, 0.9, 0.65) if got_out else Color(0.85, 0.6, 0.6))
			h.add_child(_btn("New game", _pick_class.bind(i, false)))
		h.add_child(_confirm_btn("Delete", _delete_slot.bind(i)))
	return HUD.make_panel_box(h)


func _delete_slot(slot: int) -> void:
	SaveManager.delete_slot(slot)
	show_slots()


func _on_daily() -> void:
	var daily := SaveManager.load_slot(3)
	if daily.get("alive", false) and daily.get("daily", "") == Profile.today():
		continue_requested.emit(3)
	else:
		_pick_class(3, true)


func _on_weekly() -> void:
	var weekly := SaveManager.load_slot(Grind.WEEKLY_SLOT)
	if weekly.get("alive", false) and int(weekly.get("weekly", -1)) == Grind.week_id():
		continue_requested.emit(Grind.WEEKLY_SLOT)
		return
	_pick_class(Grind.WEEKLY_SLOT, false)
	_class_weekly = true
	_depth_btn.visible = false
	_heat_btn.visible = false
	_class_title.text = "Weekly Run - " + " + ".join(Grind.weekly_mutators().map(func(m: String) -> String: return Grind.MUTATORS[m]["name"]))
	_heat_label.text = Grind.mutator_text(Grind.weekly_mutators())


func _cycle_heat() -> void:
	Grind.selected_heat = (Grind.selected_heat + 1) % (Grind.heat_max() + 1)
	_heat_btn.text = "Heat %d" % Grind.selected_heat
	_heat_btn.tooltip_text = Grind.heat_desc(Grind.selected_heat)
	_heat_label.text = "" if Grind.selected_heat == 0 else Grind.heat_desc(Grind.selected_heat)
	_click()


func show_bounties() -> void:
	_show_page(_bounty_page)
	for c in _bounty_rows.get_children():
		_bounty_rows.remove_child(c)
		c.queue_free()
	var list: Array = Grind.bounties()
	Profile.save()
	for i in list.size():
		var b: Dictionary = list[i]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.custom_minimum_size = Vector2(540, 0)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := HUD._label(12)
		l.text = "%s   (%d / %d)" % [b["desc"], int(b["progress"]), int(b["goal"])]
		if b.get("claimable", false):
			l.add_theme_color_override("font_color", Color(0.55, 1.0, 0.6))
		info.add_child(l)
		var bar_bg := ColorRect.new()
		bar_bg.color = Color(0, 0, 0, 0.5)
		bar_bg.custom_minimum_size = Vector2(300, 5)
		var fill := ColorRect.new()
		fill.color = Color(0.55, 1.0, 0.6) if b.get("claimable", false) else Color(0.95, 0.75, 0.3)
		fill.size = Vector2(300.0 * clampf(float(b["progress"]) / float(b["goal"]), 0.0, 1.0), 5)
		bar_bg.add_child(fill)
		info.add_child(bar_bg)
		var rl := HUD._label(10)
		rl.text = "Reward: " + Grind.reward_text(b["reward"])
		rl.add_theme_color_override("font_color", Color(0.75, 0.7, 0.9))
		info.add_child(rl)
		h.add_child(info)
		if b.get("claimable", false):
			h.add_child(_btn("Claim", _claim_bounty.bind(i)))
		else:
			var rb := _btn("Reroll (%d)" % Grind.REROLL_COST, _reroll_bounty.bind(i))
			rb.disabled = int(Profile.data.get("shards", 0)) < Grind.REROLL_COST
			rb.tooltip_text = "Swap this bounty for a new one (costs Soul Shards)"
			h.add_child(rb)
		_bounty_rows.add_child(HUD.make_panel_box(h))
	var sl := HUD._label(11)
	sl.text = "Soul Shards: %d" % int(Profile.data.get("shards", 0))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sl.add_theme_color_override("font_color", Color(0.75, 0.6, 1.0))
	_bounty_rows.add_child(sl)


func _claim_bounty(i: int) -> void:
	if Grind.claim(i) and main:
		main.sfx("power")
	show_bounties()


func _reroll_bounty(i: int) -> void:
	Grind.reroll(i)
	show_bounties()


func show_codex() -> void:
	_show_page(_codex_page)
	for c in _codex_rows.get_children():
		_codex_rows.remove_child(c)
		c.queue_free()
	for k in Grind.CODEX_KINDS:
		var kills := Grind.codex_kills(k)
		var tier := Grind.codex_tier(k)
		var tiers: Array = Grind.tiers_for(k)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var sw1 := ColorRect.new()
		sw1.custom_minimum_size = Vector2(12, 12)
		sw1.color = HeroArt.CODEX_EYES[k] if tier >= 2 else Color(0.2, 0.2, 0.25)
		sw1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw1.tooltip_text = "Eye glow (mastery II)"
		var sw2 := ColorRect.new()
		sw2.custom_minimum_size = Vector2(12, 12)
		sw2.color = HeroArt.CODEX_GHOST[k] if tier >= 3 else Color(0.2, 0.2, 0.25)
		sw2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		sw2.tooltip_text = "Ghost colour (mastery III)"
		var l := HUD._label(11)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var stars := "*".repeat(tier) + "-".repeat(3 - tier)
		var next := ("next at %d" % int(tiers[tier])) if tier < 3 else "mastered"
		l.text = "%-10s  [%s]   %d kills  (%s)   +%d%% damage" % [Grind.KIND_NAMES[k], stars, kills, next, int(Grind.CODEX_DAMAGE * 100 * tier)]
		if tier == 3:
			l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		elif kills == 0:
			l.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		h.add_child(l)
		h.add_child(sw1)
		h.add_child(sw2)
		_codex_rows.add_child(h)


func _pick_class(slot: int, daily: bool) -> void:
	_class_slot = slot
	_class_daily = daily
	_class_weekly = false
	_start_depth = 1
	_class_title.text = "Daily Run - choose your class" if daily else "Choose your class"
	# Shortcuts (Soul Altar) let you start deeper; not in the daily run.
	_depth_btn.visible = not daily and Profile.has("shortcut_11")
	_depth_btn.text = "Start at depth 1"
	Grind.selected_heat = mini(Grind.selected_heat, Grind.heat_max())
	_heat_btn.visible = not daily and Grind.heat_max() > 0
	_heat_btn.text = "Heat %d" % Grind.selected_heat
	_heat_btn.tooltip_text = Grind.heat_desc(Grind.selected_heat)
	_heat_label.text = "" if (daily or Grind.selected_heat == 0) else Grind.heat_desc(Grind.selected_heat)
	_show_page(_class_page)


func _cycle_depth() -> void:
	var options := [1, 11]
	if Profile.has("shortcut_21"):
		options.append(21)
	_start_depth = options[(options.find(_start_depth) + 1) % options.size()]
	_depth_btn.text = "Start at depth %d" % _start_depth


## Picking a class opens the character creator, pre-filled with your last look for it.
func _choose_class(id: String) -> void:
	_creator_class = id
	var saved: Dictionary = Profile.data.get("looks", {}).get(id, {})
	_creator_look = HeroArt.complete(id, saved) if not saved.is_empty() else HeroArt.default_look(id)
	_creator_title.text = "Create your %s" % Classes.get_def(id)["name"]
	_name_edit.text = String(_creator_look.get("name", ""))
	_creator_preview.class_id = id
	_refresh_creator()
	_show_page(_creator_page)


func _option_values(key: String) -> int:
	match key:
		"hat":
			return HeroArt.HATS.size()
		"ghost":
			return HeroArt.ghost_colors().size()
		"eyes":
			return HeroArt.eye_colors().size()
	return 1


func _cycle_opt(key: String, dir: int) -> void:
	if key == "hat":
		var i := HeroArt.HATS.find(String(_creator_look.get("hat", "class")))
		_creator_look["hat"] = HeroArt.HATS[posmod(i + dir, HeroArt.HATS.size())]
	else:
		# Skip colours not unlocked yet in the Monster Codex.
		var n := _option_values(key)
		var i := int(_creator_look.get(key, 0))
		for step in n:
			i = posmod(i + dir, n)
			if HeroArt.color_unlocked(key, i):
				break
		_creator_look[key] = i
	if main:
		main.sfx("click")
	_refresh_creator()


func _refresh_creator() -> void:
	var l := _creator_look
	for key in _opt_widgets:
		var sw: ColorRect = _opt_widgets[key][0]
		var vl: Label = _opt_widgets[key][1]
		sw.visible = true
		vl.text = ""
		match key:
			"hat":
				sw.visible = false
				var hat := String(l.get("hat", "class"))
				vl.text = HeroArt.HAT_NAMES.get(hat, hat)
				if hat == "class":
					vl.text = "Class (%s)" % HeroArt.HAT_NAMES[HeroArt.CLASS_HEAD[_creator_class]]
			"ghost":
				sw.color = HeroArt.ghost_colors()[int(l["ghost"])]
				var gk := HeroArt.codex_kind("ghost", int(l["ghost"]))
				vl.text = (" " + Grind.KIND_NAMES[gk]) if gk != "" else ""
			"eyes":
				sw.color = HeroArt.eye_colors()[int(l["eyes"])]
				var ek := HeroArt.codex_kind("eyes", int(l["eyes"]))
				vl.text = " Hollow" if int(l["eyes"]) == 0 else ((" " + Grind.KIND_NAMES[ek]) if ek != "" else "")
	_creator_preview.look = l.duplicate()


func _on_name_changed(text: String) -> void:
	_creator_look["name"] = text.strip_edges()


func _randomize_look() -> void:
	_creator_look = HeroArt.complete(_creator_class, HeroArt.random_look())
	_name_edit.text = _creator_look["name"]
	if main:
		main.sfx("click")
	_refresh_creator()


func _back_to_classes() -> void:
	_show_page(_class_page)


func _start_with_look() -> void:
	if String(_creator_look.get("name", "")) == "":
		_creator_look["name"] = HeroArt.NAMES[randi() % HeroArt.NAMES.size()]
	# Remember this look for next time.
	if not Profile.data.has("looks"):
		Profile.data["looks"] = {}
	Profile.data["looks"][_creator_class] = _creator_look.duplicate()
	Profile.save()
	Grind.pending_weekly = _class_weekly
	if _class_daily or _class_weekly:
		Grind.selected_heat = 0
	new_run_requested.emit(_class_slot, _creator_class, _start_depth, _class_daily, _creator_look.duplicate())


func show_altar() -> void:
	_show_page(_altar_page)
	_altar_shards.text = "Soul Shards: %d   (earned when a run ends: depth, bosses, kills)" % int(Profile.data.get("shards", 0))
	for c in _altar_rows.get_children():
		_altar_rows.remove_child(c)
		c.queue_free()
	for id in Profile.UNLOCKS:
		var u: Dictionary = Profile.UNLOCKS[id]
		var h := HBoxContainer.new()
		var l := HUD._label(11)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.text = "%s  -  %s" % [u["name"], u["desc"]]
		h.add_child(l)
		var b := _btn("", _buy.bind(id))
		b.custom_minimum_size = Vector2(110, 26)
		if Profile.has(id):
			b.text = "Owned"
			b.disabled = true
			l.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		elif u.has("requires") and not Profile.has(u["requires"]):
			b.text = "Locked"
			b.disabled = true
		else:
			b.text = "%d shards" % int(u["cost"])
			b.disabled = not Profile.can_buy(id)
		h.add_child(b)
		_altar_rows.add_child(h)


func show_workshop() -> void:
	_show_page(_workshop_page)
	# Stockpile: one icon + count per part type.
	for c in _stock_row.get_children():
		_stock_row.remove_child(c)
		c.queue_free()
	for id in Materials.ORDER:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.add_child(_part_icon(id))
		var n := HUD._label(11)
		n.text = str(Profile.mat_count(id))
		n.tooltip_text = Materials.part_name(id)
		if Profile.mat_count(id) == 0:
			n.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		box.add_child(n)
		_stock_row.add_child(box)
	# Recipes.
	for c in _workshop_rows.get_children():
		_workshop_rows.remove_child(c)
		c.queue_free()
	for id in Materials.RECIPE_ORDER:
		var r: Dictionary = Materials.RECIPES[id]
		var lv := Profile.crafted_level(id)
		var maxed := not Materials.endless(id) and lv >= int(r["max"])
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_constant_override("separation", 0)
		var l := HUD._label(11)
		l.text = ("%s  (Lv %d)  -  %s" % [r["name"], lv, r["desc"]]) if Materials.endless(id) else ("%s  (%d/%d)  -  %s" % [r["name"], lv, int(r["max"]), r["desc"]])
		if maxed:
			l.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
		info.add_child(l)
		if not maxed:
			# Cost, with a red number for anything you don't have enough of.
			var cost_row := HBoxContainer.new()
			cost_row.add_theme_constant_override("separation", 3)
			var cost := Materials.cost_for(id, lv)
			for k in cost:
				cost_row.add_child(_part_icon(k))
				var cl := HUD._label(10)
				cl.text = "%d/%d %s   " % [Profile.mat_count(k), int(cost[k]), Materials.part_name(k)]
				var enough := Profile.mat_count(k) >= int(cost[k])
				cl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85) if enough else Color(0.95, 0.45, 0.45))
				cost_row.add_child(cl)
			info.add_child(cost_row)
		h.add_child(info)
		var b := _btn("Maxed" if maxed else "Craft", _craft.bind(id))
		b.custom_minimum_size = Vector2(80, 26)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.disabled = maxed or not Profile.can_craft(id)
		h.add_child(b)
		_workshop_rows.add_child(h)


func _part_icon(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Sprites.item("part_" + id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(16, 16)
	t.tooltip_text = Materials.part_name(id)
	return t


func _craft(id: String) -> void:
	if Profile.craft(id) and main:
		main.sfx("power")
	show_workshop()


func _buy(id: String) -> void:
	if Profile.buy(id) and main:
		main.sfx("power")
	show_altar()


func _class_card(id: String) -> Control:
	var c := Classes.get_def(id)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.custom_minimum_size = Vector2(124, 0)
	var portrait := Portrait.new()
	portrait.class_id = id
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.custom_minimum_size = Vector2(124, 64)
	v.add_child(portrait)
	var name_l := HUD._label(16)
	name_l.text = c["name"]
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override("font_color", (c["cloak"] as Color).lightened(0.35))
	v.add_child(name_l)
	var role := HUD._label(10)
	role.text = c["role"]
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	v.add_child(role)
	var desc := HUD._label(9)
	desc.text = String(c["desc"]).replace("\n", " ")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(124, 0)
	v.add_child(desc)
	var stats := HUD._label(9)
	stats.text = "HP %d   Speed %d\nCharges %d   Crit %d%%\nDamage x%.2f\n%s" % [c["hp"], int(c["speed"]), c["charges"], int(c["crit"] * 100.0), c["damage"], Weapons.get_def(c["weapon"])["name"]]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_color_override("font_color", Color(0.75, 0.8, 0.9))
	v.add_child(stats)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var b := _btn("Choose", _choose_class.bind(id))
	b.custom_minimum_size = Vector2(110, 28)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return HUD.make_panel_box(v)


func _page() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	center.add_child(v) # child 0 = the page's VBox
	_root.add_child(center)
	return center


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(84, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(cb)
	b.pressed.connect(_click)
	return b


func _click() -> void:
	if main:
		main.sfx("click")


## A button that asks "Sure?" and needs a second press within 3 seconds.
func _confirm_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(84, 30)
	b.add_theme_font_size_override("font_size", 12)
	b.pressed.connect(_on_confirm_pressed.bind(b, text, cb))
	return b


func _on_confirm_pressed(b: Button, text: String, cb: Callable) -> void:
	if _confirm.has(b):
		_confirm.erase(b)
		cb.call()
		return
	_confirm[b] = true
	b.text = "Sure?"
	b.add_theme_color_override("font_color", Color(1, 0.5, 0.45))
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(b) and _confirm.has(b):
		_confirm.erase(b)
		b.text = text
		b.remove_theme_color_override("font_color")


## Animated background: drifting embers over a dark gradient, with descending stairs.
class Backdrop extends Control:
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := size
		for i in 12:
			var k := float(i) / 12.0
			draw_rect(Rect2(0, s.y * k, s.x, s.y / 12.0 + 1.0), Color(0.07, 0.05, 0.11).lerp(Color(0.02, 0.01, 0.03), k))
		for i in 6:
			var w := s.x * (0.5 - i * 0.07)
			draw_rect(Rect2(s.x * 0.5 - w * 0.5, s.y * 0.62 + i * 16.0, w, 10), Color(0.25, 0.22, 0.32).darkened(i * 0.15))
		for i in 40:
			var x := fmod(i * 97.3 + sin(_t * 0.3 + i) * 20.0, s.x)
			var y := s.y - fmod(_t * (8.0 + i % 5 * 3.0) + i * 53.0, s.y + 20.0)
			draw_circle(Vector2(x, y), 1.0 + (i % 3) * 0.5, Color(1.0, 0.6, 0.3, 0.25 + 0.2 * sin(_t * 2.0 + i)))


## Each class's hero, walking in place, with its starting weapon.
class Portrait extends Control:
	var class_id := "fighter"
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := 2.6 # screen pixels per world unit
		var tex := Sprites.hero(class_id, HeroArt.DEFAULT_LOOKS[class_id], "walk", int(_t * 6.0))
		var feet := Vector2(size.x * 0.5 - 6.0, size.y - 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2(feet.x, (feet.y - 1.0) / 0.35), 6.0 * s, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Sprites.draw_at(self, tex, feet, false, Color.WHITE, s * Sprites.PX)
		var w := String(Classes.get_def(class_id)["weapon"])
		Sprites.draw_rotated(self, Sprites.weapon(w), feet + HeroArt.HAND * s, Vector2.RIGHT.rotated(-1.0), Sprites.weapon_grip(w), Color.WHITE, false, s * Sprites.PX)


## Big animated preview in the character creator: walks, attacks, idles, dodges.
class HeroPreview extends Control:
	var class_id := "fighter"
	var look := {}
	var _t := 0.0
	const SEQ := [["walk", 3.2, 6.0], ["attack", 0.6, 7.0], ["idle", 2.4, 3.0], ["dodge", 0.5, 8.0]]

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if look.is_empty():
			return
		var total := 0.0
		for a in SEQ:
			total += float(a[1])
		var tt := fmod(_t, total)
		var anim := "idle"
		var frame := 0
		for a in SEQ:
			if tt < float(a[1]):
				anim = a[0]
				frame = int(tt * float(a[2]))
				if anim == "attack" or anim == "dodge":
					frame = mini(frame, HeroArt.frame_count(anim) - 1)
				break
			tt -= float(a[1])
		var s := 5.5 # screen pixels per world unit
		var feet := Vector2(size.x * 0.5, size.y - 12.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
		draw_circle(Vector2(feet.x, (feet.y - 1.0) / 0.35), 6.0 * s, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		Sprites.draw_at(self, Sprites.hero(class_id, look, anim, frame), feet, false, Color.WHITE, s * Sprites.PX)
		var nm := String(look.get("name", ""))
		draw_string(ThemeDB.fallback_font, Vector2(0, 14), nm, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(1, 0.9, 0.6))


func _process(_delta: float) -> void:
	# The heat / weekly line only takes space when it has something to say.
	if _heat_label:
		_heat_label.visible = _heat_label.text != ""
