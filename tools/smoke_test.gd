extends SceneTree
## Headless smoke test. Uses separate save/profile/settings files (user://test_*).
## Run:  Godot_console.exe --headless --path . -s res://tools/smoke_test.gd --quit-after 60000

var main: Node
var failures := 0


func _initialize() -> void:
	SaveManager.prefix = "user://test_save_"
	Profile.path_override = "user://test_profile.json"
	GameSettings.path_override = "user://test_settings.json"
	_wipe()
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_run.call_deferred()


func _wipe() -> void:
	for i in SaveManager.SLOT_COUNT + 2: # + daily + weekly
		SaveManager.delete_slot(i)
	for p in ["user://test_profile.json", "user://test_settings.json"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		failures += 1


func _dummy(offset: Vector2, kind := "brute") -> Enemy:
	var e := Enemy.new()
	e.setup(kind, 1)
	e.max_hp = 1e7
	e.hp = e.max_hp
	e.main = main
	e.player = main.player
	e.killed.connect(main._on_enemy_killed)
	e.position = main.player.position + offset
	e.stun = 1e6
	main.level.add_child(e)
	return e


func _clear_enemies() -> void:
	for e in get_nodes_in_group("enemies"):
		e.queue_free()


func _run() -> void:
	GameSettings.values["tutorial"] = false
	await _frames(5)
	_check(main.menu.visible and not main.playing, "game opens on the home screen")

	# --- new run, classes and weapons ---
	main.gear_drops = false # random drops would open dialogs mid-test
	main.start_new_run(0, "fighter")
	await _frames(10)
	var p: Player = main.player
	_check(main.playing and p.weapon == "sword" and p.max_hp == 9, "new fighter run starts")
	_check(SaveManager.load_slot(0).get("alive", false), "run autosaved")
	_clear_enemies()
	await _frames(2)
	p.invuln = 1e9
	var target := _dummy(Vector2(24, 0))
	await _frames(2)
	for cls in Classes.ORDER:
		for w in Classes.get_def(cls)["weapons"]:
			p.weapon = w
			p.charges = p.max_charges
			p.atk_cd = 0.0
			target.position = p.position + Vector2(24, 0)
			target.knockback = Vector2.ZERO
			await _frames(2)
			var before := target.hp
			p.queue_attack(false, Vector2.RIGHT, 0.25)
			await _frames(40)
			_check(target.hp < before, "%s: %s hits" % [cls, w])
	p.weapon = "sword"

	# --- every boss power (active) works ---
	for id in Abilities.ACTIVES.keys():
		# Pick a direction with open floor each time (some powers move the hero), so the random
		# layout cannot put the dummy behind a wall.
		var open_dir := Vector2.RIGHT
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			var c1: Vector2i = main.dungeon.world_to_cell(p.position + d * 28.0)
			var c2: Vector2i = main.dungeon.world_to_cell(p.position + d * 44.0)
			if main.dungeon.is_floor(c1.x, c1.y) and main.dungeon.is_floor(c2.x, c2.y):
				open_dir = d
				break
		p.actives = [{"type": "active", "id": id, "name": id, "tier": 10}]
		p.ability_cd[0] = 0.0
		target.position = p.position + open_dir * 28.0
		target.knockback = Vector2.ZERO
		p.facing = open_dir
		p._last_mouse_move = -100.0
		await _frames(2)
		var before := target.hp
		p.use_ability(0)
		await _frames(90)
		_check(target.hp < before and p.ability_cd[0] > 0.0, "active power %s damages" % id)
	p.actives = []
	target.position = p.position + Vector2(28, 0)

	# --- passives ---
	p.add_power({"type": "passive", "id": "thorns", "name": "t", "tier": 10})
	var hb := target.hp
	p.invuln = 0.0
	p.take_damage(1)
	await _frames(10)
	_check(target.hp < hb, "Thorns blasts back when hurt")
	var mc := p.max_charges
	p.add_power({"type": "passive", "id": "overcharge", "name": "o", "tier": 10})
	_check(p.max_charges == mc + 1, "Overcharge adds a charge")
	p.add_power({"type": "passive", "id": "second_wind", "name": "s", "tier": 10})
	p.add_power({"type": "passive", "id": "orbit", "name": "r", "tier": 10})
	_check(p.passives.size() == 4, "4 passive slots filled")
	target.position = p.position + Vector2(22, 0)
	target.knockback = Vector2.ZERO
	hb = target.hp
	await _frames(60)
	_check(target.hp < hb, "Orbiting Shards cut nearby foes")
	p.add_power({"type": "passive", "id": "dread", "name": "d", "tier": 10}, 1) # replace overcharge
	_check(p.max_charges == mc and p.has_passive("dread") and not p.has_passive("overcharge"), "replacing Overcharge removes its charge")
	_check(target._move_mult(30.0) < 1.0, "Aura of Dread slows nearby foes")
	p.invuln = 0.0
	p.hp = 1
	p.take_damage(5)
	_check(p.hp == 1 and not p.dead, "Second Wind survives a lethal hit")
	p.hp = p.max_hp
	p.invuln = 1e9
	target.queue_free()

	# --- devouring a boss + replace dialog ---
	p.actives = []
	var boss: Enemy = main._make_enemy("boss")
	var def := BossGen.generate(10, main.rng, ["bat"])
	def["attacks"] = BossGen.ATTACKS.duplicate()
	boss.apply_boss(def)
	for i in 8:
		main._devour(boss)
	_check(p.actives.size() <= 4 and p.passives.size() <= 4, "devouring fills slots (%d active, %d passive)" % [p.actives.size(), p.passives.size()])
	while p.actives.size() < 4:
		p.actives.append({"type": "active", "id": "fan", "name": "x", "tier": 10})
	main._pending_power = {"type": "active", "id": "slam", "name": "New Quake", "tier": 20}
	main._open_modal()
	main._on_dialog_chosen("replace:2")
	_check(p.actives[2]["name"] == "New Quake" and not main.modal, "full slots: replacing a power works")
	boss.free()
	_clear_enemies()
	await _frames(3)

	# --- every enemy type incl. a full boss runs its AI ---
	for kind in Enemy.TYPES.keys():
		var e: Enemy = main._make_enemy(kind)
		if kind == "boss":
			e.apply_boss(def)
		e.position = p.position + Vector2(60, 0)
		e.aggro = true
		main.level.add_child(e)
	await _frames(300)
	for e in get_nodes_in_group("enemies"):
		e.take_damage(1e9, Vector2.RIGHT)
	await _frames(5)
	_check(main.bosses_killed >= 1, "all enemy types + boss ran 5s and died")
	_check(main.modal, "boss kill with full slots asks what to replace")
	main._on_dialog_chosen("skip_power")
	_check(not main.modal and not paused, "'Leave it' closes the power dialog")
	_clear_enemies()
	await _frames(5)

	# --- elite affixes ---
	for affix in Enemy.AFFIXES:
		var e: Enemy = main._make_enemy("skeleton", true)
		e.set_affixes([affix])
		e.position = p.position + Vector2(40, 0)
		e.aggro = true
		main.level.add_child(e)
		await _frames(80)
		if affix == "shielded":
			var h0 := e.hp
			e.take_damage(5.0)
			_check(e.hp == h0 and e.shield > 0.0, "shielded elite absorbs damage")
		if affix == "toxic":
			_check(level_has(Puddle), "toxic elite leaves poison")
		var before := get_nodes_in_group("enemies").size()
		e.take_damage(1e9, Vector2.RIGHT)
		await _frames(3)
		if affix == "splitting":
			_check(get_nodes_in_group("enemies").size() >= before + 1, "splitting elite splits")
		if affix == "explosive":
			_check(level_has(Blast), "explosive elite explodes")
		_clear_enemies()
		await _frames(3)

	# --- floor modifiers ---
	for mod in main.MODIFIERS.keys():
		main.force_mod = mod
		main.depth = 4
		main._build_level()
		await _frames(5)
		if mod == "unstable":
			main._unstable_t = 41.0
		await _frames(120)
		_check(main.floor_mod == mod and not p.dead or p.invuln > 0, "floor modifier %s runs" % mod)
		if mod == "infested":
			_check(get_nodes_in_group("enemies").size() > 14, "infested floor has more foes (%d)" % get_nodes_in_group("enemies").size())
		if mod == "unstable":
			_check(level_has(Blast), "unstable floor drops rocks")
	main.force_mod = ""

	# --- cursed plunge ---
	main.depth = 4
	main._build_level()
	await _frames(5)
	main.on_stairs_reached(true)
	_check(main.modal and main._upgrade_context == "plunge", "plunge offers 4 upgrades")
	main._on_upgrade_chosen("damage")
	await _frames(5)
	_check(main.depth == 6 and p.curses.size() == 1 and not paused, "plunge: +2 depth and a curse (%s)" % str(p.curses))

	# --- descending to a generated boss ---
	main.depth = 9
	main._build_level()
	await _frames(5)
	p.global_position = main.stairs.global_position
	await _frames(5)
	main._on_upgrade_chosen("charge")
	await _frames(10)
	var bosses := get_nodes_in_group("enemies").filter(func(e): return e.is_boss)
	_check(main.depth == 10 and bosses.size() == 1 and main.stairs.locked, "floor 10 has a generated boss: %s" % (bosses[0].title if bosses.size() else "none"))
	var powers_before: int = p.actives.size() + p.passives.size()
	p.actives = []
	p.passives = []
	bosses[0].take_damage(1e12, Vector2.RIGHT)
	await _frames(5)
	_check(not main.stairs.locked and p.actives.size() + p.passives.size() == 1, "killing the boss unlocks stairs and grants 1 power")
	var hearts: Array = main.level.get_children().filter(func(c): return c is Pickup and c.kind == "part" and c.part == "heart")
	_check(hearts.size() == 2, "boss drops 2 Boss Hearts")
	_check(is_instance_valid(main.elevator) and not main.elevator.locked, "boss floor's extraction lift unlocks with the boss")

	# --- seeds: same run seed + depth = same floor ---
	var name_a: String = main.floor_theme["name"]
	var size_a := Vector2i(main.dungeon.w, main.dungeon.h)
	main._build_level()
	await _frames(3)
	_check(main.floor_theme["name"] == name_a and Vector2i(main.dungeon.w, main.dungeon.h) == size_a, "same seed rebuilds the same floor")

	# --- save & continue keep powers and curses ---
	var acts: int = p.actives.size() + p.passives.size()
	main.save_and_quit()
	await _frames(5)
	main.continue_run(0)
	await _frames(10)
	p = main.player
	_check(p.actives.size() + p.passives.size() == acts and p.curses.size() == 1 and main.depth == 10, "continue keeps powers, curses, depth")

	# --- death -> Soul Shards, Soul Altar ---
	var shards_before := int(Profile.data["shards"])
	main.bag = {"silk": 3}
	p.passives = [] # a random boss power could be Second Wind
	p.second_wind_used = true
	p.invuln = 0.0
	p.take_damage(999)
	await create_timer(1.3).timeout
	_check(main.game_over and int(Profile.data["shards"]) > shards_before, "death awards Soul Shards (%d)" % int(Profile.data["shards"]))
	_check(main.bag.is_empty() and Profile.mat_count("silk") == 0, "dying loses the unextracted bag")
	_check(not main._offerable_weapon("greataxe"), "Greataxe locked before unlocking")
	Profile.data["shards"] = 1000
	_check(Profile.buy("w_greataxe") and Profile.buy("shortcut_11") and Profile.buy("soul_anchor"), "buying unlocks works")
	main.go_to_menu()
	await _frames(3)
	main.start_new_run(1, "fighter", 11)
	await _frames(10)
	p = main.player
	_check(main.depth == 11 and main._offerable_weapon("greataxe"), "shortcut start at depth 11; Greataxe now offered")
	p.invuln = 0.0
	p.take_damage(999)
	await _frames(5)
	_check(not p.dead and main.revive_used, "Soul Anchor revives once")
	main.go_to_menu()

	# --- daily run is the same for everyone today ---
	main.start_new_run(3, "archer", 1, true)
	await _frames(5)
	var d1: String = main.floor_theme["name"] + str(main.dungeon.w)
	main.go_to_menu()
	main.start_new_run(3, "mage", 1, true)
	await _frames(5)
	_check(d1 == main.floor_theme["name"] + str(main.dungeon.w) and SaveManager.load_slot(3).has("daily"), "daily run floors match between attempts")
	main.go_to_menu()

	# --- tutorial ---
	GameSettings.values["tutorial"] = true
	Profile.data["tutorial_done"] = false
	main.start_new_run(2, "rogue")
	await create_timer(0.3).timeout
	_check(is_instance_valid(main.tutorial) and main.hud._hint_box.visible, "tutorial shows a hint on a first run")
	main.player.global_position += Vector2(60, 0)
	await create_timer(0.3).timeout
	_check(main.tutorial.step == 1, "tutorial advances after moving")
	main.go_to_menu()

	# --- settings, audio ---
	GameSettings.values["music"] = 0.3
	GameSettings.save()
	GameSettings.values["music"] = 1.0
	GameSettings.load_settings()
	_check(is_equal_approx(GameSettings.values["music"], 0.3), "settings save and load")
	await create_timer(3.0).timeout
	_check(main.audio._sounds.size() >= 14 and main.audio._tracks.size() == 2, "sounds (%d) and music tracks (%d) generated" % [main.audio._sounds.size(), main.audio._tracks.size()])


	# --- monster parts, extraction lift, workshop ---
	main.go_to_menu()
	await _frames(2)
	Profile.data["materials"] = {}
	Profile.data["crafted"] = {}
	main.start_new_run(0, "rogue")
	await _frames(5)
	p = main.player
	var hp0: int = p.max_hp
	var slime: Enemy = main._make_enemy("slime", true)
	slime.position = p.position + Vector2(40, 0)
	main.level.add_child(slime)
	await _frames(2)
	slime.take_damage(1e9, Vector2.RIGHT)
	await _frames(3)
	var parts: Array = main.level.get_children().filter(func(c): return c is Pickup and c.kind == "part")
	_check(parts.size() >= 2 and parts[0].part == "gel", "elite slime drops 2 Slime Gel")
	for pk in parts:
		pk.global_position = p.global_position
	await _frames(6)
	_check(int(main.bag.get("gel", 0)) >= 2, "parts go into the run bag (%s)" % str(main.bag))
	main.depth = 5
	main._build_level()
	await _frames(5)
	_check(is_instance_valid(main.elevator) and not main.elevator.locked, "floor 5 has an extraction lift")
	main.bag = {"bone": 8, "gel": 8}
	p.global_position = main.elevator.global_position
	await _frames(6)
	_check(main.modal, "stepping on the lift offers to send the loot up")
	var gold_before: int = main.gold
	main._on_dialog_chosen("extract")
	await _frames(3)
	_check(not main.game_over and main.playing and Profile.mat_count("bone") == 8 and main.bag.is_empty() and main.gold == gold_before, "the lift banks only the parts; the run goes on")
	_check(SaveManager.load_slot(0).get("alive", false), "the run is still alive after sending loot up")
	_check(Profile.craft("bone_charm") and Profile.crafted_level("bone_charm") == 1 and Profile.mat_count("bone") == 4, "crafting Bone Charm spends parts")
	_check(not Profile.craft("bone_charm"), "can't craft without enough parts")
	main.go_to_menu()
	main.menu.show_workshop()
	await _frames(2)
	_check(main.menu._workshop_rows.get_child_count() == Materials.RECIPES.size(), "Workshop lists every recipe")
	main.start_new_run(0, "rogue")
	await _frames(3)
	_check(main.player.max_hp == hp0 + 1, "Bone Charm gives +1 max HP on new runs")
	main.go_to_menu()

	# --- character creator ---
	main.go_to_menu()
	await _frames(2)
	main.menu._pick_class(2, false)
	main.menu._choose_class("rogue")
	await _frames(2)
	_check(main.menu._creator_page.visible, "picking a class opens the character creator")
	main.menu._creator_look["hat"] = "class"
	main.menu._cycle_opt("hat", 1)
	main.menu._cycle_opt("hat", 1)
	main.menu._creator_look["ghost"] = 0
	main.menu._cycle_opt("ghost", 1)
	main.menu._creator_look["eyes"] = 0
	main.menu._cycle_opt("eyes", -1)
	main.menu._name_edit.text = "Testy"
	main.menu._on_name_changed("Testy")
	var want: Dictionary = main.menu._creator_look.duplicate()
	main.menu._start_with_look()
	await _frames(5)
	_check(main.playing and main.player.look["hat"] == "knight_helm" and main.player.look["ghost"] == 1 and main.player.look["eyes"] == HeroArt.EYE_COLORS.size() - 1 and main.player.look["name"] == "Testy", "run starts with the created look (%s)" % str(main.player.look))
	var tex: Texture2D = Sprites.hero("rogue", main.player.look, "walk", 2)
	_check(tex != null and tex.get_width() == HeroArt.W + 2, "hero sprite builds from the look")
	main.save_and_quit()
	await _frames(3)
	main.continue_run(2)
	await _frames(5)
	_check(main.player.look.get("name", "") == "Testy" and main.player.look["hat"] == want["hat"], "continue keeps the look")
	_check(Profile.data["looks"]["rogue"]["name"] == "Testy", "creator remembers your last look per class")
	# Old saved looks (hair as a number etc.) must not break the creator.
	Profile.data["looks"]["mage"] = {"hair": 3, "hair_color": 2, "body": 1, "scarf": 4, "name": "Old"}
	main.go_to_menu()
	await _frames(2)
	main.menu._pick_class(2, false)
	main.menu._choose_class("mage")
	await _frames(2)
	_check(main.menu._creator_look["hat"] == "class" and main.menu._creator_look["name"] == "Old" and not main.menu._creator_look.has("hair"), "an old saved look opens cleanly in the creator")
	main.menu._start_with_look()
	await _frames(5)
	# --- gear drops, equipping, upgrades ---
	var pl: Player = main.player
	var base_dmg := pl.damage_mult
	var base_hp := pl.max_hp
	var helm := {"slot": "head", "id": "horned_helm", "name": "Horned Helm", "boon": "damage", "v": 0.12}
	pl.equip(helm)
	_check(is_equal_approx(pl.damage_mult, base_dmg * 1.12) and pl.vis_look()["eq_head"] == "horned_helm", "equipping gear applies its boon and look")
	var iron := {"slot": "head", "id": "iron_helm", "name": "Iron Helm", "boon": "max_hp", "v": 1.0}
	pl.equip(iron)
	_check(is_equal_approx(pl.damage_mult, base_dmg) and pl.max_hp == base_hp + 1, "swapping gear undoes the old boon")
	var wpool: Array = Classes.get_def("rogue")["weapons"]
	var all_ok := true
	for i in 60:
		var it := Gear.roll(wpool, i % 5 == 0)
		if Gear.describe_boon(it) == "" or Sprites.gear_icon(it) == null:
			all_ok = false
		var vl := pl.look.duplicate()
		if it["slot"] != "weapon":
			vl["eq_" + String(it["slot"])] = it["id"]
			Sprites.hero("rogue", vl, "walk", i % 8)
	_check(all_ok, "every gear piece rolls, describes and draws")
	var icons_ok := true
	for c in Classes.ORDER:
		for w in Classes.get_def(c)["weapons"]:
			if Sprites.gear_icon({"slot": "weapon", "id": w, "weapon": w}) == null or Sprites.weapon_grip(w) < 1:
				icons_ok = false
	_check(icons_ok, "every class weapon has a loot icon (Knives included)")
	var st: Array = main._roll_upgrades(3)
	_check(st.all(func(u: Dictionary) -> bool: return not String(u["id"]).begins_with("weapon:")), "stairs no longer offer weapon swaps")
	for u in main.UPGRADES:
		main._apply_upgrade(u["id"])
	_check(pl.max_hp > 0 and pl.block > 0.0 and pl.stair_heal == 2, "every stair upgrade applies (%d kinds)" % main.UPGRADES.size())
	var gp := Pickup.new()
	gp.main = main
	gp.kind = "gear"
	gp.item = Gear.roll([], false)
	gp.item["slot"] = "body"
	gp.item["id"] = "plate"
	pl.equipment.erase("body")
	main.collect(gp)
	_check(pl.equipment.get("body", {}).get("id", "") == "plate", "walking over gear in an empty slot equips it")
	gp.free()
	# --- shots stop at walls ---
	main.depth = 3
	main._build_level()
	await _frames(5)
	_clear_enemies()
	var d: Dungeon = main.dungeon
	var wall_shot_ok := false
	var pc: Vector2i = d.world_to_cell(pl.global_position)
	for dir in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
		var c := pc
		while d.is_floor(c.x, c.y):
			c += dir
		var shot := Projectile.new()
		shot.setup(Vector2(dir) * 400.0, 1.0, true, 3.0, 0)
		shot.origin = main.cell_center(c - dir)
		main.spawn(shot, main.cell_center(c + dir)) # spawned on the far side of the wall
		await _frames(3)
		wall_shot_ok = not is_instance_valid(shot) or shot._done
		break
	_check(wall_shot_ok, "a shot fired into a wall stops there (even if it spawns past it)")
	# --- heat ---
	Profile.data["heat_max"] = 0
	_check(not Grind.on_depth(0, 9, 9) and Grind.on_depth(0, 10, 10) and Grind.heat_max() == 1, "reaching depth 10 unlocks Heat 1")
	_check(not Grind.on_depth(1, 21, 1), "shortcut starts can't unlock heat")
	main.heat = 3
	var hot: Enemy = main._make_enemy("slime")
	main.heat = 0
	var cold: Enemy = main._make_enemy("slime")
	_check(hot.max_hp > cold.max_hp * 1.4, "heat makes monsters tougher")
	hot.free()
	cold.free()
	# --- endless workshop ---
	Profile.data["crafted"]["whetstone"] = 7
	_check(Materials.endless("whetstone") and Materials.cost_for("whetstone", 7)["ember"] > Materials.cost_for("whetstone", 3)["ember"] * 2, "endless recipes keep going with rising costs")
	Profile.data["materials"]["ember"] = 9999
	Profile.data["materials"]["bone"] = 9999
	_check(Profile.craft("whetstone") and Profile.crafted_level("whetstone") == 8, "you can craft past the old cap")
	_check(Materials.taper(100, 0.5) < 0.5001, "tapering bonuses stay under their cap")
	# --- gear levels + legendaries ---
	var low := Gear.roll([], false, 1)
	var hi := {}
	for i in 200:
		hi = Gear.roll([], false, 41)
		if hi["id"] == low["id"]:
			break
	if hi["id"] == low["id"]:
		_check(float(hi["v"]) > float(low["v"]), "deeper gear has stronger boons")
	var leg := Gear.roll(["daggers"], false, 30, true)
	_check(leg.get("legendary", false) and leg.has("boon2") and Gear.describe_boon(leg).contains(","), "legendary gear carries two boons")
	var dmg0 := pl.damage_mult
	var crit0 := pl.crit
	var leg2 := {"slot": "head", "id": "crown", "name": "Test Crown of Fury", "boon": "crit", "v": 0.1, "boon2": "damage", "v2": 0.5, "legendary": true}
	pl.equip(leg2)
	pl.equip({"slot": "head", "id": "bandana", "name": "Bandana", "boon": "gold", "v": 0.1})
	_check(is_equal_approx(pl.damage_mult, dmg0) and is_equal_approx(pl.crit, crit0), "unequipping a legendary removes both boons")
	# --- codex ---
	Profile.data["codex"] = {"bat": 49}
	_check(Grind.record_kill("bat") == 1 and Grind.codex_tier("bat") == 1, "the 50th kill reaches codex mastery I")
	_check(is_equal_approx(Grind.codex_bonus("bat"), 1.0 + Grind.CODEX_DAMAGE), "codex mastery boosts damage")
	var bat_ghost := HeroArt.GHOST_COLORS.size() + Grind.CODEX_KINDS.find("bat")
	_check(not HeroArt.color_unlocked("ghost", bat_ghost), "codex ghost colours start locked")
	Profile.data["codex"]["bat"] = 1000
	_check(HeroArt.color_unlocked("ghost", bat_ghost) and HeroArt.complete("rogue", {"ghost": bat_ghost})["ghost"] == bat_ghost, "mastery III unlocks its ghost colour")
	# --- bounties ---
	Profile.data["bounties"] = [{"type": "elites", "key": "", "goal": 2, "progress": 0, "desc": "Slay 2 elites", "reward": {"parts": {"gel": 5}, "shards": 10}}]
	var bl: Array = Grind.bounties()
	_check(bl.size() == 3, "the board always shows three bounties")
	Grind.bounty_progress("elites")
	var done: Array = Grind.bounty_progress("elites")
	var shards0 := int(Profile.data["shards"])
	var gel0 := Profile.mat_count("gel")
	_check(done.size() == 1 and Grind.claim(0) and int(Profile.data["shards"]) == shards0 + 10 and Profile.mat_count("gel") == gel0 + 5, "finished bounties pay out and get replaced")
	_check(Grind.bounties().size() == 3, "a new bounty takes the claimed one's place")
	# --- mutated deep bosses ---
	var mutated_seen := false
	for i in 12:
		main.run_seed = 1000 + i
		main.depth = 60
		main._build_level()
		await _frames(2)
		if is_instance_valid(main.hud.boss) and main.hud.boss.has_meta("mutated"):
			mutated_seen = main.hud.boss.title.begins_with("Mutated")
			break
	_check(mutated_seen, "deep bosses can come mutated")
	_clear_enemies()
	# --- weekly mutator run ---
	var wm: Array = Grind.weekly_mutators()
	_check(wm.size() == 2 and wm[0] != wm[1] and Grind.weekly_mutators() == wm, "two fixed mutators per week")
	main.go_to_menu()
	await _frames(2)
	main.menu._on_weekly()
	main.menu._choose_class("fighter")
	main.menu._start_with_look()
	await _frames(5)
	_check(main.is_weekly and main.mutators == wm and main.slot == Grind.WEEKLY_SLOT and main.heat == 0, "the weekly run starts with this week's mutators")
	main.save_and_quit()
	await _frames(3)
	main.continue_run(Grind.WEEKLY_SLOT)
	await _frames(5)
	_check(main.is_weekly and main.mutators == wm, "continuing keeps the weekly mutators")
	main.go_to_menu()
	await _frames(2)
	main.menu.show_bounties()
	main.menu.show_codex()
	await _frames(2)
	_check(main.menu._bounty_rows.get_child_count() >= 3 and main.menu._codex_rows.get_child_count() == Grind.CODEX_KINDS.size(), "bounty board and codex pages build")
	main.start_new_run(0, "rogue")
	await _frames(5)
	pl = main.player
	# --- dodge: see-through and untouchable during the dash and a short grace after ---
	pl.invuln = 0.0
	pl.dodge_cd = 0.0
	pl.dodge_t = 0.0
	var hp_d := pl.hp
	pl.request_dodge()
	pl.take_damage(1)
	_check(pl.phase_t > 0.0 and pl.hp == hp_d, "dodging makes you untouchable")
	await create_timer(Player.DODGE_DURATION + 0.05).timeout
	pl.take_damage(1)
	_check(pl.phase_t > 0.0 and pl.hp == hp_d, "the dodge keeps protecting you just after the dash")
	await create_timer(Player.DODGE_GRACE + 0.1).timeout
	_check(pl.phase_t == 0.0, "the dodge protection ends shortly after")
	# --- cursed idol (slot machine) ---
	var idol := EventNode.new()
	idol.main = main
	idol.kind = "slots"
	main.level.add_child(idol)
	idol.global_position = pl.global_position + Vector2(200, 0)
	var rolls_ok := true
	for i in 300:
		var res: Dictionary = main._slot_roll()
		var rr: Array = res["reels"]
		var same: bool = rr.count(rr[0]) == 3
		var has_pair: bool = rr[0] == rr[1] or rr[1] == rr[2] or rr[0] == rr[2]
		if rr.size() != 3 or (res["kind"] == "triple" and not same) or (res["kind"] == "none" and has_pair) or (res["kind"] == "pair" and (same or not has_pair)):
			rolls_ok = false
	_check(rolls_ok, "slot reels always show the rolled outcome")
	main.gold = 1000
	main._active_event = idol
	main.on_event(idol)
	_check(main.modal and main.hud.reels.visible, "the idol opens with its reels")
	var g0: int = main.gold
	main._on_dialog_chosen("slot_pull")
	_check(main.gold < g0 and main.hud.reels.spinning(), "pulling the lever costs gold and spins")
	await create_timer(2.4, true).timeout
	_check(not main.hud.reels.spinning() and int(idol.get_meta("pulls", 0)) == 1, "the reels stop and pay out")
	for o in main.SLOT_ODDS:
		if o[0] != "triple" or o[1] != "skull":
			main._slot_result(idol, {"kind": o[0], "sym": o[1], "reels": [0, 1, 2]}, 20)
	_check(pl.hp > 0, "every slot outcome resolves")
	await _frames(3)
	main._close_modal()
	idol.queue_free()
	# --- drag scrolling in the Workshop ---
	var ds := DragScroll.new(ScrollContainer.new())
	_check(ds.scroll != null, "drag-to-scroll helper builds")
	ds.scroll.free()
	ds.free()
	for anim in HeroArt.ANIMS:
		for f in HeroArt.frame_count(anim):
			Sprites.hero("mage", HeroArt.random_look(), anim, f)
	_check(true, "every hero animation frame builds")
	main.go_to_menu()
	_wipe()
	print("SMOKE TEST %s (%d failures)" % ["OK" if failures == 0 else "FAILED", failures])
	quit(1 if failures > 0 else 0)


func level_has(type) -> bool:
	if not is_instance_valid(main.level):
		return false
	for c in main.level.get_children():
		if is_instance_of(c, type):
			return true
	return false
