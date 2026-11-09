class_name CarController
extends CharacterBody3D
## Arcade car controller, Driving v2 + terrain support (Phase 1).
## Design notes: docs/research/DRIVING_GAME_FEEL.md (§2–§4), docs/DEVLOG.md (How Systems Work).
##
## The car tracks TWO directions:
## - heading: where the nose points (this node's yaw)
## - travel_dir: where the car is actually moving (flat unit vector)
## The signed angle between them is the drift angle.
##
## GRIP mode: steering changes yaw rate with inertia; travel_dir is pulled toward the
##   heading while keeping speed.
## DRIFT mode (drift-angle controller, no tire sim): steering sets the TARGET drift angle,
##   the nose is rotated to reach it, the path bends through the corner, speed is mostly kept.
##
## Ground handling ("raycast suspension", Phase 1 fix):
## - The body uses MOTION_MODE_FLOATING: move_and_slide only handles walls. The collision
##   box is raised 0.4 m so it never scrapes the ground.
## - 4 rays (one per wheel) find the ground. Car height = average wheel contact height;
##   car tilt = plane through the 4 contacts. No floor flicker, no floating.
## - The car leaves the ground only when the ground falls away faster than gravity can
##   follow (ramp lips, sharp crests). Launch keeps the ground's vertical speed -> jumps.
## - In the air: gravity, small air steering, nose follows the flight path.
## - Surface under the car (road / dirt / sand) comes from a node in group "surface_map".

signal drift_started(direction: int)
signal drift_ended(duration: float)
signal impacted(strength: float)
signal landed(fall_speed: float)

@export_group("Speed")
## Top speed in m/s on road (42 m/s ≈ 150 km/h). Surfaces multiply this.
@export var top_speed: float = 42.0
## Acceleration from a standstill (m/s²).
@export var accel_max: float = 11.0
## Acceleration multiplier at top speed (lower = slower top end).
@export_range(0.0, 1.0) var top_end_accel: float = 0.25
## Shape of the acceleration falloff (higher = stays punchy longer).
@export var accel_curve_power: float = 1.6
@export var brake_decel: float = 25.0
@export var coast_decel: float = 2.0
@export var max_reverse_speed: float = 12.0
@export var reverse_accel: float = 8.0
@export var handbrake_decel: float = 7.0

@export_group("Steering")
## How fast steering moves toward the input (per second).
@export var steer_in_speed: float = 5.0
## How fast steering recenters or flips direction (faster = snappier).
@export var steer_out_speed: float = 9.0
## Yaw rate at full lock (rad/s).
@export var turn_rate: float = 2.2
## Speed (m/s) at which steering reaches full strength.
@export var full_turn_speed: float = 8.0
## Steering multiplier at top speed.
@export_range(0.0, 1.0) var high_speed_steer: float = 0.45
## How quickly yaw rate reaches its target in grip mode (rotational weight).
@export var yaw_response_grip: float = 8.0
## How strongly travel direction follows the nose in grip mode.
@export var grip_turn: float = 10.0
## Speed lost per second while turning hard at speed (fraction).
@export var cornering_scrub: float = 0.03
## Grip multiplier while handbrake is held without drifting.
@export_range(0.0, 1.0) var handbrake_grip_factor: float = 0.25

