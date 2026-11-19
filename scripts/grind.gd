class_name Grind
extends RefCounted
## Long-term progression for endless play: Heat levels, the Monster Codex, the Bounty Board
## and the Weekly Mutator run. Progress lives in Profile.data (saved with the profile).

# ------------------------------------------------------------------ heat

## Heat chosen on the class page for the next run (0 = normal). Daily / weekly runs ignore it.
static var selected_heat := 0
## Set by the menu just before a weekly run starts (read and cleared by main).
static var pending_weekly := false
## Reach this depth on your highest heat to unlock the next one.
const HEAT_UNLOCK_DEPTH := 10


static func heat_max() -> int:
	return int(Profile.data.get("heat_max", 0))


## Called when a floor is reached: unlocks the next heat level, records best depth per heat.
## Returns true if a new heat level was unlocked.
static func on_depth(heat: int, depth: int, floors_done := 99) -> bool:
	var best: Dictionary = Profile.data.get("best_by_heat", {})
	var key := str(heat)
	best[key] = maxi(int(best.get(key, 0)), depth)
	Profile.data["best_by_heat"] = best
	if heat == heat_max() and depth >= HEAT_UNLOCK_DEPTH and floors_done >= HEAT_UNLOCK_DEPTH:
		Profile.data["heat_max"] = heat + 1
		return true
	return false


static func best_at_heat(heat: int) -> int:
	return int(Profile.data.get("best_by_heat", {}).get(str(heat), 0))


static func heat_desc(h: int) -> String:
	if h <= 0:
		return "Normal"
	var parts := ["foes +%d%% HP" % (h * 15), "+%d%% elites" % (h * 4)]
	if h >= 3:
		parts.append("foes hit harder")
	if h >= 4:
		parts.append("%d starting curse%s" % [curses_for(h), "s" if curses_for(h) > 1 else ""])
	return "Heat %d: %s.  Rewards +%d%% shards, +%d%% parts, stronger gear" % [h, ", ".join(parts), h * 25, h * 15]


static func curses_for(h: int) -> int:
	return int(h / 4)


# ------------------------------------------------------------------ codex

## Kills needed for each codex tier (bosses need far fewer).
const CODEX_TIERS := [50, 250, 1000]
const BOSS_TIERS := [5, 25, 100]
const CODEX_KINDS := ["slime", "bat", "spider", "skeleton", "bomber", "ghost", "wisp", "cultist", "brute", "golem", "boss"]
const KIND_NAMES := {
	"slime": "Slime", "bat": "Bat", "spider": "Spider", "skeleton": "Skeleton", "bomber": "Bomber",
	"ghost": "Ghost", "wisp": "Wisp", "cultist": "Cultist", "brute": "Brute", "golem": "Golem", "boss": "Boss",
}
## Damage bonus against a kind per codex tier.
const CODEX_DAMAGE := 0.06


static func codex_kills(kind: String) -> int:
	return int(Profile.data.get("codex", {}).get(kind, 0))


static func tiers_for(kind: String) -> Array:
	return BOSS_TIERS if kind == "boss" else CODEX_TIERS


static func codex_tier(kind: String) -> int:
	var k := codex_kills(kind)
	var t := 0
	for need in tiers_for(kind):
		if k >= int(need):
			t += 1
	return t


## Counts a kill. Returns the new tier if this kill reached one, else 0.
static func record_kill(kind: String) -> int:
	if kind == "slimelet":
		kind = "slime"
	if not kind in CODEX_KINDS:
		return 0
	var codex: Dictionary = Profile.data.get("codex", {})
	var before := codex_tier(kind)
	codex[kind] = int(codex.get(kind, 0)) + 1
	Profile.data["codex"] = codex
	var after := codex_tier(kind)
	return after if after > before else 0


static func codex_bonus(kind: String) -> float:
	if kind == "slimelet":
		kind = "slime"
	return 1.0 + CODEX_DAMAGE * codex_tier(kind)


