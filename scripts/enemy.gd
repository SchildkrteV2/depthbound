class_name Enemy
extends CharacterBody2D
## All enemy types in one script, chosen by `kind`. Stats scale with depth.
## Elites are tougher, bigger versions with a gold ring that drop more gold.

signal killed(enemy: Enemy)

const TYPES := {
	# --- regular ---
	"slime": {"hp": 30, "speed": 34.0, "damage": 1, "radius": 6.0, "color": Color(0.42, 0.85, 0.42), "aggro": 130.0, "gold": 1},
	"slimelet": {"hp": 10, "speed": 46.0, "damage": 1, "radius": 4.0, "color": Color(0.55, 0.92, 0.5), "aggro": 200.0, "gold": 0},
	"bat": {"hp": 20, "speed": 66.0, "damage": 1, "radius": 5.0, "color": Color(0.68, 0.45, 0.9), "aggro": 160.0, "gold": 1},
	"spider": {"hp": 26, "speed": 52.0, "damage": 1, "radius": 5.5, "color": Color(0.38, 0.28, 0.24), "aggro": 150.0, "gold": 1},
	"skeleton": {"hp": 45, "speed": 40.0, "damage": 1, "radius": 6.0, "color": Color(0.9, 0.9, 0.82), "aggro": 180.0, "gold": 2},
	"bomber": {"hp": 18, "speed": 64.0, "damage": 2, "radius": 5.0, "color": Color(0.95, 0.35, 0.2), "aggro": 160.0, "gold": 1},
	"ghost": {"hp": 38, "speed": 32.0, "damage": 1, "radius": 6.0, "color": Color(0.75, 0.88, 1.0), "aggro": 140.0, "gold": 2},
	"wisp": {"hp": 24, "speed": 46.0, "damage": 1, "radius": 5.0, "color": Color(0.45, 0.95, 0.95), "aggro": 190.0, "gold": 2},
	"cultist": {"hp": 42, "speed": 36.0, "damage": 1, "radius": 6.0, "color": Color(0.55, 0.2, 0.6), "aggro": 190.0, "gold": 3},
	"brute": {"hp": 110, "speed": 30.0, "damage": 2, "radius": 9.0, "color": Color(0.85, 0.45, 0.3), "aggro": 140.0, "gold": 4},
	"golem": {"hp": 170, "speed": 22.0, "damage": 2, "radius": 10.0, "color": Color(0.5, 0.47, 0.42), "aggro": 180.0, "gold": 5},
	# --- boss (every 10th floor; looks and attacks come from BossGen) ---
	"boss": {"hp": 620, "speed": 26.0, "damage": 2, "radius": 14.0, "color": Color(0.85, 0.2, 0.32), "aggro": 230.0, "gold": 30, "boss": true},
}
## Seconds between uses of each boss attack (shorter when the boss is below half health).
const BOSS_ATTACK_CD := {"radial": 2.3, "spiral": 3.2, "fan": 1.9, "mines": 4.0, "slam": 4.5, "charge": 4.0, "summon": 7.0, "teleport": 7.5}

var main: Node
var player: Player

var kind := "slime"
var max_hp := 30.0
var hp := 30.0
var speed := 30.0
var damage := 1
var radius := 6.0
var color := Color.WHITE
var aggro_range := 140.0
var gold_value := 1
var is_boss := false
var elite := false
var stun := 0.0

var aggro := false
var dying := false
var path: Array[Vector2] = []
var path_timer := 0.0
var shoot_timer := 1.0
var dash_timer := 2.0
var dash_time := 0.0
var windup := 0.0
var dash_dir := Vector2.ZERO
var knockback := Vector2.ZERO
var flash := 0.0
var t := 0.0
var strafe_sign := 1.0
var burst_angle := 0.0
var burst_left := 0
var burst_timer := 0.0
var summon_timer := 4.0
var special_timer := 5.0
var fuse := -1.0
var summons: Array = []
var depth_level := 1
var _face_left := false