@export_group("Drift")
## Minimum speed (m/s) to start a drift (11 ≈ 40 km/h).
@export var drift_min_speed: float = 11.0
## Drift ends below this speed.
@export var drift_exit_speed: float = 7.0
## Extra angle added on drift entry (degrees), eased in over drift_kick_time.
@export var drift_kick_deg: float = 8.0
## Seconds over which the entry kick is applied (smoothstep ease in/out; higher = softer entry).
@export var drift_kick_time: float = 0.25
## Drift angle with neutral steering (degrees).
@export var drift_base_angle: float = 25.0
## Drift angle when steering fully into the corner.
@export var drift_max_angle: float = 40.0
## Drift angle when fully counter-steering (0 lets you exit by counter-steering).
@export var drift_min_angle: float = 0.0
## Extra angle while holding throttle (when not counter-steering).
@export var drift_throttle_angle: float = 3.0
## Extra angle while holding handbrake in a drift.
@export var drift_handbrake_angle: float = 8.0
## How fast the nose rotates to reach the target drift angle.
@export var drift_angle_response: float = 5.0
## Rotational weight in drift (lower = floatier).
@export var yaw_response_drift: float = 3.0
## How fast the travel path bends through a corner while drifting (rad/s).
@export var drift_turn_rate: float = 1.35
## Speed lost per second while drifting (m/s²). Reduced when holding throttle.
@export var drift_speed_loss: float = 3.0
## Acceleration multiplier while drifting.
@export_range(0.0, 1.0) var drift_accel_factor: float = 0.6
## Drift ends when the angle falls below this (degrees).
@export var drift_exit_angle: float = 8.0
## Seconds to blend grip back in after a drift (prevents snapping).
@export var drift_exit_blend: float = 0.3
## Drift angle can never exceed this (no spin-outs).
@export var spin_clamp_angle: float = 70.0
## A brake press shorter than this (s) counts as a "tap".
@export var brake_tap_max: float = 0.3
## Time after a brake tap during which steering starts a drift (s).
@export var brake_tap_window: float = 0.4
## Full steer + full throttle at high speed for this long (s) starts a power drift.
@export var power_over_hold: float = 0.5

@export_group("Launch")
## Pressing throttle below this speed (m/s) triggers a burnout launch.
@export var burnout_max_speed: float = 3.0
@export var burnout_time: float = 0.6
## Tail wiggle during a burnout launch (degrees).
@export var launch_wiggle_deg: float = 2.0

@export_group("Terrain")
## Surface used when there is no surface map in the scene (the flat test arena).
@export var default_surface: StringName = &"road"
## How fast surface properties blend when the surface changes.
@export var surface_blend_speed: float = 6.0
## Slowdown (m/s²) when the current speed is above the surface's top speed (e.g. road -> sand).
@export var overspeed_decel: float = 10.0
## How strongly slopes speed you up downhill / slow you uphill.
@export var slope_gravity: float = 9.0
## How fast the body tilts to match the ground.
@export var ground_align_speed: float = 12.0
## How fast the body turns to follow the flight path in the air.
@export var air_align_speed: float = 3.0
## How much the nose follows the flight path in the air (0 = stays level, 1 = fully).
@export_range(0.0, 1.0) var air_pitch_follow: float = 0.6
## Yaw control in the air (rad/s at full steer).
@export var air_steer_rate: float = 1.2
## Landing faster than this (m/s downward) shakes the camera.
@export var hard_landing_speed: float = 7.0
## The car leaves the ground when the ground curves away faster than gravity × this.
@export var launch_factor: float = 1.0

@export_group("Physics")
## Gravity in the air (m/s²). Arcade: ~2x real.
@export var gravity: float = 22.0
## Speed lost in a wall hit needed to count as an impact (m/s).
@export var min_impact_speed: float = 4.0
## Wheel positions used for the ground rays (half track width, half wheelbase).
@export var wheel_half_track: float = 0.86
@export var wheel_half_base: float = 1.35
## Physics layers the wheel rays stand on (1 = solid objects, 2 = ground). The car BODY only
## collides with layer 1, so the chassis can never hit the ground before the rays do.
@export_flags_3d_physics var ground_probe_mask: int = 3

