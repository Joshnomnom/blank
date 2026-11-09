class_name Enemy
extends CharacterBody3D
## Phase 3 enemy: box placeholder of a half-humanoid robot vehicle (wheeled base + robot
## torso/head/arms). Stats and flags come from EnemyData.
## Research: docs/research/ENEMY_SPAWNING_AI.md (spawning/aggro/leash) and
##           docs/research/ENEMY_BOSS_DESIGN.md (attack anatomy, tokens, charge, boss).
##
## States:
##   IDLE   wander around home. Aggressive: player in sight radius + LoS -> ALERT.
##          Passive: only when damaged. Assist: when a camp-mate is attacked (SpawnCamp).
##   ALERT  stop, face the player, "!" for 0.5 s (telegraph) -> COMBAT.
##   COMBAT MELEE: needs an ATTACK TOKEN from the player (max 2 rammers at once); without
##            one it CIRCLES the player at orbit_radius; with one it dives in, rams, backs off
##            and releases the token (the pack takes turns).
##          ELITE (can_charge): CHARGE DASH - windup 1 s with a red lane telegraph (direction
##            locks at 60%), straight dash at 2.6× speed, hit = 2× damage + big knockback;
##            crashing into a wall = STUNNED 1.6 s taking +50% damage; then recovery (punish).
##          RANGED: keep a distance band, strafe; before each shot a red AIM LASER for 0.45 s
##            (aim locked at its start -> moving dodges it).
##          BOSS: delegated to BossBrain (orb patterns, ground strikes, phases).
##          Leash: too far from home, OR no damage for aggro_timeout AND no sight for 3 s.
##   RETURN drive home fast, INVULNERABLE ("EVADE"), regenerate -> IDLE.
##   DEAD   loot, camp notified, freed.
## Physics: layer ENEMY, collides with SOLID + PLAYER; ground snap by ray.

signal died(enemy: Enemy)

enum State { IDLE, ALERT, COMBAT, RETURN, DEAD }
## Committed actions inside COMBAT (attack anatomy: telegraph -> strike -> recovery).
enum Action { NONE, WINDUP, DASH, RECOVER, STUNNED, AIMING }

var data: EnemyData
var home: Vector3 = Vector3.ZERO
var camp: Node = null           ## SpawnCamp (null for tester-spawned enemies)
var wander_radius: float = 12.0
var state: State = State.IDLE
var action: Action = Action.NONE
var target: CarController = null
var health: Health

var _speed: float = 0.0
var _yaw: float = 0.0
var _up: Vector3 = Vector3.UP
var _want_dir: Vector3 = Vector3.ZERO
var _want_speed: float = 0.0
var _wander_target: Vector3
var _wander_wait: float = 0.0
var _scan_timer: float = 0.0
var _alert_timer: float = 0.0
var _attack_cd: float = 0.0
var _backoff: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0
var _orbit_dir: float = 1.0
var _since_damaged: float = 999.0
var _since_seen: float = 999.0
var _sees_target: bool = false
var _los_timer: float = 0.0
var _action_t: float = 0.0
var _dash_dir: Vector3 = Vector3.FORWARD
var _dash_hit: bool = false
var _charge_cd: float = 3.0
var _locked_aim: Vector3 = Vector3.ZERO
var _surface_map: Node
var _boss: BossBrain

var _visual: Node3D
var _flash_mats: Array[StandardMaterial3D] = []
var _flash_tween: Tween
var _bar: WorldHealthBar
var _alert_label: Label3D
var _status_label: Label3D
var _lane: MeshInstance3D
var _laser: MeshInstance3D
var _collision: CollisionShape3D
var _name_label: Label3D

## Damage the player dealt (boss reward share). Reset when the enemy leashes home.
var player_damage: float = 0.0
## Level actually used (data.level + tester offset). Set before add_child.
var level: int = 1

const Econ := preload("res://scripts/loot/economy.gd")