# Elite affixes: shielded, splitting, vampiric, swift, explosive, toxic.
const AFFIXES := ["shielded", "splitting", "vampiric", "swift", "explosive", "toxic"]
const AFFIX_COLORS := {
	"shielded": Color(0.45, 0.75, 1.0), "splitting": Color(0.5, 1.0, 0.5), "vampiric": Color(0.95, 0.15, 0.25),
	"swift": Color(1.0, 1.0, 0.5), "explosive": Color(1.0, 0.5, 0.15), "toxic": Color(0.6, 0.95, 0.2),
}
var affixes: Array = []
var shield := 0.0
var shield_max := 0.0
var _since_hit := 0.0
var _toxic_t := 1.0

# Generated boss data (see BossGen).
var title := ""
var boss_def: Dictionary = {}
var _attack_timers := {}


func setup(kind_name: String, depth: int, is_elite := false) -> void:
	kind = kind_name
	depth_level = depth
	var d: Dictionary = TYPES[kind]
	is_boss = d.get("boss", false)
	var per_floor := 0.12 if is_boss else 0.2
	var hp_scale := 1.0 + per_floor * (depth - 1)
	max_hp = ceilf(float(d["hp"]) * hp_scale)
	speed = float(d["speed"]) * minf(1.0 + 0.02 * (depth - 1), 1.5) * 1.15 # faster pace
	damage = int(d["damage"]) + int((depth - 1) / 8.0)
	radius = d["radius"]
	color = d["color"]
	aggro_range = d["aggro"]
	gold_value = int(d["gold"]) + int(depth / 4.0) if int(d["gold"]) > 0 else 0
	elite = is_elite and not is_boss
	if elite:
		max_hp *= 2.5
		radius *= 1.25
		speed *= 1.1
		gold_value *= 3
	hp = max_hp


func set_affixes(list: Array) -> void:
	affixes = list
	if "swift" in affixes:
		speed *= 1.4
	if "shielded" in affixes:
		shield_max = max_hp * 0.3
		shield = shield_max


func _tick_affixes(delta: float) -> void:
	if affixes.is_empty():
		return
	_since_hit += delta
	if shield_max > 0.0 and _since_hit > 4.0 and shield < shield_max:
		shield = minf(shield_max, shield + shield_max * delta * 0.5)
	if "toxic" in affixes and aggro:
		_toxic_t -= delta
		if _toxic_t <= 0.0:
			_toxic_t = 1.0
			var pd := Puddle.new()
			main.spawn(pd, global_position)


## Turns a "boss" enemy into a generated one. Call after setup(), before adding to the tree.
func apply_boss(def: Dictionary) -> void:
	boss_def = def
	title = def["title"]
	max_hp = ceilf(max_hp * float(def["hp_mult"]))
	hp = max_hp
	speed = float(def["speed"]) * minf(1.0 + 0.02 * (depth_level - 1), 1.5)
	radius = def["radius"]
	color = def["color"]
	for a in def["attacks"]:
		_attack_timers[a] = randf_range(1.0, 2.5)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 4 if kind == "ghost" else (1 | 4) # ghosts drift through walls
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CircleShape2D.new()
	shape.radius = radius
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	add_to_group("enemies")
	t = randf() * 10.0
	shoot_timer = randf_range(0.8, 2.0)
	dash_timer = randf_range(0.5, 2.0)
	strafe_sign = 1.0 if randf() < 0.5 else -1.0


func _physics_process(delta: float) -> void:
	t += delta
	flash = maxf(flash - delta, 0.0)
	var move := Vector2.ZERO
	var far := false
	if is_instance_valid(player) and not player.dead:
		var to_p := player.global_position - global_position
		var dist := to_p.length()
		far = dist > 450.0
		# Sleeping enemies far from the player cost almost nothing.
		if not aggro and dist > aggro_range + 40.0 and knockback == Vector2.ZERO:
			return
		# Lose interest when the player gets far away (keeps far-off path-finding cheap).
		if aggro and not is_boss and dist > 520.0:
			aggro = false
			path.clear()
		if not aggro and dist < aggro_range and (kind == "ghost" or _can_see(player.global_position)):
			aggro = true
		if stun > 0.0:
			stun -= delta
		elif aggro:
			move = _think(delta, to_p, dist) * _move_mult(dist)
		if kind != "bomber" and dist < radius + Player.RADIUS + 1.0:
			_hit_player(damage, to_p.normalized())
		_tick_affixes(delta)
	velocity = move + knockback
	knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	move_and_slide()
	if not far:
		queue_redraw()


