class_name OrbProjectiles
extends Node3D
## Boss "bullet hell" orbs: big, bright, SLOW projectiles that read clearly from the camera
## (research: ENEMY_BOSS_DESIGN.md §4). Data-driven (arrays) + ONE MultiMesh of glowing spheres.
## Orbs fly straight; they only hurt the PLAYER: hit when within hit_radius of the car's
## center (smaller than the car's visual size, so near-misses feel fair). They vanish when
## they hit, run out of lifetime, or touch solid geometry (cheap ray check).
## Shared node: OrbProjectiles.get_shared(tree) creates it once (group "boss_orbs").

@export var max_orbs: int = 400
@export var orb_radius: float = 0.55
## Player hitbox radius around the car center (generous to the player).
@export var hit_radius: float = 1.3

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _life := PackedFloat32Array()
var _damage := PackedFloat32Array()
var _mm: MultiMesh
var _check_walls_timer: float = 0.0


static func get_shared(tree: SceneTree) -> OrbProjectiles:
	var n := tree.get_first_node_in_group("boss_orbs") as OrbProjectiles
	if n == null:
		n = OrbProjectiles.new()
		n.add_to_group("boss_orbs")
		tree.current_scene.add_child(n)
	return n


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.45, 0.12)
	var sphere := SphereMesh.new()
	sphere.radius = orb_radius
	sphere.height = orb_radius * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = mat

	# Bright core inside each orb for readability.
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = sphere
	_mm.instance_count = max_orbs
	_mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func spawn(origin: Vector3, velocity: Vector3, damage: float, lifetime: float = 4.0) -> void:
	if _pos.size() >= max_orbs:
		return
	_pos.append(origin)
	_vel.append(velocity)
	_life.append(lifetime)
	_damage.append(damage)


func clear() -> void:
	_pos.clear()
	_vel.clear()
	_life.clear()
	_damage.clear()


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CarController
	var player_pos := player.get_aim_point() if player and player.is_alive() else Vector3(INF, INF, INF)
	var space := get_world_3d().direct_space_state
	_check_walls_timer -= delta
	var check_walls := _check_walls_timer <= 0.0
	if check_walls:
		_check_walls_timer = 0.1

	var i := 0
	while i < _pos.size():
		var from := _pos[i]
		var to := from + _vel[i] * delta
		_life[i] -= delta
		# Hit the player? (closest point on this tick's segment to the car center)
		if player_pos.x != INF:
			var seg := to - from
			var t := clampf((player_pos - from).dot(seg) / maxf(seg.length_squared(), 0.0001), 0.0, 1.0)
			if (from + seg * t).distance_to(player_pos) < hit_radius + orb_radius:
				player.take_damage(_damage[i], player_pos, DamageTypes.Type.EXPLOSIVE)
				Explosion.spawn(self, from + seg * t, 1.4, 0.0, DamageTypes.Type.EXPLOSIVE, 0.4, [])
				_remove(i)
				continue
		# Solid geometry (walls, ramps, ground) - checked 10×/s with a longer ray.
		if check_walls:
			var q := PhysicsRayQueryParameters3D.create(from, from + _vel[i] * 0.1, Layers.SIGHT_BLOCKERS)
			if not space.intersect_ray(q).is_empty():
				_remove(i)
				continue
		if _life[i] <= 0.0:
			_remove(i)
			continue
		_pos[i] = to
		i += 1

	var count := _pos.size()
	_mm.visible_instance_count = count
	for k in count:
		_mm.set_instance_transform(k, Transform3D(Basis(), _pos[k]))


func _remove(i: int) -> void:
	_pos.remove_at(i)
	_vel.remove_at(i)
	_life.remove_at(i)
	_damage.remove_at(i)
