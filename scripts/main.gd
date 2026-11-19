extends Node
## Game controller: home screen, save slots, runs, floors, events, boss powers,
## curses, floor modifiers, lighting, audio, pause and death.

const TILE := 16
const BOSS_EVERY := 10
const EVENT_CHANCE := 0.3
const MAX_CHARGES := 6
const DAILY_SLOT := 3 # hidden save slot for the daily run

## Every floor is generated: random look, random name, random enemy mix.
## Difficulty comes from the depth: tougher enemy types unlock as you go down,
## enemy stats, numbers, elite chance and boss attack count all scale forever.
const ENEMY_UNLOCK := {
	"slime": 1, "bat": 1, "spider": 2, "skeleton": 3, "bomber": 4, "wisp": 5,
	"brute": 6, "ghost": 7, "cultist": 9, "golem": 11,
}
const PLACE_ADJ := ["Sunken", "Ashen", "Forgotten", "Hollow", "Drowned", "Burning", "Silent", "Rotting",
	"Frozen", "Shattered", "Weeping", "Gilded", "Fungal", "Bleeding", "Starless", "Crooked"]
const PLACE_NOUN := ["Crypt", "Halls", "Caverns", "Catacombs", "Vaults", "Warrens", "Sanctum", "Pits",
	"Ossuary", "Galleries", "Cisterns", "Labyrinth", "Mines", "Barrows", "Depths", "Grotto"]

const UPGRADES := [
	{"id": "damage", "name": "Whetstone", "desc": "+20% damage"},
	{"id": "reload", "name": "Quick Hands", "desc": "Charges refill 25% faster"},
	{"id": "charge", "name": "Extra Charge", "desc": "+1 attack charge"},
	{"id": "speed", "name": "Swift Boots", "desc": "+12% move speed"},
	{"id": "vitality", "name": "Vitality", "desc": "+2 max HP, full heal"},
	{"id": "reach", "name": "Long Reach", "desc": "+15% weapon range"},
	{"id": "crit", "name": "Keen Eye", "desc": "+8% crit chance"},
	{"id": "dodge", "name": "Shadow Step", "desc": "Dodge recharges 25% faster"},
	{"id": "luck", "name": "Lucky Charm", "desc": "More heart drops"},
	{"id": "glass", "name": "Glass Cannon", "desc": "+40% damage, -1 max HP"},
	{"id": "iron_skin", "name": "Iron Skin", "desc": "10% chance to block a hit"},
	{"id": "gold_rush", "name": "Gold Rush", "desc": "+30% gold"},
	{"id": "leech", "name": "Leech", "desc": "6% chance to heal on kill"},
	{"id": "brutal", "name": "Brutal Crits", "desc": "+50% crit damage"},
	{"id": "magnet", "name": "Magnet", "desc": "Pull loot from much further away"},
	{"id": "titan", "name": "Titan", "desc": "+4 max HP, -6% move speed"},
	{"id": "frenzy", "name": "Frenzy", "desc": "+10% damage, +6% move speed"},
	{"id": "focus", "name": "Focus", "desc": "Boss powers recharge 20% faster"},
	{"id": "fortune", "name": "Treasure Hunter", "desc": "Gear drops 60% more often"},
	{"id": "rest", "name": "Campfire", "desc": "Heal 3 now, +1 heal on every staircase"},
	{"id": "execute", "name": "Executioner", "desc": "+60% damage to foes below 30% HP"},
	{"id": "quick_dodge", "name": "Acrobat", "desc": "Dodge recharges 15% faster, +5% speed"},
]

## Curses come with the cursed "plunge" stairs and last the whole run.
const CURSES := {
	"frail": {"name": "Frailty", "desc": "-1 max HP"},
	"heavy": {"name": "Heavy Feet", "desc": "-8% move speed"},
	"dull": {"name": "Dull Edge", "desc": "-10% damage"},
	"slow_hands": {"name": "Slow Hands", "desc": "Charges refill 15% slower"},
	"hunted": {"name": "Hunted", "desc": "Foes are 10% faster"},
	"greed": {"name": "Greed's Price", "desc": "Trader prices +25%"},
}

## Floor modifiers (rare rules for one floor).
const MODIFIERS := {
	"darkness": "Darkness: your light barely reaches",
	"flooded": "Flooded: everyone wades slower, lightning +50%",
	"infested": "Infested: twice the foes, twice the gold",
	"silent": "Silent: foes notice you later",
	"unstable": "Unstable: soon the ceiling starts to fall",
}

const EVENT_WEIGHTS := {"trader": 4, "shrine": 3, "chest": 3, "fountain": 2, "slots": 3}

var rng := RandomNumberGenerator.new()

# Run state.
var playing := false
var slot := 0
var class_id := "fighter"
var depth := 1
var gold := 0
var kills := 0
var bosses_killed := 0
var best_depth := 0
var run_seed := 0
var is_daily := false
## Weekly mutator run (Grind.MUTATORS active in `mutators`) and the Heat level of this run.
var is_weekly := false
var mutators: Array = []
var heat := 0
## Depth this run started at (shortcuts start deeper; heat unlocks need 10 floors of descent).
var run_start_depth := 1
var revive_used := false
var game_over := false
var modal := false # an upgrade / dialog panel is open
var floor_mod := ""
var floor_theme: Dictionary = {}
var _upgrade_context := "stairs"
var _active_event: EventNode = null
var _pending_power: Dictionary = {}
var _pending_gear: Dictionary = {}
## Tests switch random gear drops off so a dropped piece cannot open a dialog mid-test.
var gear_drops := true
var _unstable_t := 0.0
var _rock_t := 0.0
var _last_hue := 0.0
var force_mod := ""
## Monster parts picked up this run. Only kept once sent up on a Loot Lift.
var bag := {}
var extracted := false
var elevator: Elevator
const EXTRACT_EVERY := 5

# Scene objects.
var world: Node2D
var level: Node2D
var dungeon: Dungeon
var stairs: Stairs
var player: Player
var camera: Camera2D
var hud: HUD
var menu: Menu
var touch: TouchControls
var audio: Audio
var tutorial: Tutorial
var _touch_layer: CanvasLayer
var _overlay_layer: CanvasLayer
var _canvas_mod: CanvasModulate
var _player_light: PointLight2D
var _unshaded := CanvasItemMaterial.new()
var _shake := 0.0
var _hit_stop_ready := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	_setup_input()
	_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	audio = Audio.new()
	add_child(audio)
	GameSettings.load_settings()
	Profile.load_profile()

	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	_canvas_mod = CanvasModulate.new()
	_canvas_mod.color = Color.WHITE
	world.add_child(_canvas_mod)

	_touch_layer = CanvasLayer.new()
	_touch_layer.layer = 5
	_touch_layer.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_touch_layer)
	touch = TouchControls.new()
	touch.main = self
	_touch_layer.add_child(touch)

	hud = HUD.new()
	add_child(hud)
	hud.minimap.main = self
	hud.upgrade_chosen.connect(_on_upgrade_chosen)
	hud.dialog_chosen.connect(_on_dialog_chosen)
	hud.pause_pressed.connect(toggle_pause)
	hud.save_quit_requested.connect(save_and_quit)
	hud.abandon_requested.connect(abandon_run)
	hud.retry_requested.connect(func() -> void:
		Grind.pending_weekly = is_weekly
		Grind.selected_heat = heat
		start_new_run(slot, class_id, 1, is_daily, player.look if is_instance_valid(player) else {}))
	hud.menu_requested.connect(go_to_menu)
	hud.settings_requested.connect(open_settings)

	menu = Menu.new()
	menu.main = self
	add_child(menu)
	menu.continue_requested.connect(continue_run)
	menu.new_run_requested.connect(start_new_run)
	menu.settings_requested.connect(open_settings)

	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 30
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)

	go_to_menu()
	_signal_web_ready()