# ------------------------------------------------------------------ behaviour

func _think(delta: float, to_p: Vector2, dist: float) -> Vector2:
	var dir := to_p / maxf(dist, 0.001)
	var side := Vector2(-dir.y, dir.x)
	match kind:
		"bat":
			return (_chase_dir(delta, dist) + side * sin(t * 7.0) * 0.9).normalized() * speed
		"spider":
			return _dash_behaviour(delta, dir, dist, 70.0, 0.25, 0.22, 3.8, Vector2(1.4, 2.4))
		"brute":
			return _dash_behaviour(delta, dir, dist, 110.0, 0.45, 0.35, 4.5, Vector2(2.5, 3.5))
		"skeleton":
			if _shot_ready(delta, dist, 190.0, Vector2(1.4, 2.2)):
				_shoot(dir, 110.0)
			return _keep_distance(delta, dir, dist, 70.0, 120.0)
		"wisp":
			if burst_left > 0:
				burst_timer -= delta
				if burst_timer <= 0.0:
					burst_left -= 1
					burst_timer = 0.12
					_shoot(dir, 130.0, Color(0.45, 0.95, 0.95))
			if _shot_ready(delta, dist, 200.0, Vector2(2.2, 2.8)):
				burst_left = 3
			return _keep_distance(delta, dir, dist, 90.0, 130.0) + side * sin(t * 2.0) * speed * 0.4
		"cultist":
			summon_timer -= delta
			if summon_timer <= 0.0 and _can_see(player.global_position):
				summon_timer = 6.0
				_summon("bat", 2, 4)
			if _shot_ready(delta, dist, 200.0, Vector2(2.2, 3.0)):
				_shoot(dir, 75.0, Color(0.8, 0.3, 0.9))
			return _keep_distance(delta, dir, dist, 100.0, 150.0)
		"bomber":
			if fuse >= 0.0:
				fuse -= delta
				if fuse < 0.0:
					_explode()
				return Vector2.ZERO
			if dist < 22.0:
				_light_fuse()
				return Vector2.ZERO
			return _chase_dir(delta, dist) * speed
		"ghost":
			return dir * speed * (0.6 + 0.4 * sin(t * 1.5) ** 2)
		"golem":
			if _shot_ready(delta, dist, 200.0, Vector2(2.6, 3.2)):
				for i in 5:
					_shoot(dir.rotated((i - 2) * 0.25), 70.0, Color(0.7, 0.6, 0.45))
			return _chase_dir(delta, dist) * speed
		"boss":
			return _boss_think(delta, dir, dist)
		_:
			return _chase_dir(delta, dist) * speed


## Slow-downs: the player's Aura of Dread and flooded floors (flyers ignore water).
func _move_mult(dist: float) -> float:
	var m := 1.0
	if dist < 60.0 and player.has_passive("dread"):
		m *= 0.7
	if main.floor_mod == "flooded" and not kind in ["bat", "ghost", "wisp"]:
		m *= 0.8
	return m


func _hit_player(amount: int, dir: Vector2) -> void:
	var before := player.hp
	player.take_damage(amount, dir)
	if player.hp < before and "vampiric" in affixes:
		hp = minf(max_hp, hp + max_hp * 0.2)
		main.spawn_puff(global_position, Color(0.9, 0.1, 0.2), radius * 2.0)


## Ticks the shot timer; true when it's time to fire (in range + line of sight).
func _shot_ready(delta: float, dist: float, max_range: float, cd: Vector2) -> bool:
	shoot_timer -= delta
	if shoot_timer <= 0.0 and dist < max_range and _can_see(player.global_position):
		shoot_timer = randf_range(cd.x, cd.y)
		return true
	return false


