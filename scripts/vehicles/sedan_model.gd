class_name SedanModel
extends Node3D
## Placeholder sedan built from simple boxes and cylinders.
## The car faces -Z (Godot's forward). Front has yellow headlights, back has red taillights.
## Replace with a real 3D model later; keep update_visuals() and get_rear_wheel_ground_points()
## as the interface.
##
## Driving v2.3 visuals:
## - rear wheels spin separately: burnout (fast), drift with throttle (faster than road), handbrake (locked)
## - front wheels point along the travel direction while drifting (counter-steer look)
## - brake lights brighten when braking
## - extra body roll while drifting
##
## Phase 4 garage: BODY KITS (visual only, no stats, no collision): paint + front / rear /
## roof / side pieces. set_kit(category, index); option 0 = stock. Names and scrap costs in KITS.

const WHEEL_RADIUS := 0.36
const WHEEL_WIDTH := 0.28
const MAX_STEER_VISUAL := 0.6

@export var body_color: Color = Color(0.78, 0.2, 0.12)
## Extra body roll while drifting (radians).
@export var drift_roll: float = 0.05
## Visual landing suspension (body only, no gameplay effect): spring stiffness and damping.
@export var suspension_stiffness: float = 140.0
@export var suspension_damping: float = 14.0
## How far the body dips per m/s of landing speed (meters), and the max dip.
@export var landing_dip_per_speed: float = 0.012
@export var max_landing_dip: float = 0.18

var _body: Node3D
var _front_pivots: Array[Node3D] = []
var _rear_pivots: Array[Node3D] = []
var _front_spins: Array[Node3D] = []
var _rear_spins: Array[Node3D] = []
var _taillight_mat: StandardMaterial3D

var _front_angle: float = 0.0
var _rear_angle: float = 0.0
var _rear_spin_rate: float = 0.0
var _steer_visual: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _last_speed: float = 0.0
var _brake_glow: float = 1.0
var _susp_y: float = 0.0
var _susp_v: float = 0.0
var _mounts: Dictionary = {}
var _paint_mat: StandardMaterial3D
var _kit_mats: Dictionary = {}
var _kit_roots: Dictionary = {}   # category -> Node3D

## category -> [[name, scrap cost], ...]. Index 0 = stock (free).
const KITS := {
	"paint": [["Rust Red", 0], ["Desert Sand", 100], ["Gunmetal", 100], ["Toxic Green", 100],
		["Midnight Blue", 100], ["Hazard Yellow", 100], ["Bone White", 100], ["Matte Black", 100]],
	"front": [["Stock", 0], ["Bull Bar", 150], ["Ram Plow", 300]],
	"rear": [["Stock", 0], ["Lip Spoiler", 120], ["Big Wing", 250]],
	"roof": [["Stock", 0], ["Light Bar", 150], ["Roof Rails", 120]],
	"side": [["Stock", 0], ["Armor Skirts", 200], ["Side Pipes", 180]],
}
const PAINT_COLORS := [
	Color(0.78, 0.2, 0.12), Color(0.82, 0.68, 0.45), Color(0.32, 0.34, 0.37), Color(0.45, 0.8, 0.15),
	Color(0.1, 0.16, 0.42), Color(0.95, 0.75, 0.05), Color(0.9, 0.88, 0.8), Color(0.06, 0.06, 0.07),
]


static func kit_cost(category: String, index: int) -> int:
	var options: Array = KITS.get(category, [])
	return int(options[index][1]) if index >= 0 and index < options.size() else 0


