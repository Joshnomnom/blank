class_name DamageTypes
extends RefCounted
## Damage types (on weapons) × armor types (on targets) -> damage multiplier.
## Our version of Ragnarok's element table: it makes Q/E gun swapping a real decision.
## Research: docs/research/WEAPONS_BALANCE_EQUIPMENT.md §3.4.
##
##                LIGHT  HEAVY  SHIELDED  ORGANIC
##   KINETIC      1.25   0.60   0.80      1.00     (machine gun, shotgun, rams)
##   EXPLOSIVE    1.00   1.30   0.80      1.00     (rockets, mines)
##   FIRE         1.00   0.70   0.60      1.50     (flamethrower - planned)
##   ENERGY       0.80   1.00   1.50      0.90     (railgun, tesla - planned)

enum Type { KINETIC, EXPLOSIVE, FIRE, ENERGY }
enum Armor { LIGHT, HEAVY, SHIELDED, ORGANIC }

const TABLE := [
	[1.25, 0.60, 0.80, 1.00],
	[1.00, 1.30, 0.80, 1.00],
	[1.00, 0.70, 0.60, 1.50],
	[0.80, 1.00, 1.50, 0.90],
]

## Multipliers above / below these count as "effective" / "resisted" for feedback colors.
const EFFECTIVE_THRESHOLD := 1.05
const RESISTED_THRESHOLD := 0.95

const TYPE_NAMES := ["KINETIC", "EXPLOSIVE", "FIRE", "ENERGY"]
const ARMOR_NAMES := ["LIGHT ARMOR", "HEAVY ARMOR", "SHIELDED", "ORGANIC"]
const TYPE_COLORS := [
	Color(0.85, 0.85, 0.85),   # kinetic - grey
	Color(1.0, 0.55, 0.2),     # explosive - orange
	Color(1.0, 0.35, 0.15),    # fire - red-orange
	Color(0.4, 0.8, 1.0),      # energy - cyan
]
const ARMOR_COLORS := [
	Color(0.85, 0.7, 0.5),     # light - tan
	Color(0.6, 0.7, 0.85),     # heavy - steel blue
	Color(0.4, 0.85, 1.0),     # shielded - cyan
	Color(0.6, 0.9, 0.4),      # organic - green
]


static func multiplier(damage_type: int, armor: int) -> float:
	return TABLE[damage_type][armor]


static func is_effective(mult: float) -> bool:
	return mult > EFFECTIVE_THRESHOLD


static func is_resisted(mult: float) -> bool:
	return mult < RESISTED_THRESHOLD