# --- Read-only state (used by model, effects, audio, camera, debug, later systems) ---
var speed: float = 0.0                       ## signed speed along travel_dir (negative = reversing)
var travel_dir: Vector3 = Vector3.FORWARD    ## flat unit vector of motion
var steer_input: float = 0.0                 ## -1..1, positive = left
var throttle_input: float = 0.0
var brake_input: float = 0.0
var handbrake_input: bool = false
var yaw_rate: float = 0.0                    ## rad/s, positive = turning left
var is_drifting: bool = false
var drift_dir: int = 0                       ## +1 = drifting left (tail out right), -1 = right
var drift_angle: float = 0.0                 ## signed rad, angle from travel_dir to nose
var drift_time: float = 0.0
var burnout_amount: float = 0.0              ## 0..1
var tire_slip: float = 0.0                   ## 0..1 overall rear tire slip -> smoke/skids/sound
var on_ground: bool = false
var air_time: float = 0.0
var vertical_speed: float = 0.0              ## m/s, in the air
var current_surface: StringName = &"road"
## False while destroyed (Phase 3): all driving input reads as zero.
var controls_enabled: bool = true
## 0..1, from Suspension parts (Equipment): knockback impulses are reduced by this much.
var knockback_resist: float = 0.0
## Seconds left in which over-top-speed drag is paused (set by the nitro dash).
var boost_hold: float = 0.0
## Nitro dash (Phase 4 step 3), created in _ready as child "Nitro".
## Loaded by path (not the global class name) so a stale editor class cache can't break the car.
const NitroDashScript := preload("res://scripts/vehicles/nitro_dash.gd")
var nitro: NitroDashScript

var _spawn_transform: Transform3D
var _surface_map: Node
var _up: Vector3 = Vector3.UP                ## smoothed body up vector
var _ground_normal: Vector3 = Vector3.UP
var _ground_y: float = 0.0
var _ground_vy: float = 0.0                  ## smoothed vertical speed of the ground under the car
var _probe_hits: int = 0
var _exit_blend_timer: float = 0.0
var _brake_hold: float = 0.0
var _brake_tap_timer: float = 0.0
var _power_over_timer: float = 0.0
var _burnout_timer: float = 0.0
var _prev_throttle: float = 0.0
var _impact_cooldown: float = 0.0
var _kick_total: float = 0.0
var _kick_applied: float = 0.0
var _kick_t: float = 0.0
var _time: float = 0.0

# Smoothed surface multipliers.
var _s_grip: float = 1.0
var _s_top: float = 1.0
var _s_accel: float = 1.0
var _s_drag: float = 0.0
var _s_drift_angle: float = 0.0
var _s_drift_loss: float = 1.0

@onready var model: SedanModel = $Model
## HP, death/respawn, inventory, HUD (Phase 3). Optional (null in scenes without it).
@onready var status: PlayerStatus = get_node_or_null("Status")


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group("player")
	# Body is on the PLAYER layer and collides with solid objects (walls, ramps, dummies) and
	# enemies - but NOT the ground (layer 2): only the wheel rays touch the ground.
	collision_layer = Layers.PLAYER
	collision_mask = Layers.SOLID | Layers.ENEMY
	_spawn_transform = global_transform
	travel_dir = _flat_forward()
	_surface_map = get_tree().get_first_node_in_group("surface_map")
	current_surface = default_surface
	if _surface_map:
		current_surface = _surface_map.call("get_surface", global_position)
	_snap_surface()
	nitro = NitroDashScript.new()
	nitro.name = "Nitro"
	add_child(nitro)


func get_speed_kmh() -> float:
	return absf(speed) * 3.6


# --- Combat interface (Phase 3) -------------------------------------------

func is_alive() -> bool:
	return status == null or status.is_alive()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 0.8


## Called by enemy attacks, enemy bullets and explosions.
func take_damage(amount: float, at: Vector3, damage_type: int = DamageTypes.Type.KINETIC) -> void:
	if status:
		status.take_damage(amount, at, damage_type)


## Shove the car (rams, shockwaves). Horizontal only; mixes into the travel velocity.
func apply_knockback(impulse: Vector3) -> void:
	impulse *= 1.0 - clampf(knockback_resist, 0.0, 0.9)
	var v := travel_dir * speed + Vector3(impulse.x, 0.0, impulse.z)
	var length := v.length()
	if length > 0.1:
		travel_dir = v / length
		speed = length
	if impulse.y > 0.0 and on_ground:
		on_ground = false
		vertical_speed = impulse.y


## Loot pickup -> inventory.
func collect(item: Dictionary) -> void:
	if status:
		status.collect(item)


