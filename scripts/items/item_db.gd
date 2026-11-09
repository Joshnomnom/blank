class_name ItemDB
extends RefCounted
## Item definitions (Phase 4 step 1: bag screen + real part stats + chips).
## Research: docs/research/WEAPONS_BALANCE_EQUIPMENT.md §4 (slots, rarity, affixes),
##           docs/research/LOOT_ECONOMY_CHIPS.md §3 (chip power budget, caps).
##
## Items are plain Dictionaries (easy to save later as JSON):
##   part: {"kind": "part", "uid", "slot", "rarity", "name",
##          "main": {"key", "value"}, "affixes": [{"key", "value"}], "sockets": int, "chips": [chip]}
##   chip: {"kind": "chip", "uid", "source", "name", "rarity", "slot" ("Any" or a part slot),
##          "stats": [{"key", "value"}], "unique": bool, "remove_cost": int}
## Stat values are percent unless the stat says otherwise (max_hp = flat HP, repair = HP/s).

const SLOTS := ["Engine", "Tires", "Suspension", "Armor Plate", "Nitro", "Module"]

## Stat key -> label, unit ("%", "" flat, "/s"), and the cap on the car's TOTAL (0 = no cap).
const STATS := {
	"top_speed": {"label": "Top Speed", "unit": "%", "cap": 0.0},
	"accel": {"label": "Acceleration", "unit": "%", "cap": 0.0},
	"grip": {"label": "Grip", "unit": "%", "cap": 0.0},
	"handling": {"label": "Handling", "unit": "%", "cap": 0.0},
	"max_hp": {"label": "Max HP", "unit": "", "cap": 0.0},
	"armor": {"label": "Damage Reduction", "unit": "%", "cap": 50.0},
	"kb_resist": {"label": "Knockback Resist", "unit": "%", "cap": 60.0},
	"repair": {"label": "Field Repair", "unit": " HP/s", "cap": 0.0},
	"nitro_regen": {"label": "Nitro Recharge", "unit": "%", "cap": 100.0},
	"nitro_power": {"label": "Dash Power", "unit": "%", "cap": 40.0},
	"damage": {"label": "All Damage", "unit": "%", "cap": 0.0},
	"kinetic_dmg": {"label": "Kinetic Damage", "unit": "%", "cap": 30.0},
	"explosive_dmg": {"label": "Explosive Damage", "unit": "%", "cap": 30.0},
	"blast_radius": {"label": "Blast Radius", "unit": "%", "cap": 40.0},
}

## Main stat of each slot, value by rarity (Common..Legendary).
const MAIN_STATS := {
	"Engine": {"key": "top_speed", "values": [3.0, 5.0, 7.0, 9.0, 12.0]},
	"Tires": {"key": "grip", "values": [4.0, 6.0, 9.0, 12.0, 15.0]},
	"Suspension": {"key": "kb_resist", "values": [10.0, 15.0, 20.0, 25.0, 30.0]},
	"Armor Plate": {"key": "max_hp", "values": [60.0, 100.0, 150.0, 200.0, 260.0]},
	"Nitro": {"key": "nitro_regen", "values": [10.0, 15.0, 20.0, 25.0, 30.0]},
	"Module": {"key": "repair", "values": [3.0, 5.0, 7.0, 9.0, 12.0]},
}

## Random bonus lines: [min, max] at Common; scaled × (1 + 0.25 × rarity).
const AFFIXES := {
	"top_speed": [1.0, 3.0],
	"accel": [2.0, 4.0],
	"grip": [2.0, 4.0],
	"handling": [2.0, 4.0],
	"max_hp": [20.0, 50.0],
	"armor": [2.0, 4.0],
	"kb_resist": [3.0, 6.0],
	"repair": [0.5, 1.5],
	"damage": [2.0, 5.0],
	"kinetic_dmg": [3.0, 6.0],
	"explosive_dmg": [3.0, 6.0],
	"nitro_regen": [3.0, 6.0],
	"nitro_power": [3.0, 6.0],
}

## One chip per monster type (LOOT_ECONOMY_CHIPS.md §3.4): flat / conditional / trade-off / boss.
const CHIPS := {
	&"scrap_drone": {"name": "Scrap Drone Chip", "slot": "Tires",
		"stats": [["handling", 4.0]], "unique": false, "remove_cost": 50},
	&"raider_gunner": {"name": "Raider Gunner Chip", "slot": "Module",
		"stats": [["kinetic_dmg", 10.0]], "unique": false, "remove_cost": 80},
	&"iron_hauler": {"name": "Iron Hauler Chip", "slot": "Armor Plate",
		"stats": [["max_hp", 120.0], ["top_speed", -4.0]], "unique": false, "remove_cost": 150},
	&"dune_tyrant": {"name": "Dune Tyrant Chip", "slot": "Any",
		"stats": [["explosive_dmg", 12.0], ["blast_radius", 20.0]], "unique": true, "remove_cost": 400},
}

const PREFIXES := ["Rusty", "Salvaged", "Tuned", "Military", "Prototype"]

static var _next_uid: int = 1


static func new_uid() -> int:
	_next_uid += 1
	return _next_uid