func set_kit(category: String, index: int) -> void:
	if category == "paint":
		_paint_mat.albedo_color = PAINT_COLORS[clampi(index, 0, PAINT_COLORS.size() - 1)]
		return
	var root: Node3D = _kit_roots.get(category)
	if root == null:
		return
	for c in root.get_children():
		c.queue_free()
	var metal: Material = _kit_mats["metal"]
	var dark: Material = _kit_mats["dark"]
	var chrome: Material = _kit_mats["chrome"]
	match [category, index]:
		["front", 1]:  # bull bar
			for x in [-0.5, 0.5]:
				_add_box(root, Vector3(0.08, 0.6, 0.08), Vector3(x, 0.72, -2.42), metal)
			_add_box(root, Vector3(1.4, 0.08, 0.08), Vector3(0.0, 0.98, -2.44), metal)
			_add_box(root, Vector3(1.6, 0.08, 0.08), Vector3(0.0, 0.58, -2.44), metal)
		["front", 2]:  # ram plow
			var plow := _add_box(root, Vector3(2.1, 0.55, 0.1), Vector3(0.0, 0.58, -2.55), metal)
			plow.rotation.x = -0.45
			for x in [-0.7, 0.0, 0.7]:
				_add_box(root, Vector3(0.1, 0.1, 0.35), Vector3(x, 0.55, -2.75), chrome)
		["rear", 1]:  # lip spoiler
			_add_box(root, Vector3(1.6, 0.06, 0.3), Vector3(0.0, 0.98, 2.05), _paint_mat)
		["rear", 2]:  # big wing
			for x in [-0.6, 0.6]:
				_add_box(root, Vector3(0.06, 0.38, 0.12), Vector3(x, 1.12, 1.95), dark)
			_add_box(root, Vector3(1.95, 0.06, 0.48), Vector3(0.0, 1.32, 1.95), dark)
			for x in [-0.98, 0.98]:
				_add_box(root, Vector3(0.04, 0.22, 0.5), Vector3(x, 1.32, 1.95), dark)
		["roof", 1]:  # light bar
			_add_box(root, Vector3(1.3, 0.12, 0.16), Vector3(0.0, 1.54, -0.42), dark)
			for x in [-0.45, -0.15, 0.15, 0.45]:
				_add_box(root, Vector3(0.24, 0.08, 0.03), Vector3(x, 1.54, -0.51), _kit_mats["lamp"])
		["roof", 2]:  # roof rails
			for x in [-0.68, 0.68]:
				_add_box(root, Vector3(0.06, 0.06, 1.7), Vector3(x, 1.53, 0.35), chrome)
				for z in [-0.35, 1.05]:
					_add_box(root, Vector3(0.06, 0.08, 0.06), Vector3(x, 1.5, z), chrome)
		["side", 1]:  # armor skirts
			for x in [-0.93, 0.93]:
				_add_box(root, Vector3(0.08, 0.32, 1.9), Vector3(x, 0.52, 0.0), metal)
				for z in [-0.6, 0.0, 0.6]:
					_add_box(root, Vector3(0.1, 0.06, 0.06), Vector3(x * 1.02, 0.6, z), chrome)
		["side", 2]:  # side exhaust pipes
			for x in [-0.98, 0.98]:
				_add_box(root, Vector3(0.12, 0.12, 1.5), Vector3(x, 0.42, 0.3), chrome)
				_add_box(root, Vector3(0.14, 0.14, 0.12), Vector3(x, 0.42, 1.08), dark)


## Weapon mount points (children of the body, so weapons lean and bounce with it).
## Currently: "roof". Later: "front", "rear", "left", "right".
func get_mount(mount_name: String) -> Node3D:
	return _mounts.get(mount_name)


## Called by CarController when it lands. Pushes the body down; the spring brings it back.
func on_landed(fall_speed: float) -> void:
	_susp_v -= minf(fall_speed * landing_dip_per_speed * 10.0, max_landing_dip * 10.0)


func _ready() -> void:
	_build()


## Called by CarController every physics tick, after it moves.
func update_visuals(car: CarController, delta: float) -> void:
	var speed := car.speed

	# --- Wheel spin ---
	var road_spin := speed / WHEEL_RADIUS
	var rear_target := road_spin
	if car.handbrake_input:
		rear_target = 0.0  # locked
	elif car.burnout_amount > 0.0:
		rear_target = road_spin + 45.0 * car.burnout_amount
	elif car.is_drifting and car.throttle_input > 0.1:
		rear_target = road_spin * 1.5 + 8.0
	_rear_spin_rate = lerpf(_rear_spin_rate, rear_target, 1.0 - exp(-10.0 * delta))

	_front_angle = wrapf(_front_angle - road_spin * delta, -PI, PI)
	_rear_angle = wrapf(_rear_angle - _rear_spin_rate * delta, -PI, PI)
	for spin in _front_spins:
		spin.rotation.x = _front_angle
	for spin in _rear_spins:
		spin.rotation.x = _rear_angle

	# --- Front wheel steering (counter-steer look while drifting) ---
	var steer_target := car.steer_input * MAX_STEER_VISUAL
	if car.is_drifting:
		steer_target = clampf(-car.drift_angle, -MAX_STEER_VISUAL, MAX_STEER_VISUAL)
	_steer_visual = lerpf(_steer_visual, steer_target, 1.0 - exp(-12.0 * delta))
	for pivot in _front_pivots:
		pivot.rotation.y = _steer_visual

	# --- Body lean ---
	var accel := (speed - _last_speed) / maxf(delta, 0.0001)
	_last_speed = speed
	var target_roll := -car.yaw_rate * speed * 0.004
	if car.is_drifting:
		target_roll += -car.drift_dir * drift_roll
	target_roll = clampf(target_roll, -0.12, 0.12)
	var target_pitch := clampf(accel * 0.004, -0.06, 0.06)
	var blend := 1.0 - exp(-8.0 * delta)
	_roll = lerpf(_roll, target_roll, blend)
	_pitch = lerpf(_pitch, target_pitch, blend)
	_body.rotation = Vector3(_pitch, 0.0, _roll)

	# Visual landing suspension: damped spring on the body height.
	_susp_v += (-suspension_stiffness * _susp_y - suspension_damping * _susp_v) * delta
	_susp_y = clampf(_susp_y + _susp_v * delta, -max_landing_dip, max_landing_dip)
	_body.position.y = _susp_y

	# --- Brake lights ---
	var braking := (car.brake_input > 0.1 and speed > 0.5) or car.handbrake_input
	_brake_glow = lerpf(_brake_glow, 5.0 if braking else 1.0, 1.0 - exp(-20.0 * delta))
	_taillight_mat.emission_energy_multiplier = _brake_glow


