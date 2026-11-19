class_name Weapons
extends RefCounted
## Weapon definitions. Distances are in pixels (the player's radius is 6 px).
## Every attack uses one charge. Charges refill one at a time (`reload` seconds each).
## `cooldown` is the minimum time between two attacks.
##
## Shapes:
##   arc    - slash in a cone in front of you (arc = cone angle in degrees)
##   thrust - straight line in front of you (width)
##   slam   - circle a little in front of you (radius), stuns enemies
##   circle - spin that hits everything around you
##   line   - projectile in a straight line (speed, pierce = enemies it passes through)
##   fan    - several projectiles in a spread (count, spread in radians)
##   blast  - delayed explosion at a target point (radius, delay)
##   chain  - lightning that hits a target in a cone, then jumps (cone, jumps, jump_range, jump_mult)

const DATA := {
	# --- Fighter ---
	"sword": {
		"name": "Sword", "desc": "Wide 110 deg slash",
		"shape": "arc", "damage": 22.0, "range": 46.0, "arc": 110.0,
		"cooldown": 0.3, "reload": 1.3, "anim": 4.5, "fx": 0.26,
	},
	"greataxe": {
		"name": "Greataxe", "desc": "Huge 170 deg cleave",
		"shape": "arc", "damage": 36.0, "range": 52.0, "arc": 170.0,
		"cooldown": 0.5, "reload": 1.9, "anim": 3.2, "fx": 0.32,
	},
	"hammer": {
		"name": "Hammer", "desc": "Heavy slam, stuns",
		"shape": "slam", "damage": 38.0, "range": 30.0, "radius": 33.0, "stun": 0.5,
		"cooldown": 0.55, "reload": 2.2, "anim": 2.8, "fx": 0.3,
	},
	"spear": {
		"name": "Spear", "desc": "Long straight thrust",
		"shape": "thrust", "damage": 23.0, "range": 75.0, "width": 15.0,
		"cooldown": 0.3, "reload": 1.25, "anim": 5.0, "fx": 0.22,
	},
	# --- Rogue ---
	"daggers": {
		"name": "Twin Daggers", "desc": "Fast, short slashes",
		"shape": "arc", "damage": 10.0, "range": 32.0, "arc": 80.0,
		"cooldown": 0.12, "reload": 0.6, "anim": 8.0, "fx": 0.16,
	},
	"rapier": {
		"name": "Rapier", "desc": "Lightning-fast thrusts",
		"shape": "thrust", "damage": 13.0, "range": 50.0, "width": 10.0,
		"cooldown": 0.12, "reload": 0.55, "anim": 9.0, "fx": 0.14,
	},
	"scythe": {
		"name": "Scythe", "desc": "Spin, hits all around",
		"shape": "circle", "damage": 19.0, "range": 44.0,
		"cooldown": 0.4, "reload": 1.5, "anim": 3.4, "fx": 0.34,
	},
	# --- Archer ---
	"bow": {
		"name": "Bow", "desc": "Piercing arrow, long range",
		"shape": "line", "damage": 31.0, "range": 170.0, "speed": 400.0, "pierce": 99, "style": "arrow",
		"cooldown": 0.35, "reload": 1.5, "anim": 4.0, "fx": 0.0,
	},
	"crossbow": {
		"name": "Crossbow", "desc": "Slow, very heavy bolts",
		"shape": "line", "damage": 50.0, "range": 210.0, "speed": 540.0, "pierce": 99, "style": "arrow",
		"cooldown": 0.5, "reload": 2.0, "anim": 3.0, "fx": 0.0,
	},
	"knives": {
		"name": "Throwing Knives", "desc": "Fan of 3 fast knives",
		"shape": "fan", "damage": 12.0, "range": 115.0, "speed": 330.0, "count": 3, "spread": 0.22, "pierce": 0, "style": "knife",
		"cooldown": 0.15, "reload": 0.7, "anim": 7.0, "fx": 0.0,
	},
	# --- Mage ---
	"staff": {
		"name": "Fire Staff", "desc": "Delayed fire blast",
		"shape": "blast", "damage": 28.0, "range": 110.0, "radius": 30.0, "delay": 0.35,
		"cooldown": 0.4, "reload": 1.7, "anim": 3.4, "fx": 0.0,
	},
	"grimoire": {
		"name": "Storm Grimoire", "desc": "Chain lightning, 3 jumps",
		"shape": "chain", "damage": 20.0, "range": 120.0, "cone": 50.0, "jumps": 3, "jump_range": 65.0, "jump_mult": 0.7,
		"cooldown": 0.35, "reload": 1.3, "anim": 3.4, "fx": 0.0,
	},
	"wand": {
		"name": "Arcane Wand", "desc": "Rapid magic bolts",
		"shape": "line", "damage": 14.0, "range": 150.0, "speed": 300.0, "pierce": 0, "style": "bolt",
		"cooldown": 0.15, "reload": 0.6, "anim": 7.0, "fx": 0.0,
	},
}


static func get_def(id: String) -> Dictionary:
	return DATA[id]
