class_name EnemyData
extends RefCounted
## Stats + behavior flags for one enemy type. EnemyData.make(id) builds the known types.
## Research: docs/research/ENEMY_SPAWNING_AI.md (§2 behavior flags, §4 leash, §6 archetypes).
## Final look (art phase): half-humanoid robot vehicles. Now: box placeholders.

enum Style { MELEE, RANGED, BOSS }

var id: StringName = &""
var display_name: String = ""
var armor: int = DamageTypes.Armor.LIGHT
var max_hp: float = 150.0
var scale: float = 1.0
var body_color: Color = Color(0.6, 0.45, 0.3)

# Movement (m/s, rad/s, m/s²). Always slower than the player car (driving is defense).
var speed: float = 25.0
var turn_rate: float = 2.5
var accel: float = 20.0

# Behavior flags (Ragnarok style).
var aggressive: bool = true   ## attacks on sight; false = passive until hit
var assist: bool = true       ## joins when a camp-mate is attacked
var sight_range: float = 30.0
var leash_range: float = 120.0  ## gives up beyond this distance from home
var aggro_timeout: float = 8.0  ## gives up after this long without being hit AND without sight

# Attack.
var style: Style = Style.MELEE
var damage: float = 15.0
var damage_type: int = DamageTypes.Type.KINETIC
var attack_cooldown: float = 1.2
var attack_range: float = 1.2     ## melee: extra reach beyond touching; ranged: max shooting range
var knockback: float = 10.0
var pref_min: float = 20.0        ## ranged: preferred distance band
var pref_max: float = 34.0
var bullet_speed: float = 45.0
var bullet_spread: float = 2.5

# Group behavior (research: ENEMY_BOSS_DESIGN.md §2): melee enemies without an attack token
# circle the player at this distance and wait for their turn.
var orbit_radius: float = 14.0
## Ranged: red aim laser shown this long before each shot (aim locks when it starts).
var aim_telegraph: float = 0.45

# Elite ability: CHARGE DASH (research §3). Windup (red lane) -> straight dash -> recovery.
var can_charge: bool = false
var charge_windup: float = 1.0
var charge_speed_mult: float = 2.6
var charge_duration: float = 1.1
var charge_cooldown: float = 6.0
var charge_damage_mult: float = 2.0
var charge_knockback: float = 30.0
var charge_min_dist: float = 10.0
var charge_max_dist: float = 40.0
## Crashing into a wall while dashing: stunned this long, taking stun_damage_mult damage.
var stun_time: float = 1.6
var stun_damage_mult: float = 1.5

# Boss extras.
var is_boss: bool = false
var volley_damage: float = 18.0
var volley_cooldown: float = 2.5
var volley_range: float = 60.0
var shock_radius: float = 12.0
var shock_damage: float = 60.0
var shock_interval: float = 9.0

# Loot.
var scrap_min: int = 3
var scrap_max: int = 8
var item_chance: float = 0.2
var item_rolls: int = 1
var rarity_bonus: float = 0.0
var chip_chance: float = 0.01


static func make(type_id: StringName) -> EnemyData:
	var d := EnemyData.new()
	d.id = type_id
	match type_id:
		&"scrap_drone":
			# Fast, fragile, aggressive pack rammer. LIGHT armor -> machine gun is effective.
			d.display_name = "Scrap Drone"
			d.armor = DamageTypes.Armor.LIGHT
			d.max_hp = 150.0
			d.scale = 0.8
			d.body_color = Color(0.62, 0.46, 0.3)
			d.speed = 30.0
			d.turn_rate = 3.2
			d.accel = 30.0
			d.aggressive = true
			d.assist = true
			d.sight_range = 30.0
			d.leash_range = 120.0
			d.style = Style.MELEE
			d.damage = 15.0
			d.attack_cooldown = 1.2
			d.knockback = 10.0
			d.scrap_min = 3
			d.scrap_max = 8
			d.item_chance = 0.2
			d.chip_chance = 0.01
		&"raider_gunner":
			# Keeps its distance and strafes; slow dodgeable bullets.
			d.display_name = "Raider Gunner"
			d.armor = DamageTypes.Armor.LIGHT
			d.max_hp = 220.0
			d.scale = 0.95
			d.body_color = Color(0.58, 0.26, 0.2)
			d.speed = 25.0
			d.turn_rate = 2.5
			d.accel = 20.0
			d.aggressive = true
			d.assist = true
			d.sight_range = 40.0
			d.leash_range = 130.0
			d.style = Style.RANGED
			d.damage = 12.0
			d.attack_cooldown = 1.1
			d.attack_range = 50.0
			d.pref_min = 20.0
			d.pref_max = 34.0
			d.bullet_speed = 45.0
			d.bullet_spread = 2.5
			d.scrap_min = 5
			d.scrap_max = 12
			d.item_chance = 0.3
			d.chip_chance = 0.01
		&"iron_hauler":
			# Slow tank, passive until hit, its pack assists it. HEAVY armor -> rockets are effective.
			d.display_name = "Iron Hauler"
			d.armor = DamageTypes.Armor.HEAVY
			d.max_hp = 800.0
			d.scale = 1.35
			d.body_color = Color(0.42, 0.48, 0.58)
			d.speed = 18.0
			d.turn_rate = 1.4
			d.accel = 10.0
			d.aggressive = false
			d.assist = true
			d.sight_range = 35.0
			d.leash_range = 110.0
			d.style = Style.MELEE
			d.damage = 35.0
			d.attack_cooldown = 2.0
			d.attack_range = 1.5
			d.knockback = 22.0
			d.orbit_radius = 16.0
			# ELITE move: charge dash.
			d.can_charge = true
			d.charge_cooldown = 6.0
			d.scrap_min = 15
			d.scrap_max = 30
			d.item_chance = 0.6
			d.rarity_bonus = 0.5
			d.chip_chance = 0.02
		&"dune_tyrant":
			# Field boss (MVP): rams, cannon volleys, telegraphed shockwave. HEAVY armor.
			d.display_name = "Dune Tyrant"
			d.armor = DamageTypes.Armor.HEAVY
			d.max_hp = 6000.0
			d.scale = 2.4
			d.body_color = Color(0.5, 0.36, 0.22)
			d.speed = 20.0
			d.turn_rate = 1.2
			d.accel = 12.0
			d.aggressive = true
			d.assist = false
			d.sight_range = 50.0
			d.leash_range = 60.0  # flat boss arena radius ~55 m
			d.aggro_timeout = 12.0
			# Charge dash is used by the BossBrain in phase 2+ (not on its own).
			d.can_charge = true
			d.charge_speed_mult = 2.2
			d.charge_max_dist = 50.0
			d.style = Style.BOSS
			d.damage = 45.0
			d.attack_cooldown = 2.0
			d.attack_range = 2.0
			d.knockback = 28.0
			d.bullet_speed = 40.0
			d.bullet_spread = 6.0
			d.is_boss = true
			d.volley_damage = 18.0
			d.volley_cooldown = 2.5
			d.volley_range = 60.0
			d.shock_radius = 12.0
			d.shock_damage = 60.0
			d.shock_interval = 9.0
			d.scrap_min = 150
			d.scrap_max = 250
			d.item_chance = 1.0
			d.item_rolls = 3
			d.rarity_bonus = 3.0
			d.chip_chance = 0.15
		_:
			push_warning("EnemyData.make: unknown enemy id %s" % type_id)
	return d
