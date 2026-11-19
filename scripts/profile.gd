class_name Profile
extends RefCounted
## Progress kept between runs (shared by all save slots): Soul Shards, unlocks bought
## at the Soul Altar, best depths, daily-run records and whether the tutorial was seen.

const PATH := "user://profile.json"

## Soul Altar unlocks. Weapons marked here are hidden from a class's finds until bought.
const UNLOCKS := {
	"w_greataxe": {"name": "Greataxe", "desc": "Fighters can find the Greataxe", "cost": 25},
	"w_rapier": {"name": "Rapier", "desc": "Rogues can find the Rapier", "cost": 25},
	"w_crossbow": {"name": "Crossbow", "desc": "Archers can find the Crossbow", "cost": 25},
	"w_grimoire": {"name": "Storm Grimoire", "desc": "Mages can find the Storm Grimoire", "cost": 25},
	"deep_pockets": {"name": "Deep Pockets", "desc": "Start every run with 40 gold", "cost": 20},
	"haggler": {"name": "Haggler", "desc": "Trader prices -20%", "cost": 35},
	"fortune": {"name": "Fortune's Eye", "desc": "Floor events 50% more common", "cost": 35},
	"heirloom": {"name": "Heirloom", "desc": "Start with 1 random blessing", "cost": 45},
	"soul_anchor": {"name": "Soul Anchor", "desc": "Once per run, revive at half health", "cost": 120},
	"shortcut_11": {"name": "Shortcut: Depth 11", "desc": "May start at depth 11 (+3 blessings)", "cost": 80},
	"shortcut_21": {"name": "Shortcut: Depth 21", "desc": "May start at depth 21 (+6 blessings)", "cost": 160, "requires": "shortcut_11"},
}
const LOCKED_WEAPONS := {"greataxe": "w_greataxe", "rapier": "w_rapier", "crossbow": "w_crossbow", "grimoire": "w_grimoire"}

static var data := {}
static var path_override := ""


static func _path() -> String:
	return path_override if path_override != "" else PATH


static func load_profile() -> void:
	data = {"shards": 0, "unlocks": {}, "best_depth": 0, "daily": {}, "tutorial_done": false, "runs": 0, "materials": {}, "crafted": {}}
	if FileAccess.file_exists(_path()):
		var f := FileAccess.open(_path(), FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f else null
		if d is Dictionary:
			data.merge(d, true)


static func save() -> void:
	var f := FileAccess.open(_path(), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


static func has(unlock: String) -> bool:
	return data.get("unlocks", {}).get(unlock, false)


static func weapon_unlocked(weapon: String) -> bool:
	return not LOCKED_WEAPONS.has(weapon) or has(LOCKED_WEAPONS[weapon])


static func can_buy(unlock: String) -> bool:
	var u: Dictionary = UNLOCKS[unlock]
	if has(unlock) or int(data["shards"]) < int(u["cost"]):
		return false
	return not u.has("requires") or has(u["requires"])


static func buy(unlock: String) -> bool:
	if not can_buy(unlock):
		return false
	data["shards"] = int(data["shards"]) - int(UNLOCKS[unlock]["cost"])
	data["unlocks"][unlock] = true
	save()
	return true


## Shards earned when a run ends.
static func shards_for(depth: int, bosses: int, kills: int) -> int:
	return depth * 2 + bosses * 15 + int(kills / 10.0)


static func add_shards(n: int) -> void:
	data["shards"] = int(data["shards"]) + n
	data["runs"] = int(data.get("runs", 0)) + 1
	save()


## ---- Workshop: extracted monster parts and crafted upgrades.

static func mat_count(id: String) -> int:
	return int(data.get("materials", {}).get(id, 0))


static func add_materials(bag: Dictionary) -> void:
	if not data.has("materials"):
		data["materials"] = {}
	for k in bag:
		data["materials"][k] = mat_count(k) + int(bag[k])
	save()


static func crafted_level(recipe: String) -> int:
	return int(data.get("crafted", {}).get(recipe, 0))


static func can_craft(recipe: String) -> bool:
	var lv := crafted_level(recipe)
	if not Materials.endless(recipe) and lv >= int(Materials.RECIPES[recipe]["max"]):
		return false
	var cost := Materials.cost_for(recipe, lv)
	for k in cost:
		if mat_count(k) < int(cost[k]):
			return false
	return true


static func craft(recipe: String) -> bool:
	if not can_craft(recipe):
		return false
	var cost := Materials.cost_for(recipe, crafted_level(recipe))
	for k in cost:
		data["materials"][k] = mat_count(k) - int(cost[k])
	if not data.has("crafted"):
		data["crafted"] = {}
	data["crafted"][recipe] = crafted_level(recipe) + 1
	save()
	return true


static func today() -> String:
	return Time.get_date_string_from_system()


static func daily_best() -> int:
	return int(data["daily"].get(today(), 0))


static func record_daily(depth: int) -> void:
	data["daily"][today()] = maxi(daily_best(), depth)
	save()