static func create(p_data: EnemyData, pos: Vector3, p_camp: Node = null, p_wander_radius: float = 12.0) -> Enemy:
	var e := Enemy.new()
	e.data = p_data
	e.home = pos
	e.camp = p_camp
	e.wander_radius = p_wander_radius
	e.position = pos  # parent must be a world-aligned node
	e.level = p_data.level
	return e


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = Layers.ENEMY
	collision_mask = Layers.SOLID | Layers.PLAYER
	add_to_group("targets")
	add_to_group("enemies")
	if data.is_boss:
		add_to_group("bosses")
		_boss = BossBrain.new(self)

	health = Health.new()
	health.max_hp = data.max_hp
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_die)

	_yaw = randf() * TAU
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_surface_map = get_tree().get_first_node_in_group("surface_map")
	_wander_target = home
	_wander_wait = randf_range(0.5, 2.0)
	_build()


# --------------------------------------------------------------------------
# Interface (aim assist, HUD, camps, boss brain, tester)
# --------------------------------------------------------------------------

func is_alive() -> bool:
	return state != State.DEAD


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.3 * data.scale


func get_armor_type() -> int:
	return data.armor


func get_display_name() -> String:
	return data.display_name


func hp_ratio() -> float:
	return health.ratio()


func is_in_combat() -> bool:
	return state == State.COMBAT or state == State.ALERT


func is_action_busy() -> bool:
	return action != Action.NONE


## Movement wish for this tick (used by BossBrain).
func set_move_wish(dir: Vector3, speed: float) -> void:
	_want_dir = dir
	_want_speed = speed


## Start the charge dash now (used by BossBrain; elites trigger it themselves).
func start_charge() -> void:
	if target and action == Action.NONE:
		_start_windup()


func take_damage(amount: float, at: Vector3, damage_type: int = DamageTypes.Type.KINETIC) -> void:
	if state == State.DEAD:
		return
	if state == State.RETURN:
		DamageNumber.spawn_text(get_tree().current_scene, at + Vector3.UP * 0.3, "EVADE")
		return
	var mult := DamageTypes.multiplier(damage_type, data.armor)
	if action == Action.STUNNED:
		mult *= data.stun_damage_mult  # punish window
	_since_damaged = 0.0
	player_damage += minf(amount * mult, health.hp)  # only the player deals damage for now
	var first_hit := state == State.IDLE or state == State.ALERT
	if first_hit:
		_engage(_find_player())
	health.take_damage(amount * mult, at, mult)
	if first_hit and camp and state != State.DEAD:
		camp.call("on_member_attacked", self)


## Called by the camp when a pack-mate is attacked (assist behavior).
func assist_join(p: CarController) -> void:
	if state == State.IDLE and data.assist and p and p.is_alive():
		_alert(p)


## Tester helper: kill instantly (drops loot).
func debug_kill() -> void:
	if state != State.DEAD:
		player_damage += health.hp
		health.take_damage(health.hp, get_aim_point(), 1.0)


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_since_damaged += delta
	_attack_cd -= delta
	_charge_cd -= delta

	if target:
		_los_timer -= delta
		if _los_timer <= 0.0:
			_los_timer = 0.2
			_sees_target = _can_see(target)
		_since_seen = 0.0 if _sees_target else _since_seen + delta

	_want_dir = Vector3.ZERO
	_want_speed = 0.0
	match state:
		State.IDLE:
			_idle(delta)
		State.ALERT:
			_alert_tick(delta)
		State.COMBAT:
			_combat(delta)
		State.RETURN:
			_return_tick(delta)

	_move(delta)


func _idle(delta: float) -> void:
	if data.aggressive:
		_scan_timer -= delta
		if _scan_timer <= 0.0:
			_scan_timer = 0.25
			var p := _find_player()
			if p and global_position.distance_to(p.global_position) <= data.sight_range and _can_see(p):
				_alert(p)
				return
	if _wander_wait > 0.0:
		_wander_wait -= delta
		return
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() < 2.5:
		_wander_wait = randf_range(1.5, 4.0)
		var a := randf() * TAU
		var r := sqrt(randf()) * wander_radius
		_wander_target = home + Vector3(cos(a) * r, 0.0, sin(a) * r)
		return
	_want_dir = to.normalized()
	_want_speed = data.speed * 0.3


func _alert(p: CarController) -> void:
	target = p
	state = State.ALERT
	_alert_timer = 0.5
	_alert_label.visible = true
	_since_damaged = 0.0
	_since_seen = 0.0


func _engage(p: CarController) -> void:
	if p == null:
		return
	target = p
	state = State.COMBAT
	_alert_label.visible = false
	_since_seen = 0.0


func _alert_tick(delta: float) -> void:
	if target == null or not target.is_alive():
		_start_return()
		return
	var to := target.global_position - global_position
	to.y = 0.0
	_want_dir = to.normalized()
	_alert_timer -= delta
	if _alert_timer <= 0.0:
		_engage(target)


func _combat(delta: float) -> void:
	if target == null or not target.is_alive():
		_start_return()
		return
	var to := target.global_position - global_position
	to.y = 0.0
	var dist := maxf(to.length(), 0.01)
	var dir := to / dist

	# Committed actions run to completion (no leash checks mid-dash).
	if action != Action.NONE:
		_tick_action(delta, dir, dist)
		return

	if global_position.distance_to(home) > data.leash_range \
			or (_since_damaged > data.aggro_timeout and _since_seen > 3.0):
		_start_return()
		return

	match data.style:
		EnemyData.Style.MELEE:
			_melee(dir, dist, delta)
		EnemyData.Style.RANGED:
			_ranged(dir, dist, delta)
		EnemyData.Style.BOSS:
			_boss.tick(delta, target, dir, dist)


# --- Melee: tokens, circling, rams, elite charge ---------------------------

func _melee(dir: Vector3, dist: float, delta: float) -> void:
	# Elite: charge dash when in the right range.
	if data.can_charge and _charge_cd <= 0.0 and _sees_target \
			and dist > data.charge_min_dist and dist < data.charge_max_dist:
		target.release_attack_token(self)
		_start_windup()
		return

	if _backoff > 0.0:
		_backoff -= delta
		_want_dir = (-dir).rotated(Vector3.UP, _strafe_dir * 0.9)
		_want_speed = data.speed * 0.7
		return

	if target.request_attack_token(self):
		_want_dir = dir
		_want_speed = data.speed
		var reach := data.attack_range + 2.4 * data.scale + 1.0
		if dist < reach and _attack_cd <= 0.0:
			_ram(dir)
	else:
		# No token: circle the player and wait for a turn (flanking look).
		var from_player := -dir
		var slot := target.global_position + from_player.rotated(Vector3.UP, _orbit_dir * 0.7) * data.orbit_radius
		var to_slot := slot - global_position
		to_slot.y = 0.0
		_want_dir = to_slot.normalized() if to_slot.length() > 1.0 else dir.cross(Vector3.UP) * _orbit_dir
		_want_speed = data.speed * 0.75


func _ram(dir: Vector3) -> void:
	_attack_cd = data.attack_cooldown
	_backoff = 0.8
	_strafe_dir = 1.0 if randf() < 0.5 else -1.0
	target.take_damage(data.damage, target.get_aim_point(), data.damage_type)
	target.apply_knockback(dir * data.knockback)
	target.release_attack_token(self)  # let the next pack member have a go
	var contact := global_position.lerp(target.global_position, 0.6) + Vector3.UP
	Explosion.spawn(get_parent(), contact, 1.2 * data.scale, 0.0, DamageTypes.Type.KINETIC, 0.4, [])


func _start_windup() -> void:
	action = Action.WINDUP
	_action_t = data.charge_windup
	var to := target.global_position - global_position
	to.y = 0.0
	_dash_dir = to.normalized() if to.length() > 0.1 else -global_basis.z
	_lane.visible = true
	_status_label.text = "!!"
	_status_label.modulate = Color(1.0, 0.2, 0.15)
	_status_label.visible = true