func _keep_distance(delta: float, dir: Vector2, dist: float, near: float, far: float) -> Vector2:
	if dist > far:
		return _chase_dir(delta, dist) * speed
	if dist < near:
		return -dir * speed
	return Vector2(-dir.y, dir.x) * strafe_sign * speed * 0.5


## Wind up (flash red, stand still), then lunge in a straight line.
func _dash_behaviour(delta: float, dir: Vector2, dist: float, trigger: float, wind: float, dur: float, mult: float, cd: Vector2) -> Vector2:
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			dash_time = dur
		return Vector2.ZERO
	if dash_time > 0.0:
		dash_time -= delta
		return dash_dir * speed * mult
	dash_timer -= delta
	if dash_timer <= 0.0 and dist < trigger and _can_see(player.global_position):
		dash_timer = randf_range(cd.x, cd.y)
		windup = wind
		dash_dir = dir
		return Vector2.ZERO
	return _chase_dir(delta, dist) * speed


## Generated boss: runs each of its attack patterns on its own timer.
func _boss_think(delta: float, dir: Vector2, dist: float) -> Vector2:
	var enraged := hp * 2.0 < max_hp
	var cd_mult := 0.7 if enraged else 1.0
	var bullet := Color(boss_def.get("glow", Color(1, 0.5, 0.3)))
	var minion := String(boss_def.get("minion", "slime"))

	# Ongoing spiral stream.
	if burst_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_timer = 0.08
			burst_left -= 1
			burst_angle += 0.42
			_shoot(Vector2.RIGHT.rotated(burst_angle), 85.0, bullet)
			_shoot(Vector2.RIGHT.rotated(burst_angle + PI), 85.0, bullet)

	# Ongoing charge.
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			dash_time = 0.45
		return Vector2.ZERO
	if dash_time > 0.0:
		dash_time -= delta
		return dash_dir * speed * 4.0

	for a in _attack_timers.keys():
		_attack_timers[a] -= delta
		if _attack_timers[a] > 0.0:
			continue
		var used := true
		match String(a):
			"radial":
				var n := 14 if enraged else 10
				burst_angle += 0.3
				for i in n:
					_shoot(Vector2.RIGHT.rotated(burst_angle + TAU * i / n), 90.0 if enraged else 78.0, bullet)
			"spiral":
				burst_left = 30 if enraged else 20
			"fan":
				used = _can_see(player.global_position)
				if used:
					for i in 5:
						_shoot(dir.rotated((i - 2) * 0.22), 95.0, bullet)
			"mines":
				for i in 3:
					var off := Vector2.RIGHT.rotated(randf() * TAU) * (randf() * 34.0) if i > 0 else Vector2.ZERO
					_enemy_blast(player.global_position + off, 26.0, 1.0, damage)
			"slam":
				used = dist < 80.0
				if used:
					_enemy_blast(global_position, radius + 36.0, 0.8, damage)
					stun = 0.8 # stands still while slamming
			"charge":
				used = dist < 170.0 and _can_see(player.global_position)
				if used:
					windup = 0.5
					dash_dir = dir
			"summon":
				_summon(minion, 2 + int(depth_level / 20.0), 6)
			"teleport":
				_teleport_near_player()
		var base: float = BOSS_ATTACK_CD.get(a, 3.0)
		_attack_timers[a] = base * cd_mult * randf_range(0.9, 1.15) if used else 0.5

	# Bosses that teleport keep their distance; the rest come at you.
	if _attack_timers.has("teleport"):
		return _keep_distance(delta, dir, dist, 60.0, 110.0)
	return _chase_dir(delta, dist) * speed


func _chase_dir(delta: float, dist: float) -> Vector2:
	var direct := (player.global_position - global_position).normalized()
	if dist < 36.0:
		return direct
	path_timer -= delta
	if path_timer <= 0.0:
		# Re-plan often when close, rarely when far (A* on big floors isn't free).
		path_timer = randf_range(0.25, 0.45) * (1.0 + dist / 150.0)
		path = main.dungeon.find_path(global_position, player.global_position)
	while path.size() > 0 and global_position.distance_to(path[0]) < 5.0:
		path.remove_at(0)
	if path.is_empty():
		return direct
	return (path[0] - global_position).normalized()