# --- Attack tokens (research: ENEMY_BOSS_DESIGN.md §2) ---------------------
## Max enemies allowed to ram this car at the same time; others circle and wait.
var max_melee_attackers: int = 2
var _melee_tokens: Array = []


func request_attack_token(enemy: Node) -> bool:
	_melee_tokens = _melee_tokens.filter(func(e): return is_instance_valid(e) and e.call("is_alive"))
	if enemy in _melee_tokens:
		return true
	if _melee_tokens.size() < max_melee_attackers:
		_melee_tokens.append(enemy)
		return true
	return false


func release_attack_token(enemy: Node) -> void:
	_melee_tokens.erase(enemy)


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	speed = 0.0
	yaw_rate = 0.0
	steer_input = 0.0
	travel_dir = _flat_forward()
	_up = Vector3.UP
	on_ground = false
	vertical_speed = 0.0
	is_drifting = false
	drift_dir = 0
	drift_angle = 0.0
	_exit_blend_timer = 0.0
	_burnout_timer = 0.0
	burnout_amount = 0.0
	air_time = 0.0
	reset_physics_interpolation()


func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("reset_car") and controls_enabled:
		reset_to_spawn()
		return

	_time += delta
	_impact_cooldown = maxf(_impact_cooldown - delta, 0.0)
	boost_hold = maxf(boost_hold - delta, 0.0)

	_read_input(delta)
	_update_surface(delta)
	_update_brake_tap(delta)
	_update_burnout(delta)

	if on_ground:
		air_time = 0.0
		_update_longitudinal(delta)
		_apply_slope(delta)
		drift_angle = _current_drift_angle()
		if is_drifting:
			_update_drift(delta)
		else:
			_try_enter_drift(delta)
			if not is_drifting:
				_update_grip(delta)
	else:
		air_time += delta
		_update_air(delta)
	drift_angle = _current_drift_angle()

	_update_tire_slip()

	# Horizontal movement (+ vertical in the air). Walls are handled by move_and_slide.
	var horizontal := travel_dir * speed
	if on_ground:
		velocity = Vector3(horizontal.x, 0.0, horizontal.z)
	else:
		vertical_speed -= gravity * delta
		velocity = Vector3(horizontal.x, vertical_speed, horizontal.z)
	move_and_slide()
	_handle_collisions()

	# Vertical: follow the ground, launch off it, or land on it.
	_update_ground(delta)
	_align_body(delta)

	model.update_visuals(self, delta)


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _read_input(delta: float) -> void:
	if not controls_enabled:
		throttle_input = 0.0
		brake_input = 0.0
		handbrake_input = false
		steer_input = move_toward(steer_input, 0.0, steer_out_speed * delta)
		return
	throttle_input = Input.get_action_strength("accelerate")
	brake_input = Input.get_action_strength("brake")
	handbrake_input = Input.is_action_pressed("handbrake")

	var target := Input.get_axis("steer_right", "steer_left")
	var rate := steer_in_speed
	# Recentering or flipping direction is faster than steering in.
	if absf(target) < absf(steer_input) or target * steer_input < 0.0:
		rate = steer_out_speed
	steer_input = move_toward(steer_input, target, rate * delta)


func _update_brake_tap(delta: float) -> void:
	if brake_input > 0.1:
		_brake_hold += delta
	else:
		if _brake_hold > 0.0 and _brake_hold <= brake_tap_max:
			_brake_tap_timer = brake_tap_window
		_brake_hold = 0.0
	_brake_tap_timer = maxf(_brake_tap_timer - delta, 0.0)


func _update_burnout(delta: float) -> void:
	# Burnout starts when throttle is slammed from near standstill.
	if throttle_input > 0.8 and _prev_throttle < 0.1 and absf(speed) < burnout_max_speed and on_ground:
		_burnout_timer = burnout_time
	_prev_throttle = throttle_input

	if throttle_input < 0.1:
		_burnout_timer = 0.0
	_burnout_timer = maxf(_burnout_timer - delta, 0.0)
	burnout_amount = (_burnout_timer / burnout_time) * throttle_input if burnout_time > 0.0 else 0.0


