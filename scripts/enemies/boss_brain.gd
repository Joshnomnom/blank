class_name BossBrain
extends RefCounted
## Boss fight brain: "Space Invaders on wheels" (research: ENEMY_BOSS_DESIGN.md §4).
## The boss keeps 24–36 m away from the player and strafes; it throws readable patterns of
## glowing orbs and telegraphed ground strikes; the player dodges by driving and fires back.
##
## Phases by HP: P1 > 66%, P2 33–66% (adds spiral + charge dash, faster),
##               P3 < 33% ENRAGED (shorter gaps, faster orbs, double rings, bigger barrages).
## Each phase change: announcement + immediate ring burst.
## Patterns (never the same twice in a row):
##   fan     - aimed fan of 5/7/9 orbs, 1/2/3 bursts
##   ring    - 20 orbs all around with a 3-orb GAP to drive through (P3: two rings)
##   mortar  - 4/6/8 telegraphed ground strikes on/around the player (1.3 s warning)
##   spiral  - rotating double stream for 3 s (P2+)
##   charge  - elite charge dash with a red lane (P2+), uses Enemy's charge ability
##   shock   - red disc around the boss, only when the player hugs it

var enemy: Enemy
var phase: int = 1

var _current: String = ""
var _last: String = ""
var _gap: float = 2.5
var _t: float = 0.0
var _step: int = 0
var _spiral_angle: float = 0.0
var _strafe_dir: float = 1.0
var _strafe_timer: float = 0.0

const ORB_HEIGHT := 1.2


func _init(p_enemy: Enemy) -> void:
	enemy = p_enemy


func reset() -> void:
	phase = 1
	_current = ""
	_last = ""
	_gap = 2.5


## Called every physics tick while the boss is in COMBAT. Sets the boss's movement wish.
func tick(delta: float, target: CarController, dir: Vector3, dist: float) -> void:
	_update_phase()
	if enemy.is_action_busy():
		return  # charge dash in progress (Enemy handles it)

	_move_around(delta, dir, dist)

	if _current == "":
		_gap -= delta
		if _gap <= 0.0:
			_start(_pick(dist))
		return
	_run(delta, target, dir, dist)


# --------------------------------------------------------------------------

func _update_phase() -> void:
	var r := enemy.hp_ratio()
	var p := 1 if r > 0.66 else (2 if r > 0.33 else 3)
	if p > phase:
		phase = p
		var status := _player_status()
		if status:
			status.toast("%s %s!" % [enemy.get_display_name(), "rages" if p == 2 else "is ENRAGED"], Color(1.0, 0.4, 0.2))
		_ring(enemy.data.bullet_speed * 0.5, 0.0, 24)
		_current = ""
		_gap = 1.2


func _move_around(delta: float, dir: Vector3, dist: float) -> void:
	# Stay inside the arena.
	var from_home := enemy.global_position - enemy.home
	from_home.y = 0.0
	if from_home.length() > 40.0:
		enemy.set_move_wish(-from_home.normalized(), enemy.data.speed * 0.8)
		return
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(2.0, 4.0)
		_strafe_dir = -_strafe_dir
	var side := dir.cross(Vector3.UP) * _strafe_dir
	var speed_mult := 0.4 if _current != "" else 0.65
	if dist < 24.0:
		enemy.set_move_wish((-dir + side * 0.6).normalized(), enemy.data.speed * speed_mult)
	elif dist > 36.0:
		enemy.set_move_wish((dir + side * 0.4).normalized(), enemy.data.speed * speed_mult)
	else:
		enemy.set_move_wish(side, enemy.data.speed * speed_mult * 0.8)


func _pick(dist: float) -> String:
	var options: Array[String] = ["fan", "ring", "mortar"]
	if phase >= 2:
		options.append_array(["spiral", "charge"])
	if dist < 14.0:
		options = ["shock"]  # player hugging the boss: push them out
	options.erase(_last)
	if options.is_empty():
		options = ["fan"]
	return options[randi() % options.size()]


func _start(pattern: String) -> void:
	_current = pattern
	_last = pattern
	_t = 0.0
	_step = 0
	if pattern == "charge":
		enemy.start_charge()
		_finish()
	elif pattern == "shock":
		GroundStrike.spawn(enemy.get_parent(), enemy.global_position, enemy.data.shock_radius, 1.2, enemy.data.shock_damage, 25.0, false)
		_finish()


func _finish() -> void:
	_current = ""
	var gaps: Array[float] = [1.6, 1.2, 0.8]
	_gap = gaps[phase - 1]


func _run(delta: float, target: CarController, dir: Vector3, _dist: float) -> void:
	_t += delta
	var speed_mults: Array[float] = [0.5, 0.6, 0.7]
	var speed: float = enemy.data.bullet_speed * speed_mults[phase - 1]  # 20 / 24 / 28 m/s
	match _current:
		"fan":
			var bursts := phase
			if _step < bursts and _t >= _step * 0.5:
				var fan_counts: Array[int] = [5, 7, 9]
				_fan(dir, fan_counts[phase - 1], 50.0, speed)
				_step += 1
			if _step >= bursts:
				_finish()
		"ring":
			var rings := 2 if phase == 3 else 1
			if _step < rings and _t >= _step * 0.6:
				_ring(speed * 0.85, randf() * TAU, 20, 3)
				_step += 1
			if _step >= rings:
				_finish()
		"mortar":
			var counts: Array[int] = [4, 6, 8]
			var count: int = counts[phase - 1]
			if _step < count and _t >= _step * 0.15:
				var lead := target.velocity * 1.0
				lead.y = 0.0
				var offset := Vector3.ZERO if _step == 0 else Vector3(randf_range(-9, 9), 0.0, randf_range(-9, 9))
				GroundStrike.spawn(enemy.get_parent(), target.global_position + lead * (0.0 if _step == 0 else 0.6) + offset, 4.0, 1.3, enemy.data.shock_damage * 0.5, 12.0)
				_step += 1
			if _step >= count:
				_finish()
		"spiral":
			var duration := 3.0
			var interval := 0.09 if phase == 2 else 0.07
			while _step * interval <= _t and _t < duration:
				_spiral_angle += deg_to_rad(17.0)
				for k in 2:
					var a := _spiral_angle + PI * k
					_orb(Vector3(cos(a), 0.0, sin(a)), speed * 0.75)
				_step += 1
			if _t >= duration:
				_finish()
		_:
			_finish()


func _fan(dir: Vector3, count: int, spread_deg: float, speed: float) -> void:
	for i in count:
		var f := lerpf(-0.5, 0.5, float(i) / float(maxi(count - 1, 1)))
		_orb(dir.rotated(Vector3.UP, deg_to_rad(spread_deg) * f), speed)


func _ring(speed: float, start_angle: float, count: int, gap: int = 0) -> void:
	for i in count:
		if gap > 0 and i < gap:
			continue  # the gap: the safe lane to drive through
		var a := start_angle + TAU * float(i) / float(count)
		_orb(Vector3(cos(a), 0.0, sin(a)), speed)


func _orb(dir: Vector3, speed: float) -> void:
	var origin := enemy.global_position + Vector3.UP * ORB_HEIGHT + dir * 2.5 * enemy.data.scale
	OrbProjectiles.get_shared(enemy.get_tree()).spawn(origin, dir * speed, enemy.data.volley_damage, 4.5)


func _player_status() -> PlayerStatus:
	var car := enemy.get_tree().get_first_node_in_group("player") as CarController
	return car.status if car else null
