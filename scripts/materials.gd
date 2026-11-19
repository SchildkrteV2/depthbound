class_name Materials
extends RefCounted
## Monster parts and Workshop recipes.
##
## Monsters sometimes drop a part of themselves. Parts go into your run bag; they are only
## kept once you send them up on a Loot Lift (every 5th floor). Die and the bag is lost.
## Extracted parts are spent in the Workshop (main menu) on permanent upgrades.

## Part id -> name, and which monster drops it.
const PARTS := {
	"gel": {"name": "Slime Gel"},
	"wing": {"name": "Bat Wing"},
	"silk": {"name": "Spider Silk"},
	"bone": {"name": "Bone"},
	"powder": {"name": "Blast Powder"},
	"ecto": {"name": "Ectoplasm"},
	"ember": {"name": "Wisp Ember"},
	"sigil": {"name": "Cult Sigil"},
	"horn": {"name": "Brute Horn"},
	"core": {"name": "Golem Core"},
	"heart": {"name": "Boss Heart"},
}
const ORDER := ["gel", "wing", "silk", "bone", "powder", "ecto", "ember", "sigil", "horn", "core", "heart"]
const DROPS := {
	"slime": "gel", "slimelet": "gel", "bat": "wing", "spider": "silk", "skeleton": "bone",
	"bomber": "powder", "ghost": "ecto", "wisp": "ember", "cultist": "sigil", "brute": "horn",
	"golem": "core", "boss": "heart",
}
## Base chance a normal monster drops its part (elites always drop 2, bosses drop hearts).
const DROP_CHANCE := 0.3
const SMALL_DROP_CHANCE := 0.1 # slimelets

## Workshop recipes. "max" 0 = endless: craft it again and again; the cost climbs every level
## (and speed / crit / dodge / hearts taper off so they never break the game).
const RECIPES := {
	"bone_charm": {"name": "Bone Charm", "desc": "+1 max HP per level", "max": 0, "cost": {"bone": 4, "gel": 4}},
	"silk_wraps": {"name": "Silk Wraps", "desc": "Move speed (up to +50%)", "max": 0, "cost": {"silk": 5, "wing": 3}},
	"whetstone": {"name": "Ember Whetstone", "desc": "+8% damage per level", "max": 0, "cost": {"ember": 4, "bone": 4}},
	"ecto_lens": {"name": "Ecto Lens", "desc": "Crit chance (up to +40%)", "max": 0, "cost": {"ecto": 4, "sigil": 2}},
	"horn_talisman": {"name": "Horn Talisman", "desc": "Dodge cooldown (down to -65%)", "max": 0, "cost": {"horn": 3, "wing": 4}},
	"powder_pouch": {"name": "Powder Pouch", "desc": "+1 attack charge", "max": 3, "cost": {"powder": 6, "core": 2}},
	"greed_sigil": {"name": "Sigil of Greed", "desc": "+20% gold from monsters per level", "max": 0, "cost": {"sigil": 3, "gel": 6}},
	"lucky_charm": {"name": "Lucky Charm", "desc": "More hearts drop (up to +30%)", "max": 0, "cost": {"wing": 4, "silk": 4}},
	"scavenger": {"name": "Scavenger's Pack", "desc": "+15% part drop chance per level", "max": 0, "cost": {"gel": 5, "silk": 5, "bone": 5}},
	"heart_forge": {"name": "Heart Forge", "desc": "Start runs with a random boss power", "max": 1, "cost": {"heart": 2, "core": 3}},
}
const RECIPE_ORDER := ["bone_charm", "silk_wraps", "whetstone", "ecto_lens", "horn_talisman", "powder_pouch", "greed_sigil", "lucky_charm", "scavenger", "heart_forge"]


static func part_name(id: String) -> String:
	return PARTS[id]["name"]


static func endless(recipe: String) -> bool:
	return int(RECIPES[recipe]["max"]) == 0


## What crafting the next level of a recipe costs: linear for the first levels, then it
## grows 12% faster per level, so there is always a next goal.
static func cost_for(recipe: String, level: int) -> Dictionary:
	var out := {}
	var base: Dictionary = RECIPES[recipe]["cost"]
	var grow := pow(1.12, maxi(0, level - 2))
	for k in base:
		out[k] = int(ceil(int(base[k]) * (level + 1) * grow))
	return out


## Tapering bonus: `cap` * (1 - 0.9^level)  (level 1 = 10% of the cap).
static func taper(level: int, cap: float) -> float:
	return cap * (1.0 - pow(0.9, level))


static func bag_total(bag: Dictionary) -> int:
	var n := 0
	for k in bag:
		n += int(bag[k])
	return n


## "3 Bone, 2 Slime Gel" style text.
static func describe(bag: Dictionary) -> String:
	var parts: Array[String] = []
	for k in ORDER:
		if int(bag.get(k, 0)) > 0:
			parts.append("%d %s" % [int(bag[k]), part_name(k)])
	return ", ".join(parts)


## Gives a new run its crafted Workshop bonuses.
static func apply_to(p: Player) -> void:
	var hp_bonus := Profile.crafted_level("bone_charm")
	if hp_bonus > 0:
		p.max_hp += hp_bonus
		p.hp = p.max_hp
	p.speed *= 1.0 + taper(Profile.crafted_level("silk_wraps"), 0.5)
	p.damage_mult *= 1.0 + 0.08 * Profile.crafted_level("whetstone")
	p.crit += taper(Profile.crafted_level("ecto_lens"), 0.4)
	p.dodge_cooldown *= 1.0 - taper(Profile.crafted_level("horn_talisman"), 0.65)
	var pouch := Profile.crafted_level("powder_pouch")
	if pouch > 0:
		p.max_charges += pouch
		p.charges = p.max_charges