## Web build: tells the page's loading screen (web/shell.html) that the menu is on screen, so
## it can fade out. Waits two frames so the menu has actually been drawn.
func _signal_web_ready() -> void:
	if not OS.has_feature("web"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	JavaScriptBridge.eval("window.depthboundReady && window.depthboundReady()", true)


func _process(delta: float) -> void:
	if is_instance_valid(camera):
		if _shake > 0.0 and GameSettings.values["screen_shake"]:
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
			_shake = move_toward(_shake, 0.0, 30.0 * delta)
		else:
			_shake = 0.0
			camera.offset = Vector2.ZERO
	# Unstable floors: after a while, rocks start falling around the player.
	if playing and floor_mod == "unstable" and not get_tree().paused and is_instance_valid(player) and not player.dead:
		_unstable_t += delta
		if _unstable_t > 30.0 and _unstable_t - delta <= 30.0:
			show_banner("The ceiling groans...")
		if _unstable_t > 40.0:
			_rock_t -= delta
			if _rock_t <= 0.0:
				_rock_t = 1.4
				var b := Blast.new()
				b.from_player = false
				b.radius = 22.0
				b.delay = 1.0
				b.damage = 1
				b.color = Color(0.7, 0.6, 0.5)
				spawn(b, player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.0, 40.0))


func _unhandled_input(event: InputEvent) -> void:
	if not playing:
		return
	if event.is_action_pressed("pause"):
		toggle_pause()
	elif game_over and event.is_action_pressed("restart"):
		start_new_run(slot, class_id, 1, is_daily)


func _notification(what: int) -> void:
	if not playing or game_over:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_run()
	# On phones, save and pause when the app goes to the background.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and OS.has_feature("mobile"):
		save_run()
		if not get_tree().paused:
			toggle_pause()


func sfx(sound: String, volume_db := 0.0) -> void:
	audio.play(sound, 0.08, volume_db)


# ---------------------------------------------------------------- menu & saves

func go_to_menu() -> void:
	playing = false
	game_over = false
	modal = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(level):
		level.queue_free()
	if is_instance_valid(tutorial):
		tutorial.queue_free()
	hud.hide_all()
	hud.show_hint("")
	hud.visible = false
	_touch_layer.visible = false
	_canvas_mod.color = Color.WHITE
	RenderingServer.set_default_clear_color(Color(0.03, 0.02, 0.05))
	audio.music("calm")
	menu.open()


func open_settings() -> void:
	var panel := SettingsPanel.new()
	_overlay_layer.add_child(panel)
	panel.closed.connect(panel.queue_free)


## start_depth > 1 = Soul Altar shortcut. daily = today's shared seed.
func start_new_run(slot_index: int, cls: String, start_depth := 1, daily := false, new_look := {}) -> void:
	slot = slot_index
	class_id = cls
	is_daily = daily
	is_weekly = Grind.pending_weekly
	Grind.pending_weekly = false
	heat = 0 if (daily or is_weekly) else Grind.selected_heat
	mutators = Grind.weekly_mutators() if is_weekly else []
	best_depth = int(SaveManager.load_slot(slot).get("best_depth", 0))
	depth = start_depth
	run_start_depth = start_depth
	gold = 40 if Profile.has("deep_pockets") else 0
	kills = 0
	bosses_killed = 0
	revive_used = false
	bag = {}
	extracted = false
	run_seed = Profile.today().hash() if daily else (Grind.week_id() * 31337 + 7 if is_weekly else randi())
	_spawn_player()
	player.apply_class(cls)
	# Appearance from the character creator (or the class default).
	player.look = HeroArt.complete(cls, new_look) if not new_look.is_empty() else HeroArt.default_look(cls)
	Sprites.prewarm_hero(cls, player.look)
	# Workshop bonuses crafted from extracted monster parts.
	Materials.apply_to(player)
	if Profile.crafted_level("heart_forge") > 0:
		player.add_power(_forged_power())
	var blessings := int((start_depth - 1) / 10.0) * 3 + (1 if Profile.has("heirloom") else 0)
	# Heat: starting curses. Weekly mutators that change the hero.
	for i in Grind.curses_for(heat):
		_apply_curse()
	_apply_mutators()
	for i in blessings:
		_apply_upgrade(_roll_upgrades(1, 0.0)[0]["id"])
	if start_depth == 1 and GameSettings.values["tutorial"] and not Profile.data.get("tutorial_done", false):
		tutorial = Tutorial.new()
		tutorial.main = self
		add_child(tutorial)
	_build_level()


func continue_run(slot_index: int) -> void:
	var data := SaveManager.load_slot(slot_index)
	if data.is_empty() or not data.get("alive", false):
		return
	slot = slot_index
	class_id = data.get("class", "fighter")
	depth = int(data.get("depth", 1))
	gold = int(data.get("gold", 0))
	kills = int(data.get("kills", 0))
	bosses_killed = int(data.get("bosses", 0))
	best_depth = int(data.get("best_depth", depth))
	run_seed = int(data.get("seed", randi()))
	is_daily = data.has("daily")
	is_weekly = data.has("weekly")
	mutators = data.get("mutators", [])
	heat = int(data.get("heat", 0))
	run_start_depth = int(data.get("start_depth", 1))
	revive_used = data.get("revive_used", false)
	bag = data.get("bag", {})
	extracted = false
	_spawn_player()
	player.apply_class(class_id)
	player.from_dict(data.get("player", {}))
	player.look = HeroArt.complete(class_id, player.look)
	Sprites.prewarm_hero(class_id, player.look)
	_build_level()


func save_run() -> void:
	if not is_instance_valid(player):
		return
	best_depth = maxi(best_depth, depth)
	var data := {
		"version": 2,
		"class": class_id,
		"alive": not player.dead and not extracted,
		"bag": bag,
		"extracted": extracted,
		"depth": depth,
		"gold": gold,
		"kills": kills,
		"bosses": bosses_killed,
		"best_depth": best_depth,
		"seed": run_seed,
		"revive_used": revive_used,
		"player": player.to_dict(),
		"heat": heat,
		"start_depth": run_start_depth,
	}
	if is_daily:
		data["daily"] = Profile.today()
	if is_weekly:
		data["weekly"] = Grind.week_id()
		data["mutators"] = mutators
	SaveManager.save_slot(slot, data)
	Profile.save() # codex kills, bounty progress


func save_and_quit() -> void:
	save_run()
	go_to_menu()


func abandon_run() -> void:
	player.dead = true
	_end_run(0.5)
	save_run()
	go_to_menu()


## Run is over: award Soul Shards and records. Returns shards earned.
func _end_run(shard_mult := 1.0) -> int:
	var shards := int(Profile.shards_for(depth, bosses_killed, kills) * shard_mult * (1.0 + 0.25 * heat))
	Profile.add_shards(shards)
	Profile.data["best_depth"] = maxi(int(Profile.data.get("best_depth", 0)), depth)
	if is_daily:
		Profile.record_daily(depth)
	if is_weekly:
		Grind.record_weekly(depth)
	Profile.save()
	return shards


