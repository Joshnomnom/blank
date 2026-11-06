class_name Turret
extends Node3D
## Roof turret built from simple shapes: base -> yaw pivot (head) -> pitch pivot -> gun.
## Holds one gun model per weapon kind (machine gun barrel, rocket pod); set_weapon()
## switches the visible one with a short "pop in" during the swap.
## aim_at() turns toward a world point at limited speeds. on_fired() adds recoil + muzzle flash.
## Faces -Z like the car.

@export var yaw_speed: float = 8.0      ## rad/s
@export var pitch_speed: float = 6.0    ## rad/s
@export var pitch_min_deg: float = -15.0
@export var pitch_max_deg: float = 35.0

var _yaw: Node3D
var _pitch: Node3D
var _guns: Dictionary = {}       ## WeaponData.Kind -> gun root Node3D
var _muzzles: Dictionary = {}    ## WeaponData.Kind -> muzzle Node3D
var _rest_z: Dictionary = {}     ## WeaponData.Kind -> gun root rest z (for recoil)
var _recoil_amount: Dictionary = {}
var _current_kind: int = WeaponData.Kind.BULLET
var _flash: MeshInstance3D
var _recoil: float = 0.0
var _flash_time: float = 0.0
var _swap_tween: Tween
var _mg_barrel_mat: StandardMaterial3D
var _steam: CPUParticles3D


## Machine gun heat visuals: barrel glows orange-red with heat; steam vents while overheated.
func set_heat(heat: float, overheated: bool) -> void:
	_mg_barrel_mat.emission_energy_multiplier = heat * heat * 3.0
	_steam.emitting = overheated


func _ready() -> void:
	_build()
	set_weapon(WeaponData.Kind.BULLET, 0.0)


func get_muzzle_transform() -> Transform3D:
	return (_muzzles[_current_kind] as Node3D).global_transform