# --------------------------------------------------------------------------
# Surface
# --------------------------------------------------------------------------

func _update_surface(delta: float) -> void:
	if _surface_map and on_ground:
		current_surface = _surface_map.call("get_surface", global_position)
	var d := Surfaces.get_data(current_surface)
	var k := 1.0 - exp(-surface_blend_speed * delta)
	_s_grip = lerpf(_s_grip, d["grip"], k)
	_s_top = lerpf(_s_top, d["top_speed"], k)
	_s_accel = lerpf(_s_accel, d["accel"], k)
	_s_drag = lerpf(_s_drag, d["rolling_drag"], k)
	_s_drift_angle = lerpf(_s_drift_angle, d["drift_angle"], k)
	_s_drift_loss = lerpf(_s_drift_loss, d["drift_loss"], k)


func _snap_surface() -> void:
	var d := Surfaces.get_data(current_surface)
	_s_grip = d["grip"]
	_s_top = d["top_speed"]
	_s_accel = d["accel"]
	_s_drag = d["rolling_drag"]
	_s_drift_angle = d["drift_angle"]
	_s_drift_loss = d["drift_loss"]


# --------------------------------------------------------------------------
# Speed
# --------------------------------------------------------------------------

func _update_longitudinal(delta: float) -> void:
	var top := top_speed * _s_top
	if throttle_input > 0.0:
		if speed < -0.5:
			# Rolling backward: throttle brakes first.
			speed = move_toward(speed, 0.0, brake_decel * throttle_input * delta)
		elif speed < top:
			var ratio := clampf(speed / top, 0.0, 1.0)
			var accel := accel_max * _s_accel * lerpf(1.0, top_end_accel, pow(ratio, accel_curve_power))
			if is_drifting:
				accel *= drift_accel_factor
			speed = minf(speed + accel * throttle_input * delta, top)
	elif brake_input > 0.0:
		if speed > 0.5:
			speed = move_toward(speed, 0.0, brake_decel * brake_input * delta)
		else:
			speed = move_toward(speed, -max_reverse_speed, reverse_accel * brake_input * delta)
	else:
		speed = move_toward(speed, 0.0, coast_decel * delta)

	if handbrake_input:
		speed = move_toward(speed, 0.0, handbrake_decel * delta)

	# Surface: too fast for this surface (e.g. road -> sand) and rolling drag.
	if speed > top and boost_hold <= 0.0:
		speed = move_toward(speed, top, overspeed_decel * delta)
	speed = move_toward(speed, 0.0, _s_drag * delta)


func _apply_slope(delta: float) -> void:
	# The horizontal part of the ground normal points downhill; its length is sin(slope).
	var downhill := Vector3(_ground_normal.x, 0.0, _ground_normal.z)
	speed += slope_gravity * downhill.dot(travel_dir) * delta


# --------------------------------------------------------------------------
# Grip driving / air
# --------------------------------------------------------------------------

func _update_grip(delta: float) -> void:
	var abs_speed := absf(speed)
	var low_factor := clampf(abs_speed / full_turn_speed, 0.0, 1.0)
	var high_factor := lerpf(1.0, high_speed_steer, clampf(abs_speed / top_speed, 0.0, 1.0))
	var surface_turn := lerpf(1.0, _s_grip, 0.5)
	var target_yaw := steer_input * turn_rate * surface_turn * low_factor * high_factor * signf(speed)

	# Launch tail wiggle (small oscillating yaw during a burnout).
	if burnout_amount > 0.0:
		target_yaw += sin(_time * 22.0) * deg_to_rad(launch_wiggle_deg) * 22.0 * burnout_amount

	# Rotational inertia: yaw rate moves toward the target instead of jumping.
	yaw_rate = lerpf(yaw_rate, target_yaw, 1.0 - exp(-yaw_response_grip * delta))

	# Travel direction follows the nose, keeping speed.
	var grip := grip_turn * _s_grip
	if _exit_blend_timer > 0.0:
		grip *= lerpf(1.0, 0.15, _exit_blend_timer / drift_exit_blend)
		_exit_blend_timer = maxf(_exit_blend_timer - delta, 0.0)
	if handbrake_input:
		grip *= handbrake_grip_factor

	var fwd := _flat_forward()
	if speed > 0.5:
		var angle := travel_dir.signed_angle_to(fwd, Vector3.UP)
		travel_dir = travel_dir.rotated(Vector3.UP, angle * (1.0 - exp(-grip * delta))).normalized()
		var speed_ratio := clampf(speed / top_speed, 0.0, 1.0)
		speed -= speed * cornering_scrub * absf(steer_input) * speed_ratio * delta
	else:
		travel_dir = fwd

	rotate_y(yaw_rate * delta)