func _tick_action(delta: float, dir: Vector3, dist: float) -> void:
	_action_t -= delta
	match action:
		Action.WINDUP:
			# Track the player for the first 60% of the windup, then the direction LOCKS.
			if _action_t > data.charge_windup * 0.4:
				_dash_dir = dir
			_want_dir = _dash_dir
			_want_speed = 0.0
			var length := data.speed * data.charge_speed_mult * data.charge_duration
			_set_line(_lane, global_position + Vector3.UP * 0.12, global_position + Vector3.UP * 0.12 + _dash_dir * length, 2.2 * data.scale, 0.04)
			_visual.position = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.07 * data.scale
			if _action_t <= 0.0:
				action = Action.DASH
				_action_t = data.charge_duration
				_dash_hit = false
				_lane.visible = false
				_status_label.visible = false
				_visual.position = Vector3.ZERO
		Action.DASH:
			_want_dir = _dash_dir
			var reach := 2.4 * data.scale + 1.6
			if not _dash_hit and dist < reach:
				_dash_hit = true
				target.take_damage(data.damage * data.charge_damage_mult, target.get_aim_point(), data.damage_type)
				target.apply_knockback(_dash_dir * data.charge_knockback + Vector3.UP * 5.0)
				Explosion.spawn(get_parent(), target.global_position + Vector3.UP, 2.0, 0.0, DamageTypes.Type.KINETIC, 0.4, [])
				_end_dash(false)
			elif _action_t <= 0.0:
				_end_dash(false)
		Action.RECOVER:
			_want_speed = 0.0
			if _action_t <= 0.0:
				action = Action.NONE
				_charge_cd = data.charge_cooldown
		Action.STUNNED:
			_want_speed = 0.0
			_visual.rotation.z = sin(_action_t * 25.0) * 0.05
			if _action_t <= 0.0:
				action = Action.NONE
				_charge_cd = data.charge_cooldown
				_status_label.visible = false
				_visual.rotation.z = 0.0
		Action.AIMING:
			# Keep strafing slowly while the laser shows; fire at the LOCKED point.
			_want_dir = dir.cross(Vector3.UP) * _strafe_dir
			_want_speed = data.speed * 0.3
			var muzzle := _muzzle()
			_set_line(_laser, muzzle, _locked_aim, 0.06, 0.06)
			if _action_t <= 0.0:
				_laser.visible = false
				action = Action.NONE
				_attack_cd = data.attack_cooldown
				_fire_at(_locked_aim, data.damage, 1, data.bullet_spread)


func _end_dash(crashed: bool) -> void:
	if crashed:
		action = Action.STUNNED
		_action_t = data.stun_time
		_status_label.text = "STUNNED"
		_status_label.modulate = Color(1.0, 0.85, 0.2)
		_status_label.visible = true
		Explosion.spawn(get_parent(), global_position + _dash_dir * 2.0 * data.scale + Vector3.UP, 2.5, 0.0, DamageTypes.Type.KINETIC, 0.4, [])
	else:
		action = Action.RECOVER
		_action_t = 0.8


func _cancel_action() -> void:
	action = Action.NONE
	_lane.visible = false
	_laser.visible = false
	_status_label.visible = false
	_visual.position = Vector3.ZERO
	_visual.rotation.z = 0.0


# --- Ranged ------------------------------------------------------------------

func _ranged(dir: Vector3, dist: float, delta: float) -> void:
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(1.5, 3.0)
		_strafe_dir = -_strafe_dir
	var side := dir.cross(Vector3.UP) * _strafe_dir
	if dist > data.pref_max:
		_want_dir = dir
		_want_speed = data.speed
	elif dist < data.pref_min:
		_want_dir = (-dir + side * 0.5).normalized()
		_want_speed = data.speed * 0.8
	else:
		_want_dir = (side + dir * 0.15).normalized()
		_want_speed = data.speed * 0.6
	if _attack_cd <= 0.0 and _sees_target and dist < data.attack_range:
		# Telegraph: aim laser, locked on where the player is (+ a little lead).
		action = Action.AIMING
		_action_t = data.aim_telegraph
		var lead := target.velocity * 0.25
		lead.y = 0.0
		_locked_aim = target.get_aim_point() + lead
		_laser.visible = true


func _fire_at(point: Vector3, dmg: float, count: int, spread_deg: float) -> void:
	var muzzle := _muzzle()
	var base_dir := (point - muzzle).normalized()
	var shots := _enemy_shots()
	for i in count:
		var dir := base_dir.rotated(Vector3.UP, deg_to_rad(spread_deg) * randf_range(-0.4, 0.4))
		shots.spawn(muzzle + dir * 0.5, dir * data.bullet_speed, dmg * randf_range(0.9, 1.1), 2.2, data.damage_type)