# ---------------------------------------------------------------- runs & floors

## Weekly mutators that change the hero (the rest are checked where they apply).
func _apply_mutators() -> void:
	if "glass" in mutators:
		player.damage_mult *= 2.0
		player.max_hp = maxi(1, int(ceil(player.max_hp / 2.0)))
		player.hp = player.max_hp
	if "frenzy" in mutators:
		player.speed *= 1.3
	if "bloodless" in mutators:
		player.kill_heal += 0.1
	if "loaded" in mutators:
		player.gear_find *= 3.0


## Bounty progress, with a banner when one is completed.
func _bounty(type: String, amount := 1, key := "") -> void:
	for d in Grind.bounty_progress(type, amount, key, heat):
		show_banner("Bounty complete: %s\nClaim your reward on the Bounty Board." % d, 3.0)
		sfx("power", -6.0)


func _spawn_player() -> void:
	menu.close()
	playing = true
	game_over = false
	modal = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(tutorial):
		tutorial.queue_free()
	player = Player.new()
	player.main = self
	player.died.connect(_on_player_died)
	player.stats_changed.connect(_refresh_hud)
	world.add_child(player)
	_player_light = Torch.make_light(170.0, Color(1.0, 0.93, 0.8), 0.75)
	player.add_child(_player_light)
	hud.player = player
	hud.visible = true
	hud.hide_all()
	_touch_layer.visible = true

	camera = Camera2D.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS # required with physics interpolation
	# No smoothing: the camera sticks to the (interpolated) player so nothing judders or smears.
	camera.position_smoothing_enabled = false
	camera.position_smoothing_speed = 9.0
	player.add_child(camera)
	camera.make_current()


func get_biome() -> Dictionary:
	return floor_theme


func is_boss_floor(d := -1) -> bool:
	return (depth if d < 0 else d) % BOSS_EVERY == 0


## Enemy types allowed at this depth (harder ones unlock deeper).
func unlocked_enemies() -> Array:
	return ENEMY_UNLOCK.keys().filter(func(k: String) -> bool: return depth >= int(ENEMY_UNLOCK[k]))


func _shuffle(arr: Array) -> Array:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
	return arr


## Rolls this floor's look, name and enemy mix.
func _make_theme() -> Dictionary:
	var hue := fmod(_last_hue + rng.randf_range(0.18, 0.82), 1.0)
	_last_hue = hue
	var sat := rng.randf_range(0.12, 0.38)
	var floor_c := Color.from_hsv(hue, sat, rng.randf_range(0.17, 0.25))
	var wall_c := Color.from_hsv(fmod(hue + rng.randf_range(-0.05, 0.05) + 1.0, 1.0), sat + 0.08, rng.randf_range(0.4, 0.55))
	var pool := _shuffle(unlocked_enemies())
	var roster_size := clampi(3 + int(depth / 8.0) + rng.randi_range(-1, 1), 2, pool.size())
	var roster := {}
	for k in pool.slice(0, roster_size):
		roster[k] = rng.randi_range(1, 3)
	return {
		"name": "%s %s" % [PLACE_ADJ[rng.randi() % PLACE_ADJ.size()], PLACE_NOUN[rng.randi() % PLACE_NOUN.size()]],
		"floor": floor_c,
		"floor_alt": floor_c.darkened(0.12),
		"wall": wall_c,
		"wall_face": wall_c.darkened(0.4),
		"bg": Color.from_hsv(hue, sat, 0.05),
		"roster": roster,
	}


