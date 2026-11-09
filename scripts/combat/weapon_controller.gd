class_name WeaponController
extends Node3D
## Mouse-aimed roof turret with several guns; Q / E swap between them.
## Child of a CarController (with a SedanModel "Model" that provides a "roof" mount).
##
## Aiming: a ray from the camera through the mouse finds the aim point (ground, walls,
## targets). Light AIM ASSIST: if a live target (group "targets") is within
## aim_assist_radius_px of the cursor on screen, aim at its center instead.
## The crosshair shows whether the CURRENT gun is effective against the locked target's armor.
## Hold LMB to fire. Each gun keeps its own cooldown (it keeps recharging while holstered).
## Swapping takes swap_time (no firing during the swap). ESC shows / hides the mouse cursor.
## Design: each gun is its own attack type; no gun skills.

@export var aim_assist_radius_px: float = 70.0
@export var aim_ray_length: float = 400.0
## Seconds to swap guns (no firing meanwhile).
@export var swap_time: float = 0.35

var weapons: Array[WeaponData] = []
var current: int = 0
var aim_point: Vector3 = Vector3.ZERO
var aim_target: Node3D = null
## Damage multiplier of the current gun vs the locked target (1.0 when nothing is locked).
var aim_effectiveness: float = 1.0
var swap_timer: float = 0.0

var _car: CarController
var _turret: Turret
var _projectiles: Projectiles
var _cooldowns: Array[float] = []
var _heat: Array[float] = []
var _overheated: Array[bool] = []
var _since_shot: Array[float] = []
var _crosshair: Crosshair
var _hud: WeaponHUD


func _ready() -> void:
	_car = get_parent() as CarController
	weapons = [WeaponData.make_machine_gun(), WeaponData.make_rocket_launcher()]
	for i in weapons.size():
		_cooldowns.append(0.0)
		_heat.append(0.0)
		_overheated.append(false)
		_since_shot.append(10.0)

	var model := _car.get_node("Model") as SedanModel
	_turret = Turret.new()
	model.get_mount("roof").add_child(_turret)

	_projectiles = Projectiles.new()
	add_child(_projectiles)
	_projectiles.shooter_rid = _car.get_rid()
	_projectiles.set_tracer_color(weapons[current].tracer_color)

	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	aim_point = _car.global_position - _car.global_basis.z * 20.0


## 0..1, how much of the cooldown is left for weapon i (1 = just fired).
func cooldown_ratio(i: int) -> float:
	var cd := weapons[i].cooldown()
	return clampf(_cooldowns[i] / cd, 0.0, 1.0) if cd > 0.0 else 0.0


func cooldown_left(i: int) -> float:
	return maxf(_cooldowns[i], 0.0)


## 0..1 heat of weapon i (guns without heat stay 0).
func heat(i: int) -> float:
	return _heat[i]


func is_overheated(i: int) -> bool:
	return _overheated[i]


## Seconds until an overheated gun can fire again (0 if not overheated).
func overheat_time_left(i: int) -> float:
	if not _overheated[i]:
		return 0.0
	var w := weapons[i]
	var delay_left := maxf(w.overheat_delay - _since_shot[i], 0.0)
	return delay_left + maxf(_heat[i] - w.overheat_recover, 0.0) / w.overheat_cool_rate


## 0..1 "not ready yet" amount for the crosshair reload ring (swap or slow cooldown).
func reload_ratio() -> float:
	if swap_timer > 0.0:
		return swap_timer / swap_time
	if weapons[current].cooldown() > 0.3:
		return cooldown_ratio(current)
	return 0.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_cursor"):
		var was_hidden := Input.mouse_mode == Input.MOUSE_MODE_HIDDEN
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if was_hidden else Input.MOUSE_MODE_HIDDEN
		_crosshair.visible = not was_hidden
	elif event.is_action_pressed("weapon_prev"):
		_swap(-1)
	elif event.is_action_pressed("weapon_next"):
		_swap(1)


func _swap(direction: int) -> void:
	if weapons.size() < 2:
		return
	current = wrapi(current + direction, 0, weapons.size())
	swap_timer = swap_time
	_turret.set_weapon(weapons[current].kind, swap_time)
	_projectiles.set_tracer_color(weapons[current].tracer_color)


