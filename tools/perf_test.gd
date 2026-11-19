extends SceneTree
## Rendered performance check: a deep floor, every enemy awake, a rogue spamming attacks.
## Prints average / worst frame time. Run without --headless so rendering is included:
##   Godot_console.exe --path . -s res://tools/perf_test.gd

var main: Node


func _initialize() -> void:
	SaveManager.prefix = "user://perf_save_"
	Profile.path_override = "user://perf_profile.json"
	GameSettings.path_override = "user://perf_settings.json"
	GameSettings.values["tutorial"] = false
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	_go.call_deferred()


func _go() -> void:
	main.start_new_run(0, "rogue")
	await process_frame
	main.depth = 30
	main._build_level()
	for i in 20:
		await process_frame
	var p: Player = main.player
	p.invuln = 1e9
	p.max_charges = 6
	p.crit = 0.5
	for e in get_nodes_in_group("enemies"):
		e.aggro = true
	var args := OS.get_cmdline_user_args()
	if "nodungeon" in args:
		main.dungeon.visible = false
	if "nominimap" in args:
		main.hud.minimap.visible = false
		main.hud.minimap.set_process(false)
	if "noenemies" in args:
		for e in get_nodes_in_group("enemies"):
			e.queue_free()
	print("args: ", args)
	print("enemies: ", get_nodes_in_group("enemies").size(), "  map: ", main.dungeon.w, "x", main.dungeon.h)
	var times: Array[float] = []
	var last := Time.get_ticks_usec()
	for i in 600:
		p.charges = p.max_charges
		p.touch_move = Vector2.RIGHT.rotated(i * 0.02)
		if i % 6 == 0:
			p.queue_attack(true)
		await process_frame
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var avg := 0.0
	for t in times:
		avg += t
	avg /= times.size()
	print("frame ms  avg %.2f   p95 %.2f   worst %.2f   nodes %d" % [avg, times[int(times.size() * 0.95)], times[times.size() - 1], get_node_count()])
	print("time_scale now: ", Engine.time_scale)
	for i in 3:
		SaveManager.delete_slot(i)
	quit()