func _build_level() -> void:
	if is_instance_valid(level):
		level.queue_free()
	level = Node2D.new()
	level.name = "Level%d" % depth
	world.add_child(level)
	world.move_child(level, 1) # above the CanvasModulate, below the player
	hud.boss = null
	elevator = null
	# Same seed + same depth = same floor (daily runs, and continuing a save).
	rng.seed = ("%d:%d" % [run_seed, depth]).hash()
	player.second_wind_used = false
	_unstable_t = 0.0
	_rock_t = 0.0

	floor_theme = _make_theme()
	floor_mod = ""
	if depth >= 2 and not is_boss_floor() and rng.randf() < 0.25:
		floor_mod = MODIFIERS.keys()[rng.randi() % MODIFIERS.size()]
	if "night" in mutators and not is_boss_floor():
		floor_mod = "darkness"
	if force_mod != "": # used by the test suite
		floor_mod = force_mod
	var biome := floor_theme
	if floor_mod == "flooded":
		biome["floor"] = (biome["floor"] as Color).lerp(Color(0.12, 0.22, 0.38), 0.45)
		biome["floor_alt"] = (biome["floor"] as Color).darkened(0.12)
	RenderingServer.set_default_clear_color(biome["bg"])
	# Lighting: dim world, light around the player. Darkness floors are much darker.
	_canvas_mod.color = Color(0.1, 0.1, 0.13) if floor_mod == "darkness" else Color(0.6, 0.58, 0.64)
	_player_light.texture_scale = (90.0 if floor_mod == "darkness" else 170.0) / 128.0

	# Random size and room count, growing with depth (capped so huge depths stay smooth).
	var w := mini(rng.randi_range(48, 64) + depth * 2, 110)
	var h := mini(rng.randi_range(34, 46) + depth, 72)
	var rooms_max := mini(rng.randi_range(8, 12) + int(depth / 2.0), 24)
	var data := DungeonGenerator.new().generate(w, h, rooms_max, rng)
	dungeon = Dungeon.new()
	dungeon.setup(data, biome)
	level.add_child(dungeon)
	hud.minimap.reset()

	var rooms: Array[Rect2i] = data["rooms"]
	var start_room := rooms[0]
	player.global_position = cell_center(start_room.get_center())
	player.reset_physics_interpolation()
	camera.reset_smoothing.call_deferred()

	# Stairs in the farthest room; a cursed plunge sometimes in the second farthest.
	var by_dist: Array = rooms.duplicate()
	_sort_origin = Vector2(start_room.get_center())
	by_dist.sort_custom(_farther_room)
	var far_room: Rect2i = by_dist[0]
	stairs = Stairs.new()
	stairs.main = self
	stairs.position = cell_center(far_room.get_center())
	level.add_child(stairs)
	var plunge_room := Rect2i()
	if depth >= 3 and not is_boss_floor() and not is_boss_floor(depth + 1) and rooms.size() > 3 and rng.randf() < 0.25:
		plunge_room = by_dist[1]
		var ps := Stairs.new()
		ps.main = self
		ps.plunge = true
		ps.position = cell_center(plunge_room.get_center())
		level.add_child(ps)

	# Loot Lift every 5th floor, in a room part-way across the map.
	var lift_room := Rect2i()
	if depth % EXTRACT_EVERY == 0:
		var lift_choices: Array = by_dist.filter(func(r: Rect2i) -> bool: return r != far_room and r != plunge_room and r != start_room)
		lift_room = lift_choices[0] if not lift_choices.is_empty() else far_room
		elevator = Elevator.new()
		elevator.main = self
		elevator.locked = is_boss_floor()
		var lift_pos := cell_center(lift_room.get_center())
		if lift_room == far_room:
			lift_pos += Vector2(TILE * 2, 0)
		elevator.position = lift_pos
		level.add_child(elevator)

	_place_torches(rooms.size() + 4)

	var spawn_rooms: Array = rooms.filter(func(r: Rect2i) -> bool: return r != start_room)
	if spawn_rooms.is_empty():
		spawn_rooms = [start_room]

	# Rare event (never on boss floors). Always a trader right after a boss.
	var event_text := ""
	var after_boss := depth > 1 and (depth - 1) % BOSS_EVERY == 0
	var ev_chance := EVENT_CHANCE * (1.5 if Profile.has("fortune") else 1.0)
	var gamblers := "gamblers" in mutators
	if not is_boss_floor() and (after_boss or gamblers or rng.randf() < ev_chance):
		var mids: Array = spawn_rooms.filter(func(r: Rect2i) -> bool: return r != far_room and r != plunge_room and r != lift_room)
		if not mids.is_empty():
			var ev_room: Rect2i = mids[rng.randi() % mids.size()]
			var ev := EventNode.new()
			ev.main = self
			ev.kind = "trader" if after_boss else ("slots" if gamblers else _weighted_pick(EVENT_WEIGHTS))
			ev.position = cell_center(ev_room.get_center())
			ev.add_child(Torch.make_light(80.0, Color(0.6, 0.9, 1.0), 0.8))
			level.add_child(ev)
			event_text = EventNode.INFO[ev.kind]["banner"]
			if ev.kind != "chest": # the chest room may be guarded; others are safe rooms
				spawn_rooms.erase(ev_room)

	var count := mini(int((6 + depth * 2) * rng.randf_range(0.85, 1.15)), 48)
	if floor_mod == "infested":
		count = mini(count * 2, 70)
	var boss: Enemy = null
	if is_boss_floor():
		stairs.locked = true
		boss = _make_enemy("boss")
		var bdef := BossGen.generate(depth, rng, unlocked_enemies())
		# Deep down (depth 50+), bosses may come Mutated: an extra attack, more health, and a
		# guaranteed legendary drop.
		if depth >= 50 and rng.randf() < clampf(0.25 + (depth - 50) * 0.01, 0.0, 0.75):
			var extra: Array = BossGen.ATTACKS.filter(func(a) -> bool: return not a in bdef["attacks"])
			if not extra.is_empty():
				bdef["attacks"].append(extra[rng.randi() % extra.size()])
			bdef["hp_mult"] = float(bdef["hp_mult"]) * 1.5
			bdef["title"] = "Mutated " + String(bdef["title"])
			bdef["color"] = (bdef["color"] as Color).lerp(Color(0.45, 1.0, 0.3), 0.45)
			boss.set_meta("mutated", true)
		boss.apply_boss(bdef)
		boss.position = cell_center(far_room.get_center()) + Vector2(0, -24)
		level.add_child(boss)
		hud.boss = boss
		count = int(count / 2.0)

	var elite_chance := minf(0.05 + depth * 0.004, 0.2) + 0.04 * heat
	if "elite_horde" in mutators:
		elite_chance = 0.5
	elite_chance = minf(elite_chance, 0.6)
	for i in count:
		var r: Rect2i = spawn_rooms[rng.randi() % spawn_rooms.size()]
		var cell := Vector2i(rng.randi_range(r.position.x + 1, r.end.x - 2), rng.randi_range(r.position.y + 1, r.end.y - 2))
		var e := _make_enemy(_pick_enemy_kind(biome), rng.randf() < elite_chance)
		e.position = cell_center(cell)
		level.add_child(e)

	var lines: Array[String] = ["Depth %d  -  %s" % [depth, biome["name"]]]
	# Long-term goals: best depth per heat, heat unlocks, depth bounties.
	if not is_daily and not is_weekly and Grind.on_depth(heat, depth, depth - run_start_depth + 1):
		lines.append("HEAT %d UNLOCKED - pick it on the class screen" % Grind.heat_max())
	_bounty("depth", depth)
	_bounty("heat_depth", depth)
	if boss:
		lines.append("%s awaits" % boss.title)
		sfx("boss")
	if floor_mod != "":
		lines.append(MODIFIERS[floor_mod])
	if event_text != "":
		lines.append(event_text)
	if plunge_room != Rect2i():
		lines.append("A cursed plunge opens somewhere below...")
	if is_instance_valid(elevator):
		lines.append("A Loot Lift waits on this floor" + (" (after the boss)" if elevator.locked else ""))
	show_banner("\n".join(lines), 2.8 + lines.size() * 0.7)
	audio.music("boss" if boss else "calm")
	_refresh_hud()
	save_run()


var _sort_origin := Vector2.ZERO


func _farther_room(a: Rect2i, b: Rect2i) -> bool:
	return Vector2(a.get_center()).distance_to(_sort_origin) > Vector2(b.get_center()).distance_to(_sort_origin)


func _place_torches(n: int) -> void:
	var placed := 0
	for i in 600:
		if placed >= n:
			break
		var x := rng.randi_range(1, dungeon.w - 2)
		var y := rng.randi_range(1, dungeon.h - 2)
		if not dungeon.is_floor(x, y) and dungeon.is_floor(x, y + 1) and dungeon.is_floor(x - 1, y + 1) and dungeon.is_floor(x + 1, y + 1):
			var t := Torch.new()
			t.position = cell_center(Vector2i(x, y)) + Vector2(0, 3)
			level.add_child(t)
			placed += 1


func _make_enemy(kind: String, elite := false) -> Enemy:
	var e := Enemy.new()
	e.setup(kind, depth, elite)
	e.main = self
	e.player = player
	e.killed.connect(_on_enemy_killed)
	if elite:
		var n := 2 if depth > 25 else 1
		e.set_affixes(_shuffle(Enemy.AFFIXES.duplicate()).slice(0, n))
	if floor_mod == "silent":
		e.aggro_range *= 0.55
	var hunted := player.curses.count("hunted") if is_instance_valid(player) else 0
	e.speed *= 1.0 + 0.1 * hunted
	# Heat: tougher foes. Frenzy mutator: faster foes.
	if heat > 0:
		e.max_hp *= 1.0 + 0.15 * heat
		e.hp = e.max_hp
		e.damage += int(heat / 3.0)
		e.speed *= 1.0 + 0.02 * heat
	if "frenzy" in mutators:
		e.speed *= 1.3
	return e


## Spawns a minion (summoned by cultists, bosses, splitting slimes). No gold.
func summon(kind: String, pos: Vector2) -> Enemy:
	var e := _make_enemy(kind)
	e.gold_value = 0
	e.aggro = true
	spawn(e, pos)
	return e


func _pick_enemy_kind(biome: Dictionary) -> String:
	var table: Dictionary = biome["roster"]
	return _weighted_pick(table) if not table.is_empty() else "slime"


func _weighted_pick(table: Dictionary) -> String:
	var total := 0
	for k in table:
		total += int(table[k])
	var roll := rng.randi() % total
	for k in table:
		roll -= int(table[k])
		if roll < 0:
			return k
	return table.keys()[0]


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * TILE + Vector2(TILE, TILE) * 0.5


# ---------------------------------------------------------------- spawning & effects

func spawn(node: Node2D, pos: Vector2) -> void:
	node.position = pos
	# Effects and bullets ignore the lighting so warnings are always visible.
	if node is Projectile or node is Blast or node is Puddle or node is DamageNumber or node is SlashFx or node is LightningFx or node is Puff:
		node.material = _unshaded
	level.add_child.call_deferred(node)
	node.reset_physics_interpolation.call_deferred() # start where spawned, not slide in from 0,0