static func tier_reward_text(kind: String, tier: int) -> String:
	var dmg := "+%d%% damage vs %ss" % [int(CODEX_DAMAGE * 100 * tier), KIND_NAMES[kind]]
	match tier:
		2:
			return dmg + ", unlocks a new eye glow"
		3:
			return dmg + ", unlocks a new ghost colour"
	return dmg


# ------------------------------------------------------------------ bounties

## type -> description pattern. "kill" keys are monster kinds.
const BOUNTY_TYPES := ["kill", "elites", "bosses", "depth", "send_parts", "idol", "rare_gear", "heat_depth"]


static func bounties() -> Array:
	var b: Array = Profile.data.get("bounties", [])
	while b.size() < 3:
		b.append(_new_bounty(b))
	Profile.data["bounties"] = b
	return b


static func _new_bounty(existing: Array) -> Dictionary:
	var taken := existing.map(func(x: Dictionary) -> String: return String(x["type"]) + String(x.get("key", "")))
	var best := maxi(10, int(Profile.data.get("best_depth", 0)))
	for attempt in 30:
		var t: String = BOUNTY_TYPES[randi() % BOUNTY_TYPES.size()]
		var b := {"type": t, "key": "", "goal": 1, "progress": 0}
		var diff := 1.0 # bigger goals pay more
		match t:
			"kill":
				var unlocked := ["slime", "bat", "spider", "skeleton", "bomber", "wisp", "ghost", "brute", "cultist", "golem"]
				var k: String = unlocked[randi() % mini(unlocked.size(), 3 + int(best / 3))]
				b["key"] = k
				b["goal"] = [40, 60, 80, 120][randi() % 4] if not k in ["brute", "golem", "cultist"] else [15, 25, 35][randi() % 3]
				b["desc"] = "Slay %d %ss" % [b["goal"], KIND_NAMES[k]]
				diff = b["goal"] / 60.0
			"elites":
				b["goal"] = [10, 15, 25][randi() % 3]
				b["desc"] = "Slay %d elite monsters" % b["goal"]
				diff = b["goal"] / 12.0
			"bosses":
				b["goal"] = [2, 3, 5][randi() % 3]
				b["desc"] = "Devour %d bosses" % b["goal"]
				diff = b["goal"] / 2.0
			"depth":
				b["goal"] = int(ceil(best * randf_range(0.7, 1.1) / 5.0)) * 5
				b["desc"] = "Reach depth %d in one run" % b["goal"]
				diff = b["goal"] / 15.0
			"send_parts":
				b["goal"] = [30, 50, 80][randi() % 3]
				b["desc"] = "Send %d monster parts up the Loot Lift" % b["goal"]
				diff = b["goal"] / 40.0
			"idol":
				b["goal"] = [5, 8, 12][randi() % 3]
				b["desc"] = "Pull a Cursed Idol's lever %d times" % b["goal"]
				diff = b["goal"] / 7.0
			"rare_gear":
				b["goal"] = [3, 5][randi() % 2]
				b["desc"] = "Find %d rare or legendary gear pieces" % b["goal"]
				diff = b["goal"] / 3.0
			"heat_depth":
				if heat_max() < 1:
					continue
				var h := 1 + randi() % heat_max()
				b["key"] = str(h)
				b["goal"] = 10 + 5 * (randi() % 3)
				b["desc"] = "Reach depth %d on Heat %d or higher" % [b["goal"], h]
				diff = b["goal"] / 10.0 * (1.0 + h * 0.3)
		if (t + String(b["key"])) in taken:
			continue
		b["reward"] = _reward(diff)
		return b
	return {"type": "elites", "key": "", "goal": 10, "progress": 0, "desc": "Slay 10 elite monsters", "reward": _reward(1.0)}