static func make_part(slot: String, rarity: int) -> Dictionary:
	var main_def: Dictionary = MAIN_STATS[slot]
	var main_key: String = main_def["key"]
	var affixes: Array = []
	var pool: Array = AFFIXES.keys()
	pool.shuffle()
	var count := mini(rarity, 3)
	for key in pool:
		if affixes.size() >= count:
			break
		if key == main_key:
			continue
		var r: Array = AFFIXES[key]
		var v := randf_range(r[0], r[1]) * (1.0 + 0.25 * rarity)
		affixes.append({"key": key, "value": _round_stat(key, v)})
	var sockets := 0
	match rarity:
		Loot.Rarity.UNCOMMON: sockets = 1 if randf() < 0.5 else 0
		Loot.Rarity.RARE: sockets = 1
		Loot.Rarity.EPIC: sockets = 1 if randf() < 0.5 else 2
		Loot.Rarity.LEGENDARY: sockets = 2
	return {
		"kind": "part", "uid": new_uid(), "slot": slot, "rarity": rarity,
		"name": "%s %s" % [PREFIXES[rarity], slot], "base_name": "%s %s" % [PREFIXES[rarity], slot], "tune": 0,
		"main": {"key": main_key, "value": (main_def["values"] as Array)[rarity]},
		"affixes": affixes, "sockets": sockets, "chips": [],
	}


static func make_random_part(rarity: int) -> Dictionary:
	return make_part(SLOTS[randi() % SLOTS.size()], rarity)


static func make_chip(source: StringName) -> Dictionary:
	var def: Dictionary = CHIPS.get(source, {})
	if def.is_empty():
		return {}
	var stats: Array = []
	for s in def["stats"]:
		stats.append({"key": s[0], "value": s[1]})
	return {
		"kind": "chip", "uid": new_uid(), "source": source, "name": def["name"],
		"rarity": Loot.Rarity.EPIC, "slot": def["slot"], "stats": stats,
		"unique": def["unique"], "remove_cost": def["remove_cost"],
	}


## All stat lines of a part including its inserted chips: Array of {"key", "value"}.
static func part_lines(part: Dictionary, include_chips: bool = true) -> Array:
	var main: Dictionary = part["main"]
	var mult := 1.0 + TUNE_MAIN_PER_LEVEL * tune_level(part)
	var lines: Array = [{"key": main["key"], "value": float(main["value"]) * mult}]
	lines.append_array(part["affixes"])
	if include_chips:
		for chip in part["chips"]:
			lines.append_array(chip["stats"])
	return lines


## Sum of stat lines -> {key: total}.
static func sum_lines(lines: Array, into: Dictionary) -> Dictionary:
	for l in lines:
		into[l["key"]] = into.get(l["key"], 0.0) + float(l["value"])
	return into


static func chip_fits(chip: Dictionary, part: Dictionary) -> bool:
	return chip["slot"] == "Any" or chip["slot"] == part["slot"]


static func format_line(key: String, value: float, signed: bool = true) -> String:
	var def: Dictionary = STATS.get(key, {"label": key, "unit": ""})
	var num := ("%.1f" % value) if key == "repair" else str(roundi(value))
	if signed and value >= 0.0:
		num = "+" + num
	return "%s %s%s" % [def["label"], num, def["unit"]]


static func _round_stat(key: String, v: float) -> float:
	return snappedf(v, 0.5) if key == "repair" else float(roundi(v))


# --- Tuning +1..+10 (garage; research WEAPONS_BALANCE_EQUIPMENT.md §4.4) -----
## Each + adds this fraction of a part's MAIN stat (+10 = +60%).
const TUNE_MAIN_PER_LEVEL := 0.06
## Each + adds this fraction of a gun's damage (+10 = +30%).
const TUNE_GUN_PER_LEVEL := 0.03
const TUNE_MAX := 10
## Success chance by TARGET level (index = target). Up to +4 is safe.
const TUNE_CHANCE := [1.0, 1.0, 1.0, 1.0, 1.0, 0.8, 0.65, 0.5, 0.35, 0.25, 0.15]
## Failure = lose 1 level. Failing an attempt at this target level or higher can BREAK a part.
const TUNE_BREAK_FROM := 8
const TUNE_BREAK_CHANCE := 0.25


static func tune_level(item: Dictionary) -> int:
	return int(item.get("tune", 0))


## Scrap cost of the next attempt: 50 × target² × (1 + 0.5 × rarity).
static func tune_cost(item: Dictionary) -> int:
	var target := tune_level(item) + 1
	return roundi(50.0 * target * target * (1.0 + 0.5 * int(item.get("rarity", 0))))


static func tune_chance(item: Dictionary) -> float:
	var target := tune_level(item) + 1
	return TUNE_CHANCE[target] if target <= TUNE_MAX else 0.0


static func can_break(item: Dictionary) -> bool:
	return item.get("kind") == "part" and tune_level(item) + 1 >= TUNE_BREAK_FROM


## "+3 Tuned Engine". Updates item["name"].
static func refresh_name(item: Dictionary) -> void:
	var base: String = item.get("base_name", "")
	if base == "":
		base = item["name"]
		item["base_name"] = base
	var t := tune_level(item)
	item["name"] = ("+%d %s" % [t, base]) if t > 0 else base


# --- Guns as owned items (garage loadout) -------------------------------------
const GUNS := {
	"machine_gun": {"name": "Machine Gun"},
	"rocket_launcher": {"name": "Rocket Launcher"},
}


static func make_gun(id: String) -> Dictionary:
	var def: Dictionary = GUNS[id]
	return {"kind": "gun", "uid": new_uid(), "id": id, "name": def["name"], "base_name": def["name"],
		"rarity": Loot.Rarity.RARE, "tune": 0}


## Fresh WeaponData for an owned gun, with its tuning applied.
static func gun_weapon_data(gun: Dictionary) -> WeaponData:
	var w: WeaponData
	match String(gun["id"]):
		"rocket_launcher": w = WeaponData.make_rocket_launcher()
		_: w = WeaponData.make_machine_gun()
	w.damage *= 1.0 + TUNE_GUN_PER_LEVEL * tune_level(gun)
	w.display_name = gun["name"]
	return w