func _physics_process(delta: float) -> void:
	_update_aim()
	_turret.aim_at(aim_point, delta)

	# Holstered guns keep recharging; every gun cools down.
	for i in weapons.size():
		if i != current:
			_cooldowns[i] = maxf(_cooldowns[i] - delta, 0.0)
		_update_heat(i, delta)

	if swap_timer > 0.0:
		swap_timer = maxf(swap_timer - delta, 0.0)
		_cooldowns[current] = maxf(_cooldowns[current] - delta, 0.0)
		return

	var weapon := weapons[current]
	_cooldowns[current] -= delta
	var wants_fire := Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN and _car.is_alive()
	if wants_fire and not _overheated[current]:
		# Accumulator: fires exactly fire_rate shots per second.
		while _cooldowns[current] <= 0.0:
			_fire(weapon)
			_cooldowns[current] += weapon.cooldown()
			if weapon.heat_per_shot > 0.0:
				_heat[current] += weapon.heat_per_shot
				_since_shot[current] = 0.0
				if _heat[current] >= 1.0:
					_heat[current] = 1.0
					_overheated[current] = true
					_cooldowns[current] = maxf(_cooldowns[current], 0.0)
					break
	elif _cooldowns[current] < 0.0:
		_cooldowns[current] = 0.0


func _update_heat(i: int, delta: float) -> void:
	var w := weapons[i]
	if w.heat_per_shot <= 0.0:
		return
	_since_shot[i] += delta
	if _overheated[i]:
		# Penalty: a longer wait before cooling, then slower cooling.
		if _since_shot[i] > w.overheat_delay:
			_heat[i] = maxf(_heat[i] - w.overheat_cool_rate * delta, 0.0)
		if _heat[i] <= w.overheat_recover:
			_overheated[i] = false
	elif _since_shot[i] > w.heat_cool_delay:
		_heat[i] = maxf(_heat[i] - w.heat_cool_rate * delta, 0.0)


func _process(_delta: float) -> void:
	_crosshair.locked = aim_target != null
	_crosshair.effectiveness = aim_effectiveness
	_crosshair.reload_ratio = reload_ratio()
	var has_heat := weapons[current].heat_per_shot > 0.0
	_crosshair.heat = _heat[current] if has_heat else 0.0
	_crosshair.overheated = _overheated[current]
	_crosshair.overheat_left = overheat_time_left(current)
	# Barrel glow / steam follow the machine gun's heat even while holstered.
	for i in weapons.size():
		if weapons[i].kind == WeaponData.Kind.BULLET:
			_turret.set_heat(_heat[i], _overheated[i])


func _update_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var weapon := weapons[current]

	# Aim assist: nearest live target to the cursor on screen.
	aim_target = null
	aim_effectiveness = 1.0
	var best := aim_assist_radius_px
	for node in get_tree().get_nodes_in_group("targets"):
		if not node.call("is_alive"):
			continue
		var p: Vector3 = node.call("get_aim_point")
		if cam.is_position_behind(p) or p.distance_to(_car.global_position) > weapon.max_range:
			continue
		var d := cam.unproject_position(p).distance_to(mouse)
		if d < best:
			best = d
			aim_target = node as Node3D
	if aim_target:
		aim_point = aim_target.call("get_aim_point")
		if aim_target.has_method("get_armor_type"):
			aim_effectiveness = DamageTypes.multiplier(weapon.damage_type, aim_target.call("get_armor_type"))
		return

	# Otherwise: whatever is under the cursor.
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var to := from + dir * aim_ray_length
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.PLAYER_SHOTS, [_car.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	aim_point = hit["position"] if not hit.is_empty() else to


func _fire(weapon: WeaponData) -> void:
	var muzzle := _turret.get_muzzle_transform()
	var spread := weapon.spread_deg * (1.0 + _heat[current] * weapon.heat_spread_mult)
	var dir := _spread((-muzzle.basis.z).normalized(), spread)
	var damage := weapon.damage * randf_range(0.9, 1.1)

	match weapon.kind:
		WeaponData.Kind.BULLET:
			var lifetime := weapon.max_range / weapon.projectile_speed
			_projectiles.spawn(muzzle.origin, dir * weapon.projectile_speed, damage, lifetime, weapon.damage_type)
		WeaponData.Kind.ROCKET:
			var rocket := Rocket.new()
			rocket.setup(weapon, dir * weapon.projectile_speed, damage, _car.get_rid())
			_projectiles.add_child(rocket)
			rocket.global_position = muzzle.origin
			rocket.look_at(muzzle.origin + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)
			rocket.reset_physics_interpolation()
	_turret.on_fired()


func _spread(dir: Vector3, spread_deg: float) -> Vector3:
	if spread_deg <= 0.0:
		return dir
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var angle := randf() * TAU
	var amount := tan(deg_to_rad(spread_deg)) * sqrt(randf())
	return (dir + (side * cos(angle) + up * sin(angle)) * amount).normalized()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_crosshair = Crosshair.new()
	layer.add_child(_crosshair)

	_hud = WeaponHUD.new()
	_hud.controller = self
	layer.add_child(_hud)
