class_name Abilities
extends RefCounted
## Powers you devour from bosses. Killing a boss gives one random power from it:
## an ACTIVE (button + cooldown, comes from one of the boss's attack patterns)
## or a PASSIVE (always on). You can hold 4 of each.
##
## Active damage scales with the depth of the boss you took it from, so newer
## powers from deeper bosses are stronger - a reason to swap.

const MAX_ACTIVES := 4
const MAX_PASSIVES := 4

## Boss attack pattern -> the player's version of it.
const ACTIVES := {
	"radial": {"name": "Nova", "desc": "Ring of 12 bolts around you", "cd": 6.0, "damage": 25.0},
	"spiral": {"name": "Spiral Storm", "desc": "Two-armed bolt spiral", "cd": 10.0, "damage": 12.0},
	"fan": {"name": "Barrage", "desc": "Fan of 7 bolts", "cd": 5.0, "damage": 22.0},
	"mines": {"name": "Minefield", "desc": "Explosions under nearby foes", "cd": 8.0, "damage": 45.0},
	"slam": {"name": "Quake", "desc": "Slam around you, stuns", "cd": 7.0, "damage": 50.0},
	"charge": {"name": "Rampage", "desc": "Unstoppable charge through foes", "cd": 6.0, "damage": 40.0},
	"summon": {"name": "Spirit Swarm", "desc": "5 homing spirits", "cd": 7.0, "damage": 25.0},
	"teleport": {"name": "Blink", "desc": "Teleport, blasting both ends", "cd": 5.0, "damage": 35.0},
}

const PASSIVES := {
	"thorns": {"name": "Thorns", "desc": "When hurt, blast foes around you"},
	"vampirism": {"name": "Bloodthirst", "desc": "Kills have a 12% chance to heal 1 HP"},
	"bloodlust": {"name": "Bloodlust", "desc": "+15% damage per missing HP"},
	"echo": {"name": "Echo", "desc": "Every 4th attack strikes twice"},
	"spiked": {"name": "Spiked Shell", "desc": "Dodging through foes hurts them"},
	"dread": {"name": "Aura of Dread", "desc": "Foes near you are 30% slower"},
	"second_wind": {"name": "Second Wind", "desc": "Once per floor, survive a lethal hit"},
	"overcharge": {"name": "Overcharge", "desc": "+1 charge, refill 15% faster"},
	"volatile": {"name": "Volatile Death", "desc": "Foes you kill explode"},
	"orbit": {"name": "Orbiting Shards", "desc": "3 shards circle you, cutting foes"},
}

const ACTIVE_COLOR := Color(1.0, 0.6, 0.3)
const PASSIVE_COLOR := Color(0.55, 0.85, 1.0)


## Rolls the power a dead boss leaves behind. Returns {} if you already own everything.
static func roll_from_boss(boss: Enemy, owned_actives: Array, owned_passives: Array) -> Dictionary:
	var owner_name := boss.title.get_slice(",", 0)
	var tier := boss.depth_level
	var actives: Array = []
	for a in boss.boss_def.get("attacks", []):
		if ACTIVES.has(a) and not _owns(owned_actives, a):
			actives.append(a)
	var passives: Array = PASSIVES.keys().filter(func(p: String) -> bool: return not _owns(owned_passives, p))
	var want_active := randf() < 0.5
	if actives.is_empty() and passives.is_empty():
		return {}
	if want_active and actives.is_empty():
		want_active = false
	if not want_active and passives.is_empty():
		want_active = true
	if want_active:
		var id: String = actives[randi() % actives.size()]
		return {"type": "active", "id": id, "name": "%s's %s" % [owner_name, ACTIVES[id]["name"]], "tier": tier}
	var pid: String = passives[randi() % passives.size()]
	return {"type": "passive", "id": pid, "name": "%s's %s" % [owner_name, PASSIVES[pid]["name"]], "tier": tier}


static func _owns(list: Array, id: String) -> bool:
	for a in list:
		if a.get("id") == id:
			return true
	return false


static func describe(ab: Dictionary) -> String:
	var data: Dictionary = ACTIVES[ab["id"]] if ab["type"] == "active" else PASSIVES[ab["id"]]
	return data["desc"]


## Little glyph for an ability, drawn on any CanvasItem (HUD slots, touch buttons).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"radial", "orbit":
			for i in 8:
				var d := Vector2.RIGHT.rotated(TAU * i / 8.0)
				ci.draw_line(c + d * s * 0.3, c + d * s * 0.8, col, 1.5)
		"spiral":
			var pts := PackedVector2Array()
			for i in 16:
				pts.append(c + Vector2.RIGHT.rotated(i * 0.7) * s * (0.1 + i * 0.05))
			ci.draw_polyline(pts, col, 1.5)
		"fan":
			for i in 5:
				ci.draw_line(c + Vector2(-s * 0.6, s * 0.4), c + Vector2(-s * 0.6, s * 0.4) + Vector2.RIGHT.rotated(-0.9 + i * 0.2) * s * 1.2, col, 1.2)
		"mines", "volatile", "thorns":
			ci.draw_circle(c, s * 0.35, col)
			for i in 6:
				var d := Vector2.RIGHT.rotated(TAU * i / 6.0)
				ci.draw_line(c + d * s * 0.45, c + d * s * 0.75, col, 1.2)
		"slam":
			ci.draw_arc(c, s * 0.6, 0.0, TAU, 16, col, 2.0)
			ci.draw_arc(c, s * 0.3, 0.0, TAU, 12, col, 1.5)
		"charge", "spiked":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.6, -s * 0.4), c + Vector2(s * 0.7, 0), c + Vector2(-s * 0.6, s * 0.4)]), col)
		"summon":
			for i in 3:
				ci.draw_circle(c + Vector2.RIGHT.rotated(TAU * i / 3.0) * s * 0.4, s * 0.18, col)
		"teleport":
			ci.draw_arc(c + Vector2(-s * 0.3, 0), s * 0.3, 0.0, TAU, 10, col, 1.5)
			ci.draw_circle(c + Vector2(s * 0.4, 0), s * 0.22, col)
		"vampirism", "bloodlust":
			ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.35, col)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, 0), c + Vector2(0, -s * 0.7), c + Vector2(s * 0.3, 0)]), col)
		"echo":
			ci.draw_arc(c, s * 0.35, -1.2, 1.2, 8, col, 1.5)
			ci.draw_arc(c, s * 0.65, -1.2, 1.2, 10, col, 1.5)
		"dread":
			ci.draw_circle(c, s * 0.25, col)
			ci.draw_arc(c, s * 0.65, 0.0, TAU, 16, Color(col, 0.6), 1.5)
		"second_wind":
			ci.draw_line(c + Vector2(0, -s * 0.6), c + Vector2(0, s * 0.6), col, 2.0)
			ci.draw_line(c + Vector2(-s * 0.6, 0), c + Vector2(s * 0.6, 0), col, 2.0)
		"overcharge":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(s * 0.1, -s * 0.7), c + Vector2(-s * 0.35, s * 0.1), c + Vector2(0, s * 0.1), c + Vector2(-s * 0.1, s * 0.7), c + Vector2(s * 0.35, -s * 0.1), c + Vector2(0, -s * 0.1)]), col)
		_:
			ci.draw_circle(c, s * 0.4, col)