func spawn_puff(pos: Vector2, color: Color, size: float) -> void:
	var p := Puff.new()
	p.color = color
	p.size = size
	spawn(p, pos)


func show_floating_text(pos: Vector2, text: String) -> void:
	var n := DamageNumber.new()
	n.text = text
	spawn(n, pos)


func spawn_number(pos: Vector2, value: int, crit: bool) -> void:
	var n := DamageNumber.new()
	n.text = str(value)
	n.crit = crit
	spawn(n, pos)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## At most one freeze every 0.35 s, so fast weapons with many crits don't stutter.
func hit_stop(duration: float) -> void:
	var now := Time.get_ticks_msec()
	if now < _hit_stop_ready:
		return
	_hit_stop_ready = now + 350
	Engine.time_scale = 0.1
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0


func show_banner(text: String, duration := 2.8) -> void:
	hud.show_banner(text, duration)


# ---------------------------------------------------------------- combat events

func _on_enemy_killed(e: Enemy) -> void:
	kills += 1
	var pos := e.global_position
	if is_instance_valid(player):
		player.on_kill(e)
	# Monster Codex and bounties.
	var tier := Grind.record_kill(e.kind)
	if tier > 0:
		var k := "slime" if e.kind == "slimelet" else e.kind
		show_banner("Codex: %s mastery %s!\n%s" % [Grind.KIND_NAMES[k], ["I", "II", "III"][tier - 1], Grind.tier_reward_text(k, tier)], 3.0)
		sfx("power", -6.0)
	_bounty("kill", 1, "slime" if e.kind == "slimelet" else e.kind)
	if e.elite:
		_bounty("elites")
	if e.is_boss:
		_bounty("bosses")
	if e.gold_value > 0:
		var g := e.gold_value * (2 if floor_mod == "infested" else 1)
		g = int(round(g * (1.0 + 0.2 * Profile.crafted_level("greed_sigil"))))
		_drop("gold", g, pos)
	var heart_chance := 0.06 + player.luck + (0.3 if e.elite else 0.0) + Materials.taper(Profile.crafted_level("lucky_charm"), 0.3)
	if e.gold_value > 0 and rng.randf() < heart_chance and not "bloodless" in mutators:
		_drop("heart", 1, pos)
	_drop_parts(e, pos)
	_drop_gear(e, pos)
	if e.is_boss:
		bosses_killed += 1
		for i in 4:
			_drop("heart", 1, pos)
		stairs.unlock()
		if is_instance_valid(elevator):
			elevator.unlock()
		shake(8.0)
		audio.music("calm")
		_devour(e)
	_refresh_hud()


## Boss-eating: the boss leaves one random power behind.
func _devour(boss: Enemy) -> void:
	var ab := Abilities.roll_from_boss(boss, player.actives, player.passives)
	if ab.is_empty():
		show_banner("%s falls. The way down opens..." % boss.title)
		return
	sfx("power")
	var kind_text := "ACTIVE" if ab["type"] == "active" else "PASSIVE"
	var list: Array = player.actives if ab["type"] == "active" else player.passives
	var cap := Abilities.MAX_ACTIVES if ab["type"] == "active" else Abilities.MAX_PASSIVES
	if list.size() < cap:
		player.add_power(ab)
		var key := ""
		if ab["type"] == "active":
			key = " (key %s)" % AbilityBar.KEYS[player.actives.size() - 1]
		show_banner("You devour %s!\n%s: %s%s\n%s" % [boss.title.get_slice(",", 0), kind_text, ab["name"], key, Abilities.describe(ab)], 5.0)
		return
	# Slots full: choose what to replace.
	_pending_power = ab
	_open_modal()
	var opts := []
	for i in list.size():
		opts.append({"id": "replace:%d" % i, "label": "Replace %s" % list[i]["name"]})
	opts.append({"id": "skip_power", "label": "Leave it"})
	hud.show_dialog("You devour %s!" % boss.title.get_slice(",", 0),
		"%s: %s - %s\nYour %s slots are full." % [kind_text, ab["name"], Abilities.describe(ab), kind_text.to_lower()], opts)


func _drop(kind: String, value: int, pos: Vector2, part := "") -> void:
	var p := Pickup.new()
	p.main = self
	p.kind = kind
	p.value = value
	p.part = part
	spawn(p, pos + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)))


## Monster parts: a chance for normal foes, 2 from elites, Boss Hearts + extras from bosses.
func _drop_parts(e: Enemy, pos: Vector2) -> void:
	var id: String = Materials.DROPS.get(e.kind, "")
	if id == "":
		return
	if e.is_boss:
		for i in 2:
			_drop("part", 1, pos, "heart")
		var roster: Array = floor_theme.get("roster", {}).keys()
		for i in 3:
			if not roster.is_empty():
				_drop("part", 1, pos, Materials.DROPS[roster[randi() % roster.size()]])
		return
	if e.elite:
		for i in 2:
			_drop("part", 1, pos, id)
		return
	var chance := Materials.SMALL_DROP_CHANCE if e.kind == "slimelet" else Materials.DROP_CHANCE
	chance *= (1.0 + 0.15 * Profile.crafted_level("scavenger")) * (1.0 + 0.15 * heat)
	if randf() < chance:
		_drop("part", 1, pos, id)


## Heart Forge (Workshop): a random boss power at the start of a run.
func _forged_power() -> Dictionary:
	if randf() < 0.5:
		var aid: String = Abilities.ACTIVES.keys()[randi() % Abilities.ACTIVES.size()]
		return {"type": "active", "id": aid, "name": "Forged " + String(Abilities.ACTIVES[aid]["name"]), "tier": 5}
	var pid: String = Abilities.PASSIVES.keys()[randi() % Abilities.PASSIVES.size()]
	return {"type": "passive", "id": pid, "name": "Forged " + String(Abilities.PASSIVES[pid]["name"]), "tier": 5}


## Gear: a small chance from normal foes, better from elites, always (and rare) from bosses.
func _drop_gear(e: Enemy, pos: Vector2) -> void:
	if e.kind == "slimelet" or not gear_drops:
		return
	var chance := Gear.ELITE_CHANCE if e.elite else Gear.DROP_CHANCE
	if not e.is_boss and randf() >= chance * player.gear_find:
		return
	var pool: Array = Classes.get_def(class_id)["weapons"].filter(_offerable_weapon)
	var legend_chance := Gear.LEGEND_BOSS if e.is_boss else (Gear.LEGEND_ELITE if e.elite else Gear.LEGEND_CHANCE)
	var legendary := e.has_meta("mutated") or randf() < legend_chance
	var item := Gear.roll(pool, e.is_boss or randf() < Gear.RARE_CHANCE, item_level(), legendary)
	_spawn_gear(item, pos)


## Item level of gear found right now: deeper floors and higher heat give stronger boons.
func item_level() -> int:
	return depth + heat * 3


func _spawn_gear(item: Dictionary, pos: Vector2) -> void:
	var p := Pickup.new()
	p.main = self
	p.kind = "gear"
	p.item = item
	spawn(p, pos)