func _muzzle() -> Vector3:
	return global_position + Vector3.UP * 1.45 * data.scale + (-global_basis.z) * 1.1 * data.scale


# --- Return / leash ------------------------------------------------------------

func _start_return() -> void:
	if target:
		target.release_attack_token(self)
	state = State.RETURN
	target = null
	_sees_target = false
	_alert_label.visible = false
	_cancel_action()
	if _boss:
		_boss.reset()


func _return_tick(delta: float) -> void:
	var to := home - global_position
	to.y = 0.0
	health.hp = minf(health.max_hp, health.hp + health.max_hp * 0.4 * delta)
	_bar.set_ratio(health.ratio())
	if to.length() < 3.0:
		state = State.IDLE
		health.reset()
		player_damage = 0.0
		_bar.visible = false
		_wander_target = home
		return
	_want_dir = to.normalized()
	_want_speed = data.speed * 1.6


# --------------------------------------------------------------------------
# Movement
# --------------------------------------------------------------------------

func _move(delta: float) -> void:
	var target_speed := _want_speed
	var dashing := action == Action.DASH
	if dashing:
		_yaw = atan2(-_dash_dir.x, -_dash_dir.z)
		_speed = data.speed * data.charge_speed_mult
	else:
		if _want_dir.length_squared() > 0.001:
			var target_yaw := atan2(-_want_dir.x, -_want_dir.z)
			var diff := wrapf(target_yaw - _yaw, -PI, PI)
			_yaw += clampf(diff, -data.turn_rate * delta, data.turn_rate * delta)
			target_speed *= clampf(1.0 - absf(diff) / PI, 0.3, 1.0)
		var surface_mult := 1.0
		if _surface_map:
			var s: StringName = _surface_map.call("get_surface", global_position)
			surface_mult = 0.8 if s == &"sand" else (0.9 if s == &"dirt" else 1.0)
		_speed = move_toward(_speed, target_speed * surface_mult, data.accel * delta)

	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var v := fwd * _speed
	if not dashing:
		v += _separation() * 4.0
	velocity = Vector3(v.x, 0.0, v.z)
	move_and_slide()

	if dashing:
		# Crashed into something that isn't the player -> stunned (punish window).
		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider()
			if collider != target:
				_end_dash(true)
				break
	_ground_snap(delta, fwd)


func _separation() -> Vector3:
	var push := Vector3.ZERO
	var min_dist := 4.0 * data.scale
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self:
			continue
		var d: Vector3 = global_position - (other as Node3D).global_position
		d.y = 0.0
		var l := d.length()
		if l > 0.01 and l < min_dist:
			push += d / l * (1.0 - l / min_dist)
	return push


func _ground_snap(delta: float, fwd: Vector3) -> void:
	var from := global_position + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 12.0, Layers.GROUND, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var p: Vector3 = hit["position"]
		global_position.y = p.y
		# Normalized lerp (slerp errors when the vectors are nearly equal: "axis must be normalized").
		var blended := _up.lerp(hit["normal"], 1.0 - exp(-8.0 * delta))
		if blended.length_squared() > 0.000001:
			_up = blended.normalized()
	var back := -(fwd - _up * fwd.dot(_up)).normalized()
	var right := _up.cross(back).normalized()
	global_basis = Basis(right, _up, back)


