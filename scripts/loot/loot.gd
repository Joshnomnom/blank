class_name Loot
extends RefCounted
## Loot tables and rolls (Phase 3, start of the farming loop).
## Research: docs/research/WEAPONS_BALANCE_EQUIPMENT.md §4 (rarity, chips).
## Every kill: scrap (currency). Chance of a car PART with a rarity. Small chance of the
## enemy's CHIP (our version of Ragnarok cards). Items are plain dictionaries for now:
##   {"kind": "scrap", "amount": int}
##   {"kind": "part", "name": String, "slot": String, "rarity": Rarity}
##   {"kind": "chip", "name": String, "rarity": Rarity.EPIC, "source": StringName}
## Stats for parts/chips come in Phase 4 (RPG core).

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const RARITY_NAMES := ["Common", "Uncommon", "Rare", "Epic", "Legendary"]
const RARITY_COLORS := [
	Color(0.92, 0.92, 0.92),   # white
	Color(0.35, 0.9, 0.35),    # green
	Color(0.35, 0.6, 1.0),     # blue
	Color(0.75, 0.4, 1.0),     # purple
	Color(1.0, 0.6, 0.1),      # orange
]
## Base weights (percent) for Common..Legendary.
const RARITY_WEIGHTS := [70.0, 20.0, 8.0, 1.8, 0.2]
const PREFIXES := ["Rusty", "Salvaged", "Tuned", "Military", "Prototype"]
const SLOTS := ["Engine", "Tires", "Armor Plate", "Suspension", "Nitro Tank", "Turret Motor", "Radiator", "Gearbox"]


## rarity_bonus multiplies the weight of every rarity above Common (boss = big bonus).
static func roll_rarity(rarity_bonus: float) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for i in RARITY_WEIGHTS.size():
		var w: float = RARITY_WEIGHTS[i]
		if i > 0:
			w *= 1.0 + rarity_bonus
		weights.append(w)
		total += w
	var r := randf() * total
	for i in weights.size():
		r -= weights[i]
		if r <= 0.0:
			return i
	return Rarity.COMMON


static func roll(data: EnemyData) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	drops.append({"kind": "scrap", "amount": randi_range(data.scrap_min, data.scrap_max)})
	for i in data.item_rolls:
		if randf() < data.item_chance:
			var rarity := roll_rarity(data.rarity_bonus)
			var slot: String = SLOTS[randi() % SLOTS.size()]
			drops.append({"kind": "part", "slot": slot, "rarity": rarity,
				"name": "%s %s" % [PREFIXES[rarity], slot]})
	if randf() < data.chip_chance:
		drops.append({"kind": "chip", "rarity": Rarity.EPIC, "source": data.id,
			"name": "%s Chip" % data.display_name})
	return drops


static func drop(world: Node, pos: Vector3, data: EnemyData) -> void:
	for item in roll(data):
		Pickup.spawn(world, pos, item)
