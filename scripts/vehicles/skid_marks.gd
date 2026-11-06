class_name SkidMarks
extends MultiMeshInstance3D
## Fading skid marks drawn as flat quads in a single MultiMesh (one draw call).
## Each segment stores its spawn time in custom data; the shader fades it out.
## A ring buffer reuses the oldest segments once max_segments is reached.

@export var max_segments: int = 800
@export var segment_length: float = 0.35
@export var width: float = 0.26
## Seconds until a mark fully fades.
@export var fade_time: float = 8.0
## Mark colors per surface (alpha = max opacity). Index comes from Surfaces "skid_index".
@export var road_color: Color = Color(0.08, 0.08, 0.08, 0.7)
@export var dirt_color: Color = Color(0.36, 0.26, 0.17, 0.6)
@export var sand_color: Color = Color(0.6, 0.47, 0.3, 0.55)

const SHADER_CODE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

uniform vec4 road_color : source_color = vec4(0.08, 0.08, 0.08, 0.7);
uniform vec4 dirt_color : source_color = vec4(0.36, 0.26, 0.17, 0.6);
uniform vec4 sand_color : source_color = vec4(0.6, 0.47, 0.3, 0.55);
uniform float now = 0.0;
uniform float fade_time = 8.0;

varying float alpha_mult;
varying vec4 mark;

void vertex() {
	float age = now - INSTANCE_CUSTOM.r;
	alpha_mult = clamp(1.0 - age / fade_time, 0.0, 1.0) * mix(0.5, 1.0, INSTANCE_CUSTOM.g);
	float s = INSTANCE_CUSTOM.b;
	mark = s < 0.5 ? road_color : (s < 1.5 ? dirt_color : sand_color);
}

void fragment() {
	ALBEDO = mark.rgb;
	ALPHA = mark.a * alpha_mult;
}
"""

var _mm: MultiMesh
var _mat: ShaderMaterial
var _next: int = 0
var _clock: float = 0.0
var _last_points: Array[Vector3] = []
var _has_last: Array[bool] = []
var _surface_index: float = 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var shader := Shader.new()
	shader.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	_mat.set_shader_parameter("road_color", road_color)
	_mat.set_shader_parameter("dirt_color", dirt_color)
	_mat.set_shader_parameter("sand_color", sand_color)
	_mat.set_shader_parameter("fade_time", fade_time)
	material_override = _mat

	var plane := PlaneMesh.new()
	plane.size = Vector2(1.0, 1.0)

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_custom_data = true
	_mm.mesh = plane
	_mm.instance_count = max_segments
	# Park unused segments far below the ground, fully faded.
	var hidden := Transform3D(Basis(), Vector3(0.0, -1000.0, 0.0))
	for i in max_segments:
		_mm.set_instance_transform(i, hidden)
		_mm.set_instance_custom_data(i, Color(-100000.0, 0.0, 0.0, 0.0))
	multimesh = _mm


## Call every physics tick for each wheel.
func update_wheel(index: int, point: Vector3, active: bool, strength: float, surface_index: float = 0.0) -> void:
	_surface_index = surface_index
	while _last_points.size() <= index:
		_last_points.append(Vector3.ZERO)
		_has_last.append(false)

	var p := point + Vector3.UP * 0.03
	if not active:
		_has_last[index] = false
		return
	if not _has_last[index]:
		_last_points[index] = p
		_has_last[index] = true
		return

	var length := p.distance_to(_last_points[index])
	if length < segment_length:
		return
	if length > 3.0:
		# Teleport (reset) - don't draw a long streak.
		_last_points[index] = p
		return
	_add_segment(_last_points[index], p, strength)
	_last_points[index] = p


func tick(delta: float) -> void:
	_clock += delta
	_mat.set_shader_parameter("now", _clock)


func _add_segment(a: Vector3, b: Vector3, strength: float) -> void:
	var seg := b - a
	var length := seg.length()
	var dir := seg / length
	var side := Vector3.UP.cross(dir).normalized()
	var basis_seg := Basis(side * width, Vector3.UP, dir * length * 1.08)
	_mm.set_instance_transform(_next, Transform3D(basis_seg, (a + b) * 0.5))
	_mm.set_instance_custom_data(_next, Color(_clock, clampf(strength, 0.0, 1.0), _surface_index, 0.0))
	_next = (_next + 1) % max_segments
