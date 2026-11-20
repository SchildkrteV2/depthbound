class_name Leveling
extends RefCounted
## Two kinds of levels:
##  - Run level: kills give XP; every level makes the ghost a bit stronger (+3% damage, a heal,
##    +1 max HP every 3rd level) and every 5th level offers a choice of three perks.
##  - Ghost Level: all XP ever earned also feeds a permanent level (saved in Profile) that pays
##    shards and monster parts on every level and gives a small permanent damage / HP bonus.

const LEVEL_DAMAGE := 0.03
const HP_EVERY := 3
const PERK_EVERY := 5

## XP from one kill.
static func xp_for_kill(e: Enemy) -> int:
	if e.is_boss:
		return 25
	var xp := 2 if e.kind in ["brute", "golem", "cultist"] else 1
	if e.kind == "slimelet":
		xp = 1
	if e.elite:
		xp *= 3
	return xp


## XP needed to go from `level` to the next one.
static func need(level: int) -> int:
	return 10 + 5 * level


# ------------------------------------------------------------------ perks

## Perks offered every 5th run level: "all" perks for every class, the rest class-only.
const PERKS := {
	"vigor": {"class": "all", "name": "Spectral Vigor", "desc": "+3 max HP, full heal"},
	"second_soul": {"class": "all", "name": "Second Soul", "desc": "Once per run, survive a killing blow with 2 HP"},
	"haunt": {"class": "all", "name": "Haunting Presence", "desc": "+15% damage, +8% move speed"},
	"shockwave": {"class": "fighter", "name": "Shockwave", "desc": "Every 4th attack blasts all foes around you"},
	"bulwark": {"class": "fighter", "name": "Bulwark", "desc": "+15% block chance, +2 max HP"},
	"cleave": {"class": "fighter", "name": "Cleave", "desc": "+25% weapon range, +10% damage"},
	"shadow_strike": {"class": "rogue", "name": "Shadow Strike", "desc": "Hits within 1 s after a dodge always crit"},
	"assassin": {"class": "rogue", "name": "Assassin", "desc": "+10% crit chance, +50% crit damage"},
	"fleet": {"class": "rogue", "name": "Fleet", "desc": "+12% move speed, dodge recharges 25% faster"},
	"volley": {"class": "archer", "name": "Volley", "desc": "Every 3rd shot fires two extra arrows"},
	"eagle_eye": {"class": "archer", "name": "Eagle Eye", "desc": "+20% weapon range, +8% crit chance"},
	"quiver": {"class": "archer", "name": "Deep Quiver", "desc": "+1 charge, charges refill 20% faster"},
	"nova": {"class": "mage", "name": "Arcane Nova", "desc": "Kills have a 30% chance to burst into an arcane blast"},
	"arcane_flow": {"class": "mage", "name": "Arcane Flow", "desc": "Boss powers recharge 30% faster, +10% damage"},
	"mana_well": {"class": "mage", "name": "Mana Well", "desc": "Charges refill 35% faster"},
}


## Up to n perks the player can still take (class perks first in the pool, shuffled).
static func perk_choices(cls: String, taken: Array, n := 3) -> Array:
	var pool := []
	for id in PERKS:
		var c := String(PERKS[id]["class"])
		if (c == "all" or c == cls) and not id in taken:
			pool.append({"id": "perk:" + id, "name": PERKS[id]["name"], "desc": PERKS[id]["desc"]})
	pool.shuffle()
	return pool.slice(0, n)


# ------------------------------------------------------------------ ghost level (account)

## Ghost XP needed to go from Ghost Level `g` to the next one.
static func ghost_need(g: int) -> int:
	return 150 + 50 * g


static func ghost_level() -> int:
	return maxi(1, int(Profile.data.get("ghost_level", 1)))


static func ghost_xp() -> int:
	return int(Profile.data.get("ghost_xp", 0))


## Permanent bonus text for the current Ghost Level.
static func ghost_bonus_text(g := -1) -> String:
	if g < 0:
		g = ghost_level()
	return "+%d%% damage, +%d max HP" % [int(round(ghost_damage(g) * 100)), ghost_hp(g)]


static func ghost_damage(g: int) -> float:
	return 0.01 * mini(g - 1, 50)


static func ghost_hp(g: int) -> int:
	return mini(int(g / 10.0), 3)


## Applies the permanent Ghost Level bonus at the start of a run.
static func apply_ghost(p: Player) -> void:
	var g := ghost_level()
	p.damage_mult *= 1.0 + ghost_damage(g)
	p.max_hp += ghost_hp(g)
	p.hp = p.max_hp


## Adds Ghost XP. Pays out every level reached; returns one line per new level.
static func add_ghost_xp(amount: int) -> Array:
	var lines := []
	var g := ghost_level()
	var xp := ghost_xp() + amount
	while xp >= ghost_need(g):
		xp -= ghost_need(g)
		g += 1
		var r := ghost_reward(g)
		Profile.add_materials(r["parts"])
		Profile.data["shards"] = int(Profile.data.get("shards", 0)) + int(r["shards"])
		lines.append("Ghost Level %d!  %s + %d shards" % [g, Materials.describe(r["parts"]), int(r["shards"])])
	Profile.data["ghost_level"] = g
	Profile.data["ghost_xp"] = xp
	return lines


static func ghost_reward(g: int) -> Dictionary:
	var pool := Materials.ORDER.duplicate()
	pool.erase("heart")
	pool.shuffle()
	var parts := {pool[0]: 3 + int(g / 3.0), pool[1]: 3 + int(g / 3.0)}
	if g % 5 == 0:
		parts["heart"] = 1
	return {"parts": parts, "shards": 10 + 2 * g}
