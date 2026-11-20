class_name Player
extends CharacterBody2D
## Player controller, modelled on Noctis-style action combat:
## - Instant, analog movement (no acceleration). You face where you move, or where you aim.
## - Dodge: a quick dash with i-frames (Space / Shift / right mouse / dodge button).
## - Weapons run on CHARGES: each attack uses one, and they refill one at a time.
## - Attacking: tap = auto-aim at the nearest enemy; hold/drag = show an aim preview,
##   release = strike in that direction. Mouse: hold left to aim, release to strike.
## - Slashes alternate direction (combo), hits vary +-12%, and crits cause hit-stop.

signal died
signal stats_changed

const RADIUS := 6.0
const AIM_DEADZONE := 0.28
const DODGE_DISTANCE := 72.0
const DODGE_DURATION := 0.17
## After the dash you stay see-through and untouchable for this much longer.
const DODGE_GRACE := 0.12
## Overall pace: movement, reloads and cooldowns are this much faster than the class base.
const PACE := 1.2
const HURT_INVULN := 0.6
const AUTO_AIM_EXTRA := 30.0

var main: Node

# Stats (class + upgrades change these).
var class_id := "fighter"
var max_hp := 6
var hp := 6
var speed := 80.0
var weapon := "sword"
var damage_mult := 1.0
var range_mult := 1.0
var reload_mult := 1.0
var crit := 0.05
var crit_damage := 1.8
var max_charges := 3
var charges := 3
var dodge_cooldown := 2.5
var luck := 0.0
# From stair upgrades and gear (see Gear / main.UPGRADES).
var cdr_mult := 1.0 # power cooldowns are divided by this
var gold_mult := 1.0
var block := 0.0 # chance to ignore a hit
var kill_heal := 0.0 # chance to heal 1 on a kill
var magnet := 1.0 # pickup pull range
var stair_heal := 1 # HP healed on every staircase
var execute := 0.0 # bonus damage vs foes under 30% HP
var gear_find := 1.0 # gear drop chance multiplier
## Run level (see Leveling): XP from kills, perks picked every 5th level.
var level := 1
var xp := 0
var perks: Array = []
var soul_used := false
var _shadow_t := 0.0
## Equipped gear: {"head": item, "body": item, "weapon": item} (see Gear).
var equipment := {}

# Set by TouchControls.
var touch_move := Vector2.ZERO
var touch_aiming := false
var touch_aim := Vector2.RIGHT

# State.
var dead := false
var facing := Vector2.DOWN
var aiming := false
var aim_dir := Vector2.DOWN
var aim_power := 1.0
var combo := 0
var reload_t := 0.0
var atk_cd := 0.0
var attack_anim := 0.0
var no_ammo_flash := 0.0
var dodge_t := 0.0
var dodge_cd := 0.0
var dodge_dir := Vector2.DOWN
var invuln := 0.0
var hurt_flash := 0.0
## > 0 while dodging (and just after): see-through and invulnerable.
var phase_t := 0.0

var _pending := false
var _pending_auto := false
var _pending_dir := Vector2.ZERO
var _pending_power := 1.0
var _mouse_held := false
var _pad_aiming := false
var _pad_dir := Vector2.RIGHT
var _pad_power := 1.0

const SAVED_STATS := ["class_id", "max_hp", "hp", "speed", "weapon", "damage_mult", "range_mult",
	"reload_mult", "crit", "crit_damage", "max_charges", "dodge_cooldown", "luck",
	"actives", "passives", "curses", "look", "cdr_mult", "gold_mult", "block", "kill_heal", "magnet",
	"stair_heal", "execute", "gear_find", "equipment", "level", "xp", "perks", "soul_used"]

# Devoured boss powers (see Abilities) and curses from the plunge stairs.
var actives: Array = [] # [{type, id, name, tier}]
var passives: Array = []
var curses: Array = [] # [curse ids]
var ability_cd: Array[float] = [0.0, 0.0, 0.0, 0.0]
var second_wind_used := false
var _attack_count := 0
var last_attack_aimed := false
var _echo_t := -1.0
var _echo_dir := Vector2.ZERO
var _echo_power := 1.0
var _spiral_left := 0
var _spiral_t := 0.0
var _spiral_angle := 0.0
var _rampage_t := 0.0
var _rampage_hit := {}
var _dodge_hit := {}
var _orbit_t := 0.0
var _last_mouse_move := -10.0
var _move := Vector2.ZERO
var _vis_angle := PI / 2.0
var _walk_t := 0.0
## Character-creator appearance (see HeroArt).
var look: Dictionary = {}
var _face_left := false
var _death_ms := 0
var _last_step := -1
## Hover bob of the current frame (world units) - the weapon hand follows it.
var _bob := Vector2.ZERO


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CircleShape2D.new()
	shape.radius = RADIUS
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	add_to_group("player")


func apply_class(id: String) -> void:
	var c := Classes.get_def(id)
	class_id = id
	weapon = c["weapon"]
	max_hp = int(c["hp"])
	hp = max_hp
	speed = float(c["speed"]) * PACE
	max_charges = int(c["charges"])
	charges = max_charges
	crit = c["crit"]
	damage_mult = c["damage"]
	dodge_cooldown = float(c["dodge_cd"]) * 0.65
	reload_mult = PACE


