class_name GarageZone
extends Node3D
## TEMPORARY town garage (Phase 4 step 2) until real towns exist.
## A painted pad with an open shed (visual only, NO collision) and a glowing ring.
## Drive onto the pad, slow down below max_open_speed, press F -> GarageScreen
## (gun loadout, tuning +1..+10, body kits). The car is held still while it's open.

@export var radius: float = 9.0
@export var max_open_speed: float = 3.0

var _prompt: Label3D
var _screen: GarageScreen
var _ring_mat: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	_build()
	var layer := CanvasLayer.new()
	layer.layer = 8
	add_child(layer)
	_screen = GarageScreen.new()
	_screen.closed.connect(_on_closed)
	layer.add_child(_screen)


func _car() -> CarController:
	return get_tree().get_first_node_in_group("player") as CarController


func _player_inside() -> bool:
	var car := _car()
	if car == null or not car.is_alive():
		return false
	var d := car.global_position - global_position
	d.y = 0.0
	return d.length() <= radius


func _process(delta: float) -> void:
	_time += delta
	var inside := _player_inside()
	_ring_mat.emission_energy_multiplier = (1.6 if inside else 0.6) + 0.3 * sin(_time * 3.0)
	_prompt.visible = inside and not _screen.visible
	if inside:
		var slow := absf(_car().speed) <= max_open_speed
		_prompt.text = "[F]  OPEN GARAGE" if slow else "Stop to open the garage"
		_prompt.modulate = Color(1.0, 0.85, 0.4) if slow else Color(0.8, 0.8, 0.8)


func _unhandled_input(event: InputEvent) -> void:
	if _screen.visible or not event.is_action_pressed("interact"):
		return
	if not _player_inside():
		return
	var car := _car()
	var weapons := car.get_node_or_null("Weapons") as WeaponController
	if absf(car.speed) > max_open_speed or (weapons and weapons.ui_open) or car.status == null:
		return
	car.controls_enabled = false
	car.speed = 0.0
	if weapons:
		weapons.set_menu_open(true)
	_screen.open(car.status)
	get_viewport().set_input_as_handled()


func _on_closed() -> void:
	var car := _car()
	if car == null:
		return
	if car.is_alive():
		car.controls_enabled = true
	var weapons := car.get_node_or_null("Weapons") as WeaponController
	if weapons:
		weapons.set_menu_open(false)


func _build() -> void:
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.35, 0.33, 0.3)
	metal.roughness = 0.7
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color(0.55, 0.3, 0.15)
	roof_mat.roughness = 0.8

	# Shed: 4 posts + roof over the back half of the pad (no collision on purpose).
	for x in [-7.0, 7.0]:
		for z in [-1.0, 7.0]:
			_box(Vector3(0.35, 5.0, 0.35), Vector3(x, 2.5, z), metal)
	var roof := _box(Vector3(15.0, 0.3, 9.0), Vector3(0.0, 5.1, 3.0), roof_mat)
	roof.rotation.x = 0.06
	# Back wall panel + tool bench look.
	_box(Vector3(14.0, 2.4, 0.2), Vector3(0.0, 1.2, 7.4), metal)
	_box(Vector3(4.0, 0.9, 1.0), Vector3(-4.0, 0.45, 6.6), roof_mat)

	# Glowing ring marking the zone.
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Color(1.0, 0.7, 0.2)
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Color(1.0, 0.6, 0.15)
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.25
	ring.outer_radius = radius
	ring.rings = 48
	ring.ring_segments = 4
	var ring_mi := MeshInstance3D.new()
	ring_mi.mesh = ring
	ring_mi.material_override = _ring_mat
	ring_mi.scale = Vector3(1.0, 0.15, 1.0)
	ring_mi.position.y = 0.06
	ring_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring_mi)

	# Sign + prompt.
	var sign := Label3D.new()
	sign.text = "GARAGE"
	sign.font_size = 160
	sign.outline_size = 24
	sign.modulate = Color(1.0, 0.75, 0.3)
	sign.position = Vector3(0.0, 6.4, -1.2)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sign)
	_prompt = Label3D.new()
	_prompt.font_size = 72
	_prompt.outline_size = 16
	_prompt.position = Vector3(0.0, 3.2, 0.0)
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.visible = false
	add_child(_prompt)


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi
