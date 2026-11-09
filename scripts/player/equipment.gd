class_name Equipment
extends Node
## Phase 4 step 1: equipped car parts + chips -> real stats on the car, HP and guns.
## Created by PlayerStatus (child "Equipment"). The bag (PlayerStatus.items) holds
## unequipped parts and loose chips; equipped parts live here, one per ItemDB.SLOTS slot.
##
## Stats are applied as changes from the car's BASE values (captured once at start):
##   top_speed %, accel %, grip % (grip_turn), handling % (turn_rate + drift_turn_rate),
##   max_hp flat, armor % damage reduction, kb_resist % knockback reduction,
##   repair HP/s (after repair_delay s without damage), damage % (all guns),
##   kinetic_dmg / explosive_dmg % (by gun damage type), blast_radius % (rockets).
## Totals are capped per ItemDB.STATS[key].cap (LOOT_ECONOMY_CHIPS.md §3.4).
##
## Garage (town only, GarageScreen): gun LOADOUT (owned guns -> gun_slots mounted, Q/E order),
## TUNING +1..+10 of parts and guns (ItemDB tuning rules), BODY KITS (visual only, SedanModel).

signal changed

var equipped: Dictionary = {}   # slot -> part Dictionary
var totals: Dictionary = {}     # stat key -> capped total

## Gun mount slots on this chassis (sedan: 2 roof guns, swapped with Q/E).
@export var gun_slots: int = 2
var guns: Array = []            # owned guns (ItemDB.make_gun dicts)
var mounted: Array = []         # gun uids per slot (-1 = empty), size gun_slots

## Body kits: category -> option index (SedanModel.KITS / PAINTS). Owned = bought once.
var kits: Dictionary = {"paint": 0, "front": 0, "rear": 0, "roof": 0, "side": 0}
var owned_kits: Dictionary = {}  # "category:index" -> true

var _status: PlayerStatus
var _car: CarController
var _weapons: WeaponController
var _base := {}


func setup(status: PlayerStatus) -> void:
	_status = status
	_car = status.get_parent() as CarController
	_weapons = _car.get_node_or_null("Weapons") as WeaponController
	_base = {
		"top_speed": _car.top_speed,
		"accel_max": _car.accel_max,
		"grip_turn": _car.grip_turn,
		"turn_rate": _car.turn_rate,
		"drift_turn_rate": _car.drift_turn_rate,
		"max_hp": status.max_hp,
	}
	# Starting guns: both owned and mounted (the old fixed loadout).
	guns = [ItemDB.make_gun("machine_gun"), ItemDB.make_gun("rocket_launcher")]
	mounted = []
	for i in gun_slots:
		mounted.append(guns[i]["uid"] if i < guns.size() else -1)
	_apply()
	_apply_kits()


# --- Gun loadout ----------------------------------------------------------------

func get_gun(uid: int) -> Dictionary:
	for g in guns:
		if g["uid"] == uid:
			return g
	return {}


func mounted_count() -> int:
	return mounted.filter(func(u): return u != -1).size()


## Put an owned gun into slot i (if it's already mounted elsewhere, the two slots swap).
func mount_gun(uid: int, slot: int) -> void:
	if slot < 0 or slot >= gun_slots or get_gun(uid).is_empty():
		return
	var old_slot := mounted.find(uid)
	if old_slot >= 0:
		mounted[old_slot] = mounted[slot]
	mounted[slot] = uid
	_apply_loadout()


## Empty slot i. At least one gun must stay mounted.
func unmount_gun(slot: int) -> void:
	if slot < 0 or slot >= gun_slots or mounted[slot] == -1 or mounted_count() <= 1:
		return
	mounted[slot] = -1
	_apply_loadout()


func _apply_loadout() -> void:
	if _weapons:
		var list: Array[WeaponData] = []
		for uid in mounted:
			if uid != -1:
				list.append(ItemDB.gun_weapon_data(get_gun(uid)))
		_weapons.set_loadout(list)
	changed.emit()


# --- Tuning ---------------------------------------------------------------------

## Every tunable item: guns, equipped parts, bag parts.
func tunables() -> Array:
	var list: Array = guns.duplicate()
	for slot in ItemDB.SLOTS:
		if equipped.has(slot):
			list.append(equipped[slot])
	for item in _status.items:
		if item["kind"] == "part":
			list.append(item)
	return list


func is_equipped(item: Dictionary) -> bool:
	return equipped.values().has(item)


## One tuning attempt. Returns "success", "fail", "broken", or "" (not possible).
## Failure = −1 level. At +8 and up a failed PART can break (its chips go back to the bag).
func tune(item: Dictionary) -> String:
	var level := ItemDB.tune_level(item)
	if level >= ItemDB.TUNE_MAX:
		return ""
	var cost := ItemDB.tune_cost(item)
	if _status.scrap < cost:
		return ""
	_status.scrap -= cost
	var result := "success"
	if randf() < ItemDB.tune_chance(item):
		item["tune"] = level + 1
	elif ItemDB.can_break(item) and randf() < ItemDB.TUNE_BREAK_CHANCE:
		result = "broken"
		_destroy_part(item)
	else:
		result = "fail"
		item["tune"] = maxi(level - 1, 0)
	ItemDB.refresh_name(item)
	if item["kind"] == "gun":
		_apply_loadout()
	_apply()
	return result


func _destroy_part(part: Dictionary) -> void:
	for chip in part["chips"]:
		_status.items.append(chip)
	part["chips"] = []
	var slot: String = part["slot"]
	if equipped.get(slot) == part:
		equipped.erase(slot)
	else:
		var i := _status.items.find(part)
		if i >= 0:
			_status.items.remove_at(i)


