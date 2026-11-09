class_name PlayerStatus
extends Node
## Phase 3: the player car's HP, armor, death + respawn, inventory (scrap, parts, chips)
## and the player HUD. Node "Status" on the car (after Weapons in sedan.tscn).
##
## Damage: amount × DamageTypes.multiplier(damage_type, armor_type) -> Health.
## Destroyed: controls off, explosion, "DESTROYED" overlay, respawn at the spawn point
## after respawn_time with full HP and invuln_time seconds of invulnerability (car blinks).
## Phase 4: Equipment (equipped parts + chips -> stats) and the BAG screen (I key).
## Death costs repair only (decided 2026-11-09; the repair cost itself comes in a later step).

signal destroyed
signal respawned

@export var max_hp: float = 600.0
@export var armor_type: DamageTypes.Armor = DamageTypes.Armor.LIGHT
@export var respawn_time: float = 3.0
@export var invuln_time: float = 2.0
## Field Repair (Module parts) starts this many seconds after the last damage taken.
@export var repair_delay: float = 4.0

var health: Health
var god_mode: bool = false
var scrap: int = 0
## The BAG: unequipped parts and loose chips. Equipped parts live in `equipment`.
var items: Array[Dictionary] = []
var equipment: Equipment
## Set by Equipment: 0..1 damage reduction (Armor), HP/s field repair (Module).
var damage_reduction: float = 0.0
var repair_rate: float = 0.0

var _car: CarController
var _hud: PlayerHUD
var _dead_timer: float = 0.0
var _invuln: float = 0.0
var _since_hit: float = 100.0
var _bag: BagScreen


func _ready() -> void:
	_car = get_parent() as CarController
	health = Health.new()
	health.max_hp = max_hp
	add_child(health)
	health.died.connect(_on_died)

	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_hud = PlayerHUD.new()
	_hud.status = self
	layer.add_child(_hud)

	equipment = Equipment.new()
	equipment.name = "Equipment"
	add_child(equipment)
	equipment.setup(self)

	var bag_layer := CanvasLayer.new()
	bag_layer.layer = 8
	add_child(bag_layer)
	_bag = BagScreen.new()
	_bag.status = self
	bag_layer.add_child(_bag)


func is_alive() -> bool:
	return health.is_alive()


func is_dead_waiting() -> bool:
	return _dead_timer > 0.0


func respawn_time_left() -> float:
	return _dead_timer


func take_damage(amount: float, at: Vector3, damage_type: int) -> void:
	if not health.is_alive() or _invuln > 0.0 or god_mode:
		return
	var mult := DamageTypes.multiplier(damage_type, armor_type)
	health.take_damage(amount * mult * (1.0 - clampf(damage_reduction, 0.0, 0.9)), at, mult)
	_since_hit = 0.0
	_hud.flash_damage(clampf(amount / 60.0, 0.25, 1.0))


func heal_full() -> void:
	health.reset()


func collect(item: Dictionary) -> void:
	match item.get("kind", ""):
		"scrap":
			var amount: int = item["amount"]
			scrap += amount
			_hud.toast("+%d Scrap" % amount, Color(0.95, 0.85, 0.55))
		"part", "chip":
			items.append(item)
			var rarity: int = item["rarity"]
			_hud.toast(item["name"], Loot.RARITY_COLORS[rarity])


func toast(text: String, color: Color = Color.WHITE) -> void:
	_hud.toast(text, color)


func _on_died() -> void:
	_car.controls_enabled = false
	_dead_timer = respawn_time
	Explosion.spawn(_car.get_parent(), _car.global_position + Vector3.UP * 0.8, 5.0, 0.0, DamageTypes.Type.EXPLOSIVE, 0.4, [])
	destroyed.emit()


func _process(delta: float) -> void:
	_since_hit += delta
	if repair_rate > 0.0 and _since_hit >= repair_delay and health.is_alive() and health.hp < health.max_hp:
		health.hp = minf(health.hp + repair_rate * delta, health.max_hp)
	if _dead_timer > 0.0:
		_dead_timer -= delta
		if _dead_timer <= 0.0:
			_respawn()

	if _invuln > 0.0:
		_invuln -= delta
		# Blink while invulnerable.
		_car.model.visible = fmod(_invuln, 0.2) > 0.1 or _invuln <= 0.0
	elif not _car.model.visible:
		_car.model.visible = true


func _respawn() -> void:
	_car.reset_to_spawn()
	health.reset()
	_car.controls_enabled = true
	_invuln = invuln_time
	respawned.emit()