func to_dict() -> Dictionary:
	var d := {}
	for k in SAVED_STATS:
		d[k] = get(k)
	return d


func from_dict(d: Dictionary) -> void:
	for k in SAVED_STATS:
		if d.has(k):
			var v = d[k]
			# JSON stores every number as float; convert back for int stats.
			if typeof(get(k)) == TYPE_INT:
				v = int(v)
			set(k, v)
	if not Weapons.DATA.has(weapon):
		weapon = Classes.get_def(class_id)["weapon"]
	charges = max_charges


func weapon_def() -> Dictionary:
	return Weapons.get_def(weapon)


func reach() -> float:
	return float(weapon_def()["range"]) * range_mult


func dodge_ready() -> float:
	return 1.0 - clampf(dodge_cd / dodge_cooldown, 0.0, 1.0)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if dead:
		return
	# device -1 = mouse events emulated from touch; touch has its own controls.
	if event is InputEventMouseButton and event.device != -1:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_held = true
			elif _mouse_held:
				_mouse_held = false
				var to_mouse := get_global_mouse_position() - global_position
				queue_attack(false, to_mouse, to_mouse.length() / reach())
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			request_dodge()
	elif event is InputEventMouseMotion and event.device != -1:
		_last_mouse_move = Time.get_ticks_msec() / 1000.0
	elif event.is_action_pressed("attack"):
		queue_attack(true)
	elif event.is_action_pressed("dodge"):
		request_dodge()
	else:
		for i in Abilities.MAX_ACTIVES:
			if event.is_action_pressed("ability_%d" % (i + 1)):
				use_ability(i)


## auto = aim at the nearest enemy; otherwise strike toward `dir`.
## power (0-1) = how far to throw targeted spells like the fire blast.
func queue_attack(auto: bool, dir := Vector2.ZERO, power := 1.0) -> void:
	if dead:
		return
	_pending = true
	_pending_auto = auto
	_pending_dir = dir
	_pending_power = clampf(power, 0.15, 1.0)


func _notification(what: int) -> void:
	# Pausing (menus, level-up, shops) cancels any half-finished aim.
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_UNPAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_mouse_held = false
		_pad_aiming = false
		touch_aiming = false
		aiming = false
		queue_redraw()


func request_dodge() -> void:
	if dead or dodge_cd > 0.0 or dodge_t > 0.0:
		return
	dodge_dir = _move.normalized() if _move.length() > 0.01 else facing
	facing = dodge_dir
	dodge_t = DODGE_DURATION
	dodge_cd = dodge_cooldown
	# See-through and untouchable for the whole dash plus a short grace after it.
	phase_t = DODGE_DURATION + DODGE_GRACE
	invuln = maxf(invuln, phase_t)
	if has_perk("shadow_strike"):
		_shadow_t = DODGE_DURATION + 1.0
	_dodge_hit.clear()
	main.sfx("dodge")


# ------------------------------------------------------------------ boss powers

func has_perk(id: String) -> bool:
	return id in perks


func has_passive(id: String) -> bool:
	for p in passives:
		if p.get("id") == id:
			return true
	return false


func ability_cooldown(i: int) -> float:
	if i >= actives.size():
		return 1.0
	return float(Abilities.ACTIVES[actives[i]["id"]]["cd"]) / cdr_mult


## Adds a power, or replaces slot `replace` (-1 = append). Handles stat passives.
func add_power(ab: Dictionary, replace := -1) -> void:
	var list := actives if ab["type"] == "active" else passives
	if replace >= 0 and replace < list.size():
		if ab["type"] == "passive":
			_passive_changed(list[replace]["id"], false)
		list[replace] = ab
	else:
		list.append(ab)
	if ab["type"] == "passive":
		_passive_changed(ab["id"], true)
	else:
		ability_cd[list.find(ab)] = 0.0
	stats_changed.emit()


func _passive_changed(id: String, gained: bool) -> void:
	if id == "overcharge":
		max_charges += 1 if gained else -1
		reload_mult *= 1.15 if gained else 1.0 / 1.15
		charges = mini(charges, max_charges)


## Damage of an active power: its base, your multiplier, and the depth of the boss it came from.
func _ability_damage(ab: Dictionary) -> float:
	var tier := float(ab.get("tier", 10))
	return float(Abilities.ACTIVES[ab["id"]]["damage"]) * power_mult() * (1.0 + 0.2 * (tier - 1.0)) / 2.8


func _ability_dir() -> Vector2:
	# Mouse users aim with the cursor; everyone else gets auto-aim.
	if Time.get_ticks_msec() / 1000.0 - _last_mouse_move < 2.0:
		var m := get_global_mouse_position() - global_position
		if m.length() > 1.0:
			return m.normalized()
	var target := _nearest_enemy(180.0)
	return (target.global_position - global_position).normalized() if target else facing