static func _reward(diff: float) -> Dictionary:
	var parts := {}
	var pool := Materials.ORDER.duplicate()
	pool.erase("heart")
	pool.shuffle()
	for i in 3:
		parts[pool[i]] = int(round(randf_range(6, 12) * maxf(0.8, diff)))
	if diff >= 1.5 and randf() < 0.5:
		parts["heart"] = 1
	return {"parts": parts, "shards": int(round(20 * maxf(0.8, diff)))}


static func reward_text(r: Dictionary) -> String:
	return "%s + %d shards" % [Materials.describe(r.get("parts", {})), int(r.get("shards", 0))]


## Adds progress to every matching bounty. "set" types keep the highest value.
## Returns descriptions of bounties that just got completed.
static func bounty_progress(type: String, amount := 1, key := "", heat := 0) -> Array:
	var done := []
	for b in bounties():
		if b["type"] != type or b.get("claimable", false):
			continue
		if type == "kill" and b["key"] != key:
			continue
		if type == "heat_depth" and heat < int(b["key"]):
			continue
		if type == "depth" or type == "heat_depth":
			b["progress"] = maxi(int(b["progress"]), amount)
		else:
			b["progress"] = int(b["progress"]) + amount
		if int(b["progress"]) >= int(b["goal"]):
			b["progress"] = b["goal"]
			b["claimable"] = true
			done.append(b["desc"])
	return done


static func claim(i: int) -> bool:
	var b: Array = bounties()
	if i >= b.size() or not b[i].get("claimable", false):
		return false
	var r: Dictionary = b[i]["reward"]
	Profile.add_materials(r.get("parts", {}))
	Profile.data["shards"] = int(Profile.data.get("shards", 0)) + int(r.get("shards", 0))
	b.remove_at(i)
	b.insert(i, _new_bounty(b))
	Profile.save()
	return true


const REROLL_COST := 5


static func reroll(i: int) -> bool:
	var b: Array = bounties()
	if int(Profile.data.get("shards", 0)) < REROLL_COST or b[i].get("claimable", false):
		return false
	Profile.data["shards"] = int(Profile.data["shards"]) - REROLL_COST
	var others := b.duplicate()
	others.remove_at(i)
	b[i] = _new_bounty(others)
	Profile.save()
	return true


# ------------------------------------------------------------------ weekly mutator run

const WEEKLY_SLOT := 4
const MUTATORS := {
	"glass": {"name": "Glass Ghosts", "desc": "you deal double damage but have half the health"},
	"gamblers": {"name": "Gambler's Den", "desc": "a Cursed Idol on every floor"},
	"elite_horde": {"name": "Elite Horde", "desc": "half of all monsters are elites"},
	"frenzy": {"name": "Frenzy", "desc": "everyone moves 30% faster"},
	"bloodless": {"name": "Bloodless", "desc": "no hearts drop, but kills may heal you"},
	"loaded": {"name": "Loaded Dice", "desc": "gear drops three times as often"},
	"night": {"name": "Eternal Night", "desc": "every floor is dark"},
}


## Weeks since 1970 (changes every Thursday 00:00 UTC; same for everyone).
static func week_id() -> int:
	return int(Time.get_unix_time_from_system() / (7.0 * 86400.0))


## This week's two mutators (the same for everyone).
static func weekly_mutators(week := -1) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = (week if week >= 0 else week_id()) * 7919 + 13
	var keys := MUTATORS.keys()
	var a: String = keys[r.randi() % keys.size()]
	var b: String = a
	while b == a:
		b = keys[r.randi() % keys.size()]
	return [a, b]


static func mutator_text(list: Array) -> String:
	var lines := []
	for m in list:
		lines.append("%s: %s" % [MUTATORS[m]["name"], MUTATORS[m]["desc"]])
	return "\n".join(lines)


static func weekly_best() -> int:
	return int(Profile.data.get("weekly", {}).get(str(week_id()), 0))


static func record_weekly(depth: int) -> void:
	var w: Dictionary = Profile.data.get("weekly", {})
	w[str(week_id())] = maxi(int(w.get(str(week_id()), 0)), depth)
	Profile.data["weekly"] = w