## Walking over gear: wear it straight away if that slot is empty, otherwise compare.
func _pick_up_gear(item: Dictionary) -> void:
	if item.get("rare", false) and not item.get("counted", false):
		item["counted"] = true
		_bounty("rare_gear")
	var slot := String(item["slot"])
	if not player.equipment.has(slot) and slot != "weapon":
		player.equip(item)
		sfx("power", -4.0)
		show_banner("Equipped %s\n%s" % [item["name"], Gear.describe_boon(item)], 2.5)
		_refresh_hud()
		return
	_pending_gear = item
	_open_modal()
	var cur_text := ""
	if player.equipment.has(slot):
		cur_text = "Wearing: " + Gear.describe(player.equipment[slot])
	else:
		cur_text = "Holding: " + String(Weapons.get_def(player.weapon)["name"]) + " (no boon)"
	var salvage := _salvage_value(item)
	var rar := Gear.rarity(item)
	hud.show_dialog("Found " + (rar + " " if rar != "" else "") + String(item["name"]) + "  (lvl %d)" % int(item.get("ilvl", 1)),
		"%s\n%s" % [Gear.describe_boon(item), cur_text], [
		{"id": "gear_equip", "label": "Equip it"},
		{"id": "gear_salvage", "label": "Salvage for %d gold" % salvage},
	])


func _salvage_value(item: Dictionary) -> int:
	return (10 + int(item.get("ilvl", depth)) * 2) * (4 if item.get("legendary", false) else (2 if item.get("rare", false) else 1))


func collect(p: Pickup) -> bool:
	if p.kind == "gear":
		if modal or game_over:
			return false
		_pick_up_gear(p.item)
		return true
	if p.kind == "part":
		bag[p.part] = int(bag.get(p.part, 0)) + 1
		sfx("coin", -2.0)
		_refresh_hud()
		return true
	if p.kind == "heart":
		if player.hp >= player.max_hp:
			return false
		player.heal(p.value)
		sfx("heart")
	else:
		gold += int(round(p.value * player.gold_mult))
		sfx("coin", -4.0)
	_refresh_hud()
	return true


func _on_player_died() -> void:
	# Soul Anchor (Soul Altar unlock): one revive per run.
	if Profile.has("soul_anchor") and not revive_used:
		revive_used = true
		player.dead = false
		player.hp = maxi(1, int(player.max_hp / 2.0))
		player.invuln = 2.0
		show_banner("The Soul Anchor pulls you back!", 2.0)
		spawn_puff(player.global_position, Color(0.6, 0.8, 1.0), 20.0)
		sfx("power")
		_refresh_hud()
		return
	game_over = true
	shake(10.0)
	spawn_puff(player.global_position, Color(0.9, 0.3, 0.3), 14.0)
	var shards := _end_run()
	# Parts that were never extracted are lost.
	var lost := ""
	if not bag.is_empty():
		lost = "Lost (never sent up): " + Materials.describe(bag)
	bag = {}
	save_run() # alive = false, keeps best depth
	await get_tree().create_timer(1.0).timeout
	if game_over and playing:
		get_tree().paused = true
		hud.show_game_over(depth, gold, kills, best_depth, shards, false, lost)


# ---------------------------------------------------------------- extraction

func on_elevator() -> void:
	if modal or game_over or not playing:
		return
	_open_modal()
	if bag.is_empty():
		hud.show_dialog("Loot Lift", "The lift carries monster parts up to your Workshop.\nYour bag is empty - come back with loot.", [
			{"id": "leave", "label": "Keep descending"},
		])
		return
	hud.show_dialog("Loot Lift",
		"Send your monster parts up to the Workshop. They are safe there for crafting.\nYour bag: %s\nYou and your gold stay down here - the run goes on." % Materials.describe(bag), [
		{"id": "extract", "label": "Send up %d parts" % Materials.bag_total(bag)},
		{"id": "leave", "label": "Keep them for now"},
	])


## The lift takes only the loot: banks the bag in the Workshop; the run carries on.
func extract() -> void:
	var line := Materials.describe(bag)
	_bounty("send_parts", Materials.bag_total(bag))
	Profile.add_materials(bag)
	bag = {}
	_close_modal()
	sfx("power")
	if is_instance_valid(elevator):
		spawn_puff(elevator.global_position, Color(0.4, 1.0, 0.5), 14.0)
	show_banner("The lift rattles up with your loot:\n%s" % line, 3.0)
	_refresh_hud()
	save_run()


func toggle_pause() -> void:
	if not playing or game_over or modal:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	hud.set_paused(p)


func _refresh_hud() -> void:
	if is_instance_valid(player):
		hud.refresh(player.hp, player.max_hp, depth, floor_theme.get("name", ""), gold, kills, _mode_text(), Materials.bag_total(bag))


## Extra HUD text: floor modifier, heat level, weekly run.
func _mode_text() -> String:
	var parts: Array[String] = []
	if heat > 0:
		parts.append("Heat %d" % heat)
	if is_weekly:
		parts.append("Weekly")
	if floor_mod != "":
		parts.append(floor_mod.capitalize())
	return "  |  ".join(parts)


func _open_modal() -> void:
	modal = true
	get_tree().paused = true


func _close_modal() -> void:
	hud.hide_all()
	modal = false
	get_tree().paused = false


# ---------------------------------------------------------------- stairs & upgrades

func on_stairs_reached(plunge := false) -> void:
	if modal or game_over or not playing:
		return
	_open_modal()
	sfx("stairs")
	if plunge:
		_upgrade_context = "plunge"
		hud.show_upgrades(_roll_upgrades(4), "The abyss offers more... at a price (+2 depth, 1 curse)")
	else:
		_upgrade_context = "stairs"
		hud.show_upgrades(_roll_upgrades(3))


## Upgrade choices. Stairs and shrines never offer weapons any more - weapons come from gear
## drops (and the trader).
func _roll_upgrades(n: int, weapon_chance := 0.0) -> Array:
	var pool := UPGRADES.duplicate()
	var skip := []
	if player.max_charges >= MAX_CHARGES:
		skip.append("charge")
	if player.crit >= 0.6:
		skip.append("crit")
	if player.max_hp <= 3:
		skip.append("glass")
	if player.block >= 0.4:
		skip.append("iron_skin")
	if player.magnet >= 3.0:
		skip.append("magnet")
	pool = pool.filter(func(u: Dictionary) -> bool: return not u["id"] in skip)
	pool.shuffle()
	var picks := pool.slice(0, n)
	if randf() < weapon_chance:
		var w := _weapon_offer()
		if not w.is_empty():
			picks[randi() % picks.size()] = w
	return picks


## A weapon from this class's pool (unlocked at the Soul Altar) that the player isn't holding.
func _weapon_offer() -> Dictionary:
	var pool: Array = Classes.get_def(class_id)["weapons"].filter(_offerable_weapon)
	if pool.is_empty():
		return {}
	var wid: String = pool[randi() % pool.size()]
	var wd := Weapons.get_def(wid)
	return {"id": "weapon:" + wid, "name": "Take the " + String(wd["name"]), "desc": wd["desc"]}


func _offerable_weapon(k: String) -> bool:
	return k != player.weapon and Profile.weapon_unlocked(k)


func _on_upgrade_chosen(id: String) -> void:
	_apply_upgrade(id)
	if _upgrade_context == "stairs" or _upgrade_context == "plunge":
		if _upgrade_context == "plunge":
			var curse := _apply_curse()
			depth += 2
			_close_modal()
			_build_level()
			show_banner("Cursed: %s (%s)" % [CURSES[curse]["name"], CURSES[curse]["desc"]], 3.5)
		else:
			depth += 1
			player.heal(player.stair_heal)
			_close_modal()
			_build_level()
	else:
		_close_modal()