func _update_air(delta: float) -> void:
	# No grip in the air: travel direction and speed are kept, small yaw control only.
	var target_yaw := steer_input * air_steer_rate
	yaw_rate = lerpf(yaw_rate, target_yaw, 1.0 - exp(-3.0 * delta))
	rotate_y(yaw_rate * delta)


# --------------------------------------------------------------------------
# Drifting
# --------------------------------------------------------------------------

func _try_enter_drift(delta: float) -> void:
	if speed < drift_min_speed or absf(steer_input) < 0.3:
		_power_over_timer = 0.0
		return

	var want := false
	if handbrake_input:
		want = true
	elif _brake_tap_timer > 0.0 and absf(steer_input) > 0.5:
		want = true
	elif absf(steer_input) > 0.85 and throttle_input > 0.9 and speed > top_speed * _s_top * 0.7:
		_power_over_timer += delta
		want = _power_over_timer >= power_over_hold
	else:
		_power_over_timer = 0.0

	if want:
		_enter_drift(1 if steer_input > 0.0 else -1)


func _enter_drift(direction: int) -> void:
	is_drifting = true
	drift_dir = direction
	drift_time = 0.0
	_power_over_timer = 0.0
	_brake_tap_timer = 0.0
	_exit_blend_timer = 0.0
	# Entry kick: eased in over drift_kick_time (applied in _update_drift), not snapped.
	_kick_total = direction * deg_to_rad(drift_kick_deg)
	_kick_applied = 0.0
	_kick_t = 0.0
	drift_started.emit(direction)


func _exit_drift() -> void:
	if not is_drifting:
		return
	is_drifting = false
	_exit_blend_timer = drift_exit_blend
	drift_ended.emit(drift_time)
	drift_dir = 0


func _update_drift(delta: float) -> void:
	drift_time += delta
	var steer_rel := steer_input * drift_dir  # +1 into the corner, -1 counter-steer

	# Smooth entry kick: rotate the nose by kick × smoothstep(t / kick_time), a bit each tick.
	if _kick_t < drift_kick_time:
		_kick_t = minf(_kick_t + delta, drift_kick_time)
		var x := _kick_t / drift_kick_time if drift_kick_time > 0.0 else 1.0
		var eased := _kick_total * x * x * (3.0 - 2.0 * x)
		rotate_y(eased - _kick_applied)
		_kick_applied = eased
		drift_angle = _current_drift_angle()

	# Steering chooses the target drift angle.
	var target_deg: float
	if steer_rel >= 0.0:
		target_deg = lerpf(drift_base_angle, drift_max_angle, steer_rel)
		target_deg += drift_throttle_angle * throttle_input
		target_deg += _s_drift_angle  # loose surfaces slide wider
	else:
		target_deg = lerpf(drift_base_angle, drift_min_angle, -steer_rel)
	if handbrake_input:
		target_deg += drift_handbrake_angle

	# The path bends through the corner (strongest steering in, none at full counter-steer).
	var path_rate := drift_dir * drift_turn_rate * (0.5 + 0.5 * steer_rel)
	travel_dir = travel_dir.rotated(Vector3.UP, path_rate * delta).normalized()

	# Rotate the nose so the drift angle approaches the target.
	var current := drift_angle * drift_dir
	var error := (deg_to_rad(target_deg) - current) * drift_dir
	var target_yaw := path_rate + error * drift_angle_response
	yaw_rate = lerpf(yaw_rate, target_yaw, 1.0 - exp(-yaw_response_drift * delta))
	rotate_y(yaw_rate * delta)

	# Drifts keep most of their speed. Throttle reduces the loss.
	var loss := drift_speed_loss * _s_drift_loss * (1.0 - 0.7 * throttle_input)
	speed = maxf(speed - loss * delta, 0.0)

	# Recompute the angle and clamp it (no spin-outs).
	drift_angle = _current_drift_angle()
	var clamp_rad := deg_to_rad(spin_clamp_angle)
	if absf(drift_angle) > clamp_rad:
		rotate_y(-(drift_angle - signf(drift_angle) * clamp_rad))
		drift_angle = signf(drift_angle) * clamp_rad
		yaw_rate = path_rate

	# Exit conditions.
	var angle_in_dir := drift_angle * drift_dir
	var released := throttle_input < 0.1 and not handbrake_input and steer_rel <= 0.1
	if drift_time > 0.25 and (angle_in_dir < deg_to_rad(drift_exit_angle) or released or brake_input > 0.5):
		_exit_drift()
	elif speed < drift_exit_speed:
		_exit_drift()


