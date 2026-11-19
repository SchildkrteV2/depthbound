class_name Gear
extends RefCounted
## Gear that monsters drop: helmets/hats (head), armour (body) and weapons. Each piece changes
## how the hero looks and carries a boon. Equipped pieces live in Player.equipment
## {"head": item, "body": item, "weapon": item}; an item is
## {"slot", "id", "name", "boon", "v", "rare"} ("weapon" items also have "weapon").
##
## Boons are stat changes applied on equip and undone on unequip (see apply()).

const DROP_CHANCE := 0.035 # normal foes
const ELITE_CHANCE := 0.3
const RARE_CHANCE := 0.15 # rare = boon x1.6 (always from bosses)
## Legendary (two boons) chances; mutated deep bosses always drop one.
const LEGEND_CHANCE := 0.005
const LEGEND_ELITE := 0.04
const LEGEND_BOSS := 0.15

const HEADS := {
	"iron_helm": {"name": "Iron Helm", "boon": "max_hp", "v": 1.0},
	"horned_helm": {"name": "Horned Helm", "boon": "damage", "v": 0.12},
	"arcane_hat": {"name": "Arcane Hat", "boon": "cdr", "v": 0.15},
	"shadow_hood": {"name": "Shadow Hood", "boon": "crit", "v": 0.07},
	"crown": {"name": "Gilded Crown", "boon": "gold", "v": 0.35},
	"bandana": {"name": "Red Bandana", "boon": "speed", "v": 0.1},
}
const BODIES := {
	"chainmail": {"name": "Chainmail", "boon": "block", "v": 0.12},
	"plate": {"name": "Plate Armour", "boon": "max_hp", "v": 2.0},
	"leather": {"name": "Leather Jerkin", "boon": "dodge", "v": 0.2},
	"robe": {"name": "Mystic Robe", "boon": "reload", "v": 0.2},
	"blood_cloak": {"name": "Blood Cloak", "boon": "kill_heal", "v": 0.07},
	"gilded_mail": {"name": "Gilded Mail", "boon": "crit_damage", "v": 0.4},
}
## Weapon affixes: [prefix, boon, value].
const AFFIXES := [["Keen", "crit", 0.06], ["Heavy", "damage", 0.15], ["Swift", "reload", 0.15],
	["Long", "range", 0.12], ["Vampiric", "kill_heal", 0.05], ["Lucky", "gold", 0.25]]

## Boon descriptions; %s gets the value.
const BOON_TEXT := {
	"max_hp": "+%d max HP", "damage": "+%d%% damage", "cdr": "Powers recharge %d%% faster",
	"crit": "+%d%% crit chance", "gold": "+%d%% gold", "speed": "+%d%% move speed",
	"block": "%d%% chance to block a hit", "dodge": "Dodge recharges %d%% faster",
	"reload": "Charges refill %d%% faster", "kill_heal": "%d%% chance to heal on kill",
	"crit_damage": "+%d%% crit damage", "range": "+%d%% weapon range",
}


static func _boon_text(b: String, v: float) -> String:
	if not BOON_TEXT.has(b):
		return ""
	return BOON_TEXT[b] % (int(round(v)) if b == "max_hp" else int(round(v * 100.0)))


static func describe_boon(item: Dictionary) -> String:
	var t := _boon_text(String(item.get("boon", "")), float(item.get("v", 0.0)))
	if item.has("boon2"):
		t += ", " + _boon_text(String(item["boon2"]), float(item["v2"]))
	return t


static func rarity(item: Dictionary) -> String:
	if item.get("legendary", false):
		return "Legendary"
	return "Rare" if item.get("rare", false) else ""


static func describe(item: Dictionary) -> String:
	var r := rarity(item)
	return "%s%s (lvl %d) - %s" % [r + " " if r != "" else "", item["name"], int(item.get("ilvl", 1)), describe_boon(item)]