func _apply_curse() -> String:
	var id: String = CURSES.keys()[randi() % CURSES.size()]
	player.curses.append(id)
	match id:
		"frail":
			player.max_hp = maxi(2, player.max_hp - 1)
			player.hp = mini(player.hp, player.max_hp)
		"heavy":
			player.speed *= 0.92
		"dull":
			player.damage_mult *= 0.9
		"slow_hands":
			player.reload_mult *= 0.85
	_refresh_hud()
	return id


func _apply_upgrade(id: String) -> void:
	if id.begins_with("weapon:"):
		if player.equipment.has("weapon"): # a bought weapon replaces the dropped one and its boon
			Gear.apply(player, player.equipment["weapon"], -1)
			player.equipment.erase("weapon")
		player.weapon = id.trim_prefix("weapon:")
		player.charges = player.max_charges
		player.reload_t = 0.0
		_refresh_hud()
		return
	match id:
		"damage":
			player.damage_mult *= 1.2
		"reload":
			player.reload_mult *= 1.25
		"charge":
			player.max_charges = mini(player.max_charges + 1, MAX_CHARGES + (1 if player.has_passive("overcharge") else 0))
			player.charges = player.max_charges
		"speed":
			player.speed *= 1.12
		"vitality":
			player.max_hp += 2
			player.hp = player.max_hp
		"reach":
			player.range_mult *= 1.15
		"crit":
			player.crit += 0.08
		"dodge":
			player.dodge_cooldown *= 0.75
		"luck":
			player.luck += 0.07
		"glass":
			player.damage_mult *= 1.4
			player.max_hp = maxi(1, player.max_hp - 1)
			player.hp = mini(player.hp, player.max_hp)
		"iron_skin":
			player.block += 0.1
		"gold_rush":
			player.gold_mult += 0.3
		"leech":
			player.kill_heal += 0.06
		"brutal":
			player.crit_damage += 0.5
		"magnet":
			player.magnet += 1.0
		"titan":
			player.max_hp += 4
			player.hp += 4
			player.speed *= 0.94
		"frenzy":
			player.damage_mult *= 1.1
			player.speed *= 1.06
		"focus":
			player.cdr_mult *= 1.2
		"fortune":
			player.gear_find *= 1.6
		"rest":
			player.heal(3)
			player.stair_heal += 1
		"execute":
			player.execute += 0.6
		"quick_dodge":
			player.dodge_cooldown *= 0.85
			player.speed *= 1.05
	_refresh_hud()


# ---------------------------------------------------------------- floor events

func price(base: int) -> int:
	var p := float(base)
	if Profile.has("haggler"):
		p *= 0.8
	p *= pow(1.25, player.curses.count("greed"))
	return int(p)


func on_event(ev: EventNode) -> void:
	if modal or game_over or not playing:
		return
	_active_event = ev
	match ev.kind:
		"chest":
			ev.used = true
			var g := rng.randi_range(12, 25) + depth * 2
			gold += g
			var found := "+%d gold" % g
			if rng.randf() < 0.5:
				for i in 2:
					_drop("heart", 1, ev.global_position + Vector2(0, 14))
				found += ", hearts"
			if rng.randf() < 0.3:
				var u: Dictionary = _roll_upgrades(1, 0.0)[0]
				_apply_upgrade(u["id"])
				found += ", " + String(u["name"])
			spawn_puff(ev.global_position, Color(1.0, 0.85, 0.3), 14.0)
			sfx("coin")
			show_banner("Treasure!  " + found)
			_refresh_hud()
		"fountain":
			ev.used = true
			player.heal(player.max_hp)
			spawn_puff(player.global_position, Color(0.4, 0.7, 1.0), 14.0)
			sfx("heart")
			show_banner("The fountain restores you.")
		"shrine":
			_open_modal()
			var can := player.hp > 2
			hud.show_dialog("Blood Shrine", "Offer 2 health for a blessing of your choice.", [
				{"id": "offer", "label": "Offer 2 HP" if can else "Offer 2 HP (too weak)", "disabled": not can},
				{"id": "leave", "label": "Leave"},
			])
		"trader":
			_open_modal()
			if not ev.has_meta("stock"):
				ev.set_meta("stock", _make_stock())
			_show_shop(ev)
		"slots":
			_open_modal()
			_show_idol(ev, "Pull the lever and test your luck.\nThree of a kind pays big. Three skulls... do not.")


# ---------------------------------------------------------------- cursed idol (slot machine)

## Odds of each outcome (out of 100). Triples pay big, pairs pay a little, skulls hurt.
const SLOT_ODDS := [
	["triple", "skull", 7], ["triple", "coin", 6], ["triple", "heart", 5], ["triple", "sword", 5], ["triple", "gem", 4],
	["pair", "coin", 10], ["pair", "heart", 8], ["pair", "sword", 6], ["pair", "gem", 6], ["pair", "skull", 10],
	["none", "", 33],
]


func _idol_cost(ev: EventNode) -> int:
	return int(price(15 + depth * 3) * pow(1.5, int(ev.get_meta("pulls", 0))))


func _show_idol(ev: EventNode, text: String) -> void:
	var cost := _idol_cost(ev)
	hud.show_dialog("Cursed Idol", "%s\nYou have %d gold." % [text, gold], [
		{"id": "slot_pull", "label": "Pull the lever (%d gold)" % cost, "disabled": gold < cost},
		{"id": "leave", "label": "Walk away"},
	], true)


## Picks an outcome, then reels that show it: {"kind", "sym", "reels": [i, i, i]}.
func _slot_roll() -> Dictionary:
	var total := 0
	for o in SLOT_ODDS:
		total += int(o[2])
	var r := rng.randi() % total
	var pick: Array = SLOT_ODDS[-1]
	for o in SLOT_ODDS:
		r -= int(o[2])
		if r < 0:
			pick = o
			break
	var syms: Array = SlotReels.SYMBOLS
	var reels := []
	match String(pick[0]):
		"triple":
			var i := syms.find(pick[1])
			reels = [i, i, i]
		"pair":
			var i := syms.find(pick[1])
			var other := (i + 1 + rng.randi() % (syms.size() - 1)) % syms.size()
			reels = [i, i, other]
			reels.shuffle()
		_:
			var all := range(syms.size())
			all.shuffle()
			reels = all.slice(0, 3)
	return {"kind": pick[0], "sym": pick[1], "reels": reels}


func _slot_pull(ev: EventNode) -> void:
	var cost := _idol_cost(ev)
	if gold < cost:
		return
	gold -= cost
	ev.set_meta("pulls", int(ev.get_meta("pulls", 0)) + 1)
	_bounty("idol")
	_refresh_hud()
	sfx("coin")
	var res := _slot_roll()
	hud.show_dialog("Cursed Idol", "The reels spin...", [], true)
	hud.reels.spin(res["reels"], res["kind"] == "triple" and res["sym"] != "skull")
	if not hud.reels.reel_stopped.is_connected(_on_reel_stopped):
		hud.reels.reel_stopped.connect(_on_reel_stopped)
	hud.reels.stopped.connect(_slot_result.bind(ev, res, cost), CONNECT_ONE_SHOT)


func _on_reel_stopped(_i: int) -> void:
	sfx("click")


