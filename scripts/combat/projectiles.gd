class_name Projectiles
extends Node3D
## Fast bullets as plain data (no node per bullet). Each physics tick every bullet raycasts
## from its old to its new position, so fast bullets never tunnel through thin targets.
## Tracers are drawn with ONE MultiMesh (stretched glowing boxes). Hits call
## take_damage(amount, position) on the collider (or its parent) and spawn impact effects.
## Collision mask 3 = solid (1) + ground (2). The shooter's own body is excluded.

@export var max_bullets: int = 128
@export var tracer_length: float = 3.0
@export var tracer_width: float = 0.07

var shooter_rid: RID
## Layers bullets hit. Player guns: solid + ground + enemies. Enemy guns: Layers.ENEMY_SHOTS.
var hit_mask: int = Layers.PLAYER_SHOTS

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _dtype := PackedInt32Array()
var _mm: MultiMesh
var _tracer_mat: StandardMaterial3D
var _sparks: Array[CPUParticles3D] = []
var _dust: Array[CPUParticles3D] = []
var _next_spark: int = 0
var _next_dust: int = 0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	_tracer_mat = StandardMaterial3D.new()
	_tracer_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_mat.albedo_color = Color(1.0, 0.85, 0.4)

	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _tracer_mat
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = box
	_mm.instance_count = max_bullets
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

	for i in 6:
		_sparks.append(_make_impact(Color(1.0, 0.7, 0.25), 0.14, 10, 0.35, 4.0, 9.0, -12.0))
		_dust.append(_make_impact(Color(0.85, 0.74, 0.56, 0.7), 0.6, 6, 0.7, 1.0, 3.0, 0.5))


func set_tracer_color(color: Color) -> void:
	_tracer_mat.albedo_color = color


func spawn(origin: Vector3, velocity: Vector3, damage: float, lifetime: float, damage_type: int = 0) -> void:
	if _pos.size() >= max_bullets:
		_remove(0)
	_pos.append(origin)
	_vel.append(velocity)
	_life.append(lifetime)
	_damage.append(damage)
	_dtype.append(damage_type)


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	var exclude: Array[RID] = [shooter_rid]
	var i := 0
	while i < _pos.size():
		var from := _pos[i]
		var to := from + _vel[i] * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask, exclude)
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			_on_hit(hit, _damage[i], _dtype[i])
			_remove(i)
			continue
		_pos[i] = to
		_life[i] -= delta
		if _life[i] <= 0.0:
			_remove(i)
			continue
		i += 1
	_update_tracers()


func _on_hit(hit: Dictionary, damage: float, damage_type: int) -> void:
	var collider: Object = hit["collider"]
	var hit_pos: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"]

	var target: Object = collider
	if not target.has_method("take_damage") and collider is Node:
		target = (collider as Node).get_parent()
	if target and target.has_method("take_damage"):
		target.call("take_damage", damage, hit_pos, damage_type)
		_play(_sparks, _next_spark, hit_pos, normal)
		_next_spark = (_next_spark + 1) % _sparks.size()
		return

	var is_ground := false
	if collider is CollisionObject3D:
		is_ground = ((collider as CollisionObject3D).collision_layer & Layers.GROUND) != 0
	if is_ground:
		_play(_dust, _next_dust, hit_pos, normal)
		_next_dust = (_next_dust + 1) % _dust.size()
	else:
		_play(_sparks, _next_spark, hit_pos, normal)
		_next_spark = (_next_spark + 1) % _sparks.size()


func _remove(i: int) -> void:
	_pos.remove_at(i)
	_vel.remove_at(i)
	_life.remove_at(i)
	_damage.remove_at(i)
	_dtype.remove_at(i)


func _update_tracers() -> void:
	var count := _pos.size()
	_mm.visible_instance_count = count
	for i in count:
		var dir := _vel[i].normalized()
		var up_ref := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
		var x := up_ref.cross(dir).normalized()
		var y := dir.cross(x).normalized()
		var basis_t := Basis(x * tracer_width, y * tracer_width, dir * tracer_length)
		_mm.set_instance_transform(i, Transform3D(basis_t, _pos[i] - dir * tracer_length * 0.5))


func _play(pool: Array[CPUParticles3D], index: int, at: Vector3, normal: Vector3) -> void:
	var p := pool[index]
	p.global_position = at + normal * 0.05
	p.direction = normal
	p.restart()
	p.emitting = true


func _make_impact(color: Color, size: float, amount: int, lifetime: float, vmin: float, vmax: float, gravity_y: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.spread = 55.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0.0, gravity_y, 0.0)
	# Shrink to nothing at the end (no color ramps / vertex colors: they render black in Compatibility).
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.6))
	curve.add_point(Vector2(0.4, 1.0))
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
	return p
