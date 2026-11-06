class_name Rocket
extends Node3D
## One rocket in flight. Moves in a straight line; each physics tick raycasts its path
## (mask 3 = solid + ground, shooter excluded). Explodes on the first hit or at max range.
## Visual: small body + glowing exhaust + smoke trail (trail lingers after the explosion).

var velocity: Vector3 = Vector3.ZERO
var life: float = 2.5
var weapon: WeaponData
var damage: float = 90.0
var shooter_rid: RID

var _trail: CPUParticles3D
var _body: Node3D
var _dead: bool = false


func setup(p_weapon: WeaponData, p_velocity: Vector3, p_damage: float, p_shooter: RID) -> void:
	weapon = p_weapon
	velocity = p_velocity
	damage = p_damage
	shooter_rid = p_shooter
	life = weapon.max_range / maxf(weapon.projectile_speed, 1.0)


func _ready() -> void:
	top_level = true
	_build()
	if velocity.length_squared() > 0.0:
		look_at(global_position + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [shooter_rid])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit["position"]
		var normal: Vector3 = hit["normal"]
		_explode(hit_pos + normal * 0.2)
		return
	global_position = to
	life -= delta
	if life <= 0.0:
		_explode(global_position)


func _explode(at: Vector3) -> void:
	_dead = true
	Explosion.spawn(get_parent(), at, weapon.explosion_radius, damage, weapon.damage_type, weapon.splash_min, [shooter_rid])
	_body.visible = false
	_trail.emitting = false
	get_tree().create_timer(_trail.lifetime + 0.1).timeout.connect(queue_free)


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)

	var shell_mat := StandardMaterial3D.new()
	shell_mat.albedo_color = Color(0.3, 0.32, 0.28)
	var shell := CylinderMesh.new()
	shell.top_radius = 0.07
	shell.bottom_radius = 0.09
	shell.height = 0.6
	var shell_mi := MeshInstance3D.new()
	shell_mi.mesh = shell
	shell_mi.material_override = shell_mat
	shell_mi.rotation_degrees.x = 90.0
	_body.add_child(shell_mi)

	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.albedo_color = Color(1.0, 0.7, 0.3)
	var glow := QuadMesh.new()
	glow.size = Vector2(0.4, 0.4)
	var glow_mi := MeshInstance3D.new()
	glow_mi.mesh = glow
	glow_mi.material_override = glow_mat
	glow_mi.position = Vector3(0.0, 0.0, 0.35)
	glow_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_body.add_child(glow_mi)

	_trail = CPUParticles3D.new()
	_trail.amount = 40
	_trail.lifetime = 0.7
	_trail.local_coords = false
	_trail.position = Vector3(0.0, 0.0, 0.35)
	_trail.direction = Vector3(0.0, 0.0, 1.0)
	_trail.spread = 15.0
	_trail.initial_velocity_min = 0.5
	_trail.initial_velocity_max = 1.5
	_trail.gravity = Vector3(0.0, 0.6, 0.0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.4))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_trail.scale_amount_curve = curve
	var smoke_mat := StandardMaterial3D.new()
	smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke_mat.albedo_color = Color(0.75, 0.72, 0.68, 0.45)
	var smoke_quad := QuadMesh.new()
	smoke_quad.size = Vector2(0.5, 0.5)
	smoke_quad.material = smoke_mat
	_trail.mesh = smoke_quad
	add_child(_trail)
	_trail.emitting = true
