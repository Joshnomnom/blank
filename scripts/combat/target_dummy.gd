class_name TargetDummy
extends StaticBody3D
## Training target. A scrap-metal dummy on a post with a Health component and an ARMOR TYPE.
## Damage taken = damage × DamageTypes.multiplier(damage_type, armor_type).
## - LIGHT: rusty, thin. HEAVY: steel-blue with extra armor plates.
## - An armor label floats above it so players learn to read enemies and swap guns.
## On hit: white flash + damage number (golden orange if effective) + health bar.
## On death: burst of sparks, disappears, respawns after respawn_time with full HP.
## Solid (physics layer 1): the car bumps into it and bullets/explosions hit it.
## In group "targets" for the weapon aim assist.

@export var max_hp: float = 300.0
@export var respawn_time: float = 4.0
@export var armor_type: DamageTypes.Armor = DamageTypes.Armor.LIGHT

const BAR_SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix;

uniform float ratio = 1.0;
uniform vec4 fill_color : source_color = vec4(0.9, 0.18, 0.12, 1.0);
uniform vec4 back_color : source_color = vec4(0.05, 0.05, 0.05, 0.85);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec4 c = back_color;
	bool inside = UV.x > 0.02 && UV.x < 0.98 && UV.y > 0.18 && UV.y < 0.82;
	if (inside && (UV.x - 0.02) / 0.96 <= ratio) {
		c = fill_color;
	}
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
"""

var health: Health

var _visual: Node3D
var _flash_mats: Array[StandardMaterial3D] = []
var _bar: MeshInstance3D
var _bar_mat: ShaderMaterial
var _armor_label: Label3D
var _collision: CollisionShape3D
var _burst: CPUParticles3D
var _flash_tween: Tween


func _ready() -> void:
	collision_layer = 1
	add_to_group("targets")
	health = Health.new()
	health.max_hp = max_hp
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_build()


func is_alive() -> bool:
	return health.is_alive()


func get_aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.6


func get_armor_type() -> int:
	return armor_type


func take_damage(amount: float, at: Vector3, damage_type: int = DamageTypes.Type.KINETIC) -> void:
	var mult := DamageTypes.multiplier(damage_type, armor_type)
	health.take_damage(amount * mult, at, mult)


func _on_damaged(amount: float, at: Vector3, effectiveness: float) -> void:
	DamageNumber.spawn(get_tree().current_scene, at + Vector3.UP * 0.3, amount, effectiveness)
	_bar.visible = true
	_bar_mat.set_shader_parameter("ratio", health.ratio())

	# White hit flash (stronger when the hit is effective).
	if _flash_tween:
		_flash_tween.kill()
	var strength := 1.8 if DamageTypes.is_effective(effectiveness) else 1.2
	for mat in _flash_mats:
		mat.emission_energy_multiplier = strength
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	for mat in _flash_mats:
		_flash_tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.12)


func _on_died() -> void:
	_burst.global_position = get_aim_point()
	_burst.restart()
	_burst.emitting = true
	_visual.visible = false
	_bar.visible = false
	_armor_label.visible = false
	_collision.set_deferred("disabled", true)
	get_tree().create_timer(respawn_time).timeout.connect(_respawn)


func _respawn() -> void:
	health.reset()
	_visual.visible = true
	_armor_label.visible = true
	_collision.set_deferred("disabled", false)
	_bar_mat.set_shader_parameter("ratio", 1.0)


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)

	var heavy := armor_type == DamageTypes.Armor.HEAVY
	var post_mat := _make_mat(Color(0.3, 0.3, 0.32))
	var body_mat := _make_mat(Color(0.42, 0.48, 0.58) if heavy else Color(0.55, 0.38, 0.25))
	var plate_mat := _make_mat(Color(0.28, 0.32, 0.38))
	var accent_mat := _make_mat(Color(0.95, 0.75, 0.15))

	var post := CylinderMesh.new()
	post.top_radius = 0.12
	post.bottom_radius = 0.16
	post.height = 1.0
	_add_mesh(post, Vector3(0.0, 0.5, 0.0), post_mat)

	var torso := BoxMesh.new()
	torso.size = Vector3(1.1, 1.0, 0.6)
	_add_mesh(torso, Vector3(0.0, 1.5, 0.0), body_mat)

	var head := BoxMesh.new()
	head.size = Vector3(0.55, 0.45, 0.5)
	_add_mesh(head, Vector3(0.0, 2.25, 0.0), body_mat)

	if heavy:
		# Thick armor plates front/back + shoulder plates.
		var plate := BoxMesh.new()
		plate.size = Vector3(1.25, 0.9, 0.12)
		_add_mesh(plate, Vector3(0.0, 1.5, 0.36), plate_mat)
		_add_mesh(plate, Vector3(0.0, 1.5, -0.36), plate_mat)
		var shoulder := BoxMesh.new()
		shoulder.size = Vector3(0.35, 0.25, 0.75)
		_add_mesh(shoulder, Vector3(0.68, 1.95, 0.0), plate_mat)
		_add_mesh(shoulder, Vector3(-0.68, 1.95, 0.0), plate_mat)
	else:
		# Yellow target stripes.
		var stripe := BoxMesh.new()
		stripe.size = Vector3(1.12, 0.12, 0.62)
		_add_mesh(stripe, Vector3(0.0, 1.35, 0.0), accent_mat)
		_add_mesh(stripe, Vector3(0.0, 1.7, 0.0), accent_mat)

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3 if heavy else 1.2, 2.5, 0.9 if heavy else 0.8)
	_collision = CollisionShape3D.new()
	_collision.shape = shape
	_collision.position = Vector3(0.0, 1.25, 0.0)
	add_child(_collision)

	# Health bar above the head (hidden until damaged).
	var shader := Shader.new()
	shader.code = BAR_SHADER
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = shader
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 0.22)
	_bar = MeshInstance3D.new()
	_bar.mesh = quad
	_bar.material_override = _bar_mat
	_bar.position = Vector3(0.0, 2.9, 0.0)
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.visible = false
	add_child(_bar)

	# Armor type label (always visible, color coded).
	_armor_label = Label3D.new()
	_armor_label.text = DamageTypes.ARMOR_NAMES[armor_type]
	_armor_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_armor_label.pixel_size = 0.008
	_armor_label.font_size = 40
	_armor_label.outline_size = 10
	_armor_label.modulate = DamageTypes.ARMOR_COLORS[armor_type]
	_armor_label.position = Vector3(0.0, 3.25, 0.0)
	add_child(_armor_label)

	# Death burst.
	_burst = CPUParticles3D.new()
	_burst.one_shot = true
	_burst.emitting = false
	_burst.explosiveness = 1.0
	_burst.amount = 24
	_burst.lifetime = 0.8
	_burst.local_coords = false
	_burst.direction = Vector3.UP
	_burst.spread = 180.0
	_burst.initial_velocity_min = 3.0
	_burst.initial_velocity_max = 8.0
	_burst.gravity = Vector3(0.0, -12.0, 0.0)
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	_burst.scale_amount_curve = curve
	var burst_mat := StandardMaterial3D.new()
	burst_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	burst_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	burst_mat.albedo_color = Color(1.0, 0.6, 0.2)
	var burst_quad := QuadMesh.new()
	burst_quad.size = Vector2(0.25, 0.25)
	burst_quad.material = burst_mat
	_burst.mesh = burst_quad
	add_child(_burst)


func _make_mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.0
	_flash_mats.append(mat)
	return mat


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_visual.add_child(mi)