## Legendary second boons: [boon, base value, name suffix].
const LEGEND_BOONS := [["damage", 0.12, "of Fury"], ["crit", 0.06, "of Precision"], ["kill_heal", 0.05, "of the Leech"],
	["speed", 0.08, "of the Wind"], ["block", 0.08, "of Warding"], ["reload", 0.15, "of Haste"],
	["crit_damage", 0.3, "of Ruin"], ["max_hp", 1.0, "of Vigor"]]
## Item level scaling: boons grow 2.5% per level (depth + heat bonus).
const PER_LEVEL := 0.025


static func _scaled(b: String, v: float, mult: float) -> float:
	return maxf(1.0, round(v * mult)) if b == "max_hp" else snappedf(v * mult, 0.01)


## A random piece. `weapons` = the class's weapon pool the player may get. `ilvl` (item level,
## from depth and heat) makes the boons stronger; legendary pieces carry a second boon.
static func roll(weapons: Array, rare := false, ilvl := 1, legendary := false) -> Dictionary:
	var slots := ["head", "body"]
	if not weapons.is_empty():
		slots.append("weapon")
	var slot: String = slots[randi() % slots.size()]
	var item := {}
	match slot:
		"head", "body":
			var table: Dictionary = HEADS if slot == "head" else BODIES
			var id: String = table.keys()[randi() % table.size()]
			var d: Dictionary = table[id]
			item = {"slot": slot, "id": id, "name": d["name"], "boon": d["boon"], "v": d["v"]}
		"weapon":
			var wid: String = weapons[randi() % weapons.size()]
			var a: Array = AFFIXES[randi() % AFFIXES.size()]
			item = {"slot": "weapon", "id": wid, "weapon": wid, "name": "%s %s" % [a[0], Weapons.get_def(wid)["name"]],
				"boon": a[1], "v": a[2]}
	ilvl = maxi(1, ilvl)
	item["ilvl"] = ilvl
	var mult := 1.0 + PER_LEVEL * (ilvl - 1)
	if rare or legendary:
		item["rare"] = true
		mult *= 1.6
	item["v"] = _scaled(String(item["boon"]), float(item["v"]), mult)
	if legendary:
		item["legendary"] = true
		var pool := LEGEND_BOONS.filter(func(x: Array) -> bool: return x[0] != item["boon"])
		var lb: Array = pool[randi() % pool.size()]
		item["boon2"] = lb[0]
		item["v2"] = _scaled(String(lb[0]), float(lb[1]), mult)
		item["name"] = "%s %s" % [item["name"], lb[2]]
	return item


## Applies (sign = 1) or removes (sign = -1) an item's boons on the player.
static func apply(p: Player, item: Dictionary, sign := 1) -> void:
	if item.is_empty():
		return
	_apply_boon(p, String(item.get("boon", "")), float(item.get("v", 0.0)), sign)
	if item.has("boon2"):
		_apply_boon(p, String(item["boon2"]), float(item["v2"]), sign)
	if item.get("slot") == "weapon" and sign > 0:
		p.weapon = String(item["weapon"])


static func _apply_boon(p: Player, boon: String, v: float, sign: int) -> void:
	var mul := 1.0 + v
	match boon:
		"max_hp":
			p.max_hp = maxi(1, p.max_hp + int(v) * sign)
			p.hp = clampi(p.hp + (int(v) if sign > 0 else 0), 1, p.max_hp)
		"damage":
			p.damage_mult *= mul if sign > 0 else 1.0 / mul
		"cdr":
			p.cdr_mult *= mul if sign > 0 else 1.0 / mul
		"crit":
			p.crit += v * sign
		"gold":
			p.gold_mult += v * sign
		"speed":
			p.speed *= mul if sign > 0 else 1.0 / mul
		"block":
			p.block += v * sign
		"dodge":
			p.dodge_cooldown /= mul if sign > 0 else 1.0 / mul
		"reload":
			p.reload_mult *= mul if sign > 0 else 1.0 / mul
		"kill_heal":
			p.kill_heal += v * sign
		"crit_damage":
			p.crit_damage += v * sign
		"range":
			p.range_mult *= mul if sign > 0 else 1.0 / mul