func _slot_result(ev: EventNode, res: Dictionary, cost: int) -> void:
	var kind := String(res["kind"])
	var sym := String(res["sym"])
	var text := "Nothing. The idol grins."
	var drop_at := ev.global_position + Vector2(0, 20)
	match kind + ":" + sym:
		"triple:coin":
			gold += cost * 6
			text = "JACKPOT! +%d gold" % (cost * 6)
		"triple:heart":
			player.max_hp += 1
			player.heal(player.max_hp)
			text = "Three hearts! +1 max HP and fully healed."
		"triple:sword":
			_spawn_gear(Gear.roll(Classes.get_def(class_id)["weapons"].filter(_offerable_weapon), true, item_level(), rng.randf() < 0.2), drop_at)
			text = "Three swords! A rare piece of gear clatters out."
		"triple:gem":
			var names := []
			for u in _roll_upgrades(2):
				_apply_upgrade(u["id"])
				names.append(u["name"])
			text = "Three gems! Blessed with %s." % " and ".join(names)
		"triple:skull":
			if rng.randf() < 0.5:
				var curse := _apply_curse()
				text = "Three skulls. Cursed: %s (%s)" % [CURSES[curse]["name"], CURSES[curse]["desc"]]
			else:
				# Ambush: the idol spits out monsters and the machine shuts.
				_slot_ambush(ev)
				return
		"pair:coin":
			gold += cost * 2
			text = "Two coins: +%d gold" % (cost * 2)
		"pair:heart":
			player.heal(2)
			text = "Two hearts: healed 2."
		"pair:sword":
			_spawn_gear(Gear.roll(Classes.get_def(class_id)["weapons"].filter(_offerable_weapon), false, item_level()), drop_at)
			text = "Two swords: a piece of gear drops out."
		"pair:gem":
			var u: Dictionary = _roll_upgrades(1)[0]
			_apply_upgrade(u["id"])
			text = "Two gems: %s (%s)" % [u["name"], u["desc"]]
		"pair:skull":
			if player.hp > 1:
				player.hp -= 1
				player.stats_changed.emit()
				text = "Two skulls. The idol bites you (-1 HP)."
			else:
				text = "Two skulls. The idol sniffs... and spares you."
	if kind == "triple" and sym != "skull":
		sfx("power")
		shake(4.0)
		spawn_puff(ev.global_position, Color(1.0, 0.85, 0.3), 16.0)
	elif kind == "pair" and sym != "skull":
		sfx("coin")
	else:
		sfx("hurt" if sym == "skull" else "click", -6.0)
	_refresh_hud()
	_show_idol(ev, text)


func _slot_ambush(ev: EventNode) -> void:
	_close_modal()
	ev.used = true
	var roster: Array = floor_theme.get("roster", {}).keys()
	if roster.is_empty():
		roster = ["slime"]
	var n := 3 + mini(depth / 10, 3)
	for i in n:
		var a := TAU * i / n
		summon(roster[rng.randi() % roster.size()], ev.global_position + Vector2.RIGHT.rotated(a) * 34.0)
	spawn_puff(ev.global_position, Color(0.6, 0.2, 0.8), 20.0)
	shake(8.0)
	sfx("hurt")
	show_banner("Three skulls! The idol cackles and spits out monsters!", 2.5)


func _make_stock() -> Array:
	var stock := [
		{"label": "Healing Potion (+3 HP)", "price": price(12 + depth * 2), "kind": "heal", "value": 3},
	]
	for u in _roll_upgrades(2, 0.0):
		stock.append({"label": "%s (%s)" % [u["name"], u["desc"]], "price": price(30 + depth * 6), "kind": "upgrade", "value": u["id"]})
	var w := _weapon_offer()
	if not w.is_empty():
		stock.append({"label": "%s (%s)" % [w["name"].trim_prefix("Take the "), w["desc"]], "price": price(45 + depth * 6), "kind": "upgrade", "value": w["id"]})
	return stock


func _show_shop(ev: EventNode) -> void:
	var opts := []
	var stock: Array = ev.get_meta("stock")
	for i in stock.size():
		var item: Dictionary = stock[i]
		if item.get("sold", false):
			opts.append({"id": "none", "label": "%s - sold" % item["label"], "disabled": true})
		else:
			var cost := int(item["price"])
			opts.append({"id": "buy:%d" % i, "label": "%s - %d gold" % [item["label"], cost], "disabled": gold < cost})
	opts.append({"id": "leave", "label": "Leave"})
	hud.show_dialog("Wandering Trader", "\"Gold for power, friend.\"   You have %d gold." % gold, opts)


func _on_dialog_chosen(id: String) -> void:
	# Boss power replacement.
	if id.begins_with("replace:") or id == "skip_power":
		if id != "skip_power" and not _pending_power.is_empty():
			var old_index := int(id.trim_prefix("replace:"))
			player.add_power(_pending_power, old_index)
			show_banner("You now wield %s" % _pending_power["name"], 3.0)
		_pending_power = {}
		_close_modal()
		return
	if id == "slot_pull":
		if is_instance_valid(_active_event):
			_slot_pull(_active_event)
		return
	if id == "gear_equip" or id == "gear_salvage":
		if id == "gear_equip":
			player.equip(_pending_gear)
			show_banner("Equipped %s" % _pending_gear["name"], 2.0)
		else:
			gold += _salvage_value(_pending_gear)
			sfx("coin")
		_pending_gear = {}
		_close_modal()
		_refresh_hud()
		return
	if id == "extract":
		extract()
		return
	var ev := _active_event
	if id == "leave" or not is_instance_valid(ev):
		_close_modal()
		return
	if id == "offer":
		player.hp -= 2
		ev.used = true
		_refresh_hud()
		_upgrade_context = "shrine"
		hud.show_upgrades(_roll_upgrades(3), "The shrine accepts your offering")
	elif id.begins_with("buy:"):
		var stock: Array = ev.get_meta("stock")
		var item: Dictionary = stock[int(id.trim_prefix("buy:"))]
		var cost := int(item["price"])
		if gold >= cost and not item.get("sold", false):
			gold -= cost
			item["sold"] = true
			sfx("coin")
			if item["kind"] == "heal":
				player.heal(int(item["value"]))
			else:
				_apply_upgrade(item["value"])
			_refresh_hud()
		_show_shop(ev)


# ---------------------------------------------------------------- input map

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("move_up", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("move_down", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	# Attack key / button = tap attack with auto-aim. (Mouse: hold left to aim, release to strike.)
	_add_action("attack", [KEY_SPACE, KEY_J], [JOY_BUTTON_X, JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("dodge", [KEY_SHIFT, KEY_L], [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER])
	# Devoured boss powers.
	_add_action("ability_1", [KEY_Q], [JOY_BUTTON_Y])
	_add_action("ability_2", [KEY_E], [JOY_BUTTON_B])
	_add_action("ability_3", [KEY_R], [], JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_action("ability_4", [KEY_F], [], JOY_AXIS_TRIGGER_RIGHT, 1.0)
	# Right stick: push to aim, let go to strike.
	_add_action("aim_left", [], [], JOY_AXIS_RIGHT_X, -1.0)
	_add_action("aim_right", [], [], JOY_AXIS_RIGHT_X, 1.0)
	_add_action("aim_up", [], [], JOY_AXIS_RIGHT_Y, -1.0)
	_add_action("aim_down", [], [], JOY_AXIS_RIGHT_Y, 1.0)
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START])
	_add_action("restart", [KEY_R, KEY_ENTER], [])


func _add_action(action: String, keys: Array, buttons: Array, axis := -1, axis_value := 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	if axis >= 0:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axis
		ev.axis_value = axis_value
		InputMap.action_add_event(action, ev)
