class_name WeaponData
extends Resource
## Stats for one gun. Design: no special skills. Each gun is its own TYPE OF ATTACK
## (machine gun stream, rockets, shotgun, flamethrower, ...) and the player swaps guns with Q / E.
## Research: docs/research/WEAPONS_BALANCE_EQUIPMENT.md.

## How the gun attacks. New attack types get a new kind (SHOTGUN, FLAME, RAIL, ...).
enum Kind { BULLET, ROCKET }

@export var display_name: String = "Machine Gun"
@export var kind: Kind = Kind.BULLET
## DamageTypes.Type (KINETIC, EXPLOSIVE, FIRE, ENERGY).
@export var damage_type: int = DamageTypes.Type.KINETIC
## Damage per hit (a random ±10% is applied, Ragnarok-style varied numbers).
## For rockets: damage at the explosion center.
@export var damage: float = 8.0
## Attacks per second. Cooldown between attacks = 1 / fire_rate.
@export var fire_rate: float = 10.0
## Random cone half-angle (degrees).
@export var spread_deg: float = 1.2
## Projectile speed (m/s).
@export var projectile_speed: float = 220.0
## Projectiles disappear (rockets explode) after this distance (m).
@export var max_range: float = 160.0
@export var tracer_color: Color = Color(1.0, 0.85, 0.4)

@export_group("Heat")
## Heat added per shot (0..1 scale). 0 = this gun never overheats.
@export var heat_per_shot: float = 0.0
## Heat lost per second while not firing (after heat_cool_delay).
@export var heat_cool_rate: float = 0.4
## Seconds after the last shot before cooling starts.
@export var heat_cool_delay: float = 0.25
## PENALTY: seconds after overheating before it even starts cooling.
@export var overheat_delay: float = 0.8
## Heat lost per second while OVERHEATED (locked out). Slower than normal cooling = penalty.
@export var overheat_cool_rate: float = 0.3
## Overheat lock ends when heat falls to this level.
@export var overheat_recover: float = 0.0
## Extra spread at full heat (multiplier on spread_deg: 1 + heat × this).
@export var heat_spread_mult: float = 1.5

@export_group("Explosive")
## Explosion radius (m). 0 = no explosion.
@export var explosion_radius: float = 0.0
## Damage multiplier at the edge of the explosion (center = 1.0).
@export var splash_min: float = 0.4


func cooldown() -> float:
	return 1.0 / fire_rate if fire_rate > 0.0 else 0.0


## Machine gun: sustained kinetic stream. ~80 DPS. Strong vs LIGHT armor, weak vs HEAVY.
## OVERHEATS after 4 s of continuous fire (40 shots).
## Stopping in time: full heat cools in ~2.25 s. Overheating = PENALTY: ~4.1 s lockout.
static func make_machine_gun() -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "Machine Gun"
	w.kind = Kind.BULLET
	w.damage_type = DamageTypes.Type.KINETIC
	w.damage = 8.0
	w.fire_rate = 10.0
	w.spread_deg = 1.2
	w.projectile_speed = 220.0
	w.max_range = 160.0
	w.tracer_color = Color(1.0, 0.85, 0.4)
	w.heat_per_shot = 0.025
	w.heat_cool_rate = 0.5
	w.heat_cool_delay = 0.25
	w.overheat_delay = 0.8
	w.overheat_cool_rate = 0.3
	w.overheat_recover = 0.0
	w.heat_spread_mult = 1.5
	return w


## Rocket launcher: slow explosive rocket, area damage, 1.5 s cooldown.
## 90 dmg center (~60 DPS single target) but hits groups. Strong vs HEAVY armor.
static func make_rocket_launcher() -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "Rocket Launcher"
	w.kind = Kind.ROCKET
	w.damage_type = DamageTypes.Type.EXPLOSIVE
	w.damage = 90.0
	w.fire_rate = 1.0 / 1.5
	w.spread_deg = 0.3
	w.projectile_speed = 60.0
	w.max_range = 150.0
	w.explosion_radius = 6.0
	w.splash_min = 0.4
	w.tracer_color = Color(1.0, 0.6, 0.2)
	return w