## World-space points where the rear tires touch the ground (for smoke and skid marks).
func get_rear_wheel_ground_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for pivot in _rear_pivots:
		points.append(pivot.global_position - Vector3.UP * WHEEL_RADIUS)
	return points


func _build() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)

	var paint := _material(body_color, 0.45)
	_paint_mat = paint
	_kit_mats = {
		"metal": _material(Color(0.35, 0.33, 0.3), 0.6),
		"dark": _material(Color(0.1, 0.1, 0.11), 0.5),
		"chrome": _material(Color(0.8, 0.8, 0.82), 0.2),
		"lamp": _material(Color(1.0, 0.95, 0.7), 0.3, Color(1.0, 0.9, 0.6)),
	}
	for category in ["front", "rear", "roof", "side"]:
		var kit_root := Node3D.new()
		kit_root.name = "Kit_" + category
		_body.add_child(kit_root)
		_kit_roots[category] = kit_root
	var glass := _material(Color(0.1, 0.14, 0.18), 0.15)
	var trim := _material(Color(0.2, 0.2, 0.22), 0.7)
	var headlight := _material(Color(1.0, 0.95, 0.7), 0.3, Color(1.0, 0.9, 0.6))
	_taillight_mat = _material(Color(0.9, 0.05, 0.05), 0.3, Color(0.8, 0.0, 0.0))

	# Main body, cabin (glass), roof.
	_add_box(_body, Vector3(1.8, 0.55, 4.4), Vector3(0.0, 0.68, 0.0), paint)
	_add_box(_body, Vector3(1.56, 0.48, 2.1), Vector3(0.0, 1.19, 0.35), glass)
	_add_box(_body, Vector3(1.5, 0.06, 1.8), Vector3(0.0, 1.45, 0.35), paint)

	# Bumpers.
	_add_box(_body, Vector3(1.84, 0.22, 0.15), Vector3(0.0, 0.5, -2.25), trim)
	_add_box(_body, Vector3(1.84, 0.22, 0.15), Vector3(0.0, 0.5, 2.25), trim)

	# Lights (show which way is front).
	for side in [-1.0, 1.0]:
		_add_box(_body, Vector3(0.4, 0.14, 0.05), Vector3(0.6 * side, 0.8, -2.21), headlight)
		_add_box(_body, Vector3(0.4, 0.12, 0.05), Vector3(0.6 * side, 0.8, 2.21), _taillight_mat)

	# Weapon mount on the roof.
	var roof := Node3D.new()
	roof.name = "RoofMount"
	roof.position = Vector3(0.0, 1.48, 0.35)
	_body.add_child(roof)
	_mounts["roof"] = roof

	# Wheels (not parented to the body, so they don't lean with it).
	var tire := _material(Color(0.08, 0.08, 0.08), 0.9)
	var hub := _material(Color(0.75, 0.75, 0.78), 0.4)
	for z in [-1.35, 1.35]:
		for x in [-0.86, 0.86]:
			_add_wheel(Vector3(x, WHEEL_RADIUS, z), z < 0.0, tire, hub)


func _add_wheel(pos: Vector3, is_front: bool, tire_mat: Material, hub_mat: Material) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	add_child(pivot)

	var spin := Node3D.new()
	pivot.add_child(spin)

	if is_front:
		_front_pivots.append(pivot)
		_front_spins.append(spin)
	else:
		_rear_pivots.append(pivot)
		_rear_spins.append(spin)

	var tire_mesh := CylinderMesh.new()
	tire_mesh.top_radius = WHEEL_RADIUS
	tire_mesh.bottom_radius = WHEEL_RADIUS
	tire_mesh.height = WHEEL_WIDTH
	var tire := MeshInstance3D.new()
	tire.mesh = tire_mesh
	tire.material_override = tire_mat
	tire.rotation_degrees.z = 90.0
	spin.add_child(tire)

	# A stripe across the hub so wheel spin is visible.
	_add_box(spin, Vector3(WHEEL_WIDTH + 0.02, WHEEL_RADIUS * 1.5, 0.12), Vector3.ZERO, hub_mat)


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = box
	mesh_instance.material_override = mat
	mesh_instance.position = pos
	parent.add_child(mesh_instance)
	return mesh_instance


func _material(color: Color, roughness: float, emission: Color = Color.BLACK) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if emission != Color.BLACK:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = 1.5
	return mat