# --------------------------------------------------------------------------
# Ground: wheel rays, follow / launch / land, body tilt
# --------------------------------------------------------------------------

func _update_ground(delta: float) -> void:
	var probe := _probe_ground()
	if _probe_hits == 0:
		if on_ground:
			_launch(_ground_vy)
		return

	var gy: float = probe["y"]
	var normal: Vector3 = probe["normal"]

	if on_ground:
		# Vertical speed the car would need to follow the ground (smoothed against mesh facets).
		var raw_vy := (gy - _ground_y) / delta
		var new_vy := lerpf(_ground_vy, raw_vy, 1.0 - exp(-15.0 * delta))
		var ground_accel := (new_vy - _ground_vy) / delta
		if ground_accel < -gravity * launch_factor and absf(speed) > 3.0:
			# The ground falls away faster than gravity can pull the car: take off.
			_launch(_ground_vy)
			return
		_ground_vy = new_vy
		_ground_y = gy
		_ground_normal = normal
		global_position.y = gy
	else:
		_ground_normal = normal
		var pos_y := global_position.y
		if (pos_y <= gy + 0.05 and vertical_speed <= 0.0) or pos_y < gy:
			_land(gy)


func _launch(launch_vy: float) -> void:
	on_ground = false
	vertical_speed = launch_vy


func _land(gy: float) -> void:
	var fall := -vertical_speed
	on_ground = true
	global_position.y = gy
	_ground_y = gy
	_ground_vy = 0.0
	vertical_speed = 0.0
	model.on_landed(fall)
	if fall > hard_landing_speed:
		landed.emit(fall)
		if _impact_cooldown <= 0.0:
			impacted.emit(fall * 0.6)
			_impact_cooldown = 0.3


func _probe_ground() -> Dictionary:
	# One ray per wheel, straight down. Returns average contact height and a ground normal
	# (plane through the 4 contacts when all hit, otherwise the average hit normal).
	var space := get_world_3d().direct_space_state
	var fwd := _flat_forward()
	var right := fwd.cross(Vector3.UP).normalized()
	var origin := global_position
	var exclude: Array[RID] = [get_rid()]

	# Order: front-left, front-right, rear-left, rear-right.
	var offsets := [
		-right * wheel_half_track + fwd * wheel_half_base,
		right * wheel_half_track + fwd * wheel_half_base,
		-right * wheel_half_track - fwd * wheel_half_base,
		right * wheel_half_track - fwd * wheel_half_base,
	]
	var points: Array[Vector3] = []
	var hit_flags: Array[bool] = []
	var normal_sum := Vector3.ZERO
	var y_sum := 0.0
	_probe_hits = 0
	for off in offsets:
		var from: Vector3 = origin + off + Vector3.UP * 1.5
		var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 5.0, ground_probe_mask)
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			points.append(Vector3.ZERO)
			hit_flags.append(false)
			continue
		var p: Vector3 = hit["position"]
		points.append(p)
		hit_flags.append(true)
		normal_sum += hit["normal"]
		y_sum += p.y
		_probe_hits += 1

	if _probe_hits == 0:
		return {}

	var normal := normal_sum.normalized()
	if _probe_hits == 4:
		var side := (points[1] + points[3]) * 0.5 - (points[0] + points[2]) * 0.5
		var length_vec := (points[0] + points[1]) * 0.5 - (points[2] + points[3]) * 0.5
		var plane_normal := side.cross(length_vec).normalized()
		if plane_normal.y > 0.3:
			normal = plane_normal
	return {"y": y_sum / float(_probe_hits), "normal": normal}


