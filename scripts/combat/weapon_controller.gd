class_name WeaponController
extends Node3D
## Phase 2 step 1: mouse-aimed roof turret with ONE gun (machine gun).
## Child of a CarController (with a SedanModel "Model" that provides a "roof" mount).
##
## Aiming: a ray from the camera through the mouse finds the aim point (ground, walls,
## targets). Light AIM ASSIST: if a live target (group "targets") is within
## aim_assist_radius_px of the cursor on screen, aim at its center instead.
## The turret turns toward the aim point at limited speed; bullets leave along the barrel.
## Hold LMB to fire. ESC shows / hides the mouse cursor.
##
## Planned (not implemented): several guns, Q / E to swap, each gun has a skill with a cooldown.

@export var aim_assist_radius_px: float = 70.0
@export var aim_ray_length: float = 400.0

var weapons: Array[WeaponData] = []
var current: int = 0
var aim_point: Vector3 = Vector3.ZERO
var aim_target: Node3D = null

var _car: CarController
var _turret: Turret
var _projectiles: Projectiles
var _cooldown: float = 0.0
var _crosshair: Crosshair
var _weapon_label: Label


func _ready() -> void:
	_car = get_parent() as CarController
	weapons = [WeaponData.make_machine_gun()]

	var model := _car.get_node("Model") as SedanModel
	_turret = Turret.new()
	model.get_mount("roof").add_child(_turret)

	_projectiles = Projectiles.new()
	add_child(_projectiles)
	_projectiles.shooter_rid = _car.get_rid()
	_projectiles.set_tracer_color(weapons[current].tracer_color)

	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	aim_point = _car.global_position - _car.global_basis.z * 20.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_cursor"):
		var hidden := Input.mouse_mode == Input.MOUSE_MODE_HIDDEN
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if hidden else Input.MOUSE_MODE_HIDDEN
		_crosshair.visible = not hidden


func _physics_process(delta: float) -> void:
	_update_aim()
	_turret.aim_at(aim_point, delta)

	var weapon := weapons[current]
	_cooldown -= delta
	if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		while _cooldown <= 0.0:
			_fire(weapon)
			_cooldown += 1.0 / weapon.fire_rate
	elif _cooldown < 0.0:
		_cooldown = 0.0


func _process(_delta: float) -> void:
	_crosshair.locked = aim_target != null
	var size := get_viewport().get_visible_rect().size
	_weapon_label.position = Vector2(size.x - 280.0, size.y - 70.0)


func _update_aim() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var weapon := weapons[current]

	# Aim assist: nearest live target to the cursor on screen.
	aim_target = null
	var best := aim_assist_radius_px
	for node in get_tree().get_nodes_in_group("targets"):
		if not node.call("is_alive"):
			continue
		var p: Vector3 = node.call("get_aim_point")
		if cam.is_position_behind(p) or p.distance_to(_car.global_position) > weapon.max_range:
			continue
		var d := cam.unproject_position(p).distance_to(mouse)
		if d < best:
			best = d
			aim_target = node as Node3D
	if aim_target:
		aim_point = aim_target.call("get_aim_point")
		return

	# Otherwise: whatever is under the cursor.
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var to := from + dir * aim_ray_length
	var query := PhysicsRayQueryParameters3D.create(from, to, 3, [_car.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	aim_point = hit["position"] if not hit.is_empty() else to


func _fire(weapon: WeaponData) -> void:
	var muzzle := _turret.get_muzzle_transform()
	var dir := (-muzzle.basis.z).normalized()

	# Random spread inside a cone.
	var side := dir.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var angle := randf() * TAU
	var amount := tan(deg_to_rad(weapon.spread_deg)) * sqrt(randf())
	dir = (dir + (side * cos(angle) + up * sin(angle)) * amount).normalized()

	var damage := weapon.damage * randf_range(0.9, 1.1)
	var lifetime := weapon.max_range / weapon.projectile_speed
	_projectiles.spawn(muzzle.origin, dir * weapon.projectile_speed, damage, lifetime)
	_turret.on_fired()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)

	_crosshair = Crosshair.new()
	layer.add_child(_crosshair)

	_weapon_label = Label.new()
	_weapon_label.text = "%s\nLMB fire  ·  ESC cursor" % weapons[current].display_name.to_upper()
	_weapon_label.add_theme_font_size_override("font_size", 20)
	_weapon_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_weapon_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_weapon_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_weapon_label)