# --- Body kits (visual only) ------------------------------------------------------

func kit_owned(category: String, index: int) -> bool:
	return index == 0 or owned_kits.has("%s:%d" % [category, index])


## Buy (if not owned yet) and apply. Returns false if not enough scrap.
func set_kit(category: String, index: int) -> bool:
	if not kit_owned(category, index):
		var cost := SedanModel.kit_cost(category, index)
		if _status.scrap < cost:
			return false
		_status.scrap -= cost
		owned_kits["%s:%d" % [category, index]] = true
	kits[category] = index
	_apply_kits()
	changed.emit()
	return true


func _apply_kits() -> void:
	var model := _car.get_node_or_null("Model") as SedanModel
	if model:
		for category in kits:
			model.set_kit(category, kits[category])


func get_part(slot: String) -> Dictionary:
	return equipped.get(slot, {})


## Bag part -> its slot. The part that was there goes back to the bag.
func equip(part: Dictionary) -> void:
	var items := _status.items
	var i := items.find(part)
	if i < 0 or part.get("kind") != "part":
		return
	items.remove_at(i)
	var slot: String = part["slot"]
	if equipped.has(slot):
		items.append(equipped[slot])
	equipped[slot] = part
	_apply()


func unequip(slot: String) -> void:
	if not equipped.has(slot):
		return
	_status.items.append(equipped[slot])
	equipped.erase(slot)
	_apply()


## Why a chip can't go into a part ("" = it can).
func chip_block_reason(chip: Dictionary, part: Dictionary) -> String:
	if not ItemDB.chip_fits(chip, part):
		return "Only fits: %s" % chip["slot"]
	if (part["chips"] as Array).size() >= int(part["sockets"]):
		return "No free socket"
	if chip.get("unique", false):
		for p in equipped.values():
			for c in p["chips"]:
				if c["source"] == chip["source"]:
					return "Unique: one active"
	return ""


## Loose chip from the bag -> a socket of an EQUIPPED part. Inserting is free.
func insert_chip(chip: Dictionary, slot: String) -> bool:
	var part := get_part(slot)
	if part.is_empty() or chip_block_reason(chip, part) != "":
		return false
	var i := _status.items.find(chip)
	if i < 0:
		return false
	_status.items.remove_at(i)
	(part["chips"] as Array).append(chip)
	_apply()
	return true


## Chip out of an equipped part -> bag. Costs scrap (a scrap sink, LOOT_ECONOMY_CHIPS.md §2.3).
func remove_chip(slot: String, index: int) -> bool:
	var part := get_part(slot)
	if part.is_empty() or index < 0 or index >= (part["chips"] as Array).size():
		return false
	var chip: Dictionary = part["chips"][index]
	var cost: int = chip.get("remove_cost", 0)
	if _status.scrap < cost:
		return false
	_status.scrap -= cost
	(part["chips"] as Array).remove_at(index)
	_status.items.append(chip)
	_apply()
	return true


## Totals for a hypothetical setup (used by the bag to compare): equipped, with `part`
## replacing the part in its slot.
func totals_with(part: Dictionary) -> Dictionary:
	var sums := {}
	for slot in equipped:
		if not part.is_empty() and slot == part["slot"]:
			continue
		ItemDB.sum_lines(ItemDB.part_lines(equipped[slot]), sums)
	if not part.is_empty():
		ItemDB.sum_lines(ItemDB.part_lines(part), sums)
	return _capped(sums)


func _capped(sums: Dictionary) -> Dictionary:
	for key in sums:
		var cap: float = (ItemDB.STATS.get(key, {}) as Dictionary).get("cap", 0.0)
		if cap > 0.0:
			sums[key] = minf(sums[key], cap)
	return sums


func stat(key: String) -> float:
	return totals.get(key, 0.0)


func _apply() -> void:
	var sums := {}
	for part in equipped.values():
		ItemDB.sum_lines(ItemDB.part_lines(part), sums)
	totals = _capped(sums)

	# Car handling.
	_car.top_speed = _base["top_speed"] * (1.0 + stat("top_speed") / 100.0)
	_car.accel_max = _base["accel_max"] * (1.0 + stat("accel") / 100.0)
	_car.grip_turn = _base["grip_turn"] * (1.0 + stat("grip") / 100.0)
	_car.turn_rate = _base["turn_rate"] * (1.0 + stat("handling") / 100.0)
	_car.drift_turn_rate = _base["drift_turn_rate"] * (1.0 + stat("handling") / 100.0)
	_car.knockback_resist = stat("kb_resist") / 100.0
	if _car.nitro:
		_car.nitro.regen_mult = 1.0 + stat("nitro_regen") / 100.0
		_car.nitro.power_mult = 1.0 + stat("nitro_power") / 100.0

	# HP: a bigger max HP also adds the difference to current HP.
	var health := _status.health
	var new_max: float = _base["max_hp"] + stat("max_hp")
	var diff := new_max - health.max_hp
	health.max_hp = new_max
	if health.is_alive():
		health.hp = clampf(health.hp + maxf(diff, 0.0), 1.0, new_max)
	_status.damage_reduction = stat("armor") / 100.0
	_status.repair_rate = stat("repair")

	# Guns.
	if _weapons:
		_weapons.damage_bonus = stat("damage") / 100.0
		_weapons.type_bonus = {
			DamageTypes.Type.KINETIC: stat("kinetic_dmg") / 100.0,
			DamageTypes.Type.EXPLOSIVE: stat("explosive_dmg") / 100.0,
		}
		_weapons.blast_radius_mult = 1.0 + stat("blast_radius") / 100.0
	changed.emit()
