class_name ChaseCamera
extends Camera3D
## Third-person chase camera (Driving v2.5, smoothed after feedback).
##
## The camera is driven by CONTINUOUS values, never by switching on the drift on/off state.
## So there is no jump when a drift starts or ends:
## - yaw always follows a fixed blend of travel direction and nose (in grip driving they are
##   the same, so the blend only matters while the car slides)
## - lateral offset and tilt scale with the actual drift angle (smoothed)
## - the long-drift tighten is smoothed in and out
## Speed: FOV widens, camera drops lower and closer, subtle shake near top speed.
## Wall impacts shake the camera.

@export var target_path: NodePath

@export_group("Framing")
## Raised after feedback ("a little top angle, but not too high"): ~24° look-down.
@export var distance: float = 8.0
@export var height: float = 6.0
@export var look_height: float = 1.2
@export var look_ahead: float = 3.0

@export_group("Smoothing")
@export var follow_speed: float = 12.0
@export var rotate_speed: float = 4.0

@export_group("Speed")
@export var base_fov: float = 65.0
@export var max_fov: float = 82.0
## Height multiplier at top speed (lower = ground rushes by).
@export var high_speed_height: float = 0.85
## Distance multiplier at top speed.
@export var high_speed_distance: float = 0.92

@export_group("Drift")
## How much the camera follows the NOSE vs the travel direction (0 = only travel direction,
## 1 = only nose). Always applied; in grip driving both point the same way.
@export_range(0.0, 1.0) var heading_weight: float = 0.4
## Drift angle (degrees) at which lateral offset and tilt reach full strength.
@export var drift_effect_full_angle: float = 30.0
## Sideways shift toward the outside of the slide (meters) at full strength.
@export var drift_lateral_offset: float = 1.2
## Camera roll into the slide (degrees) at full strength.
@export var drift_tilt_deg: float = 3.0
## How much closer the camera gets during long drifts (fraction).
@export var drift_tighten: float = 0.1
## Seconds of drifting until the full tighten.
@export var drift_tighten_time: float = 2.0
## How fast drift camera effects blend in and out (lower = softer).
@export var drift_effect_speed: float = 3.0

@export_group("Shake")
## Speed shake starts at this fraction of top speed.
@export_range(0.0, 1.0) var speed_shake_start: float = 0.7
@export var speed_shake_amount: float = 0.05
@export var impact_shake_amount: float = 0.35
@export var impact_shake_decay: float = 2.5

@export_group("Zoom")
@export var min_zoom: float = 0.7
@export var max_zoom: float = 1.6
@export var zoom_step: float = 0.1

var _target: Node3D
var _car: CarController
var _yaw: float = 0.0
var _zoom: float = 1.0
var _focus: Vector3 = Vector3.ZERO
var _side: float = 0.0       ## smoothed -1..1 slide side (drift angle based)
var _tighten: float = 0.0    ## smoothed 0..drift_tighten
var _trauma: float = 0.0
var _time: float = 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	# Moved every rendered frame in _process, so it must not be physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	fov = base_fov
	current = true
	_noise.frequency = 0.3
	_target = get_node_or_null(target_path) as Node3D
	_car = _target as CarController
	if _car:
		_car.impacted.connect(_on_car_impacted)
	if _target:
		_yaw = _heading_of(_target.global_basis)
		_focus = _target.global_position
		_place_camera(1.0, 1.0, Vector3.ZERO)


func _process(delta: float) -> void:
	if _target == null:
		return
	_time += delta

	var t := _target.get_global_transform_interpolated()
	_focus = _focus.lerp(t.origin, 1.0 - exp(-follow_speed * delta))

	var heading_yaw := _heading_of(t.basis)
	var target_yaw := heading_yaw
	var speed_ratio := 0.0
	var side_target := 0.0
	var tighten_target := 0.0
	if _car:
		speed_ratio = clampf(absf(_car.speed) / _car.top_speed, 0.0, 1.0)
		if _car.speed > 1.0:
			# Continuous blend: identical to the heading when not sliding.
			var travel_yaw := atan2(-_car.travel_dir.x, -_car.travel_dir.z)
			target_yaw = lerp_angle(travel_yaw, heading_yaw, heading_weight)
			side_target = clampf(_car.drift_angle / deg_to_rad(drift_effect_full_angle), -1.0, 1.0)
		if _car.is_drifting:
			tighten_target = drift_tighten * clampf(_car.drift_time / drift_tighten_time, 0.0, 1.0)

	var effect_blend := 1.0 - exp(-drift_effect_speed * delta)
	_side = lerpf(_side, side_target, effect_blend)
	_tighten = lerpf(_tighten, tighten_target, effect_blend)
	_yaw = lerp_angle(_yaw, target_yaw, 1.0 - exp(-rotate_speed * delta))

	# Framing changes with speed and slide.
	var zoom := _zoom * (1.0 - _tighten)
	var height_mult := lerpf(1.0, high_speed_height, speed_ratio)
	var distance_mult := lerpf(1.0, high_speed_distance, speed_ratio)
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	# drift_angle > 0 = nose left of travel = sliding through a left turn, outside = right.
	var lateral := right * _side * drift_lateral_offset
	_place_camera(zoom * height_mult, zoom * distance_mult, lateral)

	# Tilt into the slide.
	rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(drift_tilt_deg) * _side)

	# Shake: subtle near top speed, strong on impacts.
	var shake := _trauma * _trauma * impact_shake_amount
	if speed_ratio > speed_shake_start:
		shake += (speed_ratio - speed_shake_start) / (1.0 - speed_shake_start) * speed_shake_amount
	_trauma = maxf(_trauma - impact_shake_decay * delta, 0.0)
	if shake > 0.0:
		var nx := _noise.get_noise_2d(_time * 40.0, 0.0)
		var ny := _noise.get_noise_2d(0.0, _time * 40.0)
		global_position += (global_basis.x * nx + global_basis.y * ny) * shake

	# FOV widens with speed.
	var target_fov := lerpf(base_fov, max_fov, speed_ratio)
	fov = lerpf(fov, target_fov, 1.0 - exp(-4.0 * delta))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom = clampf(_zoom - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom = clampf(_zoom + zoom_step, min_zoom, max_zoom)


func _on_car_impacted(strength: float) -> void:
	_trauma = clampf(_trauma + strength / 20.0, 0.0, 1.0)


## Shake from outside events (explosions). amount 0..1.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _place_camera(height_scale: float, distance_scale: float, lateral: Vector3) -> void:
	var back := Vector3(sin(_yaw), 0.0, cos(_yaw))
	global_position = _focus + back * distance * distance_scale + Vector3.UP * height * height_scale + lateral
	var aim := _focus + Vector3.UP * look_height - back * look_ahead
	look_at(aim, Vector3.UP)


func _heading_of(basis_in: Basis) -> float:
	var f := -basis_in.z
	return atan2(-f.x, -f.z)