func _can_see(p: CarController) -> bool:
	var from := global_position + Vector3.UP * 1.5 * data.scale
	var query := PhysicsRayQueryParameters3D.create(from, p.get_aim_point(), Layers.SIGHT_BLOCKERS, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _find_player() -> CarController:
	var p := get_tree().get_first_node_in_group("player") as CarController
	return p if p and p.is_alive() else null


func _enemy_shots() -> Projectiles:
	var n := get_tree().get_first_node_in_group("enemy_shots") as Projectiles
	if n == null:
		n = Projectiles.new()
		n.hit_mask = Layers.ENEMY_SHOTS
		n.tracer_width = 0.16
		n.tracer_length = 1.6
		n.add_to_group("enemy_shots")
		get_tree().current_scene.add_child(n)
		n.set_tracer_color(Color(1.0, 0.25, 0.2))
	return n


## Place a stretched box between two points (telegraph lanes, aim lasers).
func _set_line(node: MeshInstance3D, from: Vector3, to: Vector3, width: float, thickness: float) -> void:
	var d := to - from
	var length := d.length()
	if length < 0.01:
		return
	var up := Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	var b := Basis.looking_at(d / length, up) * Basis.from_scale(Vector3(width, thickness, length))
	node.global_transform = Transform3D(b, (from + to) * 0.5)


# --------------------------------------------------------------------------
# Damage / death
# --------------------------------------------------------------------------

func _on_damaged(amount: float, at: Vector3, effectiveness: float) -> void:
	DamageNumber.spawn(get_tree().current_scene, at + Vector3.UP * 0.3, amount, effectiveness)
	_bar.visible = true
	_bar.set_ratio(health.ratio())
	if _flash_tween:
		_flash_tween.kill()
	var strength := 1.8 if DamageTypes.is_effective(effectiveness) else 1.2
	for mat in _flash_mats:
		mat.emission_energy_multiplier = strength
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	for mat in _flash_mats:
		_flash_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)


func _die() -> void:
	if target:
		target.release_attack_token(self)
	state = State.DEAD
	_cancel_action()
	remove_from_group("targets")
	remove_from_group("enemies")
	remove_from_group("bosses")
	_collision.set_deferred("disabled", true)
	_visual.visible = false
	_bar.visible = false
	_alert_label.visible = false
	var world := get_parent()
	Explosion.spawn(world, get_aim_point(), 2.5 * data.scale, 0.0, DamageTypes.Type.EXPLOSIVE, 0.4, [])
	_grant_rewards(world)
	if data.is_boss:
		OrbProjectiles.get_shared(get_tree()).clear()
	died.emit(self)
	if camp:
		camp.call("on_member_died", self)
	_lane.queue_free()
	_laser.queue_free()
	queue_free()


## EXP to the player + scrap/loot drop. Level gap and (bosses) damage share scale both;
## chips ignore the gap (decided log #33). Research: LEVELS_EXP_FEEL.md §3.
func _grant_rewards(world: Node) -> void:
	var p := get_tree().get_first_node_in_group("player") as CarController
	var status: PlayerStatus = p.status if p else null
	var player_level := status.level if status else 1
	var share := 1.0
	if data.rank == Econ.Rank.BOSS:
		share = clampf(player_damage / data.max_hp, 0.0, 1.0)
		if share < Econ.BOSS_MIN_SHARE:
			share = 0.0
	var scrap: int = Econ.kill_scrap(level, data.rank, player_level, share)
	Loot.drop(world, global_position, data, scrap)
	var exp_gain: int = Econ.kill_exp(level, data.rank, player_level, share)
	if status and exp_gain > 0:
		status.add_exp(exp_gain)
		DamageNumber.spawn_text(world, get_aim_point() + Vector3.UP * (1.6 * data.scale + 0.8),
			"+%d EXP" % exp_gain, Color(0.45, 0.8, 1.0))


## Name plate "Lv 4  Raider Gunner" in the con color vs the player's level (WoW-style).
## Called on spawn and by PlayerStatus on level-up (group "enemies").
func refresh_con() -> void:
	if _name_label == null:
		return
	var p := get_tree().get_first_node_in_group("player") as CarController
	var player_level: int = p.status.level if p and p.status else 1
	var gap := level - player_level
	var tag := ""
	if data.rank == Econ.Rank.ELITE:
		tag = "  [ELITE]"
	elif data.rank == Econ.Rank.BOSS:
		tag = "  [BOSS]"
	_name_label.text = "%s  %s%s" % [Econ.level_text(level, player_level), data.display_name, tag]
	_name_label.modulate = Econ.con_color(gap)


# --------------------------------------------------------------------------
# Placeholder model: half-humanoid robot vehicle made of boxes
# --------------------------------------------------------------------------

