extends Node3D
## Tire dust/smoke and skid marks at the rear wheels.
## Intensity = max(tire slip, surface dust trail at speed).
## - tire slip comes from CarController.tire_slip (drift angle, burnout, handbrake, hard braking)
## - dust trail: loose surfaces (dirt, sand) kick up dust from speed alone
## Dust color and skid-mark color follow the current surface (scripts/world/surfaces.gd).
## Must be a child of a CarController that has a SedanModel child named "Model".

## Max dust opacity.
@export var smoke_alpha: float = 0.6
## Intensity needed before dust appears.
@export var smoke_threshold: float = 0.15
## Slip needed before skid marks are drawn.
@export var skid_threshold: float = 0.25

const SMOKE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec3 dust_color : source_color = vec3(0.86, 0.76, 0.6);

varying float v_fade;

void vertex() {
	// Billboard: face the camera, keep the particle's scale.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	// CPUParticles store the lifetime progress (0..1) in INSTANCE_CUSTOM.y.
	v_fade = 1.0 - clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
}

void fragment() {
	float d = length(UV - vec2(0.5)) * 2.0;
	float circle = 1.0 - smoothstep(0.3, 1.0, d);
	ALBEDO = dust_color;
	ALPHA = circle * COLOR.a * v_fade;
}
"""

var _car: CarController
var _model: SedanModel
var _smokes: Array[CPUParticles3D] = []
var _smoke_mats: Array[ShaderMaterial] = []
var _skids: SkidMarks
var _last_surface: StringName = &""


func _ready() -> void:
	_car = get_parent() as CarController
	_model = _car.get_node("Model") as SedanModel
	for i in 2:
		var smoke := _make_smoke()
		add_child(smoke)
		_smokes.append(smoke)
	_skids = SkidMarks.new()
	add_child(_skids)


func _physics_process(delta: float) -> void:
	var data := Surfaces.get_data(_car.current_surface)
	if _car.current_surface != _last_surface:
		_last_surface = _car.current_surface
		var c: Color = data["dust_color"]
		for mat in _smoke_mats:
			mat.set_shader_parameter("dust_color", Color(c.r, c.g, c.b))

	var points := _model.get_rear_wheel_ground_points()
	var slip := _car.tire_slip if _car.on_ground else 0.0
	var trail := 0.0
	if _car.on_ground:
		var dust_trail: float = data["dust_trail"]
		trail = dust_trail * clampf((absf(_car.speed) - 6.0) / 20.0, 0.0, 1.0)
	var amount := maxf(slip, trail)
	var skid_index: float = data["skid_index"]

	for i in mini(points.size(), _smokes.size()):
		var smoke := _smokes[i]
		smoke.global_position = points[i] + Vector3.UP * 0.2
		smoke.emitting = amount > smoke_threshold
		smoke.scale_amount_min = lerpf(0.6, 1.4, amount)
		smoke.scale_amount_max = lerpf(1.2, 2.8, amount)
		smoke.color = Color(1.0, 1.0, 1.0, smoke_alpha * amount)
		_skids.update_wheel(i, points[i], slip > skid_threshold, slip, skid_index)

	_skids.tick(delta)


func _make_smoke() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 32
	p.lifetime = 1.4
	p.local_coords = false
	p.emitting = false
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0.0, 0.8, 0.0)
	p.damping_min = 0.5
	p.damping_max = 1.0

	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 1.0))
	p.scale_amount_curve = grow

	# Custom shader instead of StandardMaterial3D + vertex colors (those rendered black in
	# the Compatibility renderer): color from a uniform, procedural soft circle,
	# alpha = particle color alpha (intensity) × fade over the particle's lifetime.
	var shader := Shader.new()
	shader.code = SMOKE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_smoke_mats.append(mat)

	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	quad.material = mat
	p.mesh = quad
	return p
