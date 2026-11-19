class_name BossGen
extends RefCounted
## Builds a random boss: name, look, stats and a set of attack patterns.
## Deeper bosses get more attack patterns, so they keep getting harder forever.
##
## Attack patterns:
##   radial   - ring of bullets in every direction
##   spiral   - two-armed spiral stream
##   fan      - aimed spread of bullets at the player
##   mines    - warning circles under the player that explode
##   slam     - ground slam around itself when you're close
##   charge   - winds up, then charges in a straight line
##   summon   - calls minions
##   teleport - blinks to a spot near the player

const ATTACKS := ["radial", "spiral", "fan", "mines", "slam", "charge", "summon", "teleport"]
const RANGED := ["radial", "spiral", "fan", "mines"]

const NAME_START := ["Gor", "Vel", "Mor", "Zar", "Ul", "Kra", "Thal", "Nyx", "Brak", "Sil", "Dra", "Oth", "Vor", "Esk", "Gul"]
const NAME_END := ["rak", "goth", "anis", "ul", "mora", "thar", "ix", "veth", "dun", "ra", "zul", "on", "grim", "eth"]
const ADJ := ["Hollow", "Rotting", "Burning", "Drowned", "Hungering", "Shattered", "Pale", "Bloated", "Weeping", "Iron", "Ashen", "Howling", "Thousand-Eyed", "Sleepless"]
const NOUN := ["King", "Tyrant", "Mother", "Colossus", "Warden", "Maw", "Prophet", "Horror", "Abomination", "Knight", "Queen", "Beast", "Devourer", "Shepherd"]


static func generate(depth: int, rng: RandomNumberGenerator, minions: Array) -> Dictionary:
	var boss_name: String = NAME_START[rng.randi() % NAME_START.size()] + NAME_END[rng.randi() % NAME_END.size()]
	var title: String = "%s, the %s %s" % [boss_name, ADJ[rng.randi() % ADJ.size()], NOUN[rng.randi() % NOUN.size()]]

	var count := mini(2 + int(depth / 20.0), ATTACKS.size())
	var pool := ATTACKS.duplicate()
	# Shuffle with our rng so the whole floor stays reproducible from one seed.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var attacks: Array = pool.slice(0, count)
	var has_ranged := false
	for a in attacks:
		if a in RANGED:
			has_ranged = true
	if not has_ranged:
		attacks[0] = RANGED[rng.randi() % RANGED.size()]

	var hue := rng.randf()
	return {
		"title": title,
		"attacks": attacks,
		"minion": minions[rng.randi() % minions.size()] if not minions.is_empty() else "slime",
		"hp_mult": rng.randf_range(0.85, 1.2),
		"speed": rng.randf_range(18.0, 32.0),
		"radius": rng.randf_range(12.0, 17.0),
		"color": Color.from_hsv(hue, rng.randf_range(0.45, 0.8), rng.randf_range(0.55, 0.85)),
		"glow": Color.from_hsv(fmod(hue + 0.5, 1.0), 0.7, 1.0),
		"body": ["round", "spiky", "blob"][rng.randi() % 3],
		"horns": rng.randf() < 0.5,
		"crown": rng.randf() < 0.4,
		"eyes": rng.randi_range(1, 4),
		"spikes": rng.randi_range(0, 8),
	}
