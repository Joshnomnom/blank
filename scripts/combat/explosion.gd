class_name Explosion
extends Node3D
## Reusable explosion: AREA DAMAGE + visuals + camera shake. Used by rockets now;
## grenades, mines and boss attacks later.
## Damage: every damageable (take_damage) on physics layer 1 inside the radius, once each,
## with linear falloff from 1.0 at the center to splash_min at the edge.
## Visuals: expanding flash sphere, fireball + smoke particles, short orange light.
## No vertex colors / color ramps on particles (they render black in Compatibility).

var radius: float = 6.0
var damage: float = 90.0
var damage_type: int = DamageTypes.Type.EXPLOSIVE
var splash_min: float = 0.4
var exclude: Array[RID] = []
## Physics layers damaged (default: solid + enemies = player rockets). damage 0 = visual only.
var mask: int = Layers.SOLID | Layers.ENEMY


static func spawn(parent: Node, pos: Vector3, p_radius: float, p_damage: float, p_type: int, p_splash_min: float, p_exclude: Array[RID], p_mask: int = Layers.SOLID | Layers.ENEMY) -> Explosion:
	var e := Explosion.new()
	e.radius = p_radius
	e.damage = p_damage
	e.damage_type = p_type
	e.splash_min = p_splash_min
	e.exclude = p_exclude
	e.mask = p_mask
	e.top_level = true
	# Set BEFORE add_child: _ready() (damage query) runs inside add_child.
	# top_level, so this local position is the world position.
	e.position = pos
	parent.add_child(e)
	return e


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_apply_damage()
	_build_visuals()
	_shake_camera()
	get_tree().create_timer(1.6).timeout.connect(queue_free)


func _apply_damage() -> void:
	if damage <= 0.0:
		return
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = sphere
	params.transform = Transform3D(Basis(), global_position)
	params.collision_mask = mask
	params.exclude = exclude
	var results := get_world_3d().direct_space_state.intersect_shape(params, 32)

	var done := {}
	for r in results:
		var target: Object = r["collider"]
		if not target.has_method("take_damage") and target is Node:
			target = (target as Node).get_parent()
		if target == null or not target.has_method("take_damage") or done.has(target):
			continue
		done[target] = true
		var at: Vector3 = (target as Node3D).global_position
		if target.has_method("get_aim_point"):
			at = target.call("get_aim_point")
		var t := clampf(global_position.distance_to(at) / radius, 0.0, 1.0)
		var amount := damage * lerpf(1.0, splash_min, t)
		target.call("take_damage", amount, at, damage_type)


func _build_visuals() -> void:
	# Flash sphere: grows and fades fast.
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flash_mat.albedo_color = Color(1.0, 0.75, 0.3, 0.85)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = 1.0
	sphere_mesh.height = 2.0
	var flash := MeshInstance3D.new()
	flash.mesh = sphere_mesh
	flash.material_override = flash_mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.scale = Vector3.ONE * 0.3
	add_child(flash)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * radius * 0.85, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(flash_mat, "albedo_color:a", 0.0, 0.3)

	# Light flash.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.omni_range = radius * 2.5
	light.light_energy = 6.0
	add_child(light)
	tween.tween_property(light, "light_energy", 0.0, 0.35)

	# Fireball and smoke.
	_add_particles(Color(1.0, 0.55, 0.15), radius * 0.35, 22, 0.55, 4.0, 10.0, 2.0, 6.0, false)
	_add_particles(Color(0.35, 0.33, 0.3, 0.6), radius * 0.55, 14, 1.4, 1.0, 4.0, 1.5, 2.0, true)


func _add_particles(color: Color, size: float, amount: int, lifetime: float, vmin: float, vmax: float, gravity_y: float, damping: float, grow: bool) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0.0, gravity_y, 0.0)
	p.damping_min = damping
	p.damping_max = damping
	var curve := Curve.new()
	if grow:
		curve.add_point(Vector2(0.0, 0.5))
		curve.add_point(Vector2(0.6, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
	else:
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.0))
	p.scale_amount_curve = curve

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	p.mesh = quad
	add_child(p)
	p.emitting = true


func _shake_camera() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and cam.has_method("add_trauma"):
		var dist := cam.global_position.distance_to(global_position)
		var amount := clampf(1.0 - dist / 45.0, 0.0, 1.0) * 0.55
		if amount > 0.0:
			cam.call("add_trauma", amount)
