class_name NitroDash
extends Node3D
## NITRO DASH (Phase 4 step 3): Shift (gamepad B) = a short forward burst of speed.
## Created by CarController in _ready (node "Nitro").
##
## - Meter 0..max_nitro. A dash costs dash_cost. Refills regen_per_sec always, plus
##   drift_charge_per_sec while drifting on the ground (driving well powers combat).
## - Dash: +dash_speed_gain m/s spread over dash_time (can go past top speed), then the car
##   keeps that speed for overspeed_hold s before the normal over-top-speed drag eats it.
##   Works on the ground and in the air (a jump + dash flies further). Not while reversing fast.
## - Feel: blue exhaust flames + light, camera shake + FOV kick, a white flash on the HUD bar.
## - Equipment (Nitro parts): regen_mult (Nitro Recharge %), power_mult (Dash Power %).

signal dashed

@export var max_nitro: float = 100.0
@export var dash_cost: float = 34.0
@export var regen_per_sec: float = 9.0
@export var drift_charge_per_sec: float = 10.0
## Extra speed (m/s) a dash adds.
@export var dash_speed_gain: float = 16.0
## Seconds over which the speed is added (a fast shove, not a teleport).
@export var dash_time: float = 0.22
## After the dash, seconds before over-top-speed drag starts slowing the car down.
@export var overspeed_hold: float = 0.35
## Minimum time between dashes.
@export var dash_cooldown: float = 0.5

var nitro: float = 100.0
var regen_mult: float = 1.0
var power_mult: float = 1.0
## 0..1 strength of the flame effect (HUD and visuals read it).
var flame: float = 0.0

var _car: CarController
var _dash_left: float = 0.0
var _cooldown: float = 0.0
var _flames: Array[MeshInstance3D] = []
var _flame_mat: StandardMaterial3D
var _light: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	_car = get_parent() as CarController
	_build_flames()


func can_dash() -> bool:
	return nitro >= dash_cost and _cooldown <= 0.0 and _car.controls_enabled and _car.is_alive() \
		and _car.speed > -3.0


## How many dashes the meter holds right now (for the HUD).
func charges() -> int:
	return floori(nitro / dash_cost)


func _physics_process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)

	var rate := regen_per_sec
	if _car.is_drifting and _car.on_ground:
		rate += drift_charge_per_sec
	nitro = minf(nitro + rate * regen_mult * delta, max_nitro)

	if Input.is_action_just_pressed("nitro") and can_dash():
		_start_dash()

	if _dash_left > 0.0:
		var step := minf(delta, _dash_left)
		_dash_left -= step
		_car.speed = maxf(_car.speed, 0.0) + dash_speed_gain * power_mult * step / dash_time
		_car.boost_hold = overspeed_hold

	var target := 1.0 if _dash_left > 0.0 else (0.45 if _car.boost_hold > 0.0 else 0.0)
	flame = move_toward(flame, target, delta * (12.0 if target > flame else 2.5))
	_update_flames()


func _start_dash() -> void:
	nitro -= dash_cost
	_cooldown = dash_cooldown
	_dash_left = dash_time
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_trauma"):
		cam.call("add_trauma", 0.3)
	if cam and cam.has_method("kick_fov"):
		cam.call("kick_fov", 10.0)
	dashed.emit()


# --- Visuals ------------------------------------------------------------------

func _build_flames() -> void:
	_flame_mat = StandardMaterial3D.new()
	_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flame_mat.albedo_color = Color(0.35, 0.65, 1.0, 0.9)
	_flame_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.14
	cone.height = 1.0
	cone.radial_segments = 8
	var model := _car.get_node_or_null("Model") as Node3D
	var parent: Node3D = model if model else _car
	for x in [-0.5, 0.5]:
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = _flame_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Cone points +Z (backwards, out of the rear bumper).
		mi.rotation.x = deg_to_rad(90.0)
		mi.position = Vector3(x, 0.45, 2.3)
		mi.visible = false
		parent.add_child(mi)
		_flames.append(mi)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.4, 0.65, 1.0)
	_light.omni_range = 6.0
	_light.light_energy = 0.0
	_light.position = Vector3(0.0, 0.6, 2.8)
	parent.add_child(_light)


func _update_flames() -> void:
	var on := flame > 0.02
	for i in _flames.size():
		var mi := _flames[i]
		mi.visible = on
		if on:
			var flicker := 0.85 + 0.15 * sin(_time * 55.0 + i * 2.0)
			var length := (0.6 + 1.6 * flame) * flicker
			mi.scale = Vector3(0.7 + 0.5 * flame, length, 0.7 + 0.5 * flame)
			mi.position.z = 2.3 + length * 0.5
	_light.light_energy = flame * 2.5
