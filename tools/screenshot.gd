extends SceneTree
## Saves screenshots (menu, Soul Altar, lit floor with powers + elites, darkness, boss) to user://.

func _initialize() -> void:
	SaveManager.prefix = "user://shot_save_"
	Profile.path_override = "user://shot_profile.json"
	GameSettings.path_override = "user://shot_settings.json"
	GameSettings.values["tutorial"] = false
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_go.call_deferred(main)


func _snap(file: String) -> void:
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png(OS.get_user_data_dir() + "/" + file)


func _go(main: Node) -> void:
	Profile.data["shards"] = 140
	Profile.data["unlocks"] = {"deep_pockets": true, "w_greataxe": true}
	SaveManager.save_slot(0, {"class": "rogue", "alive": true, "depth": 7, "gold": 84, "kills": 61, "best_depth": 12, "player": {}})
	main.menu.show_slots()
	for i in 10:
		await process_frame
	await _snap("shot_menu.png")
	Profile.data["codex"] = {"slime": 260, "bat": 1200, "spider": 40, "skeleton": 90, "boss": 6}
	Profile.data["heat_max"] = 2
	main.menu.show_bounties()
	await _snap("shot_bounties.png")
	main.menu.show_codex()
	await _snap("shot_codex.png")
	main.menu._pick_class(0, false)
	main.menu._cycle_heat()
	await _snap("shot_heat.png")
	main.menu.show_altar()
	await _snap("shot_altar.png")
	main.menu._pick_class(1, false)
	for i in 4:
		await process_frame
	await _snap("shot_classes.png")
	main.menu._choose_class("archer")
	for i in 30:
		await process_frame
	await _snap("shot_creator.png")
	Profile.data["materials"] = {"gel": 14, "wing": 6, "silk": 9, "bone": 11, "powder": 3, "ecto": 5, "ember": 4, "sigil": 2, "horn": 1, "core": 2, "heart": 1}
	Profile.data["crafted"] = {"bone_charm": 1, "silk_wraps": 3}
	main.menu.show_workshop()
	for i in 4:
		await process_frame
	await _snap("shot_workshop.png")

	main.start_new_run(1, "mage")
	main.touch.active = true
	main.depth = 13
	main._build_level()
	for i in 20:
		await physics_frame
	var p: Player = main.player
	p.invuln = 1e9
	p.add_power({"type": "active", "id": "radial", "name": "Vorrak's Nova", "tier": 10})
	p.add_power({"type": "active", "id": "teleport", "name": "Nyx's Blink", "tier": 10})
	p.add_power({"type": "active", "id": "slam", "name": "Gul's Quake", "tier": 10})
	p.add_power({"type": "passive", "id": "orbit", "name": "Shards", "tier": 10})
	p.add_power({"type": "passive", "id": "thorns", "name": "Thorns", "tier": 10})
	p.ability_cd[1] = 3.0
	for k in [["golem", Vector2(55, -20), ["shielded", "toxic"]], ["spider", Vector2(45, 25), ["vampiric"]], ["wisp", Vector2(-50, 0), []]]:
		var e: Enemy = main._make_enemy(k[0], not k[2].is_empty())
		if not k[2].is_empty():
			e.set_affixes(k[2])
		e.stun = 999.0
		e.aggro = true
		e.position = p.position + k[1]
		main.level.add_child(e)
	for i in 30:
		await physics_frame
	p.use_ability(0)
	for i in 8:
		await physics_frame
	main.gain_xp(Leveling.need(1) + 6)
	for i in 4:
		await physics_frame
	await _snap("shot_game.png")
	while p.level < 5:
		main.gain_xp(Leveling.need(p.level) - p.xp)
	for i in 30:
		await process_frame
	await _snap("shot_perk.png")
	main._on_upgrade_chosen("perk:haunt")
	# Every regular enemy walking toward you.
	var kinds := ["slime", "bat", "spider", "skeleton", "bomber", "ghost", "cultist", "brute", "golem", "slimelet"]
	for i in kinds.size():
		var e: Enemy = main._make_enemy(kinds[i], i == 7)
		e.aggro = true
		e.position = p.position + Vector2.RIGHT.rotated(TAU * i / kinds.size()) * 70.0
		main.level.add_child(e)
	for i in 25:
		await physics_frame
	await _snap("shot_crowd.png")

	main.force_mod = "darkness"
	main.depth = 14
	main._build_level()
	for i in 30:
		await physics_frame
	await _snap("shot_dark.png")
	# Extraction lift with some parts lying around.
	main.depth = 15
	main._build_level()
	for i in 10:
		await physics_frame
	p.global_position = main.elevator.global_position + Vector2(-50, 20)
	p.reset_physics_interpolation()
	for k in ["gel", "bone", "wing", "core", "ecto"]:
		main._drop("part", 1, p.global_position + Vector2(randf_range(-40, -20), randf_range(-25, 25)), k)
	main.bag = {"gel": 4, "bone": 3, "silk": 2}
	main._refresh_hud()
	for i in 30:
		await physics_frame
	await _snap("shot_lift.png")
	# Gear on the floor + the Cursed Idol mid-spin and after a payout.
	main._spawn_gear(Gear.roll(["daggers"], true), p.global_position + Vector2(30, 10))
	main._spawn_gear({"slot": "head", "id": "horned_helm", "name": "Horned Helm", "boon": "damage", "v": 0.12}, p.global_position + Vector2(50, -10))
	var idol := EventNode.new()
	idol.main = main
	idol.kind = "slots"
	main.level.add_child(idol)
	idol.global_position = p.global_position + Vector2(-40, -30)
	for i in 20:
		await physics_frame
	await _snap("shot_gear.png")
	main.gold = 300
	main.on_event(idol)
	await create_timer(0.5).timeout
	main._on_dialog_chosen("slot_pull")
	await create_timer(1.0).timeout
	await _snap("shot_slots_spin.png")
	await create_timer(1.6).timeout
	await _snap("shot_slots.png")
	main._close_modal()
	main.force_mod = ""

	main.depth = 20
	main._build_level()
	for i in 10:
		await physics_frame
	var boss: Enemy = main.hud.boss
	p.global_position = boss.global_position + Vector2(-70, 24)
	p.reset_physics_interpolation()
	boss.aggro = true
	for i in 80:
		await physics_frame
	await _snap("shot_boss.png")
	for i in 4:
		SaveManager.delete_slot(i)
	for f in ["user://shot_profile.json", "user://shot_settings.json"]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	print("saved")
	quit()
