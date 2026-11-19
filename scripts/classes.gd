class_name Classes
extends RefCounted
## Playable classes. Each has a starting weapon, base stats, and its own weapon pool
## (only these weapons show up as upgrade choices / in shops for that class).

const ORDER := ["fighter", "rogue", "archer", "mage"]

const DATA := {
	"fighter": {
		"name": "Fighter", "role": "Melee - Strong",
		"desc": "Heavy weapons, high health.\nHits hard, moves slow.",
		"weapon": "sword", "weapons": ["sword", "greataxe", "hammer", "spear"],
		"hp": 9, "speed": 74.0, "charges": 3, "crit": 0.05, "damage": 1.25, "dodge_cd": 2.5,
		"cloak": Color(0.72, 0.22, 0.2), "trim": Color(0.8, 0.8, 0.85),
	},
	"rogue": {
		"name": "Rogue", "role": "Melee - Fast",
		"desc": "Quick blades, many charges,\nhigh crit, fast dodge.",
		"weapon": "daggers", "weapons": ["daggers", "rapier", "scythe"],
		"hp": 5, "speed": 94.0, "charges": 4, "crit": 0.18, "damage": 1.0, "dodge_cd": 1.6,
		"cloak": Color(0.2, 0.42, 0.3), "trim": Color(0.12, 0.12, 0.14),
	},
	"archer": {
		"name": "Archer", "role": "Ranged - Fast",
		"desc": "Arrows from afar, quick feet.\nKeep your distance.",
		"weapon": "bow", "weapons": ["bow", "crossbow", "knives"],
		"hp": 5, "speed": 90.0, "charges": 3, "crit": 0.1, "damage": 1.0, "dodge_cd": 2.0,
		"cloak": Color(0.45, 0.55, 0.22), "trim": Color(0.5, 0.35, 0.2),
	},
	"mage": {
		"name": "Mage", "role": "Ranged - Strong",
		"desc": "Slow but devastating spells\nthat hit whole groups.",
		"weapon": "staff", "weapons": ["staff", "grimoire", "wand"],
		"hp": 5, "speed": 74.0, "charges": 3, "crit": 0.05, "damage": 1.3, "dodge_cd": 2.5,
		"cloak": Color(0.42, 0.25, 0.75), "trim": Color(0.95, 0.8, 0.35),
	},
}


static func get_def(id: String) -> Dictionary:
	return DATA[id]