func _align_body(delta: float) -> void:
	var target_up := _ground_normal
	var rate := ground_align_speed
	if not on_ground:
		# Nose follows the flight path (partly), body slowly turns to it.
		# Only when moving forward fast: slow or straight-down falls stay level
		# (pitching at low speed tipped the nose into the ground and blocked landing).
		var fwd := _flat_forward()
		var right := fwd.cross(Vector3.UP).normalized()
		var flight_pitch := atan2(vertical_speed, maxf(absf(speed), 1.0)) * air_pitch_follow
		flight_pitch = clampf(flight_pitch, deg_to_rad(-25.0), deg_to_rad(25.0))
		flight_pitch *= clampf(absf(speed) / 8.0, 0.0, 1.0)
		var tilted_fwd := fwd * cos(flight_pitch) + Vector3.UP * sin(flight_pitch)
		target_up = right.cross(tilted_fwd).normalized()
		rate = air_align_speed
	# Normalized lerp, not slerp: slerp builds an axis from cross(_up, target_up), which is
	# ~zero when the two are almost equal (flat ground) -> "axis must be normalized" error.
	var blended := _up.lerp(target_up, 1.0 - exp(-rate * delta))
	if blended.length_squared() > 0.000001:
		_up = blended.normalized()

	var f := _flat_forward()
	var back := -(f - _up * f.dot(_up)).normalized()
	var right_axis := _up.cross(back).normalized()
	global_basis = Basis(right_axis, _up, back)


# --------------------------------------------------------------------------
# Feedback state
# --------------------------------------------------------------------------

func _update_tire_slip() -> void:
	if not on_ground:
		tire_slip = 0.0
		return
	var slip := 0.0
	var abs_speed := absf(speed)
	if is_drifting:
		slip = clampf(absf(drift_angle) / deg_to_rad(35.0), 0.35, 1.0) * clampf(abs_speed / 15.0, 0.3, 1.0)
	elif abs_speed > 3.0:
		# Leftover slide after a drift, or handbrake slide.
		slip = clampf((absf(drift_angle) - deg_to_rad(4.0)) / deg_to_rad(20.0), 0.0, 1.0)
	if handbrake_input and abs_speed > 3.0:
		slip = maxf(slip, 0.7)
	if brake_input > 0.8 and speed > 15.0:
		slip = maxf(slip, 0.45)
	slip = maxf(slip, burnout_amount)
	tire_slip = slip


func _handle_collisions() -> void:
	var hit_wall := false
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if absf(normal.y) < 0.7:
			hit_wall = true
			break
	if not hit_wall:
		return

	# Keep the along-wall velocity (forgiving), lose only the into-wall part.
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var new_speed := flat.length()
	var lost := absf(speed) - new_speed
	if speed >= 0.0:
		if new_speed > 0.5:
			travel_dir = flat / new_speed
		speed = new_speed
	else:
		speed = -new_speed

	if lost > min_impact_speed and _impact_cooldown <= 0.0:
		impacted.emit(lost)
		_impact_cooldown = 0.3
	if is_drifting and lost > 6.0:
		_exit_drift()


func _current_drift_angle() -> float:
	return travel_dir.signed_angle_to(_flat_forward(), Vector3.UP) if speed > 0.5 else 0.0


func _flat_forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	if f.length_squared() < 0.0001:
		return travel_dir
	return f.normalized()