func _build() -> void:
	var s := data.scale
	_visual = Node3D.new()
	add_child(_visual)

	var dark := _mat(data.body_color.darkened(0.45))
	var body := _mat(data.body_color)
	var metal := _mat(Color(0.25, 0.25, 0.27))
	var eye := StandardMaterial3D.new()
	eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye.albedo_color = Color(1.0, 0.2, 0.15) if data.aggressive else Color(1.0, 0.8, 0.2)

	_box(Vector3(2.0, 0.55, 3.0) * s, Vector3(0.0, 0.55, 0.0) * s, dark)
	var wheel := CylinderMesh.new()
	wheel.top_radius = 0.38 * s
	wheel.bottom_radius = 0.38 * s
	wheel.height = 0.3 * s
	for x in [-1.05, 1.05]:
		for z in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			w.mesh = wheel
			w.material_override = metal
			w.rotation_degrees.z = 90.0
			w.position = Vector3(x, 0.38, z) * s
			_visual.add_child(w)

	_box(Vector3(1.1, 0.9, 0.8) * s, Vector3(0.0, 1.3, 0.1) * s, body)
	_box(Vector3(0.55, 0.45, 0.5) * s, Vector3(0.0, 2.0, 0.05) * s, body)
	var eye_mi := _box(Vector3(0.45, 0.08, 0.05) * s, Vector3(0.0, 2.05, -0.22) * s, null)
	eye_mi.material_override = eye
	for side in [-1.0, 1.0]:
		_box(Vector3(0.28, 0.75, 0.28) * s, Vector3(0.72 * side, 1.25, -0.05) * s, metal)
	if data.style != EnemyData.Style.MELEE:
		_box(Vector3(0.18, 0.18, 1.0) * s, Vector3(0.72, 1.45, -0.6) * s, metal)
	if data.style != EnemyData.Style.RANGED:
		_box(Vector3(2.1, 0.45, 0.25) * s, Vector3(0.0, 0.5, -1.6) * s, metal)

	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 1.9, 3.0) * s
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position = Vector3(0.0, 1.15, 0.0) * s
	add_child(_collision)

	_name_label = _label(data.display_name, 40 if not data.is_boss else 56, 0.008, Color.WHITE, 2.75 * s + 0.6)
	_name_label.outline_size = 10
	refresh_con()
	var armor_label := _label(DamageTypes.ARMOR_NAMES[data.armor], 32, 0.007, DamageTypes.ARMOR_COLORS[data.armor], 2.75 * s + 0.3)
	armor_label.outline_size = 8

	_bar = WorldHealthBar.new(1.6 * maxf(s, 1.0), 0.22)
	_bar.position = Vector3(0.0, 2.75 * s, 0.0)
	_bar.visible = false
	add_child(_bar)

	_alert_label = _label("!", 64, 0.02, Color(1.0, 0.85, 0.1), 2.75 * s + 1.3)
	_alert_label.no_depth_test = true
	_alert_label.outline_size = 14
	_alert_label.visible = false

	_status_label = _label("", 48, 0.014, Color(1.0, 0.2, 0.15), 2.75 * s + 1.3)
	_status_label.no_depth_test = true
	_status_label.outline_size = 12
	_status_label.visible = false

	# Telegraph meshes live in world space (top_level) so they don't tilt with the body.
	_lane = _telegraph_mesh(Color(1.0, 0.15, 0.1, 0.35))
	_laser = _telegraph_mesh(Color(1.0, 0.1, 0.1, 0.75))


func _telegraph_mesh(color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.top_level = true
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mi.visible = false
	add_child(mi)
	return mi


func _label(text: String, font_size: int, pixel: float, color: Color, height: float) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = pixel
	l.font_size = font_size
	l.modulate = color
	l.position = Vector3(0.0, height, 0.0)
	add_child(l)
	return l


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	if mat:
		mi.material_override = mat
	mi.position = pos
	_visual.add_child(mi)
	return mi


func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	m.emission_enabled = true
	m.emission = Color.WHITE
	m.emission_energy_multiplier = 0.0
	_flash_mats.append(m)
	return m
