class_name Pickup
extends Node3D
## A dropped item lying on the ground. Pops out of the wreck, bobs and spins.
## - scrap: small gold-grey cube
## - part: cube in its rarity color with a name label; Rare+ get a light beam (Ragnarok-style)
## - chip: purple card with a beam
## Magnet: when the (alive) player is within magnet_radius it flies to the car; collected at
## ~2 m -> CarController.collect(item). Despawns after lifetime seconds.

@export var magnet_radius: float = 9.0
@export var lifetime: float = 90.0

var item: Dictionary = {}

var _vel: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _landed: bool = false
var _age: float = 0.0
var _mesh_root: Node3D
var _magnet_speed: float = 0.0


static func spawn(world: Node, pos: Vector3, p_item: Dictionary) -> Pickup:
	var p := Pickup.new()
	p.item = p_item
	p.position = pos + Vector3.UP * 1.0
	var a := randf() * TAU
	p._vel = Vector3(cos(a) * randf_range(2.0, 5.0), randf_range(5.0, 8.0), sin(a) * randf_range(2.0, 5.0))
	world.add_child(p)
	return p


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ground_y = _find_ground(global_position)
	_build()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age > lifetime:
		queue_free()
		return

	var player := get_tree().get_first_node_in_group("player") as CarController
	if player and player.is_alive() and _age > 0.5:
		var to := player.get_aim_point() - global_position
		var d := to.length()
		if d < 2.2:
			player.collect(item)
			queue_free()
			return
		if d < magnet_radius:
			_magnet_speed = minf(_magnet_speed + 40.0 * delta, 45.0)
			global_position += to / d * _magnet_speed * delta
			return

	# Pop-out arc, then rest on the ground and bob.
	if not _landed:
		_vel.y -= 22.0 * delta
		global_position += _vel * delta
		if global_position.y <= _ground_y + 0.5 and _vel.y < 0.0:
			global_position.y = _ground_y + 0.5
			_landed = true
	else:
		global_position.y = _ground_y + 0.5 + sin(_age * 3.0) * 0.12
	_mesh_root.rotation.y += delta * 2.0


func _find_ground(from_pos: Vector3) -> float:
	var from := from_pos + Vector3.UP * 3.0
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 20.0, Layers.GROUND)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return (hit["position"] as Vector3).y if not hit.is_empty() else from_pos.y - 1.0


func _build() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	var kind: String = item.get("kind", "scrap")
	var rarity: int = item.get("rarity", Loot.Rarity.COMMON)
	var color: Color = Loot.RARITY_COLORS[rarity]

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	var box := BoxMesh.new()
	match kind:
		"scrap":
			box.size = Vector3(0.35, 0.35, 0.35)
			mat.albedo_color = Color(0.75, 0.65, 0.4)
			mat.emission = Color(0.9, 0.7, 0.3)
			mat.emission_energy_multiplier = 0.4
		"chip":
			box.size = Vector3(0.5, 0.7, 0.08)
			mat.albedo_color = color
			mat.emission = color
			mat.emission_energy_multiplier = 1.2
		_:
			box.size = Vector3(0.5, 0.5, 0.5)
			mat.albedo_color = color
			mat.emission = color
			mat.emission_energy_multiplier = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	_mesh_root.add_child(mi)

	if kind != "scrap":
		var label := Label3D.new()
		label.text = item.get("name", "")
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.007
		label.font_size = 36
		label.outline_size = 10
		label.modulate = color
		label.position = Vector3(0.0, 0.8, 0.0)
		add_child(label)

	if kind == "chip" or rarity >= Loot.Rarity.RARE:
		# Light beam so rare drops are visible from far away.
		var beam_mat := StandardMaterial3D.new()
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.albedo_color = Color(color.r, color.g, color.b, 0.35)
		var beam := CylinderMesh.new()
		beam.top_radius = 0.08
		beam.bottom_radius = 0.18
		beam.height = 7.0
		var beam_mi := MeshInstance3D.new()
		beam_mi.mesh = beam
		beam_mi.material_override = beam_mat
		beam_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beam_mi.position = Vector3(0.0, 3.5, 0.0)
		add_child(beam_mi)
