class_name WeaponData
extends Resource
## Stats for one gun. Phase 2 step 1 uses only the machine gun.
##
## Planned (design, NOT implemented yet): each gun has an active SKILL with a cooldown,
## and the player swaps guns with Q / E. The skill fields are here so the data shape is
## ready; nothing reads them yet.

@export var display_name: String = "Machine Gun"
## Damage per bullet (a random ±10% is applied, Ragnarok-style varied numbers).
@export var damage: float = 8.0
## Shots per second while the fire button is held.
@export var fire_rate: float = 10.0
## Random cone half-angle (degrees).
@export var spread_deg: float = 1.2
## Bullet speed (m/s). Bullets are fast projectiles, not instant hitscan.
@export var projectile_speed: float = 220.0
## Bullets disappear after this distance (m).
@export var max_range: float = 160.0
@export var tracer_color: Color = Color(1.0, 0.85, 0.4)

@export_group("Skill (planned, unused)")
@export var skill_name: String = ""
@export var skill_cooldown: float = 0.0


static func make_machine_gun() -> WeaponData:
	var w := WeaponData.new()
	w.display_name = "Machine Gun"
	w.damage = 8.0
	w.fire_rate = 10.0
	w.spread_deg = 1.2
	w.projectile_speed = 220.0
	w.max_range = 160.0
	return w