func _can_see(target: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ actions

func _shoot(dir: Vector2, spd: float, col := Color(0, 0, 0, 0)) -> void:
	var p := Projectile.new()
	p.setup(dir * spd, damage, false, 3.0, 0)
	p.color_override = col
	p.origin = global_position
	main.spawn(p, global_position + dir * (radius + 2.0))
	main.sfx("shoot", -12.0)


func _enemy_blast(pos: Vector2, rad: float, delay: float, dmg: int) -> void:
	var b := Blast.new()
	b.from_player = false
	b.radius = rad
	b.delay = delay
	b.damage = dmg
	b.color = Color(1.0, 0.3, 0.2)
	main.spawn(b, pos)


func _summon(what: String, count: int, cap: int) -> void:
	summons = summons.filter(func(s) -> bool: return is_instance_valid(s) and not s.dying)
	for i in count:
		if summons.size() >= cap:
			return
		var pos := global_position + Vector2.RIGHT.rotated(randf() * TAU) * (radius + 8.0)
		var e: Enemy = main.summon(what, pos)
		summons.append(e)
	main.spawn_puff(global_position, Color(0.7, 0.3, 0.9), radius * 2.0)


func _light_fuse() -> void:
	fuse = 0.6
	_enemy_blast(global_position, 30.0, 0.6, damage)


func _explode() -> void:
	if dying:
		return
	dying = true
	killed.emit(self)
	queue_free()


func _teleport_near_player() -> void:
	for i in 25:
		var p := player.global_position + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(70.0, 110.0)
		var c: Vector2i = main.dungeon.world_to_cell(p)
		var ok := true
		for o in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not main.dungeon.is_floor(c.x + o.x, c.y + o.y):
				ok = false
		if ok:
			main.spawn_puff(global_position, color, radius * 2.0)
			global_position = p
			reset_physics_interpolation()
			main.spawn_puff(global_position, color, radius * 2.0)
			path.clear()
			return


func take_damage(amount: float, dir: Vector2 = Vector2.ZERO, crit := false) -> void:
	if dying:
		return
	amount = maxf(1.0, roundf(amount))
	_since_hit = 0.0
	if shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		if amount <= 0.0:
			flash = 0.08
			main.spawn_puff(global_position, AFFIX_COLORS["shielded"], radius * 1.5)
			return
	hp -= amount
	flash = 0.12
	aggro = true
	knockback = dir * (20.0 if is_boss or elite else 110.0)
	windup = 0.0 # getting hit interrupts a charge wind-up
	main.spawn_number(global_position + Vector2(0, -radius), int(amount), crit)
	main.spawn_puff(global_position, Color(1, 1, 1), radius * (1.4 if crit else 1.0))
	if hp <= 0:
		dying = true
		killed.emit(self)
		main.spawn_puff(global_position, color, radius * 2.0)
		if kind == "slime":
			for i in 2:
				main.summon("slimelet", global_position + Vector2(randf_range(-5, 5), randf_range(-5, 5)))
		if "splitting" in affixes:
			for i in 2:
				main.summon(kind, global_position + Vector2(randf_range(-8, 8), randf_range(-8, 8)))
		if "explosive" in affixes:
			_enemy_blast(global_position, 34.0, 0.5, damage)
		main.sfx("kill")
		queue_free()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var jitter := Vector2.ZERO
	var mod := Color.WHITE
	if windup > 0.0 or fuse >= 0.0:
		mod = Color(1.0, 0.4, 0.4) if int(t * 16.0) % 2 == 0 else Color(1.0, 0.75, 0.75)
		jitter = Vector2(randf_range(-1, 1), 0)
	if kind == "ghost":
		mod.a = 0.55 + 0.25 * sin(t * 3.0)
	if is_boss and hp * 2.0 < max_hp:
		mod = mod.lerp(Color(1.0, 0.45, 0.4), 0.25 + 0.25 * sin(t * 8.0))
	# Shadow.
	draw_set_transform(Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.35 if kind != "ghost" else 0.15))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if elite:
		# One coloured ring per affix, plus the affix names above.
		for i in affixes.size():
			var ac: Color = AFFIX_COLORS[affixes[i]]
			draw_arc(Vector2(0, radius * 0.6), radius + 3.0 + i * 2.0, t * 2.0 + i, t * 2.0 + i + PI * 1.2, 12, ac, 1.2)
		if shield > 0.0:
			draw_circle(Vector2(0, -radius * 0.3), radius + 4.0, Color(0.45, 0.75, 1.0, 0.18 + 0.25 * shield / shield_max))
		if not affixes.is_empty():
			var label := " ".join(affixes.map(func(a: String) -> String: return a.capitalize()))
			draw_string(ThemeDB.fallback_font, Vector2(-50, -radius * 2.0 - 10.0), label, HORIZONTAL_ALIGNMENT_CENTER, 100, 6, Color(1, 0.85, 0.4, 0.9))
	if kind == "wisp":
		draw_circle(Vector2(0, -4), radius * 1.9, Color(color, 0.15))

	# Sprite. Flying things hover; everything faces the way it moves.
	if absf(velocity.x) > 3.0:
		_face_left = velocity.x < 0.0
	elif is_instance_valid(player) and aggro:
		_face_left = player.global_position.x < global_position.x
	var moving := velocity.length() > 4.0
	var variant := "white" if flash > 0.0 else ("elite" if elite else "")
	var tex: Texture2D
	if is_boss:
		tex = Sprites.boss(boss_def, int(t * 2.0), variant)
	else:
		tex = Sprites.enemy(kind, t, moving, variant)
	var feet := Vector2(0, radius + 1.0) + jitter
	match kind:
		"bat", "wisp":
			feet.y -= 4.0 + round(sin(t * 4.0) * 1.5)
		"ghost":
			feet.y -= 2.0 + round(sin(t * 2.5) * 1.5)
		"boss":
			feet.y = tex.get_height() * Sprites.PX * 0.5 + radius * 0.2
	Sprites.draw_at(self, tex, feet, _face_left, mod)

	# Extras on top of the sprite.
	match kind:
		"skeleton": # aims its bow at you
			if is_instance_valid(player) and aggro:
				var to := (player.global_position - global_position).normalized()
				Sprites.draw_rotated(self, Sprites.weapon("bow"), Vector2(0, -5) + to * 5.0, to, Sprites.weapon_grip("bow"), mod)
		"bomber": # lit bomb held up
			var bomb := Sprites.item("bomb")
			var bp := Vector2(3 if not _face_left else -10, -15) + jitter
			Sprites.draw_centered(self, bomb, bp + Vector2(2.5, 2.5), mod)
			if int(t * 12.0) % 2 == 0:
				draw_rect(Rect2(bp + Vector2(3, -1), Vector2(1, 1)), Color(1, 0.9, 0.3))
		"cultist":
			if summon_timer < 1.0:
				draw_arc(Vector2(0, -4), radius + 5.0, 0.0, TAU, 20, Color(0.8, 0.3, 0.9, 1.0 - summon_timer), 1.5)
		"boss":
			if windup > 0.0:
				draw_line(Vector2.ZERO, dash_dir * 60.0, Color(1, 0.2, 0.2, 0.6), 2.0)
	# Health bar (bosses use the big bar in the HUD).
	if hp < max_hp and not is_boss:
		var bw := roundf(radius * 2.6)
		var top := roundf(-radius * 2.0 - 6.0)
		draw_rect(Rect2(-bw / 2.0, top, bw, 2), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-bw / 2.0, top, bw * hp / max_hp, 2), Color(1.0, 0.75, 0.2) if elite else Color(0.9, 0.25, 0.25))
	_draw_stun()


func _draw_stun() -> void:
	if stun > 0.0:
		for i in 3:
			var p := Vector2.RIGHT.rotated(t * 6.0 + TAU * i / 3.0) * Vector2(radius, radius * 0.4) + Vector2(0, -radius * 2.0 - 2.0)
			draw_rect(Rect2(p.round(), Vector2(2, 2)), Color(1.0, 0.95, 0.4))