func set_weapon(kind: int, swap_time: float) -> void:
	_current_kind = kind
	for k in _guns:
		(_guns[k] as Node3D).visible = (k == kind)
	var gun := _guns[kind] as Node3D
	_flash.reparent(_muzzles[kind], false)
	_flash.position = Vector3(0.0, 0.0, -0.15)
	if swap_time > 0.0:
		if _swap_tween:
			_swap_tween.kill()
		gun.scale = Vector3.ONE * 0.2
		_swap_tween = create_tween()
		_swap_tween.tween_property(gun, "scale", Vector3.ONE, swap_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func aim_at(point: Vector3, delta: float) -> void:
	# Yaw: angle to the point in the turret's own (car-tilted) space.
	var lp := to_local(point) - _yaw.position
	var target_yaw := atan2(-lp.x, -lp.z)
	_yaw.rotation.y = _turn_toward(_yaw.rotation.y, target_yaw, yaw_speed * delta)

	# Pitch: angle to the point in the head's space.
	var hp := _yaw.to_local(point) - _pitch.position
	var horizontal := Vector2(hp.x, hp.z).length()
	var target_pitch := clampf(atan2(hp.y, horizontal), deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
	_pitch.rotation.x = move_toward(_pitch.rotation.x, target_pitch, pitch_speed * delta)


func on_fired() -> void:
	_recoil = _recoil_amount[_current_kind]
	_flash_time = 0.045 if _current_kind == WeaponData.Kind.BULLET else 0.09
	_flash.scale = Vector3.ONE * (1.0 if _current_kind == WeaponData.Kind.BULLET else 1.8)
	_flash.rotation.z = randf() * TAU
	_flash.visible = true


func _process(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, 1.2 * delta)
	var gun := _guns[_current_kind] as Node3D
	gun.position.z = _rest_z[_current_kind] + _recoil
	_flash_time -= delta
	if _flash_time <= 0.0:
		_flash.visible = false


func _turn_toward(current: float, target: float, max_step: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	return current + clampf(diff, -max_step, max_step)


func _build() -> void:
	var metal := _mat(Color(0.22, 0.23, 0.25), 0.6)
	var dark := _mat(Color(0.1, 0.1, 0.11), 0.5)
	var olive := _mat(Color(0.32, 0.36, 0.24), 0.7)
	var warning := _mat(Color(0.95, 0.75, 0.15), 0.6)

	var base := CylinderMesh.new()
	base.top_radius = 0.32
	base.bottom_radius = 0.36
	base.height = 0.12
	_add_mesh(self, base, Vector3(0.0, 0.06, 0.0), metal)

	_yaw = Node3D.new()
	_yaw.position = Vector3(0.0, 0.12, 0.0)
	add_child(_yaw)

	var head := BoxMesh.new()
	head.size = Vector3(0.5, 0.28, 0.6)
	_add_mesh(_yaw, head, Vector3(0.0, 0.14, 0.05), metal)

	_pitch = Node3D.new()
	_pitch.position = Vector3(0.0, 0.18, -0.15)
	_yaw.add_child(_pitch)

	# --- Machine gun: one long thin barrel ---
	var mg := Node3D.new()
	_pitch.add_child(mg)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.05
	barrel.bottom_radius = 0.06
	barrel.height = 1.0
	# Own material so it can glow with heat.
	_mg_barrel_mat = _mat(Color(0.1, 0.1, 0.11), 0.5)
	_mg_barrel_mat.emission_enabled = true
	_mg_barrel_mat.emission = Color(1.0, 0.35, 0.08)
	_mg_barrel_mat.emission_energy_multiplier = 0.0
	var barrel_mi := _add_mesh(mg, barrel, Vector3.ZERO, _mg_barrel_mat)
	barrel_mi.rotation_degrees.x = 90.0
	_register_gun(WeaponData.Kind.BULLET, mg, -0.5, Vector3(0.0, 0.0, -0.55), 0.12)

	# Steam venting from the barrel while overheated.
	_steam = CPUParticles3D.new()
	_steam.emitting = false
	_steam.amount = 16
	_steam.lifetime = 0.9
	_steam.local_coords = false
	_steam.direction = Vector3.UP
	_steam.spread = 25.0
	_steam.initial_velocity_min = 0.6
	_steam.initial_velocity_max = 1.4
	_steam.gravity = Vector3(0.0, 1.0, 0.0)
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_steam.emission_box_extents = Vector3(0.04, 0.04, 0.45)
	var steam_curve := Curve.new()
	steam_curve.add_point(Vector2(0.0, 0.3))
	steam_curve.add_point(Vector2(0.5, 1.0))
	steam_curve.add_point(Vector2(1.0, 0.0))
	_steam.scale_amount_curve = steam_curve
	var steam_mat := StandardMaterial3D.new()
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.albedo_color = Color(0.92, 0.92, 0.95, 0.5)
	var steam_quad := QuadMesh.new()
	steam_quad.size = Vector2(0.3, 0.3)
	steam_quad.material = steam_mat
	_steam.mesh = steam_quad
	mg.add_child(_steam)

	# --- Rocket launcher: boxy pod with two tubes ---
	var pod := Node3D.new()
	_pitch.add_child(pod)
	var pod_box := BoxMesh.new()
	pod_box.size = Vector3(0.5, 0.34, 0.85)
	_add_mesh(pod, pod_box, Vector3.ZERO, olive)
	var stripe := BoxMesh.new()
	stripe.size = Vector3(0.52, 0.06, 0.3)
	_add_mesh(pod, stripe, Vector3(0.0, 0.0, 0.15), warning)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.09
	tube.bottom_radius = 0.09
	tube.height = 0.06
	for x in [-0.12, 0.12]:
		var tube_mi := _add_mesh(pod, tube, Vector3(x, 0.0, -0.43), dark)
		tube_mi.rotation_degrees.x = 90.0
	_register_gun(WeaponData.Kind.ROCKET, pod, -0.3, Vector3(0.0, 0.0, -0.5), 0.2)

	# Muzzle flash: bright billboard quad, moved to the current gun's muzzle.
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.85, 0.4)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.billboard_keep_scale = true
	var flash_quad := QuadMesh.new()
	flash_quad.size = Vector2(0.45, 0.45)
	_flash = MeshInstance3D.new()
	_flash.mesh = flash_quad
	_flash.material_override = flash_mat
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	(_muzzles[WeaponData.Kind.BULLET] as Node3D).add_child(_flash)


func _register_gun(kind: int, root: Node3D, rest_z: float, muzzle_pos: Vector3, recoil: float) -> void:
	root.position = Vector3(0.0, 0.0, rest_z)
	var muzzle := Node3D.new()
	muzzle.position = muzzle_pos
	root.add_child(muzzle)
	_guns[kind] = root
	_muzzles[kind] = muzzle
	_rest_z[kind] = rest_z
	_recoil_amount[kind] = recoil


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
