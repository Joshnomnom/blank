class_name Turret
extends Node3D
## Roof turret built from simple shapes: base -> yaw pivot (head) -> pitch pivot -> barrel -> muzzle.
## aim_at() turns it toward a world point at limited speeds. on_fired() adds recoil + muzzle flash.
## Faces -Z like the car.

@export var yaw_speed: float = 8.0      ## rad/s
@export var pitch_speed: float = 6.0    ## rad/s
@export var pitch_min_deg: float = -15.0
@export var pitch_max_deg: float = 35.0

const BARREL_LENGTH := 1.0

var _yaw: Node3D
var _pitch: Node3D
var _barrel: Node3D
var _muzzle: Node3D
var _flash: MeshInstance3D
var _recoil: float = 0.0
var _flash_time: float = 0.0


func _ready() -> void:
	_build()


func get_muzzle_transform() -> Transform3D:
	return _muzzle.global_transform


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
	_recoil = 0.12
	_flash_time = 0.045
	_flash.rotation.z = randf() * TAU
	_flash.visible = true


func _process(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, 1.2 * delta)
	_barrel.position.z = -BARREL_LENGTH * 0.5 + _recoil
	_flash_time -= delta
	if _flash_time <= 0.0:
		_flash.visible = false


func _turn_toward(current: float, target: float, max_step: float) -> float:
	var diff := wrapf(target - current, -PI, PI)
	return current + clampf(diff, -max_step, max_step)


func _build() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.22, 0.23, 0.25)
	metal.roughness = 0.6
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.1, 0.11)
	dark.roughness = 0.5

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

	_barrel = Node3D.new()
	_barrel.position = Vector3(0.0, 0.0, -BARREL_LENGTH * 0.5)
	_pitch.add_child(_barrel)
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.05
	barrel_mesh.bottom_radius = 0.06
	barrel_mesh.height = BARREL_LENGTH
	var barrel_mi := _add_mesh(_barrel, barrel_mesh, Vector3.ZERO, dark)
	barrel_mi.rotation_degrees.x = 90.0

	_muzzle = Node3D.new()
	_muzzle.position = Vector3(0.0, 0.0, -BARREL_LENGTH * 0.5 - 0.05)
	_barrel.add_child(_muzzle)

	# Muzzle flash: bright billboard quad, shown for a few frames per shot.
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.85, 0.4)
	flash_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flash_mat.billboard_keep_scale = true
	var flash_quad := QuadMesh.new()
	flash_quad.size = Vector2(0.45, 0.45)
	_flash = _add_mesh(_muzzle, flash_quad, Vector3(0.0, 0.0, -0.15), flash_mat)
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false


func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi
