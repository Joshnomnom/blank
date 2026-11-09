class_name GroundStrike
extends Node3D
## Telegraphed area attack on the ground (boss mortars, shockwaves).
## A red disc grows/darkens for `delay` seconds (+ optional falling shell in the last 0.4 s),
## then it blasts: explosion visual + damage/knockback to the player if inside the radius.
## Only hurts the player. Research: ENEMY_BOSS_DESIGN.md §1 (telegraph -> strike).

var radius: float = 4.0
var delay: float = 1.3
var damage: float = 30.0
var knockback: float = 12.0
var falling_shell: bool = true

var _t: float = 0.0
var _disc: MeshInstance3D
var _disc_mat: StandardMaterial3D
var _rim_mat: StandardMaterial3D
var _shell: MeshInstance3D
var _done: bool = false


static func spawn(world: Node, pos: Vector3, p_radius: float, p_delay: float, p_damage: float, p_knockback: float = 12.0, p_shell: bool = true) -> GroundStrike:
	var g := GroundStrike.new()
	g.radius = p_radius
	g.delay = p_delay
	g.damage = p_damage
	g.knockback = p_knockback
	g.falling_shell = p_shell
	g.top_level = true
	g.position = _ground(world, pos)
	world.add_child(g)
	return g


static func _ground(world: Node, pos: Vector3) -> Vector3:
	var space := (world as Node3D).get_world_3d().direct_space_state if world is Node3D else null
	if space == null:
		return pos
	var from := pos + Vector3.UP * 40.0
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 80.0, Layers.GROUND))
	return (hit["position"] as Vector3) if not hit.is_empty() else pos


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Filling disc (grows from center).
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.albedo_color = Color(1.0, 0.15, 0.05, 0.25)
	_disc_mat.no_depth_test = false
	_disc = _make_disc(1.0, 0.12, _disc_mat)
	_disc.scale = Vector3(0.05, 1.0, 0.05)
	# Rim (full size from the start, so the danger area is clear immediately).
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rim_mat.albedo_color = Color(1.0, 0.25, 0.1, 0.18)
	var rim := _make_disc(radius, 0.1, _rim_mat)
	rim.scale = Vector3.ONE

	if falling_shell:
		var shell_mat := StandardMaterial3D.new()
		shell_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shell_mat.albedo_color = Color(1.0, 0.5, 0.15)
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		_shell = MeshInstance3D.new()
		_shell.mesh = sphere
		_shell.material_override = shell_mat
		_shell.visible = false
		add_child(_shell)


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var p := clampf(_t / delay, 0.0, 1.0)
	_disc.scale = Vector3(radius * p, 1.0, radius * p)
	_disc_mat.albedo_color.a = 0.25 + 0.4 * p
	if _shell:
		var fall := clampf((_t - (delay - 0.4)) / 0.4, 0.0, 1.0)
		_shell.visible = fall > 0.0
		_shell.position = Vector3(0.0, lerpf(30.0, 0.5, fall), 0.0)
	if _t >= delay:
		_blast()


func _blast() -> void:
	_done = true
	Explosion.spawn(get_parent(), global_position + Vector3.UP * 0.6, radius, 0.0, DamageTypes.Type.EXPLOSIVE, 0.4, [])
	var player := get_tree().get_first_node_in_group("player") as CarController
	if player and player.is_alive():
		var to := player.global_position - global_position
		to.y = 0.0
		if to.length() <= radius + 1.0:
			player.take_damage(damage, player.get_aim_point(), DamageTypes.Type.EXPLOSIVE)
			var dir := to.normalized() if to.length() > 0.2 else Vector3.FORWARD
			player.apply_knockback(dir * knockback + Vector3.UP * 4.0)
	queue_free()


func _make_disc(r: float, h: float, mat: Material) -> MeshInstance3D:
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = h
	disc.radial_segments = 40
	var mi := MeshInstance3D.new()
	mi.mesh = disc
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Vector3(0.0, 0.08, 0.0)
	add_child(mi)
	return mi