func use_ability(i: int) -> void:
	if dead or i >= actives.size() or ability_cd[i] > 0.0:
		return
	var ab: Dictionary = actives[i]
	ability_cd[i] = ability_cooldown(i)
	var dmg := _ability_damage(ab)
	var dir := _ability_dir()
	facing = dir
	main.sfx("ability")
	match String(ab["id"]):
		"radial":
			for k in 12:
				_bolt(Vector2.RIGHT.rotated(TAU * k / 12.0 + randf()), dmg, 0)
		"spiral":
			_spiral_left = 24
			_spiral_t = 0.0
			_spiral_angle = dir.angle()
			ab["_dmg"] = dmg
		"fan":
			for k in 7:
				_bolt(dir.rotated((k - 3) * 0.15), dmg, 1)
		"mines":
			var targets := _enemies().filter(func(e) -> bool: return global_position.distance_to(e.global_position) < 170.0)
			targets.sort_custom(func(a, b) -> bool: return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
			if targets.is_empty():
				_player_blast(global_position + dir * 70.0, 28.0, 0.5, dmg, 0.0)
			for e in targets.slice(0, 3):
				_player_blast(e.global_position, 28.0, 0.5, dmg, 0.0)
		"slam":
			_player_blast(global_position, 55.0, 0.12, dmg, 1.0)
			main.shake(4.0)
		"charge":
			dodge_dir = dir
			_rampage_t = 0.3
			_rampage_hit.clear()
			invuln = maxf(invuln, 0.4)
		"summon":
			for k in 5:
				var p := _bolt(dir.rotated((k - 2) * 0.5), dmg, 0, 140.0, 2.5)
				p.homing = true
				p.style = "spirit"
		"teleport":
			var to := global_position + dir * 100.0
			var q := PhysicsRayQueryParameters2D.create(global_position, to, 1)
			var hit := get_world_2d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				to = hit["position"] - dir * (RADIUS + 3.0)
			_player_blast(global_position, 30.0, 0.05, dmg, 0.0)
			global_position = to
			reset_physics_interpolation()
			_player_blast(global_position, 30.0, 0.05, dmg, 0.0)
			invuln = maxf(invuln, 0.25)


func _bolt(dir: Vector2, dmg: float, pierce: int, spd := 260.0, life := 0.8) -> Projectile:
	var p := Projectile.new()
	p.setup(dir * spd, dmg, true, life, pierce)
	p.source = self
	p.origin = global_position
	p.style = "bolt"
	main.spawn(p, global_position + dir * 8.0)
	return p


func _player_blast(pos: Vector2, rad: float, delay: float, dmg: float, stun_time: float) -> void:
	var b := Blast.new()
	b.radius = rad
	b.delay = delay
	b.damage = dmg
	b.source = self
	b.stun = stun_time
	b.color = Abilities.ACTIVE_COLOR
	main.spawn(b, pos)


func _tick_abilities(delta: float) -> void:
	# Echo: repeat the last strike for free.
	if _echo_t >= 0.0:
		_echo_t -= delta
		if _echo_t < 0.0:
			_strike(_echo_dir, _echo_power)
	# Spiral Storm stream.
	if _spiral_left > 0:
		_spiral_t -= delta
		if _spiral_t <= 0.0:
			_spiral_t = 0.06
			_spiral_left -= 1
			_spiral_angle += 0.45
			var dmg := 10.0
			for ab in actives:
				if ab["id"] == "spiral":
					dmg = ab.get("_dmg", _ability_damage(ab))
			_bolt(Vector2.RIGHT.rotated(_spiral_angle), dmg, 0)
			_bolt(Vector2.RIGHT.rotated(_spiral_angle + PI), dmg, 0)
	# Rampage: a long dash that hits everything you run through.
	if _rampage_t > 0.0:
		_rampage_t -= delta
		dodge_t = maxf(dodge_t, 0.02)
		var dmg := 40.0
		for ab in actives:
			if ab["id"] == "charge":
				dmg = _ability_damage(ab)
		_contact_hits(_rampage_hit, dmg, 1.0)
	# Spiked Shell: dodging through enemies hurts them.
	if dodge_t > 0.0 and has_passive("spiked"):
		_contact_hits(_dodge_hit, 25.0 * power_mult(), 0.0)
	# Orbiting Shards.
	if has_passive("orbit"):
		_orbit_t += delta
		if fmod(_orbit_t, 0.25) < delta:
			for k in 3:
				var sp := global_position + Vector2.RIGHT.rotated(_orbit_t * 3.0 + TAU * k / 3.0) * 22.0
				for e in _enemies():
					if e.global_position.distance_to(sp) < e.radius + 5.0:
						deal_damage(e, 8.0 * power_mult(), (e.global_position - global_position).normalized())


func _contact_hits(already: Dictionary, dmg: float, stun_time: float) -> void:
	for e in _enemies():
		if already.has(e):
			continue
		if e.global_position.distance_to(global_position) < e.radius + RADIUS + 6.0:
			already[e] = true
			deal_damage(e, dmg, dodge_dir)
			if stun_time > 0.0:
				e.stun = maxf(e.stun, stun_time)


## Called by main when the player kills an enemy.
func on_kill(e: Enemy) -> void:
	if (has_passive("vampirism") and randf() < 0.12) or (kill_heal > 0.0 and randf() < kill_heal):
		heal(1)
		main.spawn_puff(global_position, Color(0.9, 0.2, 0.3), 8.0)
	if has_passive("volatile") and not e.is_boss:
		_player_blast(e.global_position, 30.0, 0.05, 20.0 * power_mult(), 0.0)
	if has_perk("nova") and randf() < 0.3:
		_player_blast(e.global_position, 40.0, 0.05, 25.0 * power_mult(), 0.0)


# ------------------------------------------------------------------ update

func _physics_process(delta: float) -> void:
	if dead:
		return
	atk_cd = maxf(atk_cd - delta, 0.0)
	phase_t = maxf(phase_t - delta, 0.0)
	_shadow_t = maxf(_shadow_t - delta, 0.0)
	attack_anim = maxf(attack_anim - delta * float(weapon_def()["anim"]), 0.0)
	no_ammo_flash = maxf(no_ammo_flash - delta, 0.0)
	invuln = maxf(invuln - delta, 0.0)
	hurt_flash = maxf(hurt_flash - delta, 0.0)
	dodge_cd = maxf(dodge_cd - delta, 0.0)
	for i in ability_cd.size():
		ability_cd[i] = maxf(ability_cd[i] - delta, 0.0)
	_tick_abilities(delta)

	# Charges refill one at a time.
	if charges < max_charges:
		reload_t += delta / (float(weapon_def()["reload"]) / reload_mult)
		if reload_t >= 1.0:
			charges += 1
			reload_t = reload_t - 1.0 if charges < max_charges else 0.0

	# Movement: instant, analog, diagonals normalized.
	var mv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if touch_move.length() > 0.0:
		mv = touch_move
	mv = mv.limit_length(1.0)
	_move = mv
	if dodge_t > 0.0:
		var step := minf(delta, dodge_t)
		velocity = dodge_dir * (DODGE_DISTANCE / DODGE_DURATION) * (step / delta)
		dodge_t -= delta
	else:
		velocity = mv * speed * (0.85 if main.floor_mod == "flooded" else 1.0)
	move_and_slide()
	if mv.length() > 0.01:
		_walk_t += delta * 13.0

	# Gamepad right stick: push to aim, let go to strike.
	var rs := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if rs.length() >= AIM_DEADZONE:
		_pad_aiming = true
		_pad_dir = rs.normalized()
		_pad_power = rs.length()
	elif _pad_aiming:
		_pad_aiming = false
		queue_attack(false, _pad_dir, _pad_power)

	# If the mouse release was missed (released while paused, over a button or outside
	# the window), drop the aim instead of leaving the preview stuck on screen.
	if _mouse_held and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_mouse_held = false

	# Aim preview.
	aiming = false
	if _mouse_held:
		var to_mouse := get_global_mouse_position() - global_position
		aiming = true
		aim_dir = to_mouse.normalized() if to_mouse.length() > 1.0 else facing
		aim_power = clampf(to_mouse.length() / reach(), 0.0, 1.0)
	elif touch_aiming:
		aiming = true
		aim_dir = touch_aim.normalized()
		aim_power = clampf(touch_aim.length(), 0.15, 1.0)
	elif _pad_aiming:
		aiming = true
		aim_dir = _pad_dir
		aim_power = _pad_power

	# Facing: aim > attack/dodge lock > movement.
	if aiming:
		facing = aim_dir
	elif attack_anim <= 0.0 and dodge_t <= 0.0 and mv.length() > 0.01:
		facing = mv.normalized()
	_vis_angle = lerp_angle(_vis_angle, facing.angle(), minf(1.0, delta * 22.0))

	# Queued attack fires as soon as the cooldown / dodge allows it.
	if _pending:
		if charges <= 0:
			_pending = false
			no_ammo_flash = 0.3
		elif atk_cd <= 0.0 and dodge_t <= 0.0:
			_pending = false
			_attack()
	queue_redraw()


# ------------------------------------------------------------------ combat

func _attack() -> void:
	var w := weapon_def()
	var r := reach()
	var dir := _pending_dir
	var power := _pending_power
	if _pending_auto:
		var target := _nearest_enemy(r + AUTO_AIM_EXTRA)
		dir = (target.global_position - global_position) if target else facing
		power = clampf(global_position.distance_to(target.global_position) / r, 0.15, 1.0) if target else 0.6
	if dir.length() < 0.01:
		dir = facing
	dir = dir.normalized()
	facing = dir
	aim_dir = dir
	_vis_angle = dir.angle()
	charges -= 1
	atk_cd = float(w["cooldown"]) / PACE
	_attack_count += 1
	last_attack_aimed = not _pending_auto
	if has_passive("echo") and _attack_count % 4 == 0:
		_echo_t = 0.15
		_echo_dir = dir
		_echo_power = power
	_strike(dir, power)
	if has_perk("shockwave") and _attack_count % 4 == 0:
		_player_blast(global_position, 52.0, 0.06, 25.0 * power_mult(), 0.4)


## Current damage multiplier: upgrades, Bloodlust and curses.
func power_mult() -> float:
	var m := damage_mult
	if has_passive("bloodlust"):
		m *= 1.0 + 0.15 * (max_hp - hp)
	return m


## The weapon's hit itself (used by normal attacks and by Echo repeats).
func _strike(dir: Vector2, power: float) -> void:
	var w := weapon_def()
	var r := reach()
	combo ^= 1
	attack_anim = 1.0
	main.sfx("swing")
	var dmg := float(w["damage"]) * power_mult()
	var flip := -1.0 if combo == 1 else 1.0

	match String(w["shape"]):
		"arc":
			var min_dot := cos(deg_to_rad(float(w["arc"]) * 0.5))
			for e in _enemies():
				var to: Vector2 = e.global_position - global_position
				var d := to.length()
				if d - e.radius > r:
					continue
				if d > e.radius + 9.0 and to.normalized().dot(dir) < min_dot:
					continue
				if _clear(e.global_position):
					deal_damage(e, dmg, to.normalized())
			_fx("arc", dir, r, float(w["arc"]), 0.0, flip, w["fx"], global_position)
		"thrust":
			var width := float(w["width"])
			for e in _enemies():
				var to: Vector2 = e.global_position - global_position
				var m := to.dot(dir)
				if m < -e.radius or m > r + e.radius:
					continue
				if absf(to.cross(dir)) > width * 0.5 + e.radius:
					continue
				if _clear(e.global_position):
					deal_damage(e, dmg, dir)
			_fx("thrust", dir, r, 0.0, width, flip, w["fx"], global_position)
		"slam":
			var center := global_position + dir * r * 0.6
			var rad := float(w["radius"]) * range_mult
			for e in _enemies():
				var to: Vector2 = e.global_position - center
				if to.length() - e.radius > rad or not _clear(e.global_position):
					continue
				deal_damage(e, dmg, to.normalized() if to.length() > 0.1 else dir)
				e.stun = maxf(e.stun, float(w["stun"]))
			_fx("slam", dir, rad, 0.0, 0.0, flip, w["fx"], center)
			main.shake(3.0)
		"circle":
			for e in _enemies():
				var to: Vector2 = e.global_position - global_position
				if to.length() - e.radius <= r and _clear(e.global_position):
					deal_damage(e, dmg, to.normalized())
			_fx("circle", dir, r, 0.0, 0.0, flip, w["fx"], global_position)
		"line":
			_shoot(dir, w, dmg, r)
		"fan":
			var n := int(w["count"])
			for i in n:
				_shoot(dir.rotated((i - (n - 1) / 2.0) * float(w["spread"])), w, dmg, r)
		"blast":
			var target_pos := global_position + dir * r * power
			# Don't cast through walls: stop at the first wall in the way.
			var q := PhysicsRayQueryParameters2D.create(global_position, target_pos, 1)
			var hit := get_world_2d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				target_pos = hit["position"] - dir * 6.0
			var b := Blast.new()
			b.radius = float(w["radius"]) * range_mult
			b.delay = w["delay"]
			b.damage = dmg
			b.source = self
			main.spawn(b, target_pos)
		"chain":
			_chain(dir, w, dmg, r)


func _shoot(dir: Vector2, w: Dictionary, dmg: float, r: float) -> void:
	var dirs := [dir]
	if has_perk("volley") and _attack_count % 3 == 0: # Volley: two extra arrows
		dirs.append(dir.rotated(0.22))
		dirs.append(dir.rotated(-0.22))
	for d: Vector2 in dirs:
		var p := Projectile.new()
		var spd := float(w["speed"])
		p.setup(d * spd, dmg, true, r / spd, int(w.get("pierce", 0)))
		p.source = self
		p.origin = global_position
		p.style = w.get("style", "arrow")
		main.spawn(p, global_position + d * 8.0)


## Chain lightning: first target in a cone in front, then jumps to nearby enemies.
func _chain(dir: Vector2, w: Dictionary, dmg: float, r: float) -> void:
	if main.floor_mod == "flooded":
		dmg *= 1.5 # lightning loves water
	var min_dot := cos(deg_to_rad(float(w["cone"]) * 0.5))
	var first: Enemy = null
	var best := INF
	for e in _enemies():
		var to: Vector2 = e.global_position - global_position
		var d := to.length()
		if d - e.radius > r or d < 0.1:
			continue
		if d > e.radius + 9.0 and to.normalized().dot(dir) < min_dot:
			continue
		if d < best and _clear(e.global_position):
			best = d
			first = e
	var pts: Array[Vector2] = [global_position + dir * 6.0]
	if first == null:
		pts.append(global_position + dir * r * 0.5)
	else:
		var hit: Array = [first]
		var cur: Enemy = first
		var d_mult := 1.0
		pts.append(cur.global_position)
		deal_damage(cur, dmg, dir)
		for j in int(w["jumps"]):
			var nxt: Enemy = null
			var nd := float(w["jump_range"])
			for e in _enemies():
				if hit.has(e):
					continue
				var dd := cur.global_position.distance_to(e.global_position)
				if dd < nd and _clear_between(cur.global_position, e.global_position):
					nd = dd
					nxt = e
			if nxt == null:
				break
			d_mult *= float(w["jump_mult"])
			deal_damage(nxt, dmg * d_mult, (nxt.global_position - cur.global_position).normalized())
			hit.append(nxt)
			pts.append(nxt.global_position)
			cur = nxt
	var fx := LightningFx.new()
	fx.points = pts
	main.spawn(fx, Vector2.ZERO)


## Applies damage variance, crits, hit-stop and knockback to an enemy.
func deal_damage(e: Node, base: float, dir: Vector2) -> void:
	if not is_instance_valid(e) or e.dying:
		return
	var dmg := base * (1.0 + randf_range(-0.12, 0.12))
	if e is Enemy:
		dmg *= Grind.codex_bonus(e.kind) # Monster Codex mastery
	if execute > 0.0 and e is Enemy and e.hp < e.max_hp * 0.3:
		dmg *= 1.0 + execute
	var is_crit := randf() < crit or _shadow_t > 0.0
	if is_crit:
		dmg *= crit_damage
		main.hit_stop(0.045)
		main.shake(3.0)
	main.sfx("crit" if is_crit else "hit", -2.0)
	e.take_damage(dmg, dir, is_crit)


func _fx(shape: String, dir: Vector2, r: float, arc: float, width: float, flip: float, dur: float, at: Vector2) -> void:
	var fx := SlashFx.new()
	fx.shape = shape
	fx.angle = dir.angle()
	fx.reach = r
	fx.arc_deg = arc
	fx.width = width
	fx.flip = flip
	fx.duration = maxf(dur, 0.1)
	fx.color = Color(0.85, 0.9, 1.0) if weapon != "daggers" else Color(0.9, 0.85, 1.0)
	main.spawn(fx, at)


func _enemies() -> Array:
	var out := []
	for n in get_tree().get_nodes_in_group("enemies"):
		if n is Enemy and not n.dying:
			out.append(n)
	return out


func _clear_between(a: Vector2, b: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(a, b, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _clear(target: Vector2) -> bool:
	var q := PhysicsRayQueryParameters2D.create(global_position, target, 1)
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _nearest_enemy(max_dist: float) -> Node2D:
	var best: Node2D = null
	var best_d := max_dist
	for e in _enemies():
		var d := global_position.distance_to(e.global_position) - float(e.radius)
		if d < best_d and _clear(e.global_position):
			best_d = d
			best = e
	return best


func take_damage(amount: int, _from_dir: Vector2 = Vector2.ZERO) -> void:
	if invuln > 0.0 or dead:
		return
	if block > 0.0 and randf() < block:
		# Blocked by armour / Iron Skin: no damage, short safety window.
		invuln = 0.35
		main.sfx("hit", -6.0)
		main.spawn_puff(global_position, Color(0.85, 0.9, 1.0), 8.0)
		main.show_floating_text(global_position + Vector2(0, -14), "Block")
		return
	hp = maxi(hp - amount, 0)
	invuln = HURT_INVULN
	hurt_flash = 0.25
	main.shake(5.0)
	main.sfx("hurt")
	if has_passive("thorns"):
		_player_blast(global_position, 50.0, 0.05, 30.0 * power_mult(), 0.0)
	if hp <= 0 and has_passive("second_wind") and not second_wind_used:
		second_wind_used = true
		hp = 1
		invuln = 1.5
		main.show_banner("Second Wind!", 1.5)
		main.spawn_puff(global_position, Color(1, 1, 0.6), 16.0)
	if hp <= 0 and has_perk("second_soul") and not soul_used:
		soul_used = true
		hp = 2
		invuln = 1.5
		main.show_banner("Second Soul!", 1.5)
		main.spawn_puff(global_position, Color(0.7, 0.9, 1.0), 16.0)
	stats_changed.emit()
	if hp <= 0:
		dead = true
		_death_ms = Time.get_ticks_msec()
		velocity = Vector2.ZERO
		died.emit()
		queue_redraw()


## Wears a gear piece (undoing the boon of whatever was in that slot).
func equip(item: Dictionary) -> void:
	var slot := String(item["slot"])
	Gear.apply(self, equipment.get(slot, {}), -1)
	equipment[slot] = item
	Gear.apply(self, item, 1)
	if slot == "weapon":
		charges = max_charges
		reload_t = 0.0
	Sprites.prewarm_hero(class_id, vis_look())
	stats_changed.emit()


## The creator look plus worn headgear (what HeroArt paints; armour does not show on a ghost).
func vis_look() -> Dictionary:
	var l := look.duplicate()
	if equipment.has("head"):
		l["eq_head"] = equipment["head"]["id"]
	return l


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	stats_changed.emit()


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	var f := Vector2.RIGHT.rotated(_vis_angle)
	if absf(f.x) > 0.2:
		_face_left = f.x < 0.0
	var feet := Vector2(0, RADIUS + 1.0)
	if dead:
		_draw_death(feet)
		return
	if aiming:
		_draw_aim_preview()

	var blink := invuln > 0.0 and phase_t <= 0.0 and hurt_flash <= 0.0 and int(invuln * 20.0) % 2 == 0
	var mod := Color(1, 1, 1, 0.4 if blink else 1.0)
	if phase_t > 0.0: # dodging: a see-through, slightly spectral ghost
		mod = Color(0.8, 0.9, 1.0, 0.38)
	# Shadow (the ghost hovers, so it is small and soft and breathes with the bob).
	draw_set_transform(Vector2(0, RADIUS * 0.9), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, RADIUS * (0.8 + _bob.y * 0.08), Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Which animation: hurt > dodge > attack > walk > idle.
	var anim := "idle"
	var frame := int(Time.get_ticks_msec() / 380) # slow hover
	var variant := ""
	if hurt_flash > 0.0:
		anim = "hurt"
		frame = 0 if hurt_flash > 0.12 else 1
		if hurt_flash > 0.17:
			variant = "white"
	elif dodge_t > 0.0:
		anim = "dodge"
		frame = clampi(int((1.0 - dodge_t / DODGE_DURATION) * 4.0), 0, 3)
	elif attack_anim > 0.0:
		anim = "attack"
		frame = clampi(int((1.0 - attack_anim) * 4.0), 0, 3)
	elif _move.length() > 0.01:
		anim = "walk"
		frame = int(_walk_t / (TAU / 3.0)) # a slow, swirly glide
	var tex := Sprites.hero(class_id, vis_look(), anim, frame, variant)
	_bob = HeroArt.body_offset(anim, frame) * Sprites.PX
	if _face_left:
		_bob.x = -_bob.x

	# Weapon behind the body when aiming up, in front otherwise.
	var behind := f.y < -0.55
	if behind:
		_draw_weapon(f, mod)
	Sprites.draw_at(self, tex, feet, _face_left, mod)
	if not behind:
		_draw_weapon(f, mod)
	# Out-of-charges flash.
	if no_ammo_flash > 0.0:
		draw_arc(Vector2.ZERO, RADIUS + 4.0, 0.0, TAU, 20, Color(1, 0.3, 0.3, no_ammo_flash / 0.3), 1.5)


## Death: stagger, crumple, then lie on the ground and fade a little.
func _draw_death(feet: Vector2) -> void:
	var t := (Time.get_ticks_msec() - _death_ms) / 1000.0
	if t < 0.15:
		Sprites.draw_at(self, Sprites.hero(class_id, vis_look(), "death", 0, "white"), feet, _face_left)
	elif t < 0.4:
		Sprites.draw_at(self, Sprites.hero(class_id, vis_look(), "death", 1), feet, _face_left)
	else:
		var tex := Sprites.hero(class_id, vis_look(), "death", 1)
		var side := 1.0 if _face_left else -1.0
		Sprites.draw_centered(self, tex, Vector2(0, 3), Color(0.75, 0.72, 0.8, maxf(0.55, 1.0 - (t - 0.4))), side * PI / 2.0)


func spawn_dust(offset: Vector2, flip: bool) -> void:
	if not is_inside_tree():
		return
	var d := Dust.new()
	d.flip = flip
	d.drift = Vector2(-6.0 if not flip else 6.0, -3.0)
	main.spawn(d, global_position + offset)


## Draws the held weapon as a pixel sprite, rotated toward where you face, with its
## swing / thrust / pull animation.
func _draw_weapon(f: Vector2, mod: Color) -> void:
	var w := weapon_def()
	var shape := String(w["shape"])
	var flip := combo == 1
	var swing := 0.0
	if attack_anim > 0.0 and (shape == "arc" or shape == "circle"):
		var span := deg_to_rad(float(w.get("arc", 360.0))) * 0.5
		var k := 1.0 - attack_anim
		swing = lerpf(-span, span, 1.0 - pow(1.0 - k, 3.0)) * (-1.0 if flip else 1.0)
		if shape == "circle":
			swing = TAU * k * (-1.0 if flip else 1.0)
	var d := f.rotated(swing if attack_anim > 0.0 else 0.6)
	var hand := Vector2(HeroArt.HAND.x * (-1.0 if _face_left else 1.0), RADIUS + 1.0 + HeroArt.HAND.y) + _bob
	var id := weapon
	match weapon:
		"rapier", "spear":
			var reach_px := 8.0 if weapon == "rapier" else 10.0
			var thrust := (1.0 - attack_anim) * reach_px if attack_anim > 0.0 else 0.0
			var sd := f if attack_anim > 0.0 else f.rotated(0.45)
			var back := 2.0 if weapon == "rapier" else -2.0
			_weapon_sprite(id, hand + sd * (back + thrust), sd, mod)
		"crossbow":
			_weapon_sprite(id, hand + f * (3.0 - attack_anim * 2.0), f, mod)
		"bow":
			var tex := Sprites.weapon("bow")
			Sprites.draw_rotated(self, tex, hand + f * 5.0, f, Sprites.weapon_grip("bow"), mod)
			if attack_anim > 0.0: # the string snaps forward after the shot
				var s := f.orthogonal()
				var mid := hand + f * (5.0 - 3.0 * attack_anim)
				draw_line(hand + f * 5.0 + s * 6.0, mid, Color(0.95, 0.95, 0.9, mod.a), 1.0)
				draw_line(hand + f * 5.0 - s * 6.0, mid, Color(0.95, 0.95, 0.9, mod.a), 1.0)
		"knives":
			for i in 3:
				_weapon_sprite("knife", hand + f.rotated(0.5 + i * 0.3) * 4.0, f.rotated(0.5 + i * 0.3), mod)
		"daggers":
			_weapon_sprite(id, hand + d * 3.0, d, mod)
			var d2 := f.rotated(-swing if attack_anim > 0.0 else -0.6)
			_weapon_sprite(id, hand + d2 * 3.0, d2, mod)
		"hammer":
			var lift := f.rotated(-1.2 * attack_anim) if attack_anim > 0.0 else f.rotated(0.6)
			_weapon_sprite(id, hand + lift * 2.0, lift, mod)
		"scythe":
			_weapon_sprite(id, hand - d * 3.0, d, mod, flip)
		"staff", "wand":
			var sd := f.rotated(0.45 - 0.45 * attack_anim)
			_weapon_sprite(id, hand + sd * 2.0, sd, mod)
			var glow := Color(1.0, 0.55, 0.2) if weapon == "staff" else Color(0.85, 0.5, 1.0)
			var tip := hand + sd * (16.0 if weapon == "staff" else 10.0)
			draw_circle(tip, 3.5 + attack_anim * 3.0, Color(glow, 0.22 * mod.a))
		"grimoire":
			var tex := Sprites.weapon("grimoire")
			var c := hand + f * 7.0 + f.orthogonal() * 3.0
			Sprites.draw_centered(self, tex, c, mod)
			draw_circle(c, 3.0 + attack_anim * 3.0, Color(0.5, 0.8, 1.0, 0.25 * mod.a))
		_: # sword, greataxe
			_weapon_sprite(id, hand + d * 3.0, d, mod)


func _weapon_sprite(id: String, origin: Vector2, dir: Vector2, mod: Color, flip_y := false) -> void:
	Sprites.draw_rotated(self, Sprites.weapon(id), origin, dir, Sprites.weapon_grip(id), mod, flip_y)


func _draw_aim_preview() -> void:
	var w := weapon_def()
	var r := reach()
	var fill := Color(1, 1, 1, 0.1)
	var edge := Color(1, 1, 1, 0.4)
	var ang := aim_dir.angle()
	match String(w["shape"]):
		"arc":
			var half := deg_to_rad(float(w["arc"])) * 0.5
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 17:
				pts.append(Vector2.RIGHT.rotated(ang - half + 2.0 * half * i / 16.0) * r)
			draw_colored_polygon(pts, fill)
			draw_arc(Vector2.ZERO, r, ang - half, ang + half, 16, edge, 1.5)
		"fan":
			var n := int(w["count"])
			for i in n:
				var d := aim_dir.rotated((i - (n - 1) / 2.0) * float(w["spread"]))
				draw_line(d * 8.0, d * r, edge, 1.0)
		"blast":
			var c := aim_dir * r * aim_power
			var rad := float(w["radius"]) * range_mult
			draw_line(Vector2.ZERO, c, Color(1, 1, 1, 0.2), 1.0)
			draw_circle(c, rad, fill)
			draw_arc(c, rad, 0.0, TAU, 28, edge, 1.5)
		"chain":
			var half := deg_to_rad(float(w["cone"])) * 0.5
			var pts := PackedVector2Array([Vector2.ZERO])
			for i in 9:
				pts.append(Vector2.RIGHT.rotated(ang - half + 2.0 * half * i / 8.0) * r)
			draw_colored_polygon(pts, Color(0.6, 0.85, 1.0, 0.1))
			draw_arc(Vector2.ZERO, r, ang - half, ang + half, 8, Color(0.6, 0.85, 1.0, 0.5), 1.5)
		"thrust", "line":
			var width := float(w.get("width", 6.0))
			var s := Vector2(-aim_dir.y, aim_dir.x) * width * 0.5
			var end := aim_dir * r
			draw_colored_polygon(PackedVector2Array([s, end + s, end - s, -s]), fill)
			draw_line(s, end + s, edge, 1.0)
			draw_line(-s, end - s, edge, 1.0)
		"slam":
			var c := aim_dir * r * 0.6
			var rad := float(w["radius"]) * range_mult
			draw_circle(c, rad, fill)
			draw_arc(c, rad, 0.0, TAU, 28, edge, 1.5)
		"circle":
			draw_circle(Vector2.ZERO, r, fill)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 28, edge, 1.5)


func _process(_delta: float) -> void:
	# Physics stops when dead; keep redrawing so the death animation plays.
	if dead:
		queue_redraw()
