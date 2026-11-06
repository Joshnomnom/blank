class_name WorldBuilder
extends RefCounted
## Shared helpers for building test worlds in code: sky, sun, fog, grid ground material,
## striped walls, wall flag poles, outer desert plane and distant landmarks.
## Used by test_arena.gd (Phase 0 flat arena) and terrain_test.gd (Phase 1).

const GROUND_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec3 base_color : source_color = vec3(0.86, 0.72, 0.5);
uniform vec3 line_color : source_color = vec3(0.62, 0.48, 0.3);
uniform float cell = 10.0;
uniform float line_width = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 f = fract(world_pos.xz / cell);
	vec2 d = min(f, 1.0 - f) * cell;
	float line = 1.0 - smoothstep(line_width, line_width + 0.06, min(d.x, d.y));
	// Slightly darker in dips, lighter on crests, so dunes read better.
	float height_tint = 0.94 + clamp(world_pos.y, -4.0, 12.0) * 0.012;
	ALBEDO = mix(base_color, line_color, line) * height_tint;
	ROUGHNESS = 0.95;
}
"""

const WALL_SHADER := """
shader_type spatial;

uniform vec3 color_a : source_color = vec3(0.62, 0.46, 0.36);
uniform vec3 color_b : source_color = vec3(0.85, 0.82, 0.76);
uniform float stripe = 4.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float s = step(0.5, fract((world_pos.x + world_pos.z) / (stripe * 2.0)));
	ALBEDO = mix(color_a, color_b, s);
	ROUGHNESS = 0.9;
}
"""

const SAND_BASE := Color(0.86, 0.72, 0.5)
const SAND_LINE := Color(0.62, 0.48, 0.3)


static func make_ground_material(base: Color, line: Color, cell: float = 10.0) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("line_color", line)
	mat.set_shader_parameter("cell", cell)
	return mat


static func add_environment(parent: Node) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.55, 0.8)
	sky_material.sky_horizon_color = Color(0.93, 0.8, 0.62)
	sky_material.ground_horizon_color = Color(0.93, 0.8, 0.62)
	sky_material.ground_bottom_color = Color(0.5, 0.4, 0.3)

	var sky := Sky.new()
	sky.sky_material = sky_material

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.9, 0.8, 0.65)
	env.fog_density = 0.0015

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)


static func add_sun(parent: Node) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	parent.add_child(sun)


static func add_outer_ground(parent: Node, size: float = 1400.0) -> void:
	# Visual-only desert floor out to the landmarks (no collision).
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.84, 0.7, 0.5)
	mat.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	var mesh := MeshInstance3D.new()
	mesh.mesh = plane
	mesh.material_override = mat
	mesh.position = Vector3(0.0, -0.05, 0.0)
	parent.add_child(mesh)


static func add_walls(parent: Node, arena_size: float, wall_height: float, wall_thickness: float) -> void:
	var half := arena_size * 0.5
	var t := wall_thickness
	var h := wall_height
	var long_side := arena_size + t * 2.0

	var shader := Shader.new()
	shader.code = WALL_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader

	_add_wall(parent, Vector3(0.0, h * 0.5, -half - t * 0.5), Vector3(long_side, h, t), mat)
	_add_wall(parent, Vector3(0.0, h * 0.5, half + t * 0.5), Vector3(long_side, h, t), mat)
	_add_wall(parent, Vector3(-half - t * 0.5, h * 0.5, 0.0), Vector3(t, h, arena_size), mat)
	_add_wall(parent, Vector3(half + t * 0.5, h * 0.5, 0.0), Vector3(t, h, arena_size), mat)


static func _add_wall(parent: Node, pos: Vector3, size: Vector3, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	parent.add_child(body)

	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)

	var box := BoxMesh.new()
	box.size = size
	var mesh := MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)


static func add_wall_poles(parent: Node, arena_size: float, wall_height: float, wall_thickness: float, spacing: float = 10.0) -> void:
	# Tall poles with flags standing on the walls. One MultiMesh each = cheap.
	var half := arena_size * 0.5 + wall_thickness * 0.5
	var positions: Array[Vector3] = []
	var count := int(arena_size / spacing)
	for i in count + 1:
		var p := -arena_size * 0.5 + i * spacing
		positions.append(Vector3(p, 0.0, -half))
		positions.append(Vector3(p, 0.0, half))
		if i > 0 and i < count:
			positions.append(Vector3(-half, 0.0, p))
			positions.append(Vector3(half, 0.0, p))

	var pole_height := 4.0
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.15, pole_height, 0.15)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.25, 0.25, 0.27)
	pole_mesh.material = pole_mat

	var flag_mesh := BoxMesh.new()
	flag_mesh.size = Vector3(0.05, 0.7, 1.1)
	var flag_mat := StandardMaterial3D.new()
	flag_mat.albedo_color = Color(0.95, 0.45, 0.1)
	flag_mesh.material = flag_mat

	_add_multimesh(parent, pole_mesh, positions, wall_height + pole_height * 0.5, Vector3.ZERO)
	_add_multimesh(parent, flag_mesh, positions, wall_height + pole_height - 0.4, Vector3(0.0, 0.0, 0.6))


static func _add_multimesh(parent: Node, mesh: Mesh, positions: Array[Vector3], y: float, offset: Vector3) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = positions.size()
	for i in positions.size():
		var p := positions[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x, y, p.z) + offset))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	parent.add_child(mmi)


static func add_landmarks(parent: Node, arena_half: float, landmark_seed: int = 7) -> void:
	# Mesas and towers far outside the walls, so you always know which way you face.
	var rng := RandomNumberGenerator.new()
	rng.seed = landmark_seed

	var mesa_mat := StandardMaterial3D.new()
	mesa_mat.albedo_color = Color(0.72, 0.45, 0.3)
	mesa_mat.roughness = 1.0
	for i in 10:
		var angle := TAU * float(i) / 10.0 + rng.randf_range(-0.2, 0.2)
		var dist := rng.randf_range(arena_half + 80.0, arena_half + 280.0)
		var radius := rng.randf_range(18.0, 45.0)
		var height := rng.randf_range(25.0, 70.0)
		var mesa := CylinderMesh.new()
		mesa.top_radius = radius * 0.8
		mesa.bottom_radius = radius
		mesa.height = height
		mesa.radial_segments = 10
		var mi := MeshInstance3D.new()
		mi.mesh = mesa
		mi.material_override = mesa_mat
		mi.position = Vector3(cos(angle) * dist, height * 0.5, sin(angle) * dist)
		parent.add_child(mi)

	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.3, 0.28, 0.27)
	for i in 3:
		var angle := TAU * float(i) / 3.0 + 0.5
		var tower := BoxMesh.new()
		tower.size = Vector3(5.0, 90.0, 5.0)
		var mi := MeshInstance3D.new()
		mi.mesh = tower
		mi.material_override = tower_mat
		var dist := arena_half + 20.0
		mi.position = Vector3(cos(angle) * dist, 45.0, sin(angle) * dist)
		parent.add_child(mi)
